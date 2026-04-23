#!/usr/bin/env bash
# =============================================================================
# install/lib/downloads.sh
#
# Network, archive, and cargo-install helpers. Depends on common.sh —
# source common.sh first, then this.
#   source "$(dirname "$0")/lib/common.sh"
#   source "$(dirname "$0")/lib/downloads.sh"
#
# Provides: curl helpers with retry, GitHub/GitLab release-tag
# resolution, archive extraction, binary install from release artifacts,
# cargo-install with retry.
# =============================================================================

# Sourcing guard
[[ -n "${_DOTFILES_DOWNLOADS_SH_LOADED:-}" ]] && return 0
_DOTFILES_DOWNLOADS_SH_LOADED=1

CARGO_INSTALL_CACHE_DIR="${CARGO_INSTALL_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/cargo-install}"

# ---------------------------------------------------------------------------
# curl helpers
# ---------------------------------------------------------------------------
curl_download() {
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 -o "$2" "$1"
}

curl_stdout() {
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 "$1"
}

curl_effective_url() {
    curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 \
        -o /dev/null -w '%{url_effective}' "$1"
}

# ---------------------------------------------------------------------------
# Release-tag resolution
# ---------------------------------------------------------------------------
resolve_github_latest_tag() {
    local repo="$1"
    local latest_url effective_url tag

    latest_url="https://github.com/${repo}/releases/latest"
    effective_url="$(curl_effective_url "$latest_url")"
    tag="${effective_url##*/}"

    if [[ -z "$tag" || "$tag" == "latest" ]]; then
        err "Failed to resolve latest release tag for ${repo}"
        return 1
    fi

    printf '%s\n' "$tag"
}

resolve_gitlab_latest_tag() {
    local release_json tag

    release_json="$(curl_stdout "https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest")"
    tag="$(printf '%s' "$release_json" | jq -r '.tag_name')"

    if [[ -z "$tag" || "$tag" == "null" ]]; then
        err "Failed to resolve latest release tag for gitlab-org/cli"
        return 1
    fi

    printf '%s\n' "$tag"
}

# ---------------------------------------------------------------------------
# Archive handling
# ---------------------------------------------------------------------------
extract_archive() {
    local archive_path="$1"
    local destination="$2"

    case "$archive_path" in
        *.tar.gz|*.tgz)
            tar -xzf "$archive_path" -C "$destination"
            ;;
        *.tar.xz|*.txz)
            tar -xJf "$archive_path" -C "$destination"
            ;;
        *.zip)
            unzip -q "$archive_path" -d "$destination"
            ;;
        *)
            err "Unsupported archive format: $archive_path"
            return 1
            ;;
    esac
}

# Try each archive_name in order; extract and install the first that contains
# the target binary. Used for GitHub release artifacts with multiple naming
# conventions (musl vs gnu, etc).
install_binary_from_archive_candidates() {
    local package="$1"
    local binary="$2"
    local base_url="$3"
    shift 3

    local tmp_dir archive_name archive_path extracted_path

    tmp_dir="$(mktemp -d)"

    for archive_name in "$@"; do
        archive_path="$tmp_dir/$archive_name"

        if ! curl_download "${base_url}/${archive_name}" "$archive_path"; then
            rm -f "$archive_path"
            continue
        fi

        extract_archive "$archive_path" "$tmp_dir"
        extracted_path="$(find "$tmp_dir" -type f -name "$binary" | head -1)"
        if [[ -n "$extracted_path" ]]; then
            install -m 0755 "$extracted_path" "$LOCAL_BIN/$binary"
            rm -rf "$tmp_dir"
            ok "$package installed"
            return 0
        fi
    done

    rm -rf "$tmp_dir"
    err "Failed to locate $binary in downloaded release artifacts"
    return 1
}

# ---------------------------------------------------------------------------
# Cargo install with retry
# ---------------------------------------------------------------------------
cargo_install_if_missing() {
    local package="$1"
    local binary="$2"
    local target_dir="$CARGO_INSTALL_CACHE_DIR/$package"
    local attempt
    local max_attempts=3
    local -a cargo_env=(
        "CARGO_HTTP_TIMEOUT=${CARGO_HTTP_TIMEOUT:-120}"
        "CARGO_NET_RETRY=${CARGO_NET_RETRY:-10}"
        "CARGO_NET_GIT_FETCH_WITH_CLI=${CARGO_NET_GIT_FETCH_WITH_CLI:-true}"
        "CARGO_REGISTRIES_CRATES_IO_PROTOCOL=${CARGO_REGISTRIES_CRATES_IO_PROTOCOL:-sparse}"
        "CARGO_HTTP_MULTIPLEXING=${CARGO_HTTP_MULTIPLEXING:-false}"
    )

    if command -v "$binary" >/dev/null 2>&1; then
        ok "$binary already installed"
        return 0
    fi

    mkdir -p "$target_dir"

    for attempt in $(seq 1 "$max_attempts"); do
        info "Installing $package via cargo (attempt $attempt/$max_attempts)..."
        if env "${cargo_env[@]}" cargo install --locked --target-dir "$target_dir" "$package"; then
            ok "$binary installed"
            return 0
        fi

        if (( attempt < max_attempts )); then
            warn "cargo install failed for $package; retrying after a short pause"
            sleep $((attempt * 5))
        fi
    done

    err "Failed to install $package after $max_attempts attempts"
    return 1
}
