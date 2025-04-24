# HPC Cluster Setup

This repository contains scripts and configurations for setting up a High-Performance Computing (HPC) cluster using Rocky Linux 9.5. The setup includes SLURM workload manager, Spack package manager, monitoring tools, and container support.

## Components

- **Network Setup**: Configuration of network interfaces, DHCP, and firewall rules
- **SLURM**: Job scheduling and resource management
- **Spack**: Package management and software installation
- **Monitoring**: ELK stack (Elasticsearch, Logstash, Kibana) and Grafana
- **Squid**: HTTP proxy for package caching
- **Apptainer**: Container runtime for HPC workloads

## Prerequisites

- Rocky Linux 9.5
- Root access
- Minimum system requirements:
  - 20GB disk space
  - 4GB RAM
  - 2 CPU cores
- Network interface (default: enp2s0)

## Directory Structure

```
.
├── ansible/              # Ansible playbooks and roles
│   ├── inventory/       # Inventory files
│   ├── roles/          # Ansible roles
│   └── vars/           # Variable definitions
├── shell/              # Shell scripts
│   ├── common/         # Common functions and configs
│   ├── network/        # Network setup scripts
│   ├── slurm/          # SLURM setup scripts
│   ├── spack/          # Spack setup scripts
│   ├── monitoring/     # Monitoring setup scripts
│   ├── squid/          # Squid setup scripts
│   ├── apptainer/      # Apptainer setup scripts
│   └── utils/          # Utility scripts
└── docs/               # Documentation
```

## Installation

### Using Shell Scripts

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/hpc-setup.git
   cd hpc-setup
   ```

2. Run the setup script:
   ```bash
   sudo ./shell/setup.sh
   ```

   Available options:
   - `--step <component>`: Install specific component (network, slurm, spack, monitoring, squid, apptainer)
   - `--list-checkpoints`: List available checkpoints
   - `--clear-checkpoint <name>`: Clear specific checkpoint
   - `--clear-all-checkpoints`: Clear all checkpoints

### Using Ansible

1. Install Ansible:
   ```bash
   sudo dnf install ansible
   ```

2. Run the playbook:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml
   ```

## Configuration

### Network Configuration

- Interface: enp2s0
- Head node IP: 10.0.0.1
- Network mask: 255.255.252.0
- DHCP range: 10.0.1.1 - 10.0.1.255

### SLURM Configuration

- Cluster name: hpc-cluster
- Default partition: normal
- Accounting enabled
- Max jobs: 10000
- Max jobs per user: 1000

### Spack Configuration

- Installation directory: /opt/spack
- Configuration directory: /etc/spack
- System-wide environment: /etc/profile.d/spack.sh
- Default packages:
  - openmpi
  - mpich
  - hpl
  - osu-micro-benchmarks
  - stream
  - cmake
  - gcc

#### System-Level Spack Installation

This project provides two methods for installing Spack at the system level:

1. **Shell Scripts**:
   - `scripts/install_system_spack.sh`: Installs Spack in `/opt/spack`
   - `scripts/setup_system_spack_config.sh`: Configures system-wide Spack settings in `/etc/spack`

   Usage:
   ```bash
   # Install Spack
   sudo ./scripts/install_system_spack.sh
   
   # Configure Spack
   sudo ./scripts/setup_system_spack_config.sh
   ```

2. **Ansible Role**:
   - The `spack` role in `ansible/roles/spack/` handles system-level installation
   - Automatically configures compilers, packages, and environment modules
   - Creates system-wide environment file in `/etc/profile.d/spack.sh`

   Usage:
   ```bash
   # Run the playbook with the spack tag
   ansible-playbook -i ansible/inventory/hosts.yml ansible/site.yml --tags spack
   ```

#### Spack Configuration Files

The following configuration files are created in `/etc/spack/`:

- `config.yaml`: General Spack configuration
- `compilers.yaml`: System compiler definitions
- `packages.yaml`: Package preferences and external packages
- `modules.yaml`: Module file generation settings
- `spack.yaml`: Environment-specific settings

#### User Access

After installation, users need to either:
1. Log out and log back in
2. Run `source /etc/profile.d/spack.sh`

This will make Spack available in their environment.

#### Customizing Spack

To customize the Spack installation:

1. **Shell Scripts**: Edit the variables at the top of the installation scripts
2. **Ansible**: Modify the variables in `ansible/roles/spack/defaults/main.yml`

Common customizations include:
- Adding more packages to install
- Configuring additional compilers
- Setting up external packages
- Adjusting build parameters

### Monitoring Configuration

- Elasticsearch: Port 9200
- Kibana: Port 5601
- Grafana: Port 3000
- Logstash: Port 5044 (beats)

### Squid Configuration

- Port: 3128
- Cache size: 10000 MB
- Max object size: 4096 KB

### Apptainer Configuration

- Installation directory: /opt/apptainer
- Cache directory: /opt/apptainer/cache
- Bind paths:
  - /scratch
  - /opt/software
  - /opt/modules

## Usage

### SLURM

1. Submit a job:
   ```bash
   srun --partition=normal --time=01:00:00 ./your_program
   ```

2. Check job status:
   ```bash
   squeue
   ```

### Spack

1. Install a package:
   ```bash
   spack install package_name
   ```

2. Load a package:
   ```bash
   spack load package_name
   ```

### Monitoring

1. Access Kibana:
   ```
   http://headnode:5601
   ```

2. Access Grafana:
   ```
   http://headnode:3000
   ```

## Troubleshooting

1. Check logs:
   ```bash
   tail -f /var/log/slurm/slurm_jobacct.log
   ```

2. Verify services:
   ```bash
   systemctl status slurmctld
   systemctl status slurmd
   ```

3. Check network:
   ```bash
   ip addr show enp2s0
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.