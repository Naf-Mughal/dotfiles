--!nonstrict
-- File Manager service: points Mod+E, folder opening (xdg-mime) and the
-- org.freedesktop.FileManager1 D-Bus name at one file manager. Runs on every
-- start and settings change and only touches a file when its contents differ.
--
-- In: IPC "apply" - apply now

local UMBRIEL_DIR = noctalia.expandPath("~/.config/umbriel/plugins")
local UMBRIEL_FILE = UMBRIEL_DIR .. "/file-manager.toml"
local DBUS_DIR = noctalia.expandPath("~/.local/share/dbus-1/services")
local DBUS_FILE = DBUS_DIR .. "/org.freedesktop.FileManager1.service"

-- command = what Mod+E runs, desktop = its .desktop file, dbus = how D-Bus
-- starts it as FileManager1, process = the name to stop when switching away.
local APPS = {
  dolphin = { command = "dolphin", desktop = "org.kde.dolphin.desktop", dbus = "/usr/bin/dolphin --daemon", process = "dolphin" },
  thunar = { command = "thunar", desktop = "thunar.desktop", dbus = "/usr/bin/Thunar --gapplication-service", process = "thunar" },
  nemo = { command = "nemo", desktop = "nemo.desktop", dbus = "/usr/bin/nemo --no-default-window", process = "nemo" },
  nautilus = { command = "nautilus", desktop = "org.gnome.Nautilus.desktop", dbus = "/usr/bin/nautilus --gapplication-service", process = "nautilus" },
}

local function umbrielToml(app)
  return table.concat({
    "# Written by the File Manager plugin (nafeel/file-manager); edits here",
    "# are overwritten. Included from ~/.config/umbriel/config.toml, whose own",
    "# [keybinds] win over these, so don't bind the same keys there.",
    "[keybinds]",
    '"Mod+E" = { action = "spawn:' .. app.command .. '", repeat = false }',
    "",
  }, "\n")
end

local function dbusService(app)
  return table.concat({
    "# Written by the File Manager plugin (nafeel/file-manager); edits here are overwritten.",
    "[D-BUS Service]",
    "Name=org.freedesktop.FileManager1",
    "Exec=" .. app.dbus,
    "",
  }, "\n")
end

local function put(path, text)
  if noctalia.fileExists(path) and noctalia.readFile(path) == text then
    return false
  end
  local ok, err = noctalia.writeFile(path, text)
  if ok == false then
    noctalia.notifyError(noctalia.tr("title"), tostring(err))
    return false
  end
  noctalia.log("wrote " .. path)
  return true
end

-- If another app already holds FileManager1, the new .service file is only
-- used once that name is free, so stop the holder when it isn't ours.
local function takeOverDbusName(app)
  noctalia.runAsync({
    "sh", "-c",
    [[pid=$(busctl --user status org.freedesktop.FileManager1 2>/dev/null | sed -n 's/^PID=//p')
[ -n "$pid" ] || exit 0
[ "$(cat /proc/$pid/comm 2>/dev/null)" = "$1" ] && exit 0
busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null 2>&1
kill "$pid"]],
    "sh", app.process,
  })
end

local function apply()
  local name = tostring(noctalia.getConfig("app") or "dolphin")
  local app = APPS[name]
  if app == nil then
    noctalia.notifyError(noctalia.tr("title"), string.format(noctalia.tr("notify.unknown"), name))
    return
  end
  noctalia.mkdirAll(UMBRIEL_DIR)
  noctalia.mkdirAll(DBUS_DIR)
  put(UMBRIEL_FILE, umbrielToml(app))
  put(DBUS_FILE, dbusService(app))
  noctalia.runAsync({
    "sh", "-c",
    '[ "$(xdg-mime query default inode/directory)" = "$1" ] || xdg-mime default "$1" inode/directory',
    "sh", app.desktop,
  })
  takeOverDbusName(app)
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
