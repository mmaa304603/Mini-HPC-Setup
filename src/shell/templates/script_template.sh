#!/bin/bash

# Script template with error handling and logging

# Configuration
CONFIG_FILE="/etc/hpc/config.conf"
LOG_FILE="/var/log/hpc/$(basename $0).log"
ERROR_LOG="/var/log/hpc/$(basename $0).error.log"

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found: $CONFIG_FILE" | tee -a "$ERROR_LOG"
    exit 1
fi

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" | tee -a "$ERROR_LOG"
    exit 1
}

# Error handling
set -e
trap 'error "Script failed at line $LINENO"' ERR

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$ERROR_LOG")"

# Main script logic
main() {
    log "Starting script execution"
    
    # Your script logic here
    # Example:
    if ! command -v some_command >/dev/null 2>&1; then
        error "Required command not found: some_command"
    fi
    
    # Example with error handling
    if ! some_command; then
        error "Command failed: some_command"
    fi
    
    log "Script completed successfully"
}

# Execute main function
main "$@" 