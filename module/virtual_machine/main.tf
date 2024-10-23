terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.6.0"
    }
  }
}

provider "azurerm" {
  features {
  }
  subscription_id = "38d52de4-2fb6-4a85-96fb-5ba22d363e4e"
}

variable "rgname" {
 type = string
  default = "devrg" 
}
variable "rgloc" {
 type = string
  default = "West Europe" 
}

variable "enable_public_ip" {
  type = bool
  default = false
}

data "azurerm_client_config" "clientconfigdata" {}

resource "azurerm_resource_group" "rg" {
  name     = "${var.rgname}-${terraform.workspace}"
  location = "${var.rgloc}"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.rgname}-${terraform.workspace}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.rgname}-${terraform.workspace}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "pip" {
  count = var.enable_public_ip ? 1 : 0
  name                = "${var.rgname}-${terraform.workspace}-pip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                = "${var.rgname}-${terraform.workspace}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = var.enable_public_ip ? azurerm_public_ip.pip[0].id : null
  }
}

resource "random_password" "apass" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_key_vault_secret" "password" {
  name         = "${var.rgname}-${terraform.workspace}-password"
  value        = random_password.apass.result
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "${var.rgname}-${terraform.workspace}-machine"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = azurerm_key_vault_secret.password.value
  disable_password_authentication = "false"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

 provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx",
    ]

    connection {
      type     = "ssh"
      user     = "adminuser"
      password = azurerm_key_vault_secret.password.value 
      host     = self.public_ip_address
    }
  }

provisioner "local-exec" {
    command = "echo VM ${self.name} created with public IP ${self.public_ip_address}"
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "my_vm_id" {
  value = azurerm_linux_virtual_machine.vm.id
}

# terraform taint azurerm_linux_virtual_machine.vm
# terraform apply



resource "azurerm_key_vault" "kv" {
  name                        = "${var.rgname}-${terraform.workspace}-keyvaults"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.clientconfigdata.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.clientconfigdata.tenant_id
    object_id = data.azurerm_client_config.clientconfigdata.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get", "Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"
    ]

    storage_permissions = [
      "Get",
    ]
  }
}


resource "azurerm_network_security_group" "nsg" {
  name                = "${var.rgname}-${terraform.workspace}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}


resource "azurerm_firewall" "firewall" {
  name                = "${var.rgname}-${terraform.workspace}-firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnet.id
    public_ip_address_id = var.enable_public_ip ? azurerm_public_ip.pip[0].id : null
  }
}

resource "azurerm_firewall_network_rule_collection" "firewallrule" {
  name                = "${var.rgname}-${terraform.workspace}-firewalltestcollection"
  azure_firewall_name = azurerm_firewall.firewall.name
  resource_group_name = azurerm_resource_group.rg.name
  priority            = 100
  action              = "Allow"

  rule {
    name = "testrule"

    source_addresses = [
      "10.0.0.0/16",
    ]

    destination_ports = [
      "53",
    ]

    destination_addresses = [
      "8.8.8.8",
      "8.8.4.4",
    ]

    protocols = [
      "TCP",
      "UDP",
    ]
  }
}

resource "null_resource" "vm_provisioning" {
  triggers = {
    vm_id = azurerm_linux_virtual_machine.vm.id
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx",
    ]

    connection {
      type     = "ssh"
      user     = "adminuser"
      password = azurerm_key_vault_secret.password.value
      host     = var.enable_public_ip ? azurerm_public_ip.pip[0].ip_address : null
      #  azurerm_public_ip.pip.ip_address
      # var.enable_public_ip ? azurerm_public_ip.pip[0].id : null
    }
  }

  provisioner "local-exec" {
    command = "echo VM ${azurerm_linux_virtual_machine.vm.name} created with public IP ${var.enable_public_ip ? azurerm_public_ip.pip[0].ip_address : null}"
  }
}