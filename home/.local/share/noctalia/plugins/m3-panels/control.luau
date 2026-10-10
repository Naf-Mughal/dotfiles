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

-- Active indicator geometry. Every icon reserves REACH px above and below
-- (the groups use widget_spacing = 0, so neighbours touch); the pill normally
-- covers PAD of that and can stretch to REACH toward a neighbour, so while the
-- indicator moves within a group the two pills meet at the shared edge and
-- read as one blob flowing across. The outer box never changes size.
local REACH, PAD = 10, 6
local WIDTH, WIDTH_MAX, WIDTH_IDLE = 28, 30, 20

-- Position along the bar (top to bottom), so the indicator stretches toward
-- wherever the pointer went next - into the neighbour within a group, or
-- across the gap toward another group. Keep in step with the bar layout in
-- ~/.config/noctalia/edges.toml.
local ORDER = {
  notifications = 1, clipboard = 2, media = 4, volume = 5, brightness = 6,
  network = 7, bluetooth = 8, battery = 9, session = 10,
}
local order = ORDER[kind] or 0
local MORPH_MS = 220 -- another icon entered this soon after we left: morph toward it

-- Springs (slightly underdamped: the goo overshoot), stepped in update().
-- Bar widgets tick at ~20 fps however short the interval, so they're stiff
-- enough to settle in about a quarter second.
local function newSpring(x, k, c, eps)
  return { x = x, v = 0, t = x, k = k, c = c, eps = eps }
end
local sp = {
  top = newSpring(0, 600, 36, 0.2), -- px
  bot = newSpring(0, 600, 36, 0.2),
  w = newSpring(WIDTH_IDLE, 520, 28, 0.2),
  a = newSpring(0, 520, 44, 0.02), -- opacity
}
local animating, lastFrame = false, 0
local activeTarget = false

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
  local alpha = math.clamp(sp.a.x, 0, 1)
  -- Content colour: a warning colour wins, then the pill's ink once the pill
  -- is mostly there, else unset so the capsule group's foreground applies.
  local color = st.color or (if alpha > 0.5 then ACTIVE_COLOR else nil)
  -- isVertical() can report false before the bar lays the widget out; these
  -- controls live on the side bar, so stack them.
  local box = ui.column
  local children = {}
  if kind == "battery" then
    -- Solid tonal battery like Noctalia's own: the empty part is a faint
    -- shape, the charge fills it from the bottom, and the bolt sits inside -
    -- in whichever part has more room.
    local ink = color or "on_primary"
    local hole = if alpha > 0.5 then ACTIVE_FILL else "primary"
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
  -- root (hover target) > outer box: fixed footprint, its padding is whatever
  -- the pill doesn't cover > pill: the animated indicator around the content.
  local pt = math.clamp(sp.top.x, 0, REACH)
  local pb = math.clamp(sp.bot.x, 0, REACH)
  local w = math.clamp(sp.w.x, 12, WIDTH_MAX)
  -- Only uniform padding exists, so the uneven top/bottom is spacer boxes.
  local pill = { ui.box({ width = 1, height = pt, fill = "#00000000" }) }
  for _, c in ipairs(children) do
    table.insert(pill, c)
  end
  table.insert(pill, ui.box({ width = 1, height = pb, fill = "#00000000" }))
  barWidget.render(ui.row({ align = "center", justify = "center", onHover = "onControlHover" }, {
    box({ width = WIDTH_MAX, align = "center" }, {
      ui.box({ width = 1, height = REACH - pt, fill = "#00000000" }),
      box({
        gap = 1,
        align = "center",
        justify = "center",
        width = w,
        radius = math.min(w / 2, 14),
        fill = if alpha > 0.01 then ACTIVE_FILL .. "/" .. string.format("%.2f", alpha) else "#00000000",
      }, pill),
      ui.box({ width = 1, height = REACH - pb, fill = "#00000000" }),
    }),
  }))
end

-- Active indicator ------------------------------------------------------------

local function animate()
  if not animating then
    animating = true
    lastFrame = noctalia.nowMs()
  end
  noctalia.setUpdateInterval(16)
end

-- Steps every spring; returns true once all have settled.
local function stepSprings(dt)
  local settled = true
  for _, s in pairs(sp) do
    s.v += (s.k * (s.t - s.x) - s.c * s.v) * dt
    s.x += s.v * dt
    if math.abs(s.t - s.x) > s.eps or math.abs(s.v) > s.eps * 2.5 then
      settled = false
    else
      s.x, s.v = s.t, 0
    end
  end
  return settled
end

-- Shown: full pill. Hidden: shrinks and fades, stretched toward `toward`
-- (-1 up, 1 down) when the pointer moved on to another icon.
local function setActive(on, toward)
  activeTarget = on
  if on then
    sp.top.t, sp.bot.t, sp.w.t, sp.a.t = PAD, PAD, WIDTH, 1
  else
    sp.top.t = if toward == -1 then REACH else 0
    sp.bot.t = if toward == 1 then REACH else 0
    sp.w.t, sp.a.t = WIDTH_IDLE, 0
  end
  animate()
end

-- Active while hovered, or while its panel is open and no other icon is
-- hovered (so the open panel shows which icon it belongs to).
local function wantActive()
  if hovered then
    return true
  end
  local h = noctalia.state.get("m3.hover")
  return h == nil and PANELS[kind] ~= nil and noctalia.state.get("m3.openPanel") == PANELS[kind]
end

local function syncActive(toward)
  local want = wantActive()
  if want ~= activeTarget then
    setActive(want, toward)
  end
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
  local now = noctalia.nowMs()
  if hovered then
    -- Came straight from another icon: start stretched toward it, so the
    -- pill flows in from that side instead of popping up in place.
    local prev = noctalia.state.get("m3.left")
    if type(prev) == "table" and prev.kind ~= kind and now >= prev.at and now - prev.at < MORPH_MS
      and not activeTarget then
      local from = if prev.order < order then -1 else 1
      sp.top.x = if from == -1 then REACH else 0
      sp.bot.x = if from == 1 then REACH else 0
      sp.w.x, sp.a.x = WIDTH_IDLE, 0.85
    end
    noctalia.state.set("m3.hover", { kind = kind, order = order, at = now })
    setActive(true)
  else
    local h = noctalia.state.get("m3.hover")
    if type(h) == "table" and h.kind == kind then
      noctalia.state.set("m3.hover", nil)
    end
    noctalia.state.set("m3.left", { kind = kind, order = order, at = now })
    -- The next icon's enter may already be here (events race between
    -- widgets): morph toward it. Otherwise fade in place; the m3.hover
    -- watcher retargets if the next icon shows up a moment later.
    if activeTarget then
      local h = noctalia.state.get("m3.hover")
      if type(h) == "table" and h.kind ~= kind and math.abs(now - h.at) < MORPH_MS then
        setActive(false, if h.order < order then -1 else 1)
      else
        syncActive(nil)
      end
    end
  end
  if hovered then
    enteredAt = now
    fired = false
    leftAt = nil
  elseif previewing then
    leftAt = now -- give the pointer time to reach the panel
  end
  -- The animation needs 16 ms ticks; update() relaxes the rate afterwards.
  noctalia.setUpdateInterval(if animating then 16 else 30)
end

local lastPoll = 0
function update()
  local now = noctalia.nowMs()
  if animating then
    local dt = math.min(0.06, (now - lastFrame) / 1000)
    lastFrame = now
    if stepSprings(dt) then
      animating = false
      if not activeTarget then
        -- Hidden: drop the stretch so the next entrance starts from the icon.
        sp.top.x, sp.bot.x, sp.w.x = 0, 0, WIDTH_IDLE
        sp.top.t, sp.bot.t, sp.w.t = 0, 0, WIDTH_IDLE
      end
    end
    render()
  end
  if hovered and not fired and now - enteredAt >= HOVER_MS then
    fired = true
    openPanel()
  end
  if leftAt and now - leftAt >= LEAVE_MS then
    endPreview()
  end
  if animating then
    noctalia.setUpdateInterval(16)
  elseif hovered and not fired then
    noctalia.setUpdateInterval(30) -- timing the hover delay
  elseif leftAt ~= nil then
    noctalia.setUpdateInterval(30) -- timing the preview leave
  else
    noctalia.setUpdateInterval(POLL_MS)
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



-- Follow panels opening/closing and other icons being hovered. When another
-- icon takes the hover right after we lost it, stretch our fading pill toward
-- it - the other half of the morph.
noctalia.state.watch("m3.openPanel", function(_)
  syncActive(nil)
end)

noctalia.state.watch("m3.hover", function(h)
  if type(h) == "table" and h.kind ~= kind then
    local left = noctalia.state.get("m3.left")
    -- Events can arrive late and out of order: only a hover that started
    -- after we left (and soon after) is "where the pointer went".
    if type(left) == "table" and left.kind == kind and h.at >= left.at and h.at - left.at < MORPH_MS then
      setActive(false, if h.order < order then -1 else 1)
      return
    end
  end
  syncActive(nil)
end)

refresh()
render()
noctalia.setUpdateInterval(POLL_MS)

