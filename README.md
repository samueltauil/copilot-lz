# iac-demo — Azure landing zone (Copilot + Terraform demo)

A 10-minute demo repo showing how GitHub Copilot helps a small central
infrastructure team govern a brownfield Azure estate with Terraform —
**without becoming a human bottleneck**.

## Story

One engineer, one day, three moves:

1. **Import brownfield** — Copilot agent mode reads `az` output and writes
   `import {}` blocks + matching resources in [imports.tf](imports.tf).
2. **Governance as code** — on the PR, Copilot Code Review enforces the
   landing-zone policy in
   [.github/instructions/terraform-landing-zone.instructions.md](.github/instructions/terraform-landing-zone.instructions.md)
   (tags, private endpoints, approved regions/SKUs, no public access).
3. **Drift → async fix** — [.github/workflows/drift.yml](.github/workflows/drift.yml)
   files an Issue when Azure drifts from Terraform; assign it to `@copilot`
   and the coding agent opens a remediation PR governed by the landing-zone
   policy and repo `copilot-instructions.md`.

## Stack

- Terraform `>= 1.9`, providers `azurerm ~> 4.20`, `azapi ~> 2.2`,
  `random ~> 3.6`.
- Remote state in Azure Storage, **OIDC federation** (no long-lived secrets).
- CI in [.github/workflows/pr.yml](.github/workflows/pr.yml):
  `fmt` → `validate` → `tflint` → `checkov` → `plan` (plan-only, never apply).

## Repo layout

| File | Purpose |
|---|---|
| [providers.tf](providers.tf) | Provider + backend pinning |
| [variables.tf](variables.tf) | Inputs + `local.required_tags` |
| [main.tf](main.tf) | Platform resource group |
| [network.tf](network.tf) | VNet, subnets, NSG |
| [storage.tf](storage.tf) | LZ-compliant storage account + PE + diagnostics |
| [imports.tf](imports.tf) | Populated live in Act 1 |
| [outputs.tf](outputs.tf) | Selected outputs |
| [.tflint.hcl](.tflint.hcl) | TFLint config (azurerm ruleset) |
| [.github/copilot-instructions.md](.github/copilot-instructions.md) | Repo context for Copilot chat + agent |
| [.github/instructions/terraform-landing-zone.instructions.md](.github/instructions/terraform-landing-zone.instructions.md) | **Policy file** — the reviewer |
| [.github/prompts/](.github/prompts/) | Pre-baked `/act1`, `/act2`, `/act3` demo prompts |

## Local bootstrap

```bash
az login
cp terraform.tfvars.example terraform.tfvars   # edit if needed
terraform init \
  -backend-config="resource_group_name=$TFSTATE_RG" \
  -backend-config="storage_account_name=$TFSTATE_SA" \
  -backend-config="container_name=$TFSTATE_CONTAINER" \
  -backend-config="key=iac-demo.tfstate"
terraform fmt -recursive
terraform validate
terraform plan
```

> **Never run `terraform apply` on stage.** PR workflow is plan-only by design.

## GitHub setup (one-time)

Set these as **repository variables** (not secrets — they're not sensitive
under OIDC):

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TFSTATE_RG`, `TFSTATE_SA`, `TFSTATE_CONTAINER`

Federate the app registration to this repo's `pull_request` and
`schedule`/`workflow_dispatch` events.

## Pre-session checklist (run 30 min before)

1. `az login` in a clean terminal; confirm correct subscription (`az account show -o table`).
2. Brownfield RG exists **outside** Terraform:
   - `rg-brownfield-demo` in `eastus2`
   - one storage account inside, created in portal, with `allow_blob_public_access = true` (the intentional violation)
   - one vnet + nsg so the import touches 3+ resources
3. Platform RG is deployed via TF and state is in Azure Storage — so drift is detectable.
4. Create drift on the TF-managed storage account in the portal (e.g., toggle `Allow Blob anonymous access` → On, or change `min_tls_version`).
5. Manually run `drift.yml` (`gh workflow run drift.yml`) — confirm the Issue gets filed.
6. Assign that Issue to `@copilot` now — the agent's PR will exist by the time you present.
7. Open VS Code: set font size 16+, hide sidebar icons you don't need, close extra tabs, disable notifications, switch Copilot chat to **Agent** mode.
8. Pre-open these 4 tabs:
   - VS Code with the repo
   - github.com PR page (ready to refresh after Act 2 push)
   - github.com Issues page (the drift issue)
   - github.com Actions → `pr.yml` latest successful run (for the closing Checks tour)
9. `terraform fmt -check -recursive && terraform validate` → clean baseline.
10. Have a **wifi-fail fallback**: 3-screenshot PDF covering the agent's imports.tf, the Copilot review comments, and the coding-agent PR.

## Demo runbook (10 minutes)

### 0:00–0:45 — Hook
**Show:** Side-by-side — the portal RG with untracked resources, and the empty
`imports.tf` in VS Code.

**Say:**
> "You've inherited an Azure estate. Team of three. Terraform-comfortable from
> AWS. Goal by end of May is a governed landing zone. Here's one engineer's
> day with Copilot."

---

### 0:45–3:15 — Act 1: Import brownfield
**Setup:** VS Code with [imports.tf](imports.tf) open; Copilot chat in **Agent** mode.

**Prompt:** run [/act1-import-brownfield](.github/prompts/act1-import-brownfield.prompt.md)
(type `/act1-import-brownfield` in Copilot chat, or open the file and click
“Run prompt”).

**While it runs, narrate:**
- Agent reads the instructions file automatically.
- It's writing real `import {}` blocks (Terraform 1.5+) — no `terraform
  import` CLI, no state surgery.
- This is the opposite of "rewrite everything" — brownfield becomes tracked
  in place.

**Success signal to call out:** `terraform plan` says **"No changes"**. That
means state now matches reality. *"That's the moment your estate stops being
the wild west."*

---

### 3:15–6:15 — Act 2: Governance as code
**Do:**
```bash
git checkout -b demo/import-brownfield
git add -A && git commit -m "import brownfield RG"
git push -u origin demo/import-brownfield
gh pr create --fill
```
Open the PR on github.com. Copilot Code Review runs automatically (or click
**"Request Copilot review"**).

**Narrate while review posts:**
- Point at [.github/instructions/terraform-landing-zone.instructions.md](.github/instructions/terraform-landing-zone.instructions.md).
- "This file is the reviewer. Every `LZ-*` rule is policy. No humans needed
  for the first pass."

**Expected review comments** (from the brownfield violation you planted):
- `LZ-NET-01` — `public_network_access_enabled = true` on the storage account
- `LZ-TAG-01` — missing required tags
- `LZ-SEC-02` — `allow_nested_items_to_be_public` not set

**Fix in VS Code** via prompt file:
run [/act2-fix-review-comments](.github/prompts/act2-fix-review-comments.prompt.md).

Push the fix → checks go green → "Approved by Copilot."

**Key line:**
> "Your landing-zone policy just reviewed the PR. The infra team reviewed
> zero lines of code."

---

### 6:15–8:45 — Act 3: Drift → async fix
**Switch tab:** The pre-filed Issue from `drift.yml` ("Drift detected on …").
Scroll the plan diff in the issue body.

**Say:**
> "Nightly workflow compared Terraform to Azure, found a delta, opened this
> issue. No human woke up. Now watch what happens when we assign it."

Show the **Assignees → `@copilot`** selection you already made. The coding
agent receives its marching orders from
[/act3-remediate-drift](.github/prompts/act3-remediate-drift.prompt.md) —
attach or link that prompt in the issue body if you want to make the
instructions explicit on stage.

Cut to the **PR the coding agent already opened** (pre-baked overnight).

Walk the PR:
1. Issue linked in the body.
2. Diff is minimal and scoped (the one flipped setting).
3. Checks tab: `fmt`, `validate`, `tflint`, `checkov`, `plan` all green.
4. Plan comment shows **0 adds / 1 change / 0 destroys** — drift reconciled.

**Key line:**
> "Drift detected by a workflow. Fix authored by an agent. Reviewed by a
> policy file. Your on-call just got their night back."

---

### 8:45–10:00 — Close
**Switch tab:** [.github/workflows/pr.yml](.github/workflows/pr.yml) checks run.
Scroll the 5 gates: fmt → validate → tflint → checkov → plan with PR comment.

**Land the takeaway (verbatim):**
> "Copilot lets a small infra team govern brownfield Azure without becoming a
> bottleneck. The policy is in the repo, the reviewer is Copilot, and the
> agents do the rote work. You keep the keys — you just stop being the
> gatekeeper."

Hand to Randy for CAF/ALZ alignment wrap-up.

---

## Cuts if running long

| Cut order | What to drop | Time saved |
|---|---|---|
| 1 | Act 3 `@copilot` assignment gesture — go straight to pre-baked PR | ~45s |
| 2 | Reading the drift plan diff in the Issue body | ~30s |
| 3 | Closing Checks-tab tour — just land the takeaway | ~30s |

## Known risks

- **Copilot review latency** — can take 30–60s to post. Fill with narration
  pointing at the instructions file.
- **`az` auth expiring mid-demo** — re-login in the pre-session; keep a
  second terminal authenticated as backup.
- **Coding-agent PR not ready** — if you skipped the pre-bake, do **not**
  assign live. Cut Act 3 down to "here's the Issue the workflow filed" and
  walk the workflow code instead.

