# Dotfiles bootstrap modularization plan

Record of decisions, findings, and execution plan for splitting the
monolithic `bootstrap.sh` into per-step modules under `install/`.

## Goal

Convert `bootstrap.sh` from a ~775-line linear script into a thin
orchestrator (~50 lines) that invokes small, individually-runnable
`install/*/*.sh` scripts — one per concrete setup step — grouped into
semantic buckets.

Motivations:

- Traceability: one commit per extraction; blame scopes to a concern.
- Isolated re-runs: `./install/02-languages/07-rust.sh` to refresh Rust
  without touching anything else.
- Lower cognitive load when modifying a single concern.
- Shared helpers in `install/lib/` instead of copy-pasted across scripts.

## Migration methodology — parallel-implementation pattern

This is load-bearing and non-negotiable:

1. **Nothing is removed from `bootstrap.sh` or `install-cli-extensions.sh`
   during extraction.** Both legacy entry points remain fully functional
   at every commit.
2. **Duplicate intentionally.** Extracted code coexists with its inline
   ancestor. Not a smell — the point.
3. **New modules are used only by new code** (subsequent extracted
   scripts) until all extractions are complete.
4. **The legacy entry points are swapped/deleted at the very last step**,
   in a dedicated commit, after every per-step script exists and has
   been verified.

Why: touching working code mid-migration causes silent breakage. Keeping
the old path green at every commit means each extraction is independently
reviewable and reversible.

## Target directory layout

```
dotfiles/
├── bootstrap.sh                     # final state: ~50-line orchestrator
└── install/
    ├── plan.md                      # this file
    ├── lib/
    │   ├── common.sh                # logging, platform, PATH/env, fs
    │   └── downloads.sh             # curl, archive, release tags, cargo
    ├── 01-system/
    │   └── 01-packages.sh
    ├── 02-languages/
    │   ├── 01-temurin-jdk.sh
    │   ├── 02-installcert-java.sh   # optional — gates on file presence
    │   ├── 03-go.sh
    │   ├── 04-cpp-toolchain.sh
    │   ├── 05-gradle.sh
    │   ├── 06-palantir-java-format.sh
    │   ├── 07-rust.sh
    │   └── 08-node.sh
    ├── 03-dotfiles/
    │   ├── 01-repo.sh
    │   ├── 02-runtime-deps.sh       # lift OMZ + TPM to runtime paths
    │   ├── 03-p10k.sh
    │   ├── 04-omz-plugins.sh
    │   ├── 05-stow.sh
    │   └── 06-patch-home.sh
    ├── 04-editors/
    │   ├── 01-neovim.sh
    │   ├── 02-tmux-plugins.sh
    │   └── 03-neovim-plugins.sh
    ├── 05-tools/
    │   ├── 01-fzf.sh
    │   ├── 02-github-cli.sh
    │   ├── 03-pay-respects.sh
    │   ├── 04-cli-extensions.sh
    │   └── 05-taskwarrior.sh
    ├── 06-shell/
    │   ├── 01-default-shell.sh
    │   └── 02-nerd-font.sh
    └── 07-ai/
        └── 01-mcp.sh
```

Numeric prefixes give lexicographic execution order; the orchestrator
globs `install/??-*/??-*.sh` and runs in sort order.

## Library design

Two lib files, sourced (not executed) at the top of every install script.

### `install/lib/common.sh`

Universal helpers. Source first in every script.

- Logging: `info`, `ok`, `warn`, `err`
- Platform: `require_linux`, `require_command`, `arch_slug`,
  `apt_arch_slug`
- Paths: sets `LOCAL_BIN`, prepends `$HOME/.local/bin` + `$HOME/.fzf/bin`
  to PATH; sources `$HOME/.cargo/env` and `$NVM_DIR/nvm.sh` if present
  (maintains toolchain continuity across subshells)
- Skip/failure tracking: `SKIP_PACKAGES`, `FAILED_OPTIONAL_PACKAGES`,
  `skip_package`, `record_failure`
- Filesystem: `BACKUP_DIR`, `BACKUP_NEEDED`, `backup_if_real`,
  `patch_home`

### `install/lib/downloads.sh`

Network + archive + cargo helpers. Source after `common.sh`.

- `curl_download`, `curl_stdout`, `curl_effective_url` (retry, no
  corporate-CA support — see Intentional omissions)
- `resolve_github_latest_tag`, `resolve_gitlab_latest_tag`
- `extract_archive` (tar.gz / tar.xz / zip)
- `install_binary_from_archive_candidates`
- `cargo_install_if_missing` (retry, tuned `CARGO_HTTP_*` defaults)

## Per-script requirements

Every new `.sh` in this tree MUST:

1. Start with `#!/usr/bin/env bash` and `set -euo pipefail`.
2. Include a sourcing guard immediately after the header:
   ```bash
   [[ -n "${_DOTFILES_<NAME>_SH_LOADED:-}" ]] && return 0
   _DOTFILES_<NAME>_SH_LOADED=1
   ```
   For scripts that may be sourced or executed, use the dual-mode form:
   ```bash
   if [[ -n "${_DOTFILES_<NAME>_SH_LOADED:-}" ]]; then
       return 0 2>/dev/null || exit 0
   fi
   _DOTFILES_<NAME>_SH_LOADED=1
   ```
3. Source `install/lib/common.sh` (and `downloads.sh` if needed) via
   `$(dirname "${BASH_SOURCE[0]}")` plus relative path.
4. Be idempotent — safe to re-run any number of times.
5. Guard each action with a `command -v` or equivalent check before
   installing.

## Intentional omissions

### Corporate CA bundle (`COMBINED_CA_PEM`)

The legacy `install-cli-extensions.sh` detects a corporate CA bundle at
`~/.aws/combined_cas.pem` and wires it into curl + cargo. This is
work-specific and does not port to other machines.

Decision: new `install/lib/downloads.sh` does NOT include any CA logic.
`install-cli-extensions.sh` has a TODO comment flagging the constant
for removal alongside the legacy script during final swap.

## Dependency graph — findings that shaped the design

### Hard ordering constraints

- **System packages (01-system/01-packages.sh) blocks everything else.**
  Every downstream step needs at least one of apt, git, curl, wget, jq,
  build-essential, cmake, unzip, python3/pipx, stow, fontconfig,
  sqlite3, zsh, tmux.
- **JDK subchain:** `01-temurin-jdk` → `02-installcert-java` →
  `05-gradle` (installcert needs `javac`; Gradle needs the imported
  keystore on corporate networks).
- **Palantir Java Format is a native binary** — NO JDK dependency at
  install time.
- **Rust (02-languages/07-rust.sh)** enables cargo for three downstream
  steps: `05-tools/03-pay-respects`, `05-tools/04-cli-extensions`
  (tokscale, rga fallback, etc.), `05-tools/05-taskwarrior`.
- **Dotfiles chain:** `01-repo` (clone + submodule sync) →
  `02-runtime-deps` (oh-my-zsh + TPM lift/move/install) + `03-p10k` +
  `04-omz-plugins` → `05-stow` (reads source tree once; everything
  must exist first) → `06-patch-home` (sed on hardcoded paths).
- **Neovim plugin sync (04-editors/03-neovim-plugins.sh)** needs:
  nvim binary (04-editors/01-neovim), `~/.config/nvim` symlink
  (03-dotfiles/05-stow), and Temurin JDK (02-languages/01) for Mason
  Java tools.
- **Tmux plugins (04-editors/02-tmux-plugins.sh)** needs TPM installed
  at `~/.tmux/plugins/tpm` by bootstrap runtime dependency setup.
- **Taskwarrior (05-tools/05-taskwarrior.sh)** needs cargo from
  02-languages and the `.taskrc` file from 03-dotfiles (which it
  symlinks manually — NOT via stow, because the stow ignore list skips
  `.taskrc`).
- **MCP (07-ai/01-mcp.sh)** needs curl (01-system) and the `claude`
  CLI (installed externally by the user).

### Bucket-level DAG

```
01-system ──► all other buckets
02-languages ──► 04-editors (JDK needed for Mason)
              ├─► 05-tools   (cargo needed for pay-respects, cli-ext, taskwarrior)
03-dotfiles  ──► 04-editors (stow-produced symlinks)
              └─► 05-tools  (.taskrc consumed by taskwarrior)
```

No cycles. Strictly monotonic by bucket number.

### Intra-bucket reorderability

| Bucket         | Fully reorderable? | Residual order constraint                              |
| -------------- | ------------------ | ------------------------------------------------------ |
| 01-system      | trivial            | single step                                            |
| 02-languages   | partial            | JDK subchain stays ordered (01→02→05)                  |
| 03-dotfiles    | partial            | `01-repo` first, `05-stow` after content, `06-patch-home` last |
| 04-editors     | partial            | `01-neovim` before `03-neovim-plugins`                 |
| 05-tools       | yes                | all siblings — no intra-bucket edges                   |
| 06-shell       | yes                | both independent                                       |
| 07-ai          | trivial            | single step                                            |

The residual constraints are physical (JDK must exist before keystore
import; stow must see the full source tree) and cannot be eliminated by
refactoring.

### Hidden subtleties

1. **Cargo env must be SOURCED, not just on PATH.** Handled:
   `common.sh` sources `~/.cargo/env` on every source, so each subshell
   sees a working cargo.
2. **pipx-installed binaries land in `~/.local/bin`** — `common.sh`
   prepends this to PATH.
3. **`BACKUP_DIR` is shell-level state.** If multiple scripts call
   `backup_if_real`, they need a shared `BACKUP_DIR` to avoid creating
   several timestamped dirs per bootstrap run. The orchestrator will
   `export BACKUP_DIR` before invoking children; `common.sh` respects
   that via `BACKUP_DIR="${BACKUP_DIR:-...}"`.
4. **The wholesale-`~/.config`-symlink guard** (`bootstrap.sh:506-515`)
   must be preserved in `03-dotfiles/05-stow.sh` — dropping it risks
   `backup_if_real` nuking the live `.config` submodule.
5. **`.taskrc` is manually symlinked by `05-tools/05-taskwarrior.sh`,
   not by stow.** The stow invocation ignores `.taskrc`. Preserve both
   behaviors when extracting.
6. **The stow `--ignore` list** (`bootstrap.sh:539-548`) is critical.
   When extracting to `03-dotfiles/05-stow.sh`, the list must move
   verbatim. Also: **the new `install/` directory must be added to the
   ignore list** — otherwise stow will try to link `~/install/*`.
7. **MCP requires `claude` CLI** which bootstrap does not install. The
   MCP script warns and skips if missing — preserved behavior.
8. **Context7 API key** lives in `~/.config/secrets/mcp.env` (mode
   600), outside the repo. `install/07-ai/01-mcp.sh` will source it if
   present; otherwise warn and skip context7 registration.

## Orchestrator design

Final state of `bootstrap.sh` (after the swap commit):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Minimal prereqs for clone (curl | bash compatibility)
sudo apt-get update -qq && sudo apt-get install -y -qq git curl

# Clone or reuse dotfiles repo
DOTFILES_REPO="https://github.com/DanielMarchukov/dotfiles.git"
DOTFILES_DIR="$HOME/repos/dotfiles"
if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    mkdir -p "$(dirname "$DOTFILES_DIR")"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Single, shared backup dir for this run
export BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"

# Run install steps in bucket/step order
SKIP_SECTIONS="${SKIP_SECTIONS:-}"
for script in "$DOTFILES_DIR/install"/??-*/??-*.sh; do
    [[ -x "$script" ]] || continue
    name="${script#$DOTFILES_DIR/install/}"
    tag="${name%.sh}"
    if [[ " $SKIP_SECTIONS " == *" $tag "* ]]; then
        echo "[WARN] Skipping $tag (SKIP_SECTIONS)"
        continue
    fi
    echo "=== $tag ==="
    "$script"
done

echo "Bootstrap complete!"
```

The clone step stays in `bootstrap.sh` because `install/` doesn't exist
until after clone.

## Execution phases

### Phase 0 — MCP setup (DONE)

- `claude mcp add` for context7, basic-memory, git at user scope.
- Created `install-mcp.sh` at repo root (will move to
  `install/07-ai/01-mcp.sh` during Phase 2).
- Added MCP step to `bootstrap.sh` Section 19.
- Secrets file at `~/.config/secrets/mcp.env`.
- Committed and pushed (`fdcf3b5`, `61067ad`).

### Phase 1 — Create shared lib (DONE)

- [x] `install/lib/common.sh` — logging, platform, PATH/env, skip/fail,
      fs helpers.
- [x] `install/lib/downloads.sh` — curl, archive, release tags, cargo.
- [x] Sourcing guards on both.
- [x] `COMBINED_CA_PEM` stripped from new lib; TODO added in
      legacy script.
- [x] 7 bucket directories created under `install/` with brief
      per-bucket `README.md` explaining scope, ordering, and
      cross-bucket dependencies.
- Committed and pushed (`1a8c061`). Bucket READMEs follow in a
  separate commit once the dotfiles-bucket layout is reconciled with
  the post-modernization naming (`02-runtime-deps`, `03-p10k`,
  `04-omz-plugins`, `05-stow`, `06-patch-home`).

### Phase 2 — Extract per-step scripts (NEXT)

One commit per script. Each script:

1. Copy logic from the corresponding section of `bootstrap.sh` or
   `install-cli-extensions.sh`.
2. Replace local helpers with sources from `install/lib/*.sh`.
3. Add sourcing guard.
4. Keep idempotency checks intact.
5. Run the extracted script standalone to verify it works.
6. Confirm the legacy path (`bootstrap.sh` or
   `install-cli-extensions.sh`) still works (the original inline code
   is still present).
7. Commit with message `Extract install/<bucket>/<step>.sh from
   <source-script>`.

Extraction order (follows the bucket/step DAG):

- 01-system/01-packages.sh
- 02-languages/01-temurin-jdk.sh
- 02-languages/02-installcert-java.sh
- 02-languages/03-go.sh
- 02-languages/04-cpp-toolchain.sh
- 02-languages/05-gradle.sh
- 02-languages/06-palantir-java-format.sh
- 02-languages/07-rust.sh
- 02-languages/08-node.sh
- 03-dotfiles/01-repo.sh
- 03-dotfiles/02-runtime-deps.sh  (lift OMZ + TPM to runtime paths)
- 03-dotfiles/03-p10k.sh
- 03-dotfiles/04-omz-plugins.sh
- 03-dotfiles/05-stow.sh     (preserve ignore list + `.config`-guard;
                               ADD `install` to ignore list)
- 03-dotfiles/06-patch-home.sh
- 04-editors/01-neovim.sh
- 04-editors/02-tmux-plugins.sh
- 04-editors/03-neovim-plugins.sh
- 05-tools/01-fzf.sh
- 05-tools/02-github-cli.sh
- 05-tools/03-pay-respects.sh
- 05-tools/04-cli-extensions.sh   (move from repo-root
                                    install-cli-extensions.sh; inline
                                    its own helpers into lib sources)
- 05-tools/05-taskwarrior.sh     (includes the manual .taskrc symlink)
- 06-shell/01-default-shell.sh
- 06-shell/02-nerd-font.sh
- 07-ai/01-mcp.sh                (move from repo-root install-mcp.sh)

### Phase 3 — Final swap (LAST)

Single commit:

- Replace `bootstrap.sh` with the orchestrator above.
- Delete `install-cli-extensions.sh` from repo root.
- Delete `install-mcp.sh` from repo root.
- Update any references in README or other docs.
- Verify `bootstrap.sh` runs end-to-end on this machine (idempotent
  re-run should be no-op).

## Acceptance criteria per phase

### Phase 2 (per extraction)

- `bash -n install/<bucket>/<step>.sh` — syntax OK.
- `./install/<bucket>/<step>.sh` — runs successfully (idempotent — all
  steps report "already installed" on second run).
- `./bootstrap.sh` — unchanged, still runs fully. Or
  `./install-cli-extensions.sh` still runs fully.
- No new stow ignore breakage.
- Commit message is imperative-mood, ≤72 chars title.

### Phase 3 (final swap)

- `./bootstrap.sh` on a fresh WSL instance completes successfully.
- Re-running `./bootstrap.sh` is idempotent.
- `SKIP_SECTIONS="02-languages/07-rust 05-tools/05-taskwarrior"` skips
  exactly those steps.
- All MCP servers still connect after bootstrap.

## Open risks

1. **Stow ignore list**: the new `install/` directory MUST be added to
   `--ignore` when extracting `03-dotfiles/05-stow.sh`. Otherwise stow
   will try to link `~/install/*`.
2. **BACKUP_DIR propagation**: orchestrator must `export BACKUP_DIR`
   before invoking children so all `backup_if_real` calls share one
   timestamped backup dir.
3. **Cross-bucket PATH assumptions**: any step that relies on a tool
   installed by an earlier step must be validated to still find it in a
   fresh subshell. `common.sh` handles the common cases (cargo, nvm,
   `~/.local/bin`, `~/.fzf/bin`), but tool-specific PATHs (e.g., Go at
   `/usr/local/go/bin`, vcpkg at `$VCPKG_ROOT`) need to be set by the
   step that installs them, not assumed.
4. **Cloud bootstrap path**: `curl | bash` of the RAW bootstrap.sh
   still works because the orchestrator clones the repo first and only
   then invokes `install/*/*.sh`. Verify this on a clean VM before
   calling the migration done.

## References

- Parallel-implementation methodology saved to memory:
  `~/.claude/projects/.../memory/feedback_parallel_migration.md`
- Sourcing-guard convention saved to memory:
  `~/.claude/projects/.../memory/feedback_shell_sourcing_guards.md`
