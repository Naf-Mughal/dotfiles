"""Pigment: a wallpaper palette for ink and paper (styles: see STYLES).

Material You builds every role from one seed colour. Pigment reads the whole
wallpaper instead and weighs each of its colours by two things:

  coverage   how much of the picture it takes up
  intensity  how vivid it is (OKLCH chroma)

so a wall of ochre paper with a small, fierce red sun gives an ochre lead and
a red that still pops, while a little dull green and blue are kept only as
whispers (subtle tints for terminal colours and the like) or dropped.

  1. Quantize a thumbnail to 96 colours with their pixel counts (Celebi, as
     Material You does), in OKLab/OKLCH, a perceptual space.
  2. Split them into neutrals (paper and ink: the wallpaper's own light and
     dark low-chroma tones) and colour families (merged by hue).
  3. Score each family: coverage and intensity. Families a few degrees apart
     read as one colour. The most covering leads (primary); the most intense
     of the rest pops (tertiary, the seal colour); the next real colour is
     secondary; weak families become whispers or are dropped. Roles use the
     wallpaper's colours as they are (only the fruit-salad style blends).
  4. Pigment pass: every role in pastel. Surfaces are the wallpaper's own
     ink (dark) or paper (light), barely tinted; accents are soft pigments
     whose strength follows their family's intensity, so a vivid colour stays
     vivid among soft ones.

Writes the same Material role names as the Material You path (and term0-15),
so the shell, Noctalia and the app templates take it unchanged.
"""

import math

from materialyoucolor.hct import Hct
from materialyoucolor.quantize import ImageQuantizeCelebi

# ── OKLab ─────────────────────────────────────────────────────────────────


def _lin(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c: float) -> float:
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def rgb_to_oklab(r: int, g: int, b: int) -> tuple[float, float, float]:
    r, g, b = _lin(r / 255), _lin(g / 255), _lin(b / 255)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def oklab_to_linear(L: float, a: float, b: float) -> tuple[float, float, float]:
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)


def oklch(L: float, C: float, h: float) -> int:
    """An OKLCH colour as ARGB, chroma reduced until it fits sRGB."""
    lo, hi = 0.0, C
    for _ in range(18):
        rgb = oklab_to_linear(L, hi * math.cos(math.radians(h)), hi * math.sin(math.radians(h)))
        if all(-1e-4 <= c <= 1 + 1e-4 for c in rgb):
            break
        mid = (lo + hi) / 2
        rgb = oklab_to_linear(L, mid * math.cos(math.radians(h)), mid * math.sin(math.radians(h)))
        if all(-1e-4 <= c <= 1 + 1e-4 for c in rgb):
            lo = mid
        else:
            hi = mid
        if hi - lo < 1e-4:
            hi = lo
    rgb = oklab_to_linear(L, hi * math.cos(math.radians(h)), hi * math.sin(math.radians(h)))
    r, g, b = (max(0, min(255, round(_gam(max(0.0, min(1.0, c))) * 255))) for c in rgb)
    return 0xFF000000 | (r << 16) | (g << 8) | b


def hue_diff(a: float, b: float) -> float:
    d = abs(a - b) % 360
    return min(d, 360 - d)


# ── Reading the wallpaper ─────────────────────────────────────────────────

NEUTRAL_C = 0.035  # below this an OKLCH colour reads as paper or ink, not a hue
SPLIT = 0.05  # a/b distance that makes a new colour family


class Family:
    """Colours of one hue in the wallpaper."""

    def __init__(self):
        self.members = []  # (L, C, h, weight)

    @property
    def share(self) -> float:
        return sum(w for *_, w in self.members)

    @property
    def hue(self) -> float:
        # Weighted circular mean, chroma-weighted so the vivid core leads.
        x = sum(C * w * math.cos(math.radians(h)) for _, C, h, w in self.members)
        y = sum(C * w * math.sin(math.radians(h)) for _, C, h, w in self.members)
        return math.degrees(math.atan2(y, x)) % 360

    @property
    def body_hue(self) -> float:
        # The hue you see: weighted by coverage (a little by chroma), not
        # pulled toward the family's most vivid edge.
        x = sum(w * C ** 0.5 * math.cos(math.radians(h)) for _, C, h, w in self.members)
        y = sum(w * C ** 0.5 * math.sin(math.radians(h)) for _, C, h, w in self.members)
        return math.degrees(math.atan2(y, x)) % 360

    @property
    def chroma(self) -> float:
        # Intensity: the vivid end of the family (weighted toward its peak),
        # ignoring specks under 0.3% of the picture.
        solid = [(C, w) for _, C, _, w in self.members if w >= 0.003] or [(C, w) for _, C, _, w in self.members]
        peak = max(C for C, _ in solid)
        mean = sum(C * w for C, w in solid) / sum(w for _, w in solid)
        return 0.6 * peak + 0.4 * mean

    @property
    def lightness(self) -> float:
        return sum(L * w for L, *_, w in self.members) / self.share

    def describe(self) -> dict:
        return {"hue": round(self.hue, 1), "share": round(self.share, 4), "chroma": round(self.chroma, 4),
                "lightness": round(self.lightness, 3)}


def read(thumb: str) -> dict:
    counts = ImageQuantizeCelebi(thumb, 1, 96)
    total = sum(counts.values()) or 1
    colours = []
    for argb, n in counts.items():
        L, a, b = rgb_to_oklab((argb >> 16) & 255, (argb >> 8) & 255, argb & 255)
        colours.append((L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360, n / total))

    # Neutrals: the paper (light) and the ink (dark) of the picture.
    neutral = [c for c in colours if c[1] < NEUTRAL_C]

    def tone_of(items, lo, hi, fallback):
        sel = [c for c in items if lo <= c[0] <= hi]
        w = sum(c[3] for c in sel)
        if w <= 0:
            return fallback
        x = sum(c[1] * c[3] * math.cos(math.radians(c[2])) for c in sel) / w
        y = sum(c[1] * c[3] * math.sin(math.radians(c[2])) for c in sel) / w
        return {"L": sum(c[0] * c[3] for c in sel) / w, "C": math.hypot(x, y),
                "h": math.degrees(math.atan2(y, x)) % 360, "share": w}

    # Low-chroma colours also tint the paper and ink (a beige paper is barely
    # a hue), so they count toward them too.
    soft = [c for c in colours if c[1] < NEUTRAL_C * 2.2]
    paper = tone_of(soft, 0.62, 1.01, None)
    ink = tone_of(soft, -0.01, 0.42, None)

    # Colour families: clustered in OKLab's a/b plane (hue and chroma
    # together), so a vivid red sun and a soft ochre paper stay apart even
    # when orange tones run between them. Seeded from the most covering
    # colours, then refined (weighted k-means).
    chroma_cols = [c for c in colours if c[1] >= NEUTRAL_C]
    ab = [(c[1] * math.cos(math.radians(c[2])), c[1] * math.sin(math.radians(c[2]))) for c in chroma_cols]
    centres: list[tuple[float, float]] = []
    for i in sorted(range(len(chroma_cols)), key=lambda i: -chroma_cols[i][3]):
        if all(math.dist(ab[i], m) > SPLIT for m in centres):
            centres.append(ab[i])
    assign = [0] * len(chroma_cols)
    for _ in range(8):
        for i, p in enumerate(ab):
            assign[i] = min(range(len(centres)), key=lambda k: math.dist(p, centres[k]))
        new = []
        for k in range(len(centres)):
            mem = [(ab[i], chroma_cols[i][3]) for i in range(len(ab)) if assign[i] == k]
            w = sum(m[1] for m in mem)
            new.append((sum(m[0][0] * m[1] for m in mem) / w, sum(m[0][1] * m[1] for m in mem) / w) if w else centres[k])
        centres = new
    families: list[Family] = []
    for k in range(len(centres)):
        f = Family()
        f.members = [chroma_cols[i] for i in range(len(ab)) if assign[i] == k]
        if f.members:
            families.append(f)
    return {"families": families, "paper": paper, "ink": ink, "neutralShare": sum(c[3] for c in neutral)}


# ── Choosing the pigments ─────────────────────────────────────────────────


def salience(f: Family) -> float:
    return (f.share ** 0.6) * ((f.chroma / 0.15) ** 1.2)


def choose(r: dict) -> dict:
    fams = sorted(r["families"], key=lambda f: -f.share)
    # Too little to matter at all: dropped.
    fams = [f for f in fams if f.share >= 0.004]
    if not fams:
        return {"lead": None, "pop": None, "second": None, "whispers": []}

    # Families a few degrees apart in hue read as one colour (an ochre and a
    # paler yellow are both "the yellow"): merge them for choosing roles.
    merged: list[Family] = []
    for f in fams:
        same = next((m for m in merged if hue_diff(m.body_hue, f.body_hue) < 8), None)
        if same:
            same.members += f.members
        else:
            g = Family()
            g.members = list(f.members)
            merged.append(g)
    fams = sorted(merged, key=lambda f: -f.share)

    # The lead: what the picture is mostly made of (coverage first, a touch of
    # intensity to break near-ties).
    lead = max(fams, key=lambda f: f.share * (0.6 + f.chroma / 0.25))
    rest = [f for f in fams if f is not lead and hue_diff(f.body_hue, lead.body_hue) > 18]

    # The pop: the most intense of the rest, if it's really present.
    pops = [f for f in rest if f.share >= 0.01 and f.chroma >= 0.08]
    pop = max(pops, key=lambda f: f.chroma * f.share ** 0.35, default=None)
    rest = [f for f in rest if f is not pop]

    # Second: the next real colour that's clearly there (a colour of its own:
    # not the pop again).
    seconds = [f for f in rest if (f.share >= 0.03 or salience(f) >= 0.08)
               and (pop is None or hue_diff(f.body_hue, pop.hue) > 8 or abs(f.chroma - pop.chroma) > 0.04)]
    second = max(seconds, key=salience, default=None)
    rest = [f for f in rest if f is not second]

    # Whispers: weak (little and dull) families, kept as subtle tints.
    whispers = [f for f in rest if f.share >= 0.008]
    return {"lead": lead, "pop": pop, "second": second, "whispers": whispers}


# ── The pigment pass: roles in pastel ink and paper ─────────────────────


def strength(f: Family | None, lo: float, hi: float, k: float) -> float:
    """A pastel chroma for a family: its intensity scaled down, within lo..hi."""
    if f is None:
        return lo * 0.5
    return max(lo, min(hi, f.chroma * k))


ANSI_HUES = {"red": 27, "green": 145, "yellow": 95, "blue": 255, "magenta": 335, "cyan": 200}


# Styles over the same reading (the variants of the `pigment` palette):
#   faithful    the colours as they are: coloured paper (a watercolour wash
#               of the lead) written on with clear inks (default)
#   vibrant     the lead intensified; surfaces drawn a little toward it
#   expressive  every real colour gets a role of its own, bolder
#   fruitsalad  blends and rotations of what's there (invents colours)
#   soft        pastel: everything quieter, nearly ink and paper alone
STYLES = {
    "faithful":   dict(lead_k=1.55, lead_lo=0.10, lead_hi=0.15, pop_k=1.0, pop_hi=0.19, sec_k=0.9,
                       tint=0.0, term=1.0, blend=False, spread=False, promote=False, paper=0.04),
    "vibrant":    dict(lead_k=1.95, lead_lo=0.13, lead_hi=0.18, pop_k=1.1, pop_hi=0.21, sec_k=1.0,
                       tint=0.012, term=1.15, blend=False, spread=False, promote=False, paper=0.052),
    "expressive": dict(lead_k=1.6, lead_lo=0.11, lead_hi=0.16, pop_k=1.1, pop_hi=0.21, sec_k=1.1,
                       tint=0.008, term=1.2, blend=False, spread=True, promote=True, paper=0.046),
    "fruitsalad": dict(lead_k=1.45, lead_lo=0.10, lead_hi=0.15, pop_k=1.0, pop_hi=0.18, sec_k=0.9,
                       tint=0.006, term=1.1, blend=True, spread=False, promote=False, paper=0.042),
    "soft":       dict(lead_k=0.85, lead_lo=0.06, lead_hi=0.10, pop_k=0.7, pop_hi=0.12, sec_k=0.55,
                       tint=0.0, term=0.75, blend=False, spread=False, promote=False, paper=0.028),
}


def roles(r: dict, pick: dict, light: bool, contrast: float = 0.0, style: str = "faithful") -> dict[str, Hct]:
    lead, pop, second = pick["lead"], pick["pop"], pick["second"]
    whispers = pick["whispers"]
    paper = r["paper"] or {"L": 0.93, "C": 0.02, "h": (lead.hue if lead else 80)}
    ink = r["ink"] or {"L": 0.2, "C": 0.015, "h": (lead.hue if lead else 250)}

    st = STYLES.get(style, STYLES["faithful"])
    lh = lead.body_hue if lead else paper["h"]
    # The lead's paper tone (the wide pale areas of the same hue, too soft to
    # count as a colour) is part of how that colour reads: weigh it in.
    if lead and r["paper"] and hue_diff(r["paper"]["h"], lh) < 15:
        w1, w2 = lead.share, r["paper"]["share"]
        d = ((r["paper"]["h"] - lh + 540) % 360) - 180
        lh = (lh + d * w2 / (w1 + w2)) % 360
    ph = pop.hue if pop else None
    # The third real colour, if any: a clear second family, else the
    # strongest whisper (expressive promotes it; the others keep it quiet).
    third = second or (max(whispers, key=salience) if whispers and st["promote"] else None)

    if st["blend"]:
        # Fruit salad: roles from blends of what's there (and rotations when
        # there's little), the one style that invents colours.
        if ph is None:
            ph = (lh + 60) % 360
        d = ((ph - lh + 540) % 360) - 180
        sh = (lh + d * 0.5) % 360
        tertiary = (ph, strength(pop, 0.07, st["pop_hi"], st["pop_k"]) if pop else 0.07)
        secondary = (sh, 0.07)
    elif st["spread"]:
        # Expressive: every real colour gets a role of its own: the pop is
        # secondary, the third colour (or a whisper) tertiary.
        secondary = (ph, strength(pop, 0.07, st["pop_hi"], st["pop_k"])) if pop else \
            ((third.body_hue, strength(third, 0.05, 0.12, st["sec_k"])) if third else (lh, 0.04))
        if pop and third:
            tertiary = (third.body_hue, strength(third, 0.06, 0.13, st["sec_k"] * 1.3))
        elif pop:
            tertiary = (ph, strength(pop, 0.05, 0.10, st["pop_k"] * 0.6))
        else:
            tertiary = (lh, 0.05)
    else:
        # Faithful, vibrant, soft: the colours as they are. Primary the lead,
        # tertiary the pop, secondary the next real colour, or else the lead
        # itself, quieter (never a colour the picture doesn't have).
        secondary = (third.body_hue, strength(third, 0.035, 0.09, st["sec_k"])) if third else \
            (lh, strength(lead, 0.03, 0.07, st["sec_k"] * 0.7))
        if pop:
            tertiary = (ph, strength(pop, 0.06, st["pop_hi"], st["pop_k"]))
        elif third:
            tertiary = (third.body_hue, strength(third, 0.05, 0.12, st["sec_k"] * 1.2))
        else:
            tertiary = (lh, strength(lead, 0.03, 0.06, st["sec_k"] * 0.5))
    primary = (lh, strength(lead, st["lead_lo"], st["lead_hi"], st["lead_k"]))

    # Paper: the surfaces are a stack of coloured papers, watercolour washes
    # of the wallpaper's real colours: the base sheet in the lead colour, the
    # cards on the second colour's paper, the highest on the pop's (a yellow
    # sheet, orange cards, red-tinted tops, for an ochre wallpaper with an
    # orange halo and a red sun). Pastel in light mode; in dark mode dusky
    # pastels, lifted a little (the frosted translucency lowers them further),
    # rather than deep browns. Inks on top carry the saturation.
    base_h = lh if lead else (paper["h"] if light else ink["h"])
    base_c = st["paper"] * (1.25 if light else 0.8) if lead else min((paper if light else ink)["C"], 0.02)
    sheets = [f for f in (lead, second, pop) if f] or [None]
    def sheet(i: int) -> tuple[float, float]:
        f = sheets[min(i, len(sheets) - 1)]
        if f is None:
            return base_h, base_c
        h = lh if f is lead else f.body_hue
        # A more intense colour dyes its sheet a little more (within reason).
        c = base_c * (1.0 + min(0.8, max(0.0, (f.chroma - 0.08) * 6)))
        return h, c
    # Writing ink: light mode writes with the wallpaper's own dark ink, given
    # colour; dark mode with a warm luminous ink of the paper's hue.
    if light:
        text_h, text_c = ink["h"], max(min(ink["C"] * 3, 0.06), 0.035)
    else:
        text_h, text_c = base_h, min(0.045, base_c * 1.1 + 0.005)
    cboost = 1 + contrast * 0.5

    out: dict[str, int] = {}

    def put(name, L, C, h):
        L = max(0.0, min(1.0, L))
        out[name] = oklch(L, max(0.0, C), keep_name(h, L))

    if light:
        surf = {"surfaceContainerLowest": 0.985, "surfaceContainerLow": 0.955, "surface": 0.945,
                "surfaceContainer": 0.93, "surfaceContainerHigh": 0.91, "surfaceContainerHighest": 0.89,
                "surfaceDim": 0.87, "surfaceBright": 0.965}
    else:
        surf = {"surfaceContainerLowest": 0.17, "surfaceDim": 0.20, "surface": 0.22,
                "surfaceContainerLow": 0.25, "surfaceContainer": 0.28, "surfaceContainerHigh": 0.31,
                "surfaceContainerHighest": 0.34, "surfaceBright": 0.37}
    # Which sheet each layer is: the base in the lead, cards in the second,
    # the top layers in the pop.
    layer = {"surfaceContainer": 1, "surfaceContainerHigh": 1, "surfaceContainerHighest": 2, "surfaceBright": 2}
    for name, L in surf.items():
        h, c = sheet(layer.get(name, 0))
        put(name, L, c, h)
    put("background", surf["surface"], base_c, base_h)
    put("surfaceVariant", surf["surfaceContainerHighest"], base_c, base_h)

    if light:
        put("onSurface", 0.24 / cboost, text_c, text_h)
        put("onSurfaceVariant", 0.40, text_c * 0.9, text_h)
        put("outline", 0.58, 0.02, text_h)
        put("outlineVariant", 0.82, 0.015, base_h)
        put("inverseSurface", 0.26, text_c, text_h)
        put("inverseOnSurface", 0.94, base_c, base_h)
    else:
        put("onSurface", min(0.97, 0.92 * cboost), text_c, text_h)
        put("onSurfaceVariant", 0.80, text_c * 0.9, text_h)
        put("outline", 0.60, 0.02, text_h)
        put("outlineVariant", 0.37, 0.015, base_h)
        put("inverseSurface", 0.90, text_c, text_h)
        put("inverseOnSurface", 0.25, base_c, base_h)
    put("onBackground", out_L(out, "onSurface"), text_c, text_h)

    # Accents: pastel pigments; the pop keeps more of its intensity.
    accents = {"primary": primary, "secondary": secondary, "tertiary": tertiary}
    for name, (h, C) in accents.items():
        if light:
            # A colour you can see as itself on pastel paper (a gold, a
            # cinnabar), written on in dark ink, rather than a dark brown.
            put(name, 0.70 if name == "primary" else 0.62, C * 1.1, h)
            put(f"on{cap(name)}", 0.22, C * 0.4, h)
            put(f"{name}Container", 0.89, max(C * 0.6, 0.06) if hue_diff(h, 50) < 45 else C * 0.5, h)
            put(f"on{cap(name)}Container", 0.30, C * 0.8, h)
            put(f"{name}Dim", 0.46, C, h)
            put(f"inverse{cap(name)}" if name == "primary" else f"_{name}Inv", 0.82, C, h)
        else:
            # The pop sits a touch deeper so an intense colour can show its
            # strength (light tones run out of sRGB chroma).
            if name == "tertiary":
                L = 0.68 if st["pop_k"] >= 1 else 0.78
            else:
                # A stronger lead sits a touch deeper so its chroma can show.
                L = 0.80 if name == "primary" and st["lead_k"] >= 1.9 else 0.84
            put(name, L, C, h)
            put(f"on{cap(name)}", 0.26, C * 0.45, h)
            # Containers: a pastel wash of the colour written on in dark ink
            # (a soft red, a soft orange), not a deep brown fill.
            # (A red's wash sits deeper: lighter, it can only turn pink.)
            redish = 5 <= h % 360 < 42
            put(f"{name}Container", 0.68 if redish else 0.74, max(C * 1.1, 0.12) if hue_diff(h, 50) < 45 else C * 0.75, h)
            put(f"on{cap(name)}Container", 0.25, C * 0.55, h)
            put(f"{name}Dim", 0.76, C * 0.9, h)
            put(f"inverse{cap(name)}" if name == "primary" else f"_{name}Inv", 0.48, C, h)
        put(f"{name}Fixed", 0.90, C * 0.55, h)
        put(f"{name}FixedDim", 0.82, C * 0.8, h)
        put(f"on{cap(name)}Fixed", 0.22, C * 0.5, h)
        put(f"on{cap(name)}FixedVariant", 0.38, C * 0.6, h)
        put(f"{name}PaletteKeyColor", 0.62, C * 1.4, h)

    # Error: cinnabar, softened like everything else; nudged away from the
    # pop when that is itself a red, so the two stay apart.
    eh = 25.0
    if any(hue_diff(h, eh) < 20 for h, _ in accents.values()):
        eh = (min((h for h, _ in accents.values()), key=lambda h: hue_diff(h, 25.0)) - 18) % 360
    if light:
        put("error", 0.52, 0.15, eh)
        put("onError", 0.98, 0.01, eh)
        put("errorContainer", 0.89, 0.06, eh)
        put("onErrorContainer", 0.32, 0.10, eh)
        put("errorDim", 0.46, 0.14, eh)
    else:
        put("error", 0.76, 0.13, eh)
        put("onError", 0.27, 0.07, eh)
        put("errorContainer", 0.40, 0.09, eh)
        put("onErrorContainer", 0.91, 0.05, eh)
        put("errorDim", 0.70, 0.12, eh)
    put("errorPaletteKeyColor", 0.62, 0.17, eh)
    put("neutralPaletteKeyColor", 0.6, base_c, base_h)
    put("neutralVariantPaletteKeyColor", 0.6, base_c * 1.5, base_h)
    out["surfaceTint"] = out["primary"]
    out["shadow"] = 0xFF000000
    out["scrim"] = 0xFF000000

    # Terminal: each ANSI colour takes the wallpaper's family of that hue when
    # there is one (its strength following the family's), else a whisper of
    # it (low chroma), so a wallpaper without blue gets a quiet blue.
    fams = [f for f in (lead, pop, second, *whispers) if f]
    for i, (name, h) in enumerate(ANSI_HUES.items(), start=1):
        near = min(fams, key=lambda f: hue_diff(f.hue, h), default=None)
        if near and hue_diff(near.hue, h) < 35:
            hue, C = near.hue + (h - near.hue) * 0.25, strength(near, 0.06, 0.13 * st["term"], 0.7 * st["term"])
        else:
            hue, C = h, 0.035 * st["term"]
        if light:
            put(f"term{i}", 0.50, C, hue)
            put(f"term{i + 8}", 0.42, C * 1.1, hue)
        else:
            put(f"term{i}", 0.72, C, hue)
            put(f"term{i + 8}", 0.82, C * 0.9, hue)
    if light:
        put("term0", 0.95, base_c, base_h)
        put("term8", 0.62, 0.015, text_h)
        put("term7", 0.30, text_c, text_h)
        put("term15", 0.20, text_c, text_h)
    else:
        put("term0", 0.22, base_c, base_h)
        put("term8", 0.45, 0.015, base_h)
        put("term7", 0.82, text_c, text_h)
        put("term15", 0.94, text_c, text_h)

    return {k: Hct.from_int(v) for k, v in out.items() if not k.startswith("_")}


def keep_name(h: float, L: float) -> float:
    """A warm hue made lighter keeps its colour's name: an ochre lightened is
    a pastel yellow (not peach), an orange an apricot and a red a coral (not
    pink). Darker tones keep their hue (a dark yellow is a brown, which is
    right)."""
    h %= 360
    if L <= 0.6:
        return h
    t = min(1.0, (L - 0.6) / 0.35)
    if 50 <= h <= 105:      # yellows and ochres -> yellow
        return h + (95 - h) * 0.85 * t
    if 42 <= h < 50:        # oranges -> apricot
        return h + 22 * t
    if 5 <= h < 42:         # reds and vermilions -> coral, away from pink
        return h + 5 * t
    return h


def out_L(out: dict, name: str) -> float:
    argb = out[name]
    return rgb_to_oklab((argb >> 16) & 255, (argb >> 8) & 255, argb & 255)[0]


def cap(s: str) -> str:
    return s[0].upper() + s[1:]


def generate(thumb: str, light: bool, contrast: float = 0.0, style: str = "faithful") -> tuple[dict[str, Hct], dict]:
    """The scheme and a description of what was read (for the summary)."""
    r = read(thumb)
    pick = choose(r)
    desc = {
        "lead": {**pick["lead"].describe(), "bodyHue": round(pick["lead"].body_hue, 1)} if pick["lead"] else None,
        "pop": pick["pop"].describe() if pick["pop"] else None,
        "second": pick["second"].describe() if pick["second"] else None,
        "whispers": [f.describe() for f in pick["whispers"]],
        "dropped": [f.describe() for f in r["families"] if f.share < 0.004],
        "paper": r["paper"], "ink": r["ink"],
    }
    desc["style"] = style
    return roles(r, pick, light, contrast, style), desc
