#!/usr/bin/env bash
# =============================================================================
# install/02-languages/03-go.sh
#
# Installs the latest stable Go toolchain to /usr/local/go and the
# gopls language server. Fetches the official tarball from go.dev.
#
# Uses curl + jq from 01-system/01-packages.sh.
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_GO_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_GO_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo
require_command curl
require_command jq

if ! command -v go &>/dev/null; then
    info "Installing Go..."
    GO_VERSION=$(curl -fsSL https://go.dev/dl/?mode=json | jq -r '.[0].version')
    GO_TARBALL="${GO_VERSION}.linux-amd64.tar.gz"
    curl -fsSL -o "/tmp/${GO_TARBALL}" "https://go.dev/dl/${GO_TARBALL}"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"
    rm -f "/tmp/${GO_TARBALL}"
    ok "Go: $(/usr/local/go/bin/go version)"
else
    ok "Go: $(go version)"
fi

if ! command -v gopls &>/dev/null; then
    info "Installing gopls..."
    /usr/local/go/bin/go install golang.org/x/tools/gopls@latest
    ok "gopls installed"
else
    ok "gopls: $(gopls version | head -1)"
fi
