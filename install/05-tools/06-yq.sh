#!/usr/bin/env bash
# =============================================================================
# install/05-tools/06-yq.sh
#
# Installs yq v4 (mikefarah/yq) from official GitHub release. Skips if
# a v4 binary is already present.
#
# Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_YQ_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_YQ_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/downloads.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/downloads.sh"

require_linux
require_command curl

yq_is_v4() {
    local version_output
    if ! command -v yq >/dev/null 2>&1; then
        return 1
    fi
    version_output="$(yq --version 2>/dev/null || true)"
    [[ "$version_output" == *" version v4."* || "$version_output" == *" version 4."* || "$version_output" == *" v4."* ]]
}

if yq_is_v4; then
    ok "yq already installed"
    exit 0
fi

case "$(apt_arch_slug)" in
    amd64) arch='amd64' ;;
    arm64) arch='arm64' ;;
esac

url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}"
tmp="$(mktemp)"

info "Installing yq v4 from official release..."
curl_download "$url" "$tmp"
install -m 0755 "$tmp" "$LOCAL_BIN/yq"
rm -f "$tmp"
ok "yq installed"
