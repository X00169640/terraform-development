resource "azurerm_virtual_network" "azure-terraform-vnet" {
  name                = "azure-terraform-vnet"
  resource_group_name = var.resource_group
  location            = var.location
  address_space       = [var.vnetcidr]
}

resource "azurerm_subnet" "web-subnet" {
  name                 = "web-subnet"
  virtual_network_name = azurerm_virtual_network.azure-terraform-vnet.name
  resource_group_name  = var.resource_group
  address_prefixes     = [var.websubnetcidr]
}

resource "azurerm_subnet" "app-subnet" {
  name                 = "app-subnet"
  virtual_network_name = azurerm_virtual_network.azure-terraform-vnet.name
  resource_group_name  = var.resource_group
  address_prefixes     = [var.appsubnetcidr]
  depends_on           = [azurerm_subnet.web-subnet]
}

resource "azurerm_subnet" "db-subnet" {
  name                 = "db-subnet"
  virtual_network_name = azurerm_virtual_network.azure-terraform-vnet.name
  resource_group_name  = var.resource_group
  address_prefixes     = [var.dbsubnetcidr]
  depends_on           = [azurerm_subnet.app-subnet]
}