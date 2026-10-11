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
- [x] **D2 Pigment palette** (2026-10-11; reworked the same day). `wallpaper-palette/bin/pigment.py`,
  the plugin's default variant `pigment`. Reading after Okmain (dgroshev.com/blog/okmain): the
  full image averaged down in Oklab (no sRGB mud, no noise colours), pixels weighted by place
  (centre 1, borders 0.3), neutrals split off (ink and paper), colour pixels clustered by
  weighted k-means++ in the a/b plane and merged when they're one colour. Roles: surfaces are
  black and white (the wallpaper's own ink and paper, barely tinted; the paper look is the
  shell's frost, not coloured surfaces); accents are the real colours: the most covering leads
  (primary), the most vivid of the rest pops (tertiary), the next real colour is secondary;
  nothing invented (only the fruit-salad style blends); a faint colour that covers little stays
  faint; a black-and-white wallpaper gives a black-and-white palette (errors stay red). Warm
  colours keep their names as they lighten (ochre -> yellow, not peach; red -> coral, not
  pink). Styles: `pigment`, `-vibrant`, `-expressive`, `-fruitsalad`, `-soft`.
  Tried and dropped (the user found them bad): coloured-paper surfaces and a watercolour wash
  in the frame shader; maybe revisit later.
- [x] **D3a Blob engine** (2026-10-11). Ryoku's blob engine (GPL-3.0, from Caelestia) ported
  into the `Nafeel` module: BlobGroup, BlobRect, BlobInvertedRect, BlobShape, BlobMaterial and
  its shaders (`native/src/blob*`, `native/shaders/blob.*`). Extended: the paper (ink wash,
  grain, fibre, gilded line just outside the shape) in the blob shader; BlobRect `axisAligned`
  (corners bounce outward, no tilt) and `maxStretch`. FrameWindow draws the frame as a
  BlobInvertedRect and every drawer as a BlobRect (per-corner radii: only desktop-facing corners
  round; no sinks), all inside one layer faded as a whole: the frosted paper, without seams
  where shapes overlap. The goo is the BlobRect spring in C++ (Drawer reads `rawDeformMatrix`);
  the JS goo is gone. The lock frame still uses shaders/frame.frag.
- [x] **D3b Wet ink** (2026-10-11): each blob has a wetness (BlobRect `wet` from outside, plus
  its own speed, eased: quick to wet, slower to dry; packed in the rect data). Wet ink bleeds:
  a ragged edge (two octaves of noise on the boundary, up to ~3.5 px) that dries crisp; and
  surface tension: wet shapes join each other and the frame with a fatter neck (fillet up to
  2.5x) that tightens to the exact fillet as they settle. Drawers are wet as they open, near
  closed, and while moving fast. (Padding widened so the neck isn't clipped.)
- [x] **Out of the bar** (2026-10-11): corner panels have no seed bubble; they start flush with
  their bar, run along it first (progY leads opening) and then come out of it (progX), and
  closing pull back into the bar first and then shrink along it. Wet follows how far out of the
  bar it is; the ragged bleed toned to 1.6 px. Mist and spirit motes removed from all drawers
  (they made the motion janky).
- [x] **The bar morphs** (2026-10-11): a panel is the bar's own edge swelling out. `emerge`
  (0..1, how far out of the bar) drives it: while low, the desktop-facing corners are as round as
  the blob allows (a smooth swell of the bar) and square up as it comes out; the join neck is up
  to 4x the fillet while wet (wet = 1 - emerge), so the bar's edge flows into the swell and it
  melts back the same way; the content inks in only from 50% out (and leaves first), so nothing
  seems to slide out from under the bar.
- [x] **Part of the bar** (2026-10-11, after several rounds with the user): a corner panel grows
  out of its corner point in both directions (a spring per axis, width a touch brisker; a try at
  "length at once, only the edge moves" read as coming from the left and was reverted); the content sits in an `out` window clipped at the bar's and border's
  edges and rides the moving edges (a corner's free corner), so it never appears from behind the bar's icons, which act as the panel's tabs
  (content starts right beside them). The spring goo stays, but pinned: BlobRect `anchor` (the
  side it grows out of; offset = (M - I)(C - P)) so only the free edge squashes and stretches and
  the root never comes loose from the bar; the content window gets the same transform. Tried and
  dropped on the way: the bar's drawn width growing; a round swell with a fat neck; content
  inking in late.
- [x] **Tempo** (2026-10-11): Tokens.tempo scales all motion (tried 2 and 1.5; the user settled
  on 1, brisk 0.7). Durations scale by it (Tokens.dur, now used by every hard-coded duration but the lock theme's); every spring
  goes through Tokens.springK/dampK (stiffness / t^2, damping / t: same bounce, slower), and the
  goo's stiffness and damping scale the same way.
- [x] **Goo pill** (2026-10-11): the bar groups' active pill is a BlobRect in its own BlobGroup
  (the pill colour), so it stretches along its travel between controls and settles with a
  squash (deformScale 2.2x the frame's goo).
- [x] **D3c More motion** (2026-10-11): the goo pill splits: moving to another control it leaves
  a tail BlobRect behind that shrinks away (Tokens.anim.normal) while the pill springs off, the
  two joined by a neck (group smoothing 8) that thins and snaps. Ink-soak reveal: a drawer's
  content window gets a layer effect (shaders/soak.frag) only while revealing: the content soaks
  out from the side or corner it grows from behind a blotchy fbm front, on its own pace
  (`soak`: 900 ms in, InOutQuad, so it isn't over before it shows; normal out). Fixed after the
  user's first look: a tail was dropped when the pill re-entered a group mid-fade (a full-width
  line); now tails only between controls, the pill appears in place when entering, and the split
  is stronger (smoothing 10, slower tail, goo 3.5x). Second look: the pill jumped because the
  brief no-control gap while the pointer crosses between icons reset it; BarGroup now moves the
  pill imperatively (onActiveControlChanged: spring + tail between controls, instant from
  nowhere, held 220 ms through gaps). The soak was hidden by Choreo.cascade (content still
  faded while the front passed): cascades removed from frame panels, the soak is their reveal.
  Third look: the soak runs once from empty each time content arrives (Drawer.resoak(): on open,
  and CornerPopout on switching kinds while open), recedes on close; the notifications group's
  pill was pale on pale (secondary on secondaryContainer), now the group's inverse like the
  sound group's; the workspace indicator's gold plate is a goo blob with a splitting tail too
  (the user loves it). Fourth look: a hairline across the bar was a pill/tail sliver on its way to
  nothing (wide, sub-pixel tall); tails and pills now leave their BlobGroup below 1 px, and
  BlobShape repaints when its group changes (leaving a group, Ryoku's engine kept drawing the
  last frame: a stale pill). Reduced
  motion: a plain fade.
- [x] **D4 Primitives** (2026-10-12). Roles in Colours (`roleFill/roleInk/roleSubInk`: "paper"
  at a level 0..4, or primary/secondary/tertiary/error at "soft" | "strong" | "ghost"), so fill
  and ink always pair the same way. `Surface`: the one container (role, emphasis, level, shape
  preset, hairline outline; interactive: state layer, press bounce, Expressive morph,
  clicked/rightClicked/middleClicked; `ink`/`subInk` for children). `Sheet` (titled section:
  eyebrow, Latin + gloss heading, trailing actions, content), `Chip`, `Strip` (scrolling row
  or column, wheel, optional centred carousel). IconButton, Tile, ListRow and ButtonGroup
  rebuilt on Surface (same APIs). Wallpaper chips and strip and the Alt+Tab carousel moved onto
  Chip/Strip. Remaining hand-made surfaces (about 79 Rectangle/StyledRect in modules) move over
  with D5.
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
