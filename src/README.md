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
│   ├── bin/      # Entry points and automation scripts
│   │   ├── hpc-setup    # Main cluster setup orchestrator
│   │   ├── hpc-manage   # Cluster management CLI
│   │   ├── hpc-monitor  # Health monitoring
│   │   ├── hpc-backup   # Backup management
│   │   ├── hpc-security # Security hardening
│   │   └── hpc-test     # Testing and validation
│   ├── lib/      # Shared libraries (DRY principle)
│   │   ├── functions.sh # Core utilities
│   │   ├── config.sh    # Configuration management
│   │   └── install.sh   # Environment Modules installer
│   ├── config/   # Configuration files
│   ├── components/ # Individual service installers
│   ├── maintenance/ # Operational scripts
│   └── templates/ # Configuration templates
│
└── common/       # Cross-method shared utilities
    ├── utils/    # Shared utility scripts
    ├── helpers/  # Helper functions (currently empty)
    └── templates/# Common templates (currently empty)
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
- Modular script-based organization
- Features:
  - **Entry Points** (`bin/`): Main orchestration scripts with checkpointing
  - **Components** (`components/`): Individual service installers
  - **Libraries** (`lib/`): Shared utilities following DRY principle
  - **Maintenance** (`maintenance/`): Operational and monitoring scripts
  - **Configuration** (`config/`): Centralized configuration management
  - Direct system control and template-based configuration

### Common Utilities
- Located in `src/common/`
- Shared between both methods
- Features:
  - Common functions
  - Shared templates
  - Helper utilities
  - Cross-method tools

## Directory Overlaps and Consolidation

### Current Overlaps
There are some functional overlaps between directories that should be addressed:

**Logging Functions:**
- `src/common/utils/logging.sh` - Advanced logging with levels and file output
- `src/shell/lib/functions.sh` - Basic logging with colors and console output

**Error Handling:**
- `src/common/utils/error.sh` - Comprehensive error handling with error codes
- `src/shell/lib/functions.sh` - Basic error functions

**Validation:**
- `src/common/utils/validate.sh` - Input validation utilities
- `src/common/utils/validation.sh` - Additional validation functions

### Consolidation Strategy
1. **Keep `src/shell/lib/`** as the primary library for shell scripts
2. **Migrate useful functions** from `src/common/utils/` to `src/shell/lib/`
3. **Use `src/common/`** only for truly cross-method utilities (Ansible + Shell)
4. **Empty directories** (`helpers/`, `templates/`) should be populated or removed

### Recommended Actions
- Consolidate logging functions into `src/shell/lib/functions.sh`
- Merge error handling approaches
- Remove duplicate validation scripts
- Populate or remove empty `common/` subdirectories

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