#!/usr/bin/env bash
# =============================================================================
# install/06-shell/02-nerd-font.sh
#
# Installs the MesloLGS Nerd Font variants used by Powerlevel10k icons.
# Downloads to ~/.local/share/fonts and refreshes fc-cache.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_NERD_FONT_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_NERD_FONT_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command curl
require_command fc-cache

FONT_DIR="$HOME/.local/share/fonts"
if ! fc-list 2>/dev/null | grep -qi "MesloLGS"; then
    info "Installing MesloLGS Nerd Font..."
    mkdir -p "$FONT_DIR"
    FONT_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
    for variant in "Regular" "Bold" "Italic" "Bold%20Italic"; do
        name="${variant//%20/ }"
        curl -fsSL -o "$FONT_DIR/MesloLGS NF ${name}.ttf" \
            "${FONT_BASE}/MesloLGS%20NF%20${variant}.ttf"
    done
    fc-cache -f "$FONT_DIR"
    ok "MesloLGS Nerd Font installed"
else
    ok "MesloLGS Nerd Font already installed"
fi
