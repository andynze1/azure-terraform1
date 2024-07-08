variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID"
}

variable "client_id" {
  type        = string
  description = "Azure client ID"
}

variable "client_secret" {
  type        = string
  description = "Azure client secret"
}

variable "azurerm_client_secret" {
  type        = string
  description = "Azure client secret"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "myresource-group01"
}

variable "resource_group_location" {
  description = "Location of the resource group"
  type        = string
  default     = "East US"
}

variable "virtual_network" {
  description = "Virtual network configuration"
  type = object({
    name          = string
    address_space = list(string)
  })
  default = {
    name          = "dml-vpn"
    address_space = ["10.0.0.0/16"]
  }
}

variable "subnets" {
  description = "Subnets configuration"
  type = list(object({
    name           = string
    address_prefix = string
  }))
  default = [
    {
      name           = "public_subnet"
      address_prefix = "10.0.0.0/24"
    },
    {
      name           = "private_subnet"
      address_prefix = "10.0.1.0/24"
    }
  ]
}
