#!/bin/bash

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