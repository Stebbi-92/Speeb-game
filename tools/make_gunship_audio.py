"""Makes the Gunship's sounds: its rotor loop, its cannon, its missile's launch and its blast.

Run: python3 tools/make_gunship_audio.py <cut takes> [out folder]
  <cut takes>  a folder holding mg_1.ogg and mg_2.ogg as tools/cut_gunshots.py cuts them from the
               Free Firearm Sound Library (CC0); the cannon's crack is built on them
Writes assets/audio/rotor_gunship.wav (a seamless 5 s loop), gunship_cannon_[1-3].ogg,
gunship_missile_[1-2].ogg and gunship_blast_[1-3].ogg.

The rotor is a big attack helicopter's: four blades slapping 4.8 times a second, the low body of
the air they throw down, the wash, the tail rotor's buzz and the turbines' whine. Every part repeats
exactly in 5 s (noise is filtered round the loop, tones and beats are whole numbers of cycles in it),
so the loop has no seam. The cannon is a 30 mm chain gun: two heavy rounds a tenth of a second
apart in each take, a sub boom, a crack and a long outdoor roll. The missile is an ignition pop and
a motor's roar going away; the blast a crack, a deep thump, debris and a rumble that rolls on.
"""
import os, subprocess, sys
import numpy as np

SR = 44100
SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


def load(path):
	raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "2", "-ar", str(SR), "-f", "f32le", "-"],
		capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).astype(np.float64).reshape(-1, 2).T.copy()


def save(x, name, wav=False):
	path = os.path.join(OUT, name + (".wav" if wav else ".ogg"))
	pcm = np.ascontiguousarray(x.T.astype(np.float32))
	codec = ["-c:a", "pcm_s16le"] if wav else ["-c:a", "libvorbis", "-q:a", "6"]
	subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-"] + codec + [path],
		input=pcm.tobytes(), check=True)
	print("wrote", os.path.basename(path))


def band(x, lo=None, hi=None, order=2):
	"""A Butterworth-shaped band, applied round the buffer (so a loop stays a loop)."""
	n = x.shape[-1]
	f = np.fft.rfftfreq(n, 1 / SR)
	g = np.ones_like(f)
	if lo:
		g *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
	if hi:
		g *= 1 / np.sqrt(1 + (f / hi) ** (2 * order))
	return np.fft.irfft(np.fft.rfft(x, axis=-1) * g, n, axis=-1)


def pad_band(x, lo=None, hi=None, order=2):
	"""The same for a one-shot: padded first, so nothing wraps from its end round to its start."""
	n = x.shape[-1]
	y = band(np.concatenate([x, np.zeros(x.shape[:-1] + (n,))], -1), lo, hi, order)
	return y[..., :n]


def env(n, attack, decay):
	t = np.arange(n) / SR
	return (1 - np.exp(-t / max(attack, 1e-5))) * np.exp(-t / decay)


def resample(x, ratio):
	n = int(x.shape[-1] / ratio)
	t = np.arange(n) * ratio
	return np.vstack([np.interp(t, np.arange(x.shape[-1]), ch) for ch in np.atleast_2d(x)])


def place(dst, src, at, wrap=False):
	i = int(at * SR)
	src = np.atleast_2d(src)
	if src.shape[0] == 1:
		src = np.vstack([src, src])
	if wrap:
		idx = (i + np.arange(src.shape[-1])) % dst.shape[-1]
		np.add.at(dst[0], idx, src[0])
		np.add.at(dst[1], idx, src[1])
		return
	m = min(dst.shape[-1] - i, src.shape[-1])
	if m > 0:
		dst[:, i:i + m] += src[:, :m]


def thump(length, f_hi, f_lo, sweep, decay, drive):
	n = int(length * SR)
	t = np.arange(n) / SR
	f = f_lo + (f_hi - f_lo) * np.exp(-t / sweep)
	s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.002, decay)
	return np.tanh(drive * s) / np.tanh(drive)


def limit(x, ceiling_db=-1.6, release=0.06):
	c = 10 ** (ceiling_db / 20)
	need = np.minimum(1.0, c / np.maximum(np.abs(x).max(axis=0), 1e-9))
	la = int(0.0015 * SR)
	ahead = np.min(np.lib.stride_tricks.sliding_window_view(np.r_[need, np.ones(la)], la + 1), axis=1)[:len(need)]
	g = np.empty_like(ahead)
	r = np.exp(-1 / (release * SR))
	cur = 1.0
	for n, v in enumerate(ahead):
		cur = v if v < cur else v + (cur - v) * r
		g[n] = cur
	return np.clip(x * g, -c, c)


def level(x):
	"""The loudest 300 ms, roughly K-weighted (dB)."""
	m = pad_band(x.mean(axis=0), 60, None, 2)
	f = np.fft.rfftfreq(len(m), 1 / SR)
	m = np.fft.irfft(np.fft.rfft(m) * (1 + (10 ** (4 / 20) - 1) / (1 + (1500 / np.maximum(f, 1e-3)) ** 2)), len(m))
	w = int(0.3 * SR)
	c = np.cumsum(np.r_[0, m ** 2])
	return 10 * np.log10(max(((c[w:] - c[:-w]) / w).max(), 1e-12)) - 0.7


def to_level(x, target, ceiling=-2.2):
	for _ in range(3):
		x = limit(x * 10 ** ((target - level(x)) / 20), ceiling)
	return x


def outdoor(rng, x, t60, echoes, bright):
	"""An outdoor tail: a few slaps off the land, then a diffuse roll, darker as it goes."""
	n = int(t60 * 1.2 * SR)
	t = np.arange(n) / SR
	ir = np.zeros((2, n))
	for at, g in echoes:
		for k in (0, 1):
			i = int((at + rng.uniform(-0.008, 0.008)) * SR)
			if i < n:
				ir[k, i] += g * rng.uniform(0.7, 1.0)
	d = rng.standard_normal((2, n)) * np.exp(-6.9 * t / t60) * (1 - np.exp(-t / 0.05))
	d[:, :int(0.03 * SR)] = 0
	k = np.clip(t / (t60 * 0.5), 0, 1)
	ir += 0.03 * (pad_band(d, 100, bright) * (1 - k) + pad_band(d, 60, bright * 0.3) * k)
	m = x.shape[-1] + n
	y = np.fft.irfft(np.fft.rfft(pad_band(x, 60, 3500), m, axis=-1) * np.fft.rfft(ir, m, axis=-1), m, axis=-1)
	return y / max(np.abs(y).max(), 1e-9)


# ---------------------------------------------------------------- the rotor, a seamless loop
L = 5.0
N = int(L * SR)
BEAT = 24 / L            # 4.8 blade slaps a second
rng = np.random.default_rng(1)
t = np.arange(N) / SR
rot = np.zeros((2, N))
# the blade slap: each blade's pass a sharp, low-mid crack of air, the blades not quite alike
for i in range(24):
	at = i / BEAT + rng.uniform(-0.002, 0.002)
	g = (1.0, 0.86, 0.95, 0.8)[i % 4] * rng.uniform(0.94, 1.06)
	m = int(0.16 * SR)
	burst = pad_band(rng.standard_normal((2, m)) * env(m, 0.0025, 0.03), 140, 1300)
	whump = thump(0.16, 70, 48, 0.02, 0.05, 1.3)
	place(rot, g * (1.5 * burst / np.abs(burst).max() + 0.6 * whump), at, wrap=True)
# the low body, the downwash, beating with the blades (the beat a little after each slap)
beat = 0.55 + 0.45 * (0.5 + 0.5 * np.cos(2 * np.pi * BEAT * (t - 0.02))) ** 2
body = band(rng.standard_normal((2, N)), 30, 160, 3)
rot += 0.4 * body / np.abs(body).max() * beat
wash = band(rng.standard_normal((2, N)), 300, 4500)
rot += 0.22 * wash / np.abs(wash).max() * (0.8 + 0.2 * beat)
# the tail rotor's buzz, 90 times a second, and its tone
tail_beat = (0.5 + 0.5 * np.cos(2 * np.pi * 90.0 * t)) ** 6
tail = band(rng.standard_normal((2, N)), 900, 3500)
rot += 0.12 * tail / np.abs(tail).max() * tail_beat
rot += 0.035 * np.sin(2 * np.pi * 90.0 * t) + 0.02 * np.sin(2 * np.pi * 180.0 * t + 0.4)
# the turbines' whine and the gearbox, a slow waver whole in the loop
for f, a in ((1652.0, 0.03), (3304.0, 0.016), (6190.0, 0.007), (412.0, 0.014)):
	for ch, off in ((0, 0.0), (1, 0.7)):
		rot[ch] += a * np.sin(2 * np.pi * f * t + 3 * np.sin(2 * np.pi * (2 / L) * t) + off)
rot *= 10 ** ((-17.0 - level(np.concatenate([rot, rot], 1))) / 20)
pk = np.abs(rot).max()
if pk > 10 ** (-3 / 20):
	rot *= 10 ** (-3 / 20) / pk   # a loop cannot be limited across its seam without care: just kept under -3 dB
save(rot, "rotor_gunship", wav=True)

# ---------------------------------------------------------------- the cannon: two 30 mm rounds a take
mg = [load(os.path.join(SRC, "mg_%d.ogg" % i)) for i in (1, 2)]
for v in range(1, 4):
	rng = np.random.default_rng(10 + v)
	n = int(1.5 * SR)
	out = np.zeros((2, n))
	for k, at in enumerate((0.0, 0.105 + rng.uniform(-0.004, 0.004))):
		j = rng.uniform(0.95, 1.05)
		rd = np.zeros((2, n))
		place(rd, 0.7 * resample(mg[(v + k) % 2], 0.62 * j), 0.0)        # the recorded crack, deepened
		place(rd, 0.32 * thump(0.5, 95 * j, 45 * j, 0.025, 0.08, 1.6), 0.0)   # the round's sub boom
		m = int(0.2 * SR)
		place(rd, 0.5 * pad_band(rng.standard_normal((2, m)) * env(m, 0.0008, 0.05), 180, 900) * 2.0, 0.0)   # the body
		m = int(0.02 * SR)
		place(rd, 0.6 * pad_band(rng.standard_normal((2, m)) * env(m, 0.0002, 0.0025), 1500, None), 0.0)   # the crack
		place(out, rd[:, :n - int(at * SR)] * (1.0 if k == 0 else 0.93), at)
	out += 0.4 * np.abs(out).max() * outdoor(rng, out, 1.1, [(0.09, 0.5), (0.2, 0.35), (0.34, 0.22)], 1800)[:, :n]
	out = to_level(out, -14.0)
	out[:, -int(0.4 * SR):] *= np.cos(np.linspace(0, np.pi / 2, int(0.4 * SR))) ** 2
	save(out, "gunship_cannon_%d" % v)

# ---------------------------------------------------------------- the missile: ignition and its motor going away
for v in range(1, 3):
	rng = np.random.default_rng(30 + v)
	n = int(2.2 * SR)
	t = np.arange(n) / SR
	out = np.zeros((2, n))
	place(out, 0.7 * thump(0.4, 120, 55, 0.02, 0.06, 1.5), 0.0)                      # the pop off the rail
	m = int(0.03 * SR)
	place(out, 0.8 * pad_band(rng.standard_normal((2, m)) * env(m, 0.0003, 0.004), 1200, None), 0.0)
	# the motor: a rough roar, fluttering, darker and fainter as it goes
	roar = rng.standard_normal((2, n))
	flutter = 1 + 0.25 * band(rng.standard_normal(n), None, 30)[None, :] / 0.05
	shape = (1 - np.exp(-t / 0.04)) * np.exp(-t / 0.9)
	bright = pad_band(roar, 500, 5000) * np.exp(-t / 0.45)
	dark = pad_band(roar, 120, 1400)
	motor = (0.6 * bright / np.abs(bright).max() + 0.8 * dark / np.abs(dark).max()) * shape * np.clip(flutter, 0.5, 1.6)
	out += motor
	# its whoosh: a band swept down as it leaves
	whoosh = np.zeros((2, n))
	for i, f in enumerate(np.geomspace(2600, 500, 12)):
		seg = int(n / 12)
		s = pad_band(rng.standard_normal((2, seg * 2)), f * 0.6, f * 1.6)[:, :seg * 2] * np.hanning(seg * 2)
		place(whoosh, s, i * seg / SR * 0.9)
	out += 0.35 * whoosh / max(np.abs(whoosh).max(), 1e-9) * np.exp(-t / 1.2)
	out += 0.25 * np.abs(out).max() * outdoor(rng, out, 1.3, [(0.12, 0.4), (0.3, 0.25)], 2000)[:, :n]
	out = to_level(out, -13.0)
	out[:, -int(0.5 * SR):] *= np.cos(np.linspace(0, np.pi / 2, int(0.5 * SR))) ** 2
	save(out, "gunship_missile_%d" % v)

# ---------------------------------------------------------------- the blast where it lands
for v in range(1, 4):
	rng = np.random.default_rng(50 + v)
	n = int(4.5 * SR)
	t = np.arange(n) / SR
	j = rng.uniform(0.94, 1.06)
	out = np.zeros((2, n))
	m = int(0.03 * SR)
	place(out, 1.0 * pad_band(rng.standard_normal((2, m)) * env(m, 0.0002, 0.003), 1000, None), 0.0)   # the crack
	place(out, 1.0 * thump(1.2, 90 * j, 36 * j, 0.04, 0.3, 2.2), 0.0)                                   # the deep thump
	m = int(1.2 * SR)
	fire = pad_band(rng.standard_normal((2, m)), 60, 1500) * env(m, 0.002, 0.18)
	place(out, 0.9 * fire / np.abs(fire).max(), 0.0)                                                    # the body of it
	# debris: grit and stones falling back, thinning out
	deb = np.zeros((2, n))
	for _ in range(160):
		at = rng.exponential(0.45) + 0.08
		if at < 3.0:
			m = int(0.012 * SR)
			c = pad_band(rng.standard_normal((2, m)) * env(m, 0.0003, 0.002), 800, 6000)
			place(deb, c * rng.uniform(0.2, 1.0) * np.exp(-at / 0.8), at)
	out += 0.25 * deb / np.abs(deb).max()
	rum = pad_band(rng.standard_normal((2, n)), 25, 220, 3) * (1 - np.exp(-t / 0.06)) * np.exp(-t / 1.1)
	out += 0.6 * rum / np.abs(rum).max()
	out += 0.4 * np.abs(out).max() * outdoor(rng, out, 2.4, [(0.15, 0.5), (0.36, 0.35), (0.62, 0.25), (0.95, 0.15)], 1500)[:, :n]
	out = to_level(out, -10.0)
	out[:, -int(1.0 * SR):] *= np.cos(np.linspace(0, np.pi / 2, int(1.0 * SR))) ** 2
	save(out, "gunship_blast_%d" % v)
