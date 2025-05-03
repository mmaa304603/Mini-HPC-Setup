# Maintenance Guide

This document provides procedures for regular maintenance of the HPC cluster.

## Daily Maintenance

### System Checks
```bash
# Check system status
systemctl status warewulfd
systemctl status slurmctld
systemctl status sssd
systemctl status globus-connect-server
systemctl status elasticsearch
systemctl status grafana-server

# Check disk space
df -h

# Check memory usage
free -h

# Check load average
uptime
```

### Log Review
```bash
# Check system logs
journalctl -S today

# Check service logs
tail -f /var/log/messages
tail -f /var/log/secure
```

## Weekly Maintenance

### Backup Procedures
```bash
# Backup configuration files
tar -czf /backup/config-$(date +%Y%m%d).tar.gz /etc

# Backup user data
rsync -avz /home /backup/home-$(date +%Y%m%d)

# Backup system state
systemctl stop warewulfd
systemctl stop slurmctld
tar -czf /backup/system-$(date +%Y%m%d).tar.gz /var/lib/warewulf /var/lib/slurm
systemctl start warewulfd
systemctl start slurmctld
```

### System Updates
```bash
# Update system packages
dnf update -y

# Update Spack packages
spack update

# Update container images
wwctl container build rocky9
```

## Monthly Maintenance

### Performance Optimization
```bash
# Clean temporary files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clean old logs
find /var/log -type f -name "*.log" -mtime +30 -delete

# Optimize databases
elasticsearch-optimize
```

### Security Updates
```bash
# Update security packages
dnf update --security -y

# Run security scan
lynis audit system

# Check for vulnerabilities
rkhunter --check
```

## Quarterly Maintenance

### Hardware Checks
```bash
# Check disk health
smartctl -a /dev/sda

# Check memory
memtest86+

# Check network
iperf3 -s
```

### System Reboot
```bash
# Schedule maintenance window
systemctl stop warewulfd
systemctl stop slurmctld
systemctl stop globus-connect-server
systemctl stop elasticsearch
systemctl stop grafana-server

# Reboot system
reboot

# Verify services
systemctl start warewulfd
systemctl start slurmctld
systemctl start globus-connect-server
systemctl start elasticsearch
systemctl start grafana-server
```

## Annual Maintenance

### Documentation Update
```bash
# Update system documentation
cd /docs
git pull
./update-docs.sh

# Update user documentation
cd /docs/user
./update-user-docs.sh
```

### License Renewal
```bash
# Check license status
slurm-license-check

# Renew licenses
slurm-license-renew
```

## Emergency Procedures

### System Recovery
```bash
# Stop all services
systemctl stop warewulfd
systemctl stop slurmctld
systemctl stop globus-connect-server
systemctl stop elasticsearch
systemctl stop grafana-server

# Restore from backup
tar -xzf /backup/system-$(date +%Y%m%d).tar.gz -C /

# Start services
systemctl start warewulfd
systemctl start slurmctld
systemctl start globus-connect-server
systemctl start elasticsearch
systemctl start grafana-server
```

### Data Recovery
```bash
# Restore user data
rsync -avz /backup/home-$(date +%Y%m%d) /home

# Restore configuration
tar -xzf /backup/config-$(date +%Y%m%d).tar.gz -C /
```

## Maintenance Schedule

### Daily Tasks
- System status check
- Log review
- Disk space check
- Service status verification

### Weekly Tasks
- Configuration backup
- User data backup
- System updates
- Log rotation

### Monthly Tasks
- Performance optimization
- Security updates
- Database maintenance
- Temporary file cleanup

### Quarterly Tasks
- Hardware health check
- System reboot
- Network performance test
- Security audit

### Annual Tasks
- Documentation update
- License renewal
- Hardware inventory
- Performance review

## Maintenance Logs

### Required Documentation
- Maintenance schedule
- Service logs
- Backup logs
- Update logs
- Incident reports

### Maintenance Contacts
- System Administrator: admin@ttu.edu
- Support Team: support@ttu.edu
- Emergency Contact: +1-806-742-0000 