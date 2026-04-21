#!/usr/bin/env bash
# =============================================================================
# install/05-tools/05-tealdeer.sh
#
# Installs tealdeer (tldr client) from official GitHub release into
# $HOME/.local/bin/tldr-real. If $DOTFILES_DIR/bin/tldr exists it's
# installed as a user wrapper at $HOME/.local/bin/tldr; otherwise tldr
# is symlinked directly to tldr-real. $HOME/.local/bin/tealdeer is
# symlinked to tldr. Also refreshes the tldr cache once installed.
#
# Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_TEALDEER_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_TEALDEER_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/downloads.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/downloads.sh"

require_linux
require_command curl

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

tealdeer_version() {
    if ! command -v tldr >/dev/null 2>&1; then
        return 1
    fi
    tldr --version 2>/dev/null | awk 'NR == 1 { print $2 }'
}

tag="$(resolve_github_latest_tag "tealdeer-rs/tealdeer")"
version="${tag#v}"
current_version="$(tealdeer_version || true)"

if [[ "$current_version" == "$version" ]]; then
    ok "tealdeer ${version} already installed"
else
    case "$(arch_slug)" in
        x86_64) asset_arch='x86_64' ;;
        aarch64) asset_arch='aarch64' ;;
    esac

    url="https://github.com/tealdeer-rs/tealdeer/releases/download/${tag}/tealdeer-linux-${asset_arch}-musl"
    tmp="$(mktemp)"

    info "Installing tealdeer ${tag} from official release..."
    curl_download "$url" "$tmp"
    install -m 0755 "$tmp" "$LOCAL_BIN/tldr-real"
    rm -f "$tmp"

    if [[ -f "$DOTFILES_DIR/bin/tldr" ]]; then
        install -m 0755 "$DOTFILES_DIR/bin/tldr" "$LOCAL_BIN/tldr"
    else
        ln -sfn "$LOCAL_BIN/tldr-real" "$LOCAL_BIN/tldr"
    fi
    ln -sfn "$LOCAL_BIN/tldr" "$LOCAL_BIN/tealdeer"
    ok "tealdeer installed"
fi

# Refresh the cache once the binary is in place
if command -v tldr >/dev/null 2>&1; then
    info "Refreshing tealdeer cache..."
    if tldr --update >/dev/null 2>&1; then
        ok "tealdeer cache updated"
    else
        warn "tealdeer cache update failed; run \`tldr --update\` later"
    fi
fi
