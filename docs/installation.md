# Installation Guide

This document provides detailed installation instructions for the HPC cluster setup.

## Prerequisites

Before starting the installation, ensure you have:

1. **Hardware Requirements**
   - Head node with SSD storage
   - 3 compute nodes (Radax X2L)
   - Gigabit Ethernet network
   - Minimum 4GB RAM per node
   - Minimum 20GB free disk space on head node

2. **Network Requirements**
   - Static IP for head node (10.0.0.1)
   - DHCP range for compute nodes (10.0.1.1 - 10.0.1.255)
   - Network interface for provisioning (enp2s0)

3. **Base OS**
   - Rocky Linux 9.5 installed on head node
   - x86_64 architecture

## Installation Methods

### 1. Shell Script Installation

The shell script installation method provides step-by-step control over the installation process.

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/HPC-Setup.git
   cd HPC-Setup
   ```

2. **Configure Network**
   - Edit `shell/config/network.conf`
   - Set appropriate IP addresses and network interfaces
   - Configure DHCP and TFTP settings

3. **Run Setup Script**
   ```bash
   cd shell
   ./setup.sh
   ```

4. **Verify Installation**
   ```bash
   # Check Warewulf status
   wwctl node list
   
   # Check SLURM status
   sinfo
   
   # Check Spack installation
   spack find
   ```

### 2. Ansible Installation

The Ansible installation method provides automated deployment.

1. **Prepare Inventory**
   - Edit `ansible/inventory/hosts`
   - Add your nodes with appropriate groups

2. **Configure Variables**
   - Edit `ansible/group_vars/all.yml`
   - Set required variables for your environment

3. **Run Playbook**
   ```bash
   cd ansible
   ansible-playbook -i inventory/hosts site.yml
   ```

4. **Verify Installation**
   ```bash
   # Check all services
   ansible-playbook -i inventory/hosts verify.yml
   ```

## Component Installation Order

1. **Base System**
   - Network configuration
   - System updates
   - Basic utilities

2. **Warewulf**
   - Install Warewulf 4.6
   - Configure provisioning
   - Create container image

3. **SLURM**
   - Install SLURM
   - Configure partitions
   - Set up job accounting

4. **Spack and Modules**
   - Install Spack
   - Configure environment modules
   - Install required packages

5. **Monitoring Stack**
   - ELK stack
   - Grafana
   - Filebeat

6. **Additional Components**
   - Squid proxy
   - Apptainer
   - GitLab CI

## Post-Installation

1. **Verify Services**
   ```bash
   # Check service status
   systemctl status warewulf
   systemctl status slurmctld
   systemctl status elasticsearch
   systemctl status grafana-server
   ```

2. **Configure Firewall**
   ```bash
   # Allow required ports
   firewall-cmd --permanent --add-port=6817/tcp  # SLURM
   firewall-cmd --permanent --add-port=5601/tcp  # Kibana
   firewall-cmd --permanent --add-port=3000/tcp  # Grafana
   firewall-cmd --reload
   ```

3. **Set Up Monitoring**
   - Access Kibana: http://headnode:5601
   - Access Grafana: http://headnode:3000
   - Configure dashboards and alerts

4. **Configure Benchmarks**
   - Set up GitLab CI
   - Configure Microsoft Teams webhook
   - Schedule benchmark runs

## Troubleshooting

### Common Issues

1. **Network Issues**
   - Check network interface configuration
   - Verify DHCP server status
   - Check TFTP server logs

2. **Warewulf Issues**
   - Check container image status
   - Verify node provisioning
   - Check Warewulf logs

3. **SLURM Issues**
   - Check node status
   - Verify partition configuration
   - Check SLURM logs

### Log Files

- Warewulf logs: `/var/log/warewulf/`
- SLURM logs: `/var/log/slurm/`
- ELK logs: `/var/log/elasticsearch/`
- Grafana logs: `/var/log/grafana/`

## Next Steps

1. **User Management**
   - Create user accounts
   - Set up home directories
   - Configure user quotas

2. **Application Installation**
   - Install required applications
   - Create module files
   - Test applications

3. **Performance Tuning**
   - Optimize network settings
   - Tune SLURM parameters
   - Configure resource limits 