"""Makes the shotguns' heavier shots and the pump's rack, layered onto the CC0 recordings.

Run: python3 tools/make_shotgun_audio.py <cut takes> <Kenney audio> [out folder]
  <cut takes>     a folder holding the plain takes tools/cut_gunshots.py cuts from the Free Firearm Sound
                  Library (CC0): shotgun_1/2, shotgun_far_1/2, autoshotgun_1/2, autoshotgun_far_1/2 .ogg
  <Kenney audio>  a folder holding metalLatch.ogg, metalClick.ogg (Kenney RPG Audio, CC0) and
                  impactMetal_*.ogg (Kenney Impact Sounds, CC0)
Writes assets/audio/shotgun_[1-3].ogg, shotgun_far_[1-3].ogg, autoshotgun_[1-3].ogg,
autoshotgun_far_[1-3].ogg and pump_rack_[1-3].ogg.

Each close shot is the recording with, laid under it: a sub thump (a sine falling from about 115 to
48 Hz), a chest punch around 150 Hz, a sharp crack at the front, a short mechanical body (the
receiver's ring), and an outdoor tail (a few slap echoes off far ground, then a long diffuse roll).
The autoshotgun has the same parts, tighter: higher, shorter thump and a shorter tail. The far takes
get a longer roll and a low rumble, with no crack. Peaks are held under -1 dBFS.
"""
import os, subprocess, sys
import numpy as np

SR = 44100
SRC, KEN = sys.argv[1], sys.argv[2]
OUT = sys.argv[3] if len(sys.argv) > 3 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


def load(path, ch=2):
	raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", str(ch), "-ar", str(SR), "-f", "f32le", "-"],
		capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).astype(np.float64).reshape(-1, ch).T.copy()


def save(x, name):
	path = os.path.join(OUT, name + ".ogg")
	pcm = np.ascontiguousarray(x.T.astype(np.float32))
	subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[0]), "-i", "-",
		"-c:a", "libvorbis", "-q:a", "6", path], input=pcm.tobytes(), check=True)
	print("wrote", name)


def biquad(x, kind, f, q=0.707):
	"""An RBJ biquad (lowpass, highpass or bandpass) over each channel."""
	w = 2 * np.pi * f / SR
	a = np.sin(w) / (2 * q)
	c = np.cos(w)
	if kind == "lp":
		b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
	elif kind == "hp":
		b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
	else:
		b = [a, 0, -a]
	a0, a1, a2 = 1 + a, -2 * c, 1 - a
	b = [v / a0 for v in b]
	a1 /= a0
	a2 /= a0
	x = np.atleast_2d(x)
	y = np.zeros_like(x)
	for k in range(x.shape[0]):
		xs, ys = x[k], y[k]
		x1 = x2 = y1 = y2 = 0.0
		for n in range(len(xs)):
			v = b[0] * xs[n] + b[1] * x1 + b[2] * x2 - a1 * y1 - a2 * y2
			x2, x1, y2, y1 = x1, xs[n], y1, v
			ys[n] = v
	return y


def fft_filter(x, lo=None, hi=None, order=2):
	"""Zero-phase Butterworth-shaped band, in the frequency domain (for long noise beds)."""
	n = x.shape[-1]
	f = np.fft.rfftfreq(n, 1 / SR)
	g = np.ones_like(f)
	if lo:
		g *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * order))
	if hi:
		g *= 1 / np.sqrt(1 + (f / hi) ** (2 * order))
	return np.fft.irfft(np.fft.rfft(x, axis=-1) * g, n, axis=-1)


def resample(x, ratio):
	"""Plays x faster by ratio (a pitch shift, as a tape would)."""
	n = int(x.shape[-1] / ratio)
	t = np.arange(n) * ratio
	return np.vstack([np.interp(t, np.arange(x.shape[-1]), ch) for ch in np.atleast_2d(x)])


def place(dst, src, at):
	i = int(at * SR)
	m = min(dst.shape[-1] - i, src.shape[-1])
	if m > 0:
		dst[:, i:i + m] += src[:, :m]


def fit(x, n):
	out = np.zeros((2, n))
	x = np.atleast_2d(x)
	if x.shape[0] == 1:
		x = np.vstack([x, x])
	out[:, :min(n, x.shape[-1])] = x[:, :n]
	return out


def limit(x, ceiling_db=-1.6, release=0.05):
	"""A look-ahead peak limiter (1.5 ms), then a hard guard at the ceiling."""
	c = 10 ** (ceiling_db / 20)
	pk = np.abs(x).max(axis=0)
	need = np.minimum(1.0, c / np.maximum(pk, 1e-9))
	la = int(0.0015 * SR)
	# the gain must be down before the peak arrives: a running minimum looking ahead
	padded = np.r_[need, np.ones(la)]
	ahead = np.min(np.lib.stride_tricks.sliding_window_view(padded, la + 1), axis=1)[:len(need)]
	g = np.empty_like(ahead)
	r = np.exp(-1 / (release * SR))
	cur = 1.0
	for n, v in enumerate(ahead):
		cur = v if v < cur else v + (cur - v) * r
		g[n] = cur
	return np.clip(x * g, -c, c)


def fade_out(x, length):
	n = int(length * SR)
	x[:, -n:] *= np.cos(np.linspace(0, np.pi / 2, n)) ** 2
	return x


def env(n, attack, decay):
	t = np.arange(n) / SR
	return (1 - np.exp(-t / max(attack, 1e-5))) * np.exp(-t / decay)


def thump(length, f_hi, f_lo, sweep, decay, drive):
	"""The sub: a sine falling in pitch, gently driven so small speakers hear its overtones."""
	n = int(length * SR)
	t = np.arange(n) / SR
	f = f_lo + (f_hi - f_lo) * np.exp(-t / sweep)
	s = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.0015, decay)
	return np.tanh(drive * s) / np.tanh(drive)


def tail_ir(rng, length, t60, echoes, bright):
	"""An outdoor tail: discrete slaps off far ground and trees, then a diffuse roll, darker as it goes."""
	n = int(length * SR)
	t = np.arange(n) / SR
	ir = np.zeros((2, n))
	for at, g in echoes:
		for k, pan in ((0, rng.uniform(0.7, 1.0)), (1, rng.uniform(0.7, 1.0))):
			i = int((at + rng.uniform(-0.006, 0.006)) * SR)
			if i < n:
				ir[k, i] += g * pan
	diffuse = rng.standard_normal((2, n)) * np.exp(-6.9 * t / t60) * (1 - np.exp(-t / 0.04))
	diffuse[:, :int(0.03 * SR)] = 0
	early = fft_filter(diffuse, 120, bright)
	late = fft_filter(diffuse, 80, bright * 0.3)
	mixk = np.clip(t / (t60 * 0.5), 0, 1)
	ir += 0.035 * (early * (1 - mixk) + late * mixk)
	return ir


def conv(x, ir):
	n = x.shape[-1] + ir.shape[-1]
	X = np.fft.rfft(np.atleast_2d(x), n, axis=-1)
	H = np.fft.rfft(ir, n, axis=-1)
	return np.fft.irfft(X * H, n, axis=-1)


KITS = {
	# name: (thump hi, lo, sweep, decay, gain; punch Hz, gain; tail t60, gain; length)
	"shotgun": dict(th=(118, 48, 0.035, 0.17, 0.14), punch=(150, 0.2), t60=1.7, tail=0.85, length=2.0,
		echoes=[(0.075, 0.5), (0.16, 0.38), (0.27, 0.3), (0.41, 0.2), (0.6, 0.12)], ring=0.16),
	"autoshotgun": dict(th=(130, 58, 0.025, 0.11, 0.11), punch=(170, 0.18), t60=1.15, tail=0.62, length=1.5,
		echoes=[(0.07, 0.42), (0.15, 0.3), (0.25, 0.2), (0.38, 0.12)], ring=0.2),
}
VARIANTS = [(1, 1.0, 11), (2, 1.0, 23), (1, 0.965, 37)]   # (recording take, playback ratio, seed)
# The loudest 300 ms as heard in the game (see in_game): the old cuts sat near -23, the other guns -22 to -26.5
TARGET = {"shotgun": -21.0, "autoshotgun": -21.5}
FAR_LIFT = 1.0   # dB over the old far take


def level(x):
	m = fft_filter(x.mean(axis=0), 60, None, 2)
	f = np.fft.rfftfreq(len(m), 1 / SR)
	shelf = 1 + (10 ** (4 / 20) - 1) / (1 + (1500 / np.maximum(f, 1e-3)) ** 2)
	m = np.fft.irfft(np.fft.rfft(m) * shelf, len(m))
	e = m ** 2
	w = int(0.3 * SR)
	c = np.cumsum(np.r_[0, e])
	return 10 * np.log10(max(((c[w:] - c[:-w]) / w).max(), 1e-12)) - 0.7


def in_game(x, gain_db=9.0):
	"""The level as heard: played GUN_DB hot into the Guns bus limiter (-0.5 dB ceiling, 60 ms release)."""
	g = 10 ** (gain_db / 20)
	m = fft_filter(x.mean(axis=0), 60, None, 2)
	f = np.fft.rfftfreq(len(m), 1 / SR)
	m = np.fft.irfft(np.fft.rfft(m) * (1 + (10 ** (4 / 20) - 1) / (1 + (1500 / np.maximum(f, 1e-3)) ** 2)), len(m))
	need = np.minimum(1.0, 10 ** (-0.5 / 20) / np.maximum(np.abs(x).max(axis=0) * g, 1e-9))
	r = np.exp(-1 / (0.06 * SR))
	cur = 1.0
	e = np.empty_like(m)
	for n, v in enumerate(need):
		cur = v if v < cur else v + (cur - v) * r
		e[n] = (m[n] * g * cur) ** 2
	w = int(0.3 * SR)
	c = np.cumsum(np.r_[0, e])
	return 10 * np.log10(max(((c[w:] - c[:-w]) / w).max(), 1e-12)) - 0.7


def to_level(x, target, gain_db=9.0):
	for _ in range(4):
		x = limit(x * 10 ** ((target - in_game(x, gain_db)) / 20))
	return x


metal = {k: load(os.path.join(KEN, k + ".ogg")) for k in ["metalLatch", "metalClick", "impactMetal_heavy_001",
	"impactMetal_medium_002", "impactMetal_light_003", "impactMetal_medium_000", "impactMetal_light_001"]}

for gun, kit in KITS.items():
	for v, (take, ratio, seed) in enumerate(VARIANTS, 1):
		rng = np.random.default_rng(seed + (0 if gun == "shotgun" else 100))
		n = int(kit["length"] * SR)
		rec = resample(load(os.path.join(SRC, "%s_%d.ogg" % (gun, take))), ratio)
		rec = fit(rec, n)
		jit = rng.uniform(0.94, 1.06)
		# 1. the recording itself, the gun's own voice and crack, its first 25 ms lifted so the crack leads
		t = np.arange(n) / SR
		out = rec * (1 + 0.6 * np.exp(-t / 0.025))
		# 2. the sub thump
		hi, lo, sweep, decay, g = kit["th"]
		out += fit(g * thump(decay * 6, hi * jit, lo * jit, sweep, decay, 1.8), n)
		# 3. the chest punch, low mids that a laptop can still play
		pf, pg = kit["punch"]
		punch = biquad(rng.standard_normal(int(0.25 * SR)) * env(int(0.25 * SR), 0.001, 0.045), "bp", pf * jit, 1.2)
		out += fit(pg * 6 * punch, n)
		# 4. the crack: a few milliseconds of bright noise right at the front
		cn = int(0.012 * SR)
		crack = biquad(rng.standard_normal(cn) * env(cn, 0.0002, 0.0018), "hp", 1800)
		out += fit(1.1 * crack, n)
		# 5. the mechanical body: the receiver and barrel ringing a moment
		ring = resample(metal["impactMetal_heavy_001"], 0.7 * jit)
		body = biquad(rng.standard_normal(int(0.15 * SR)) * env(int(0.15 * SR), 0.0008, 0.03), "bp", 900, 0.8)
		mech = np.zeros((2, n))
		place(mech, kit["ring"] * ring / max(np.abs(ring).max(), 1e-6), 0.004)
		place(mech, np.vstack([body, body]) * 0.35, 0.0)
		out += mech
		# 6. the outdoor tail: the shot, darkened, sent out over the waste and back
		ir = tail_ir(rng, kit["length"], kit["t60"], kit["echoes"], 2200)
		wet = conv(fft_filter(out, 70, 3000), ir)[:, :n]
		out += kit["tail"] * wet / max(np.abs(wet).max(), 1e-6) * 0.5
		# low roll under the tail
		rn = int(kit["t60"] * 0.7 * SR)
		roll = fft_filter(rng.standard_normal((2, rn)), 35, 140, 3) * env(rn, 0.03, kit["t60"] * 0.22)
		out += fit(0.08 * roll / max(np.abs(roll).max(), 1e-6), n)
		out = fade_out(to_level(out, TARGET[gun]), 0.35)
		save(out, "%s_%d" % (gun, v))

		# The far take: the recorded far shot, with a longer roll and the low rumble that carries
		fn = int(kit["length"] * 1.4 * SR)
		far = fit(resample(load(os.path.join(SRC, "%s_far_%d.ogg" % (gun, take))), ratio), fn)
		far = fft_filter(far, 40, 7000)
		ir = tail_ir(rng, kit["length"] * 1.4, kit["t60"] * 1.3, [(a * 1.6, g) for a, g in kit["echoes"]], 1400)
		wet = conv(far, ir)[:, :fn]
		far += 0.7 * wet / max(np.abs(wet).max(), 1e-6) * np.abs(far).max()
		boom = thump(0.9, 85 * jit, 55 * jit, 0.06, kit["th"][3] * 2.2, 1.4)
		bn = int(1.0 * SR)
		rumble = fft_filter(rng.standard_normal((2, bn)), 30, 120, 3) * env(bn, 0.05, 0.35)
		far += fit(0.18 * np.abs(far).max() * boom, fn) + fit(0.12 * np.abs(far).max() * rumble / np.abs(rumble).max(), fn)
		ref = load(os.path.join(SRC, "%s_far_%d.ogg" % (gun, take)))
		far = fade_out(to_level(far, in_game(ref) + FAR_LIFT), 0.5)
		save(far, "%s_far_%d" % (gun, v))

# The pump worked after a shot: the fore-end slammed back (its stop at 0.05 s), then home and locked (0.33 s).
# Played 0.3 s after the shot, so the clacks land as the pump on screen reaches the back and comes home.
for v, seed in enumerate([5, 6, 7], 1):
	rng = np.random.default_rng(seed)
	n = int(0.48 * SR)
	out = np.zeros((2, n))
	j = rng.uniform(0.95, 1.05)

	def hit(name, at, pitch, gain):
		s = resample(metal[name], pitch * j)
		place(out, gain * s / max(np.abs(s).max(), 1e-6), at)

	def slide(at, length, f, gain):
		m = int(length * SR)
		s = biquad(rng.standard_normal(m) * np.sin(np.linspace(0, np.pi, m)) ** 2, "bp", f * j, 1.5)
		place(out, gain * np.vstack([s, s]) / max(np.abs(s).max(), 1e-6), at)

	def knock(at, f, gain):
		m = int(0.05 * SR)
		s = np.sin(2 * np.pi * f * j * np.arange(m) / SR) * env(m, 0.0005, 0.012)
		place(out, gain * np.vstack([s, s]), at)

	slide(0.0, 0.06, 2400, 0.25)                 # back: the fore-end sliding
	hit("metalLatch", 0.035, 0.8, 0.55)
	hit("impactMetal_medium_002", 0.05, 0.75, 0.7)   # back: the stop
	knock(0.05, 190, 0.45)
	hit("impactMetal_light_001", 0.11, 1.2, 0.18)    # the case kicked out
	slide(0.26, 0.07, 2000, 0.22)                # forward
	hit("metalClick", 0.32, 0.85, 0.5)
	hit("impactMetal_medium_000", 0.33, 0.85, 0.85)  # home: the lock
	knock(0.33, 160, 0.55)
	out *= 10 ** ((-16.5 - level(out)) / 20)
	save(fade_out(limit(out, -1.6, 0.03), 0.06), "pump_rack_%d" % v)
