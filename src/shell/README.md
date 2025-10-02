# Shell Implementation

Bash-based scripts and tooling for provisioning, configuring, and managing the Mini-HPC cluster setup.

## Architecture Overview

This shell implementation provides a modular, maintainable approach to HPC cluster management with clear separation of concerns:

- **📁 bin/** - User-facing entry points and automation scripts
- **📁 lib/** - Shared utilities and functions (DRY principle)
- **📁 config/** - Centralized configuration management
- **📁 components/** - Individual service installers/configurators
- **📁 maintenance/** - Operational scripts for ongoing cluster management
- **📁 templates/** - Static configuration templates

## Overall flow
Prerequsites:
1. Install Rocky Linux 9.6 on head node
2. Jetson Orin Nano is flashed, this can be easily done with an ubuntu host (https://www.jetson-ai-lab.com/initial_setup_jon_sdkm.html)

Cluster setup:
1. Set up netwrok configuration
2. Install and configure warewulf
3. Install and configure slurm
4. Use spack for package management
5. Lmod to load packages for users
6. Logging management: ELK
7. System monitoring: MonsTER + Grafana

## Directory Structure

```
src/shell/
├── bin/                    # 🚀 Entry Points & Automation
│   ├── hpc-setup          # Main cluster setup orchestrator
│   ├── hpc-manage         # Main cluster management CLI
│   ├── hpc-monitor        # Monitoring and health checks
│   ├── hpc-backup         # Backup management
│   ├── hpc-security       # Security hardening
│   ├── hpc-test           # Testing and validation
│   ├── build.sh           # Build distribution packages
│   ├── deploy.sh          # Deploy built packages
│   ├── cleanup.sh         # Clean build artifacts
│   └── setup-dev-env.sh   # Development environment setup
│
├── lib/                   # 🔧 Shared Libraries (DRY)
│   ├── functions.sh       # Core utilities (logging, validation, system ops)
│   ├── config.sh          # Configuration loading/export helpers
│   └── install.sh         # Environment Modules installer
│
├── config/                # ⚙️ Configuration Management
│   ├── network.conf       # Network topology and IP assignments
│   ├── slurm.conf         # SLURM cluster configuration
│   ├── spack.conf         # Spack package manager settings
│   ├── monitoring.conf    # ELK/Grafana/Prometheus stack config
│   ├── squid.conf         # Squid proxy configuration
│   └── apptainer.conf     # Apptainer container settings
│
├── components/            # 🏗️ Service Installers
│   ├── base/              # Base OS prerequisites (Rocky & Jetson)
│   ├── warewulf/          # Bare-metal provisioning system
│   ├── slurm/             # Workload manager and scheduler
│   ├── spack/             # Package manager for HPC software
│   ├── elk/               # Elasticsearch, Logstash, Kibana
│   ├── grafana/           # Metrics visualization
│   ├── globus/            # Data transfer and sharing
│   ├── eraider/           # Authentication and identity
│   ├── squid/             # HTTP proxy and caching
│   └── apptainer/         # Container runtime
│
├── maintenance/           # 🔄 Operational Scripts
│   ├── setup.sh           # Monitoring stack installation
│   ├── backup.sh          # Data backup operations
│   ├── backup_config.sh   # Configuration backup
│   ├── verify_backup.sh   # Backup integrity verification
│   ├── maintenance_daily.sh # Daily health checks and cleanup
│   └── security_scan.sh   # Security auditing and hardening
│
└── templates/             # 📄 Configuration Templates
    └── [static templates used by component scripts]
```

## Quickstart

### 🚀 Getting Started
```bash
# Navigate to shell implementation
cd src/shell

# Check available management commands
./bin/hpc-setup --help
./bin/hpc-manage --help
./bin/hpc-monitor --help
./bin/hpc-security --help

# Install a specific component (e.g., Warewulf provisioning)
./components/warewulf/install.sh

# Run daily maintenance tasks
./maintenance/maintenance_daily.sh
```

### 🏗️ Typical Workflow
```bash
# 1. Configure your cluster settings
vim config/network.conf
vim config/slurm.conf

# 2. Prepare base OS (Rocky headnode or Jetson)
./components/base/install.sh        # OS updates + essential tools

# 3. Install all components (orchestrated setup)
./bin/hpc-setup --step all          # Install all components with checkpointing

# OR install components individually
./bin/hpc-setup --step slurm        # Install only SLURM
./bin/hpc-setup --step spack        # Install only Spack
./bin/hpc-setup --step monitoring   # Install monitoring stack

# 4. Verify installation
./bin/hpc-test --all

# 5. Start daily operations
./maintenance/maintenance_daily.sh
```

## Setup Scripts Clarification

### 🎯 **Two Different Setup Scripts**

**`bin/hpc-setup`** - Main cluster setup orchestrator
- **Purpose**: Orchestrates installation of all HPC components
- **Features**: Checkpointing, component selection, error recovery
- **Usage**: `./bin/hpc-setup --step all` or `./bin/hpc-setup --step slurm`
- **Scope**: Full cluster deployment and component management

**`maintenance/setup.sh`** - Monitoring stack installer
- **Purpose**: Installs only the monitoring stack (ELK/Grafana)
- **Features**: Focused on monitoring infrastructure
- **Usage**: Called by `hpc-setup` when `--step monitoring` is used
- **Scope**: Monitoring components only

### 🔄 **Relationship**
- `hpc-setup` calls `maintenance/setup.sh` when monitoring is requested
- `maintenance/setup.sh` is a specialized installer for monitoring components
- Use `hpc-setup` for full cluster deployment, `maintenance/setup.sh` for monitoring-only

## Design Principles

### 🔧 Modular Architecture
- **Separation of Concerns**: Each directory has a specific purpose
- **DRY Principle**: Shared functionality in `lib/` prevents code duplication
- **Configuration-Driven**: All settings externalized to `config/` files
- **Component-Based**: Each service has its own installer in `components/`

### 📋 Coding Conventions

#### Library Sourcing
```bash
# Always source libraries first (adjust path based on location)
source "$(dirname "$0")/../../lib/functions.sh"  # From components/
source "$(dirname "$0")/../lib/functions.sh"     # From bin/
source "$(dirname "$0")/../../lib/config.sh"
```

#### Privilege Management
```bash
# Guard privileged operations
check_root   # Ensures script runs as root when needed
```

#### Configuration Loading
```bash
# Load only needed configurations
load_config "network.conf"  # Load specific config file
export_config               # Make variables available to child processes
```

#### Configuration Format
```bash
# Simple KEY=VALUE pairs in .conf files
HEAD_NODE_IP="10.0.0.1"
NETWORK_MASK="255.255.252.0"
CLUSTER_NAME="hpc-cluster"
```

#### Error Handling
```bash
# Robust error handling pattern
install_package "slurm" || {
    error "Failed to install SLURM"
    return 1
}
```

## Component Details

### 🏗️ Service Installers (`components/`)
Each component provides self-contained installation and configuration:

- **`base/`** - Base OS prerequisites (updates, common tools, firewall tooling)
- **`warewulf/`** - Bare-metal provisioning system for managing compute nodes
- **`slurm/`** - Job scheduler and workload manager for HPC workloads  
- **`spack/`** - Package manager for scientific software installation
- **`elk/`** - Elasticsearch, Logstash, Kibana for log aggregation and analysis
- **`grafana/`** - Metrics visualization and dashboard platform
- **`globus/`** - Secure data transfer and sharing capabilities
- **`eraider/`** - Authentication and identity management
- **`squid/`** - HTTP proxy and caching for improved performance
- **`apptainer/`** - Container runtime for reproducible environments

### 🔄 Operational Scripts (`maintenance/`)
Essential for ongoing cluster management:

- **`setup.sh`** - Installs monitoring stack (ELK/Grafana) - *Note: Different from bin/hpc-setup*
- **`backup.sh`** - Comprehensive data backup operations
- **`backup_config.sh`** - Configuration file backup and versioning
- **`verify_backup.sh`** - Backup integrity verification
- **`maintenance_daily.sh`** - Daily health checks, log rotation, cleanup
- **`security_scan.sh`** - Security auditing with Lynis, rkhunter, ClamAV

### 🚀 Entry Points (`bin/`)
User-facing commands for cluster management:

- **`hpc-setup`** - Main cluster setup orchestrator with checkpointing
- **`hpc-manage`** - Main cluster management CLI
- **`hpc-monitor`** - Health monitoring and status checks
- **`hpc-backup`** - Backup management interface
- **`hpc-security`** - Security hardening and auditing
- **`hpc-test`** - Testing and validation suite

## Why This Structure Works

### ✅ **Maintainability**
- Clear separation between installation, configuration, and operations
- Shared libraries prevent code duplication
- Configuration externalized for easy customization

### ✅ **Scalability** 
- Component-based approach allows adding new services easily
- Modular design supports different deployment scenarios
- Configuration-driven approach scales to different cluster sizes

### ✅ **Reliability**
- Consistent error handling and logging across all scripts
- Backup and verification procedures built-in
- Security scanning and hardening automated

### ✅ **Usability**
- Simple entry points for common operations
- Clear documentation and examples
- Standardized configuration format

## Development Guidelines

### 🎯 **Best Practices**
- **Use library functions**: Leverage `lib/functions.sh` utilities (logging, validation, system ops)
- **Configuration-driven**: Keep all settings in `config/` files, never hardcode values
- **Error handling**: Use `|| { error "message"; return 1; }` pattern consistently
- **Code organization**: Place shared logic in `lib/`, not in entry points

### 🔧 **Adding New Components**
1. Create directory in `components/`
2. Add `install.sh` script following existing patterns
3. Source libraries: `source "$(dirname "$0")/../../lib/functions.sh"`
4. Load configuration: `load_config "component.conf"`
5. Use standard functions: `check_root`, `info`, `error`, `install_package`

## Support & Documentation

- **📚 Documentation**: `docs/development/`
- **🐛 Issues**: https://github.com/ttu-hpc/Mini-HPC-Setup/issues
- **💬 Community**: HPC development team discussions