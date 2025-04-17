# Filebeat

Filebeat is a lightweight shipper for forwarding and centralizing log data. Installed on each node in the HPC cluster, it monitors the specified log files or locations, collects log events, and forwards them to either Elasticsearch or Logstash for indexing.

## Features

- Lightweight and resource-efficient
- Real-time log shipping
- Automatic log rotation handling
- Support for multiple outputs
- Built-in modules for common log formats
- SSL/TLS encryption support
- Load balancing and retry mechanisms

## Installation

The installation script (`install.sh`) handles:
1. Installing dependencies
2. Downloading and installing Filebeat
3. Configuring Filebeat
4. Setting up modules
5. Starting the Filebeat service

### Dependencies
- wget
- curl
- unzip
- tar
- gzip

## Configuration

### Main Configuration
Location: `/etc/filebeat/filebeat.yml`

Key settings:
```yaml
filebeat.config:
  modules:
    path: ${path.config}/modules.d/*.yml
    reload.enabled: false

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  username: "elastic"
  password: "changeme"

setup.kibana:
  host: "kibana:5601"
```

### Enabled Modules

#### System Module
- Monitors system logs
- Paths:
  - `/var/log/messages`
  - `/var/log/syslog`
  - `/var/log/auth.log`
  - `/var/log/secure`

#### SLURM Module
- Monitors SLURM logs
- Paths:
  - `/var/log/slurm/job_completion.log`
  - `/var/log/slurm/accounting.log`

## Usage

### Installation
```bash
# Install Filebeat
./install.sh
```

### Service Management
```bash
# Start Filebeat
systemctl start filebeat

# Stop Filebeat
systemctl stop filebeat

# Check status
systemctl status filebeat

# Enable on boot
systemctl enable filebeat
```

### Configuration
```bash
# Test configuration
filebeat test config

# Test output
filebeat test output

# Reload configuration
systemctl reload filebeat
```

## Log Management

### Log Location
- Filebeat logs: `/var/log/filebeat`
- Log rotation: 7 days retention
- Log level: info

### Monitoring
- Check Filebeat status: `filebeat status`
- View metrics: `filebeat -e --httpprof :6060`

## Security

- SSL/TLS encryption for Elasticsearch output
- Authentication for Elasticsearch and Kibana
- File permissions: 0644 for log files
- Root ownership of configuration files

## Troubleshooting

Common issues and solutions:

1. Filebeat not starting
   - Check configuration syntax
   - Verify file permissions
   - Check for port conflicts

2. Logs not being shipped
   - Verify Elasticsearch connectivity
   - Check log file paths
   - Validate module configuration

3. High resource usage
   - Adjust prospector settings
   - Review log file patterns
   - Check for duplicate entries

## Best Practices

1. Log Management
   - Use appropriate log rotation policies
   - Monitor disk space usage
   - Regular log cleanup

2. Performance
   - Adjust batch size based on load
   - Monitor memory usage
   - Regular configuration review

3. Security
   - Regular password updates
   - SSL/TLS for all connections
   - Minimal required permissions

## Integration

### With Elasticsearch
- Automatic index creation
- Template management
- Index lifecycle management

### With Kibana
- Dashboard integration
- Log visualization
- Search capabilities

### With Logstash
- Log transformation
- Field extraction
- Custom parsing rules 