#!/usr/bin/env bash
# =============================================================================
# install/05-tools/20-tdf.sh
#
# Installs tdf, a terminal PDF viewer (renders via the sixel/kitty graphics
# protocol). Used for in-terminal vimtex preview. Built from git — the `tdf`
# name on crates.io is an unrelated library. Needs clang (04-cpp-toolchain)
# and libfontconfig1-dev (01-packages), both installed by earlier steps.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_TDF_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_TDF_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command cargo

if command -v tdf >/dev/null 2>&1; then
    ok "tdf already installed"
    exit 0
fi

info "Installing tdf (terminal PDF viewer)..."
cargo install --git https://github.com/itsjunetime/tdf.git --quiet 2>/dev/null \
    && ok "tdf installed" \
    || warn "tdf install failed (needs clang + libfontconfig1-dev; non-fatal)"
