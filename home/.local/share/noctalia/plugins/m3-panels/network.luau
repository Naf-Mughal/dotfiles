--!nonstrict
-- Wi-Fi panel: master toggle, the current connection as a hero card, and the
-- networks in range. Saved networks connect on click, open ones too; secured
-- new ones unfold a password field in place. Everything goes through nmcli.

local m3 = require("./m3.luau")

local st = {
  enabled = nil,
  networks = {},
  saved = {},
  active = nil,
  ethernet = nil,
  ip = nil,
  scanning = false,
  busy = nil,
  askFor = nil,
  password = "",
  error = nil,
}

local render

-- nmcli -t escapes ':' inside fields as '\:'.
local function splitTerse(line)
  local out, cur, i = {}, {}, 1
  while i <= #line do
    local c = string.sub(line, i, i)
    if c == "\\" and i < #line then
      table.insert(cur, string.sub(line, i + 1, i + 1))
      i += 2
    elseif c == ":" then
      table.insert(out, table.concat(cur))
      cur = {}
      i += 1
    else
      table.insert(cur, c)
      i += 1
    end
  end
  table.insert(out, table.concat(cur))
  return out
end

local function lines(s)
  local out = {}
  for l in string.gmatch(s or "", "[^\n]+") do
    table.insert(out, l)
  end
  return out
end

local function signalGlyph(s)
  if s >= 70 then
    return "wifi"
  elseif s >= 45 then
    return "wifi-2"
  elseif s >= 20 then
    return "wifi-1"
  end
  return "wifi-0"
end

local function refresh(rescan)
  noctalia.runAsync({ "nmcli", "-t", "-f", "WIFI", "radio" }, function(r)
    st.enabled = noctalia.string.trim(r.stdout or "") == "enabled"
    render()
  end)
  noctalia.runAsync({ "nmcli", "-t", "-f", "NAME,TYPE", "connection", "show" }, function(r)
    local saved = {}
    for _, l in ipairs(lines(r.stdout)) do
      local f = splitTerse(l)
      if f[2] == "802-11-wireless" then
        saved[f[1]] = true
      end
    end
    st.saved = saved
    render()
  end)
  noctalia.runAsync({ "nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device" }, function(r)
    st.ethernet = nil
    for _, l in ipairs(lines(r.stdout)) do
      local f = splitTerse(l)
      if f[2] == "ethernet" and f[3] == "connected" then
        st.ethernet = f[4]
      end
    end
    render()
  end)
  noctalia.runAsync({ "sh", "-c", "ip -4 -o addr show scope global | awk '{print $4; exit}'" }, function(r)
    st.ip = noctalia.string.trim(r.stdout or "")
    render()
  end)
  if rescan then
    st.scanning = true
  end
  noctalia.runAsync({ "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan",
    if rescan then "yes" else "auto" }, function(r)
    st.scanning = false
    local seen, list = {}, {}
    st.active = nil
    for _, l in ipairs(lines(r.stdout)) do
      local f = splitTerse(l)
      local ssid = f[2] or ""
      if ssid ~= "" then
        local net = { ssid = ssid, signal = tonumber(f[3]) or 0, secure = (f[4] or "") ~= "", inUse = f[1] == "*" }
        if net.inUse then
          st.active = net
        end
        local prev = seen[ssid]
        if prev == nil then
          seen[ssid] = net
          table.insert(list, net)
        elseif net.inUse or (not prev.inUse and net.signal > prev.signal) then
          prev.signal, prev.inUse, prev.secure = net.signal, prev.inUse or net.inUse, net.secure
        end
      end
    end
    table.sort(list, function(a, b)
      if a.inUse ~= b.inUse then
        return a.inUse
      end
      return a.signal > b.signal
    end)
    st.networks = list
    render()
  end)
end

local function connect(ssid, password)
  st.busy = ssid
  st.error = nil
  render()
  local argv
  if st.saved[ssid] and password == nil then
    argv = { "nmcli", "connection", "up", "id", ssid }
  else
    argv = { "nmcli", "device", "wifi", "connect", ssid }
    if password then
      table.insert(argv, "password")
      table.insert(argv, password)
    end
  end
  noctalia.runAsync(argv, function(r)
    st.busy = nil
    if r.exitCode == 0 then
      st.askFor = nil
      st.password = ""
    else
      st.error = noctalia.string.trim((r.stderr or "") .. (r.stdout or ""))
      if st.error == "" then
        st.error = "Couldn't connect"
      end
    end
    refresh(false)
  end)
end

local function onNetwork(net)
  if net.inUse or st.busy then
    return
  end
  if st.saved[net.ssid] or not net.secure then
    connect(net.ssid, nil)
  else
    st.askFor = if st.askFor == net.ssid then nil else net.ssid
    st.password = ""
    st.error = nil
    render()
  end
end

local function disconnect()
  if st.active then
    noctalia.runAsync({ "nmcli", "connection", "down", "id", st.active.ssid }, function()
      refresh(false)
    end)
  end
end

local function forget(ssid)
  noctalia.runAsync({ "nmcli", "connection", "delete", "id", ssid }, function()
    refresh(false)
  end)
end

-- View ----------------------------------------------------------------------

local function hero()
  if not st.enabled then
    return m3.card("hero", { m3.empty("wifi-off", "Wi-Fi is off") })
  end
  if st.active == nil and st.ethernet == nil then
    return m3.card("hero", {
      ui.row({ gap = 12, align = "center" }, {
        m3.badge("wifi-0", "on_surface", 52),
        ui.column({ gap = 2, flexGrow = 1 }, {
          ui.label({ text = "Not connected", fontSize = 16, fontWeight = "bold" }),
          ui.label({ text = "Pick a network below", fontSize = 12, color = "on_surface_variant" }),
        }),
      }),
    })
  end
  local name = if st.active then st.active.ssid else st.ethernet
  local glyph = if st.active then signalGlyph(st.active.signal) else "network"
  local sub = if st.active then (tostring(st.active.signal) .. "% signal") else "Ethernet"
  if st.ip and st.ip ~= "" then
    sub = sub .. "  ·  " .. st.ip
  end
  return m3.card("hero", {
    ui.row({ gap = 14, align = "center" }, {
      ui.row({ width = 56, height = 56, radius = 20, fill = "on_primary/0.18", align = "center", justify = "center" }, {
        ui.glyph({ name = glyph, size = 26, color = "on_primary" }),
      }),
      ui.column({ gap = 2, flexGrow = 1 }, {
        ui.label({ text = "Connected", fontSize = 11, fontWeight = "semibold", color = "on_primary/0.8" }),
        ui.label({ text = name, fontSize = 18, fontWeight = "bold", color = "on_primary", maxLines = 1 }),
        ui.label({ text = sub, fontSize = 12, color = "on_primary/0.8", maxLines = 1 }),
      }),
      if st.active
        then ui.row({ key = "disc", width = 44, height = 44, radius = 22, fill = "on_primary/0.18",
          align = "center", justify = "center", onClick = disconnect, tooltip = "Disconnect" }, {
          ui.glyph({ name = "plug-connected-x", size = 18, color = "on_primary" }),
        })
        else ui.spacer({ width = 0 }),
    }),
  }, { fill = "primary", padding = 16 })
end

local function passwordRow(net)
  local children = {
    ui.row({ gap = 8, align = "center" }, {
      ui.input({
        key = "pw-" .. net.ssid,
        placeholder = "Password for " .. net.ssid,
        password = true,
        focus = true,
        flexGrow = 1,
        onChange = function(v)
          st.password = v
        end,
        onSubmit = function(v)
          connect(net.ssid, v)
        end,
      }),
      m3.circle("go", "arrow-right", true, function()
        connect(net.ssid, st.password)
      end, "Connect", 38),
    }),
  }
  if st.error then
    table.insert(children, ui.label({ text = st.error, fontSize = 11, color = "error", maxLines = 2 }))
  end
  return ui.column({ key = "ask-" .. net.ssid, gap = 6, paddingH = 6, paddingV = 4 }, children)
end

local function networkList()
  local rows = {}
  for _, net in ipairs(st.networks) do
    if not net.inUse then
      local trailing = {}
      if st.busy == net.ssid then
        table.insert(trailing, ui.glyph({ name = "loader-2", size = 18, color = "primary" }))
      elseif st.saved[net.ssid] then
        table.insert(trailing, ui.row({ key = "f-" .. net.ssid, width = 32, height = 32, radius = 16, fill = m3.IDLE,
          align = "center", justify = "center", tooltip = "Forget", onClick = function()
            forget(net.ssid)
          end }, { ui.glyph({ name = "trash", size = 14, color = "on_surface_variant" }) }))
      end
      table.insert(rows, m3.item({
        key = "n-" .. net.ssid,
        lead = signalGlyph(net.signal),
        title = net.ssid,
        subtitle = (if st.saved[net.ssid] then "Saved" elseif net.secure then "Secured" else "Open")
          .. "  ·  " .. tostring(net.signal) .. "%",
        trailing = trailing,
        onClick = function()
          onNetwork(net)
        end,
      }))
      if st.askFor == net.ssid then
        table.insert(rows, passwordRow(net))
      end
    end
  end
  if #rows == 0 then
    return m3.empty("antenna-bars-off", if st.scanning then "Scanning…" else "No networks found")
  end
  return ui.scroll({ gap = 6, flexGrow = 1 }, rows)
end

render = function()
  local subtitle = if st.enabled == false then "Off"
    elseif st.active then st.active.ssid
    elseif st.ethernet then "Ethernet"
    else "Not connected"
  local children = {
    m3.header("wifi", "Wi-Fi", subtitle, {
      m3.circle("scan", if st.scanning then "loader-2" else "refresh", st.scanning, function()
        refresh(true)
        render()
      end, "Scan", 40),
      ui.toggle({ checked = st.enabled == true, onChange = function(v)
        st.enabled = v == "true"
        render()
        noctalia.runAsync({ "nmcli", "radio", "wifi", if st.enabled then "on" else "off" }, function()
          refresh(st.enabled)
        end)
      end }),
    }),
    hero(),
  }
  if st.enabled then
    table.insert(children, m3.section("Available networks"))
    table.insert(children, networkList())
  else
    table.insert(children, ui.spacer({ flexGrow = 1 }))
  end
  if noctalia.commandExists("nm-connection-editor") then
    table.insert(children, m3.footer("Network settings", function()
      panel.close()
      noctalia.runAsync({ "nm-connection-editor" })
    end))
  end
  panel.render(ui.column({ gap = 12, padding = 16, flexGrow = 1 }, children))
end

function onOpen(_context)
  noctalia.state.set("m3.openPanel", "nafeel/m3-panels:network")
  st.askFor = nil
  st.error = nil
  render()
  refresh(false)
  noctalia.setUpdateInterval(5000)
end

function onClose()
  noctalia.state.set("m3.openPanel", nil)
  noctalia.setUpdateInterval(600000)
end

function update()
  if st.busy == nil and st.askFor == nil then
    refresh(false)
  end
end
