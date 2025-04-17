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
    
    # Load Warewulf configuration from the Warewulf directory
    if [ -f "$(dirname "$(dirname "$0")")/warewulf/warewulf.conf" ]; then
        info "Loading Warewulf configuration"
        # We don't source this file directly as it's in YAML format
    fi
}

# Export configuration variables
export_config() {
    # Network configuration
    export NETWORK_INTERFACE
    export HEAD_NODE_IP
    export NETWORK_MASK
    export NETWORK
    export DHCP_START
    export DHCP_END
    
    # SLURM configuration
    export CLUSTER_NAME
    export NODE_COUNT
    export NODE_PREFIX
    export PARTITION_NAME
    export DEFAULT_PARTITION
    export MAX_TIME
    export LOG_DIR
    export STATE_SAVE_LOCATION
    
    # Spack configuration
    export SPACK_ROOT
    export SPACK_ENV_FILE
    
    # Monitoring configuration
    export ELASTICSEARCH_ENABLED
    export LOGSTASH_ENABLED
    export KIBANA_ENABLED
    export GRAFANA_ENABLED
    export FILEBEAT_ENABLED
}

# Node Configuration
HEAD_NODE="headnode"
HEAD_NODE_IP="192.168.1.10"
COMPUTE_NODES=("compute01" "compute02" "compute03")
COMPUTE_NODE_IPS=("192.168.1.11" "192.168.1.12" "192.168.1.13")

# Network Configuration
NETWORK_INTERFACE="eth0"
NETWORK_MASK="255.255.255.0"
NETWORK="192.168.1.0"
DHCP_START="192.168.1.100"
DHCP_END="192.168.1.200"

# Warewulf Configuration
WAREWULF_VERSION="4.6"
WAREWULF_PORT="9873"
CONTAINER_NAME="rocky-8"
CONTAINER_BASE="/var/lib/warewulf/container"

# SLURM Configuration
SLURM_CLUSTER_NAME="hpc-cluster"
SLURM_PARTITION_NAME="compute"
SLURM_DEFAULT_MEM="4096"
SLURM_MAX_MEM="8192"
SLURM_SOCKETS="1"
SLURM_CORES_PER_SOCKET="4"
SLURM_THREADS_PER_CORE="1"

# Spack Configuration
SPACK_VERSION="0.20.1"
SPACK_INSTALL_DIR="/opt/spack"
SPACK_REPO="https://github.com/spack/spack.git"
SPACK_BRANCH="releases/v${SPACK_VERSION}"
SPACK_COMPILERS=("gcc@9.4.0" "gcc@8.5.0")
SPACK_PACKAGES=(
    "openmpi@4.1.5"
    "hdf5@1.12.2"
    "netcdf@4.9.2"
    "python@3.10.13"
    "numpy@1.24.3"
    "scipy@1.10.1"
    "matplotlib@3.7.1"
)

# Environment Modules Configuration
MODULES_VERSION="5.2.1"
MODULES_INSTALL_DIR="/opt/modules"
MODULES_REPO="https://github.com/cea-hpc/modules.git"
MODULES_BRANCH="v${MODULES_VERSION}"
MODULES_PREFIX="/opt/modules"
MODULES_DEFAULT_PATH="/opt/modules/modulefiles"

# Logging
LOG_DIR="/var/log/hpc-setup"
LOG_FILE="${LOG_DIR}/setup.log"

# Component enablement flags
NETWORK_SETUP_ENABLED=true
SLURM_ENABLED=true
SPACK_ENABLED=true
MONITORING_ENABLED=true

# Network configuration
NETWORK_IP="192.168.1.1"
NETWORK_NETMASK="255.255.255.0"
NETWORK_GATEWAY="192.168.1.254"

# SLURM configuration
SLURM_CONTROLLER_HOST="controller"
SLURM_NODES=("node1" "node2" "node3")
SLURM_PARTITION_NODES="node[1-3]"
SLURM_PARTITION_STATE="UP"

# Spack configuration
SPACK_COMPILERS=("gcc@9.4.0" "gcc@10.3.0")
SPACK_PACKAGES=("openmpi@4.1.1" "hdf5@1.12.1" "netcdf@4.8.1")

# Monitoring configuration
MONITORING_ELK_ENABLED=true
MONITORING_GRAFANA_ENABLED=true
MONITORING_PROMETHEUS_ENABLED=true
MONITORING_NODE_EXPORTER_ENABLED=true

# System requirements
MIN_DISK_SPACE_GB=20
MIN_MEMORY_GB=4
MIN_CPU_CORES=2 