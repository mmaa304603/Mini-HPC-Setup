# Spack Role

This Ansible role installs and configures Spack, a flexible package manager designed to support multiple versions, configurations, platforms, and compilers.

## Features

- Installs Spack from source
- Configures system compilers
- Sets up environment modules
- Installs common HPC packages
- Configures system packages and externals

## Requirements

- RHEL/CentOS 7 or later
- Git
- GCC and development tools
- Environment Modules

## Role Variables

### Installation

- `spack_install_dir`: Directory where Spack will be installed (default: `/opt/spack`)
- `spack_repo`: Spack repository URL (default: `https://github.com/spack/spack.git`)
- `spack_branch`: Spack branch to clone (default: `develop`)

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

## Example Playbook

```yaml
- hosts: hpc_nodes
  roles:
    - role: spack
      vars:
        spack_packages:
          - openmpi
          - python@3.8
          - hdf5
```

## License

MIT

## Author Information

Created for HPC-Setup project 