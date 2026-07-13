#!/usr/bin/env bash
# =============================================================================
# install/02-languages/09-dotnet.sh
#
# Installs the .NET SDK (latest LTS) to ~/.dotnet via Microsoft's official
# dotnet-install.sh. User-local (no sudo), no apt-feed conflicts. Enables C#/F#
# development in Neovim — OmniSharp LSP, csharpier, and netcoredbg all require
# the .NET runtime. PATH/DOTNET_ROOT are exported by lib/common.sh (for later
# install steps) and by .zshrc (for interactive shells).
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_DOTNET_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_DOTNET_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command curl

DOTNET_ROOT="$HOME/.dotnet"

if command -v dotnet >/dev/null 2>&1 || [[ -x "$DOTNET_ROOT/dotnet" ]]; then
    ok "dotnet: $("$DOTNET_ROOT/dotnet" --version 2>/dev/null || dotnet --version 2>/dev/null || echo installed)"
    exit 0
fi

info "Installing .NET SDK (LTS) to $DOTNET_ROOT..."
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$tmp"
# --no-path: PATH is managed centrally (common.sh + .zshrc), not by the script.
bash "$tmp" --channel LTS --install-dir "$DOTNET_ROOT" --no-path

export DOTNET_ROOT
export PATH="$DOTNET_ROOT:$PATH"
ok ".NET SDK installed: $(dotnet --version 2>/dev/null || echo '(restart shell to use dotnet)')"
