#!/bin/bash

# Configuration loader script
# This script loads configuration from the config directory

# Source common functions
source "$(dirname "$0")/functions.sh"

# Configuration directory
CONFIG_DIR="$(dirname "$(dirname "$0")")/config"

# Load configuration file
load_config() {
    local config_file="$1"
    local full_path="$CONFIG_DIR/$config_file"
    
    if [ ! -f "$full_path" ]; then
        error "Configuration file not found: $full_path"
        return 1
    fi
    
    info "Loading configuration from $full_path"
    source "$full_path"
    return 0
}

# Load all configuration files
load_all_configs() {
    load_config "network.conf"
    load_config "slurm.conf"
    load_config "spack.conf"
    load_config "monitoring.conf"
    # load_config "squid.conf"  # Removed - squid no longer needed with spack
    load_config "apptainer.conf"
    
    # Load Warewulf configuration from the Warewulf directory
    if [ -f "$(dirname "$(dirname "$0")")/warewulf/warewulf.conf" ]; then
        info "Loading Warewulf configuration"
        # We don't source this file directly as it's in YAML format
    fi
}

# Export configuration variables
export_config() {
    # Export all variables that start with uppercase letters
    # This will export variables loaded from config files
    local var
    for var in $(compgen -v | grep '^[A-Z]'); do
        export "$var"
    done
} 
