"""Cuts the game's sounds out of the CC0 sound packs listed in CREDITS.md.

Run: python3 tools/cut_sounds.py <folder holding the unpacked packs>
Each entry makes assets/audio/<name>_<n>.ogg takes (or <name>.ogg for loops). The game picks a take
at random each time, so nothing repeats exactly.
"""
import os, re, subprocess, sys

ROOT = sys.argv[1]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")

# name: (mode, [source files], seconds per take, most takes, extra filter)
SOUNDS = {
	# The blade
	"swing": ("one", ["MAGIC WEPONES/Weapons/0009_combat_sword_swing_c.wav", "MAGIC WEPONES/Weapons/0009_combat_sword_swing_d.wav", "MAGIC WEPONES/Weapons/0009_combat_sword_swing_e.wav", "MAGIC WEPONES/Weapons/0009_combat_dagger_swing_c.wav"], 0.6, 4, ""),
	"chop": ("one", ["MAGIC WEPONES/Weapons/0009_combat_sword_hit_flesh_a.wav", "MAGIC WEPONES/Weapons/0009_combat_sword_hit_flesh_b.wav", "MAGIC WEPONES/Weapons/0009_combat_sword_hit_flesh_c.wav", "MAGIC WEPONES/Weapons/0009_combat_sword_hit_flesh_e.wav"], 0.7, 4, ""),
	"parry": ("one", ["MAGIC WEPONES/Weapons/0009_combat_block_sword_c.wav", "MAGIC WEPONES/Weapons/0009_combat_block_sword_d.wav", "MAGIC WEPONES/Weapons/0009_combat_block_sword_e.wav"], 0.8, 3, ""),
	"draw": ("one", ["MAGIC WEPONES/Weapons/0009_combat_sword_draw_c.wav", "MAGIC WEPONES/Weapons/0009_combat_sword_draw_d.wav"], 0.9, 2, ""),
	# Shots striking things
	"hit_flesh": ("one", ["Hits/Body_HIts_01.wav", "Hits/Body_HIts_02.wav", "Hits/Body_HIts_03.wav", "Battle/Punch Thud 2.wav", "Battle/Punch Thud 3.wav"], 0.35, 5, ""),
	"hit_metal": ("one", ["Hits/Metal_Hit_01.wav", "Hits/Metal_Hit_02.wav", "Hits/Metal_Hit_03.wav", "Hits/Metal_Hit_05.wav", "Hits/Metal_Hit_07.wav"], 0.6, 5, ""),
	# The fallen
	"fall": ("one", ["Battle/Impact Body Fall 1.wav", "Battle/Impact Body Fall 2.wav", "Battle/Impact Body Fall 3.wav", "Battle/Impact Body Fall 4 .wav"], 1.0, 4, ""),
	"fall_heavy": ("one", ["Battle/Body Fall Heavy 5.wav", "Battle/Body Fall Heavy 7.wav"], 1.4, 2, ""),
	# Great ones: the roar of something very large
	"great_roar": ("one", ["dragon/Dragon_01.wav", "dragon/Dragon_03.wav", "dragon/Dragon_05.wav", "dragon/Dragon_08.wav"], 3.0, 4, ""),
	"troll": ("one", ["monsters_creatures_sfx_1_wav/Troll/0014_monster_troll_vocal_a.wav", "monsters_creatures_sfx_1_wav/Troll/0014_monster_troll_vocal_b.wav", "monsters_creatures_sfx_1_wav/Minotaur/0014_monster_minotaur_vocal_a.wav"], 2.0, 3, ""),
	"heavy_step": ("one", ["Footsteps/Monster Footsteps 1.wav", "Footsteps/Monster Footsteps 2 .wav", "Footsteps/Monster Footsteps 3.wav"], 1.0, 3, ""),
	# Footsteps by ground
	"step_sand": ("takes", ["Footsteps/Sand Footsteps Walk Run.wav"], 0.32, 8, ""),
	"step_gravel": ("takes", ["Footsteps/Footsteps Gravel 11.wav"], 0.32, 6, ""),
	"step_wood": ("takes", ["Footsteps/Footsteps Wood 31.wav"], 0.32, 6, ""),
	"step_stone": ("takes", ["Footsteps/Footsteps Cement 12.wav"], 0.3, 6, ""),
	# Places, as loops
	"amb_desert_night": ("loop", ["Desert KalNight .wav"], 60.0, 1, ""),
	"amb_town": ("loop", ["Town_01.wav"], 60.0, 1, ""),
	"amb_cave": ("loop", ["Cave Ambience Wind.wav"], 50.0, 1, ""),
	# The sea and the weather (0.8)
	"amb_sea": ("loop", ["Small Waves Lapping Beach .wav"], 50.0, 1, ""),
	"amb_surf": ("loop", ["Shore_01.wav"], 50.0, 1, ""),
	"amb_rain": ("loop", ["Rain Light 1.wav"], 50.0, 1, ""),
	"amb_storm": ("loop", ["Rain Downpour 1.wav"], 50.0, 1, ""),
}


def find(rel):
	for base, dirs, files in os.walk(ROOT):
		p = os.path.join(base, rel)
		if os.path.exists(p):
			return p
	raise SystemExit("missing " + rel)


def onsets(path, db=-38, gap=0.12):
	out = subprocess.run(["ffmpeg", "-i", path, "-af", "silencedetect=n=%ddB:d=%.2f" % (db, gap), "-f", "null", "-"], capture_output=True, text=True).stderr
	return [float(x) for x in re.findall(r"silence_end: ([0-9.]+)", out)]


def run(args):
	subprocess.run(["ffmpeg", "-y", "-loglevel", "error"] + args, check=True)


def cut(src, at, length, dest, norm="-16"):
	fade = length * 0.4
	run(["-ss", "%.3f" % max(0.0, at - 0.01), "-t", "%.3f" % length, "-i", src,
		"-af", "afade=t=in:d=0.005,afade=t=out:st=%.3f:d=%.3f,loudnorm=I=%s:TP=-1.0" % (length - fade, fade, norm),
		"-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "4", dest])


only = sys.argv[2:]
for name, (mode, srcs, length, most, _) in SOUNDS.items():
	if only and name not in only:
		continue
	for f in os.listdir(OUT):
		if re.fullmatch(re.escape(name) + r"(_\d+)?\.(ogg|wav)(\.import)?", f):
			os.remove(os.path.join(OUT, f))
	if mode == "loop":
		src = find(srcs[0])
		tmp = "/tmp/_loop.wav"
		# Two overlapping pieces crossfaded so the end runs into the start without a seam
		run(["-ss", "10", "-t", "%.1f" % (length + 4), "-i", src, "-ar", "44100", tmp])
		run(["-i", tmp, "-t", "4", "/tmp/_head.wav"])
		run(["-ss", "4", "-i", tmp, "/tmp/_body.wav"])
		run(["-i", "/tmp/_body.wav", "-i", "/tmp/_head.wav", "-filter_complex", "[0][1]acrossfade=d=4,loudnorm=I=-24:TP=-3[o]",
			"-map", "[o]", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "3", os.path.join(OUT, name + ".ogg")])
		print(name, "loop")
		continue
	n = 0
	for src in map(find, srcs):
		starts = onsets(src) if mode == "takes" else [max(0.0, (onsets(src) or [0.0])[0])]
		for t in starts:
			if n >= most:
				break
			n += 1
			cut(src, t, length, os.path.join(OUT, "%s_%d.ogg" % (name, n)), "-14" if name in ("great_roar", "troll") else "-16")
	print(name, n, "takes")
