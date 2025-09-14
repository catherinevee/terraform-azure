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