--!nonstrict
-- Bluetooth panel: adapter toggle, paired devices (connect / disconnect /
-- forget, battery when the device reports it) and a scan for new ones, which
-- pairs, trusts and connects in one click. Everything goes through bluetoothctl.

local m3 = require("./m3.luau")

local SCAN_SECONDS = 12

local st = {
  powered = nil,
  devices = {},
  scanning = false,
  busy = nil,
  error = nil,
}

local render

local ICONS = {
  ["audio-headset"] = "headset",
  ["audio-headphones"] = "headphones",
  ["audio-card"] = "device-speaker",
  ["input-keyboard"] = "keyboard",
  ["input-mouse"] = "mouse",
  ["input-gaming"] = "device-gamepad-2",
  ["phone"] = "device-mobile",
  ["computer"] = "device-laptop",
}

local function parseInfo(mac, out)
  local d = { mac = mac, name = mac }
  for line in string.gmatch(out or "", "[^\n]+") do
    local k, v = string.match(line, "^%s*([%w ]+):%s*(.-)%s*$")
    if k == "Name" or k == "Alias" then
      d.name = v
    elseif k == "Paired" then
      d.paired = v == "yes"
    elseif k == "Connected" then
      d.connected = v == "yes"
    elseif k == "Trusted" then
      d.trusted = v == "yes"
    elseif k == "Icon" then
      d.icon = v
    elseif k == "Battery Percentage" then
      d.battery = tonumber(string.match(v, "%((%d+)%)") or "")
    end
  end
  return d
end

local function refresh()
  noctalia.runAsync({ "bluetoothctl", "show" }, function(r)
    st.powered = string.find(r.stdout or "", "Powered: yes", 1, true) ~= nil
    render()
  end)
  -- One shell round trip for every device's info.
  local script = "bluetoothctl devices | while read -r _ mac _; do echo \"@@ $mac\"; bluetoothctl info \"$mac\"; done"
  noctalia.runAsync({ "sh", "-c", script }, function(r)
    local list, cur, buf = {}, nil, {}
    for line in string.gmatch(r.stdout or "", "[^\n]+") do
      local mac = string.match(line, "^@@ (%S+)")
      if mac then
        if cur then
          table.insert(list, parseInfo(cur, table.concat(buf, "\n")))
        end
        cur, buf = mac, {}
      else
        table.insert(buf, line)
      end
    end
    if cur then
      table.insert(list, parseInfo(cur, table.concat(buf, "\n")))
    end
    table.sort(list, function(a, b)
      if (a.connected == true) ~= (b.connected == true) then
        return a.connected == true
      end
      if (a.paired == true) ~= (b.paired == true) then
        return a.paired == true
      end
      return a.name < b.name
    end)
    st.devices = list
    render()
  end)
end

local function run(mac, script)
  st.busy = mac
  st.error = nil
  render()
  noctalia.runAsync({ "sh", "-c", script }, function(r)
    st.busy = nil
    if r.exitCode ~= 0 then
      st.error = "Couldn't reach the device"
    end
    refresh()
  end)
end

local function onDevice(d)
  if st.busy then
    return
  end
  if d.connected then
    run(d.mac, "bluetoothctl disconnect " .. d.mac)
  elseif d.paired then
    run(d.mac, "bluetoothctl connect " .. d.mac)
  else
    run(d.mac, "bluetoothctl --timeout 20 pair " .. d.mac .. " && bluetoothctl trust " .. d.mac
      .. " && bluetoothctl connect " .. d.mac)
  end
end

local function scan()
  if st.scanning or not st.powered then
    return
  end
  st.scanning = true
  render()
  noctalia.runAsync({ "bluetoothctl", "--timeout", tostring(SCAN_SECONDS), "scan", "on" }, function()
    st.scanning = false
    refresh()
  end)
end

-- View ----------------------------------------------------------------------

local function deviceItem(d)
  local sub
  if st.busy == d.mac then
    sub = if d.connected then "Disconnecting…" elseif d.paired then "Connecting…" else "Pairing…"
  elseif d.connected then
    sub = "Connected"
  elseif d.paired then
    sub = "Paired"
  else
    sub = "Tap to pair"
  end
  local trailing = {}
  if d.battery then
    table.insert(trailing, m3.chip("b-" .. d.mac, tostring(d.battery) .. "%", nil, d.connected))
  end
  if st.busy == d.mac then
    table.insert(trailing, ui.glyph({ name = "loader-2", size = 18, color = "primary" }))
  elseif d.paired and not d.connected then
    table.insert(trailing, ui.row({ key = "x-" .. d.mac, width = 32, height = 32, radius = 16, fill = m3.IDLE,
      align = "center", justify = "center", tooltip = "Forget", onClick = function()
        run(d.mac, "bluetoothctl remove " .. d.mac)
      end }, { ui.glyph({ name = "trash", size = 14, color = "on_surface_variant" }) }))
  end
  return m3.item({
    key = "d-" .. d.mac,
    lead = ICONS[d.icon or ""] or "bluetooth",
    title = d.name,
    subtitle = sub,
    active = d.connected,
    trailing = trailing,
    onClick = function()
      onDevice(d)
    end,
  })
end

render = function()
  local connected, paired, found = {}, {}, {}
  for _, d in ipairs(st.devices) do
    if d.connected then
      table.insert(connected, d)
    elseif d.paired then
      table.insert(paired, d)
    elseif d.name ~= d.mac then -- skip nameless beacons
      table.insert(found, d)
    end
  end

  local subtitle = if st.powered == false then "Off"
    elseif #connected == 1 then connected[1].name
    elseif #connected > 1 then tostring(#connected) .. " devices connected"
    else "No devices connected"

  local children = {
    m3.header(if st.powered == false then "bluetooth-off" else "bluetooth", "Bluetooth", subtitle, {
      m3.circle("scan", if st.scanning then "loader-2" else "radar", st.scanning, scan, "Scan for devices", 40),
      ui.toggle({ checked = st.powered == true, onChange = function(v)
        st.powered = v == "true"
        render()
        noctalia.runAsync({ "bluetoothctl", "power", if st.powered then "on" else "off" }, function()
          refresh()
        end)
      end }),
    }),
  }

  if not st.powered then
    table.insert(children, m3.card("off", { m3.empty("bluetooth-off", "Bluetooth is off") }, { grow = 1 }))
  else
    local rows = {}
    if #connected + #paired > 0 then
      table.insert(rows, m3.section("My devices"))
      for _, d in ipairs(connected) do
        table.insert(rows, deviceItem(d))
      end
      for _, d in ipairs(paired) do
        table.insert(rows, deviceItem(d))
      end
    end
    table.insert(rows, m3.section(if st.scanning then "Searching…" else "Available devices",
      if st.scanning then nil else m3.chip("scan2", "Scan", scan)))
    if #found == 0 then
      table.insert(rows, ui.label({ text = if st.scanning then "Looking for devices nearby…"
        else "Tap Scan to find devices nearby", fontSize = 12, color = "on_surface_variant" }))
    end
    for _, d in ipairs(found) do
      table.insert(rows, deviceItem(d))
    end
    if st.error then
      table.insert(rows, ui.label({ text = st.error, fontSize = 12, color = "error" }))
    end
    table.insert(children, ui.scroll({ gap = 6, flexGrow = 1 }, rows))
  end

  if noctalia.commandExists("blueman-manager") then
    table.insert(children, m3.footer("Bluetooth settings", function()
      panel.close()
      noctalia.runAsync({ "blueman-manager" })
    end))
  end
  panel.render(ui.column({ gap = 12, padding = 16, flexGrow = 1 }, children))
end

function onOpen(_context)
  st.error = nil
  render()
  refresh()
  noctalia.setUpdateInterval(4000)
end

function onClose()
  noctalia.setUpdateInterval(600000)
end

function update()
  if st.busy == nil then
    refresh()
  end
end
