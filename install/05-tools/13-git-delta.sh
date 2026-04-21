#!/usr/bin/env bash
# =============================================================================
# install/05-tools/13-git-delta.sh
#
# Installs git-delta via apt. Binary command is `delta`.
# Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_GIT_DELTA_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_GIT_DELTA_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo

if command -v delta >/dev/null 2>&1; then
    ok "git-delta already installed"
else
    info "Installing git-delta via apt..."
    sudo apt-get install -y -qq git-delta
    ok "git-delta installed"
fi

# Wire delta into global git config. Idempotent — setting the same
# value twice is a no-op.
info "Configuring git to use delta as pager..."
git config --global core.pager delta
git config --global interactive.diffFilter 'delta --color-only'
git config --global delta.navigate true
ok "git-delta configured"
