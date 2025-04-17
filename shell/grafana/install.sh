#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Check if running as root
check_root

# Install dependencies for Grafana
install_grafana_dependencies() {
    info "Installing Grafana dependencies..."
    
    local packages=(
        "wget"
        "curl"
        "unzip"
        "tar"
        "gzip"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Install Grafana
install_grafana() {
    info "Installing Grafana..."
    
    # Add Grafana repository
    cat > /etc/yum.repos.d/grafana.repo << EOF
[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
    
    # Install Grafana
    install_package "grafana" || {
        error "Failed to install Grafana"
        return 1
    }
    
    # Configure Grafana
    configure_grafana
    
    # Start Grafana
    systemctl enable grafana-server
    systemctl start grafana-server
    
    # Wait for Grafana to be ready
    wait_for_service "grafana-server" "http://localhost:3000/api/health" || {
        error "Grafana failed to start"
        return 1
    }
    
    info "Grafana installed and started successfully"
}

# Configure Grafana
configure_grafana() {
    info "Configuring Grafana..."
    
    # Backup original config
    cp /etc/grafana/grafana.ini /etc/grafana/grafana.ini.bak
    
    # Create new config
    cat > /etc/grafana/grafana.ini << EOF
[server]
http_port = 3000
domain = $(hostname)
root_url = %(protocol)s://%(domain)s:%(http_port)s/
serve_from_sub_path = false

[security]
admin_user = admin
admin_password = changeme

[auth.anonymous]
enabled = false

[users]
allow_sign_up = false

[dashboards]
min_refresh_interval = 5s

[paths]
data = /var/lib/grafana
logs = /var/log/grafana
plugins = /var/lib/grafana/plugins

[log]
mode = file
level = info
files = /var/log/grafana/grafana.log

[snapshots]
external_enabled = true
EOF
    
    # Create directories for provisioning
    mkdir -p /etc/grafana/provisioning/datasources
    mkdir -p /etc/grafana/provisioning/dashboards
    mkdir -p /var/lib/grafana/dashboards
    
    # Configure datasources
    cat > /etc/grafana/provisioning/datasources/datasources.yaml << EOF
apiVersion: 1

datasources:
  - name: Elasticsearch
    type: elasticsearch
    access: proxy
    url: http://localhost:9200
    jsonData:
      esVersion: 7.10.0
      timeField: "@timestamp"
    secureJsonData:
      basicAuthUser: "elastic"
      basicAuthPassword: "changeme"

  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
EOF
    
    # Configure dashboards
    cat > /etc/grafana/provisioning/dashboards/dashboards.yaml << EOF
apiVersion: 1

providers:
  - name: 'HPC Dashboards'
    orgId: 1
    folder: 'HPC'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF
    
    # Create HPC dashboard
    create_hpc_dashboard
    
    info "Grafana configured successfully"
}

# Create HPC dashboard
create_hpc_dashboard() {
    info "Creating HPC dashboard..."
    
    # Create a basic HPC dashboard
    cat > /var/lib/grafana/dashboards/hpc-dashboard.json << EOF
{
  "annotations": {
    "list": [
      {
        "builtIn": 1,
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": true,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Annotations & Alerts",
        "type": "dashboard"
      }
    ]
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": 1,
  "links": [],
  "panels": [
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 0,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 2,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.5.5",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[1m])) * 100)",
          "interval": "",
          "legendFormat": "CPU Usage",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "CPU Usage",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "percent",
          "label": null,
          "logBase": 1,
          "max": "100",
          "min": "0",
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    },
    {
      "aliasColors": {},
      "bars": false,
      "dashLength": 10,
      "dashes": false,
      "datasource": "Prometheus",
      "fieldConfig": {
        "defaults": {
          "custom": {}
        },
        "overrides": []
      },
      "fill": 1,
      "fillGradient": 0,
      "gridPos": {
        "h": 8,
        "w": 12,
        "x": 12,
        "y": 0
      },
      "hiddenSeries": false,
      "id": 3,
      "legend": {
        "avg": false,
        "current": false,
        "max": false,
        "min": false,
        "show": true,
        "total": false,
        "values": false
      },
      "lines": true,
      "linewidth": 1,
      "nullPointMode": "null",
      "options": {
        "alertThreshold": true
      },
      "percentage": false,
      "pluginVersion": "7.5.5",
      "pointradius": 2,
      "points": false,
      "renderer": "flot",
      "seriesOverrides": [],
      "spaceLength": 10,
      "stack": false,
      "steppedLine": false,
      "targets": [
        {
          "expr": "100 * (1 - ((node_memory_MemAvailable_bytes or node_memory_MemFree_bytes) / node_memory_MemTotal_bytes))",
          "interval": "",
          "legendFormat": "Memory Usage",
          "refId": "A"
        }
      ],
      "thresholds": [],
      "timeFrom": null,
      "timeRegions": [],
      "timeShift": null,
      "title": "Memory Usage",
      "tooltip": {
        "shared": true,
        "sort": 0,
        "value_type": "individual"
      },
      "type": "graph",
      "xaxis": {
        "buckets": null,
        "mode": "time",
        "name": null,
        "show": true,
        "values": []
      },
      "yaxes": [
        {
          "format": "percent",
          "label": null,
          "logBase": 1,
          "max": "100",
          "min": "0",
          "show": true
        },
        {
          "format": "short",
          "label": null,
          "logBase": 1,
          "max": null,
          "min": null,
          "show": true
        }
      ],
      "yaxis": {
        "align": false,
        "alignLevel": null
      }
    }
  ],
  "refresh": "5s",
  "schemaVersion": 26,
  "style": "dark",
  "tags": [],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-6h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "HPC Dashboard",
  "uid": "hpc",
  "version": 1
}
EOF
    
    info "HPC dashboard created successfully"
}

# Create admin user
create_admin_user() {
    info "Creating admin user..."
    
    # Wait for Grafana to be ready
    wait_for_service "grafana-server" "http://localhost:3000/api/health" || {
        error "Grafana is not running"
        return 1
    }
    
    # Create admin user
    curl -X POST "http://localhost:3000/api/admin/users" \
         -H "Content-Type: application/json" \
         -d '{"email":"admin@example.com","login":"admin","password":"changeme"}' || {
        error "Failed to create admin user"
        return 1
    }
    
    info "Admin user created successfully"
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    # Install dependencies
    install_grafana_dependencies
    
    # Install and configure Grafana
    install_grafana
    
    # Create admin user
    create_admin_user
    
    info "Grafana installation completed successfully"
}

main "$@" 