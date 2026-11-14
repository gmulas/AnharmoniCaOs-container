# AnharmoniCaOs-container

Docker/Apptainer images of
[AnharmoniCaOs](https://sourceforge.net/projects/anharmonica/), which computes
anharmonic infrared spectra of large molecules such as polycyclic aromatic
hydrocarbons (PAHs), including the hot bands of vibrationally excited
molecules. The image contains the three programs, already built with all
their libraries, the Python tools for spectra at T > 0, and the examples
of the [user manual](https://github.com/gmulas/AnharmoniCaOs-manual/releases/latest).
Nothing needs to be compiled.

The image is `ghcr.io/gmulas/anharmonicaos`, for x86_64 (amd64) and arm64
(for example Apple Silicon Macs), tagged with the release (`2026.11.1`) and
`latest`.

## Laptop or workstation: Docker

With Docker (Linux, or Docker Desktop on macOS and Windows):
```
docker pull ghcr.io/gmulas/anharmonicaos:2026.11.1
docker run --rm ghcr.io/gmulas/anharmonicaos:2026.11.1 anh-selftest
```
`anh-selftest` runs Tutorial 1 of the manual and should end with
`anh-selftest: OK`.

To work on your own files, mount the current directory as `/work`:
```
docker run --rm -it -v "$PWD":/work ghcr.io/gmulas/anharmonicaos:2026.11.1
```
Inside, the programs `thermal_anharmonicity_fase1`, `_fase2a` and `_fase2b`
and the tools `anh_sample.py`, `anh_jobs.py`, `anh_assemble.py` are in the
`PATH`; the examples of the manual are in `$ANH_EXAMPLES`. For example,
Tutorial 1:
```
cp -r $ANH_EXAMPLES/pyrene t1 && cd t1 && sh run.sh $ANHBIN 4
```
Phase 2b runs with `mpirun -np N` inside the container. On Linux, add
`--user $(id -u):$(id -g)` to `docker run` so that the files you write
belong to you.

## Cluster: Apptainer (Singularity)

```
apptainer pull anharmonicaos-2026.11.1.sif docker://ghcr.io/gmulas/anharmonicaos:2026.11.1
apptainer exec anharmonicaos-2026.11.1.sif anh-selftest
apptainer exec anharmonicaos-2026.11.1.sif thermal_anharmonicity_fase1
```
Apptainer mounts your home and the current directory, so the programs read
and write your files directly. In a batch job, run the programs with
`apptainer exec`; phase 2b runs within one node, with `mpirun` inside the
container:
```
apptainer exec anharmonicaos-2026.11.1.sif mpirun -np 8 thermal_anharmonicity_fase2b
```
For many starting states, the job scripts of `anh_jobs.py` take the program
names from `FASE2A`/`FASE2B`, for example
`FASE2A="apptainer exec $PWD/anharmonicaos-2026.11.1.sif thermal_anharmonicity_fase2a"`.

## What is inside

- Debian stable with OpenMPI, 64-bit BLAS/LAPACK and ScaLAPACK, GSL, PARI,
  Python 3 with numpy and matplotlib;
- PETSc and SLEPc with 64-bit indices and 64-bit BLAS integers, and ELPA
  with 64-bit integers and OpenMP, built from their release tarballs;
- AnharmoniCaOs, built from the release tarball on SourceForge, whose
  SHA256 is checked.

There are no CPU-specific optimisations, so the image runs on any x86_64
or arm64 machine; a build tuned for one machine (see the manual) can be
faster. Only one node: MPI across several nodes from a container needs an
MPI compatible with the host's, and is not covered here.

## Building it yourself

```
docker build -t anharmonicaos:2026.11.1 .
docker run --rm anharmonicaos:2026.11.1 anh-selftest
```
The versions of AnharmoniCaOs, PETSc, SLEPc and ELPA are set at the top of
the `Dockerfile`. The workflow in `.github/workflows/image.yml` builds and
tests the image on amd64 and arm64 for every pull request, and publishes it
from `main`.

## Licence

The files of this repository are under the GNU General Public License,
version 3. The image contains AnharmoniCaOs (GPL v3) and free software
under its own licences (GPL, LGPL, BSD and others); the sources of
everything are public: AnharmoniCaOs on SourceForge, the libraries from
Debian and from their projects at the versions given in the `Dockerfile`.
