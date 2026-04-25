#!/usr/bin/env bash
# =============================================================================
# scripts/install-hooks.sh — Gitleaks Pre-Commit Hook Installer
# Part of: basecoat Enterprise Governance Framework (Issue #43)
#
# PURPOSE:
#   This script installs gitleaks as a pre-commit hook in the local git repo.
#   It is THE REAL ENFORCEMENT GATE — it blocks commits at the developer's
#   machine before any secret ever reaches the remote.
#
#   The CI workflow (secret-scan.yml) is warn-only. This hook is the blocker.
#
# USAGE:
#   bash scripts/install-hooks.sh            # install in current git repo
#   bash scripts/install-hooks.sh /path/to/repo
#
# PLATFORMS:
#   - macOS (amd64 / arm64 via Homebrew or direct download)
#   - Linux  (amd64 / arm64 via direct download)
#   - Windows: use WSL2, Git Bash, or see PowerShell note below.
#
# WINDOWS (Git Bash / WSL2):
#   Run this script from Git Bash or WSL2. The installed hook will work
#   correctly in both environments as long as gitleaks is on PATH.
#   Native PowerShell users: see scripts/install-git-hooks.ps1 for the
#   existing hooks setup, and install gitleaks via:
#     winget install gitleaks  OR  scoop install gitleaks
#   Then add a pre-commit hook manually (see MANUAL HOOK section below).
#
# REQUIREMENTS:
#   - git
#   - curl (for auto-install)
#   - gitleaks (auto-installed if not present)
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
GITLEAKS_VERSION="${GITLEAKS_VERSION:-8.18.4}"   # override via env var
HOOKS_DIR=""
HOOK_FILE=""
ROOT_DIR="${1:-$(pwd)}"
HOOK_STRATEGY="${HOOK_STRATEGY:-hooks_path}"     # "hooks_path" or "pre_commit_file"

# Colours (disabled if not a TTY)
if [ -t 1 ]; then
  RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
else
  RED=''; YELLOW=''; GREEN=''; CYAN=''; BOLD=''; RESET=''
fi

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

check_git() {
  command -v git >/dev/null 2>&1 || die "git is required but not found on PATH."
}

detect_git_root() {
  cd "$ROOT_DIR"
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) \
    || die "Not inside a git repository: $ROOT_DIR"
  info "Git root: $GIT_ROOT"
}

detect_os_arch() {
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)           ARCH="x64"  ;;
    aarch64|arm64)    ARCH="arm64";;
    *)  die "Unsupported architecture: $ARCH" ;;
  esac
  case "$OS" in
    linux)  GITLEAKS_OS="linux"  ;;
    darwin) GITLEAKS_OS="darwin" ;;
    msys*|cygwin*|mingw*)
      GITLEAKS_OS="windows"
      ARCH="x64"
      ;;
    *)  die "Unsupported OS: $OS" ;;
  esac
  info "Detected OS/Arch: ${GITLEAKS_OS}/${ARCH}"
}

install_gitleaks() {
  if command -v gitleaks >/dev/null 2>&1; then
    INSTALLED_VER=$(gitleaks version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
    success "gitleaks already installed (version: ${INSTALLED_VER})"
    return 0
  fi

  info "gitleaks not found — attempting automatic install (v${GITLEAKS_VERSION})..."

  # Attempt Homebrew on macOS first
  if [[ "$GITLEAKS_OS" == "darwin" ]] && command -v brew >/dev/null 2>&1; then
    info "Installing via Homebrew..."
    brew install gitleaks
    success "gitleaks installed via Homebrew."
    return 0
  fi

  # Direct download for Linux / Git Bash
  detect_os_arch
  local EXT="tar.gz"
  local FILENAME="gitleaks_${GITLEAKS_VERSION}_${GITLEAKS_OS}_${ARCH}.${EXT}"
  local URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/${FILENAME}"
  local TMP_DIR
  TMP_DIR=$(mktemp -d)

  info "Downloading: $URL"
  curl -sSfL "$URL" -o "${TMP_DIR}/${FILENAME}" \
    || die "Failed to download gitleaks. Check your internet connection or install manually: https://github.com/gitleaks/gitleaks#installing"

  info "Extracting..."
  tar -xzf "${TMP_DIR}/${FILENAME}" -C "$TMP_DIR"

  local INSTALL_DIR="/usr/local/bin"
  if [[ ! -w "$INSTALL_DIR" ]]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    warn "No write access to /usr/local/bin — installing to $INSTALL_DIR"
    warn "Ensure $INSTALL_DIR is on your PATH."
  fi

  mv "${TMP_DIR}/gitleaks" "${INSTALL_DIR}/gitleaks"
  chmod +x "${INSTALL_DIR}/gitleaks"
  rm -rf "$TMP_DIR"

  success "gitleaks v${GITLEAKS_VERSION} installed to ${INSTALL_DIR}/gitleaks"
}

# ---------------------------------------------------------------------------
# Hook installation strategies
#
# Strategy A (default — "hooks_path"):
#   Set core.hooksPath to .githooks/ so ALL hooks in that directory are used.
#   Adds pre-commit to .githooks/. Integrates with the existing commit-msg hook.
#
# Strategy B ("pre_commit_file"):
#   Write the hook directly to .git/hooks/pre-commit.
#   Use when you cannot modify core.hooksPath (e.g. repo already has one set).
# ---------------------------------------------------------------------------

write_hook_script() {
  local HOOK_PATH="$1"
  cat > "$HOOK_PATH" << 'HOOK_EOF'
#!/usr/bin/env bash
# =============================================================================
# pre-commit hook — gitleaks secret scan
# Installed by: scripts/install-hooks.sh (basecoat Issue #43)
#
# This hook scans STAGED changes for secrets before every commit.
# To bypass in an emergency: git commit --no-verify  (use sparingly!)
# =============================================================================

set -euo pipefail

# Find config file — prefer repo root, fall back to no config (uses built-ins)
REPO_ROOT=$(git rev-parse --show-toplevel)
CONFIG_ARG=""
if [[ -f "${REPO_ROOT}/.gitleaks.toml" ]]; then
  CONFIG_ARG="--config ${REPO_ROOT}/.gitleaks.toml"
fi

if ! command -v gitleaks >/dev/null 2>&1; then
  echo ""
  echo "⚠️  WARNING: gitleaks not found on PATH — secret scan skipped!"
  echo "   Install it: bash scripts/install-hooks.sh"
  echo ""
  exit 0   # Soft fail — don't block commit if tool is missing
fi

echo "🔐 Running gitleaks secret scan on staged changes..."

# scan staged content (protect mode scans what is staged)
set +e
gitleaks protect \
  ${CONFIG_ARG} \
  --staged \
  --no-banner \
  --redact \
  --exit-code 1
LEAK_EXIT=$?
set -e

if [[ $LEAK_EXIT -ne 0 ]]; then
  echo ""
  echo "❌ COMMIT BLOCKED — gitleaks detected a potential secret in staged changes."
  echo ""
  echo "   Fix options:"
  echo "   1. Remove the secret from the file and unstage it."
  echo "   2. If it's a false positive, add an allowlist entry to .gitleaks.toml"
  echo "      and re-stage that file."
  echo "   3. EMERGENCY BYPASS (use sparingly): git commit --no-verify"
  echo ""
  echo "   See: docs/security/SECRET_SCANNING.md"
  echo ""
  exit 1
fi

echo "✅ gitleaks — no secrets detected in staged changes."
exit 0
HOOK_EOF
  chmod +x "$HOOK_PATH"
}

install_via_hooks_path() {
  HOOKS_DIR="${GIT_ROOT}/.githooks"
  mkdir -p "$HOOKS_DIR"

  HOOK_FILE="${HOOKS_DIR}/pre-commit"
  write_hook_script "$HOOK_FILE"

  # Configure git to use .githooks/ directory
  git -C "$GIT_ROOT" config core.hooksPath .githooks
  success "core.hooksPath set to .githooks/"
  success "pre-commit hook written to ${HOOK_FILE}"
}

install_via_pre_commit_file() {
  HOOKS_DIR="${GIT_ROOT}/.git/hooks"
  mkdir -p "$HOOKS_DIR"

  HOOK_FILE="${HOOKS_DIR}/pre-commit"

  if [[ -f "$HOOK_FILE" ]]; then
    warn "Existing .git/hooks/pre-commit found — backing up to ${HOOK_FILE}.bak"
    cp "$HOOK_FILE" "${HOOK_FILE}.bak"
  fi

  write_hook_script "$HOOK_FILE"
  success "pre-commit hook written to ${HOOK_FILE}"
}

# ---------------------------------------------------------------------------
# Verify installation
# ---------------------------------------------------------------------------
verify() {
  info "Verifying hook installation..."

  if ! command -v gitleaks >/dev/null 2>&1; then
    warn "gitleaks not found on PATH — hook is installed but will soft-fail."
    warn "Re-run this script after installing gitleaks."
    return
  fi

  # Quick smoke test: scan the HEAD commit
  set +e
  gitleaks detect \
    --config "${GIT_ROOT}/.gitleaks.toml" \
    --source "$GIT_ROOT" \
    --log-opts "HEAD~1..HEAD" \
    --no-banner \
    --redact \
    --exit-code 1 \
    >/dev/null 2>&1
  VERIFY_EXIT=$?
  set -e

  if [[ $VERIFY_EXIT -eq 0 ]]; then
    success "Verification scan passed — no secrets in last commit."
  else
    warn "Verification scan found potential findings in last commit."
    warn "Run: gitleaks detect --config .gitleaks.toml --log-opts HEAD~1..HEAD"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo ""
  echo -e "${BOLD}🔐 basecoat — gitleaks pre-commit hook installer${RESET}"
  echo "   Issue #43 · Enterprise Governance Framework"
  echo ""

  check_git
  detect_git_root
  install_gitleaks

  case "$HOOK_STRATEGY" in
    hooks_path)
      install_via_hooks_path
      ;;
    pre_commit_file)
      install_via_pre_commit_file
      ;;
    *)
      die "Unknown HOOK_STRATEGY: $HOOK_STRATEGY. Use 'hooks_path' or 'pre_commit_file'."
      ;;
  esac

  verify

  echo ""
  echo -e "${GREEN}${BOLD}Installation complete!${RESET}"
  echo ""
  echo "  Every git commit will now be scanned for secrets."
  echo "  To bypass in an emergency: git commit --no-verify"
  echo "  Docs: docs/security/SECRET_SCANNING.md"
  echo ""
}

main "$@"
