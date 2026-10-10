--!nonstrict
-- The capture dialog, modelled on Windows' Snipping Tool: one panel for
-- screenshots and recordings, attached to the bar like the control center.
--
-- Idle:      Screenshot | Record · the area (Region / Screen / Annotate) · a
--            delay or the audio · the big button, which closes the dialog first
--            so it's never in the picture
-- Picking:   Mod+Shift+S opens it on Screenshot · Region, shows the hint for a
--            moment, then hides it for the region picker
-- Recording: the timer · Stop · Pause · live mic mute · system audio (fixed)

local lib = require("./lib.luau")

local tr = noctalia.tr

-- Long enough for the panel to slide away before anything is captured.
local CLOSE_DELAY_MS = 350
-- How long Mod+Shift+S shows the dialog before the picker takes over.
local SNIP_HOLD_MS = 180
local DELAYS = { 0, 3, 5, 10 }

local snipLeftMs = nil

local function prefs()
  return noctalia.state.get("capture.prefs")
    or { kind = "screenshot", shot = "region", area = "region", delay = 0, mic = false, system = true }
end

local function set(key, value)
  return function()
    lib.request("set", key, 0, tostring(value))
  end
end

local function go()
  panel.close()
  lib.request("capture", nil, CLOSE_DELAY_MS)
end

-- ── Pieces ───────────────────────────────────────────────────────────
-- Material 3 Expressive, matching the notification / quick-settings panels
-- (nafeel/m3-panels): a badge header, tonal cards, connected button groups
-- whose chosen segment squares off and fills, and a big pill action button.

local CARD = "on_surface/0.05"
local TILE = "on_surface/0.06"
local IDLE = "on_surface/0.09"

local function circle(glyph, onClick, tooltip)
  return ui.row({ width = 40, height = 40, radius = 20, fill = IDLE, align = "center", justify = "center",
    onClick = onClick, tooltip = tooltip }, {
    ui.glyph({ name = glyph, size = 17, color = "on_surface" }),
  })
end

local function header(glyph, subtitle, tone)
  tone = tone or "primary"
  return ui.row({ gap = 12, align = "center", paddingH = 4 }, {
    ui.row({ width = 44, height = 44, radius = 16, fill = tone .. "/0.18", align = "center", justify = "center" }, {
      ui.glyph({ name = glyph, size = 20, color = tone }),
    }),
    ui.column({ gap = 1, flexGrow = 1 }, {
      ui.label({ text = tr("title"), fontSize = 20, fontWeight = "bold" }),
      ui.label({ text = subtitle, fontSize = 12, color = "on_surface_variant", maxLines = 1 }),
    }),
    circle("settings", function()
      panel.close()
      noctalia.openSettings()
    end, tr("toolbar.settings")),
    circle("x", function() panel.close() end, tr("toolbar.close")),
  })
end

-- Connected button group: the chosen one fills and squares off.
local function segmented(items, height)
  height = height or 48
  local children = {}
  for _, it in ipairs(items) do
    local on = it.on == true
    local content = {}
    if it.glyph then
      table.insert(content, ui.glyph({ name = it.glyph, size = 17, color = if on then "on_primary" else "on_surface" }))
    end
    if it.text then
      table.insert(content, ui.label({ text = it.text, fontSize = 13, fontWeight = "semibold",
        color = if on then "on_primary" else "on_surface" }))
    end
    table.insert(children, ui.row({
      key = it.key, flexGrow = if on then 1.3 else 1, height = height, gap = 8,
      radius = if on then math.floor(height * 0.3) else height / 2,
      fill = if on then "primary" else IDLE, align = "center", justify = "center", onClick = it.onClick,
    }, content))
  end
  return ui.row({ gap = 4 }, children)
end

-- A big choice: glyph over a label; squircle + accent when chosen.
local function tile(glyph, text, on, onClick)
  return ui.column({
    flexGrow = 1, height = 88, gap = 8, align = "center", justify = "center",
    radius = if on then 22 else 32,
    fill = if on then "primary/0.18" else TILE,
    onClick = onClick,
  }, {
    ui.row({ width = 40, height = 40, radius = if on then 14 else 20, fill = if on then "primary" else IDLE,
      align = "center", justify = "center" }, {
      ui.glyph({ name = glyph, size = 19, color = if on then "on_primary" else "on_surface" }),
    }),
    ui.label({ text = text, fontSize = 12, fontWeight = "semibold", color = if on then "primary" else "on_surface" }),
  })
end

local function section(text)
  return ui.label({ text = text, fontSize = 12, fontWeight = "semibold", color = "primary" })
end

-- A row of the options card: tonal glyph badge · label · whatever goes right.
local function optionRow(glyph, text, right, dim)
  return ui.row({ gap = 12, align = "center", height = 44 }, {
    ui.row({ width = 32, height = 32, radius = 12, fill = if dim then IDLE else "primary/0.14",
      align = "center", justify = "center" }, {
      ui.glyph({ name = glyph, size = 16, color = if dim then "outline" else "primary" }),
    }),
    ui.label({ text = text, fontSize = 13, color = if dim then "outline" else "on_surface", flexGrow = 1 }),
    right,
  })
end

local function card(children)
  return ui.column({ gap = 2, paddingH = 14, paddingV = 8, radius = 24, fill = CARD }, children)
end

-- Pill action button.
local function action(glyph, text, tone, onClick, grow)
  return ui.row({
    height = 56, gap = 10, radius = 28, fill = tone, align = "center", justify = "center",
    flexGrow = grow, onClick = onClick,
  }, {
    ui.glyph({ name = glyph, size = 20, color = "on_" .. tone }),
    ui.label({ text = text, fontSize = 15, fontWeight = "bold", color = "on_" .. tone }),
  })
end

-- ── States ───────────────────────────────────────────────────────────

local function idle(p)
  local isShot = p.kind ~= "record"
  local delay = p.delay or 0

  local tiles, options, label
  if isShot then
    tiles = {
      tile("crop", tr("toolbar.region"), p.shot == "region", set("shot", "region")),
      tile("device-desktop", tr("toolbar.screen"), p.shot == "screen", set("shot", "screen")),
      tile("pencil", tr("toolbar.annotate"), p.shot == "edit", set("shot", "edit")),
    }
    local delays = {}
    for _, d in ipairs(DELAYS) do
      local on = delay == d
      table.insert(delays, ui.row({
        key = "d" .. d, height = 30, paddingH = 10, radius = if on then 9 else 15,
        fill = if on then "secondary" else IDLE, align = "center", justify = "center", onClick = set("delay", d),
      }, {
        ui.label({ text = if d == 0 then tr("toolbar.no_delay") else tr("toolbar.seconds", { n = d }),
          fontSize = 11, fontWeight = "semibold", color = if on then "on_secondary" else "on_surface" }),
      }))
    end
    options = card({
      optionRow("clock", tr("toolbar.delay"), ui.row({ gap = 3 }, delays)),
      optionRow("clipboard", tr("toolbar.clipboard"), ui.glyph({ name = "circle-check-filled", size = 20, color = "primary" })),
    })
    label = tr(if delay > 0 then "toolbar.take_in" else "toolbar.take", { n = delay })
  else
    tiles = {
      tile("crop", tr("toolbar.region"), p.area == "region", set("area", "region")),
      tile("device-desktop", tr("toolbar.screen"), p.area == "screen", set("area", "screen")),
    }
    options = card({
      optionRow(if p.mic then "microphone" else "microphone-off", tr("toolbar.mic"),
        ui.toggle({ checked = p.mic == true, onChange = function(v) lib.request("set", "mic", 0, v) end })),
      optionRow(if p.system then "volume" else "volume-off", tr("toolbar.system"),
        ui.toggle({ checked = p.system == true, onChange = function(v) lib.request("set", "system", 0, v) end })),
    })
    label = tr("toolbar.start")
  end

  local area = if isShot
    then (if p.shot == "screen" then tr("toolbar.screen") elseif p.shot == "edit" then tr("toolbar.annotate") else tr("toolbar.region"))
    else (if p.area == "screen" then tr("toolbar.screen") else tr("toolbar.region"))

  return {
    header(if isShot then "camera" else "video", (if isShot then tr("toolbar.screenshot") else tr("toolbar.record")) .. " · " .. area,
      if isShot then "primary" else "error"),
    segmented({
      { key = "shot", glyph = "camera", text = tr("toolbar.screenshot"), on = isShot, onClick = set("kind", "screenshot") },
      { key = "rec", glyph = "video", text = tr("toolbar.record"), on = not isShot, onClick = set("kind", "record") },
    }),
    ui.row({ gap = 8 }, tiles),
    options,
    ui.spacer({ flexGrow = 1 }),
    action(if isShot then "camera" else "player-record-filled", label, if isShot then "primary" else "error", go),
    ui.label({ text = tr("toolbar.keys"), fontSize = 11, color = "outline", textAlign = "center" }),
  }
end

local function picking(p)
  local starting = p.kind == "record" and p.area ~= "region"
  return {
    header(if p.kind == "record" then "video" else "camera", tr(if starting then "toolbar.starting" else "toolbar.pick")),
    ui.column({ flexGrow = 1, gap = 12, align = "center", justify = "center", radius = 28, fill = CARD }, {
      ui.row({ width = 72, height = 72, radius = 26, fill = "primary/0.18", align = "center", justify = "center" }, {
        ui.glyph({ name = if starting then "loader-2" else "crop", size = 34, color = "primary" }),
      }),
      ui.label({ text = tr(if starting then "toolbar.starting" else "toolbar.pick"), fontSize = 16,
        fontWeight = "bold", color = "on_surface", textAlign = "center" }),
      ui.label({ text = tr("toolbar.esc"), fontSize = 12, color = "outline", textAlign = "center",
        visible = not starting }),
    }),
  }
end

local function recording(s, p)
  local tone = if s.paused then "secondary" else "error"
  local micLive = p.mic == true and not s.micMuted

  return {
    header("video", tr(if s.mode == "region" then "toolbar.recording_region" else "toolbar.recording_screen"), "error"),
    ui.column({ gap = 4, align = "center", paddingV = 22, radius = 28, fill = tone }, {
      ui.row({ gap = 8, align = "center", height = 28, paddingH = 12, radius = 14, fill = "on_" .. tone .. "/0.16" }, {
        ui.glyph({ name = if s.paused then "player-pause-filled" else "point-filled", size = 14, color = "on_" .. tone }),
        ui.label({ text = tr(if s.paused then "toolbar.paused" else "toolbar.recording"),
          fontSize = 11, fontWeight = "bold", color = "on_" .. tone }),
      }),
      ui.label({ text = lib.clock(lib.elapsed(s)), fontSize = 48, fontWeight = "heavy", color = "on_" .. tone }),
    }),
    section(tr("toolbar.audio")),
    card({
      optionRow(if micLive then "microphone" else "microphone-off",
        tr(if not p.mic then "toolbar.mic_not_recorded" elseif s.micMuted then "toolbar.mic_muted" else "toolbar.mic"),
        ui.toggle({ checked = micLive, enabled = p.mic == true, onChange = function(_) lib.request("mic") end }),
        not p.mic),
      optionRow(if p.system then "volume" else "volume-off", tr("toolbar.system_fixed"),
        ui.toggle({ checked = p.system == true, enabled = false }), true),
    }),
    ui.spacer({ flexGrow = 1 }),
    ui.row({ gap = 8 }, {
      action("player-stop-filled", tr("toolbar.stop"), "error", function() lib.request("stop") end, 1.4),
      ui.row({
        width = 120, height = 56, gap = 8, radius = 18, fill = IDLE, align = "center", justify = "center",
        onClick = function() lib.request("pause") end,
      }, {
        ui.glyph({ name = if s.paused then "player-play-filled" else "player-pause-filled", size = 18, color = "on_surface" }),
        ui.label({ text = tr(if s.paused then "toolbar.resume" else "toolbar.pause"), fontSize = 14,
          fontWeight = "semibold" }),
      }),
    }),
  }
end

local function render()
  local s = lib.state()
  local p = prefs()
  local children
  if s.recording then
    children = recording(s, p)
  elseif s.starting or snipLeftMs ~= nil then
    children = picking(p)
  else
    children = idle(p)
  end
  panel.render(ui.column({ padding = 16, gap = 12, flexGrow = 1 }, children))
end

-- ── Lifecycle ────────────────────────────────────────────────────────

local wasRecording = false

function onOpen(_context)
  noctalia.state.set("capture.toolbar", true)
  wasRecording = lib.state().recording == true
  -- Mod+Shift+S: show the dialog for a moment, then hand over to the picker.
  local pending = noctalia.state.get("capture.pending")
  snipLeftMs = nil
  if type(pending) == "table" and pending.action == "snip" and noctalia.nowMs() - (pending.at or 0) < 2000 then
    noctalia.state.set("capture.pending", nil)
    snipLeftMs = SNIP_HOLD_MS
    panel.setNeedsFrameTick(true)
  end
  panel.setWantsSecondTicks(true)
  render()
end

function onClose()
  noctalia.state.set("capture.toolbar", false)
  snipLeftMs = nil
end

function onFrameTick(deltaMs)
  if snipLeftMs == nil then
    panel.setNeedsFrameTick(false)
    return
  end
  snipLeftMs -= deltaMs
  if snipLeftMs <= 0 then
    snipLeftMs = nil
    panel.setNeedsFrameTick(false)
    panel.close()
    -- The snip key never waits on the dialog's delay.
    lib.request("screenshot", "region", CLOSE_DELAY_MS)
  end
end

function update()
  render()
end

noctalia.state.watch("capture.state", function(s)
  local isRecording = type(s) == "table" and s.recording == true
  if wasRecording and not isRecording then
    panel.close() -- finished: the notification takes over
  end
  wasRecording = isRecording
  render()
end)

noctalia.state.watch("capture.prefs", function(_)
  render()
end)
