#!/usr/bin/env bash
# =============================================================================
# install/03-dotfiles/01-repo.sh
#
# Syncs the .config submodule (and its nested nvim submodule) for the
# dotfiles repo. The initial clone of the dotfiles repo itself stays in
# bootstrap.sh because install/ does not exist until after clone.
#
# Idempotent — `git submodule update --init` skips already-initialized
# submodules.
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_REPO_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_REPO_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command git

# Resolve the dotfiles repo root (two levels up from this script)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    err "Expected a git repo at $DOTFILES_DIR (dotfiles root)"
    exit 1
fi

info "Syncing submodules..."
git -C "$DOTFILES_DIR" submodule update --init .config

# Init nvim inside .config submodule
if [[ -f "$DOTFILES_DIR/.config/.gitmodules" ]]; then
    git -C "$DOTFILES_DIR/.config" submodule update --init nvim 2>/dev/null || true
fi

ok "Dotfiles repo ready"
