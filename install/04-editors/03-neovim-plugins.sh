#!/usr/bin/env bash
# =============================================================================
# install/04-editors/03-neovim-plugins.sh
#
# Headless Lazy.nvim plugin sync + Mason registry refresh + Mason Java
# tools install (jdtls, java-debug-adapter, java-test).
#
# Requires:
#   - 04-editors/01-neovim.sh (nvim binary)
#   - 03-dotfiles/05-stow.sh (~/.config/nvim symlink)
#   - 02-languages/01-temurin-jdk.sh (JAVA_HOME for jdtls)
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_NEOVIM_PLUGINS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_NEOVIM_PLUGINS_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux

if ! command -v nvim &>/dev/null; then
    warn "nvim not on PATH — skipping Neovim plugin sync"
    exit 0
fi

info "Syncing Neovim plugins (lazy.nvim)..."
nvim --headless "+Lazy! sync" +qa 2>/dev/null && ok "Neovim plugins synced" \
    || warn "Neovim plugin sync failed (open nvim manually to complete setup)"

info "Updating Mason tool registry..."
nvim --headless -c "lua require('mason-registry').refresh()" -c "sleep 5" -c "qa" 2>/dev/null \
    && ok "Mason registry updated" \
    || warn "Mason update failed (open nvim manually, tools install on first use)"

info "Installing Mason Java tooling..."
nvim --headless "+MasonInstall jdtls java-debug-adapter java-test" +qa 2>/dev/null \
    && ok "Mason Java tools installed" \
    || warn "Mason Java tool install failed (open a Java file in nvim to trigger install)"
