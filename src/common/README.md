# Common Utilities

This directory contains shared utilities, helper functions, and templates used by both Ansible and shell implementations.

## Directory Structure

```
common/
├── utils/     # Shared utility scripts
│   ├── logging.sh    # Logging utilities
│   ├── error.sh      # Error handling
│   └── validation.sh # Input validation
│
├── helpers/   # Helper functions
│   ├── network.sh    # Network helpers
│   ├── storage.sh    # Storage helpers
│   └── security.sh   # Security helpers
│
└── templates/ # Common templates
    ├── config/       # Configuration templates
    ├── scripts/      # Script templates
    └── docs/         # Documentation templates
```

## Usage

### Utilities
```bash
# Source utility scripts
source utils/logging.sh
source utils/error.sh
source utils/validation.sh
```

### Helpers
```bash
# Source helper functions
source helpers/network.sh
source helpers/storage.sh
source helpers/security.sh
```

### Templates
```bash
# Use configuration templates
cp templates/config/hosts.template config/hosts

# Use script templates
cp templates/scripts/install.template bin/install.sh

# Use documentation templates
cp templates/docs/README.template docs/README.md
```

## Development

### Adding New Utilities
1. Place in appropriate subdirectory
2. Add documentation
3. Update tests
4. Update CI/CD pipeline

### Utility Requirements
- Must be self-contained
- Must include documentation
- Must include error handling
- Must support configuration
- Must be maintainable

## Support

For utility-related issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/utilities.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 