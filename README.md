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
`anh-selftest [N]` runs Tutorial 1 of the manual with N MPI processes for
phase 2b (default 2) and should end with `anh-selftest: OK`; it takes about
one minute. N must not exceed the number of physical cores: the image's
OpenMPI gives one slot per core, so on a machine with hyper-threading
`anh-selftest $(nproc)` fails with "not enough slots" (use
`mpirun --use-hwthread-cpus` or `--oversubscribe` for your own runs if you
really want more processes). The image is about 1.5 GB.

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
Phase 2b runs with `mpirun -np N` inside the container.

Who owns the files you write in `/work`:
- **rootless Docker** (and Docker Desktop on macOS and Windows): root in the
  container is you on the host, so the files already belong to you. Do
  **not** add `--user`: the container's user would then be a different,
  unprivileged id on the host, and writing in `/work` fails with
  "Permission denied".
- **Docker with a root daemon** (the usual Linux installation): add
  `--user $(id -u):$(id -g)` to `docker run`, or the files belong to root.

## Cluster: Apptainer (Singularity)

```
apptainer pull anharmonicaos-2026.11.1.sif docker://ghcr.io/gmulas/anharmonicaos:2026.11.1
apptainer exec anharmonicaos-2026.11.1.sif anh-selftest
apptainer exec anharmonicaos-2026.11.1.sif thermal_anharmonicity_fase1
```
The `.sif` file is about 0.5 GB. Apptainer runs as you and mounts your home
and the current directory, so the programs read and write your files
directly, and the files belong to you. In a batch job, run the programs with
`apptainer exec`; phase 2b runs within one node, with `mpirun` inside the
container:
```
apptainer exec anharmonicaos-2026.11.1.sif mpirun -np 8 thermal_anharmonicity_fase2b
```
**Several nodes (try at your own risk).** Apptainer also supports the
"hybrid" model, in which the host's `mpirun` (or `srun`) starts one
container per process:
```
mpirun -np 64 apptainer exec anharmonicaos-2026.11.1.sif thermal_anharmonicity_fase2b
```
It needs an MPI on the host that can start the image's OpenMPI (see
`apptainer exec ... ompi_info --version`; the image has the OpenMPI of
Debian stable, 5.0.7 in trixie), and it depends on the cluster's MPI,
network and launcher. What was tried, on Tutorial 1:
- a laptop: the host's OpenMPI 6.0.0rc2 started 4 processes of the image's
  5.0.7 as one MPI job, and the histograms were identical to those of
  `mpirun` inside the container;
- a Slurm cluster with OpenMPI 5.0.7 and SingularityCE 3.11 (use
  `singularity exec` where there is no `apptainer`): with the host's
  `mpirun` inside the allocation, 4 processes on one node gave histograms
  identical to a run inside the container, and 8 processes on two nodes
  ran as one job, with differences only in the last digits (as with any
  change of the process count). The processes chose OpenMPI's `ob1`
  transport, not UCX, so the fast network of the cluster was probably not
  used: fine for phase 2b, which communicates little, but check with
  `--mca pml_base_verbose 10` before relying on the speed of a larger run.

Inside a Slurm allocation, `mpirun` *inside* the container sees the job's
task count: for a single-task job with several cores, use
`apptainer exec --cleanenv ... mpirun -np N ...`, which hides the Slurm
variables. Check the result against a single-node run (for example
Tutorial 1) before relying on it.

For many starting states, the job scripts of `anh_jobs.py` take the program
names from `FASE2A`/`FASE2B`, for example
`FASE2A="apptainer exec $PWD/anharmonicaos-2026.11.1.sif thermal_anharmonicity_fase2a"`.

## What is inside

- Debian stable with OpenMPI, OpenBLAS with 64-bit integers and OpenMP
  (as BLAS/LAPACK), ScaLAPACK with 64-bit integers, GSL, PARI, Python 3 with
  numpy and matplotlib;
- PETSc and SLEPc with 64-bit BLAS integers (32-bit PETSc indices), and
  ELPA with 64-bit integers, built from their release tarballs with the
  options of the build the release was validated with;
- AnharmoniCaOs, built from the release tarball on SourceForge, whose
  SHA256 is checked.

There are no CPU-specific optimisations, so the image runs on any x86_64
or arm64 machine; a build tuned for one machine (see the manual) can be
faster. In particular, ELPA has **no GPU back end** (NVIDIA, AMD or Intel)
and only its generic CPU kernels. To use a GPU, or ELPA's kernels for your
CPU (AVX2, AVX-512, ...), build your own ELPA and AnharmoniCaOs outside the
image, following the "Building" section of the AnharmoniCaOs README. Within one node MPI runs inside the container; across several
nodes see the hybrid model above, which needs an MPI on the host close to
the one in the image.

## Building it yourself

```
docker build --build-arg JOBS=$(nproc) -t anharmonicaos:2026.11.1 .
docker run --rm anharmonicaos:2026.11.1 anh-selftest 4
```
On a 16-thread laptop the build takes about 12 minutes (PETSc about 4,
ELPA about 5); `JOBS` is the number of parallel compile jobs (default 4).
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
