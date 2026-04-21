#!/usr/bin/env bash
# =============================================================================
# install/01-system/01-packages.sh
#
# Baseline apt packages that every other install step depends on.
# Also registers pipx's PATH and creates Ubuntu fd/bat symlinks.
#
# Idempotent — apt-get install is idempotent; symlink/ensurepath steps
# are guarded.
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_PACKAGES_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_PACKAGES_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo
require_command apt-get

# ---------------------------------------------------------------------------
# Baseline apt packages
# ---------------------------------------------------------------------------
info "Ensuring system packages are installed..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
    zsh git curl wget stow tmux \
    fd-find bat ripgrep zoxide \
    python3 pipx \
    build-essential cmake \
    unzip fontconfig \
    sqlite3 \
    jq \
    uuid-dev libgnutls28-dev \
    ca-certificates libssl-dev zlib1g-dev

# ---------------------------------------------------------------------------
# Ubuntu renaming quirks: fd → fdfind, bat → batcat
# ---------------------------------------------------------------------------
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
fi

if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"
fi

# ---------------------------------------------------------------------------
# Register pipx PATH for user shells (~/.local/bin). No-op if already
# registered.
# ---------------------------------------------------------------------------
pipx ensurepath 2>/dev/null || true

ok "System packages"
