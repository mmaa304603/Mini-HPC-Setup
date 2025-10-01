#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/logging.sh"

# Function to check OS version
check_os_version() {
    if [ ! -f /etc/rocky-release ]; then
        log_error "Not running on Rocky Linux"
        return 1
    fi
    
    OS_VERSION=$(grep -oP 'Rocky Linux release \K[0-9.]+' /etc/rocky-release)
    if [[ "$OS_VERSION" != "9.5" ]]; then
        log_error "Rocky Linux version must be 9.5, found ${OS_VERSION}"
        return 1
    fi
    
    log_info "OS version check passed: Rocky Linux ${OS_VERSION}"
    return 0
}

# Function to check network interface
check_network_interface() {
    if ! ip link show "${NETWORK_INTERFACE}" >/dev/null 2>&1; then
        log_error "Network interface ${NETWORK_INTERFACE} not found"
        return 1
    fi
    
    log_info "Network interface check passed: ${NETWORK_INTERFACE}"
    return 0
}

# Function to check disk space
check_disk_space() {
    local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_space" -lt "$MIN_DISK_SPACE_GB" ]; then
        log_error "Insufficient disk space. Required: ${MIN_DISK_SPACE_GB}GB, Available: ${available_space}GB"
        return 1
    fi
    
    log_info "Disk space check passed: ${available_space}GB available"
    return 0
}

# Function to check memory
check_memory() {
    local total_memory=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_memory" -lt "$MIN_MEMORY_GB" ]; then
        log_error "Insufficient memory. Required: ${MIN_MEMORY_GB}GB, Available: ${total_memory}GB"
        return 1
    fi
    
    log_info "Memory check passed: ${total_memory}GB available"
    return 0
}

# Function to check CPU cores
check_cpu_cores() {
    local cpu_cores=$(nproc)
    if [ "$cpu_cores" -lt "$MIN_CPU_CORES" ]; then
        log_error "Insufficient CPU cores. Required: ${MIN_CPU_CORES}, Available: ${cpu_cores}"
        return 1
    fi
    
    log_info "CPU cores check passed: ${cpu_cores} cores available"
    return 0
}

# Function to check required commands
check_required_commands() {
    local required_commands=("dnf" "systemctl" "firewall-cmd" "git")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -ne 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
    
    log_info "Required commands check passed"
    return 0
}

# Main validation function
validate_environment() {
    local checks=(
        "check_os_version"
        "check_network_interface"
        "check_disk_space"
        "check_memory"
        "check_cpu_cores"
        "check_required_commands"
    )
    
    local failed=0
    
    for check in "${checks[@]}"; do
        if ! $check; then
            failed=1
        fi
    done
    
    if [ $failed -eq 1 ]; then
        log_error "Environment validation failed"
        return 1
    fi
    
    log_info "Environment validation passed"
    return 0
}

# Run validation if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_environment
    exit $?
fi 