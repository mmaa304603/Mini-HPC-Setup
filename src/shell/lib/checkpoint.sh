#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/logging.sh"

# Checkpoint directory
CHECKPOINT_DIR="${LOG_DIR}/checkpoints"

# Initialize checkpoint system
init_checkpoints() {
    mkdir -p "${CHECKPOINT_DIR}"
    log_info "Checkpoint system initialized at ${CHECKPOINT_DIR}"
}

# Create a checkpoint
create_checkpoint() {
    local checkpoint_name="$1"
    local checkpoint_file="${CHECKPOINT_DIR}/${checkpoint_name}.checkpoint"
    
    if [ -z "$checkpoint_name" ]; then
        log_error "Checkpoint name is required"
        return 1
    fi
    
    # Create checkpoint with timestamp
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "${checkpoint_file}"
    log_info "Created checkpoint: ${checkpoint_name}"
    return 0
}

# Verify a checkpoint exists
verify_checkpoint() {
    local checkpoint_name="$1"
    local checkpoint_file="${CHECKPOINT_DIR}/${checkpoint_name}.checkpoint"
    
    if [ -z "$checkpoint_name" ]; then
        log_error "Checkpoint name is required"
        return 1
    fi
    
    if [ -f "${checkpoint_file}" ]; then
        local checkpoint_time=$(cat "${checkpoint_file}")
        log_info "Found checkpoint ${checkpoint_name} created at ${checkpoint_time}"
        return 0
    else
        log_error "Checkpoint ${checkpoint_name} not found"
        return 1
    fi
}

# List all checkpoints
list_checkpoints() {
    if [ ! -d "${CHECKPOINT_DIR}" ]; then
        log_error "Checkpoint directory not found"
        return 1
    fi
    
    log_info "Available checkpoints:"
    for checkpoint in "${CHECKPOINT_DIR}"/*.checkpoint; do
        if [ -f "$checkpoint" ]; then
            local name=$(basename "$checkpoint" .checkpoint)
            local time=$(cat "$checkpoint")
            echo "  - ${name}: ${time}"
        fi
    done
    return 0
}

# Clear a specific checkpoint
clear_checkpoint() {
    local checkpoint_name="$1"
    local checkpoint_file="${CHECKPOINT_DIR}/${checkpoint_name}.checkpoint"
    
    if [ -z "$checkpoint_name" ]; then
        log_error "Checkpoint name is required"
        return 1
    fi
    
    if [ -f "${checkpoint_file}" ]; then
        rm "${checkpoint_file}"
        log_info "Cleared checkpoint: ${checkpoint_name}"
        return 0
    else
        log_error "Checkpoint ${checkpoint_name} not found"
        return 1
    fi
}

# Clear all checkpoints
clear_all_checkpoints() {
    if [ -d "${CHECKPOINT_DIR}" ]; then
        rm -f "${CHECKPOINT_DIR}"/*.checkpoint
        log_info "Cleared all checkpoints"
        return 0
    else
        log_error "Checkpoint directory not found"
        return 1
    fi
}

# Run initialization if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_checkpoints
fi 