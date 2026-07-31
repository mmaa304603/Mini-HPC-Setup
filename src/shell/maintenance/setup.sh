#!/bin/bash
set -euo pipefail

# Source library scripts
source "$(dirname "$0")/../lib/functions.sh"
source "$(dirname "$0")/../lib/config.sh"

# Load configuration
source "$(dirname "$0")/../components/grafana/monitoring.conf"

export_config

# Install Elasticsearch
install_elasticsearch() {
    if [ "$ELASTICSEARCH_ENABLED" != "true" ]; then
        info "Elasticsearch installation is disabled"
        return 0
    fi
    
    info "Installing Elasticsearch..."
    
    # Add Elasticsearch repository
    rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
    cat > /etc/yum.repos.d/elasticsearch.repo << EOF
[elasticsearch]
name=Elasticsearch repository
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
    
    # Install Elasticsearch
    dnf install -y elasticsearch
    
    # Configure Elasticsearch
    cat > /etc/elasticsearch/elasticsearch.yml << EOF
cluster.name: $ELASTICSEARCH_CLUSTER_NAME
node.name: $ELASTICSEARCH_NODE_NAME
network.host: $ELASTICSEARCH_HOST
http.port: $ELASTICSEARCH_PORT
discovery.type: single-node
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
EOF

    info "Allowing elasticsearch user to create the keystore, locking config dir back down"
    chown root:elasticsearch /etc/elasticsearch
    chmod 2750 /etc/elasticsearch

    if [ ! -f /etc/elasticsearch/elasticsearch.keystore ]; then
        chmod g+w /etc/elasticsearch
        runuser -u elasticsearch -- /usr/share/elasticsearch/bin/elasticsearch-keystore create
        chmod g-w /etc/elasticsearch
    fi

    info "Double checking Elasticsearch keystore permissions"
    chown root:elasticsearch /etc/elasticsearch/elasticsearch.keystore
    chmod 660 /etc/elasticsearch/elasticsearch.keystore
    
    # Start and enable Elasticsearch
    systemctl enable --now elasticsearch
    
    info "Elasticsearch installed successfully"
}

# Install Logstash
install_logstash() {
    if [ "$LOGSTASH_ENABLED" != "true" ]; then
        info "Logstash installation is disabled"
        return 0
    fi
    
    info "Installing Logstash..."
    
    # Install Logstash
    dnf install -y logstash
    
    # Configure Logstash
    ensure_dir "$LOGSTASH_CONF_DIR"
    cat > "$LOGSTASH_CONF_DIR/slurm.conf" << EOF
input {
  beats {
    port => $LOGSTASH_BEATS_PORT
  }
}

filter {
  if [type] == "slurm" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{WORD:component} %{GREEDYDATA:message}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["$KIBANA_ELASTICSEARCH_HOST"]
    index => "slurm-%{+YYYY.MM.dd}"
  }
}
EOF
    
    # Start and enable Logstash
    systemctl enable --now logstash
    
    info "Logstash installed successfully"
}

# Install Kibana
install_kibana() {
    if [ "$KIBANA_ENABLED" != "true" ]; then
        info "Kibana installation is disabled"
        return 0
    fi
    
    info "Installing Kibana..."
    
    # Install Kibana
    dnf install -y kibana
    
    # Configure Kibana
    cat > /etc/kibana/kibana.yml << EOF
server.port: $KIBANA_PORT
server.host: "$KIBANA_HOST"
elasticsearch.hosts: ["http://$KIBANA_ELASTICSEARCH_HOST"]
EOF
    
    # Start and enable Kibana
    systemctl enable --now kibana
    
    info "Kibana installed successfully"
}

# Install Grafana
install_grafana() {
    if [ "$GRAFANA_ENABLED" != "true" ]; then
        info "Grafana installation is disabled"
        return 0
    fi
    
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
    dnf install -y grafana
    
    # Configure Grafana
    cat > /etc/grafana/grafana.ini << EOF
[server]
http_port = $GRAFANA_PORT
domain = $GRAFANA_DOMAIN
root_url = %(protocol)s://%(domain)s:%(http_port)s/

[security]
admin_user = $GRAFANA_ADMIN_USER
admin_password = $GRAFANA_ADMIN_PASSWORD

[auth.anonymous]
enabled = $GRAFANA_ANONYMOUS_ENABLED
org_role = $GRAFANA_ANONYMOUS_ROLE
EOF
    
    # Start and enable Grafana
    systemctl enable --now grafana-server
    
    info "Grafana installed successfully"
}

# Configure Filebeat
configure_filebeat() {
    if [ "$FILEBEAT_ENABLED" != "true" ]; then
        info "Filebeat configuration is disabled"
        return 0
    fi
    
    info "Configuring Filebeat..."
    
    # Install Filebeat
    dnf install -y filebeat
    
    # Configure Filebeat
    cat > /etc/filebeat/filebeat.yml << EOF
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - ${FILEBEAT_LOG_PATHS[0]}
  fields:
    type: $FILEBEAT_LOG_TYPE

output.logstash:
  hosts: ["$FILEBEAT_LOGSTASH_HOST"]

logging.level: info
EOF
    
    # Start and enable Filebeat
    systemctl enable --now filebeat
    
    info "Filebeat configured successfully"
}

# Main execution
main() {
    check_root
    
    install_elasticsearch
    install_logstash
    install_kibana
    install_grafana
    configure_filebeat
    
    info "Monitoring setup completed successfully"
}

main "$@"
