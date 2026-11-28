"""Suppressed shots that sound like the real thing, made from each gun's own shot (CC0 takes already in the game).

A suppressor does not make a gun go "pfft". It takes the deep boom out of the muzzle blast and cuts the whole
shot by some 20-30 dB, so what is left is a hard, flat slap with little low end and a short tail. What it
cannot take away is the rest: the action slamming back and forth (loud, close by, now that the blast is
gone), and, from a rifle, the bullet's own supersonic crack, as sharp as ever. Pistol and SMG rounds here
are taken as subsonic, so they have no crack.

Run: python3 tools/make_supp_audio.py [out folder]   (needs ffmpeg and numpy)
Writes into assets/audio: supp_pistol_N, supp_smg_N, supp_rifle_N, supp_shotgun_N (.ogg), each made from one
of that kind's takes. Their loudness in the game is set by SUPP_DB in scripts/weapon.gd.
"""
import glob, os, subprocess, sys
import numpy as np

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
AUDIO = os.path.join(HERE, "..", "assets", "audio")
OUT = sys.argv[1] if len(sys.argv) > 1 else AUDIO


def load(path, ch=2):
	raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", str(ch), "-ar", str(SR), "-f", "f32le", "-"],
		capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32).astype(np.float64).reshape(-1, ch).T.copy()


def save(x, name):
	path = os.path.join(OUT, name + ".ogg")
	pcm = np.ascontiguousarray(x.T.astype(np.float32))
	subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "f32le", "-ar", str(SR), "-ac", str(x.shape[0]), "-i", "-",
		"-c:a", "libvorbis", "-q:a", "6", path], input=pcm.tobytes(), check=True)
	print("wrote", path)


def shape(x, gain):
	"""Filters by a gain (linear) for each frequency in Hz, over the whole sound at once."""
	n = x.shape[1]
	f = np.fft.rfftfreq(n, 1.0 / SR)
	g = gain(f)
	return np.fft.irfft(np.fft.rfft(x, axis=1) * g, n=n, axis=1)


def shelf(f, at, below_db, above_db, width=1.0):
	"""A smooth step in gain from below_db to above_db around the frequency at (octaves wide)."""
	k = 1.0 / (1.0 + np.exp(-np.log2(np.maximum(f, 1.0) / at) * 4.0 / width))
	return 10 ** ((below_db + (above_db - below_db) * k) / 20.0)


def onset(x):
	"""Where the shot begins: the first sample within 20 dB of the loudest."""
	m = np.abs(x).max(axis=0)
	return int(np.argmax(m > m.max() * 0.1))


def env(n, attack_s, tau_s, tail=0.0, tail_tau=0.25):
	t = np.arange(n) / SR
	a = np.clip(t / max(attack_s, 1e-4), 0.0, 1.0)
	return a * (np.exp(-t / tau_s) * (1.0 - tail) + tail * np.exp(-t / tail_tau))


def place(dst, src, at, gain=1.0):
	end = min(dst.shape[1], at + src.shape[1])
	if end > at:
		dst[:, at:end] += src[:, : end - at] * gain


def norm(x, peak=0.6):
	return x * (peak / max(np.abs(x).max(), 1e-9))


# The kinds: [takes, the blast's low end cut (dB below ~400 Hz), its top cut (dB above ~3 kHz),
#  how fast the slap dies (s), how much outdoor tail is left, the action (take, delay s, gain), crack?]
KINDS = {
	"pistol": [["pistol_1", "pistol_2", "pistol9_1", "pistol9_2"], -16.0, -9.0, 0.035, 0.08, ["mag_in_1", 0.028, 0.55], False],
	"smg": [["smg_1", "smg_2", "smg_3"], -15.0, -8.0, 0.03, 0.07, ["mag_in_2", 0.022, 0.5], False],
	"rifle": [["rifle_1", "rifle_2", "sniper_1", "sniper_2"], -13.0, -5.0, 0.04, 0.1, ["mag_in_3", 0.03, 0.45], True],
	"shotgun": [["shotgun_1", "shotgun_2", "autoshotgun_1"], -12.0, -7.0, 0.05, 0.12, ["pump_1", 0.05, 0.25], False],
}

for kind, (takes, low_db, top_db, tau, tail, action, crack) in KINDS.items():
	act_src = load(os.path.join(AUDIO, action[0] + ".ogg"))
	a0 = onset(act_src)
	# The action's first strike only: a metal clack, its low thud thinned (it is the gun's, not the hand's)
	act = act_src[:, a0 : a0 + int(0.09 * SR)] * env(int(0.09 * SR), 0.0005, 0.025)[: act_src[:, a0 : a0 + int(0.09 * SR)].shape[1]]
	act = shape(act, lambda f: shelf(f, 700.0, -10.0, 0.0) * shelf(f, 9000.0, 0.0, -6.0))
	act *= np.linspace(1.0, 0.0, act.shape[1]) ** 2   # faded right out, so it never ends on a click
	for i, take in enumerate(takes):
		src = load(os.path.join(AUDIO, take + ".ogg"))
		s0 = max(0, onset(src) - int(0.002 * SR))
		x = src[:, s0 : s0 + int(0.9 * SR)]
		n = x.shape[1]
		# The blast through the can: the boom and the hiss above taken down, the slap in between kept
		slap = shape(x, lambda f: shelf(f, 400.0, low_db, 0.0) * shelf(f, 3000.0, 0.0, top_db))
		slap *= env(n, 0.0008, tau, tail)
		out = slap * 1.0
		if crack:
			# The bullet's crack, untouched: the first few milliseconds of the shot's top end, at full strength
			c = shape(x[:, : int(0.012 * SR)], lambda f: shelf(f, 2500.0, -30.0, 0.0))
			c *= env(c.shape[1], 0.0002, 0.0025)
			place(out, c, 0, 1.4)
		# The action cycling right after, close by and plain to hear
		place(out, act, int(action[1] * SR), action[2] * np.abs(slap).max() / max(np.abs(act).max(), 1e-9))
		# A little air of the place after it
		out *= np.minimum(1.0, np.exp(-(np.arange(n) / SR - 0.35).clip(0) / 0.08))
		save(norm(out), "supp_%s_%d" % (kind, i + 1))
