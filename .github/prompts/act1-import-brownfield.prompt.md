---
mode: agent
description: Act 1 — Import brownfield Azure resources into Terraform using import blocks.
---

Use the `az` CLI to list every resource in the resource group
`rg-brownfield-demo` in the currently-selected subscription.

For each resource you find:

1. Add an `import {}` block to `imports.tf` with:
   - `to` pointing at the Terraform resource address you will create
   - `id` set to the resource's full Azure resource ID (from `az`)
2. Add the matching `resource {}` definition in the appropriate file:
   - resource groups → `imports.tf` (so the import + definition stay together)
   - storage accounts → `storage.tf`
   - virtual networks / subnets / NSGs → `network.tf`
3. Follow the conventions in `.github/copilot-instructions.md` and the
   landing-zone rules in `.github/instructions/terraform-landing-zone.instructions.md`.
   Do not "fix" policy violations in this step — the goal is a faithful
   import. Act 2 will enforce policy via Copilot Code Review.
4. Use `local.required_tags` where tags are already set; otherwise preserve
   the existing tags from the live resources.

When finished:

- Run `terraform fmt -recursive`.
- Run `terraform plan` and show me the summary. The expected outcome is
  **0 to add, 0 to change, 0 to destroy** — state should match reality.

Do not run `terraform apply`. Do not delete anything.
