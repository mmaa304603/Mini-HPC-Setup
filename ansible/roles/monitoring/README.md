# HPC Cluster Monitoring

This directory contains Ansible roles for setting up monitoring and logging in the HPC cluster using ELK (Elasticsearch, Logstash, Kibana) and Grafana.

## Components

### ELK Stack
- **Elasticsearch**: Search and analytics engine
- **Logstash**: Log processing pipeline
- **Kibana**: Data visualization dashboard

### Grafana
- Metrics visualization
- Custom dashboards for HPC monitoring
- Integration with Elasticsearch and Prometheus

## Prerequisites

- Rocky Linux 8 or later
- Ansible 2.9 or later
- Sufficient memory (recommended: 16GB+ for ELK)
- Sufficient disk space (recommended: 100GB+ for logs)

## Installation

1. Update the inventory file to include monitoring hosts:
   ```ini
   [monitoring]
   monitor01 ansible_host=192.168.1.20

   [compute]
   compute01 ansible_host=192.168.1.11
   compute02 ansible_host=192.168.1.12
   compute03 ansible_host=192.168.1.13
   ```

2. Run the monitoring playbook:
   ```bash
   ansible-playbook -i inventory monitoring.yml
   ```

## Accessing the Dashboards

### Kibana
- URL: http://monitor01:5601
- Default credentials:
  - Username: elastic
  - Password: changeme (change in production!)

### Grafana
- URL: http://monitor01:3000
- Default credentials:
  - Username: admin
  - Password: changeme (change in production!)

## Monitoring Features

### System Metrics
- CPU usage
- Memory usage
- Disk I/O
- Network traffic

### HPC-specific Metrics
- SLURM job statistics
- Queue status
- Node utilization
- Job efficiency

### Log Analysis
- System logs
- SLURM logs
- Application logs
- Security events

## Customization

### Adding New Dashboards
1. Create a new dashboard in Grafana
2. Export the dashboard JSON
3. Place it in `/var/lib/grafana/dashboards/`
4. Update the dashboards.yaml configuration

### Adding New Data Sources
1. Edit the datasources.yaml template
2. Add the new data source configuration
3. Redeploy the Grafana role

## Security Considerations

1. Change default passwords
2. Enable SSL/TLS
3. Configure firewall rules
4. Set up authentication
5. Regular security updates

## Maintenance

### Backup
- Regular backups of Elasticsearch indices
- Grafana dashboard exports
- Configuration backups

### Updates
- Regular updates of ELK stack
- Grafana updates
- Security patches

## Troubleshooting

### Common Issues
1. Elasticsearch not starting
   - Check memory settings
   - Verify disk space
   - Check logs in /var/log/elasticsearch

2. Logstash pipeline issues
   - Check configuration syntax
   - Verify input/output plugins
   - Check logs in /var/log/logstash

3. Grafana connection issues
   - Verify datasource configurations
   - Check network connectivity
   - Review Grafana logs

## License

MIT

## Author Information

Created for HPC-Setup project 