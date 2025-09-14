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
  description = "ID of the application subnet"
  type        = string
}

variable "gateway_subnet_id" {
  description = "ID of the gateway subnet"
  type        = string
}

variable "key_vault_id" {
  description = "ID of the Key Vault"
  type        = string
}

variable "key_vault_uri" {
  description = "URI of the Key Vault"
  type        = string
}

variable "vm_sku" {
  description = "SKU for VM instances"
  type        = string
}

variable "vm_instances" {
  description = "VM instance configuration"
  type = object({
    min     = number
    max     = number
    default = number
  })
}

variable "database_connection_string" {
  description = "Secret ID for database connection string"
  type        = string
}