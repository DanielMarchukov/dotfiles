#!/usr/bin/env bash
# =============================================================================
# install/06-shell/01-default-shell.sh
#
# Switches the user's default shell to zsh. Requires zsh from
# 01-system/01-packages.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_DEFAULT_SHELL_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_DEFAULT_SHELL_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command zsh

if [[ "$SHELL" != *"zsh"* ]]; then
    info "Changing default shell to zsh..."
    chsh -s "$(command -v zsh)" || warn "Could not change shell (run: chsh -s $(command -v zsh))"
else
    ok "Default shell is already zsh"
fi
