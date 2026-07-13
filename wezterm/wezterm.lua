-- WezTerm configuration.
--
-- WezTerm runs host-side, so on Windows this file is read from
-- %USERPROFILE%\.config\wezterm\wezterm.lua. The canonical copy lives here in
-- the dotfiles repo; bootstrap.sh deploys it to the Windows side under WSL.
-- The config is platform-aware, so the same file also works on Linux/macOS.

local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Font: 0xProto Nerd Font (Mono = single-width icon glyphs, best grid alignment)
config.font = wezterm.font_with_fallback({
  "0xProto Nerd Font Mono",
  "0xProto Nerd Font",
})
config.font_size = 11.0

-- Colors: Catppuccin Mocha, matching the Neovim + tmux theme.
config.color_scheme = "Catppuccin Mocha"

-- On Windows, launch straight into WSL (first detected distro, so this stays
-- portable across machines). On Linux/macOS, use the default login shell.
if wezterm.target_triple:find("windows") then
  local wsl_domains = wezterm.default_wsl_domains()
  if #wsl_domains > 0 then
    config.default_domain = wsl_domains[1].name
  end
end

-- tmux handles multiplexing, so keep WezTerm's own chrome minimal.
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.window_decorations = "RESIZE"
config.window_padding = { left = 4, right = 4, top = 2, bottom = 2 }
config.scrollback_lines = 10000
config.audible_bell = "Disabled"
config.adjust_window_size_when_changing_font_size = false

-- No update nag; smoother redraw on high-refresh displays.
config.check_for_updates = false
config.max_fps = 120

-- tmux (with tmux-resurrect + tmux-continuum) persists sessions, so closing a
-- window never loses work — skip the confirmation prompt.
config.window_close_confirmation = "NeverPrompt"

-- Sixel works out of the box in WezTerm — that's what carries tdf's PDF
-- preview through tmux (kitty graphics protocol does not survive tmux).

return config
