# Configuration

User-editable configuration consumed by scripts in `src/shell/components/` and `src/shell/bin/`.

## Files

Top-level `.conf` files (key=value) loaded via `lib/config.sh`:

- `config.conf` - shared paths and feature flags

Component-specific configuration lives with each component, for example
`components/network/network.conf`, `components/slurm/slurm.conf`,
`components/spack/spack.conf`, `components/grafana/monitoring.conf`, and
`components/apptainer/apptainer.conf`.

## Loading configuration in scripts

```bash
source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../lib/config.sh"

# Load what you need
load_component_config "network"
load_component_config "slurm"

# Make variables available to child processes
export_config
```

## Tips

- Keep values simple: `KEY=VALUE` with no quotes unless needed.
- Do not commit secrets; use environment variables or separate, ignored files.
- YAML such as Warewulf config is generated/consumed by components and not sourced directly.