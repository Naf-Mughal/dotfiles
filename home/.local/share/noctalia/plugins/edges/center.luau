--!nonstrict
-- Action center: the bottom-right panel. Stacked bottom-up like Windows -
-- session buttons at the very bottom, sliders and quick toggles above them,
-- and the notification list filling the rest.
--
-- Noctalia exposes no notification API to plugins, so the list is read from the
-- daemon's history file; clearing goes through `noctalia msg`.

local HISTORY = noctalia.expandPath("~/.local/state/noctalia/notification_history.json")
local ASSETS = noctalia.expandPath("~/.local/state/noctalia/notification_history_assets")
local CONFIRM_MS = 4000
local SLIDER_THROTTLE_MS = 60

local st = {
  notifs = {},
  historyMtime = -1,
  wifi = nil,
  bluetooth = nil,
  dnd = nil,
  profile = nil,
  volume = 0,
  muted = false,
  brightness = nil,
  armed = nil,
  armedAt = 0,
  lastVolumeSent = 0,
  lastBrightnessSent = 0,
  dragging = false,
}

local iconCache = {}

local function msg(...)
  local argv = { "noctalia", "msg" }
  for _, a in ipairs({ ... }) do
    table.insert(argv, a)
  end
  return argv
end

-- Notifications -------------------------------------------------------------

local function iconFor(n)
  if type(n.image_data) == "table" and n.image_data.image_file then
    local path = ASSETS .. "/" .. n.image_data.image_file
    if noctalia.fileExists(path) then
      return path
    end
  end
  if type(n.icon) == "string" and n.icon ~= "" then
    if string.sub(n.icon, 1, 1) == "/" then
      if noctalia.fileExists(n.icon) then
        return n.icon
      end
    else
      local cached = iconCache[n.icon]
      if cached == nil then
        cached = noctalia.appIconPath(n.icon, 32) or false
        iconCache[n.icon] = cached
      end
      if cached then
        return cached
      end
    end
  end
  local app = n.desktop_entry or n.app_name
  if type(app) == "string" and app ~= "" then
    local cached = iconCache[app]
    if cached == nil then
      cached = noctalia.appIconPath(app, 32) or false
      iconCache[app] = cached
    end
    if cached then
      return cached
    end
  end
  return nil
end

local render
local loadingHistory = false

local function applyHistory(raw)
  local data = raw and noctalia.json.decode(raw)
  local entries = {}
  if type(data) == "table" and type(data.entries) == "table" then
    for _, e in ipairs(data.entries) do
      if type(e.notification) == "table" then
        table.insert(entries, e.notification)
      end
    end
  end
  table.sort(entries, function(a, b)
    return (a.received_wall_ms or 0) > (b.received_wall_ms or 0)
  end)
  -- Trim before resolving icons: icon lookups can scan the icon theme.
  local max = noctalia.getConfig("max_notifications") or 30
  local list = {}
  for i = 1, math.min(#entries, max) do
    local n = entries[i]
    table.insert(list, {
      id = tostring(n.id or i),
      app = n.app_name or "",
      summary = n.summary or "",
      body = n.body or "",
      at = n.received_wall_ms or 0,
      icon = iconFor(n),
    })
  end
  st.notifs = list
end

-- Re-reads the daemon's history when it changes, off the UI thread.
local function loadHistory()
  local info = noctalia.fileInfo(HISTORY)
  if info == nil then
    if #st.notifs > 0 then
      st.notifs = {}
      return true
    end
    return false
  end
  if info.mtime == st.historyMtime or loadingHistory then
    return false
  end
  st.historyMtime = info.mtime
  loadingHistory = true
  noctalia.readFileAsync(HISTORY, function(raw, _err)
    loadingHistory = false
    applyHistory(raw)
    if render then
      render()
    end
  end)
  return false
end

local function ago(ms)
  local s = math.max(0, math.floor((noctalia.nowMs() - ms) / 1000))
  if s < 60 then
    return "now"
  elseif s < 3600 then
    return math.floor(s / 60) .. "m"
  elseif s < 86400 then
    return math.floor(s / 3600) .. "h"
  end
  return math.floor(s / 86400) .. "d"
end

-- System state --------------------------------------------------------------


local function readStatus(key, argv)
  noctalia.runAsync(argv, function(r)
    if r.exitCode == 0 then
      st[key] = noctalia.string.trim(r.stdout)
      render()
    end
  end)
end

local function refreshSystem()
  readStatus("wifi", msg("wifi-status"))
  readStatus("bluetooth", msg("bluetooth-status"))
  readStatus("dnd", msg("notification-dnd-status"))
  if noctalia.commandExists("powerprofilesctl") then
    readStatus("profile", { "powerprofilesctl", "get" })
  end
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

local function isOn(v)
  return v == "on" or v == "true" or v == "enabled"
end

-- Callbacks -----------------------------------------------------------------

function onToggleWifi()
  st.wifi = if isOn(st.wifi) then "off" else "on"
  render()
  noctalia.runAsync(msg("wifi-toggle"), function()
    readStatus("wifi", msg("wifi-status"))
  end)
end

function onToggleBluetooth()
  st.bluetooth = if isOn(st.bluetooth) then "off" else "on"
  render()
  noctalia.runAsync(msg("bluetooth-toggle"), function()
    readStatus("bluetooth", msg("bluetooth-status"))
  end)
end

function onToggleDnd()
  st.dnd = if isOn(st.dnd) then "off" else "on"
  render()
  noctalia.runAsync(msg("notification-dnd-toggle"), function()
    readStatus("dnd", msg("notification-dnd-status"))
  end)
end

function onCycleProfile()
  noctalia.runAsync(msg("power-cycle"), function()
    readStatus("profile", { "powerprofilesctl", "get" })
  end)
end

function onCaffeine()
  noctalia.runAsync(msg("caffeine-toggle"))
end

function onNightlight()
  noctalia.runAsync(msg("nightlight-force-toggle"))
end

function onMute()
  st.muted = not st.muted
  render()
  noctalia.runAsync(msg("volume-mute"))
end

function onVolume(value)
  st.dragging = true
  st.volume = math.floor(tonumber(value) + 0.5)
  local now = noctalia.nowMs()
  if now - st.lastVolumeSent >= SLIDER_THROTTLE_MS then
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
  if now - st.lastBrightnessSent >= SLIDER_THROTTLE_MS then
    st.lastBrightnessSent = now
    noctalia.runAsync(msg("brightness-set", st.brightness .. "%"))
  end
  render()
end

function onBrightnessEnd()
  st.dragging = false
  noctalia.runAsync(msg("brightness-set", st.brightness .. "%"))
end

function onClearAll()
  noctalia.runAsync(msg("notification-clear-history"), function()
    st.historyMtime = -1
    loadHistory()
    render()
  end)
end

function onOpenHistory()
  panel.close()
  noctalia.runAsync(msg("panel-open", "control-center", "notifications"))
end

function onOpenSettings()
  panel.close()
  noctalia.runAsync(msg("panel-open", "control-center"))
end

-- Session -------------------------------------------------------------------

local SESSION_GLYPHS = {
  lock = "lock",
  lock_and_suspend = "zzz",
  suspend = "zzz",
  logout = "logout",
  reboot = "refresh",
  shutdown = "power",
}

local NEEDS_CONFIRM = { logout = true, reboot = true, shutdown = true }

local function sessionActions()
  local configured = noctalia.getSetting("shell.session.actions")
  local out = {}
  if type(configured) == "table" and #configured > 0 then
    for _, a in ipairs(configured) do
      if a.enabled ~= false and SESSION_GLYPHS[a.action] then
        table.insert(out, a)
      end
    end
  else
    for _, name in ipairs({ "lock", "lock_and_suspend", "logout", "reboot", "shutdown" }) do
      table.insert(out, { action = name })
    end
  end
  return out
end

local function runSession(a)
  local cmd = a.command
  if (cmd == nil or cmd == "") and (a.action == "reboot" or a.action == "shutdown") then
    local power = noctalia.getSetting("shell.session.power")
    if type(power) == "table" then
      cmd = power[a.action]
    end
  end
  panel.close()
  if cmd ~= nil and cmd ~= "" then
    noctalia.runAsync(cmd)
  else
    local verb = string.gsub(a.action, "_", "-")
    noctalia.runAsync(msg("session", verb))
  end
end

local function onSession(a)
  if NEEDS_CONFIRM[a.action] and not (st.armed == a.action and noctalia.nowMs() - st.armedAt < CONFIRM_MS) then
    st.armed = a.action
    st.armedAt = noctalia.nowMs()
    render()
    return
  end
  st.armed = nil
  runSession(a)
end

-- View ----------------------------------------------------------------------
-- Material 3, after Caelestia's utilities drawer: tonal cards on the panel
-- surface, round icon badges, round icon toggles that fill with the accent when
-- on, and inner tiles for list items.

-- Tonal layers: each level is a light overlay of the text colour on the one
-- below, so cards, tiles and idle buttons stay distinct in dark and light themes.
local CARD_FILL = "on_surface/0.06"
local TILE_FILL = "on_surface/0.06"
local IDLE_FILL = "on_surface/0.09"
local CARD_RADIUS = 24

local function card(key, children, grow)
  return ui.column({ key = key, gap = 12, padding = 14, radius = CARD_RADIUS, fill = CARD_FILL, flexGrow = grow }, children)
end

-- Round tonal badge leading a card header.
local function badge(glyph)
  return ui.row({ width = 40, height = 40, radius = 20, fill = "primary/0.16", align = "center", justify = "center" }, {
    ui.glyph({ name = glyph, size = 18, color = "primary" }),
  })
end

-- Icon button, Material 3 Expressive: a tonal circle when idle that morphs into a
-- wider rounded square in the accent colour when active.
local function circle(key, glyph, active, onClick, tooltip, size)
  size = size or 44
  return ui.row({
    key = key,
    width = if active then math.floor(size * 1.3) else size,
    height = size,
    radius = if active then math.floor(size * 0.32) else size / 2,
    fill = if active then "primary" else IDLE_FILL,
    align = "center",
    justify = "center",
    onClick = onClick,
    tooltip = tooltip,
  }, {
    ui.glyph({ name = glyph, size = math.floor(size * 0.42), color = if active then "on_primary" else "on_surface" }),
  })
end

-- Rounded-square icon button (session actions).
local function square(key, glyph, onClick, tooltip, size, tone)
  size = size or 40
  return ui.row({
    key = key,
    width = size,
    height = size,
    radius = math.floor(size * 0.3),
    fill = tone or IDLE_FILL,
    align = "center",
    justify = "center",
    onClick = onClick,
    tooltip = tooltip,
  }, {
    ui.glyph({ name = glyph, size = math.floor(size * 0.42), color = "on_surface" }),
  })
end

local function header(glyph, title, subtitle, trailing)
  local row = {
    badge(glyph),
    ui.column({ gap = 1, flexGrow = 1 }, {
      ui.label({ text = title, fontSize = 15, fontWeight = "semibold", maxLines = 1 }),
      ui.label({ text = subtitle, fontSize = 12, color = "on_surface_variant", maxLines = 1 }),
    }),
  }
  for _, t in ipairs(trailing or {}) do
    table.insert(row, t)
  end
  return ui.row({ gap = 12, align = "center" }, row)
end

local function notifTile(n)
  local icon = if n.icon
    then ui.image({ path = n.icon, width = 36, height = 36, radius = 12, fit = "cover" })
    else ui.row({ width = 36, height = 36, radius = 12, fill = "primary/0.16", align = "center", justify = "center" }, {
      ui.glyph({ name = "bell", size = 16, color = "primary" }),
    })
  local text = {
    ui.row({ gap = 6, align = "center" }, {
      ui.label({ text = n.app, fontSize = 11, color = "on_surface_variant", maxLines = 1, flexGrow = 1 }),
      ui.label({ text = ago(n.at), fontSize = 11, color = "on_surface_variant" }),
    }),
    ui.label({ text = n.summary, fontWeight = "semibold", maxLines = 1 }),
  }
  if n.body ~= "" then
    table.insert(text, ui.label({ text = n.body, fontSize = 12, color = "on_surface_variant", maxLines = 2 }))
  end
  return ui.row({ key = "n" .. n.id, gap = 12, padding = 12, radius = 16, fill = TILE_FILL }, {
    ui.column({ align = "start" }, { icon }),
    ui.column({ gap = 2, flexGrow = 1 }, text),
  })
end

local function notificationsCard()
  local count = #st.notifs
  local subtitle = if isOn(st.dnd)
    then "Do not disturb is on"
    elseif count == 0 then "All caught up"
    elseif count == 1 then "1 notification"
    else tostring(count) .. " notifications"

  local top = header("bell", "Notifications", subtitle, {
    circle("dnd", if isOn(st.dnd) then "bell-off" else "bell-z", isOn(st.dnd), "onToggleDnd", "Do not disturb", 36),
    square("history", "history", "onOpenHistory", "History", 36),
    square("clear", "clear-all", if count > 0 then "onClearAll" else "", "Clear all", 36),
  })

  local body
  if count == 0 then
    body = ui.column({ flexGrow = 1, align = "center", justify = "center", gap = 8 }, {
      ui.glyph({ name = "bell-z", size = 32, color = "on_surface_variant" }),
      ui.label({ text = "No new notifications", fontSize = 13, color = "on_surface_variant" }),
    })
  else
    local tiles = {}
    for _, n in ipairs(st.notifs) do
      table.insert(tiles, notifTile(n))
    end
    body = ui.scroll({ gap = 8, flexGrow = 1 }, tiles)
  end

  return card("notifications", { top, body }, 1)
end

local function togglesCard()
  local profile = st.profile or "balanced"
  local profileGlyph = ({ ["power-saver"] = "leaf", performance = "rocket" })[profile] or "scale"
  local profileName = string.upper(string.sub(profile, 1, 1)) .. string.gsub(string.sub(profile, 2), "-", " ")
  return card("toggles", {
    ui.label({ text = "Quick Toggles", fontSize = 15, fontWeight = "semibold" }),
    ui.row({ justify = "space_between", align = "center" }, {
      circle("wifi", if isOn(st.wifi) then "wifi" else "wifi-off", isOn(st.wifi), "onToggleWifi", "Wi-Fi"),
      circle(
        "bt",
        if isOn(st.bluetooth) then "bluetooth" else "bluetooth-off",
        isOn(st.bluetooth),
        "onToggleBluetooth",
        "Bluetooth"
      ),
      circle("profile", profileGlyph, profile ~= "balanced", "onCycleProfile", "Power profile: " .. profileName),
      circle("caffeine", "coffee", false, "onCaffeine", "Caffeine"),
      circle("night", "moon", false, "onNightlight", "Night light"),
      circle("more", "settings", false, "onOpenSettings", "Control Center"),
    }),
  })
end

-- Expressive pill slider: thick track, fill from the left, round handle carrying
-- the icon. The percentage chip on the right is a button (mute for volume).
local function sliderRow(key, glyph, value, max, onChange, onEnd, chipClick, chipActive, tooltip)
  return ui.row({ key = key, gap = 10, align = "center" }, {
    ui.slider({
      pill = true,
      thickness = 36,
      glyph = glyph,
      min = 0,
      max = max,
      step = 1,
      value = value,
      flexGrow = 1,
      onChange = onChange,
      onDragEnd = onEnd,
    }),
    ui.row({
      key = key .. "-chip",
      width = 56,
      height = 36,
      radius = 12,
      fill = if chipActive then "primary" else IDLE_FILL,
      align = "center",
      justify = "center",
      onClick = chipClick or "",
      tooltip = tooltip,
    }, {
      ui.label({
        text = tostring(value) .. "%",
        fontSize = 12,
        fontWeight = "semibold",
        color = if chipActive then "on_primary" else "on_surface",
      }),
    }),
  })
end

local function slidersCard()
  local overdrive = noctalia.getSetting("audio.enable_overdrive") == true
  local volGlyph = if st.muted or st.volume == 0 then "volume-off" elseif st.volume < 50 then "volume-2" else "volume"
  local rows = {
    sliderRow("vol", volGlyph, st.volume, if overdrive then 150 else 100, "onVolume", "onVolumeEnd", "onMute", st.muted, "Mute"),
  }
  if st.brightness ~= nil then
    table.insert(rows, sliderRow("bri", "sun", st.brightness, 100, "onBrightness", "onBrightnessEnd", nil, false, "Brightness"))
  end
  return card("sliders", rows)
end

local function sessionCard()
  local buttons = {}
  for _, a in ipairs(sessionActions()) do
    local armed = st.armed == a.action and noctalia.nowMs() - st.armedAt < CONFIRM_MS
    local onClick = function()
      onSession(a)
    end
    if armed then
      table.insert(buttons, ui.row({
        key = "s" .. a.action,
        height = 38,
        paddingH = 14,
        radius = 12,
        fill = "error",
        align = "center",
        justify = "center",
        onClick = onClick,
      }, {
        ui.label({ text = "Sure?", fontSize = 13, fontWeight = "semibold", color = "on_error" }),
      }))
    else
      local label = string.gsub(a.action, "_", " ")
      table.insert(buttons, square("s" .. a.action, SESSION_GLYPHS[a.action], onClick, label, 38))
    end
  end
  return card("session", {
    ui.row({ gap = 8, align = "center" }, {
      ui.column({ gap = 0, flexGrow = 1 }, {
        ui.label({ text = noctalia.formatTime("{:%-I:%M %p}"), fontSize = 20, fontWeight = "bold", maxLines = 1 }),
        ui.label({ text = noctalia.formatTime("{:%A, %b %-d}"), fontSize = 12, color = "on_surface_variant", maxLines = 1 }),
      }),
      ui.row({ gap = 6, align = "center" }, buttons),
    }),
  })
end

render = function()
  panel.render(ui.column({ gap = 10, flexGrow = 1 }, {
    notificationsCard(),
    togglesCard(),
    slidersCard(),
    sessionCard(),
  }))
end

-- Lifecycle -----------------------------------------------------------------

function onOpen(_context)
  st.armed = nil
  st.dragging = false
  loadHistory()
  render()
  refreshSystem()
  noctalia.setUpdateInterval(1000)
end

function onClose()
  st.armed = nil
  noctalia.setUpdateInterval(60000)
end

local tick = 0
function update()
  tick += 1
  local changed = loadHistory()
  if tick % 3 == 0 then
    refreshSystem()
  end
  -- The confirm timeout needs per-second renders; "ago" labels can wait 30s.
  if changed or st.armed or tick % 30 == 0 then
    render()
  end
end
