#!/bin/bash

# Source common utilities
source "$(dirname "$0")/../../common/utils/logging.sh"
source "$(dirname "$0")/../../common/utils/error.sh"
source "$(dirname "$0")/../../common/utils/validation.sh"

# Source library scripts
source "$(dirname "$0")/../lib/config.sh"
source "$(dirname "$0")/../lib/functions.sh"

# Source configuration
source "$(dirname "$0")/../config/core/config.sh"
source "$(dirname "$0")/../config/setup/config.sh"

# Security scanning script

# Install security tools
echo "Installing security tools..."
dnf install -y lynis rkhunter clamav

# Run Lynis audit
echo "Running Lynis audit..."
lynis audit system

# Run Rootkit Hunter
echo "Running Rootkit Hunter..."
rkhunter --check

# Run ClamAV scan
echo "Running ClamAV scan..."
freshclam
clamscan -r / --exclude-dir="^/sys" --exclude-dir="^/proc" --exclude-dir="^/dev"

# Check for open ports
echo "Checking for open ports..."
netstat -tuln

# Check firewall rules
echo "Checking firewall rules..."
firewall-cmd --list-all

# Check user accounts
echo "Checking user accounts..."
awk -F: '($3 < 1000) {print}' /etc/passwd

# Check sudo access
echo "Checking sudo access..."
grep -v '^#' /etc/sudoers

# Check file permissions
echo "Checking file permissions..."
find / -type f -perm -4000 -ls
find / -type f -perm -2000 -ls

# Check SSH configuration
echo "Checking SSH configuration..."
sshd -T

# Check SELinux status
echo "Checking SELinux status..."
sestatus

# Check audit logs
echo "Checking audit logs..."
ausearch -m AVC -ts today

# Check system logs
echo "Checking system logs..."
journalctl -p err..alert

# Check for suspicious processes
echo "Checking for suspicious processes..."
ps aux | grep -E '[s]shd|httpd|apache|nginx|mysql|postgres'

# Check for suspicious files
echo "Checking for suspicious files..."
find / -type f -name "*.php" -o -name "*.pl" -o -name "*.py" -o -name "*.sh" -o -name "*.cgi"

# Check for world-writable files
echo "Checking for world-writable files..."
find / -type f -perm -2 -ls

# Check for SUID/SGID files
echo "Checking for SUID/SGID files..."
find / -type f -perm -4000 -o -perm -2000 -ls

# Check for hidden files
echo "Checking for hidden files..."
find / -name ".*" -ls

# Check for suspicious cron jobs
echo "Checking for suspicious cron jobs..."
for user in $(cut -f1 -d: /etc/passwd); do crontab -u $user -l 2>/dev/null; done

# Check for suspicious network connections
echo "Checking for suspicious network connections..."
netstat -anp | grep -i listen
netstat -anp | grep -i established

# Generate security report
echo "Generating security report..."
{
    echo "Security Scan Report - $(date)"
    echo "============================="
    echo
    echo "1. System Information"
    uname -a
    echo
    echo "2. Open Ports"
    netstat -tuln
    echo
    echo "3. Firewall Rules"
    firewall-cmd --list-all
    echo
    echo "4. User Accounts"
    awk -F: '($3 < 1000) {print}' /etc/passwd
    echo
    echo "5. Sudo Access"
    grep -v '^#' /etc/sudoers
    echo
    echo "6. File Permissions"
    find / -type f -perm -4000 -ls
    echo
    echo "7. SSH Configuration"
    sshd -T
    echo
    echo "8. SELinux Status"
    sestatus
    echo
    echo "9. Audit Logs"
    ausearch -m AVC -ts today
    echo
    echo "10. System Logs"
    journalctl -p err..alert
} > /var/log/security_scan_$(date +%Y%m%d).log

echo "Security scan completed successfully" 