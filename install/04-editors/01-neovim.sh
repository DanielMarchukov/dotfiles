#!/usr/bin/env bash
# =============================================================================
# install/04-editors/01-neovim.sh
#
# Installs the latest stable Neovim release binary to /opt and symlinks
# it into /usr/local/bin/nvim. Plugin sync happens in
# 04-editors/03-neovim-plugins.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_NEOVIM_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_NEOVIM_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo
require_command curl
require_command jq

if ! command -v nvim &>/dev/null; then
    info "Installing Neovim..."
    NVIM_VERSION=$(curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest | jq -r '.tag_name')
    curl -fsSL -o /tmp/nvim-linux-x86_64.tar.gz \
        "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar xzf /tmp/nvim-linux-x86_64.tar.gz -C /opt/
    sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
    rm -f /tmp/nvim-linux-x86_64.tar.gz
    ok "Neovim ${NVIM_VERSION} installed"
else
    ok "Neovim: $(nvim --version | head -1)"
fi
