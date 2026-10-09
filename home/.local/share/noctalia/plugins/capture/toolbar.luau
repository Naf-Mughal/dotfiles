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

local function header()
  return ui.row({ gap = 10, align = "center" }, {
    ui.box({ width = 4, height = 18, radius = 2, fill = "primary" }),
    ui.label({ text = tr("title"), fontSize = 16, fontWeight = "bold", color = "on_surface" }),
    ui.spacer({ flexGrow = 1 }),
    ui.button({ glyph = "settings", variant = "ghost", controlSize = "sm", tooltip = tr("toolbar.settings"),
      onClick = function()
        panel.close()
        noctalia.openSettings()
      end }),
    ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", tooltip = tr("toolbar.close"),
      onClick = function() panel.close() end }),
  })
end

-- Equal buttons in a track, one of them chosen.
local function segmented(items)
  local children = {}
  for _, it in ipairs(items) do
    table.insert(children, ui.button({
      key = it.key, glyph = it.glyph, text = it.text, flexGrow = 1, controlSize = "md",
      variant = if it.on then "primary" else "ghost", selected = it.on, onClick = it.onClick,
    }))
  end
  return ui.row({ gap = 4, padding = 4, radius = 12, fill = "on_surface/0.06" }, children)
end

-- A big choice: glyph over a label.
local function tile(glyph, text, on, onClick)
  return ui.column({
    flexGrow = 1, gap = 6, align = "center", justify = "center", paddingV = 14, radius = 12,
    fill = if on then "primary/0.16" else "on_surface/0.04",
    border = if on then "primary" else "outline/0.25", borderWidth = 1,
    onClick = onClick,
  }, {
    ui.glyph({ name = glyph, size = 22, color = if on then "primary" else "on_surface_variant" }),
    ui.label({ text = text, fontSize = 13, fontWeight = if on then "semibold" else "medium",
      color = if on then "primary" else "on_surface" }),
  })
end

local function section(text)
  return ui.label({ text = text, fontSize = 11, fontWeight = "semibold", color = "on_surface_variant" })
end

-- A row of the options card: glyph · label · whatever goes on the right.
local function optionRow(glyph, text, right, dim)
  return ui.row({ gap = 10, align = "center", height = 38 }, {
    ui.glyph({ name = glyph, size = 18, color = if dim then "outline" else "on_surface_variant" }),
    ui.label({ text = text, fontSize = 13, color = if dim then "outline" else "on_surface", flexGrow = 1 }),
    right,
  })
end

local function card(children)
  return ui.column({ gap = 2, paddingH = 14, paddingV = 6, radius = 12, fill = "on_surface/0.04" }, children)
end

-- ── States ───────────────────────────────────────────────────────────

local function idle(p)
  local isShot = p.kind ~= "record"
  local delay = p.delay or 0

  local tiles, options, action
  if isShot then
    tiles = {
      tile("crop", tr("toolbar.region"), p.shot == "region", set("shot", "region")),
      tile("device-desktop", tr("toolbar.screen"), p.shot == "screen", set("shot", "screen")),
      tile("pencil", tr("toolbar.annotate"), p.shot == "edit", set("shot", "edit")),
    }
    local delays = {}
    for _, d in ipairs(DELAYS) do
      table.insert(delays, ui.button({
        key = "d" .. d, text = if d == 0 then tr("toolbar.no_delay") else tr("toolbar.seconds", { n = d }),
        controlSize = "sm", variant = if delay == d then "secondary" else "ghost",
        selected = delay == d, onClick = set("delay", d),
      }))
    end
    options = card({
      optionRow("clock", tr("toolbar.delay"), ui.row({ gap = 2 }, delays)),
      optionRow("clipboard", tr("toolbar.clipboard"), ui.glyph({ name = "check", size = 16, color = "primary" })),
    })
    action = tr(if delay > 0 then "toolbar.take_in" else "toolbar.take", { n = delay })
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
    action = tr("toolbar.start")
  end

  return {
    header(),
    segmented({
      { key = "shot", glyph = "camera", text = tr("toolbar.screenshot"), on = isShot, onClick = set("kind", "screenshot") },
      { key = "rec", glyph = "video", text = tr("toolbar.record"), on = not isShot, onClick = set("kind", "record") },
    }),
    section(tr("toolbar.area")),
    ui.row({ gap = 8 }, tiles),
    section(tr("toolbar.options")),
    options,
    ui.spacer({ flexGrow = 1 }),
    ui.button({
      glyph = if isShot then "camera" else "player-record-filled", text = action,
      variant = "primary", controlSize = "lg", onClick = go,
    }),
    ui.label({ text = tr("toolbar.keys"), fontSize = 11, color = "outline", textAlign = "center" }),
  }
end

local function picking(p)
  local starting = p.kind == "record" and p.area ~= "region"
  return {
    header(),
    ui.spacer({ flexGrow = 1 }),
    ui.column({ gap = 10, align = "center" }, {
      ui.glyph({ name = if starting then "loader-2" else "crop", size = 40, color = "primary" }),
      ui.label({ text = tr(if starting then "toolbar.starting" else "toolbar.pick"), fontSize = 15,
        fontWeight = "semibold", color = "on_surface", textAlign = "center" }),
      ui.label({ text = tr("toolbar.esc"), fontSize = 12, color = "outline", textAlign = "center",
        visible = not starting }),
    }),
    ui.spacer({ flexGrow = 1 }),
  }
end

local function recording(s, p)
  local color = if s.paused then "outline" else "error"
  local micLive = p.mic == true and not s.micMuted

  return {
    header(),
    ui.column({ gap = 4, align = "center", paddingV = 18, radius = 12,
      fill = if s.paused then "on_surface/0.04" else "error/0.08" }, {
      ui.row({ gap = 8, align = "center" }, {
        ui.glyph({ name = if s.paused then "player-pause-filled" else "point-filled", size = 16, color = color }),
        ui.label({ text = tr(if s.paused then "toolbar.paused" else "toolbar.recording"),
          fontSize = 12, fontWeight = "semibold", color = color }),
      }),
      ui.label({ text = lib.clock(lib.elapsed(s)), fontSize = 38, fontWeight = "bold", color = "on_surface" }),
      ui.label({ text = tr(if s.mode == "region" then "toolbar.recording_region" else "toolbar.recording_screen"),
        fontSize = 12, color = "on_surface_variant" }),
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
      ui.button({ glyph = "player-stop-filled", text = tr("toolbar.stop"), variant = "destructive",
        controlSize = "lg", flexGrow = 1, onClick = function() lib.request("stop") end }),
      ui.button({ glyph = if s.paused then "player-play-filled" else "player-pause-filled",
        text = tr(if s.paused then "toolbar.resume" else "toolbar.pause"),
        controlSize = "lg", flexGrow = 1, onClick = function() lib.request("pause") end }),
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
  panel.render(ui.column({ padding = 16, gap = 12 }, children))
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
