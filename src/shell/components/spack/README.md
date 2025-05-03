# Spack Package Manager Scripts

This directory contains scripts for managing the Spack package manager installation and configuration.

## Directory Structure

```
spack/
├── install/          # Installation scripts
│   ├── install.sh           # Basic Spack installation
│   └── install_system_spack.sh  # Full system installation
├── config/          # Configuration scripts
│   └── setup_system_spack_config.sh  # System configuration
└── README.md        # This file
```

## Scripts

### Installation Scripts

1. `install/install.sh`
   - Basic Spack installation
   - Minimal dependencies
   - Core functionality
   - Quick setup

2. `install/install_system_spack.sh`
   - Full system installation
   - All dependencies
   - Complete functionality
   - Production setup

### Configuration Scripts

1. `config/setup_system_spack_config.sh`
   - System-wide configuration
   - Environment setup
   - Package repositories
   - Compiler configuration

## Usage

### Basic Installation
```bash
# Install basic Spack
./install/install.sh
```

### Full System Installation
```bash
# Install complete Spack system
./install/install_system_spack.sh
```

### Configuration
```bash
# Configure Spack system
./config/setup_system_spack_config.sh
```

## Notes

- Basic installation is suitable for development/testing
- Full system installation is recommended for production
- Configuration should be done after installation
- Review configuration before applying to production

## Support

For Spack-related issues:
- Email: hpc-support@ttu.edu
- Documentation: [docs/](docs/)
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues)

## Spack Installation Scripts

### `install_system_spack.sh`

This script installs Spack at the system level, making it available to all users on the system.

**Features:**
- Installs Spack in `/opt/spack`
- Sets up proper permissions for system-wide access
- Creates initial configuration in `/etc/spack`
- Handles existing installations with backup options

**Usage:**
```bash
sudo ./scripts/install_system_spack.sh
```

**Configuration:**
Edit the following variables at the top of the script to customize the installation:
```bash
SPACK_VERSION="v0.23.1"
SPACK_INSTALL_DIR="/opt/spack"
SPACK_CONFIG_DIR="/etc/spack"
SPACK_REPO="https://github.com/spack/spack.git"
```

### `setup_system_spack_config.sh`

This script configures system-wide Spack settings after installation.

**Features:**
- Copies configuration files from the repository to `/etc/spack`
- Sets up system-wide environment file in `/etc/profile.d/spack.sh`
- Configures proper permissions for all files

**Usage:**
```bash
sudo ./scripts/setup_system_spack_config.sh
```

**Configuration:**
Edit the following variables at the top of the script to customize the configuration:
```bash
SPACK_INSTALL_DIR="/opt/spack"
SPACK_CONFIG_DIR="/etc/spack"
```

## System-Level Spack Configuration

The system-level Spack installation creates the following configuration files in `/etc/spack/`:

- `config.yaml`: General Spack configuration
- `compilers.yaml`: System compiler definitions
- `packages.yaml`: Package preferences and external packages
- `modules.yaml`: Module file generation settings
- `spack.yaml`: Environment-specific settings

## User Access

After installation, users need to either:
1. Log out and log back in
2. Run `source /etc/profile.d/spack.sh`

This will make Spack available in their environment.

## Customizing Spack

To customize the Spack installation:

1. Edit the variables at the top of the installation scripts
2. Modify the configuration files in `.spack/` directory before running the setup script
3. Add additional packages or compilers after installation

Common customizations include:
- Adding more packages to install
- Configuring additional compilers
- Setting up external packages
- Adjusting build parameters

## Troubleshooting

If you encounter issues during installation:

1. Check the script output for error messages
2. Verify that you have sudo privileges
3. Ensure all prerequisites are installed
4. Check the Spack logs in `/opt/spack/var/log/spack/` 