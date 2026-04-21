#!/usr/bin/env bash
# =============================================================================
# install/05-tools/01-fzf.sh
#
# Installs fzf from git (apt version is too old for the OMZ fzf plugin).
# Clones to $HOME/.fzf and runs the upstream installer to populate
# $HOME/.fzf/bin.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_FZF_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_FZF_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command git

if [[ ! -d "$HOME/.fzf" ]]; then
    info "Installing fzf from git..."
    git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --bin --no-bash --no-fish --no-update-rc
    ok "fzf installed: $("$HOME/.fzf/bin/fzf" --version)"
elif [[ -d "$HOME/.fzf/.git" ]]; then
    info "Updating fzf..."
    git -C "$HOME/.fzf" pull --ff-only 2>/dev/null && "$HOME/.fzf/install" --bin --no-bash --no-fish --no-update-rc 2>/dev/null || true
    ok "fzf: $("$HOME/.fzf/bin/fzf" --version)"
fi
