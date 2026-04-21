#!/usr/bin/env bash
# =============================================================================
# install/03-dotfiles/03-p10k.sh
#
# Clones Powerlevel10k into the oh-my-zsh custom themes directory.
# Depends on 03-dotfiles/02-runtime-deps.sh having populated
# $HOME/.oh-my-zsh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_P10K_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_P10K_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command git

OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
P10K_DIR="$OH_MY_ZSH_DIR/custom/themes/powerlevel10k"

if [[ ! -d "$OH_MY_ZSH_DIR" ]]; then
    err "$OH_MY_ZSH_DIR missing — run 03-dotfiles/02-runtime-deps.sh first"
    exit 1
fi

if [[ ! -d "$P10K_DIR" ]]; then
    info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    ok "Powerlevel10k installed"
else
    ok "Powerlevel10k already installed"
fi
