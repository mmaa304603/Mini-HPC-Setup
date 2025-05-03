# System Overview

## High-Level Architecture

The Mini HPC cluster is designed as a modular, scalable system with the following key components:

```
┌─────────────────────────────────────────────────────────┐
│                     Management Layer                     │
│  ┌───────────────────────────────────────────────────┐  │
│  │                    Head Node                      │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌──────────┐  │  │
│  │  │ Management  │  │ Monitoring  │  │   Auth   │  │  │
│  │  └─────────────┘  └─────────────┘  └──────────┘  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────────┐
│                     Compute Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ Compute Node│  │ Compute Node│  │   Compute Node  │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────────┐
│                     Storage Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐  │
│  │ High Perf   │  │  Capacity   │  │     Backup      │  │
│  └─────────────┘  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## System Components

### Management Layer
- **Head Node**: Central management, monitoring, and authentication
  - System management and control
  - System health and performance tracking
  - User and service authentication

### Compute Layer
- **Compute Nodes**: Processing and computation
- **Workload Manager**: Job scheduling and resource allocation
- **Provisioning**: Node management and deployment

### Storage Layer
- **High Performance**: Fast access storage
- **Capacity**: Large-scale storage
- **Backup**: Data protection and recovery

## Network Architecture

### Network Segments
1. **Management Network**
   - Internal communication
   - System administration
   - Monitoring traffic

2. **Compute Network**
   - Inter-node communication
   - Job execution
   - MPI traffic

3. **Storage Network**
   - Data access
   - File transfers
   - Backup operations

4. **User Network**
   - User access
   - Service endpoints
   - External connections

## Security Architecture

### Security Zones
1. **External Zone**
   - Public access
   - Service endpoints
   - DMZ services

2. **Internal Zone**
   - Private network
   - System components
   - Protected services

3. **Management Zone**
   - Administrative access
   - System control
   - Monitoring

## System Features

### Core Features
- Modular design
- Scalable architecture
- High availability
- Fault tolerance
- Security by design

### Management Features
- Centralized control
- Automated provisioning
- Resource management
- Monitoring and alerting
- Backup and recovery

### User Features
- Job scheduling
- Resource allocation
- Data management
- User authentication
- Service access

## System Requirements

### Hardware Requirements
- Head Node: 8+ cores, 32GB+ RAM
- Compute Nodes: 4+ cores, 16GB+ RAM
- Storage: 1TB+ per node
- Network: 10Gbps+ connectivity

### Software Requirements
- Rocky Linux 9.5
- SLURM 23.02+
- Warewulf 4.3+
- Spack 0.23.1+
- Monitoring stack

## Deployment Options

### Minimal Deployment
- 1 Head Node
- 2 Compute Nodes
- Basic storage
- Essential services

### Standard Deployment
- 1 Head Node
- 4+ Compute Nodes
- Tiered storage
- Full service stack

### Enterprise Deployment
- Multiple Head Nodes
- 10+ Compute Nodes
- Advanced storage
- High availability

## Support

For architecture-related questions:
- Email: hpc-arch@ttu.edu
- Documentation: [docs/](docs/)
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 