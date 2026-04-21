#!/usr/bin/env bash
# install-deps.sh — install tooling for the Copilot + Terraform demo.
#
# Supported:
#   - macOS (Homebrew)
#   - Fedora Linux, incl. WSL on Windows (dnf)
#
# Idempotent: skips anything already on PATH.

set -euo pipefail

RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'

log()  { printf "%s==>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn() { printf "%s!!%s %s\n"  "$YELLOW" "$RESET" "$*"; }
fail() { printf "%sxx%s %s\n"  "$RED" "$RESET" "$*" >&2; exit 1; }

FAILED=()

# --- OS detection ----------------------------------------------------------

OS="unknown"
if [[ "$(uname)" == "Darwin" ]]; then
  OS="macos"
elif [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  case ":${ID:-}:${ID_LIKE:-}:" in
    *:fedora:*|*fedora*) OS="fedora" ;;
    *:rhel:*|*:centos:*|*rhel*|*centos*) OS="fedora" ;;
  esac
fi

[[ "$OS" == "unknown" ]] && fail "Unsupported OS. Supported: macOS, Fedora/RHEL (incl. WSL)."
log "Detected OS: $OS"

# --- Privilege helper ------------------------------------------------------

SUDO=""
if [[ "$OS" == "fedora" ]] && [[ $EUID -ne 0 ]]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    fail "sudo not available and not running as root."
  fi
fi

# ===========================================================================
# macOS
# ===========================================================================

install_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    fail "Homebrew is required. Install from https://brew.sh then re-run."
  fi
  log "Homebrew: $(brew --version | head -n1)"

  # name|brew-spec|version-command
  local TOOLS=(
    "terraform|hashicorp/tap/terraform|terraform version"
    "tflint|tflint|tflint --version"
    "az|azure-cli|az version --output tsv"
    "gh|gh|gh --version"
    "checkov|checkov|checkov --version"
    "jq|jq|jq --version"
  )

  for entry in "${TOOLS[@]}"; do
    IFS='|' read -r bin spec vercmd <<<"$entry"
    if command -v "$bin" >/dev/null 2>&1; then
      log "$bin already installed: $(eval "$vercmd" 2>&1 | head -n1)"
      continue
    fi
    log "Installing $bin (brew install $spec)…"
    if brew install "$spec"; then
      log "$bin installed."
    else
      warn "brew install $spec failed."
      FAILED+=("$bin")
    fi
  done
}

# ===========================================================================
# Fedora / WSL Fedora
# ===========================================================================

add_repo_from_url() {
  # add_repo_from_url <url> <marker-file-in-/etc/yum.repos.d>
  local url="$1" marker="$2"
  [[ -f "/etc/yum.repos.d/$marker" ]] && return 0
  # dnf5 (Fedora 41+) uses `config-manager addrepo --from-repofile=`.
  # dnf4 uses `config-manager --add-repo`. Try new, then old.
  $SUDO dnf config-manager addrepo --from-repofile="$url" >/dev/null 2>&1 && return 0
  $SUDO dnf config-manager --add-repo "$url" >/dev/null 2>&1 && return 0
  warn "Could not add repo: $url"
  return 1
}

add_repo_hashicorp() {
  add_repo_from_url "https://rpm.releases.hashicorp.com/fedora/hashicorp.repo" "hashicorp.repo"
}

add_repo_gh() {
  add_repo_from_url "https://cli.github.com/packages/rpm/gh-cli.repo" "gh-cli.repo"
}

add_repo_azurecli() {
  [[ -f /etc/yum.repos.d/azure-cli.repo ]] && return 0
  log "Adding Microsoft Azure CLI dnf repo…"
  $SUDO rpm --import https://packages.microsoft.com/keys/microsoft.asc
  $SUDO tee /etc/yum.repos.d/azure-cli.repo >/dev/null <<'EOF'
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
}

install_tflint_binary() {
  if command -v tflint >/dev/null 2>&1; then
    log "tflint already installed: $(tflint --version 2>&1 | head -n1)"
    return 0
  fi
  log "Installing tflint (upstream installer)…"
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh -o "$tmp/install.sh"; then
    if TFLINT_INSTALL_PATH="/usr/local/bin" $SUDO bash "$tmp/install.sh" >/dev/null 2>&1 \
       || $SUDO bash "$tmp/install.sh" >/dev/null 2>&1; then
      log "tflint installed: $(tflint --version 2>&1 | head -n1)"
    else
      warn "tflint installer failed."
      FAILED+=("tflint")
    fi
  else
    warn "Could not download tflint installer."
    FAILED+=("tflint")
  fi
  rm -rf "$tmp"
}

install_checkov_pipx() {
  if command -v checkov >/dev/null 2>&1; then
    log "checkov already installed: $(checkov --version 2>&1 | head -n1)"
    return 0
  fi
  log "Installing checkov via pipx…"
  if ! command -v pipx >/dev/null 2>&1; then
    if ! $SUDO dnf -y install pipx >/dev/null 2>&1; then
      warn "Failed to install pipx."
      FAILED+=("checkov")
      return
    fi
    pipx ensurepath >/dev/null 2>&1 || true
  fi
  if pipx install checkov >/dev/null 2>&1; then
    log "checkov installed. Open a new shell if ~/.local/bin is not on PATH."
  else
    warn "pipx install checkov failed."
    FAILED+=("checkov")
  fi
}

install_fedora() {
  log "Refreshing dnf metadata (may take a moment)…"
  $SUDO dnf -y makecache >/dev/null 2>&1 || true

  log "Ensuring dnf-plugins-core is present…"
  $SUDO dnf -y install dnf-plugins-core >/dev/null 2>&1 || \
    warn "Could not install dnf-plugins-core (may already be present)."

  local BASE_PKGS=(curl jq git unzip ca-certificates)
  log "Installing base packages: ${BASE_PKGS[*]}"
  $SUDO dnf -y install "${BASE_PKGS[@]}" >/dev/null 2>&1 || \
    warn "Some base packages failed to install."

  # terraform
  if ! command -v terraform >/dev/null 2>&1; then
    add_repo_hashicorp && \
      { log "Installing terraform…"; $SUDO dnf -y install terraform \
          || { warn "dnf install terraform failed."; FAILED+=("terraform"); }; } \
      || FAILED+=("terraform")
  else
    log "terraform already installed: $(terraform version | head -n1)"
  fi

  # azure-cli
  if ! command -v az >/dev/null 2>&1; then
    add_repo_azurecli
    log "Installing azure-cli…"
    $SUDO dnf -y install azure-cli || { warn "dnf install azure-cli failed."; FAILED+=("az"); }
  else
    log "az already installed."
  fi

  # gh
  if ! command -v gh >/dev/null 2>&1; then
    add_repo_gh && \
      { log "Installing gh…"; $SUDO dnf -y install gh \
          || { warn "dnf install gh failed."; FAILED+=("gh"); }; } \
      || FAILED+=("gh")
  else
    log "gh already installed: $(gh --version | head -n1)"
  fi

  install_tflint_binary
  install_checkov_pipx
}

# ===========================================================================
# Dispatch
# ===========================================================================

case "$OS" in
  macos)  install_macos ;;
  fedora) install_fedora ;;
esac

# --- Summary ---------------------------------------------------------------

echo
printf "%s== summary ==%s\n" "$BOLD" "$RESET"
SUMMARY_TOOLS=(
  "terraform|terraform version"
  "tflint|tflint --version"
  "az|az version --output tsv"
  "gh|gh --version"
  "checkov|checkov --version"
  "jq|jq --version"
)
for entry in "${SUMMARY_TOOLS[@]}"; do
  IFS='|' read -r bin vercmd <<<"$entry"
  if command -v "$bin" >/dev/null 2>&1; then
    printf "  %s✓%s %-10s %s\n" "$GREEN" "$RESET" "$bin" "$(eval "$vercmd" 2>&1 | head -n1)"
  else
    printf "  %s✗%s %-10s NOT INSTALLED\n" "$RED" "$RESET" "$bin"
  fi
done

if (( ${#FAILED[@]} > 0 )); then
  warn "Failed: ${FAILED[*]}"
  exit 1
fi

log "All dependencies installed."
