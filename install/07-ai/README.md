# 07-ai

AI-adjacent tooling: Claude Code MCP servers and the Python runner
they depend on.

## Scope

- `01-mcp.sh` — installs `uv` (Astral's Python tool runner) and
  registers three Claude Code MCP servers at user scope:
  - `basic-memory` (stdio via `uvx basic-memory mcp`) — markdown-based
    project memory; per-project vaults initialized manually with
    `basic-memory project add <name> .`.
  - `git` (stdio via `uvx mcp-server-git`) — lets Claude walk git
    history and diffs.
  - `context7` (HTTP) — up-to-date library docs; requires
    `CONTEXT7_API_KEY` in `~/.config/secrets/mcp.env` (mode 600,
    outside the dotfiles repo).

All registrations are idempotent: already-registered servers are
skipped. Missing API key warns and skips context7 only.

## Ordering

- Single step — no intra-bucket concerns.

## Needs from upstream buckets

- `01-system` — `curl` for the `uv` installer.

## External dependencies

- `claude` CLI must be installed separately by the user (bootstrap
  does not install it). If missing, `01-mcp.sh` warns and skips
  registration.
