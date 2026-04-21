#!/usr/bin/env bash
# =============================================================================
# install/05-tools/07-glab.sh
#
# Installs glab (GitLab CLI) from the official GitLab release. Falls
# back to the Ubuntu apt package if the release download fails.
#
# Split out from install-cli-extensions.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_GLAB_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_GLAB_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
# shellcheck source=../lib/downloads.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/downloads.sh"

require_linux
require_command curl
require_command jq
require_command sudo

if command -v glab >/dev/null 2>&1; then
    ok "glab already installed"
    exit 0
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
    exit 0
fi

warn "Official glab release install failed; falling back to Ubuntu package"
sudo apt-get install -y -qq glab
ok "glab installed from apt fallback"
