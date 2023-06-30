terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.62.1"
    }
  }

  # TODO
  #
  # backend "azurerm" {
  #     resource_group_name  = "tfstate"
  #     storage_account_name = "<storage_account_name>"
  #     container_name       = "tfstate"
  #     key                  = "terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}
