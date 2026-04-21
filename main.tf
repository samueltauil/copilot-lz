resource "azurerm_resource_group" "platform" {
  name     = "rg-${var.name_prefix}-platform-${var.environment}"
  location = var.location
  tags     = local.required_tags
}
