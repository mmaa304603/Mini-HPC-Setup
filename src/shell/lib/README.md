# Library Scripts

Shared libraries providing common functionality for shell-based HPC setup scripts.

## Files

- **`functions.sh`** - Core utilities (logging, validation, system operations)
- **`config.sh`** - Configuration loading and management
- **`install.sh`** - Environment Modules installation helper
- **`logging.sh`** - Advanced logging utilities with levels
- **`error.sh`** - Error handling and error codes
- **`validation.sh`** - Input validation functions
- **`validate.sh`** - System environment validation
- **`checkpoint.sh`** - Checkpoint system for tracking progress

## Usage in Components

### Basic Pattern
```bash
#!/bin/bash

# Source libraries (adjust path based on location)
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load configuration
load_component_config "network"
export_config

# Use functions
check_root
info "Starting installation..."
install_package "some-package"
```

### From Different Locations

**From `src/shell/components/component/`:**
```bash
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"
```

**From `src/shell/bin/`:**
```bash
source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../lib/config.sh"
```

## functions.sh - Core Utilities

### Logging Functions
```bash
info "Operation completed successfully"
warn "This is a warning message"
error "Something went wrong"
```

### System Functions
```bash
check_root                    # Ensure running as root
ensure_dir "/path/to/dir"     # Create directory if missing
backup_file "/etc/config"     # Backup file with timestamp
install_package "package"     # Install via dnf
start_service "servicename"   # Enable and start service
configure_firewall "8080"     # Add firewall rule
```

### Utility Functions
```bash
command_exists "git"          # Check if command exists
service_running "httpd"       # Check if service is running
remote_exec "node1" "ls -la"  # Execute command on remote node
```

## config.sh - Configuration Management

### Loading Configuration
```bash
# Load specific config file
load_component_config "network"

# Load all standard configs
load_all_configs

# Make variables available to child processes
export_config
```

### Available Configurations
- `network.conf` - Network settings (IPs, DHCP ranges)
- `slurm.conf` - SLURM cluster configuration
- `spack.conf` - Spack package manager settings
- `monitoring.conf` - ELK/Grafana/Prometheus settings
- `squid.conf` - Squid proxy configuration, not used anymore
- `apptainer.conf` - Apptainer container settings

### Configuration Variables
After loading, variables are available:
```bash
load_component_config "network"
echo "Head node IP: $HEAD_NODE_IP"
echo "Network: $NETWORK"
echo "DHCP range: $DHCP_START - $DHCP_END"
```

## install.sh - Environment Modules

Installs and configures Environment Modules for managing software environments.

### Usage
```bash
# Source and run
source "$(dirname "$0")/install.sh"
main
```

### What it does
- Installs dependencies (git, gcc, tcl)
- Clones and builds Environment Modules
- Creates modulefiles for Spack
- Sets up environment scripts

## Best Practices

1. **Always source functions.sh first** - provides logging and utilities
2. **Use check_root early** - for scripts requiring privileges
3. **Load only needed configs** - don't load everything unnecessarily
4. **Export config variables** - if spawning child processes
5. **Handle errors gracefully** - use `|| { error "message"; return 1; }`

## Examples

### Component Install Script
```bash
#!/bin/bash
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

main() {
    check_root
    load_component_config "network"
    
    info "Installing component..."
    install_package "my-package"
    
    info "Configuring component..."
    ensure_dir "/etc/my-component"
    backup_file "/etc/my-component/config.conf"
    
    info "Starting service..."
    start_service "my-component"
    
    info "Component installation completed"
}

main "$@"
```

### Configuration Script
```bash
#!/bin/bash
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

main() {
    load_component_config "network"
    load_component_config "slurm"
    export_config
    
    info "Configuring with network: $NETWORK"
    info "SLURM cluster: $CLUSTER_NAME"
    
    # Generate config files using loaded variables
    generate_config_file
}

main "$@"
``` 
