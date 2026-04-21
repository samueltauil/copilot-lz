resource "random_string" "storage_suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

# Landing-zone compliant storage account. This file is the "good example"
# that Copilot Code Review will use as the positive reference during Act 2.
resource "azurerm_storage_account" "platform" {
  name                = "st${var.name_prefix}plat${var.environment}${random_string.storage_suffix.result}"
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location

  account_tier             = "Standard"
  account_replication_type = "ZRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  # Landing-zone guardrails
  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  https_traffic_only_enabled      = true

  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = local.required_tags
}

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-${azurerm_storage_account.platform.name}-blob"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  subnet_id           = azurerm_subnet.pe.id
  tags                = local.required_tags

  private_service_connection {
    name                           = "psc-${azurerm_storage_account.platform.name}-blob"
    private_connection_resource_id = azurerm_storage_account.platform.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }
}

resource "random_string" "law_suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

resource "azurerm_log_analytics_workspace" "platform" {
  name                = "log-${var.name_prefix}-platform-${var.environment}-${random_string.law_suffix.result}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.required_tags
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "diag-${azurerm_storage_account.platform.name}"
  target_resource_id         = azurerm_storage_account.platform.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.platform.id

  enabled_metric {
    category = "Transaction"
  }
}
