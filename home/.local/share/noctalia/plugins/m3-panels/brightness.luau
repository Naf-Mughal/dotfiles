--!nonstrict
-- Display panel: screen brightness, then night light, caffeine and dark mode
-- as expressive tiles. Noctalia doesn't report night light or caffeine state,
-- so those two remember what was last pressed here.

local m3 = require("./m3.luau")

local st = {
  brightness = nil,
  dragging = false,
  dark = nil,
}

local throttle = m3.throttle(60)
local render

local function refresh()
  if not st.dragging and noctalia.commandExists("brightnessctl") then
    noctalia.runAsync({ "brightnessctl", "-m", "-c", "backlight" }, function(r)
      local p = string.match(r.stdout or "", ",(%d+)%%,")
      if p and not st.dragging then
        st.brightness = tonumber(p)
        render()
      end
    end)
  end
  noctalia.runAsync(m3.msg("theme-mode-get"), function(r)
    st.dark = string.find(r.stdout or "", "dark", 1, true) ~= nil
    render()
  end)
end

local function flag(key)
  return noctalia.state.get("m3.display." .. key) == true
end

local function flip(key, cmd)
  noctalia.state.set("m3.display." .. key, not flag(key))
  render()
  noctalia.runAsync(m3.msg(cmd))
end

render = function()
  local b = st.brightness or 0
  local glyph = if b < 34 then "brightness-down" elseif b < 67 then "brightness-half" else "brightness-up"
  local children = {
    m3.header("sun", "Display", if st.brightness then (tostring(b) .. "% brightness") else "No backlight control", {}),
  }
  if st.brightness then
    table.insert(children, m3.card("bri", {
      m3.slider("bri", glyph, b, 100, function(v)
        st.dragging = true
        st.brightness = math.max(1, math.floor(tonumber(v) + 0.5))
        throttle(function()
          noctalia.runAsync(m3.msg("brightness-set", st.brightness .. "%"))
        end)
        render()
      end, function()
        st.dragging = false
        noctalia.runAsync(m3.msg("brightness-set", st.brightness .. "%"))
      end, nil, false, "Brightness"),
    }))
  end
  table.insert(children, ui.row({ gap = 8 }, {
    m3.tile("night", "moon", "Night light", if flag("night") then "On" else "Off", flag("night"), function()
      flip("night", "nightlight-force-toggle")
    end, "tertiary"),
    m3.tile("caffeine", "coffee", "Caffeine", if flag("caffeine") then "Awake" else "Off", flag("caffeine"), function()
      flip("caffeine", "caffeine-toggle")
    end, "secondary"),
  }))
  table.insert(children, ui.row({ gap = 8 }, {
    m3.tile("dark", if st.dark then "moon-stars" else "sun-high", "Dark mode", if st.dark then "On" else "Off",
      st.dark == true, function()
        st.dark = not st.dark
        render()
        noctalia.runAsync(m3.msg("theme-mode-toggle"))
      end),
    m3.tile("wall", "photo", "Wallpaper", "Change", false, function()
      panel.close()
      noctalia.runAsync(m3.msg("panel-open", "wallpaper"))
    end),
  }))
  panel.render(ui.column({ onHover = m3.panelHover, gap = 12, padding = 16, flexGrow = 1 }, children))
end

function onOpen(_context)
  m3.panelOpened("nafeel/m3-panels:brightness")
  st.dragging = false
  render()
  refresh()
  noctalia.setUpdateInterval(2000)
end

function onClose()
  m3.panelClosed("nafeel/m3-panels:brightness")
  noctalia.setUpdateInterval(600000)
end

function update()
  refresh()
end
