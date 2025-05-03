#!/bin/bash

# System Cleanup Script
# Version: 1.0.0

# Configuration
SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="$SCRIPT_DIR/../logs/cleanup.log"
CONFIG_FILE="$SCRIPT_DIR/../config/cleanup.conf"

# Logging setup
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Clean temporary files
clean_temp_files() {
    log "Cleaning temporary files..."
    
    # Clean system temp directory
    find /tmp -type f -atime +7 -delete || handle_error "Failed to clean system temp files"
    
    # Clean application temp files
    find /var/tmp -type f -atime +7 -delete || handle_error "Failed to clean application temp files"
    
    # Clean user temp files
    find ~/tmp -type f -atime +7 -delete || handle_error "Failed to clean user temp files"
}

# Clean log files
clean_logs() {
    log "Cleaning log files..."
    
    # Rotate and compress old logs
    find /var/log -type f -name "*.log" -size +10M -exec gzip {} \; || handle_error "Failed to compress large log files"
    
    # Remove old compressed logs
    find /var/log -type f -name "*.gz" -mtime +30 -delete || handle_error "Failed to remove old compressed logs"
}

# Clean package cache
clean_package_cache() {
    log "Cleaning package cache..."
    
    # Clean DNF cache
    sudo dnf clean all || handle_error "Failed to clean DNF cache"
    
    # Clean pip cache
    pip cache purge || handle_error "Failed to clean pip cache"
}

# Clean system cache
clean_system_cache() {
    log "Cleaning system cache..."
    
    # Clean page cache
    sudo sync && sudo echo 1 > /proc/sys/vm/drop_caches || handle_error "Failed to clean page cache"
    
    # Clean dentries and inodes
    sudo echo 2 > /proc/sys/vm/drop_caches || handle_error "Failed to clean dentries and inodes"
}

# Optimize system
optimize_system() {
    log "Optimizing system..."
    
    # Update locate database
    sudo updatedb || handle_error "Failed to update locate database"
    
    # Rebuild RPM database
    sudo rpm --rebuilddb || handle_error "Failed to rebuild RPM database"
}

# Main function
main() {
    log "Starting system cleanup"
    
    # Clean temporary files
    clean_temp_files
    
    # Clean log files
    clean_logs
    
    # Clean package cache
    clean_package_cache
    
    # Clean system cache
    clean_system_cache
    
    # Optimize system
    optimize_system
    
    log "System cleanup completed successfully"
}

# Execute main function
main "$@" 