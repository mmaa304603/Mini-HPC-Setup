#!/bin/bash

# Input validation utility for HPC cluster setup
# Version: 1.0.0

# Source error handling utility
source "$(dirname "$0")/error.sh"

# Validate IP address
# Usage: validate_ip <ip>
validate_ip() {
    local ip=$1
    local octet='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
    local pattern="^$octet\.$octet\.$octet\.$octet$"

    if [[ ! $ip =~ $pattern ]]; then
        handle_error $ERR_INVALID_ARG "Invalid IP address: $ip"
        return $ERR_INVALID_ARG
    fi
}

# Validate hostname
# Usage: validate_hostname <hostname>
validate_hostname() {
    local hostname=$1
    local pattern='^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?$'

    if [[ ! $hostname =~ $pattern ]]; then
        handle_error $ERR_INVALID_ARG "Invalid hostname: $hostname"
        return $ERR_INVALID_ARG
    fi
}

# Validate port number
# Usage: validate_port <port>
validate_port() {
    local port=$1

    if [[[ ! $port =~ ^[0-9]+$ ]] || [ $port -lt 1 ] || [ $port -gt 65535 ]]; then
        handle_error $ERR_INVALID_ARG "Invalid port number: $port"
        return $ERR_INVALID_ARG
    fi
}

# Validate path
# Usage: validate_path <path>
validate_path() {
    local path=$1

    if [[ ! $path =~ ^/ ]]; then
        handle_error $ERR_INVALID_ARG "Invalid path (must be absolute): $path"
        return $ERR_INVALID_ARG
    fi
}

# Validate username
# Usage: validate_username <username>
validate_username() {
    local username=$1
    local pattern='^[a-z_][a-z0-9_-]*$'

    if [[ ! $username =~ $pattern ]]; then
        handle_error $ERR_INVALID_ARG "Invalid username: $username"
        return $ERR_INVALID_ARG
    fi
}

# Validate password
# Usage: validate_password <password>
validate_password() {
    local password=$1

    if [ ${#password} -lt 8 ]; then
        handle_error $ERR_INVALID_ARG "Password too short (minimum 8 characters)"
        return $ERR_INVALID_ARG
    fi
}

# Validate email
# Usage: validate_email <email>
validate_email() {
    local email=$1
    local pattern='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

    if [[ ! $email =~ $pattern ]]; then
        handle_error $ERR_INVALID_ARG "Invalid email address: $email"
        return $ERR_INVALID_ARG
    fi
}

# Validate number
# Usage: validate_number <number> <min> <max>
validate_number() {
    local number=$1
    local min=$2
    local max=$3

    if [[ ! $number =~ ^[0-9]+$ ]] || [ $number -lt $min ] || [ $number -gt $max ]; then
        handle_error $ERR_INVALID_ARG "Invalid number (must be between $min and $max): $number"
        return $ERR_INVALID_ARG
    fi
}

# Validate boolean
# Usage: validate_boolean <value>
validate_boolean() {
    local value=$1

    if [[ ! $value =~ ^(true|false)$ ]]; then
        handle_error $ERR_INVALID_ARG "Invalid boolean value: $value"
        return $ERR_INVALID_ARG
    fi
}

# Validate array
# Usage: validate_array <array> <separator>
validate_array() {
    local array=$1
    local separator=$2

    if [ -z "$array" ]; then
        handle_error $ERR_INVALID_ARG "Empty array"
        return $ERR_INVALID_ARG
    fi

    IFS=$separator read -ra elements <<< "$array"
    if [ ${#elements[@]} -eq 0 ]; then
        handle_error $ERR_INVALID_ARG "Invalid array format"
        return $ERR_INVALID_ARG
    fi
} 