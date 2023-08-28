# Create resource group
resource "azurerm_resource_group" "rg-parsec-cloud" {
  location = var.resource_group_location
  name     = var.resource_group_name
}

# Create virtual networks
resource "azurerm_virtual_network" "parsec-public-vnet" {
  name                = "${var.resource_group_location}-public-vnet-${var.resource_group_name}"
  address_space       = ["10.0.1.0/24"]
  location            = azurerm_resource_group.rg-parsec-cloud.location
  resource_group_name = azurerm_resource_group.rg-parsec-cloud.name
}

resource "azurerm_virtual_network" "parsec-private-vnet" {
  name                = "${var.resource_group_location}-private-vnet-${var.resource_group_name}"
  address_space       = ["10.0.11.0/24"]
  location            = azurerm_resource_group.rg-parsec-cloud.location
  resource_group_name = azurerm_resource_group.rg-parsec-cloud.name
}

# Create subnets
resource "azurerm_subnet" "public-subnet" {
  name                 = "${var.resource_group_location}-public-subnet-${var.resource_group_name}"
  resource_group_name  = azurerm_resource_group.rg-parsec-cloud.name
  virtual_network_name = azurerm_virtual_network.parsec-public-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private-subnet" {
  name                 = "${var.resource_group_location}-private-subnet-${var.resource_group_name}"
  resource_group_name  = azurerm_resource_group.rg-parsec-cloud.name
  virtual_network_name = azurerm_virtual_network.parsec-private-vnet.name
  address_prefixes     = ["10.0.11.0/24"]
}

# Create Network Security Groups (NSG) and rules
resource "azurerm_network_security_group" "public_nsg" {
  name                = var.public_nsg_name
  location            = azurerm_resource_group.rg-parsec-cloud.location
  resource_group_name = azurerm_resource_group.rg-parsec-cloud.name
  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ParsecHost"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "4900"
    source_address_prefix      = azurerm_subnet.private-subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ParsecClient"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "private_nsg" {
  name                = var.private_nsg_name
  location            = azurerm_resource_group.rg-parsec-cloud.location
  resource_group_name = azurerm_resource_group.rg-parsec-cloud.name
  security_rule {
    name                       = "hpr_stream"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "5000"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_subnet.public-subnet.address_prefixes[0]
    destination_address_prefix = "*"
  }
}

# Associate NSG to subnets
resource "azurerm_subnet_network_security_group_association" "assign-nsg-public" {
  subnet_id                 = azurerm_subnet.public-subnet.id
  network_security_group_id = azurerm_network_security_group.public_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "assign-nsg-private" {
  subnet_id                 = azurerm_subnet.private-subnet.id
  network_security_group_id = azurerm_network_security_group.private_nsg.id
}

# Enable global peering between the two virtual networks
resource "azurerm_virtual_network_peering" "public-to-private" {
  name                         = "peering-to-${azurerm_virtual_network.parsec-private-vnet.name}"
  resource_group_name          = azurerm_resource_group.rg-parsec-cloud.name
  virtual_network_name         = azurerm_virtual_network.parsec-public-vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.parsec-private-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit        = false
}

resource "azurerm_virtual_network_peering" "private-to-public" {
  name                         = "peering-to-${azurerm_virtual_network.parsec-public-vnet.name}"
  resource_group_name          = azurerm_resource_group.rg-parsec-cloud.name
  virtual_network_name         = azurerm_virtual_network.parsec-private-vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.parsec-public-vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit        = false
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg-parsec-cloud.location
  resource_group_name      = azurerm_resource_group.rg-parsec-cloud.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create Virtual Machine Scale Set (VMSS) for relay servers
resource "azurerm_linux_virtual_machine_scale_set" "hpr_vmss" {
  name                            = var.relay_vmss_name
  resource_group_name             = azurerm_resource_group.rg-parsec-cloud.name
  location                        = azurerm_resource_group.rg-parsec-cloud.location
  sku                             = var.relay_vm_sku
  instances                       = var.relay_quantity
  admin_username                  = var.username
  disable_password_authentication = true
  user_data = base64encode("${file("parsechpr_bootstrap.sh")}")
  admin_ssh_key {
    username   = var.username
    public_key = var.publickey1
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
  network_interface {
    name                = "hpr-nic"
    primary             = true
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.public-subnet.id
      public_ip_address {
        name = "hpr-public-ip"
      }
    }
  }
}

# Create Virtual Machine Scale Set (VMSS) for desktops
resource "azurerm_windows_virtual_machine_scale_set" "desktop_vmss" {
  name                = var.desktop_vmss_name
  resource_group_name = azurerm_resource_group.rg-parsec-cloud.name
  location            = azurerm_resource_group.rg-parsec-cloud.location
  sku                 = var.desktop_vm_sku
  instances           = var.desktop_quantity
  admin_password      = random_password.password.result 
  admin_username      = var.username
  user_data           = base64encode("${file("user_data.json")}")
  upgrade_mode        = "Automatic"
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-22h2-pro-g2"
    version   = "latest"
  }
  os_disk {
    storage_account_type = "StandardSSD_LRS"
    caching              = "ReadWrite"
  }
  network_interface {
    name    = "win10-T4-nic"
    primary = true
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.private-subnet.id
      public_ip_address {
        name = "w10-public-ip"
      }
    }
  }
}

# Install custom script extension to configure Parsec app
resource "azurerm_virtual_machine_scale_set_extension" "powershell_extension" {
  name                         = "install_parsec"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.desktop_vmss.id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"
  auto_upgrade_minor_version   = true
  settings = jsonencode({
    "commandToExecute" = "powershell -executionpolicy unrestricted -c invoke-webrequest -uri \"https://github.com/unity-jl/t4-cloud-prep/archive/refs/heads/main.zip\" -outfile \"c:\\cloud_prep.zip\" ; expand-archive \"c:\\cloud_prep.zip\" -destinationpath \"c:\\cloud_prep\" -force ; c:\\cloud_prep\\t4-cloud-prep-main\\loader.ps1"
  })
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg-parsec-cloud.name
  }
  byte_length = 8
}

# Generate random password for desktop VMs
resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}