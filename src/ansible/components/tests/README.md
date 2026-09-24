# Component tests

Local regression checks for the Warewulf, Slurm, Spack and Lmod roles.
The runner syntax-checks their real entry points through static role imports,
then runs Python unittest discovery. Core's dynamic includes alone do not
syntax-check every component task.

## Requirements and commands

Use the project's Ansible environment with Python 3, ansible-core, PyYAML and
Jinja2 available. The tests also use Bash, OpenSSH (`ssh` and `ssh-keygen`),
standard Linux utilities and POSIX pseudo-terminals. Install the pinned
collections from `src/ansible/requirements.yml` if they are not already present.

From `src/ansible`:

```bash
ansible-galaxy collection install -r requirements.yml
bash components/tests/run.sh
```

The runner also works from the repository root:

```bash
bash src/ansible/components/tests/run.sh
```

Do not use sudo. The runner creates temporary Ansible configuration directories,
disables become-password prompting, and cleans up its temporary directory on
exit. Tests use temporary files and command stubs; they do not deploy the cluster,
install packages, change system accounts or start provisioning services.

To run only the embedded-template regression from `src/ansible`:

```bash
python3 -m unittest discover -s components/tests -p test_image_rendering.py -v
```

This focused command does not include the runner's static role syntax check.

## Coverage

| File | Main checks |
| --- | --- |
| `test_components.py` | Rendered configuration, root/controller public keys, image execution guard, identity collisions, repeatable file updates, publication fingerprints and entry points. |
| `test_slurm.py` | Unsynchronized clocks, wrong selected NTP source and Munge decoding failures stop acceptance; credential output remains hidden. These use command stubs. |
| `test_software.py` | Missing/existing fstab handling, corrupt lockfiles, noninteractive Spack installation under a pseudo-terminal, lazy Spack initialization, Lmod paths and rejection of the wrong executable. |
| `test_hardening.py` | Ownership migration with symlinks and internal/external hardlinks, pinned inputs, and optional real Warewulf overlay rendering. Ownership changes are mocked. |
| `test_root_ssh.py` | Real temporary SSH key generation, preservation of existing keys, public-key repair, effective SSH configuration, invalid-key refusal and node-task syntax. Role paths and ownership settings are adapted for temporary unprivileged execution. |
| `test_image_rendering.py` | Real Ansible template lookup preserves standalone heredoc boundaries; generated files exclude script remainder; profiles parse; image-task completion-marker checks reject incomplete runs. |

The image-rendering regression checks shell-parser warnings as well as exit
status: an unterminated heredoc can otherwise pass `bash -n` with a warning.

## Optional Warewulf rendering check

`WarewulfStagingTests` is skipped unless `HPC_WAREWULF_SOURCE` is set and `wwctl`
is on PATH. To enable it, supply the pinned Warewulf 4.6.4 source tree containing
its `overlays` directory. Matching `wwctl` and the `dhcpd` validator must already
be installed and on PATH; the skip condition does not check for `dhcpd`.

From `src/ansible`, replace the example path with that source checkout:

```bash
HPC_WAREWULF_SOURCE=/path/to/warewulf-4.6.4 bash components/tests/run.sh
```

The check uses a temporary `WAREWULFCONF`, node database and overlay output.
It checks the PXE DHCP pool, MAC-matched static configuration, DHCP syntax and
repeatable policy edits. It does not publish an image or start DHCP. A skipped
test means that this real-Warewulf coverage was not exercised.

## Limits and live verification

These checks do not prove package availability, sufficient build space, working
SELinux/firewall rules, PXE boot, live NFS access or successful Slurm registration.
They do not perform a full image build or test GPU provisioning.

Run the separate orchestration/checkpoint suite with `bash core/tests/run.sh`
from `src/ansible`. See [core tests](../../core/README.md#tests).

After a deliberate deployment and CPU reboot into the published image, run
live acceptance separately:

```bash
ansible-playbook core/playbooks/verify.yml -K
```

Use the same component selection as the deployment. Live acceptance contacts
the head and workers and runs bounded software/Slurm jobs; it is not part of
the local regression runner. See the [component overview](../README.md) and
[core recovery and verification](../../core/README.md#recovery-and-verification).
