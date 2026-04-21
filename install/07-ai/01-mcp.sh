#!/usr/bin/env bash
# =============================================================================
# install/07-ai/01-mcp.sh
#
# Installs uv (Python tool runner) and registers Claude Code MCP
# servers at user scope. Idempotent — safe to re-run.
#
# Registers:
#   - basic-memory (stdio via `uvx basic-memory mcp`)
#   - git (stdio via `uvx mcp-server-git`)
#   - context7 (HTTP, requires CONTEXT7_API_KEY in mcp.env)
#
# Extracted from repo-root install-mcp.sh.
# =============================================================================
set -euo pipefail

if [[ -n "${_DOTFILES_MCP_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_MCP_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command curl

MCP_SECRETS_FILE="${MCP_SECRETS_FILE:-$HOME/.config/secrets/mcp.env}"

# ---------------------------------------------------------------------------
# uv install
# ---------------------------------------------------------------------------
install_uv() {
    if command -v uv &>/dev/null; then
        ok "uv: $(uv --version 2>&1)"
        return 0
    fi

    info "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
    export PATH="$HOME/.local/bin:$PATH"

    if command -v uv &>/dev/null; then
        ok "uv: $(uv --version 2>&1)"
    else
        err "uv install reported success but binary not on PATH"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# MCP server registration (user scope — shared across all projects)
# ---------------------------------------------------------------------------
register_mcp_stdio() {
    local name="$1"; shift
    if claude mcp list 2>/dev/null | grep -qE "^${name}:"; then
        ok "MCP: $name (already registered)"
    elif claude mcp add --scope user "$name" "$@" >/dev/null 2>&1; then
        ok "MCP: $name"
    else
        warn "MCP: $name registration failed (non-fatal)"
    fi
}

register_mcp_http() {
    local name="$1" url="$2"; shift 2
    if claude mcp list 2>/dev/null | grep -qE "^${name}:"; then
        ok "MCP: $name (already registered)"
    elif claude mcp add --scope user --transport http "$name" "$url" "$@" >/dev/null 2>&1; then
        ok "MCP: $name"
    else
        warn "MCP: $name registration failed (non-fatal)"
    fi
}

register_mcp_servers() {
    if ! command -v claude &>/dev/null; then
        warn "claude CLI not found; skipping MCP registration"
        return 0
    fi
    if ! command -v uv &>/dev/null; then
        warn "uv not available; skipping MCP registration"
        return 0
    fi

    info "Registering Claude Code MCP servers (user scope)..."
    export PATH="$HOME/.local/bin:$PATH"

    register_mcp_stdio basic-memory uvx basic-memory mcp
    register_mcp_stdio git uvx mcp-server-git

    # Load optional secrets file (outside dotfiles repo — never committed)
    if [[ -f "$MCP_SECRETS_FILE" ]]; then
        # shellcheck source=/dev/null
        set -a; source "$MCP_SECRETS_FILE"; set +a
    fi

    if [[ -n "${CONTEXT7_API_KEY:-}" ]]; then
        register_mcp_http context7 https://mcp.context7.com/mcp \
            --header "CONTEXT7_API_KEY: $CONTEXT7_API_KEY"
    elif claude mcp list 2>/dev/null | grep -qE '^context7:'; then
        ok "MCP: context7 (already registered)"
    else
        warn "MCP: context7 not registered — set CONTEXT7_API_KEY in $MCP_SECRETS_FILE"
    fi
}

install_uv
register_mcp_servers
ok "MCP setup complete"
