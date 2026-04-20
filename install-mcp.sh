#!/usr/bin/env bash
# =============================================================================
# Claude Code MCP Server Installer
# Installs uv (Python tool runner) and registers MCP servers at user scope.
# Idempotent — safe to re-run. Invoked by bootstrap.sh or stand-alone.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
err()   { printf '\033[0;31m[ ERR]\033[0m  %s\n' "$*" >&2; }

MCP_SECRETS_FILE="${MCP_SECRETS_FILE:-$HOME/.config/secrets/mcp.env}"

# ---------------------------------------------------------------------------
# uv (Python tool runner — required for stdio MCP servers)
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

main() {
    install_uv
    register_mcp_servers
    ok "MCP setup complete"
}

main "$@"
