# Lmod component

Lmod is the user interface for software built by Spack. It does not build
packages or run a daemon. The role installs the EPEL `Lmod` package on the head
and the same RPM version-release in the CPU image. Spack owns module generation;
this role owns Bash initialization and module acceptance checks.

Run it through [core](../../core/README.md); standalone role execution is
rejected. Selecting Lmod requires Spack in `core_components`.

## Sequence and ownership

1. Spack head: install the pinned Spack checkout, build the `hpc` environment,
   and generate Lua module files under `/opt/spack/modules/lmod/Core`.
2. Spack image: configure read-only NFS access to `/opt/spack`.
3. Lmod head: install the OS runtime, write `/etc/profile.d/z10-hpc-lmod.sh`,
   and test loading a generated module and running its executable.
4. Lmod image: install the matching runtime and the same initialization script.
5. Warewulf: publish once, after every component has finished.

The default single-compiler layout uses one `Core` module directory. Spack's
hashed module names keep package builds distinct; no site-wide aliases, separate
module-file repository, or Lmod source build is needed. Existing unrelated
MODULEPATH entries are retained. No package is automatically loaded at login.

Spack's `module_context.yml` resolves the exact generated module name and
installed prefix. Lmod consumes that result instead of duplicating Spack's
configuration. The default test uses the first `spack_packages` spec and
`spack_verify_command` (initially `hdf5` and `[h5dump, -V]`). Set
`spack_verify_spec` if the test should target another installed spec.

## Use

From `src/ansible`, after setup and configuration, deploy the default four
components together:

```bash
ansible-playbook core/playbooks/site.yml -K -e core_action=preflight
ansible-playbook core/playbooks/site.yml -K
# After CPU nodes boot the published image:
ansible-playbook core/playbooks/verify.yml -K
```

New Bash sessions initialize Lmod through the managed profile. Existing shells
and batch scripts can initialize it explicitly:

```bash
source /etc/profile.d/z10-hpc-lmod.sh
module avail
module load hdf5
h5dump -V
module unload hdf5
```

If several versions/builds exist, select the full module name shown by
`module avail`. This role configures Bash; site-specific csh/fish/zsh setup is
outside this milestone. Spack remains usable without Lmod.

## Verification

Run core verification after workers boot the published image. Lmod checks equal
RPM releases, starts a clean Bash process as `nobody` on the head and every CPU
node, sources the managed profile, loads the exact generated module, and checks
that the executable resolves to that package's installation before running it.
The test creates and removes only a temporary home directory. It cannot pass
solely because root or the caller already has the software in PATH. Slurm's
separate acceptance test still uses the configured normal job user.

The managed profile is syntax checked on both head and image. Embedded image
templates now insert explicit newline boundaries, and the image task requires
its final completion marker. If a previously built image reports an unexpected
end of file or contains `fiHPC_LMOD`, follow the
[image repair procedure](../../core/README.md#recovering-images-built-with-malformed-template-boundaries).
Publish the corrected image and reboot workers; Lmod has no daemon to restart.

## Operational risks

- Installing Lmod adds distribution-provided module initialization as well as
  the managed Bash profile. Sites already using another module engine should
  review the resulting shell behavior. Personal shell files are not rewritten.
- Modules and programs depend on the head's NFS export. Ordinary initialization
  does not intentionally read the shared tree; `module` and software commands
  can wait or fail if the head/export is unavailable. The worker mount uses
  `nofail` and automount, but active hard-NFS I/O can still block during outages.
- Spack builds consume head CPU, memory and disk, run package build scripts as
  the dedicated `hpc-spack` account, and require trusted sources. Root installs
  OS prerequisites and system profiles. Set
  `spack_build_jobs` for the head's capacity. This is not a build sandbox.
- Regenerating modules changes shared files immediately, including for already
  booted workers. There is no atomic software release switch or automatic
  rollback; schedule changes around active jobs. Old software/modules are not
  automatically removed.
- These roles do not renumber accounts or modify the head bootloader or fstab.
  A full core run still reconciles earlier networking and Slurm phases. Worker
  runtime changes require booting the new image; deployment does not reboot nodes.

See [local tests](../tests/README.md).

References: [Spack 0.23.1 modules](https://spack.readthedocs.io/en/v0.23.1/module_file_support.html),
[EPEL Lmod package](https://packages.fedoraproject.org/pkgs/Lmod/Lmod/epel-9.html),
[Lmod initialization](https://lmod.readthedocs.io/en/latest/030_installing.html).
