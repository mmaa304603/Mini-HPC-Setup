# Template Files

This directory contains template files used for configuration generation.

## Structure

```
templates/
├── core/     # Core templates
├── setup/    # Setup templates
└── tools/    # Utility templates
```

## Usage

Templates are used to generate configuration files with variable substitution.

```bash
# Generate configuration from template
source "$(dirname "$0")/../lib/config.sh"
generate_config "$(dirname "$0")/../templates/core/template.conf" "$(dirname "$0")/../config/core/config.conf"
```

## Dependencies

- Common utilities from `src/common/utils/`
- Library scripts from `src/shell/lib/`
- Configuration from `src/shell/config/`

## Support

For template issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/templates.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 