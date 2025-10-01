#!/bin/bash

# Logging utility for HPC cluster setup
# Version: 1.0.0

# Default log file
LOG_FILE="${LOG_FILE:-/var/log/hpc-setup.log}"

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Current log level (default: INFO)
LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

# Log a message
# Usage: log <level> <message>
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local level_str

    case $level in
        $LOG_LEVEL_DEBUG) level_str="DEBUG" ;;
        $LOG_LEVEL_INFO)  level_str="INFO"  ;;
        $LOG_LEVEL_WARN)  level_str="WARN"  ;;
        $LOG_LEVEL_ERROR) level_str="ERROR" ;;
        *)                level_str="UNKNOWN" ;;
    esac

    # Only log if level is >= current log level
    if [ $level -ge $LOG_LEVEL ]; then
        echo "[$timestamp] [$level_str] $message" | tee -a "$LOG_FILE"
    fi
}

# Log a debug message
# Usage: log_debug <message>
log_debug() {
    log $LOG_LEVEL_DEBUG "$1"
}

# Log an info message
# Usage: log_info <message>
log_info() {
    log $LOG_LEVEL_INFO "$1"
}

# Log a warning message
# Usage: log_warn <message>
log_warn() {
    log $LOG_LEVEL_WARN "$1"
}

# Log an error message
# Usage: log_error <message>
log_error() {
    log $LOG_LEVEL_ERROR "$1"
}

# Set log level
# Usage: set_log_level <level>
set_log_level() {
    case $1 in
        debug) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        info)  LOG_LEVEL=$LOG_LEVEL_INFO  ;;
        warn)  LOG_LEVEL=$LOG_LEVEL_WARN  ;;
        error) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        *)     log_error "Invalid log level: $1" ;;
    esac
}

# Set log file
# Usage: set_log_file <file>
set_log_file() {
    LOG_FILE="$1"
    touch "$LOG_FILE" 2>/dev/null || {
        log_error "Cannot create log file: $LOG_FILE"
        return 1
    }
} 