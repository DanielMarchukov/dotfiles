#!/usr/bin/env bash
# =============================================================================
# install/05-tools/08-watchexec.sh
#
# Installs watchexec from official GitHub release (musl preferred, gnu
# fallback). If that fails, falls back to cargo install watchexec-cli.
#
# Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_WATCHEXEC_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_WATCHEXEC_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/downloads.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/downloads.sh"

require_linux
require_command curl

if command -v watchexec >/dev/null 2>&1; then
    ok "watchexec already installed"
    exit 0
fi

case "$(arch_slug)" in
    x86_64) asset_arch='x86_64' ;;
    aarch64) asset_arch='aarch64' ;;
esac

tag="$(resolve_github_latest_tag "watchexec/watchexec")"
version="${tag#v}"
base_url="https://github.com/watchexec/watchexec/releases/download/${tag}"

info "Installing watchexec ${tag} from official release..."
if install_binary_from_archive_candidates \
    "watchexec" \
    "watchexec" \
    "$base_url" \
    "watchexec-${version}-${asset_arch}-unknown-linux-musl.tar.xz" \
    "watchexec-${version}-${asset_arch}-unknown-linux-gnu.tar.xz"
then
    exit 0
fi

warn "Official watchexec release install failed; trying cargo build fallback"
cargo_install_if_missing "watchexec-cli" "watchexec"
