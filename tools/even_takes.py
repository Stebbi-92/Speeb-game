"""Evens out the loudness of a sound's takes, so no take jumps out of the rest.

Run: python3 tools/even_takes.py
Each group's takes are brought to one level (the loudest 300 ms, roughly K-weighted), with a limiter
keeping the peaks under -1 dB. Run it again after re-cutting any of these sounds.
"""
import glob, os, subprocess, numpy as np

AUDIO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")

# group glob: target level (dB)
GROUPS = {
	"kills/kill_*.ogg": -14.0,
	"cloth_*.ogg": -26.0, "page_*.ogg": -24.0,
	"fall_heavy_*.ogg": -17.0, "great_roar_*.ogg": -12.0,
	"hit_flesh_[123].ogg": -10.5,
	"step_gravel_*.ogg": -20.0, "step_stone_*.ogg": -20.0, "step_snow_*.ogg": -20.0, "step_wood_*.ogg": -20.0,
	"step_sand_*.ogg": -20.0, "step_grass_*.ogg": -21.0, "step_[0-9].ogg": -20.0,
	"mag_in_*.ogg": -17.5, "mag_out_*.ogg": -17.5,
	"growl_1_*.ogg": -8.5, "shriek_2_*.ogg": -10.0, "shriek_3_*.ogg": -10.0,
	"splash_*.ogg": -19.0, "whoosh_*.ogg": -15.0,
	"jingle_find_*.ogg": -11.0, "jingle_up_*.ogg": -10.0,
	"autoshotgun_far_*.ogg": -20.0, "pistol9_far_*.ogg": -20.5,
}


def decode(f, af=None):
	cmd = ["ffmpeg", "-v", "error", "-i", f] + (["-af", af] if af else []) + ["-ac", "1", "-ar", "48000", "-f", "f32le", "-"]
	return np.frombuffer(subprocess.run(cmd, capture_output=True).stdout, np.float32)


def level(f):
	e = decode(f, "highpass=f=60,highshelf=f=1500:g=4").astype(np.float64) ** 2
	w = int(0.3 * 48000)
	m = e.mean() if len(e) <= w else (lambda c: ((c[w:] - c[:-w]) / w).max())(np.cumsum(np.r_[0, e]))
	return 10 * np.log10(max(m, 1e-12)) - 0.7


for pat, target in GROUPS.items():
	for f in sorted(glob.glob(os.path.join(AUDIO, pat))):
		gain = target - level(f)
		if abs(gain) < 0.5:
			continue
		tmp = f[:-4] + ".tmp.ogg"
		ch = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=channels,sample_rate", "-of", "csv=p=0", f], capture_output=True, text=True).stdout.strip().split(",")
		subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", f, "-af", "volume=%.2fdB,alimiter=limit=0.89:attack=1:release=40:level=false" % gain,
			"-c:a", "libvorbis", "-q:a", "5", tmp], check=True)
		os.replace(tmp, f)
		print("%-28s %+5.1f dB -> %.1f" % (os.path.relpath(f, AUDIO), gain, level(f)))
