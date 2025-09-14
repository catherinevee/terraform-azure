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

variable "subnet_id" {
  description = "ID of the subnet for network ACLs"
  type        = string
}

variable "allowed_ip_ranges" {
  description = "IP ranges allowed to access Key Vault"
  type        = list(string)
  default     = []
}