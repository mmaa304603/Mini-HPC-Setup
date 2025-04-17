# HPC-Setup

This project provides tools to build an HPC cluster from scratch using Rocky Linux 9.5 as the base OS.

## Overview

The project supports building a mini HPC cluster with the following components:
- One head node with SSD storage
- Three compute nodes that PXE boot from the head node
- Warewulf 4.6 for provisioning
- SLURM for job scheduling
- Spack + Environment Modules for package management
- ELK stack and Grafana for monitoring
- GitLab CI for automated benchmarking

## Network Configuration

The internal network uses 10.0.0.0/22 with the following settings:
- Head node IP: 10.0.0.1
- DHCP interface: enp2s0
- DHCP range: 10.0.1.1 - 10.0.1.255

## Project Structure

```
HPC-Setup/
├── ansible/                  # Ansible playbooks and roles
│   ├── inventory/            # Inventory files
│   ├── roles/                # Ansible roles
│   └── site.yml              # Main playbook
├── shell/                    # Shell scripts
│   ├── common/               # Common functions and utilities
│   ├── config/               # Configuration files
│   ├── modules/              # Environment modules setup
│   ├── monitoring/           # Monitoring setup (ELK, Grafana)
│   ├── slurm/                # SLURM setup
│   ├── spack/                # Spack setup
│   ├── utils/                # Utility scripts
│   ├── warewulf/             # Warewulf setup
│   └── setup.sh              # Main setup script
├── .gitlab-ci.yml            # GitLab CI configuration
└── README.md                 # This file
```

## Installation Methods

### Shell Scripts

To install using shell scripts:

```bash
cd shell
./setup.sh --step all  # Run all steps
# Or run specific steps:
./setup.sh --step network
./setup.sh --step warewulf
./setup.sh --step slurm
./setup.sh --step spack
./setup.sh --step modules
./setup.sh --step monitoring
```

### Ansible

To install using Ansible:

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml site.yml
```

## Configuration

Configuration files are located in the `shell/config` directory. Edit these files to customize the installation:

- `network.conf`: Network configuration
- `warewulf.conf`: Warewulf configuration
- `slurm.conf`: SLURM configuration
- `spack.conf`: Spack configuration
- `monitoring.conf`: Monitoring configuration

## Monitoring

The monitoring stack includes:
- Elasticsearch: For log storage and search
- Logstash: For log processing
- Kibana: For log visualization
- Grafana: For metrics visualization
- Filebeat: For log collection

Access the monitoring dashboards at:
- Kibana: http://headnode:5601
- Grafana: http://headnode:3000

## Benchmarking

The project includes automated benchmarking using GitLab CI. The benchmarks include:
- HPL (High Performance Linpack)
- OSU Micro-Benchmarks
- STREAM

Results are sent to a Microsoft Teams channel.

## License

This project is licensed under the MIT License - see the LICENSE file for details.