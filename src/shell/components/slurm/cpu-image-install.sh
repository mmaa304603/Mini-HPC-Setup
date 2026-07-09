#!/bin/bash

# Warewulf CPU image SLURM installation
# Installs MUNGE and SLURM client in Warewulf VNFS image

# Source common functions
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load component configuration
load_component_config "slurm" 2>/dev/null || true
load_component_config "network" 2>/dev/null || true
export_config

check_root

IMAGE_NAME="rockylinux-9.6"

# halt pre-running image commands if exists
rm -rf /var/lib/warewulf/chroots/rockylinux-9.6/run

configure_time_sync() {
    info "Configuring time synchronization in Warewulf CPU image..."

    wwctl image exec "$IMAGE_NAME" -- /bin/bash -c "
        set -e
        dnf -y install chrony

        # Remove existing source and local clock directives, produces one deterministic cluster-time configuration.
        sed -i -E \
            '/^[[:space:]]*(pool|server|makestep)[[:space:]]+/d;
             /^[[:space:]]*rtcsync([[:space:]]|$)/d' \
            /etc/chrony.conf

        printf '%s\n' 'server ${HEAD_NODE_IP} iburst' 'makestep 1.0 3' 'rtcsync' \
            >> /etc/chrony.conf

        # Start chronyd before MUNGE, but do not block MUNGE while waiting for synchronization
        install -d /etc/systemd/system/munge.service.d
        printf '%s\n' '[Unit]' 'Wants=chronyd.service' 'After=chronyd.service' \
            > /etc/systemd/system/munge.service.d/time-sync.conf
        systemctl enable chronyd
    "
}

# Install MUNGE in Warewulf image
install_munge() {
    info "Installing MUNGE in Warewulf CPU image of ${IMAGE_NAME}"

    wwctl image exec "$IMAGE_NAME" -- /bin/bash -c '
        set -e
        export PATH=/usr/sbin:/usr/bin:/sbin:/bin
        
        # Install MUNGE packages in the image
        dnf -y install munge munge-libs
        
        mkdir -p /var/run/munge

        # Set proper ownership and permissions in the image
        chown -R munge:munge /etc/munge /var/lib/munge /var/log/munge /var/run/munge
        chmod 0700 /etc/munge /var/lib/munge
        chmod 0755 /var/log/munge /var/run/munge
        systemctl enable munge

        echo "MUNGE installed in Warewulf image successfully inside image"
    '
    info "MUNGE installed in Warewulf image successfully"
}

# Install SLURM client in Warewulf image
install_slurm() {
    info "Installing SLURM client in Warewulf CPU image..."
    
    # Install SLURM packages in the image
    wwctl image exec "$IMAGE_NAME" -- /bin/bash -c '
        set -e
        export PATH=/usr/sbin:/usr/bin:/sbin:/bin

        dnf -y install slurm slurm-slurmd
        # dnf -y install slurm-wlm slurmd slurm-client
    '
    
    info "SLURM client installed in Warewulf image successfully"
}

# Configure SLURM client in Warewulf image
configure_slurm() {
    info "Configuring SLURM client in Warewulf CPU image..."

    : "${SLURM_UID:?SLURM_UID must be defined in components/slurm/slurm.conf}"
    : "${SLURM_GID:?SLURM_GID must be defined in components/slurm/slurm.conf}"
    
    # Create SLURM directories in the image
    wwctl image exec "$IMAGE_NAME" -- \
        /usr/bin/env SLURM_UID="$SLURM_UID" SLURM_GID="$SLURM_GID" \
        /bin/bash -c '
        set -e
        export PATH=/usr/sbin:/usr/bin:/sbin:/bin

        # Create service account when absent and align existing accounts with the controller IDssudo 
        target_group="$(getent group "$SLURM_GID" | cut -d: -f1 || true)"
        if getent group slurm >/dev/null; then
            current_gid="$(getent group slurm | cut -d: -f3)"
            if [ "$current_gid" != "$SLURM_GID" ]; then
                if [ -n "$target_group" ] && [ "$target_group" != slurm ]; then
                    echo "GID $SLURM_GID is already used by group $target_group" >&2
                    exit 1
                fi
                groupmod --gid "$SLURM_GID" slurm
            fi
        else
            if [ -n "$target_group" ]; then
                echo "GID $SLURM_GID is already used by group $target_group" >&2
                exit 1
            fi
            groupadd --system --gid "$SLURM_GID" slurm
        fi

        target_user="$(getent passwd "$SLURM_UID" | cut -d: -f1 || true)"
        if id slurm >/dev/null 2>&1; then
            current_uid="$(id -u slurm)"
            if [ "$current_uid" != "$SLURM_UID" ]; then
                if [ -n "$target_user" ] && [ "$target_user" != slurm ]; then
                    echo "UID $SLURM_UID is already used by user $target_user" >&2
                    exit 1
                fi
                usermod --uid "$SLURM_UID" slurm
            fi
            usermod --gid "$SLURM_GID" slurm
        else
            if [ -n "$target_user" ]; then
                echo "UID $SLURM_UID is already used by user $target_user" >&2
                exit 1
            fi
            useradd --system \
                --uid "$SLURM_UID" \
                --gid "$SLURM_GID" \
                --home-dir /var/lib/slurm \
                --shell /sbin/nologin \
                slurm
        fi

        # Create SLURM directories in the image.
        mkdir -p /var/lib/slurm /var/log/slurm /var/spool/slurm /var/spool/slurmd
        chown -R slurm:slurm /var/lib/slurm /var/log/slurm /var/spool/slurm
        chmod 0755 /var/log/slurm /var/spool/slurm /var/spool/slurmd
        
        # Enable SLURM compute daemon in the image
        systemctl enable slurmd
    '

    info "SLURM client configuration completed in Warewulf image"
}

copy_slurm_config() {
    info "Copying SLURM configuration to Warewulf CPU image..."

    if [ ! -f /etc/slurm/slurm.conf ]; then
        error "Missing /etc/slurm/slurm.conf; run head-install.sh first"
        return 1
    fi

    local bind_args=(--bind /etc/slurm/slurm.conf:/tmp/slurm.conf:ro)
    for script in prolog.sh epilog.sh; do
        [ ! -f "/etc/slurm/$script" ] ||
            bind_args+=(--bind "/etc/slurm/$script:/tmp/$script:ro")
    done

    wwctl image exec "${bind_args[@]}" "$IMAGE_NAME" -- /bin/bash -c '
        set -e
        install -D -o root -g root -m 0644 /tmp/slurm.conf /etc/slurm/slurm.conf
        for script in prolog.sh epilog.sh; do
            [ ! -f "/tmp/$script" ] ||
                install -o root -g root -m 0755 "/tmp/$script" "/etc/slurm/$script"
        done
    '
}

# Copy MUNGE key to Warewulf image
copy_munge_key() {
    info "Copying MUNGE key to Warewulf CPU image..."
    
    # Copy MUNGE key from head node to the image
    if [ -f "/etc/munge/munge.key" ]; then
        wwctl image exec \
            --bind /etc/munge/munge.key:/tmp/munge.key:ro \
            "$IMAGE_NAME" -- /bin/bash -c '
                set -e
                export PATH=/usr/sbin:/usr/bin:/sbin:/bin

                mkdir -p /etc/munge
                cp /tmp/munge.key /etc/munge/munge.key
                chown munge:munge /etc/munge/munge.key
                chmod 0400 /etc/munge/munge.key
            '

        info "MUNGE key copied to Warewulf image successfully"
    else
        error "MUNGE key not found at /etc/munge/munge.key"
        error "Run head-install.sh first to generate the key"
        return 1
    fi
}

main() {
    info "Starting Warewulf CPU image SLURM setup..."
    
    # Check if Warewulf is running
    if ! command -v wwctl >/dev/null 2>&1; then
        error "Warewulf not found. Install Warewulf first."
        return 1
    fi
    
    # Install MUNGE in the image
    configure_time_sync
    install_munge
    
    # Install SLURM client in the image
    install_slurm
    configure_slurm
    copy_slurm_config
    
    # Copy MUNGE key to the image
    copy_munge_key
    
    info "CPU image SLURM setup completed successfully"
    info "Rebuild and deploy the VNFS image to apply changes"
}

main "$@"
