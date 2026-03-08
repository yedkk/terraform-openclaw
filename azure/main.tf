locals {
  vm_size = (
    var.agent_count <= 1  ? "Standard_B1ms" :  # 2 GB
    var.agent_count <= 3  ? "Standard_B2s" :   # 4 GB
    var.agent_count <= 6  ? "Standard_B2ms" :  # 8 GB
    var.agent_count <= 10 ? "Standard_B4ms" :  # 16 GB
    "Standard_B8ms"                            # 32 GB
  )
}

# --- SSH Key (auto-generated) ---

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# --- Auth Token ---

resource "random_id" "auth_token" {
  count       = var.agent_count
  byte_length = 32
}

# --- Resource Group ---

resource "azurerm_resource_group" "openclaw" {
  name     = "openclaw-rg"
  location = var.region
}

# --- Virtual Network ---

resource "azurerm_virtual_network" "main" {
  name                = "openclaw-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name
}

resource "azurerm_subnet" "public" {
  name                 = "openclaw-subnet"
  resource_group_name  = azurerm_resource_group.openclaw.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# --- Network Security Group ---

resource "azurerm_network_security_group" "openclaw" {
  name                = "openclaw-nsg"
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_rule" "extra_agents" {
  count                       = var.agent_count > 1 ? 1 : 0
  name                        = "ExtraAgents"
  priority                    = 300
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8002-${8000 + var.agent_count}"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.openclaw.name
  network_security_group_name = azurerm_network_security_group.openclaw.name
}

# --- Public IP ---

resource "azurerm_public_ip" "openclaw" {
  name                = "openclaw-pip"
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# --- Network Interface ---

resource "azurerm_network_interface" "openclaw" {
  name                = "openclaw-nic"
  location            = azurerm_resource_group.openclaw.location
  resource_group_name = azurerm_resource_group.openclaw.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.openclaw.id
  }
}

resource "azurerm_network_interface_security_group_association" "openclaw" {
  network_interface_id      = azurerm_network_interface.openclaw.id
  network_security_group_id = azurerm_network_security_group.openclaw.id
}

# --- Virtual Machine ---

resource "azurerm_linux_virtual_machine" "openclaw" {
  name                            = "openclaw-vm"
  location                        = azurerm_resource_group.openclaw.location
  resource_group_name             = azurerm_resource_group.openclaw.name
  size                            = local.vm_size
  admin_username                  = "azureuser"
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.openclaw.id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  custom_data = base64encode(templatefile("${path.module}/templates/cloud-init.sh.tpl", {
    agent_count = var.agent_count
    auth_tokens = random_id.auth_token[*].hex
  }))
}
