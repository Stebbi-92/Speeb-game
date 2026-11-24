"""Makes Brelm's blood textures (our own, CC0): splatter decals, a droplet and a mist puff.

Run: python3 tools/make_blood.py
Splats are drawn for a blow travelling up the picture (+Y in the image = the way the blood flew): a wet
pool with a darker rim, then droplets and streaks thrown forward, longer and thinner the further they went.
Colour is left white-ish with dark variation in the alpha-weighted value, so the game tints it per kind.
"""
import os, numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures", "blood")
os.makedirs(OUT, exist_ok=True)
N = 512


def noise(rng, n, scale):
	small = rng.random((n // scale + 2, n // scale + 2))
	im = Image.fromarray((small * 255).astype(np.uint8)).resize((n + scale * 2, n + scale * 2), Image.BICUBIC)
	return np.asarray(im, np.float32)[:n, :n] / 255.0


def splat(seed):
	rng = np.random.default_rng(seed)
	yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
	a = np.zeros((N, N), np.float32)
	cx, cy = N * 0.5, N * 0.62   # the pool sits back from the middle; the throw runs toward the top
	# The pool: a lumpy blob, its edge broken by noise
	n1 = noise(rng, N, 24) * 0.6 + noise(rng, N, 8) * 0.4
	r0 = N * rng.uniform(0.09, 0.13)
	d = np.hypot((xx - cx) / 1.0, (yy - cy) / 1.25)
	a = np.maximum(a, np.clip((r0 * (0.75 + 0.5 * n1) - d) / 3.0, 0, 1))
	# Lobes round the pool
	for _ in range(rng.integers(5, 9)):
		ang = rng.uniform(0, 2 * np.pi)
		rr = r0 * rng.uniform(0.6, 1.2)
		px, py = cx + np.cos(ang) * rr, cy + np.sin(ang) * rr * 1.2
		rad = r0 * rng.uniform(0.25, 0.5)
		a = np.maximum(a, np.clip((rad - np.hypot(xx - px, yy - py)) / 2.5, 0, 1))
	# Thrown drops: mostly forward (up the picture), elongated along their flight, smaller further out
	for _ in range(rng.integers(70, 110)):
		ang = -np.pi / 2 + rng.normal(0, 0.55)
		dist = r0 + rng.exponential(N * 0.16)
		px, py = cx + np.cos(ang) * dist, cy + np.sin(ang) * dist
		if not (8 < px < N - 8 and 8 < py < N - 8):
			continue
		size = max(1.2, N * 0.02 * np.exp(-dist / (N * 0.25)) * rng.uniform(0.4, 1.3))
		stretch = 1.0 + dist / (N * 0.12) * rng.uniform(0.3, 1.0)
		ux, uy = np.cos(ang), np.sin(ang)
		lx, ly = xx - px, yy - py
		along = lx * ux + ly * uy
		across = -lx * uy + ly * ux
		e = np.hypot(along / (size * stretch), across / size)
		a = np.maximum(a, np.clip((1.0 - e) * size / 1.5, 0, 1))
		# A fine tail back toward where it came from
		if stretch > 2.2 and rng.random() < 0.6:
			t = np.clip(-along / (size * stretch * 2.5), 0, 1)
			tail = np.clip((size * 0.35 * (1 - t) - np.abs(across)) / 0.8, 0, 1) * (along < 0) * (along > -size * stretch * 2.5)
			a = np.maximum(a, tail)
	# A fine mist of specks
	for _ in range(rng.integers(150, 260)):
		ang = -np.pi / 2 + rng.normal(0, 0.9)
		dist = rng.uniform(r0, N * 0.48)
		px, py = cx + np.cos(ang) * dist, cy + np.sin(ang) * dist
		if not (3 < px < N - 3 and 3 < py < N - 3):
			continue
		s = rng.uniform(0.7, 1.8)
		a = np.maximum(a, np.clip((s - np.hypot(xx - px, yy - py)) / 0.8, 0, 1) * rng.uniform(0.5, 1))
	# Value: thick blood is darker; edges and thin spray lighter. Slight mottling.
	blur = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6)), np.float32) / 255
	v = 1.0 - 0.45 * blur + (noise(rng, N, 6) - 0.5) * 0.15
	rim = np.clip(a - blur, 0, 1)
	v = np.clip(v - rim * 0.25, 0.35, 1.0)
	rgba = np.dstack([v, v, v, a * 0.97])
	Image.fromarray((rgba * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "splat_%d.png" % seed))


def drop():
	n = 64
	yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
	d = np.hypot((xx - 31.5) / 1.0, (yy - 31.5) / 1.0) / 30.0
	a = np.clip((1.0 - d) * 4.0, 0, 1)
	v = np.clip(0.55 + 0.45 * (1 - np.hypot(xx - 26, yy - 26) / 22), 0.5, 1.0)   # a small highlight, it is wet
	Image.fromarray((np.dstack([v, v, v, a]) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "drop.png"))


def mist():
	rng = np.random.default_rng(7)
	n = 128
	yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
	d = np.hypot(xx - 63.5, yy - 63.5) / 63.0
	a = np.clip(1.0 - d, 0, 1) ** 1.6 * (0.55 + 0.45 * noise(rng, n, 10))
	Image.fromarray((np.dstack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a * 0.8]) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "mist.png"))


for s in range(1, 5):
	splat(s)
drop()
mist()
print("done")
