#!/usr/bin/env bash
# =============================================================================
# install/04-editors/04-wezterm.sh
#
# Deploys the repo's WezTerm config to Windows under WSL. WezTerm runs
# host-side, so the config is copied to %USERPROFILE%\.config\wezterm. No-op
# off WSL or without Windows interop. Idempotent (copies each run).
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_WEZTERM_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_WEZTERM_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux

WEZTERM_CONFIG="$(dirname "${BASH_SOURCE[0]}")/../../wezterm/wezterm.lua"

if ! grep -qi microsoft /proc/version 2>/dev/null || ! command -v cmd.exe >/dev/null 2>&1; then
    ok "WezTerm: not under WSL / no Windows interop; skipping host deploy"
    exit 0
fi

if [[ ! -f "$WEZTERM_CONFIG" ]]; then
    warn "WezTerm config not found at $WEZTERM_CONFIG; skipping"
    exit 0
fi

win_home="$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null || true)"
if [[ -n "$win_home" && -d "$win_home" ]]; then
    info "Deploying WezTerm config to Windows..."
    mkdir -p "$win_home/.config/wezterm"
    cp -f "$WEZTERM_CONFIG" "$win_home/.config/wezterm/wezterm.lua"
    ok "WezTerm config deployed to $win_home/.config/wezterm/wezterm.lua"
else
    warn "Could not resolve Windows home; skipping WezTerm deploy"
fi
