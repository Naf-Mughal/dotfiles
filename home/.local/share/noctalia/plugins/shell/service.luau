--!nonstrict
-- Shell service. While the plugin is enabled:
--
--   * bin/nafeel-shell runs the Quickshell shell (stopped with this runtime)
--   * Noctalia's bars and dock are hidden; the shell draws the frame instead
--   * ~/.config/umbriel/plugins/shell.toml reserves the frame's edges
--     (layout.struts), so tiled windows sit inside it, and binds Alt+Tab to
--     the shell's window switcher (Mod+Tab: the overview)
--   * ~/.config/noctalia/shell.toml registers templates/scheme.json, which
--     Noctalia renders with every Material role of the current palette to
--     ~/.local/state/nafeel-shell/scheme.json for the shell's colours, and
--     turns Noctalia's notification server and its volume/brightness/toggle
--     OSDs off (the shell takes over)
--
-- Disabling the plugin hands the desktop back to Noctalia: its default bar,
-- notification server and OSD.

local root = noctalia.pluginDir()

-- The frame's thickness; keep in step with quickshell/config/Tokens.qml.
local BAR_WIDTH = 52
local BORDER = 14
-- umbriel's layout gap (layout.gap, default 8). The left strut leaves it out,
-- so windows sit flush against the bar's edge and the bar reads as exactly its
-- own width (its content centred in it); the other edges keep the gap.
local LAYOUT_GAP = 8

-- Noctalia's corner_radius_scale for each of the shell's rounding presets.
local RADIUS_SCALE = { tight = "0.25", compact = "0.45", restrained = "0.8", relaxed = "1.0", generous = "1.4" }

local UMBRIEL_INCLUDE = noctalia.expandPath("~/.config/umbriel/plugins/shell.toml")
local NOCTALIA_INCLUDE = noctalia.expandPath("~/.config/noctalia/shell.toml")

local UMBRIEL_HEADER = [[
# Written by the Shell plugin (nafeel/shell); edits here are overwritten.
# Included from ~/.config/umbriel/config.toml.
]]

local SETTINGS = noctalia.expandPath("~/.local/state/nafeel-shell/settings.json")

local function write(path, text)
  local ok, err = noctalia.writeFile(path, text)
  if not ok then
    noctalia.log("shell: can't write " .. path .. ": " .. tostring(err))
  end
end

local function msg(...)
  local args = { ... }
  noctalia.runAsync({ "noctalia", "msg", table.unpack(args) }, function(result)
    if result.exitCode ~= 0 then
      noctalia.log("shell: noctalia msg " .. table.concat(args, " ") .. " failed")
    end
  end)
end

-- Frosted paper: umbriel blurs what's behind the shell's surfaces (only where
-- they're drawn, not the desktop hole), unless the paper setting is solid.
local function frostRule()
  if (noctalia.getConfig("paper") or "85") == "solid" then
    return ""
  end
  return [=[

# Frosted paper: blur behind the shell's frame and panels, only inside their
# shapes (ignore_alpha), including windows under an open panel (not optimized).
[[layer_rule]]
match.namespace = "^nafeel-shell"
blur = true
blur_ignore_alpha = 0.05
blur_optimized = false
]=]
end

local function reserveFrame()
  write(UMBRIEL_INCLUDE, UMBRIEL_HEADER .. string.format([[
# The shell's frame: the bar on the left (windows flush against it), a thin
# border elsewhere.
[layout.struts]
left = %d
top = %d
right = %d
bottom = %d

# The shell's window switcher (live previews, most recent first): Alt+Tab
# opens it on the previous window, letting go of Alt switches. While it's
# open the shell holds umbriel in the "switcher" submap, so Tab goes to it
# directly; Ctrl+Alt+Escape leaves that submap if the shell ever can't.
[keybinds]
"Alt+Tab" = { action = "spawn:shell-msg switch next", allow_when_inhibited = true }
"Alt+Shift+Tab" = { action = "spawn:shell-msg switch prev", allow_when_inhibited = true }
"Mod+Tab" = { action = "spawn:sh -c 'umbriel msg overview-open; umbriel msg window-focus-next'", allow_when_inhibited = true }
"Ctrl+Alt+Escape" = { action = "submap:reset", submap = "switcher" }
]], BAR_WIDTH, BORDER, BORDER, BORDER) .. frostRule())
end

-- Shell disabled: no struts (Noctalia's own bar reserves its space).
local function releaseFrame()
  write(UMBRIEL_INCLUDE, UMBRIEL_HEADER .. "# Shell disabled: Noctalia's bars reserve their own space.\n")
end

-- Noctalia config while the shell runs: the colour template, and its
-- notification server off (the shell is the server now).
local function configureNoctalia()
  write(NOCTALIA_INCLUDE, string.format([[
# Written by the Shell plugin (nafeel/shell); removed when it's disabled.

# The shell themes the apps (bin/nafeel-theme, from its own theme.json):
# Noctalia's templates are off so only one writes them.
[theme.templates]
enable_builtin_templates = false
enable_community_templates = false

# The shell is the notification server while it runs.
[notification]
enable_daemon = false

# Noctalia's panels the shell still opens (clipboard, launcher fallback) match
# it: floating, the clipboard in the top-left corner by its bar icon, and the
# shell's corner rounding.
[shell]
corner_radius_scale = %s
# The shell's polkit agent asks for passwords instead.
polkit_agent = false
# The shell keeps the clipboard and its history (Noctalia's own code, ported;
# the same files): Noctalia's is off so only one writes them.
clipboard_enabled = false

[shell.panel]
clipboard_placement = "floating"
clipboard_position = "top_left"

# The shell draws the bar and the dock: Noctalia's are off while it runs.
[bar.main]
enabled = false

[bar.default]
enabled = false

[dock]
enabled = false

# The shell runs the night light itself (gamma control, native module).
[nightlight]
enabled = false
force = false

# The shell draws the wallpaper (its own background layer, ink-soak
# transition). Noctalia only keeps the path, which the shell sets, for the
# palette and its templates until the shell does those too.
[wallpaper]
enabled = false

# The shell's OSD shows all of these.
[osd.kinds]
volume = false
brightness = false
wifi = false
bluetooth = false
power_profile = false
dnd = false
caffeine = false
nightlight = false
lock_keys = false
keyboard_layout = false
privacy = false
]], RADIUS_SCALE[noctalia.getConfig("radius") or "restrained"] or "0.8"))
end

-- The plugin's settings, for the shell (watched live).
local function writeSettings()
  write(SETTINGS, noctalia.json.encode({
    radius = noctalia.getConfig("radius") or "restrained",
    immersion = noctalia.getConfig("immersion") or "immersive",
    motion = noctalia.getConfig("motion") or "normal",
    paper = noctalia.getConfig("paper") or "85",
    location = (noctalia.getConfig("location") ~= "" and noctalia.getConfig("location")) or noctalia.getSetting("location.address") or "",
  }, true))
end

function onConfigChanged()
  writeSettings()
  reserveFrame()
  configureNoctalia()
  msg("config-reload")
end

function onExit(_signal, reason)
  if reason == "disable" or reason == "uninstall" then
    releaseFrame()
    -- Noctalia's own polkit agent back (its GUI setting was moved here, since
    -- settings.toml would override the shell turning it off).
    write(NOCTALIA_INCLUDE, "# Shell disabled: Noctalia's own polkit agent.\n[shell]\npolkit_agent = true\n")
    -- Stop the shell before Noctalia reloads, so its notification server can
    -- take the D-Bus name back (it only tries once).
    noctalia.runAsync({ "sh", "-c", 'pkill -f "^quickshell -p $1$"; for _ in 1 2 3 4 5 6 7 8 9 10; do busctl --user status org.freedesktop.Notifications 2>/dev/null | grep -q "^Comm=quickshell$" || break; sleep 0.3; done; noctalia msg config-reload', "sh", root .. "/quickshell" })
    msg("bar-show")
    msg("dock-show")
  end
end

-- Keybinds call `shell-msg` (bin/shell-msg); keep it on the PATH.
noctalia.runAsync({ "sh", "-c", 'mkdir -p "$HOME/.local/bin" && ln -sf "$1" "$HOME/.local/bin/shell-msg"', "sh", root .. "/bin/shell-msg" })
writeSettings()
configureNoctalia()
reserveFrame()
msg("bar-hide")
msg("dock-hide")
-- Start the shell once Noctalia has reloaded (and let go of notifications).
noctalia.runAsync({ "noctalia", "msg", "config-reload" }, function(_)
  noctalia.runStream(root .. "/bin/nafeel-shell", function(line)
    noctalia.log("shell: " .. line)
  end)
end)
