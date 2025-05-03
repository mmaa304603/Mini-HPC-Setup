# Library Scripts

This directory contains shared library scripts used by other components.

## Scripts

- `config.sh` - Configuration management library
- `functions.sh` - Common function library
- `install.sh` - Installation helper library

## Usage

```bash
# Source libraries in scripts
source "$(dirname "$0")/../lib/config.sh"
source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../lib/install.sh"
```

## Dependencies

- Common utilities from `src/common/utils/`
- Configuration from `src/shell/config/`
- Templates from `src/shell/templates/`

## Support

For library script issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/lib.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 