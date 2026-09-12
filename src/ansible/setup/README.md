# Setup and Installation Prototype

This directory is the single pre-core bootstrap for the HPC head node. It
validates the host, establishes required baseline state, verifies that state,
and writes one completion flag. Warewulf, Slurm, Spack, Apptainer, and other
cluster components remain under `../core/` and `../components/`.

This prototype does not modify or replace `src/ansible/setup/`.

## Requirements

The current inventory runs Ansible locally on the head node, so the controller
and managed host are the same machine. Requirements fall into three groups.

### Required before the playbook starts

- Rocky Linux 9 on the head node.
- Python 3 and `ansible-core`. This prototype is tested with Ansible Core
  2.14.18.
- Root access or working sudo access. The setup-local Ansible configuration
  prompts for the sudo password automatically.
- The pinned collections in `requirements.yml`:
  - `ansible.posix` 1.5.4 for SELinux management;
  - `community.general` 8.6.0 for NetworkManager management.
- DNS and Internet access while installing those collections from Ansible
  Galaxy.
- A configured package repository path from which DNF can install the
  bootstrap packages.
- The selected cluster interface must already exist and must not carry the
  host's default route during a real run.
- At least 4 GiB free on `/`, 1 GiB memory, and one CPU.
- The bootstrap commands `dnf`, `systemctl`, `ip`, `df`, `free`, `nproc`, and
  Bash.

From `src/bansible`, install Ansible and its collections before the first run:

```bash
sudo dnf install -y ansible-core
ansible-galaxy collection install -r requirements.yml
```

Run `ansible-galaxy` as the same account that will run `ansible-playbook`.
Installing collections with `sudo` normally puts them under root's collection
path, where a playbook launched by a regular user may not find them.

### Installed by setup

These are not manual prerequisites. Setup installs them before the roles that
need them:

- `epel-release`, when `setup_enable_epel` is enabled;
- wget, git, vim-enhanced, tmux, htop, and nfs-utils;
- NetworkManager, which supplies `nmcli` for the network role;
- chrony;
- firewalld and audit;
- policycoreutils and python3-libselinux for SELinux management.

Setup then activates the requested NetworkManager connection and enables or
starts chronyd, firewalld, and auditd as required by their respective roles.

### Existing-state constraints

- A valid `setup_complete` flag causes an immediate skip. Use
  `setup_force=true` after changing setup inputs.
- UID 960/GID 968 must be available for Slurm, and UID 959/GID 967 must be
  available for Munge. Existing `slurm` and `munge` accounts are reconciled to
  those values; setup stops if an unrelated identity owns a target ID.
- Real network activation can affect host connectivity even after check mode
  succeeds. Review every network value before forcing setup.

## One-path workflow

There is one entry point: `playbooks/init.yml`. It does not support partial
setup through tags or separate package, configuration, security, and
verification playbooks.

On every invocation it first checks:

```text
/var/log/hpc-setup/checkpoints/setup_complete
```

If the flag exists, setup reports that the host is complete and stops without
gathering facts or running roles. To deliberately reconcile the entire setup,
set `setup_force=true`. A forced real run removes the old flag first, and a
new flag is written only after every stage and final verification succeeds.

The full path is:

1. validate Rocky Linux 9, root access, resources, commands, and the cluster
   interface;
2. create setup directories;
3. install baseline packages;
4. create stable Slurm/Munge identities and add the invoking user to
   `hpc-admin`;
5. establish the firewalld, SELinux, and audit baseline without changing SSH;
6. configure and activate the cluster NetworkManager connection;
7. enable chronyd and write the versioned effective configuration;
8. verify all managed state;
9. write `setup_complete`.

## Important network safety

Network configuration is always part of a real setup run. Interface, address,
prefix, gateway, DNS, and NetworkManager profile values are deployment inputs
defined in `vars/system.yml`. Review them for each head node before running
setup.

A real run refuses to configure an interface that carries the default route.
This protects the management or Internet-facing interface from being
repurposed and disconnecting the host. The declarative NetworkManager tasks
support check mode, although a preview cannot prove post-activation
connectivity.

After changing any network input, run setup once with `setup_force=true`;
otherwise an existing completion flag will correctly skip all setup work and
the new configuration will not be applied.

## Administrator and service identities

The invoking local account is derived from `SUDO_USER`, then `USER`, and is
added to `hpc-admin`. For the normal invocation by Jay, this selects `jay`.
Override it explicitly if automatic detection is wrong:

```bash
-e setup_admin_user=jay
```

Membership in `hpc-admin` does not itself grant sudo access. It establishes a
cluster-administration identity that later core/component roles can use for
group-owned files and commands.

Numeric IDs are fixed so service-owned files have the same meaning on the head
node and future compute images:

```text
slurm: UID 960, GID 968
munge: UID 959, GID 967
```

Setup reconciles correctly named accounts created with dynamic IDs, which
supports hosts used by earlier prototypes. It refuses to reuse a target ID
that belongs to a different user or group.

## Commands

Run structural checks from `src/bansible`:

```bash
bash setup/tests/run.sh
```

Run the playbook from the setup directory so Ansible automatically loads
`setup/ansible.cfg` and the setup inventory:

```bash
cd setup
```

Preview the full workflow:

```bash
ansible-playbook playbooks/init.yml \
  --check -e setup_force=true
```

Run or resume setup:

```bash
ansible-playbook playbooks/init.yml
```

Force a complete reconciliation:

```bash
ansible-playbook playbooks/init.yml \
  -e setup_force=true
```

Do not run `sudo ansible-playbook`. Keep the controller process under the
account that installed the Ansible collections; the play's `become` setting
gives system-changing tasks root privileges. `setup/ansible.cfg` prompts for
the sudo password before execution. On a host with passwordless sudo, suppress
that prompt for an invocation with `ANSIBLE_BECOME_ASK_PASS=False`.

If you must invoke the playbook from `src/bansible`, select the setup config
explicitly:

```bash
ANSIBLE_CONFIG="$PWD/setup/ansible.cfg" \
  ansible-playbook setup/playbooks/init.yml
```

A bare `ansible-playbook setup/playbooks/init.yml` command from `src/bansible`
loads `src/bansible/ansible.cfg` instead. That config deliberately selects the
core test inventory, where privilege escalation is disabled, so setup
validation will reject the run.

## Structure

```text
setup/
├── ansible.cfg
├── inventory/
│   ├── hosts
│   └── test
├── playbooks/
│   └── init.yml
├── roles/
│   ├── validation/
│   ├── bootstrap/
│   ├── security/
│   ├── network/
│   ├── config/
│   └── verify/
├── tests/
│   └── run.sh
└── vars/
    ├── main.yml
    ├── system.yml
    ├── packages.yml
    └── security.yml
```
