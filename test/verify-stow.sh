#!/usr/bin/env bash
set -euo pipefail

output="$(
    bash /home/dmarciukovas/repos/dotfiles/install/03-dotfiles/05-stow.sh 2>&1
)"

printf '%s\n' "$output"

if grep -Eq 'BUG in find_stowed_path|Absolute/relative mismatch' <<<"$output"; then
    printf 'FAIL: stow emitted an absolute/relative path warning\n' >&2
    exit 1
fi
