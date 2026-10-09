--!nonstrict
-- Control-center tile: opens the recording toolbar, or stops the recording
-- (right-click: record the whole screen straight away).

local lib = require("./lib.luau")

local CLOSE_DELAY_MS = 450

local function render()
  local s = lib.state()
  shortcut.setActive(s.recording == true)
  shortcut.setIcon(if s.recording then "player-stop-filled" else "video")
  shortcut.setLabel(noctalia.tr(if s.recording then "tile.stop" else "tile.record"))
end

function onClick()
  if lib.state().recording then
    lib.request("stop")
  else
    lib.request("record")
  end
end

function onRightClick()
  if not lib.state().recording then
    lib.request("start", "screen", CLOSE_DELAY_MS)
  end
end

noctalia.state.watch("capture.state", function(_)
  render()
end)

render()
