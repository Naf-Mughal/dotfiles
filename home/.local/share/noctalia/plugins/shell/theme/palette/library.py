#!/usr/bin/env python3
"""The wallpaper library's index, for the shell's picker (stage W1).

The idea is Ryoku's (ryogami's daemon indexes every wallpaper with a thumbnail
and its colour: hue bucket, saturation, "richness"), done with the shell's own
colour reading (pigment.py): each wallpaper's lead pigment (the colour the
theme would build on), how vivid it is, whether it's really black and white,
and how light it is, so the picker can filter by what a wallpaper *is*.

    library.py ROOT INDEX.json THUMBS_DIR [--force]

Incremental: a wallpaper whose size and mtime haven't changed keeps its entry.
Progress is NDJSON on stdout ({"done": n, "total": m}), the index is written
atomically at the end (and every 40 new entries, so a long first run shows
up as it goes).

Entry: { path, name, folder, mtime, size, w, h, thumb, hue, bucket, chroma,
         lightness, neutral, colours: ["#rrggbb", …] }
  bucket  0..11: the lead pigment's hue in twelve steps of 30° (0 = red);
          99: black and white / neutral (Ryoku's numbering)
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
import tempfile
from pathlib import Path

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pigment  # noqa: E402

EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}
THUMB_W = 480


def write_atomic(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".library-")
    with os.fdopen(fd, "w") as f:
        json.dump(data, f, separators=(",", ":"))
    os.replace(tmp, path)


def entry_for(path: Path, root: Path, thumbs: Path) -> dict:
    st = path.stat()
    key = hashlib.sha1(f"{path}|{st.st_size}|{int(st.st_mtime)}".encode()).hexdigest()[:20]
    thumb = thumbs / f"{key}.webp"
    with Image.open(path) as img:
        w, h = img.size
        if not thumb.exists():
            img = img.convert("RGB")
            img.thumbnail((THUMB_W, THUMB_W * 2), Image.Resampling.LANCZOS)
            thumb.parent.mkdir(parents=True, exist_ok=True)
            img.save(thumb, "WEBP", quality=82, method=4)

    # The colour, from the thumbnail (pigment averages down to ~96 px anyway).
    r = pigment.read(str(thumb))
    pick = pigment.choose(r)
    lead = pick["lead"]
    families = sorted(r["families"], key=lambda f: -f.share)
    colours = ["#%06x" % (pigment.oklch(f.lightness, f.chroma, f.hue) & 0xFFFFFF) for f in families[:4] if f.share > 0.02]
    # Mean lightness: paper, ink and the colour families, by share.
    parts = [(t["L"], t["share"]) for t in (r["paper"], r["ink"]) if t] + [(f.lightness, f.share) for f in families]
    total = sum(s for _, s in parts) or 1
    lightness = sum(l * s for l, s in parts) / total

    rel = path.relative_to(root)
    return {
        "path": str(path),
        "name": path.name,
        "folder": rel.parts[0] if len(rel.parts) > 1 else "",
        "mtime": int(st.st_mtime),
        "size": st.st_size,
        "w": w,
        "h": h,
        "thumb": str(thumb),
        "hue": round(lead.hue, 1) if lead else None,
        "bucket": int(((lead.hue + 15) % 360) // 30) if lead else 99,
        "chroma": round(lead.chroma, 4) if lead else 0.0,
        "lightness": round(lightness, 3),
        "neutral": lead is None,
        "colours": colours,
    }


def main() -> int:
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    root, index_path, thumbs = Path(sys.argv[1]).expanduser(), Path(sys.argv[2]), Path(sys.argv[3])
    force = "--force" in sys.argv[4:]
    try:
        old = {e["path"]: e for e in json.loads(index_path.read_text()).get("wallpapers", [])}
    except (OSError, ValueError):
        old = {}

    files = sorted(p for p in root.rglob("*") if p.is_file() and p.suffix.lower() in EXTS and not any(part.startswith(".") for part in p.relative_to(root).parts))
    out, fresh = [], 0
    for i, path in enumerate(files):
        prev = old.get(str(path))
        try:
            st = path.stat()
            if prev and not force and prev.get("size") == st.st_size and prev.get("mtime") == int(st.st_mtime) and Path(prev.get("thumb", "")).exists():
                out.append(prev)
            else:
                out.append(entry_for(path, root, thumbs))
                fresh += 1
                if fresh % 40 == 0:
                    write_atomic(index_path, {"root": str(root), "wallpapers": out + [e for p, e in old.items() if p not in {o["path"] for o in out}]})
        except Exception as e:  # a broken file shouldn't stop the rest
            print(json.dumps({"error": str(path), "why": str(e)[:200]}), flush=True)
        if fresh and (i % 5 == 0 or i == len(files) - 1):
            print(json.dumps({"done": i + 1, "total": len(files), "new": fresh}), flush=True)

    write_atomic(index_path, {"root": str(root), "wallpapers": out})
    print(json.dumps({"done": len(files), "total": len(files), "new": fresh, "finished": True}), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
