--!nonstrict
-- Cave Abode service. Writes settings.json and colors.json into the plugin
-- data dir for the Quickshell lock (quickshell/services/CaveAbode.qml), starts
-- the lock, and runs the lock-before-suspend watcher. No onConfigChanged: a
-- settings change restarts this runtime, which also restarts the watcher.
--
-- Once greeter-setup.sh has created /var/lib/cave-abode, every sync also
-- mirrors the wallpaper, ~/.face, palette, settings and cultivation there for
-- the greeter, which runs as the `greeter` user and can't read your home.
--
--   noctalia msg plugin nafeel/cave-abode:service all lock|lock-and-suspend|preview|sync

local root = noctalia.pluginDir()
local dataDir = noctalia.pluginDataDir()
local GREETER_DIR = "/var/lib/cave-abode"

-- Positional args: $1 greeter dir, $2 data dir, $3 wallpaper, $4 avatar.
-- Copies only what changed; each file lands whole (copy, then rename).
local MIRROR_SCRIPT = [[
[ -d "$1" ] && [ -w "$1" ] || exit 0
put() {
  [ -f "$1" ] || return 0
  cmp -s "$1" "$2" 2>/dev/null && return 0
  cp -f "$1" "$2.tmp" && chmod 644 "$2.tmp" && mv -f "$2.tmp" "$2"
}
put "$3" "$1/wallpaper"
put "$4" "$1/avatar"
for f in colors.json settings.json lockstats.json; do put "$2/$f" "$1/$f"; done
]]

local function lighten(hex, amount)
  local r, g, b = hex:match("#(%x%x)(%x%x)(%x%x)")
  if r == nil then
    return hex
  end
  local function mix(c)
    local v = tonumber(c, 16)
    return math.floor(v + (255 - v) * amount + 0.5)
  end
  return string.format("#%02x%02x%02x", mix(r), mix(g), mix(b))
end

-- `a` moved towards `b` by `t` (0..1).
local function blend(a, b, t)
  local ar, ag, ab = (a or ""):match("#(%x%x)(%x%x)(%x%x)")
  local br, bg, bb = (b or ""):match("#(%x%x)(%x%x)(%x%x)")
  if ar == nil or br == nil then
    return a
  end
  local function mix(x, y)
    x, y = tonumber(x, 16), tonumber(y, 16)
    return math.floor(x + (y - x) * t + 0.5)
  end
  return string.format("#%02x%02x%02x", mix(ar, br), mix(ag, bg), mix(ab, bb))
end

local function sync()
  local settings = {
    palette = noctalia.getConfig("palette") or "noctalia",
    greeter_session = noctalia.getConfig("greeter_session") or "start-umbriel",
    wallpaper = noctalia.wallpaperPath(noctalia.focusedOutputName() or "") or "",
  }
  noctalia.writeFile(dataDir .. "/settings.json", noctalia.json.encode(settings, true))

  -- The theme always sits on a dark ink backdrop; a light palette keeps the
  -- original ink and gold.
  local colors = {}
  if noctalia.isDarkMode() then
    local c = noctalia.getColor
    colors = {
      ink = c("surface"), night = c("surface_variant"), mist = c("on_surface_variant"),
      paper = c("on_surface"), gold = c("primary"),
      -- Secondary text. "outline" is a border colour, far too dark to read on
      -- the ink; on_surface_variant, eased a little towards the ink, is.
      paperDim = blend(c("on_surface_variant"), c("surface"), 0.18),
      goldHi = lighten(c("primary") or "", 0.35), jade = c("tertiary"),
      cinnabar = c("error"), ember = c("secondary"),
    }
  end
  noctalia.writeFile(dataDir .. "/colors.json", noctalia.json.encode(colors, true))

  noctalia.runAsync({
    "sh", "-c", MIRROR_SCRIPT, "sh", GREETER_DIR, dataDir, settings.wallpaper, noctalia.expandPath("~/.face"),
  }, function(result)
    if result.exitCode ~= 0 then
      noctalia.log("cave-abode: greeter mirror failed: " .. noctalia.string.trim(result.stderr))
    end
  end)
end

local function lock()
  noctalia.runAsync({ root .. "/bin/cave-abode-lock" })
end

function onIpc(event, _payload)
  if event == "lock" then
    lock()
  elseif event == "lock-and-suspend" then
    noctalia.runAsync({ "sh", "-c", '"$1" & sleep 1.5; systemctl suspend', "sh", root .. "/bin/cave-abode-lock" })
  elseif event == "preview" then
    noctalia.runAsync({ "sh", "-c", 'CAVE_ABODE_STATE="$2" exec quickshell -p "$1"', "sh",
      root .. "/quickshell/Preview.qml", dataDir })
  elseif event == "sync" then
    sync()
  end
end

sync()
if noctalia.getConfig("lock_before_suspend") ~= false then
  noctalia.runStream(root .. "/bin/cave-abode-sleep-lock", function(line)
    noctalia.log("cave-abode sleep watcher: " .. line)
  end)
end
