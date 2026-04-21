# Copilot repo context: Azure landing zone

This repository is an **Azure landing zone** — Terraform that governs a
brownfield Azure estate managed by a small central infrastructure team. The
team does not want to become a human bottleneck, so policy is expressed in
code and enforced by Copilot review + GitHub Actions.

## Stack

- Terraform `>= 1.9` with `azurerm ~> 4.20`, `azapi ~> 2.2`, `random ~> 3.6`.
- Remote state in Azure Storage, authenticated via OIDC federation (no
  long-lived secrets).
- CI runs `fmt`, `validate`, `tflint`, `checkov`, and `terraform plan` on
  every PR. A scheduled `drift.yml` workflow files a GitHub Issue when
  `plan -detailed-exitcode` reports drift.

## Conventions

- One file per logical area: `main.tf`, `network.tf`, `storage.tf`,
  `imports.tf`, `variables.tf`, `outputs.tf`, `providers.tf`.
- Tags come from `local.required_tags` — never inline literal tag maps.
- Approved regions: `eastus2`, `centralus`.
- Naming follows Microsoft CAF abbreviations (`rg-`, `vnet-`, `snet-`,
  `nsg-`, `st`, `log-`, `kv-`, `pe-`).
- For brownfield adoption use `import {}` blocks in `imports.tf`, never the
  `terraform import` CLI.

## Hard rules

- Never run `terraform apply` from CI or from an agent — PRs are `plan`-only.
- Never introduce `public_network_access_enabled = true`, shared access keys,
  SAS tokens, connection strings, or `0.0.0.0/0` inbound NSG rules.
- Never remove the remote backend or switch to `backend "local"`.
- Policy authority is
  [.github/instructions/terraform-landing-zone.instructions.md](instructions/terraform-landing-zone.instructions.md).
  If a request conflicts with that file, follow the instructions file and
  flag the conflict in your response.

## When helping with changes

1. Read `providers.tf`, `variables.tf`, and the target file before editing.
2. Run `terraform fmt` on touched files.
3. Summarize the change as a one-line PR title plus a bulleted body citing
   the relevant `LZ-*` rule IDs that the change satisfies.
