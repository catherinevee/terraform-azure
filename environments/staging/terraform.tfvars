project_name = "webapp"
environment  = "staging"
location     = "eastus2"
location_short = "eus2"

vm_sku = "Standard_B2ms"
vm_instances = {
  min     = 2
  max     = 5
  default = 2
}

database_sku = "GP_Standard_D2s_v3"

tags = {
  CostCenter = "Staging"
  Owner      = "DevTeam"
}

allowed_ip_ranges = [
  "203.0.113.42/32"  # Replace with your IP
]

admin_email = "terraform-admin@example.com"

# vWAN configuration for staging
enable_vwan_firewall = true

# No branch sites for staging
branch_sites = {}

# No ExpressRoute for staging
express_route_circuits = {}