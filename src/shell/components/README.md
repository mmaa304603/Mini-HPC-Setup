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

Each component follows this structure:
```
component/
├── install.sh    # Installation script
├── config.sh     # Configuration script
├── manage.sh     # Management script
├── templates/    # Component templates
└── config/       # Component configurations
```

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

- Common utilities from `src/common/utils/`
- Library scripts from `src/shell/lib/`
- Configuration from `src/shell/config/`
- Templates from `src/shell/templates/`

## Support

For component issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/components.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 