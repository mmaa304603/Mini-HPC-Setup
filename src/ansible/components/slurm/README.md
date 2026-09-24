# Slurm component

The head entry point installs Munge and slurmctld. The cpu_image entry point
installs Munge and slurmd inside the prepared Warewulf image; it never starts
worker services on the head.

Run these entry points through [core](../../core/README.md); standalone role
execution is rejected. The default full sequence prepares Warewulf, configures
Slurm, then Spack and Lmod, and finally publishes the complete CPU image.

## Deploy Warewulf and Slurm

The inventory sets `slurm_real_memory_mb: 7000`, matching `SLURM_DEFAULT_MEM`
in `src/shell/components/slurm/slurm.conf`. Its CPU topology also matches the
shell configuration: 1 socket, 4 cores per socket, 1 thread per core. These are
configured values, not hardware measurements. Verify them against each worker;
use per-host overrides in `config/hosts.yml` if machines differ. `slurmd -C`
on a worker with Slurm installed reports its detected resources.

From `src/ansible`, after completing setup and supplying the Warewulf SSH keys:

```bash
ansible-playbook core/playbooks/site.yml -K -e core_action=preflight \
  -e '{"core_components":["warewulf","slurm"],"core_stage":"full"}'

ansible-playbook core/playbooks/site.yml -K \
  -e '{"core_components":["warewulf","slurm"],"core_stage":"full"}'
```

This reconciles Warewulf head/image preparation, configures the Slurm head and
CPU image, then publishes the image and overlays. It does not install Spack or
Lmod or remove their existing installations. Existing compute nodes need to boot
the newly published image; deployment
does not reboot them or update their running services automatically.

After booting the CPU nodes:

```bash
ansible-playbook core/playbooks/verify.yml -K \
  -e '{"core_components":["warewulf","slurm"],"core_stage":"full"}'
```

## Time and authentication startup

The head preserves its existing Chrony upstream sources and allows NTP clients
from the cluster subnet. Warewulf opens NTP in the private firewall zone.
Slurm's head phase enables Chrony and checks synchronization before starting
Munge; it retries for about two minutes, requiring less than one second of
remaining clock correction. It does not force a head clock step or configure
an unsynchronized local-clock fallback. The head needs a reachable upstream
source. On failure, inspect `chronyc tracking` and `chronyc -n sources` and
correct upstream reachability/configuration before rerunning.

Workers receive `server <head-private-IP> iburst`, `makestep 1.0 3`, and
`rtcsync` in their image's `/etc/chrony.conf`. Chrony, Munge, and slurmd are enabled
in the image and start when workers boot. Munge is ordered after Chrony;
slurmctld/slurmd require Munge and start after it. This boot ordering alone does
not prove synchronization, so acceptance explicitly checks the clock and the
worker's selected NTP source. It does not block head boot waiting for NTP.

Head deployment starts Munge, applies pending key/service changes and requires
a successful local encode/decode test before starting slurmctld. The existing
key is retained; a newly generated key also triggers Munge restart. Acceptance
tests authentication in both head-to-worker and worker-to-head directions.

## Package and identity handling

An optional slurm_version selects an EPEL package version. Without it, the head
uses its installed/available version. The CPU image must install the exact
version-release reported by the head RPM; unavailable matching worker packages
cause a failure instead of allowing a controller/worker version mismatch.

Head Slurm/Munge accounts must already match completed setup. They are never
renumbered. An existing nonempty regular Munge key is preserved and protected;
a key is generated only when absent. Its image transfer uses protected task
stdin with no_log and never stores key data in repository configuration.

slurm_verify_user defaults to the administrator saved by setup. It must be an
existing non-system, non-root head account. Only that user's numeric identity
is added to the CPU image for the acceptance job. Collisions in the image stop
installation. Its image home is local, not an export of the head home directory.
This does not implement general cluster user provisioning.

Warewulf's head-root SSH key separately enables `sudo wwctl ssh` for head users
who already have sudo permission. The Slurm test identity does not grant sudo
or provide that SSH access.

## Configuration and acceptance

Slurm uses the actual head hostname with an explicit controller address, and
CPU names/resources from core_cluster. GPU nodes are excluded. The CPU image
gets cgroup settings, time-service ordering and a private-source worker firewall
rule if firewalld is installed in the image.

Verification checks clock synchronization, selection of the head as each
worker's NTP source, service health, matching package versions, cross-node
Munge authentication, worker registration, and one bounded hostname job per
CPU node as slurm_verify_user. The job uses /tmp as its working directory and
creates no submission/output files. Queue waiting and execution have time limits;
failures propagate to core.

## Troubleshooting worker registration

From the head, inspect a booted worker before changing its scheduler state:

```bash
sudo wwctl ssh cpu01 'systemctl is-active chronyd munge slurmd'
sudo wwctl ssh cpu01 'journalctl -b -u munge -u slurmd -n 80 --no-pager'
sudo wwctl ssh cpu01 'chronyc tracking; chronyc -n sources; slurmd -C'
scontrol show node cpu01
sinfo
```

An `UNKNOWN` node has not successfully registered. Correct service, configuration,
clock, network or Munge errors first; `State=RESUME` cannot substitute for a
working slurmd. Compare `slurmd -C` output with the inventory resources.

Older rendered images could append `HPC_SLURM` and shell commands to slurm.conf
because an embedded template lacked a newline. The image template now inserts
explicit boundaries, and the task requires its final completion marker. Follow
[image recovery](../../core/README.md#recovering-images-built-with-malformed-template-boundaries)
to redeploy and reboot; editing a running stateless node is not a persistent fix.

See [local tests](../tests/README.md) and
[Slurm configuration reference](https://slurm.schedmd.com/slurm.conf.html).
Time checks use [Chrony's waitsync command](https://chrony-project.org/doc/3.1/chronyc.html),
which tests synchronization and remaining clock correction.
