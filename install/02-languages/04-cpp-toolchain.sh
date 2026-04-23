#!/usr/bin/env bash
# =============================================================================
# install/02-languages/04-cpp-toolchain.sh
#
# C++ development stack:
#   - LLVM 19 APT repo + clang/clang-format/clang-tidy/llvm
#   - GCC 14 + libstdc++
#   - Ninja, pkg-config, autotools, lcov
#   - Boost, ZeroMQ, cURL, OpenSSL headers
#   - vcpkg (git checkout + bootstrap)
#   - pipx tools: pre-commit, cmake-format (cmakelang), mdformat
#
# Requires system apt, wget, and pipx from 01-system/01-packages.sh.
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_CPP_TOOLCHAIN_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_CPP_TOOLCHAIN_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command sudo
require_command apt-get
require_command wget
require_command git
require_command pipx
require_command lsb_release

info "Ensuring C++ toolchain is installed..."

# ---------------------------------------------------------------------------
# LLVM/Clang 19 APT repo
# ---------------------------------------------------------------------------
if ! command -v clang-19 &>/dev/null; then
    info "Adding LLVM 19 APT repository..."
    wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | sudo tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc > /dev/null
    CODENAME=$(lsb_release -cs)
    echo "deb http://apt.llvm.org/$CODENAME/ llvm-toolchain-$CODENAME-19 main" \
        | sudo tee /etc/apt/sources.list.d/llvm-19.list > /dev/null
    sudo apt-get update -qq
fi

sudo apt-get install -y -qq \
    g++-14 libstdc++-14-dev \
    clang-19 clang-format-19 clang-tidy-19 clangd-19 llvm-19 \
    ninja-build pkg-config \
    autoconf automake autoconf-archive libtool \
    linux-libc-dev lcov \
    libboost-all-dev libzmq3-dev libcurl4-openssl-dev libssl-dev

# Symlink clang-19 as default if no unversioned clang exists
if command -v clang-19 &>/dev/null && ! command -v clang &>/dev/null; then
    sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-19 100
    sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-19 100
    sudo update-alternatives --install /usr/bin/clang-format clang-format /usr/bin/clang-format-19 100
    sudo update-alternatives --install /usr/bin/clang-tidy clang-tidy /usr/bin/clang-tidy-19 100
fi

# Unversioned clangd for tools (e.g., Claude Code clangd-lsp) that look
# for `clangd` on PATH. Updates only if clangd-19 is present and no
# unversioned clangd is already registered.
if command -v clangd-19 &>/dev/null && ! command -v clangd &>/dev/null; then
    sudo update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-19 100
fi

ok "C++ toolchain"

# ---------------------------------------------------------------------------
# vcpkg
# ---------------------------------------------------------------------------
export VCPKG_ROOT="$HOME/vcpkg"
if [[ ! -d "$VCPKG_ROOT" ]]; then
    info "Installing vcpkg..."
    git clone https://github.com/microsoft/vcpkg.git "$VCPKG_ROOT"
    "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
    ok "vcpkg installed"
elif [[ -d "$VCPKG_ROOT/.git" ]]; then
    info "Updating vcpkg..."
    git -C "$VCPKG_ROOT" pull --ff-only 2>/dev/null && "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics 2>/dev/null || true
    ok "vcpkg: up to date"
fi
export PATH="$VCPKG_ROOT:$PATH"

# ---------------------------------------------------------------------------
# pipx tools (pre-commit, cmake-format, mdformat)
# ---------------------------------------------------------------------------
if ! command -v pre-commit &>/dev/null; then
    info "Installing pre-commit via pipx..."
    pipx install pre-commit 2>/dev/null \
        || warn "pre-commit install failed (non-fatal)"
else
    ok "pre-commit: $(pre-commit --version)"
fi

if ! command -v cmake-format &>/dev/null; then
    info "Installing cmakelang (cmake-format) via pipx..."
    pipx install cmakelang 2>/dev/null || warn "cmakelang install failed (non-fatal)"
else
    ok "cmake-format already installed"
fi

if ! command -v mdformat &>/dev/null; then
    info "Installing mdformat via pipx..."
    pipx install mdformat 2>/dev/null || warn "mdformat install failed (non-fatal)"
else
    ok "mdformat already installed"
fi
