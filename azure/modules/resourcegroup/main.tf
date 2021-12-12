resource "azurerm_resource_group" "azure-terraform-rg" {
  name     = var.name
  location = var.location
}
