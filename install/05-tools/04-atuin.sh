#!/usr/bin/env bash
# =============================================================================
# install/05-tools/04-atuin.sh
#
# Installs atuin (shell history sync / search) from the official GitHub
# release. Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_ATUIN_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_ATUIN_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/downloads.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/downloads.sh"

require_linux
require_command curl

if command -v atuin >/dev/null 2>&1; then
    ok "atuin already installed"
    exit 0
fi

case "$(arch_slug)" in
    x86_64) asset_arch='x86_64-unknown-linux-gnu' ;;
    aarch64) asset_arch='aarch64-unknown-linux-gnu' ;;
esac

tag="$(resolve_github_latest_tag "atuinsh/atuin")"
base_url="https://github.com/atuinsh/atuin/releases/download/${tag}"

info "Installing atuin ${tag} from official release..."
install_binary_from_archive_candidates \
    "atuin" \
    "atuin" \
    "$base_url" \
    "atuin-${asset_arch}.tar.gz"

# Import existing shell history on fresh install. Only runs here (not on
# the "already installed" early-exit path) so re-runs don't re-import.
if command -v atuin >/dev/null 2>&1; then
    info "Importing shell history into atuin..."
    atuin import auto 2>/dev/null || warn "atuin import auto failed (non-fatal)"
fi
