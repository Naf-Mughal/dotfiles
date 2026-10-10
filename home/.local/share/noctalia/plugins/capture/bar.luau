--!nonstrict
-- Bar widget: a camera that opens the capture dialog, or while recording a red
-- dot and the time recorded. Resting the pointer on it opens the dialog (no
-- tooltip - the dialog shows everything).
-- Idle:      hover/click dialog · right-click region screenshot · middle-click record
-- Recording: hover/click dialog · right-click stop · middle-click pause/resume

local lib = require("./lib.luau")

local HOVER_MS = 140

local hovered, enteredAt, fired = false, 0, false

local function render()
  local s = lib.state()
  local vertical = barWidget.isVertical()
  local box = if vertical then ui.column else ui.row
  if s.recording then
    barWidget.setVisible(true)
    local color = if s.paused then "outline" else "error"
    -- The bar lays the root out along its own axis; the inner box stacks.
    barWidget.render(ui.row({ align = "center", justify = "center", onHover = "onCaptureHover" }, {
      box({ gap = 1, align = "center", justify = "center" }, {
        ui.glyph({ name = if s.paused then "player-pause-filled" else "player-record-filled", color = color }),
        ui.label({ text = lib.clock(lib.elapsed(s)), fontSize = 10, fontWeight = "bold", color = color }),
      }),
    }))
    if not hovered or fired then
      noctalia.setUpdateInterval(500)
    end
  else
    -- Read each time, so the setting applies without a restart.
    barWidget.setVisible(noctalia.getConfig("hide_when_idle") ~= true or s.starting == true)
    barWidget.render(box({ align = "center", justify = "center", onHover = "onCaptureHover" }, {
      ui.glyph({ name = if s.starting then "loader-2" else "camera" }),
    }))
    if not hovered or fired then
      noctalia.setUpdateInterval(5000)
    end
  end
end

function onCaptureHover(state)
  hovered = state == "true"
  if hovered then
    enteredAt = noctalia.nowMs()
    fired = false
    noctalia.setUpdateInterval(30)
  else
    render()
  end
end

function update()
  if hovered and not fired and noctalia.nowMs() - enteredAt >= HOVER_MS then
    fired = true
    if noctalia.state.get("capture.toolbar") ~= true then
      noctalia.togglePanel("nafeel/capture:toolbar")
    end
    render()
  elseif not hovered then
    render()
  end
end

function onClick()
  noctalia.togglePanel("nafeel/capture:toolbar")
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

render()
