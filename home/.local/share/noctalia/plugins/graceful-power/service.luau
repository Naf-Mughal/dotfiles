--!nonstrict
-- Graceful Power service: points the session menu's Restart and Shut down at
-- bin/graceful-power by writing ~/.config/noctalia/graceful-power.toml. Only
-- writes when the contents differ, so the reload a write causes is a no-op.

local BIN = noctalia.pluginDir() .. "/bin/graceful-power"
local DST = noctalia.expandPath("~/.config/noctalia/graceful-power.toml")

local function toml()
  return table.concat({
    "# Written by the Graceful Power plugin (nafeel/graceful-power); edits here",
    "# are overwritten.",
    "[shell.session.power]",
    'reboot = "' .. BIN .. ' reboot"',
    'shutdown = "' .. BIN .. ' shutdown"',
    "",
  }, "\n")
end

local function install()
  local want = toml()
  if noctalia.fileExists(DST) and noctalia.readFile(DST) == want then
    return
  end
  local ok, err = noctalia.writeFile(DST, want)
  if ok == false then
    noctalia.notifyError(noctalia.tr("title"), tostring(err))
  else
    noctalia.log("wrote " .. DST)
  end
end

function onConfigChanged()
  install()
end

install()
