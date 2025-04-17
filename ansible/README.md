# Ansible Installation

This directory contains Ansible playbooks and roles for automating the HPC cluster setup.

## Prerequisites

Before using Ansible, ensure you have:
1. Rocky Linux 9.5 installed on the head node
2. Network connectivity between head node and compute nodes
   - Head node: 10.0.0.1
   - Compute nodes: 10.0.2.x (permanent IPs)
3. Warewulf 4.6 installed and configured on the head node
4. Compute nodes booted and accessible via SSH

## Installation Steps

1. **Initial Setup**: Install Rocky Linux 9.5 on the head node (manual step)

2. **Ansible Installation**: Install Ansible on the head node (this is the control machine)
   ```bash
   dnf install -y ansible
   ```

3. **Head Node Network Setup**: Configure the head node's network interface
   ```bash
   cd HPC-Setup/shell
   # This step configures the head node's network interface (enp2s0) with:
   # - Static IP (10.0.0.1)
   # - Network mask (/22)
   # - Disable NetworkManager for the provisioning interface
   ./setup.sh --step network
   ```

4. **Warewulf Setup**: Install and configure Warewulf 4.6 on the head node
   ```bash
   # This step will:
   # - Install Warewulf 4.6
   # - Configure DHCP server for PXE boot (10.0.1.x range)
   # - Set up TFTP and HTTP services
   # - Configure container image
   ./setup.sh --step warewulf
   ```

5. **Compute Node Provisioning**: Boot the compute nodes using PXE (manual step)
   - Power on the compute nodes
   - They will receive temporary IPs (10.0.1.x) via DHCP
   - Download PXE boot files via TFTP
   - Warewulf will provision them with the container image
   - Warewulf will assign permanent IPs (10.0.2.x)
   - Nodes will reboot with their permanent IPs

6. **SSH Configuration**: After compute nodes are booted, configure SSH access
   ```bash
   # Generate SSH keys on the head node if not already done
   ssh-keygen -t rsa -b 4096
   
   # Copy SSH keys to compute nodes
   for node in compute{1..3}; do
     ssh-copy-id $node
   done
   ```

7. **Ansible Inventory Setup**: Configure the inventory file
   ```bash
   cd ../ansible
   # Edit inventory/hosts.yml to match your node configuration
   ```

8. **Ansible Deployment**: Use Ansible to deploy the remaining software
   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml
   ```

## Directory Structure

```
ansible/
├── inventory/            # Inventory files
├── group_vars/           # Group variables
├── roles/                # Ansible roles
│   ├── apptainer/        # Apptainer container role
│   ├── checkpoint/       # Checkpoint management role
│   ├── elk/              # ELK stack role
│   ├── grafana/          # Grafana role
│   ├── modules/          # Environment modules role
│   ├── monitoring/       # Monitoring role
│   ├── slurm/            # SLURM role
│   ├── spack/            # Spack role
│   ├── squid/            # Squid proxy role
│   └── warewulf/         # Warewulf role
├── site.yml              # Main playbook
└── monitoring.yml        # Monitoring playbook
```

## Ansible Roles

The project includes the following Ansible roles:

- **apptainer**: Installs and configures Apptainer container runtime
- **checkpoint**: Manages installation checkpoints
- **elk**: Deploys the ELK stack for log management
- **grafana**: Sets up Grafana for metrics visualization
- **modules**: Configures Environment Modules
- **monitoring**: Sets up the monitoring infrastructure
- **slurm**: Installs and configures SLURM job scheduler
- **spack**: Installs and configures Spack package manager
- **squid**: Sets up the Squid proxy server
- **warewulf**: Configures Warewulf provisioning

## Ansible Variables

Key variables can be customized in the following locations:
- `group_vars/all.yml`: Common variables for all nodes
- `group_vars/headnode.yml`: Head node specific variables
- `group_vars/compute.yml`: Compute node specific variables
- Role-specific variables in `roles/<role>/defaults/main.yml`

## Configuration

1. Update the inventory file `inventory/hosts.yml` with your actual node IP addresses
2. Review and adjust the Warewulf configuration in `roles/warewulf/templates/warewulf.conf.j2`
3. Review and adjust the SLURM configuration in `roles/slurm/templates/slurm.conf.j2`

## Usage

1. Test the connection to all nodes:
   ```bash
   ansible all -i inventory/hosts.yml -m ping
   ```

2. Run the playbook:
   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml
   ```

## Post-Installation

After the playbook completes:

1. Verify Warewulf is running on the head node:
   ```bash
   systemctl status warewulfd
   ```

2. Verify SLURM is running:
   ```bash
   sinfo
   squeue
   ```

3. Test job submission:
   ```bash
   srun --partition=compute hostname
   ``` 