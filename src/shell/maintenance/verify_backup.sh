#!/bin/bash

# Source library scripts
source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../lib/config.sh"

# Load configuration
load_config "monitoring.conf"
export_config

# Backup Verification Script

# Load configuration
source /etc/hpc/config.conf

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/verify_backup.log"
}

# Error handling
error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" | tee -a "$LOG_DIR/verify_backup.error.log"
    exit 1
}

# Verify configuration backup
verify_config() {
    local backup_file="$1"
    log "Verifying configuration backup: $backup_file"
    
    # Check if backup exists
    [ -f "$backup_file" ] || error "Backup file not found: $backup_file"
    
    # Verify backup integrity
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        error "Backup file is corrupted: $backup_file"
    fi
    
    # Verify backup contents
    local temp_dir=$(mktemp -d)
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Check critical files
    for file in "$temp_dir"/etc/slurm/slurm.conf \
                "$temp_dir"/etc/warewulf/warewulf.conf \
                "$temp_dir"/etc/globus-connect-server/config.json; do
        [ -f "$file" ] || error "Critical file missing in backup: $file"
    done
    
    rm -rf "$temp_dir"
    log "Configuration backup verification completed successfully"
}

# Verify data backup
verify_data() {
    local backup_dir="$1"
    log "Verifying data backup: $backup_dir"
    
    # Check if backup directory exists
    [ -d "$backup_dir" ] || error "Backup directory not found: $backup_dir"
    
    # Verify directory structure
    [ -d "$backup_dir/home" ] || error "Home directory missing in backup"
    [ -d "$backup_dir/shared" ] || error "Shared directory missing in backup"
    [ -d "$backup_dir/scratch" ] || error "Scratch directory missing in backup"
    
    # Verify file integrity
    find "$backup_dir" -type f -exec md5sum {} \; > "$LOG_DIR/backup_checksums.txt"
    
    log "Data backup verification completed successfully"
}

# Verify system state backup
verify_system() {
    local backup_file="$1"
    log "Verifying system state backup: $backup_file"
    
    # Check if backup exists
    [ -f "$backup_file" ] || error "Backup file not found: $backup_file"
    
    # Verify backup integrity
    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        error "Backup file is corrupted: $backup_file"
    fi
    
    # Verify backup contents
    local temp_dir=$(mktemp -d)
    tar -xzf "$backup_file" -C "$temp_dir"
    
    # Check critical directories
    for dir in "$temp_dir"/var/lib/warewulf \
               "$temp_dir"/var/lib/slurm \
               "$temp_dir"/var/lib/globus-connect-server; do
        [ -d "$dir" ] || error "Critical directory missing in backup: $dir"
    done
    
    rm -rf "$temp_dir"
    log "System state backup verification completed successfully"
}

# Main function
main() {
    case "$1" in
        config)
            verify_config "$2"
            ;;
        data)
            verify_data "$2"
            ;;
        system)
            verify_system "$2"
            ;;
        all)
            verify_config "$BACKUP_DIR/config/config-$(date +%Y%m%d).tar.gz"
            verify_data "$BACKUP_DIR/data/data-$(date +%Y%m%d)"
            verify_system "$BACKUP_DIR/system/system-$(date +%Y%m%d).tar.gz"
            ;;
        *)
            echo "Usage: $0 {config|data|system|all} [backup_path]"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@" 