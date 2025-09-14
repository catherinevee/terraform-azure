variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.project_name))
    error_message = "Project name must be 3-24 characters, lowercase alphanumeric and hyphens only."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus2"
}

variable "location_short" {
  description = "Short form of Azure region for naming"
  type        = string
  default     = "eus2"
}

variable "secondary_location" {
  description = "Secondary Azure region for vWAN and DR"
  type        = string
  default     = "westus2"
}

variable "secondary_location_short" {
  description = "Short form of secondary Azure region"
  type        = string
  default     = "wus2"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "vm_sku" {
  description = "SKU for virtual machine scale set instances"
  type        = string
  default     = "Standard_B2ms"
}

variable "vm_instances" {
  description = "Number of VM instances in scale set"
  type = object({
    min     = number
    max     = number
    default = number
  })
  default = {
    min     = 2
    max     = 10
    default = 3
  }
}

variable "database_sku" {
  description = "SKU for PostgreSQL database"
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "admin_email" {
  description = "Admin email for notifications"
  type        = string
  sensitive   = true
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access resources"
  type        = list(string)
  default     = []
}

variable "enable_vwan_firewall" {
  description = "Enable Azure Firewall in vWAN hub"
  type        = bool
  default     = true
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