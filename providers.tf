terraform {
  required_version = ">=1.0"

  required_providers {
    azuread = {
      source = "hashicorp/azuread"
      version = "~>2.41.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "=0.4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azuread" {
  tenant_id = "" #YOUR AZURE TENANT ID
  features {}
}

provider "azurerm" {
    features {}
}

provider "azapi" {
}

provider "random" {

}