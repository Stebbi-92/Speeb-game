"""Makes the skins of the waste's new foes from Kenney's CC0 character textures.

The Unlit (raiders) are recoloured from the blocky characters: ash-dark cloth, a rust or ochre sash,
and a Speeb face (one of the game's own emoji) worn as a mask, in mockery of Speeb. The graveyard characters become
the Hollowed (ash-grey skin, ember eyes), the Salt-Bones (salt white) and the Lost Vigil (pale gold).
Run: python3 tools/retexture.py
"""
import colorsys, os
from PIL import Image, ImageDraw

HERE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "models", "foes")
TEX = os.path.join(HERE, "Textures")
OUT = os.path.join(HERE, "skins")
EMOJI = os.path.join(HERE, "..", "..", "emoji")
os.makedirs(OUT, exist_ok=True)


def lum(c):
	return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0


def ramp(t, stops):
	"""A colour along a list of stops, by 0..1."""
	t = max(0.0, min(1.0, t)) * (len(stops) - 1)
	i = min(int(t), len(stops) - 2)
	f = t - i
	a, b = stops[i], stops[i + 1]
	return tuple(int(a[k] + (b[k] - a[k]) * f) for k in range(3))


def unlit(base, accent, name, emoji):
	im = Image.open(os.path.join(TEX, base)).convert("RGBA")
	px = im.load()
	w, h = im.size
	s = w / 1024.0
	cloth = [(22, 20, 22), (52, 46, 44), (92, 84, 76), (140, 128, 112)]
	for y in range(h):
		for x in range(w):
			r, g, b, a = px[x, y]
			hh, ll, ss = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
			skin = 0.02 < hh < 0.12 and ss > 0.35 and ll > 0.45
			if skin:
				c = ramp(ll, [(60, 54, 50), (128, 116, 104), (170, 158, 142)])   # ash-dusted skin
			elif ss > 0.45 and ll > 0.25 and (hh < 0.05 or hh > 0.9):
				c = accent   # what was red becomes the sash colour
			else:
				c = ramp(lum((r, g, b)), cloth)
			px[x, y] = c + (a,)
	# The head: a dark hood all round, and on the front a bone-white cat mask
	d = ImageDraw.Draw(im)
	hood = (34, 30, 32, 255)
	for box in [(128, 0, 256, 128), (0, 128, 128, 256), (256, 128, 384, 256), (384, 128, 512, 256), (128, 256, 256, 384)]:
		d.rectangle([int(v * s) for v in box], fill=hood)
	# On the front, a Speeb face worn as a mask: one of Steve's own emoji, over the hood
	face = Image.open(os.path.join(EMOJI, emoji + ".png")).convert("RGBA").resize((int(128 * s), int(128 * s)), Image.LANCZOS)
	im.alpha_composite(face, (int(128 * s), int(128 * s)))
	im.save(os.path.join(OUT, name))
	print(name)


def tint(name, fn):
	im = Image.open(os.path.join(TEX, "colormap.png")).convert("RGBA")
	px = im.load()
	for y in range(im.size[1]):
		for x in range(im.size[0]):
			r, g, b, a = px[x, y]
			hh, ll, ss = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
			px[x, y] = fn(hh, ll, ss) + (a,)
	im.save(os.path.join(OUT, name))
	print(name)


def hollow(hh, ll, ss):
	if 0.11 < hh < 0.17 and ss > 0.5 and ll > 0.5:   # the eyes: embers
		return (255, 130, 40)
	return ramp(ll, [(26, 24, 24), (78, 74, 70), (130, 124, 116), (176, 170, 160)])


def saltbone(hh, ll, ss):
	return ramp(ll, [(70, 78, 90), (170, 176, 182), (232, 234, 232), (252, 250, 244)])


def vigil(hh, ll, ss):
	return ramp(ll, [(120, 90, 40), (220, 180, 90), (250, 228, 160), (255, 246, 214)])


def warden(hh, ll, ss):
	if 0.11 < hh < 0.17 and ss > 0.5 and ll > 0.5:   # eyes, if any: embers
		return (255, 130, 40)
	if ss > 0.45 and (hh < 0.04 or hh > 0.93):   # what was red: dried blood
		return ramp(ll, [(40, 10, 8), (90, 22, 16)])
	return ramp(ll, [(18, 16, 16), (46, 42, 40), (92, 86, 80), (150, 144, 134)])


unlit("texture-a.png", (150, 52, 30), "unlit_rust.png", "emberspeeb")
unlit("texture-k.png", (190, 140, 40), "unlit_ochre.png", "wrathspeeb")
unlit("texture-m.png", (200, 196, 180), "unlit_bone.png", "negaspeeb")
tint("hollow.png", hollow)
tint("saltbone.png", saltbone)
tint("vigil.png", vigil)
tint("warden.png", warden)
