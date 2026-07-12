#!/usr/bin/env bash
# =============================================================================
# install/06-shell/02-nerd-font.sh
#
# Installs the 0xProto Nerd Font (terminal + Neovim glyphs and Powerlevel10k
# icons) into ~/.local/share/fonts. Under WSL the interactive terminal renders
# host-side, so it also installs the font on Windows (per-user, no admin) via
# Windows interop.
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
require_command unzip

NERD_FONTS_VERSION="v3.4.0"
FONT_DIR="$HOME/.local/share/fonts"

# ---------------------------------------------------------------------------
# Linux side (fontconfig / WSLg)
# ---------------------------------------------------------------------------
if ! fc-list 2>/dev/null | grep -qi "0xProto"; then
    info "Installing 0xProto Nerd Font..."
    mkdir -p "$FONT_DIR"
    font_tmp="$(mktemp -d)"
    curl -fsSL -o "$font_tmp/0xProto.zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/0xProto.zip"
    unzip -qo "$font_tmp/0xProto.zip" '*.ttf' -d "$FONT_DIR"
    rm -rf "$font_tmp"
    fc-cache -f "$FONT_DIR"
    ok "0xProto Nerd Font installed"
else
    ok "0xProto Nerd Font already installed"
fi

# ---------------------------------------------------------------------------
# Windows side (per-user, under WSL): copy the .ttf into the per-user Fonts
# dir and register them under HKCU. Idempotent; requires Windows interop.
# ---------------------------------------------------------------------------
if grep -qi microsoft /proc/version 2>/dev/null && command -v reg.exe >/dev/null 2>&1; then
    win_localappdata="$(cmd.exe /c 'echo %LOCALAPPDATA%' 2>/dev/null | tr -d '\r')"
    win_fonts_wsl="$([[ -n "$win_localappdata" ]] && wslpath "$win_localappdata" 2>/dev/null)/Microsoft/Windows/Fonts"
    reg_key='HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    if [[ -n "$win_localappdata" ]] && ! reg.exe query "$reg_key" 2>/dev/null | grep -qi '0xProto'; then
        info "Installing 0xProto Nerd Font on Windows (per-user)..."
        mkdir -p "$win_fonts_wsl"
        for f in "$FONT_DIR"/0xProto*.ttf; do
            [[ -e "$f" ]] || continue
            base="$(basename "$f")"
            cp -f "$f" "$win_fonts_wsl/$base"
            reg_name="$(printf '%s' "$base" | sed -E 's/\.ttf$//; s/0xProtoNerdFont/0xProto Nerd Font/; s/Mono/ Mono/; s/Propo/ Propo/; s/-/ /') (TrueType)"
            reg.exe add "$reg_key" /v "$reg_name" /t REG_SZ \
                /d "$(wslpath -w "$win_fonts_wsl/$base")" /f >/dev/null 2>&1 || true
        done
        ok "0xProto Nerd Font installed on Windows (restart your terminal to use it)"
    else
        ok "0xProto Nerd Font already present on Windows (or interop unavailable)"
    fi
fi
