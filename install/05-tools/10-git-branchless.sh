#!/usr/bin/env bash
# =============================================================================
# install/05-tools/10-git-branchless.sh
#
# Installs git-branchless from official GitHub release (musl preferred,
# gnu fallback). Falls back to `cargo install git-branchless` if the
# release download fails.
#
# Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_GIT_BRANCHLESS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_GIT_BRANCHLESS_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/downloads.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/downloads.sh"

require_linux
require_command curl

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Initialize git-branchless in the dotfiles repo. Idempotent — safe to
# re-run. Defined as a function so it can be called on both fresh
# install and "already installed" paths.
init_branchless_in_dotfiles() {
    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        info "Initializing git-branchless in dotfiles repo..."
        git -C "$DOTFILES_DIR" branchless init 2>/dev/null \
            || warn "git branchless init failed in $DOTFILES_DIR (non-fatal)"
    fi
}

if command -v git-branchless >/dev/null 2>&1; then
    ok "git-branchless already installed"
    init_branchless_in_dotfiles
    exit 0
fi

case "$(arch_slug)" in
    x86_64) asset_arch='x86_64' ;;
    aarch64) asset_arch='aarch64' ;;
esac

tag="$(resolve_github_latest_tag "arxanas/git-branchless")"
base_url="https://github.com/arxanas/git-branchless/releases/download/${tag}"

info "Installing git-branchless ${tag} from official release..."
if install_binary_from_archive_candidates \
    "git-branchless" \
    "git-branchless" \
    "$base_url" \
    "git-branchless-${tag}-${asset_arch}-unknown-linux-musl.tar.gz" \
    "git-branchless-${tag}-${asset_arch}-unknown-linux-gnu.tar.gz"
then
    init_branchless_in_dotfiles
    exit 0
fi

warn "Official git-branchless release install failed; trying cargo build fallback"
cargo_install_if_missing "git-branchless" "git-branchless"
init_branchless_in_dotfiles
