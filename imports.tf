# imports.tf
#
# This file is intentionally empty at the start of the demo.
# During Act 1, Copilot (agent mode) will read `az` output for the
# brownfield resource group and populate this file with `import {}`
# blocks plus the matching `resource {}` definitions.
#
# Expected shape after agent runs:
#
#   import {
#     to = azurerm_resource_group.brownfield
#     id = "/subscriptions/<sub>/resourceGroups/rg-brownfield-demo"
#   }
#
#   resource "azurerm_resource_group" "brownfield" { ... }
