#!/usr/bin/env bash
# =============================================================================
# test/lib/harness.sh
#
# Shared harness for the dotfiles verify-*.sh suite. Source this first:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"
#
# Provides a hermetic sandbox (throwaway $HOME + a fakebin/ of stub
# executables so the real install scripts run against mocks, never the
# host system), stub factories for the boundaries every module crosses
# (uname/sudo/jq/curl), and non-fatal assertions that tally pass/fail.
#
# A verify script's shape:
#   source .../lib/harness.sh
#   describe "scenario name"
#   case_dir="$(sandbox my-case)"
#   stub "$case_dir/fakebin" curl <<'EOF' ... EOF
#   run_module "$ROOT_DIR/install/.../foo.sh" "$case_dir" ENV=val ...
#   assert_success "$RUN_RC" "installer exits 0"
#   assert_file "$case_dir/home/.local/bin/foo"
#   harness_summary   # last line: its exit status becomes the script's
#
# Assertions never abort the script — a scenario reports every check so a
# single run surfaces all failures at once. Do NOT use `set -e` in verify
# scripts; use `set -uo pipefail` and let harness_summary set the exit code.
# =============================================================================

# Sourcing guard
[[ -n "${_DOTFILES_TEST_HARNESS_SH_LOADED:-}" ]] && return 0
_DOTFILES_TEST_HARNESS_SH_LOADED=1

# ---------------------------------------------------------------------------
# Paths — resolved from this file, so tests run from any CWD.
# ---------------------------------------------------------------------------
HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2034  # ROOT_DIR is the harness's public API — sourcing verify-*.sh reference it.
ROOT_DIR="$(cd "$HARNESS_DIR/../.." && pwd)"

# One temp root per test process; auto-removed on exit. Cleanup preserves the
# pending exit status because the trap does not call `exit`.
HARNESS_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$HARNESS_TMPDIR"' EXIT

# Curated coreutils bin — the ONLY host binaries a sandbox sees besides its
# own fakebin stubs. Sandboxes run with PATH=fakebin:HARNESS_COREUTILS, never
# the host /usr/bin, so a tool the host happens to have installed (delta, just,
# nvim…) can't leak in and make `command -v` lie about what's present.
# Application tools that a test means to control (curl, apt-get, sudo, cargo,
# stow, jq, nvim, fc-*) are deliberately absent here — a test must stub them.
HARNESS_COREUTILS="$HARNESS_TMPDIR/.coreutils"
mkdir -p "$HARNESS_COREUTILS"
for _t in bash sh env printf echo cat cp mv rm mkdir rmdir ln readlink \
          chmod touch sed grep egrep awk gawk find sort uniq head tail tr cut \
          wc basename dirname mktemp date seq uname tar gzip gunzip unzip \
          install python3 git xargs sleep true false test '['; do
    if _p="$(command -v "$_t" 2>/dev/null)"; then
        ln -sf "$_p" "$HARNESS_COREUTILS/$_t"
    fi
done
unset _t _p

# ---------------------------------------------------------------------------
# Output styling (suppressed when not a TTY or NO_COLOR is set)
# ---------------------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    _C_RED=$'\033[0;31m'; _C_GREEN=$'\033[0;32m'
    _C_YELLOW=$'\033[0;33m'; _C_DIM=$'\033[2m'; _C_RESET=$'\033[0m'
else
    _C_RED=''; _C_GREEN=''; _C_YELLOW=''; _C_DIM=''; _C_RESET=''
fi

_HARNESS_PASS=0
_HARNESS_FAIL=0
_HARNESS_SCENARIO=''

# ---------------------------------------------------------------------------
# Scenario framing + sandbox
# ---------------------------------------------------------------------------
# describe <name> — label the current scenario (printed as a header).
describe() {
    _HARNESS_SCENARIO="$1"
    printf '\n%s• %s%s\n' "$_C_DIM" "$1" "$_C_RESET"
}

# sandbox <name> — create and echo a fresh case dir with fakebin/ home/ work/.
sandbox() {
    local name="$1"
    local dir="$HARNESS_TMPDIR/$name"
    rm -rf "$dir"
    mkdir -p "$dir/fakebin" "$dir/home" "$dir/work"
    printf '%s\n' "$dir"
}

# stub <fakebin_dir> <name> — write an executable stub; body read from stdin.
stub() {
    local dir="$1" name="$2"
    cat >"$dir/$name"
    chmod +x "$dir/$name"
}

# ---------------------------------------------------------------------------
# Common stub factories — the OS/tooling boundary shared by most modules.
# ---------------------------------------------------------------------------
# stub_uname <fakebin> [os] [arch] — default Linux/x86_64; other args deferred
# to the real uname so callers like `uname -r` still work.
stub_uname() {
    local dir="$1" os="${2:-Linux}" arch="${3:-x86_64}"
    stub "$dir" uname <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-s" ]]; then printf '%s\n' "$os"
elif [[ "\$1" == "-m" ]]; then printf '%s\n' "$arch"
else exec /usr/bin/uname "\$@"; fi
EOF
}

# stub_sudo <fakebin> — transparent sudo (drops the sudo, runs the command).
stub_sudo() {
    stub "$1" sudo <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "-n" ]] && exit 0
while [[ "$1" == -* ]]; do shift; done
exec "$@"
EOF
}

# stub_jq <fakebin> — minimal jq backed by python3 for the queries the
# installers use (.tag_name, .body, .tag_name // empty).
stub_jq() {
    stub "$1" jq <<'EOF'
#!/usr/bin/env bash
python3 -c '
import json, sys
query = sys.argv[-1]
data = json.load(sys.stdin)
def field(q):
    q = q.split("//")[0].strip().lstrip(".")
    return data.get(q, "")
val = field(query)
print(val if val is not None else "")
' "$@"
EOF
}

# stub_apt <fakebin> <logfile> — log every apt-get invocation, always succeed.
stub_apt() {
    local dir="$1" log="$2"
    stub "$dir" apt-get <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$log"
exit 0
EOF
}

# ---------------------------------------------------------------------------
# Running a module under test
# ---------------------------------------------------------------------------
# run_module <script> <case_dir> [ENV=val ...] — run a real install script in
# the sandbox: HOME=<case>/home, PATH=fakebin:<real minimum>, plus any extra
# env. Captures stdout/stderr to <case>/stdout,<case>/stderr and the exit code
# into the global RUN_RC. Extra `-o`/`-e` overrides are not needed.
# These three are the run_module/run_lib output API, read by sourcing tests.
# shellcheck disable=SC2034
RUN_RC=0
# shellcheck disable=SC2034
RUN_OUT=''
# shellcheck disable=SC2034
RUN_ERR=''
run_module() {
    local script="$1" case_dir="$2"; shift 2
    RUN_OUT="$case_dir/stdout"
    RUN_ERR="$case_dir/stderr"
    env -i \
        HOME="$case_dir/home" \
        PATH="$case_dir/fakebin:$HARNESS_COREUTILS" \
        PYTHONDONTWRITEBYTECODE=1 \
        "$@" \
        bash "$script" >"$RUN_OUT" 2>"$RUN_ERR"
    # shellcheck disable=SC2034  # read by sourcing tests as assert_success "$RUN_RC"
    RUN_RC=$?
    return 0
}

# ---------------------------------------------------------------------------
# Assertions — record pass/fail, never exit.
# ---------------------------------------------------------------------------
pass() {
    _HARNESS_PASS=$((_HARNESS_PASS + 1))
    printf '  %s✓%s %s\n' "$_C_GREEN" "$_C_RESET" "$1"
}

# fail <msg> [detail] — detail (multi-line ok) is indented under the message.
fail() {
    _HARNESS_FAIL=$((_HARNESS_FAIL + 1))
    printf '  %s✗ %s%s\n' "$_C_RED" "$1" "$_C_RESET" >&2
    if [[ -n "${2:-}" ]]; then
        printf '%s\n' "$2" | sed 's/^/      /' >&2
    fi
}

skip() {
    printf '  %s- skip: %s%s\n' "$_C_YELLOW" "$1" "$_C_RESET"
}

assert_success() {
    local rc="$1" msg="$2"
    if [[ "$rc" -eq 0 ]]; then pass "$msg"
    else fail "$msg" "exit=$rc$( [[ -f "$RUN_ERR" ]] && printf '\n%s' "$(cat "$RUN_ERR")" )"; fi
}

assert_failure() {
    local rc="$1" msg="$2"
    if [[ "$rc" -ne 0 ]]; then pass "$msg"
    else fail "$msg" "expected non-zero exit"; fi
}

assert_eq() {
    if [[ "$1" == "$2" ]]; then pass "${3:-values equal}"
    else fail "${3:-values differ}" "expected: $2"$'\n'"actual:   $1"; fi
}

assert_file() {
    if [[ -f "$1" ]]; then pass "${2:-file exists: $1}"
    else fail "${2:-file missing: $1}"; fi
}

assert_executable() {
    if [[ -x "$1" ]]; then pass "${2:-executable: $1}"
    else fail "${2:-not executable: $1}"; fi
}

assert_symlink() {
    if [[ -L "$1" ]]; then pass "${2:-symlink: $1}"
    else fail "${2:-not a symlink: $1}"; fi
}

# assert_empty <file> [msg] — passes when the file is absent or zero-length
# (e.g. a command-log proving a stub was never invoked).
assert_empty() {
    if [[ ! -s "$1" ]]; then pass "${2:-no output in $(basename "$1")}"
    else fail "${2:-unexpected output in $(basename "$1")}" "$(cat "$1" 2>/dev/null)"; fi
}

# assert_contains <literal-needle> <file> [msg] — fixed-string match.
assert_contains() {
    if grep -qF -- "$1" "$2" 2>/dev/null; then
        pass "${3:-'$1' in $(basename "$2")}"
    else
        fail "${3:-'$1' not found in $(basename "$2")}" "$(cat "$2" 2>/dev/null)"
    fi
}

assert_not_contains() {
    if grep -qF -- "$1" "$2" 2>/dev/null; then
        fail "${3:-unexpected '$1' in $(basename "$2")}" "$(cat "$2" 2>/dev/null)"
    else
        pass "${3:-'$1' absent from $(basename "$2")}"
    fi
}

# ---------------------------------------------------------------------------
# Summary — call as the last line of every verify script.
# ---------------------------------------------------------------------------
harness_summary() {
    local total=$((_HARNESS_PASS + _HARNESS_FAIL))
    if [[ "$_HARNESS_FAIL" -eq 0 ]]; then
        printf '%s——%s %s%d passed%s (%d checks)\n' \
            "$_C_DIM" "$_C_RESET" "$_C_GREEN" "$_HARNESS_PASS" "$_C_RESET" "$total"
    else
        printf '%s——%s %s%d passed, %d failed%s (%d checks)\n' \
            "$_C_DIM" "$_C_RESET" "$_C_RED" "$_HARNESS_PASS" "$_HARNESS_FAIL" "$_C_RESET" "$total"
    fi
    [[ "$_HARNESS_FAIL" -eq 0 ]]
}
