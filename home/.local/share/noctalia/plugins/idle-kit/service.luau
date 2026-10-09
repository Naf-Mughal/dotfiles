--!nonstrict
-- Idle Kit service: keeps ~/.config/noctalia/idle-kit.toml (hooks, lock
-- screen) equal to the plugin's config/idle-kit.toml and makes sure an idle
-- profile is active. The hooks do the rest: they run bin/idle-profile and
-- bin/power-mode on start and on every charger / battery event. Only writes
-- when contents differ, so the reload a write causes is a no-op here.
--
-- In: IPC "apply"                      - re-copy the current profile
--     IPC "profile" [auto|ac|battery]  - pick a profile (default auto)

local root = noctalia.pluginDir()
local CONFIG_SRC = root .. "/config/idle-kit.toml"
local CONFIG_DST = noctalia.expandPath("~/.config/noctalia/idle-kit.toml")
local ACTIVE = noctalia.expandPath("~/.config/noctalia/zz-idle-active.toml")
local IDLE_PROFILE = root .. "/bin/idle-profile"
local trim = noctalia.string.trim

local function idleProfile(arg)
  noctalia.runAsync({ IDLE_PROFILE, arg }, function(result)
    if result and result.exitCode ~= nil and result.exitCode ~= 0 then
      noctalia.notifyError(noctalia.tr("title"), trim(result.stderr or ""))
    end
  end)
end

local function install()
  local want = noctalia.readFile(CONFIG_SRC)
  if want and not (noctalia.fileExists(CONFIG_DST) and noctalia.readFile(CONFIG_DST) == want) then
    local ok, err = noctalia.writeFile(CONFIG_DST, want)
    if ok == false then
      noctalia.notifyError(noctalia.tr("title"), tostring(err))
    else
      noctalia.log("wrote " .. CONFIG_DST)
    end
  end
  if not noctalia.fileExists(ACTIVE) then
    idleProfile("auto")
  end
end

function onIpc(event, payload)
  local arg = if type(payload) == "string" then trim(payload) else ""
  if event == "apply" then
    idleProfile("apply")
  elseif event == "profile" then
    idleProfile(if arg == "" then "auto" else arg)
  end
end

function onConfigChanged()
  install()
end

install()
