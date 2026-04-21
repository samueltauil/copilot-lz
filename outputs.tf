output "resource_group_name" {
  value = azurerm_resource_group.platform.name
}

output "storage_account_name" {
  value = azurerm_storage_account.platform.name
}

output "vnet_id" {
  value = azurerm_virtual_network.platform.id
}
