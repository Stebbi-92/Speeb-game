class_name LesserSpeeb
extends CharacterBody3D
## A lesser form of Speeb, hostile to the seeker.
## rusher: closes in to bite.  spitter: keeps its distance and casts bolts.
## idol: gilded, slow, its face proof against shot; strike it from the side or behind.
## swarm: small and quick, comes in numbers.  elite: a great form, one to a land.
## spider: a cat head on eight legs; it skitters along the ground and leaps.
## saucer: a disc of the lesser that hovers out of reach and lets down mites, small forms that swarm.
## unseen: a tall thing that is barely there. It does not move while it is looked upon.

signal died

## Each kind: its name, its numbers, how it fights, and what it fears ("weak") or shrugs off ("tough"),
## by the kind of harm: shot (pellets), bullet, blast, fire, blade. "body" is "cat" for those that walk
## on four legs; the rest are heads that drift through the air.
## The danger a form first walks at: the weak are met near home, the worst only far out.
## A land sends only the forms its danger allows, so new kinds come in one step at a time.
const FORM_TIER := {
	"box_cat": 1, "rusher": 1, "spitter": 1, "swarm": 1, "spider": 1, "howler": 1, "mite": 1, "saltbone": 1, "hollow": 1, "bloater": 1,
	"idol": 2, "lurker": 2, "vigil": 2, "drowned": 2, "wisp": 2, "saltrifle": 2, "unlit_gun": 2, "unlit_blade": 2, "unlit_flame": 2,
	"deacon": 3, "brute": 3, "warden": 3, "unlit_mark": 3, "unseen": 2, "elite": 3, "saucer": 2,
	"colossus": 4, "knight": 4, "unlit_brute": 3,
	"cinder_hound": 1, "rust_stalker": 2, "bog_crawler": 2, "rime_bones": 3, "bile_elder": 2, "mourner": 2,
	"dirge_howler": 3, "iron_idol": 3, "pyre_sack": 3, "sand_maw": 3, "tar_giant": 3, "glass_crawler": 4, "cinder_hauler": 4,
	# 0.10: the forms of the far lands. Each has a way of its own (see FoeTraits).
	"flicker": 3, "archivist_hand": 3, "tunnel_unlit": 3, "kelp_drowner": 3, "weed_eel": 3, "geyser_wight": 3, "canyon_strider": 3,
	"dust_choir": 3, "grass_stalker": 3, "raven_mask": 4, "rime_walker": 4, "glass_husk": 4, "mound_guard": 4, "herd_ghost": 4,
	# 0.12: the old tales of the themed isles
	"nykur": 2, "draugr": 3, "shtriga": 3, "kulshedra": 4,
	"ash_weaver": 3, "gaunt": 3, "harrow": 4,
}

## Kin of the common forms, bred hard by their own lands: each moves and fights as its "base" does,
## with its own name, numbers and colour. Met further out than the form they come from.
const VARIANTS := {
	"box_cat": {"base": "rusher", "name": "Box Cat", "hp": 16.0, "size": 0.55, "speed": 7.4, "bite": 6.0, "radius": 0.3,
		"weak": {"shot": 1.5, "fire": 1.5}, "tough": {}, "text": "A cat in a box. They come at night in screaming packs. One is nothing."},
	"cinder_hound": {"base": "rusher", "name": "Cinder Hound", "hp": 40.0, "speed": 6.4, "bite": 12.0, "tint": Color(0.95, 0.45, 0.15),
		"weak": {"bullet": 1.3}, "tough": {"fire": 0.4}, "text": "Lean and quick, warm to the touch. Fire does little to it."},
	"rust_stalker": {"base": "rusher", "name": "Rust Stalker", "hp": 78.0, "size": 1.15, "bite": 20.0, "tint": Color(0.6, 0.25, 0.15),
		"text": "A stalker of the dunes, heavier and redder."},
	"bog_crawler": {"base": "spider", "name": "Bog Crawler", "hp": 70.0, "bite": 16.0, "size": 0.95, "tint": Color(0.25, 0.4, 0.2),
		"text": "Slick with marsh water. Fire still undoes it."},
	"glass_crawler": {"base": "spider", "name": "Glass Crawler", "hp": 95.0, "bite": 20.0, "tint": Color(0.08, 0.06, 0.1),
		"weak": {"blast": 1.5, "blade": 1.3}, "tough": {"bullet": 0.6, "fire": 0.8}, "text": "Its back is black glass. Rounds glance off it."},
	"bile_elder": {"base": "spitter", "name": "Bile Elder", "hp": 85.0, "size": 1.1, "tint": Color(0.55, 0.65, 0.25),
		"text": "An old voice of the choir. It spits further."},
	"dirge_howler": {"base": "howler", "name": "Dirge Howler", "hp": 140.0, "size": 1.4, "bite": 20.0, "tint": Color(0.35, 0.3, 0.45),
		"text": "Its cry carries over the hills and brings the rest at a run."},
	"mourner": {"base": "hollow", "name": "Hollow Mourner", "hp": 110.0, "bite": 22.0, "size": 1.15, "tint": Color(0.4, 0.42, 0.35),
		"text": "One of the Hollowed that still weeps. Slow, and hard to stop."},
	"rime_bones": {"base": "saltbone", "name": "Rime-Bones", "hp": 72.0, "bite": 18.0, "speed": 6.4, "tint": Color(0.7, 0.85, 1.0),
		"text": "Salt-Bones furred with frost. Faster than they look."},
	"pyre_sack": {"base": "bloater", "name": "Pyre Sack", "hp": 70.0, "size": 1.5, "tint": Color(0.9, 0.3, 0.1),
		"text": "A great sack of embers. Its burst is wide. Shoot it far off."},
	"iron_idol": {"base": "idol", "name": "Iron Idol", "hp": 165.0, "bite": 34.0, "size": 1.35, "tint": Color(0.45, 0.45, 0.5),
		"text": "An idol with an iron face. Go round it, or bring a blast."},
	"cinder_hauler": {"base": "brute", "name": "Cinder Hauler", "hp": 330.0, "bite": 40.0, "size": 1.8, "tint": Color(0.3, 0.15, 0.1),
		"tough": {"shot": 0.6, "bullet": 0.8, "fire": 0.5}, "text": "A hauler of the heights, charred black. Its charge breaks walls."},
	"sand_maw": {"base": "lurker", "name": "Sand Maw", "hp": 150.0, "bite": 34.0, "size": 1.35, "tint": Color(0.75, 0.5, 0.3),
		"text": "A lurker grown huge. The ground opens under you."},
	"bellwound": {"base": "serpent", "name": "The Bell-Wound", "hp": 2400.0, "size": 5.0, "bite": 46.0, "radius": 2.2, "speed": 5.6,
		"text": "Wound about the drowned tower of the Kraken-Bell. It pulls boats down."},
	# 0.10: the forms of the far lands, each with one way to learn ("trait", see FoeTraits)
	"flicker": {"base": "wisp", "name": "Flicker", "hp": 55.0, "bite": 14.0, "trait": "phase", "tint": Color(0.75, 0.85, 1.0),
		"weak": {"blade": 1.6, "shot": 1.4}, "tough": {"bullet": 0.5, "fire": 0.0}, "text": "Here, then gone, then behind you. Keep turning. A blade finds it best."},
	"archivist_hand": {"base": "hollow", "name": "Archivist's Hand", "hp": 65.0, "speed": 4.4, "bite": 10.0, "trait": "thief", "tint": Color(0.55, 0.5, 0.35),
		"text": "It grabs at your rounds and runs. Slay it and you get them back."},
	"tunnel_unlit": {"base": "unlit_gun", "name": "Tunnel Unlit", "hp": 75.0, "trait": "burrow", "tint": Color(0.4, 0.33, 0.25),
		"text": "Goes into the ground and comes up at your back. Listen for the earth breaking."},
	"weed_eel": {"base": "serpent", "name": "Weed Eel", "hp": 120.0, "size": 1.0, "bite": 14.0, "slow": 4.0, "speed": 6.5, "radius": 0.6, "tint": Color(0.22, 0.32, 0.18),
		"text": "Long and thin, wound in kelp. It comes up under swimmers in the Kelp Forest and pulls them down."},
	"kelp_drowner": {"base": "drowned", "name": "Kelp Drowner", "hp": 95.0, "bite": 16.0, "slow": 5.0, "tint": Color(0.2, 0.35, 0.25),
		"text": "Wrapped in weed from the deep. Its grip holds you a long while. Burn it."},
	"rime_walker": {"base": "colossus", "name": "Rime Walker", "hp": 300.0, "bite": 34.0, "freeze": 1.5, "tint": Color(0.75, 0.88, 1.0),
		"weak": {"fire": 1.8, "blast": 1.4}, "tough": {"bullet": 0.7, "blade": 0.8}, "text": "A giant of the frost. Its blow freezes you where you stand. Fire undoes it."},
	"geyser_wight": {"base": "hollow", "name": "Geyser Wight", "hp": 80.0, "bite": 14.0, "trait": "vent", "tint": Color(0.85, 0.8, 0.7),
		"weak": {"shot": 1.3}, "tough": {"fire": 0.3}, "text": "Sleeps in hot ground and bursts up in scalding steam. Do not stand near the vents."},
	"raven_mask": {"base": "unlit_blade", "name": "Raven Mask", "hp": 160.0, "bite": 24.0, "trait": "ravens", "tint": Color(0.1, 0.1, 0.12),
		"text": "It calls ravens to your face, and strikes while you cannot see. Close in fast."},
	"canyon_strider": {"base": "rusher", "name": "Canyon Strider", "hp": 120.0, "speed": 8.5, "bite": 22.0, "trait": "leap", "size": 1.2, "tint": Color(0.7, 0.45, 0.3),
		"text": "Springs at you from far off. Step aside as it leaps."},
	"dust_choir": {"base": "spitter", "name": "Dust Choir", "hp": 90.0, "trait": "choir", "pack": 3, "tint": Color(0.8, 0.7, 0.5),
		"text": "Comes in threes. While it sings, the forms about it heal. Kill the singers first."},
	"glass_husk": {"base": "idol", "name": "Glass Husk", "hp": 260.0, "bite": 30.0, "trait": "split", "size": 1.4, "tint": Color(0.7, 0.9, 0.95),
		"weak": {"blunt": 1.8, "blast": 1.5}, "tough": {"shot": 0.6}, "text": "Cracks into two when it falls. A heavy blow breaks it best."},
	"grass_stalker": {"base": "rusher", "name": "Grass Stalker", "hp": 70.0, "bite": 18.0, "trait": "stealth", "tint": Color(0.55, 0.6, 0.3),
		"text": "You cannot see it in the grass until it is close. Watch the grass move."},
	"mound_guard": {"base": "knight", "name": "Mound Guard", "hp": 280.0, "trait": "pair", "pack": 2, "tint": Color(0.35, 0.3, 0.25),
		"weak": {"blunt": 1.5, "blast": 1.3}, "tough": {"blade": 0.6, "shot": 0.7}, "text": "They guard the old mounds in pairs, and strike harder side by side. Part them."},
	"herd_ghost": {"base": "brute", "name": "Herd Ghost", "hp": 400.0, "speed": 7.0, "bite": 34.0, "trait": "stampede", "pack": 4, "tint": Color(0.85, 0.85, 0.9),
		"tough": {"bullet": 0.7, "shot": 0.7, "blade": 0.7, "fire": 0.7, "blast": 0.7}, "text": "A stampede of the dead. Do not stand in its line. It fades after a while."},
	"tar_giant": {"base": "drowned", "name": "Tar Giant", "hp": 170.0, "bite": 24.0, "size": 1.45, "tint": Color(0.12, 0.1, 0.08),
		"text": "Something drowned long ago and grown in the tar. It clings."},
	# 0.12: the old tales of the themed isles. Hrafnsey keeps the north's dead; Kalaja the south's night things.
	"draugr": {"base": "hollow", "name": "Draugr", "hp": 190.0, "bite": 28.0, "size": 1.4, "speed": 3.6, "tint": Color(0.32, 0.4, 0.45),
		"weak": {"fire": 1.8, "blunt": 1.4}, "tough": {"bullet": 0.6, "blade": 0.8}, "text": "A dead man of the north who would not lie in his mound. Heavy and slow. Burn him."},
	"nykur": {"base": "rusher", "name": "Nykur", "hp": 95.0, "bite": 18.0, "size": 1.3, "speed": 7.8, "slow": 3.0, "tint": Color(0.62, 0.64, 0.66),
		"weak": {"bullet": 1.3}, "tough": {"shot": 0.8}, "text": "A grey horse by the water, its hooves turned backward. Its bite drags at your legs."},
	"shtriga": {"base": "deacon", "name": "Shtriga", "hp": 120.0, "bite": 20.0, "speed": 5.4, "drain": 1.6, "tint": Color(0.42, 0.3, 0.45),
		"weak": {"fire": 2.0, "blade": 1.3}, "tough": {"bullet": 0.8}, "text": "A night witch of the keep. She drinks from you, and each sip heals her. Fire undoes her."},
	"kulshedra": {"base": "elite", "name": "Kulshedra", "hp": 460.0, "bite": 34.0, "size": 2.4, "tint": Color(0.45, 0.18, 0.1),
		"weak": {"blast": 1.5, "bullet": 1.2}, "tough": {"fire": 0.1, "shot": 0.7}, "text": "The she-dragon of the south. She breathes fire in a fan. Get behind stone."},
	# 0.12: forms with scanned bodies of their own (see SCANS)
	"ash_weaver": {"base": "spider", "name": "Ash Weaver", "hp": 150.0, "bite": 26.0, "size": 1.0, "speed": 6.0, "radius": 0.8,
		"weak": {"fire": 1.8}, "tough": {"bullet": 0.8}, "text": "A spider the size of a cart. It climbs what you build. Fire still undoes it."},
	"harrow": {"base": "unseen", "name": "The Harrow", "hp": 170.0, "bite": 36.0, "size": 1.0, "radius": 0.5,
		"weak": {"fire": 1.4, "blade": 1.2}, "tough": {}, "text": "A man with a spider's legs on his back. It comes only when you look away."},
	"gaunt": {"base": "lurker", "name": "The Gaunt", "hp": 120.0, "bite": 28.0, "size": 1.0, "speed": 6.4, "radius": 0.45,
		"weak": {"shot": 1.3}, "tough": {"bullet": 0.8}, "text": "Thin as a rake and taller than a man. It waits under the ash and stands up at your feet."},
}

## What a form is made of, by the sound a hit makes on it: [sound, pitch]. Flesh when not named.
const MATTER := {
	"metal": ["hit_metal", 1.0], "glass": ["hit_metal", 1.7], "bone": ["chop", 1.45], "ghost": ["whoosh", 1.6], "shell": ["hit_flesh", 1.3],
}
const MATTER_OF := {
	"idol": "metal", "saucer": "metal", "knight": "metal", "iron_idol": "metal", "mound_guard": "metal",
	"glass_crawler": "glass", "glass_husk": "glass",
	"saltbone": "bone", "rime_bones": "bone", "saltrifle": "bone", "draugr": "bone",
	"vigil": "ghost", "wisp": "ghost", "flicker": "ghost", "herd_ghost": "ghost",
	"spider": "shell", "bog_crawler": "shell", "ash_weaver": "shell", "swarm": "shell",
}


func matter() -> String:
	if plate > 0.0:
		return "metal"
	return str(MATTER_OF.get(variant, MATTER_OF.get(kind, "flesh")))


## Scanned bodies (CC-BY 4.0, see CREDITS): [model, height in metres, animation, pace the walk is made for (0: it stands),
## where the head is (up and forward, as parts of the height)]. The form keeps its base's ways; only the body is new.
const SCANS := {
	"ash_weaver": ["res://assets/models/foes/spiderthing/spiderthing.glb", 1.5, 0, 4.0, Vector2(0.55, 0.55)],
	"harrow": ["res://assets/models/foes/monster_spider/monster_spider.glb", 2.2, 0, 0.0, Vector2(0.9, 0.0)],
	"gaunt": ["res://assets/models/foes/horror_monster/horror_monster.glb", 2.3, 0, 2.0, Vector2(0.88, 0.05)],
	# The great ones' own bodies (CC-BY 4.0, see CREDITS.md), each with its Speeb's head on its neck:
	# [file, height at size 1, walking clip, walking pace, head (height, forward) as parts of its height,
	#  {bone: the head bone the face rides, shrink: its own head hidden, idle: standing clip, tint, turn}]
	"boss_ash": ["res://assets/models/foes/magma_hound/magma_hound.glb", 1.15, "Walk", 1.6, Vector2(0.8, 0.45),
		{"bone": "head_0137", "shrink": true, "idle": "Idle", "head_k": 0.55, "head_off": Vector3(0, 0.05, 0.08)}],
	"boss_dunes": ["res://assets/models/foes/sandworm/sandworm.glb", 6.0, "Sandworm|SandwormWiggle", 0.0, Vector2(0.95, 0.2),
		{"bone": "Bone.010_010", "idle": "Sandworm|SandwormIdle", "head_k": 0.7, "tint": Color(0.85, 0.72, 0.52), "bone_bounds": true, "by_long": true, "turn": PI / 2}],
	"boss_basalt": ["res://assets/models/foes/golem/golem.glb", 1.3, "Walk", 1.2, Vector2(0.9, 0.1),
		{"bone": "Head_0", "shrink": true, "idle": "Idle", "head_k": 0.6, "tint": Color(0.42, 0.4, 0.42)}],
	"boss_forest": ["res://assets/models/foes/criatura/criatura.glb", 2.0, "", 1.5, Vector2(0.62, 1.05), {"head_k": 0.5, "bone_bounds": true, "turn": PI}],
	"boss_marsh": ["res://assets/models/foes/widow/widow.glb", 1.4, "", 2.0, Vector2(0.55, 0.42),
		{"head_k": 0.75, "tint": Color(0.16, 0.13, 0.12), "bone_bounds": true}],
	# The far great ones wear the near ones' bodies, changed: glass, ice, red bone and old white bone
	"boss_quiet": ["res://assets/models/foes/criatura/criatura.glb", 2.4, "", 1.5, Vector2(0.62, 1.05), {"head_k": 0.5, "bone_bounds": true, "turn": PI, "tint": Color(0.75, 0.85, 0.95)}],
	"boss_frost": ["res://assets/models/foes/golem/golem.glb", 1.3, "Walk", 1.2, Vector2(0.9, 0.1),
		{"bone": "Head_0", "shrink": true, "idle": "Idle", "head_k": 0.6, "tint": Color(0.72, 0.84, 0.95)}],
	"boss_sun": ["res://assets/models/foes/sandworm/sandworm.glb", 6.0, "Sandworm|SandwormWiggle", 0.0, Vector2(0.95, 0.2),
		{"bone": "Bone.010_010", "idle": "Sandworm|SandwormIdle", "head_k": 0.7, "tint": Color(0.75, 0.38, 0.25), "bone_bounds": true, "by_long": true, "turn": PI / 2}],
	"boss_steppe": ["res://assets/models/foes/magma_hound/magma_hound.glb", 1.15, "Walk", 1.6, Vector2(0.8, 0.45),
		{"bone": "head_0137", "shrink": true, "idle": "Idle", "head_k": 0.55, "head_off": Vector3(0, 0.05, 0.08), "tint": Color(0.88, 0.86, 0.8)}],
	# Kulshedra, the she-dragon: "Prowler Dragon Variant Rig" by DM-913, on wings that are its forelegs
	"kulshedra": ["res://assets/models/foes/drake/drake.glb", 1.9, "Walk", 2.0, Vector2(0.7, 0.5),
		{"bone": "Head_65", "shrink": true, "head_k": 0.42, "tint": Color(0.85, 0.55, 0.45), "bone_bounds": true}],
}
static var _scan_bounds := {}


const KINDS := {
	"rusher": {"name": "Ash Stalker", "hp": 60.0, "size": 1.0, "speed": 5.6, "bite": 15.0, "radius": 0.45, "body": "cat",
		"weak": {"shot": 1.3}, "tough": {}, "text": "Runs you down and springs at the last."},
	"spitter": {"name": "Bile Choir", "hp": 38.0, "size": 0.85, "speed": 3.2, "bite": 0.0, "radius": 0.4,
		"weak": {"bullet": 1.4}, "tough": {"shot": 0.7}, "text": "Keeps its distance and spits. Pick it off."},
	"idol": {"name": "Gilt Idol", "hp": 90.0, "size": 1.25, "speed": 2.6, "bite": 26.0, "radius": 0.55, "body": "cat",
		"weak": {"blast": 1.6, "blade": 1.4}, "tough": {"shot": 0.6}, "text": "Its golden face turns shot. Strike from the side, or with a blade or a blast."},
	"swarm": {"name": "Cinder Mote", "hp": 12.0, "size": 0.5, "speed": 7.0, "bite": 7.0, "radius": 0.25,
		"weak": {"shot": 1.5, "fire": 2.0}, "tough": {}, "text": "Small, quick and many. A spread of shot clears them."},
	"elite": {"name": "Ash Lion", "hp": 320.0, "size": 2.0, "speed": 4.0, "bite": 30.0, "radius": 0.9, "body": "cat",
		"weak": {"blast": 1.5}, "tough": {"shot": 0.75, "fire": 0.7}, "text": "Great and slow to fall. It spits fire in a fan."},
	"saucer": {"name": "Watching Disc", "hp": 150.0, "size": 1.0, "speed": 4.5, "bite": 0.0, "radius": 1.6,
		"weak": {"bullet": 1.3, "blast": 1.3}, "tough": {"fire": 0.5}, "text": "Hangs above and lets down its brood."},
	"mite": {"name": "Mite", "hp": 9.0, "size": 0.42, "speed": 7.6, "bite": 5.0, "radius": 0.22,
		"weak": {"shot": 1.5}, "tough": {}, "text": "Let down by the discs."},
	"spider": {"name": "Tar Crawler", "hp": 44.0, "size": 0.8, "speed": 6.4, "bite": 12.0, "radius": 0.55,
		"weak": {"fire": 2.0}, "tough": {"bullet": 0.8}, "text": "Climbs what you build. Fire undoes it."},
	"unseen": {"name": "The Unseen", "hp": 140.0, "size": 1.3, "speed": 5.0, "bite": 34.0, "radius": 0.6,
		"weak": {"fire": 1.5}, "tough": {}, "text": "Moves only when not watched. Keep your eyes on it."},
	"brute": {"name": "Bone Hauler", "hp": 210.0, "size": 1.6, "speed": 2.8, "bite": 32.0, "radius": 0.8, "body": "cat",
		"weak": {"blade": 1.5, "blast": 1.3}, "tough": {"shot": 0.6, "bullet": 0.8}, "text": "Slow, until it charges. Step aside and cut at it."},
	"howler": {"name": "Howler", "hp": 70.0, "size": 1.1, "speed": 4.6, "bite": 14.0, "radius": 0.5, "body": "cat",
		"weak": {"bullet": 1.5}, "tough": {"fire": 0.6}, "text": "Stands back and screams. The cry hurts and drives the others on."},
	"bloater": {"name": "Ember Sack", "hp": 30.0, "size": 1.15, "speed": 2.4, "bite": 0.0, "radius": 0.55,
		"weak": {"bullet": 1.5}, "tough": {"blade": 0.5}, "text": "Bursts into fire when it reaches you, or when it dies. Shoot it far off."},
	"lurker": {"name": "Dune Lurker", "hp": 80.0, "size": 1.0, "speed": 6.0, "bite": 24.0, "radius": 0.5, "body": "cat",
		"weak": {"shot": 1.4}, "tough": {"bullet": 0.7}, "text": "Swims under the sand and rises at your feet."},
	# Not lesser forms: men and the dead, with bodies of their own (see FoeBody)
	"unlit_gun": {"name": "Unlit Gunman", "hp": 60.0, "size": 1.0, "speed": 4.2, "bite": 9.0, "radius": 0.45, "body": "model", "role": "gun", "head_y": 0.62, "plate": 30.0,
		"weak": {"bullet": 1.2, "blade": 1.3}, "tough": {}, "text": "One of those who put out the beacons. Keeps its distance and shoots. Close in, or out-shoot it."},
	"unlit_blade": {"name": "Unlit Blade", "hp": 85.0, "size": 1.0, "speed": 5.0, "bite": 20.0, "radius": 0.45, "body": "model", "role": "melee", "head_y": 0.65, "plate": 50.0,
		"weak": {"blast": 1.4}, "tough": {}, "text": "Guards against shots from the front. Strike when it swings, or turn its blade with your own guard."},
	"unlit_brute": {"name": "Unlit Breaker", "hp": 200.0, "size": 1.3, "speed": 3.4, "bite": 34.0, "radius": 0.6, "body": "model", "role": "melee", "head_y": 0.95, "plate": 120.0,
		"weak": {"blade": 1.3}, "tough": {"shot": 0.8}, "text": "A great maul, a slow swing, and thick plate. Step out of the swing, then strike."},
	"hollow": {"name": "The Hollowed", "hp": 55.0, "size": 1.0, "speed": 2.4, "bite": 15.0, "radius": 0.45, "body": "model", "role": "melee", "head_y": 0.7,
		"weak": {"fire": 1.8, "shot": 1.2}, "tough": {}, "text": "Pilgrims the night took. Slow, and never alone."},
	"saltbone": {"name": "Salt-Bones", "hp": 40.0, "size": 0.9, "speed": 6.0, "bite": 13.0, "radius": 0.4, "body": "model", "role": "melee", "head_y": 0.62,
		"weak": {"blade": 1.6, "blast": 1.5, "shot": 1.3}, "tough": {"bullet": 0.6}, "text": "Bones the salt kept. Quick, and bullets slip through them. Use shot or the blade."},
	"vigil": {"name": "Lost Vigil", "hp": 70.0, "size": 1.0, "speed": 3.4, "bite": 12.0, "radius": 0.5, "body": "model", "role": "float", "head_y": 0.5,
		"weak": {"fire": 1.6, "blade": 1.6}, "tough": {"bullet": 0.5, "shot": 0.6}, "text": "A beacon-keeper who never left the dark. It drifts through, and steals warmth."},
	"warden": {"name": "Gravewarden", "hp": 260.0, "size": 1.4, "speed": 3.0, "bite": 30.0, "radius": 0.7, "body": "model", "role": "melee", "head_y": 1.1,
		"weak": {"fire": 1.4}, "tough": {"bullet": 0.8}, "text": "It keeps the Hollowed. Where it walks, more of them rise."},
	# 0.7: more of the waste's foes. Each has one thing to learn about it.
	"unlit_mark": {"name": "Unlit Marksman", "hp": 55.0, "size": 1.0, "speed": 3.8, "bite": 24.0, "radius": 0.45, "body": "model", "role": "gun", "head_y": 0.62,
		"sight": 75.0, "burst": 1, "aim": 1.4, "mag": 5, "aimed": 0.55,
		"weak": {"bullet": 1.2, "blade": 1.5}, "tough": {}, "text": "Shoots from far off, one careful shot at a time. Watch for the glint, then move."},
	"unlit_flame": {"name": "Unlit Firebrand", "hp": 75.0, "size": 1.0, "speed": 5.2, "bite": 14.0, "radius": 0.45, "body": "model", "role": "melee", "head_y": 0.65,
		"burn": 4.0, "weak": {"shot": 1.3}, "tough": {"fire": 0.2}, "text": "Its blade is lit. A cut sets you burning for a while."},
	"deacon": {"name": "Pale Deacon", "hp": 110.0, "size": 1.0, "speed": 4.6, "bite": 18.0, "radius": 0.45, "body": "model", "role": "melee", "head_y": 0.7,
		"drain": 1.0, "weak": {"fire": 1.8, "blade": 1.3}, "tough": {"bullet": 0.8}, "text": "It walks only by night, and every wound it gives closes its own."},
	"drowned": {"name": "Tar-Drowned", "hp": 70.0, "size": 1.0, "speed": 2.8, "bite": 12.0, "radius": 0.45, "body": "model", "role": "melee", "head_y": 0.7,
		"slow": 3.0, "weak": {"fire": 2.0}, "tough": {"bullet": 0.8, "shot": 0.8}, "text": "Risen from the marsh, still dripping. Its grip leaves tar on your legs and slows you."},
	"colossus": {"name": "Hollow Colossus", "hp": 480.0, "size": 1.8, "speed": 2.2, "bite": 42.0, "radius": 0.9, "body": "model", "role": "melee", "head_y": 1.6,
		"weak": {"blast": 1.6, "fire": 1.3}, "tough": {"bullet": 0.7, "blade": 0.8}, "text": "Many Hollowed, grown into one. Slow, and each blow lands like a falling wall. Keep away."},
	"wisp": {"name": "Ember Wisp", "hp": 45.0, "size": 0.9, "speed": 4.6, "bite": 8.0, "radius": 0.45, "body": "model", "role": "float", "head_y": 0.45,
		"burn": 3.0, "weak": {"shot": 1.6, "blade": 1.4}, "tough": {"fire": 0.0, "bullet": 0.7}, "text": "A live coal with a will. It drifts close and sets you burning."},
	"serpent": {"name": "Grey Wyrm", "hp": 420.0, "size": 2.2, "speed": 7.0, "bite": 26.0, "radius": 1.0,
		"weak": {"blast": 1.5, "bullet": 1.2}, "tough": {"fire": 0.3}, "text": "It lives under the Grey Sea and follows boats that stray far from land. Shoot it as it rises."},
	"lampeater": {"name": "Lamp-Eater", "hp": 1300.0, "size": 4.2, "speed": 5.2, "bite": 42.0, "radius": 1.8,
		"weak": {"blast": 1.4, "fire": 1.3}, "tough": {"shot": 0.6}, "text": "A huge pale thing of the deep sea. It rises under any boat that carries a lit lamp at night. Sail dark, and it does not come."},
	"knight": {"name": "Ashen Knight", "hp": 240.0, "size": 1.4, "speed": 3.2, "bite": 30.0, "radius": 0.7, "body": "model", "role": "melee", "head_y": 1.1, "plate": 160.0,
		"weak": {"blast": 1.3}, "tough": {"shot": 0.7}, "text": "Old iron, filled with ash. Its plate turns most things; piercing rounds or a blast will open it."},
	"saltrifle": {"name": "Salt Rifleman", "hp": 45.0, "size": 0.9, "speed": 4.4, "bite": 11.0, "radius": 0.4, "body": "model", "role": "gun", "head_y": 0.62,
		"weak": {"blade": 1.6, "blast": 1.5, "shot": 1.3}, "tough": {"bullet": 0.6}, "text": "A soldier the salt kept, still holding its rifle. Bullets slip through; use shot."},
}
## The kind of harm now being dealt. Set by whatever deals it, just before it does.
static var harm_kind := ""
static var harm_head := false    ## the blow is a head shot: it goes over any plate
static var harm_pierce := 1.0    ## the load's bite on plate: above 1 goes through, below 1 is stopped more
static var harm_heavy := false   ## the blow is a heavy, wound-up one: it breaks a foe's footing twice as fast
static var harm_arm := ""        ## the arm the blow came from, where it matters (the far arms)

## Poise: how much a foe can take before its footing breaks. Every blow wears it (blades more, heavy and
## blunt blows twice as much, a close shotgun blast a little more); left alone two seconds it comes back.
## Broken, the foe reels a moment and takes more harm: so a big foe is opened by heavy blows and teamwork,
## not by a stream of small ones.
const POISE_FRAC := 0.4
const POISE_FRAC_HEAVY := 0.6
const POISE_BACK := 2.0
const BROKEN_SECS := 1.5
const BROKEN_HARM := 1.3
var poise := -1.0
var _poise_t := 0.0
var _broken := 0.0
static var _smoke: Texture2D
static var _blot: Texture2D
static var blood_shown := 0   ## for the tests

## What each kind bleeds: the ash forms run dark, the gilded ones shed gold, the discs only spark.
const BLOOD := {
	"idol": Color(0.85, 0.65, 0.2), "saucer": Color(0.9, 0.85, 0.6), "mite": Color(0.9, 0.85, 0.6),
	"swarm": Color(0.95, 0.45, 0.1), "bloater": Color(0.95, 0.45, 0.1), "spider": Color(0.08, 0.06, 0.05),
	"unseen": Color(0.1, 0.1, 0.12), "spitter": Color(0.45, 0.5, 0.12),
}


## A puff of smoke (Kenney Particle Pack, CC0); a soft round dot if the picture is missing.
## Smoke and dust fade away as the eye comes into them, and take the light of the hour, so standing in a
## plume never fills the view with a lit sheet.
static func soften(m: BaseMaterial3D, near := 0.4, clear := 2.5) -> BaseMaterial3D:
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = near
	m.distance_fade_max_distance = clear
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.6
	return m


static func smoke_tex() -> Texture2D:
	if _smoke == null and ResourceLoader.exists("res://assets/textures/particles/smoke_a.png"):
		_smoke = load("res://assets/textures/particles/smoke_a.png")
	if _smoke == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
		_smoke = ImageTexture.create_from_image(img)
	return _smoke


## The great ones of the waste, one to a land, each in its lair. Each wears the body of a lesser kind
## ("base") grown vast, and has ways of its own: slam (the ground breaks around it), brood (it brings
## forth lesser forms), volley (a fan of bolts), blink (watched too long, it is suddenly elsewhere).
const BOSSES := {
	"boss_ash": {"name": "The Cinder Matron", "base": "elite", "hp": 2400.0, "size": 3.2, "speed": 3.2, "bite": 40.0, "radius": 1.6, "grow": 1.0, "ways": ["slam", "brood", "charge"], "brood": "swarm", "land": "ash"},
	"boss_dunes": {"name": "The Sand Choir", "base": "spitter", "hp": 1700.0, "size": 2.6, "speed": 4.0, "bite": 0.0, "radius": 1.3, "grow": 1.0, "ways": ["volley", "brood", "rain"], "brood": "spider", "land": "dunes"},
	"boss_salt": {"name": "The White Disc", "base": "saucer", "hp": 2000.0, "size": 1.0, "speed": 4.0, "bite": 0.0, "radius": 3.2, "grow": 2.0, "ways": ["volley", "rain", "charge"], "land": "salt"},
	"boss_forest": {"name": "The Long Watcher", "base": "unseen", "hp": 1600.0, "size": 1.3, "speed": 5.5, "bite": 50.0, "radius": 1.1, "grow": 1.9, "ways": ["blink", "charge"], "land": "forest"},
	"boss_basalt": {"name": "The Basalt Idol", "base": "idol", "hp": 2600.0, "size": 3.0, "speed": 2.2, "bite": 45.0, "radius": 1.5, "grow": 1.0, "ways": ["slam", "volley", "charge"], "land": "basalt"},
	"boss_marsh": {"name": "The Tar Mother", "base": "spider", "hp": 1800.0, "size": 0.8, "speed": 6.0, "bite": 35.0, "radius": 1.3, "grow": 2.6, "ways": ["brood", "rain", "charge"], "brood": "spider", "land": "marsh"},
	# The great ones of the far sea and the Far Shores (0.16): land is the isle they keep
	"boss_quiet": {"name": "The Archivist", "base": "unseen", "hp": 2600.0, "size": 1.5, "speed": 5.0, "bite": 46.0, "radius": 1.2, "grow": 2.1, "ways": ["line", "volley", "ambush"], "land": "quiet"},
	"boss_domes": {"name": "The Lantern-Breaker", "base": "unlit_brute", "hp": 2800.0, "size": 1.7, "speed": 4.2, "bite": 48.0, "radius": 1.1, "grow": 1.0, "ways": ["charge", "brood", "volley"], "brood": "tunnel_unlit", "land": "domes"},
	"boss_frost": {"name": "The Glacier Mother", "base": "idol", "hp": 3400.0, "size": 3.4, "speed": 2.0, "bite": 52.0, "radius": 1.7, "grow": 1.0, "ways": ["slam", "quake", "rain"], "land": "frost"},
	"boss_sun": {"name": "The Dry River", "base": "spitter", "hp": 2900.0, "size": 2.8, "speed": 4.2, "bite": 0.0, "radius": 1.4, "grow": 1.0, "ways": ["volley", "rain", "brood"], "brood": "canyon_strider", "land": "sun"},
	"boss_steppe": {"name": "The Spine-King", "base": "elite", "hp": 3200.0, "size": 3.4, "speed": 3.6, "bite": 50.0, "radius": 1.7, "grow": 1.0, "ways": ["charge", "slam", "brood"], "brood": "grass_stalker", "land": "steppe"},
}
const IDOL_CODES := ["goldspeeb", "marblespeeb", "jadespeeb", "obsidianspeeb", "fossilspeeb"]

var code := ""
var kind := "rusher"
var hp := 40.0
var level: Level
var head: LesserHead
var _legs: Array = []
var _leap_cd := 2.0
var spec: Dictionary
var variant := ""      ## a kin of the base form, if it is one (see VARIANTS)
var _sk := ""          ## its own scanned body, if it has one (see SCANS): a great one's, or its kin's
var _attack_cd := 1.0
var _flash := 0.0
var _alive := true
var _t := 0.0
var _knock := Vector3.ZERO
var _knock_on := Vector3.ZERO   ## the push already in the velocity, so it is added once and not every frame
var _shot_slow := 0.0            ## a heavy form under fire slows for a moment, and keeps coming
var _strafe := 1.0
var _disc: Node3D
var _beam: MeshInstance3D
var _mites: Array = []
var _cry_cd := 0.0
var boss := ""        ## the great one this is, or "" for a lesser form
var max_hp := 1.0
var hp_frac := 1.0    ## for puppets, as the host tells it
var _pat_i := 0          ## which step of its pattern a great one is on
var _combo: Array = []   ## the ways of the step now under way, one after another
var _gap := 3.0          ## the breath between steps: the time to strike back
var _reach_wait := 0.0
var _busy := 0.0      ## a great one winding up a way: it does nothing else meanwhile
var _charge_t := 0.0  ## running down a line
var _charge_dir := Vector3.ZERO
var _charge_hit := {}
var plate := 0.0      ## iron on the body: it soaks shots and cuts until it breaks
var _spent := 0.0     ## worn out after a charge or a slam: it stands still and takes more harm
var _wroth := false   ## past half its life: quicker in all its ways
var _brood: Array = []
var _watched_t := 0.0
var _bar: MeshInstance3D
var _bar_t := 0.0
static var _bar_mat: ShaderMaterial
var _shimmer: ShaderMaterial
var _seen := 0.08
var _watched := false
var _breath_cd := 0.0
# In a fellowship the host runs every form; the others see puppets that follow what the host tells them
var net_id := 0
var _wind := 0.0          ## a bite gathering: seconds until it lands. Step out of reach and it misses
var _wind_total := 0.0
var _stagger := 0.0       ## reeling from heavy harm: it neither moves on you nor bites
## What a foe of the waste has in mind: "calm" (keeps to its place), "search" (goes to look where
## something was heard or last seen), "hunt" (knows where you are) or "flee" (hurt, and running).
## Lesser forms and great ones always hunt; so do raiders sent against a base.
var mind := "hunt"
var _home := Vector3.ZERO
var _last_known := Vector3.ZERO
var _lost_t := 0.0
var _search_t := 0.0
var _look_t := 0.0
var _wander := Vector3.ZERO
var _fled := false
var _flee_t := 0.0
var _mark: Label3D
var _mark_t := 0.0
var _flank := 0.0         ## which side it swings out to as it closes
var _head_base := Vector3.ONE
## How long each kind gathers itself before it bites. The quick ones barely pause; the heavy ones show it.
const WINDUP := {"rusher": 0.38, "idol": 0.6, "swarm": 0.2, "mite": 0.18, "elite": 0.55, "spider": 0.3,
	"brute": 0.65, "howler": 0.4, "lurker": 0.3, "unlit_blade": 0.45, "unlit_brute": 0.85, "hollow": 0.6, "saltbone": 0.35, "vigil": 0.4, "warden": 0.8,
	"unlit_flame": 0.45, "deacon": 0.4, "drowned": 0.6, "colossus": 1.1, "wisp": 0.35, "knight": 0.8}
var puppet := false
var hidden := false   ## under the ground, or between places (FoeTraits): not seen, not struck
var credit := false
var last_hitter := 1
var heard_at := 0
var _net_to := Vector3.ZERO
var _net_body_y := 0.0
var _net_head := Vector2.ZERO
var _net_v := Vector3.ZERO


func setup(c: String, k: String, lvl: Level) -> LesserSpeeb:
	if BOSSES.has(k):
		boss = k
		k = BOSSES[k].base
	if VARIANTS.has(k):
		variant = k
		k = VARIANTS[k].base
	kind = k
	_sk = boss if SCANS.has(boss) else (variant if SCANS.has(variant) else "")
	code = IDOL_CODES[randi() % IDOL_CODES.size()] if k == "idol" else c
	level = lvl
	spec = BOSSES[boss] if boss != "" else KINDS[k]
	if variant != "":
		spec = KINDS[k].duplicate(true)
		for key in VARIANTS[variant]:
			spec[key] = VARIANTS[variant][key]
	hp = spec.hp * Game.difficulty_scale("hp")
	if boss != "":
		hp *= WCrowd.boss(lvl) if Game.wasteland else 1.0 + 0.6 * maxi(0, lvl.targets().size() - 1)
	max_hp = hp
	return self


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0 if puppet else (1 | 2 | WCat.SOLID_LAYER)
	_net_to = position
	heard_at = Time.get_ticks_msec()
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED if walks() else CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	if kind == "saucer":
		var cy := CylinderShape3D.new()
		cy.radius = spec.radius
		cy.height = 1.5
		cs.shape = cy
		cs.position.y = 0.15
	else:
		var s := SphereShape3D.new()
		s.radius = spec.radius
		cs.shape = s
	add_child(cs)
	head = LesserHead.new().setup(code, spec.size)
	head.position.y = 0.42 if kind == "saucer" else -0.05 * spec.size
	add_child(head)
	if kind == "idol":
		head.set_gild(1.0)
	if kind == "unseen":
		_build_unseen()
	if _sk != "":
		_build_scan(cs)
	elif kind == "spider":
		_build_spider()
	if variant == "box_cat":
		_build_box_cat()
	elif spec.get("body", "") == "cat" and _sk == "":
		_build_cat()
	elif kind in WINGED and _sk == "":
		_build_wings()
	if kind == "bloater":
		_build_sack()
	if variant == "bellwound":
		_build_serpent(Color(0.2, 0.16, 0.22), 2.6, 11)
	elif kind == "serpent":
		_build_serpent()
	if kind == "lampeater":
		_build_serpent(Color(0.78, 0.76, 0.7), 1.9, 7)
	if spec.get("body", "") == "model":
		_fb = FoeBody.make(kind)
		_fb.position.y = -float(spec.radius)
		add_child(_fb)
		head.visible = false
		head.position.y = float(spec.head_y)
		_flank = randf_range(-PI, PI)
		_ammo = 9
		if Game.wasteland and boss == "":
			mind = "calm"
			_home = global_position
			_wander = global_position
		plate = float(spec.get("plate", 0.0))
		# The knight's and the breaker's own armour is their plate: it soaks the same, with nothing drawn over it
		if plate > 0.0 and not kind in ["knight", "unlit_brute"]:
			_fb.wear_plate(false)
		_fit_shape(cs)
		# Once its arms and plate are on and it has found its stance, fitted again
		get_tree().create_timer(0.4, false).timeout.connect(func(): if is_instance_valid(cs): _fit_shape(cs))
	if kind != "unseen":
		_make_name()
	if kind == "saucer":
		_build_saucer()
	if boss != "":
		_grow_into_boss()
	elif spec.hp >= 30.0:
		_make_bar()
	if _fb:
		_lift_tags()
		# Its gear is fitted a moment later, so it is measured once more then
		get_tree().create_timer(0.5, false).timeout.connect(_lift_tags)
	if spec.has("tint"):
		_tint(spec.tint)
	_remember_head()
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_attack_cd = randf_range(1.0, 2.5)
	_cry_cd = randf_range(0.5, 2.0)
	if boss != "":
		level.sfx("great_roar", 6, global_position, 0.9)
		level.sfx("horror_deep", 0, global_position, 0.8)
	elif kind == "elite":
		level.sfx("roar", 2, global_position, 0.9)
	elif kind == "saucer":
		var hum := AudioStreamPlayer3D.new()
		var st = load("res://assets/audio/saucer_hum.ogg")
		st.loop = true
		hum.stream = st
		hum.unit_size = 14
		hum.volume_db = -2
		hum.autoplay = true
		add_child(hum)
	elif kind == "spider":
		_cry("critter_%d" % (randi() % 3), -2)
	elif kind == "unseen":
		level.sfx("unseen_call", 2, global_position, randf_range(0.9, 1.05))
		_cry_cd = randf_range(12.0, 20.0)
	elif kind != "mite":
		_cry("growl_%d" % (randi() % 3), -4)
	if not puppet and spec.has("trait"):
		_trait_start.call_deferred()


func _trait_start() -> void:
	if _alive:
		FoeTraits.start(self)


## Out of sight and out of reach (a Flicker between places, a Tunneller under the ground), or back.
func set_hidden(on: bool) -> void:
	hidden = on
	visible = not on
	if _alive:
		collision_layer = 0 if on else 2
	if on:
		_wind = 0.0
		_show_wind(-1.0)


## A cry from the lesser form, pitched by its size: the small shriek high, the great ones low.
func _remember_head() -> void:
	if head:
		_head_base = head.scale
	_flank = randf_range(-1.0, 1.0)


func _cry(sound: String, vol := 0.0) -> void:
	var pitch: float = clampf(1.0 / spec.size, 0.6, 1.7) * randf_range(0.85, 1.15)
	level.sfx(sound, vol, global_position, pitch)



func _physics_process(delta: float) -> void:
	if not _alive or level.player == null:
		return
	if _flinch != Vector2.ZERO:
		# Struck, it rocks away from the blow and comes back
		_flinch = _flinch.lerp(Vector2.ZERO, minf(1.0, delta * 9.0))
		if _flinch.length() < 0.004:
			_flinch = Vector2.ZERO
		rotation.x = _flinch.x
		rotation.z = _flinch.y
	FoeTraits.look(self, delta)
	if puppet:
		_puppet_tick(delta)
		return
	delta *= level.enemy_time
	_t += delta
	seen_t -= delta
	smoke_t -= delta
	# It hunts the nearest pilgrim still standing; with none, it waits
	var p: Node3D = level.nearest_target(global_position)
	var idle := p == null
	if idle:
		p = level.player
	# A form that falls from the world, or strays too far from it, is simply unmade
	if global_position.y < level.kill_y or (not idle and global_position.distance_to(p.global_position) > 90.0):
		die(false)
		return
	var target := p.global_position + Vector3(0, 1.3, 0)
	_rescue(delta, idle)
	var to := target - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	if not idle and not level.combat_frozen and FoeTraits.tick(self, delta, p, dist):
		velocity = Vector3.ZERO
		return
	var turn := 1.5 if kind == "idol" else 12.0
	head.rotation.y = lerp_angle(head.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * turn))
	head.rotation.x = -asin(clampf(dir.y, -0.6, 0.6)) * 0.6
	var want := Vector3.ZERO
	if _broken > 0.0:
		_broken -= delta
	_poise_t += delta
	if _poise_t > POISE_BACK and poise >= 0.0:
		poise = poise_max()
	if _stagger > 0.0:
		_stagger -= delta
		head.rotation.z = sin(_t * 18.0) * 0.25 * minf(1.0, _stagger * 2.0)
	elif head.rotation.z != 0.0:
		head.rotation.z = 0.0
	if _spent > 0.0:
		_spent -= delta
		head.rotation.x = 0.5 * minf(1.0, _spent * 2.0)
	if _charge_t > 0.0 and not level.combat_frozen:
		if boss != "":
			_check_wroth()
		_charge_tick(delta)
		return
	var frozen: bool = level.combat_frozen or idle or _stagger > 0.0 or _spent > 0.0 or _busy > 0.0
	if boss != "" and not level.combat_frozen and not idle and not level.completed:
		_boss_tick(delta, p, dist)
	if _fb:
		_foe_move(delta, p, dist, dir, frozen)
		return
	if walks():
		_spider_move(delta, p, dist, frozen)
		return
	var speed: float = spec.speed * Game.difficulty_scale("speed") * (0.55 if _shot_slow > 0.0 else 1.0)
	if not frozen:
		match kind:
			"spitter":
				var side := dir.cross(Vector3.UP) * _strafe * 2.2
				if dist > 14.0:
					want = dir * speed + side
				elif dist < 8.0:
					want = -dir * speed * 0.9 + side
				else:
					want = side
				want.y += (target.y + 1.5 - global_position.y) * 1.2
			"saucer":
				var ang := _t * 0.3 * _strafe
				var hover := p.global_position + Vector3(cos(ang) * 11.0, 7.5, sin(ang) * 11.0)
				want = (hover - global_position).limit_length(speed)
			"elite":
				want = dir * speed if dist > 4.0 else dir.cross(Vector3.UP) * _strafe * 3.0
				want.y += (target.y + 0.8 - global_position.y) * 1.0
			"serpent", "lampeater":
				# It swims at the surface, then rears up out of the water to strike
				want = dir * speed * (1.0 if dist > 5.0 else 0.4)
				var sy := WIsles.SEA_Y + 0.4 if dist > 7.0 else target.y - 0.8
				want.y = (sy - global_position.y) * 2.5
			"unseen":
				# Still as a post while it is watched; when the eye leaves it, it comes on fast
				var w := dist < 30.0 and _is_watched(p)
				if w and not _watched and dist < 22.0:
					level.sfx("unseen_click", -3, global_position, randf_range(0.9, 1.1))
				_watched = w
				if not w:
					want = dir * speed * (1.7 if dist > 9.0 else 1.0)
					want.y = (target.y - 0.2 - global_position.y) * 2.0
			_:
				# They come at you from the sides as well as the front, closing straight only near
				var d2 := dir.rotated(Vector3.UP, _flank * 0.7) if dist > 7.0 and (not Game.wasteland or WRules.flanks()) else dir
				want = d2 * speed
				want += dir.cross(Vector3.UP) * sin(_t * 2.0 + _strafe) * (2.5 if kind == "swarm" else 1.2)
	if kind == "unseen":
		_shade_tick(delta, dist)
		if _watched:
			velocity = Vector3.ZERO
	else:
		want.y += sin(_t * 2.6) * 0.4
	if kind == "serpent" or kind == "lampeater":
		_coil_tick()
	_shot_slow = maxf(0.0, _shot_slow - delta)
	velocity = (velocity - _knock_on).lerp(want, minf(1.0, delta * (8.0 if kind == "unseen" else 3.0))) + _knock
	_knock_on = _knock
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	var real_v := velocity
	velocity *= level.enemy_time
	move_and_slide()
	velocity = real_v
	if is_on_wall():
		velocity.y += 6.0 * delta * 10.0
		_claw_at_wall()
	_flash = maxf(0.0, _flash - delta * 5.0)
	head.set_flash(_flash)
	_bar_tick(delta)
	if frozen or level.completed or level.failing:
		return
	_attack_cd -= delta
	_cry_cd -= delta
	if kind == "unseen":
		_unseen_noise(delta, dist)
	# The forms scream as they close on him; a Box Cat screams high and loud the whole way in
	if variant == "box_cat" and _cry_cd <= 0.0 and dist < 45.0:
		level.sfx("shriek_%d" % (randi() % 4), 4, global_position, randf_range(1.9, 2.4))
		_cry_cd = randf_range(1.2, 2.6)
	elif _cry_cd <= 0.0 and dist < 16.0:
		match kind:
			"rusher", "swarm", "idol":
				_cry("shriek_%d" % (randi() % 4), 0 if kind != "swarm" else -6)
				_cry_cd = randf_range(3.5, 7.0)
			"mite":
				_cry("chitter", -4)
				_cry_cd = randf_range(1.5, 3.5)
			"elite":
				level.sfx("roar", 0, global_position, randf_range(0.85, 1.05))
				_cry_cd = randf_range(7.0, 11.0)
			"spitter":
				_cry("growl_%d" % (randi() % 3), -2)
				_cry_cd = randf_range(5.0, 9.0)
	if kind == "bloater" and dist < 2.4:
		last_hitter = 0   # it burst itself: no one slew it
		die(true)
		return
	var reach: float = 1.0 + spec.radius
	if kind == "unseen" and spec.bite > 0.0 and dist < reach and _attack_cd <= 0.0:
		# The Unseen gives no warning: its warning is that you looked away
		_attack_cd = 0.9
		level.sfx("bite", -2, global_position)
		level.sfx("unseen_scream", 2, global_position, randf_range(0.9, 1.1))
		_seen = 1.0
		level.hurt_target(p, spec.bite, global_position)
		_knock = -dir * 6.0
	elif spec.bite > 0.0 and kind != "unseen":
		_bite_tick(delta, p, dist, dir, reach, 1.3 if kind == "idol" else 0.9, spec.bite)
	if kind == "saucer":
		_disc.rotation.y += delta * 2.5
		_mites = _mites.filter(func(m): return is_instance_valid(m) and m.is_alive())
		if _attack_cd <= 0.0:
			_attack_cd = randf_range(5.0, 6.5)
			if _mites.size() < 6:
				_let_down()
		return
	if (kind == "spitter" or kind == "elite") and _attack_cd <= 0.0 and dist < 26.0 and _can_see(target):
		_attack_cd = randf_range(1.5, 2.3)
		if kind == "elite":
			for k in [-0.2, 0.0, 0.2]:
				_spit(global_position + (target - global_position).rotated(Vector3.UP, k))
		else:
			_spit(target)


var _coils: Array = []


## A long dark body trailing behind the face, in coils that rise and fall as it swims.
var _coil_gap := 1.3


func _build_serpent(col := Color(0.14, 0.17, 0.17), girth := 1.0, segs := 9) -> void:
	_coil_gap = 1.3 * girth
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.4
	m.metallic = 0.2
	for i in segs:
		var seg := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := 0.9 * girth * (1.0 - i * 0.08)
		sm.radius = r
		sm.height = r * 2.0
		seg.mesh = sm
		seg.material_override = m
		add_child(seg)
		seg.position = Vector3(0, -0.3, -_coil_gap * (i + 1))
		_coils.append(seg)
	head.set_flash(0.0)


func _coil_tick() -> void:
	var back := -Vector3(velocity.x, 0, velocity.z).normalized() if Vector2(velocity.x, velocity.z).length() > 0.3 else Vector3(0, 0, -1)
	for i in _coils.size():
		var seg: MeshInstance3D = _coils[i]
		var along := back * _coil_gap * (i + 1)
		seg.position = Vector3(along.x, -0.3 + sin(_t * 3.0 - i * 0.8) * 0.6 - i * 0.05, along.z)


## Eight legs about a dark abdomen, the head carried low in front.
func _build_spider() -> void:
	head.position = Vector3(0, 0.1, 0.25)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = head.fur.darkened(0.85)
	dark.roughness = 0.5
	dark.metallic = 0.2
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.8
	body.mesh = sm
	body.material_override = dark
	body.position = Vector3(0, 0.15, -0.5)
	body.scale = Vector3(1.0, 0.8, 1.25)
	add_child(body)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.08, 0.04)
	var mark := MeshInstance3D.new()
	var mm := PrismMesh.new()
	mm.size = Vector3(0.22, 0.2, 0.05)
	mark.mesh = mm
	mark.material_override = red
	mark.position = Vector3(0, 0.5, -0.55)
	mark.rotation.x = -PI / 2
	add_child(mark)
	for side in [-1.0, 1.0]:
		for i in 4:
			var hip := Node3D.new()
			hip.position = Vector3(side * 0.22, 0.15, 0.05 - i * 0.22)
			add_child(hip)
			var knee := Vector3(side * 0.55, 0.38, 0.28 - i * 0.18)
			var foot := knee + Vector3(side * 0.35, -1.05, 0.16 - i * 0.1)
			_segment(hip, Vector3.ZERO, knee, 0.05, dark)
			_segment(hip, knee, foot, 0.035, dark)
			_legs.append({"pivot": hip, "phase": i * 1.6 + (0.0 if side > 0 else PI)})


func _segment(parent: Node3D, from: Vector3, to: Vector3, r: float, m: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r * 0.7
	c.bottom_radius = r
	c.height = from.distance_to(to)
	c.radial_segments = 6
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	var y := (to - from).normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length() < 0.1:
		x = Vector3.RIGHT
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (from + to) * 0.5)
	parent.add_child(mi)


func walks() -> bool:
	return kind == "spider" or spec.get("body", "") == "cat" or (spec.get("body", "") == "model" and spec.get("role", "") != "float")


var _buried := 0.0       ## a lurker under the sand: 1 hidden, 0 risen
var _fb: FoeBody         ## the body of a foe that is not a lesser form
var _ammo := 9           ## a gunman's rounds before it must reload
var _aim := 0.0          ## a gunman drawing a bead: seconds left before it fires
var _burst := 0          ## shots left in the burst
var _guard := false      ## an Unlit Blade with its blade up: shots from the front are turned
var _charge := 0.0       ## a hauler's charge, seconds left
var _howl_cd := 4.0
var seen_t := 0.0        ## shown by a flare or the censer: its name stands over it and it is marked
var smoke_t := 0.0       ## in the censer's smoke: it chokes and slows, and cannot hide under the sand


## A flare's light or the censer's smoke shows it for a while; smoke also chokes it.
func reveal(secs: float, smoke := false) -> void:
	seen_t = maxf(seen_t, secs)
	if smoke:
		smoke_t = maxf(smoke_t, secs)


## Those that walk run the ground, legs rippling, and spring when near. Each kind has its own way.
func _spider_move(delta: float, p: Node3D, dist: float, frozen: bool) -> void:
	var flat := p.global_position - global_position
	flat.y = 0
	var fd := flat.length()
	var dir := flat / maxf(fd, 0.01)
	var speed: float = spec.speed * Game.difficulty_scale("speed") * (0.65 if smoke_t > 0.0 else 1.0) * (0.55 if _shot_slow > 0.0 else 1.0)
	_shot_slow = maxf(0.0, _shot_slow - delta)
	var on_floor := is_on_floor()
	var cat := kind != "spider"
	if _charge <= 0.0:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * (10.0 if kind != "brute" else 4.0)))
	if not frozen:
		var d2 := dir.rotated(Vector3.UP, _flank * 0.7) if fd > 7.0 and kind in ["rusher", "spider", "idol"] and (not Game.wasteland or WRules.flanks()) else dir
		var want := d2 * speed + dir.cross(Vector3.UP) * sin(_t * 3.0 + _strafe) * (2.5 if not cat else 1.0)
		match kind:
			"howler":
				# It keeps to the middle distance, where its cry carries
				if fd < 9.0:
					want = -dir * speed * 0.8 + dir.cross(Vector3.UP) * _strafe * 2.0
				elif fd < 15.0:
					want = dir.cross(Vector3.UP) * _strafe * 2.5
			"lurker":
				var under := fd > 6.0 and seen_t <= 0.0
				_buried = move_toward(_buried, 1.0 if under else 0.0, delta * (1.5 if under else 3.0))
				if under:
					want = dir * speed * 1.3
			"brute":
				if _charge > 0.0:
					_charge -= delta
					want = Vector3(sin(rotation.y), 0, cos(rotation.y)) * speed * 4.2
		if on_floor:
			velocity.x = lerpf(velocity.x, want.x, minf(1.0, delta * 8.0))
			velocity.z = lerpf(velocity.z, want.z, minf(1.0, delta * 8.0))
		_leap_cd -= delta
		if kind == "brute":
			if on_floor and fd < 16.0 and fd > 4.0 and _leap_cd <= 0.0 and _charge <= 0.0:
				_leap_cd = randf_range(4.0, 6.0)
				_charge = 1.1
				level.sfx("roar", 0, global_position, 0.75)
		elif kind in ["rusher", "spider", "lurker", "elite"]:
			if on_floor and fd < (15.0 if spec.get("trait", "") == "leap" else 7.5) and fd > 2.0 and _leap_cd <= 0.0 and _buried < 0.5 and _wind <= 0.0:
				_leap_cd = randf_range(2.0, 3.5) * (1.6 if kind == "elite" else 1.0)
				velocity = dir * 11.0 + Vector3(0, 6.5, 0)
				_cry("spider_hiss" if kind == "spider" else "shriek_%d" % (randi() % 4), 0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
	velocity.y -= 22.0 * delta
	velocity += _knock - _knock_on
	_knock_on = _knock
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	var real_v := velocity
	velocity *= level.enemy_time
	move_and_slide()
	velocity = real_v
	if is_on_wall():
		_claw_at_wall()
		_charge = 0.0
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	# Spiders climb what stands in their way; cats scramble over the low things
	if is_on_wall() and not frozen:
		velocity.y = 4.5 if not cat else 3.0
	# The legs ripple with its pace
	var pace := Vector2(velocity.x, velocity.z).length()
	for leg in _legs:
		var ph: float = _t * (6.0 + pace * 2.0) + leg.phase
		if cat:
			leg.pivot.rotation.x = sin(ph) * minf(0.7, 0.1 + pace * 0.08)
		else:
			var amp := minf(0.4, 0.08 + pace * 0.05)
			leg.pivot.rotation.y = sin(ph) * amp
			leg.pivot.rotation.x = maxf(0.0, cos(ph)) * amp * -0.6
	if _scan:
		_scan.position.y = (-float(spec.radius) + _lift) / (float(spec.get("grow", 1.0)) if boss != "" else 1.0) - _buried * 1.6 * float(SCANS[_sk][1])
		_scan.visible = _buried < 0.95
		_scan_tick(pace)
		if _dust:
			_dust.emitting = _buried > 0.3 and pace > 1.0
	if _box:
		var hop := absf(sin(_t * 13.0)) * minf(1.0, pace / 5.0)
		_box.position.y = -float(spec.radius) + hop * 0.14
		_box.rotation.z = sin(_t * 13.0) * 0.12 * minf(1.0, pace / 5.0)
	if _tail:
		_tail.rotation.x = -0.6 + sin(_t * 2.2) * 0.25
		_tail.rotation.y = sin(_t * 1.7) * 0.4
	_pan_tick(pace)
	if _body_node:
		_body_node.position.y = _lift - _buried * 1.6 * spec.size
		_body_node.visible = _buried < 0.95
		if _dust:
			_dust.emitting = _buried > 0.3 and pace > 1.0
	head.rotation.y = 0.0
	head.rotation.x = -asin(clampf((p.global_position.y + 1.3 - global_position.y) / maxf(dist, 0.1), -0.6, 0.6)) * 0.5
	_flash = maxf(0.0, _flash - delta * 5.0)
	head.set_flash(_flash)
	_bar_tick(delta)
	if frozen or level.completed or level.failing:
		return
	_attack_cd -= delta
	_cry_cd -= delta
	if _cry_cd <= 0.0 and dist < 18.0 and _buried < 0.5:
		_cry_cd = randf_range(1.2, 3.0) if not cat else randf_range(3.5, 7.0)
		if cat:
			_cry("growl_%d" % (randi() % 3) if randf() < 0.5 else "shriek_%d" % (randi() % 4), -2)
		else:
			_cry("skitter" if randf() < 0.5 else "critter_%d" % (randi() % 3), -2)
	if kind == "howler":
		_howl_cd -= delta
		if _howl_cd <= 0.0 and dist < 18.0 and _can_see(p.global_position + Vector3(0, 1.3, 0)):
			_howl_cd = randf_range(5.0, 7.0)
			_howl(p)
	if kind == "elite" and _attack_cd <= 0.0 and dist < 22.0 and dist > 4.0 and _can_see(p.global_position + Vector3(0, 1.3, 0)):
		_attack_cd = randf_range(2.0, 3.0)
		for k in [-0.2, 0.0, 0.2]:
			_spit(global_position + Vector3(0, 0.8, 0) + (p.global_position + Vector3(0, 1.3, 0) - global_position).rotated(Vector3.UP, k))
		return
	var reach: float = 1.2 + spec.radius
	if _charge > 0.0:
		# A hauler's charge strikes as it comes, with no pause: the roar before it was the warning
		if dist < reach and _attack_cd <= 0.0:
			_attack_cd = 1.4
			level.sfx("bite", -2, global_position)
			level.hurt_target(p, spec.bite * 1.8, global_position)
			if p == level.player:
				level.player.velocity += dir * 14.0 + Vector3(0, 5, 0)
			_charge = 0.0
			_knock = -dir * 5.0
	elif _buried < 0.3:
		_bite_tick(delta, p, dist, dir, reach, 0.8 if kind != "brute" else 1.4, spec.bite)


## The howler's cry: it hurts what hears it close, and the forms near it come on faster a while.
func _howl(p: Node3D) -> void:
	level.sfx("roar", 2, global_position, 1.35)
	head.set_flash(1.0)
	var d := global_position.distance_to(p.global_position)
	if d < 14.0:
		level.hurt_target(p, 10.0 * (1.0 - d / 16.0) + 4.0, global_position)
		if p == level.player:
			level.player.shake(0.6)
	for e in level.enemies:
		if is_instance_valid(e) and e != self and e.is_alive() and e.global_position.distance_to(global_position) < 16.0:
			e._knock += (p.global_position - e.global_position).normalized() * 3.0
			e._leap_cd = 0.0


var _legs_m: Material
var _tail: Node3D
var _body_node: Node3D
var _lift := 0.0
var _dust: CPUParticles3D


## Four legs and a long back under the head, a tail that will not keep still: a cat gone wrong.
## The Box Cat ("Box Cat" by mellting, CC-BY 4.0): a model of its own that hops as it runs.
var _box: Node3D

func _build_box_cat() -> void:
	head.visible = false
	var path := "res://assets/models/foes/box_cat/box_cat.glb"
	if not ResourceLoader.exists(path):
		_build_cat()
		head.visible = true
		return
	_box = Node3D.new()
	var m: Node3D = (load(path) as PackedScene).instantiate()
	# Measured through the model's own nodes (its file shrinks it a hundredfold), then brought to about a metre
	if not _scan_bounds.has(path):
		var bb := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = Arms._chain(mi, m) * (mi as MeshInstance3D).get_aabb()
			bb = a if first else bb.merge(a)
			first = false
		_scan_bounds[path] = bb
	var b: AABB = _scan_bounds[path]
	var k := 0.97 * float(spec.size) / 0.55 / maxf(b.size.y, 0.0001)
	var c0 := b.get_center()
	# Turned about to face the way it runs, feet on the ground
	m.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * k), Vector3(-c0.x * k, -b.position.y * k, -c0.z * k))
	_box.add_child(m)
	_box.position.y = -float(spec.radius)
	add_child(_box)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## A body of its own, scanned, in place of the drawn one: brought to its height, feet on the ground, walking as it goes.
var _scan: Node3D
var _scan_anim: AnimationPlayer

var _scan_bone := -1
var _scan_skel: Skeleton3D
var _scan_walk := ""
var _scan_idle := ""
var _scan_gait := ""

func _build_scan(cs: CollisionShape3D) -> void:
	var sc: Array = SCANS[_sk]
	if not ResourceLoader.exists(sc[0]):
		return
	var opt: Dictionary = sc[5] if sc.size() > 5 else {}
	var with_head := sc.size() > 5
	head.visible = with_head
	for c in get_children():
		if c is MeshInstance3D:   # the unseen's own bent-light body gives way
			(c as MeshInstance3D).visible = false
	var m: Node3D = (load(sc[0]) as PackedScene).instantiate()
	if not _scan_bounds.has(sc[0]):
		var bb := AABB()
		var first := true
		var sks := m.find_children("*", "Skeleton3D", true, false)
		if opt.get("bone_bounds", false) and not sks.is_empty():
			# Its skin's stored bounds are not where it stands: measured by skinning its points as they rest
			bb = _skinned_bounds(m)
		else:
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				var a: AABB = Arms._chain(mi, m) * (mi as MeshInstance3D).get_aabb()
				bb = a if first else bb.merge(a)
				first = false
		_scan_bounds[sc[0]] = bb
	var b: AABB = _scan_bounds[sc[0]]
	# A great one is grown afterwards (see _grow_into_boss); its shape for collision is set here at full size
	var g := float(spec.get("grow", 1.0)) if boss != "" else 1.0
	var tall := float(sc[1]) * float(spec.size)
	var k := tall / maxf(b.size.y, 0.001)
	if opt.get("by_long", false):
		# A long thing (the worm) is sized by its length; its height is what that leaves
		k = tall / maxf(maxf(b.size.x, b.size.z), 0.001)
		tall = b.size.y * k
	var c0 := b.get_center()
	# A scan faces +Z, as a form does when it walks
	var turn := Basis(Vector3.UP, float(opt.get("turn", 0.0)))
	m.transform = Transform3D(turn.scaled(Vector3.ONE * k), turn * Vector3(-c0.x * k, -b.position.y * k, -c0.z * k))
	_scan = Node3D.new()
	_scan.add_child(m)
	_scan.position.y = -float(spec.radius) / g
	add_child(_scan)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if opt.has("tint") and mm.mesh:
			# Tinted to its land: ash, sand, basalt, tar
			for si in mm.mesh.get_surface_count():
				var sm := mm.mesh.surface_get_material(si)
				if sm is StandardMaterial3D:
					var t := (sm as StandardMaterial3D).duplicate() as StandardMaterial3D
					t.albedo_color = t.albedo_color * (opt.tint as Color)
					mm.set_surface_override_material(si, t)
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_scan_anim = aps[0]
		var names := _scan_anim.get_animation_list()
		_scan_walk = str(sc[2]) if sc[2] is String and str(sc[2]) != "" else str(names[int(sc[2]) if sc[2] is int else 0])
		_scan_idle = str(opt.get("idle", ""))
		for an in [_scan_walk, _scan_idle]:
			if an != "" and _scan_anim.has_animation(an):
				_scan_anim.get_animation(an).loop_mode = Animation.LOOP_LINEAR
		_scan_gait = ""
		_scan_play(_scan_walk)
		_scan_anim.seek(randf() * _scan_anim.get_animation(_scan_walk).length, true)
	var hp: Vector2 = sc[4]
	head.position = Vector3(0, tall * hp.x - float(spec.radius), tall * hp.y)
	if with_head:
		head.scale = Vector3.ONE * float(opt.get("head_k", 0.6))
	if opt.has("bone"):
		var sks := m.find_children("*", "Skeleton3D", true, false)
		if not sks.is_empty():
			_scan_skel = sks[0]
			_scan_bone = _scan_skel.find_bone(str(opt.bone))
			if _scan_bone >= 0 and opt.get("shrink", false):
				_scan_skel.set_bone_pose_scale(_scan_bone, Vector3.ONE * 0.05)
				# Its own head's scale gives way in every clip, so the shrink holds
				var hpath := "%s:%s" % [str(_scan_anim.get_node(_scan_anim.root_node).get_path_to(_scan_skel)), str(opt.bone)] if _scan_anim else ""
				if _scan_anim:
					for an in _scan_anim.get_animation_list():
						var a := _scan_anim.get_animation(an)
						for t in range(a.get_track_count() - 1, -1, -1):
							if a.track_get_type(t) == Animation.TYPE_SCALE_3D and str(a.track_get_path(t)) == hpath:
								a.remove_track(t)
	# Struck anywhere up its height, not only about the feet
	var r := float(spec.radius)
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = maxf(2.0 * r, tall * g * (0.75 if hp.y > 0.3 else 1.0))
	cs.shape = cap
	cs.position.y = -r + cap.height * 0.5


## The true bounds of a skinned model at rest: each point carried by its bones, as the skin would draw it.
static func _skinned_bounds(m: Node3D) -> AABB:
	var bb := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.mesh == null:
			continue
		var sk := mm.get_node_or_null(mm.skeleton) as Skeleton3D
		var skin := mm.skin
		var to_m := Arms._chain(mm, m)
		for si in mm.mesh.get_surface_count():
			var arr: Array = mm.mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var wts = arr[Mesh.ARRAY_WEIGHTS]
			var per := 4 if bones == null or v.is_empty() else (bones as Array).size() / v.size() if bones is Array else (bones as PackedInt32Array).size() / v.size()
			for i in range(0, v.size(), 3):
				var p: Vector3 = v[i]
				var q := to_m * p
				if sk and skin and bones != null and wts != null:
					var sum := Vector3.ZERO
					var wsum := 0.0
					for j in per:
						var bi: int = bones[i * per + j]
						var wj: float = wts[i * per + j]
						if wj <= 0.0 or bi >= skin.get_bind_count():
							continue
						var bone := skin.get_bind_bone(bi)
						if bone < 0:
							bone = sk.find_bone(skin.get_bind_name(bi))
						if bone < 0:
							continue
						sum += (sk.get_bone_global_rest(bone) * skin.get_bind_pose(bi) * p) * wj
						wsum += wj
					if wsum > 0.0:
						q = Arms._chain(sk, m) * (sum / wsum)
				bb = AABB(q, Vector3.ZERO) if first else bb.expand(q)
				first = false
	return bb


func _scan_play(an: String) -> void:
	if _scan_anim and an != "" and an != _scan_gait and _scan_anim.has_animation(an):
		_scan_gait = an
		_scan_anim.play(an, 0.3)


## Its body walks with its pace (or stands, if it has a standing clip), and its Speeb's head rides its neck.
func _scan_tick(pace: float) -> void:
	if _scan_anim:
		var walk: float = SCANS[_sk][3]
		if _scan_idle != "" and pace < 0.3:
			_scan_play(_scan_idle)
			_scan_anim.speed_scale = 1.0
		else:
			_scan_play(_scan_walk)
			_scan_anim.speed_scale = clampf(pace / walk, 0.35, 2.2) if walk > 0.0 else 1.0
	if _scan_skel and _scan_bone >= 0:
		var opt: Dictionary = SCANS[_sk][5]
		var at: Vector3 = (_scan_skel.global_transform * _scan_skel.get_bone_global_pose(_scan_bone)).origin
		head.position = to_local(at) + (opt.get("head_off", Vector3.ZERO) as Vector3) * float(SCANS[_sk][1]) * float(spec.size)


func _build_cat() -> void:
	var s: float = spec.size
	var coat: Color = head.coat if head.coat != Color() else head.fur.darkened(0.8)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = coat
	fur.roughness = 0.95
	fur.rim_enabled = true
	fur.rim = 0.25
	fur.rim_tint = 0.0
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color(0.25, 0.04, 0.02)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.28, 0.08)
	ember.emission_energy_multiplier = 1.4
	_legs_m = fur
	_body_node = Node3D.new()
	add_child(_body_node)
	head.reparent(_body_node, false)
	head.position = Vector3(0, 0.15 * s, 0.55 * s)
	head.scale = Vector3.ONE * 0.72
	var torso := _panther_body(s, coat)
	# Cracks of ember along the spine: the mark of a lesser form
	for i in 4:
		var c := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.03, 0.16) * s
		c.mesh = bm
		c.material_override = ember
		c.position = Vector3(sin(i * 2.3) * 0.06 * s, 0.25 * s, (0.2 - i * 0.2) * s)
		c.rotation.y = sin(i * 1.7) * 0.5
		_body_node.add_child(c)
	if kind == "idol":
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(0.85, 0.66, 0.3)
		gold.metallic = 0.9
		gold.roughness = 0.3
		for mi in torso.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = gold
		fur = gold
	if kind == "brute":
		# Plates of bone over the shoulders
		var bone := StandardMaterial3D.new()
		bone.albedo_color = Color(0.82, 0.78, 0.68)
		for sx in [-1.0, 1.0]:
			var pl := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.25, 0.1, 0.45) * s
			pl.mesh = bm
			pl.material_override = bone
			pl.position = Vector3(sx * 0.18 * s, 0.22 * s, 0.2 * s)
			pl.rotation.z = sx * 0.5
			_body_node.add_child(pl)
	if kind == "lurker":
		_dust = CPUParticles3D.new()
		_dust.amount = 24
		_dust.lifetime = 0.9
		_dust.emitting = false
		_dust.direction = Vector3.UP
		_dust.spread = 40.0
		_dust.initial_velocity_min = 1.0
		_dust.initial_velocity_max = 2.5
		_dust.gravity = Vector3(0, -4, 0)
		var dq := QuadMesh.new()
		dq.size = Vector2.ONE * 0.3
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		dm.albedo_texture = smoke_tex()
		dm.albedo_color = Color(0.7, 0.6, 0.45, 0.6)
		soften(dm)
		dq.material = dm
		_dust.mesh = dq
		_dust.position.y = -0.6 * s
		add_child(_dust)
		_buried = 1.0
	# It stands on its legs: lift the body so the feet meet the ground below the round of its collision
	_lift = 0.74 * s - float(spec.radius)
	_body_node.position.y = _lift
	if puppet:
		_buried = 0.0


## The body of a lesser cat ("black panther" by kenchoo, CC-BY 4.0), in the coat of its face: its own head
## shrinks away inside the lesser's, which rides on its neck. The one long take it came with is cut into
## standing, walking and stalking.
const PANTHER := "res://assets/models/foes/panther/panther.glb"
const PANTHER_HEAD := "Bip001 Head_23"
const PANTHER_CUTS := {"idle": [0.2, 5.5], "walk": [7.4, 8.933], "stalk": [12.467, 13.267]}
const PANTHER_K := 1.53       ## its size to the lesser's: back at about a quarter of the size over the middle
const PANTHER_WALK := 1.3     ## how fast its walk goes over the ground, at size 1
static var _panther_cuts: AnimationLibrary
var _pan_skel: Skeleton3D
var _pan_anim: AnimationPlayer
var _pan_head := -1
var _pan_gait := ""


static func _cut_panther(an: Animation, head_path: String) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for cut in PANTHER_CUTS:
		var r: Array = PANTHER_CUTS[cut]
		var out := Animation.new()
		out.length = float(r[1]) - float(r[0])
		out.loop_mode = Animation.LOOP_LINEAR
		for t in an.get_track_count():
			var ty := an.track_get_type(t)
			if ty == Animation.TYPE_SCALE_3D and str(an.track_get_path(t)) == head_path:
				continue
			if ty not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
				continue
			var nt := out.add_track(ty)
			out.track_set_path(nt, an.track_get_path(t))
			var step := 1.0 / 30.0
			var x := 0.0
			while x <= out.length + 0.0001:
				var at := float(r[0]) + x
				match ty:
					Animation.TYPE_POSITION_3D: out.position_track_insert_key(nt, x, an.position_track_interpolate(t, at))
					Animation.TYPE_ROTATION_3D: out.rotation_track_insert_key(nt, x, an.rotation_track_interpolate(t, at))
					Animation.TYPE_SCALE_3D: out.scale_track_insert_key(nt, x, an.scale_track_interpolate(t, at))
				x += step
		lib.add_animation(cut, out)
	return lib


## The drifting heads fly on a bat's wings ("Bat animated character" by GoldGryphon, CC-BY 4.0): the bat's own
## head is shrunk away and the lesser's head sits where it was, the wings beating behind it.
const WINGED := ["spitter", "swarm", "mite"]
const BAT := "res://assets/models/foes/bat/bat.glb"
const BAT_HEAD := "mixamorig_Head_06"
const BAT_AT := Vector3(-0.009, -0.45, -1.5)   ## where the bat's head is, in its own units
const BAT_SPAN := 12.0                           ## its wingspan, in its own units
var _wings: Node3D

func _build_wings() -> void:
	if not ResourceLoader.exists(BAT):
		return
	var m: Node3D = (load(BAT) as PackedScene).instantiate()
	# Wings a little more than twice the head's breadth; the bat's head where the lesser's is, facing as it faces
	var k := 2.4 / BAT_SPAN
	m.scale = Vector3.ONE * k
	m.rotation.y = PI
	m.position = Basis(Vector3.UP, PI) * (-BAT_AT * k) + Vector3(0, -0.05, 0)
	head.add_child(m)
	_wings = m
	var sk: Skeleton3D = m.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	var hi := sk.find_bone(BAT_HEAD)
	for lib in ap.get_animation_library_list():
		for an in ap.get_animation_library(lib).get_animation_list():
			var a: Animation = ap.get_animation_library(lib).get_animation(an)
			for t in range(a.get_track_count() - 1, -1, -1):
				if a.track_get_type(t) == Animation.TYPE_SCALE_3D and str(a.track_get_path(t)).ends_with(":" + BAT_HEAD):
					a.remove_track(t)
			a.loop_mode = Animation.LOOP_LINEAR
	sk.set_bone_pose_scale(hi, Vector3.ONE * 0.02)
	var coat: Color = head.coat if head.coat != Color() else head.fur.darkened(0.6)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mm: MeshInstance3D = mi
		var sm: Material = mm.mesh.surface_get_material(0) if mm.mesh else null
		if sm is StandardMaterial3D:
			var t := (sm as StandardMaterial3D).duplicate() as StandardMaterial3D
			t.albedo_color = Color(1, 1, 1).lerp(coat.lightened(0.15), 0.5) * 1.4
			t.cull_mode = BaseMaterial3D.CULL_DISABLED
			mm.material_override = t
	var names := ap.get_animation_list()
	if not names.is_empty():
		ap.play(names[0])
		ap.speed_scale = randf_range(1.6, 2.2) / maxf(float(spec.size), 0.5)
		ap.seek(randf() * 1.0, true)


func _panther_body(s: float, coat: Color) -> Node3D:
	var m: Node3D = (load(PANTHER) as PackedScene).instantiate()
	m.scale = Vector3.ONE * PANTHER_K * s
	m.position = Vector3(0, -0.74 * s, -0.05 * s)
	_body_node.add_child(m)
	_pan_skel = m.find_children("*", "Skeleton3D", true, false)[0]
	_pan_anim = m.find_children("*", "AnimationPlayer", true, false)[0]
	_pan_head = _pan_skel.find_bone(PANTHER_HEAD)
	if _panther_cuts == null:
		var hp := "%s:%s" % [str(_pan_anim.get_node(_pan_anim.root_node).get_path_to(_pan_skel)), PANTHER_HEAD]
		_panther_cuts = _cut_panther(_pan_anim.get_animation("Animation"), hp)
	_pan_anim.remove_animation_library("")   # the long take (and its head's scale) gives way to the cuts
	_pan_anim.add_animation_library("cut", _panther_cuts)
	_pan_skel.set_bone_pose_scale(_pan_head, Vector3.ONE * 0.05)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mm: MeshInstance3D = mi
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var sm: Material = mm.mesh.surface_get_material(0) if mm.mesh else null
		if sm is StandardMaterial3D:
			var tinted := (sm as StandardMaterial3D).duplicate() as StandardMaterial3D
			tinted.albedo_color = Color(1, 1, 1).lerp(coat.lightened(0.2), 0.6) * 1.8
			tinted.rim_enabled = true
			tinted.rim = 0.25
			tinted.rim_tint = 0.0
			mm.material_override = tinted
	_pan_gait = ""
	_pan_play("idle")
	_pan_anim.seek(randf() * 1.0, true)
	_pan_tick(0.0)
	return m


func _pan_play(g: String) -> void:
	if g != _pan_gait:
		_pan_gait = g
		_pan_anim.play("cut/" + g, 0.3)


## Its gait by its pace (stalking when the lurker creeps or anything comes low), and the lesser's head on its neck.
func _pan_tick(pace: float) -> void:
	if _pan_anim == null:
		return
	var s: float = spec.size
	if pace > 0.3:
		_pan_play("stalk" if kind == "lurker" or _buried > 0.05 else "walk")
		_pan_anim.speed_scale = clampf(pace / (PANTHER_WALK * s), 0.6, 3.2)
	else:
		_pan_play("idle")
		_pan_anim.speed_scale = 1.0
	var at: Vector3 = (_pan_skel.global_transform * _pan_skel.get_bone_global_pose(_pan_head)).origin
	head.position = _body_node.to_local(at) + Vector3(0, 0.06, 0.1) * s


## The ember sack: a head swollen with fire, glowing through its skin.
func _build_sack() -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.9, 0.35, 0.1, 0.55)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.4, 0.1)
	glow.emission_energy_multiplier = 2.0
	var sack := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.42 * spec.size
	sm.height = 0.84 * spec.size
	sack.mesh = sm
	sack.material_override = glow
	sack.position = Vector3(0, -0.45 * spec.size, -0.1)
	add_child(sack)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = sack.position
	add_child(l)


var _name_l: Label3D


## Its name, shown in the colour of the forms when it is hurt or close by.
## Lays the kin's colour over all of it.
func _tint(c: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c, 0.42)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if c.v < 0.2 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for g in find_children("*", "GeometryInstance3D", true, false):
		if g is Label3D or g is CPUParticles3D or g is GPUParticles3D:
			continue
		(g as GeometryInstance3D).material_overlay = m


## Its name and bar float clear above the top of its body (horns, hood and raised arms too), never inside it.
func _lift_tags() -> void:
	if not is_instance_valid(_fb):
		return
	var top := _fb.position.y + _fb.top() * _fb.scale.y
	if _name_l:
		_name_l.position.y = top + 0.42
	if _bar:
		_bar.position.y = top + 0.2


func _make_name() -> void:
	_name_l = Label3D.new()
	_name_l.text = str(spec.get("name", "")) if boss == "" else ""
	_name_l.font = load("res://assets/fonts/Marcellus-Regular.ttf")
	_name_l.font_size = 36
	_name_l.pixel_size = 0.005
	_name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_l.no_depth_test = false
	_name_l.modulate = Color(1.0, 0.55, 0.45, 0.0)
	_name_l.outline_size = 6
	_name_l.outline_modulate = Color(0, 0, 0, 0.0)
	_name_l.position.y = (1.4 if kind == "saucer" else 0.75 * spec.size + 0.55) + (1.1 if kind == "unseen" else 0.0)
	add_child(_name_l)


## The hull of a saucer: a spinning disc ringed with red lights, a glass dome over its head.
func _build_saucer() -> void:
	_disc = Node3D.new()
	add_child(_disc)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.32, 0.31, 0.33)
	steel.metallic = 0.85
	steel.roughness = 0.3
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.95
	tm.bottom_radius = 1.75
	tm.height = 0.32
	top.mesh = tm
	top.material_override = steel
	top.position.y = 0.0
	_disc.add_child(top)
	var under := MeshInstance3D.new()
	var um := CylinderMesh.new()
	um.top_radius = 1.75
	um.bottom_radius = 0.8
	um.height = 0.28
	under.mesh = um
	under.material_override = steel
	under.position.y = -0.3
	_disc.add_child(under)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.12, 0.06)
	for i in 10:
		var a := TAU * i / 10.0
		var lamp := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.09
		lm.height = 0.18
		lamp.mesh = lm
		lamp.material_override = red
		lamp.position = Vector3(cos(a) * 1.68, -0.16, sin(a) * 1.68)
		_disc.add_child(lamp)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.78
	dm.height = 1.56
	dome.mesh = dm
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.2, 0.18, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.4
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	dome.material_override = glass
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.position.y = 0.4
	add_child(dome)
	_beam = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.6
	bm.bottom_radius = 2.2
	bm.height = 7.0
	_beam.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(1.0, 0.2, 0.12, 0.0)
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = bmat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = -3.9
	add_child(_beam)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.2, 0.1)
	spot.light_energy = 3.0
	spot.spot_range = 14.0
	spot.spot_angle = 28.0
	spot.rotation_degrees.x = -90
	add_child(spot)


## A red beam falls, and three mites are let down to swarm the seeker.
func _let_down() -> void:
	level.sfx("beam", 0, global_position)
	var m: StandardMaterial3D = _beam.material_override
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.35, 0.3)
	tw.tween_interval(0.9)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	for i in 3:
		var at := global_position + Vector3(randf_range(-0.8, 0.8), -1.2 - i * 0.6, randf_range(-0.8, 0.8))
		_mites.append(level.spawn_at("mite", at))


func _can_see(target: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, target, 1)
	q.exclude = [get_rid(), level.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _spit(target: Vector3) -> void:
	level.sfx("spit", -6, global_position)
	if randf() < 0.6:
		_cry("screech", -2)
	var b := Bolt.new()
	b.level = level
	b.velocity = (target - global_position).normalized() * 14.0
	level.add_child(b)
	b.global_position = global_position + (target - global_position).normalized() * (spec.radius + 0.2)
	if Net.online:
		Net.bolt(b.global_position, b.velocity, b.damage)


## Returns true if the blow landed with force (false when a gilded face turned it aside).
## A blow that lands on the plate: most of it is soaked and the plate is worn. Piercing rounds go
## through nearly untouched, soft ones are stopped. The head is never covered.
func _on_plate(amount: float) -> float:
	var through := clampf(0.35 * harm_pierce * harm_pierce, 0.1, 1.0) if harm_kind != "blade" else clampf(0.5 * harm_pierce, 0.1, 1.0)
	var soak := minf(plate, amount * (1.0 - through))
	plate -= soak
	level.sfx("hit_metal", -6, global_position + Vector3(0, 0.4, 0))
	if plate <= 0.0:
		plate = 0.0
		if _fb:
			_fb.break_plate()
		level.sfx("hit_metal", 0, global_position + Vector3(0, 0.4, 0), 0.7)
	return amount - soak


var _flinch := Vector2.ZERO   ## the lean a blow gives it (about x, about z), fading
static var flinches := 0


## A blow rocks the body away from where it came from: harder for a hard blow, little for the great ones.
func flinch(amount: float, from_dir: Vector3) -> void:
	if kind in ["saucer"] or from_dir.length() < 0.01:
		return
	var k := clampf(amount / (25.0 + max_hp * 0.12), 0.06, 0.32)
	if boss != "" or kind in ["idol", "brute", "elite"]:
		k *= 0.35
	var d := global_transform.basis.inverse() * from_dir.normalized()
	_flinch = Vector2(clampf(_flinch.x + d.z * k, -0.4, 0.4), clampf(_flinch.y - d.x * k, -0.4, 0.4))
	flinches += 1


func hurt(amount: float, from_dir: Vector3) -> bool:
	if not _alive or hidden:
		return false
	flinch(amount, from_dir)
	if boss == "" and amount > 4.0 and level.has_method("power_k") and randf() < level.power_k("rime"):
		_stagger = maxf(_stagger, 0.7)   # the Glacier Mother's power: struck, a lesser form freezes a moment
	if boss == "" and harm_arm == "war_pick":
		_stagger = maxf(_stagger, 0.6)   # ice iron: a lesser form freezes where it stands, a moment
	var raw := amount   # what a puppet sends on: the host weighs weakness, plate and guard itself
	if harm_kind != "" and boss == "":
		# A blunt blow is a blade's to a form that has no word on blunt harm
		var hk := harm_kind
		if hk == "blunt" and not spec.get("weak", {}).has("blunt") and not spec.get("tough", {}).has("blunt"):
			hk = "blade"
		amount *= float(spec.get("weak", {}).get(hk, 1.0)) * float(spec.get("tough", {}).get(hk, 1.0))
	if spec.has("trait"):
		set_meta("struck_t", 3.0)
	if kind == "lurker" and _buried > 0.5:
		amount *= 0.2
	var full := true
	if kind == "idol":
		var facing := Vector3(sin(head.rotation.y), 0, cos(head.rotation.y))
		var incoming := -from_dir
		incoming.y = 0
		if facing.dot(incoming.normalized()) > 0.35:
			full = false
	_bar_t = 8.0
	var plated := false
	if plate > 0.0 and harm_kind in ["bullet", "shot", "blade", "blunt"] and not harm_head:
		amount = _on_plate(amount)
		plated = plate > 0.0
	if full and not plated and amount > 0.5:
		bleed(from_dir, amount)
	if puppet:
		# The blow is sent to the host, who alone decides whether the form is undone
		Net.hit(net_id, raw, from_dir, harm_kind, harm_head, harm_pierce, harm_heavy)
		_flash = 1.0 if full else 0.3
		return full and not plated
	if not full:
		amount *= 0.12
	if plated:
		full = false   # the hit marker shows it rang off iron
	if _guard and harm_kind in ["bullet", "shot"]:
		var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
		var inc := -from_dir
		inc.y = 0.0
		if fwd.dot(inc.normalized()) > 0.4:
			amount *= 0.3
			full = false
			level.sfx("hit_metal", -4, global_position + Vector3(0, 0.6, 0))
	if _spent > 0.0:
		amount *= 1.6
	if _broken > 0.0:
		amount *= BROKEN_HARM
	if champion == "warded" and harm_kind in ["bullet", "shot"] and not harm_head:
		amount *= 0.5   # a ward turns shots to the body: aim for the head, or close in with a blade
	if mind != "hunt" and mind != "flee":
		var by: Node3D = level.nearest_target(global_position)
		_alarm(by.global_position if by else global_position)
	hp -= amount
	_flash = 1.0 if full else 0.3
	# Heavy forms barely give ground unless the blow is a heavy one; they slow under fire instead
	var heavy_blow := amount >= 60.0 or harm_kind == "blast" or harm_arm == "hand_cannon"   # the hand cannon staggers even the heavy
	var steady := kind in ["idol", "brute", "elite"]
	_knock += from_dir.normalized() * minf(amount, 80.0) * (0.0 if boss != "" else (0.03 if steady and not heavy_blow else (0.08 if kind == "elite" else 0.2)))
	if steady:
		_shot_slow = 0.6
	# Its footing wears with every blow; when it breaks, it reels, its blow is broken off, and it is open
	if boss == "" and not kind in ["saucer", "unseen"] and _broken <= 0.0:
		if poise < 0.0:
			poise = poise_max()
		var wear := amount
		if harm_kind == "blade":
			wear *= 1.5
		if harm_kind == "blunt" or harm_heavy or harm_kind == "blast":
			wear *= 2.0
		if harm_arm == "hand_cannon":
			wear *= 1.8
		if harm_kind == "shot":
			var near_t: Node3D = level.nearest_target(global_position)
			if near_t and near_t.global_position.distance_to(global_position) < 6.0:
				wear *= 1.3
		poise -= wear
		_poise_t = 0.0
		if poise <= 0.0:
			_break_poise(from_dir, steady and not heavy_blow)
	hp_frac = hp / max_hp
	if hp <= 0.0:
		die(true)
	return full


## How much its footing can take: a share of its health (more for the heavy), as the world's foe skill sets.
func poise_max() -> float:
	var heavy: bool = kind in ["idol", "brute", "elite"] or float(spec.get("hp", 0.0)) >= 150.0
	var k := (WRules.stagger_at() / 0.3) if Game.wasteland else 1.0
	return max_hp * (POISE_FRAC_HEAVY if heavy else POISE_FRAC) * k


static var poise_breaks := 0   ## (for the tests)

## Its footing gives: it reels, its gathering blow is lost, and for a moment it takes more harm.
func _break_poise(from_dir: Vector3, steady: bool) -> void:
	poise_breaks += 1
	_broken = BROKEN_SECS
	_stagger = BROKEN_SECS
	poise = poise_max()
	if _wind > 0.0:
		_wind = 0.0
		_show_wind(-1.0)
	if not steady:
		_knock += from_dir.normalized() * 3.0
	level.sfx("thud", -4, global_position, 0.7)


## Champions: in the harder lands, now and then a foe stands out from its kind with one way of its own,
## twice the health, and better pickings. Its name is gilded and its kind's colour is laid over it.
const CHAMPION := {
	"swift": {"name": "Swift", "tint": Color(0.95, 0.9, 0.55)},
	"plated": {"name": "Plated", "tint": Color(0.6, 0.62, 0.66)},
	"burning": {"name": "Burning", "tint": Color(1.0, 0.45, 0.12)},
	"splitting": {"name": "Splitting", "tint": Color(0.5, 0.85, 0.4)},
	"warded": {"name": "Warded", "tint": Color(0.45, 0.65, 1.0)},
}
var champion := ""


func become_champion(tr: String) -> void:
	if champion != "" or not CHAMPION.has(tr):
		return
	champion = tr
	set_meta("champion", tr)
	spec = spec.duplicate(true)
	if not puppet:
		max_hp *= 2.0
		hp = max_hp
	match tr:
		"swift":
			spec.speed = float(spec.speed) * 1.4
		"plated":
			if not puppet:
				plate += 40.0 + max_hp * 0.25
			if _fb and not kind in ["knight", "unlit_brute"]:
				_fb.wear_plate(true)
		"burning":
			spec["burn"] = 3.0
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.5, 0.2)
			l.light_energy = 1.0
			l.omni_range = 3.5
			l.position.y = 1.0
			add_child(l)
	_tint(CHAMPION[tr].tint)
	if _name_l:
		_name_l.text = "%s %s" % [CHAMPION[tr].name, str(spec.get("name", ""))]
		_name_l.modulate = Color(1.0, 0.82, 0.35, _name_l.modulate.a)


## A champion's own way, at its death: a splitting one breaks into two lesser of its kind.
func _champion_die() -> void:
	if champion != "splitting" or puppet or has_meta("shard"):
		return
	var lvl = level
	var k: String = variant if variant != "" else kind
	var at := global_position
	lvl.get_tree().create_timer(0.2, false).timeout.connect(func():
		for i in 2:
			var o = lvl.spawn_at(k, at + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2)))
			if o:
				o.set_meta("shard", true)
				o.max_hp *= 0.5
				o.hp = o.max_hp)


func is_alive() -> bool:
	return _alive


## A spray where the blow landed and a stain on the ground under it, unless blood is turned off.
func bleed(from_dir: Vector3, amount: float) -> void:
	if not Game.blood or Net.dedicated or not is_inside_tree():
		return
	blood_shown += 1
	var c: Color = BLOOD.get(kind, Color(0.34, 0.02, 0.02))
	var r: float = spec.get("radius", 0.5)
	var d := from_dir.normalized() if from_dir.length() > 0.01 else Vector3.FORWARD
	var at := global_position + Vector3(0, r * 1.2, 0) - d * r * 0.8
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = clampi(int(amount * 0.9), 8, 32)
	p.lifetime = 0.8
	p.explosiveness = 0.95
	p.direction = d
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.albedo_texture = _blot_tex()
	q.material = m
	p.mesh = q
	level.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)
	# A stain on the ground behind, if the blow was a hard one
	if amount >= 8.0 and kind != "saucer" and randf() < 0.6:
		var dec := Decal.new()
		dec.texture_albedo = _blot_tex()
		dec.modulate = Color(c.darkened(0.35), 0.8)
		var s := clampf(0.3 + amount * 0.012, 0.35, 1.0) * maxf(1.0, r * 1.5)
		dec.size = Vector3(s, 1.2, s)
		dec.normal_fade = 0.9
		dec.upper_fade = 0.2
		dec.lower_fade = 0.2
		level.add_child(dec)
		var g := global_position + d * randf_range(0.3, 1.2)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3(0, 2, 0), g - Vector3(0, 6, 0), 1))
		if not hit.is_empty():
			g.y = hit.position.y
		dec.global_position = g
		dec.rotation.y = randf() * TAU
		var tw := dec.create_tween()
		tw.tween_interval(18.0)
		tw.tween_property(dec, "modulate:a", 0.0, 4.0)
		tw.tween_callback(dec.queue_free)


static func _blot_tex() -> Texture2D:
	if _blot:
		return _blot
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var blobs: Array = [[Vector2(32, 32), 18.0]]
	for i in 7:
		blobs.append([Vector2(32, 32) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10, 22), rng.randf_range(3, 8)])
	for y in n:
		for x in n:
			var a := 0.0
			for b in blobs:
				a = maxf(a, clampf(1.0 - (Vector2(x, y).distance_to(b[0]) - b[1]) / 3.0, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_blot = ImageTexture.create_from_image(img)
	return _blot


func die(slain: bool) -> void:
	if not _alive:
		return
	_alive = false
	if kind == "bloater" and slain and not puppet:
		_burst_fire()
	if spec.has("trait"):
		FoeTraits.on_die(self, slain)
	if slain and champion != "":
		_champion_die()
	collision_layer = 0
	level.sfx("dissolve", -4, global_position)
	if slain:
		level.sfx("fall_heavy" if spec.get("size", 1.0) >= 1.5 else "fall", -4, global_position)
	var mine := credit if puppet else last_hitter == Net.me()
	if Net.is_host() and not puppet:
		level.foes.erase(net_id)
		Net.foe_died(net_id, slain, last_hitter)
	if slain:
		level.burst(global_position, head.fur)
		if mine:
			level.on_enemy_slain(self)
			if Game.find_emoji(code) and Game.lesser.has(code):
				var e: Dictionary = Game.lesser[code]
				level.hud.notify("Recorded in the Book of Emojis\n%s: %s" % [e.name, e.decree])
		elif not puppet:
			level.team_kill(self)
	died.emit()
	if _fb and slain:
		_fb.act("die")
		var tf := create_tween()
		tf.tween_interval(1.6)
		tf.tween_property(self, "scale", Vector3.ONE * 0.01, 0.6)
		tf.tween_callback(queue_free)
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.4, 0.05, 1.4) if slain else Vector3.ONE * 0.01, 0.35)
	tw.tween_callback(queue_free)


## The ember sack bursts: fire on everything near, the forms included.
func _burst_fire() -> void:
	var at := global_position
	Arms.blast(level, at, 4.0, 40.0, null, "fire")
	Arms.Thrown.burn(level, at, 3.5, 10.0, 5.0, true)
	for t in level.targets():
		var d: float = t.global_position.distance_to(at)
		if d < 4.5:
			level.hurt_target(t, 28.0 * (1.0 - d / 5.5), at)


## A form pressed against something built tears at it.
func _claw_at_wall() -> void:
	if _attack_cd > 0.0 or spec.bite <= 0.0:
		return
	var c := get_last_slide_collision()
	if c and level.on_blocked(self, c.get_collider(), spec.bite * 1.5):
		_attack_cd = 0.9
		level.sfx("bite", -6, global_position, 0.7)


var _cut_off := 0.0
var _sight_t := 0.0


## A form walled off from every pilgrim for long (taken shape behind a wall, or wandered through a gap)
## is drawn back into the open near them, so that every gathering can be finished.
func _rescue(delta: float, idle: bool) -> void:
	if idle or kind == "mite":
		return
	_sight_t -= delta
	if _sight_t > 0.0:
		return
	_sight_t = 0.5
	if level.reachable(global_position):
		_cut_off = 0.0
		return
	_cut_off += 0.5
	if _cut_off >= (6.0 if kind in ["elite", "saucer"] else 10.0):
		_cut_off = 0.0
		var spot = level.open_spot_near(level.focus_pos(), 7.0, 14.0, kind == "saucer")
		if spot != null:
			global_position = spot
			velocity = Vector3.ZERO
			level.sfx("hiss", -6, spot)


## What the host tells the others of this form, fifteen times a second.
## A bite in two beats: it gathers itself (the head swells and glows), then lunges. Out of reach when it
## lands, it misses. Staggered, it does not bite at all.
func _bite_tick(delta: float, p: Node3D, dist: float, dir: Vector3, reach: float, cd: float, dmg: float) -> void:
	if _wind > 0.0:
		_wind -= delta
		_show_wind(1.0 - _wind / maxf(_wind_total, 0.01))
		if _wind <= 0.0:
			_show_wind(-1.0)
			_attack_cd = cd
			_knock += dir * 4.0
			if dist < reach + 0.7 and _perfect_guard(p):
				_parried(dir)
			elif dist < reach + 0.7:
				level.sfx("bite", -2, global_position)
				if randf() < 0.5:
					_cry("growl_%d" % (randi() % 3), 0)
				level.hurt_target(p, dmg * FoeTraits.bite_mult(self), global_position)
				_afflict(p)
				FoeTraits.on_bite(self, p)
				_knock = -dir * 5.0
			else:
				level.sfx("swing", -8, global_position, 1.4)
		return
	if dist < reach + 0.4 and _attack_cd <= 0.0 and _stagger <= 0.0:
		_wind_total = float(WINDUP.get(kind, 0.35)) / sqrt(Game.difficulty_scale("speed")) * (WRules.windup() if Game.wasteland else 1.0)
		_wind = _wind_total
		_cry("growl_%d" % (randi() % 3), -4)


## A guard raised just as the blow lands (a quarter of a second): the blow is turned for nothing, and the
## foe reels open. A guard held up long before only blunts the blow, for stamina (see damage_player).
func _perfect_guard(p: Node3D) -> bool:
	if p is Companion:
		return level.friend_guarded(p, global_position)
	if p != level.player or level.player.weapon == null or not level.player.weapon.guarding:
		return false
	if float(level.player.weapon.get("guard_age")) > Arms.PERFECT_GUARD:
		return false
	var pf := -level.player.global_transform.basis.z
	var to := global_position - level.player.global_position
	to.y = 0.0
	return pf.dot(to.normalized()) > 0.3


static var parries := 0   ## (for the tests)

func _parried(dir: Vector3) -> void:
	parries += 1
	level.sfx("parry", 0, global_position)
	_stagger = 1.3
	_wind = 0.0
	_show_wind(-1.0)
	level.player.shake(0.2)
	level.hud.hitmarker(false, true)
	_knock = -dir * 3.0


## The swelling and glow of a gathering bite (k from 0 to 1), or back to rest (k below 0).
func _show_wind(k: float) -> void:
	if k < 0.0:
		head.scale = _head_base
		return
	head.scale = _head_base * (1.0 + 0.2 * sin(k * PI * 0.5))
	head.set_flash(maxf(_flash, 0.2 + 0.4 * k))


## A foe with a body is struck all over it, not only about its middle: a capsule from its feet to the
## crown of its head, as wide as it was (so it walks as it did).
func _fit_shape(cs: CollisionShape3D) -> void:
	var to_me := global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	var top := float(spec.radius)
	for mi in _fb.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var ab: AABB = (to_me * m.global_transform) * m.get_aabb() if is_inside_tree() else m.get_aabb()
		top = maxf(top, ab.end.y)
	var r := float(spec.radius)
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = maxf(2.0 * r, top + 0.12 + r)   # a little over the crown, so a shot at the top of the head lands
	cs.shape = c
	cs.position.y = -r + c.height * 0.5


## Where a shot does the most harm: the head, and how near to its middle counts.
func weak_point() -> Array:
	if not is_instance_valid(head) or kind in ["saucer", "bloater"]:
		return []
	if _fb and is_instance_valid(_fb.head_node) and _fb.head_node is MeshInstance3D:
		# The model's own head, wherever its walk and swing have carried it
		var mh: MeshInstance3D = _fb.head_node
		var ab: AABB = mh.global_transform * mh.get_aabb()
		return [ab.get_center(), 0.45 * maxf(ab.size.x, ab.size.y)]
	return [head.global_position, 0.42 * float(spec.size) * _head_base.x * scale.x]


func net_state() -> Array:
	return [net_id, boss if boss != "" else (variant if variant != "" else kind), code, global_position, rotation.y, head.rotation.y, head.rotation.x, _flash, hp / max_hp, _wind > 0.0, _stagger > 0.0, hidden, champion]


func net_apply(st: Array) -> void:
	var to: Vector3 = st[3]
	_net_v = (to - _net_to) * 15.0
	_net_to = to
	_net_body_y = st[4]
	_net_head = Vector2(st[5], st[6])
	_flash = maxf(_flash, st[7])
	if st.size() > 8:
		hp_frac = st[8]
	if st.size() > 10:
		_wind = 0.3 if st[9] else 0.0
		_stagger = 0.3 if st[10] else 0.0
	if st.size() > 12 and str(st[12]) != "" and champion == "":
		become_champion(str(st[12]))
	if st.size() > 11 and bool(st[11]) != hidden:
		set_hidden(bool(st[11]))
		if not hidden:
			global_position = to
			return
	if global_position.distance_to(to) > 6.0:
		global_position = to


## A puppet glides toward where the host says the form is, and keeps its cries and its legs.
func _puppet_tick(delta: float) -> void:
	_t += delta
	global_position = global_position.lerp(_net_to + _net_v * 0.03, minf(1.0, delta * 12.0))
	rotation.y = lerp_angle(rotation.y, _net_body_y, minf(1.0, delta * 12.0))
	head.rotation.y = lerp_angle(head.rotation.y, _net_head.x, minf(1.0, delta * 12.0))
	head.rotation.x = lerpf(head.rotation.x, _net_head.y, minf(1.0, delta * 12.0))
	_flash = maxf(0.0, _flash - delta * 5.0)
	head.set_flash(_flash)
	if _pan_anim:
		_pan_tick(Vector2(_net_v.x, _net_v.z).length())
	if _scan:
		_scan_tick(Vector2(_net_v.x, _net_v.z).length())
	if _fb:
		var pv := Vector2(_net_v.x, _net_v.z).length()
		_fb.play("sprint" if pv > 4.5 else ("walk" if pv > 0.4 else "idle"))
		if _wind > 0.0 and _fb._once <= 0.0:
			_fb.act("attack-melee-right")
	if _wind > 0.0:
		_wind -= delta
		_show_wind(0.8)
		if _wind <= 0.0:
			_show_wind(-1.0)
	if _stagger > 0.0:
		_stagger -= delta
	head.rotation.z = sin(_t * 18.0) * 0.2 if _stagger > 0.0 else 0.0
	_bar_tick(delta)
	if kind == "saucer" and _disc:
		_disc.rotation.y += delta * 2.5
	if kind == "unseen":
		var d := global_position.distance_to(level.player.global_position)
		_shade_tick(delta, d)
		_unseen_noise(delta, d)
	if kind == "spider":
		var pace := Vector2(_net_v.x, _net_v.z).length()
		for leg in _legs:
			var ph: float = _t * (6.0 + pace * 2.0) + leg.phase
			var amp := minf(0.4, 0.08 + pace * 0.05)
			leg.pivot.rotation.y = sin(ph) * amp
			leg.pivot.rotation.x = maxf(0.0, cos(ph)) * amp * -0.6
	_cry_cd -= delta
	var dist := global_position.distance_to(level.player.global_position)
	if _cry_cd <= 0.0 and dist < 16.0 and not level.combat_frozen and kind != "unseen":
		_cry_cd = randf_range(3.5, 7.0)
		match kind:
			"rusher", "swarm", "idol":
				_cry("shriek_%d" % (randi() % 4), 0 if kind != "swarm" else -6)
			"mite":
				_cry("chitter", -4)
			"elite":
				level.sfx("roar", 0, global_position, randf_range(0.85, 1.05))
			"spitter":
				_cry("growl_%d" % (randi() % 3), -2)
			"spider":
				_cry("skitter" if randf() < 0.5 else "critter_%d" % (randi() % 3), -2)


## The unseen: a long dark figure of bent light, arms to its knees, a narrow head with no face.
func _build_unseen() -> void:
	head.visible = false
	_shimmer = ShaderMaterial.new()
	_shimmer.shader = load("res://scripts/shimmer.gdshader")
	var parts := [
		[CapsuleMesh, Vector3(0, -0.25, 0), Vector3(0.34, 2.3, 0), Vector3.ZERO],
		[CapsuleMesh, Vector3(0, 1.2, 0.04), Vector3(0.19, 0.62, 0), Vector3(0.2, 0, 0)],
		[CapsuleMesh, Vector3(0.42, -0.35, 0.1), Vector3(0.07, 2.1, 0), Vector3(0.15, 0, 0.12)],
		[CapsuleMesh, Vector3(-0.42, -0.35, 0.1), Vector3(0.07, 2.1, 0), Vector3(0.15, 0, -0.12)],
	]
	for pt in parts:
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = pt[2].x
		cm.height = pt[2].y
		mi.mesh = cm
		mi.position = pt[1]
		mi.rotation = pt[3]
		mi.material_override = _shimmer
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## Does the one it hunts look upon it?
func _is_watched(p: Node3D) -> bool:
	var face: Vector3 = -p.global_transform.basis.z if p is Player else p.global_transform.basis.z
	if p is Player and p.cam:
		face = -p.cam.global_transform.basis.z
	var to_it := global_position - (p.global_position + Vector3(0, 1.5, 0))
	face.y = 0.0
	to_it.y = 0.0
	return face.normalized().dot(to_it.normalized()) > 0.85


## Near, or struck, it shows plainly; otherwise it is only a bending of the air.
func _shade_tick(delta: float, dist: float) -> void:
	var want := 0.08
	if dist < 7.0:
		want = lerpf(1.0, 0.08, dist / 7.0)
	want = maxf(want, _flash)
	_seen = lerpf(_seen, want, minf(1.0, delta * 3.0))
	_shimmer.set_shader_parameter("seen", _seen)
	_shimmer.set_shader_parameter("flash", _flash)
	# It sways where it stands, as if listening
	rotation.z = sin(_t * 0.7) * 0.04


func _unseen_noise(delta: float, dist: float) -> void:
	_breath_cd -= delta
	if _cry_cd <= 0.0:
		level.sfx("unseen_call", 0, global_position, randf_range(0.85, 1.05))
		_cry_cd = randf_range(12.0, 20.0)
	if dist < 12.0 and _breath_cd <= 0.0:
		level.sfx("unseen_breath", -4, global_position, randf_range(0.9, 1.1))
		_breath_cd = randf_range(3.0, 5.0)


## A thin bar of life over the form, shown once it has been struck (great ones have theirs across the sight).
func _make_bar() -> void:
	if _bar_mat == null:
		_bar_mat = ShaderMaterial.new()
		_bar_mat.shader = load("res://scripts/foe_bar.gdshader")
	_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(clampf(0.7 * spec.size + 0.3, 0.6, 1.6), 0.09)
	_bar.mesh = q
	_bar.material_override = _bar_mat
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.position.y = (1.25 if kind == "saucer" else 0.75 * spec.size + 0.35) + (1.1 if kind == "unseen" else 0.0)
	_bar.set_instance_shader_parameter("shown", 0.0)
	_bar.visible = false
	add_child(_bar)


func _bar_tick(delta: float) -> void:
	if _name_l:
		var near: bool = _alive and level.player != null and (seen_t > 0.0 or global_position.distance_to(level.player.global_position) < 10.0)
		var a := maxf(clampf(_bar_t, 0.0, 1.0) if _alive else 0.0, 0.85 if near else 0.0) * (1.0 - _buried)
		_name_l.modulate.a = move_toward(_name_l.modulate.a, a, delta * 3.0)
		_name_l.outline_modulate.a = _name_l.modulate.a * 0.8
	if _bar == null:
		return
	_bar_t -= delta
	var show := clampf(_bar_t, 0.0, 1.0) if _alive else 0.0
	_bar.visible = show > 0.0
	if show > 0.0:
		_bar.set_instance_shader_parameter("shown", show)
		_bar.set_instance_shader_parameter("frac", clampf(hp_frac if puppet else hp / max_hp, 0.0, 1.0))


## A great one is a lesser body made vast: its flesh, legs and disc are grown, its shape for collision set by spec.
func _grow_into_boss() -> void:
	var g: float = spec.get("grow", 1.0)
	if g == 1.0:
		return
	for c in get_children():
		if c is Node3D and not c is CollisionShape3D:
			c.scale *= g
			c.position *= g


func is_boss() -> bool:
	return boss != ""


## Each great one fights in a set order that can be learned: a loop of steps, each step one way or a
## few run back to back, every way shown before it lands, and a breath after each step to strike
## back in. Past half its life ("wroth") it turns to a harder loop with its own worst trick.
const PATTERNS := {
	"boss_ash": [[["charge"], ["slam"], ["brood"]], [["charge", "slam"], ["brood"], ["slam"]]],
	"boss_dunes": [[["volley"], ["rain"], ["brood"]], [["volley", "volley"], ["rain"], ["brood", "volley"]]],
	"boss_salt": [[["volley"], ["line"], ["charge"]], [["line", "line"], ["volley"], ["charge", "rain"]]],
	"boss_forest": [[["charge"], ["ambush"]], [["ambush", "charge"], ["charge"]]],
	"boss_basalt": [[["slam"], ["volley"], ["charge"]], [["quake"], ["volley"], ["charge", "slam"]]],
	"boss_marsh": [[["brood"], ["rain"], ["charge"]], [["charge", "charge"], ["rain"], ["brood"]]],
	"boss_quiet": [[["line"], ["ambush"], ["volley"]], [["ambush", "line"], ["volley", "volley"], ["line"]]],
	"boss_domes": [[["volley"], ["charge"], ["brood"]], [["brood", "volley"], ["charge", "charge"], ["volley"]]],
	"boss_frost": [[["slam"], ["rain"], ["quake"]], [["quake", "slam"], ["rain", "rain"], ["quake"]]],
	"boss_sun": [[["volley"], ["brood"], ["rain"]], [["rain", "volley"], ["brood"], ["rain", "rain"]]],
	"boss_steppe": [[["charge"], ["slam"], ["brood"]], [["charge", "charge"], ["slam", "brood"], ["charge"]]],
}


## Whether a way can reach from here (otherwise the great one closes in, or gives the step up).
func _way_reaches(w: String, dist: float) -> bool:
	match w:
		"slam":
			return dist < 10.0 + spec.radius
		"quake":
			return dist < 16.0 + spec.radius
		"volley":
			return dist < 40.0
		"charge":
			return dist > 6.0 and dist < 34.0
		"rain", "line":
			return dist < 45.0
		"ambush":
			return dist < 40.0
	return true


func _do_way(w: String, p: Node3D) -> void:
	match w:
		"slam":
			_slam()
		"quake":
			_quake()
		"volley":
			# A breath drawn and a glow before the bolts fly
			_busy = 0.9
			_flash = 0.8
			level.sfx("hiss", -2, global_position, 1.3)
			get_tree().create_timer(0.55, false).timeout.connect(func():
				if not _alive or not is_instance_valid(p):
					return
				var target := p.global_position + Vector3(0, 1.2, 0)
				for k in ([-0.4, -0.2, 0.0, 0.2, 0.4] if _wroth else [-0.3, -0.15, 0.0, 0.15, 0.3]):
					_spit(global_position + (target - global_position).rotated(Vector3.UP, k)))
		"charge":
			_start_charge(p)
		"rain":
			_rain()
		"line":
			_line(p)
		"ambush":
			_ambush(p)
		"brood":
			_busy = 1.0
			_brood = _brood.filter(func(m): return is_instance_valid(m) and m.is_alive())
			if _brood.size() < 6:
				level.sfx("roar", -2, global_position, 1.3)
				for k in 3:
					var at := global_position + Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3))
					var e: LesserSpeeb = level.spawn_at(str(spec.get("brood", "swarm")), at)
					if e:
						_brood.append(e)


## The ways of the great ones, run by the host.
func _boss_tick(delta: float, p: Node3D, dist: float) -> void:
	_busy = maxf(0.0, _busy - delta)
	_check_wroth()
	_boss_ways(delta, p, dist)


## Below half its strength a great one grows wroth: a roar, and its wroth loop of ways (even mid-charge).
func _check_wroth() -> void:
	if not _wroth and hp < max_hp * 0.5:
		_wroth = true
		level.sfx("great_roar", 8, global_position, 0.8)
		level.shared("_w_boss_wroth", [boss])
		_combo = []
		_pat_i = 0
		_gap = 1.5


func _boss_ways(delta: float, p: Node3D, dist: float) -> void:
	# One way at a time: nothing new while one is shown, run or recovered from
	if _busy <= 0.0 and _spent <= 0.0 and _charge_t <= 0.0:
		var pats: Array = PATTERNS.get(boss, [[spec.ways.map(func(x): return [x])]])
		var loop: Array = pats[1 if _wroth and pats.size() > 1 else 0]
		if _combo.is_empty():
			_gap -= delta * level.enemy_time
			if _gap <= 0.0:
				_combo = (loop[_pat_i % loop.size()] as Array).duplicate()
				_pat_i += 1
				_reach_wait = 0.0
		if not _combo.is_empty():
			var w: String = _combo[0]
			if _way_reaches(w, dist):
				_combo.pop_front()
				_do_way(w, p)
				if _combo.is_empty():
					_gap = 1.6 if _wroth else 2.6
			else:
				_reach_wait += delta * level.enemy_time
				if _reach_wait > 6.0:
					_combo = []
					_gap = 0.5
	if spec.ways.has("blink"):
		_watched_t = _watched_t + get_physics_process_delta_time() if _watched else 0.0
		if _watched_t > 4.5:
			_watched_t = 0.0
			var back := -p.global_transform.basis.z
			if p is Player and p.cam:
				back = -p.cam.global_transform.basis.z
			back.y = 0.0
			var to := p.global_position - back.normalized() * 7.0 + Vector3(0, 1.5, 0)
			level.sfx("unseen_click", 2, global_position, 0.7)
			global_position = to
			level.sfx("unseen_scream", 0, to, 0.75)
			_seen = 1.0


## The great one strikes the ground: everything near is thrown down, and the earth is seen to break.
func _slam() -> void:
	level.sfx("great_roar", 4, global_position, 1.0)
	_flash = 1.0
	_busy = 1.0
	var at := global_position
	var r: float = 9.0 + spec.radius
	level.shared("_w_warn", [at, r, 0.9, 0])
	get_tree().create_timer(0.9, false).timeout.connect(func():
		if not _alive:
			return
		_spent = 1.2
		level.sfx("boom", 4, at, 0.6)
		level.shared("_w_slam_fx", [at, r])
		for t in level.targets():
			var d: float = t.global_position.distance_to(at)
			if d < r and absf(t.global_position.y - at.y) < 6.0:
				level.hurt_target(t, lerpf(36.0, 12.0, d / r), at))


## The Basalt Idol's worst: the ground breaks in three rings, one after another, each further out.
## Stand where the last one broke.
func _quake() -> void:
	level.sfx("great_roar", 6, global_position, 0.8)
	_flash = 1.0
	_busy = 3.2
	var at := global_position
	var r0: float = spec.radius + 2.0
	for k in 3:
		var inner: float = r0 + k * 6.0
		var outer := inner + 6.0
		get_tree().create_timer(0.7 * k, false).timeout.connect(func():
			if _alive:
				level.shared("_w_warn", [at, outer, 0.9, 0]))
		get_tree().create_timer(0.7 * k + 0.9, false).timeout.connect(func():
			if not _alive:
				return
			level.sfx("boom", 2, at, 0.7 - k * 0.08)
			level.shared("_w_slam_fx", [at, outer])
			for t in level.targets():
				var d: float = Vector2(t.global_position.x - at.x, t.global_position.z - at.z).length()
				if d >= inner and d < outer and absf(t.global_position.y - at.y) < 6.0:
					level.hurt_target(t, 28.0, at))
	get_tree().create_timer(3.0, false).timeout.connect(func():
		if _alive:
			_spent = 1.4)


## Fire comes down in a line from the great one out past a pilgrim, one spot after another.
func _line(p: Node3D) -> void:
	_busy = 1.0
	_flash = 0.7
	level.sfx("beam", 0, global_position, 0.6)
	var d := p.global_position - global_position
	d.y = 0.0
	if d.length() < 0.5:
		d = Vector3.FORWARD
	var dir := d.normalized()
	var spots: Array = []
	for k in 9:
		var at := global_position + dir * (4.0 + k * 4.0)
		at.y = p.global_position.y
		spots.append(at)
		level.shared("_w_warn", [at, 2.4, 1.1 + k * 0.12, 2])
	for k in spots.size():
		var at: Vector3 = spots[k]
		get_tree().create_timer(1.1 + k * 0.12, false).timeout.connect(func():
			if not _alive:
				return
			level.shared("_w_slam_fx", [at, 2.8])
			level.sfx("boom", -6, at, 1.2)
			for t in level.targets():
				var off: Vector3 = t.global_position - at
				if Vector2(off.x, off.z).length() < 2.4 and absf(off.y) < 4.0:
					level.hurt_target(t, 22.0, at))


## The Long Watcher is gone, and then it is behind you. A click, a scream, and it runs at you.
func _ambush(p: Node3D) -> void:
	var back := -p.global_transform.basis.z
	if p is Player and p.cam:
		back = -p.cam.global_transform.basis.z
	back.y = 0.0
	if back.length() < 0.1:
		back = Vector3.FORWARD
	var to := p.global_position - back.normalized() * 12.0 + Vector3(0, 1.5, 0)
	level.sfx("unseen_click", 2, global_position, 0.7)
	global_position = to
	level.sfx("unseen_scream", 2, to, 0.75)
	_seen = 1.0
	_busy = 0.8
	get_tree().create_timer(0.8, false).timeout.connect(func():
		if _alive and is_instance_valid(p):
			_busy = 0.0
			_start_charge(p))


## The great one marks a line toward a pilgrim, rears, then runs it down. It stands spent at the end.
func _start_charge(p: Node3D) -> void:
	var d := p.global_position - global_position
	d.y = 0.0
	if d.length() < 1.0:
		return
	_charge_dir = d.normalized()
	var reach := minf(d.length() + 8.0, 34.0)
	_busy = 0.9
	_flash = 1.0
	level.sfx("great_roar", 2, global_position, 1.1)
	level.shared("_w_warn", [global_position + _charge_dir * reach * 0.5, reach * 0.5, 0.85, 1, atan2(_charge_dir.x, _charge_dir.z), spec.radius + 1.0])
	get_tree().create_timer(0.85, false).timeout.connect(func():
		if not _alive:
			return
		_charge_t = reach / 24.0
		_charge_hit = {})


## Running the marked line: anyone in the way is struck once and thrown aside.
func _charge_tick(delta: float) -> void:
	_charge_t -= delta
	velocity = _charge_dir * 24.0 * level.enemy_time
	velocity.y = -4.0 if walks() or not kind in ["saucer", "unseen"] else 0.0
	move_and_slide()
	for t in level.targets():
		if _charge_hit.has(t):
			continue
		var off: Vector3 = t.global_position - global_position
		off.y = 0.0
		if off.length() < spec.radius + 1.3:
			_charge_hit[t] = true
			level.hurt_target(t, float(spec.bite) * 0.9 + 10.0, global_position)
	if _charge_t <= 0.0 or is_on_wall():
		_charge_t = 0.0
		_spent = 1.6
		level.sfx("thud", 2, global_position, 0.6)
		level.shared("_w_slam_fx", [global_position, 4.0])


## Marks a burning circle under each pilgrim near, and a few about, then brings fire down on them.
func _rain() -> void:
	_busy = 0.5
	_flash = 0.7
	level.sfx("beam", -2, global_position, 0.7)
	var spots: Array = []
	for t in level.targets():
		if t.global_position.distance_to(global_position) < 50.0:
			spots.append(t.global_position)
			for k in (2 if _wroth else 1):
				spots.append(t.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
	for at in spots:
		level.shared("_w_warn", [at, 2.6, 1.3, 2])
	get_tree().create_timer(1.3, false).timeout.connect(func():
		if not _alive:
			return
		for at in spots:
			level.shared("_w_slam_fx", [at, 3.0])
			level.sfx("boom", -4, at, 1.2)
			for t in level.targets():
				var off: Vector3 = t.global_position - at
				if Vector2(off.x, off.z).length() < 2.6 and absf(off.y) < 4.0:
					level.hurt_target(t, 24.0, at))


## A spat bolt of burning light.
class Bolt extends Area3D:
	const MAX_LIT := 6
	static var lit := 0
	static var _mesh: SphereMesh
	static var _mat: StandardMaterial3D
	var _has_light := false
	var velocity := Vector3.ZERO
	var damage := 13.0
	var level: Level
	var life := 4.0
	var look := ""   ## "" a spat bolt; "round" a gunman's round: a quick bright streak you can step out of
	static var _round_mesh: CapsuleMesh
	static var _round_mat: StandardMaterial3D

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.22 if look != "round" else 0.16
		cs.shape = s
		add_child(cs)
		if look == "round":
			if _round_mesh == null:
				_round_mesh = CapsuleMesh.new()
				_round_mesh.radius = 0.035
				_round_mesh.height = 0.9
				_round_mat = StandardMaterial3D.new()
				_round_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_round_mat.albedo_color = Color(1.0, 0.82, 0.4)
				_round_mat.emission_enabled = true
				_round_mat.emission = Color(1.0, 0.7, 0.3)
			var rm := MeshInstance3D.new()
			rm.mesh = _round_mesh
			rm.material_override = _round_mat
			rm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			rm.rotation.x = PI * 0.5   # lying along its flight
			add_child(rm)
			if velocity.length() > 0.1:
				look_at_from_position(position, position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)
			body_entered.connect(_hit)
			return
		# One mesh and one look shared by every bolt, and only a few carry a light: a swarm spitting
		# at once would otherwise light the night with dozens of lamps
		if _mesh == null:
			_mesh = SphereMesh.new()
			_mesh.radius = 0.16
			_mesh.height = 0.32
			_mat = StandardMaterial3D.new()
			_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_mat.albedo_color = Color(1.0, 0.35, 0.2)
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh
		mi.material_override = _mat
		add_child(mi)
		if lit < MAX_LIT:
			lit += 1
			_has_light = true
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.3, 0.15)
			l.light_energy = 1.2
			l.omni_range = 3.5
			add_child(l)
		body_entered.connect(_hit)

	func _exit_tree() -> void:
		if _has_light:
			lit -= 1
			_has_light = false

	func _physics_process(delta: float) -> void:
		global_position += velocity * delta * level.enemy_time
		life -= delta * level.enemy_time
		if life <= 0.0:
			queue_free()

	func _hit(b: Node) -> void:
		# A pilgrim stepping aside as it comes lets it fly past, however far it was fired from
		if b is Player and (b as Player).dodge_t > 0.0:
			return
		if b is Player and not level.sheltered(b.global_position):
			level.damage_player(damage * level.foe_harm(), global_position - velocity.normalized() * 2.0)
		queue_free()


# ------------------------------------------------------------------ foes with bodies of their own

## How the Unlit and the dead move and fight. Melee foes close in and spread around their prey
## instead of queueing; a gunman keeps its distance, draws a bead and fires in bursts, reloads, and
## backs off when badly hurt; the Lost Vigil drifts through the air.
## Whether it can see the pilgrim: near enough (less at night, or treading softly), in front of it
## (or very close), and nothing in the way.
func sees(p: Node3D) -> bool:
	var to := p.global_position - global_position
	var d := to.length()
	var reach := 48.0 if spec.get("role", "") == "gun" else 34.0
	if level.get("night"):
		reach *= 0.6
	if p == level.player and Game.held("soft"):
		reach *= 0.55
	if p == level.player and level.has_method("power_k"):
		reach *= 1.0 - 0.45 * level.power_k("hush")
	if d > reach:
		return false
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var flat := Vector3(to.x, 0, to.z).normalized()
	if d > 6.0 and fwd.dot(flat) < 0.2:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.8, 0), p.global_position + Vector3(0, 1.3, 0))
	q.exclude = [get_rid(), p.get_rid()] if p is CollisionObject3D else [get_rid()]
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A noise at a place, carrying radius far. Near, it knows where it came from; further, it goes to look.
func hear(at: Vector3, radius: float) -> void:
	if not _alive or puppet or mind == "hunt" or mind == "flee" or _fb == null:
		return
	var d := global_position.distance_to(at)
	if d > radius:
		return
	if d < radius * 0.3:
		_alarm(at)
	else:
		mind = "search"
		_search_t = 14.0
		_last_known = at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * d * 0.15
		_show_mark("?")


## Sent to look somewhere (the night's walkers, drawn to the living).
func seek(at: Vector3, for_t: float) -> void:
	if _fb == null or mind == "hunt":
		return
	mind = "search"
	_search_t = for_t
	_last_known = at


## It knows where the pilgrim is, and calls the others of its band near it.
func _alarm(at: Vector3, call := true) -> void:
	if mind == "hunt" or mind == "flee":
		return
	mind = "hunt"
	_last_known = at
	_lost_t = 0.0
	_show_mark("!")
	if kind.begins_with("unlit"):
		_cry("growl_%d" % (randi() % 3), -4)
	if call:
		for e in level.enemies:
			if is_instance_valid(e) and e != self and e.get("_fb") != null and e.global_position.distance_to(global_position) < 22.0:
				e._alarm(at, false)


func _show_mark(t: String) -> void:
	if _mark == null:
		_mark = Label3D.new()
		_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mark.no_depth_test = true
		_mark.font_size = 96
		_mark.outline_size = 18
		_mark.pixel_size = 0.006
		_mark.position.y = float(spec.get("head_y", 1.0)) + 1.0
		add_child(_mark)
	_mark.text = t
	_mark.modulate = Color(1, 0.35, 0.2) if t == "!" else Color(1, 0.85, 0.4)
	_mark.visible = true
	_mark_t = 2.5


## The foe's mind, each frame: what it notices, and where it goes when it is not hunting.
## Returns the way it wants to go, or null when it hunts and the usual closing in applies.
func _think(delta: float, p: Node3D, fd: float, speed: float):
	_mark_t -= delta
	if _mark and _mark_t <= 0.0:
		_mark.visible = false
	if has_meta("raid") or not Game.wasteland or boss != "":
		mind = "hunt"
		return null
	_look_t -= delta
	var seen := false
	if _look_t <= 0.0:
		_look_t = 0.3
		seen = sees(p)
		if seen:
			_last_known = p.global_position
			_lost_t = 0.0
			if mind in ["calm", "search"]:
				_alarm(p.global_position)
		elif mind == "hunt":
			_lost_t += 0.3
	if mind == "hunt" and fd < 5.0:
		_lost_t = 0.0   # close enough to hear its breathing
	# Badly hurt, an Unlit breaks off and runs, once, then comes back at you
	if mind == "hunt" and not _fled and kind.begins_with("unlit") and hp < max_hp * 0.3:
		_fled = true
		mind = "flee"
		_flee_t = 5.0
	match mind:
		"flee":
			_flee_t -= delta
			if _flee_t <= 0.0:
				mind = "hunt"
				return null
			var away := global_position - p.global_position
			away.y = 0.0
			return away.normalized() * speed * 1.15
		"hunt":
			if _lost_t > 7.0:
				mind = "search"
				_search_t = 12.0
				_show_mark("?")
			return null
		"search":
			_search_t -= delta
			if _search_t <= 0.0:
				mind = "calm"
				_home = global_position
				_wander = global_position
				return Vector3.ZERO
			var to := _last_known - global_position
			to.y = 0.0
			if to.length() > 2.0:
				return to.normalized() * speed * 0.7
			# There: it turns about, looking
			rotation.y += delta * 1.2
			return Vector3.ZERO
		_:
			var to := _wander - global_position
			to.y = 0.0
			if to.length() < 1.0:
				if randf() < delta * 0.25:
					_wander = _home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
				return Vector3.ZERO
			return to.normalized() * speed * 0.3


func _foe_move(delta: float, p: Node3D, dist: float, dir: Vector3, frozen: bool) -> void:
	var role: String = spec.get("role", "melee")
	var flat := p.global_position - global_position
	flat.y = 0.0
	var fd := flat.length()
	var fdir := flat / maxf(fd, 0.01)
	var speed: float = spec.speed * Game.difficulty_scale("speed") * (0.55 if _shot_slow > 0.0 else 1.0) * (0.6 if _guard else 1.0)
	_shot_slow = maxf(0.0, _shot_slow - delta)
	_flash = maxf(0.0, _flash - delta * 5.0)
	_bar_tick(delta)
	var want := Vector3.ZERO
	var hurt_bad := hp < max_hp * 0.35
	var away = null if frozen else _think(delta, p, fd, speed)
	if away != null:
		# Not hunting: it goes its own way, faces where it walks, and strikes at nothing
		_guard = false
		if role == "float":
			away.y = sin(_t * 1.7) * 0.4
			velocity = velocity.lerp(away, minf(1.0, delta * 3.0))
		else:
			velocity.x = lerpf(velocity.x, away.x, minf(1.0, delta * 6.0))
			velocity.z = lerpf(velocity.z, away.z, minf(1.0, delta * 6.0))
			velocity.y -= 22.0 * delta
		if Vector2(away.x, away.z).length() > 0.2:
			rotation.y = lerp_angle(rotation.y, atan2(away.x, away.z), minf(1.0, delta * 6.0))
		move_and_slide()
		if is_on_floor() and velocity.y < 0.0:
			velocity.y = 0.0
		if is_on_wall() and role != "float":
			velocity.y = 3.5
		var pc := Vector2(velocity.x, velocity.z).length()
		_fb.play("sprint" if pc > 4.5 else ("walk" if pc > 0.4 else "idle"), clampf(pc / 3.0, 0.7, 1.6) if pc > 0.4 else 1.0)
		return
	if not frozen:
		match role:
			"gun":
				var keep := 30.0 if hurt_bad else 18.0
				var side := fdir.cross(Vector3.UP) * _strafe
				if fd > keep + 6.0:
					want = fdir * speed
				elif fd < keep - 6.0:
					want = -fdir * speed * 0.9 + side * 1.5
				else:
					want = side * speed * 0.6
				if randf() < delta * 0.3:
					_strafe = -_strafe
			"float":
				want = fdir * speed
				want.y = (p.global_position.y + 1.2 - global_position.y) * 1.5 + sin(_t * 1.7) * 0.6
			_:
				# Close from its own side: a ring about the prey, each foe to its own place on it
				var slot := p.global_position + Vector3(cos(_flank), 0, sin(_flank)) * (1.6 if fd < 6.0 else 5.0)
				var to_slot := slot - global_position
				to_slot.y = 0.0
				want = (fdir if fd > 12.0 else to_slot.normalized()) * speed * (1.0 if fd > 3.0 else 0.6)
				if fd < 1.2 + spec.radius:
					want = Vector3.ZERO
				# An Unlit Blade raises its guard against a gun pointed at it
				if kind == "unlit_blade":
					var aim_at: bool = p == level.player and fd > 3.5 and fd < 18.0 and (-level.player.cam.global_transform.basis.z).dot(-fdir) > 0.93
					_guard = aim_at and _wind <= 0.0
		if role == "float":
			velocity = velocity.lerp(want, minf(1.0, delta * 3.0))
		elif is_on_floor():
			velocity.x = lerpf(velocity.x, want.x, minf(1.0, delta * 8.0))
			velocity.z = lerpf(velocity.z, want.z, minf(1.0, delta * 8.0))
		rotation.y = lerp_angle(rotation.y, atan2(fdir.x, fdir.z), minf(1.0, delta * 8.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
	if role != "float":
		velocity.y -= 22.0 * delta
	velocity += _knock - _knock_on
	_knock_on = _knock
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	var real_v := velocity
	velocity *= level.enemy_time
	move_and_slide()
	velocity = real_v
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	if is_on_wall() and not frozen and role != "float":
		velocity.y = 3.5
	var pace := Vector2(velocity.x, velocity.z).length()
	_fb.play("sprint" if pace > 4.5 else ("walk" if pace > 0.4 else ("holding-both" if role == "gun" and fd < 40.0 else "idle")), clampf(pace / 3.0, 0.7, 1.6) if pace > 0.4 else 1.0)
	if frozen or level.completed or level.failing:
		return
	_attack_cd -= delta
	_cry_cd -= delta
	if _cry_cd <= 0.0 and dist < 18.0:
		_cry_cd = randf_range(4.0, 8.0)
		match kind:
			"hollow", "warden":
				_cry("troll", -6)
			"vigil":
				_cry("whispers", -8)
			"saltbone":
				_cry("skitter", -4)
	if role == "gun":
		_gun_tick(delta, p, dist)
		return
	var reach: float = 1.3 + spec.radius
	_foe_strike(delta, p, dist, dir, reach)


## A melee foe's blow: it raises its arm (the warning), and strikes if you are still in reach. A
## pilgrim who turns the blow with a raised guard staggers it, and it stands open a while.
func _foe_strike(delta: float, p: Node3D, dist: float, dir: Vector3, reach: float) -> void:
	if _wind > 0.0:
		_wind -= delta
		if _wind <= 0.0:
			_attack_cd = 2.2 if kind in HEAVY_MOVERS else 1.3
			match _move:
				"sweep":
					_land_sweep(reach)
				"lunge":
					_land_lunge(p, dir, reach)
				"grab":
					_land_grab(p, dist, dir, reach)
				_:
					_land_strike(p, dist, dir, reach)
			_move = ""
		return
	if _attack_cd > 0.0 or _stagger > 0.0:
		return
	var heavy: bool = kind in HEAVY_MOVERS
	# A heavy one far enough off may lunge the gap; close in, it may sweep all round it or grab
	if heavy and dist > reach + 2.0 and dist < 9.0 and randf() < delta * 0.6:
		_begin_move("lunge", 0.9, dir)
		return
	if dist < reach + 0.4:
		var roll := randf()
		if heavy and roll < 0.25:
			_begin_move("sweep", 1.3, dir, reach)
		elif heavy and roll < 0.45:
			_begin_move("grab", 0.85, dir)
		else:
			_begin_move("", 1.0, dir)


## The heavy foes (and the knight, lich and walking dead) have three ways besides the plain blow, each
## with its own tell: a sweep (a ring on the ground round it), a lunge (a lane on the ground toward you),
## and a grab (it raises both arms and roars). Step out of the ring, off the lane, or away.
const HEAVY_MOVERS := ["unlit_brute", "knight", "warden", "colossus", "deacon", "hollow", "drowned"]
var _move := ""
static var moves_seen := {}   ## (for the tests)


func _begin_move(m: String, k: float, dir: Vector3, reach := 0.0) -> void:
	_move = m
	moves_seen[m] = int(moves_seen.get(m, 0)) + 1
	_wind_total = float(WINDUP.get(kind, 0.5)) * k / sqrt(Game.difficulty_scale("speed")) * (WRules.windup() if Game.wasteland else 1.0)
	_wind = _wind_total
	_guard = false
	match m:
		"sweep":
			level.shared("_w_warn", [global_position, reach + 1.5, _wind_total, 0])
			_fb.act("attack-melee-right", 0.4 / maxf(_wind_total, 0.2))
			level.sfx("swing", -6, global_position, 0.6)
		"lunge":
			var lane := 8.0
			level.shared("_w_warn", [global_position + dir * lane * 0.5, lane * 0.5, _wind_total, 1, atan2(dir.x, dir.z), spec.radius + 0.8])
			_cry("growl_%d" % (randi() % 3), -2)
		"grab":
			_fb.act("holding-both", 1.0)
			_cry("troll" if kind in ["hollow", "drowned", "colossus"] else "growl_%d" % (randi() % 3), -2)
			_flash = 1.0
		_:
			_fb.act("attack-melee-right", 0.55 / maxf(_wind_total, 0.2))
			level.sfx("swing", -10, global_position, 0.8)


func _land_strike(p: Node3D, dist: float, dir: Vector3, reach: float) -> void:
	if dist < reach + 0.7:
		if _perfect_guard(p):
			_parried(dir)
		else:
			level.sfx("chop" if kind.begins_with("unlit") or kind in ["warden", "knight"] else "bite", -3, global_position)
			level.hurt_target(p, spec.bite * FoeTraits.bite_mult(self), global_position)
			_afflict(p)
			FoeTraits.on_bite(self, p)
	else:
		level.sfx("swing", -6, global_position, 0.9)


## All round it, everyone within the ring: less than a full blow, and it cannot be parried, only left.
func _land_sweep(reach: float) -> void:
	level.sfx("swing", -2, global_position, 0.55)
	level.shared("_w_slam_fx", [global_position, reach + 1.5])
	for t in level.targets():
		var off: Vector3 = t.global_position - global_position
		if Vector2(off.x, off.z).length() < reach + 1.5 and absf(off.y) < 3.0:
			level.hurt_target(t, spec.bite * 0.8, global_position)


## Across the gap in a rush along the lane it showed: a hard blow at the end of it.
func _land_lunge(p: Node3D, dir: Vector3, reach: float) -> void:
	level.sfx("whoosh", -2, global_position, 0.8)
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var go := minf(to.length() - reach * 0.6, 8.0)
	if go > 0.0:
		var tw := create_tween()
		tw.tween_property(self, "global_position", global_position + dir * go, 0.25).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(0.27, false).timeout.connect(func():
		if not _alive or not is_instance_valid(p):
			return
		var d := global_position.distance_to(p.global_position)
		if d < reach + 1.0:
			if _perfect_guard(p):
				_parried(dir)
			else:
				level.sfx("chop", -2, global_position)
				level.hurt_target(p, spec.bite * 1.3, global_position))


## Close in, both arms: held fast a moment (the legs locked), and hurt less than a blow.
func _land_grab(p: Node3D, dist: float, dir: Vector3, reach: float) -> void:
	if dist >= reach + 0.5:
		level.sfx("swing", -6, global_position, 0.7)
		return
	if _perfect_guard(p):
		_parried(dir)
		return
	if p == level.player and level.player.dodge_t > 0.0:
		return
	level.sfx("bite", -2, global_position, 0.8)
	level.hurt_target(p, spec.bite * 0.6, global_position)
	if not level.sheltered(p.global_position):
		FoeTraits._afflict_target(self, p, "held", 1.2)


## What a blow leaves behind: fire, tar on the legs, or the foe's own wounds closing.
func _afflict(p: Node3D) -> void:
	if spec.has("drain"):
		hp = minf(max_hp, hp + float(spec.bite) * float(spec.drain))
	if not level.has_method("afflict"):
		return
	for what in ["burn", "slow", "freeze"]:
		if spec.has(what):
			FoeTraits._afflict_target(self, p, what, float(spec[what]))


## A gunman: it draws a bead with a glint at the muzzle (the warning), then fires a short burst.
## Each shot may miss, more so at range and against a moving target. It reloads after nine.
func _gun_tick(delta: float, p: Node3D, dist: float) -> void:
	if _aim > 0.0:
		_aim -= delta
		if _aim <= 0.0:
			_burst = int(spec.get("burst", 3))
			_attack_cd = 0.0
		return
	if _burst > 0:
		_attack_cd -= delta
		if _attack_cd <= 0.0:
			_attack_cd = 0.16
			_burst -= 1
			_ammo -= 1
			_shoot_at(p, dist)
			if _ammo <= 0:
				_ammo = int(spec.get("mag", 9))
				_burst = 0
				_attack_cd = 2.6
				level.sfx("pump", -6, global_position, 0.9)
			elif _burst == 0:
				_attack_cd = randf_range(1.4, 2.4)
		return
	if _attack_cd <= 0.0 and dist < float(spec.get("sight", 45.0)) and _can_see(p.global_position + Vector3(0, 1.3, 0)):
		_aim = float(spec.get("aim", 0.75))
		level.shared("_w_glint", [net_id])


func _shoot_at(p: Node3D, dist: float) -> void:
	var from: Vector3 = _fb.muzzle.global_position if _fb and _fb.muzzle else global_position + Vector3(0, 0.6, 0)
	var at := p.global_position + Vector3(0, 1.2, 0)
	var moving := 0.0
	if p is CharacterBody3D:
		moving = Vector2(p.velocity.x, p.velocity.z).length()
	# A real round, seen in flight: it goes where the gunman aimed, so moving, or stepping aside as it
	# comes, is how it is beaten. A marksman's flies faster and truer.
	var aimed := float(spec.get("aimed", 1.0))
	var spread := (0.25 + dist * 0.006) * aimed
	at += Vector3(randf_range(-spread, spread), randf_range(-spread * 0.6, spread * 0.6), randf_range(-spread, spread))
	_fb.act("holding-both-shoot")
	level.sfx("mg", -4, from, 0.85)
	var speed := 40.0 / clampf(aimed, 0.5, 1.2)
	var b := Bolt.new()
	b.level = level
	b.look = "round"
	b.damage = float(spec.bite)
	b.life = 3.0
	b.velocity = (at - from).normalized() * speed
	level.add_child(b)
	b.global_position = from
	if Net.online:
		Net.bolt(from, b.velocity, b.damage, "round")
