# Dotfiles

This repo holds two kinds of machine state:

- Linux/WSL dotfiles and bootstrap logic via `bootstrap.sh`
- Windows UI/tooling config snapshots under `windows/`

## Windows UI Snapshot

The `windows/` tree stores the current Windows-side look/feel setup for:

- `YASB`
- `GlazeWM`
- `Flow Launcher`
- Flow Launcher `Favorites` plugin
- Flow Launcher `Catppuccin Mocha` theme
- optional wallpaper rotator script

The snapshot intentionally excludes logs, caches, `.bak` files, and transient history/state files.

## Fresh Windows Setup

Install these first on the new machine:

- `YASB`
- `GlazeWM`
- `Flow Launcher`
- `Zen Browser` if you want Flow Launcher to keep using Zen as its browser target
- `FiraCode Nerd Font` / `FiraCode Nerd Font Mono`

Then clone this repo on Windows and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\restore-ui.ps1
```

To restore the Tokyo Night variant instead of the current Catppuccin-based one:

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\restore-ui.ps1 -Theme TokyoNight
```

The restore script:

- creates timestamped backups before overwriting anything
- restores YASB config into `%USERPROFILE%\.config\yasb`
- restores GlazeWM config into `%USERPROFILE%\.glzr\glazewm`
- restores Flow Launcher settings, plugin settings, theme, and vendored `Favorites` plugin
- restores the wallpaper rotator script into `%USERPROFILE%\Scripts`
- supports `Catppuccin` and `TokyoNight` as the active restored theme
- copies both Flow Launcher theme files so you can still switch themes inside Flow Launcher after restore

After the restore:

1. Restart `Flow Launcher`
2. Restart `YASB`
3. Restart `GlazeWM`
4. Re-enable or recreate any scheduled task that should call `windows\Scripts\windots-wallpaper-rotator.ps1`

## Notes

- Flow Launcher window positions are backed up as-is. If the launcher or settings window opens off-screen on a new monitor layout, reset the window position fields in `AppData\Roaming\FlowLauncher\Settings\Settings.json`.
- The wallpaper script is stored as an optional asset only. It is not automatically re-enabled as a scheduled task.
- The Flow Launcher `Favorites` plugin is vendored here so a fresh machine does not depend on plugin-manager state.
- The default snapshot under `windows/` is the current Catppuccin setup. Tokyo Night variants live under `windows/themes/tokyonight/`.

## Linux / WSL

For Linux/WSL bootstrap, use:

```bash
./bootstrap.sh
```

Bootstrap now also runs the shell-workflow extension installer by default. To skip that step on a constrained network, use:

```bash
SKIP_CLI_EXTENSIONS=1 ./bootstrap.sh
```

You can also rerun the extension installer directly:

```bash
./install-cli-extensions.sh
```

That installer adds `direnv`, `atuin`, `delta`, `git-absorb`, `git-branchless`, `glab`, `just`, `hyperfine`, `timewarrior`, `yq`, `watchexec`, `tealdeer`/`tldr`, `rga`, and `mosh`.

`tldr` is installed from upstream tealdeer releases and configured to update from GitHub release assets instead of the old `tldr.sh/assets` path.

The dotfiles also ship a reusable global `just` config at `~/.config/just/justfile`. Use it with:

```bash
gj gradle-current-build
gj gradle-current-test
gj gradle-module-clean acceptance-test
```
