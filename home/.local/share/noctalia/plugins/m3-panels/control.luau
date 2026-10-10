--!nonstrict
-- Bar control: one icon per instance (`kind` picks which), drawn from live
-- state, that previews its panel when the pointer rests on it (gone again if
-- the pointer leaves without going into it) - no tooltip, the details live in
-- the panel. Click toggles the panel; right-click does the
-- quick action (Wi-Fi / Bluetooth on-off, mute, play-pause, do not disturb).
-- Scrolling is bound in config ([widget.<name>.actions]).

local m3 = require("./m3.luau")

local HOVER_MS = 140
local POLL_MS = 3000
local LEAVE_MS = 350

local kind = noctalia.getConfig("kind") or "network"
-- Active look: a filled pill behind the icon while hovered or its panel is open, in the
-- inverse of the group's colours, set per instance to match its capsule group.
local ACTIVE_FILL = noctalia.getConfig("active_fill") or "on_primary"
local ACTIVE_COLOR = noctalia.getConfig("active_color") or "primary"

local PANELS = {
  network = "nafeel/m3-panels:network",
  bluetooth = "nafeel/m3-panels:bluetooth",
  volume = "nafeel/m3-panels:audio",
  brightness = "nafeel/m3-panels:brightness",
  battery = "nafeel/m3-panels:battery",
  session = "nafeel/m3-panels:session",
  media = "nafeel/m3-panels:media",
  notifications = "nafeel/m3-panels:notifications",
}

-- Noctalia's own panels, opened over IPC on the bar this widget lives on.
local BUILTIN = { clipboard = "clipboard" }

local st = { glyph = nil, label = nil, color = nil, image = nil, hidden = false }
local hovered, enteredAt, fired = false, 0, false
local render

-- State readers ---------------------------------------------------------------

local function run(argv, cb)
  noctalia.runAsync(argv, function(r)
    cb(r.stdout or "", r.exitCode)
    render()
  end)
end

local READERS = {}

READERS.network = function()
  run({ "sh", "-c", "nmcli -t -f WIFI radio; nmcli -t -f ACTIVE,SIGNAL dev wifi | grep '^yes' | head -1;"
    .. " nmcli -t -f TYPE,STATE dev | grep -c '^ethernet:connected'" }, function(out)
    local radio, sig, eth = string.match(out, "^(%S+)\n(.-)\n?(%d+)%s*$")
    local signal = tonumber(string.match(sig or "", "yes:(%d+)"))
    if eth and tonumber(eth) > 0 and not signal then
      st.glyph = "network"
    elseif radio ~= "enabled" then
      st.glyph = "wifi-off"
    elseif signal == nil then
      st.glyph = "wifi-0"
    else
      st.glyph = if signal >= 70 then "wifi-3" elseif signal >= 45 then "wifi-2" elseif signal >= 20 then "wifi-1" else "wifi-0"
    end
  end)
end

READERS.bluetooth = function()
  run({ "sh", "-c", "bluetoothctl show | grep -c 'Powered: yes'; bluetoothctl devices Connected | grep -c ^Device" },
    function(out)
      local on, n = string.match(out, "(%d+)%s+(%d+)")
      st.glyph = if on ~= "1" then "bluetooth-off" elseif tonumber(n or 0) > 0 then "bluetooth-connected" else "bluetooth"
    end)
end

READERS.volume = function()
  run({ "wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@" }, function(out)
    local v = tonumber(string.match(out, "Volume:%s*([%d%.]+)") or "") or 0
    local muted = string.find(out, "MUTED", 1, true) ~= nil
    st.glyph = if muted then "volume-mute" elseif v == 0 then "volume-zero" elseif v < 0.5 then "volume-low" else "volume-high"
    st.color = if muted then "error" else nil
  end)
end

READERS.brightness = function()
  run({ "brightnessctl", "-m", "-c", "backlight" }, function(out)
    local p = tonumber(string.match(out, ",(%d+)%%,") or "")
    st.hidden = p == nil
    p = p or 0
    st.glyph = if p < 50 then "brightness-low" else "brightness-high"
  end)
end

READERS.battery = function()
  run({ "sh", "-c", "upower -i \"$(upower -e | grep -m1 BAT)\" | grep -E 'state|percentage'" }, function(out)
    local p = tonumber(string.match(out, "percentage:%s*([%d%.]+)") or "")
    local state = string.match(out, "state:%s*([%w%-]+)") or ""
    st.hidden = p == nil
    p = math.floor(p or 0)
    st.level = p
    local charging = state == "charging" or state == "fully-charged" or state == "pending-charge"
    st.charging = charging
    st.label = tostring(p)
    local warn = noctalia.getSetting("battery.warning_threshold") or 20
    st.color = if not charging and p <= warn then "error" else nil
  end)
end

local HISTORY = noctalia.expandPath("~/.local/state/noctalia/notification_history.json")

READERS.notifications = function()
  run(m3.msg("notification-dnd-status"), function(out)
    st.glyph = if m3.isOn(noctalia.string.trim(out)) then "bell-off" else "bell"
    local info = noctalia.fileInfo(HISTORY)
    local seen = noctalia.state.get("m3.notifSeen") or 0
    st.dot = info ~= nil and info.size > 64 and info.mtime * 1000 > seen
  end)
end

READERS.media = function()
  run({ "playerctl", "metadata", "--format", "{{status}}\t{{mpris:artUrl}}" }, function(out, code)
    local status, art = string.match(out, "^(%S*)\t(.-)%s*$")
    st.hidden = code ~= 0 or status == nil or status == ""
    st.image = nil
    if art and string.sub(art, 1, 7) == "file://" then
      local path = noctalia.string.urlDecode(string.sub(art, 8))
      if noctalia.fileExists(path) then
        st.image = path
      end
    end
    st.glyph = if status == "Playing" then "player-play-filled" else "player-pause-filled"
  end)
end

READERS.clipboard = function()
  st.glyph = "clipboard"
end

READERS.session = function()
  st.glyph = "power"
end


local function refresh()
  local reader = READERS[kind]
  if reader then
    reader()
  end
end

-- View ----------------------------------------------------------------------

render = function()
  if st.hidden then
    barWidget.setVisible(false)
    return
  end
  barWidget.setVisible(true)
  -- Active while hovered, and while its panel is open (so the panel always
  -- shows which icon it belongs to).
  local active = hovered or (PANELS[kind] ~= nil and noctalia.state.get("m3.openPanel") == PANELS[kind])
  -- Content colour: a warning colour wins, then the active pill's ink, else
  -- unset so the capsule group's foreground applies.
  local color = st.color or (if active then ACTIVE_COLOR else nil)
  -- isVertical() can report false before the bar lays the widget out; these
  -- controls live on the side bar, so stack them.
  local box = ui.column
  local children = {}
  if kind == "battery" then
    -- Solid tonal battery like Noctalia's own: the empty part is a faint
    -- shape, the charge fills it from the bottom, and the bolt sits inside -
    -- in whichever part has more room.
    local ink = color or "on_primary"
    local hole = if active then ACTIVE_FILL else "primary"
    local height = 24
    local level = math.floor(height * (st.level or 0) / 100 + 0.5)
    local bolt = function(c)
      return if st.charging then { ui.glyph({ name = "bolt", size = 11, color = c }) } else {}
    end
    local boltLow = (st.level or 0) < 50
    table.insert(children, ui.column({ gap = 1, align = "center" }, {
      ui.box({ width = 7, height = 3, radius = 1, fill = ink .. "/0.35" }),
      ui.column({ width = 16, height = height, radius = 5, fill = ink .. "/0.35", justify = "end" }, {
        ui.column({ flexGrow = 1, align = "center", justify = "center" }, if boltLow then bolt(ink) else {}),
        ui.column({ height = level, radius = 5, fill = ink, align = "center", justify = "center" },
          if boltLow then {} else bolt(hole)),
      }),
    }))
  elseif st.image then
    table.insert(children, ui.image({ path = st.image, width = 22, height = 22, radius = 11, fit = "cover" }))
  else
    table.insert(children, ui.glyph({ name = st.glyph or "point", color = color }))
    if st.dot then
      table.insert(children, ui.box({ width = 5, height = 5, radius = 3, fill = "error" }))
    end
  end
  if st.label then
    table.insert(children, ui.label({ text = st.label, fontSize = 11, fontWeight = "bold", color = color }))
  end
  -- The bar lays the root out along its own axis; the inner box stacks. While
  -- the panel is open, the inner box becomes the filled active pill.
  barWidget.render(ui.row({ align = "center", justify = "center", onHover = "onControlHover" }, {
    box({
      gap = 1,
      align = "center",
      justify = "center",
      width = 30,
      paddingV = 5, -- constant, so hovering never shifts the group
      radius = 15,
      fill = if active then ACTIVE_FILL else "#00000000",
    }, children),
  }))
end

-- Hover / click ---------------------------------------------------------------

local function builtin(verb)
  noctalia.runAsync(m3.msg(verb, "@default", BUILTIN[kind]))
end

-- The panel this icon opened by hover, and when the pointer left the icon.
local previewing, leftAt = nil, nil

local function openPanel()
  if BUILTIN[kind] then
    builtin("panel-open")
    return
  end
  local id = PANELS[kind]
  if id and noctalia.state.get("m3.openPanel") ~= id then
    noctalia.togglePanel(id)
    previewing = id
  end
end

-- Hover preview ended: close it unless the pointer went into the panel or the
-- icon was clicked in the meantime.
local function endPreview()
  local id = previewing
  previewing, leftAt = nil, nil
  if id and noctalia.state.get("m3.openPanel") == id and noctalia.state.get("m3.entered") ~= true then
    noctalia.togglePanel(id)
  end
end

function onControlHover(state)
  hovered = state == "true"
  render()
  if hovered then
    enteredAt = noctalia.nowMs()
    fired = false
    leftAt = nil
    noctalia.setUpdateInterval(30)
  elseif previewing then
    leftAt = noctalia.nowMs() -- give the pointer time to reach the panel
  else
    noctalia.setUpdateInterval(POLL_MS)
  end
end

local lastPoll = 0
function update()
  local now = noctalia.nowMs()
  if hovered and not fired and now - enteredAt >= HOVER_MS then
    fired = true
    openPanel()
  end
  if leftAt and now - leftAt >= LEAVE_MS then
    endPreview()
  end
  if not hovered and leftAt == nil then
    noctalia.setUpdateInterval(POLL_MS)
  elseif fired and leftAt == nil then
    noctalia.setUpdateInterval(POLL_MS) -- resting on the icon: nothing to time
  end
  if now - lastPoll >= POLL_MS then
    lastPoll = now
    refresh()
  end
end

-- Click toggles the panel (and stops a hover preview from closing it).
function onClick()
  if BUILTIN[kind] then
    builtin("panel-toggle")
    return
  end
  local id = PANELS[kind]
  if id then
    previewing, leftAt = nil, nil
    noctalia.togglePanel(id)
  end
end

function onRightClick()
  if kind == "network" then
    noctalia.runAsync(m3.msg("wifi-toggle"))
  elseif kind == "bluetooth" then
    noctalia.runAsync(m3.msg("bluetooth-toggle"))
  elseif kind == "volume" then
    noctalia.runAsync(m3.msg("volume-mute"))
  elseif kind == "media" then
    noctalia.runAsync(m3.msg("media", "toggle"))
  elseif kind == "notifications" then
    noctalia.runAsync(m3.msg("notification-dnd-toggle"))
  end
  lastPoll = 0
end



-- Re-render when any panel opens or closes, so the active pill follows it.
noctalia.state.watch("m3.openPanel", function(_)
  render()
end)

refresh()
render()
noctalia.setUpdateInterval(POLL_MS)
