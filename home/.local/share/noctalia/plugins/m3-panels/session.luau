--!nonstrict
-- Session panel: clock, date and uptime on top, then the session actions as
-- big expressive tiles. Logout, reboot and shutdown ask "Sure?" first (a second
-- press within 4 s). Actions come from [shell.session.actions], so the Cave
-- Abode lock and Graceful Power commands apply here too.

local m3 = require("./m3.luau")

local CONFIRM_MS = 4000

local INFO = {
  lock = { glyph = "lock", text = "Lock" },
  lock_and_suspend = { glyph = "zzz", text = "Sleep" },
  suspend = { glyph = "zzz", text = "Sleep" },
  hibernate = { glyph = "snowflake", text = "Hibernate" },
  logout = { glyph = "logout", text = "Log out" },
  reboot = { glyph = "refresh", text = "Restart" },
  shutdown = { glyph = "power", text = "Shut down" },
}

local NEEDS_CONFIRM = { logout = true, reboot = true, shutdown = true }

local st = { armed = nil, armedAt = 0, uptime = nil }
local render

local function actions()
  local configured = noctalia.getSetting("shell.session.actions")
  local out = {}
  if type(configured) == "table" and #configured > 0 then
    for _, a in ipairs(configured) do
      if a.enabled ~= false and INFO[a.action] then
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

local function run(a)
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
    noctalia.runAsync(m3.msg("session", (string.gsub(a.action, "_", "-"))))
  end
end

local function press(a)
  if NEEDS_CONFIRM[a.action] and not (st.armed == a.action and noctalia.nowMs() - st.armedAt < CONFIRM_MS) then
    st.armed = a.action
    st.armedAt = noctalia.nowMs()
    render()
    return
  end
  st.armed = nil
  run(a)
end

local function tile(a)
  local info = INFO[a.action]
  local armed = st.armed == a.action and noctalia.nowMs() - st.armedAt < CONFIRM_MS
  local danger = a.action == "shutdown"
  local fill = if armed then "error" elseif danger then "error/0.16" else m3.TILE
  local fg = if armed then "on_error" elseif danger then "error" else "on_surface"
  return ui.column({
    key = "a-" .. a.action,
    flexGrow = 1,
    height = 74,
    gap = 8,
    radius = if armed then 20 else 30,
    fill = fill,
    align = "center",
    justify = "center",
    onClick = function()
      press(a)
    end,
  }, {
    ui.row({ width = 36, height = 36, radius = if armed then 12 else 18,
      fill = if armed then "on_error/0.2" elseif danger then "error/0.2" else m3.IDLE,
      align = "center", justify = "center" }, {
      ui.glyph({ name = if armed then "alert-triangle" else info.glyph, size = 20, color = fg }),
    }),
    ui.label({ text = if armed then "Sure?" else info.text, fontSize = 13, fontWeight = "semibold", color = fg }),
  })
end

render = function()
  local list = actions()
  local rows = {}
  local i = 1
  while i <= #list do
    local row = { tile(list[i]) }
    -- Shutdown always gets the last row to itself when the count is odd.
    if list[i + 1] and not (#list % 2 == 1 and i + 1 == #list) then
      table.insert(row, tile(list[i + 1]))
      i += 2
    else
      i += 1
    end
    table.insert(rows, ui.row({ gap = 8 }, row))
  end

  local user = noctalia.getenv("USER") or ""
  panel.render(ui.column({ onHover = m3.panelHover, gap = 12, padding = 16, flexGrow = 1 }, {
    m3.card("clock", {
      ui.row({ gap = 12, align = "center" }, {
        ui.column({ gap = 0, flexGrow = 1 }, {
          ui.label({ text = noctalia.formatTime("{:%-I:%M}"), fontSize = 38, fontWeight = "heavy", color = "on_primary" }),
          ui.label({ text = noctalia.formatTime("{:%A, %B %-d}"), fontSize = 13, fontWeight = "semibold",
            color = "on_primary/0.85" }),
        }),
        ui.column({ gap = 2, align = "end" }, {
          m3.chip("user", user, nil, false, "on_primary"),
          ui.label({ text = st.uptime or "", fontSize = 11, color = "on_primary/0.8" }),
        }),
      }),
    }, { fill = "primary", padding = 16 }),
    ui.column({ gap = 8, flexGrow = 1 }, rows),
  }))
end

local function readUptime()
  noctalia.readFileAsync("/proc/uptime", function(raw)
    local s = tonumber(string.match(raw or "", "^([%d%.]+)"))
    if s then
      local h = math.floor(s / 3600)
      local m = math.floor((s % 3600) / 60)
      st.uptime = "up " .. (if h > 0 then (h .. "h ") else "") .. m .. "m"
      render()
    end
  end)
end

function onOpen(_context)
  m3.panelOpened("nafeel/m3-panels:session")
  st.armed = nil
  render()
  readUptime()
  panel.setWantsSecondTicks(true)
end

function onClose()
  m3.panelClosed()
  st.armed = nil
end

function update()
  if st.armed and noctalia.nowMs() - st.armedAt >= CONFIRM_MS then
    st.armed = nil
  end
  render()
end
