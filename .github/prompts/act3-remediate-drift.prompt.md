---
mode: agent
description: Act 3 — Remediate configuration drift detected between Terraform and Azure.
---

A nightly `drift.yml` workflow detected that the Azure estate has drifted
from Terraform and opened a GitHub Issue (label `drift`).

Your task:

1. Read the linked drift Issue body to understand what changed out-of-band
   (the issue includes the full `terraform plan` diff).
2. Decide the correct remediation **per the landing-zone policy** in
   `.github/instructions/terraform-landing-zone.instructions.md`:
   - If the out-of-band change violates policy (e.g., someone enabled
     public network access), the fix is to **re-assert the Terraform
     value** (do not update code to match reality).
   - If the out-of-band change is benign and policy-compliant, update the
     Terraform code to match so the estate stops being "drifted."
3. Make the minimum set of changes to `*.tf` files to reconcile drift.
4. Run `terraform fmt -recursive` and `terraform validate`.
5. Run `terraform plan` and confirm the diff matches the stated intent.
   Do **not** run `terraform apply`.
6. Open a pull request targeting `main` whose body includes:
   - A link to the originating drift issue.
   - A bulleted list of `LZ-*` rules the change satisfies.
   - The `terraform plan` summary (adds / changes / destroys).
   - The sentence: "This PR reconciles drift detected by `drift.yml`."

Branch name: `drift/remediate-<short-description>`.
