# Production-Ready Azure Terraform Deployment with vWAN

[![Terraform CI/CD Pipeline](https://github.com/terraform-user/terraform-azure/workflows/Terraform%20CI%2FCD%20Pipeline/badge.svg)](https://github.com/terraform-user/terraform-azure/actions/workflows/terraform-cicd.yml)
[![Security Scan](https://github.com/terraform-user/terraform-azure/workflows/Terraform%20CI%2FCD%20Pipeline/badge.svg?event=schedule)](https://github.com/terraform-user/terraform-azure/security)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform->=1.5.0-purple.svg)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-Cloud-blue.svg)](https://azure.microsoft.com/)

## Overview

This Terraform configuration deploys a scalable, secure web application infrastructure on Azure with advanced networking capabilities using Azure Virtual WAN (vWAN). The infrastructure is designed for enterprise-grade deployments with high availability, security, and global connectivity.

## Architecture Components

### Core Infrastructure
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

## Prerequisites

- Azure subscription with appropriate permissions
- Azure CLI installed and authenticated
- Terraform >= 1.5.0
- Git for version control

## Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd terraform-azure
```

### 2. Set Up Backend Storage
```bash
# Create resource group for Terraform state
az group create --name rg-terraform-state --location eastus2

# Create storage account (replace 12345 with random numbers)
az storage account create \
  --name stterraformstate12345 \
  --resource-group rg-terraform-state \
  --location eastus2 \
  --sku Standard_LRS \
  --encryption-services blob

# Create container
az storage container create \
  --name tfstate \
  --account-name stterraformstate12345 \
  --auth-mode login
```

### 3. Update Backend Configuration
Edit the `backend.tf` files in each environment folder with your storage account name.

### 4. Configure Environment Variables
Edit the `terraform.tfvars` file in your target environment folder:
- Replace `YOUR_OFFICE_IP/32` with your actual IP address
- Update `admin_email` with your email
- Modify other variables as needed

### 5. Deploy Infrastructure

#### Development Environment
```bash
cd environments/dev
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

#### Production Environment
```bash
cd environments/prod
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## Directory Structure

```
terraform-azure/
├── environments/          # Environment-specific configurations
│   ├── dev/              # Development environment
│   ├── staging/          # Staging environment
│   └── prod/             # Production environment
├── modules/              # Reusable Terraform modules
│   ├── vwan/            # Virtual WAN and connectivity
│   ├── networking/      # Virtual network and subnets
│   ├── compute/         # VM Scale Set and App Gateway
│   ├── database/        # PostgreSQL database
│   ├── security/        # Key Vault and security
│   └── monitoring/      # Monitoring and alerts
├── main.tf              # Root module configuration
├── variables.tf         # Variable definitions
├── outputs.tf           # Output definitions
├── versions.tf          # Provider requirements
└── README.md            # This file
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

### Regular Tasks
```bash
# Check for drift
terraform plan

# Update providers
terraform init -upgrade

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
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

[Your License Here]

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

**Note**: This infrastructure is designed for production use but requires proper configuration of secrets, IP addresses, and other environment-specific settings before deployment.# Trigger workflow
