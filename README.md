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

> **Legend:** 🎤 = what you say aloud · 🖱️ = what you click/type on screen · ⏳ = wait/fill time

---

### 0:00–0:45 — Hook

🖱️ **Screen layout before you start:**
- Left half: Azure Portal open to `rg-brownfield-demo` → Overview blade showing the untracked resources (storage account, VNet, NSG)
- Right half: VS Code with [imports.tf](imports.tf) open — the file should be empty or just have comment headers

🎤 **Say (look at the audience, not the screen):**
> "You've inherited an Azure estate. Team of three. Everyone's
> Terraform-comfortable from AWS. Goal by end of May: a governed landing zone.
> Here's one engineer's entire day with Copilot."

🖱️ Point at the portal side → "These resources exist in Azure but Terraform
doesn't know about them." Point at VS Code → "This file is empty."

---

### 0:45–3:15 — Act 1: Import brownfield

🖱️ **Step-by-step:**

1. Click into VS Code (full-screen it now — done with the portal).
2. Open Copilot Chat panel (`Ctrl+Shift+I` or click the Copilot icon).
3. Make sure chat is in **Agent mode** (check the mode dropdown at the top of chat).
4. Type exactly: **`/act1-import-brownfield`** and press Enter.
   *(This runs [.github/prompts/act1-import-brownfield.prompt.md](.github/prompts/act1-import-brownfield.prompt.md))*

⏳ **While the agent works (~60–90 sec), narrate:**

🎤 *As it reads the instructions file:*
> "First thing it does — reads our landing-zone policy file automatically.
> That's `.github/instructions/terraform-landing-zone.instructions.md`.
> Same file that will review the PR later."

🎤 *As it starts writing import blocks:*
> "These are native Terraform `import {}` blocks — no `terraform import` CLI,
> no state surgery. Terraform 1.5+ feature. The agent uses `az` to discover
> the resource IDs."

🎤 *As it writes resource definitions:*
> "Notice it's writing the resource definitions to match exactly what's in
> Azure — warts and all. TLS 1.0, public access enabled. That's intentional.
> Faithful import first, fix later."

🖱️ **When the agent finishes and runs `terraform plan`:**

5. Scroll the chat to the plan output. Look for: **"0 to add, 0 to change, 0 to destroy"**.

🎤 **Hit this line with conviction:**
> "Zero adds, zero changes, zero destroys. State matches reality. That's the
> moment your estate stops being the wild west."

---

### 3:15–6:15 — Act 2: Governance as code

🖱️ **Step-by-step:**

1. Open the VS Code integrated terminal (`` Ctrl+` ``).
2. Run these commands (have them ready in clipboard or shell history):
   ```bash
   git checkout -b demo/import-brownfield
   git add -A && git commit -m "import brownfield RG"
   git push -u origin demo/import-brownfield
   gh pr create --fill
   ```
3. Switch to your **browser tab** with github.com. Navigate to the new PR.
4. On the PR page, click **Reviewers** → select **Copilot** (the robot icon).
   Or wait — Copilot Code Review may start automatically.

⏳ **While Copilot reviews (~30–60 sec), narrate:**

🖱️ Open [.github/instructions/terraform-landing-zone.instructions.md](.github/instructions/terraform-landing-zone.instructions.md) in a new browser tab (or show it in VS Code).

🎤 *Point at the file:*
> "This Markdown file is the reviewer. Every `LZ-*` rule is policy. Copilot
> reads it automatically and enforces it on every PR. No humans needed for the
> first pass."

🖱️ **When review comments appear on the PR:**

5. Scroll through the review comments. You should see violations like:
   - `LZ-NET-01` — `public_network_access_enabled = true`
   - `LZ-SEC-01` — `min_tls_version = "TLS1_0"`
   - `LZ-TAG-04` — missing `tags = local.required_tags`
   - `LZ-NET-03` — `network_rules.default_action = "Allow"`

🎤 *Point at each comment:*
> "Public access — flagged. Old TLS — flagged. Missing tags — flagged. Network
> wide open — flagged. All from a Markdown file in the repo."

🖱️ **Now fix them:**

6. Switch back to VS Code.
7. In Copilot Chat (still in Agent mode), type: **`/act2-fix-review-comments`** and press Enter.
   *(This runs [.github/prompts/act2-fix-review-comments.prompt.md](.github/prompts/act2-fix-review-comments.prompt.md))*
8. When the agent finishes, run in the terminal:
   ```bash
   git add -A && git commit -m "fix: apply LZ policy to brownfield resources"
   git push
   ```
9. Switch to the browser. Refresh the PR page. Watch CI go green.

🎤 **Key line (pause for effect):**
> "Your landing-zone policy just reviewed the PR and the agent fixed every
> violation. The infra team reviewed zero lines of code."

---

### 6:15–8:45 — Act 3: Drift → async fix

> **Note:** This act shows work that happened *before* the demo. You
> pre-created the drift and the Issue during setup. If Copilot Coding Agent
> is enabled, the remediation PR already exists. You're walking the audience
> through the result.

🖱️ **Step-by-step:**

1. Switch to your **browser tab** with the GitHub Issues page.
2. Click on the drift Issue ("Drift detected on …").
3. Scroll to show the `terraform plan` diff embedded in the issue body.

🎤 **Say:**
> "Every night, a GitHub Actions workflow runs `terraform plan`. If it finds
> drift — someone changed something in the portal — it opens an issue
> automatically. No human woke up for this."

🖱️ 4. Scroll to the **Assignees** section. Show that it's assigned to `@copilot`.

🎤 **Say:**
> "We assigned it to Copilot. The coding agent picks it up, reads the same
> policy file, and opens a fix PR."

🖱️ 5. Click through to the **PR the coding agent opened** (linked from the issue or in the PR list).

🖱️ 6. Walk the PR — point at each of these as you narrate:
   - **PR body:** Issue link + `LZ-*` rule citations
   - **Files changed tab:** minimal diff — just the one or two drifted settings
   - **Checks tab:** all 5 gates green (fmt → validate → tflint → checkov → plan)
   - **Plan comment:** `0 adds / 1 change / 0 destroys`

🎤 **Key line:**
> "Drift detected by a workflow. Fix authored by an agent. Reviewed by a
> policy file. Your on-call just got their night back."

---

### 8:45–10:00 — Close

🖱️ Switch to the **Actions tab** on any green PR run. Expand the job to show
the 5 sequential steps: `fmt` → `validate` → `tflint` → `checkov` → `plan`.

🎤 **Say (slowly, land each phrase):**
> "Five automated gates. No human gatekeeper. The policy lives in a Markdown
> file. Copilot reads it, reviews it, and the agent fixes what it finds."

🎤 **Final takeaway (pause, then deliver verbatim — this is your closer):**
> "Copilot lets a small infra team govern brownfield Azure without becoming a
> bottleneck. The policy is in the repo, the reviewer is Copilot, and the
> agents do the rote work. You keep the keys — you just stop being the
> gatekeeper."

🖱️ Pause 2 seconds on the green checks screen. Then hand to Randy for
CAF/ALZ alignment wrap-up.

---

### Presenter cheat sheet

| If this happens… | Do this |
|---|---|
| Agent takes >2 min in Act 1 | Keep narrating the instructions file; if >3 min, switch to pre-baked branch |
| Copilot Code Review is slow | Show the policy file in detail; talk about LZ-* rules; refresh in 30 sec |
| CI fails on the PR | Check Checkov `soft_fail` — it should be `true`. Push a fix live ("see, even the fix is fast") |
| Coding agent PR doesn't exist for Act 3 | Show the Issue + explain the flow; say "the agent is still working — in production this runs overnight" |
| WiFi dies | Open your fallback PDF: 3 screenshots (imports.tf, review comments, agent PR) |

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
