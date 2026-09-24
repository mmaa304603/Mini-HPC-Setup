# Spack component

Implements head, cpu_image and verify entry points for Spack v0.23.1. The head
installs OS build prerequisites, checks out the pinned Spack tree without
discarding local edits, detects compilers, and concretizes/installs a shared
software environment. Checkout and Spack commands run under the dedicated
`hpc-spack` account, using exact commit `2bfcc69fa870d3c6919be87593f22647981b648a`.
Root installs OS prerequisites and system profiles. No system-wide pip installation
is used. Run the entry points through [core](../../core/README.md); standalone
role execution is rejected. The current software target is generic x86_64 CPU
nodes, not GPU or aarch64 provisioning.

## Ownership migration

The builder uses `/var/lib/hpc-spack` as its home, `/var/cache/hpc-spack` as its
cache, and `/var/tmp/hpc-spack-stage` for builds. Legacy ownership migration is
limited to the dedicated installation, cache and staging trees. It skips
symlinks and other filesystems and supports hardlinks whose links are all inside
those trees. It refuses unexpected special files and ownership changes to
hardlinks shared outside them. A failure may follow earlier ownership changes;
stop concurrent Spack builds and inspect the reported problem before retrying.
Retain the installation database and installed software.

## Build reruns and lockfile recovery

The install task redirects stdin from `/dev/null` for non-interactive builds.
This avoids Spack 0.23.1's terminal-query failure when sudo/Ansible supplies a
pseudo-terminal without a controlling terminal (`Inappropriate ioctl for device`
followed by `BrokenPipeError`). Build errors still fail the playbook. After
updating the task, rerun core normally; retain the lockfile and installed software.

Core validates existing lockfiles before concretization and saves a validated
`spack.lock.last-good` before/after successful concretization. An empty or corrupt
lockfile stops deployment with its path. Stop concurrent Spack runs before
recovery; restore a valid backup when available. Otherwise move the corrupt
lockfile aside and reconcretize, keeping the install database and software.
Reconstruction can select different dependency versions; it cannot restore
the lost exact plan. The last-good copy is not a full software rollback.

## Configuration and deployment

- spack_install_dir: /opt/spack
- spack_environment_dir: /opt/spack/environments/hpc
- spack_view_dir: /opt/spack/views/hpc
- spack_packages: [hdf5] initially
- spack_build_jobs: 4
- spack_verify_command: [h5dump, -V]
- spack_verify_spec: first requested spec (used for the Lmod executable test)

The environment and view stay inside the exported installation directory.
If you change the package list, also select an appropriate executable smoke
test. A generic x86_64 target avoids building software only for the head's
particular CPU microarchitecture.

From `src/ansible`, after setup and configuration, the default full deployment
runs Spack after Slurm and before Lmod:

```bash
ansible-playbook core/playbooks/site.yml -K -e core_action=preflight
ansible-playbook core/playbooks/site.yml -K
# After CPU nodes boot the published image:
ansible-playbook core/playbooks/verify.yml -K
```

Spack uses a lockfile and its installed-package database for reruns. Adding a
package does not get skipped merely because an installation database exists.
Builds run on the head; compute nodes consume a read-only NFS software tree.
Warewulf owns that export. The image phase adds only a managed fstab block and
shell initialization, preserving other filesystem entries. The NFS mount uses
`nofail` and automount. Spack initializes on the first `spack` command, avoiding
shared-filesystem reads during ordinary login. It uses the managed site config;
system and user configuration overrides are disabled for this entry point.

The image phase creates a missing `/etc/fstab` before managing its entries.
Both head and image profiles are syntax checked. Embedded profile templates
have explicit newline boundaries, and the image task requires its final
completion marker. For existing `}HPC_PROFILE` or unexpected-end-of-file errors,
use the [image repair procedure](../../core/README.md#recovering-images-built-with-malformed-template-boundaries).

Lmod module generation is enabled only when Lmod is selected in core_components.
Spack owns modules.yaml and generated files under /opt/spack/modules/lmod/Core;
generation happens at the end of its head phase, before Lmod installation.
The Lmod role owns the OS runtime and shell module path. A single flat Core
directory uses the detected system GCC as the core compiler; the environment
prefers that compiler and targets generic x86_64. Spack works without Lmod.
The `hierarchy:: []` override deliberately replaces Spack's default MPI hierarchy.

For maintenance, edit `spack_packages` in `config/group_vars/all.yml`, then rerun
core deployment. The lockfile and install database retain existing solutions;
module refresh reconciles generated files without deleting the whole tree.
Removed specs are not automatically uninstalled. If the representative package
changes, update its smoke-test command/spec too.

Verification requires every requested package and runs the selected executable
as `nobody` from the environment view on the head and each CPU node. Warewulf verification
separately checks that the view is supplied by the expected read-only NFS mount.

## Build progress and operational limits

One requested root spec such as HDF5 can require many dependency builds.
Installation can therefore take much longer than installing one OS package.
Inspect the saved plan using the same builder and configuration as the role:

```bash
sudo -u hpc-spack env SPACK_DISABLE_LOCAL_CONFIG=true \
  SPACK_USER_CACHE_PATH=/var/cache/hpc-spack SPACK_PYTHON=/usr/bin/python3 \
  /opt/spack/bin/spack -e /opt/spack/environments/hpc find --show-concretized
```

Tune `spack_build_jobs` for available head CPU and memory, and allow disk space
for build stages as well as installed software. Package build scripts execute
as the builder and require trusted sources; this is not a build sandbox.
Software and module changes become visible through NFS immediately, including
to already booted workers. Warewulf release rollback does not roll them back.

See [local tests](../tests/README.md),
[Spack 0.23.1 environments](https://spack.readthedocs.io/en/v0.23.1/environments.html)
and [module configuration](https://spack.readthedocs.io/en/v0.23.1/module_file_support.html).
