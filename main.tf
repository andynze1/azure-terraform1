terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.111.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "caa21c1c-cb6d-450c-af43-025e73e7c628"
  tenant_id = "27efb6c8-a6c7-4447-837e-75c28304d7f2"
  client_id = "8e8350d4-9e8b-4357-9d4e-67e656050cad"
  client_secret = "REMOVED_SECRET"
  features {}
}

resource "azurerm_resource_group" "appgrp" {
  name     = "app-grp"
  location = "East US"
}