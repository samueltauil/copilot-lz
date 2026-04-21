#!/usr/bin/env bash
# create-drift.sh — Introduce drift on the TF-managed storage account.
#
# This creates the configuration delta that drift.yml will detect and
# file as a GitHub Issue (pre-session checklist item 4).
#
# What it changes (via the Azure portal-equivalent CLI):
#   - Toggles Allow Blob anonymous access → On  (violates LZ-SEC-02)
#   - Sets min_tls_version → TLS1_0             (violates LZ-SEC-01)
#
# Prerequisites:
#   - az CLI authenticated, correct subscription selected
#   - Platform RG + storage account already deployed via Terraform
#
# Usage:
#   ./scripts/create-drift.sh                        # auto-detect storage account
#   ./scripts/create-drift.sh --sa <account-name>    # explicit storage account name

set -euo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
log()  { printf "%s==>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn() { printf "%s!!%s %s\n"  "$YELLOW" "$RESET" "$*"; }
fail() { printf "%sxx%s %s\n"  "$RED" "$RESET" "$*" >&2; exit 1; }

SA_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sa) SA_NAME="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--sa <storage-account-name>]"
      echo "Introduce drift on the TF-managed storage account for the demo."
      exit 0 ;;
    *) fail "Unknown arg: $1" ;;
  esac
done

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
command -v az >/dev/null 2>&1 || fail "az CLI not found."

log "Checking Azure login..."
az account show -o none 2>/dev/null || fail "Not logged in. Run: az login"

# Find the platform RG. Convention: rg-lz-platform-dev
PLATFORM_RG="rg-lz-platform-dev"

if [[ -z "$SA_NAME" ]]; then
  log "Auto-detecting TF-managed storage account in $PLATFORM_RG..."
  SA_NAME=$(az storage account list -g "$PLATFORM_RG" --query "[?starts_with(name, 'stlz')].name | [0]" -o tsv 2>/dev/null) \
    || fail "Could not list storage accounts in $PLATFORM_RG. Is the platform RG deployed?"
  [[ -z "$SA_NAME" ]] && fail "No storage account matching 'stlz*' found in $PLATFORM_RG."
fi

log "Target storage account: $SA_NAME (in $PLATFORM_RG)"

# ---------------------------------------------------------------------------
# Introduce drift
# ---------------------------------------------------------------------------
log "Setting allow-blob-public-access = true (violates LZ-SEC-02)..."
az storage account update \
  -n "$SA_NAME" \
  -g "$PLATFORM_RG" \
  --allow-blob-public-access true \
  -o none

log "Setting min-tls-version = TLS1_0 (violates LZ-SEC-01)..."
az storage account update \
  -n "$SA_NAME" \
  -g "$PLATFORM_RG" \
  --min-tls-version TLS1_0 \
  -o none

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n%s${BOLD}Drift introduced on: %s%s\n" "" "$SA_NAME" "$RESET"
printf "  allow_nested_items_to_be_public : true  (should be false per LZ-SEC-02)\n"
printf "  min_tls_version                 : TLS1_0 (should be TLS1_2 per LZ-SEC-01)\n"

printf "\n%sNext steps:%s\n" "$BOLD" "$RESET"
printf "  1. Run: gh workflow run drift.yml\n"
printf "  2. Wait ~2 min, then check: gh run list -w drift.yml -L 1\n"
printf "  3. Find the drift issue: gh issue list --label drift\n"
printf "  4. Assign to copilot: gh issue edit <number> --add-assignee copilot\n"
