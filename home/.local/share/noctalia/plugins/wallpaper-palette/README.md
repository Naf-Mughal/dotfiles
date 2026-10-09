# Wallpaper Palette

Shell colours from the wallpaper, made by Caelestia's colour generator.

`bin/extract.py` is a port of [caelestia-cli](https://github.com/caelestia-dots/cli)'s
dynamic scheme, so a wallpaper gives the same colours here as in Caelestia:

- **Seed**: a 128px thumbnail, Celebi-quantized to 128 colours and ranked by
  Caelestia's own Score (hue presence vs chroma, then the first colour above a
  falling chroma/tone cutoff). That's why it picks the vivid accent and not the
  biggest muddy area.
- **Scheme**: Material You via `materialyoucolor` (the library and spec
  Caelestia uses), in any variant: tonal spot, vibrant, expressive, fidelity,
  content, fruit salad, rainbow, neutral, monochrome. **Auto** picks neutral /
  content / tonal spot by how colourful the wallpaper is, like Caelestia's
  smart scheme.
- **Terminal**: Caelestia's gruvbox colours harmonized to the seed.
- **Hard flavour** and a **contrast** level (advanced), and optionally
  Caelestia's light/dark switch from the wallpaper's brightness.

The result is a Noctalia custom palette, `~/.config/noctalia/palettes/wallpaper.json`
(dark and light), mapped to Noctalia's roles the way Noctalia maps its own
`m3-*` schemes. Selecting it re-themes the shell and runs the templates, so
apps and the greeter follow.

The service checks the wallpaper every 2 s and regenerates when it, or a
setting, changes. Seeds are cached per wallpaper, so switching variants is
instant. It switches the shell to the palette when the palette is already in
use, or when Noctalia's own wallpaper colours are (setting "Replace Noctalia's
wallpaper colours"). A built-in or community palette you picked is left alone.

On first run it sets up a venv with `materialyoucolor` and `pillow` in the
plugin's data dir (`~/.local/state/noctalia/plugins/data/…`), which needs the
network once.

Settings → Plugins → Wallpaper Palette: follow the wallpaper, variant, flavour,
contrast, light/dark from the wallpaper, replace Noctalia's wallpaper colours.

Control-center tile: click regenerates and switches to it, right-click turns
following the wallpaper on or off.

IPC (`noctalia msg plugin nafeel/wallpaper-palette:service all …`): `apply`,
`regenerate`, `auto [on|off|toggle]`, `variant [NAME|next|prev|reset]`. A
variant set over IPC lasts until the settings change.

Try it on any image without changing anything (with the venv's python):
`python3 bin/extract.py IMAGE --variant fruitsalad`

Needs `python3` (and `ffmpeg` for video wallpapers).

## License

GPL-3.0-or-later, since `bin/extract.py` ports code from caelestia-cli
(GPL-3.0, © Caelestia contributors). See `LICENSE`.
