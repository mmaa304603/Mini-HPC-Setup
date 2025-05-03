# Utility Tools

This directory contains Ansible playbooks for utility and helper functions.

## Structure

```
tools/
├── roles/         # Tool roles
│   ├── backup/    # Backup management
│   ├── monitor/   # Monitoring setup
│   └── test/      # Testing tools
│
├── playbooks/     # Tool playbooks
│   ├── backup.yml # Backup management
│   ├── monitor.yml # Monitoring setup
│   └── test.yml   # Testing tools
│
├── vars/          # Tool variables
│   ├── main.yml   # Main variables
│   └── test.yml   # Test variables
│
└── inventory/     # Tool inventory
    ├── hosts      # Host definitions
    └── test       # Test environment
```

## Usage

```bash
# Run tool playbooks
ansible-playbook -i inventory/hosts playbooks/backup.yml
ansible-playbook -i inventory/hosts playbooks/monitor.yml
ansible-playbook -i inventory/test playbooks/test.yml
```

## Dependencies

- Common utilities from `src/common/utils/`
- Core roles from `src/ansible/core/roles/`
- Configuration from `src/ansible/config/`
- Templates from `src/ansible/templates/`

## Support

For tool issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/ansible/tools.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 