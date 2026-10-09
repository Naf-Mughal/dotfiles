--!nonstrict
-- App Theming service: points Qt apps at Noctalia's KDE colour scheme through
-- qtengine. Runs on every start and settings change and only touches a file
-- when its contents differ.
--
-- In: IPC "apply" - rewrite the files now

local UMBRIEL_DIR = noctalia.expandPath("~/.config/umbriel/plugins")
local UMBRIEL_FILE = UMBRIEL_DIR .. "/app-theming.toml"
local QTENGINE_DIR = noctalia.expandPath("~/.config/qtengine")
local QTENGINE_FILE = QTENGINE_DIR .. "/config.json"
local SCHEME = noctalia.expandPath("~/.local/share/color-schemes/noctalia.colors")

local function umbrielToml()
  return table.concat({
    "# Written by the App Theming plugin (nafeel/app-theming); edits here are overwritten.",
    "[environment]",
    'QT_QPA_PLATFORMTHEME = "qtengine"',
    "",
  }, "\n")
end

local function qtengineJson()
  local icons = noctalia.getConfig("icon_theme") or "breeze-dark"
  return string.format([[{
    "theme": {
        "colorScheme": "%s",
        "iconTheme": "%s",
        "style": "Darkly",
        "font": { "family": "Sans Serif", "size": 11, "weight": -1 },
        "fontFixed": { "family": "Monospace", "size": 11, "weight": -1 }
    },
    "misc": {
        "menusHaveIcons": true,
        "singleClickActivate": false,
        "shortcutsForContextMenus": true
    }
}
]], SCHEME, icons)
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
  noctalia.mkdirAll(QTENGINE_DIR)
  put(UMBRIEL_FILE, umbrielToml())
  put(QTENGINE_FILE, qtengineJson())
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
