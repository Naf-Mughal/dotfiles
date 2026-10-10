--!nonstrict
-- Hover zone: an invisible strip on a border bar. Resting the pointer on it for
-- `delay_ms` runs `action` once; leaving and coming back runs it again.
-- `action` is a `noctalia msg` command ("panel-open control-center") or
-- "exec <shell command>".

local IDLE_INTERVAL = 60000
local POLL_INTERVAL = 30

local hovered = false
local enteredAt = 0
local fired = false

local function runAction()
  local action = noctalia.string.trim(noctalia.getConfig("action") or "")
  if action == "" or action == "none" then
    return
  end
  if string.sub(action, 1, 5) == "exec " then
    noctalia.runAsync(string.sub(action, 6))
    return
  end
  local argv = { "noctalia", "msg" }
  for word in string.gmatch(action, "%S+") do
    table.insert(argv, word)
  end
  noctalia.runAsync(argv)
end

local function check()
  if not hovered or fired then
    return
  end
  if noctalia.nowMs() - enteredAt >= (noctalia.getConfig("delay_ms") or 0) then
    fired = true
    noctalia.setUpdateInterval(IDLE_INTERVAL)
    runAction()
  end
end

function onZoneHover(state)
  hovered = state == "true"
  if hovered then
    enteredAt = noctalia.nowMs()
    fired = false
    noctalia.setUpdateInterval(POLL_INTERVAL)
    check()
  else
    noctalia.setUpdateInterval(IDLE_INTERVAL)
  end
end

function update()
  check()
end

-- The bar clips the cross axis to its thickness, so oversize it and let the
-- bar decide; the main axis is the configured length.
local length = noctalia.getConfig("length") or 320
local vertical = barWidget.isVertical()
barWidget.render(ui.box({
  width = if vertical then 200 else length,
  height = if vertical then length else 200,
  fill = "#00000000",
  onHover = "onZoneHover",
}))
noctalia.setUpdateInterval(IDLE_INTERVAL)
