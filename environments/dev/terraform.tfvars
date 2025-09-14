project_name = "webapp"
environment  = "dev"
location     = "eastus2"
location_short = "eus2"

vm_sku = "Standard_B2s"
vm_instances = {
  min     = 1
  max     = 3
  default = 1
}

database_sku = "B_Standard_B1ms"

tags = {
  CostCenter = "Development"
  Owner      = "DevTeam"
}

allowed_ip_ranges = [
  "203.0.113.42/32"  # Replace with your IP
]

admin_email = "terraform-admin@example.com"

# vWAN configuration for dev (minimal)
enable_vwan_firewall = false

# No branch sites for dev
branch_sites = {}

# No ExpressRoute for dev
express_route_circuits = {}