#!/bin/bash

# Configuration loader script
# This script loads configuration from the config directory

# Configuration directory (legacy support only; centralized configs removed)
LIB_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
SHELL_DIR="$(dirname "$LIB_DIR")"
CONFIG_DIR="${SHELL_DIR}/config"

source "${LIB_DIR}/functions.sh" # Source common functions
source "${CONFIG_DIR}/config.conf"

# Load component-specific configuration
load_component_config() {
    local component="$1"
    local base_dir="$SHELL_DIR"
    local config_file="$base_dir/components/$component/$component.conf"
    
    if [ ! -f "$config_file" ]; then
        error "Component configuration file not found: $config_file"
        return 1
    fi
    
    info "Loading $component configuration from $config_file"
    source "$config_file"
    return 0
}

# Load all configuration files from component directories
load_all_configs() {
    local base_dir="$SHELL_DIR"
    # Load network configuration
    if [ -f "$base_dir/components/network/network.conf" ]; then
        info "Loading network configuration"
        source "$base_dir/components/network/network.conf"
    fi
    
    # Load warewulf configuration
    if [ -f "$base_dir/components/warewulf/warewulf.conf" ]; then
        info "Loading warewulf configuration"
        source "$base_dir/components/warewulf/warewulf.conf"
    fi
    
    # Load slurm configuration
    if [ -f "$base_dir/components/slurm/slurm.conf" ]; then
        info "Loading slurm configuration"
        source "$base_dir/components/slurm/slurm.conf"
    fi
    
    # Load spack configuration
    if [ -f "$base_dir/components/spack/spack.conf" ]; then
        info "Loading spack configuration"
        source "$base_dir/components/spack/spack.conf"
    fi
    
    # Load monitoring configuration
    if [ -f "$base_dir/components/grafana/monitoring.conf" ]; then
        info "Loading monitoring configuration"
        source "$base_dir/components/grafana/monitoring.conf"
    fi
    
    # Load apptainer configuration
    if [ -f "$base_dir/components/apptainer/apptainer.conf" ]; then
        info "Loading apptainer configuration"
        source "$base_dir/components/apptainer/apptainer.conf"
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
