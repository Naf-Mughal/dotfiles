--!nonstrict
-- Sliders: volume and brightness as vertical pills, attached to the right bar
-- like Caelestia's OSD drawer. Opened by the right bar's hover zone. Drag or
-- scroll a pill; the handle shows the value while dragging.

local THROTTLE_MS = 60

local st = {
  volume = 0,
  muted = false,
  brightness = nil,
  dragging = false,
  lastVolumeSent = 0,
  lastBrightnessSent = 0,
}

local function msg(...)
  local argv = { "noctalia", "msg" }
  for _, a in ipairs({ ... }) do
    table.insert(argv, a)
  end
  return argv
end

local render

local function refresh()
  if st.dragging then
    return
  end
  noctalia.runAsync({ "wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@" }, function(r)
    local v = string.match(r.stdout or "", "Volume:%s*([%d%.]+)")
    if v and not st.dragging then
      st.volume = math.floor(tonumber(v) * 100 + 0.5)
      st.muted = string.find(r.stdout, "MUTED", 1, true) ~= nil
      render()
    end
  end)
  if noctalia.commandExists("brightnessctl") then
    noctalia.runAsync({ "brightnessctl", "-m", "-c", "backlight" }, function(r)
      local pct = string.match(r.stdout or "", ",(%d+)%%,")
      if pct and not st.dragging then
        st.brightness = tonumber(pct)
        render()
      end
    end)
  end
end

function onVolume(value)
  st.dragging = true
  st.volume = math.floor(tonumber(value) + 0.5)
  local now = noctalia.nowMs()
  if now - st.lastVolumeSent >= THROTTLE_MS then
    st.lastVolumeSent = now
    noctalia.runAsync(msg("volume-set", st.volume .. "%"))
  end
  render()
end

function onVolumeEnd()
  st.dragging = false
  noctalia.runAsync(msg("volume-set", st.volume .. "%"))
end

function onBrightness(value)
  st.dragging = true
  st.brightness = math.max(1, math.floor(tonumber(value) + 0.5))
  local now = noctalia.nowMs()
  if now - st.lastBrightnessSent >= THROTTLE_MS then
    st.lastBrightnessSent = now
    noctalia.runAsync(msg("brightness-set", st.brightness .. "%"))
  end
  render()
end

function onBrightnessEnd()
  st.dragging = false
  noctalia.runAsync(msg("brightness-set", st.brightness .. "%"))
end

local function pill(glyph, value, max, onChange, onEnd)
  return ui.slider({
    vertical = true,
    length = 150,
    thickness = 28,
    glyph = glyph,
    min = 0,
    max = max,
    step = 1,
    value = value,
    onChange = onChange,
    onDragEnd = onEnd,
  })
end

render = function()
  local overdrive = noctalia.getSetting("audio.enable_overdrive") == true
  local volGlyph = if st.muted or st.volume == 0 then "volume-off" elseif st.volume < 50 then "volume-2" else "volume"
  local pills = { pill(volGlyph, st.volume, if overdrive then 150 else 100, "onVolume", "onVolumeEnd") }
  if st.brightness ~= nil then
    table.insert(pills, pill("sun", st.brightness, 100, "onBrightness", "onBrightnessEnd"))
  end
  panel.render(ui.column({ gap = 12, align = "center", justify = "center", flexGrow = 1 }, pills))
end

function onOpen(_context)
  st.dragging = false
  render()
  refresh()
  noctalia.setUpdateInterval(1500)
end

function onClose()
  noctalia.setUpdateInterval(60000)
end

function update()
  refresh()
end
