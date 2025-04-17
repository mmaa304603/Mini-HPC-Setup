#!/bin/bash

# Source common functions and configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/common/functions.sh"
source "${SCRIPT_DIR}/common/config.sh"
source "${SCRIPT_DIR}/utils/validate.sh"
source "${SCRIPT_DIR}/utils/checkpoint.sh"

# Function to create log directory
setup_logging() {
    mkdir -p "${LOG_DIR}"
    exec 1> >(tee -a "${LOG_DIR}/setup.log")
    exec 2> >(tee -a "${LOG_DIR}/setup.log" >&2)
    log_info "Logging initialized to ${LOG_DIR}/setup.log"
}

# Function to run installation scripts with checkpoints
run_installations() {
    local failed=0
    
    # Initialize checkpoint system
    init_checkpoints
    
    # Network setup
    if [ "${NETWORK_SETUP_ENABLED}" = true ]; then
        if ! verify_checkpoint "network_setup"; then
            log_info "Running network setup..."
            if ! "${SCRIPT_DIR}/network/setup.sh"; then
                log_error "Network setup failed"
                failed=1
            else
                create_checkpoint "network_setup"
            fi
        else
            log_info "Network setup checkpoint found, skipping..."
        fi
    fi
    
    # SLURM setup
    if [ "${SLURM_ENABLED}" = true ]; then
        if ! verify_checkpoint "slurm_setup"; then
            log_info "Running SLURM setup..."
            if ! "${SCRIPT_DIR}/slurm/setup.sh"; then
                log_error "SLURM setup failed"
                failed=1
            else
                create_checkpoint "slurm_setup"
            fi
        else
            log_info "SLURM setup checkpoint found, skipping..."
        fi
    fi
    
    # Spack setup
    if [ "${SPACK_ENABLED}" = true ]; then
        if ! verify_checkpoint "spack_setup"; then
            log_info "Running Spack setup..."
            if ! "${SCRIPT_DIR}/spack/setup.sh"; then
                log_error "Spack setup failed"
                failed=1
            else
                create_checkpoint "spack_setup"
            fi
        else
            log_info "Spack setup checkpoint found, skipping..."
        fi
    fi
    
    # Monitoring setup
    if [ "${MONITORING_ENABLED}" = true ]; then
        if ! verify_checkpoint "monitoring_setup"; then
            log_info "Running monitoring setup..."
            if ! "${SCRIPT_DIR}/monitoring/setup.sh"; then
                log_error "Monitoring setup failed"
                failed=1
            else
                create_checkpoint "monitoring_setup"
            fi
        else
            log_info "Monitoring setup checkpoint found, skipping..."
        fi
    fi
    
    return $failed
}

# Function to handle command line arguments
handle_args() {
    local action=""
    local checkpoint=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list-checkpoints)
                list_checkpoints
                exit 0
                ;;
            --clear-checkpoint)
                checkpoint="$2"
                shift 2
                if [ -n "$checkpoint" ]; then
                    clear_checkpoint "$checkpoint"
                else
                    log_error "Checkpoint name required for --clear-checkpoint"
                    exit 1
                fi
                ;;
            --clear-all-checkpoints)
                clear_all_checkpoints
                exit 0
                ;;
            --step)
                action="$2"
                shift 2
                case $action in
                    network)
                        NETWORK_SETUP_ENABLED=true
                        SLURM_ENABLED=false
                        SPACK_ENABLED=false
                        MONITORING_ENABLED=false
                        ;;
                    slurm)
                        NETWORK_SETUP_ENABLED=false
                        SLURM_ENABLED=true
                        SPACK_ENABLED=false
                        MONITORING_ENABLED=false
                        ;;
                    spack)
                        NETWORK_SETUP_ENABLED=false
                        SLURM_ENABLED=false
                        SPACK_ENABLED=true
                        MONITORING_ENABLED=false
                        ;;
                    monitoring)
                        NETWORK_SETUP_ENABLED=false
                        SLURM_ENABLED=false
                        SPACK_ENABLED=false
                        MONITORING_ENABLED=true
                        ;;
                    all)
                        NETWORK_SETUP_ENABLED=true
                        SLURM_ENABLED=true
                        SPACK_ENABLED=true
                        MONITORING_ENABLED=true
                        ;;
                    *)
                        log_error "Invalid step: $action"
                        exit 1
                        ;;
                esac
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    # Check for root privileges
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Setup logging
    setup_logging
    
    # Handle command line arguments
    handle_args "$@"
    
    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed. Please fix the issues and try again."
        exit 1
    fi
    
    # Run installations
    if ! run_installations; then
        log_error "One or more installation steps failed. Check the logs for details."
        exit 1
    fi
    
    log_info "Setup completed successfully"
    exit 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 