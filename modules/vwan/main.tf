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

  depends_on = [azurerm_firewall.primary]

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
      source_addresses  = ["10.0.0.0/8"]
      destination_fqdns = ["*"]
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

  # NAT rules commented out - requires firewall to be fully provisioned first
  # nat_rule_collection {
  #   name     = "DNATRules"
  #   priority = 300
  #   action   = "Dnat"

  #   rule {
  #     name                = "RDPToManagement"
  #     protocols           = ["TCP"]
  #     source_addresses    = var.allowed_ip_ranges
  #     destination_address = azurerm_firewall.primary[0].virtual_hub[0].public_ip_addresses[0]
  #     destination_ports   = ["3389"]
  #     translated_address  = "10.0.4.4"
  #     translated_port     = "3389"
  #   }
  # }
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
    virtual_hub_id  = azurerm_virtual_hub.primary.id
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
    virtual_hub_id  = azurerm_virtual_hub.secondary[0].id
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
    shared_key  = each.value.pre_shared_key
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

  service_provider_name = each.value.service_provider
  peering_location      = each.value.peering_location
  bandwidth_in_mbps     = each.value.bandwidth_mbps

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

# ExpressRoute Connections - Commented out as circuit needs provider provisioning
# resource "azurerm_express_route_connection" "circuits" {
#   for_each                         = var.express_route_circuits
#   name                             = "ercon-${var.name_prefix}-${each.key}"
#   express_route_gateway_id         = azurerm_express_route_gateway.primary[0].id
#   express_route_circuit_peering_id = azurerm_express_route_circuit_peering.circuits[each.key].id
# }

# Add delay for firewall to be fully ready
resource "time_sleep" "wait_for_firewall" {
  count = var.enable_firewall ? 1 : 0

  create_duration = "300s"

  depends_on = [azurerm_firewall.primary]
}

# Hub Route Table (Custom Routes)
resource "azurerm_virtual_hub_route_table" "main" {
  count          = var.enable_firewall ? 1 : 0
  name           = "RT-${var.name_prefix}"
  virtual_hub_id = azurerm_virtual_hub.primary.id

  depends_on = [
    azurerm_firewall.primary,
    time_sleep.wait_for_firewall
  ]

  route {
    name              = "default-to-firewall"
    destinations_type = "CIDR"
    destinations      = ["0.0.0.0/0"]
    next_hop_type     = "ResourceId"
    next_hop          = azurerm_firewall.primary[0].id
  }

  route {
    name              = "private-traffic"
    destinations_type = "CIDR"
    destinations      = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    next_hop_type     = "ResourceId"
    next_hop          = azurerm_firewall.primary[0].id
  }
}

# Hub-to-Hub connections are automatic within a vWAN