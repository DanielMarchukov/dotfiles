#!/usr/bin/env bash
set -euo pipefail

assert_quiet() {
    local label="$1"
    shift

    local output
    output="$("$@" 2>&1)"

    if [[ -n "$output" ]]; then
        printf 'FAIL: %s produced unexpected output:\n%s\n' "$label" "$output" >&2
        return 1
    fi
}

assert_quiet "zsh reload" zsh -ic 'source ~/.zshrc'
assert_quiet "szsh restart" zsh -ic 'szsh -ic exit'
