# Templates

Static templates used by component scripts to render config files.

## Where used

- Component scripts under `src/shell/components/**` copy or render templates as part of install/configure steps.

## Example: render from template

If you maintain a rendering helper (e.g., `generate_config`), source it and run:

```bash
source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../lib/config.sh"

load_component_config "network"

# Example paths
TEMPLATE_PATH="$(dirname "$0")/../templates/core/example.conf.j2"
OUTPUT_PATH="/etc/example.conf"

# hypothetical helper (implement if needed)
generate_config "$TEMPLATE_PATH" "$OUTPUT_PATH"
```

Otherwise, simple templates are often copied and then edited by the scripts themselves.
