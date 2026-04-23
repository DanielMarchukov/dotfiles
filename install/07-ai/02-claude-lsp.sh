#!/usr/bin/env bash
# =============================================================================
# install/07-ai/02-claude-lsp.sh
#
# Configures Claude Code LSP plugins and ensures their backing language-
# server binaries are available. For each plugin, checks the required
# binary; installs via the appropriate channel (rustup / apt / npm /
# Mason symlink) when possible. Only plugins whose binary resolves are
# written to ~/.claude/settings.json's enabledPlugins — prevents
# enabled-but-broken entries.
#
# Handled marketplace plugins (all @claude-plugins-official):
#   rust-analyzer-lsp  — rust-analyzer       via rustup component
#   clangd-lsp         — clangd              via apt
#   pyright-lsp        — pyright             via npm
#   lua-lsp            — lua-language-server via apt (fallback: Mason symlink)
#   gopls-lsp          — gopls               (installed by 02-languages/03-go.sh)
#   jdtls-lsp          — jdtls               via Mason symlink
#   typescript-lsp     — typescript-language-server via npm
#
# Custom plugins sourced from install/07-ai/plugins/ (this repo acts as
# a filesystem marketplace named "dotfiles-lsp"):
#   bash-lsp      — bash-language-server      via Mason symlink
#   yaml-lsp      — yaml-language-server      via Mason symlink
#   marksman-lsp  — marksman                  via Mason symlink
#   neocmake-lsp  — neocmakelsp               via Mason symlink
#   json-lsp      — vscode-json-language-server via Mason symlink
#
# Idempotent. Safe to re-run.
# =============================================================================
set -euo pipefail

# Sourcing guard (dual-mode: works when sourced or executed)
if [[ -n "${_DOTFILES_CLAUDE_LSP_SH_LOADED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi
_DOTFILES_CLAUDE_LSP_SH_LOADED=1

# shellcheck source=../lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

require_linux
require_command jq

SETTINGS_FILE="$HOME/.claude/settings.json"
MASON_BIN="$HOME/.local/share/nvim/mason/bin"

# ---------------------------------------------------------------------------
# Binary-availability helpers
# ---------------------------------------------------------------------------
# Symlink a Mason-installed LSP binary into $LOCAL_BIN so it's on PATH.
# No-op if the Mason binary doesn't exist or the target already exists.
symlink_mason_lsp() {
    local name="$1"
    local src="$MASON_BIN/$name"
    local dst="$LOCAL_BIN/$name"
    if [[ -x "$src" && ! -e "$dst" ]]; then
        ln -sfn "$src" "$dst"
        ok "Linked $name from Mason to $dst"
    fi
}

# ---------------------------------------------------------------------------
# Ensure each LSP binary
# ---------------------------------------------------------------------------

# rust-analyzer — rustup component
if ! command -v rust-analyzer >/dev/null 2>&1; then
    if command -v rustup >/dev/null 2>&1; then
        info "Installing rust-analyzer via rustup component..."
        rustup component add rust-analyzer 2>/dev/null \
            && ok "rust-analyzer installed" \
            || warn "rustup component add rust-analyzer failed"
    else
        warn "rust-analyzer missing and rustup unavailable"
    fi
fi

# clangd — apt
if ! command -v clangd >/dev/null 2>&1; then
    info "Installing clangd via apt..."
    sudo apt-get install -y -qq clangd 2>/dev/null \
        && ok "clangd installed" \
        || warn "clangd apt install failed (non-fatal)"
fi

# pyright — npm
if ! command -v pyright >/dev/null 2>&1; then
    if command -v npm >/dev/null 2>&1; then
        info "Installing pyright via npm..."
        npm install -g pyright >/dev/null 2>&1 \
            && ok "pyright installed" \
            || warn "pyright npm install failed (non-fatal)"
    else
        warn "pyright missing and npm unavailable"
    fi
fi

# lua-language-server — apt first, then Mason fallback
if ! command -v lua-language-server >/dev/null 2>&1; then
    if apt-cache show lua-language-server &>/dev/null; then
        info "Installing lua-language-server via apt..."
        sudo apt-get install -y -qq lua-language-server 2>/dev/null \
            && ok "lua-language-server installed" \
            || warn "lua-language-server apt install failed"
    fi
    command -v lua-language-server >/dev/null 2>&1 || symlink_mason_lsp lua-language-server
fi

# gopls — installed by 02-languages/03-go.sh
if ! command -v gopls >/dev/null 2>&1; then
    warn "gopls missing — run install/02-languages/03-go.sh first"
fi

# jdtls — Mason symlink (Mason populated by 04-editors/03-neovim-plugins.sh)
if ! command -v jdtls >/dev/null 2>&1; then
    symlink_mason_lsp jdtls
fi

# typescript-language-server — npm
if ! command -v typescript-language-server >/dev/null 2>&1; then
    if command -v npm >/dev/null 2>&1; then
        info "Installing typescript-language-server via npm..."
        npm install -g typescript-language-server typescript >/dev/null 2>&1 \
            && ok "typescript-language-server installed" \
            || warn "typescript-language-server npm install failed (non-fatal)"
    else
        warn "typescript-language-server missing and npm unavailable"
    fi
fi

# Custom-plugin LSP binaries — all from Mason (no upstream Ubuntu/npm path)
for name in bash-language-server yaml-language-server marksman neocmakelsp vscode-json-language-server; do
    command -v "$name" >/dev/null 2>&1 || symlink_mason_lsp "$name"
done

# ---------------------------------------------------------------------------
# Register the dotfiles-lsp filesystem marketplace for custom plugins
# ---------------------------------------------------------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCAL_PLUGINS_DIR="$DOTFILES_DIR/install/07-ai/plugins"
KNOWN_MARKETPLACES="$HOME/.claude/plugins/known_marketplaces.json"

if [[ -f "$LOCAL_PLUGINS_DIR/.claude-plugin/marketplace.json" ]]; then
    mkdir -p "$(dirname "$KNOWN_MARKETPLACES")"
    [[ -f "$KNOWN_MARKETPLACES" ]] || echo '{}' > "$KNOWN_MARKETPLACES"
    now="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
    tmp="$(mktemp)"
    jq --arg path "$LOCAL_PLUGINS_DIR" --arg now "$now" '
        ."dotfiles-lsp" = {
            "source": { "source": "filesystem", "path": $path },
            "installLocation": $path,
            "lastUpdated": $now
        }
    ' "$KNOWN_MARKETPLACES" > "$tmp" && mv "$tmp" "$KNOWN_MARKETPLACES"
    ok "Registered dotfiles-lsp marketplace at $LOCAL_PLUGINS_DIR"

    # Claude Code normally COPIES marketplace plugins into its cache on
    # first scan, then serves from that stale copy. Replace each cache
    # slot with a symlink to the live repo source so every repo edit is
    # picked up by the next /reload-plugins without a re-install dance.
    CACHE_BASE="$HOME/.claude/plugins/cache/dotfiles-lsp"
    for plugin_dir in "$LOCAL_PLUGINS_DIR"/*/; do
        plugin_name="$(basename "$plugin_dir")"
        [[ "$plugin_name" == ".claude-plugin" ]] && continue
        [[ -f "$plugin_dir/.claude-plugin/plugin.json" ]] || continue
        version="$(jq -r '.version // "1.0.0"' "$plugin_dir/.claude-plugin/plugin.json")"
        cache_slot="$CACHE_BASE/$plugin_name/$version"
        mkdir -p "$(dirname "$cache_slot")"
        if [[ -L "$cache_slot" ]]; then
            ok "Cache symlink OK: $plugin_name@$version"
        else
            rm -rf "$cache_slot"
            ln -sfn "${plugin_dir%/}" "$cache_slot"
            ok "Linked cache slot $plugin_name@$version -> repo source"
        fi
    done
else
    warn "$LOCAL_PLUGINS_DIR/.claude-plugin/marketplace.json missing — skipping custom-plugin marketplace registration"
fi

# ---------------------------------------------------------------------------
# Enable plugins in ~/.claude/settings.json
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$SETTINGS_FILE")"
if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{}' > "$SETTINGS_FILE"
    ok "Initialized empty $SETTINGS_FILE"
fi

# Each entry: "<plugin_name>:<backing_binary>"
LSP_PLUGINS=(
    # Marketplace plugins (claude-plugins-official)
    "rust-analyzer-lsp@claude-plugins-official:rust-analyzer"
    "clangd-lsp@claude-plugins-official:clangd"
    "pyright-lsp@claude-plugins-official:pyright"
    "lua-lsp@claude-plugins-official:lua-language-server"
    "gopls-lsp@claude-plugins-official:gopls"
    "jdtls-lsp@claude-plugins-official:jdtls"
    "typescript-lsp@claude-plugins-official:typescript-language-server"
    # Custom plugins (dotfiles-lsp filesystem marketplace)
    "bash-lsp@dotfiles-lsp:bash-language-server"
    "yaml-lsp@dotfiles-lsp:yaml-language-server"
    "marksman-lsp@dotfiles-lsp:marksman"
    "neocmake-lsp@dotfiles-lsp:neocmakelsp"
    "json-lsp@dotfiles-lsp:vscode-json-language-server"
)

info "Updating enabledPlugins in $SETTINGS_FILE..."
for entry in "${LSP_PLUGINS[@]}"; do
    plugin_name="${entry%%:*}"
    binary="${entry##*:}"
    if command -v "$binary" >/dev/null 2>&1; then
        tmp="$(mktemp)"
        jq --arg name "$plugin_name" '.enabledPlugins[$name] = true' \
            "$SETTINGS_FILE" > "$tmp" && mv "$tmp" "$SETTINGS_FILE"
        ok "Enabled $plugin_name"
    else
        warn "Skipping $plugin_name — $binary not available"
    fi
done

ok "Claude LSP setup complete — reload plugins in active sessions: /reload-plugins"
