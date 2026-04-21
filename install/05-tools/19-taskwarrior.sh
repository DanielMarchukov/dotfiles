#!/usr/bin/env bash
# =============================================================================
# install/05-tools/19-taskwarrior.sh
#
# Builds Taskwarrior 3.x from source (apt only ships 2.x). Needs cmake
# + cargo for the TaskChampion backend (cargo from 02-languages/07-rust,
# cmake from 01-system/01-packages).
#
# Also manually symlinks $DOTFILES_DIR/.taskrc to ~/.taskrc (stow
# ignores .taskrc) and patches the hardcoded home path inside it.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_TASKWARRIOR_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_TASKWARRIOR_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo
require_command curl
require_command jq
require_command cmake

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TW_MIN_VERSION="3"
install_taskwarrior=false

if ! command -v task &>/dev/null; then
    install_taskwarrior=true
elif [[ "$(task --version 2>/dev/null | cut -d. -f1)" -lt "$TW_MIN_VERSION" ]]; then
    info "Taskwarrior $(task --version) found but < 3.x, upgrading..."
    install_taskwarrior=true
fi

if [[ "$install_taskwarrior" == true ]]; then
    info "Building Taskwarrior 3.x from source..."
    if TW_VERSION=$(curl -fsSL https://api.github.com/repos/GothenburgBitFactory/taskwarrior/releases/latest | jq -r '.tag_name' | sed 's/^v//'); then
        TW_BUILD_DIR=$(mktemp -d)
        if curl -fsSL -o "$TW_BUILD_DIR/task.tar.gz" \
            "https://github.com/GothenburgBitFactory/taskwarrior/releases/download/v${TW_VERSION}/task-${TW_VERSION}.tar.gz" \
            && tar xzf "$TW_BUILD_DIR/task.tar.gz" -C "$TW_BUILD_DIR" \
            && cmake -S "$TW_BUILD_DIR/task-${TW_VERSION}" -B "$TW_BUILD_DIR/build" \
                -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local \
            && cmake --build "$TW_BUILD_DIR/build" -j"$(nproc)" \
            && sudo cmake --install "$TW_BUILD_DIR/build"; then
            ok "Taskwarrior ${TW_VERSION} installed"
        else
            warn "Taskwarrior build failed; continuing without Taskwarrior 3.x"
        fi
        rm -rf "$TW_BUILD_DIR"
    else
        warn "Could not resolve latest Taskwarrior release; continuing without Taskwarrior 3.x"
    fi
else
    ok "Taskwarrior: $(task --version)"
fi

# Symlink .taskrc from dotfiles (stow ignores it)
if [[ -f "$DOTFILES_DIR/.taskrc" ]]; then
    backup_if_real "$HOME/.taskrc"
    ln -sf "$DOTFILES_DIR/.taskrc" "$HOME/.taskrc"
    ok "Linked ~/.taskrc"
fi

# Patch hardcoded home path in .taskrc
patch_home "$DOTFILES_DIR/.taskrc"
