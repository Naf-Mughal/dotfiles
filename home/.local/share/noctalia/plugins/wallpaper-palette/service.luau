--!nonstrict
-- Wallpaper Palette service: keeps a Noctalia custom palette ("wallpaper")
-- made from the current wallpaper by bin/extract.py (Caelestia's scheme
-- generator), and uses it.
--
-- bin/extract.py runs in a private venv (materialyoucolor + pillow, what
-- Caelestia uses) in the plugin's data dir, set up on first run. There's no
-- wallpaper-changed callback for plugins, so this checks the wallpaper path
-- every couple of seconds (a string compare, no I/O) and only runs the
-- extractor when the wallpaper or a setting changed. Seeds are cached per
-- wallpaper, so switching variants is instant.
--
-- Whether it switches the shell to the palette:
--   source custom/"wallpaper" (ours)    -> yes, always
--   source "wallpaper" (Noctalia's own) -> if "Replace Noctalia's wallpaper
--                                          colours" is on
--   anything else (built-in, community, another custom palette) -> no; the
--     file is still kept current, so switching to it later is instant
--
-- In:  IPC and the "palette.request" channel (the tile):
--        apply                        - regenerate and switch to it, whatever the source
--        regenerate                   - regenerate only
--        auto [on|off|toggle]         - follow the wallpaper
--        variant [NAME|next|prev|reset] - override the variant setting until it's changed
-- Out: "palette.state" - { active, auto, wallpaper, variant, seed, colors, ready }

local PALETTE = "wallpaper"
local POLL_MS = 2000
-- Caelestia's order (launcher ">variant").
local VARIANTS = { "vibrant", "tonalspot", "expressive", "fidelity", "content", "fruitsalad", "rainbow", "neutral", "monochrome" }

local root = noctalia.pluginDir()
local dataDir = noctalia.pluginDataDir()
local out = noctalia.expandPath("~/.config/noctalia/palettes/" .. PALETTE .. ".json")
-- The whole Material scheme (every role, dark and light) for the nafeel/shell
-- Quickshell shell, which needs more than the 16 roles above.
local SHELL_SCHEME = noctalia.expandPath("~/.local/state/nafeel-shell/wallpaper-scheme.json")
local lastPath = dataDir .. "/last.json"
local venv = dataDir .. "/venv"
local python = venv .. "/bin/python"
local venvReady = venv .. "/.ready"
local trim = noctalia.string.trim

-- What the palette file was last made from: { key, wallpaper, summary, auto, variant }.
local last = {}
do
  local text = noctalia.fileExists(lastPath) and noctalia.readFile(lastPath) or nil
  local saved = text and noctalia.json.decode(text) or nil
  if type(saved) == "table" then
    last = saved
  end
end

-- Overrides from the tile / IPC outlive a restart, over the settings, until
-- the settings change.
local autoOverride = last.auto
local variantOverride = last.variant

local busy = false
local again = nil -- a request that came in while busy: { force, switch }

local function auto()
  if autoOverride ~= nil then
    return autoOverride
  end
  return noctalia.getConfig("auto") ~= false
end

local function variant()
  return variantOverride or noctalia.getConfig("variant") or "pigment"
end

local function flavour()
  return noctalia.getConfig("flavour") or "default"
end

local function contrast()
  return tonumber(noctalia.getConfig("contrast")) or 0
end

local function ours()
  return noctalia.getSetting("theme.source") == "custom" and noctalia.getSetting("theme.custom_palette") == PALETTE
end

local function publish()
  local s = last.summary or {}
  noctalia.state.set("palette.state", {
    active = ours(), auto = auto(), wallpaper = last.wallpaper or "", variant = s.variant or variant(),
    seed = s.seed or "", colors = s.primary and (s.primary .. " " .. s.secondary .. " " .. s.tertiary) or "",
    ready = noctalia.fileExists(venvReady),
  })
end

local function save()
  last.auto = autoOverride
  last.variant = variantOverride
  noctalia.writeFile(lastPath, noctalia.json.encode(last, true))
end

-- The first output's wallpaper: one palette for the whole shell, and it
-- doesn't flip as focus moves between monitors.
local function wallpaper()
  for _, o in ipairs(noctalia.outputs() or {}) do
    local p = noctalia.wallpaperPath(o.name) or o.wallpaperPath
    if p ~= nil and p ~= "" then
      return p
    end
  end
  return nil
end

local function shouldSwitch(force)
  if force or ours() then
    return true
  end
  return noctalia.getSetting("theme.source") == "wallpaper" and noctalia.getConfig("take_over") ~= false
end

local function failed(result)
  noctalia.notifyError(noctalia.tr("notify.failed"), trim((result.stderr or "") .. (result.stdout or "")))
end

-- Re-selecting the palette makes Noctalia reload the file, re-theme the shell
-- and run the templates (GTK, Qt, terminals, the greeter, ...).
local function use()
  noctalia.runAsync({ "noctalia", "msg", "color-scheme-set", "custom", PALETTE }, function(result)
    if result.exitCode ~= 0 then
      failed(result)
    end
    publish()
  end, 10000)
end

-- Caelestia's smart scheme also flips light/dark to suit the wallpaper.
local function smartMode(summary)
  if noctalia.getConfig("smart_mode") ~= true or (summary.mode ~= "light" and summary.mode ~= "dark") then
    return
  end
  if noctalia.getSetting("theme.mode") ~= summary.mode then
    noctalia.runAsync({ "noctalia", "msg", "theme-mode-set", summary.mode }, function(result)
      if result.exitCode ~= 0 then
        failed(result)
      end
    end, 10000)
  end
end

-- First run: a venv with what Caelestia's generator needs (needs the network once).
local function withVenv(cb)
  if noctalia.fileExists(venvReady) then
    cb()
    return
  end
  noctalia.notify(noctalia.tr("title"), noctalia.tr("notify.setup"))
  local script = 'python3 -m venv "$1" && "$1/bin/pip" install -q --disable-pip-version-check materialyoucolor pillow && touch "$1/.ready"'
  noctalia.runAsync({ "sh", "-c", script, "sh", venv }, function(result)
    if result.exitCode ~= 0 or not noctalia.fileExists(venvReady) then
      noctalia.notifyError(noctalia.tr("notify.setup_failed"), trim((result.stderr or "") .. (result.stdout or "")))
      cb(false)
      return
    end
    cb()
  end, 600000)
end

local refresh

local function finish()
  busy = false
  publish()
  if again ~= nil then
    local next = again
    again = nil
    refresh(next.force, next.switch)
  end
end

-- `force`: extract even if nothing changed. `switch`: use it even if the
-- current palette is someone else's.
function refresh(force, switch)
  if busy then
    again = { force = force or (again and again.force), switch = switch or (again and again.switch) }
    return
  end
  local path = wallpaper()
  if path == nil then
    return
  end
  local v, f, c = variant(), flavour(), contrast()
  local key = table.concat({ path, v, f, string.format("%.2f", c) }, "|")
  if not force and key == last.key and noctalia.fileExists(out) and noctalia.fileExists(SHELL_SCHEME) then
    return
  end

  busy = true
  withVenv(function(ok)
    if ok == false then
      -- Remember it anyway, so a failed setup isn't retried every poll.
      last.key = key
      save()
      finish()
      return
    end
    local cmd = {
      python, "-I", root .. "/bin/extract.py", path, out,
      "--variant", v, "--flavour", f, "--contrast", string.format("%.2f", c), "--cache", dataDir .. "/cache",
      "--scheme-out", SHELL_SCHEME,
    }
    noctalia.runAsync(cmd, function(result)
      last.key, last.wallpaper = key, path
      if result.exitCode ~= 0 then
        -- Remember it anyway, so a broken file isn't retried every poll.
        save()
        failed(result)
        finish()
        return
      end
      local summary = noctalia.json.decode(trim(result.stdout or "")) or {}
      last.summary = summary
      save()
      smartMode(summary)
      if shouldSwitch(switch) then
        use()
      end
      finish()
    end, 60000)
  end)
end

local function setAuto(value)
  if value == "on" then
    autoOverride = true
  elseif value == "off" then
    autoOverride = false
  else
    autoOverride = not auto()
  end
  save()
  publish()
  if auto() then
    refresh(false, false)
  end
end

local function setVariant(value)
  local current = variant()
  if value == "reset" or value == "" then
    variantOverride = nil
  elseif value == "next" or value == "prev" then
    local index = table.find(VARIANTS, current) or (if value == "next" then 0 else 1)
    local step = if value == "next" then 1 else -1
    variantOverride = VARIANTS[(index - 1 + step) % #VARIANTS + 1]
  elseif value == "auto" or table.find(VARIANTS, value) then
    variantOverride = value
  else
    noctalia.notifyError(noctalia.tr("notify.bad_variant", { name = value }), table.concat(VARIANTS, ", "))
    return
  end
  save()
  noctalia.notify(noctalia.tr("title"), noctalia.tr("notify.variant", { name = noctalia.tr("variants." .. variant()) }))
  refresh(false, true)
end

local function handle(action, value)
  if action == "apply" then
    refresh(true, true)
  elseif action == "regenerate" then
    refresh(true, false)
  elseif action == "auto" then
    setAuto(value)
  elseif action == "variant" then
    setVariant(value or "")
  end
end

function onIpc(event, payload)
  handle(event, if type(payload) == "string" then trim(payload) else "")
end

noctalia.state.watch("palette.request", function(request)
  if type(request) == "table" then
    handle(request.action, request.value)
  end
end)

-- The settings win over the tile / IPC again once changed.
function onConfigChanged()
  autoOverride = nil
  variantOverride = nil
  save()
  publish()
  if auto() then
    refresh(false, false)
  end
end

local sinceCheck = 0

function update()
  sinceCheck += 1
  if auto() then
    refresh(false, false)
  end
  -- Pick up palette source changes made elsewhere (Settings, IPC) for the tile.
  if sinceCheck % 5 == 0 then
    publish()
  end
end

noctalia.setUpdateInterval(POLL_MS)
publish()
if auto() then
  refresh(false, false)
end
