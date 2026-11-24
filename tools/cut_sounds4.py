"""Air support sounds made from the recorded ones already in the game (all CC0 or credited in CREDITS.md):
  brrt_1..2.ogg  the gun run's cannon: Free Firearm Library minigun takes, chained, slowed and deepened
  bomb_1..3.ogg  a bomb: the dynamite blast slowed, with a long low rumble
Run from the project root: python3 tools/cut_sounds4.py (needs ffmpeg)."""
import subprocess, os
A = "assets/audio/"
def ff(args):
	subprocess.run(["ffmpeg", "-v", "error", "-y"] + args, check=True)
for n, (rate, order) in enumerate([(0.78, [1, 2, 3, 4, 2, 1, 3, 4]), (0.72, [3, 1, 4, 2, 4, 3, 1, 2])], 1):
	ins = []
	for k in order:
		ins += ["-i", A + "minigun_%d.ogg" % k]
	chain = "".join("[%d:a]" % i for i in range(len(order)))
	ff(ins + ["-filter_complex", chain + "concat=n=%d:v=0:a=1,asetrate=44100*%.2f,aresample=44100," % (len(order), rate)
		+ "bass=g=9:f=90,aecho=0.8:0.6:60|140:0.35|0.2,afade=t=out:st=1.9:d=0.8,loudnorm=I=-12:TP=-1", A + "brrt_%d.ogg" % n])
for n, rate in enumerate([0.62, 0.55, 0.68], 1):
	ff(["-i", A + "boom.ogg", "-filter_complex", "asetrate=44100*%.2f,aresample=44100,bass=g=10:f=60,aecho=0.8:0.7:250|600:0.4|0.25,apad=pad_dur=1.5,afade=t=out:st=3.4:d=1.6,loudnorm=I=-11:TP=-1" % rate,
		"-t", "5", A + "bomb_%d.ogg" % n])
print("ok")
