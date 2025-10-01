#!/bin/bash

# Error handling utility for HPC cluster setup
# Version: 1.0.0

# Source logging utility
source "$(dirname "$0")/logging.sh"

# Error codes
ERR_GENERAL=1
ERR_INVALID_ARG=2
ERR_FILE_NOT_FOUND=3
ERR_PERMISSION_DENIED=4
ERR_SERVICE_FAILED=5
ERR_CONFIG_INVALID=6
ERR_DEPENDENCY_MISSING=7
ERR_NETWORK_FAILED=8
ERR_STORAGE_FAILED=9
ERR_SECURITY_FAILED=10

# Error messages
declare -A ERR_MSGS=(
    [$ERR_GENERAL]="General error"
    [$ERR_INVALID_ARG]="Invalid argument"
    [$ERR_FILE_NOT_FOUND]="File not found"
    [$ERR_PERMISSION_DENIED]="Permission denied"
    [$ERR_SERVICE_FAILED]="Service failed"
    [$ERR_CONFIG_INVALID]="Invalid configuration"
    [$ERR_DEPENDENCY_MISSING]="Missing dependency"
    [$ERR_NETWORK_FAILED]="Network operation failed"
    [$ERR_STORAGE_FAILED]="Storage operation failed"
    [$ERR_SECURITY_FAILED]="Security check failed"
)

# Handle error
# Usage: handle_error <code> <message>
handle_error() {
    local code=$1
    local message=$2
    local err_msg="${ERR_MSGS[$code]:-Unknown error}"

    log_error "[$code] $err_msg: $message"
    return $code
}

# Check if command exists
# Usage: check_command <command>
check_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        handle_error $ERR_DEPENDENCY_MISSING "Command not found: $1"
        return $ERR_DEPENDENCY_MISSING
    fi
}

# Check if file exists
# Usage: check_file <file>
check_file() {
    if [ ! -f "$1" ]; then
        handle_error $ERR_FILE_NOT_FOUND "File not found: $1"
        return $ERR_FILE_NOT_FOUND
    fi
}

# Check if directory exists
# Usage: check_dir <directory>
check_dir() {
    if [ ! -d "$1" ]; then
        handle_error $ERR_FILE_NOT_FOUND "Directory not found: $1"
        return $ERR_FILE_NOT_FOUND
    fi
}

# Check if user has permission
# Usage: check_permission <file>
check_permission() {
    if [ ! -w "$1" ]; then
        handle_error $ERR_PERMISSION_DENIED "No write permission: $1"
        return $ERR_PERMISSION_DENIED
    fi
}

# Check if service is running
# Usage: check_service <service>
check_service() {
    if ! systemctl is-active --quiet "$1"; then
        handle_error $ERR_SERVICE_FAILED "Service not running: $1"
        return $ERR_SERVICE_FAILED
    fi
}

# Check if network is available
# Usage: check_network <host>
check_network() {
    if ! ping -c 1 "$1" >/dev/null 2>&1; then
        handle_error $ERR_NETWORK_FAILED "Network unreachable: $1"
        return $ERR_NETWORK_FAILED
    fi
}

# Check if storage is available
# Usage: check_storage <path>
check_storage() {
    if ! df "$1" >/dev/null 2>&1; then
        handle_error $ERR_STORAGE_FAILED "Storage not available: $1"
        return $ERR_STORAGE_FAILED
    fi
}

# Check if security requirements are met
# Usage: check_security <requirement>
check_security() {
    case $1 in
        root)
            if [ "$(id -u)" -ne 0 ]; then
                handle_error $ERR_SECURITY_FAILED "Root privileges required"
                return $ERR_SECURITY_FAILED
            fi
            ;;
        *)
            handle_error $ERR_INVALID_ARG "Unknown security requirement: $1"
            return $ERR_INVALID_ARG
            ;;
    esac
} 