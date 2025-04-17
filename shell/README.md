# Shell Script Installation

This directory contains shell scripts for installing and configuring the HPC cluster components.

## Installation Order

For a cluster with Radax X2L nodes where only the head node has SSD storage and worker nodes rely on PXE boot, the installation must follow this specific order:

1. **Head Node Setup**: Install Rocky Linux 9.5 on the head node
2. **Network Configuration**: Configure the network interface for PXE boot
3. **Warewulf Installation**: Install and configure Warewulf 4.6 on the head node
4. **Container Creation**: Create the container for compute nodes
5. **Compute Node Provisioning**: Configure PXE boot for compute nodes
6. **Compute Node Boot**: Boot the compute nodes using PXE
7. **SLURM Installation**: Install SLURM on the head node and configure it to manage compute nodes
8. **Additional Software**: Install Spack, Environment Modules, monitoring tools, etc.

## Installation Steps

```bash
# 1. Install Rocky Linux 9.5 on the head node (manual step)
# 2. Clone this repository on the head node
git clone https://github.com/yourusername/HPC-Setup.git
cd HPC-Setup/shell

# 3. Configure the head node's network interface
# This step sets up the head node's network interface (enp2s0) with:
# - Static IP (10.0.0.1)
# - Network mask (/22)
# - Disable NetworkManager for the provisioning interface
./setup.sh --step network

# 4. Install and configure Warewulf
# This step will:
# - Install Warewulf 4.6
# - Configure DHCP server for PXE boot (10.0.1.x range)
# - Set up TFTP and HTTP services
# - Configure container image
./setup.sh --step warewulf

# 5. Boot the compute nodes (manual step - power on the nodes)
# 6. Install SLURM
./setup.sh --step slurm

# 7. Install additional software
./setup.sh --step spack
./setup.sh --step modules
./setup.sh --step monitoring
./setup.sh --step squid
./setup.sh --step apptainer
```

## Directory Structure

```
shell/
├── apptainer/            # Apptainer setup
├── common/               # Common functions and utilities
├── config/               # Configuration files
├── elk/                  # ELK stack setup
├── filebeat/             # Filebeat setup
├── grafana/              # Grafana setup
├── modules/              # Environment modules setup
├── monitoring/           # Monitoring setup
├── slurm/                # SLURM setup
├── spack/                # Spack setup
├── squid/                # Squid proxy setup
├── utils/                # Utility scripts
├── warewulf/             # Warewulf setup
└── setup.sh              # Main setup script
```

## Configuration Files

Configuration files are located in the `config` directory. Edit these files to customize the installation:

- `network.conf`: Network configuration
- `warewulf.conf`: Warewulf configuration
- `slurm.conf`: SLURM configuration
- `spack.conf`: Spack configuration
- `monitoring.conf`: Monitoring configuration
- `squid.conf`: Squid proxy configuration
- `apptainer.conf`: Apptainer configuration

## Network Configuration

The internal network uses 10.0.0.0/22 with the following settings:

### Head Node
- IP: 10.0.0.1
- Provisioning interface: enp2s0
- DHCP server for initial PXE boot
- TFTP server for boot files
- HTTP server for container image

### Compute Nodes
The compute nodes go through a two-phase IP assignment process:

1. **Initial PXE Boot Phase (10.0.1.x)**
   - DHCP range: 10.0.1.1 - 10.0.1.255
   - Temporary IP assignment for PXE boot
   - Used only during initial boot and provisioning
   - Managed by DHCP server on head node

2. **Final Provisioned Phase (10.0.2.x)**
   - Permanent IP range: 10.0.2.1 - 10.0.2.255
   - Assigned by Warewulf during provisioning
   - Used for normal operation
   - Configured in Warewulf container

### Network Flow
1. Compute node powers on and requests DHCP address
2. Head node's DHCP server assigns temporary IP (10.0.1.x)
3. Node downloads PXE boot files via TFTP
4. Warewulf provisions the node with container image
5. Warewulf assigns permanent IP (10.0.2.x)
6. Node reboots with new permanent IP

## Prerequisites

1. Rocky Linux 8 installed on the head node
2. Root or sudo access on all nodes
3. Network connectivity between nodes
4. SSH access configured between nodes

## Usage

1. Update the configuration in `common/config.sh` with your node information
2. Run the main setup script:
   ```bash
   sudo ./setup.sh
   ```

## Manual Step-by-Step Setup

If you prefer to run steps manually:

1. Configure the network:
   ```bash
   sudo ./utils/network.sh
   ```

2. Install and configure Warewulf:
   ```bash
   sudo ./warewulf/install.sh
   sudo ./warewulf/configure.sh
   ```

3. Install and configure SLURM:
   ```bash
   sudo ./slurm/install.sh
   sudo ./slurm/configure.sh
   ```

4. Install and configure Spack:
   ```bash
   sudo ./spack/install.sh
   ```

5. Install and configure Environment Modules:
   ```bash
   sudo ./modules/install.sh
   ```

## Post-Installation Verification

After setup completes:

1. Verify Warewulf:
   ```bash
   systemctl status warewulfd
   wwctl node list
   ```

2. Verify SLURM:
   ```bash
   sinfo
   squeue
   srun --partition=compute hostname
   ```

3. Verify Spack:
   ```bash
   source /etc/profile.d/spack.sh
   spack --version
   spack find
   ```

4. Verify Environment Modules:
   ```bash
   source /etc/profile.d/modules.sh
   module avail
   module load spack
   module list
   ```

## Using Spack and Environment Modules

### Spack

Spack is a flexible package manager designed specifically for HPC environments. It allows you to install and manage software packages with different versions, compilers, and options.

#### Basic Spack Commands

```bash
# Load Spack environment
source /etc/profile.d/spack.sh

# List available packages
spack list

# Search for packages
spack search <package>

# Install a package
spack install <package>

# List installed packages
spack find

# Load a package
spack load <package>

# Unload a package
spack unload <package>
```

### Environment Modules

Environment Modules provide a convenient way to dynamically modify a user's environment via modulefiles. This allows users to easily switch between different software versions and configurations.

#### Basic Module Commands

```bash
# Load Modules environment
source /etc/profile.d/modules.sh

# List available modules
module avail

# Load a module
module load <module>

# List loaded modules
module list

# Unload a module
module unload <module>

# Switch between module versions
module switch <module1> <module2>

# Display module information
module show <module>
```

#### Using Spack with Modules

Spack can generate modulefiles for installed packages, which can then be loaded using the Environment Modules system:

```bash
# Load Spack module
module load spack

# Load a package installed by Spack
module load openmpi
module load python
module load numpy
```

## Customizing the Setup

### Adding New Packages to Spack

To add new packages to the Spack installation, edit the `SPACK_PACKAGES` array in `common/config.sh`:

```bash
SPACK_PACKAGES=(
    "openmpi@4.1.5"
    "hdf5@1.12.2"
    "netcdf@4.9.2"
    "python@3.10.13"
    "numpy@1.24.3"
    "scipy@1.10.1"
    "matplotlib@3.7.1"
    "your-package@version"  # Add your package here
)
```

### Customizing Module Files

To customize the module files, edit the `configure_modules` function in `modules/install.sh`. You can add new modulefiles or modify existing ones to suit your needs. 

[monitoring]
monitor01 ansible_host=192.168.1.20 