# Ansible components

Warewulf, Slurm, Spack and Lmod implement the staged [core workflow](../core/README.md).
Each directory is one Ansible role. Core selects named task entry points;
the four supported roles' `tasks/main.yml` deliberately fail with directions
to use core instead. They are not standalone installation entry points.

| Component | Implemented entry points |
| --- | --- |
| [Warewulf](warewulf/README.md) | security, head, image_prepare, publish, verify_publication, verify, rollback |
| [Slurm](slurm/README.md) | head, cpu_image, verify |
| [Spack](spack/README.md) | head, cpu_image, verify |
| [Lmod](lmod/README.md) | head, cpu_image, verify |

The existing Apptainer, ELK, Grafana, Globus and
eRaider roles have not been revised as part of this milestone. No GPU deployment
entry point is included.

## Initialization order and responsibilities

The default full deployment runs these phases on the head:

1. **Warewulf `head` → `image_prepare`:** configure provisioning services,
   prepare head-root SSH access, and install base services and identities in
   the working CPU image.
2. **Slurm `head` → `cpu_image`:** configure the controller and workers, copy
   the Munge key through protected stdin, configure time synchronization, and
   enable the worker services for boot.
3. **Spack `head` → `cpu_image`:** prepare the software environment on the head,
   install requested packages, generate Lmod modules when selected, and configure
   the CPU's read-only NFS software mount and on-demand Spack shell function.
4. **Lmod `head` → `cpu_image`:** install the module runtime and Bash integration
   for the shared Spack modules.
5. **Warewulf `publish`:** snapshot and build the completed image, configure CPU
   nodes and overlays, validate the release, and activate it. Core then runs
   `verify_publication`, including when a valid resume skips publication.

Handlers finish and a phase receipt is saved before the next phase starts.
Image edits use `wwctl image exec --build=false --syncuser=false` with a guard
against modifying the head root. Only final publication builds the OS image.
Core does not boot or reboot compute nodes.

Warewulf is required; Lmod requires Spack. Use `core_components` to select
components, and use the same selection for deployment and verification.
Selection does not uninstall previously installed software. The
`core_stage=warewulf_prepare` option runs only the first two Warewulf phases;
it does not publish the changed image or make CPUs ready for acceptance checks.

## Before deployment

Complete `ansible/setup` first. Core reads its head-node handoff from
`/etc/hpc-setup/setup.yml` and the `setup_complete` checkpoint. Provisioning
uses inventory MACs on an isolated trusted network, without asset keys.

Configure the repository's [shared deployment files](../../../config/README.md):

- `config/hosts.yml`: actual CPU MAC/IP addresses, architecture, and Slurm CPU
  topology and usable memory. GPU entries currently reserve addresses only.
- `config/group_vars/all.yml`: selected components, image/package settings and
  `warewulf_authorized_keys` containing the controller user's public SSH keys.
  Review `warewulf_compute_dns` for your network.

The current selection is Warewulf, Slurm, Spack and Lmod, with CPU image
`rockylinux-9.5` and Spack package `hdf5`. DHCP leases use `10.0.1.1–10.0.1.255`;
the node network overlay applies final CPU addresses `10.0.2.1–10.0.2.3` after
boot. Both are inside the configured cluster `/22`.

Check that the upstream subnet does not overlap the cluster subnet. In particular,
VirtualBox's `10.0.2.0/24` NAT subnet conflicts with these CPU addresses. Core's
preflight does not detect every overlapping route. Its 6 GiB/100,000-inode check
on `/` is also only a minimum: allow space for active and staged images and
check separately mounted deployment filesystems.

Spack builds as the dedicated `hpc-spack` account. Its head phase migrates
ownership inside the dedicated Spack trees; existing installations need review
before adoption. Package repositories and Internet access are required for the
Warewulf RPM/image and Spack sources. Head service UID/GID mismatches cause an
error rather than automatic renumbering.

From the repository root, using your Ansible environment:

```bash
cd src/ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook core/playbooks/site.yml -e core_action=plan
ansible-playbook core/playbooks/site.yml -K -e core_action=preflight
ansible-playbook core/playbooks/site.yml -K

# After booting CPUs with the published image:
ansible-playbook core/playbooks/verify.yml -K
```

Run Ansible as the controller user. `-K` normally asks for that user's head sudo
password; omit it when sudo is passwordless. Preflight checks the setup handoff,
cluster inputs and provisioning requirements. Component-specific prerequisites
are also checked at their entry points. The setup directory and shell
implementations remain separate from this workflow.

## Administrative access

Warewulf image preparation preserves or creates the head's
`/root/.ssh/id_ed25519` and adds its public key alongside the configured controller
keys in the image's root `authorized_keys`. An encrypted or invalid existing key
stops preparation; it is never overwritten. The head's private login key is not
copied into the image.

Publication records each CPU's generated SSH host key for both the controller
user and head root. Root's SSH configuration selects the matching identity for
managed CPU addresses with host-key checking enabled. After publishing and
booting the updated image:

```bash
sudo wwctl ssh cpu01 'id -u'
sudo wwctl ssh cpu01 'systemctl restart slurmd'
```

The first command should report `0`. This uses a root SSH login on the CPU; it
does not create compute sudo accounts or grant new head sudo permissions. Head
users already authorized to run `sudo wwctl ssh` can use it without a compute
password. GPU image provisioning and access setup are not part of this workflow.

## Reruns, recovery and acceptance

Core stores successful phase receipts under
`/var/log/hpc-setup/checkpoints/core/`. Normal deployment reconciles all selected
phases; `-e core_resume=true` skips only a matching prefix after validating code,
configuration and recorded state. Failed phases rerun from their beginning.
Use `-e core_resume=false` for a full reconciliation. Shell component flags do
not substitute for these receipts.

After successful publication, only the active release directory is retained.
Historical rollback is unavailable after commit, and copied older archives
inside the active provision tree can still consume space. See the core README's
[recovery guidance](../core/README.md#recovery-and-verification) for publication
boundaries, interrupted-run recovery and storage limitations.

Earlier image rendering could concatenate a file's last line with its heredoc
terminator, corrupting Spack/Lmod profiles and Slurm configuration while skipping
later service setup. Current templates preserve those boundaries, syntax-check
shell profiles, and require a completion marker from the main image scripts.
Affected nodes need a full deployment with `core_resume=false`, publication,
and reboot. See [image repair instructions](../core/README.md#recovering-images-built-with-malformed-template-boundaries).

Post-boot verification checks the served/booted image and network/software mounts,
Slurm/Munge/time health and real CPU jobs, installed software executables, and
Lmod module loading. A successful image build or phase receipt alone is not
cluster acceptance. For nodes in `UNKNOWN`, inspect Munge/Slurmd logs and resolve
registration failures before trying scheduler state changes.

## Validation scope

~~~bash
bash components/tests/run.sh
bash core/tests/run.sh
~~~

Component tests statically import the real task files for syntax checking,
render and inspect configuration, check shell syntax, exercise the guard
against head-root execution, check identity conflict refusal, and test
publication fingerprints and repeatable managed-file writes. They do not run
DNF, change system services, import/build OS images, or submit real Slurm jobs.
Tests also exercise actual Ansible template lookup and heredoc boundaries,
incomplete image-script rejection, and root SSH key preservation/configuration
in temporary directories. Some optional checks use an installed `wwctl` against
temporary overlay data. Full PXE/NFS/Slurm/Spack integration still needs live
cluster acceptance checks.
