#!/usr/bin/env bash
# =============================================================================
# install/04-editors/05-alacritty.sh
#
# Deploys the repo's Alacritty config to Windows under WSL. Alacritty is kept
# as a backup terminal (WezTerm is primary); its config lives host-side at
# %APPDATA%\alacritty\alacritty.toml. No-op off WSL or without Windows interop.
# Idempotent (copies each run).
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_ALACRITTY_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_ALACRITTY_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux

ALACRITTY_CONFIG="$(dirname "${BASH_SOURCE[0]}")/../../alacritty/alacritty.toml"

if ! grep -qi microsoft /proc/version 2>/dev/null || ! command -v cmd.exe >/dev/null 2>&1; then
    ok "Alacritty: not under WSL / no Windows interop; skipping host deploy"
    exit 0
fi

if [[ ! -f "$ALACRITTY_CONFIG" ]]; then
    warn "Alacritty config not found at $ALACRITTY_CONFIG; skipping"
    exit 0
fi

win_appdata="$(wslpath "$(cmd.exe /c 'echo %APPDATA%' 2>/dev/null | tr -d '\r')" 2>/dev/null || true)"
if [[ -n "$win_appdata" && -d "$win_appdata" ]]; then
    info "Deploying Alacritty config to Windows..."
    mkdir -p "$win_appdata/alacritty"
    cp -f "$ALACRITTY_CONFIG" "$win_appdata/alacritty/alacritty.toml"
    ok "Alacritty config deployed to $win_appdata/alacritty/alacritty.toml"
else
    warn "Could not resolve Windows APPDATA; skipping Alacritty deploy"
fi
