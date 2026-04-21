#!/usr/bin/env bash
# =============================================================================
# install/05-tools/03-pay-respects.sh
#
# Installs pay-respects via cargo (thefuck replacement — thefuck broke
# on Python 3.12+). Also removes any legacy thefuck pipx install.
#
# Depends on 02-languages/07-rust.sh for cargo.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_PAY_RESPECTS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_PAY_RESPECTS_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command cargo

if ! command -v pay-respects &>/dev/null; then
    info "Installing pay-respects via cargo..."
    cargo install pay-respects --quiet 2>/dev/null \
        || warn "pay-respects install failed (non-fatal, install manually with: cargo install pay-respects)"
else
    ok "pay-respects: $(pay-respects --version 2>&1 | head -1)"
fi

# Clean up legacy thefuck pipx install if present (distutils/imp removed in Py3.12)
if command -v pipx &>/dev/null && pipx list --short 2>/dev/null | grep -q '^thefuck '; then
    info "Removing legacy thefuck pipx install..."
    pipx uninstall thefuck >/dev/null 2>&1 || true
fi
