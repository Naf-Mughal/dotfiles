--!nonstrict
-- Audio panel: speaker and microphone sliders (the chip mutes), the output
-- device as a button group of tiles, and a slider per playing app.

local m3 = require("./m3.luau")

local st = {
  volume = 0,
  muted = false,
  mic = 0,
  micMuted = false,
  sinks = {},
  defaultSink = nil,
  sources = {},
  defaultSource = nil,
  apps = {},
  dragging = nil,
}

local throttleVol = m3.throttle(60)
local throttleMic = m3.throttle(60)
local throttleApp = m3.throttle(60)
local iconCache = {}
local render

local function pct(vol)
  if type(vol) ~= "table" then
    return 0
  end
  for _, ch in pairs(vol) do
    local p = tonumber(string.match(ch.value_percent or "", "(%d+)"))
    if p then
      return p
    end
  end
  return 0
end

local function iconFor(props)
  for _, id in ipairs({ props["application.icon_name"], props["application.process.binary"], props["application.name"] }) do
    if type(id) == "string" and id ~= "" then
      local key = string.lower(id)
      local cached = iconCache[key]
      if cached == nil then
        cached = noctalia.appIconPath(key, 40) or false
        iconCache[key] = cached
      end
      if cached then
        return cached
      end
    end
  end
  return nil
end

local function readWp(target, cb)
  noctalia.runAsync({ "wpctl", "get-volume", target }, function(r)
    local v = string.match(r.stdout or "", "Volume:%s*([%d%.]+)")
    if v then
      cb(math.floor(tonumber(v) * 100 + 0.5), string.find(r.stdout, "MUTED", 1, true) ~= nil)
    end
  end)
end

local function refresh()
  if st.dragging == nil then
    readWp("@DEFAULT_AUDIO_SINK@", function(v, m)
      if st.dragging == nil then
        st.volume, st.muted = v, m
        render()
      end
    end)
    readWp("@DEFAULT_AUDIO_SOURCE@", function(v, m)
      if st.dragging == nil then
        st.mic, st.micMuted = v, m
        render()
      end
    end)
  end
  noctalia.runAsync({ "sh", "-c", "pactl get-default-sink; pactl get-default-source" }, function(r)
    local a, b = string.match(r.stdout or "", "^(%S+)\n(%S+)")
    st.defaultSink, st.defaultSource = a, b
    render()
  end)
  noctalia.runAsync({ "pactl", "-f", "json", "list", "sinks" }, function(r)
    local data = noctalia.json.decode(r.stdout or "") or {}
    local list = {}
    for _, s in ipairs(data) do
      table.insert(list, { name = s.name, label = s.description or s.name, bt = string.find(s.name or "", "bluez", 1, true) ~= nil })
    end
    st.sinks = list
    render()
  end)
  noctalia.runAsync({ "pactl", "-f", "json", "list", "sink-inputs" }, function(r)
    if st.dragging and string.sub(st.dragging, 1, 4) == "app-" then
      return
    end
    local data = noctalia.json.decode(r.stdout or "") or {}
    local list = {}
    for _, s in ipairs(data) do
      local p = s.properties or {}
      if p["media.role"] ~= "event" then
        table.insert(list, {
          index = s.index,
          name = p["application.name"] or p["application.process.binary"] or "App",
          media = p["media.name"],
          volume = pct(s.volume),
          muted = s.mute == true,
          icon = iconFor(p),
        })
      end
    end
    st.apps = list
    render()
  end)
end

-- Callbacks -----------------------------------------------------------------

local function onVolume(v)
  st.dragging = "vol"
  st.volume = math.floor(tonumber(v) + 0.5)
  throttleVol(function()
    noctalia.runAsync(m3.msg("volume-set", st.volume .. "%"))
  end)
  render()
end

local function onMic(v)
  st.dragging = "mic"
  st.mic = math.floor(tonumber(v) + 0.5)
  throttleMic(function()
    noctalia.runAsync(m3.msg("mic-volume-set", st.mic .. "%"))
  end)
  render()
end

local function endDrag()
  if st.dragging == "vol" then
    noctalia.runAsync(m3.msg("volume-set", st.volume .. "%"))
  elseif st.dragging == "mic" then
    noctalia.runAsync(m3.msg("mic-volume-set", st.mic .. "%"))
  end
  st.dragging = nil
end

local function appSlider(a)
  local key = "app-" .. tostring(a.index)
  local lead = if a.icon
    then ui.image({ path = a.icon, width = 36, height = 36, radius = 12, fit = "contain" })
    else m3.badge("apps", "secondary", 36)
  return ui.column({ key = key, gap = 8, padding = 12, radius = m3.R_TILE, fill = m3.TILE }, {
    ui.row({ gap = 10, align = "center" }, {
      lead,
      ui.column({ gap = 0, flexGrow = 1 }, {
        ui.label({ text = a.name, fontSize = 13, fontWeight = "semibold", maxLines = 1 }),
        ui.label({ text = a.media or "", fontSize = 11, color = "on_surface_variant", maxLines = 1,
          visible = a.media ~= nil and a.media ~= "" }),
      }),
    }),
    m3.slider(key .. "-s", if a.muted then "volume-off" else "volume", a.volume, 150,
      function(v)
        st.dragging = key
        a.volume = math.floor(tonumber(v) + 0.5)
        throttleApp(function()
          noctalia.runAsync({ "pactl", "set-sink-input-volume", tostring(a.index), a.volume .. "%" })
        end)
        render()
      end,
      function()
        st.dragging = nil
        noctalia.runAsync({ "pactl", "set-sink-input-volume", tostring(a.index), a.volume .. "%" })
      end,
      function()
        a.muted = not a.muted
        render()
        noctalia.runAsync({ "pactl", "set-sink-input-mute", tostring(a.index), "toggle" })
      end,
      a.muted, "Mute " .. a.name, "secondary"),
  })
end

-- View ----------------------------------------------------------------------

render = function()
  local overdrive = noctalia.getSetting("audio.enable_overdrive") == true
  local volGlyph = if st.muted or st.volume == 0 then "volume-off" elseif st.volume < 50 then "volume-2" else "volume"
  local micGlyph = if st.micMuted or st.mic == 0 then "microphone-off" else "microphone"

  local outLabel = "Speakers"
  for _, s in ipairs(st.sinks) do
    if s.name == st.defaultSink then
      outLabel = s.label
    end
  end

  local rows = {
    m3.card("levels", {
      m3.slider("vol", volGlyph, st.volume, if overdrive then 150 else 100, onVolume, endDrag, function()
        st.muted = not st.muted
        render()
        noctalia.runAsync(m3.msg("volume-mute"))
      end, st.muted, "Mute speakers"),
      m3.slider("mic", micGlyph, st.mic, 100, onMic, endDrag, function()
        st.micMuted = not st.micMuted
        render()
        noctalia.runAsync({ "wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle" })
      end, st.micMuted, "Mute microphone", "tertiary"),
    }),
  }

  if #st.sinks > 1 then
    table.insert(rows, m3.section("Output"))
    for _, s in ipairs(st.sinks) do
      table.insert(rows, m3.item({
        key = "sink-" .. s.name,
        lead = if s.bt then "headphones" else "device-speaker",
        title = s.label,
        active = s.name == st.defaultSink,
        onClick = function()
          st.defaultSink = s.name
          render()
          noctalia.runAsync({ "pactl", "set-default-sink", s.name }, function()
            refresh()
          end)
        end,
      }))
    end
  end

  table.insert(rows, m3.section("Apps"))
  if #st.apps == 0 then
    table.insert(rows, ui.label({ text = "Nothing is playing", fontSize = 12, color = "on_surface_variant" }))
  else
    for _, a in ipairs(st.apps) do
      table.insert(rows, appSlider(a))
    end
  end

  panel.render(ui.column({ gap = 12, padding = 16, flexGrow = 1 }, {
    m3.header(volGlyph, "Sound", outLabel, {
      m3.circle("mute", if st.muted then "volume-off" else "volume", st.muted, function()
        st.muted = not st.muted
        render()
        noctalia.runAsync(m3.msg("volume-mute"))
      end, "Mute", 40),
    }),
    ui.scroll({ gap = 8, flexGrow = 1 }, rows),
    m3.footer("Sound settings", function()
      panel.close()
      noctalia.runAsync(m3.msg("panel-open", "control-center", "audio"))
    end),
  }))
end

function onOpen(_context)
  st.dragging = nil
  render()
  refresh()
  noctalia.setUpdateInterval(1500)
end

function onClose()
  noctalia.setUpdateInterval(600000)
end

function update()
  refresh()
end
