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

variable "vnet_address_space" {
  description = "Address space for virtual network"
  type        = list(string)
}

variable "subnet_configs" {
  description = "Configuration for subnets"
  type = map(object({
    address_prefixes  = list(string)
    service_endpoints = optional(list(string), [])
    delegation        = optional(string, null)
  }))
}

variable "enable_ddos_protection" {
  description = "Enable DDoS protection plan"
  type        = bool
  default     = false
}

variable "vwan_hub_id" {
  description = "ID of the vWAN hub to connect to"
  type        = string
  default     = null
}

variable "enable_vwan_connection" {
  description = "Enable connection to vWAN hub"
  type        = bool
  default     = false
}

variable "vwan_route_table_id" {
  description = "ID of the vWAN route table"
  type        = string
  default     = null
}