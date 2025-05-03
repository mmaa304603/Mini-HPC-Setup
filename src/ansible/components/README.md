# Component Implementations

This directory contains Ansible implementations of various HPC cluster components.

## Components

- `slurm/` - SLURM workload manager
- `warewulf/` - Warewulf provisioning system
- `spack/` - Spack package manager
- `globus/` - Globus data management
- `eraider/` - Eraider authentication
- `elk/` - ELK logging stack
- `grafana/` - Grafana monitoring
- `filebeat/` - Filebeat log shipping
- `squid/` - Squid proxy server
- `apptainer/` - Apptainer container runtime

## Structure

Each component follows this structure:
```
component/
├── roles/         # Component roles
│   ├── install/   # Installation
│   ├── config/    # Configuration
│   └── manage/    # Management
│
├── playbooks/     # Component playbooks
│   ├── install.yml # Installation
│   ├── config.yml  # Configuration
│   └── manage.yml  # Management
│
├── vars/          # Component variables
│   ├── main.yml   # Main variables
│   └── test.yml   # Test variables
│
└── inventory/     # Component inventory
    ├── hosts      # Host definitions
    └── test       # Test environment
```

## Usage

```bash
# Install a component
ansible-playbook -i inventory/hosts components/slurm/playbooks/install.yml

# Configure a component
ansible-playbook -i inventory/hosts components/slurm/playbooks/config.yml

# Manage a component
ansible-playbook -i inventory/hosts components/slurm/playbooks/manage.yml
```

## Dependencies

- Common utilities from `src/common/utils/`
- Core roles from `src/ansible/core/roles/`
- Configuration from `src/ansible/config/`
- Templates from `src/ansible/templates/`

## Support

For component issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/ansible/components.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 