# Base System Setup

Base prerequisites for head node (Rocky Linux) and GPU nodes (Jetson Ubuntu-based).

## Scripts

- **`head-install.sh`** - Rocky Linux head node setup
- **`gpu-install.sh`** - Jetson GPU node setup  
- **`lib.sh`** - Common functions shared by both scripts

## What each script does

### head-install.sh (Rocky Linux head node)
- **Base setup**: Updates system, enables EPEL, installs core utilities
- **Head node packages**: chrony, openssh-server, nfs-utils, tftp-server, dhcp-server, httpd, cockpit, pdsh
- **Services**: Enables chronyd, sshd, httpd, cockpit.socket
- **PDSH configuration**: Sets up cluster management tools with system-wide and per-user options

### gpu-install.sh (Jetson GPU node)
- **Base setup**: Updates system, installs core utilities and networking tools
- **GPU node packages**: openssh-server, nfs-common, chrony, htop, iotop, nvidia-utils (if available)
- **Services**: Enables ssh, chrony
- **GPU configuration**: Adds user to docker group, configures for compute environment

### lib.sh (Common functions)
- **Package management**: Centralized package lists (`get_common_packages()`, `get_head_packages()`, `get_gpu_packages()`)
- **Service management**: Unified service enablement with error handling
- **User management**: Group membership functions
- **Role-specific setup**: `setup_head_node()` and `setup_gpu_node()` functions
- **PDSH configuration**: Complete cluster management setup

## Usage

```bash
# From repo root
cd src/shell

# Setup Rocky Linux head node
./components/base/head-install.sh

# Setup Jetson GPU node
./components/base/gpu-install.sh
```

## Why this structure works
- **Role-specific**: Head node needs server services, GPU nodes need compute tools
- **OS-specific**: Rocky uses dnf/firewalld, Jetson uses apt/ufw
- **DRY principle**: Common functionality moved to lib.sh eliminates duplication
- **Maintainable**: Easy to modify head vs GPU node requirements independently
- **Modular**: Each script focuses on its specific role while sharing common functions

## Notes
- Both scripts require root privileges
- Reboot recommended if kernel was updated
- Head node enables firewalld, GPU nodes install but don't enable ufw
- GPU nodes may have NVIDIA-specific packages if available
