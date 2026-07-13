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

  cat >"$fakebin/jq" <<'EOF'
#!/usr/bin/env bash
python3 -c '
import json
import sys

query = sys.argv[-1]
data = json.load(sys.stdin)

if query == ".tag_name":
    print(data["tag_name"])
elif query == ".body":
    print(data["body"])
else:
    raise SystemExit(f"unsupported jq query: {query}")
' "$@"
EOF
  chmod +x "$fakebin/jq"

  cat >"$fakebin/sudo" <<'EOF'
#!/usr/bin/env bash
"$@"
EOF
  chmod +x "$fakebin/sudo"
}

make_tarball() {
  local tarball="$1"
  local payload_dir="$2"

  mkdir -p "$payload_dir/nvim-linux-x86_64/bin"
  cat >"$payload_dir/nvim-linux-x86_64/bin/nvim" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'NVIM v0.12.4\n'
  exit 0
fi
printf 'fake nvim\n'
EOF
  chmod +x "$payload_dir/nvim-linux-x86_64/bin/nvim"
  tar -czf "$tarball" -C "$payload_dir" nvim-linux-x86_64
}

assert_contains() {
  local needle="$1"
  local file="$2"
  if ! grep -q "$needle" "$file"; then
    printf 'FAIL: expected %s in %s\n' "$needle" "$file" >&2
    exit 1
  fi
}

scenario_api_403_falls_back_to_channel_alias_download() {
  local case_dir="$TMPDIR/api-403-fallback"
  local fakebin="$case_dir/fakebin"
  local workdir="$case_dir/work"
  local install_root="$workdir/install-root"
  local local_bin="$workdir/local-bin"
  local logfile="$workdir/curl.log"
  local stdout="$workdir/stdout"
  local stderr="$workdir/stderr"

  mkdir -p "$install_root" "$local_bin"
  make_common_stubs "$fakebin" "$workdir"
  make_tarball "$case_dir/nvim-linux-x86_64.tar.gz" "$case_dir/payload"

  cat >"$fakebin/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$logfile"

output=""
write_url_effective=0
url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o)
      output="\$2"
      shift 2
      ;;
    -w)
      if [[ "\$2" == "%{url_effective}" ]]; then
        write_url_effective=1
      fi
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

if [[ "\$url" == "https://api.github.com/repos/neovim/neovim/releases/latest" ]]; then
  printf 'curl: (22) The requested URL returned error: 403\n' >&2
  exit 22
fi

if [[ "\$url" == "https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz" ]]; then
  cp "$case_dir/nvim-linux-x86_64.tar.gz" "\$output"
  exit 0
fi

if [[ "\$url" == "https://github.com/neovim/neovim/releases/latest" ]]; then
  printf 'curl: (28) Resolving timed out after 15001 milliseconds\n' >&2
  exit 28
fi

printf 'unexpected curl invocation: %s\n' "\$url" >&2
exit 1
EOF
  chmod +x "$fakebin/curl"

  PATH="$fakebin:$local_bin:/usr/bin:/bin" \
  NVIM_INSTALL_ROOT="$install_root" \
  NVIM_SYMLINK="$local_bin/nvim" \
  "$ROOT_DIR/install-nvim.sh" >"$stdout" 2>"$stderr" || {
    printf 'FAIL: install-nvim.sh should succeed when GitHub API latest returns 403 by downloading the stable alias directly\n' >&2
    cat "$stdout" >&2 || true
    cat "$stderr" >&2 || true
    exit 1
  }

  if [[ ! -e "$local_bin/nvim" ]] || ! "$local_bin/nvim" --version >/dev/null 2>&1; then
    printf 'FAIL: expected runnable installed nvim at %s\n' "$local_bin/nvim" >&2
    ls -l "$local_bin" >&2 || true
    find "$install_root" -maxdepth 3 -type f | sort >&2 || true
    cat "$stdout" >&2 || true
    cat "$stderr" >&2 || true
    exit 1
  fi

  assert_contains 'https://github.com/neovim/neovim/releases/download/stable/nvim-linux-x86_64.tar.gz' "$logfile"

  if grep -q 'https://github.com/neovim/neovim/releases/latest' "$logfile"; then
    printf 'FAIL: installer should not query releases/latest redirect when API lookup fails\n' >&2
    cat "$logfile" >&2 || true
    exit 1
  fi
}

scenario_stable_tag_uses_release_body_version_for_idempotence() {
  local case_dir="$TMPDIR/stable-idempotence"
  local fakebin="$case_dir/fakebin"
  local workdir="$case_dir/work"
  local install_root="$workdir/install-root"
  local local_bin="$workdir/local-bin"
  local logfile="$workdir/curl.log"
  local stdout="$workdir/stdout"
  local stderr="$workdir/stderr"

  mkdir -p "$install_root" "$local_bin"
  make_common_stubs "$fakebin" "$workdir"

  cat >"$local_bin/nvim" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'NVIM v0.12.4\n'
  exit 0
fi
printf 'existing fake nvim\n'
EOF
  chmod +x "$local_bin/nvim"

  cat >"$fakebin/curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"$logfile"

url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    http*)
      url="\$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "\$url" == "https://api.github.com/repos/neovim/neovim/releases/latest" ]]; then
  cat <<'JSON'
{"tag_name":"stable","body":"NVIM v0.12.4\nBuild type: Release"}
JSON
  exit 0
fi

printf 'unexpected curl invocation: %s\n' "\$url" >&2
exit 1
EOF
  chmod +x "$fakebin/curl"

  PATH="$fakebin:$local_bin:/usr/bin:/bin" \
  NVIM_INSTALL_ROOT="$install_root" \
  NVIM_SYMLINK="$local_bin/nvim" \
  "$ROOT_DIR/install-nvim.sh" >"$stdout" 2>"$stderr" || {
    printf 'FAIL: install-nvim.sh should treat stable release body version as current\n' >&2
    cat "$logfile" >&2 || true
    sed -n '1,220p' "$fakebin/curl" >&2 || true
    cat "$stdout" >&2 || true
    cat "$stderr" >&2 || true
    exit 1
  }

  assert_contains 'Neovim already up to date (v0.12.4)' "$stdout"

  if grep -q 'releases/download/' "$logfile"; then
    printf 'FAIL: installer should not download when current version already matches stable release body\n' >&2
    exit 1
  fi
}

scenario_api_403_falls_back_to_channel_alias_download
scenario_stable_tag_uses_release_body_version_for_idempotence
