#!/usr/bin/env bash
# =============================================================================
# install/05-tools/09-rga.sh
#
# Installs rga (ripgrep-all) from official GitHub release. Also installs
# the sibling tools that rga shells out to for content extraction:
# ffmpeg, pandoc, poppler-utils (ripgrep is already in 01-packages).
#
# Falls back to `cargo install ripgrep_all` if the release download
# fails.
#
# Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_RGA_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_RGA_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/downloads.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/downloads.sh"

require_linux
require_command sudo
require_command curl

# rga sibling tools for content extraction
info "Installing rga content-extraction deps (ffmpeg, pandoc, poppler-utils)..."
sudo apt-get install -y -qq ffmpeg pandoc poppler-utils

if command -v rga >/dev/null 2>&1; then
    ok "rga already installed"
    exit 0
fi

case "$(arch_slug)" in
    x86_64) asset_arch='x86_64' ;;
    aarch64) asset_arch='aarch64' ;;
esac

tag="$(resolve_github_latest_tag "phiresky/ripgrep-all")"
base_url="https://github.com/phiresky/ripgrep-all/releases/download/${tag}"

info "Installing rga ${tag} from official release..."
if install_binary_from_archive_candidates \
    "rga" \
    "rga" \
    "$base_url" \
    "ripgrep_all-${tag}-${asset_arch}-unknown-linux-musl.tar.gz" \
    "ripgrep_all-${tag}-${asset_arch}-unknown-linux-gnu.tar.gz"
then
    exit 0
fi

warn "Official rga release install failed; trying cargo build fallback"
cargo_install_if_missing "ripgrep_all" "rga"
