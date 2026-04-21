#!/usr/bin/env bash
# =============================================================================
# install/04-editors/02-tmux-plugins.sh
#
# Invokes TPM's install_plugins against the configured plugin list.
# TPM itself lives at $HOME/.tmux/plugins/tpm — installed by
# 03-dotfiles/02-runtime-deps.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_TMUX_PLUGINS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_TMUX_PLUGINS_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux

TPM_INSTALL="$HOME/.tmux/plugins/tpm/bin/install_plugins"
if [[ -x "$TPM_INSTALL" ]]; then
    info "Installing tmux plugins via TPM..."
    "$TPM_INSTALL" 2>/dev/null && ok "Tmux plugins installed" \
        || warn "TPM install failed (start tmux and press prefix+I)"
else
    warn "TPM not found — tmux plugins will install on first tmux launch (prefix+I)"
fi
