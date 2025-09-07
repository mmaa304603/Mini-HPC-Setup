# Configuration

User-editable configuration consumed by scripts in `src/shell/components/` and `src/shell/bin/`.

## Files

Top-level `.conf` files (key=value) loaded via `lib/config.sh`:

- `network.conf`, `slurm.conf`, `spack.conf`, `monitoring.conf`, `squid.conf`, `apptainer.conf`

## Loading configuration in scripts

```bash
source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../lib/config.sh"

# Load what you need
load_config "network.conf"
load_config "slurm.conf"

# Make variables available to child processes
export_config
```

## Tips

- Keep values simple: `KEY=VALUE` with no quotes unless needed.
- Do not commit secrets; use environment variables or separate, ignored files.
- YAML such as Warewulf config is generated/consumed by components and not sourced directly.