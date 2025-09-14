terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstateca6ce2"
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}