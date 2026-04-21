#!/usr/bin/env bash
# =============================================================================
# install/01-system/02-locale.sh
#
# Generates the en_US.UTF-8 locale and sets it as the system default.
# Fixes NVM's `manpath: can't set the locale` warning during nvm.sh
# sourcing (common on fresh WSL installs where LANG is set but the
# underlying locale data was never generated).
#
# Idempotent — skips generation if the locale is already present.
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_LOCALE_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_LOCALE_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo

TARGET_LOCALE="en_US.UTF-8"

# locale -a normalizes to "en_US.utf8" (lowercase, no dash) — match loosely
if locale -a 2>/dev/null | grep -qiE '^en_us\.?utf-?8$'; then
    ok "Locale $TARGET_LOCALE already generated"
else
    info "Generating locale $TARGET_LOCALE..."
    sudo apt-get install -y -qq locales >/dev/null 2>&1 || true
    sudo locale-gen "$TARGET_LOCALE" >/dev/null
    sudo update-locale LANG="$TARGET_LOCALE"
    ok "Locale $TARGET_LOCALE generated and set as default (logout/login to take effect)"
fi
