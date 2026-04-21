resource "azurerm_virtual_network" "platform" {
  name                = "vnet-${var.name_prefix}-platform-${var.environment}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  address_space       = ["10.40.0.0/16"]
  tags                = local.required_tags
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.platform.name
  address_prefixes     = ["10.40.1.0/24"]
}

resource "azurerm_subnet" "pe" {
  name                 = "snet-privateendpoints"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.platform.name
  address_prefixes     = ["10.40.2.0/24"]

  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-${var.name_prefix}-app-${var.environment}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.required_tags
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

# ── Brownfield network resources (imported from rg-brownfield-demo) ────────

resource "azurerm_virtual_network" "brownfield" {
  name                = "vnet-brownfield-demo"
  location            = azurerm_resource_group.brownfield.location
  resource_group_name = azurerm_resource_group.brownfield.name
  address_space       = ["10.50.0.0/16"]
}

resource "azurerm_subnet" "brownfield_default" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.brownfield.name
  virtual_network_name = azurerm_virtual_network.brownfield.name
  address_prefixes     = ["10.50.1.0/24"]
}

resource "azurerm_network_security_group" "brownfield" {
  name                = "nsg-brownfield-demo"
  location            = azurerm_resource_group.brownfield.location
  resource_group_name = azurerm_resource_group.brownfield.name
}
