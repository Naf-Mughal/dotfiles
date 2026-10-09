--!nonstrict
-- Window Switcher service: writes the Noctalia and Umbriel config Alt+Tab
-- needs. Runs on every start and settings change and only touches a file
-- when its contents differ, so a reload it causes comes back here as a no-op.
--
-- In: IPC "apply" - rewrite both files now

local NOCTALIA_FILE = noctalia.expandPath("~/.config/noctalia/window-switcher.toml")
local UMBRIEL_DIR = noctalia.expandPath("~/.config/umbriel/plugins")
local UMBRIEL_FILE = UMBRIEL_DIR .. "/window-switcher.toml"

-- Noctalia's own switcher options, as this setup likes them. They're only the
-- baseline: Settings -> Shell -> Window Switcher saves to the GUI state, which
-- wins over config files, so changes made there still apply.
local SWITCHER = {
  { "style", '"carousel"' },
  { "mru", "true" },
  { "current_workspace_only", "true" },
  { "show_all_outputs", "true" },
  { "show_app_icon", "true" },
  { "show_caption", "true" },
  { "show_count", "true" },
}

local function noctaliaToml()
  local lines = {
    "# Written by the Window Switcher plugin (nafeel/window-switcher); edits here",
    "# are overwritten. Change these in Settings -> Shell -> Window Switcher.",
    "[shell.window_switcher]",
  }
  for _, kv in SWITCHER do
    table.insert(lines, kv[1] .. " = " .. kv[2])
  end
  table.insert(lines, "")
  return table.concat(lines, "\n")
end

local function umbrielToml()
  local lines = {
    "# Written by the Window Switcher plugin (nafeel/window-switcher); edits here",
    "# are overwritten. Included from ~/.config/umbriel/config.toml, whose own",
    "# [keybinds] win over these, so don't bind the same keys there.",
    "[keybinds]",
    '"Alt+Tab" = { action = "spawn:noctalia msg window-switcher hold", allow_when_inhibited = true }',
    '"Alt+Shift+Tab" = { action = "spawn:noctalia msg window-switcher hold", allow_when_inhibited = true }',
  }
  if noctalia.getConfig("overview_tab") ~= false then
    table.insert(lines, [["Mod+Tab" = { action = "spawn:sh -c 'umbriel msg overview-open; umbriel msg window-focus-next'", allow_when_inhibited = true }]])
  end
  table.insert(lines, "")
  return table.concat(lines, "\n")
end

local function put(path, text)
  if noctalia.fileExists(path) and noctalia.readFile(path) == text then
    return
  end
  local ok, err = noctalia.writeFile(path, text)
  if ok == false then
    noctalia.notifyError(noctalia.tr("title"), tostring(err))
  else
    noctalia.log("wrote " .. path)
  end
end

local function apply()
  noctalia.mkdirAll(UMBRIEL_DIR)
  put(NOCTALIA_FILE, noctaliaToml())
  put(UMBRIEL_FILE, umbrielToml())
end

function onIpc(event, _payload)
  if event == "apply" then
    apply()
  end
end

function onConfigChanged()
  apply()
end

apply()
