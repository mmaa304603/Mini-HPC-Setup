# Warewulf Component

This directory contains the Warewulf provisioning system implementation for the Mini HPC Cluster Setup.

## Overview

Warewulf is a modern, scalable system provisioning tool that enables stateless computing for HPC clusters. It manages compute nodes through network booting, container-based provisioning, and centralized configuration management.

## Architecture

Unlike other components that require role-specific installation (like SLURM), Warewulf follows a **centralized management model**:

- **Head Node Only**: Warewulf is installed and runs exclusively on the head node
- **Stateless Compute Nodes**: Compute nodes boot from VNFS (Virtual Node File System) images
- **No Local Installation**: Compute nodes don't require local Warewulf installation
- **Centralized Configuration**: All node management happens from the head node

### Why No Role Splitting Needed

| Aspect | SLURM Component | Warewulf Component |
|--------|----------------|-------------------|
| **Installation** | Role-specific (head/gpu/cpu) | Head node only |
| **Compute Nodes** | Local installation required | Stateless (VNFS boot) |
| **Configuration** | Per-node configuration | Centralized management |
| **Splitting Strategy** | ✅ Split by role | ❌ Single management point |

## Files and Scripts

### Scripts

#### `install.sh` - Initial Installation
**Purpose:** Installs Warewulf and performs initial system setup.

**What it does:**
- Downloads and installs Warewulf RPM from GitHub releases
- Configures firewalld services (warewulf, dhcp, nfs, tftp)
- Creates initial Warewulf configuration from template
- Enables and starts required system services
- Sets up basic Warewulf infrastructure

**Usage:**
```bash
./install.sh
```

**When to run:** First time setup, or when reinstalling Warewulf.

#### `configure.sh` - Post-Installation Configuration
**Purpose:** Configures Warewulf after installation and manages ongoing operations.

**What it does:**
- Updates Warewulf configuration with network-specific values
- Creates or updates VNFS (Virtual Node File System) images
- Manages compute node configurations
- Handles node profiles and settings
- Provides ongoing configuration management

**Usage:**
```bash
./configure.sh
```

**When to run:** After installation, when updating configuration, or when adding new compute nodes.

### Configuration Files

#### `warewulf.conf` - Warewulf Configuration Template
**Purpose:** Template configuration file for Warewulf system settings.

**Configuration sections:**
- **Network settings:** IP address, netmask, network range
- **Warewulf service:** Port, security, update intervals
- **DHCP settings:** IP range for compute nodes
- **TFTP settings:** Boot file management
- **NFS settings:** Shared filesystem exports
- **Image mounts:** Container file system bindings
- **Paths:** System directories and service locations

**Key settings:**
```yaml
ipaddr: 10.0.0.1              # Head node IP
netmask: 255.255.252.0         # Network mask
network: 10.0.0.0              # Network address
dhcp:
  range start: 10.0.1.1        # DHCP start IP
  range end: 10.0.1.255        # DHCP end IP
warewulf:
  port: 9873                   # Warewulf service port
  secure: false                # Security settings
```

## Workflow

### Two-Phase Process

Unlike SLURM which requires separate installation on each node type, Warewulf follows a simpler two-phase approach:

#### Phase 1: Head Node Installation (One-time)
```bash
# Install Warewulf on head node only
./install.sh
```

#### Phase 2: VNFS Configuration (Ongoing)
```bash
# Configure VNFS images and compute nodes
./configure.sh
```

### Compute Node Lifecycle

- **No Local Installation**: Compute nodes don't need Warewulf installed locally
- **Network Boot**: Nodes boot from VNFS images over the network
- **Stateless Operation**: All configuration managed centrally from head node
- **Easy Management**: Add/remove/update nodes through head node configuration

### 2. Adding Compute Nodes
```bash
# Add a compute node
wwctl node add node01 --ipaddr=10.0.1.1 --discoverable=true

# Set node profile
wwctl node set node01 --profile default

# Configure node
wwctl node configure node01
```

### 3. Managing Images
```bash
# List available images
wwctl image list

# Build/rebuild image
wwctl image build rockylinux-9.6

# Set default profile image
wwctl profile set default --image rockylinux-9.6
```

## Network Architecture

```
Head Node (10.0.0.1)
├── Warewulf Service (Port 9873)
├── DHCP Server (10.0.1.1-10.0.1.255)
├── TFTP Server (Boot files)
├── NFS Server (Shared filesystems)
└── Firewall (Services: warewulf, dhcp, nfs, tftp)

Compute Nodes
├── CPU Nodes (10.0.1.1-10.0.1.255) - Managed by Warewulf
├── GPU Node (10.0.2.4) - Static IP, not managed by Warewulf
└── Network Boot → Warewulf Provisioning
```

## Dependencies

- **Network configuration** - Requires network component for IP settings
- **Firewall services** - Needs firewalld for service management
- **System services** - DHCP, TFTP, NFS services
- **Container runtime** - For VNFS image management

## Configuration Integration

The Warewulf component integrates with the network configuration:

```bash
# Loads network settings from network.conf
load_component_config "network"

# Uses these variables:
# - HEAD_NODE_IP (10.0.0.1)
# - NETWORK_MASK (255.255.252.0)
# - NETWORK (10.0.0.0)
# - DHCP_START (10.0.1.1)
# - DHCP_END (10.0.1.255)
```

## Troubleshooting

### Common Issues

1. **Service not starting:**
   ```bash
   systemctl status warewulfd
   journalctl -u warewulfd
   ```

2. **Network connectivity:**
   ```bash
   # Check firewall
   firewall-cmd --list-services
   
   # Test DHCP
   systemctl status dhcpd
   ```

3. **Image issues:**
   ```bash
   # List images
   wwctl image list
   
   # Rebuild image
   wwctl image build rockylinux-9.6
   ```

### Logs and Debugging

- **Warewulf logs:** `/var/log/warewulf/`
- **DHCP logs:** `journalctl -u dhcpd`
- **TFTP logs:** `journalctl -u tftp`
- **NFS logs:** `journalctl -u nfs-server`

## Next Steps

After Warewulf is configured:

1. **Add compute nodes** using `wwctl node add`
2. **Configure node profiles** with `wwctl profile set`
3. **Build overlays** with `wwctl overlay build`
4. **Boot compute nodes** to test provisioning

## References

- [Warewulf Documentation](https://warewulf.org/)
- [Warewulf GitHub](https://github.com/warewulf/warewulf)
- [HPC Cluster Setup Guide](../README.md)
