#!/usr/bin/env bash
set -euo pipefail

info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
err()   { printf '\033[0;31m[ ERR]\033[0m  %s\n' "$*" >&2; }

LOCAL_BIN="$HOME/.local/bin"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARGO_INSTALL_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/cargo-install"
COMBINED_CA_PEM="$HOME/.aws/combined_cas.pem"
SKIP_PACKAGES="${SKIP_PACKAGES:-${SKIP_CARGO_PACKAGES:-}}"
FAILED_OPTIONAL_PACKAGES=()

require_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        err "This installer currently targets Linux/WSL."
        exit 1
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        err "Missing required command: $1"
        exit 1
    fi
}

arch_slug() {
    case "$(uname -m)" in
        x86_64|amd64)
            printf '%s\n' 'x86_64'
            ;;
        aarch64|arm64)
            printf '%s\n' 'aarch64'
            ;;
        *)
            err "Unsupported architecture: $(uname -m)"
            exit 1
            ;;
    esac
}

apt_arch_slug() {
    case "$(arch_slug)" in
        x86_64) printf '%s\n' 'amd64' ;;
        aarch64) printf '%s\n' 'arm64' ;;
    esac
}

skip_package() {
    local candidate

    for candidate in "$@"; do
        [[ " $SKIP_PACKAGES " == *" $candidate "* ]] && return 0
    done

    return 1
}

record_failure() {
    local package="$1"
    local reason="$2"

    warn "Skipping $package after install failure ($reason)"
    FAILED_OPTIONAL_PACKAGES+=("$package")
}

curl_download() {
    local url="$1"
    local dest="$2"
    local -a args=(
        -fsSL
        --retry 3
        --retry-delay 2
        --connect-timeout 15
    )

    if [[ -f "$COMBINED_CA_PEM" ]]; then
        args+=(--cacert "$COMBINED_CA_PEM")
    fi

    curl "${args[@]}" -o "$dest" "$url"
}

curl_stdout() {
    local url="$1"
    local -a args=(
        -fsSL
        --retry 3
        --retry-delay 2
        --connect-timeout 15
    )

    if [[ -f "$COMBINED_CA_PEM" ]]; then
        args+=(--cacert "$COMBINED_CA_PEM")
    fi

    curl "${args[@]}" "$url"
}

curl_effective_url() {
    local url="$1"
    local -a args=(
        -fsSL
        --retry 3
        --retry-delay 2
        --connect-timeout 15
    )

    if [[ -f "$COMBINED_CA_PEM" ]]; then
        args+=(--cacert "$COMBINED_CA_PEM")
    fi

    curl "${args[@]}" -o /dev/null -w '%{url_effective}' "$url"
}

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

install_apt_packages() {
    local packages=(
        build-essential
        ca-certificates
        cargo
        curl
        gzip
        jq
        less
        libssl-dev
        pkg-config
        tar
        unzip
        xz-utils
        zlib1g-dev
    )

    if ! skip_package direnv; then
        packages+=(direnv)
    fi
    if ! skip_package delta git-delta; then
        packages+=(git-delta)
    fi
    if ! skip_package git-absorb; then
        packages+=(git-absorb)
    fi
    if ! skip_package hyperfine; then
        packages+=(hyperfine)
    fi
    if ! skip_package just; then
        packages+=(just)
    fi
    if ! skip_package timewarrior timew; then
        packages+=(timewarrior)
    fi
    if ! skip_package mosh; then
        packages+=(mosh)
    fi
    if ! skip_package rga ripgrep-all ripgrep_all; then
        packages+=(
            ffmpeg
            pandoc
            poppler-utils
            ripgrep
        )
    fi

    info "Installing apt packages for CLI extensions..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq "${packages[@]}"
    ok "apt packages ready"
}

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

    if [[ -f "$COMBINED_CA_PEM" ]]; then
        cargo_env+=(
            "CARGO_HTTP_CAINFO=$COMBINED_CA_PEM"
            "SSL_CERT_FILE=$COMBINED_CA_PEM"
            "CURL_CA_BUNDLE=$COMBINED_CA_PEM"
        )
    fi

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

install_atuin() {
    local tag asset_arch base_url

    if command -v atuin >/dev/null 2>&1; then
        ok "atuin already installed"
        return 0
    fi

    case "$(arch_slug)" in
        x86_64) asset_arch='x86_64-unknown-linux-gnu' ;;
        aarch64) asset_arch='aarch64-unknown-linux-gnu' ;;
    esac

    tag="$(resolve_github_latest_tag "atuinsh/atuin")"
    base_url="https://github.com/atuinsh/atuin/releases/download/${tag}"

    info "Installing atuin ${tag} from official release..."
    install_binary_from_archive_candidates \
        "atuin" \
        "atuin" \
        "$base_url" \
        "atuin-${asset_arch}.tar.gz"
}

tealdeer_version() {
    if ! command -v tldr >/dev/null 2>&1; then
        return 1
    fi

    tldr --version 2>/dev/null | awk 'NR == 1 { print $2 }'
}

install_tealdeer() {
    local tag version current_version asset_arch url tmp

    tag="$(resolve_github_latest_tag "tealdeer-rs/tealdeer")"
    version="${tag#v}"
    current_version="$(tealdeer_version || true)"

    if [[ "$current_version" == "$version" ]]; then
        ok "tealdeer ${version} already installed"
        return 0
    fi

    case "$(arch_slug)" in
        x86_64) asset_arch='x86_64' ;;
        aarch64) asset_arch='aarch64' ;;
    esac

    url="https://github.com/tealdeer-rs/tealdeer/releases/download/${tag}/tealdeer-linux-${asset_arch}-musl"
    tmp="$(mktemp)"

    info "Installing tealdeer ${tag} from official release..."
    curl_download "$url" "$tmp"
    install -m 0755 "$tmp" "$LOCAL_BIN/tldr-real"
    install -m 0755 "$DOTFILES_DIR/bin/tldr" "$LOCAL_BIN/tldr"
    ln -sfn "$LOCAL_BIN/tldr" "$LOCAL_BIN/tealdeer"
    rm -f "$tmp"
    ok "tealdeer installed"
}

yq_is_v4() {
    local version_output

    if ! command -v yq >/dev/null 2>&1; then
        return 1
    fi

    version_output="$(yq --version 2>/dev/null || true)"
    [[ "$version_output" == *" version v4."* || "$version_output" == *" version 4."* || "$version_output" == *" v4."* ]]
}

install_yq() {
    local arch url tmp

    if yq_is_v4; then
        ok "yq already installed"
        return 0
    fi

    case "$(apt_arch_slug)" in
        amd64) arch='amd64' ;;
        arm64) arch='arm64' ;;
    esac

    url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}"
    tmp="$(mktemp)"

    info "Installing yq v4 from official release..."
    curl_download "$url" "$tmp"
    install -m 0755 "$tmp" "$LOCAL_BIN/yq"
    rm -f "$tmp"
    ok "yq installed"
}

install_glab() {
    local tag version arch base_url

    if command -v glab >/dev/null 2>&1; then
        ok "glab already installed"
        return 0
    fi

    arch="$(apt_arch_slug)"

    tag="$(resolve_gitlab_latest_tag)"
    version="${tag#v}"
    base_url="https://gitlab.com/gitlab-org/cli/-/releases/${tag}/downloads"

    info "Installing glab ${tag} from official release..."
    if install_binary_from_archive_candidates \
        "glab" \
        "glab" \
        "$base_url" \
        "glab_${version}_linux_${arch}.tar.gz"
    then
        return 0
    fi

    warn "Official glab release install failed; falling back to Ubuntu package"
    sudo apt-get install -y -qq glab
    ok "glab installed from apt fallback"
}

install_watchexec() {
    local tag version asset_arch base_url

    if command -v watchexec >/dev/null 2>&1; then
        ok "watchexec already installed"
        return 0
    fi

    case "$(arch_slug)" in
        x86_64) asset_arch='x86_64' ;;
        aarch64) asset_arch='aarch64' ;;
    esac

    tag="$(resolve_github_latest_tag "watchexec/watchexec")"
    version="${tag#v}"
    base_url="https://github.com/watchexec/watchexec/releases/download/${tag}"

    info "Installing watchexec ${tag} from official release..."
    install_binary_from_archive_candidates \
        "watchexec" \
        "watchexec" \
        "$base_url" \
        "watchexec-${version}-${asset_arch}-unknown-linux-musl.tar.xz" \
        "watchexec-${version}-${asset_arch}-unknown-linux-gnu.tar.xz"
}

install_rga() {
    local tag asset_arch base_url

    if command -v rga >/dev/null 2>&1; then
        ok "rga already installed"
        return 0
    fi

    case "$(arch_slug)" in
        x86_64) asset_arch='x86_64' ;;
        aarch64) asset_arch='aarch64' ;;
    esac

    tag="$(resolve_github_latest_tag "phiresky/ripgrep-all")"
    base_url="https://github.com/phiresky/ripgrep-all/releases/download/${tag}"

    info "Installing rga ${tag} from official release..."
    install_binary_from_archive_candidates \
        "rga" \
        "rga" \
        "$base_url" \
        "ripgrep_all-${tag}-${asset_arch}-unknown-linux-musl.tar.gz" \
        "ripgrep_all-${tag}-${asset_arch}-unknown-linux-gnu.tar.gz"
}

install_git_branchless() {
    local tag asset_arch base_url

    if command -v git-branchless >/dev/null 2>&1; then
        ok "git-branchless already installed"
        return 0
    fi

    case "$(arch_slug)" in
        x86_64) asset_arch='x86_64' ;;
        aarch64) asset_arch='aarch64' ;;
    esac

    tag="$(resolve_github_latest_tag "arxanas/git-branchless")"
    base_url="https://github.com/arxanas/git-branchless/releases/download/${tag}"

    info "Installing git-branchless ${tag} from official release..."
    install_binary_from_archive_candidates \
        "git-branchless" \
        "git-branchless" \
        "$base_url" \
        "git-branchless-${tag}-${asset_arch}-unknown-linux-musl.tar.gz" \
        "git-branchless-${tag}-${asset_arch}-unknown-linux-gnu.tar.gz"
}

refresh_tealdeer_cache() {
    if command -v tldr >/dev/null 2>&1; then
        info "Refreshing tealdeer cache..."
        if tldr --update >/dev/null 2>&1; then
            ok "tealdeer cache updated"
        else
            warn "tealdeer cache update failed; run \`tldr --update\` later"
        fi
    fi
}

main() {
    require_linux
    require_command sudo
    require_command curl

    mkdir -p "$LOCAL_BIN"
    export PATH="$LOCAL_BIN:$PATH"

    install_apt_packages

    if [[ -f "$HOME/.cargo/env" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
    fi

    if skip_package atuin; then
        warn "Skipping atuin because it was listed in SKIP_PACKAGES"
    elif ! install_atuin; then
        record_failure "atuin" "shell history search and recall"
    fi

    if skip_package tealdeer tldr; then
        warn "Skipping tealdeer because it was listed in SKIP_PACKAGES"
    elif ! install_tealdeer; then
        record_failure "tealdeer" "tldr pages and cheat-sheet cache"
    fi

    if skip_package yq; then
        warn "Skipping yq because it was listed in SKIP_PACKAGES"
    elif ! install_yq; then
        record_failure "yq" "YAML processing"
    fi

    if skip_package glab; then
        warn "Skipping glab because it was listed in SKIP_PACKAGES"
    elif ! install_glab; then
        record_failure "glab" "GitLab CLI"
    fi

    if skip_package watchexec watchexec-cli; then
        warn "Skipping watchexec because it was listed in SKIP_PACKAGES"
    elif ! install_watchexec; then
        warn "Official watchexec binary install failed; trying cargo build fallback"
        if ! cargo_install_if_missing "watchexec-cli" "watchexec"; then
            record_failure "watchexec" "rerun-on-change loops"
        fi
    fi

    if skip_package rga ripgrep-all ripgrep_all; then
        warn "Skipping rga because it was listed in SKIP_PACKAGES"
    elif ! install_rga; then
        warn "Official rga binary install failed; trying cargo build fallback"
        if ! cargo_install_if_missing "ripgrep_all" "rga"; then
            record_failure "rga" "search inside PDFs and other documents"
        fi
    fi

    if skip_package git-branchless; then
        warn "Skipping git-branchless because it was listed in SKIP_PACKAGES"
    elif ! install_git_branchless; then
        warn "Official git-branchless binary install failed; trying cargo build fallback"
        if ! cargo_install_if_missing "git-branchless" "git-branchless"; then
            record_failure "git-branchless" "stacked branch and rebase workflow"
        fi
    fi

    if skip_package tokenusage tu; then
        warn "Skipping tokenusage because it was listed in SKIP_PACKAGES"
    elif ! cargo_install_if_missing "tokenusage" "tu"; then
        record_failure "tokenusage" "LLM token-usage reports (claude/codex)"
    fi

    refresh_tealdeer_cache

    ok "CLI extensions installed"

    if (( ${#FAILED_OPTIONAL_PACKAGES[@]} > 0 )); then
        warn "Packages that failed and were skipped: ${FAILED_OPTIONAL_PACKAGES[*]}"
    fi

    cat <<'EOF'

Next steps:
  - Restart the shell with `exec zsh`
  - Run `atuin import auto` once if you want old history in Atuin
  - Use `direnv allow` inside repos that define `.envrc`
  - Run `glab auth login` before GitLab MR or pipeline work
  - Run `git config --global core.pager delta`
  - Run `git config --global interactive.diffFilter 'delta --color-only'`
  - Run `git config --global delta.navigate true`
  - Run `git branchless init` inside repos where you want branchless workflow support
  - To skip specific tools on rerun: SKIP_PACKAGES="git-branchless watchexec rga" ./install-cli-extensions.sh
EOF
}

main "$@"
