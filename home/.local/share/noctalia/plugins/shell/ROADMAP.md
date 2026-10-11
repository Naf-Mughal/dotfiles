# Shell roadmap

The plan for nafeel/shell: from a Quickshell shell hosted by Noctalia to a full desktop stack of
its own. Kept here so any session (or person) can see where things stand. Update it in the same
change as the work: tick items, move finished stages to Done with a date.

## Where it's going

One cohesive system, owned end to end:

| Layer | Runs on |
|---|---|
| Compositor | umbriel |
| Login | greetd + the shell's own Quickshell greeter (cave-abode look) |
| Desktop | `nafeel-shell` (all UI and services) + the `Nafeel` native module + small scripts |
| Lock | the same cave-abode code, inside the shell |
| Apps | themed from one pigment palette by the shell's own template engine |

The look, in layers:

1. **Base: ink and paper xianxia** with Ryoku's discipline: sumi ink (dark) or rice paper (light),
   paper fibre and grain, ink wash, hairlines not boxes, Latin + CJK gloss pairs, tracked mono
   labels, seals, nothing loud.
2. **Colour: M3 roles, pastel pigments.** Roles from the wallpaper, then a pigment pass that
   desaturates them into ink-wash and paper tones nudged toward mineral pigments (cinnabar,
   jade/malachite, azurite, ochre-gold). Cinnabar stays fixed.
3. **Frosted paper** (Ryoku's recipe): translucent surfaces (80-90%, a setting) over a small
   compositor blur with grain and a touch of vibrancy, frost only inside the shapes.
4. **Motion: one physics engine** better than Caelestia's goo and Ryoku's blob: real GPU blobs,
   ink-bleed edges, split and merge, surface tension, surfaces that soak in like ink.
5. **Primitives and layout directives built for this desktop**, so every new panel comes out
   cohesive without hand-tuning.

Sources: Caelestia and Ryoku (GPL-3.0) and Noctalia (MIT) may be ported directly (the user wants
direct code reuse where it's good: Noctalia's clipboard and idle 1:1), with their
notices kept (see NOTICE). Take mechanics wholesale; restyle visuals into the one language above.

## Now

- [x] **Verify Alt+Tab by hand** (user confirmed 2026-10-11): hold Alt + Tab through the list; a quick tap flips to the last
  window without the panel showing; Shift+Tab back; Esc cancels; over a fullscreen app. Note
  whether Tab inside the `switcher` submap is instant or goes through the keybind (~70 ms).
- [x] Verify screenshots keep panels (user confirmed 2026-10-11): `Mod+Shift+S` with a panel open; the capture button with
  the capture panel pinned.
- [x] Commit the work so far (native module, switcher, previews, capture fix) as a known-good
  point to roll back to.
- [x] Add NOTICE: Caelestia, Ryoku (and what it inherits: DankMaterialShell MIT, OkShell),
  Cave Abode, Noctalia (MIT).

## Stage D: design system (before rebuilding anything else)

Everything built after this uses it, so nothing needs restyling later.

- [x] **D1 Frosted paper** (2026-10-11). Plugin setting `paper` (90 / 85 / 80% or solid, default
  85) -> Tokens.transparency -> the frame and lock frame surfaces; containers stay solid sheets.
  umbriel `[[layer_rule]]` for `^nafeel-shell` (blur, ignore_alpha 0.05, not optimized) written
  into the shell's fragment unless solid; global `[appearance.blur]` set to Ryoku's recipe
  (radius 4, 1 pass, noise 0.01, saturation 1.17; config backed up). Paper fibre (`fibre`
  uniform: strands at three angles + speckle, slightly denser and lighter) in frame.frag.
- [x] **D2 Pigment palette** (2026-10-11). A new extractor instead of Material You's one-seed
  scheme: `wallpaper-palette/bin/pigment.py`, the plugin's default variant `pigment`. Celebi
  quantization with pixel counts, in OKLab; neutrals become the wallpaper's own paper (light) and
  ink (dark); colour families clustered in the a/b plane (hue and chroma, so a vivid red and a
  soft ochre stay apart), refined by weighted k-means; each family scored by coverage and
  intensity; families a few degrees apart merge into one colour (ochre + pale yellow); the most
  covering leads (primary), the most intense of the rest pops (tertiary), the next real colour
  is secondary (else the lead, quieter: never an invented colour), weak families are whispers
  (subtle tints) or dropped. Styles as variants, like Material's: `pigment` (faithful,
  default), `pigment-vibrant` (lead intensified, surfaces tinted toward it),
  `pigment-expressive` (every real colour its own role, bolder), `pigment-fruitsalad` (the
  only one that blends), `pigment-soft` (quiet). Every role in pastel OKLCH (accent strength follows the
  family's intensity, so the pop stays vivid), the same Material role names and term0-15, so
  the shell, Noctalia and the app templates take it unchanged. Reading saved in the scheme
  (`pigment`: lead, pop, second, whispers, paper, ink).
- [ ] **D3 Motion engine.** Port Ryoku's `Blobs` C++ plugin (from Caelestia) into the `Nafeel`
  module; replace the QML goo. Then beyond it: ink-bleed edges in motion, split/merge (a pill
  leaving the bar, a toast dripping from its corner), surface tension, ink-soak reveal. One
  engine for drawers, corners, the workspace plate, the switcher selection, toasts.
- [ ] **D4 Primitives.** Surface (paper/ink, blob-shaped), Sheet, Seal, Gloss, Rail, Strip,
  Chip, and the controls (button, switch, slider, field, list row) rebuilt on them.
- [ ] **D5 Layout directives.** Declare a panel (anchor: edge or corner, grow-from, sections,
  density) and the system does spacing rhythm, the reveal cascade, morphs between panels and
  the corner joins. Migrate the existing panels onto it.

## Stage N: replace Noctalia

Noctalia keeps running as the fallback until N7.

- [ ] **N1 Easy wins.** Brightness via brightnessctl; night light (gammastep/wlsunset); caffeine
  as a shell idle inhibitor; dark/light as a palette setting; weather fetched by the shell
  (Open-Meteo, location setting); session actions with graceful-power's "close apps first"
  ported; notes storage in the shell only; file-manager as a one-off `xdg-mime` script;
  volume/brightness/DPMS keys through `shell-msg`.
- [ ] **N2 Clipboard: a direct 1:1 port** (the user wants Noctalia's behaviour exactly, restyled).
  Port Noctalia's `clipboard_service.cpp` (ext/wlr data-control, encrypted
  history via libsodium, images) into the `Nafeel` module as a `Clipboard` type; panel in the
  shell (a command center tab or corner) keeping Noctalia's behaviour: paste, pin, delete,
  image previews. `:` mode in the command center uses it.
- [ ] **N3 Capture.** The capture plugin's backend (grim, slurp, gpu-screen-recorder, state,
  pause/mic, notifications to open/edit/delete) as a shell Capture service.
- [ ] **N4 Wallpaper.** A background layer in the shell (crossfade on change), set/random/default
  and folders without Noctalia; the picker writes the path; the palette step (`extract.py`,
  Caelestia's generator) runs on change.
- [ ] **N5 Theme engine (T).** The shell's template renderer, ported from Noctalia's own
  (`src/theme/`: builtin/community templates and palettes) where it helps, replacing it: one theme
  file (pigment roles, paper/ink alpha, fonts, radius), Noctalia/matugen-compatible template
  syntax, reload hooks. Port the templates in use: btop, cava, foot, gtk3, gtk4, kcolorscheme,
  qt, umbriel, Claude Code, Discord, VS Code, Spicetify, fuzzel, rofi, fastfetch, OBS, fcitx5,
  LibreOffice, Papirus, hyprtoolkit, antigravity; plus app-theming (qtengine). Translucency
  where apps support it (foot alpha, GTK CSS).
- [ ] **N6 Idle: a direct 1:1 port of Noctalia's idle management** (the user rates it highly):
  `src/idle/idle_manager.cpp` (ext-idle-notify behaviours in order, timeouts, resume commands),
  `idle_inhibitor.cpp`, `idle_grace_overlay.cpp` (the fade warning before an action, cancelled by
  input; redrawn in the shell), and `src/dbus/idle/screensaver_service.cpp` (apps' ScreenSaver
  inhibit) into the `Nafeel` module, about 1,300 lines; idle-kit's AC/battery profiles, battery
  saver and media-aware suspend on top; cave-abode's sleep lock on
  logind `PrepareForSleep`; cave-abode settings into the shell.
- [ ] **N7 Settings and cut-over.** A settings panel in the shell (rounding, immersion, motion,
  opacity, wallpaper and scheme, idle timeouts, location, capture prefs, templates). Then:
  umbriel autostarts `nafeel-shell` directly, struts and keybinds become static dotfiles,
  `shell-msg` loses its Noctalia fallbacks, Noctalia leaves autostart, the plugin-host glue
  (`service.luau`, plugin.toml) is retired. Keep a known-good commit first.

## Stage G: greeter

- [ ] **G1 Quickshell greeter** on greetd (Quickshell's Greetd service) under umbriel or cage,
  built from the lock's code: the same cave-abode theme, frame and frost.
- [ ] **G2 Sync** shell code, wallpaper and scheme to a place the `greeter` user can read
  (as noctalia-greeter does), then swap the command in `/etc/greetd/config.toml` and retire
  noctalia-greeter.

## Ideas, not scheduled

- Custom panels through `extensions/` (a Ryoku Rashin-style dashboard).
- Dock window thumbnails (WindowThumb).
- A layout studio for the bar (Ryoku's Bar Studio idea) on top of D5.
- Trim memory (about 230 MB PSS with everything opened once).

## Notes

- Screen-share picker belongs to xdg-desktop-portal-umbriel, not Noctalia: unaffected by N7.
- The native module needs a rebuild after a Qt minor upgrade (`native/build.sh`).

## Done

- Phases 0-7 (2026-10-10/11): plugin + supervisor, full Material scheme from wallpaper-palette,
  frame of four bars and four corners (Noctalia-style concave joins, ink wash, gilded edge),
  bar with spring active pill, corner and edge popouts (Wi-Fi, Bluetooth, audio, display, battery,
  media, notifications, capture, session), dock + command center (search, `>` `=` `:` modes, 12
  tabs), notification server + toasts + action center, OSD (volume, mic, brightness, toggles),
  cave-abode lock inside the shell and its frame, switch-over from Noctalia's bars.
- Polish passes 1-4: settings (radius preset, immersion, motion), tokens, goo (BlobRect port),
  two-spring corners, choreography (cascade, toast glide), M3 state layers and press bounce, dock
  magnify, mist and spirit motes, glosses and 时辰 touches, empty states, lock cohesion.
- 2026-10-11: `Mod+Shift+S` goes straight to region picking (closing any open panel first);
  `Mod+Shift+R` opens the capture popout on Record, starts on a second press, stops while
  recording (the old keys' flow, without Noctalia's centred dialog). Tried windows flush against
  the bar; reverted, the user prefers the gap.
- 2026-10-11: **wallpaper picker** (`Mod+W`, top-centre drawer: folder chips, a strip of the
  library centred on the current wall, set through Noctalia), **notes** (`Mod+X`, right-edge pad,
  autosaved to `~/.local/state/nafeel-shell/notes.md`), **polkit prompts** (the shell's agent in a
  top-centre drawer; Noctalia's `polkit_agent` GUI override moved out of settings.toml so the
  plugin can switch it, restored on disable), **the rest of the OSD** (caffeine, night light,
  Caps/Num Lock, keyboard layout, microphone in use, screen being shared; `Mod+Ctrl+C` routes
  through the shell). Frame shader now has ten drawer slots.
- 2026-10-11: left bar regrouped: above the session button only [tray] and [sound · connections ·
  battery], every left-bar panel now a corner panel (bottom-left: session, sound = volume + mic +
  brightness + display toggles + now playing, connections = Wi-Fi | Bluetooth, battery; top-left:
  notifications, capture); the middle bar popout is gone. OSD is a pill from the top centre. Any
  pinned panel takes the keyboard (Esc closes it); clicks inside pinned panels no longer close them
  (the outside-click catcher ignores open drawers). Wallpaper picker: search field, arrow keys move
  the selection, Enter sets, Esc closes.
- 2026-10-11: **native module** (`native/`, QML import `Nafeel`, built by `native/build.sh`, by the
  supervisor if missing, and by install.sh): `WindowThumb` captures one window over
  ext-image-copy-capture on its own Wayland connection, only while visible, damage-driven with an
  fps cap, scaled to its drawn size on the CPU and uploaded as a texture; `Keyboard.modifiers()`
  reads the held modifiers. **Shell Alt+Tab** replaces Noctalia's: a top-centre carousel of live
  previews (MRU order from the umbriel service, windows on every screen's active workspace),
  Alt+Tab / Alt+Shift+Tab through `shell-msg switch`, letting go of Alt commits (key release, or
  the modifier state once it has the keyboard, so a quick tap works; the carousel waits 140 ms before showing, so a quick tap never shows it), umbriel `switcher` submap
  while open (Ctrl+Alt+Escape leaves it). Binds and Mod+Tab live in the shell's umbriel fragment;
  the nafeel/window-switcher plugin is disabled (its fragment backed up and removed). **Workspace
  previews**: windows on other workspaces are live thumbnails now.
- 2026-10-11: screenshots keep open panels again (the capture plugin's old rule, which `shell-msg
  snip` had broken by closing them): `Mod+Shift+S` leaves any panel up to be captured, and the
  capture popout's button keeps the popout in the shot when it's pinned (clicked open); a hover
  preview, or a recording, still closes it first.
- 2026-10-11: workspace previews draw inactive workspaces as a miniature desktop: the wallpaper in
  a scaled copy of the shell's frame (bar-thick border, rounded hole, gilded edge), live window
  tiles on it; an empty one shows 空 on a chip of the shell's surface.
- 2026-10-11: fixed bar groups vanishing for good after a fullscreen window or the lock (a group
  hid itself when no child was visible, and children count as invisible while the bar is hidden).
