#!/usr/bin/env bash
# preflight-check.sh — Validate that everything is ready before the demo.
#
# Checks every item from the pre-session checklist in the README.
# Run this 30 minutes before going on stage.
#
# Usage:
#   ./scripts/preflight-check.sh

set -euo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$*"; PASS=$((PASS + 1)); }
fail() { printf "  %s✗%s %s\n" "$RED"   "$RESET" "$*"; FAIL=$((FAIL + 1)); }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$*"; WARN=$((WARN + 1)); }
section() { printf "\n%s%s%s\n" "$BOLD" "$*" "$RESET"; }

# ===========================================================================
section "1. CLI tools"
# ===========================================================================
for cmd in az gh terraform tflint; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd found: $($cmd --version 2>/dev/null | head -n1)"
  else
    fail "$cmd not found — run ./scripts/install-deps.sh"
  fi
done

# ===========================================================================
section "2. Azure login & subscription"
# ===========================================================================
if az account show -o none 2>/dev/null; then
  SUB=$(az account show --query "name" -o tsv)
  SUB_ID=$(az account show --query "id" -o tsv)
  pass "Logged in to Azure: $SUB ($SUB_ID)"
else
  fail "Not logged in to Azure — run: az login"
fi

# ===========================================================================
section "3. Brownfield resource group"
# ===========================================================================
BF_RG="rg-brownfield-demo"

if az group show -n "$BF_RG" -o none 2>/dev/null; then
  pass "Resource group $BF_RG exists"
else
  fail "Resource group $BF_RG not found — run: ./scripts/setup-demo.sh"
fi

# Check for resources inside the brownfield RG
BF_COUNT=$(az resource list -g "$BF_RG" --query "length(@)" -o tsv 2>/dev/null || echo "0")
if [[ "$BF_COUNT" -ge 3 ]]; then
  pass "Brownfield RG has $BF_COUNT resources (need ≥ 3)"
else
  fail "Brownfield RG has only $BF_COUNT resources (need ≥ 3: storage + vnet + nsg)"
fi

# Check the brownfield storage account has public access (intentional violation)
BF_SA=$(az storage account list -g "$BF_RG" --query "[0].name" -o tsv 2>/dev/null || echo "")
if [[ -n "$BF_SA" ]]; then
  PUBLIC_ACCESS=$(az storage account show -n "$BF_SA" -g "$BF_RG" \
    --query "allowBlobPublicAccess" -o tsv 2>/dev/null || echo "")
  if [[ "$PUBLIC_ACCESS" == "true" ]]; then
    pass "Brownfield storage $BF_SA has public blob access ON (intentional violation)"
  else
    fail "Brownfield storage $BF_SA does NOT have public blob access — recreate with: ./scripts/setup-demo.sh"
  fi
else
  fail "No storage account found in $BF_RG"
fi

# ===========================================================================
section "4. Platform resources (TF-managed)"
# ===========================================================================
PLATFORM_RG="rg-lz-platform-dev"

if az group show -n "$PLATFORM_RG" -o none 2>/dev/null; then
  pass "Platform RG $PLATFORM_RG exists"
else
  fail "Platform RG $PLATFORM_RG not found — run terraform apply (locally, one-time)"
fi

# ===========================================================================
section "5. Drift on TF-managed storage"
# ===========================================================================
PLATFORM_SA=$(az storage account list -g "$PLATFORM_RG" --query "[?starts_with(name, 'stlz')].name | [0]" -o tsv 2>/dev/null || echo "")
if [[ -n "$PLATFORM_SA" ]]; then
  TLS=$(az storage account show -n "$PLATFORM_SA" -g "$PLATFORM_RG" --query "minimumTlsVersion" -o tsv 2>/dev/null || echo "")
  if [[ "$TLS" != "TLS1_2" ]]; then
    pass "Platform storage $PLATFORM_SA has min_tls=$TLS (drift present — good)"
  else
    warn "Platform storage $PLATFORM_SA has min_tls=TLS1_2 (no drift yet) — run: ./scripts/create-drift.sh"
  fi
else
  warn "No platform storage account found in $PLATFORM_RG — deploy TF first"
fi

# ===========================================================================
section "6. GitHub repo"
# ===========================================================================
if gh auth status >/dev/null 2>&1; then
  pass "GitHub CLI authenticated"
else
  fail "GitHub CLI not authenticated — run: gh auth login"
fi

REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
if [[ -n "$REPO" ]]; then
  pass "Repository: $REPO"
else
  fail "Could not determine GitHub repo"
fi

# Check labels
for label in drift infra; do
  if gh label list --json name -q ".[].name" 2>/dev/null | grep -qx "$label"; then
    pass "Label '$label' exists"
  else
    fail "Label '$label' missing — run: ./scripts/setup-demo.sh"
  fi
done

# Check for open drift issue
DRIFT_ISSUES=$(gh issue list --label drift --state open --json number -q 'length' 2>/dev/null || echo "0")
if [[ "$DRIFT_ISSUES" -gt 0 ]]; then
  pass "Open drift issue(s) found: $DRIFT_ISSUES"
else
  warn "No open drift issue — run: gh workflow run drift.yml (after creating drift)"
fi

# Check for copilot-assigned issue
COPILOT_ASSIGNED=$(gh issue list --label drift --state open --assignee copilot --json number -q 'length' 2>/dev/null || echo "0")
if [[ "$COPILOT_ASSIGNED" -gt 0 ]]; then
  pass "Drift issue assigned to @copilot"
else
  warn "No drift issue assigned to @copilot — assign after the issue is filed"
fi

# ===========================================================================
section "7. GitHub repo variables"
# ===========================================================================
for var in AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID TFSTATE_RG TFSTATE_SA TFSTATE_CONTAINER; do
  VAL=$(gh variable get "$var" 2>/dev/null || echo "")
  if [[ -n "$VAL" ]]; then
    # Mask all but last 4 chars for IDs
    if [[ ${#VAL} -gt 8 ]]; then
      MASKED="***${VAL: -4}"
    else
      MASKED="$VAL"
    fi
    pass "Repo variable $var = $MASKED"
  else
    fail "Repo variable $var not set — see README 'GitHub setup' section"
  fi
done

# ===========================================================================
section "8. Terraform baseline"
# ===========================================================================
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

if terraform fmt -check -recursive >/dev/null 2>&1; then
  pass "terraform fmt — clean"
else
  fail "terraform fmt — formatting issues found. Run: terraform fmt -recursive"
fi

if terraform validate -no-color >/dev/null 2>&1; then
  pass "terraform validate — valid"
else
  warn "terraform validate failed (may need terraform init first)"
fi

# ===========================================================================
section "9. imports.tf is empty (clean slate for Act 1)"
# ===========================================================================
IMPORT_LINES=$(grep -c "^import {" imports.tf 2>/dev/null || echo "0")
if [[ "$IMPORT_LINES" -eq 0 ]]; then
  pass "imports.tf has no import blocks (ready for Act 1)"
else
  fail "imports.tf already has $IMPORT_LINES import blocks — run: ./scripts/reset-demo.sh"
fi

# ===========================================================================
section "10. Local branch is clean"
# ===========================================================================
BRANCH=$(git branch --show-current)
if [[ "$BRANCH" == "main" ]]; then
  pass "On branch: main"
else
  warn "On branch: $BRANCH (expected main for demo start)"
fi

if git diff --quiet && git diff --cached --quiet; then
  pass "Working tree clean"
else
  warn "Uncommitted changes in working tree"
fi

# ===========================================================================
# Summary
# ===========================================================================
printf "\n%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$BOLD" "$RESET"
printf "  %s✓ %d passed%s  " "$GREEN" "$PASS" "$RESET"
printf "  %s✗ %d failed%s  " "$RED" "$FAIL" "$RESET"
printf "  %s! %d warnings%s\n" "$YELLOW" "$WARN" "$RESET"
printf "%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n" "$BOLD" "$RESET"

if (( FAIL > 0 )); then
  printf "\n%sFix the failures above before starting the demo.%s\n" "$RED" "$RESET"
  exit 1
elif (( WARN > 0 )); then
  printf "\n%sWarnings present — review before going on stage.%s\n" "$YELLOW" "$RESET"
  exit 0
else
  printf "\n%sAll checks passed — ready to demo!%s\n" "$GREEN" "$RESET"
  exit 0
fi
