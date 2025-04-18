# Shell Scripts for HPC Setup

This directory contains shell scripts for setting up an HPC cluster. The scripts are organized by component and include common utilities.

## Directory Structure

```
shell/
├── common/           # Common functions and configurations
├── network/         # Network setup scripts
├── slurm/          # SLURM setup scripts
├── spack/          # Spack setup scripts
├── monitoring/     # Monitoring setup scripts
├── squid/          # Squid setup scripts
├── apptainer/      # Apptainer setup scripts
└── utils/          # Utility scripts
```

## Common Functions

The `common` directory contains shared functions and configurations used across all setup scripts:

- `functions.sh`: Common shell functions for logging, error handling, and system checks
- `config.sh`: Global configuration variables

## Setup Script

The main setup script (`setup.sh`) orchestrates the installation process:

```bash
./setup.sh [options]
```

Options:
- `--step <component>`: Install specific component
- `--list-checkpoints`: List available checkpoints
- `--clear-checkpoint <name>`: Clear specific checkpoint
- `--clear-all-checkpoints`: Clear all checkpoints

## Component Scripts

### Network Setup (`network/setup.sh`)

Configures network interfaces, DHCP, and firewall rules:
- Sets up network interface (enp2s0)
- Configures DHCP server
- Sets up firewall rules
- Configures NFS exports

### SLURM Setup (`slurm/setup.sh`)

Installs and configures SLURM:
- Installs SLURM packages
- Configures slurm.conf
- Sets up accounting
- Configures partitions
- Starts SLURM services

### Spack Setup (`spack/setup.sh`)

Installs and configures Spack:
- Clones Spack repository
- Configures environment
- Installs default packages
- Sets up module system

### Monitoring Setup (`monitoring/setup.sh`)

Sets up monitoring stack:
- Installs ELK stack
- Configures Grafana
- Sets up Filebeat
- Configures dashboards

### Squid Setup (`squid/setup.sh`)

Configures Squid proxy:
- Installs Squid
- Configures cache settings
- Sets up access controls
- Configures logging

### Apptainer Setup (`apptainer/setup.sh`)

Installs and configures Apptainer:
- Installs Apptainer
- Configures cache directory
- Sets up bind paths
- Configures security settings

## Utility Scripts

The `utils` directory contains helper scripts:

- `validate.sh`: Environment validation
- `checkpoint.sh`: Checkpoint management
- `backup.sh`: System backup utilities
- `cleanup.sh`: Cleanup utilities

## Checkpoint System

The checkpoint system allows for resuming interrupted installations:

1. List checkpoints:
   ```bash
   ./setup.sh --list-checkpoints
   ```

2. Clear specific checkpoint:
   ```bash
   ./setup.sh --clear-checkpoint network_setup
   ```

3. Clear all checkpoints:
   ```bash
   ./setup.sh --clear-all-checkpoints
   ```

## Logging

All scripts write logs to `/var/log/hpc-setup/`:
- `setup.log`: Main setup log
- `network.log`: Network setup log
- `slurm.log`: SLURM setup log
- etc.

## Error Handling

Scripts include error handling and validation:
- Environment checks
- Dependency verification
- Service status checks
- Rollback capabilities

## Best Practices

1. Always run scripts as root
2. Review logs for errors
3. Use checkpoints for long-running installations
4. Backup configuration files before changes
5. Test in a non-production environment first 