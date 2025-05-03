# Security Guide

This document provides security best practices for the HPC cluster.

## System Security

### Firewall Configuration
```bash
# Check current firewall rules
firewall-cmd --list-all

# Allow required services
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --add-service=dhcp
firewall-cmd --permanent --add-service=tftp
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https

# Reload firewall
firewall-cmd --reload
```

### SSH Security
```bash
# Configure SSH
cat > /etc/ssh/sshd_config << EOF
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AllowUsers admin
EOF

# Restart SSH
systemctl restart sshd
```

### SELinux Configuration
```bash
# Check SELinux status
sestatus

# Set SELinux mode
setenforce 1

# Configure SELinux policies
semanage port -a -t ssh_port_t -p tcp 22
```

## Authentication Security

### eRaider Integration
```bash
# Configure SSSD
cat > /etc/sssd/sssd.conf << EOF
[sssd]
domains = ttu.edu
config_file_version = 2
services = nss, pam

[domain/ttu.edu]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldaps://ldap.ttu.edu
ldap_search_base = dc=ttu,dc=edu
ldap_tls_reqcert = demand
EOF

# Set permissions
chmod 600 /etc/sssd/sssd.conf
```

### PAM Configuration
```bash
# Configure PAM
cat > /etc/pam.d/system-auth << EOF
auth        required      pam_env.so
auth        sufficient    pam_unix.so try_first_pass nullok
auth        sufficient    pam_sss.so use_first_pass
auth        required      pam_deny.so

account     required      pam_unix.so
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 1000 quiet
account     [default=bad success=ok user_unknown=ignore] pam_sss.so
account     required      pam_permit.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type=
password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok
password    sufficient    pam_sss.so use_authtok
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so
session     optional      pam_sss.so
EOF
```

## Network Security

### Network Isolation
```bash
# Configure VLAN
ip link add link enp2s0 name enp2s0.100 type vlan id 100
ip addr add 10.0.0.1/24 dev enp2s0.100
ip link set enp2s0.100 up
```

### SSL/TLS Configuration
```bash
# Generate SSL certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/globus.key \
  -out /etc/ssl/certs/globus.crt

# Configure SSL
cat > /etc/ssl/globus.conf << EOF
ssl_cert_file = /etc/ssl/certs/globus.crt
ssl_key_file = /etc/ssl/private/globus.key
ssl_ca_file = /etc/ssl/certs/ca-bundle.crt
EOF
```

## Data Security

### File Permissions
```bash
# Set home directory permissions
chmod 700 /home/*
chown -R user:group /home/*

# Set shared directory permissions
chmod 755 /shared
chown root:users /shared
```

### Backup Security
```bash
# Configure backup encryption
cat > /etc/backup/encryption.conf << EOF
encryption_method = aes-256-cbc
encryption_key = /etc/backup/key
EOF

# Set backup permissions
chmod 600 /etc/backup/encryption.conf
chmod 600 /etc/backup/key
```

## Monitoring Security

### Audit Logging
```bash
# Configure audit rules
cat > /etc/audit/rules.d/audit.rules << EOF
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity
-w /var/log/auth.log -p wa -k authentication
EOF

# Restart audit service
systemctl restart auditd
```

### Security Scanning
```bash
# Install security tools
dnf install -y lynis rkhunter

# Run security scan
lynis audit system
rkhunter --check
```

## Incident Response

### Security Incident Checklist
1. Identify the incident
2. Contain the incident
3. Eradicate the threat
4. Recover systems
5. Document lessons learned

### Emergency Procedures
```bash
# Emergency shutdown
systemctl stop warewulfd
systemctl stop slurmctld
systemctl stop globus-connect-server
systemctl stop elasticsearch
systemctl stop grafana-server
```

## Regular Security Tasks

### Daily Tasks
- Review system logs
- Check for failed login attempts
- Monitor network traffic
- Verify backup status

### Weekly Tasks
- Update security patches
- Review user accounts
- Check file permissions
- Run security scans

### Monthly Tasks
- Review security policies
- Update firewall rules
- Rotate encryption keys
- Test backup recovery

## Security Documentation

### Required Documentation
- Security policies
- Incident response procedures
- Backup and recovery procedures
- User access policies

### Security Contacts
- System Administrator: admin@ttu.edu
- Security Team: security@ttu.edu
- Emergency Contact: +1-806-742-0000 