#!/usr/bin/env bash
# =============================================================================
# install/03-dotfiles/06-patch-home.sh
#
# Replaces hardcoded /home/danmarchukov/ paths in shell rc files with
# the live $HOME. Idempotent: the grep guard in patch_home (common.sh)
# makes it a no-op after the first run.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_PATCH_HOME_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_PATCH_HOME_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

patch_home "$DOTFILES_DIR/.zshenv"
patch_home "$DOTFILES_DIR/.zprofile"
