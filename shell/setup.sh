#!/bin/bash

# Source common functions
source "$(dirname "$0")/common/functions.sh"

# Check if running as root
check_root

# Parse command line arguments
parse_args() {
    local step="all"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --step)
                step="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--step STEP]"
                echo "Steps:"
                echo "  network    - Configure network settings"
                echo "  warewulf   - Install and configure Warewulf"
                echo "  slurm      - Install and configure SLURM"
                echo "  spack      - Install and configure Spack"
                echo "  modules    - Install and configure Environment Modules"
                echo "  all        - Run all steps (default)"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    echo "$step"
}

# Run network configuration
run_network_config() {
    info "Running network configuration..."
    bash "$(dirname "$0")/utils/network.sh" || {
        error "Network configuration failed"
        return 1
    }
}

# Run Warewulf installation and configuration
run_warewulf_config() {
    info "Running Warewulf installation and configuration..."
    
    # Install Warewulf
    bash "$(dirname "$0")/warewulf/install.sh" || {
        error "Warewulf installation failed"
        return 1
    }
    
    # Configure Warewulf
    bash "$(dirname "$0")/warewulf/configure.sh" || {
        error "Warewulf configuration failed"
        return 1
    }
}

# Run SLURM installation and configuration
run_slurm_config() {
    info "Running SLURM installation and configuration..."
    
    # Install SLURM
    bash "$(dirname "$0")/slurm/install.sh" || {
        error "SLURM installation failed"
        return 1
    }
    
    # Configure SLURM
    bash "$(dirname "$0")/slurm/configure.sh" || {
        error "SLURM configuration failed"
        return 1
    }
}

# Run Spack installation and configuration
run_spack_config() {
    info "Running Spack installation and configuration..."
    
    # Install Spack
    bash "$(dirname "$0")/spack/install.sh" || {
        error "Spack installation failed"
        return 1
    }
}

# Run Environment Modules installation and configuration
run_modules_config() {
    info "Running Environment Modules installation and configuration..."
    
    # Install Environment Modules
    bash "$(dirname "$0")/modules/install.sh" || {
        error "Environment Modules installation failed"
        return 1
    }
}

# Main execution
main() {
    local step
    
    # Create log directory
    ensure_dir "$LOG_DIR"
    
    # Parse command line arguments
    step=$(parse_args "$@")
    
    # Run requested step(s)
    case "$step" in
        network)
            run_network_config
            ;;
        warewulf)
            run_warewulf_config
            ;;
        slurm)
            run_slurm_config
            ;;
        spack)
            run_spack_config
            ;;
        modules)
            run_modules_config
            ;;
        all)
            run_network_config
            run_warewulf_config
            run_slurm_config
            run_spack_config
            run_modules_config
            ;;
        *)
            error "Unknown step: $step"
            exit 1
            ;;
    esac
    
    info "Setup completed successfully"
}

main "$@" 