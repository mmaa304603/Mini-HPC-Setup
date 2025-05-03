# Shell Implementation

This directory contains the shell script-based implementation of the Mini HPC cluster setup.

## Directory Structure

```
shell/
├── bin/          # Executable scripts
│   ├── core/     # Core functionality
│   ├── setup/    # Setup scripts
│   └── tools/    # Utility scripts
│
├── lib/          # Library scripts
│   ├── core/     # Core libraries
│   ├── setup/    # Setup libraries
│   └── tools/    # Utility libraries
│
├── config/       # Configuration files
│   ├── core/     # Core configurations
│   ├── setup/    # Setup configurations
│   └── tools/    # Utility configurations
│
├── templates/    # Template files
│   ├── core/     # Core templates
│   ├── setup/    # Setup templates
│   └── tools/    # Utility templates
│
└── components/   # Component implementations
    ├── slurm/    # SLURM implementation
    ├── warewulf/ # Warewulf implementation
    ├── spack/    # Spack implementation
    ├── globus/   # Globus implementation
    ├── eraider/  # Eraider implementation
    ├── elk/      # ELK implementation
    ├── grafana/  # Grafana implementation
    ├── filebeat/ # Filebeat implementation
    ├── squid/    # Squid implementation
    └── apptainer/# Apptainer implementation
```

## Implementation Details

### Core Components
- Located in `components/`
- Each component has its own directory
- Contains installation, configuration, and management scripts
- Follows consistent structure:
  ```
  component/
  ├── install.sh    # Installation script
  ├── config.sh     # Configuration script
  ├── manage.sh     # Management script
  ├── templates/    # Component templates
  └── config/       # Component configurations
  ```

### Script Organization
- **Binaries** (`bin/`): Executable scripts
  - `core/`: Core functionality scripts
  - `setup/`: Setup and installation scripts
  - `tools/`: Utility and helper scripts

- **Libraries** (`lib/`): Shared functions
  - `core/`: Core functionality libraries
  - `setup/`: Setup and installation libraries
  - `tools/`: Utility and helper libraries

- **Configurations** (`config/`): Configuration files
  - `core/`: Core configuration files
  - `setup/`: Setup configuration files
  - `tools/`: Utility configuration files

- **Templates** (`templates/`): Template files
  - `core/`: Core template files
  - `setup/`: Setup template files
  - `tools/`: Utility template files

## Usage

### Installation
```bash
# Install a component
./components/slurm/install.sh

# Configure a component
./components/slurm/config.sh

# Manage a component
./components/slurm/manage.sh
```

### Development

#### Adding New Components
1. Create component directory in `components/`
2. Add required scripts:
   - `install.sh`
   - `config.sh`
   - `manage.sh`
3. Add templates and configurations
4. Update documentation

#### Script Requirements
- Must be well-documented
- Must include error handling
- Must use common utilities
- Must follow style guidelines
- Must include tests

## Support

For shell implementation issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/shell.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 