# Deployment Configurations

This directory contains environment-specific configurations for deploying the Mini HPC cluster. These configurations control how the implementation code runs but are not part of the source code itself.

## Purpose

The config directory contains settings for:
- Environment-specific deployments
- Security and access control
- Resource allocation
- Service configuration

## Directory Structure

```
config/
├── dev/          # Development environment
│   ├── ansible/  # Ansible development config
│   └── shell/    # Shell development config
│
├── test/         # Testing environment
│   ├── ansible/  # Ansible test config
│   └── shell/    # Shell test config
│
└── prod/         # Production environment
    ├── ansible/  # Ansible production config
    └── shell/    # Shell production config
```

## Environment Types

### Development
- Located in `config/dev/`
- Used for local development
- Includes debug settings
- May include test data
- Not for production use

### Testing
- Located in `config/test/`
- Used for CI/CD testing
- Includes test-specific settings
- May include mock services
- Simulates production environment

### Production
- Located in `config/prod/`
- Used for production deployment
- Includes security settings
- May include sensitive data
- Requires careful management

## Usage

### Ansible Configuration
```bash
# Use development config
ansible-playbook -i config/dev/ansible/inventory site.yml

# Use test config
ansible-playbook -i config/test/ansible/inventory site.yml

# Use production config
ansible-playbook -i config/prod/ansible/inventory site.yml
```

### Shell Configuration
```bash
# Use development config
./src/shell/install.sh -c config/dev/shell/config.json

# Use test config
./src/shell/install.sh -c config/test/shell/config.json

# Use production config
./src/shell/install.sh -c config/prod/shell/config.json
```

## Security Guidelines

### Sensitive Data
- Never commit sensitive data
- Use environment variables for secrets
- Follow security best practices
- Review configuration regularly

### Access Control
- Restrict access to production configs
- Use encryption for sensitive data
- Implement audit logging
- Regular security reviews

## Version Control

### Configuration Management
- Track changes in version control
- Use branches for different environments
- Document configuration changes
- Regular backups of configurations

## Support

For configuration issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/configuration.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 