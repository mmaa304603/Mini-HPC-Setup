# Core Ansible Functionality

This directory contains core Ansible functionality used by all components.

## Structure

```
core/
├── roles/       # Core roles
│   ├── common/  # Common configurations
│   ├── network/ # Network setup
│   └── security/# Security configuration
│
├── playbooks/   # Core playbooks
│   ├── init.yml # Initial setup
│   ├── base.yml # Base configuration
│   └── test.yml # Testing playbooks
│
├── vars/        # Core variables
│   ├── main.yml # Main variables
│   └── test.yml # Test variables
│
└── inventory/   # Core inventory
    ├── hosts    # Host definitions
    └── test     # Test environment
```

## Usage

```bash
# Run core playbooks
ansible-playbook -i inventory/hosts playbooks/init.yml
ansible-playbook -i inventory/hosts playbooks/base.yml
ansible-playbook -i inventory/test playbooks/test.yml
```

## Dependencies

- Common utilities from `src/common/utils/`
- Configuration from `src/ansible/config/`
- Templates from `src/ansible/templates/`

## Support

For core Ansible issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/ansible/core.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 