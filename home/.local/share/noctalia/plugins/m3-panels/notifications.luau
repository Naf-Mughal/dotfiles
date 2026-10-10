--!nonstrict
-- Notifications panel: history grouped by app into cards (newest app first),
-- with do not disturb and clear all in the header. Noctalia exposes no
-- notification API to plugins, so - like the edges action center - the list
-- comes from the daemon's history file and clearing goes through `noctalia msg`.

local m3 = require("./m3.luau")

local HISTORY = noctalia.expandPath("~/.local/state/noctalia/notification_history.json")
local ASSETS = noctalia.expandPath("~/.local/state/noctalia/notification_history_assets")
local MAX = 40
local PER_APP = 4

local st = { groups = {}, total = 0, mtime = -1, loading = false, dnd = nil, expanded = {} }
local iconCache = {}
local render

local function appIcon(id)
  if type(id) ~= "string" or id == "" then
    return nil
  end
  local c = iconCache[id]
  if c == nil then
    c = noctalia.appIconPath(id, 40) or false
    iconCache[id] = c
  end
  return c or nil
end

local function imageFor(n)
  if type(n.image_data) == "table" and n.image_data.image_file then
    local path = ASSETS .. "/" .. n.image_data.image_file
    if noctalia.fileExists(path) then
      return path
    end
  end
  if type(n.icon) == "string" and string.sub(n.icon, 1, 1) == "/" and noctalia.fileExists(n.icon) then
    return n.icon
  end
  return nil
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

local function apply(raw)
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
  local groups, byApp = {}, {}
  for i = 1, math.min(#entries, MAX) do
    local n = entries[i]
    local app = if (n.app_name or "") ~= "" then n.app_name else "System"
    local g = byApp[app]
    if g == nil then
      g = {
        app = app,
        icon = appIcon(n.desktop_entry) or appIcon(n.app_name)
          or (if type(n.icon) == "string" and string.sub(n.icon, 1, 1) ~= "/" then appIcon(n.icon) else nil),
        items = {},
      }
      byApp[app] = g
      table.insert(groups, g)
    end
    table.insert(g.items, {
      id = tostring(n.id or i),
      summary = n.summary or "",
      body = n.body or "",
      at = n.received_wall_ms or 0,
      image = imageFor(n),
    })
  end
  st.groups = groups
  st.total = math.min(#entries, MAX)
end

local function load()
  local info = noctalia.fileInfo(HISTORY)
  if info == nil then
    st.groups, st.total = {}, 0
    return
  end
  if info.mtime == st.mtime or st.loading then
    return
  end
  st.mtime = info.mtime
  st.loading = true
  noctalia.readFileAsync(HISTORY, function(raw)
    st.loading = false
    apply(raw)
    render()
  end)
end

local function refreshDnd()
  noctalia.runAsync(m3.msg("notification-dnd-status"), function(r)
    st.dnd = noctalia.string.trim(r.stdout or "")
    render()
  end)
end

-- View ----------------------------------------------------------------------

local function entry(n, first)
  local text = {
    ui.row({ gap = 6, align = "center" }, {
      ui.label({ text = n.summary, fontSize = 13, fontWeight = "semibold", maxLines = 1, flexGrow = 1 }),
      ui.label({ text = ago(n.at), fontSize = 11, color = "on_surface_variant" }),
    }),
  }
  if n.body ~= "" then
    table.insert(text, ui.label({ text = n.body, fontSize = 12, color = "on_surface_variant", maxLines = if first then 3 else 2 }))
  end
  local row = { ui.column({ gap = 2, flexGrow = 1 }, text) }
  if n.image then
    table.insert(row, ui.image({ path = n.image, width = 44, height = 44, radius = 14, fit = "cover" }))
  end
  return ui.row({ key = "n" .. n.id, gap = 10, padding = 12, radius = 16, fill = m3.TILE, align = "center" }, row)
end

local function groupCard(g)
  local open = st.expanded[g.app] == true
  local lead = if g.icon
    then ui.image({ path = g.icon, width = 28, height = 28, radius = 10, fit = "contain" })
    else m3.badge("bell", "primary", 28)
  local head = {
    lead,
    ui.label({ text = g.app, fontSize = 13, fontWeight = "bold", maxLines = 1, flexGrow = 1 }),
  }
  if #g.items > 1 then
    table.insert(head, m3.chip("c-" .. g.app, if open then "Less" else tostring(#g.items), function()
      st.expanded[g.app] = not open
      render()
    end, false))
  end
  local children = { ui.row({ gap = 10, align = "center" }, head) }
  local limit = if open then PER_APP * 3 else 1
  for i, n in ipairs(g.items) do
    if i > limit then
      break
    end
    table.insert(children, entry(n, i == 1))
  end
  return m3.card("g-" .. g.app, children, { gap = 8, padding = 12, radius = 24 })
end

render = function()
  local dnd = m3.isOn(st.dnd)
  local subtitle = if dnd then "Do not disturb is on"
    elseif st.total == 0 then "All caught up"
    elseif st.total == 1 then "1 notification"
    else tostring(st.total) .. " notifications"

  local body
  if st.total == 0 then
    body = m3.card("empty", { m3.empty(if dnd then "bell-off" else "bell-check", "No new notifications") }, { grow = 1 })
  else
    local cards = {}
    for _, g in ipairs(st.groups) do
      table.insert(cards, groupCard(g))
    end
    body = ui.scroll({ gap = 8, flexGrow = 1 }, cards)
  end

  panel.render(ui.column({ gap = 12, padding = 16, flexGrow = 1 }, {
    m3.header("bell", "Notifications", subtitle, {
      m3.circle("dnd", if dnd then "bell-off" else "bell-z", dnd, function()
        st.dnd = if dnd then "off" else "on"
        render()
        noctalia.runAsync(m3.msg("notification-dnd-toggle"), refreshDnd)
      end, "Do not disturb", 40),
      m3.circle("clear", "clear-all", false, if st.total > 0 then function()
        noctalia.runAsync(m3.msg("notification-clear-history"), function()
          st.mtime = -1
          st.groups, st.total = {}, 0
          load()
          render()
        end)
      end else nil, "Clear all", 40),
    }),
    body,
  }))
end

function onOpen(_context)
  st.expanded = {}
  load()
  render()
  refreshDnd()
  noctalia.setUpdateInterval(1000)
end

function onClose()
  noctalia.setUpdateInterval(600000)
end

local tick = 0
function update()
  tick += 1
  load()
  if tick % 30 == 0 then
    render()
  end
end
