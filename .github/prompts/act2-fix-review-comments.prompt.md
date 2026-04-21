---
mode: agent
description: Act 2 — Apply Copilot Code Review suggestions to satisfy landing-zone policy.
---

Apply the fixes flagged by Copilot Code Review on this PR so the pull
request complies with
`.github/instructions/terraform-landing-zone.instructions.md`.

Specifically, for any storage account that was imported from the
brownfield resource group:

- Set `public_network_access_enabled = false` (rule **LZ-NET-01**).
- Set `allow_nested_items_to_be_public = false` (rule **LZ-SEC-02**).
- Set `shared_access_key_enabled = false` (rule **LZ-ID-01**).
- Set `min_tls_version = "TLS1_2"` (rule **LZ-SEC-01**).
- Replace any inline tag map with `tags = local.required_tags`
  (rule **LZ-TAG-04**).
- Ensure `network_rules.default_action = "Deny"` (rule **LZ-NET-03**).

Do not modify `providers.tf`, `variables.tf`, or anything under
`.github/`.

Run `terraform fmt -recursive` and `terraform validate` after editing.
Do not run `terraform apply`.

Summarize your changes as a bulleted list citing the `LZ-*` rule IDs each
change satisfies.
