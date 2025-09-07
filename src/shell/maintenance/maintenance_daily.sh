#!/bin/bash

# Source library scripts
source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../lib/config.sh"

# Load configuration
load_config "monitoring.conf"
export_config

# Daily maintenance script

# Check system status
echo "Checking system status..."
systemctl status warewulfd
systemctl status slurmctld
systemctl status sssd
systemctl status globus-connect-server
systemctl status elasticsearch
systemctl status grafana-server

# Check disk space
echo "Checking disk space..."
df -h

# Check memory usage
echo "Checking memory usage..."
free -h

# Check load average
echo "Checking load average..."
uptime

# Check system logs
echo "Checking system logs..."
journalctl -S today

# Check service logs
echo "Checking service logs..."
tail -f /var/log/messages
tail -f /var/log/secure

# Check network status
echo "Checking network status..."
ip addr show
ip route show
netstat -tuln

# Check firewall status
echo "Checking firewall status..."
firewall-cmd --list-all

# Check user accounts
echo "Checking user accounts..."
awk -F: '($3 < 1000) {print}' /etc/passwd

# Check file permissions
echo "Checking file permissions..."
find / -type f -perm -4000 -ls
find / -type f -perm -2000 -ls

# Check for updates
echo "Checking for updates..."
dnf check-update

# Check backup status
echo "Checking backup status..."
ls -la /backup/config
ls -la /backup/data
ls -la /backup/system

# Check monitoring status
echo "Checking monitoring status..."
curl -s http://localhost:9200/_cluster/health
curl -s http://localhost:5601/api/status
curl -s http://localhost:3000/api/health

# Check SLURM status
echo "Checking SLURM status..."
sinfo
squeue

# Check Warewulf status
echo "Checking Warewulf status..."
wwctl node list
wwctl vnfs list

# Check eRaider status
echo "Checking eRaider status..."
sssctl domain-status ttu.edu

# Check Globus status
echo "Checking Globus status..."
globus-connect-server self-diagnostic
globus endpoint show HPC\ Cluster

# Check Spack status
echo "Checking Spack status..."
spack find
spack config get

# Generate maintenance report
echo "Generating maintenance report..."
{
    echo "Daily Maintenance Report - $(date)"
    echo "============================="
    echo
    echo "1. System Status"
    systemctl status warewulfd
    systemctl status slurmctld
    systemctl status sssd
    systemctl status globus-connect-server
    systemctl status elasticsearch
    systemctl status grafana-server
    echo
    echo "2. Disk Space"
    df -h
    echo
    echo "3. Memory Usage"
    free -h
    echo
    echo "4. Load Average"
    uptime
    echo
    echo "5. Network Status"
    ip addr show
    ip route show
    netstat -tuln
    echo
    echo "6. Firewall Status"
    firewall-cmd --list-all
    echo
    echo "7. User Accounts"
    awk -F: '($3 < 1000) {print}' /etc/passwd
    echo
    echo "8. File Permissions"
    find / -type f -perm -4000 -ls
    echo
    echo "9. Updates Available"
    dnf check-update
    echo
    echo "10. Backup Status"
    ls -la /backup/config
    ls -la /backup/data
    ls -la /backup/system
    echo
    echo "11. Monitoring Status"
    curl -s http://localhost:9200/_cluster/health
    curl -s http://localhost:5601/api/status
    curl -s http://localhost:3000/api/health
    echo
    echo "12. SLURM Status"
    sinfo
    squeue
    echo
    echo "13. Warewulf Status"
    wwctl node list
    wwctl vnfs list
    echo
    echo "14. eRaider Status"
    sssctl domain-status ttu.edu
    echo
    echo "15. Globus Status"
    globus-connect-server self-diagnostic
    globus endpoint show HPC\ Cluster
    echo
    echo "16. Spack Status"
    spack find
    spack config get
} > /var/log/maintenance_$(date +%Y%m%d).log

echo "Daily maintenance completed successfully" 