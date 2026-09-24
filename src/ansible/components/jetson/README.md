# Jetson node initialization

The GPU entrypoint manages the original cluster's preinstalled Orin Nano over
SSH: Ubuntu 22.04, aarch64, JetPack 6 / L4T 36.x, local SSD, and the inventory's
static private address. It prepares the node and verifies local CUDA execution.
Slurm enrollment and ARM Spack/Lmod environments remain later stages.

## Before the first run

1. Flash and boot JetPack separately. Keep NVIDIA's matching kernel, firmware,
   driver and CUDA stack. See the [NVIDIA Jetson guide](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/).
2. Configure persistent networking on the Jetson, using its console if needed:
   `10.0.2.4/22`, gateway `10.0.0.1`, and working DNS for Ubuntu/NVIDIA package
   repositories. Use the actual inventory/setup values if those were changed.
   The GPU is SSD-booted; it does not use the Warewulf CPU image or DHCP pool.
3. Enable SSH and ensure `/usr/bin/python3` exists. Install the controller user's
   public SSH key for the normal JetPack login and verify its SSH host key.
   Confirm that this login can use sudo and access the GPU without sudo.
4. Set `ansible_user` in `config/group_vars/gpu_nodes.yml` to that login, or set
   it per GPU in `config/hosts.yml`. No username or password is assumed.
5. Complete head setup and Warewulf head services. The head must already route
   cluster traffic and serve synchronized NTP to the private subnet (UDP 123).
   A full CPU core deployment supplies this; GPU initialization does not
   require CPUs to be booted. Its shared handoff validation still checks the
   cluster inventory, including CPU MAC/address validity.

SSH runs from the controller, normally the head. Jetson sudo credentials can
differ from the head's: use per-host `ansible_become_password` through Ansible
Vault or existing passwordless sudo when appropriate. `-K` supplies one sudo
password for the run, not independent passwords for each host. Never commit
plaintext passwords or private keys.

## Entry points

Run from `src/ansible`, as the controller user:

```bash
# Offline: validate workflow selection and display phases; no SSH/sudo needed.
ansible-playbook core/playbooks/gpu.yml -e gpu_action=plan

# Live prerequisites, including a CUDA kernel as the normal SSH user.
ansible-playbook core/playbooks/gpu.yml -e gpu_action=preflight -K

# Initialize and verify the Jetson.
ansible-playbook core/playbooks/gpu.yml -K

# Verify current state without installing or repairing it.
ansible-playbook core/playbooks/gpu-verify.yml -K
```

Omit `-K` with passwordless sudo. The plan permits an unset login so it can be
inspected before configuration. Live actions require an explicit non-root
`ansible_user` and SSH connection. The workflow rejects `--limit`, partial tag
runs, and `--check` for deploy/verify. Do not use `--start-at-task` to bypass
prerequisites. Check mode supports plan/preflight only; their probes really run.

## Process

`gpu.yml` has two plays. First, `hpc_gpu` validates inventory and reuses the
existing `hpc_core/preflight` head handoff, OS, network and identity checks.
It omits CPU image capacity checks and Slurm CPU resource requirements. It
then checks the head time service. Second, it connects to the GPU nodes one
at a time and invokes these Jetson component entry points:

| Entry | Behavior |
| --- | --- |
| `preflight` | Require Ubuntu 22.04/aarch64, Orin Nano hardware, L4T 36.x, root sudo, correct IP/prefix/default gateway, package DNS, free space, collision-free service IDs and a working CUDA kernel as the SSH user. |
| `deploy` | Create missing Slurm/Munge identities from the head contract, install `ca-certificates`, `chrony`, `nfs-common`, set the inventory hostname/local hostname entry, and configure Chrony to use the head. |
| `verify` | Check hostname, packages, service identities, enabled/active Chrony, synchronization to the head, network and CUDA execution. |

Deploy always runs preflight, deploy, handler flushing, then verify. Preflight
does not require the baseline packages or service accounts to exist yet.
Verify runs preflight and acceptance without invoking installation tasks.
The CUDA probe uses the [CUDA Driver API](https://docs.nvidia.com/cuda/cuda-driver-api/group__CUDA__EXEC.html)
through Python's standard library; it loads a tiny PTX kernel, checks a returned
value, and releases its resources. It requires neither NVML nor `nvidia-smi`,
`nvcc`, or third-party Python packages. The probe has a timeout and disables
the CUDA disk cache; preflight/verify do not write managed configuration.

This initialization does not flash, reboot, upgrade the OS/JetPack, replace
network profiles, mount the x86 software tree, copy Munge keys, or change the
Slurm controller. It installs only the baseline package list; installing Chrony
may replace Ubuntu's default `systemd-timesyncd`. GPU service identities are
prepared for later enrollment, but no Munge/Slurm daemon is installed here.

## Reruns and failures

There are no completion flags or resume shortcuts. Rerun the same command after
fixing a failure; each task reconciles current state and acceptance runs again.
A failure stops the workflow and never reports initialization success. Changes
already applied on the Jetson remain; there is no automatic rollback.
CPU publication is a separate entrypoint and is never invoked here.

Existing matching service accounts are preserved. Name/UID/GID collisions cause
an error before package installation; resolve them deliberately rather than
renumbering accounts or recursively changing file ownership. For a CUDA probe
failure, check the flashed NVIDIA stack and SSH user's device permissions. For
time failures, check the head's synchronization, Chrony allow rule, and UDP 123.

Defaults (`jetson_min_free_bytes`, `jetson_dns_probe`, `jetson_cuda_timeout`) live
with this role. Override them in `config/group_vars/gpu_nodes.yml` if needed.
Live deployment and CUDA device isolation still need physical Jetson testing;
local tests cover guard behavior, failure propagation and orchestration only.
