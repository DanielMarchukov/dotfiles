#!/usr/bin/env bash
# =============================================================================
# install/05-tools/17-timewarrior.sh
#
# Installs timewarrior via apt. Binary command is `timew`.
# Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_TIMEWARRIOR_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_TIMEWARRIOR_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo

if command -v timew >/dev/null 2>&1; then
    ok "timewarrior already installed"
    exit 0
fi

info "Installing timewarrior via apt..."
sudo apt-get install -y -qq timewarrior
ok "timewarrior installed"
