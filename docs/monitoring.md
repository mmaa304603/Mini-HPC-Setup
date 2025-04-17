# Monitoring Setup

This document provides detailed information about the monitoring stack setup and configuration.

## Overview

The monitoring stack consists of:
- Elasticsearch: Log storage and search
- Logstash: Log processing
- Kibana: Log visualization
- Grafana: Metrics visualization
- Filebeat: Log collection

## Component Details

### Elasticsearch

Elasticsearch is used for storing and indexing logs.

#### Configuration
- Port: 9200
- Data directory: `/var/lib/elasticsearch`
- Log directory: `/var/log/elasticsearch`
- Memory: 2GB heap size
- Network: Bound to localhost

#### Access
- HTTP API: http://localhost:9200
- Transport: 9300/tcp

### Logstash

Logstash processes and transforms logs before sending them to Elasticsearch.

#### Configuration
- Port: 5044 (Beats input)
- Config directory: `/etc/logstash/conf.d`
- Pipeline workers: 2
- Batch size: 1000

#### Inputs
- Filebeat (5044/tcp)
- System logs
- Application logs

### Kibana

Kibana provides visualization and exploration of logs.

#### Configuration
- Port: 5601
- Elasticsearch URL: http://localhost:9200
- Log directory: `/var/log/kibana`

#### Access
- Web interface: http://headnode:5601
- Default credentials: admin/admin

### Grafana

Grafana provides metrics visualization and alerting.

#### Configuration
- Port: 3000
- Data directory: `/var/lib/grafana`
- Log directory: `/var/log/grafana`

#### Access
- Web interface: http://headnode:3000
- Default credentials: admin/admin

### Filebeat

Filebeat collects logs from various sources.

#### Configuration
- Log paths:
  - System logs: `/var/log/*.log`
  - SLURM logs: `/var/log/slurm/*.log`
  - Application logs: `/var/log/applications/*.log`

## Installation

### Using Shell Scripts

1. **Install ELK Stack**
   ```bash
   cd shell/elk
   ./install.sh
   ```

2. **Install Grafana**
   ```bash
   cd shell/grafana
   ./install.sh
   ```

3. **Install Filebeat**
   ```bash
   cd shell/filebeat
   ./install.sh
   ```

### Using Ansible

```bash
cd ansible
ansible-playbook -i inventory/hosts monitoring.yml
```

## Configuration

### Elasticsearch

1. **Configure Memory**
   ```bash
   # Edit /etc/elasticsearch/jvm.options
   -Xms2g
   -Xmx2g
   ```

2. **Configure Network**
   ```bash
   # Edit /etc/elasticsearch/elasticsearch.yml
   network.host: 127.0.0.1
   http.port: 9200
   ```

### Logstash

1. **Configure Pipeline**
   ```bash
   # Edit /etc/logstash/conf.d/pipeline.conf
   input {
     beats {
       port => 5044
     }
   }
   
   filter {
     # Add filters here
   }
   
   output {
     elasticsearch {
       hosts => ["localhost:9200"]
       index => "logs-%{+YYYY.MM.dd}"
     }
   }
   ```

### Kibana

1. **Configure Elasticsearch Connection**
   ```bash
   # Edit /etc/kibana/kibana.yml
   elasticsearch.hosts: ["http://localhost:9200"]
   server.port: 5601
   ```

### Grafana

1. **Configure Data Sources**
   - Add Elasticsearch data source
   - Configure Prometheus data source (if used)

2. **Import Dashboards**
   - SLURM dashboard
   - System metrics dashboard
   - Application metrics dashboard

### Filebeat

1. **Configure Inputs**
   ```bash
   # Edit /etc/filebeat/filebeat.yml
   filebeat.inputs:
   - type: log
     enabled: true
     paths:
       - /var/log/*.log
       - /var/log/slurm/*.log
   ```

## Monitoring Dashboards

### SLURM Dashboard

- Job statistics
- Node status
- Queue information
- Resource utilization

### System Metrics

- CPU usage
- Memory usage
- Disk I/O
- Network traffic

### Application Metrics

- Application-specific metrics
- Error rates
- Response times
- Resource usage

## Alerting

### Grafana Alerts

1. **SLURM Alerts**
   - Node down
   - Job failures
   - Queue thresholds

2. **System Alerts**
   - High CPU usage
   - Low memory
   - Disk space
   - Network issues

3. **Application Alerts**
   - Error rates
   - Response times
   - Resource usage

## Maintenance

### Backup

1. **Elasticsearch**
   ```bash
   # Create snapshot
   curl -X PUT "localhost:9200/_snapshot/backup/snapshot_1"
   
   # Restore snapshot
   curl -X POST "localhost:9200/_snapshot/backup/snapshot_1/_restore"
   ```

2. **Grafana**
   ```bash
   # Backup database
   pg_dump grafana > grafana_backup.sql
   
   # Restore database
   psql grafana < grafana_backup.sql
   ```

### Log Rotation

1. **Elasticsearch**
   - Index lifecycle management
   - Index templates
   - Retention policies

2. **Application Logs**
   - logrotate configuration
   - Compression settings
   - Retention periods

## Troubleshooting

### Common Issues

1. **Elasticsearch**
   - Cluster health
   - Index issues
   - Memory pressure

2. **Logstash**
   - Pipeline errors
   - Input/output issues
   - Performance problems

3. **Kibana**
   - Connection issues
   - Dashboard errors
   - Search problems

4. **Grafana**
   - Data source issues
   - Alert failures
   - Dashboard loading

### Log Files

- Elasticsearch: `/var/log/elasticsearch/`
- Logstash: `/var/log/logstash/`
- Kibana: `/var/log/kibana/`
- Grafana: `/var/log/grafana/`
- Filebeat: `/var/log/filebeat/` 