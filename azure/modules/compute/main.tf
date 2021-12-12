resource "azurerm_availability_set" "web-availability-set" {
  name                = "web-availability-set"
  location            = var.location
  resource_group_name = var.resource_group
}

resource "azurerm_public_ip" "web-public-ip" {
  name                = "web-public-ip"
  resource_group_name = var.resource_group
  location            = var.location
  allocation_method   = "Static"
}

resource "azurerm_network_security_group" "webnetworksg" {
  name                = "webnetworksg"
  location            = var.location
  resource_group_name = var.resource_group
  
  security_rule {
    name                       = "ssh-rule-1"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
  }
  
  security_rule {
    name                       = "ssh-rule-2"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_address_prefix      = "192.168.3.0/24"
    source_port_range          = "*"
    destination_address_prefix = "*"
    destination_port_range     = "22"
}
}

resource "azurerm_network_interface" "web-network-interface" {
    name = "web-network-interface"
    resource_group_name = var.resource_group
    location = var.location

    ip_configuration {
        name                          = "web-webserver"
        subnet_id                     = var.web_subnet_id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.web-public-ip.id
    }
}

resource "azurerm_subnet_network_security_group_association" "web-nsg-subnet" {
  subnet_id                 = var.web_subnet_id
  network_security_group_id = azurerm_network_security_group.webnetworksg.id
  depends_on = [
    azurerm_network_security_group.webnetworksg
  ]
}

resource "azurerm_network_interface_security_group_association" "web-nic-sg-assoc" {
    network_interface_id      = azurerm_network_interface.web-network-interface.id
    network_security_group_id = azurerm_network_security_group.webnetworksg.id
}

resource "azurerm_virtual_machine" "web-vm" {
  name = "web-vm"
  location = var.location
  resource_group_name = var.resource_group
  network_interface_ids = [ azurerm_network_interface.web-network-interface.id ]
  availability_set_id = azurerm_availability_set.web-availability-set.id
  vm_size = "Standard_D2s_v3"
  delete_os_disk_on_termination = true
  
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name = "web-disk"
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name = var.web_host_name
    admin_username = var.web_username
  }

os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
        path     = "/home/diarmaid/.ssh/authorized_keys"
        key_data = file("~/.ssh/id_rsa.pub")
    }
  }

}
  
  
  resource "azurerm_availability_set" "app-availability-set" {
  name                = "app-availability-set"
  location            = var.location
  resource_group_name = var.resource_group
 }

 resource "azurerm_network_security_group" "appnetworksg" {
    name = "appnetworksg"
    location = var.location
    resource_group_name = var.resource_group

    security_rule {
        name = "ssh-rule-1"
        priority = 100
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_address_prefix = "192.168.1.0/24"
        source_port_range = "*"
        destination_address_prefix = "*"
        destination_port_range = "22"
    }
    
    security_rule {
        name = "ssh-rule-2"
        priority = 101
        direction = "Outbound"
        access = "Allow"
        protocol = "Tcp"
        source_address_prefix = "192.168.1.0/24"
        source_port_range = "*"
        destination_address_prefix = "*"
        destination_port_range = "22"
    }
}

resource "azurerm_subnet_network_security_group_association" "app-nsg-subnet" {
  subnet_id                 = var.app_subnet_id
  network_security_group_id = azurerm_network_security_group.appnetworksg.id
  depends_on = [
    azurerm_subnet_network_security_group_association.web-nsg-subnet
  ]
}

resource "azurerm_network_interface" "app-network-interface" {
    name = "app-network-interface"
    resource_group_name = var.resource_group
    location = var.location

    ip_configuration{
        name = "app-webserver"
        subnet_id = var.app_subnet_id
        private_ip_address_allocation = "Dynamic"
    }
}

resource "azurerm_network_interface_security_group_association" "app-nic-sg-assoc" {
    network_interface_id      = azurerm_network_interface.app-network-interface.id
    network_security_group_id = azurerm_network_security_group.appnetworksg.id
}
resource "azurerm_virtual_machine" "app-vm" {
  name = "app-vm"
  location = var.location
  resource_group_name = var.resource_group
  network_interface_ids = [ azurerm_network_interface.app-network-interface.id ]
  availability_set_id = azurerm_availability_set.app-availability-set.id
  vm_size = "Standard_D2s_v3"
  delete_os_disk_on_termination = true
  
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name = "app-disk"
    caching = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
        path     = "/home/diarmaid/.ssh/authorized_keys"
        key_data = file("~/.ssh/id_rsa.pub")
    }
  }
  
  os_profile {
    computer_name = var.app_host_name
    admin_username = var.app_username
  }
}

