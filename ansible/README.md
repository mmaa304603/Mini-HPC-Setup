# HPC Cluster Ansible Automation

This directory contains Ansible playbooks and roles for automating the setup of an HPC cluster using Rocky Linux, Warewulf, and SLURM.

## Prerequisites

1. Ansible installed on the control machine
2. Rocky Linux 8 installed on the head node
3. Network connectivity between the head node and compute nodes
4. SSH access to all nodes

## Directory Structure

```
ansible/
├── inventory/
│   └── hosts.yml
├── roles/
│   ├── warewulf/
│   │   ├── tasks/
│   │   ├── templates/
│   │   └── handlers/
│   └── slurm/
│       ├── tasks/
│       ├── templates/
│       └── handlers/
└── site.yml
```

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