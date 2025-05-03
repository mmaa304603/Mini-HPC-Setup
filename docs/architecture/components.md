# Component Architecture

## Core Components

### Head Node
The head node serves as the central management point for the cluster, integrating management, monitoring, and authentication functions.

#### Responsibilities
- System management and control
- User authentication
- Job scheduling
- Resource allocation
- System health monitoring
- Performance tracking
- Alert management
- Log collection and analysis

#### Configuration
- Operating System: Rocky Linux 9.5
- CPU: 8+ cores
- RAM: 32GB+
- Storage: 1TB+
- Network: 10Gbps+
- Monitoring Stack: ELK, Grafana, Prometheus
- Authentication: LDAP, Kerberos

### Compute Nodes
Compute nodes handle the actual processing and computation tasks.

#### Responsibilities
- Job execution
- Resource utilization
- Process management
- Data processing

#### Configuration
- Operating System: Rocky Linux 9.5
- CPU: 4+ cores
- RAM: 16GB+
- Storage: 500GB+
- Network: 10Gbps+

### Storage Systems
The storage system provides data storage and management capabilities.

#### Types
1. **High Performance Storage**
   - Fast access storage
   - SSD-based
   - Low latency
   - High throughput

2. **Capacity Storage**
   - Large-scale storage
   - HDD-based
   - Cost-effective
   - High capacity

3. **Backup Storage**
   - Data protection
   - Redundant storage
   - Version control
   - Disaster recovery

#### Configuration
- File System: Lustre/GPFS
- RAID Configuration: RAID 6/10
- Backup: Daily incremental
- Replication: Real-time

### Network Infrastructure
The network infrastructure connects all components.

#### Components
1. **Switches**
   - Management switches
   - Compute switches
   - Storage switches
   - User switches

2. **Routers**
   - Edge routers
   - Core routers
   - Access routers

3. **Firewalls**
   - Perimeter firewall
   - Internal firewall
   - Application firewall

#### Configuration
- Speed: 10Gbps+
- Redundancy: Dual-path
- Security: VLANs, ACLs
- Monitoring: SNMP, NetFlow

## Service Components

### SLURM Workload Manager
Manages job scheduling and resource allocation.

#### Features
- Job scheduling
- Resource management
- Queue management
- Priority handling
- Fair share

#### Configuration
- Scheduler: Backfill
- Accounting: SlurmDBD
- Priority: Multifactor
- Fair Share: Tree

### Warewulf Provisioning
Handles node provisioning and management.

#### Features
- Node provisioning
- Image management
- Configuration management
- State management
- Update management

#### Configuration
- Provisioning: PXE
- Images: SquashFS
- Configuration: YAML
- Updates: Rolling

### Spack Package Manager
Manages software packages and dependencies.

#### Features
- Package management
- Dependency resolution
- Version control
- Build management
- Environment management

#### Configuration
- Repositories: Custom
- Compilers: GCC, Intel
- MPI: OpenMPI, MPICH
- Build Options: Optimized

### Monitoring Stack
Provides system monitoring and alerting.

#### Components
1. **ELK Stack**
   - Log collection
   - Log analysis
   - Log visualization
   - Alerting

2. **Grafana**
   - Metrics visualization
   - Dashboard creation
   - Alert management
   - Reporting

3. **Prometheus**
   - Metrics collection
   - Time series data
   - Alert rules
   - Service discovery

#### Configuration
- Collection: 1-minute intervals
- Retention: 30 days
- Alerts: Multi-level
- Dashboards: Custom

### Backup System
Provides data protection and recovery.

#### Features
- Automated backups
- Incremental backups
- Version control
- Disaster recovery
- Data verification

#### Configuration
- Schedule: Daily
- Retention: 30 days
- Verification: Automated
- Recovery: Point-in-time

## Component Interactions

### Management Flow
1. User submits job
2. SLURM schedules job
3. Warewulf provisions nodes
4. Spack provides software
5. Monitoring tracks execution
6. Backup protects data

### Data Flow
1. User data → Storage
2. Storage → Compute
3. Compute → Results
4. Results → Storage
5. Storage → Backup

### Network Flow
1. User → Head Node
2. Head Node → Compute
3. Compute → Storage
4. Storage → Backup
5. Monitoring → All

## Support

For component-related questions:
- Email: hpc-arch@ttu.edu
- Documentation: [docs/](docs/)
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 