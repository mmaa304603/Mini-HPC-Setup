# Source Code

This directory contains the implementation code for the Mini HPC cluster setup. The code is organized into two main configuration methods: Ansible and shell scripts.

## Architecture Overview

The Mini cluster consists of:
- **Head Node**: One Radxa X2L with 2TB SSD
- **CPU Compute Nodes**: Three Radxa X2L without external storage  
- **GPU Compute Node**: One Jetson Orin Nano with 512GB SSD

Network configuration uses 10.0.0.0/22 subnet with head node at 10.0.0.1 and compute nodes at 10.0.2.1-10.0.2.4.

## Setup Flow

### Prerequisites
1. Install Rocky Linux 9.6 on head node
2. Jetson Orin Nano is flashed (can be done with Ubuntu host: [Jetson AI Lab Setup Guide](https://www.jetson-ai-lab.com/initial_setup_jon_sdkm.html))

### Cluster Setup Steps
1. Set up network configuration
2. Install and configure Warewulf
3. Install and configure SLURM
4. Use Spack for package management
5. Configure Lmod to load packages for users
6. Set up logging management (ELK stack)
7. Configure system monitoring (MonSTER + Grafana)

## Implementation Methods

### Ansible Method
- Located in `src/ansible/`
- Uses declarative configuration
- Role-based organization
- Features:
  - Idempotent operations
  - Inventory management
  - Role-based organization
  - Template-based configuration
  - Package management via Spack (replaces Squid proxy)

### Shell Method
- Located in `src/shell/`
- Uses imperative configuration
- Modular script-based organization
- Features:
  - **Entry Points** (`bin/`): Main orchestration scripts with checkpointing
  - **Components** (`components/`): Individual service installers
  - **Libraries** (`lib/`): Shared utilities following DRY principle
  - **Maintenance** (`maintenance/`): Operational and monitoring scripts
  - **Configuration** (`config/`): Centralized configuration management
  - Direct system control and template-based configuration


## Shell Library Structure

The shell implementation uses a comprehensive library system in `src/shell/lib/`:

**Core Utilities:**
- `functions.sh` - Basic system operations and logging
- `config.sh` - Configuration loading and management
- `logging.sh` - Advanced logging with levels
- `error.sh` - Comprehensive error handling
- `validation.sh` - Input validation functions
- `validate.sh` - System environment validation
- `checkpoint.sh` - Progress tracking system

## Development

### Adding New Code
1. Choose appropriate method (Ansible or shell)
2. Place code in correct subdirectory
3. Add documentation
4. Update tests
5. Update CI/CD pipeline

### Code Requirements
- Must be well-documented
- Must include error handling
- Must be maintainable
- Must follow style guidelines
- Must include tests

