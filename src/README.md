# Source Code

This directory contains the implementation code for the Mini HPC cluster setup. The code is organized into two main configuration methods: Ansible and shell scripts.

## Directory Structure

```
src/
├── ansible/      # Ansible-based configuration
│   ├── roles/    # Ansible roles
│   ├── playbooks/# Ansible playbooks
│   ├── inventory/# Inventory files
│   └── vars/     # Variable files
│
├── shell/        # Shell script-based configuration
│   ├── bin/      # Executable scripts
│   ├── lib/      # Library scripts
│   ├── config/   # Configuration files
│   └── templates/# Template files
│
└── common/       # Common utilities
    ├── utils/    # Shared utilities
    ├── helpers/  # Helper functions
    └── templates/# Common templates
```

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

### Shell Method
- Located in `src/shell/`
- Uses imperative configuration
- Script-based organization
- Features:
  - Direct system control
  - Script-based automation
  - Template-based configuration
  - System-level operations

### Common Utilities
- Located in `src/common/`
- Shared between both methods
- Features:
  - Common functions
  - Shared templates
  - Helper utilities
  - Cross-method tools

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

## Support

For implementation issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/implementation.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 