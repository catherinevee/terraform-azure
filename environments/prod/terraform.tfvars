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
  "203.0.113.42/32"  # Replace with your IP
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