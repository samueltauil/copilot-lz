#!/usr/bin/env bash
# reset-demo.sh — reset the repo + GitHub state between rehearsals.
#
# Runs on macOS (bash 3.2+) and Linux (tested on Fedora 43, bash 5.x).
# Dependencies: git, gh (authenticated). No external jq required
# (uses `gh --jq` which is built in).
#
# After a rehearsal, imports.tf has been populated by the agent, a demo
# branch + PR exists, a drift issue is filed, and the coding agent may have
# opened a remediation PR. This script puts everything back to a clean
# pre-demo state so you can run the demo again.
#
# What this script DOES:
#   1. Resets the local working tree to origin/main (discarding local edits)
#   2. Restores imports.tf to its empty template
#   3. Deletes local rehearsal branches (demo/*, copilot/*)
#   4. On GitHub: closes demo PRs, closes drift issues, deletes demo branches
#
# What this script does NOT do:
#   - Touch Azure resources (brownfield RG, TF-managed RG, state)
#     Those are re-used across rehearsals. To recreate the brownfield
#     violation, re-run the commands in scripts/install-deps.sh checklist.
#
# Usage:
#   ./scripts/reset-demo.sh            # interactive confirm
#   ./scripts/reset-demo.sh --yes      # no prompt
#   ./scripts/reset-demo.sh --dry-run  # show what would happen

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
      sed -n '2,26p' "$0"; exit 0 ;;
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

# --- Preflight -------------------------------------------------------------

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -z "$REPO_ROOT" ]] && fail "Not inside a git repository."
cd "$REPO_ROOT"

command -v gh >/dev/null 2>&1 || fail "gh CLI is required."
gh auth status >/dev/null 2>&1 || fail "gh is not authenticated. Run: gh auth login"

DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null || echo main)"

log "Repo: $(gh repo view --json nameWithOwner --jq .nameWithOwner)"
log "Default branch: $DEFAULT_BRANCH"
log "Mode: $( ((DRY_RUN)) && echo DRY-RUN || echo EXECUTE )"

# --- Confirm ---------------------------------------------------------------

if (( ! DRY_RUN )) && (( ! ASSUME_YES )); then
  printf "\n%sThis will discard local changes and close demo PRs/issues on GitHub.%s\n" "$BOLD" "$RESET"
  read -r -p "Continue? [y/N] " ans
# Lowercase comparison without bash-4 ${var,,} (macOS bash 3.2 friendly)
  ans_lc="$(printf '%s' "${ans:-}" | tr '[:upper:]' '[:lower:]')"
  [[ "$ans_lc" == "y" || "$ans_lc" == "yes" ]] || { log "Aborted."; exit 0; }
fi

echo

# --- 1. Reset local working tree ------------------------------------------

log "Fetching origin…"
run "git fetch origin --prune --quiet"

log "Switching to $DEFAULT_BRANCH and hard-resetting to origin/$DEFAULT_BRANCH"
run "git checkout $DEFAULT_BRANCH --quiet"
run "git reset --hard origin/$DEFAULT_BRANCH --quiet"
run "git clean -fd --quiet"

# --- 2. Restore imports.tf template (idempotent) --------------------------

IMPORTS_TEMPLATE='# imports.tf
#
# This file is intentionally empty at the start of the demo.
# During Act 1, Copilot (agent mode) will read `az` output for the
# brownfield resource group and populate this file with `import {}`
# blocks plus the matching `resource {}` definitions.
#
# Expected shape after agent runs:
#
#   import {
#     to = azurerm_resource_group.brownfield
#     id = "/subscriptions/<sub>/resourceGroups/rg-brownfield-demo"
#   }
#
#   resource "azurerm_resource_group" "brownfield" { ... }
'

if ! diff -q <(printf "%s" "$IMPORTS_TEMPLATE") imports.tf >/dev/null 2>&1; then
  log "Restoring imports.tf to empty template"
  if (( DRY_RUN )); then
    printf "  %s[dry-run]%s would overwrite imports.tf\n" "$YELLOW" "$RESET"
  else
    printf "%s" "$IMPORTS_TEMPLATE" > imports.tf
    if ! git diff --quiet imports.tf; then
      git add imports.tf
      git commit -m "chore: reset imports.tf to pre-demo template" --quiet
      git push origin "$DEFAULT_BRANCH" --quiet
    fi
  fi
else
  log "imports.tf already matches template — skipping"
fi

# --- 3. Delete local demo branches ----------------------------------------

LOCAL_DEMO_BRANCHES="$(git branch --list 'demo/*' 'copilot/*' 'drift/*' | sed 's/^[* ] *//' | grep -v "^$DEFAULT_BRANCH$" || true)"
if [[ -n "$LOCAL_DEMO_BRANCHES" ]]; then
  while IFS= read -r b; do
    log "Deleting local branch: $b"
    run "git branch -D '$b' >/dev/null"
  done <<<"$LOCAL_DEMO_BRANCHES"
else
  log "No local demo branches to delete"
fi

# --- 4. Close demo PRs on GitHub ------------------------------------------

log "Searching for open demo PRs (head matches demo/*, copilot/*, drift/*)…"
PR_LIST="$(gh pr list --state open --limit 100 \
  --json number,headRefName,title \
  --jq '.[] | select(.headRefName | test("^(demo/|copilot/|drift/)")) | "\(.number)\t\(.headRefName)\t\(.title)"')"

if [[ -n "$PR_LIST" ]]; then
  while IFS=$'\t' read -r num head title; do
    [[ -z "$num" ]] && continue
    log "Closing PR #$num ($head): $title"
    # --delete-branch may fail if the branch is already gone; don't abort.
    run "gh pr close '$num' --delete-branch --comment 'Closing: rehearsal reset.' >/dev/null 2>&1 || \
         gh pr close '$num' --comment 'Closing: rehearsal reset.' >/dev/null"
  done <<<"$PR_LIST"
else
  log "No open demo PRs"
fi

# --- 5. Close drift issues ------------------------------------------------

log "Searching for open drift issues (label=drift)…"
ISSUE_LIST="$(gh issue list --state open --label drift --limit 100 \
  --json number,title --jq '.[] | "\(.number)\t\(.title)"')"

if [[ -n "$ISSUE_LIST" ]]; then
  while IFS=$'\t' read -r num title; do
    [[ -z "$num" ]] && continue
    log "Closing issue #$num: $title"
    run "gh issue close '$num' --comment 'Closing: rehearsal reset.' >/dev/null"
  done <<<"$ISSUE_LIST"
else
  log "No open drift issues"
fi

# --- 6. Delete orphaned remote demo branches -----------------------------

log "Checking for orphaned remote demo branches…"
REMOTE_DEMO="$(git branch -r --list 'origin/demo/*' 'origin/copilot/*' 'origin/drift/*' \
  | sed 's|^ *origin/||' | grep -v '^$' || true)"
if [[ -n "$REMOTE_DEMO" ]]; then
  while IFS= read -r b; do
    [[ -z "$b" ]] && continue
    log "Deleting remote branch: $b"
    run "git push origin --delete '$b' >/dev/null 2>&1 || true"
  done <<<"$REMOTE_DEMO"
else
  log "No orphaned remote demo branches"
fi

# --- Done -----------------------------------------------------------------

echo
log "${BOLD}Reset complete.${RESET}"
echo
cat <<EOF
Next steps before rehearsing again:
  1. Confirm Azure brownfield + TF-managed RGs still exist (this script does
     NOT touch Azure).
  2. Re-introduce drift on the TF-managed storage account (portal flip).
  3. Fire drift.yml:         gh workflow run drift.yml
  4. Assign new issue:       gh issue edit <n> --add-assignee copilot
  5. Verify clean baseline:  terraform fmt -check -recursive && terraform validate
EOF
