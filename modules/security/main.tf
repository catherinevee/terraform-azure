# Get current client configuration
data "azurerm_client_config" "current" {}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                            = "kv-${replace(var.name_prefix, "-", "")}${random_string.kv_suffix.result}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = "standard"
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  purge_protection_enabled        = true
  soft_delete_retention_days      = 90
  tags                            = var.tags

  network_acls {
    default_action             = "Allow" # Changed to Allow for CI/CD deployment
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.subnet_id]
    # ip_rules = [for ip in var.allowed_ip_ranges : split("/", ip)[0]]  # Disabled for deployment
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
    "Get", "List", "Create", "Delete", "Recover", "Backup", "Restore", "Purge", "Encrypt", "Decrypt", "WrapKey", "UnwrapKey"
  ]

  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Recover", "Backup", "Restore", "Purge", "Import", "Update"
  ]

  storage_permissions = [
    "Get", "List", "Delete", "Set", "Update", "RegenerateKey", "Recover", "Backup", "Restore", "Purge"
  ]
}

# Storage Account for secure file storage
resource "azurerm_storage_account" "secure" {
  name                     = "st${replace(var.name_prefix, "-", "")}${random_string.storage_suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
  tags                     = var.tags

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
    default_action             = "Allow" # Changed to Allow for CI/CD deployment
    bypass                     = ["AzureServices", "Logging", "Metrics"]
    virtual_network_subnet_ids = [var.subnet_id]
    # ip_rules = [for ip in var.allowed_ip_ranges : split("/", ip)[0]]  # Disabled for deployment
  }

  min_tls_version           = "TLS1_2"
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
  tags                = var.tags
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