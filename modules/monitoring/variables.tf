variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
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

variable "admin_email" {
  description = "Admin email for alerts"
  type        = string
}

variable "vmss_id" {
  description = "ID of the VM Scale Set"
  type        = string
}

variable "app_gateway_id" {
  description = "ID of the Application Gateway"
  type        = string
}

variable "database_id" {
  description = "ID of the PostgreSQL server"
  type        = string
}

variable "vwan_id" {
  description = "ID of the Virtual WAN"
  type        = string
}

variable "vwan_hub_ids" {
  description = "List of vWAN hub IDs"
  type        = list(string)
}

variable "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  type        = string
  default     = null
}