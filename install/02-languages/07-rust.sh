#!/usr/bin/env bash
# =============================================================================
# install/02-languages/07-rust.sh
#
# Rust via rustup: installs if missing, updates stable otherwise.
# Ensures clippy, rustfmt, llvm-tools-preview components are present.
# Installs cargo dev tools (cargo-llvm-cov, cargo-audit, cargo-deny).
#
# Enables cargo for three downstream steps:
#   - 05-tools/03-pay-respects.sh
#   - 05-tools/04-cli-extensions.sh (rga/watchexec/git-branchless fallbacks)
#   - 05-tools/05-taskwarrior.sh (TaskChampion backend build)
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_RUST_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_RUST_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command curl

if ! command -v rustup &>/dev/null; then
    info "Installing Rust via rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --quiet
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
    ok "Rust installed: $(rustc --version)"
else
    # Ensure toolchain is up to date
    rustup update stable --no-self-update 2>/dev/null || true
    ok "Rust: $(rustc --version)"
fi

# Ensure standard components are installed
rustup component add clippy rustfmt llvm-tools-preview 2>/dev/null || true

# Cargo dev tools (used by tusk and rop CI pipelines)
CARGO_TOOLS=(
    "cargo-llvm-cov"    # code coverage
    "cargo-audit"       # security vulnerability audit
    "cargo-deny"        # dependency license/source linting
)

for tool in "${CARGO_TOOLS[@]}"; do
    bin_name="${tool}"
    if ! cargo install --list 2>/dev/null | grep -q "^${tool} "; then
        info "Installing ${tool}..."
        cargo install "${tool}" --quiet 2>/dev/null \
            || warn "${tool} install failed (non-fatal)"
    else
        ok "cargo tool: ${tool}"
    fi
done
