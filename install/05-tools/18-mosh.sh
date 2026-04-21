#!/usr/bin/env bash
# =============================================================================
# install/05-tools/18-mosh.sh
#
# Installs mosh via apt. Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_MOSH_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_MOSH_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo

if command -v mosh >/dev/null 2>&1; then
    ok "mosh already installed"
    exit 0
fi

info "Installing mosh via apt..."
sudo apt-get install -y -qq mosh
ok "mosh installed"
