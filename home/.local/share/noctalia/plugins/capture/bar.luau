--!nonstrict
-- Bar widget: a camera that opens the capture dialog, or while recording a red
-- dot and the time recorded.
-- Idle:      click dialog · right-click region screenshot · middle-click record
-- Recording: click dialog · right-click stop · middle-click pause/resume

local lib = require("./lib.luau")

local function render()
  local s = lib.state()
  if s.recording then
    barWidget.setVisible(true)
    barWidget.setGlyph(if s.paused then "player-pause-filled" else "player-record-filled")
    barWidget.setGlyphColor(if s.paused then "outline" else "error")
    barWidget.setText(lib.clock(lib.elapsed(s)))
    barWidget.setTooltip({
      noctalia.tr(if s.paused then "bar.paused" else "bar.recording"),
      noctalia.tr("bar.recording_hint"),
    })
    noctalia.setUpdateInterval(500)
  else
    -- Read each time, so the setting applies without a restart.
    barWidget.setVisible(noctalia.getConfig("hide_when_idle") ~= true or s.starting == true)
    barWidget.setGlyph(if s.starting then "loader-2" else "camera")
    barWidget.setGlyphColor("on_surface")
    barWidget.setText("")
    barWidget.setTooltip({ noctalia.tr("title"), noctalia.tr("bar.idle_hint") })
    noctalia.setUpdateInterval(5000)
  end
end

function update()
  render()
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
