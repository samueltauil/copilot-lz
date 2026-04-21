---
applyTo: "**/*.tf"
---

# Azure Landing-Zone Guardrails

You are reviewing Terraform for the Azure landing zone. Apply these rules
strictly when authoring, editing, or reviewing any `*.tf` file. Cite the
specific rule ID (e.g., `LZ-TAG-01`) in every review comment so engineers can
trace feedback back to policy.

## Naming & regions

- **LZ-REG-01** Approved regions only: `eastus2`, `centralus`. Reject any other `location`.
- **LZ-NAME-01** Resource names must follow `<type-prefix>-<workload>-<env>[-<suffix>]`
  using Microsoft CAF abbreviations (e.g., `rg-`, `vnet-`, `snet-`, `nsg-`,
  `st` for storage accounts, `log-`, `kv-`, `pe-`).

## Required tags

- **LZ-TAG-01** Every taggable resource must carry all of:
  `environment`, `owner`, `cost-center`, `data-class`, `managed-by`, `repo`.
- **LZ-TAG-02** `data-class` must be one of `public | internal | confidential | phi`.
- **LZ-TAG-03** `managed-by` must equal `terraform`.
- **LZ-TAG-04** Prefer sourcing tags from a shared `local.required_tags` map;
  flag inline literal tag maps as a smell.

## Network exposure

- **LZ-NET-01** No resource may set `public_network_access_enabled = true`.
- **LZ-NET-02** PaaS data services (Storage, Key Vault, SQL, Cosmos, ACR,
  App Config, Service Bus, Event Hubs) must be reached via
  `azurerm_private_endpoint` on `snet-privateendpoints`.
- **LZ-NET-03** Storage accounts must set `network_rules.default_action = "Deny"`.
- **LZ-NET-04** NSG rules must not allow `0.0.0.0/0` inbound on ports 22, 3389, or
  any management-plane port. Flag `source_address_prefix = "*"` as well.
- **LZ-NET-05** Public IPs are disallowed on anything other than approved
  egress/ingress constructs (Azure Firewall, App Gateway, Front Door).

## Identity & secrets

- **LZ-ID-01** Storage accounts must set `shared_access_key_enabled = false`
  and use Entra ID (`storage_use_azuread = true` on the provider).
- **LZ-ID-02** No access keys, connection strings, SAS tokens, or passwords in
  code, variables, outputs, or `locals`. Use Key Vault references or federated
  identity.
- **LZ-ID-03** Every compute resource (VM, VMSS, App Service, Function,
  Container App) must have a system- or user-assigned managed identity.

## Encryption & TLS

- **LZ-SEC-01** `min_tls_version = "TLS1_2"` on storage, App Service, SQL, and
  any resource that exposes a TLS endpoint.
- **LZ-SEC-02** Storage: `https_traffic_only_enabled = true`,
  `allow_nested_items_to_be_public = false`.

## SKUs & tiers

- **LZ-SKU-01** Storage: `account_tier = "Standard"`, `account_replication_type`
  in `["ZRS", "GZRS", "RAGZRS"]` for prod; `LRS` only allowed for non-prod.
- **LZ-SKU-02** Approved VM sizes for general compute: `Standard_D2s_v5`,
  `Standard_D4s_v5`, `Standard_D8s_v5`. Flag anything outside this list
  unless the PR description justifies it.

## Observability

- **LZ-OBS-01** Every resource that supports diagnostic settings must have an
  `azurerm_monitor_diagnostic_setting` targeting the platform
  `azurerm_log_analytics_workspace`.

## Terraform hygiene

- **LZ-TF-01** All providers must be pinned with `~>` constraints.
- **LZ-TF-02** No `terraform apply` in CI on PRs; PRs run `plan` only.
- **LZ-TF-03** Remote state only (Azure Storage backend with OIDC). Flag any
  PR that removes the `backend "azurerm"` block or adds `backend "local"`.
- **LZ-TF-04** Prefer `moved {}` blocks over rename-then-reapply; prefer
  `import {}` blocks over the `terraform import` CLI.
- **LZ-TF-05** New `resource` blocks in `imports.tf` must be paired with a
  matching `import {}` block and produce a zero-diff `plan`.

## Review output format

When reviewing a PR, for each violation produce a comment:

> **`<RULE-ID>`** — <one-line problem>.
> *Fix:* <smallest concrete change, as a code suggestion when possible>.
