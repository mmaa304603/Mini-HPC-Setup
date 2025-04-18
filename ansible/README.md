# Ansible Playbooks for HPC Setup

This directory contains Ansible playbooks and roles for setting up an HPC cluster. The setup is modular and can be customized through variables.

## Directory Structure

```
ansible/
├── inventory/       # Inventory files
│   └── hosts.yml   # Host definitions
├── roles/          # Ansible roles
│   ├── init/       # Initial system setup
│   ├── common/     # Common configurations
│   ├── network/    # Network setup
│   ├── slurm/      # SLURM setup
│   ├── spack/      # Spack setup
│   ├── monitoring/ # Monitoring setup
│   ├── squid/      # Squid setup
│   └── apptainer/  # Apptainer setup
└── vars/           # Variable definitions
    └── main.yml    # Main variables file
```

## Prerequisites

1. Install Ansible:
   ```bash
   sudo dnf install ansible
   ```

2. Install required collections:
   ```bash
   ansible-galaxy collection install community.general
   ```

## Inventory

The inventory file (`inventory/hosts.yml`) defines the cluster structure:

```yaml
all:
  children:
    headnode:
      hosts:
        headnode:
          ansible_host: 10.0.0.1
    computenodes:
      hosts:
        compute01:
          ansible_host: 10.0.1.1
        compute02:
          ansible_host: 10.0.1.2
        compute03:
          ansible_host: 10.0.1.3
```

## Variables

The main variables file (`vars/main.yml`) contains all configurable parameters:

- Network configuration
- SLURM settings
- Spack packages
- Monitoring configuration
- Squid settings
- Apptainer configuration

## Roles

### Init Role

Initial system setup:
- System updates
- Basic packages
- System configuration
- SELinux settings
- Firewall setup

### Common Role

Common configurations for all nodes:
- Directory structure
- Environment modules
- System limits
- Kernel parameters

### Network Role

Network configuration:
- Interface setup
- DHCP server
- Firewall rules
- NFS exports

### SLURM Role

SLURM setup:
- Package installation
- Configuration
- Accounting
- Partitions
- Services

### Spack Role

Spack setup:
- Installation
- Environment
- Packages
- Module system

### Monitoring Role

Monitoring stack:
- ELK installation
- Grafana setup
- Filebeat configuration
- Dashboards

### Squid Role

Squid proxy:
- Installation
- Cache configuration
- Access controls
- Logging

### Apptainer Role

Apptainer setup:
- Installation
- Cache configuration
- Bind paths
- Security settings

## Usage

1. Update inventory:
   ```bash
   # Edit inventory/hosts.yml with your node information
   ```

2. Update variables:
   ```bash
   # Edit vars/main.yml with your configuration
   ```

3. Run the playbook:
   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml
   ```

## Customization

### Adding New Nodes

1. Add node to inventory:
   ```yaml
   computenodes:
     hosts:
       newnode:
         ansible_host: 10.0.1.4
   ```

2. Run playbook:
   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml --limit newnode
   ```

### Modifying Configurations

1. Edit variables:
   ```bash
   # Edit vars/main.yml
   ```

2. Run specific role:
   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml --tags slurm
   ```

## Best Practices

1. Use version control for playbooks
2. Test changes in a non-production environment
3. Use tags for selective execution
4. Keep inventory and variables separate
5. Document custom configurations

## Troubleshooting

1. Check Ansible logs:
   ```bash
   ansible-playbook -i inventory/hosts.yml site.yml -vvv
   ```

2. Verify connectivity:
   ```bash
   ansible all -i inventory/hosts.yml -m ping
   ```

3. Check service status:
   ```bash
   ansible all -i inventory/hosts.yml -m service -a "name=slurmd state=started"
   ``` 