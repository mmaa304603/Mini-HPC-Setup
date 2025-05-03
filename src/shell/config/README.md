# Configuration Files

This directory contains configuration files for the HPC cluster.

## Structure

```
config/
├── core/     # Core configurations
├── setup/    # Setup configurations
└── tools/    # Utility configurations
```

## Usage

Configuration files are sourced by scripts to set environment variables and parameters.

```bash
# Source configuration in scripts
source "$(dirname "$0")/../config/core/config.sh"
source "$(dirname "$0")/../config/setup/config.sh"
source "$(dirname "$0")/../config/tools/config.sh"
```

## Dependencies

- Common utilities from `src/common/utils/`
- Library scripts from `src/shell/lib/`
- Templates from `src/shell/templates/`

## Support

For configuration issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/config.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 