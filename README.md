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
- Squid proxy server for caching and access control
- Apptainer for container management

## System Requirements

- Base OS: Rocky Linux 9.5
- CPU: x86_64 architecture
- Memory: Minimum 4GB RAM
- Storage: Minimum 20GB free disk space
- Network: Gigabit Ethernet
- Hardware: Radax X2L nodes (1 head node, 3 worker nodes)
- Storage: SSD only on head node, worker nodes boot via PXE

## Network Configuration

The internal network uses 10.0.0.0/22 with the following settings:

### Head Node
- IP: 10.0.0.1
- Provisioning interface: enp2s0
- DHCP server for initial PXE boot
- TFTP server for boot files
- HTTP server for container image

### Compute Nodes
The compute nodes go through a two-phase IP assignment process:

1. **Initial PXE Boot Phase (10.0.1.x)**
   - DHCP range: 10.0.1.1 - 10.0.1.255
   - Temporary IP assignment for PXE boot
   - Used only during initial boot and provisioning
   - Managed by DHCP server on head node

2. **Final Provisioned Phase (10.0.2.x)**
   - Permanent IP range: 10.0.2.1 - 10.0.2.255
   - Assigned by Warewulf during provisioning
   - Used for normal operation
   - Configured in Warewulf container

### Network Flow
1. Compute node powers on and requests DHCP address
2. Head node's DHCP server assigns temporary IP (10.0.1.x)
3. Node downloads PXE boot files via TFTP
4. Warewulf provisions the node with container image
5. Warewulf assigns permanent IP (10.0.2.x)
6. Node reboots with new permanent IP

## Project Structure

```
HPC-Setup/
├── ansible/                  # Ansible playbooks and roles
│   ├── inventory/            # Inventory files
│   ├── group_vars/           # Group variables
│   ├── roles/                # Ansible roles
│   │   ├── apptainer/        # Apptainer container role
│   │   ├── checkpoint/       # Checkpoint management role
│   │   ├── elk/              # ELK stack role
│   │   ├── grafana/          # Grafana role
│   │   ├── modules/          # Environment modules role
│   │   ├── monitoring/       # Monitoring role
│   │   ├── slurm/            # SLURM role
│   │   ├── spack/            # Spack role
│   │   ├── squid/            # Squid proxy role
│   │   └── warewulf/         # Warewulf role
│   ├── site.yml              # Main playbook
│   └── monitoring.yml        # Monitoring playbook
├── shell/                    # Shell scripts
│   ├── apptainer/            # Apptainer setup
│   ├── common/               # Common functions and utilities
│   ├── config/               # Configuration files
│   ├── elk/                  # ELK stack setup
│   ├── filebeat/             # Filebeat setup
│   ├── grafana/              # Grafana setup
│   ├── modules/              # Environment modules setup
│   ├── monitoring/           # Monitoring setup
│   ├── slurm/                # SLURM setup
│   ├── spack/                # Spack setup
│   ├── squid/                # Squid proxy setup
│   ├── utils/                # Utility scripts
│   ├── warewulf/             # Warewulf setup
│   └── setup.sh              # Main setup script
├── .gitlab-ci.yml            # GitLab CI configuration
└── README.md                 # This file
```

## Installation Methods

The project provides two installation methods:

1. **Shell Scripts**: Manual installation using shell scripts
   - See [Shell Script Installation](shell/README.md) for detailed instructions
   - Suitable for step-by-step installation and troubleshooting
   - Provides more control over the installation process

2. **Ansible**: Automated installation using Ansible
   - See [Ansible Installation](ansible/README.md) for detailed instructions
   - Suitable for automated deployment
   - Requires initial setup of Warewulf and node provisioning

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

This project is licensed under the BSD 3-Clause License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2025, billzyj

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.