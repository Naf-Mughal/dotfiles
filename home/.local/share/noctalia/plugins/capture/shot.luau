--!nonstrict
-- Control-center tile: region screenshot (right-click: the whole screen).

local lib = require("./lib.luau")

-- Long enough for the control center to close before the capture.
local CLOSE_DELAY_MS = 450

shortcut.setLabel(noctalia.tr("tile.screenshot"))
shortcut.setIcon("screenshot")

function onClick()
  lib.request("screenshot", "region", CLOSE_DELAY_MS)
end

function onRightClick()
  lib.request("screenshot", "screen", CLOSE_DELAY_MS)
end
