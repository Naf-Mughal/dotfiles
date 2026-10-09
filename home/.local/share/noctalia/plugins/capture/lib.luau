--!nonstrict
-- Shared by the UI entries: asking the service for something, and reading
-- how long the current recording has run.

local M = {}

-- `delay` (ms) gives a panel or the control center time to close first.
-- `value` goes with "set" (mode, mic, system).
function M.request(action, mode, delay, value)
  noctalia.state.set("capture.request", {
    action = action, mode = mode or "", delay = delay or 0, value = value, at = noctalia.nowMs(),
  })
end

function M.state()
  return noctalia.state.get("capture.state") or {}
end

-- Seconds recorded so far, not counting pauses.
function M.elapsed(s)
  if not s.recording or (s.startedAt or 0) == 0 then
    return 0
  end
  local now = noctalia.nowMs()
  local paused = (s.pausedMs or 0) + (if s.paused then now - (s.pausedAt or now) else 0)
  return math.max(0, (now - s.startedAt - paused) / 1000)
end

function M.clock(seconds)
  local s = math.floor(seconds)
  if s >= 3600 then
    return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
  end
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

return M
