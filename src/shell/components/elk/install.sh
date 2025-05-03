#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Check if running as root
check_root

# Install dependencies for ELK
install_elk_dependencies() {
    info "Installing ELK dependencies..."
    
    local packages=(
        "java-11-openjdk"
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

# Install Elasticsearch
install_elasticsearch() {
    info "Installing Elasticsearch..."
    
    # Download Elasticsearch
    local es_version="7.17.0"
    local es_url="https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-${es_version}-x86_64.rpm"
    local es_rpm="/tmp/elasticsearch-${es_version}-x86_64.rpm"
    
    download_file "$es_url" "$es_rpm" || {
        error "Failed to download Elasticsearch"
        return 1
    }
    
    # Install Elasticsearch
    install_package "$es_rpm" || {
        error "Failed to install Elasticsearch"
        return 1
    }
    
    # Configure Elasticsearch
    configure_elasticsearch
    
    # Start Elasticsearch
    systemctl enable elasticsearch
    systemctl start elasticsearch
    
    # Wait for Elasticsearch to be ready
    wait_for_service "elasticsearch" "http://localhost:9200" || {
        error "Elasticsearch failed to start"
        return 1
    }
    
    info "Elasticsearch installed and started successfully"
}

# Configure Elasticsearch
configure_elasticsearch() {
    info "Configuring Elasticsearch..."
    
    # Backup original config
    cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.bak
    
    # Create new config
    cat > /etc/elasticsearch/elasticsearch.yml << EOF
cluster.name: hpc-cluster
node.name: $(hostname)
network.host: 0.0.0.0
http.port: 9200
discovery.type: single-node

# Security settings
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true

# Memory settings
bootstrap.memory_lock: true

# Path settings
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch

# Cluster settings
cluster.routing.allocation.disk.threshold_enabled: true
cluster.routing.allocation.disk.watermark.low: 85%
cluster.routing.allocation.disk.watermark.high: 90%
cluster.routing.allocation.disk.watermark.flood_stage: 95%
EOF
    
    # Configure JVM options
    cp /etc/elasticsearch/jvm.options /etc/elasticsearch/jvm.options.bak
    
    # Set heap size to 2GB
    sed -i 's/^-Xms.*/-Xms2g/' /etc/elasticsearch/jvm.options
    sed -i 's/^-Xmx.*/-Xmx2g/' /etc/elasticsearch/jvm.options
    
    # Set system limits
    cat > /etc/security/limits.d/elasticsearch.conf << EOF
elasticsearch soft nofile 65535
elasticsearch hard nofile 65535
elasticsearch soft memlock unlimited
elasticsearch hard memlock unlimited
EOF
    
    # Set system parameters
    cat > /etc/sysctl.d/elasticsearch.conf << EOF
vm.max_map_count=262144
EOF
    sysctl -p /etc/sysctl.d/elasticsearch.conf
    
    info "Elasticsearch configured successfully"
}

# Install Logstash
install_logstash() {
    info "Installing Logstash..."
    
    # Download Logstash
    local ls_version="7.17.0"
    local ls_url="https://artifacts.elastic.co/downloads/logstash/logstash-${ls_version}-x86_64.rpm"
    local ls_rpm="/tmp/logstash-${ls_version}-x86_64.rpm"
    
    download_file "$ls_url" "$ls_rpm" || {
        error "Failed to download Logstash"
        return 1
    }
    
    # Install Logstash
    install_package "$ls_rpm" || {
        error "Failed to install Logstash"
        return 1
    }
    
    # Configure Logstash
    configure_logstash
    
    # Start Logstash
    systemctl enable logstash
    systemctl start logstash
    
    info "Logstash installed and started successfully"
}

# Configure Logstash
configure_logstash() {
    info "Configuring Logstash..."
    
    # Backup original config
    cp /etc/logstash/logstash.yml /etc/logstash/logstash.yml.bak
    
    # Create new config
    cat > /etc/logstash/logstash.yml << EOF
http.host: "0.0.0.0"
xpack.monitoring.elasticsearch.hosts: [ "http://localhost:9200" ]
xpack.monitoring.enabled: true

path.config: /etc/logstash/conf.d
path.logs: /var/log/logstash

pipeline.workers: $(nproc)
pipeline.batch.size: 125
pipeline.batch.delay: 50

queue.type: memory
queue.max_bytes: 1gb

config.reload.automatic: true
config.reload.interval: 3s
EOF
    
    # Create pipeline config
    mkdir -p /etc/logstash/conf.d
    cat > /etc/logstash/conf.d/logstash.conf << EOF
input {
  beats {
    port => 5044
  }
  tcp {
    port => 5000
  }
  syslog {
    port => 5140
  }
}

filter {
  if [type] == "syslog" {
    grok {
      match => { "message" => "%{SYSLOGBASE} %{GREEDYDATA:syslog_message}" }
    }
  }
  
  if [type] == "slurm" {
    grok {
      match => { "message" => "%{TIMESTAMP_ISO8601:timestamp} %{WORD:component} %{GREEDYDATA:slurm_message}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "logstash-%{+YYYY.MM.dd}"
    user => "elastic"
    password => "changeme"
  }
  stdout { codec => rubydebug }
}
EOF
    
    info "Logstash configured successfully"
}

# Install Kibana
install_kibana() {
    info "Installing Kibana..."
    
    # Download Kibana
    local kb_version="7.17.0"
    local kb_url="https://artifacts.elastic.co/downloads/kibana/kibana-${kb_version}-x86_64.rpm"
    local kb_rpm="/tmp/kibana-${kb_version}-x86_64.rpm"
    
    download_file "$kb_url" "$kb_rpm" || {
        error "Failed to download Kibana"
        return 1
    }
    
    # Install Kibana
    install_package "$kb_rpm" || {
        error "Failed to install Kibana"
        return 1
    }
    
    # Configure Kibana
    configure_kibana
    
    # Start Kibana
    systemctl enable kibana
    systemctl start kibana
    
    # Wait for Kibana to be ready
    wait_for_service "kibana" "http://localhost:5601" || {
        error "Kibana failed to start"
        return 1
    }
    
    info "Kibana installed and started successfully"
}

# Configure Kibana
configure_kibana() {
    info "Configuring Kibana..."
    
    # Backup original config
    cp /etc/kibana/kibana.yml /etc/kibana/kibana.yml.bak
    
    # Create new config
    cat > /etc/kibana/kibana.yml << EOF
server.port: 5601
server.host: "0.0.0.0"

elasticsearch.hosts: ["http://localhost:9200"]
elasticsearch.username: "elastic"
elasticsearch.password: "changeme"

monitoring.ui.container.elasticsearch.enabled: true

xpack.security.enabled: true
xpack.security.audit.enabled: true

logging.verbose: true
logging.dest: /var/log/kibana/kibana.log

pid.file: /var/run/kibana/kibana.pid
EOF
    
    info "Kibana configured successfully"
}

# Set up Elasticsearch password
setup_elasticsearch_password() {
    info "Setting up Elasticsearch password..."
    
    # Wait for Elasticsearch to be ready
    wait_for_service "elasticsearch" "http://localhost:9200" || {
        error "Elasticsearch is not running"
        return 1
    }
    
    # Set password for elastic user
    /usr/share/elasticsearch/bin/elasticsearch-setup-passwords interactive -u "http://localhost:9200" || {
        error "Failed to set Elasticsearch password"
        return 1
    }
    
    info "Elasticsearch password set successfully"
}

# Create index pattern in Kibana
create_kibana_index_pattern() {
    info "Creating Kibana index pattern..."
    
    # Wait for Kibana to be ready
    wait_for_service "kibana" "http://localhost:5601" || {
        error "Kibana is not running"
        return 1
    }
    
    # Create index pattern
    curl -X POST "http://localhost:5601/api/saved_objects/index-pattern/logstash-*" \
         -H "kbn-xsrf: true" \
         -H "Content-Type: application/json" \
         -d '{"attributes":{"title":"logstash-*","timeFieldName":"@timestamp"}}' || {
        error "Failed to create Kibana index pattern"
        return 1
    }
    
    info "Kibana index pattern created successfully"
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    # Install dependencies
    install_elk_dependencies
    
    # Install and configure ELK stack
    install_elasticsearch
    install_logstash
    install_kibana
    
    # Set up passwords and index patterns
    setup_elasticsearch_password
    create_kibana_index_pattern
    
 