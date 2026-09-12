# Spack Role

This Ansible role installs and configures Spack at the system level, making it available to all users on the system. Spack is a flexible package manager designed to support multiple versions, configurations, platforms, and compilers.

## Features

- Installs Spack from source in `/opt/spack`
- Configures system-wide Spack settings in `/etc/spack`
- Sets up system compilers and external packages
- Configures environment modules for package management
- Installs common HPC packages
- Creates system-wide environment file in `/etc/profile.d/spack.sh`

## Requirements

- RHEL/CentOS/Rocky Linux 7 or later
- Git
- GCC and development tools
- Environment Modules
- Python 3 with required packages (clingo, pyyaml, jinja2)

## Role Variables

### Installation

- `spack_version`: Spack version to install (default: `v0.23.1`)
- `spack_install_dir`: Directory where Spack will be installed (default: `/opt/spack`)
- `spack_config_dir`: Directory for Spack configuration files (default: `/etc/spack`)
- `spack_repo`: Spack repository URL (default: `https://github.com/spack/spack.git`)

### Build Configuration

- `spack_build_jobs`: Number of parallel build jobs (default: `8`)
- `spack_build_language`: Build language (default: `C`)
- `spack_install_path_scheme`: Installation path scheme (default: `{name}/{version}-{compiler.name}-{compiler.version}/{hash}`)

### Cache Configuration

- `spack_source_cache`: Source cache directory (default: `{{ spack_install_dir }}/sources`)
- `spack_misc_cache`: Miscellaneous cache directory (default: `{{ spack_install_dir }}/cache`)
- `spack_build_stage`: Build stage directory (default: `/tmp/spack-stage`)

### Module Configuration

- `spack_module_roots`: Module roots configuration
  ```yaml
  spack_module_roots:
    tcl: "{{ spack_install_dir }}/modules/tcl"
    lmod: "{{ spack_install_dir }}/modules/lmod"
  ```

### Compilers

- `spack_compilers`: List of system compiler paths to add to Spack
  ```yaml
  spack_compilers:
    - /usr/bin/gcc
    - /usr/bin/g++
    - /usr/bin/gfortran
  ```

### Packages

- `spack_packages`: List of packages to install
  ```yaml
  spack_packages:
    - openmpi
    - python@3.8
    - hdf5
    - netcdf
    - cmake
    - git
  ```

### Environment Modules

- `modules_default_path`: Path to system modulefiles (default: `/usr/share/Modules/modulefiles`)

## Configuration Files

The role creates the following configuration files in `{{ spack_config_dir }}`:

- `config.yaml`: General Spack configuration
- `compilers.yaml`: System compiler definitions
- `packages.yaml`: Package preferences and external packages
- `modules.yaml`: Module file generation settings
- `spack.yaml`: Environment-specific settings

## Example Playbook

```yaml
- hosts: hpc_nodes
  roles:
    - role: spack
      vars:
        spack_version: "v0.23.1"
        spack_packages:
          - openmpi
          - python@3.8
          - hdf5
          - netcdf
          - cmake
        spack_compilers:
          - /usr/bin/gcc
          - /usr/bin/g++
          - /usr/bin/gfortran
```

## User Access

After the role is applied, users need to either:
1. Log out and log back in
2. Run `source /etc/profile.d/spack.sh`

This will make Spack available in their environment.

## License

MIT

## Author Information

Created for HPC-Setup project 