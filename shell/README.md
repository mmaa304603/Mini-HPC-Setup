# HPC Cluster Shell Scripts

This directory contains shell scripts for manually setting up an HPC cluster using Rocky Linux, Warewulf, SLURM, Spack, and Environment Modules.

## Directory Structure

```
shell/
├── common/           # Common functions and utilities
│   ├── functions.sh  # Shared shell functions
│   └── config.sh     # Configuration variables
├── warewulf/         # Warewulf installation and configuration
│   ├── install.sh    # Install Warewulf and dependencies
│   └── configure.sh  # Configure Warewulf settings
├── slurm/            # SLURM installation and configuration
│   ├── install.sh    # Install SLURM and dependencies
│   └── configure.sh  # Configure SLURM settings
├── spack/            # Spack installation and configuration
│   └── install.sh    # Install Spack and packages
├── modules/          # Environment Modules installation and configuration
│   └── install.sh    # Install Environment Modules
├── utils/            # Utility scripts
│   ├── network.sh    # Network configuration utilities
│   └── system.sh     # System configuration utilities
└── setup.sh          # Main setup script
```

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