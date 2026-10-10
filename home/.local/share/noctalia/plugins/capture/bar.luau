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

-- Active pill, same geometry as the m3-panels bar controls (REACH reserved
-- above and below, pill PAD around the content) so the tools group spaces
-- evenly. It grows in and fades out on a spring while hovered or while the
-- dialog is open, in the tools group's tonal secondary.
local REACH, PAD, WIDTH, WIDTH_IDLE = 10, 6, 28, 20
local spring = {
  p = { x = 0, v = 0, t = 0 }, -- 0 hidden .. 1 shown (overshoots a little)
}
local animating, lastFrame = false, 0

local function animate(on)
  spring.p.t = if on then 1 else 0
  if not animating then
    animating = true
    lastFrame = noctalia.nowMs()
  end
  noctalia.setUpdateInterval(16)
end

local function stepSpring(dt)
  local s = spring.p
  s.v += (520 * (s.t - s.x) - 34 * s.v) * dt -- stiff: bar widgets tick at ~20 fps
  s.x += s.v * dt
  if math.abs(s.t - s.x) < 0.01 and math.abs(s.v) < 0.01 then
    s.x, s.v = s.t, 0
    return true
  end
  return false
end

local function pill(children)
  local p = spring.p.x
  local alpha = math.clamp(p, 0, 1)
  local pad = math.clamp(PAD * p, 0, REACH)
  local w = math.clamp(WIDTH_IDLE + (WIDTH - WIDTH_IDLE) * p, 12, 30)
  -- Only uniform padding exists, so top/bottom room is spacer boxes.
  local inner = { ui.box({ width = 1, height = pad, fill = "#00000000" }) }
  for _, c in ipairs(children) do
    table.insert(inner, c)
  end
  table.insert(inner, ui.box({ width = 1, height = pad, fill = "#00000000" }))
  return ui.row({ align = "center", justify = "center", onHover = "onCaptureHover" }, {
    ui.column({ width = 30, align = "center" }, {
      ui.box({ width = 1, height = REACH - pad, fill = "#00000000" }),
      ui.column({ gap = 1, align = "center", justify = "center", width = w,
        radius = math.min(w / 2, 14),
        fill = if alpha > 0.01 then "secondary/" .. string.format("%.2f", alpha) else "#00000000" }, inner),
      ui.box({ width = 1, height = REACH - pad, fill = "#00000000" }),
    }),
  })
end

local function render()
  local s = lib.state()
  local active = spring.p.x > 0.5
  if s.recording then
    barWidget.setVisible(true)
    local color = if s.paused then "outline" else "error"
    -- The bar lays the root out along its own axis; the inner box stacks.
    barWidget.render(pill({
      ui.glyph({ name = if s.paused then "player-pause-filled" else "player-record-filled", color = color }),
      ui.label({ text = lib.clock(lib.elapsed(s)), fontSize = 10, fontWeight = "bold", color = color }),
    }))
    if (not hovered or fired) and leftAt == nil and not animating then
      noctalia.setUpdateInterval(500)
    end
  else
    -- Read each time, so the setting applies without a restart.
    barWidget.setVisible(noctalia.getConfig("hide_when_idle") ~= true or s.starting == true)
    barWidget.render(pill({
      ui.glyph({ name = if s.starting then "loader-2" else "camera", color = if active then "on_secondary" else nil }),
    }))
    if (not hovered or fired) and leftAt == nil and not animating then
      noctalia.setUpdateInterval(5000)
    end
  end
end

function onCaptureHover(state)
  hovered = state == "true"
  animate(hovered or noctalia.state.get("capture.toolbar") == true)
  if hovered then
    enteredAt = noctalia.nowMs()
    fired = false
    leftAt = nil
    noctalia.setUpdateInterval(30)
  elseif previewing then
    leftAt = noctalia.nowMs()
  else
    render()
  end
end

function update()
  local now = noctalia.nowMs()
  if animating then
    local dt = math.min(0.06, (now - lastFrame) / 1000)
    lastFrame = now
    if stepSpring(dt) then
      animating = false
    end
    render()
  end
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

noctalia.state.watch("capture.toolbar", function(open)
  animate(hovered or open == true)
end)

render()
