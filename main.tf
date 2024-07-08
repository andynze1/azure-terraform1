terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.111.0"
    }
  }
}

# Resource Group
resource "azurerm_resource_group" "myresource-group01" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

# Virtial network - VPC
resource "azurerm_virtual_network" "dml-vpn" {
  name                = var.virtual_network.name
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  address_space       = var.virtual_network.address_space
  tags = {
    environment = "Production"
  }
}
# Public Subnet
resource "azurerm_subnet" "public-subnet" {
  name                 = var.subnets[0].name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.dml-vpn.name
  address_prefixes     = [var.subnets[0].address_prefix]
  depends_on           = [azurerm_virtual_network.dml-vpn]
}
# Private Subnet
resource "azurerm_subnet" "private-subnet" {
  name                 = var.subnets[1].address_prefix
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.dml-vpn.name
  address_prefixes     = [var.subnets[1].address_prefix]
  depends_on           = [azurerm_virtual_network.dml-vpn]
}

# Public IP address
resource "azurerm_public_ip" "dml-public-ip" {
  name                = "dml-public-ip"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
}

# Network interface
resource "azurerm_network_interface" "dml-nic" {
  name                = "dml-nic"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dml-public-ip.id
  }
  depends_on = [azurerm_subnet.public-subnet]
}

# Security Groups
resource "azurerm_network_security_group" "dml-security-group" {
  name                = "dml-security-group"
  location            = var.resource_group_location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = {
      "SSH"        = { priority = 1001, destination_port_range = "22" },
      "HTTP"       = { priority = 1002, destination_port_range = "8080" },
      "HTTP-8081"  = { priority = 1003, destination_port_range = "8081" },
      "NEXUS-9000" = { priority = 1004, destination_port_range = "9000" },
    }

    content {
      name                       = security_rule.key
      priority                   = security_rule.value.priority
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = "146.85.137.76/32"
      destination_address_prefix = "*"
    }
  }
}

# Notwork Interface and SG association
resource "azurerm_network_interface_security_group_association" "networksgass" {
  network_interface_id      = azurerm_network_interface.dml-nic.id
  network_security_group_id = azurerm_network_security_group.dml-security-group.id
  depends_on                = [azurerm_network_interface.dml-nic, azurerm_network_security_group.dml-security-group]
}

# Storage Account1
resource "azurerm_storage_account" "tfstatestore" {
  name                     = "tfstatestorageacct84"
  resource_group_name      = var.resource_group_name
  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on               = [azurerm_resource_group.myresource-group01]
}
# Storage Container1
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstatestore.name
  container_access_type = "blob"
  depends_on            = [azurerm_storage_account.tfstatestore]
}

# Storage Account2
resource "azurerm_storage_account" "appstorage" {
  name                     = "appstorage1984"
  resource_group_name      = var.resource_group_name
  location                 = var.resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  depends_on               = [azurerm_resource_group.myresource-group01]
}

# Storage Container2
resource "azurerm_storage_container" "appfolder01" {
  name                 = "appfolder01"
  storage_account_name = azurerm_storage_account.appstorage.name
  depends_on           = [azurerm_storage_account.appstorage]
}

# Virtual Machine - EC2
resource "azurerm_linux_virtual_machine" "Jenkins-Server" {
  name                = "Jenkins-Server"
  resource_group_name = var.resource_group_name
  location            = var.resource_group_location
  size                = "Standard_D4s_v3"
  admin_username = "adminuser"
  admin_ssh_key {
    username   = "adminuser"
    public_key = file("azure-keypair.pub")
  }
  network_interface_ids = [
    azurerm_network_interface.dml-nic.id,
  ]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  custom_data = filebase64("install.sh")
  depends_on = [azurerm_network_interface.dml-nic]
}

# vars {
#   resource_group_name="myresource-group01"
#   resource_group_location="East US"
#   virtual_network={
#     name="dml-vpn"
#     address_space=["10.0.0.0/16"]
#   }
#   subnets=[
#     {
#       name="public_subnet"
#       address_prefix="10.0.0.0/24"
#     },
#     {
#       name="private_subnet"
#       address_prefix="10.0.1.0/24"
#     }
#   ]
# }