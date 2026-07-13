#!/usr/bin/env bash
# =============================================================================
# Neovim installer / updater
# Installs or upgrades Neovim to the latest stable GitHub release tarball.
# Idempotent — safe to re-run; skips work when already on the latest version.
# Invoked by install/04-editors/01-neovim.sh or stand-alone. Requires sudo.
#
#   ./install-nvim.sh                 # install or upgrade to latest stable
#   NVIM_CHANNEL=nightly ./install-nvim.sh   # track the nightly prerelease
#   NVIM_FORCE=1 ./install-nvim.sh    # reinstall even if already up to date
# =============================================================================

# Sourcing guard (repo convention): prevent double-init / circular sourcing.
# Dual-mode so `return` doesn't error when the script is executed directly.
if [[ -n "${_DOTFILES_INSTALL_NVIM_SH_LOADED:-}" ]]; then
    # shellcheck disable=SC2317  # reachable when sourced; return falls through to exit
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_INSTALL_NVIM_SH_LOADED=1

set -euo pipefail

info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
err()   { printf '\033[0;31m[ ERR]\033[0m  %s\n' "$*" >&2; }

NVIM_INSTALL_ROOT="${NVIM_INSTALL_ROOT:-/opt}"
NVIM_SYMLINK="${NVIM_SYMLINK:-/usr/local/bin/nvim}"
NVIM_CHANNEL="${NVIM_CHANNEL:-stable}"   # stable | nightly
NVIM_FORCE="${NVIM_FORCE:-0}"

# Global so the EXIT trap can see it after main() returns (a `local` would be
# out of scope by then and trip `set -u`).
NVIM_TMPDIR=""
cleanup() { [[ -n "$NVIM_TMPDIR" ]] && rm -rf "$NVIM_TMPDIR"; return 0; }
trap cleanup EXIT

nvim_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  printf 'linux-x86_64\n' ;;
        aarch64|arm64) printf 'linux-arm64\n' ;;
        *) err "Unsupported architecture: $(uname -m)"; exit 1 ;;
    esac
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || { err "Missing required command: $1"; exit 1; }
}

curl_common_args() {
    printf '%s\n' \
        "-fsSL" \
        "--retry" "5" \
        "--retry-delay" "2" \
        "--retry-all-errors" \
        "--connect-timeout" "30" \
        "-H" "Accept: application/vnd.github+json" \
        "-H" "User-Agent: dotfiles-install-nvim"
}

github_curl_stdout() {
    local -a args
    mapfile -t args < <(curl_common_args)
    curl "${args[@]}" "$1"
}

github_curl_download() {
    local destination="$1"
    local url="$2"
    local -a args
    mapfile -t args < <(curl_common_args)
    curl "${args[@]}" -o "$destination" "$url"
}

extract_release_version() {
    local release_json="$1"
    local version

    version="$(
        printf '%s' "$release_json" \
            | jq -r '.body' \
            | grep -m1 -oE 'NVIM v[^[:space:]]+' \
            | awk '{ print $2 }'
    )" || true

    if [[ -n "$version" ]]; then
        printf '%s\n' "$version"
        return 0
    fi

    version="$(printf '%s' "$release_json" | jq -r '.tag_name')" || true
    if [[ "$version" == v* ]]; then
        printf '%s\n' "$version"
    fi
}

main() {
    [[ "$(uname -s)" == "Linux" ]] || { err "This updater targets Linux/WSL."; exit 1; }
    require_command curl
    require_command jq
    require_command tar

    local arch tarball current api_url release_json release_tag release_version release_label
    arch="$(nvim_arch)"                       # e.g. linux-x86_64
    tarball="nvim-${arch}.tar.gz"

    if [[ "$NVIM_CHANNEL" == "nightly" ]]; then
        api_url="https://api.github.com/repos/neovim/neovim/releases/tags/nightly"
        release_tag="nightly"
    else
        api_url="https://api.github.com/repos/neovim/neovim/releases/latest"
        release_tag="stable"
    fi

    info "Querying latest Neovim ${NVIM_CHANNEL} release..."
    release_json=""
    release_version=""
    if release_json="$(github_curl_stdout "$api_url" 2>/dev/null)"; then
        release_tag="$(printf '%s' "$release_json" | jq -r '.tag_name')"
        release_version="$(extract_release_version "$release_json")"
    else
        warn "GitHub API lookup failed; falling back to direct ${NVIM_CHANNEL} channel download"
    fi
    [[ -n "$release_tag" && "$release_tag" != "null" ]] || { err "Could not determine latest release tag."; exit 1; }
    release_label="${release_version:-$release_tag}"

    # Read the currently-installed version without letting `head` close the pipe
    # early (which would SIGPIPE nvim and trip pipefail).
    if command -v nvim >/dev/null 2>&1; then
        local version_line
        version_line="$(nvim --version)"
        current="v$(printf '%s\n' "$version_line" | sed -nE '1s/^NVIM v?//p')"
        if [[ -n "$release_version" && "$current" == "$release_version" && "$NVIM_FORCE" != "1" ]]; then
            ok "Neovim already up to date ($current)"
            return 0
        fi
        info "Upgrading Neovim ${current} -> ${release_label}"
    else
        info "Installing Neovim ${release_label}"
    fi

    NVIM_TMPDIR="$(mktemp -d)"

    info "Downloading ${tarball} (${release_label})..."
    github_curl_download "$NVIM_TMPDIR/$tarball" \
        "https://github.com/neovim/neovim/releases/download/${release_tag}/${tarball}"

    info "Installing to ${NVIM_INSTALL_ROOT}/nvim-${arch} (sudo)..."
    sudo rm -rf "${NVIM_INSTALL_ROOT:?}/nvim-${arch}"
    sudo tar xzf "$NVIM_TMPDIR/$tarball" -C "$NVIM_INSTALL_ROOT"
    sudo ln -sf "${NVIM_INSTALL_ROOT}/nvim-${arch}/bin/nvim" "$NVIM_SYMLINK"

    hash -r 2>/dev/null || true
    ok "Neovim $(nvim --version | sed -nE '1s/^NVIM //p') installed at ${NVIM_SYMLINK}"
}

main "$@"
