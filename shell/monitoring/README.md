# Monitoring Stack

This directory contains scripts for managing the HPC cluster's monitoring infrastructure, which consists of several components working together to provide comprehensive monitoring and visualization capabilities.

## Components

### 1. Elasticsearch
- Central data storage and search engine
- Stores metrics, logs, and other monitoring data
- Provides REST API for data access
- Version: 7.17.0

### 2. Grafana
- Visualization and dashboard platform
- Connects to multiple data sources (Elasticsearch, Prometheus)
- Custom HPC dashboards for cluster monitoring
- Version: Latest stable

### 3. Kibana
- Data exploration and visualization
- Log analysis and search
- Integrated with Elasticsearch
- Version: 7.17.0

### 4. Logstash
- Log processing and transformation
- Collects logs from various sources
- Transforms and forwards data to Elasticsearch
- Version: 7.17.0

## Scripts

### Installation
- `install.sh`: Main installation script for the monitoring stack
- `install_elasticsearch.sh`: Elasticsearch installation and configuration
- `install_grafana.sh`: Grafana installation and configuration
- `install_kibana.sh`: Kibana installation and configuration
- `install_logstash.sh`: Logstash installation and configuration

### Backup and Restore
- `backup.sh`: Creates backups of all monitoring components
- `restore.sh`: Restores monitoring stack from backups

## Configuration

### Elasticsearch
- Data directory: `/var/lib/elasticsearch`
- Config directory: `/etc/elasticsearch`
- Default port: 9200

### Grafana
- Data directory: `/var/lib/grafana`
- Config directory: `/etc/grafana`
- Default port: 3000
- Default credentials:
  - Username: admin
  - Password: changeme

### Kibana
- Data directory: `/var/lib/kibana`
- Config directory: `/etc/kibana`
- Default port: 5601

### Logstash
- Data directory: `/var/lib/logstash`
- Config directory: `/etc/logstash`
- Pipeline directory: `/etc/logstash/pipeline`

## Usage

### Installation
```bash
# Install all components
./install.sh

# Install individual components
./install_elasticsearch.sh
./install_grafana.sh
./install_kibana.sh
./install_logstash.sh
```

### Backup
```bash
# Create a backup
./backup.sh

# Restore from backup
./restore.sh /path/to/backup
```

## Monitoring Data

The stack collects and monitors:
1. System metrics (CPU, memory, disk, network)
2. SLURM job statistics
3. Node health and status
4. Application logs
5. Security events

## Dashboards

### HPC Dashboard
- Cluster overview
- Node status and health
- Job statistics
- Resource utilization
- System metrics

### SLURM Dashboard
- Job queue status
- Resource allocation
- Job history
- User statistics

## Maintenance

### Logs
- Elasticsearch: `/var/log/elasticsearch`
- Grafana: `/var/log/grafana`
- Kibana: `/var/log/kibana`
- Logstash: `/var/log/logstash`

### Backup Location
- Default backup directory: `/var/backups/monitoring`
- Keeps last 5 backups
- Each backup includes data and configuration

## Security

- All components use authentication
- Default credentials should be changed after installation
- SSL/TLS encryption available for all services
- Network access can be restricted via firewall rules

## Troubleshooting

Common issues and solutions:
1. Service won't start
   - Check logs in respective log directories
   - Verify configuration files
   - Ensure sufficient system resources

2. Data not appearing
   - Verify data source connections
   - Check Elasticsearch indices
   - Validate Logstash pipelines

3. Performance issues
   - Monitor system resources
   - Check Elasticsearch cluster health
   - Verify network connectivity 