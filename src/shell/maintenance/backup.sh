#!/bin/bash

# Source library scripts
source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../lib/config.sh"

# Load configuration
load_config "monitoring.conf"
export_config

# Check if running as root
check_root

# Configuration
BACKUP_DIR="/var/backups/monitoring"
ELASTICSEARCH_DATA="/var/lib/elasticsearch"
GRAFANA_DATA="/var/lib/grafana"
KIBANA_DATA="/var/lib/kibana"
LOGSTASH_DATA="/var/lib/logstash"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="monitoring_backup_${DATE}"

# Create backup directory
create_backup_dir() {
    info "Creating backup directory..."
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"
}

# Backup Elasticsearch
backup_elasticsearch() {
    info "Backing up Elasticsearch..."
    
    # Stop Elasticsearch
    systemctl stop elasticsearch
    
    # Create snapshot
    local snapshot_dir="${BACKUP_DIR}/${BACKUP_NAME}/elasticsearch"
    mkdir -p "$snapshot_dir"
    
    # Backup data directory
    tar -czf "${snapshot_dir}/elasticsearch_data.tar.gz" -C "$ELASTICSEARCH_DATA" .
    
    # Backup configuration
    cp -r /etc/elasticsearch "${snapshot_dir}/config"
    
    # Start Elasticsearch
    systemctl start elasticsearch
    
    info "Elasticsearch backup completed"
}

# Backup Grafana
backup_grafana() {
    info "Backing up Grafana..."
    
    local grafana_dir="${BACKUP_DIR}/${BACKUP_NAME}/grafana"
    mkdir -p "$grafana_dir"
    
    # Backup data directory
    tar -czf "${grafana_dir}/grafana_data.tar.gz" -C "$GRAFANA_DATA" .
    
    # Backup configuration
    cp -r /etc/grafana "${grafana_dir}/config"
    
    # Backup dashboards
    cp -r /var/lib/grafana/dashboards "${grafana_dir}/dashboards"
    
    info "Grafana backup completed"
}

# Backup Kibana
backup_kibana() {
    info "Backing up Kibana..."
    
    local kibana_dir="${BACKUP_DIR}/${BACKUP_NAME}/kibana"
    mkdir -p "$kibana_dir"
    
    # Backup data directory
    tar -czf "${kibana_dir}/kibana_data.tar.gz" -C "$KIBANA_DATA" .
    
    # Backup configuration
    cp -r /etc/kibana "${kibana_dir}/config"
    
    info "Kibana backup completed"
}

# Backup Logstash
backup_logstash() {
    info "Backing up Logstash..."
    
    local logstash_dir="${BACKUP_DIR}/${BACKUP_NAME}/logstash"
    mkdir -p "$logstash_dir"
    
    # Backup data directory
    tar -czf "${logstash_dir}/logstash_data.tar.gz" -C "$LOGSTASH_DATA" .
    
    # Backup configuration
    cp -r /etc/logstash "${logstash_dir}/config"
    
    # Backup pipelines
    cp -r /etc/logstash/pipeline "${logstash_dir}/pipeline"
    
    info "Logstash backup completed"
}

# Create backup manifest
create_manifest() {
    info "Creating backup manifest..."
    
    local manifest_file="${BACKUP_DIR}/${BACKUP_NAME}/manifest.txt"
    
    cat > "$manifest_file" << EOF
Monitoring Stack Backup
Date: $(date)
Version: 1.0

Components:
- Elasticsearch: $(elasticsearch --version)
- Grafana: $(grafana-server --version)
- Kibana: $(kibana --version)
- Logstash: $(logstash --version)

Backup Contents:
- Elasticsearch data and configuration
- Grafana data, configuration, and dashboards
- Kibana data and configuration
- Logstash data, configuration, and pipelines

Backup Location: ${BACKUP_DIR}/${BACKUP_NAME}
EOF
    
    info "Manifest created at ${manifest_file}"
}

# Cleanup old backups
cleanup_old_backups() {
    info "Cleaning up old backups..."
    
    # Keep last 5 backups
    local keep_count=5
    local backup_count=$(ls -1 "${BACKUP_DIR}" | grep "monitoring_backup_" | wc -l)
    
    if [ "$backup_count" -gt "$keep_count" ]; then
        ls -1t "${BACKUP_DIR}" | grep "monitoring_backup_" | tail -n +$((keep_count + 1)) | while read backup; do
            rm -rf "${BACKUP_DIR}/${backup}"
            info "Removed old backup: ${backup}"
        done
    fi
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    info "Starting monitoring stack backup..."
    
    create_backup_dir
    backup_elasticsearch
    backup_grafana
    backup_kibana
    backup_logstash
    create_manifest
    cleanup_old_backups
    
    info "Backup completed successfully at ${BACKUP_DIR}/${BACKUP_NAME}"
}

main "$@" 