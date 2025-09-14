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