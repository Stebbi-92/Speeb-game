"""Swaps the game's older code-made sounds for recordings from the CC0 packs in the asset library.

Run: python3 tools/cut_sounds2.py <folder holding the unpacked packs>
  (unzip fantasy-ambient-cc0/*.zip and kenney-cc0/kenney-{Impact-Sounds,RPG-Audio,Interface-Sounds}.zip there)

Each entry makes assets/audio/<name>_<n>.ogg takes. The game looks for numbered takes before the old
<name>.wav, so the code-made file is simply no longer heard. Every take is brought to the loudness the
old sound had (its loudest tenth of a second), so the mix the code sets stays as it was.
"""
import os, subprocess, sys, numpy as np

ROOT = sys.argv[1]
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
MON = "monsters_creatures_sfx_1_wav/monsters_creatures_sfx_1_wav/"
MAG = "MAGIC/MAGIC WEPONES/Weapons/0009_combat_"
IMP = "kenney-Impact-Sounds/Audio/"
RPG = "kenney-RPG-Audio/Audio/"
UI = "kenney-Interface-Sounds/Audio/"

# name: ([source files], most seconds per take, loudness to match: the old file, or a level in dB)
SOUNDS = {
	# Creatures
	"bite": ([MON + "Ghoul/0014_monster_ghoul_bite.wav", MON + "Troll/0014_monster_troll_bite.wav", MON + "Ghoul/0014_monster_ghoul_claw.wav",
		MON + "Troll/0014_monster_troll_claw.wav", MON + "Demon/0014_monster_demon_claw.wav"], 0.7, "bite.wav"),
	"roar": ([MON + "Minotaur/0014_monster_minotaur_vocal_a.wav", MON + "Minotaur/0014_monster_minotaur_vocal_b.wav", MON + "Demon/0014_monster_demon_vocal_a.wav"], 2.2, "roar.wav"),
	"growl_0": ([MON + "Orc/0014_monster_orc_vocal_a.wav", MON + "Orc/0014_monster_orc_vocal_b.wav"], 1.9, "growl_0.wav"),
	"growl_1": ([MON + "Ghoul/0014_monster_ghoul_vocal_a.wav", MON + "Giant/Enemy_Walker_Rock_Grunts_01.wav"], 1.9, "growl_1.wav"),
	"growl_2": ([MON + "Giant/Enemy_Walker_Rock_Grunts_02.wav", MON + "Earth Elemental/0014_monster_elemental_earth_vocal_a.wav"], 1.9, "growl_2.wav"),
	"shriek_0": ([MON + "Ghost/0014_monster_ghost_vocal_a.wav"], 2.2, "shriek_0.wav"),
	"shriek_1": ([MON + "Ghost/0014_monster_ghost_vocal_b.wav"], 2.2, "shriek_1.wav"),
	"shriek_2": ([MON + "Ghost/0014_monster_ghost_attack_a.wav", MON + "Goblin/0014_monster_goblin_vocal_a.wav"], 2.2, "shriek_2.wav"),
	"shriek_3": ([MON + "Ghost/0014_monster_ghost_attack_b.wav", MON + "Goblin/0014_monster_goblin_vocal_b.wav"], 2.2, "shriek_3.wav"),
	"screech": ([MON + "Ghost/0014_monster_ghost_attack_b.wav"], 1.6, "screech.wav"),
	"critter_0": ([MON + "Ghoul/Enemy_ Walker_Bug_Detect.wav", MON + "Demon/Enemy_ Walker_Bug_LandFoliage.wav"], 1.4, "critter_0.wav"),
	"crumble": ([MON + "Giant/Enemy_Walker_Rock_LandRock.wav", MON + "Earth Elemental/0014_monster_elemental_earth_movement_l.wav",
		MON + "Earth Elemental/0014_monster_elemental_earth_movement_r.wav"], 1.4, "crumble.wav"),
	# Bodies, blows and air
	"thud": ([IMP + "impactSoft_heavy_000.ogg", IMP + "impactSoft_heavy_001.ogg", IMP + "impactPunch_heavy_000.ogg", IMP + "impactPunch_heavy_001.ogg"], 0.6, "thud.wav"),
	"hurt": ([IMP + "impactPunch_medium_000.ogg", IMP + "impactPunch_medium_001.ogg", IMP + "impactPunch_medium_002.ogg"], 0.6, "hurt.wav"),
	"whoosh": ([MAG + "punch_swing_c.wav", MAG + "punch_swing_d.wav", MAG + "staff_swing_d.wav", MAG + "staff_swing_e.wav"], 0.7, "whoosh.wav"),
	"step": ([RPG + "footstep0%d.ogg" % i for i in range(5)], 0.5, "step.wav"),
	# The shotgun's action and its shells
	"pump": ([MAG + "crossbow_load_b.wav", MAG + "crossbow_load_c.wav", RPG + "metalLatch.ogg"], 0.6, "pump.wav"),
	"shell": ([RPG + "metalClick.ogg", IMP + "impactMetal_light_000.ogg", IMP + "impactMetal_light_001.ogg"], 0.45, "shell.wav"),
	# The menu's no. (Not the bell: the packs' bells are short clangs, and the beacons want a long toll.)
	"deny": ([UI + "error_00%d.ogg" % i for i in range(1, 5)], 0.6, "deny.wav"),
}


def decode(path):
	raw = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "44100", "-f", "f32le", "-"], capture_output=True, check=True).stdout
	return np.frombuffer(raw, np.float32)


def loudest(x):
	w = 4410
	n = max(1, len(x) // w)
	x = np.pad(x, (0, max(0, n * w - len(x))))
	return 20 * np.log10(np.sqrt((x[:n * w].reshape(n, w) ** 2).mean(1)).max() + 1e-9)


for name, (srcs, length, match) in SOUNDS.items():
	old = os.path.join(OUT, match)
	target = loudest(decode(old)) if isinstance(match, str) else float(match)
	for i, src in enumerate(srcs):
		path = os.path.join(ROOT, src)
		x = decode(path)
		# Start where the sound starts
		on = np.argmax(np.abs(x) > 0.02 * np.abs(x).max())
		start = max(0.0, on / 44100 - 0.01)
		dur = min(length, len(x) / 44100 - start)
		gain = target - loudest(x[on:on + int(dur * 44100)])
		fade = dur * 0.35
		dest = os.path.join(OUT, "%s_%d.ogg" % (name, i + 1))
		subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", "%.3f" % start, "-t", "%.3f" % dur, "-i", path,
			"-af", "volume=%.2fdB,alimiter=limit=0.95:level=false,afade=t=out:st=%.3f:d=%.3f" % (gain, dur - fade, fade),
			"-ac", "2", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", dest], check=True)
		print("%-10s %-70s %+5.1f dB" % (name, src[-70:], gain))
