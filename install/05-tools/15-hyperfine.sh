#!/usr/bin/env bash
# =============================================================================
# install/05-tools/15-hyperfine.sh
#
# Installs hyperfine via apt. Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_HYPERFINE_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_HYPERFINE_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo

if command -v hyperfine >/dev/null 2>&1; then
    ok "hyperfine already installed"
    exit 0
fi

info "Installing hyperfine via apt..."
sudo apt-get install -y -qq hyperfine
ok "hyperfine installed"
