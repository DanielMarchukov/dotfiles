#!/usr/bin/env bash
# =============================================================================
# test/run.sh
#
# Discovers and runs the verify-*.sh suite, each in its own process, and
# aggregates the results. Exits non-zero if any test file fails.
#
# Usage:
#   test/run.sh                 # run everything
#   test/run.sh stow downloads  # run only tests whose name matches a filter
#
# Each verify-*.sh is self-contained: it sources lib/harness.sh, runs its
# scenarios, and ends with harness_summary (whose exit status it inherits).
# =============================================================================
set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'
    C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
    C_RED=''; C_GREEN=''; C_BOLD=''; C_DIM=''; C_RESET=''
fi

# Collect test files, applying any name filters passed as arguments.
mapfile -t all_tests < <(find "$TEST_DIR" -maxdepth 1 -name 'verify-*.sh' | sort)
tests=()
if [[ $# -gt 0 ]]; then
    for t in "${all_tests[@]}"; do
        for pat in "$@"; do
            if [[ "$(basename "$t")" == *"$pat"* ]]; then
                tests+=("$t")
                break
            fi
        done
    done
else
    tests=("${all_tests[@]}")
fi

if [[ ${#tests[@]} -eq 0 ]]; then
    printf '%sNo matching tests.%s\n' "$C_RED" "$C_RESET" >&2
    exit 1
fi

passed=0
failed=0
failed_names=()

for t in "${tests[@]}"; do
    name="$(basename "$t" .sh)"
    printf '%s╭─ %s%s%s\n' "$C_DIM" "$C_BOLD" "$name" "$C_RESET"
    if bash "$t"; then
        passed=$((passed + 1))
    else
        failed=$((failed + 1))
        failed_names+=("$name")
    fi
done

printf '\n%s═══════════════════════════════════%s\n' "$C_DIM" "$C_RESET"
if [[ "$failed" -eq 0 ]]; then
    printf '%s%s✓ all %d test files passed%s\n' "$C_BOLD" "$C_GREEN" "$passed" "$C_RESET"
    exit 0
fi

printf '%s%s✗ %d/%d test files failed:%s\n' "$C_BOLD" "$C_RED" \
    "$failed" "$((passed + failed))" "$C_RESET"
for n in "${failed_names[@]}"; do
    printf '   %s- %s%s\n' "$C_RED" "$n" "$C_RESET"
done
exit 1
