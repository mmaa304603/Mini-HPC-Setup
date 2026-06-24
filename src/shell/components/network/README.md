# Network Component

This component handles network configuration for the HPC cluster setup using modern NetworkManager approach.

## Files

- `configure-head.sh` - Head node network configuration script
- `configure-gpu.sh` - GPU node network configuration script

## Usage

### Head Node Configuration
```bash
# Run head node network configuration
./configure-head.sh
```

### GPU Node Configuration
```bash
# Run GPU node network configuration (on Jetson Orin Nano)
./configure-gpu.sh
```

## Connection Naming Strategy

### Head Node Connection (`cluster-internal`)
```bash
nmcli con add type ethernet ifname enp2s0 con-name cluster-internal \
  ip4 10.0.0.1/22 \
  connection.autoconnect yes
```

**Why "cluster-internal":**
- Manages the **entire internal cluster network**
- Provides services to **all compute nodes** (CPU + GPU)
- Acts as **gateway** for internal cluster subnet (10.0.0.0/22)
- Covers the range: 10.0.0.1 → 10.0.2.4 (all nodes)

### GPU Node Connection (`gpu`)
```bash
nmcli con add type ethernet ifname eth0 con-name gpu \
  ip4 10.0.2.4/22 \
  gw4 10.0.0.1 \
  connection.autoconnect yes
```

**Why "gpu":**
- **Client connection** to the cluster
- Connects **to** the cluster, not managing it
- Acts as **compute node** that uses cluster services

## Node-Specific Network Configuration

### Head Node (10.0.0.1)
- **Purpose**: Gateway and service provider
- **Interface**: enp2s0 (internal), enp0s21f0u6c2 (external)
- **IP**: 10.0.0.1/22 (internal), 192.168.1.222 (external)
- **Gateway**: External router (192.168.1.1)
- **Services**: DHCP, TFTP, NFS, SLURM controller
- **Routing**: IP forwarding + masquerading for cluster traffic

### CPU Compute Nodes (10.0.2.1-10.0.2.3)
- **Purpose**: CPU compute resources
- **Management**: Warewulf PXE boot
- **IP Range**: 10.0.2.1-10.0.2.3
- **Configuration**: Automatic via Warewulf

### GPU Compute Node (10.0.2.4)
- **Purpose**: GPU compute resources
- **Interface**: eth0 (Jetson Orin Nano)
- **IP**: 10.0.2.4/22
- **Gateway**: Head node (10.0.0.1)
- **Configuration**: Manual via configure-gpu.sh
- **Connection Name**: gpu-cluster

## Network Architecture

```
Internet
    │
    └── Head Node (10.0.0.1) ── Internal Switch
                                    │
                                    ├── CPU Node 1 (10.0.2.1) [Warewulf]
                                    ├── CPU Node 2 (10.0.2.2) [Warewulf]
                                    ├── CPU Node 3 (10.0.2.3) [Warewulf]
                                    └── GPU Node (10.0.2.4) [Manual]
```

## GPU Node Specific Configuration

### Network Configuration
- **IP Address**: 10.0.2.4 (static assignment)
- **Gateway**: 10.0.0.1 (head node)
- **Subnet**: 10.0.0.0/22
- **Interface**: eth0 (typical for Jetson devices)
- **DNS**: 8.8.8.8, 8.8.4.4

### Key Differences from Head Node

| Aspect | Head Node | GPU Node |
|--------|-----------|----------|
| **IP Address** | 10.0.0.1 | 10.0.2.4 |
| **Purpose** | Gateway + Services | Compute only |
| **Management** | Manual config | Manual config |
| **Interface** | enp2s0 | eth0 |
| **Gateway** | External router | Head node (10.0.0.1) |
| **Connection Name** | cluster-internal | gpu-cluster |

### GPU Node Configuration Process

#### 1. Network Interface Setup
```bash
# Create NetworkManager connection
nmcli con add type ethernet ifname eth0 con-name gpu-cluster \
  ip4 10.0.2.4/22 \
  gw4 10.0.0.1 \
  connection.autoconnect yes

# Activate the connection
nmcli con up gpu-cluster
```

#### 2. DNS Configuration
```bash
# Set DNS servers
nmcli con mod gpu-cluster ipv4.dns "8.8.8.8,8.8.4.4"

# Set search domain
nmcli con mod gpu-cluster ipv4.dns-search "hpc.ttu.edu"
```

**Why DNS is configured on GPU node instead of head node:**

The head node has a **dual network interface architecture**:
- **External Connection** - Connected to Internet (via router/ISP) with automatic DNS from ISP
- **Internal Connection** - Connected to internal switch (for cluster) without DNS forwarding

**DNS Resolution Flow:**
```
Internet DNS Servers (8.8.8.8, 1.1.1.1)
    ↑
External Router/Gateway
    ↑
Head Node (10.0.0.1) ── Internal Switch
    │                      │
    │                      ├── CPU Nodes
    │                      └── GPU Node (needs direct DNS)
```

**Why GPU node needs direct DNS:**
- ✅ **Head node doesn't provide DNS forwarding** - Only routes traffic
- ✅ **External DNS comes from ISP** - Head node gets DNS automatically
- ✅ **Internal network focus** - Head node provides DHCP, TFTP, NFS, SLURM services
- ✅ **Simpler architecture** - No additional DNS server setup needed
- ✅ **More reliable** - Direct DNS resolution without forwarding dependency

#### 3. Connectivity Testing
- Tests connectivity to head node (10.0.0.1)
- Tests external connectivity (8.8.8.8)
- Validates network configuration

## Prerequisites

### Head Node
- Rocky Linux 9.6
- NetworkManager installed and running
- External network connection

### GPU Node
- Jetson Orin Nano with Ubuntu 22.04
- NetworkManager installed and running
- Physical connection to internal switch
- Head node already configured and running

## Troubleshooting

### Common Issues

1. **Interface not found**
   - Check interface name: `ip link show`
   - Head node typically uses `enp2s0`
   - Jetson devices typically use `eth0`

2. **Cannot reach head node (GPU node)**
   - Verify head node is running and configured
   - Check physical network connection
   - Verify switch configuration

3. **DNS resolution fails**
   - Check DNS server configuration
   - Verify search domain settings
   - Test with: `nslookup google.com`

### Manual Configuration (GPU Node)

If the script fails, you can configure manually:

```bash
# Set static IP
sudo ip addr add 10.0.2.4/22 dev eth0

# Set gateway
sudo ip route add default via 10.0.0.1

# Set DNS
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf
```

## Configuration

The scripts use configuration from `src/shell/components/network/network.conf` with clearly separated sections:

### Head Node Variables
- `HEAD_NODE_IP` - Head node IP address (e.g., 10.0.0.1)
- `HEAD_NETWORK_INTERFACE` - Head node interface name (e.g., enp2s0)
- `NETWORK_MASK` - Network mask (e.g., 255.255.252.0)
- `NETWORK` - Network address (e.g., 10.0.0.0)
- `DHCP_START` - DHCP range start (e.g., 10.0.1.1)
- `DHCP_END` - DHCP range end (e.g., 10.0.1.255)
- `FIREWALL_ENABLED` - Enable/disable firewall configuration
- `FIREWALL_SERVICES` - Array of services to allow
- `FIREWALL_PORTS` - Array of ports to allow

### GPU Node Variables
- `GPU_NODE_IP` - GPU node IP address (e.g., 10.0.2.4)
- `GPU_NETWORK_INTERFACE` - GPU node interface name (e.g., eth0)
- `HEAD_NODE_IP` - Gateway IP for GPU node (e.g., 10.0.0.1)

## Network Configuration Approach

### Modern NetworkManager Method (Current)
The head node script uses **NetworkManager** (`nmcli`) for network configuration:

```bash
# Create NetworkManager connection
nmcli con add type ethernet ifname enp2s0 con-name cluster-internal \
  ip4 10.0.0.1/22 \
  connection.autoconnect yes

# Activate the connection
nmcli con up cluster-internal
```

### Gateway Configuration (Head Node)
The head node also configures routing for the cluster:

```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# Configure masquerading
firewall-cmd --permanent --add-masquerade
firewall-cmd --reload
```

**Advantages:**
- ✅ **Modern and supported** - Active development and maintenance
- ✅ **Better integration** - Works with systemd, cloud-init, etc.
- ✅ **More features** - VPN, WiFi, bonding, teaming support
- ✅ **Future-proof** - Standard approach for RHEL/Rocky Linux 9.6+
- ✅ **Reliable** - Better error handling and status reporting

### Legacy Method (Deprecated)
The previous approach used legacy `network-scripts`:

```bash
# Old method - creates /etc/sysconfig/network-scripts/ifcfg-enp2s0
cat > "/etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE" << EOF
DEVICE=$NETWORK_INTERFACE
BOOTPROTO=static
IPADDR=$HEAD_NODE_IP
NETMASK=$NETWORK_MASK
ONBOOT=yes
TYPE=Ethernet
EOF
systemctl restart network
```

**Disadvantages:**
- ❌ **Deprecated** - No longer actively maintained
- ❌ **Limited features** - Basic functionality only
- ❌ **Integration issues** - Conflicts with NetworkManager
- ❌ **Future removal** - Will be removed in future RHEL versions

## Dependencies

- Requires root privileges
- Uses `nmcli` for network configuration (NetworkManager)
- Uses `firewall-cmd` for firewall configuration
- Sources from `src/shell/lib/functions.sh` and `src/shell/lib/config.sh`
