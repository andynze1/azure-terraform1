terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.111.0"
    }
  }
}

provider "azurerm" {
  subscription_id = "caa21c1c-cb6d-450c-af43-025e73e7c628"     // from account
  tenant_id       = "27efb6c8-a6c7-4447-837e-75c28304d7f2"     // app registration user
  client_id       = "8e8350d4-9e8b-4357-9d4e-67e656050cad"     // app reg app client id
  client_secret   = "REMOVED_SECRET" // Cert&secret app reg
  features {
    # resource_group {
    #   prevent_deletion_if_contains_resources = false
    # }
  }
}

resource "azurerm_resource_group" "dml-group" {
  name     = "app-group"
  location = "East US"
}

# resource "azurerm_network_watcher" "dml-watcher" {
#   name                = "dml-watcher"
#   location            = azurerm_resource_group.dml-group.location
#   resource_group_name = azurerm_resource_group.dml-group.name
# }
resource "azurerm_network_security_group" "dml-security-group" {
  name                = "dml-security-group"
  location            = azurerm_resource_group.dml-group.location
  resource_group_name = azurerm_resource_group.dml-group.name

  dynamic "security_rule" {
    for_each = {
      "SSH"      = { priority = 1001, destination_port_range = "22" },
      "HTTP"     = { priority = 1002, destination_port_range = "8080" },
      "HTTP-8081" = { priority = 1003, destination_port_range = "8081" },
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


resource "azurerm_virtual_network" "dml-vpn" {
  name                = "dml-vpn"
  location            = azurerm_resource_group.dml-group.location
  resource_group_name = azurerm_resource_group.dml-group.name
  address_space       = ["10.0.0.0/16"]
 // dns_servers         = ["10.0.0.4", "10.0.0.5"]
  # subnet {
  #   name           = "public-subnet"
  #   address_prefix = "10.0.1.0/24"
  # }

  # subnet {
  #   name           = "private-subnet"
  #   address_prefix = "10.0.2.0/24"
  #   security_group = azurerm_network_security_group.dml-security-group.id
  # }
  tags = {
    environment = "Production"
  }
}
resource "azurerm_subnet" "public-subnet" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.dml-group.name
  virtual_network_name = azurerm_virtual_network.dml-vpn.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_subnet" "private-subnet" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.dml-group.name
  virtual_network_name = azurerm_virtual_network.dml-vpn.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "dml-public-ip" {
  name                = "dml-public-ip"
  location            = azurerm_resource_group.dml-group.location
  resource_group_name = azurerm_resource_group.dml-group.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "dml-nic" {
  name                = "dml-nic"
  location            = azurerm_resource_group.dml-group.location
  resource_group_name = azurerm_resource_group.dml-group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dml-public-ip.id
  }
  depends_on = [
    azurerm_subnet.public-subnet
  ]
}

resource "azurerm_network_interface_security_group_association" "networksgass" {
  network_interface_id      = azurerm_network_interface.dml-nic.id
  network_security_group_id = azurerm_network_security_group.dml-security-group.id
}

resource "azurerm_linux_virtual_machine" "Jenkins-Server" {
  name                = "Jenkins-Server"
  resource_group_name = azurerm_resource_group.dml-group.name
  location            = azurerm_resource_group.dml-group.location
  size                = "Standard_D4s_v3"
  //size                = "Standard_DS1_v2"

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
}


resource "azurerm_storage_account" "appstorage" {
  name                     = "appstorage1984" // Ensure this is unique globally
  resource_group_name      = azurerm_resource_group.dml-group.name
  location                 = azurerm_resource_group.dml-group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  depends_on = [
    azurerm_resource_group.dml-group
  ]
}

resource "azurerm_storage_container" "appfolder01" {
  name                 = "appfolder01"
  storage_account_name = azurerm_storage_account.appstorage.name

  depends_on = [
    azurerm_storage_account.appstorage
  ]
}