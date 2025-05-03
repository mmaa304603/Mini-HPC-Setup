# Setup and Installation

This directory contains Ansible playbooks for initial setup and installation.

## Structure

```
setup/
├── roles/         # Setup roles
│   ├── init/      # Initial setup
│   ├── packages/  # Package installation
│   └── config/    # Configuration setup
│
├── playbooks/     # Setup playbooks
│   ├── init.yml   # Initial setup
│   ├── packages.yml # Package installation
│   └── config.yml # Configuration setup
│
├── vars/          # Setup variables
│   ├── main.yml   # Main variables
│   └── packages.yml # Package variables
│
└── inventory/     # Setup inventory
    ├── hosts      # Host definitions
    └── test       # Test environment
```

## Usage

```bash
# Run setup playbooks
ansible-playbook -i inventory/hosts playbooks/init.yml
ansible-playbook -i inventory/hosts playbooks/packages.yml
ansible-playbook -i inventory/hosts playbooks/config.yml
```

## Dependencies

- Common utilities from `src/common/utils/`
- Core roles from `src/ansible/core/roles/`
- Configuration from `src/ansible/config/`
- Templates from `src/ansible/templates/`

## Support

For setup issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/ansible/setup.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 