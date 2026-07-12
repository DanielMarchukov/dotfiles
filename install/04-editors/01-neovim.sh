#!/usr/bin/env bash
# =============================================================================
# install/04-editors/01-neovim.sh
#
# Installs or upgrades Neovim to the latest stable release by delegating to
# the repo-root install-nvim.sh (idempotent, arch-aware, install-or-upgrade).
# Plugin sync happens in 04-editors/03-neovim-plugins.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_NEOVIM_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_NEOVIM_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo
require_command curl
require_command jq

NVIM_INSTALLER="$(dirname "${BASH_SOURCE[0]}")/../../install-nvim.sh"
if [[ -x "$NVIM_INSTALLER" ]]; then
    "$NVIM_INSTALLER"
else
    err "install-nvim.sh not found or not executable at $NVIM_INSTALLER"
    exit 1
fi
