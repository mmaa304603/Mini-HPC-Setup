# Cluster configuration

One physical cluster uses two deployment files:

```text
config/
├── hosts.yml             # Node inventory and per-node hardware settings
└── group_vars/all.yml    # Shared deployment overrides
```

`hosts.yml` contains the README's one local head, three diskless CPU nodes and
one preinstalled GPU node. Verify the CPU PXE NIC MACs, usable Slurm memory,
CPU topology and SSH connection settings before deployment. CPU memory is
7000 MB per node, matching `SLURM_DEFAULT_MEM` in the shell Slurm configuration;
override it per host if hardware differs.
The GPU address is reserved but the initial core workflow configures CPUs only.

`group_vars/all.yml` selects Warewulf, Slurm, Spack and Lmod, the DHCP range and
CPU image, and software overrides. Ansible automatically loads this file next
to the inventory. Component defaults stay with their roles; add overrides only
when needed. There are no dev/test/prod copies for this single cluster.

Head interface/address and service IDs come from the effective configuration
written by the existing setup workflow at `/etc/hpc-setup/setup.yml`. Do not
duplicate those values here. Changing setup inputs still follows setup's own
documented workflow.

From `src/ansible`, inspect the cluster plan:

```bash
ansible-playbook core/playbooks/site.yml -e core_action=plan
```

The root Ansible configuration selects this inventory. Keep setup using its
own `setup/ansible.cfg`. Tests use temporary inventories and recording roles,
not this cluster's live machines. These YAML files configure the Ansible core;
the shell implementation continues to use its existing configuration files.

Warewulf, Slurm, Spack and Lmod entry points are implemented. Supply the controller
public SSH keys in warewulf_authorized_keys, verify usable Slurm memory, and
review compute DNS before installation. The default selection deploys all four.
Spack's package list drives software builds; Lmod exposes the generated modules.
See the
[core README](../src/ansible/core/README.md) for commands, current limitations,
and the required component entry points. Do not store Munge keys or passwords
in these files.
