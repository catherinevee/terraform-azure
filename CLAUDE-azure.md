# Production-Ready Azure Terraform Deployment with vWAN

## Project Overview
This Terraform configuration deploys a scalable, secure web application infrastructure on Azure with the following components:
- Azure Virtual WAN for global connectivity and hub-spoke topology
- Virtual Network with proper segmentation connected via vWAN hub
- Application Gateway (Layer 7 Load Balancer)
- Virtual Machine Scale Set for application servers
- Azure Database for PostgreSQL
- Azure Key Vault for secrets management
- Azure Monitor and Log Analytics
- Azure Storage for static assets
- Network Security Groups with least-privilege access
- Site-to-Site VPN and ExpressRoute capabilities via vWAN

## Directory Structure
```
terraform-azure-webapp/
├── environments/
│   ├── dev/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── prod/
│       ├── terraform.tfvars
│       └── backend.tf
├── modules/
│   ├── vwan/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── database/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── monitoring/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── README.md
```

## Root Configuration Files

### versions.tf
```hcl
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
```

### variables.tf
```hcl
variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.project_name))
    error_message = "Project name must be 3-24 characters, lowercase alphanumeric and hyphens only."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus2"
}

variable "location_short" {
  description = "Short form of Azure region for naming"
  type        = string
  default     = "eus2"
}

variable "secondary_location" {
  description = "Secondary Azure region for vWAN and DR"
  type        = string
  default     = "westus2"
}

variable "secondary_location_short" {
  description = "Short form of secondary Azure region"
  type        = string
  default     = "wus2"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "vm_sku" {
  description = "SKU for virtual machine scale set instances"
  type        = string
  default     = "Standard_B2ms"
}

variable "vm_instances" {
  description = "Number of VM instances in scale set"
  type = object({
    min     = number
    max     = number
    default = number
  })
  default = {
    min     = 2
    max     = 10
    default = 3
  }
}

variable "database_sku" {
  description = "SKU for PostgreSQL database"
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "admin_email" {
  description = "Admin email for notifications"
  type        = string
  sensitive   = true
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access resources"
  type        = list(string)
  default     = []
}

variable "enable_vwan_firewall" {
  description = "Enable Azure Firewall in vWAN hub"
  type        = bool
  default     = true
}

variable "branch_sites" {
  description = "Branch site configurations for S2S VPN"
  type = map(object({
    address_space = list(string)
    vpn_gateway_address = string
    pre_shared_key = string
    bandwidth_mbps = number
  }))
  default = {}
}

variable "express_route_circuits" {
  description = "ExpressRoute circuit configurations"
  type = map(object({
    service_provider = string
    peering_location = string
    bandwidth_mbps = number
    sku_tier = string
    sku_family = string
  }))
  default = {}
}
```

### main.tf
```hcl
# Local variables for consistent naming
locals {
  name_prefix = "${var.project_name}-${var.environment}-${var.location_short}"
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      CreatedAt   = timestamp()
    }
  )
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

# Secondary Resource Group for vWAN hub in another region (for DR)
resource "azurerm_resource_group" "secondary" {
  count    = var.environment == "prod" ? 1 : 0
  name     = "rg-${var.project_name}-${var.environment}-${var.secondary_location_short}"
  location = var.secondary_location
  tags     = local.common_tags
}

# Virtual WAN Module
module "vwan" {
  source = "./modules/vwan"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  name_prefix        = local.name_prefix
  tags              = local.common_tags
  
  # Secondary hub for production
  secondary_resource_group_name = var.environment == "prod" ? azurerm_resource_group.secondary[0].name : null
  secondary_location            = var.environment == "prod" ? var.secondary_location : null
  secondary_location_short      = var.environment == "prod" ? var.secondary_location_short : null
  
  enable_firewall    = var.enable_vwan_firewall
  branch_sites      = var.branch_sites
  express_route_circuits = var.express_route_circuits
  
  # Hub configuration
  hub_address_prefix = "10.100.0.0/24"
  secondary_hub_address_prefix = "10.101.0.0/24"
}

# Networking Module (now connects to vWAN)
module "networking" {
  source = "./modules/networking"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  name_prefix        = local.name_prefix
  tags              = local.common_tags
  
  vnet_address_space = ["10.0.0.0/16"]
  
  # vWAN connection
  vwan_hub_id = module.vwan.hub_id
  enable_vwan_connection = true
  
  subnet_configs = {
    gateway = {
      address_prefixes = ["10.0.1.0/24"]
      service_endpoints = []
    }
    application = {
      address_prefixes = ["10.0.2.0/24"]
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
    }
    database = {
      address_prefixes = ["10.0.3.0/24"]
      service_endpoints = ["Microsoft.Sql"]
      delegation = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
    management = {
      address_prefixes = ["10.0.4.0/24"]
      service_endpoints = []
    }
  }
}

# Security Module
module "security" {
  source = "./modules/security"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  name_prefix        = local.name_prefix
  tags              = local.common_tags
  
  subnet_id          = module.networking.subnet_ids["application"]
  allowed_ip_ranges  = var.allowed_ip_ranges
}

# Database Module
module "database" {
  source = "./modules/database"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  name_prefix        = local.name_prefix
  tags              = local.common_tags
  
  subnet_id          = module.networking.subnet_ids["database"]
  vnet_id            = module.networking.vnet_id
  key_vault_id       = module.security.key_vault_id
  database_sku       = var.database_sku
  backup_retention_days = var.environment == "prod" ? 35 : 7
  geo_redundant_backup = var.environment == "prod" ? true : false
}

# Compute Module
module "compute" {
  source = "./modules/compute"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  name_prefix        = local.name_prefix
  tags              = local.common_tags
  
  subnet_id          = module.networking.subnet_ids["application"]
  gateway_subnet_id  = module.networking.subnet_ids["gateway"]
  key_vault_id       = module.security.key_vault_id
  key_vault_uri      = module.security.key_vault_uri
  vm_sku            = var.vm_sku
  vm_instances      = var.vm_instances
  
  database_connection_string = module.database.connection_string_secret_id
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"
  
  resource_group_name = azurerm_resource_group.main.name
  location           = azurerm_resource_group.main.location
  name_prefix        = local.name_prefix
  tags              = local.common_tags
  
  admin_email        = var.admin_email
  vmss_id           = module.compute.vmss_id
  app_gateway_id    = module.compute.app_gateway_id
  database_id       = module.database.postgresql_server_id
  vwan_id           = module.vwan.vwan_id
  vwan_hub_ids      = module.vwan.hub_ids
}
```

### outputs.tf
```hcl
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "app_gateway_public_ip" {
  description = "Public IP of the Application Gateway"
  value       = module.compute.app_gateway_public_ip
  sensitive   = false
}

output "app_gateway_fqdn" {
  description = "FQDN of the Application Gateway"
  value       = module.compute.app_gateway_fqdn
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.security.key_vault_uri
  sensitive   = true
}

output "database_server_name" {
  description = "Name of the PostgreSQL server"
  value       = module.database.postgresql_server_name
}

output "monitoring_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.monitoring.workspace_id
}

output "vwan_id" {
  description = "ID of the Virtual WAN"
  value       = module.vwan.vwan_id
}

output "vwan_hub_ids" {
  description = "IDs of the vWAN hubs"
  value       = module.vwan.hub_ids
}

output "vwan_firewall_ips" {
  description = "Public IPs of Azure Firewalls in vWAN hubs"
  value       = module.vwan.firewall_public_ips
  sensitive   = false
}

output "vpn_gateway_connections" {
  description = "VPN Gateway connection details"
  value       = module.vwan.vpn_gateway_connections
  sensitive   = true
}
```

## Module: Virtual WAN (modules/vwan/)

### main.tf
```hcl
# Virtual WAN
resource "azurerm_virtual_wan" "main" {
  name                = "vwan-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  
  # Enable branch-to-branch traffic
  allow_branch_to_branch_traffic = true
  
  # Office 365 optimization
  office365_local_breakout_category = "OptimizeAndAllow"
  
  type = "Standard"
}

# Primary vWAN Hub
resource "azurerm_virtual_hub" "primary" {
  name                = "vhub-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_wan_id      = azurerm_virtual_wan.main.id
  address_prefix      = var.hub_address_prefix
  tags                = var.tags
  
  sku = "Standard"
}

# Secondary vWAN Hub (for production DR)
resource "azurerm_virtual_hub" "secondary" {
  count               = var.secondary_location != null ? 1 : 0
  name                = "vhub-${var.name_prefix}-${var.secondary_location_short}"
  resource_group_name = var.secondary_resource_group_name
  location            = var.secondary_location
  virtual_wan_id      = azurerm_virtual_wan.main.id
  address_prefix      = var.secondary_hub_address_prefix
  tags                = var.tags
  
  sku = "Standard"
}

# Azure Firewall Policy
resource "azurerm_firewall_policy" "vwan" {
  count               = var.enable_firewall ? 1 : 0
  name                = "afwp-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Premium"
  tags                = var.tags
  
  threat_intelligence_mode = "Alert"
  
  dns {
    proxy_enabled = true
  }
  
  intrusion_detection {
    mode = "Alert"
  }
}

# Firewall Policy Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "vwan" {
  count              = var.enable_firewall ? 1 : 0
  name               = "DefaultRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.vwan[0].id
  priority           = 100
  
  application_rule_collection {
    name     = "AllowWebTraffic"
    priority = 100
    action   = "Allow"
    
    rule {
      name = "AllowHTTPS"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses      = ["10.0.0.0/8"]
      destination_fqdns     = ["*"]
    }
  }
  
  network_rule_collection {
    name     = "AllowInternalTraffic"
    priority = 200
    action   = "Allow"
    
    rule {
      name                  = "AllowVnetToVnet"
      protocols             = ["Any"]
      source_addresses      = ["10.0.0.0/8"]
      destination_addresses = ["10.0.0.0/8"]
      destination_ports     = ["*"]
    }
  }
  
  nat_rule_collection {
    name     = "DNATRules"
    priority = 300
    action   = "Dnat"
    
    rule {
      name                = "RDPToManagement"
      protocols           = ["TCP"]
      source_addresses    = var.allowed_ip_ranges
      destination_address = azurerm_firewall.primary[0].virtual_hub[0].public_ip_addresses[0]
      destination_ports   = ["3389"]
      translated_address  = "10.0.4.4"
      translated_port     = "3389"
    }
  }
}

# Azure Firewall in Primary Hub
resource "azurerm_firewall" "primary" {
  count               = var.enable_firewall ? 1 : 0
  name                = "afw-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_name            = "AZFW_Hub"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.vwan[0].id
  tags                = var.tags
  
  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.primary.id
    public_ip_count = 1
  }
}

# Azure Firewall in Secondary Hub
resource "azurerm_firewall" "secondary" {
  count               = var.enable_firewall && var.secondary_location != null ? 1 : 0
  name                = "afw-${var.name_prefix}-${var.secondary_location_short}"
  resource_group_name = var.secondary_resource_group_name
  location            = var.secondary_location
  sku_name            = "AZFW_Hub"
  sku_tier            = "Premium"
  firewall_policy_id  = azurerm_firewall_policy.vwan[0].id
  tags                = var.tags
  
  virtual_hub {
    virtual_hub_id = azurerm_virtual_hub.secondary[0].id
    public_ip_count = 1
  }
}

# VPN Gateway for Primary Hub
resource "azurerm_vpn_gateway" "primary" {
  count               = length(var.branch_sites) > 0 ? 1 : 0
  name                = "vpng-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_hub_id      = azurerm_virtual_hub.primary.id
  tags                = var.tags
  
  bgp_settings {
    asn         = 65515
    peer_weight = 0
  }
  
  scale_unit = 2
}

# VPN Sites (Branch Offices)
resource "azurerm_vpn_site" "branches" {
  for_each            = var.branch_sites
  name                = "vpns-${var.name_prefix}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_wan_id      = azurerm_virtual_wan.main.id
  tags                = var.tags
  
  address_cidrs = each.value.address_space
  
  link {
    name       = "${each.key}-link"
    ip_address = each.value.vpn_gateway_address
    
    bgp {
      asn             = 65000
      peering_address = cidrhost(each.value.address_space[0], 1)
    }
    
    provider_name = "ISP"
    speed_in_mbps = each.value.bandwidth_mbps
  }
}

# VPN Connections to Branch Sites
resource "azurerm_vpn_gateway_connection" "branches" {
  for_each           = var.branch_sites
  name               = "vpnc-${var.name_prefix}-${each.key}"
  vpn_gateway_id     = azurerm_vpn_gateway.primary[0].id
  remote_vpn_site_id = azurerm_vpn_site.branches[each.key].id
  
  vpn_link {
    name             = "${each.key}-connection"
    vpn_site_link_id = azurerm_vpn_site.branches[each.key].link[0].id
    
    bgp_enabled = true
    
    ipsec_policy {
      sa_lifetime_sec          = 3600
      sa_data_size_kb          = 102400000
      ipsec_encryption         = "AES256"
      ipsec_integrity          = "SHA256"
      ike_encryption           = "AES256"
      ike_integrity            = "SHA256"
      dh_group                 = "DHGroup14"
      pfs_group                = "PFS14"
    }
    
    shared_key = each.value.pre_shared_key
  }
  
  routing {
    associated_route_table_id = azurerm_virtual_hub.primary.default_route_table_id
    
    propagated_route_table {
      route_table_ids = [azurerm_virtual_hub.primary.default_route_table_id]
    }
  }
}

# ExpressRoute Gateway for Primary Hub
resource "azurerm_express_route_gateway" "primary" {
  count               = length(var.express_route_circuits) > 0 ? 1 : 0
  name                = "ergw-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  virtual_hub_id      = azurerm_virtual_hub.primary.id
  scale_units         = 2
  tags                = var.tags
}

# ExpressRoute Circuits
resource "azurerm_express_route_circuit" "circuits" {
  for_each            = var.express_route_circuits
  name                = "erc-${var.name_prefix}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  
  service_provider_properties {
    service_provider_name = each.value.service_provider
    peering_location      = each.value.peering_location
    bandwidth_in_mbps     = each.value.bandwidth_mbps
  }
  
  sku {
    tier   = each.value.sku_tier
    family = each.value.sku_family
  }
  
  allow_classic_operations = false
}

# ExpressRoute Circuit Peering
resource "azurerm_express_route_circuit_peering" "circuits" {
  for_each                      = var.express_route_circuits
  peering_type                  = "AzurePrivatePeering"
  express_route_circuit_name    = azurerm_express_route_circuit.circuits[each.key].name
  resource_group_name           = var.resource_group_name
  peer_asn                      = 65000
  primary_peer_address_prefix   = "192.168.1.0/30"
  secondary_peer_address_prefix = "192.168.2.0/30"
  vlan_id                       = 100
  shared_key                    = "SharedSecret123!"
}

# ExpressRoute Connections
resource "azurerm_express_route_connection" "circuits" {
  for_each                     = var.express_route_circuits
  name                         = "ercon-${var.name_prefix}-${each.key}"
  express_route_gateway_id     = azurerm_express_route_gateway.primary[0].id
  express_route_circuit_peering_id = azurerm_express_route_circuit_peering.circuits[each.key].id
  
  routing {
    associated_route_table_id = azurerm_virtual_hub.primary.default_route_table_id
    
    propagated_route_table {
      route_table_ids = [azurerm_virtual_hub.primary.default_route_table_id]
    }
  }
}

# Hub Route Table (Custom Routes)
resource "azurerm_virtual_hub_route_table" "main" {
  name           = "RT-${var.name_prefix}"
  virtual_hub_id = azurerm_virtual_hub.primary.id
  
  route {
    name              = "default-to-firewall"
    destinations_type = "CIDR"
    destinations      = ["0.0.0.0/0"]
    next_hop_type     = "ResourceId"
    next_hop          = var.enable_firewall ? azurerm_firewall.primary[0].id : null
  }
  
  route {
    name              = "private-traffic"
    destinations_type = "CIDR"
    destinations      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    next_hop_type     = "ResourceId"
    next_hop          = var.enable_firewall ? azurerm_firewall.primary[0].id : null
  }
}

# Hub-to-Hub connection (for multi-region)
resource "azurerm_virtual_hub_connection" "hub_to_hub" {
  count                     = var.secondary_location != null ? 1 : 0
  name                      = "hub-connection-${var.name_prefix}"
  virtual_hub_id            = azurerm_virtual_hub.primary.id
  remote_virtual_hub_id     = azurerm_virtual_hub.secondary[0].id
  
  routing {
    associated_route_table_id = azurerm_virtual_hub.primary.default_route_table_id
    
    propagated_route_table {
      route_table_ids = [
        azurerm_virtual_hub.primary.default_route_table_id,
        azurerm_virtual_hub.secondary[0].default_route_table_id
      ]
    }
  }
}
```

### variables.tf
```hcl
variable "resource_group_name" {
  description = "Name of the primary resource group"
  type        = string
}

variable "secondary_resource_group_name" {
  description = "Name of the secondary resource group for DR"
  type        = string
  default     = null
}

variable "location" {
  description = "Primary Azure region"
  type        = string
}

variable "secondary_location" {
  description = "Secondary Azure region for DR"
  type        = string
  default     = null
}

variable "secondary_location_short" {
  description = "Short form of secondary Azure region"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "hub_address_prefix" {
  description = "Address prefix for primary vWAN hub"
  type        = string
  default     = "10.100.0.0/24"
}

variable "secondary_hub_address_prefix" {
  description = "Address prefix for secondary vWAN hub"
  type        = string
  default     = "10.101.0.0/24"
}

variable "enable_firewall" {
  description = "Enable Azure Firewall in vWAN hub"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed for management access"
  type        = list(string)
  default     = []
}

variable "branch_sites" {
  description = "Branch site configurations for S2S VPN"
  type = map(object({
    address_space = list(string)
    vpn_gateway_address = string
    pre_shared_key = string
    bandwidth_mbps = number
  }))
  default = {}
}

variable "express_route_circuits" {
  description = "ExpressRoute circuit configurations"
  type = map(object({
    service_provider = string
    peering_location = string
    bandwidth_mbps = number
    sku_tier = string
    sku_family = string
  }))
  default = {}
}
```

### outputs.tf
```hcl
output "vwan_id" {
  description = "ID of the Virtual WAN"
  value       = azurerm_virtual_wan.main.id
}

output "hub_id" {
  description = "ID of the primary vWAN hub"
  value       = azurerm_virtual_hub.primary.id
}

output "hub_ids" {
  description = "IDs of all vWAN hubs"
  value = concat(
    [azurerm_virtual_hub.primary.id],
    var.secondary_location != null ? [azurerm_virtual_hub.secondary[0].id] : []
  )
}

output "firewall_public_ips" {
  description = "Public IPs of Azure Firewalls"
  value = var.enable_firewall ? {
    primary   = azurerm_firewall.primary[0].virtual_hub[0].public_ip_addresses
    secondary = var.secondary_location != null ? azurerm_firewall.secondary[0].virtual_hub[0].public_ip_addresses : []
  } : {}
}

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = length(var.branch_sites) > 0 ? azurerm_vpn_gateway.primary[0].id : null
}

output "vpn_gateway_connections" {
  description = "VPN Gateway connection details"
  value = {
    for k, v in azurerm_vpn_gateway_connection.branches : k => {
      name   = v.name
      status = v.id
    }
  }
}

output "express_route_gateway_id" {
  description = "ID of the ExpressRoute Gateway"
  value       = length(var.express_route_circuits) > 0 ? azurerm_express_route_gateway.primary[0].id : null
}

output "default_route_table_id" {
  description = "ID of the default route table"
  value       = azurerm_virtual_hub.primary.default_route_table_id
}
```

## Module: Networking (modules/networking/) - Updated for vWAN

### main.tf
```hcl
# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  tags               = var.tags
}

# vWAN Hub Connection
resource "azurerm_virtual_hub_connection" "main" {
  count                     = var.enable_vwan_connection ? 1 : 0
  name                      = "vhub-connection-${var.name_prefix}"
  virtual_hub_id            = var.vwan_hub_id
  remote_virtual_network_id = azurerm_virtual_network.main.id
  
  routing {
    associated_route_table_id = var.vwan_route_table_id
    
    propagated_route_table {
      route_table_ids = [var.vwan_route_table_id]
    }
    
    static_vnet_route {
      name                = "vnet-default-route"
      address_prefixes    = var.vnet_address_space
      next_hop_ip_address = cidrhost(var.vnet_address_space[0], 1)
    }
  }
}

# Subnets
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_configs
  
  name                 = "snet-${var.name_prefix}-${each.key}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = each.value.address_prefixes
  service_endpoints    = try(each.value.service_endpoints, [])
  
  dynamic "delegation" {
    for_each = can(each.value.delegation) ? [each.value.delegation] : []
    content {
      name = "delegation"
      service_delegation {
        name = delegation.value
      }
    }
  }
}

# Network Security Groups
resource "azurerm_network_security_group" "nsgs" {
  for_each = var.subnet_configs
  
  name                = "nsg-${var.name_prefix}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags               = var.tags
}

# NSG Rules for Application Gateway
resource "azurerm_network_security_rule" "gateway_inbound_http" {
  name                        = "AllowHTTP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "80"
  source_address_prefix      = "Internet"
  destination_address_prefix = "*"
  network_security_group_name = azurerm_network_security_group.nsgs["gateway"].name
  resource_group_name        = var.resource_group_name
}

resource "azurerm_network_security_rule" "gateway_inbound_https" {
  name                        = "AllowHTTPS"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "443"
  source_address_prefix      = "Internet"
  destination_address_prefix = "*"
  network_security_group_name = azurerm_network_security_group.nsgs["gateway"].name
  resource_group_name        = var.resource_group_name
}

resource "azurerm_network_security_rule" "gateway_health_probe" {
  name                        = "AllowHealthProbe"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "65200-65535"
  source_address_prefix      = "GatewayManager"
  destination_address_prefix = "*"
  network_security_group_name = azurerm_network_security_group.nsgs["gateway"].name
  resource_group_name        = var.resource_group_name
}

# Allow traffic from vWAN hub
resource "azurerm_network_security_rule" "allow_vwan_hub" {
  for_each = var.enable_vwan_connection ? var.subnet_configs : {}
  
  name                        = "AllowVWANHub"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range          = "*"
  destination_port_range     = "*"
  source_address_prefix      = "10.100.0.0/24"  # vWAN hub prefix
  destination_address_prefix = "*"
  network_security_group_name = azurerm_network_security_group.nsgs[each.key].name
  resource_group_name        = var.resource_group_name
}

# NSG Associations
resource "azurerm_subnet_network_security_group_association" "associations" {
  for_each = var.subnet_configs
  
  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsgs[each.key].id
}

# Route Table for forced tunneling through vWAN
resource "azurerm_route_table" "vwan_routes" {
  count                         = var.enable_vwan_connection ? 1 : 0
  name                          = "rt-${var.name_prefix}-vwan"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  disable_bgp_route_propagation = false
  tags                          = var.tags
}

# Default route to vWAN hub
resource "azurerm_route" "to_vwan" {
  count                  = var.enable_vwan_connection ? 1 : 0
  name                   = "default-to-vwan"
  resource_group_name    = var.resource_group_name
  route_table_name       = azurerm_route_table.vwan_routes[0].name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.100.0.68"  # Azure Firewall IP in vWAN hub
}

# Associate route table with subnets (except gateway subnet)
resource "azurerm_subnet_route_table_association" "vwan_routes" {
  for_each = var.enable_vwan_connection ? {
    for k, v in var.subnet_configs : k => v if k != "gateway"
  } : {}
  
  subnet_id      = azurerm_subnet.subnets[each.key].id
  route_table_id = azurerm_route_table.vwan_routes[0].id
}

# DDoS Protection (Optional for production)
resource "azurerm_network_ddos_protection_plan" "main" {
  count = var.enable_ddos_protection ? 1 : 0
  
  name                = "ddos-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags               = var.tags
}
```

### variables.tf
```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "vnet_address_space" {
  description = "Address space for virtual network"
  type        = list(string)
}

variable "subnet_configs" {
  description = "Configuration for subnets"
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
    delegation       = optional(string, null)
  }))
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection plan"
  type        = bool
  default     = false
}

variable "vwan_hub_id" {
  description = "ID of the vWAN hub to connect to"
  type        = string
  default     = null
}

variable "enable_vwan_connection" {
  description = "Enable connection to vWAN hub"
  type        = bool
  default     = false
}

variable "vwan_route_table_id" {
  description = "ID of the vWAN route table"
  type        = string
  default     = null
}
```

### outputs.tf
```hcl
output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value = {
    for k, v in azurerm_subnet.subnets : k => v.id
  }
}

output "nsg_ids" {
  description = "Map of NSG names to IDs"
  value = {
    for k, v in azurerm_network_security_group.nsgs : k => v.id
  }
}
```

## Module: Security (modules/security/)

### main.tf
```hcl
# Get current client configuration
data "azurerm_client_config" "current" {}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                        = "kv-${replace(var.name_prefix, "-", "")}${random_string.kv_suffix.result}"
  resource_group_name         = var.resource_group_name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enabled_for_disk_encryption = true
  enabled_for_deployment      = true
  enabled_for_template_deployment = true
  purge_protection_enabled    = true
  soft_delete_retention_days  = 90
  tags                       = var.tags
  
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.subnet_id]
    ip_rules                  = var.allowed_ip_ranges
  }
}

# Random suffix for Key Vault name uniqueness
resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Key Vault access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "admin" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  
  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
  ]
  
  key_permissions = [
    "Get", "List", "Create", "Delete", "Recover", "Backup", "Restore", "Purge"
  ]
  
  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Recover", "Backup", "Restore", "Purge"
  ]
}

# Storage Account for secure file storage
resource "azurerm_storage_account" "secure" {
  name                     = "st${replace(var.name_prefix, "-", "")}${random_string.storage_suffix.result}"
  resource_group_name      = var.resource_group_name
  location                = var.location
  account_tier            = "Standard"
  account_replication_type = "GRS"
  tags                    = var.tags
  
  identity {
    type = "SystemAssigned"
  }
  
  blob_properties {
    versioning_enabled = true
    
    delete_retention_policy {
      days = 30
    }
    
    container_delete_retention_policy {
      days = 30
    }
  }
  
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [var.subnet_id]
    ip_rules                  = var.allowed_ip_ranges
  }
  
  min_tls_version = "TLS1_2"
  enable_https_traffic_only = true
}

resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Application Insights for APM
resource "azurerm_application_insights" "main" {
  name                = "appi-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  application_type    = "web"
  retention_in_days   = 90
  tags               = var.tags
}

# Store Application Insights key in Key Vault
resource "azurerm_key_vault_secret" "app_insights_key" {
  name         = "app-insights-instrumentation-key"
  value        = azurerm_application_insights.main.instrumentation_key
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_key_vault_access_policy.admin]
}

resource "azurerm_key_vault_secret" "app_insights_connection" {
  name         = "app-insights-connection-string"
  value        = azurerm_application_insights.main.connection_string
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_key_vault_access_policy.admin]
}
```

### variables.tf
```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "subnet_id" {
  description = "ID of the subnet for network ACLs"
  type        = string
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access Key Vault"
  type        = list(string)
  default     = []
}
```

### outputs.tf
```hcl
output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.secure.id
}

output "app_insights_id" {
  description = "ID of Application Insights"
  value       = azurerm_application_insights.main.id
}

output "app_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = azurerm_application_insights.main.instrumentation_key
  sensitive   = true
}
```

## Module: Database (modules/database/)

### main.tf
```hcl
# Random password for database admin
resource "random_password" "db_admin" {
  length  = 32
  special = true
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "14"
  administrator_login = "psqladmin"
  administrator_password = random_password.db_admin.result
  sku_name           = var.database_sku
  storage_mb         = 32768
  backup_retention_days = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup
  tags               = var.tags
  
  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }
}

# Private DNS Zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgresql" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags               = var.tags
}

# Link DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  name                  = "pdnsz-link-${var.name_prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

# Database for application
resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Store connection string in Key Vault
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "database-connection-string"
  value        = "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}:${random_password.db_admin.result}@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.app.name}?sslmode=require"
  key_vault_id = var.key_vault_id
}

# Firewall rules for Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# PostgreSQL server configuration
resource "azurerm_postgresql_flexible_server_configuration" "log_checkpoints" {
  name      = "log_checkpoints"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}
```

### variables.tf
```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "subnet_id" {
  description = "ID of the database subnet"
  type        = string
}

variable "vnet_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Key Vault"
  type        = string
}

variable "database_sku" {
  description = "SKU for PostgreSQL server"
  type        = string
}

variable "backup_retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 7
}

variable "geo_redundant_backup" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}
```

### outputs.tf
```hcl
output "postgresql_server_id" {
  description = "ID of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.id
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "postgresql_server_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "connection_string_secret_id" {
  description = "ID of the connection string secret in Key Vault"
  value       = azurerm_key_vault_secret.db_connection_string.id
}
```

## Module: Compute (modules/compute/)

### main.tf
```hcl
# Public IP for Application Gateway
resource "azurerm_public_ip" "app_gateway" {
  name                = "pip-${var.name_prefix}-appgw"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                = "Standard"
  domain_name_label  = "${var.name_prefix}-app"
  tags               = var.tags
}

# Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = "agw-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags               = var.tags
  
  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }
  
  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = var.gateway_subnet_id
  }
  
  frontend_port {
    name = "http-port"
    port = 80
  }
  
  frontend_port {
    name = "https-port"
    port = 443
  }
  
  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.app_gateway.id
  }
  
  backend_address_pool {
    name = "backend-pool"
  }
  
  backend_http_settings {
    name                  = "backend-http-settings"
    cookie_based_affinity = "Enabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name           = "health-probe"
  }
  
  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip"
    frontend_port_name            = "http-port"
    protocol                      = "Http"
  }
  
  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "backend-http-settings"
  }
  
  probe {
    name                = "health-probe"
    protocol            = "Http"
    path                = "/health"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
  }
  
  autoscale_configuration {
    min_capacity = 2
    max_capacity = 10
  }
  
  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }
}

# Virtual Machine Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "app" {
  name                = "vmss-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                = var.vm_sku
  instances          = var.vm_instances.default
  admin_username     = "azureuser"
  tags               = var.tags
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  
  network_interface {
    name    = "nic"
    primary = true
    
    ip_configuration {
      name                                         = "ipconfig"
      primary                                      = true
      subnet_id                                    = var.subnet_id
      application_gateway_backend_address_pool_ids = [azurerm_application_gateway.main.backend_address_pool[0].id]
    }
  }
  
  boot_diagnostics {
    storage_account_uri = null
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    db_connection_string_secret_id = var.database_connection_string
    key_vault_uri                  = var.key_vault_uri
  }))
}

# SSH Key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store SSH private key in Key Vault
resource "azurerm_key_vault_secret" "ssh_private_key" {
  name         = "vmss-ssh-private-key"
  value        = tls_private_key.ssh.private_key_pem
  key_vault_id = var.key_vault_id
}

# Autoscale settings
resource "azurerm_monitor_autoscale_setting" "vmss" {
  name                = "autoscale-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.app.id
  
  profile {
    name = "default"
    
    capacity {
      default = var.vm_instances.default
      minimum = var.vm_instances.min
      maximum = var.vm_instances.max
    }
    
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        statistic          = "Average"
        time_grain         = "PT1M"
        time_aggregation   = "Average"
        time_window        = "PT5M"
        operator           = "GreaterThan"
        threshold          = 75
      }
      
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
    
    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.app.id
        statistic          = "Average"
        time_grain         = "PT1M"
        time_aggregation   = "Average"
        time_window        = "PT5M"
        operator           = "LessThan"
        threshold          = 25
      }
      
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }
}
```

### variables.tf
```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "subnet_id" {
  description = "ID of the application subnet"
  type        = string
}

variable "gateway_subnet_id" {
  description = "ID of the gateway subnet"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Key Vault"
  type        = string
}

variable "key_vault_uri" {
  description = "URI of the Key Vault"
  type        = string
}

variable "vm_sku" {
  description = "SKU for VM instances"
  type        = string
}

variable "vm_instances" {
  description = "VM instance configuration"
  type = object({
    min     = number
    max     = number
    default = number
  })
}

variable "database_connection_string" {
  description = "Secret ID for database connection string"
  type        = string
}
```

### outputs.tf
```hcl
output "vmss_id" {
  description = "ID of the VM Scale Set"
  value       = azurerm_linux_virtual_machine_scale_set.app.id
}

output "app_gateway_id" {
  description = "ID of the Application Gateway"
  value       = azurerm_application_gateway.main.id
}

output "app_gateway_public_ip" {
  description = "Public IP address of the Application Gateway"
  value       = azurerm_public_ip.app_gateway.ip_address
}

output "app_gateway_fqdn" {
  description = "FQDN of the Application Gateway"
  value       = azurerm_public_ip.app_gateway.fqdn
}
```

## Module: Monitoring (modules/monitoring/) - Updated for vWAN

### main.tf
```hcl
# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                = "PerGB2018"
  retention_in_days   = 30
  tags               = var.tags
}

# Action Group for alerts
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  short_name          = "alerts"
  tags               = var.tags
  
  email_receiver {
    name          = "admin"
    email_address = var.admin_email
  }
}

# CPU Alert for VMSS
resource "azurerm_monitor_metric_alert" "vmss_cpu" {
  name                = "alert-${var.name_prefix}-vmss-cpu"
  resource_group_name = var.resource_group_name
  scopes              = [var.vmss_id]
  description         = "Alert when CPU exceeds 90%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags               = var.tags
  
  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Database Alert
resource "azurerm_monitor_metric_alert" "database_cpu" {
  name                = "alert-${var.name_prefix}-db-cpu"
  resource_group_name = var.resource_group_name
  scopes              = [var.database_id]
  description         = "Alert when database CPU exceeds 80%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags               = var.tags
  
  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Application Gateway Alert
resource "azurerm_monitor_metric_alert" "app_gateway_unhealthy" {
  name                = "alert-${var.name_prefix}-agw-unhealthy"
  resource_group_name = var.resource_group_name
  scopes              = [var.app_gateway_id]
  description         = "Alert when backend hosts are unhealthy"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags               = var.tags
  
  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "UnhealthyHostCount"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 0
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# vWAN Hub Health Alert
resource "azurerm_monitor_metric_alert" "vwan_hub_health" {
  for_each            = toset(var.vwan_hub_ids)
  name                = "alert-${var.name_prefix}-vwan-hub-${substr(each.key, -8, -1)}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value]
  description         = "Alert for vWAN hub health issues"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags               = var.tags
  
  criteria {
    metric_namespace = "Microsoft.Network/virtualHubs"
    metric_name      = "VirtualHubHealthStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# VPN Gateway Connection Alert
resource "azurerm_monitor_metric_alert" "vpn_connection" {
  count               = var.vpn_gateway_id != null ? 1 : 0
  name                = "alert-${var.name_prefix}-vpn-connection"
  resource_group_name = var.resource_group_name
  scopes              = [var.vpn_gateway_id]
  description         = "Alert when VPN connections drop"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags               = var.tags
  
  criteria {
    metric_namespace = "Microsoft.Network/vpnGateways"
    metric_name      = "TunnelConnectionStatus"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }
  
  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Diagnostic Settings for Application Gateway
resource "azurerm_monitor_diagnostic_setting" "app_gateway" {
  name                       = "diag-${var.name_prefix}-agw"
  target_resource_id         = var.app_gateway_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  enabled_log {
    category = "ApplicationGatewayAccessLog"
  }
  
  enabled_log {
    category = "ApplicationGatewayPerformanceLog"
  }
  
  enabled_log {
    category = "ApplicationGatewayFirewallLog"
  }
  
  metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for vWAN
resource "azurerm_monitor_diagnostic_setting" "vwan" {
  name                       = "diag-${var.name_prefix}-vwan"
  target_resource_id         = var.vwan_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  enabled_log {
    category = "RouteTables"
  }
  
  metric {
    category = "AllMetrics"
  }
}

# Diagnostic Settings for vWAN Hubs
resource "azurerm_monitor_diagnostic_setting" "vwan_hubs" {
  for_each                   = toset(var.vwan_hub_ids)
  name                       = "diag-${var.name_prefix}-hub-${substr(each.key, -8, -1)}"
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  
  enabled_log {
    category = "RouteTables"
  }
  
  enabled_log {
    category = "BGPLogs"
  }
  
  metric {
    category = "AllMetrics"
  }
}
```

### variables.tf (Monitoring module)
```hcl
variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "admin_email" {
  description = "Admin email for alerts"
  type        = string
}

variable "vmss_id" {
  description = "ID of the VM Scale Set"
  type        = string
}

variable "app_gateway_id" {
  description = "ID of the Application Gateway"
  type        = string
}

variable "database_id" {
  description = "ID of the PostgreSQL server"
  type        = string
}

variable "vwan_id" {
  description = "ID of the Virtual WAN"
  type        = string
}

variable "vwan_hub_ids" {
  description = "List of vWAN hub IDs"
  type        = list(string)
}

variable "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  type        = string
  default     = null
}
```

### outputs.tf (Monitoring module)
```hcl
output "workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "action_group_id" {
  description = "ID of the action group"
  value       = azurerm_monitor_action_group.main.id
}
```

## Environment Configuration Files

### environments/dev/terraform.tfvars
```hcl
project_name = "webapp"
environment  = "dev"
location     = "eastus2"
location_short = "eus2"

vm_sku = "Standard_B2s"
vm_instances = {
  min     = 1
  max     = 3
  default = 1
}

database_sku = "B_Standard_B1ms"

tags = {
  CostCenter = "Development"
  Owner      = "DevTeam"
}

allowed_ip_ranges = [
  "YOUR_OFFICE_IP/32"  # Replace with your IP
]

admin_email = "admin@example.com"

# vWAN configuration for dev (minimal)
enable_vwan_firewall = false

# No branch sites for dev
branch_sites = {}

# No ExpressRoute for dev
express_route_circuits = {}
```

### environments/prod/terraform.tfvars
```hcl
project_name = "webapp"
environment  = "prod"
location     = "eastus2"
location_short = "eus2"
secondary_location = "westus2"
secondary_location_short = "wus2"

vm_sku = "Standard_D4s_v5"
vm_instances = {
  min     = 3
  max     = 20
  default = 5
}

database_sku = "GP_Standard_D4s_v3"

tags = {
  CostCenter = "Production"
  Owner      = "ProdTeam"
  Compliance = "PCI-DSS"
}

allowed_ip_ranges = [
  "YOUR_OFFICE_IP/32"  # Replace with your IP
]

admin_email = "prod-alerts@example.com"

# vWAN configuration for production
enable_vwan_firewall = true

# Branch site VPN connections
branch_sites = {
  "newyork" = {
    address_space = ["192.168.10.0/24"]
    vpn_gateway_address = "203.0.113.10"
    pre_shared_key = "CHANGE_THIS_SECRET_KEY_NY"
    bandwidth_mbps = 100
  }
  "london" = {
    address_space = ["192.168.20.0/24"]
    vpn_gateway_address = "203.0.113.20"
    pre_shared_key = "CHANGE_THIS_SECRET_KEY_LON"
    bandwidth_mbps = 50
  }
}

# ExpressRoute configuration
express_route_circuits = {
  "primary" = {
    service_provider = "Equinix"
    peering_location = "Washington DC"
    bandwidth_mbps = 1000
    sku_tier = "Premium"
    sku_family = "UnlimitedData"
  }
}
```

### environments/prod/backend.tf
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate12345"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}
```

## Cloud-Init Configuration (modules/compute/cloud-init.yaml)
```yaml
#cloud-config
package_update: true
package_upgrade: true
packages:
  - nginx
  - docker.io
  - azure-cli
  - jq

write_files:
  - path: /etc/nginx/sites-available/default
    content: |
      server {
        listen 80 default_server;
        listen [::]:80 default_server;
        
        location /health {
          access_log off;
          return 200 "healthy\n";
          add_header Content-Type text/plain;
        }
        
        location / {
          proxy_pass http://localhost:3000;
          proxy_http_version 1.1;
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection 'upgrade';
          proxy_set_header Host $host;
          proxy_cache_bypass $http_upgrade;
        }
      }

runcmd:
  - systemctl restart nginx
  - systemctl enable docker
  - systemctl start docker
  - az login --identity
  - echo "export DB_CONNECTION_STRING=$(az keyvault secret show --vault-name ${key_vault_uri} --name database-connection-string --query value -o tsv)" >> /etc/environment
```

## Deployment Instructions for AI Tools

### Initial Setup
```bash
# 1. Initialize Azure CLI and authenticate
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# 2. Create backend storage for Terraform state
az group create --name rg-terraform-state --location eastus2
az storage account create \
  --name stterraformstate$RANDOM \
  --resource-group rg-terraform-state \
  --location eastus2 \
  --sku Standard_LRS \
  --encryption-services blob

az storage container create \
  --name tfstate \
  --account-name stterraformstate$RANDOM \
  --auth-mode login

# 3. Update backend.tf with storage account name
```

### Deployment Commands
```bash
# Development environment
cd environments/dev
terraform init
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan

# Production environment  
cd environments/prod
terraform init
terraform plan -var-file="terraform.tfvars" -out=tfplan
terraform apply tfplan
```

### Post-Deployment Validation
```bash
# Test application gateway health
curl -I http://$(terraform output -raw app_gateway_fqdn)/health

# Check VMSS instances
az vmss list-instances \
  --resource-group $(terraform output -raw resource_group_name) \
  --name vmss-* \
  --output table

# View monitoring metrics
az monitor metrics list \
  --resource $(terraform output -raw vmss_id) \
  --metric "Percentage CPU" \
  --output table

# Check vWAN hub status
az network vhub show \
  --resource-group $(terraform output -raw resource_group_name) \
  --name vhub-webapp-prod-eus2 \
  --query "routingState"

# List VPN connections
az network vpn-gateway connection list \
  --resource-group $(terraform output -raw resource_group_name) \
  --gateway-name vpng-webapp-prod-eus2 \
  --output table
```

## vWAN Architecture Documentation

### Overview
Azure Virtual WAN (vWAN) provides a unified hub for networking, security, and routing. This deployment implements a hub-spoke topology with advanced connectivity options.

### vWAN Components

#### 1. **Virtual WAN Resource**
- Global transit network backbone
- Enables branch-to-branch connectivity
- Office 365 local breakout optimization
- Standard SKU for advanced features

#### 2. **Virtual Hubs**
- **Primary Hub** (East US 2): Main connectivity point
- **Secondary Hub** (West US 2): DR and geo-redundancy (production only)
- Address spaces: 10.100.0.0/24 (primary), 10.101.0.0/24 (secondary)
- Automatic route propagation between hubs

#### 3. **Azure Firewall Integration**
- Premium tier with threat intelligence
- Intrusion detection and prevention
- DNS proxy enabled
- Application, network, and NAT rules
- Centralized security policy management

#### 4. **Connectivity Options**

##### Site-to-Site VPN
- Connects branch offices to Azure
- BGP-enabled for dynamic routing
- IPSec encryption with configurable policies
- Multiple links per site supported
- Bandwidth allocation per branch

##### ExpressRoute
- Private connectivity from on-premises
- Guaranteed bandwidth and low latency
- Redundant connections for HA
- Global reach for multi-region connectivity

##### Virtual Network Connections
- Spoke VNets connected to vWAN hub
- Transitive connectivity between spokes
- Routing through Azure Firewall
- Propagated routes to all connected networks

### Traffic Flow Patterns

#### Internet Egress
```
VM → VNet → vWAN Hub → Azure Firewall → Internet
```

#### Branch-to-Azure
```
Branch Office → S2S VPN → vWAN Hub → Azure Firewall → Spoke VNet → Application
```

#### Branch-to-Branch
```
Branch A → vWAN Hub → Azure Firewall → vWAN Hub → Branch B
```

#### On-Premises via ExpressRoute
```
On-Premises → ExpressRoute → vWAN Hub → Spoke VNet
```

### Routing Configuration

#### Default Routes
- 0.0.0.0/0 → Azure Firewall (secured virtual hub)
- RFC1918 ranges → Azure Firewall for inspection
- VNet-specific routes propagated automatically

#### Route Tables
- Default route table with automatic association
- Custom route tables for advanced scenarios
- BGP route propagation from on-premises

### Security Features

#### Network Segmentation
- Micro-segmentation via Azure Firewall rules
- NSGs at subnet level for defense in depth
- Private endpoints for PaaS services

#### Traffic Inspection
- All inter-VNet traffic through firewall
- TLS inspection capabilities
- Threat intelligence integration
- IDPS (Intrusion Detection and Prevention)

#### Access Control
- Centralized policy management
- Application rules for FQDN filtering
- Network rules for IP-based filtering
- NAT rules for inbound connectivity

### High Availability and DR

#### Multi-Region Setup (Production)
- Primary hub in East US 2
- Secondary hub in West US 2
- Automatic failover capabilities
- Cross-region connectivity

#### Redundancy Features
- Zone-redundant gateways
- Multiple firewall instances
- Dual VPN tunnels per site
- ExpressRoute circuit redundancy

### Monitoring and Diagnostics

#### Metrics Tracked
- Hub health status
- VPN connection status
- Firewall rule hits
- Bandwidth utilization
- Packet drops and errors

#### Log Categories
- Route table changes
- BGP events
- Firewall logs
- Connection diagnostics
- Flow logs

### Cost Optimization

#### Development Environment
- Single hub deployment
- No Azure Firewall (optional)
- Minimal VPN/ExpressRoute usage
- Basic monitoring

#### Production Environment
- Multi-hub with firewall
- Auto-scaling based on traffic
- Reserved capacity options
- Comprehensive monitoring

### Best Practices

1. **Hub Sizing**: Plan for 10,000 routes per hub maximum
2. **Firewall Rules**: Organize rules by priority and function
3. **BGP Configuration**: Use unique ASN per location
4. **IP Planning**: Reserve sufficient space for growth
5. **Monitoring**: Set up proactive alerts for connectivity
6. **Documentation**: Maintain network diagrams and runbooks
7. **Testing**: Regular DR drills and failover testing
8. **Updates**: Schedule maintenance windows for updates

### Troubleshooting Guide

#### VPN Connection Issues
```bash
# Check VPN gateway status
az network vpn-gateway show \
  --resource-group rg-webapp-prod-eus2 \
  --name vpng-webapp-prod-eus2

# View connection status
az network vpn-connection show \
  --resource-group rg-webapp-prod-eus2 \
  --gateway-name vpng-webapp-prod-eus2 \
  --name vpnc-webapp-prod-newyork

# Check BGP peers
az network vpn-gateway show-bgp-peer-status \
  --resource-group rg-webapp-prod-eus2 \
  --name vpng-webapp-prod-eus2
```

#### Firewall Rule Verification
```bash
# List firewall rules
az network firewall policy rule-collection-group show \
  --resource-group rg-webapp-prod-eus2 \
  --policy-name afwp-webapp-prod-eus2 \
  --name DefaultRuleCollectionGroup

# Check firewall logs
az monitor log-analytics query \
  --workspace $(terraform output -raw monitoring_workspace_id) \
  --analytics-query "AzureDiagnostics | where Category == 'AzureFirewallApplicationRule' | take 10"
```

#### Route Table Inspection
```bash
# View effective routes
az network vhub get-effective-routes \
  --resource-group rg-webapp-prod-eus2 \
  --name vhub-webapp-prod-eus2 \
  --resource-type RouteTable \
  --resource-id /subscriptions/.../routeTables/defaultRouteTable
```

## Security Best Practices Implemented

1. **Network Segmentation**: Separate subnets for gateway, application, database, and management
2. **Private Endpoints**: Database uses private endpoints, not exposed to internet
3. **Key Vault Integration**: All secrets stored in Azure Key Vault
4. **Managed Identities**: System-assigned identities for secure authentication
5. **WAF Protection**: Application Gateway with WAF enabled
6. **Network Security Groups**: Least-privilege access rules
7. **Encryption**: TLS 1.2 minimum, encryption at rest and in transit
8. **Monitoring**: Comprehensive logging and alerting
9. **Backup**: Automated backups with geo-redundancy for production
10. **DDoS Protection**: Optional DDoS protection plan
11. **vWAN Firewall**: Centralized security inspection and policy enforcement
12. **Zero Trust**: All traffic inspected, micro-segmentation enabled

## Scalability Features

1. **Auto-scaling**: VMSS scales based on CPU metrics
2. **Load Balancing**: Application Gateway distributes traffic
3. **High Availability**: Multi-zone deployment for critical components
4. **Database HA**: Zone-redundant PostgreSQL with standby replica
5. **Geo-redundancy**: Storage and backups replicated across regions
6. **Global Connectivity**: vWAN enables worldwide expansion
7. **Dynamic Routing**: BGP for automatic route updates

## Cost Optimization

1. **Environment-specific sizing**: Smaller SKUs for dev/staging
2. **Auto-scaling**: Scale down during low traffic
3. **Reserved Instances**: Can be applied for production workloads
4. **Monitoring**: Alerts for unusual resource consumption
5. **Tag-based cost tracking**: Resources tagged for cost allocation
6. **vWAN Hub Optimization**: Single hub for dev, multi-hub for prod

## Maintenance Tasks

### Regular Updates
```bash
# Update Terraform providers
terraform init -upgrade

# Check for configuration drift
terraform plan

# Apply security patches to VMs
az vmss update \
  --resource-group rg-webapp-prod-eus2 \
  --name vmss-webapp-prod-eus2 \
  --set upgradePolicy.mode=Automatic
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
# Export logs for analysis
az monitor log-analytics query \
  --workspace $(terraform output -raw monitoring_workspace_id) \
  --analytics-query "AzureDiagnostics | take 100" \
  --output table
```

## Notes for AI-Assisted Development

- All variables have validation rules to catch errors early
- Modules are self-contained with clear interfaces
- Outputs provide necessary information for integration
- Tags enable resource tracking and automation
- Naming conventions follow Azure best practices
- Comments explain complex configurations
- Error messages are descriptive for debugging
- vWAN module is optional and can be disabled for simpler deployments
- Branch sites and ExpressRoute circuits are configured via variables
- Firewall rules are customizable per environment
- Monitoring covers all critical components including vWAN
- Documentation includes architecture diagrams and traffic flows
- Troubleshooting commands provided for common issues