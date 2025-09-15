# Production-Ready Azure Terraform Deployment with vWAN

**Deployment Regions: East US 2 (Primary) | West US 2 (DR)**

[![Deployed?](https://github.com/catherinevee/terraform-azure/workflows/Terraform/badge.svg)](https://github.com/catherinevee/terraform-azure/actions/workflows/terraform.yml)
[![Security Scan](https://github.com/catherinevee/terraform-azure/workflows/Security%20Scan/badge.svg)](https://github.com/catherinevee/terraform-azure/actions/workflows/security.yml)
[![Infrastructure Status](https://github.com/catherinevee/terraform-azure/workflows/Infrastructure%20Status/badge.svg)](https://github.com/catherinevee/terraform-azure/actions/workflows/infrastructure-status.yml)

**Badge Descriptions:**
- **Deployed?** - Terraform CI/CD pipeline status. Shows whether the latest Terraform plan, validate, and format checks are passing. Green indicates the pipeline can successfully deploy infrastructure.
- **Security Scan** - Security and compliance validation status. Runs TFSec, Checkov, and format validation. Green indicates all security policies and best practices are being followed.
- **Infrastructure Status** - Real-time Azure infrastructure deployment state. Checks actual Azure resources every 30 minutes. Green indicates infrastructure is currently deployed in Azure, red indicates no resources are deployed.

## Overview

Enterprise-grade Azure infrastructure deployment using Terraform with Virtual WAN (vWAN) for global connectivity. This solution provides a scalable, secure web application platform with automated CI/CD pipelines, comprehensive security scanning, and multi-environment support.

### Current Status
- **Infrastructure**: Successfully deployed and tested in production environment
- **CI/CD Pipeline**: Fully operational with automated validation, deployment, and destruction capabilities
- **Security Scanning**: All security checks passing with automated TFSec, Checkov, and format validation
- **Terraform State**: Managed in Azure Storage with proper backend configuration
- **Resource Management**: Automated resource lifecycle management with proper dependency handling

### Key Features
- **Global Connectivity**: Azure Virtual WAN with hub-spoke topology
- **High Availability**: Multi-region deployment with automatic failover
- **Security-First**: Azure Firewall, NSGs, and private endpoints
- **Automated Deployment**: GitHub Actions CI/CD with branch-based environments
- **Compliance Ready**: Built-in security scanning and policy validation

### Deployment Target
- **Primary Region**: Azure East US 2
- **Secondary Region**: West US 2 (Production only)
- **Azure Subscription**: `48421ac6-de0a-47d9-8a76-2166ceafcfe6`
- **Environments**: Development, Staging, Production

## Architecture

### Core Infrastructure Components
- **Azure Virtual WAN**: Global transit network backbone with hub-spoke topology
- **Virtual Network**: Segmented network with dedicated subnets for different tiers
- **Application Gateway**: Layer 7 load balancer with WAF protection
- **VM Scale Set**: Auto-scaling application servers
- **Azure Database for PostgreSQL**: Managed database with high availability
- **Azure Key Vault**: Centralized secrets management
- **Azure Monitor**: Comprehensive monitoring and alerting
- **Azure Storage**: Secure storage for static assets

### Networking & Connectivity
- **vWAN Hubs**: Primary and secondary hubs for global connectivity
- **Azure Firewall**: Premium tier firewall with threat intelligence
- **Site-to-Site VPN**: Secure connectivity to branch offices
- **ExpressRoute**: Private connectivity for on-premises integration
- **Network Security Groups**: Granular access control at subnet level

### Architecture Diagrams

#### High-Level Architecture
![Terraform Modules Architecture](docs/diagrams/terraform-modules-architecture.png)

#### Terraform Dependency Graph
![Terraform Architecture Diagram](docs/diagrams/terraform-architecture-diagram.png)

*Additional diagrams available:*
- [High-level SVG](docs/diagrams/terraform-modules-architecture.svg)
- [Dependency graph SVG](docs/diagrams/terraform-architecture-diagram.svg)
- [Development environment diagram](docs/diagrams/terraform-dev-architecture-diagram.png)

## Getting Started

### Prerequisites

#### For CI/CD Deployment (Recommended)
- GitHub account with repository access
- Azure subscription with appropriate permissions
- Azure Service Principal with Contributor role
- GitHub Secrets configured (see Quick Start section)

#### For Manual Deployment
- Azure subscription with appropriate permissions
- Azure CLI installed and authenticated
- Terraform >= 1.5.0
- Git for version control

### Quick Start

#### Automated Deployment (Recommended)

This infrastructure uses GitHub Actions for automated CI/CD deployment:

1. **Fork this repository** to your GitHub account

2. **Set up GitHub Secrets** in your repository settings:
   - `ARM_CLIENT_ID` - Azure Service Principal Client ID
   - `ARM_CLIENT_SECRET` - Azure Service Principal Secret
   - `ARM_SUBSCRIPTION_ID` - Azure Subscription ID
   - `ARM_TENANT_ID` - Azure Tenant ID
   - `BACKEND_RESOURCE_GROUP` - Resource group for Terraform state
   - `BACKEND_STORAGE_ACCOUNT` - Storage account for Terraform state
   - `BACKEND_CONTAINER` - Container name for Terraform state

3. **Configure environments** (optional):
   - Edit `environments/dev/terraform.tfvars` for development settings
   - Edit `environments/staging/terraform.tfvars` for staging settings
   - Edit `environments/prod/terraform.tfvars` for production settings

4. **Deploy infrastructure**:
   - Push to `main` branch → deploys to production
   - Push to `develop` branch → deploys to staging
   - Create PR → validates and plans deployment to dev
   - Manual dispatch → choose environment and action

#### Manual Deployment (Alternative)

For local development and testing:

```bash
# 1. Clone the repository
git clone https://github.com/catherinevee/terraform-azure.git
cd terraform-azure

# 2. Authenticate with Azure
az login

# 3. Option A: Use Makefile (recommended)
make init ENV=dev      # Initialize Terraform
make plan ENV=dev      # Review changes
make apply ENV=dev     # Deploy infrastructure

# 3. Option B: Direct Terraform commands
cd environments/dev    # Navigate to environment
terraform init         # Initialize
terraform plan         # Review changes
terraform apply        # Deploy
```

### Setup Scripts

Automated setup scripts are available in the `scripts/` directory:
- **Windows PowerShell**: `scripts/setup-pipeline.ps1`
- **Windows Command Prompt**: `scripts/setup-pipeline.bat`
- **Linux/macOS/Git Bash**: `scripts/setup-pipeline.sh`

These scripts automate the creation of Azure resources and GitHub secrets needed for CI/CD.

## CI/CD Pipeline

### Primary Workflows

#### Terraform Deployment (`terraform.yml`)
- **Environment Detection**: Automatically determines target environment based on branch
- **Terraform Validation**: Format checking, validation, and planning
- **Artifact Management**: Stores Terraform plans and outputs
- **PR Integration**: Adds plan details as PR comments
- **Multi-Environment Support**: Handles dev, staging, and production deployments

#### Security Scanning (`security.yml`)
- **TFSec**: Infrastructure security scanning
- **Checkov**: Compliance and security policy checks
- **Terraform Lint**: Code quality and formatting validation
- **Secrets Detection**: TruffleHog and Gitleaks scanning
- **Compliance Check**: Policy-as-code validation
- **SARIF Integration**: Results uploaded to GitHub Security tab

### Branch Strategy
- **main** → Production environment (auto-deploy)
- **develop** → Staging environment (auto-deploy)
- **feature/** → Development environment (plan only)
- **PRs** → Development environment (validation only)

### Workflow Details

| Workflow | Description | Trigger |
|----------|-------------|---------|
| **Terraform** | Unified CI/CD: validation, security scanning, and deployment | Push to main/develop, PRs, manual dispatch |
| **Security Scan** | Comprehensive security analysis (TFSec, Checkov, Secrets) | Weekly schedule, PRs, and pushes |
| **Infrastructure Status** | Monitors actual Azure resources deployment state | Every 30 minutes, pushes to main, manual dispatch |
| **Dependabot** | Automated dependency updates | Weekly (Mondays 4 AM) |

## Directory Structure

```
terraform-azure/
├── .github/               # GitHub Actions workflows
│   └── workflows/        # CI/CD pipeline definitions
├── docs/                 # Documentation
│   ├── diagrams/         # Architecture diagrams
│   └── *.md              # Documentation files
├── environments/         # Environment-specific configurations
│   ├── dev/              # Development environment
│   ├── staging/          # Staging environment
│   └── prod/             # Production environment
├── modules/              # Reusable Terraform modules
│   ├── vwan/             # Virtual WAN and connectivity
│   ├── networking/       # Virtual network and subnets
│   ├── compute/          # VM Scale Set and App Gateway
│   ├── database/         # PostgreSQL database
│   ├── security/         # Key Vault and security
│   └── monitoring/       # Monitoring and alerts
├── scripts/              # Automation scripts
│   └── setup-pipeline.*  # Pipeline setup scripts
├── main.tf               # Root module configuration
├── variables.tf          # Variable definitions
├── outputs.tf            # Output definitions
├── versions.tf           # Provider requirements
├── Makefile              # Common operations automation
└── README.md             # This file
```

## Module Descriptions

### vWAN Module
- Deploys Azure Virtual WAN with hub-spoke topology
- Configures Azure Firewall for security inspection
- Sets up VPN gateways for branch connectivity
- Manages ExpressRoute circuits for on-premises connectivity
- Implements routing policies and BGP configuration

### Networking Module
- Creates virtual network with proper segmentation
- Configures subnets for different application tiers
- Implements Network Security Groups with least-privilege rules
- Connects to vWAN hub for global connectivity
- Optional DDoS protection for production

### Security Module
- Deploys Azure Key Vault for secrets management
- Creates secure storage account with encryption
- Configures Application Insights for APM
- Implements network ACLs and access policies
- Manages service identities and RBAC

### Database Module
- Deploys PostgreSQL Flexible Server
- Configures high availability with zone redundancy
- Implements private endpoints for security
- Manages automated backups with geo-redundancy
- Stores connection strings in Key Vault

### Compute Module
- Deploys VM Scale Set with auto-scaling
- Configures Application Gateway with WAF
- Implements health probes and load balancing
- Manages SSH keys and cloud-init configuration
- Integrates with Key Vault for secrets

### Monitoring Module
- Creates Log Analytics workspace
- Configures metric alerts for all components
- Implements diagnostic settings
- Sets up action groups for notifications
- Monitors vWAN, VPN, and ExpressRoute health

## Environment Configurations

### Development
- Minimal resources for cost optimization
- Single vWAN hub without firewall
- Small VM SKUs (Standard_B2s)
- Basic database tier
- No branch sites or ExpressRoute

### Staging
- Moderate resources for testing
- vWAN with firewall enabled
- Medium VM SKUs (Standard_B2ms)
- Standard database tier
- Limited monitoring and alerting

### Production
- High-performance resources
- Multi-region vWAN hubs with DR
- Large VM SKUs (Standard_D4s_v5)
- Premium database with geo-redundancy
- Full branch connectivity and ExpressRoute
- Comprehensive monitoring and alerting

## Security Features

1. **Network Security**
   - Azure Firewall with threat intelligence
   - Network segmentation with NSGs
   - Private endpoints for PaaS services
   - DDoS protection (optional)

2. **Identity & Access**
   - Managed identities for Azure resources
   - Key Vault for secrets management
   - RBAC for access control
   - Service principals for automation

3. **Data Protection**
   - Encryption at rest and in transit
   - TLS 1.2 minimum for all connections
   - Secure storage with versioning
   - Automated backup with retention

4. **Compliance**
   - Audit logging to Log Analytics
   - Resource tagging for governance
   - Policy compliance checking
   - Security Center integration

## Monitoring & Alerts

### Configured Alerts
- VM Scale Set CPU > 90%
- Database CPU > 80%
- Application Gateway unhealthy hosts
- vWAN hub health issues
- VPN connection drops
- ExpressRoute circuit issues

### Log Collection
- Application Gateway access logs
- Azure Firewall logs
- vWAN routing tables
- BGP session logs
- Application performance metrics

## Connectivity Options

### Site-to-Site VPN
Configure branch sites in `terraform.tfvars`:
```hcl
branch_sites = {
  "branch-name" = {
    address_space = ["192.168.x.0/24"]
    vpn_gateway_address = "public-ip"
    pre_shared_key = "secure-key"
    bandwidth_mbps = 100
  }
}
```

### ExpressRoute
Configure circuits in `terraform.tfvars`:
```hcl
express_route_circuits = {
  "circuit-name" = {
    service_provider = "Provider"
    peering_location = "Location"
    bandwidth_mbps = 1000
    sku_tier = "Premium"
    sku_family = "UnlimitedData"
  }
}
```

## Cost Optimization

1. **Development**: Use smallest SKUs, disable unnecessary features
2. **Auto-scaling**: Scale down during off-peak hours
3. **Reserved Instances**: Purchase RIs for production workloads
4. **Monitoring**: Set up cost alerts and budgets
5. **Cleanup**: Remove unused resources regularly

## Maintenance

### Using Makefile
The repository includes a Makefile for common operations:

```bash
make help           # Show available commands
make init ENV=dev   # Initialize environment
make plan ENV=dev   # Plan changes
make apply ENV=dev  # Apply changes
make destroy ENV=dev # Destroy infrastructure
make clean          # Clean temporary files
make docs           # Generate documentation
```

### Regular Tasks
```bash
# Check for drift
make plan ENV=prod

# Update providers
terraform init -upgrade

# Validate configuration
make validate ENV=prod

# Format code
terraform fmt -recursive

# Clean up temporary files
make clean
```

### Backup Verification
```bash
# List database backups
az postgres flexible-server backup list \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw database_server_name)
```

### Monitoring Review
```bash
# View recent alerts
az monitor activity-log list \
  --resource-group $(terraform output -raw resource_group_name) \
  --start-time $(date -u -d '1 hour ago' '+%Y-%m-%dT%H:%M:%SZ')
```

## Troubleshooting

### Common Issues

1. **VPN Connection Failed**
   - Verify pre-shared keys
   - Check firewall rules
   - Review BGP configuration
   - Validate IP addresses

2. **Application Gateway 502 Errors**
   - Check backend health probes
   - Verify NSG rules
   - Review application logs
   - Check VM Scale Set instances

3. **Database Connection Issues**
   - Verify firewall rules
   - Check private endpoint
   - Validate connection string
   - Review network connectivity

4. **Long Deployment/Destruction Times**
   - vWAN resources can take 1-3 hours to fully deploy or destroy
   - Virtual Hub creation/deletion is particularly time-consuming
   - Azure Firewall in vWAN takes significant time to provision
   - This is normal Azure behavior for complex networking resources
   - Use manual resource group deletion if Terraform destroy times out

### Debug Commands
```bash
# Check vWAN hub status
az network vhub show \
  --resource-group rg-webapp-prod-eus2 \
  --name vhub-webapp-prod-eus2

# View VPN connection status
az network vpn-connection show \
  --resource-group rg-webapp-prod-eus2 \
  --gateway-name vpng-webapp-prod-eus2 \
  --name vpnc-webapp-prod-branch

# Check firewall logs
az monitor log-analytics query \
  --workspace $(terraform output -raw monitoring_workspace_id) \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallApplicationRule' | take 10"
```

## Disaster Recovery

### Backup Strategy
- Database: Automated backups with 35-day retention (prod)
- Configuration: Terraform state in geo-redundant storage
- Secrets: Key Vault with soft delete and purge protection
- Application: Container images in geo-replicated registry

### Recovery Procedures
1. **Database Recovery**: Restore from automated backups
2. **Infrastructure Recovery**: Re-run Terraform apply
3. **Secret Recovery**: Restore from Key Vault soft delete
4. **Network Recovery**: Failover to secondary vWAN hub

## Best Practices

1. **Version Control**: Commit all changes to Git
2. **Code Review**: Review Terraform plans before applying
3. **Testing**: Test changes in dev/staging first
4. **Documentation**: Update README for significant changes
5. **Secrets**: Never commit secrets to Git
6. **Tagging**: Use consistent tagging strategy
7. **Naming**: Follow Azure naming conventions
8. **Monitoring**: Review alerts and metrics regularly

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review Azure documentation
3. Check Terraform Azure provider documentation
4. Contact your Azure support team

## License

MIT License

Copyright (c) 2024 Catherine Vee

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Documentation

Additional documentation is available in the `docs/` directory:
- [Documentation Index](docs/README.md) - Complete documentation overview
- [CI/CD Setup Guide](docs/SETUP_CICD.md) - Detailed CI/CD configuration
- [Pipeline Setup Summary](docs/PIPELINE_SETUP_SUMMARY.md) - Current pipeline status
- [Architecture Diagrams](docs/diagrams/) - Visual architecture representations
- [Terraform Docs](docs/terraform-docs.md) - Auto-generated module documentation

---

**Note**: This infrastructure is designed for production use but requires proper configuration of secrets, IP addresses, and other environment-specific settings before deployment.