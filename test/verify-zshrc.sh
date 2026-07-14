#!/usr/bin/env bash
# =============================================================================
# test/verify-zshrc.sh
#
# Smoke test of the live shell config: sourcing ~/.zshrc must be silent (no
# warnings/errors on an interactive reload). Unlike the rest of the suite
# this is intentionally NOT hermetic — it exercises the real installed
# ~/.zshrc. It skips cleanly when zsh or ~/.zshrc is absent (e.g. CI).
# =============================================================================
set -uo pipefail

if [[ -n "${_DOTFILES_VERIFY_ZSHRC_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_VERIFY_ZSHRC_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

describe "zshrc: interactive reload is silent"
if ! command -v zsh >/dev/null 2>&1; then
    skip "zsh not installed"
elif [[ ! -f "$HOME/.zshrc" ]]; then
    skip "no .zshrc in \$HOME"
else
    out="$(zsh -ic 'source ~/.zshrc' 2>&1)"
    if [[ -z "$out" ]]; then
        pass "sourcing ~/.zshrc produced no output"
    else
        fail "sourcing ~/.zshrc produced output" "$out"
    fi

    # szsh is the repo's fast interactive-restart helper; only assert it when
    # the live config actually defines it.
    if zsh -ic 'command -v szsh >/dev/null 2>&1' 2>/dev/null; then
        out="$(zsh -ic 'szsh -ic exit' 2>&1)"
        if [[ -z "$out" ]]; then
            pass "szsh restart produced no output"
        else
            fail "szsh restart produced output" "$out"
        fi
    else
        skip "szsh not defined in this shell"
    fi
fi

harness_summary
