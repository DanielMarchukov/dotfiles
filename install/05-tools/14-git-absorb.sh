#!/usr/bin/env bash
# =============================================================================
# install/05-tools/14-git-absorb.sh
#
# Installs git-absorb via apt. Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_GIT_ABSORB_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_GIT_ABSORB_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo

if command -v git-absorb >/dev/null 2>&1; then
    ok "git-absorb already installed"
    exit 0
fi

info "Installing git-absorb via apt..."
sudo apt-get install -y -qq git-absorb
ok "git-absorb installed"
