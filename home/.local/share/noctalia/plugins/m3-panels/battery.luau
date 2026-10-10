--!nonstrict
-- Battery panel: a big charge hero (level bar, state, time left), the power
-- profile as a connected button group, and a few health facts from UPower.

local m3 = require("./m3.luau")

local st = {
  pct = nil,
  state = nil,
  timeTo = nil,
  rate = nil,
  health = nil,
  profile = nil,
  profiles = {},
}

local render

local function refresh()
  local script = "upower -i \"$(upower -e | grep -m1 BAT)\""
  noctalia.runAsync({ "sh", "-c", script }, function(r)
    local out = r.stdout or ""
    st.pct = tonumber(string.match(out, "percentage:%s*([%d%.]+)"))
    st.state = string.match(out, "state:%s*([%w%-]+)")
    local t = string.match(out, "time to %a+:%s*([^\n]+)")
    st.timeTo = if t then noctalia.string.trim(t) else nil
    st.rate = tonumber(string.match(out, "energy%-rate:%s*([%d%.]+)"))
    st.health = tonumber(string.match(out, "capacity:%s*([%d%.]+)"))
    render()
  end)
  if noctalia.commandExists("powerprofilesctl") then
    noctalia.runAsync({ "powerprofilesctl", "get" }, function(r)
      st.profile = noctalia.string.trim(r.stdout or "")
      render()
    end)
  end
end

local PROFILES = {
  { id = "power-saver", glyph = "leaf", text = "Saver" },
  { id = "balanced", glyph = "scale", text = "Balanced" },
  { id = "performance", glyph = "rocket", text = "Performance" },
}

local function setProfile(id)
  st.profile = id
  render()
  noctalia.runAsync(m3.msg("power-set", id), function()
    refresh()
  end)
end

render = function()
  local p = math.floor(st.pct or 0)
  local charging = st.state == "charging" or st.state == "fully-charged" or st.state == "pending-charge"
  local low = not charging and p <= 20
  local tone = if low then "error" elseif charging then "primary" else "secondary"

  local stateText = if st.state == "fully-charged" then "Fully charged"
    elseif st.state == "charging" then "Charging"
    elseif st.state == "pending-charge" then "Plugged in, not charging"
    elseif st.state == "discharging" then "On battery"
    else m3.cap(st.state or "Unknown")
  local timeText = if st.timeTo == nil then ""
    elseif charging then st.timeTo .. " until full"
    else st.timeTo .. " left"

  local hero = m3.card("hero", {
    ui.row({ gap = 14, align = "center" }, {
      ui.column({ gap = 0, flexGrow = 1 }, {
        ui.row({ gap = 2, align = "end" }, {
          ui.label({ text = tostring(p), fontSize = 40, fontWeight = "heavy", color = "on_" .. tone }),
          ui.label({ text = "%", fontSize = 20, fontWeight = "bold", color = "on_" .. tone .. "/0.8" }),
        }),
        ui.label({ text = stateText, fontSize = 14, fontWeight = "semibold", color = "on_" .. tone }),
        ui.label({ text = timeText, fontSize = 12, color = "on_" .. tone .. "/0.8", visible = timeText ~= "" }),
      }),
      ui.row({ width = 56, height = 56, radius = 20, fill = "on_" .. tone .. "/0.16", align = "center", justify = "center" }, {
        ui.glyph({ name = if charging then "bolt" elseif low then "battery-exclamation" else "battery-3", size = 26,
          color = "on_" .. tone }),
      }),
    }),
    ui.progress({ progress = p / 100, height = 10, radius = 5, fill = "on_" .. tone, track = "on_" .. tone .. "/0.2" }),
  }, { fill = tone, padding = 16, gap = 10 })

  local seg = {}
  for _, pr in ipairs(PROFILES) do
    table.insert(seg, { key = pr.id, glyph = pr.glyph, text = pr.text, on = st.profile == pr.id, onClick = function()
      setProfile(pr.id)
    end })
  end

  local facts = {}
  if st.rate and st.rate > 0 then
    table.insert(facts, m3.item({ key = "rate", lead = "activity", title = string.format("%.1f W", st.rate),
      subtitle = if charging then "Charging rate" else "Power draw", grow = 1 }))
  end
  if st.health then
    table.insert(facts, m3.item({ key = "health", lead = "heart-rate-monitor", title = string.format("%d%%", st.health),
      subtitle = "Battery health", grow = 1 }))
  end

  local children = {
    m3.header(if charging then "battery-charging-2" else "battery-2", "Battery", stateText, {}, tone),
    hero,
    m3.section("Power mode"),
    m3.segmented(seg),
  }
  if #facts > 0 then
    table.insert(children, ui.row({ gap = 8 }, facts))
  end
  panel.render(ui.column({ gap = 10, padding = 16, flexGrow = 1 }, children))
end

function onOpen(_context)
  render()
  refresh()
  noctalia.setUpdateInterval(5000)
end

function onClose()
  noctalia.setUpdateInterval(600000)
end

function update()
  refresh()
end
