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