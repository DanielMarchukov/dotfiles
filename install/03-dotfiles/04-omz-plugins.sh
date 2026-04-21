#!/usr/bin/env bash
# =============================================================================
# install/03-dotfiles/04-omz-plugins.sh
#
# Clones oh-my-zsh custom plugins into ~/.oh-my-zsh/custom/plugins/.
# Depends on 03-dotfiles/02-runtime-deps.sh having populated
# $HOME/.oh-my-zsh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_OMZ_PLUGINS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_OMZ_PLUGINS_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command git

OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="$OH_MY_ZSH_DIR/custom"

if [[ ! -d "$OH_MY_ZSH_DIR" ]]; then
    err "$OH_MY_ZSH_DIR missing — run 03-dotfiles/02-runtime-deps.sh first"
    exit 1
fi

declare -A PLUGINS=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions.git"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    [fzf-z]="https://github.com/andrewferrier/fzf-z.git"
    [you-should-use]="https://github.com/MichaelAquilina/zsh-you-should-use.git"
    [zsh-bat]="https://github.com/fdellwing/zsh-bat.git"
)

for plugin in "${!PLUGINS[@]}"; do
    dest="$ZSH_CUSTOM/plugins/$plugin"
    if [[ ! -d "$dest" ]]; then
        info "Installing zsh plugin: $plugin"
        git clone --depth=1 "${PLUGINS[$plugin]}" "$dest"
    else
        ok "zsh plugin: $plugin"
    fi
done
