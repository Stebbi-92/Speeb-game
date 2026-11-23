class_name ArmsDB
extends RefCounted
## Every weapon, attachment, grenade and gadget a pilgrim may carry, and the level that unlocks it.
##
## A gun's "mode" says how it fires:
##   pump   a spread of pellets, then a pump      semi   one shot per click
##   auto   fires while held                      spin   fires while held, after spinning up
##   bolt   one heavy shot, then the bolt         rocket a projectile that bursts on contact
##   flame  a short cone of fire while held: burns all it reaches, and leaves the ground alight
## "reload" is "shell" (one at a time, can be cut short) or "mag" (all at once).

const GUNS := {
	"shotgun": {"name": "Pump Shotgun", "slot": "primary", "mode": "pump", "dmg": 12.0, "pellets": 8, "spread": 0.075, "range": 45.0,
		"mag": 6, "rate": 0.7, "reload": "shell", "reload_t": 0.45, "sound": "shotgun", "kick": 1.0, "falloff": 25.0, "unlock": 1,
		"mounts": ["red_dot", "suppressor", "foregrip", "ext_mag"], "text": "Eight pellets and a pump between each. It forgives a poor aim, close in."},
	"autoshotgun": {"name": "Autoshotgun", "slot": "primary", "mode": "semi", "dmg": 9.0, "pellets": 8, "spread": 0.085, "range": 40.0,
		"mag": 7, "rate": 0.32, "reload": "shell", "reload_t": 0.42, "sound": "autoshotgun", "kick": 1.1, "falloff": 22.0, "unlock": 9,
		"mounts": ["red_dot", "suppressor", "foregrip", "ext_mag"], "text": "A shotgun that works itself. Eight pellets as fast as you pull, and slow to fill."},
	"smg": {"name": "SMG", "slot": "primary", "mode": "auto", "dmg": 14.0, "pellets": 1, "spread": 0.016, "range": 85.0,
		"mag": 30, "rate": 0.075, "reload": "mag", "reload_t": 2.6, "sound": "smg", "kick": 0.2, "falloff": 40.0, "unlock": 7,
		"mounts": ["suppressor", "ext_mag"], "text": "Pistol rounds, thirty at a run. Light, quick and steady, and short of reach."},
	"machine_gun": {"name": "Machine Gun", "slot": "primary", "mode": "auto", "dmg": 17.0, "pellets": 1, "spread": 0.02, "range": 140.0,
		"mag": 30, "rate": 0.095, "reload": "mag", "reload_t": 2.1, "sound": "rifle", "kick": 0.22, "falloff": 70.0, "unlock": 3,
		"mounts": ["red_dot", "scope", "suppressor", "foregrip", "ext_mag"], "text": "A steady stream that climbs as you hold it. Short bursts keep it true."},
	"lmg": {"name": "Belt Gun", "slot": "primary", "mode": "auto", "dmg": 21.0, "pellets": 1, "spread": 0.03, "range": 160.0,
		"mag": 100, "rate": 0.11, "reload": "mag", "reload_t": 5.0, "sound": "mg", "kick": 0.3, "falloff": 80.0, "unlock": 8, "slow": 0.85,
		"mounts": ["red_dot", "scope", "suppressor", "foregrip"], "text": "A belt of a hundred heavy rounds. Slow to load and heavy to carry, and it does not stop."},
	"sniper": {"name": "Sniper Rifle", "slot": "primary", "mode": "bolt", "dmg": 135.0, "pellets": 1, "spread": 0.0, "range": 400.0,
		"mag": 5, "rate": 1.25, "reload": "mag", "reload_t": 2.6, "sound": "sniper", "kick": 1.6, "falloff": 0.0, "unlock": 6, "zoom": 8.0, "iron_zoom": 2.0,
		"mounts": ["scope", "suppressor", "ext_mag"], "text": "One heavy round, then the bolt. Aim to look down the glass."},
	"rocket": {"name": "Rocket Launcher", "slot": "primary", "mode": "rocket", "dmg": 170.0, "radius": 5.5, "speed": 38.0, "pellets": 1,
		"spread": 0.0, "range": 300.0, "mag": 1, "rate": 0.9, "reload": "mag", "reload_t": 2.4, "sound": "rocket", "kick": 1.4, "falloff": 0.0,
		"unlock": 10, "mounts": ["scope"], "text": "Bursts where it strikes and takes everything near with it. Keep it far from your own feet."},
	"minigun": {"name": "Minigun", "slot": "primary", "mode": "spin", "dmg": 10.0, "pellets": 1, "spread": 0.04, "range": 110.0,
		"mag": 200, "rate": 0.042, "reload": "mag", "reload_t": 4.2, "sound": "minigun", "kick": 0.12, "falloff": 60.0, "unlock": 12,
		"spin": 0.7, "slow": 0.6, "mounts": [], "text": "It must spin before it speaks, and it slows the one who carries it. Then nothing stands."},
	"flamer": {"name": "Flamethrower", "slot": "primary", "mode": "flame", "dmg": 7.0, "pellets": 1, "spread": 0.0, "range": 10.0,
		"mag": 100, "rate": 0.07, "reload": "mag", "reload_t": 3.2, "sound": "jet", "kick": 0.0, "falloff": 0.0, "unlock": 14, "cone": 0.88,
		"mounts": [], "text": "A tank of lamp fuel and a lit tongue. Short reach, and everything in front of it burns."},
	"pistol": {"name": "Pistol", "slot": "secondary", "mode": "semi", "dmg": 18.0, "pellets": 1, "spread": 0.012, "range": 90.0,
		"mag": 12, "rate": 0.16, "reload": "mag", "reload_t": 1.3, "sound": "pistol45", "kick": 0.35, "falloff": 45.0, "unlock": 1,
		"mounts": ["red_dot", "suppressor", "ext_mag"], "text": "Quick to draw and quick to load. Something to reach for when the long gun runs dry."},
	"pistol9": {"name": "Auto Pistol", "slot": "secondary", "mode": "auto", "dmg": 13.0, "pellets": 1, "spread": 0.022, "range": 70.0,
		"mag": 18, "rate": 0.05, "reload": "mag", "reload_t": 1.5, "sound": "pistol9", "kick": 0.28, "falloff": 35.0, "unlock": 4,
		"mounts": ["red_dot", "reflex", "suppressor", "compensator", "flash_hider", "ext_mag"], "text": "Eighteen rounds as fast as you can hold it down. It climbs: keep it close."},
	"revolver": {"name": "Revolver", "slot": "secondary", "mode": "semi", "dmg": 52.0, "pellets": 1, "spread": 0.008, "range": 110.0,
		"mag": 6, "rate": 0.45, "reload": "mag", "reload_t": 2.0, "sound": "revolver", "kick": 0.8, "falloff": 60.0, "unlock": 5,
		"mounts": ["red_dot"], "text": "Six heavy rounds. Slow, and sure."},
	# The far arms: made only of the far lands' stuff, never in the trials. "look" is the gun whose body they borrow.
	"carbine": {"name": "Sunglass Carbine", "slot": "primary", "mode": "semi", "dmg": 50.0, "pellets": 1, "spread": 0.005, "range": 240.0,
		"mag": 15, "rate": 0.2, "reload": "mag", "reload_t": 2.0, "sound": "rifle", "kick": 0.45, "falloff": 120.0, "unlock": 99, "far": true,
		"look": "machine_gun", "mounts": ["red_dot", "scope", "suppressor", "foregrip", "ext_mag"],
		"text": "Sunglass sights and a long, true barrel. One heavy rifle round per pull, as fast as you can aim."},
	"hand_cannon": {"name": "Dome-steel Hand Cannon", "slot": "secondary", "mode": "semi", "dmg": 17.0, "pellets": 7, "spread": 0.055, "range": 40.0,
		"mag": 2, "rate": 0.3, "reload": "mag", "reload_t": 1.7, "sound": "shotgun", "kick": 1.3, "falloff": 22.0, "unlock": 99, "far": true,
		"look": "revolver", "mounts": ["red_dot"], "text": "Two shells in a short dome-steel barrel. A side arm that hits like a shotgun, close in."},
}

## "arc" is how wide a swing sweeps (the least facing a foe needs: lower is wider); "back" multiplies a blow
## to a foe that is not facing you.
const MELEE := {
	"knife": {"name": "Knife", "dmg": 26.0, "rate": 0.24, "reach": 2.2, "arc": 0.75, "back": 2.5, "unlock": 2, "text": "Short and quick. Cruel from behind."},
	"hatchet": {"name": "Hatchet", "dmg": 42.0, "rate": 0.6, "reach": 2.6, "unlock": 1, "text": "A short haft and a broad head."},
	"machete": {"name": "Machete", "dmg": 40.0, "rate": 0.38, "reach": 2.8, "arc": 0.5, "unlock": 4, "text": "Lighter and quicker, for the swarm."},
	"sword": {"name": "Sword", "dmg": 66.0, "rate": 0.48, "reach": 3.0, "arc": 0.55, "unlock": 6, "text": "Old iron with a true edge. Quick enough, and long."},
	"sledge": {"name": "Sledge", "dmg": 100.0, "rate": 1.1, "reach": 2.9, "pierce": 2.0, "unlock": 9, "harm": "blunt", "text": "Slow, and it breaks whatever it meets. Plate does not stop it."},
	"glaive": {"name": "Obsidian Glaive", "dmg": 120.0, "rate": 0.85, "reach": 3.6, "arc": 0.45, "pierce": 1.5, "unlock": 16, "text": "Black glass on a long haft. The longest reach, and it bites through plate."},
	"battle_axe": {"name": "Battle Axe", "dmg": 125.0, "rate": 0.95, "reach": 3.2, "arc": 0.3, "unlock": 11, "text": "A long haft and a bearded head. It sweeps all before it."},
	"war_pick": {"name": "Ice-iron War-pick", "dmg": 150.0, "rate": 0.9, "reach": 3.0, "arc": 0.4, "pierce": 2.5, "unlock": 99, "far": true, "look": "sledge",
		"harm": "blunt", "text": "A spike of Frostmark iron on a horn haft. It goes through any plate."},
}

const GRENADES := {
	"frag": {"name": "Frag Grenade", "dmg": 150.0, "radius": 6.0, "fuse": 2.2, "carry": 2, "unlock": 1, "text": "Thrown with G. Bursts after a moment."},
	"incendiary": {"name": "Fire Grenade", "dmg": 14.0, "radius": 5.0, "fuse": 1.4, "burn": 7.0, "carry": 2, "unlock": 7, "text": "Leaves the ground burning a while. Enemies will not cross it unharmed."},
}

const GADGETS := {
	"bandages": {"name": "Field Dressing", "charges": 2, "recharge": 50.0, "unlock": 2, "text": "Used with T. Restores forty health over a few seconds."},
	"flare": {"name": "Flare", "charges": 2, "recharge": 40.0, "unlock": 4, "text": "Thrown with T. A red light that burns a long while and shows what moves near it."},
	"mine": {"name": "Salt Mine", "charges": 2, "recharge": 45.0, "unlock": 8, "text": "Set with T. Bursts when an enemy steps near."},
}

## What may be fitted to a gun. One thing to each slot: a sight above, something on the muzzle,
## a grip under the fore-end, a longer magazine.
const ATTACHMENTS := {
	"red_dot": {"name": "Red Dot", "slot": "sight", "unlock": 2, "text": "Tighter spread, and a steadier aim down the sight."},
	"foregrip": {"name": "Foregrip", "slot": "grip", "unlock": 3, "text": "Less kick and less climb. The shots keep closer together."},
	"suppressor": {"name": "Suppressor", "slot": "muzzle", "unlock": 5, "text": "Quiets the shot and hides the flash. A little less force."},
	"ext_mag": {"name": "Long Magazine", "slot": "mag", "unlock": 6, "text": "Holds half as many rounds again."},
	"scope": {"name": "Scope", "slot": "sight", "unlock": 7, "text": "Looks further when you aim."},
	"reflex": {"name": "Reflex Sight", "slot": "sight", "unlock": 99, "mods": {"aim": 1.12}, "text": "An open glass on a low rail. Quickest to the eye."},
	"holo": {"name": "Holo Sight", "slot": "sight", "unlock": 99, "mods": {"spread": 0.94}, "text": "A boxed window with a ring to aim by. Steady at middle reach."},
	"combat_scope": {"name": "Short Scope", "slot": "sight", "unlock": 99, "mods": {"aim": 0.92}, "text": "A short, stout glass. Brings the middle distance near."},
	"heavy_suppressor": {"name": "Heavy Suppressor", "slot": "muzzle", "unlock": 99, "quiet": true, "mods": {"kick": 0.85, "aim": 0.9, "dmg": 0.95},
		"text": "A thick can. Quiet, and it takes the kick out; heavy at the end of the gun."},
	"compensator": {"name": "Compensator", "slot": "muzzle", "unlock": 99, "mods": {"kick": 0.8}, "text": "Ports cut in the muzzle. The gun climbs less."},
	"muzzle_brake": {"name": "Muzzle Brake", "slot": "muzzle", "unlock": 99, "mods": {"kick": 0.65, "spread": 1.06}, "text": "A broad brake. Kills the kick, and throws the shots a little wide."},
	"flash_hider": {"name": "Flash Hider", "slot": "muzzle", "unlock": 99, "noflash": true, "mods": {"spread": 0.95}, "text": "Hides the flash, so foes see less of where you are."},
	"angled_grip": {"name": "Angled Grip", "slot": "grip", "unlock": 99, "mods": {"aim": 1.12, "kick": 0.92}, "text": "A slanted grip under the barrel. Quicker to raise."},
	"slim_grip": {"name": "Slim Grip", "slot": "grip", "unlock": 99, "mods": {"kick": 0.85, "spread": 0.95}, "text": "A thin upright grip. Holds the gun down."},
	# The waste's own parts, made at a workbench. "mods" multiply the gun: dmg, rate (time between
	# shots), spread, range, reload (time), kick, aim (how fast it is raised), crit, mag.
	"long_barrel": {"name": "Long Barrel", "slot": "barrel", "unlock": 99, "mods": {"range": 1.35, "dmg": 1.08, "spread": 0.85, "aim": 0.85}, "text": "Reaches further and hits a little harder. Slower to raise."},
	"sawn_barrel": {"name": "Sawn Barrel", "slot": "barrel", "unlock": 99, "mods": {"aim": 1.3, "spread": 1.2, "range": 0.75, "dmg": 1.06}, "text": "Quick to raise, and wild. For close work."},
	"heavy_barrel": {"name": "Heavy Barrel", "slot": "barrel", "unlock": 99, "mods": {"kick": 0.7, "spread": 0.9, "aim": 0.9}, "text": "Thick walled. It barely climbs."},
	"light_stock": {"name": "Light Stock", "slot": "stock", "unlock": 99, "mods": {"aim": 1.25, "kick": 1.1}, "text": "A frame of bent rod. Up to the eye in a blink."},
	"padded_stock": {"name": "Padded Stock", "slot": "stock", "unlock": 99, "mods": {"kick": 0.75}, "text": "Hide over the butt. Softens the kick."},
	"heavy_stock": {"name": "Heavy Stock", "slot": "stock", "unlock": 99, "mods": {"kick": 0.65, "spread": 0.9, "aim": 0.85}, "text": "Solid wood. Steady, and slow."},
	"rapid_receiver": {"name": "Rapid Receiver", "slot": "receiver", "unlock": 99, "mods": {"rate": 0.87, "dmg": 0.95}, "text": "A lighter action. Fires faster, a little weaker."},
	"heavy_receiver": {"name": "Heavy Receiver", "slot": "receiver", "unlock": 99, "mods": {"dmg": 1.15, "rate": 1.12, "kick": 1.1}, "text": "Takes a heavier load. Harder hits, slower shots."},
	"smooth_receiver": {"name": "Smooth Action", "slot": "receiver", "unlock": 99, "mods": {"reload": 0.8}, "text": "Polished and oiled. Loads faster."},
	# Loads: what the rounds are made of. "pierce" above 1 goes through plate; below 1, plate stops more.
	"piercing_rounds": {"name": "Piercing Rounds", "slot": "ammo", "unlock": 99, "mods": {"pierce": 2.0, "dmg": 0.92}, "text": "Hardened tips. They go through plate, and hit flesh a little less."},
	"hollow_rounds": {"name": "Hollow Rounds", "slot": "ammo", "unlock": 99, "mods": {"pierce": 0.5, "dmg": 1.18}, "text": "Soft-nosed. Cruel on flesh, useless on plate."},
}
const SLOT_NAMES := {"sight": "Sight", "muzzle": "Muzzle", "grip": "Grip", "mag": "Magazine", "barrel": "Barrel", "stock": "Stock", "receiver": "Receiver", "ammo": "Load"}

## What the right mouse does to the view and the spread, per sight.
const SIGHTS := {"": {"zoom": 1.25, "spread": 0.6}, "red_dot": {"zoom": 1.4, "spread": 0.35}, "scope": {"zoom": 8.0, "spread": 0.15},
	"reflex": {"zoom": 1.35, "spread": 0.38}, "holo": {"zoom": 1.45, "spread": 0.32}, "combat_scope": {"zoom": 4.0, "spread": 0.2}}

const DEFAULT := {"primary": "shotgun", "secondary": "pistol", "melee": "hatchet", "grenade": "frag", "gadget": "bandages", "mounts": {}}

const MAX_LEVEL := 40


static func need(lv: int) -> int:
	## Profile experience from this level to the next.
	return int(round(250.0 * pow(lv, 1.25)))


## The arm whose body a far arm borrows (its model, flash and spent case); any other arm is its own.
static func look(id: String) -> String:
	return str(GUNS.get(id, MELEE.get(id, {})).get("look", id))


## Whether an arm is one of the far arms: made only in the waste, of the far lands' stuff.
static func far(id: String) -> bool:
	return bool(GUNS.get(id, MELEE.get(id, {})).get("far", false))


static func table(kind: String) -> Dictionary:
	match kind:
		"primary", "secondary":
			return GUNS
		"melee":
			return MELEE
		"grenade":
			return GRENADES
		"gadget":
			return GADGETS
	return {}


## The choices for one loadout slot, in unlock order.
static func choices(kind: String) -> Array:
	var t := table(kind)
	var out: Array = []
	for id in t:
		if kind in ["primary", "secondary"] and t[id].slot != kind:
			continue
		if t[id].get("far", false):
			continue
		out.append(id)
	out.sort_custom(func(a, b): return int(t[a].unlock) < int(t[b].unlock))
	return out


## Everything that a level unlocks, as readable names.
static func unlocked_at(lv: int) -> Array:
	var out: Array = []
	for t in [GUNS, MELEE, GRENADES, GADGETS, ATTACHMENTS]:
		for id in t:
			if int(t[id].unlock) == lv:
				out.append(t[id].name)
	return out
