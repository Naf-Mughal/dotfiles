--!nonstrict
-- Bar widget: a camera that opens the capture dialog, or while recording a red
-- dot and the time recorded. Resting the pointer on it previews the dialog
-- (no tooltip - the dialog shows everything); a click toggles it.
-- Idle:      hover/click dialog · right-click region screenshot · middle-click record
-- Recording: hover/click dialog · right-click stop · middle-click pause/resume

local lib = require("./lib.luau")

local HOVER_MS = 140
local LEAVE_MS = 350

local hovered, enteredAt, fired = false, 0, false
-- A hover-opened dialog closes again if the pointer leaves the icon without
-- going into it.
local previewing, leftAt = false, nil

local ID = "nafeel/capture:toolbar"

-- Active pill, same geometry as the m3-panels bar controls: always laid out
-- at full size so it never shifts the bar; the fill (the tools group's tonal
-- secondary) shows while hovered or while the dialog is open.
local function isActive()
  return hovered or noctalia.state.get("capture.toolbar") == true
end

local function pill(children)
  return ui.row({ align = "center", justify = "center", onHover = "onCaptureHover" }, {
    ui.column({ gap = 1, align = "center", justify = "center", width = 28, paddingV = 6, radius = 14,
      fill = if isActive() then "secondary" else "#00000000" }, children),
  })
end

local function render()
  local s = lib.state()
  local active = isActive()
  if s.recording then
    barWidget.setVisible(true)
    local color = if s.paused then "outline" else "error"
    -- The bar lays the root out along its own axis; the inner box stacks.
    barWidget.render(pill({
      ui.glyph({ name = if s.paused then "player-pause-filled" else "player-record-filled", color = color }),
      ui.label({ text = lib.clock(lib.elapsed(s)), fontSize = 10, fontWeight = "bold", color = color }),
    }))
    if (not hovered or fired) and leftAt == nil then
      noctalia.setUpdateInterval(500)
    end
  else
    -- Read each time, so the setting applies without a restart.
    barWidget.setVisible(noctalia.getConfig("hide_when_idle") ~= true or s.starting == true)
    barWidget.render(pill({
      ui.glyph({ name = if s.starting then "loader-2" else "camera", color = if active then "on_secondary" else nil }),
    }))
    if (not hovered or fired) and leftAt == nil then
      noctalia.setUpdateInterval(5000)
    end
  end
end

function onCaptureHover(state)
  hovered = state == "true"
  render()
  if hovered then
    enteredAt = noctalia.nowMs()
    fired = false
    leftAt = nil
    noctalia.setUpdateInterval(30)
  elseif previewing then
    leftAt = noctalia.nowMs()
  end
end

function update()
  local now = noctalia.nowMs()
  if hovered and not fired and now - enteredAt >= HOVER_MS then
    fired = true
    if noctalia.state.get("capture.toolbar") ~= true then
      noctalia.togglePanel(ID)
      previewing = true
    end
    render()
  elseif leftAt and now - leftAt >= LEAVE_MS then
    leftAt = nil
    previewing = false
    if noctalia.state.get("capture.toolbar") == true
      and noctalia.state.get("capture.entered") ~= true then
      noctalia.togglePanel("nafeel/capture:toolbar")
    end
    render()
  elseif not hovered and leftAt == nil then
    render()
  end
end

function onClick()
  previewing, leftAt = false, nil
  noctalia.togglePanel(ID)
end

function onRightClick()
  if lib.state().recording then
    lib.request("stop")
  else
    lib.request("screenshot", "region")
  end
end

function onMiddleClick()
  if lib.state().recording then
    lib.request("pause")
  else
    lib.request("set", "kind", 0, "record")
    noctalia.togglePanel("nafeel/capture:toolbar")
  end
end

noctalia.state.watch("capture.state", function(_)
  render()
end)

noctalia.state.watch("capture.toolbar", function(_)
  render()
end)

render()
