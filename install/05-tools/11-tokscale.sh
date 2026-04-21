#!/usr/bin/env bash
# =============================================================================
# install/05-tools/11-tokscale.sh
#
# Installs tokscale (multi-provider LLM token-usage analytics) via
# `npm install -g`. Depends on 02-languages/08-node.sh for npm.
#
# Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_TOKSCALE_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_TOKSCALE_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux

if command -v tokscale >/dev/null 2>&1; then
    ok "tokscale already installed"
    exit 0
fi

if ! command -v npm >/dev/null 2>&1; then
    warn "npm not found; cannot install tokscale (run 02-languages/08-node.sh first)"
    exit 0
fi

info "Installing tokscale via npm..."
if npm install -g tokscale@latest >/dev/null 2>&1; then
    ok "tokscale installed"
else
    warn "tokscale npm install failed"
fi
