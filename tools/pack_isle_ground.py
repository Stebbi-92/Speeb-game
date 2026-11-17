#!/usr/bin/env python3
"""Packs an isle's own ground grain and relief into the six maps the ground shader reads.

The waste's own maps (assets/textures/ground) hold one land per channel. An isle uses only some of
them (its shore, its base land and slope rock), so this copies the waste's maps at 1024 and puts the
isle's photographed ground (Poly Haven, CC0) into those channels.

Usage: python3 tools/pack_isle_ground.py THEME SRC_DIR channel=texture_id [...]
  channels: ash dunes salt forest basalt marsh rock road
  SRC_DIR holds 8-bit <id>_diff.png and <id>_nor_gl.png at 1024.
"""
import sys, os
import numpy as np
from PIL import Image

LANDS = ["ash", "dunes", "salt", "forest", "basalt", "marsh", "rock", "road"]
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "ground")
SIZE = 1024


def load(name):
    im = Image.open(os.path.join(ROOT, name + ".png")).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
    return np.asarray(im).astype(np.float32) / 255.0


def grain(path):
    a = np.asarray(Image.open(path).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)).astype(np.float32) / 255.0
    lum = a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114
    g = 0.5 + (lum - lum.mean()) / max(lum.std(), 1e-4) * 0.159
    return np.clip(g, 0.0, 1.0)


def relief(path):
    a = np.asarray(Image.open(path).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)).astype(np.float32) / 255.0
    return a[..., 0], a[..., 1]


def main():
    theme, src = sys.argv[1], sys.argv[2]
    pairs = dict(arg.split("=", 1) for arg in sys.argv[3:])
    maps = {k: load(k) for k in ["ground_a", "ground_b", "ground_n1", "ground_n2", "ground_n3", "ground_n4"]}
    changed = set()
    for land, tex in pairs.items():
        i = LANDS.index(land)
        changed.update(["ground_a" if i < 4 else "ground_b", "ground_n%d" % (i // 2 + 1)])
        maps["ground_a" if i < 4 else "ground_b"][..., i % 4] = grain(os.path.join(src, tex + "_diff.png"))
        nx, ny = relief(os.path.join(src, tex + "_nor_gl.png"))
        n = maps["ground_n%d" % (i // 2 + 1)]
        c = (i % 2) * 2
        n[..., c] = nx
        n[..., c + 1] = ny
    out = os.path.join(ROOT, "isles", theme)
    os.makedirs(out, exist_ok=True)
    for k, v in maps.items():
        if k not in changed:
            continue   # the game uses the waste's own map for a channel set the isle does not change
        Image.fromarray((np.clip(v, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(out, k + ".png"), optimize=True)
    print("packed", theme, "->", out)


if __name__ == "__main__":
    main()
