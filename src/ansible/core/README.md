# Core cluster orchestration

Core prepares a Rocky Linux 9 x86_64 head and a Warewulf CPU image in this order:

1. Check the completed setup handoff and deployment inputs.
2. Configure Warewulf head services and prepare the base CPU image.
3. Configure Slurm/Munge on the head and inside the image.
4. Configure Spack and Lmod on the head and provide image access.
5. Publish the completed image and overlays.
6. After CPU nodes boot, run cluster acceptance checks separately.

## Current implementation status

Provisioning uses inventory MACs on an isolated, trusted private network.

**Warewulf, Slurm, Spack and Lmod implement the core entry points.**
The default selection runs all four components. Spack builds software and
generates module files; Lmod installs their runtime and Bash initialization.
The existing setup directory remains unchanged.
Component tasks have local syntax/template/guard tests; physical PXE boot,
package installation and multi-node acceptance still require deployment testing.

`core_action=plan` reports the selected phase order and any missing entry-point
files without connecting to managed hosts. Deployment and verification stop
before host access if their component entry points are missing. A complete plan
establishes file availability; it does not establish deployment readiness.
The component entry points and their order are listed below.
See [component deployment inputs](../components/README.md) before installation.

## Configuration

Edit the two deployment files described in [config/README.md](../../../config/README.md):

- `config/hosts.yml`: groups, addresses, actual CPU PXE MACs, and hardware values;
- `config/group_vars/all.yml`: components, versions, DHCP range, image and software settings.

Verify CPU MACs and Slurm memory before preflight. The inventory uses the
shell Slurm configuration's 7000 MB per CPU node and 1 socket × 4 cores × 1 thread.
Use actual hardware values; the included topology is the README's cluster.
Preflight requires at least 6 GiB and 100,000 free inodes on the head root
filesystem because the active and staged releases coexist during activation.
This is a fixed minimum, not a calculation of the space needed by the actual
image. Larger images or separate filesystems under `/var` or `/opt` need their
own capacity checks before deployment.
Override `core_min_free_bytes` or `core_min_free_inodes` only after measuring a
larger image; core never removes the active release to create space.

Core reads the head address, prefix, interface and service IDs from completed
setup rather than introducing a second source for those settings.
CPU firmware/iPXE obtains a temporary lease from `core_dhcp_start` through
`core_dhcp_end` (currently `10.0.1.1–10.0.1.255`). On boot, the MAC-matched
NetworkManager overlay applies each CPU's static inventory `ansible_host`
(`10.0.2.1–10.0.2.3`). Both address sets belong to the setup /22 subnet;
DHCP does not reserve the final static addresses. This matches the shell flow.

Set warewulf_authorized_keys to the controller's existing public SSH keys and
review compute DNS. No firmware tags or provisioning Vault file are required.

The configured CPU image is `rockylinux-9.5`. GPU inventory entries reserve addresses only: core does not
provision GPU operating systems, images or drivers.

Slurm uses setup's existing administrator as its normal
test-job user; slurm_verify_user may select another existing normal head user.

## Commands

Run from `src/ansible` so the root Ansible configuration is selected:

```bash
cd src/ansible

# No sudo or compute-node access required; reports phases and missing entries.
ansible-playbook core/playbooks/site.yml -e core_action=plan

# Read-only setup, topology, capacity, identity and provisioning-input checks.
ansible-playbook core/playbooks/site.yml -e core_action=preflight -K

# Reconcile all four components and publish the CPU image.
ansible-playbook core/playbooks/site.yml -K

# After booting CPU nodes with the published image:
ansible-playbook core/playbooks/verify.yml -K
```

`-K` normally requests the invoking head user's sudo password. Do not run the
controller as root. From another directory, set `ANSIBLE_CONFIG` to the absolute
path of `src/ansible/ansible.cfg`; its inventory and role paths resolve relative
to that configuration file. An explicit `-i` selects another inventory.

The setup entry point must still use `setup/ansible.cfg` (normally by running
from `src/ansible/setup`). The parent Ansible configuration selects the cluster
inventory and core/component role paths; do not use it to run setup against `all`.

### Administrative SSH from the head

`warewulf/image_prepare` creates `/root/.ssh/id_ed25519` on the head only if
absent, derives its public key, and adds that key alongside
`warewulf_authorized_keys` in the image's root `authorized_keys`. An encrypted
or invalid existing private key stops preparation; it is not replaced. The head's
private login key stays on the head.

The role adds an address-specific block to root's `/root/.ssh/config` selecting
that identity. During publication, each CPU's generated SSH host key is recorded
in root's `known_hosts` and the controller user's `known_hosts`. Host-key checking
remains enabled. Root SSH configuration, the derived public identity and published
host trust are covered by checkpoint observations.

After full publication and booting the updated image:

```bash
sudo wwctl ssh cpu01 'id -u'                 # Expected output includes 0
sudo wwctl ssh cpu01 'systemctl restart slurmd'
```

`wwctl ssh` invokes SSH for the node IP; running it with sudo normally selects
head root's identity and connects as compute root. Core does not change head sudo
permissions or create named compute sudo accounts. The controller's configured
key still supports direct `ssh root@10.0.2.1` and Ansible acceptance checks.

### First two Warewulf phases

Set `warewulf_authorized_keys` in `config/group_vars/all.yml` and check the CPU
MACs, cluster NIC isolation and DHCP range before deployment. Slurm memory is
not required for this selection. From `src/ansible`:

```bash
# Inspect the two-phase plan without changing the head.
ansible-playbook core/playbooks/site.yml -e core_action=plan \
  -e '{"core_components":["warewulf"],"core_stage":"warewulf_prepare"}'

# Check the live setup handoff without installing components.
ansible-playbook core/playbooks/site.yml -K -e core_action=preflight \
  -e '{"core_components":["warewulf"],"core_stage":"warewulf_prepare"}'

# Configure head services, then prepare the working image.
ansible-playbook core/playbooks/site.yml -K \
  -e '{"core_components":["warewulf"],"core_stage":"warewulf_prepare"}'
```

`warewulf_prepare` preserves the normal setup/identity/network checks and flushes
handlers after each phase. It requires exactly `[warewulf]`, skips publication
and acceptance checks, and does not require other components' entry points.
Preflight checks the core handoff and provisioning security inputs; SSH keys
are checked at the start of deployment.

This is a real installation: it changes the firewall, enables forwarding,
starts DHCP/TFTP and Warewulf, and modifies the named working image. Node
definitions and host-key overlays are reconciled only at final publication.
It does not publish a new image or overlays, remove old published artifacts,
or prevent existing nodes from contacting the provisioning services. There is
no automatic rollback. Do not treat preparation success as boot readiness.

To continue later, omit `core_stage` (default `full`) and select the intended
components. The full run reconciles preparation again before installing later
components and publishing. `verify` rejects the preparation stage.

For a complete Warewulf-only provisioning plan, including publication:

```bash
ansible-playbook core/playbooks/site.yml \
  -e '{"core_action":"plan","core_components":["warewulf"]}'
```

To deliberately omit Lmod, use this selection consistently for plan,
deployment and verification:

~~~bash
ansible-playbook core/playbooks/site.yml -e core_action=plan \
  -e '{"core_components":["warewulf","slurm","spack"]}'
ansible-playbook core/playbooks/site.yml -K \
  -e '{"core_components":["warewulf","slurm","spack"]}'
ansible-playbook core/playbooks/verify.yml -K \
  -e '{"core_components":["warewulf","slurm","spack"]}'
~~~

Warewulf is required. Other supported selections are Slurm, Spack and Lmod;
Lmod requires Spack. Selection does not uninstall previously installed components.
With the default `core_stage=full`, all required phases for selected components
run in the declared order. GPU,
ELK, Grafana, Apptainer, eRaider and Globus are outside this milestone.

### Software order and maintenance

`site.yml` calls `hpc_core`, which runs preflight, acquires the deployment lock,
validates provisioning inputs and checkpoints, then invokes these component
task files through `tasks/phase.yml`:

| Order | Component entry point | Purpose |
|---|---|---|
| 1 | `warewulf/tasks/head.yml` | Head provisioning, network services and time service |
| 2 | `warewulf/tasks/image_prepare.yml` | Root SSH access and base CPU image preparation |
| 3 | `slurm/tasks/head.yml` | Controller, Munge and time configuration |
| 4 | `slurm/tasks/cpu_image.yml` | Worker configuration, matching Munge key and boot services |
| 5 | `spack/tasks/head.yml` | Spack environment, requested packages and modules |
| 6 | `spack/tasks/cpu_image.yml` | Read-only software mount and Spack shell integration |
| 7 | `lmod/tasks/head.yml` | Head module runtime and shell integration |
| 8 | `lmod/tasks/cpu_image.yml` | CPU module runtime and shell integration |
| 9 | `warewulf/tasks/publish.yml` | Build and activate the complete image and overlays |

Only selected components run. After each phase, handlers finish before its
checkpoint is saved. Full deployment then verifies the served release and
releases the lock; post-boot acceptance runs separately via `verify.yml`.

Keep package choices in `config/group_vars/all.yml`; no separate Lmod package
list is needed.
Spack generates modules on the head and workers read the shared software tree.
The Lmod role installs only the runtime and Bash initialization. See the
[Lmod guide](../components/lmod/README.md) for use, acceptance checks and risks.

## Setup handoff and host protection

Non-plan actions read these root-owned regular files from the **head node**:

```text
/var/log/hpc-setup/checkpoints/setup_complete
/etc/hpc-setup/setup.yml
```

Core supports setup schema 1. The schema version and network prefix accept
integers or quoted decimal strings, matching setup's serialized defaults.
Missing, malformed and unsupported values are rejected; no snapshot edits or
setup rerun are needed just to convert those strings.
It checks the configured subnet, DHCP/static
address separation, unique CPU MACs, Slurm resources when enabled, and the
Slurm/Munge service-identity schema. It then checks the live head OS, existing
service UID/GID assignments, actual interface address and default routes.
It does not rerun baseline package, audit, SELinux or NetworkManager setup.

Core preserves existing head service identities and setup flags. Spack creates
a dedicated unprivileged `hpc-spack` builder; it does not renumber existing users.
Provisioning services receive startup guards for interrupted publication. Core
does not edit the head bootloader or `/etc/nologin`. Existing setup can still
renumber service identities during a forced setup run; that behavior is outside
this change. Component implementations must honor the same head-identity boundary.

## Recovery and verification

Deployments write one JSON receipt per successful phase under
`/var/log/hpc-setup/checkpoints/core/`, for example `warewulf-head.json`,
`warewulf-image_prepare.json`, `slurm-head.json` and `slurm-cpu_image.json`.
Receipts are written atomically **after the phase and its handlers succeed**.
A failed phase gets no receipt and stops subsequent phases. The directory is
root-owned mode 0700 and receipts are mode 0600 when using the normal become-root
playbook. Setup's `setup_complete` and shell component flags remain separate.

From `src/ansible`, resume a failed deployment with the same component selection
and configuration:

```bash
ansible-playbook core/playbooks/site.yml -K -e core_resume=true
```

For an explicitly selected Warewulf/Slurm/Spack/Lmod deployment:

```bash
ansible-playbook core/playbooks/site.yml -K -e core_resume=true \
  -e '{"core_components":["warewulf","slurm","spack","lmod"]}'
```

Resume always runs preflight. It skips only the consecutive matching receipts
at the start of the selected sequence, logging `CHECKPOINT_SKIP::<component>/<phase>`.
It validates receipt schema, ownership, permissions, required facts and a SHA-256
fingerprint of setup, the cluster contract, declared component configuration
overrides and role code. Configuration changes conservatively invalidate all
phases. Component code changes invalidate that component's first phase and all
later phases; core code changes invalidate all. Documentation edits do not.
All receipts outside the retained prefix are removed **before any installer
runs**, including receipts for unselected phases. This prevents a later retry
from trusting old downstream success after an interrupted rebuild.

Only the Slurm RPM release, controller hostname, job identity, Lmod RPM release
and module test contract are restored when needed. No Munge keys or arbitrary
Ansible facts are stored. New cross-phase facts must be added to the explicit
allowlist and tests. Within a failed phase, tasks rerun normally and rely on
their existing idempotency (including Spack's installed-package database).

Older receipts without current-state observations cannot be reused: the first
run with this code must execute phases to establish them. Do not manufacture flags to bypass that
run. To reconcile everything regardless of receipts, omit `core_resume` or use
`-e core_resume=false`. To rerun from one phase with unchanged inputs, remove its
receipt, then resume; later receipts will be invalidated automatically:

```bash
sudo rm /var/log/hpc-setup/checkpoints/core/spack-head.json
ansible-playbook core/playbooks/site.yml -K -e core_resume=true
```

Inspect recorded completion and timestamps:

```bash
sudo ls -l /var/log/hpc-setup/checkpoints/core/
sudo cat /var/log/hpc-setup/checkpoints/core/slurm-head.json
```

Resume now compares selected files, package versions and service probes with
recorded observations before skipping a phase. Missing or changed state invalidates
the suffix. Full publication integrity is checked even when publication was skipped.
These checks cover declared state, not every runtime condition; post-boot acceptance
is still required. Deploy/rollback use an exclusive head-local lock, including when
`core_checkpoint_enabled=false`. Manual installers must respect that lock too.
Disabling checkpoints cannot be combined with resume and leaves old receipts in
place; reconcile with checkpoints enabled before resuming again. Plan, preflight
and verification never write or skip using deployment checkpoints.

Each executed publication creates a private, versioned image/kernel/overlay bundle,
validates it, then switches the served release while provisioning is stopped. The
DHCP configuration is atomically installed as a regular `/etc/dhcp/dhcpd.conf`
file so the unprivileged daemon and SELinux can read it; it is checked against the
selected release during publication verification.
The preceding release is retained until activation checks pass. Commit then
deletes every stale `release-*` directory, leaving one active bundle. When a
valid active release exists, abandoned staging directories are also removed
before allocating the next publication.
After commit, `previous` also points to the active bundle: rollback does not
provide historical releases after a successful deployment. One retained bundle
does not guarantee one archive or fixed disk usage: staging copies the current
provision tree, which can carry older image archives into the retained bundle.
Do not interpret release-directory cleanup as a complete image-cache cleanup.
An unchanged publication phase can be skipped through validated resume receipts.
If activation was interrupted and a preceding release is available, stop any
other deployment and use the locked recovery entry point from `src/ansible`:

```bash
ansible-playbook core/playbooks/rollback.yml -K
```

Rollback stops provisioning, restores the preceding publication, verifies its
integrity and DHCP label, restarts services, and invalidates deployment receipts.
It does not undo installed head packages, working-image edits or changes already
loaded by running compute nodes. A surviving deployment lock must be investigated
before retrying; do not remove it while an installer is still running.

Only Warewulf's final `publish` entry point builds the completed image during
deployment. A prepared image is not a verified cluster. `verify.yml` waits for
CPU SSH/Python availability and invokes each selected component's acceptance
checks. Any failed check fails the run; core never ignores it or writes a
completion flag. No node boot or reboot is triggered by core.

### Recovering images built with malformed template boundaries

Older rendering could join an included file's last line to its shell heredoc
terminator, producing `}HPC_PROFILE`, `fiHPC_LMOD`, or `State=UPHPC_SLURM`.
The remaining setup commands could then be written into the configuration file
instead of executed. Symptoms include profile `unexpected end of file` errors,
Slurm configuration parse errors, and disabled/inactive Munge or Slurmd services.
A receipt from that older run does not prove those services were configured.

The templates now insert explicit newlines before those terminators. Spack/Lmod
profiles are syntax-checked, and the four main image-configuration tasks require
a final `HPC_CHANGED=0` or `HPC_CHANGED=1` output line as well as a zero exit code.
To repair an affected image, run the full selected deployment, including
publication, rather than editing only the running node:

```bash
ansible-playbook core/playbooks/site.yml -K -e core_action=preflight
ansible-playbook core/playbooks/site.yml -K -e core_resume=false
```

After successful publication and a maintenance reboot of the CPUs:

```bash
sudo wwctl ssh cpu01 'systemctl is-active chronyd munge slurmd'
sudo wwctl ssh cpu01 'bash -n /etc/profile.d/hpc-spack.sh && bash -n /etc/profile.d/z10-hpc-lmod.sh'
sinfo
ansible-playbook core/playbooks/verify.yml -K
```

Repeat the service/profile checks for other booted CPUs. Services should be
active and syntax checks should be silent. For `UNKNOWN` nodes, inspect
`journalctl -b -u munge -u slurmd` on the node and resolve startup/registration
errors before attempting scheduler state changes. `State=RESUME` cannot repair
an invalid configuration or start a failed daemon.

Use `core_action=plan` for an offline plan and `core_action=preflight` for
read-only live checks. `--check` is accepted only with those two actions;
deployment and acceptance check-mode runs are rejected because image mutations
and job execution cannot establish success in that mode.
Partial execution via `--tags`, `--skip-tags`, `--start-at-task`, or excluding the
head with `--limit` is unsupported. Do not use them to bypass prerequisites.

## Structure

```text
core/
├── README.md
├── playbooks/
│   ├── site.yml
│   ├── verify.yml
│   └── rollback.yml
├── roles/hpc_core/
│   ├── defaults/main.yml          # Overridable orchestration inputs
│   ├── vars/main.yml              # Ordered deployment/verification phases
│   ├── filter_plugins/cluster.py # Validated shared topology model
│   ├── action_plugins/          # Resolve inputs and fingerprint code on controller
│   ├── library/hpc_core_checkpoint.py # Private, atomic phase receipts
│   ├── library/hpc_core_lock.py       # Exclusive deployment ownership
│   └── tasks/
│       ├── main.yml               # Select, inspect and orchestrate phases
│       ├── preflight.yml          # Read-only setup handoff checks
│       ├── deploy.yml             # Lock, validate security, deploy, verify publication
│       ├── rollback.yml           # Locked served-release recovery
│       ├── checkpoints.yml        # Validate resume prefix; restore allowed facts
│       └── phase.yml              # Invoke role; flush handlers; record success
└── tests/
    ├── run.sh
    ├── test_contract.py
    ├── test_checkpoints.py
    ├── test_hardening.py
    └── test_orchestration.py
```

The old `init`, `network`, `checkpoint`, and `final` roles were removed. Their
bootstrap overlap, checkpoint-on-read behavior and ignored final errors are not
part of the new workflow.

## Tests

Tested with Ansible Core 2.14.18, matching the setup baseline. The core tests
need Python, PyYAML and `ansible-core`; they do not execute component installers
or require sudo, compute nodes, or the collections needed by real components.

```bash
bash core/tests/run.sh
bash components/tests/run.sh
```

Tests check inventory parsing, syntax, input validation, missing-component and
missing-setup failures, phase order, handler flushing, stopping on failure, and
plan/preflight behavior. Successful sequencing uses temporary recording roles
and a simulated setup handoff; it is not a live deployment test. The pure
contract tests can also run without Ansible:

```bash
python3 -m unittest discover -s core/tests -p test_contract.py -v
```

Component tests additionally exercise actual Ansible template lookup for image
heredoc boundaries, extracted shell-profile syntax, incomplete image-script
rejection, and root SSH key preservation/configuration in temporary directories.
They do not publish images, reboot nodes or establish live cluster acceptance.
