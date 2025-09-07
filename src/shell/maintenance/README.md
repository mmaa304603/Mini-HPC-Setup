# Maintenance Scripts

This directory contains scripts for maintaining and monitoring the HPC cluster.

## Scripts

- **`setup.sh`** - Setup monitoring stack (Elasticsearch, Grafana, Kibana, Logstash)
- **`backup.sh`** - Backup monitoring stack data and configuration
- **`backup_config.sh`** - Backup HPC configuration files
- **`verify_backup.sh`** - Verify backup integrity and completeness
- **`maintenance_daily.sh`** - Daily maintenance tasks (health checks, log rotation, cleanup)
- **`security_scan.sh`** - Security scanning and auditing (Lynis, rkhunter, ClamAV)

## Usage

```bash
# Setup monitoring stack
./setup.sh

# Run daily maintenance
./maintenance_daily.sh

# Perform backup
./backup.sh

# Backup configuration files
./backup_config.sh

# Verify backup integrity
./verify_backup.sh

# Run security scan
./security_scan.sh
```

## What Each Script Does

### setup.sh
- Installs and configures monitoring stack components
- Sets up Elasticsearch, Grafana, Kibana, and Logstash
- Configures data sources and dashboards
- Enables and starts services

### maintenance_daily.sh
- Checks system service status (warewulfd, slurmctld, etc.)
- Monitors disk space and system resources
- Rotates logs and cleans up temporary files
- Performs health checks on cluster components

### backup.sh
- Creates comprehensive backups of monitoring data
- Backs up Elasticsearch indices, Grafana dashboards, configurations
- Compresses and stores backups with timestamps
- Maintains backup retention policy

### security_scan.sh
- Installs and runs security auditing tools
- Performs system hardening checks with Lynis
- Scans for rootkits with rkhunter
- Runs antivirus scans with ClamAV

## Configuration

Scripts use configuration from `src/shell/config/monitoring.conf` for:
- Service enablement flags
- Backup locations and retention
- Security scan parameters
- Monitoring stack versions

## Dependencies

- Library functions from `src/shell/lib/functions.sh`
- Configuration loading from `src/shell/lib/config.sh`
- Monitoring configuration from `src/shell/config/monitoring.conf`

## Support

For maintenance script issues:
- Documentation: `docs/development/maintenance.md`
- Issues: https://github.com/ttu-hpc/Mini-HPC-Setup/issues 