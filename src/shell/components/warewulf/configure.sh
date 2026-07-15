#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load network configuration for IP-related values
load_component_config "network"
export_config

# Load compute node definitions if present
NODES_DEF_FILE="$(dirname "$0")/nodes.conf"
if [ -f "$NODES_DEF_FILE" ]; then
    info "Loading compute node definitions from $NODES_DEF_FILE"
    source "$NODES_DEF_FILE"
else
    warn "nodes.conf not found; compute node operations will be skipped unless arrays are set elsewhere"
fi

patch_dhcp_config() {
    local dhcp_conf="/etc/dhcp/dhcpd.conf"
    local subnet_line="subnet ${NETWORK} netmask ${NETWORK_MASK} {"
    info "Patching DHCP configuration..."

    if [ ! -f "$dhcp_conf" ]; then
        warn "$dhcp_conf not found; skipping DHCP patch"
        return 0
    fi

    if ! grep -q "ignore-client-uids true;" "$dhcp_conf"; then
        sed -i "/${subnet_line}/a\\    ignore-client-uids true;" "$dhcp_conf" || {
            error "Failed to add ignore-client-uids to DHCP config"
            return 1
        }
    fi

    for i in "${!COMPUTE_NODES[@]}"; do
        local node="${COMPUTE_NODES[$i]}"
        local ip="${COMPUTE_NODE_IPS[$i]:-}"
        local hwaddr="${COMPUTE_NODE_HWADDRS[$i]:-}"

        [ -n "$ip" ] && [ -n "$hwaddr" ] || continue
        grep -qi "$hwaddr" "$dhcp_conf" && continue

        {
            echo ""
            echo "host ${node} {"
            echo "    hardware ethernet ${hwaddr};"
            echo "    fixed-address ${ip};"
            echo "    option host-name \"${node}\";"
            echo "}"
        } >> "$dhcp_conf" || {
            error "Failed to add DHCP reservation for $node"
            return 1
        }
    done

    if [ -n "${BLOCKED_MAC:-}" ] && ! grep -qi "$BLOCKED_MAC" "$dhcp_conf"; then
        echo "Disabling $BLOCKED_MAC from DHCP..."
        {
            echo ""
            echo "host blocked-device {"
            echo "    hardware ethernet ${BLOCKED_MAC};"
            echo "    deny booting;"
            echo "}"
        } >> "$dhcp_conf" || {
            error "Failed to add blocked device to DHCP config"
            return 1
        }
    fi
}

regenerate_dhcp_config() {
    info "Regenerating DHCP configuration from Warewulf..."

    wwctl configure dhcp || {
        error "Failed to regenerate DHCP configuration"
        return 1
    }

    truncate -s 0 /var/lib/dhcpd/dhcpd.leases

    patch_dhcp_config || return 1

    systemctl restart dhcpd || {
        error "Failed to restart DHCP service"
        return 1
    }
}

# Update Warewulf configuration (post-installation)
update_warewulf_config() {
    info "Updating Warewulf configuration..."
    
    # Backup existing configuration
    if [ -f "/etc/warewulf/warewulf.conf" ]; then
        cp "/etc/warewulf/warewulf.conf" "/etc/warewulf/warewulf.conf.backup.$(date +%Y%m%d_%H%M%S)"
        info "Backed up existing configuration"
    fi
    
    # Update configuration with network-specific values
    sed -i "s/ipaddr: 10.0.0.1/ipaddr: ${HEAD_NODE_IP}/" /etc/warewulf/warewulf.conf
    sed -i "s/netmask: 255.255.252.0/netmask: ${NETWORK_MASK}/" /etc/warewulf/warewulf.conf
    sed -i "s/network: 10.0.0.0/network: ${NETWORK}/" /etc/warewulf/warewulf.conf
    sed -i "s/range start: 10.0.1.1/range start: ${DHCP_START}/" /etc/warewulf/warewulf.conf
    sed -i "s/range end: 10.0.1.255/range end: ${DHCP_END}/" /etc/warewulf/warewulf.conf
    regenerate_dhcp_config || return 1

    # Restart Warewulf service
    systemctl restart warewulfd || {
        error "Failed to restart Warewulf service"
        return 1
    }
    
    info "Warewulf configuration updated successfully"
}

# Update VNFS image (post-installation)
update_vnfs() {
    info "Updating VNFS image..."
    
    # Check if image exists, if not create it
    if ! wwctl image list | grep -q "rockylinux-9.6"; then
        info "VNFS image not found, creating new image..."
        wwctl image import "docker://ghcr.io/warewulf/warewulf-rockylinux:9.6" "rockylinux-9.6" --build || {
            error "Failed to import base node image"
            return 1
        }
    else
        info "VNFS image already exists, updating..."
        wwctl image build "rockylinux-9.6" || {
            error "Failed to rebuild VNFS image"
            return 1
        }
    fi
    
    info "VNFS image update completed"
}

configure_shared_opt_mount_overlay() {
    local mount_script

    info "Configuring Warewulf init script to mount shared /opt..."

    mount_script="$(mktemp)"
    cat > "$mount_script" <<'EOF'
#!/bin/sh

echo "Warewulf prescript: mount shared /opt"

mkdir -p /opt

if mountpoint -q /opt; then
    exit 0
fi

for attempt in 1 2 3 4 5; do
    if mount /opt; then
        exit 0
    fi
    sleep 2
done

echo "Warning: failed to mount shared /opt"
EOF

    wwctl overlay import -p -o wwinit "$mount_script" /warewulf/init.d/85-mount-opt || {
        rm -f "$mount_script"
        error "Failed to import /opt mount script into Warewulf wwinit overlay"
        return 1
    }

    wwctl overlay chmod wwinit /warewulf/init.d/85-mount-opt 0755 || {
        rm -f "$mount_script"
        error "Failed to mark /opt mount script executable in Warewulf wwinit overlay"
        return 1
    }

    rm -f "$mount_script"
    info "Warewulf /opt mount script configured"
}

# Remove existing compute nodes defined in nodes.conf
remove_existing_nodes() {
    info "Removing existing configured compute nodes..."

    for node in "${COMPUTE_NODES[@]}"; do
        if wwctl node list "$node" >/dev/null 2>&1; then
            info "Deleting existing node $node..."
            wwctl node delete "$node" -y || {
                error "Failed to delete existing node $node"
                return 1
            }
        fi
    done
}

# Configure compute nodes
configure_compute_nodes() {
    info "Configuring compute nodes..."
        
    # Remove expsting nodes to prevent confusion
    remove_existing_nodes || {
        error "Failed to remove existing compute nodes"
        return 1
    }
    
    # Guard: skip if arrays are undefined or empty
    if [ "${#COMPUTE_NODES[@]}" -eq 0 ] || [ "${#COMPUTE_NODE_IPS[@]}" -eq 0 ]; then
        warn "No compute nodes defined; skipping compute node configuration"
        return 0
    fi

    if [ "${#COMPUTE_NODE_HWADDRS[@]}" -eq 0 ]; then
        warn "No COMPUTE_NODE_HWADDRS defined; DHCP leases will stay within the configured pool, but physical node-to-IP order is not guaranteed"
    elif [ "${#COMPUTE_NODE_HWADDRS[@]}" -ne "${#COMPUTE_NODES[@]}" ]; then
        warn "COMPUTE_NODE_HWADDRS count does not match COMPUTE_NODES; missing entries will be ignored"
    fi

    for i in "${!COMPUTE_NODES[@]}"; do
        local node="${COMPUTE_NODES[$i]}"
        local ip="${COMPUTE_NODE_IPS[$i]}"
        local hwaddr="${COMPUTE_NODE_HWADDRS[$i]:-}"
        
        if [ -n "$hwaddr" ]; then
            info "Configuring node $node ($ip, $hwaddr)..."
            wwctl node add "$node" --ipaddr "$ip" --hwaddr "$hwaddr" --discoverable=true || {
                error "Failed to add node $node"
                continue
            }
        else
            info "Configuring node $node ($ip)..."
            wwctl node add "$node" --ipaddr "$ip" --discoverable=true || {
                error "Failed to add node $node"
                continue
            }
        fi
        
        # Set node profile
        wwctl node set "$node" --profile default -y || {
            error "Failed to set profile for node $node"
            continue
        }
        
        # Configure node
        wwctl node configure "$node" || {
            error "Failed to configure node $node"
            continue
        }

        wwctl profile set default --image rockylinux-9.6 -y

    done

    regenerate_dhcp_config || return 1
}

# Main execution
main() {
    check_root
    
    # Update Warewulf configuration
    update_warewulf_config
    
    # Update VNFS image
    update_vnfs

    configure_shared_opt_mount_overlay

    # Configure compute nodes
    configure_compute_nodes
    
    info "Warewulf configuration completed successfully"
}

main "$@"
