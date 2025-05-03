# Backup and Recovery Guide

This document provides procedures for backing up and recovering the HPC cluster.

## Backup Procedures

### Configuration Backup
```bash
# Create backup directory
mkdir -p /backup/config

# Backup configuration files
tar -czf /backup/config/config-$(date +%Y%m%d).tar.gz /etc

# Backup Warewulf configuration
tar -czf /backup/config/warewulf-$(date +%Y%m%d).tar.gz /etc/warewulf

# Backup SLURM configuration
tar -czf /backup/config/slurm-$(date +%Y%m%d).tar.gz /etc/slurm

# Backup Globus configuration
tar -czf /backup/config/globus-$(date +%Y%m%d).tar.gz /etc/globus-connect-server
```

### Data Backup
```bash
# Create backup directory
mkdir -p /backup/data

# Backup user data
rsync -avz --delete /home /backup/data/home-$(date +%Y%m%d)

# Backup shared data
rsync -avz --delete /shared /backup/data/shared-$(date +%Y%m%d)

# Backup scratch data
rsync -avz --delete /scratch /backup/data/scratch-$(date +%Y%m%d)
```

### System State Backup
```bash
# Create backup directory
mkdir -p /backup/system

# Stop services
systemctl stop warewulfd
systemctl stop slurmctld
systemctl stop globus-connect-server

# Backup system state
tar -czf /backup/system/system-$(date +%Y%m%d).tar.gz \
  /var/lib/warewulf \
  /var/lib/slurm \
  /var/lib/globus-connect-server

# Start services
systemctl start warewulfd
systemctl start slurmctld
systemctl start globus-connect-server
```

### Database Backup
```bash
# Create backup directory
mkdir -p /backup/database

# Backup Elasticsearch
elasticsearch-backup /backup/database/elasticsearch-$(date +%Y%m%d)

# Backup Grafana
grafana-backup /backup/database/grafana-$(date +%Y%m%d)
```

## Recovery Procedures

### Configuration Recovery
```bash
# Stop services
systemctl stop warewulfd
systemctl stop slurmctld
systemctl stop globus-connect-server

# Restore configuration
tar -xzf /backup/config/config-$(date +%Y%m%d).tar.gz -C /
tar -xzf /backup/config/warewulf-$(date +%Y%m%d).tar.gz -C /
tar -xzf /backup/config/slurm-$(date +%Y%m%d).tar.gz -C /
tar -xzf /backup/config/globus-$(date +%Y%m%d).tar.gz -C /

# Start services
systemctl start warewulfd
systemctl start slurmctld
systemctl start globus-connect-server
```

### Data Recovery
```bash
# Restore user data
rsync -avz --delete /backup/data/home-$(date +%Y%m%d) /home

# Restore shared data
rsync -avz --delete /backup/data/shared-$(date +%Y%m%d) /shared

# Restore scratch data
rsync -avz --delete /backup/data/scratch-$(date +%Y%m%d) /scratch
```

### System State Recovery
```bash
# Stop services
systemctl stop warewulfd
systemctl stop slurmctld
systemctl stop globus-connect-server

# Restore system state
tar -xzf /backup/system/system-$(date +%Y%m%d).tar.gz -C /

# Start services
systemctl start warewulfd
systemctl start slurmctld
systemctl start globus-connect-server
```

### Database Recovery
```bash
# Stop services
systemctl stop elasticsearch
systemctl stop grafana-server

# Restore databases
elasticsearch-restore /backup/database/elasticsearch-$(date +%Y%m%d)
grafana-restore /backup/database/grafana-$(date +%Y%m%d)

# Start services
systemctl start elasticsearch
systemctl start grafana-server
```

## Backup Schedule

### Daily Backups
- Configuration files
- User data
- System logs
- Database incremental

### Weekly Backups
- Full system state
- Shared data
- Scratch data
- Database full

### Monthly Backups
- Complete system backup
- Archive old backups
- Verify backup integrity
- Test recovery procedures

## Backup Verification

### Configuration Verification
```bash
# Verify configuration backup
tar -tvf /backup/config/config-$(date +%Y%m%d).tar.gz

# Verify service configuration
systemctl status warewulfd
systemctl status slurmctld
systemctl status globus-connect-server
```

### Data Verification
```bash
# Verify data backup
rsync -n -avz /home /backup/data/home-$(date +%Y%m%d)

# Check file integrity
find /home -type f -exec md5sum {} \; > /tmp/home.md5
find /backup/data/home-$(date +%Y%m%d) -type f -exec md5sum {} \; > /tmp/backup.md5
diff /tmp/home.md5 /tmp/backup.md5
```

### System Verification
```bash
# Verify system state
tar -tvf /backup/system/system-$(date +%Y%m%d).tar.gz

# Check service status
systemctl status warewulfd
systemctl status slurmctld
systemctl status globus-connect-server
```

### Database Verification
```bash
# Verify database backup
elasticsearch-verify /backup/database/elasticsearch-$(date +%Y%m%d)
grafana-verify /backup/database/grafana-$(date +%Y%m%d)

# Check database status
systemctl status elasticsearch
systemctl status grafana-server
```

## Backup Storage

### Local Storage
- Primary backup: /backup
- Secondary backup: /backup2
- Archive storage: /archive

### Remote Storage
- Cloud backup: s3://hpc-backup
- Offsite backup: rsync://backup.ttu.edu/hpc
- Disaster recovery: tape backup

## Backup Documentation

### Required Documentation
- Backup schedule
- Recovery procedures
- Verification procedures
- Storage locations
- Contact information

### Backup Contacts
- System Administrator: admin@ttu.edu
- Backup Team: backup@ttu.edu
- Emergency Contact: +1-806-742-0000 