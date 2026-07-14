#!/usr/bin/env bash
# =============================================================================
# test/verify-downloads.sh
#
# Unit tests for install/lib/downloads.sh — the shared release-download
# library that atuin, tealdeer, yq, watchexec, git-branchless (and more)
# all depend on. Testing the library directly is the highest-leverage
# coverage in the suite: one green run here vouches for every consumer.
#
# Each case sources common.sh + downloads.sh in a hermetic subshell (fresh
# HOME, fakebin-only PATH) and calls a single library function against
# stubbed curl/jq, asserting on return value, stdout, and side-effects.
# =============================================================================
set -uo pipefail

if [[ -n "${_DOTFILES_VERIFY_DOWNLOADS_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_VERIFY_DOWNLOADS_SH_LOADED=1

source "$(dirname "${BASH_SOURCE[0]}")/lib/harness.sh"

# run_lib <case_dir> <fn> [args...] — source the libs in an isolated subshell
# and invoke a downloads.sh function. common.sh derives LOCAL_BIN from the
# sandbox HOME, so installs land under <case>/home/.local/bin.
run_lib() {
    local case_dir="$1"; shift
    RUN_OUT="$case_dir/stdout"
    RUN_ERR="$case_dir/stderr"
    env -i \
        HOME="$case_dir/home" \
        PATH="$case_dir/fakebin:$HARNESS_COREUTILS" \
        ROOT_DIR="$ROOT_DIR" \
        bash -c '
            set -uo pipefail
            source "$ROOT_DIR/install/lib/common.sh"
            source "$ROOT_DIR/install/lib/downloads.sh"
            "$@"
        ' _ "$@" >"$RUN_OUT" 2>"$RUN_ERR"
    RUN_RC=$?
    return 0
}

# ---------------------------------------------------------------------------
# resolve_github_latest_tag
# ---------------------------------------------------------------------------
describe "resolve_github_latest_tag: reads tag_name from the API"
c="$(sandbox gh-api-ok)"
stub_jq "$c/fakebin"
stub "$c/fakebin" curl <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do [[ "$a" == https://api.github.com/* ]] && { printf '{"tag_name":"v1.2.3"}\n'; exit 0; }; done
exit 1
EOF
run_lib "$c" resolve_github_latest_tag owner/repo
assert_success "$RUN_RC" "resolves via API"
assert_contains "v1.2.3" "$RUN_OUT" "returns v1.2.3"

describe "resolve_github_latest_tag: falls back to redirect URL when API fails"
c="$(sandbox gh-redirect)"
stub_jq "$c/fakebin"
stub "$c/fakebin" curl <<'EOF'
#!/usr/bin/env bash
url=""; for a in "$@"; do [[ "$a" == http* ]] && url="$a"; done
if [[ "$url" == https://api.github.com/* ]]; then exit 22; fi
if [[ "$url" == https://github.com/*/releases/latest ]]; then
  printf 'https://github.com/owner/repo/releases/tag/v9.9.9'  # -w url_effective
  exit 0
fi
exit 1
EOF
run_lib "$c" resolve_github_latest_tag owner/repo
assert_success "$RUN_RC" "resolves via redirect fallback"
assert_contains "v9.9.9" "$RUN_OUT" "returns v9.9.9 from effective URL"

describe "resolve_github_latest_tag: fails when both API and redirect are unusable"
c="$(sandbox gh-fail)"
stub_jq "$c/fakebin"
stub "$c/fakebin" curl <<'EOF'
#!/usr/bin/env bash
url=""; for a in "$@"; do [[ "$a" == http* ]] && url="$a"; done
if [[ "$url" == https://api.github.com/* ]]; then exit 22; fi
# redirect resolves to bare .../latest (no tag) -> unusable
printf 'https://github.com/owner/repo/releases/latest'
exit 0
EOF
run_lib "$c" resolve_github_latest_tag owner/repo
assert_failure "$RUN_RC" "returns non-zero"
assert_contains "Failed to resolve latest release tag" "$RUN_ERR" "emits diagnostic"

# ---------------------------------------------------------------------------
# resolve_gitlab_latest_tag
# ---------------------------------------------------------------------------
describe "resolve_gitlab_latest_tag: reads tag_name from GitLab API"
c="$(sandbox gl-ok)"
stub_jq "$c/fakebin"
stub "$c/fakebin" curl <<'EOF'
#!/usr/bin/env bash
for a in "$@"; do [[ "$a" == https://gitlab.com/api/* ]] && { printf '{"tag_name":"v1.60.0"}\n'; exit 0; }; done
exit 1
EOF
run_lib "$c" resolve_gitlab_latest_tag
assert_success "$RUN_RC" "resolves GitLab tag"
assert_contains "v1.60.0" "$RUN_OUT" "returns v1.60.0"

# ---------------------------------------------------------------------------
# extract_archive
# ---------------------------------------------------------------------------
describe "extract_archive: unpacks .tar.gz"
c="$(sandbox extract-tgz)"
printf 'hello\n' >"$c/work/payload.txt"
tar -czf "$c/work/a.tar.gz" -C "$c/work" payload.txt
mkdir -p "$c/work/out-tgz"
run_lib "$c" extract_archive "$c/work/a.tar.gz" "$c/work/out-tgz"
assert_success "$RUN_RC" "tar.gz extracts cleanly"
assert_file "$c/work/out-tgz/payload.txt" "member extracted"

describe "extract_archive: unpacks .zip"
c="$(sandbox extract-zip)"
if command -v unzip >/dev/null 2>&1; then
    printf 'zipped\n' >"$c/work/z.txt"
    ( cd "$c/work" && python3 -c 'import zipfile; z=zipfile.ZipFile("a.zip","w"); z.write("z.txt"); z.close()' )
    mkdir -p "$c/work/out-zip"
    run_lib "$c" extract_archive "$c/work/a.zip" "$c/work/out-zip"
    assert_success "$RUN_RC" "zip extracts cleanly"
    assert_file "$c/work/out-zip/z.txt" "member extracted"
else
    skip "unzip not installed"
fi

describe "extract_archive: rejects unsupported format"
c="$(sandbox extract-bad)"
: >"$c/work/a.rar"
run_lib "$c" extract_archive "$c/work/a.rar" "$c/work"
assert_failure "$RUN_RC" "returns non-zero"
assert_contains "Unsupported archive format" "$RUN_ERR" "emits diagnostic"

# ---------------------------------------------------------------------------
# install_binary_from_archive_candidates
# ---------------------------------------------------------------------------
describe "install_binary_from_archive_candidates: skips a missing candidate, installs from the next"
c="$(sandbox cand-fallback)"
# Prebuild an archive whose second candidate name contains the binary.
mkdir -p "$c/work/pkg/inner"
printf '#!/usr/bin/env bash\necho mybin\n' >"$c/work/pkg/inner/mybin"
chmod +x "$c/work/pkg/inner/mybin"
tar -czf "$c/work/mybin-musl.tar.gz" -C "$c/work/pkg" inner
stub "$c/fakebin" curl <<EOF
#!/usr/bin/env bash
out=""; url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in -o) out="\$2"; shift 2 ;; http*) url="\$1"; shift ;; *) shift ;; esac
done
case "\$url" in
  */mybin-gnu.tar.gz)  exit 22 ;;                       # first candidate: miss
  */mybin-musl.tar.gz) cp "$c/work/mybin-musl.tar.gz" "\$out"; exit 0 ;;
esac
exit 1
EOF
run_lib "$c" install_binary_from_archive_candidates \
    mybin mybin https://example.test/dl mybin-gnu.tar.gz mybin-musl.tar.gz
assert_success "$RUN_RC" "installs from the second candidate"
assert_executable "$c/home/.local/bin/mybin" "binary installed to LOCAL_BIN"
assert_contains "mybin installed" "$RUN_OUT" "reports success"

describe "install_binary_from_archive_candidates: fails when no archive holds the binary"
c="$(sandbox cand-miss)"
mkdir -p "$c/work/pkg2"
printf 'not the binary\n' >"$c/work/pkg2/other"
tar -czf "$c/work/only.tar.gz" -C "$c/work/pkg2" other
stub "$c/fakebin" curl <<EOF
#!/usr/bin/env bash
out=""
while [[ \$# -gt 0 ]]; do case "\$1" in -o) out="\$2"; shift 2 ;; *) shift ;; esac; done
cp "$c/work/only.tar.gz" "\$out"; exit 0
EOF
run_lib "$c" install_binary_from_archive_candidates \
    wanted wanted https://example.test/dl only.tar.gz
assert_failure "$RUN_RC" "returns non-zero"
assert_contains "Failed to locate wanted" "$RUN_ERR" "emits diagnostic"

# ---------------------------------------------------------------------------
# cargo_install_if_missing
# ---------------------------------------------------------------------------
describe "cargo_install_if_missing: no-op when the binary already exists"
c="$(sandbox cargo-present)"
stub "$c/fakebin" ripgrep-bin <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
# Put the target binary on PATH so command -v finds it.
cp "$c/fakebin/ripgrep-bin" "$c/fakebin/rg"
stub "$c/fakebin" cargo <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$c/work/cargo.log"
exit 0
EOF
: >"$c/work/cargo.log"
run_lib "$c" cargo_install_if_missing ripgrep rg
assert_success "$RUN_RC" "returns success"
assert_contains "already installed" "$RUN_OUT" "reports already installed"
assert_not_contains "install" "$c/work/cargo.log" "cargo was not invoked"

describe "cargo_install_if_missing: invokes cargo when the binary is missing"
c="$(sandbox cargo-missing)"
: >"$c/work/cargo.log"
stub "$c/fakebin" cargo <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$c/work/cargo.log"
exit 0
EOF
run_lib "$c" cargo_install_if_missing some-crate some-crate
assert_success "$RUN_RC" "returns success"
assert_contains "install --locked" "$c/work/cargo.log" "cargo install --locked invoked"
assert_contains "some-crate" "$c/work/cargo.log" "with the requested crate"

harness_summary
