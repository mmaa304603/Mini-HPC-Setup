# SLURM Component

SLURM (Simple Linux Utility for Resource Management) installation and configuration for HPC clusters.

## Files

- **`head-install.sh`** - Rocky Linux head node SLURM installation
- **`gpu-install.sh`** - Ubuntu 22.04 GPU node SLURM installation
- **`cpu-image-install.sh`** - Warewulf VNFS CPU image SLURM installation
- **`configure.sh`** - Generates SLURM configuration files
- **`slurm.conf`** - SLURM configuration template
- **`distribute-munge-key.sh`** - Distributes MUNGE key to compute nodes

## Prerequisites

- **MUNGE**: Authentication system required by SLURM
- **EPEL Repository**: For MUNGE and SLURM packages
- **Network connectivity**: For distributing MUNGE keys

## Installation Process

### Choose the appropriate installation script for your node type:

#### 1. Head Node (Rocky Linux)
```bash
# Install SLURM controller on head node
./src/shell/components/slurm/head-install.sh
```
- **Purpose**: Installs MUNGE and SLURM controller
- **For**: HPC head nodes running Rocky Linux
- **Components**: MUNGE authentication, SLURM controller daemon

#### 2. GPU Node (Ubuntu 22.04)
```bash
# Install SLURM compute daemon on GPU node
./src/shell/components/slurm/gpu-install.sh
```
- **Purpose**: Installs MUNGE and SLURM compute daemon
- **For**: GPU compute nodes running Ubuntu 22.04
- **Components**: MUNGE authentication, SLURM compute daemon

#### 3. CPU Image (Warewulf VNFS)
```bash
# Install SLURM client in Warewulf image
./src/shell/components/slurm/cpu-image-install.sh
```
- **Purpose**: Installs MUNGE and SLURM client in Warewulf image
- **For**: Stateless CPU compute nodes
- **Components**: MUNGE authentication, SLURM client in VNFS image

### 2. Distribute MUNGE Key
```bash
# Copy MUNGE key to compute nodes
./src/shell/components/slurm/distribute-munge-key.sh compute-01 compute-02 gpu-01
```

### 3. Configure SLURM
```bash
# Generate SLURM configuration
./src/shell/components/slurm/configure.sh
```

## MUNGE Key Management

### Key Location
- **Head node**: `/etc/munge/munge.key`
- **Compute nodes**: `/etc/munge/munge.key` (copied from head node)

### Key Distribution
The MUNGE key must be identical across all nodes in the cluster:

```bash
# Manual distribution
scp /etc/munge/munge.key <node>:/etc/munge/munge.key
ssh <node> "chown munge: /etc/munge/munge.key && chmod 0400 /etc/munge/munge.key"
ssh <node> "systemctl enable munge && systemctl start munge"
```

### Verification
Test MUNGE authentication across nodes:
```bash
# Local test
munge -n | unmunge

# Cross-node test
munge -n | ssh <node> unmunge
```

## SLURM Configuration

### Head Node Services
- **slurmctld**: SLURM controller daemon
- **munge**: Authentication service

### Compute Node Services
- **slurmd**: SLURM compute daemon
- **munge**: Authentication service

### Configuration Files
- **`/etc/slurm/slurm.conf`**: Main SLURM configuration
- **`/etc/munge/munge.key`**: MUNGE authentication key

## Security Notes

- MUNGE key is sensitive - protect it like a password
- Key must be identical across all cluster nodes
- Proper file permissions: `chmod 0400 /etc/munge/munge.key`
- Proper ownership: `chown munge: /etc/munge/munge.key`

## Troubleshooting

### MUNGE Issues
```bash
# Check MUNGE service status
systemctl status munge

# Check key permissions
ls -la /etc/munge/munge.key

# Test authentication
munge -n | unmunge
```

### Manual MUNGE Setup (if package installation fails)

If the package installation doesn't handle user/group creation or permissions correctly, you may need to run these commands manually:

```bash
# Create MUNGE user and group (if not created by package)
groupadd --system munge
useradd --system --gid munge --home-dir /var/lib/munge --shell /sbin/nologin munge

# Set ownership and permissions (if not set by package)
chown -R munge: /etc/munge /var/lib/munge /var/log/munge /var/run/munge
chmod 0700 /etc/munge /var/lib/munge
chmod 0755 /var/log/munge /var/run/munge

# Generate MUNGE key (if not generated)
/usr/sbin/create-munge-key

# Set key ownership and permissions (if not set by create-munge-key)
chown munge: /etc/munge/munge.key
chmod 0400 /etc/munge/munge.key
```

### Installation from Source (if packages unavailable)

If MUNGE packages are not available in your repository, you can install from source:

```bash
# Install prerequisites
dnf groupinstall -y "Development Tools"
dnf install -y epel-release
dnf install -y bzip2 zlib zlib-devel openssl openssl-devel rng-tools wget git

# Create MUNGE user and group
groupadd --system munge
useradd --system --gid munge --home-dir /var/lib/munge --shell /sbin/nologin munge

# Download and build MUNGE
cd /usr/local/src
git clone https://github.com/dun/munge.git
cd munge
git checkout munge-0.5.16
./bootstrap
./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
make
make install

# Set ownership and permissions
chown -R munge: /etc/munge /var/lib/munge /var/log/munge /var/run/munge
chmod 0700 /etc/munge /var/lib/munge
chmod 0755 /var/log/munge /var/run/munge

# Generate MUNGE key
/usr/sbin/create-munge-key
chown munge: /etc/munge/munge.key
chmod 0400 /etc/munge/munge.key

# Setup systemd service
cp contrib/systemd/munge.service /usr/lib/systemd/system/
systemctl daemon-reload
systemctl enable munge
systemctl start munge
```

### SLURM Issues
```bash
# Check SLURM services
systemctl status slurmctld
systemctl status slurmd

# Check SLURM logs
tail -f /var/log/slurm/slurmctld.log
tail -f /var/log/slurm/slurmd.log
```

## Notes

- Requires root privileges for installation
- MUNGE key distribution requires SSH access to compute nodes
- All nodes must have the same MUNGE key for SLURM to work
- Reboot recommended after installation
