--!nonstrict
-- Capture service - the only entry that runs anything.
--
-- In:  IPC (keybinds) and the "capture.request" channel (bar, dialog, tiles,
--      toolbar):
--        screenshot region|screen|edit
--        snip                    - the Mod+Shift+S key: open the dialog on
--                                  Screenshot · Region and go straight into
--                                  the region picker (the dialog hides)
--        record [region|screen]  - the Mod+Shift+R key: stop a recording, start
--                                  one from the open dialog, else open it
--        capture                 - the dialog's big button: screenshot or
--                                  record with its choices
--        start [region|screen]   - start recording now with the dialog's choices
--        toolbar · stop · pause · mic (live mute while recording)
--        set <key> <value>       - a dialog choice: kind, shot, area, delay,
--                                  mic, system
--        saved <png path>        - from the screenshot pipe command
-- Out: "capture.state" - { recording, starting, paused, startedAt, pausedAt,
--        pausedMs, mode, file, micMuted }
--      "capture.prefs" - the dialog's choices { kind, shot, area, delay, mic,
--        system }, kept in the plugin data dir across restarts.
--      "capture.pending" - { action = "snip", at } for the dialog to pick up
--        when it opens.
--
-- Screenshots are Noctalia's own: config/capture.toml turns its automatic
-- save off and pipes each PNG to a command that saves it and reports back
-- here as "saved", so this service can post the notification instead of
-- Noctalia's plain one. Recordings are gpu-screen-recorder, run through
-- bin/record.sh.
--
-- On the lock screen umbriel refuses screencopy to every client (Noctalia's
-- screenshots fail with "screencopy frame failed"), and no region picker can
-- show over a lock. So while locked both capture the whole focused monitor
-- with gpu-screen-recorder, which reads it from the GPU (KMS) instead.

-- A notification's buttons still work from Noctalia's notification history
-- after the popup goes, so notify-send waits for a click this long.
local NOTIFY_WAIT_MS = 10 * 60 * 1000
local NOTIFY_POPUP_MS = 8000
local LOCK_FILE = (noctalia.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/cave-abode-lock.lock"
local SCREENSHOT_IPC = { region = "screenshot-region", screen = "screenshot-fullscreen", edit = "screenshot-annotate" }

local TOOLBAR = "nafeel/capture:toolbar"

local root = noctalia.pluginDir()
local dataDir = noctalia.pluginDataDir()
local thumbDir = dataDir .. "/thumbs"
local prefsPath = dataDir .. "/prefs.json"
noctalia.mkdirAll(thumbDir)

local trim = noctalia.string.trim

local state = {
  recording = false, starting = false, paused = false,
  startedAt = 0, pausedAt = 0, pausedMs = 0, mode = "", file = "", micMuted = false,
}

-- The dialog's choices. kind: "screenshot" | "record"; shot: region | screen |
-- edit (freeze and annotate); area: what a recording takes, region | screen;
-- delay: seconds before a screenshot.
local prefs = { kind = "screenshot", shot = "region", area = "region", delay = 0, mic = false, system = true }
local DELAYS = { [0] = true, [3] = true, [5] = true, [10] = true }
do
  local text = noctalia.fileExists(prefsPath) and noctalia.readFile(prefsPath) or nil
  local saved = text and noctalia.json.decode(text) or nil
  if type(saved) == "table" then
    -- 1.0 kept the recording area as `mode`.
    if saved.mode == "region" or saved.mode == "screen" then
      saved.area = saved.mode
    end
    for k, v in pairs(saved) do
      if prefs[k] ~= nil and type(v) == type(prefs[k]) then
        prefs[k] = v
      end
    end
  end
end
local recorderPid = nil
local recorderLog = {}

-- Also written to state.json for the Cave Abode lock screen, which runs
-- outside Noctalia and shows its own record button and timer.
local function publish()
  noctalia.state.set("capture.state", state)
  noctalia.writeFile(dataDir .. "/state.json", noctalia.json.encode({
    recording = state.recording, starting = state.starting, paused = state.paused,
    startedAt = state.startedAt, pausedAt = state.pausedAt, pausedMs = state.pausedMs,
  }))
end

local function publishPrefs()
  noctalia.state.set("capture.prefs", prefs)
  noctalia.writeFile(prefsPath, noctalia.json.encode(prefs, true))
end

local function basename(path)
  return path:match("([^/]+)$") or path
end

local function dirname(path)
  return path:match("^(.*)/[^/]*$") or "."
end

local function fileUri(path)
  return "file://" .. path:gsub("[^%w/%._%-~]", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
end

local function humanSize(bytes)
  if bytes == nil then
    return nil
  end
  if bytes >= 1024 * 1024 then
    return string.format("%.1f MB", bytes / (1024 * 1024))
  end
  return string.format("%d KB", math.max(1, math.floor(bytes / 1024)))
end

local function humanDuration(seconds)
  local s = math.max(0, math.floor(seconds + 0.5))
  if s >= 3600 then
    return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
  end
  return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

-- ── Notifications ────────────────────────────────────────────────────
-- Plugin notifications can't carry images or buttons, so these go through
-- notify-send to Noctalia's notification server, which shows both.
-- `actions` is a list of { id, label }; `onAction(id)` runs for a click.
local function notify(title, body, image, actions, onAction)
  if noctalia.getConfig("notifications") == false then
    return
  end
  local argv = { "notify-send", "--app-name=" .. noctalia.tr("title"), "--expire-time=" .. NOTIFY_POPUP_MS }
  if image ~= nil then
    table.insert(argv, "--icon=" .. image)
    table.insert(argv, "--hint=string:image-path:" .. image)
  end
  if actions ~= nil and #actions > 0 then
    table.insert(argv, "--wait")
    for _, a in ipairs(actions) do
      table.insert(argv, "--action=" .. a[1] .. "=" .. a[2])
    end
  end
  table.insert(argv, title)
  table.insert(argv, body or "")
  noctalia.runAsync(argv, function(result)
    local id = trim(result.stdout or "")
    if id ~= "" and onAction ~= nil then
      onAction(id)
    end
  end, NOTIFY_WAIT_MS)
end

local function showInFolder(path)
  noctalia.runAsync({
    "sh", "-c",
    'gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 '
      .. '--method org.freedesktop.FileManager1.ShowItems "[\'$1\']" "" >/dev/null 2>&1 || xdg-open "$2"',
    "sh", fileUri(path), dirname(path),
  })
end

local function deleteFile(path)
  local ok, err = noctalia.removeFile(path)
  if ok then
    notify(noctalia.tr("notify.deleted"), basename(path))
  else
    noctalia.notifyError(noctalia.tr("notify.delete_failed"), tostring(err))
  end
end

-- The monitor to capture: the focused one, else whichever Noctalia marks
-- focused, else the first. focusedOutputName() can come back empty when the
-- request isn't from a keypress or click (a script, a timer).
local function focusedOutput()
  local name = noctalia.focusedOutputName()
  if name ~= nil and name ~= "" then
    return name
  end
  local outputs = noctalia.outputs() or {}
  for _, o in ipairs(outputs) do
    if o.focused then
      return o.name
    end
  end
  return if outputs[1] ~= nil then outputs[1].name else nil
end

-- ── Lock screen ──────────────────────────────────────────────────────
-- Locked while the Cave Abode lock (nafeel/cave-abode) holds its lock file.
local function whenLockKnown(fn)
  noctalia.runAsync({ "sh", "-c", '[ -e "$1" ] && ! flock -n "$1" true', "sh", LOCK_FILE }, function(result)
    fn(result.exitCode == 0)
  end, 2000)
end

-- ── Screenshots ──────────────────────────────────────────────────────
local lockedShots = {}
local onShotSaved
local screenshotLocked

-- `withTimer` adds the dialog's delay; the snip key and the bar never wait.
local function screenshot(mode, delayMs, withTimer)
  if SCREENSHOT_IPC[mode] == nil then
    mode = "region"
  end
  delayMs = (delayMs or 0) + (if withTimer then (prefs.delay or 0) * 1000 else 0)
  whenLockKnown(function(locked)
    if locked then
      screenshotLocked()
      return
    end
    local command = SCREENSHOT_IPC[mode]
    -- The delay lets a panel that asked for this close before the capture.
    noctalia.runAsync(
      { "sh", "-c", 'sleep "$1"; exec noctalia msg "$2"', "sh", tostring(delayMs / 1000), command },
      function(result)
        if result.exitCode ~= 0 then
          noctalia.notifyError(noctalia.tr("notify.shot_failed"), trim((result.stdout or "") .. (result.stderr or "")))
        end
      end,
      5000
    )
  end)
end

-- A PNG of the focused monitor taken by gpu-screen-recorder: the lock-screen
-- path, where Noctalia's own capture is refused. Saved where Noctalia saves.
function screenshotLocked()
  local output = focusedOutput()
  if output == nil or not noctalia.commandExists("gpu-screen-recorder") then
    noctalia.notifyError(noctalia.tr("notify.shot_failed"), noctalia.tr("notify.no_gsr"))
    return
  end
  local dir = noctalia.expandPath(noctalia.getSetting("shell.screenshot.directory") or "")
  if dir == "" then
    dir = noctalia.expandPath("~/Pictures")
  end
  noctalia.mkdirAll(dir)
  local pattern = noctalia.getSetting("shell.screenshot.filename_pattern") or ""
  local file = dir .. "/" .. os.date(if pattern ~= "" then pattern else "screenshot_%Y%m%d_%H%M%S") .. ".png"
  noctalia.runAsync({ "gpu-screen-recorder", "-w", output, "-cursor", "no", "-o", file }, function(result)
    if result.exitCode == 0 and noctalia.fileExists(file) then
      lockedShots[file] = true
      onShotSaved(file)
    else
      noctalia.notifyError(noctalia.tr("notify.shot_failed"), trim((result.stderr or "") .. (result.stdout or "")))
    end
  end, 15000)
end

function onShotSaved(path)
  if path == nil or path == "" or not noctalia.fileExists(path) then
    return
  end
  noctalia.runAsync({ "magick", "identify", "-format", "%wx%h", path .. "[0]" }, function(result)
    local parts = { basename(path) }
    local dims = trim(result.stdout or "")
    if result.exitCode == 0 and dims ~= "" then
      table.insert(parts, (dims:gsub("x", "×")))
    end
    if not lockedShots[path] then
      table.insert(parts, noctalia.tr("notify.copied"))
    end
    notify(noctalia.tr("notify.shot_saved"), table.concat(parts, " · "), path, {
      { "open", noctalia.tr("action.open") },
      { "edit", noctalia.tr("action.edit") },
      { "folder", noctalia.tr("action.folder") },
      { "delete", noctalia.tr("action.delete") },
    }, function(action)
      if action == "open" then
        noctalia.runAsync({ "xdg-open", path })
      elseif action == "edit" then
        noctalia.runAsync({ "noctalia", "msg", "annotate", path })
      elseif action == "folder" then
        showInFolder(path)
      elseif action == "delete" then
        deleteFile(path)
      end
    end)
  end, 5000)
end

-- ── Recording ────────────────────────────────────────────────────────
local function shellQuote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

-- `target` is { output = "eDP-1" } or { region = "WxH+X+Y" }.
local function recorderArgs(target, file)
  local argv = {
    "gpu-screen-recorder", "-w", target.region or target.output,
    "-f", tostring(noctalia.getConfig("record_fps") or 60),
    "-q", noctalia.getConfig("record_quality") or "very_high",
    "-k", noctalia.getConfig("record_codec") or "auto",
    "-cursor", if noctalia.getConfig("record_cursor") == false then "no" else "yes",
  }
  local audio = {}
  if prefs.system then
    table.insert(audio, "default_output")
  end
  if prefs.mic then
    table.insert(audio, "default_input")
  end
  if #audio > 0 then
    -- One track, both mixed: what a video player plays by default.
    table.insert(argv, "-a")
    table.insert(argv, table.concat(audio, "|"))
  end
  table.insert(argv, "-o")
  table.insert(argv, file)
  return argv
end

local function setMicMuted(muted)
  noctalia.runAsync({ "pactl", "set-source-mute", "@DEFAULT_SOURCE@", if muted then "1" else "0" })
end

local function resetState()
  -- A mic muted from the toolbar comes back on with the recording's end.
  if state.micMuted then
    setMicMuted(false)
  end
  state = {
    recording = false, starting = false, paused = false,
    startedAt = 0, pausedAt = 0, pausedMs = 0, mode = "", file = "", micMuted = false,
  }
  recorderPid = nil
  publish()
end

local function onRecordingFinished(file, status)
  local log = table.concat(recorderLog, "\n")
  resetState()
  local info = noctalia.fileExists(file) and noctalia.fileInfo(file) or nil
  if info == nil or (info.size or 0) == 0 then
    if noctalia.fileExists(file) then
      noctalia.removeFile(file)
    end
    noctalia.notifyError(noctalia.tr("notify.record_failed"), if log ~= "" then log else "exit " .. tostring(status))
    return
  end

  if noctalia.getConfig("copy_recording") == true then
    noctalia.copyToClipboard(fileUri(file) .. "\r\n", "text/uri-list")
  end

  local thumb = thumbDir .. "/" .. basename(file):gsub("%.[^.]+$", "") .. ".jpg"
  noctalia.runAsync({
    "sh", "-c",
    'ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; '
      .. 'ffmpeg -y -loglevel error -ss 0.5 -i "$1" -frames:v 1 -vf scale=480:-2 "$2" >/dev/null 2>&1 '
      .. '|| ffmpeg -y -loglevel error -i "$1" -frames:v 1 -vf scale=480:-2 "$2" >/dev/null 2>&1',
    "sh", file, thumb,
  }, function(result)
    local parts = { basename(file) }
    local seconds = tonumber(trim(result.stdout or ""))
    if seconds ~= nil then
      table.insert(parts, humanDuration(seconds))
    end
    local size = humanSize(info.size)
    if size ~= nil then
      table.insert(parts, size)
    end
    notify(noctalia.tr("notify.record_saved"), table.concat(parts, " · "),
      if noctalia.fileExists(thumb) then thumb else nil, {
        { "open", noctalia.tr("action.open") },
        { "folder", noctalia.tr("action.folder") },
        { "delete", noctalia.tr("action.delete") },
      }, function(action)
        if action == "open" then
          noctalia.runAsync({ "xdg-open", file })
        elseif action == "folder" then
          showInFolder(file)
        elseif action == "delete" then
          deleteFile(file)
          noctalia.removeFile(thumb)
        end
      end)
  end, 30000)
end

local function beginRecording(target, mode)
  local dir = noctalia.expandPath(noctalia.getConfig("record_directory") or "~/Videos/Recordings")
  noctalia.mkdirAll(dir)
  local file = dir .. "/" .. os.date("recording_%Y%m%d_%H%M%S") .. ".mp4"

  local quoted = { shellQuote(root .. "/bin/record.sh") }
  for _, arg in ipairs(recorderArgs(target, file)) do
    table.insert(quoted, shellQuote(arg))
  end

  recorderLog = {}
  state.file = file
  state.mode = mode
  publish()

  local started = noctalia.runStream(table.concat(quoted, " "), function(line)
    local pid = line:match("^PID (%d+)$")
    local status = line:match("^EXIT (%d+)$")
    if pid ~= nil then
      recorderPid = pid
      state.starting = false
      state.recording = true
      state.startedAt = noctalia.nowMs()
      publish()
    elseif status ~= nil then
      onRecordingFinished(file, tonumber(status))
    elseif trim(line) ~= "" then
      table.insert(recorderLog, trim(line))
      if #recorderLog > 8 then
        table.remove(recorderLog, 1)
      end
    end
  end)
  if not started then
    resetState()
    noctalia.notifyError(noctalia.tr("notify.record_failed"), noctalia.tr("notify.no_start"))
  end
end

local function startRecording(mode, delayMs)
  if state.recording or state.starting then
    return
  end
  if not noctalia.commandExists("gpu-screen-recorder") then
    noctalia.notifyError(noctalia.tr("notify.record_failed"), noctalia.tr("notify.no_gsr"))
    return
  end
  mode = if mode == "screen" or mode == "region" then mode else prefs.area
  state.starting = true
  publish()

  whenLockKnown(function(locked)
    if mode ~= "region" or locked then
      local output = focusedOutput()
      if output == nil then
        resetState()
        noctalia.notifyError(noctalia.tr("notify.record_failed"), noctalia.tr("notify.no_monitor"))
        return
      end
      beginRecording({ output = output }, "screen")
      return
    end

    if not noctalia.commandExists("slurp") then
      resetState()
      noctalia.notifyError(noctalia.tr("notify.record_failed"), noctalia.tr("notify.no_slurp"))
      return
    end
    -- The region picker, in the palette.
    local accent = noctalia.getColor("primary") or "#d9b35d"
    local shade = noctalia.getColor("shadow") or "#000000"
    noctalia.runAsync({
      "sh", "-c", 'sleep "$1"; shift; exec slurp "$@"', "sh", tostring((delayMs or 0) / 1000),
      "-d", "-w", "2",
      "-b", shade .. "66", "-c", accent .. "ff", "-s", accent .. "1f", "-B", accent .. "33",
      "-F", "Noto Sans",
    }, function(result)
      local x, y, w, h = (result.stdout or ""):match("(%-?%d+),(%-?%d+) (%d+)x(%d+)")
      if result.exitCode ~= 0 or x == nil then
        resetState() -- cancelled
        return
      end
      -- Encoders want even dimensions.
      w = tonumber(w) - tonumber(w) % 2
      h = tonumber(h) - tonumber(h) % 2
      if w < 2 or h < 2 then
        resetState()
        return
      end
      beginRecording({ region = string.format("%dx%d+%d+%d", w, h, tonumber(x), tonumber(y)) }, "region")
    end, 10 * 60 * 1000)
  end)
end

local function stopRecording()
  if recorderPid ~= nil then
    noctalia.runAsync({ "kill", "-INT", recorderPid })
  end
end

local function togglePause()
  if recorderPid == nil or not state.recording then
    return
  end
  noctalia.runAsync({ "kill", "-USR2", recorderPid })
  local now = noctalia.nowMs()
  if state.paused then
    state.pausedMs += now - state.pausedAt
    state.paused = false
    state.pausedAt = 0
  else
    state.paused = true
    state.pausedAt = now
  end
  publish()
end

-- ── Dialog ───────────────────────────────────────────────────────────
-- The dialog (the "toolbar" panel) reports whether it's open, so the keys can
-- tell "open the dialog" from "go from it".
local toolbarOpen = false

local function openToolbar(pending)
  noctalia.state.set("capture.pending", if pending ~= nil then { action = pending, at = noctalia.nowMs() } else nil)
  if not toolbarOpen then
    noctalia.togglePanel(TOOLBAR)
  end
end

local function setPref(key, value)
  if key == "kind" and (value == "screenshot" or value == "record") then
    prefs.kind = value
  elseif key == "shot" and SCREENSHOT_IPC[value] ~= nil then
    prefs.shot = value
  elseif key == "area" and (value == "region" or value == "screen") then
    prefs.area = value
  elseif key == "delay" and DELAYS[tonumber(value) or -1] then
    prefs.delay = tonumber(value)
  elseif (key == "mic" or key == "system") and not state.recording then
    prefs[key] = value == true or value == "true"
  else
    return
  end
  publishPrefs()
end

-- During a recording the mic button mutes the microphone itself (the default
-- PulseAudio/PipeWire source); it's unmuted again when the recording ends.
local function toggleMic()
  if state.recording and prefs.mic then
    state.micMuted = not state.micMuted
    setMicMuted(state.micMuted)
    publish()
  elseif not state.recording then
    setPref("mic", not prefs.mic)
  end
end

-- ── Requests ─────────────────────────────────────────────────────────
-- Mod+Shift+S, like Windows' Win+Shift+S: the dialog opens on Screenshot ·
-- Region, hides itself and the region picker comes up. Locked: the monitor.
local function onSnipKey()
  whenLockKnown(function(locked)
    if locked then
      screenshotLocked()
      return
    end
    setPref("kind", "screenshot")
    setPref("shot", "region")
    if toolbarOpen then
      noctalia.togglePanel(TOOLBAR) -- already showing: hide it and pick
      screenshot("region", 350)
      return
    end
    -- Another panel is open: the dialog would replace it, so go straight to the
    -- picker and leave that panel on screen to be captured.
    noctalia.runAsync({ "noctalia", "msg", "status" }, function(result)
      local status = noctalia.json.decode(result.stdout or "")
      if type(status) == "table" and status.panelOpen and status.activePanelId ~= TOOLBAR then
        screenshot("region", 0)
      else
        openToolbar("snip")
      end
    end)
  end)
end

local function onRecordKey(mode)
  if state.recording then
    stopRecording()
    return
  end
  if state.starting then
    return
  end
  whenLockKnown(function(locked)
    if locked then
      startRecording("screen", 0)
    elseif toolbarOpen and prefs.kind == "record" then
      startRecording(if mode ~= "" then mode else prefs.area, 0)
    else
      setPref("kind", "record")
      openToolbar()
    end
  end)
end

-- The dialog's big button, sent after the dialog has closed itself.
local function capture(delayMs)
  if prefs.kind == "record" then
    startRecording(prefs.area, delayMs)
  else
    screenshot(prefs.shot, delayMs, true)
  end
end

local function handle(action, mode, delayMs, value)
  if action == "screenshot" then
    screenshot(mode, delayMs)
  elseif action == "snip" then
    onSnipKey()
  elseif action == "capture" then
    capture(delayMs)
  elseif action == "record" then
    onRecordKey(mode or "")
  elseif action == "start" then
    startRecording(mode, delayMs)
  elseif action == "toolbar" then
    openToolbar()
  elseif action == "stop" then
    stopRecording()
  elseif action == "pause" then
    togglePause()
  elseif action == "mic" then
    toggleMic()
  elseif action == "set" then
    setPref(mode, value)
  end
end

function onIpc(event, payload)
  local arg = if type(payload) == "string" then trim(payload) else ""
  if event == "saved" then
    onShotSaved(arg)
  elseif event == "set" then
    local key, value = arg:match("^(%S+)%s+(%S+)$")
    handle("set", key, 0, value)
  else
    handle(event, arg, 0)
  end
end

-- UI entries send { action, mode, delay, value, at }; `at` makes repeats distinct.
noctalia.state.watch("capture.request", function(request)
  if type(request) == "table" then
    handle(request.action, request.mode, request.delay, request.value)
  end
end)

noctalia.state.watch("capture.toolbar", function(open)
  toolbarOpen = open == true
end)

publish()
publishPrefs()
