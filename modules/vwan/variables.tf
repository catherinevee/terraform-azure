variable "resource_group_name" {
  description = "Name of the primary resource group"
  type        = string
}

variable "secondary_resource_group_name" {
  description = "Name of the secondary resource group for DR"
  type        = string
  default     = null
}

variable "location" {
  description = "Primary Azure region"
  type        = string
}

variable "secondary_location" {
  description = "Secondary Azure region for DR"
  type        = string
  default     = null
}

variable "secondary_location_short" {
  description = "Short form of secondary Azure region"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "hub_address_prefix" {
  description = "Address prefix for primary vWAN hub"
  type        = string
  default     = "10.100.0.0/24"
}

variable "secondary_hub_address_prefix" {
  description = "Address prefix for secondary vWAN hub"
  type        = string
  default     = "10.101.0.0/24"
}

variable "enable_firewall" {
  description = "Enable Azure Firewall in vWAN hub"
  type        = bool
  default     = true
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed for management access"
  type        = list(string)
  default     = []
}

variable "branch_sites" {
  description = "Branch site configurations for S2S VPN"
  type = map(object({
    address_space = list(string)
    vpn_gateway_address = string
    pre_shared_key = string
    bandwidth_mbps = number
  }))
  default = {}
}

variable "express_route_circuits" {
  description = "ExpressRoute circuit configurations"
  type = map(object({
    service_provider = string
    peering_location = string
    bandwidth_mbps = number
    sku_tier = string
    sku_family = string
  }))
  default = {}
}