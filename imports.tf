# imports.tf
#
# Brownfield imports from rg-brownfield-demo.
# These import {} blocks bring existing Azure resources under Terraform
# management. The resource definitions faithfully mirror the live state —
# policy violations will be addressed in Act 2 via Copilot Code Review.

# ── Resource Group ─────────────────────────────────────────────────────────

import {
  to = azurerm_resource_group.brownfield
  id = "/subscriptions/4056ba05-003e-46b0-9a5c-1fbce204e9d1/resourceGroups/rg-brownfield-demo"
}

resource "azurerm_resource_group" "brownfield" {
  name     = "rg-brownfield-demo"
  location = "eastus2"
}

# ── Storage Account ────────────────────────────────────────────────────────

import {
  to = azurerm_storage_account.brownfield
  id = "/subscriptions/4056ba05-003e-46b0-9a5c-1fbce204e9d1/resourceGroups/rg-brownfield-demo/providers/Microsoft.Storage/storageAccounts/stbfdemolz7a6988"
}

# ── Virtual Network ────────────────────────────────────────────────────────

import {
  to = azurerm_virtual_network.brownfield
  id = "/subscriptions/4056ba05-003e-46b0-9a5c-1fbce204e9d1/resourceGroups/rg-brownfield-demo/providers/Microsoft.Network/virtualNetworks/vnet-brownfield-demo"
}

# ── Subnet ─────────────────────────────────────────────────────────────────

import {
  to = azurerm_subnet.brownfield_default
  id = "/subscriptions/4056ba05-003e-46b0-9a5c-1fbce204e9d1/resourceGroups/rg-brownfield-demo/providers/Microsoft.Network/virtualNetworks/vnet-brownfield-demo/subnets/snet-default"
}

# ── Network Security Group ─────────────────────────────────────────────────

import {
  to = azurerm_network_security_group.brownfield
  id = "/subscriptions/4056ba05-003e-46b0-9a5c-1fbce204e9d1/resourceGroups/rg-brownfield-demo/providers/Microsoft.Network/networkSecurityGroups/nsg-brownfield-demo"
}
