"""Cuts the sounds Steve fetched on 2026-11-23 (OpenGameArt and the Free Firearm Sound Library) into the game's
own sound names, in place of sounds once made in code. Run: python3 tools/cut_sounds3.py <dir of the fetched files>
Files expected there (as fetched): silencer.wav, windy_ambiance.ogg, helicopter.mp3, fireball.wav (Julien Matthey),
fire-1.wav, dynamite.wav, airplane.wav, assaultriflereload1.wav, gunreload1.wav, reload.wav, shotguncock.wav,
Rack.mp3 (shotgun reload pack) and splash_01..04.ogg (40 CC0 water / splash / slime SFX)."""
import os, subprocess, sys

SRC = sys.argv[1]
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def run(args):
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + args, check=True)


def cut(src, dest, start=0.0, length=None, fade=0.05, norm=-16, ext="ogg"):
	af = "afade=t=in:d=0.005,"
	if length:
		af += "afade=t=out:st=%.3f:d=%.3f," % (max(0.0, length - fade), fade)
	af += "loudnorm=I=%d:TP=-1.0:LRA=11" % norm
	args = ["-ss", "%.3f" % start] + (["-t", "%.3f" % length] if length else []) + ["-i", os.path.join(SRC, src), "-af", af, "-ar", "44100"]
	args += (["-c:a", "libvorbis", "-q:a", "5"] if ext == "ogg" else ["-c:a", "pcm_s16le", "-ac", "1"])
	run(args + [os.path.join(OUT, dest + "." + ext)])


def loop(src, dest, start, length, xf=2.0, norm=-18, ext="ogg"):
	"""A seamless loop: the end fades over into what comes just before the start."""
	s = os.path.join(SRC, src)
	args = ["-ss", "%.3f" % (start + xf), "-t", "%.3f" % length, "-i", s, "-ss", "%.3f" % start, "-t", "%.3f" % xf, "-i", s,
		"-filter_complex", "[0:a][1:a]acrossfade=d=%.3f,loudnorm=I=%d:TP=-1.5:LRA=11" % (xf * 0.97, norm), "-ar", "44100"]
	args += (["-c:a", "libvorbis", "-q:a", "5"] if ext == "ogg" else ["-c:a", "pcm_s16le", "-ac", "1"])
	run(args + [os.path.join(OUT, dest + "." + ext)])


cut("silencer.wav", "supp", 0.0, 0.45, 0.2, -14)
loop("windy_ambiance.ogg", "wind", 10.0, 60.0, 3.0, -20)
loop("helicopter.mp3", "rotor", 4.0, 2.4, 0.3, -16)   # played every 2.4 s while it circles
cut("fireball.wav", "rocket", 0.0, 1.9, 0.6, -14)
loop("fire-1.wav", "flame_loop", 0.2, 2.2, 0.4, -16, "wav")
cut("dynamite.wav", "boom", 1.6, 2.78, 1.4, -12)
cut("airplane.wav", "flyby", 11.0, 14.0, 4.0, -14)
for i, (f, a, b) in enumerate([("assaultriflereload1.wav", 0.15, 0.21), ("gunreload1.wav", 0.0, 0.3), ("reload.wav", 0.1, 0.14)]):
	cut(f, "mag_out_%d" % (i + 1), a, b, 0.04, -18)
for i, (f, a, b) in enumerate([("assaultriflereload1.wav", 1.039, 0.44), ("gunreload1.wav", 0.685, 0.38), ("reload.wav", 0.579, 0.21)]):
	cut(f, "mag_in_%d" % (i + 1), a, b, 0.04, -16)
cut("Rack.mp3", "pump_1", 0.0, 1.0, 0.2, -14)
cut("shotguncock.wav", "pump_2", 0.0, 0.47, 0.1, -14)
for i in range(4):
	cut("splash_%02d.ogg" % (i + 1), "splash_%d" % (i + 1), 0.0, None, 0.05, -18)
