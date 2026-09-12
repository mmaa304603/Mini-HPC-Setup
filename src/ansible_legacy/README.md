# Ansible Implementation

This directory contains the Ansible-based implementation of the Mini HPC cluster setup.

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

## Directory Structure

```
ansible/
├── core/          # Core Ansible functionality
│   ├── roles/     # Core roles
│   ├── playbooks/ # Core playbooks
│   ├── vars/      # Core variables
│   └── inventory/ # Core inventory
│
├── setup/         # Setup and installation
│   ├── roles/     # Setup roles
│   ├── playbooks/ # Setup playbooks
│   ├── vars/      # Setup variables
│   └── inventory/ # Setup inventory
│
├── tools/         # Utility tools
│   ├── roles/     # Tool roles
│   ├── playbooks/ # Tool playbooks
│   ├── vars/      # Tool variables
│   └── inventory/ # Tool inventory
│
└── components/    # Component implementations
    ├── slurm/     # SLURM implementation
    ├── warewulf/  # Warewulf implementation
    ├── spack/     # Spack implementation
    ├── globus/    # Globus implementation
    ├── eraider/   # Eraider implementation
    ├── elk/       # ELK implementation
    ├── grafana/   # Grafana implementation
    ├── filebeat/  # Filebeat implementation
    └── apptainer/ # Apptainer implementation
```

## Implementation Details

### Core Components
- Located in `core/`
- Contains base roles, playbooks, and variables
- Provides common functionality for all components
- Follows consistent structure:
  ```
  component/
  ├── roles/       # Component roles
  ├── playbooks/   # Component playbooks
  ├── vars/        # Component variables
  └── inventory/   # Component inventory
  ```

### Setup Components
- Located in `setup/`
- Contains installation and configuration playbooks
- Handles initial setup and deployment
- Follows same structure as core components

### Tool Components
- Located in `tools/`
- Contains utility and helper playbooks
- Provides additional functionality
- Follows same structure as core components

### Component Implementations
- Located in `components/`
- Each component has its own directory
- Contains component-specific roles and playbooks
- Follows same structure as core components

## Usage

### Installation
```bash
# Install all components
ansible-playbook -i inventory/hosts site.yml

# Install specific component
ansible-playbook -i inventory/hosts components/slurm/site.yml
```

### Development

#### Adding New Components
1. Create component directory in `components/`
2. Add required roles and playbooks
3. Add variables and inventory
4. Update documentation

#### Playbook Requirements
- Must be well-documented
- Must include error handling
- Must use common roles
- Must follow style guidelines
- Must include tests

## Support

For Ansible implementation issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/ansible.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 