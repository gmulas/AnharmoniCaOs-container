# AnharmoniCaOs in a container, built from the public release tarball.
#
#   docker build -t anharmonicaos:2026.11.1 .
#   docker run --rm anharmonicaos:2026.11.1 anh-selftest
#
# Everything is built from public sources: Debian packages (MPI, 64-bit
# BLAS/LAPACK/ScaLAPACK, GSL, PARI, Python), PETSc, SLEPc and ELPA from
# their release tarballs, AnharmoniCaOs from the release tarball on
# SourceForge (checked against its SHA256). Integers are 64-bit throughout
# (PETSc indices and BLAS integers, ScaLAPACK, ELPA), as in the builds the
# release was validated with. No CPU-specific optimisation: the image runs
# on any x86_64 or arm64 machine.
#
# Versions: change them here (and the SHA256 of the AnharmoniCaOs tarball).
ARG DEBIAN=trixie

FROM debian:${DEBIAN}-slim AS build
ARG ANH_VERSION=2026.11.1
ARG ANH_SHA256=8f923633b758553ea1c497694eacec3adf66216ad9d9b5fc5b450c2484f7a6f6
# Where to get the release tarball; its SHA256 is checked whatever the
# source. For a local test before the upload, serve the tarball with
# "python3 -m http.server" and build with --network=host
# --build-arg ANH_URL=http://localhost:8000/AnharmoniCaOs-<version>.tar.gz
ARG ANH_URL=https://downloads.sourceforge.net/project/anharmonica/AnharmoniCaOs-${ANH_VERSION}.tar.gz
ARG PETSC_VERSION=3.24.1
ARG SLEPC_VERSION=3.24.1
ARG ELPA_VERSION=2026.02.002
ARG JOBS=4

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential gfortran pkg-config python3 curl ca-certificates xz-utils file \
      libopenmpi-dev openmpi-bin \
      libopenblas64-openmp-dev liblapack64-dev libscalapack64-openmpi-dev \
      libgsl-dev libpari-dev \
    && rm -rf /var/lib/apt/lists/*

ENV OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
# 64-bit-integer BLAS/LAPACK: OpenBLAS64 with OpenMP, as in the build the
# release was validated with (Debian's libblas64.so.3 and liblapack64.so.3
# are alternatives that point to it, and it has the highest priority over
# the reference BLAS64); ScaLAPACK64 links against them.
ENV BLAS64="-llapack64 -lblas64" SCALAPACK64="-lscalapack64-openmpi"
WORKDIR /src

# PETSc: 64-bit indices and 64-bit BLAS integers, no debugging, generic -O2.
# Without ScaLAPACK: PETSc refuses it with 64-bit BLAS integers ("Cannot use
# ScaLAPACK with 64-bit BLAS/LAPACK indices") and does not need it;
# AnharmoniCaOs and ELPA link Debian's scalapack64-openmpi themselves.
RUN curl -fsSL https://web.cels.anl.gov/projects/petsc/download/release-snapshots/petsc-${PETSC_VERSION}.tar.gz | tar xz \
 && cd petsc-${PETSC_VERSION} \
 && ./configure --prefix=/opt/petsc --with-debugging=0 \
      --with-64-bit-indices --with-64-bit-blas-indices \
      --with-cc=mpicc --with-cxx=mpicxx --with-fc=mpifort \
      COPTFLAGS=-O2 CXXOPTFLAGS=-O2 FOPTFLAGS=-O2 \
      --with-blaslapack-lib="${BLAS64}" \
      --with-x=0 --with-shared-libraries=1 \
 && make PETSC_DIR=$PWD PETSC_ARCH=arch-linux-c-opt -j${JOBS} all \
 && make PETSC_DIR=$PWD PETSC_ARCH=arch-linux-c-opt install \
 && cd .. && rm -rf petsc-${PETSC_VERSION}

# SLEPc on that PETSc
RUN curl -fsSL https://slepc.upv.es/download/distrib/slepc-${SLEPC_VERSION}.tar.gz | tar xz \
 && cd slepc-${SLEPC_VERSION} \
 && PETSC_DIR=/opt/petsc ./configure --prefix=/opt/slepc \
 && make SLEPC_DIR=$PWD PETSC_DIR=/opt/petsc -j${JOBS} \
 && make SLEPC_DIR=$PWD PETSC_DIR=/opt/petsc install \
 && cd .. && rm -rf slepc-${SLEPC_VERSION}

# ELPA with 64-bit integers, OpenMP, generic kernels only (AnharmoniCaOs
# uses the one-stage solver by default; generic kernels avoid illegal
# instructions on older CPUs and build the same way on arm64)
RUN curl -fsSL https://elpa.mpcdf.mpg.de/software/tarball-archive/Releases/${ELPA_VERSION}/elpa-${ELPA_VERSION}.tar.gz | tar xz \
 && cd elpa-${ELPA_VERSION} \
 && ./configure FC=mpifort CC=mpicc FCFLAGS="-O2" CFLAGS="-O2" \
      SCALAPACK_LDFLAGS="${SCALAPACK64} ${BLAS64}" SCALAPACK_FCFLAGS="" \
      --prefix=/opt/elpa --enable-openmp --enable-64bit-integer-math-support \
      --disable-sse --disable-sse-assembly --disable-avx --disable-avx2 --disable-avx512 \
      --disable-neon-arch64 --disable-sve128 --disable-sve256 --disable-sve512 \
      --enable-c-tests=no --enable-cpp-tests=no --with-test-programs=no \
 && make -j${JOBS} && make install \
 && cd .. && rm -rf elpa-${ELPA_VERSION}

# AnharmoniCaOs from the release tarball, with its bundled input parser
RUN curl -fsSL -o anh.tar.gz "${ANH_URL}" \
 && echo "${ANH_SHA256}  anh.tar.gz" | sha256sum -c - \
 && tar xzf anh.tar.gz && rm anh.tar.gz \
 && cd AnharmoniCaOs-${ANH_VERSION} \
 && mkdir -p build/oct-parser && cd build/oct-parser \
 && ../../external/oct-parser/configure --prefix=/opt/oct-parser --disable-fortran \
 && make -j${JOBS} && make install && cd ../.. \
 && ./configure --prefix=/opt/anharmonicaos \
      --with-petsc=/opt/petsc --with-slepc=/opt/slepc --with-elpa=/opt/elpa \
      --with-oct-parser=/opt/oct-parser \
 && make -j${JOBS} && make install \
 && mkdir -p /opt/anharmonicaos/share/anharmonicaos \
 && cp -r tools doc/manual/examples README.md NEWS.md COPYING AUTHORS /opt/anharmonicaos/share/anharmonicaos/ \
 && cd .. && rm -rf AnharmoniCaOs-${ANH_VERSION}

FROM debian:${DEBIAN}-slim
ARG ANH_VERSION=2026.11.1
LABEL org.opencontainers.image.title="AnharmoniCaOs" \
      org.opencontainers.image.version="${ANH_VERSION}" \
      org.opencontainers.image.description="Anharmonic IR spectra of large molecules (PAHs), including hot bands" \
      org.opencontainers.image.licenses="GPL-3.0-only" \
      org.opencontainers.image.source="https://github.com/gmulas/AnharmoniCaOs-container" \
      org.opencontainers.image.url="https://sourceforge.net/projects/anharmonica/" \
      org.opencontainers.image.documentation="https://github.com/gmulas/AnharmoniCaOs-manual/releases/latest"
# Runtime libraries only. The -dev packages pull in the matching runtime
# packages under their versioned names; keeping them is simpler than
# tracking those names, at the cost of some size.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      openmpi-bin libopenmpi-dev libgfortran5 libgomp1 \
      libopenblas64-openmp-dev liblapack64-dev libscalapack64-openmpi-dev \
      libgsl-dev libpari-dev \
      python3 python3-numpy python3-matplotlib xz-utils \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /opt /opt
COPY anh-selftest /opt/anharmonicaos/bin/anh-selftest
ENV PATH=/opt/anharmonicaos/bin:/opt/anharmonicaos/share/anharmonicaos/tools:$PATH \
    LD_LIBRARY_PATH=/opt/petsc/lib:/opt/slepc/lib:/opt/elpa/lib:/opt/oct-parser/lib \
    ANHBIN=/opt/anharmonicaos/bin \
    ANH_EXAMPLES=/opt/anharmonicaos/share/anharmonicaos/examples \
    OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1 \
    OMP_NUM_THREADS=1 \
    MPLBACKEND=Agg
WORKDIR /work
CMD ["bash"]
