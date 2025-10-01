# Component Implementations

This directory contains implementations of various HPC cluster components.

## Components

- `slurm/` - SLURM workload manager
- `warewulf/` - Warewulf provisioning system
- `spack/` - Spack package manager
- `globus/` - Globus data management
- `eraider/` - Eraider authentication
- `elk/` - ELK logging stack
- `grafana/` - Grafana monitoring
- `filebeat/` - Filebeat log shipping
- `apptainer/` - Apptainer container runtime

## Structure

Each component follows this structure with component-based configuration:
```
component/
├── install.sh    # Installation script
├── configure.sh  # Configuration script
├── component.conf # Component-specific configuration
├── templates/    # Component templates (if needed)
└── README.md     # Component documentation (if needed)
```

### Configuration Management

Each component manages its own configuration files:

- **`network/network.conf`** - Network settings (IPs, interfaces, firewall)
- **`slurm/slurm.conf`** - SLURM cluster configuration
- **`spack/spack.conf`** - Spack package manager settings
- **`warewulf/warewulf.conf`** - Warewulf provisioning configuration
- **`grafana/monitoring.conf`** - Monitoring and alerting settings
- **`apptainer/apptainer.conf`** - Container configuration

### Loading Component Configuration

```bash
# In component scripts
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load specific component configuration
load_component_config "network"
load_component_config "slurm"
```

### Benefits of Component-Based Configuration

- ✅ **Logical grouping** - Config files with related scripts
- ✅ **Easier maintenance** - All component files in one place
- ✅ **Better modularity** - Components are self-contained
- ✅ **Clearer dependencies** - Easy to see what each component needs
- ✅ **Version control** - Easier to track changes per component

## Usage

```bash
# Install a component
./components/slurm/install.sh

# Configure a component
./components/slurm/config.sh

# Manage a component
./components/slurm/manage.sh
```

## Dependencies

- Library scripts from `src/shell/lib/`
- Component-specific configuration files
- Global system configuration from `src/shell/config/config.conf`

## Support

For component issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/components.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 