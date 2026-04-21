#!/usr/bin/env bash
# setup-demo.sh — Create the brownfield Azure resources needed before the demo.
#
# This automates pre-session checklist items 2–6 from the README.
#
# What it creates:
#   1. rg-brownfield-demo (resource group in eastus2)
#   2. A storage account inside that RG with public blob access ON (the
#      intentional policy violation Copilot Code Review will catch in Act 2)
#   3. A VNet + NSG inside that RG (so the import touches 3+ resources)
#   4. GitHub labels "drift" and "infra" (idempotent)
#
# Prerequisites:
#   - az CLI authenticated (`az login`)
#   - gh CLI authenticated (`gh auth status`)
#   - Correct subscription selected (`az account set -s <sub>`)
#
# Usage:
#   ./scripts/setup-demo.sh            # interactive confirm
#   ./scripts/setup-demo.sh --yes      # no prompt
#   ./scripts/setup-demo.sh --dry-run  # show what would happen

set -euo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
log()  { printf "%s==>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn() { printf "%s!!%s %s\n"  "$YELLOW" "$RESET" "$*"; }
fail() { printf "%sxx%s %s\n"  "$RED" "$RESET" "$*" >&2; exit 1; }

DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y)  ASSUME_YES=1 ;;
    -h|--help)
      echo "Usage: $0 [--yes|--dry-run]"
      echo "Create brownfield Azure resources + GitHub labels for the demo."
      exit 0 ;;
    *) fail "Unknown arg: $arg" ;;
  esac
done

run() {
  if (( DRY_RUN )); then
    printf "  %s[dry-run]%s %s\n" "$YELLOW" "$RESET" "$*"
  else
    eval "$@"
  fi
}

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------
command -v az >/dev/null 2>&1 || fail "az CLI not found. Install: https://aka.ms/install-azure-cli"
command -v gh >/dev/null 2>&1 || fail "gh CLI not found. Install: https://cli.github.com"

log "Checking Azure login..."
SUBSCRIPTION=$(az account show --query "name" -o tsv 2>/dev/null) \
  || fail "Not logged in to Azure. Run: az login"
SUB_ID=$(az account show --query "id" -o tsv)
log "Subscription: $SUBSCRIPTION ($SUB_ID)"

log "Checking GitHub auth..."
gh auth status >/dev/null 2>&1 || fail "Not logged in to GitHub. Run: gh auth login"
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null) \
  || fail "Not inside a GitHub repo. Run from the repo root."
log "Repository: $REPO"

if (( !ASSUME_YES && !DRY_RUN )); then
  printf "\n%sThis will create Azure resources in subscription '%s' and labels on '%s'.%s\n" \
    "$BOLD" "$SUBSCRIPTION" "$REPO" "$RESET"
  printf "Continue? [y/N] "
  read -r REPLY
  [[ "$REPLY" =~ ^[Yy]$ ]] || { log "Aborted."; exit 0; }
fi

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
LOCATION="eastus2"
BF_RG="rg-brownfield-demo"
BF_SA_PREFIX="stbfdemolz"
BF_VNET="vnet-brownfield-demo"
BF_NSG="nsg-brownfield-demo"

# ---------------------------------------------------------------------------
# 1. Brownfield resource group
# ---------------------------------------------------------------------------
log "Creating resource group: $BF_RG"
if az group show -n "$BF_RG" &>/dev/null; then
  warn "Resource group $BF_RG already exists — skipping."
else
  run "az group create -n '$BF_RG' -l '$LOCATION' -o none"
fi

# ---------------------------------------------------------------------------
# 2. Brownfield storage account (intentionally non-compliant)
# ---------------------------------------------------------------------------
# Storage account names must be globally unique; append a short hash.
SUFFIX=$(echo "${SUB_ID}" | md5sum | head -c 6)
BF_SA="${BF_SA_PREFIX}${SUFFIX}"

log "Creating storage account: $BF_SA (with public blob access — intentional violation)"
if az storage account show -n "$BF_SA" -g "$BF_RG" &>/dev/null; then
  warn "Storage account $BF_SA already exists — skipping creation."
else
  run "az storage account create \
    -n '$BF_SA' \
    -g '$BF_RG' \
    -l '$LOCATION' \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_0 \
    --allow-blob-public-access true \
    --public-network-access Enabled \
    -o none"
fi

# ---------------------------------------------------------------------------
# 3. Brownfield VNet + NSG
# ---------------------------------------------------------------------------
log "Creating VNet: $BF_VNET"
if az network vnet show -n "$BF_VNET" -g "$BF_RG" &>/dev/null; then
  warn "VNet $BF_VNET already exists — skipping."
else
  run "az network vnet create \
    -n '$BF_VNET' \
    -g '$BF_RG' \
    -l '$LOCATION' \
    --address-prefix '10.50.0.0/16' \
    --subnet-name 'snet-default' \
    --subnet-prefixes '10.50.1.0/24' \
    -o none"
fi

log "Creating NSG: $BF_NSG"
if az network nsg show -n "$BF_NSG" -g "$BF_RG" &>/dev/null; then
  warn "NSG $BF_NSG already exists — skipping."
else
  run "az network nsg create \
    -n '$BF_NSG' \
    -g '$BF_RG' \
    -l '$LOCATION' \
    -o none"
fi

# ---------------------------------------------------------------------------
# 4. GitHub labels (idempotent)
# ---------------------------------------------------------------------------
log "Ensuring GitHub labels exist..."
for label in "drift:Configuration drift detected:d73a4a" "infra:Infrastructure change:0075ca"; do
  IFS=: read -r name desc color <<< "$label"
  if gh label list --json name -q ".[].name" | grep -qx "$name"; then
    warn "Label '$name' already exists — skipping."
  else
    run "gh label create '$name' --description '$desc' --color '$color'"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n%s${BOLD}Brownfield resources created:%s\n" "" "$RESET"
printf "  Resource group : %s\n" "$BF_RG"
printf "  Storage account: %s (public blob access ON — intentional violation)\n" "$BF_SA"
printf "  VNet           : %s\n" "$BF_VNET"
printf "  NSG            : %s\n" "$BF_NSG"
printf "  GitHub labels  : drift, infra\n"

printf "\n%sNext steps:%s\n" "$BOLD" "$RESET"
printf "  1. Run Terraform init + plan to confirm the platform resources deploy cleanly.\n"
printf "  2. Run ./scripts/create-drift.sh to introduce drift on TF-managed resources.\n"
printf "  3. Run 'gh workflow run drift.yml' to file the drift issue.\n"
printf "  4. Assign the drift issue to @copilot.\n"
printf "  5. Run ./scripts/preflight-check.sh to verify everything is ready.\n"
