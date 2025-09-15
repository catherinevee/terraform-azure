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
  location            = azurerm_resource_group.main.location
  name_prefix         = local.name_prefix
  tags                = local.common_tags

  # Secondary hub for production
  secondary_resource_group_name = var.environment == "prod" ? azurerm_resource_group.secondary[0].name : null
  secondary_location            = var.environment == "prod" ? var.secondary_location : null
  secondary_location_short      = var.environment == "prod" ? var.secondary_location_short : null

  enable_firewall        = var.enable_vwan_firewall
  branch_sites           = var.branch_sites
  express_route_circuits = var.express_route_circuits

  # Hub configuration
  hub_address_prefix           = "10.100.0.0/24"
  secondary_hub_address_prefix = "10.101.0.0/24"
}

# Networking Module (now connects to vWAN)
module "networking" {
  source = "./modules/networking"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  name_prefix         = local.name_prefix
  tags                = local.common_tags

  vnet_address_space = ["10.0.0.0/16"]

  # vWAN connection
  vwan_hub_id            = module.vwan.hub_id
  vwan_route_table_id    = module.vwan.default_route_table_id
  enable_vwan_connection = true

  subnet_configs = {
    gateway = {
      address_prefixes  = ["10.0.1.0/24"]
      service_endpoints = []
    }
    application = {
      address_prefixes  = ["10.0.2.0/24"]
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
    }
    database = {
      address_prefixes  = ["10.0.3.0/24"]
      service_endpoints = ["Microsoft.Sql"]
      delegation        = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
    management = {
      address_prefixes  = ["10.0.4.0/24"]
      service_endpoints = []
    }
  }
}

# Security Module
module "security" {
  source = "./modules/security"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  name_prefix         = local.name_prefix
  tags                = local.common_tags

  subnet_id         = module.networking.subnet_ids["application"]
  allowed_ip_ranges = var.allowed_ip_ranges
}

# Database Module
module "database" {
  source = "./modules/database"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  name_prefix         = local.name_prefix
  tags                = local.common_tags

  subnet_id                = module.networking.subnet_ids["database"]
  vnet_id                  = module.networking.vnet_id
  key_vault_id             = module.security.key_vault_id
  database_sku             = var.database_sku
  backup_retention_days    = var.environment == "prod" ? 35 : 7
  geo_redundant_backup     = var.environment == "prod" ? true : false
  enable_high_availability = var.environment == "prod" ? true : false
}

# Compute Module
module "compute" {
  source = "./modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  name_prefix         = local.name_prefix
  tags                = local.common_tags

  subnet_id         = module.networking.subnet_ids["application"]
  gateway_subnet_id = module.networking.subnet_ids["gateway"]
  key_vault_id      = module.security.key_vault_id
  key_vault_uri     = module.security.key_vault_uri
  vm_sku            = var.vm_sku
  vm_instances      = var.vm_instances

  database_connection_string = module.database.connection_string_secret_id
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  name_prefix         = local.name_prefix
  tags                = local.common_tags

  admin_email    = var.admin_email
  vmss_id        = module.compute.vmss_id
  app_gateway_id = module.compute.app_gateway_id
  database_id    = module.database.postgresql_server_id
  vwan_id        = module.vwan.vwan_id
  vwan_hub_ids   = module.vwan.hub_ids
}