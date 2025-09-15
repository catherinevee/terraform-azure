# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Add a delay for hub to be ready
resource "time_sleep" "wait_for_hub" {
  count = var.enable_vwan_connection ? 1 : 0

  create_duration = "60s"

  triggers = {
    hub_id = var.vwan_hub_id
  }
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
      route_table_ids = var.vwan_route_table_id != null ? [var.vwan_route_table_id] : []
    }

    static_vnet_route {
      name                = "vnet-default-route"
      address_prefixes    = var.vnet_address_space
      next_hop_ip_address = cidrhost(var.vnet_address_space[0], 1)
    }
  }

  depends_on = [
    azurerm_subnet.subnets,
    time_sleep.wait_for_hub
  ]
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
    for_each = try(each.value.delegation, null) != null ? [each.value.delegation] : []
    content {
      name = "delegation"
      service_delegation {
        name    = delegation.value
        actions = try(each.value.delegation_actions, [])
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
  tags                = var.tags
}

# NSG Rules for Application Gateway
resource "azurerm_network_security_rule" "gateway_inbound_http" {
  name                        = "AllowHTTP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsgs["gateway"].name
  resource_group_name         = var.resource_group_name
}

resource "azurerm_network_security_rule" "gateway_inbound_https" {
  name                        = "AllowHTTPS"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsgs["gateway"].name
  resource_group_name         = var.resource_group_name
}

resource "azurerm_network_security_rule" "gateway_health_probe" {
  name                        = "AllowHealthProbe"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsgs["gateway"].name
  resource_group_name         = var.resource_group_name
}

# Allow traffic from vWAN hub
resource "azurerm_network_security_rule" "allow_vwan_hub" {
  for_each = var.enable_vwan_connection ? var.subnet_configs : {}

  name                        = "AllowVWANHub"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.100.0.0/24" # vWAN hub prefix
  destination_address_prefix  = "*"
  network_security_group_name = azurerm_network_security_group.nsgs[each.key].name
  resource_group_name         = var.resource_group_name
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
  next_hop_in_ip_address = "10.100.0.68" # Azure Firewall IP in vWAN hub
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
  tags                = var.tags
}