--!nonstrict
-- Control-center tile: regenerate the palette from the wallpaper and use it
-- (right-click: turn following the wallpaper on or off).

local function render()
  local s = noctalia.state.get("palette.state") or {}
  shortcut.setLabel(noctalia.tr("tile.label"))
  shortcut.setIcon("palette")
  shortcut.setActive(s.active == true)
end

function onClick()
  noctalia.state.set("palette.request", { action = "apply", at = noctalia.nowMs() })
end

function onRightClick()
  noctalia.state.set("palette.request", { action = "auto", value = "toggle", at = noctalia.nowMs() })
end

noctalia.state.watch("palette.state", function(_)
  render()
end)

render()
