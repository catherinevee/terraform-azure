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