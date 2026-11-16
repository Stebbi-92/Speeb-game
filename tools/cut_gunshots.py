"""Cuts single shots out of the Free Firearm Sound Library (CC0) into the game's gun sounds.

Each source file holds several takes of one shot with silence between them. Every take becomes one
variation: <sound>_<n>.ogg (close, for your own gun) and <sound>_far_<n>.ogg (from further off, for
other pilgrims' shots). Run: python3 tools/cut_gunshots.py "<path to Prepared SFX Library>" [only,these]
"""
import os, re, subprocess, sys

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
# game sound: (near file, mid file, seconds kept per shot, gain in dB)
GUNS = {
	"shotgun": ("Nova/O_21P", "Nova/O_17P", 1.6, 0),
	"mg": ("AK-47/C_28P", "AK-47/C_31P", 0.55, -2),
	"sniper": ("Mosin Nagant/M_21P", "Mosin Nagant/M_26P", 2.4, 0),
	"pistol": ("Walther PPQ/X_39P", "Walther PPQ/X_31P", 0.9, -1),
	"revolver": ("Smith & Wesson 642/V_27P", "Smith & Wesson 642/V_22P", 1.3, 0),
	"minigun": ("PPSh/P_30P", "PPSh/P_16P", 0.28, -4),
	"rifle": ("AR-15/D_32P", "AR-15/D_24P", 0.6, -1),        # the HK416's sharper 5.56 crack
	"pistol45": ("1911/A_42P", "1911/A_34P", 0.9, 0),        # the service pistol's heavier .45
}
ONLY = sys.argv[2].split(",") if len(sys.argv) > 2 else None


def onsets(path):
	out = subprocess.run(["ffmpeg", "-i", path, "-af", "silencedetect=n=-35dB:d=0.3", "-f", "null", "-"], capture_output=True, text=True).stderr
	return [float(x) for x in re.findall(r"silence_end: ([0-9.]+)", out)]


def cut(path, at, length, gain, dest):
	fade = length * 0.45
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % max(0.0, at - 0.01), "-t", "%.3f" % length, "-i", path,
		"-af", "volume=%ddB,afade=t=out:st=%.3f:d=%.3f,loudnorm=I=-14:TP=-1.0:LRA=7" % (gain, length - fade, fade),
		"-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", dest], check=True)


for name, (near, mid, length, gain) in GUNS.items():
	if ONLY and name not in ONLY:
		continue
	for tag, f in (("", near), ("_far", mid)):
		path = os.path.join(SRC, f + ".wav")
		takes = [t for t in onsets(path) if t < 1000][:-1] or onsets(path)[:1]
		takes = takes[:4]
		for i, t in enumerate(takes):
			cut(path, t, length * (1.4 if tag else 1.0), gain, os.path.join(OUT, "%s%s_%d.ogg" % (name, tag, i + 1)))
		print(name + tag, len(takes), "takes")
