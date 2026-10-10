--!nonstrict
-- Media panel: artwork, title and artist, a seek bar and the transport
-- controls, with the play button as the big shape-shifting centrepiece. Reads
-- playerctl; more than one player shows a chip to switch between them.

local m3 = require("./m3.luau")

local ART = "/tmp/noctalia-m3-media-art"

local st = {
  players = {},
  player = nil,
  status = nil,
  title = nil,
  artist = nil,
  album = nil,
  art = nil,
  artUrl = nil,
  position = 0,
  length = 0,
  seeking = false,
  shuffle = nil,
  loop = nil,
}

local render
local artSlot = 0

local function fmt(us)
  local s = math.floor((us or 0) / 1e6)
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local function pc(...)
  local argv = { "playerctl" }
  if st.player then
    table.insert(argv, "-p")
    table.insert(argv, st.player)
  end
  for _, a in ipairs({ ... }) do
    table.insert(argv, a)
  end
  return argv
end

local function loadArt(url)
  if url == st.artUrl then
    return
  end
  st.artUrl = url
  st.art = nil
  if url == nil or url == "" then
    return
  end
  if string.sub(url, 1, 7) == "file://" then
    local path = noctalia.string.urlDecode(string.sub(url, 8))
    if noctalia.fileExists(path) then
      st.art = path
    end
  elseif string.sub(url, 1, 4) == "http" then
    -- Two slots, so the image node always sees a new path for new artwork.
    artSlot = 1 - artSlot
    local dest = ART .. "-" .. tostring(artSlot) .. ".img"
    noctalia.download(url, dest, function(ok)
      if ok and st.artUrl == url then
        st.art = dest
        render()
      end
    end)
  end
end

local function refresh()
  noctalia.runAsync({ "playerctl", "-l" }, function(r)
    local list = {}
    for l in string.gmatch(r.stdout or "", "[^\n]+") do
      table.insert(list, l)
    end
    st.players = list
    if st.player and not table.find(list, st.player) then
      st.player = nil
    end
    local fmtStr = "{{status}}\t{{title}}\t{{artist}}\t{{album}}\t{{mpris:artUrl}}\t{{position}}\t{{mpris:length}}\t{{shuffle}}\t{{loop}}"
    noctalia.runAsync(pc("metadata", "--format", fmtStr), function(m)
      if m.exitCode ~= 0 then
        st.status = nil
        render()
        return
      end
      local f = string.split(noctalia.string.trim(m.stdout or ""), "\t")
      st.status = f[1]
      st.title = f[2]
      st.artist = f[3]
      st.album = f[4]
      loadArt(f[5])
      if not st.seeking then
        st.position = tonumber(f[6]) or 0
      end
      st.length = tonumber(f[7]) or 0
      st.shuffle = f[8] == "true"
      st.loop = f[9]
      render()
    end)
  end)
end

local function act(...)
  local argv = pc(...)
  noctalia.runAsync(argv, function()
    refresh()
  end)
end

local function ctl(key, glyph, onClick, size, active, tooltip)
  return m3.circle(key, glyph, active, onClick, tooltip, size)
end

render = function()
  if st.status == nil then
    panel.render(ui.column({ onHover = m3.panelHover, gap = 12, padding = 16, flexGrow = 1 }, {
      m3.header("music", "Media", "Nothing playing", {}),
      m3.card("empty", { m3.empty("player-play", "Play something and it shows up here") }, { grow = 1 }),
    }))
    return
  end

  local playing = st.status == "Playing"
  local art = if st.art
    then ui.image({ path = st.art, width = 96, height = 96, radius = 28, fit = "cover" })
    else ui.row({ width = 96, height = 96, radius = 28, fill = "primary/0.16", align = "center", justify = "center" }, {
      ui.glyph({ name = "music", size = 40, color = "primary" }),
    })

  local playerName = st.player or (st.players[1] or "")
  playerName = string.match(playerName, "^([^.]+)") or playerName

  local top = ui.row({ gap = 14, align = "center" }, {
    art,
    ui.column({ gap = 3, flexGrow = 1 }, {
      m3.chip("player", m3.cap(playerName), if #st.players > 1 then function()
        local idx = (table.find(st.players, st.player or st.players[1]) or 1) % #st.players + 1
        st.player = st.players[idx]
        st.artUrl = nil
        refresh()
      end else nil, false, "tertiary"),
      ui.label({ text = st.title or "", fontSize = 16, fontWeight = "bold", maxLines = 2 }),
      ui.label({ text = st.artist or "", fontSize = 12, color = "on_surface_variant", maxLines = 1 }),
    }),
  })

  local seek = ui.column({ gap = 2 }, {
    ui.slider({
      key = "seek",
      min = 0,
      max = math.max(1, math.floor(st.length / 1e6)),
      step = 1,
      value = math.floor(st.position / 1e6),
      enabled = st.length > 0,
      onChange = function(v)
        st.seeking = true
        st.position = tonumber(v) * 1e6
        render()
      end,
      onDragEnd = function()
        st.seeking = false
        act("position", tostring(math.floor(st.position / 1e6)))
      end,
    }),
    ui.row({ paddingH = 4 }, {
      ui.label({ text = fmt(st.position), fontSize = 11, color = "on_surface_variant", flexGrow = 1 }),
      ui.label({ text = fmt(st.length), fontSize = 11, color = "on_surface_variant" }),
    }),
  })

  local controls = ui.row({ gap = 8, align = "center", justify = "center" }, {
    ctl("shuffle", "arrows-shuffle", function()
      act("shuffle", "toggle")
    end, 40, st.shuffle == true, "Shuffle"),
    ctl("prev", "player-skip-back-filled", function()
      act("previous")
    end, 48),
    ui.row({
      key = "play",
      width = 84,
      height = 60,
      radius = if playing then 20 else 30,
      fill = "primary",
      align = "center",
      justify = "center",
      onClick = function()
        st.status = if playing then "Paused" else "Playing"
        render()
        act("play-pause")
      end,
    }, {
      ui.glyph({ name = if playing then "player-pause-filled" else "player-play-filled", size = 26, color = "on_primary" }),
    }),
    ctl("next", "player-skip-forward-filled", function()
      act("next")
    end, 48),
    ctl("loop", if st.loop == "Track" then "repeat-once" else "repeat", function()
      act("loop", if st.loop == "None" then "Playlist" elseif st.loop == "Playlist" then "Track" else "None")
    end, 40, st.loop ~= nil and st.loop ~= "None" and st.loop ~= "", "Repeat"),
  })

  panel.render(ui.column({ onHover = m3.panelHover, gap = 14, padding = 16, flexGrow = 1 }, {
    m3.card("now", { top, seek, controls }, { grow = 1, gap = 14, padding = 16 }),
  }))
end

function onOpen(_context)
  m3.panelOpened("nafeel/m3-panels:media")
  render()
  refresh()
  panel.setWantsSecondTicks(true)
end

function onClose()
  m3.panelClosed()
end

local tick = 0
function update()
  tick += 1
  if st.status == "Playing" and not st.seeking then
    st.position += 1e6
    render()
  end
  if tick % 3 == 0 then
    refresh()
  end
end
