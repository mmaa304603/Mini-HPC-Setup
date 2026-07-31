#!/bin/bash
set -euo pipefail

# Slurm component orchestrator

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "${SCRIPT_DIR}/../../lib/functions.sh"
source "${SCRIPT_DIR}/../../lib/config.sh"

load_component_config "slurm" 2>/dev/null || true
load_component_config "network" 2>/dev/null || true
load_component_config "warewulf" 2>/dev/null || true
export_config

check_root

main() {
    info "Installing Slurm controller on head node..."
    bash "${SCRIPT_DIR}/head-install.sh"

    if [ "${SLURM_CPU_IMAGE_ENABLED:-true}" = true ]; then
        info "Installing Slurm client into CPU image..."
        bash "${SCRIPT_DIR}/cpu-image-install.sh"
    fi

    if [ "${SLURM_GPU_IMAGE_ENABLED:-false}" = true ]; then
        info "Installing Slurm client into GPU image..."
        bash "${SCRIPT_DIR}/gpu-install.sh"
    fi

    info "Rebuilding Warewulf images and overlays..."

    if [ "${SLURM_CPU_IMAGE_ENABLED:-true}" = true ]; then
        wwctl image build rockylinux-9.6
    fi

    #if [ "${SLURM_GPU_IMAGE_ENABLED:-false}" = true ]; then
    #    wwctl image build ...
    #fi

    wwctl overlay build
    wwctl configure --all

    systemctl restart slurmctld

    info "Slurm component installation completed."
    info "Reboot compute nodes to boot the updated images."
}

main "$@"