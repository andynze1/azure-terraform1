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
  name     = "myresource-group01"
  location = "East US"
}
# Storage Account1
resource "azurerm_storage_account" "tfstatestore" {
  name                     = "tfstatestorageacct84"
  resource_group_name      = azurerm_resource_group.myresource-group01.name
  location                 = azurerm_resource_group.myresource-group01.location
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
  resource_group_name      = azurerm_resource_group.myresource-group01.name
  location                 = azurerm_resource_group.myresource-group01.location
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

# Security Groups
resource "azurerm_network_security_group" "dml-security-group" {
  name                = "dml-security-group"
  location            = azurerm_resource_group.myresource-group01.location
  resource_group_name = azurerm_resource_group.myresource-group01.name

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

# Virtial network - VPC
resource "azurerm_virtual_network" "dml-vpn" {
  name                = "dml-vpn"
  location            = azurerm_resource_group.myresource-group01.location
  resource_group_name = azurerm_resource_group.myresource-group01.name
  address_space       = ["10.0.0.0/16"]
  tags = {
    environment = "Production"
  }
}

# Public Subnet
resource "azurerm_subnet" "public-subnet" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.myresource-group01.name
  virtual_network_name = azurerm_virtual_network.dml-vpn.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on           = [azurerm_virtual_network.dml-vpn]
}
# Private Subnet
resource "azurerm_subnet" "private-subnet" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.myresource-group01.name
  virtual_network_name = azurerm_virtual_network.dml-vpn.name
  address_prefixes     = ["10.0.2.0/24"]
  depends_on           = [azurerm_virtual_network.dml-vpn]
}

# Public IP address
resource "azurerm_public_ip" "dml-public-ip" {
  name                = "dml-public-ip"
  location            = azurerm_resource_group.myresource-group01.location
  resource_group_name = azurerm_resource_group.myresource-group01.name
  allocation_method   = "Dynamic"
}

# Network interface
resource "azurerm_network_interface" "dml-nic" {
  name                = "dml-nic"
  location            = azurerm_resource_group.myresource-group01.location
  resource_group_name = azurerm_resource_group.myresource-group01.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dml-public-ip.id
  }
  depends_on = [azurerm_subnet.public-subnet]
}

# Notwork Interface and SG association
resource "azurerm_network_interface_security_group_association" "networksgass" {
  network_interface_id      = azurerm_network_interface.dml-nic.id
  network_security_group_id = azurerm_network_security_group.dml-security-group.id
  depends_on                = [azurerm_network_interface.dml-nic, azurerm_network_security_group.dml-security-group]
}
# Virtual Machine - EC2
resource "azurerm_linux_virtual_machine" "Jenkins-Server" {
  name                = "Jenkins-Server"
  resource_group_name = azurerm_resource_group.myresource-group01.name
  location            = azurerm_resource_group.myresource-group01.location
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
