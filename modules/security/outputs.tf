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