# Troubleshooting Guide

This document provides solutions for common issues encountered during HPC cluster operation.

## Network Issues

### DHCP Server Not Starting
```bash
# Check DHCP service status
systemctl status dhcpd

# Check DHCP logs
journalctl -u dhcpd

# Verify DHCP configuration
cat /etc/dhcp/dhcpd.conf
```

### TFTP Server Issues
```bash
# Check TFTP service status
systemctl status tftpd

# Verify TFTP directory permissions
ls -la /var/lib/tftpboot

# Check TFTP logs
journalctl -u tftpd
```

## Warewulf Issues

### Node Provisioning Fails
```bash
# Check node status
wwctl node list

# Check VNFS status
wwctl vnfs list

# Check Warewulf logs
journalctl -u warewulfd
```

### Container Image Issues
```bash
# Check container status
wwctl container list

# Verify container files
ls -la /var/lib/warewulf/container/

# Check container logs
journalctl -u warewulfd | grep container
```

## SLURM Issues

### Node Not Responding
```bash
# Check node status
sinfo

# Check node details
scontrol show node <node_name>

# Check SLURM logs
tail -f /var/log/slurm/slurmd.log
```

### Job Submission Fails
```bash
# Check job status
squeue

# Check job details
scontrol show job <job_id>

# Check accounting logs
tail -f /var/log/slurm/slurm_jobacct.log
```

## eRaider Authentication Issues

### Login Fails
```bash
# Check SSSD status
systemctl status sssd

# Check domain status
sssctl domain-status ttu.edu

# Check authentication logs
tail -f /var/log/sssd/sssd.log
```

### Home Directory Issues
```bash
# Check home directory permissions
ls -la /home/<username>

# Check PAM configuration
cat /etc/pam.d/system-auth

# Check NSS configuration
cat /etc/nsswitch.conf
```

## Globus Issues

### Endpoint Not Responding
```bash
# Run self-diagnostic
globus-connect-server self-diagnostic

# Check endpoint status
globus endpoint show HPC\ Cluster

# Check service status
systemctl status globus-connect-server
```

### File Transfer Issues
```bash
# Check storage gateway
globus-connect-server storage-gateway list

# Check mapped collections
globus-connect-server mapped-collections list

# Check transfer logs
tail -f /var/log/globus-connect-server/transfer.log
```

## Spack Issues

### Package Installation Fails
```bash
# Check Spack configuration
spack config get

# Check package details
spack info <package_name>

# Check build logs
spack install --verbose <package_name>
```

### Module Loading Issues
```bash
# Check module path
echo $MODULEPATH

# Check module files
ls -la /opt/modules/

# Check module logs
tail -f /var/log/modules.log
```

## Monitoring Issues

### ELK Stack Issues
```bash
# Check Elasticsearch status
systemctl status elasticsearch

# Check Kibana status
systemctl status kibana

# Check Logstash status
systemctl status logstash
```

### Grafana Issues
```bash
# Check Grafana status
systemctl status grafana-server

# Check Grafana logs
tail -f /var/log/grafana/grafana.log

# Check dashboard configuration
ls -la /etc/grafana/provisioning/dashboards/
```

## Common Solutions

### Service Restart
```bash
# Restart service
systemctl restart <service_name>

# Check service status
systemctl status <service_name>

# Check service logs
journalctl -u <service_name>
```

### Configuration Verification
```bash
# Check configuration files
ls -la /etc/<service_name>/

# Verify configuration
<service_name> --verify-config

# Check configuration logs
tail -f /var/log/<service_name>/config.log
```

### Network Verification
```bash
# Check network interface
ip addr show

# Check routing table
ip route show

# Check firewall rules
firewall-cmd --list-all
```

## Log Files Location

- Warewulf: `/var/log/warewulf/`
- SLURM: `/var/log/slurm/`
- SSSD: `/var/log/sssd/`
- Globus: `/var/log/globus-connect-server/`
- Spack: `/var/log/spack/`
- ELK: `/var/log/elasticsearch/`, `/var/log/kibana/`, `/var/log/logstash/`
- Grafana: `/var/log/grafana/`
- System: `/var/log/messages` 