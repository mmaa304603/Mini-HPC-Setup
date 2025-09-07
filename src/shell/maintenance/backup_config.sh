#!/bin/bash

# Source library scripts
source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../lib/config.sh"

# Load configuration
load_config "monitoring.conf"
export_config

# Configuration backup script

# Create backup directory
BACKUP_DIR="/backup/config/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup configuration files
echo "Backing up configuration files..."
tar -czf $BACKUP_DIR/config.tar.gz /etc

# Backup Warewulf configuration
echo "Backing up Warewulf configuration..."
tar -czf $BACKUP_DIR/warewulf.tar.gz /etc/warewulf

# Backup SLURM configuration
echo "Backing up SLURM configuration..."
tar -czf $BACKUP_DIR/slurm.tar.gz /etc/slurm

# Backup Globus configuration
echo "Backing up Globus configuration..."
tar -czf $BACKUP_DIR/globus.tar.gz /etc/globus-connect-server

# Backup Spack configuration
echo "Backing up Spack configuration..."
tar -czf $BACKUP_DIR/spack.tar.gz /etc/spack

# Backup monitoring configuration
echo "Backing up monitoring configuration..."
tar -czf $BACKUP_DIR/elasticsearch.tar.gz /etc/elasticsearch
tar -czf $BACKUP_DIR/kibana.tar.gz /etc/kibana
tar -czf $BACKUP_DIR/grafana.tar.gz /etc/grafana

# Backup Squid configuration
echo "Backing up Squid configuration..."
tar -czf $BACKUP_DIR/squid.tar.gz /etc/squid

# Backup Apptainer configuration
echo "Backing up Apptainer configuration..."
tar -czf $BACKUP_DIR/apptainer.tar.gz /etc/apptainer

# Verify backup
echo "Verifying backup..."
for file in $BACKUP_DIR/*.tar.gz; do
    if ! tar -tzf "$file" > /dev/null; then
        echo "Error: $file is corrupted"
        exit 1
    fi
done

# Set permissions
echo "Setting backup permissions..."
chmod 600 $BACKUP_DIR/*.tar.gz
chown root:root $BACKUP_DIR/*.tar.gz

# Clean old backups
echo "Cleaning old backups..."
find /backup/config -type d -mtime +30 -exec rm -rf {} \;

echo "Configuration backup completed successfully" 