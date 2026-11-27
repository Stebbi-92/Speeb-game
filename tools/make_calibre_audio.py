"""Gives each gun's shot the weight of its calibre: a heavier round, a deeper thump and a longer roll.

Run: python3 tools/make_calibre_audio.py <cut takes> [out folder]
  <cut takes>  a folder holding the plain takes tools/cut_gunshots.py cuts from the Free Firearm Sound
               Library (CC0): smg_*, revolver_*, rifle_*, mg_*, minigun_*, sniper_* .ogg
Writes those takes again into assets/audio, layered: the recording, a sub thump pitched and timed by
the round (a 9 mm's short and high, a 7.62's deep and long), a crack, and an outdoor tail. Each is
levelled to its calibre's place in the game's mix (CALIBRE in scripts/weapon.gd), as heard through
the Guns bus limiter, so a heavier round sounds louder without its peak going over -1.6 dBFS.
The pistols and shotguns keep their files: their loudness is set by their shot_db alone.
"""
import glob, os, subprocess, sys
import numpy as np

SR = 44100
SRC = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")


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



def loudness(x, gain_db):
	"""As heard: played gain_db hot into the Guns bus limiter (-0.5 dB, 60 ms); the mean of the
	loudest 100 ms (the crack) and the loudest 300 ms (the boom and its roll), roughly K-weighted."""
	g = 10 ** (gain_db / 20)
	m = fft_filter(x.mean(axis=0), 60, None, 2)
	f = np.fft.rfftfreq(len(m), 1 / SR)
	m = np.fft.irfft(np.fft.rfft(m) * (1 + (10 ** (4 / 20) - 1) / (1 + (1500 / np.maximum(f, 1e-3)) ** 2)), len(m))
	need = np.minimum(1.0, 10 ** (-0.5 / 20) / np.maximum(np.abs(x).max(axis=0) * g, 1e-9))
	r = np.exp(-1 / (0.06 * SR))
	cur = 1.0
	e = np.empty(len(m) + int(0.3 * SR))
	e[len(m):] = 0
	for n, v in enumerate(need):
		cur = v if v < cur else v + (cur - v) * r
		e[n] = (m[n] * g * cur) ** 2
	c = np.cumsum(np.r_[0, e])
	out = []
	for win in (0.1, 0.3):
		w = int(win * SR)
		out.append(10 * np.log10(max(((c[w:] - c[:-w]) / w).max(), 1e-12)) - 0.7)
	return (out[0] + out[1]) / 2


# sound: (thump hi, lo, decay, gain; crack gain; tail t60, gain; length s; target loudness; played at dB)
# The automatics keep a short roll, or a burst piles its tails into one long roar; their targets also
# sit 1 dB (the minigun 2 dB) under their calibre's, so a held burst does not bury the rest.
# The targets are the calibre table's (see SHOTGUN_REPORT / scripts/weapon.gd CALIBRE), heard at GUN_DB 9.
KITS = {
	"smg":      dict(th=(150, 85, 0.045, 0.14), crack=0.5, t60=0.6, tail=0.2, length=0.75, target=-22.9),
	"revolver": dict(th=(125, 60, 0.08, 0.2), crack=0.7, t60=1.3, tail=0.6, length=1.4, target=-19.4),
	"rifle":    dict(th=(115, 58, 0.07, 0.22), crack=0.9, t60=1.0, tail=0.3, length=1.1, target=-19.9),
	"mg":       dict(th=(105, 52, 0.085, 0.26), crack=0.8, t60=1.0, tail=0.3, length=1.1, target=-19.3),
	"minigun":  dict(th=(105, 55, 0.05, 0.18), crack=0.6, t60=0.4, tail=0.12, length=0.45, target=-20.3),
	"sniper":   dict(th=(100, 45, 0.12, 0.26), crack=1.0, t60=2.0, tail=0.8, length=2.4, target=-17.7),
}

for gun, kit in KITS.items():
	takes = sorted(glob.glob(os.path.join(SRC, gun + "_[0-9].ogg")))
	for i, path in enumerate(takes, 1):
		rng = np.random.default_rng(sum(map(ord, gun)) * 10 + i)
		n = int(kit["length"] * SR)
		rec = fit(load(path), n)
		t = np.arange(n) / SR
		jit = rng.uniform(0.95, 1.05)
		out = rec * (1 + 0.4 * np.exp(-t / 0.02))
		hi, lo, decay, g = kit["th"]
		out += fit(g * thump(decay * 6, hi * jit, lo * jit, 0.025, decay, 1.6), n)
		cn = int(0.01 * SR)
		out += fit(kit["crack"] * biquad(rng.standard_normal(cn) * env(cn, 0.0002, 0.0015), "hp", 2200), n)
		ir = tail_ir(rng, kit["length"], kit["t60"], [(0.07, 0.45), (0.15, 0.32), (0.26, 0.22), (0.4, 0.14)], 2400)
		wet = conv(fft_filter(out, 80, 3500), ir)[:, :n]
		out += kit["tail"] * wet / max(np.abs(wet).max(), 1e-6) * 0.5
		for _ in range(5):
			out = limit(out * 10 ** ((kit["target"] - loudness(out, 9.0)) / 20))
		out = fade_out(out, min(0.3, kit["length"] * 0.4))
		save(out, "%s_%d" % (gun, i))
