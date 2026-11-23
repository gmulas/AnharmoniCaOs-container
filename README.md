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
(for example Apple Silicon Macs), tagged with the release (`2026.11.4`) and
`latest`.

## Laptop or workstation: Docker

With Docker (Linux, or Docker Desktop on macOS and Windows; see
[macOS and Windows](#macos-and-windows) below):
```
docker pull ghcr.io/gmulas/anharmonicaos:2026.11.4
docker run --rm ghcr.io/gmulas/anharmonicaos:2026.11.4 anh-selftest
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
docker run --rm -it -v "$PWD":/work ghcr.io/gmulas/anharmonicaos:2026.11.4
```
Inside, the programs `thermal_anharmonicity_fase1`, `_fase2a` and `_fase2b`
and the tools (`gaussian2ac.py`, `orca2ac.py`, `anh_sample.py`,
`anh_hopball.py`, `anh_jobs.py`, `anh_assemble.py`) are in the `PATH`;
the examples of the manual are in `$ANH_EXAMPLES`. For example,
Tutorial 1:
```
cp -r $ANH_EXAMPLES/pyrene t1 && cd t1 && sh run.sh $ANHBIN 4
```
Phase 2b runs with `mpirun -np N` inside the container.

**Threads, processes and memory.** The image sets `OMP_NUM_THREADS=1`; pass
more threads with `-e OMP_NUM_THREADS=8` (Docker) or
`--env OMP_NUM_THREADS=8` (Apptainer). Threads times MPI processes should
not exceed the cores the container sees (`docker run --rm IMAGE nproc`).
On macOS and Windows every engine runs the container in a Linux virtual
machine, also from a terminal, and the container sees only its cores and
memory: set them in Docker Desktop, Settings > Resources (macOS), or in
`.wslconfig` for WSL2 (Windows). Details, and other engines: section
"Threads, processes and memory in a container" of the
[user manual](https://github.com/gmulas/AnharmoniCaOs-manual).

Who owns the files you write in `/work`:
- **rootless Docker** (and Docker Desktop on macOS and Windows): root in the
  container is you on the host, so the files already belong to you. Do
  **not** add `--user`: the container's user would then be a different,
  unprivileged id on the host, and writing in `/work` fails with
  "Permission denied".
- **Docker with a root daemon** (the usual Linux installation): add
  `--user $(id -u):$(id -g)` to `docker run`, or the files belong to root.

## macOS and Windows

The image has been tested on Linux (x86_64 and arm64) and, with
`anh-selftest` of release 2026.11.1 (all three numbers as expected), on:

| system | machine | engine | time |
|---|---|---|---|
| macOS 26.7.1 | MacBook Pro, Apple M1 Pro, 32 GB (arm64 image) | Docker Desktop 4.99 | 2 min 22 s |
| Windows 11 Pro 23H2, WSL 3.0.1 | ASUS Zenbook, Intel Core i9-13900H, 32 GB (amd64 image) | Docker Desktop 4.99.0, WSL2 back end, from PowerShell | about 30 s |

- **macOS**: Docker Desktop, or an equivalent (Colima, OrbStack, Podman;
  not tested), runs a Linux virtual machine; Docker picks the arm64 image
  on Apple silicon and the amd64 one on Intel Macs. The `.sif` files are of
  no use on a Mac: Apptainer and Singularity do not run on macOS itself.
- **Windows**: Docker Desktop with the WSL2 back end, from PowerShell or
  from the terminal of a WSL2 distribution; Docker installed inside the
  WSL2 distribution, or Apptainer there, should work too (not tested).
  Windows without WSL2 is not supported. To work on your own files, keep
  them in the Linux file system of the WSL2 distribution and run from its
  terminal: files under `C:\` (`/mnt/c`) are much slower to reach from the
  virtual machine. From PowerShell the current folder is mounted with
  `-v ${PWD}:/work`.

Reports from other systems are welcome: send the last lines of
`anh-selftest`, the version of the system and of the processor, and the
output of `docker version`, to the maintainer, or open an issue in this
repository.

Docker Desktop gives its virtual machine only part of the computer's
memory and cores (Settings → Resources); the self-test needs less than
1 GB, larger calculations may need more.

## Cluster: Apptainer (Singularity)

```
apptainer pull anharmonicaos-2026.11.4.sif docker://ghcr.io/gmulas/anharmonicaos:2026.11.4
apptainer exec anharmonicaos-2026.11.4.sif anh-selftest
apptainer exec anharmonicaos-2026.11.4.sif thermal_anharmonicity_fase1
```
The `.sif` file is about 0.5 GB. Apptainer runs as you and mounts your home
and the current directory, so the programs read and write your files
directly, and the files belong to you. In a batch job, run the programs with
`apptainer exec`; phase 2b runs within one node, with `mpirun` inside the
container:
```
apptainer exec anharmonicaos-2026.11.4.sif mpirun -np 8 thermal_anharmonicity_fase2b
```
**Several nodes (try at your own risk).** Apptainer also supports the
"hybrid" model, in which the host's `mpirun` (or `srun`) starts one
container per process:
```
mpirun -np 64 apptainer exec anharmonicaos-2026.11.4.sif thermal_anharmonicity_fase2b
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
  change of the process count).

**InfiniBand.** Debian's OpenMPI, which the image has, disables UCX by
default (`pml = ^ucx` in `/etc/openmpi/openmpi-mca-params.conf`), so the
processes fall back to OpenMPI's `ob1` transport, which does not use
InfiniBand. To use it, set the PML to UCX for the processes in the
container:
```
mpirun -np 64 -x OMPI_MCA_pml=ucx apptainer exec anharmonicaos-2026.11.4.sif thermal_anharmonicity_fase2b
```
On the cluster above this made UCX use the InfiniBand adapter (`rc_verbs`
on `mlx5_0`, shown with `--mca pml_ucx_verbose 10`), phase 2b of Tutorial
1 on two nodes took 34 s instead of 55 s, and the histograms were the same
up to the last digits.

Inside a Slurm allocation, `mpirun` *inside* the container sees the job's
task count: in a single-task job with several cores, `mpirun -np 4` stops
with "not enough slots"; use `apptainer exec --cleanenv ... mpirun -np N ...`,
which hides the Slurm variables (`--env OMP_NUM_THREADS=N` still passes the
threads). Check the result against a single-node run (for example
Tutorial 1) before relying on it.

For many starting states, put the container in the `mpirun` entry of the
Slurm profile of `anh_jobs.py`, and leave `bindir` empty, so that each job
starts the programs inside the image:
```
"mpirun": "apptainer exec --cleanenv --env OMP_NUM_THREADS=8 /path/anharmonicaos-2026.11.4.sif mpirun -np 1 --bind-to none",
"bindir": ""
```
(tested on a Slurm cluster with SingularityCE: the histograms are the same
as those of a direct run). Setting `FASE2A`/`FASE2B` to a command of
several words does not work: the job scripts pass them as a single word.
See the chapter "Running the programs" of the manual.

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
docker build --build-arg JOBS=$(nproc) -t anharmonicaos:2026.11.4 .
docker run --rm anharmonicaos:2026.11.4 anh-selftest 4
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
