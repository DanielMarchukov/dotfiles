#!/usr/bin/env bash
# =============================================================================
# install/02-languages/08-node.sh
#
# Installs NVM at $HOME/.nvm and the latest LTS Node.js. On re-run,
# reports "already installed" and skips — Node/nvm version bumps are
# manual (`nvm install --lts` in a shell).
#
# Enables npm for downstream use:
#   - tokscale install inside 05-tools/04-cli-extensions.sh
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_NODE_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_NODE_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command curl

export NVM_DIR="$HOME/.nvm"
if [[ ! -d "$NVM_DIR" ]]; then
    info "Installing NVM..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    info "Installing latest LTS Node.js..."
    nvm install --lts
    nvm alias default 'lts/*'
    ok "Node.js installed: $(node --version)"
else
    ok "NVM already installed"
fi
