#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

make_common_stubs() {
  local fakebin="$1"
  local workdir="$2"

  mkdir -p "$fakebin" "$workdir"

  cat >"$fakebin/uname" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-s" ]]; then
  printf 'Linux\n'
elif [[ "$1" == "-m" ]]; then
  printf 'x86_64\n'
else
  /usr/bin/uname "$@"
fi
EOF
  chmod +x "$fakebin/uname"

  cat >"$fakebin/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
  chmod +x "$fakebin/sudo"
}

assert_contains() {
  local needle="$1"
  local file="$2"
  if ! grep -q "$needle" "$file"; then
    printf 'FAIL: expected %s in %s\n' "$needle" "$file" >&2
    exit 1
  fi
}

scenario_latest_tag_lookup_failure_falls_back_to_latest_download() {
  local case_dir="$TMPDIR/tag-fallback"
  local fakebin="$case_dir/fakebin"
  local workdir="$case_dir/work"
  local home_dir="$workdir/home"
  local local_bin="$home_dir/.local/bin"
  local logfile="$workdir/curl.log"
  local stdout="$workdir/stdout"
  local stderr="$workdir/stderr"

  mkdir -p "$local_bin"
  make_common_stubs "$fakebin" "$workdir"

  cat >"$fakebin/install" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mode=""
src=""
dest=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m)
      mode="$2"
      shift 2
      ;;
    *)
      if [[ -z "$src" ]]; then
        src="$1"
      elif [[ -z "$dest" ]]; then
        dest="$1"
      else
        printf 'unexpected install args\n' >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -n "$mode" ]]; then
  cp "$src" "$dest"
  chmod "$mode" "$dest"
else
  cp "$src" "$dest"
fi
EOF
  chmod +x "$fakebin/install"

  cat >"$fakebin/ln" <<'EOF'
#!/usr/bin/env bash
exec /usr/bin/ln "$@"
EOF
  chmod +x "$fakebin/ln"

  cat >"$fakebin/tldr" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "--version" ]]; then
  printf 'tealdeer 1.7.2\n'
  exit 0
fi
if [[ "\${1:-}" == "--update" ]]; then
  printf 'tldr --update\n' >>"$logfile"
  exit 0
fi
exec "$local_bin/tldr-real" "\$@"
EOF
  chmod +x "$fakebin/tldr"

  cat >"$fakebin/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$logfile"

output=""
url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o)
      output="\$2"
      shift 2
      ;;
    http*)
      url="\$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "\$url" == "https://api.github.com/repos/tealdeer-rs/tealdeer/releases/latest" ]]; then
  printf 'curl: (22) The requested URL returned error: 403\n' >&2
  exit 22
fi

if [[ "\$url" == "https://github.com/tealdeer-rs/tealdeer/releases/latest" ]]; then
  printf 'curl: (28) Resolving timed out after 15000 milliseconds\n' >&2
  exit 28
fi

if [[ "\$url" == "https://github.com/tealdeer-rs/tealdeer/releases/latest/download/tealdeer-linux-x86_64-musl" ]]; then
  cat >"\$output" <<'BINARY'
#!/usr/bin/env bash
if [[ "\${1:-}" == "--version" ]]; then
  printf 'tealdeer 1.7.2\n'
  exit 0
fi
printf 'fake tealdeer\n'
BINARY
  chmod +x "\$output"
  exit 0
fi

printf 'unexpected curl invocation: %s\n' "\$url" >&2
exit 1
EOF
  chmod +x "$fakebin/curl"

  HOME="$workdir/home" \
  PATH="$fakebin:/usr/bin:/bin" \
  "$ROOT_DIR/install/05-tools/05-tealdeer.sh" >"$stdout" 2>"$stderr" || {
    printf 'FAIL: tealdeer installer should succeed when latest tag lookup fails by downloading the latest asset alias directly\n' >&2
    cat "$stdout" >&2 || true
    cat "$stderr" >&2 || true
    exit 1
  }

  if [[ ! -x "$local_bin/tldr-real" ]]; then
    printf 'FAIL: expected installed tealdeer binary at %s\n' "$local_bin/tldr-real" >&2
    ls -l "$local_bin" >&2 || true
    cat "$stdout" >&2 || true
    cat "$stderr" >&2 || true
    exit 1
  fi

  assert_contains 'https://github.com/tealdeer-rs/tealdeer/releases/latest/download/tealdeer-linux-x86_64-musl' "$logfile"
}

scenario_latest_tag_lookup_failure_falls_back_to_latest_download
