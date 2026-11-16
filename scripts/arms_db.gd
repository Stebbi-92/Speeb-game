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
	"shotgun": {"name": "Pump Shotgun", "slot": "primary", "mode": "pump", "dmg": 11.0, "pellets": 8, "spread": 0.075, "range": 45.0,
		"mag": 6, "rate": 0.7, "reload": "shell", "reload_t": 0.45, "sound": "shotgun", "kick": 1.0, "falloff": 25.0, "unlock": 1,
		"mounts": ["red_dot", "suppressor", "foregrip", "ext_mag"], "text": "Eight pellets and a pump between each. It forgives a poor aim, close in."},
	"machine_gun": {"name": "Machine Gun", "slot": "primary", "mode": "auto", "dmg": 15.0, "pellets": 1, "spread": 0.02, "range": 140.0,
		"mag": 30, "rate": 0.095, "reload": "mag", "reload_t": 2.1, "sound": "mg", "kick": 0.22, "falloff": 70.0, "unlock": 3,
		"mounts": ["red_dot", "scope", "suppressor", "foregrip", "ext_mag"], "text": "A steady stream that climbs as you hold it. Short bursts keep it true."},
	"sniper": {"name": "Sniper Rifle", "slot": "primary", "mode": "bolt", "dmg": 135.0, "pellets": 1, "spread": 0.0, "range": 400.0,
		"mag": 5, "rate": 1.25, "reload": "mag", "reload_t": 2.6, "sound": "sniper", "kick": 1.6, "falloff": 0.0, "unlock": 6, "zoom": 2.5,
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
	"pistol": {"name": "Pistol", "slot": "secondary", "mode": "semi", "dmg": 21.0, "pellets": 1, "spread": 0.012, "range": 90.0,
		"mag": 12, "rate": 0.16, "reload": "mag", "reload_t": 1.3, "sound": "pistol", "kick": 0.35, "falloff": 45.0, "unlock": 1,
		"mounts": ["red_dot", "suppressor", "ext_mag"], "text": "Quick to draw and quick to load. Something to reach for when the long gun runs dry."},
	"revolver": {"name": "Revolver", "slot": "secondary", "mode": "semi", "dmg": 52.0, "pellets": 1, "spread": 0.008, "range": 110.0,
		"mag": 6, "rate": 0.45, "reload": "mag", "reload_t": 2.0, "sound": "revolver", "kick": 0.8, "falloff": 60.0, "unlock": 5,
		"mounts": ["red_dot"], "text": "Six heavy rounds. Slow, and sure."},
}

## "arc" is how wide a swing sweeps (the least facing a foe needs: lower is wider); "back" multiplies a blow
## to a foe that is not facing you.
const MELEE := {
	"knife": {"name": "Knife", "dmg": 26.0, "rate": 0.24, "reach": 2.2, "arc": 0.75, "back": 2.5, "unlock": 2, "text": "Short and quick. Cruel from behind."},
	"hatchet": {"name": "Hatchet", "dmg": 55.0, "rate": 0.6, "reach": 2.6, "unlock": 1, "text": "A short haft and a broad head."},
	"machete": {"name": "Machete", "dmg": 40.0, "rate": 0.38, "reach": 2.8, "arc": 0.5, "unlock": 4, "text": "Lighter and quicker, for the swarm."},
	"sword": {"name": "Sword", "dmg": 66.0, "rate": 0.48, "reach": 3.0, "arc": 0.55, "unlock": 6, "text": "Old iron with a true edge. Quick enough, and long."},
	"sledge": {"name": "Sledge", "dmg": 100.0, "rate": 1.1, "reach": 2.9, "pierce": 2.0, "unlock": 9, "text": "Slow, and it breaks whatever it meets. Plate does not stop it."},
	"battle_axe": {"name": "Battle Axe", "dmg": 125.0, "rate": 0.95, "reach": 3.2, "arc": 0.3, "unlock": 11, "text": "A long haft and a bearded head. It sweeps all before it."},
}

const GRENADES := {
	"frag": {"name": "Frag Grenade", "dmg": 150.0, "radius": 6.0, "fuse": 2.2, "carry": 2, "unlock": 1, "text": "Thrown with G. Bursts after a moment."},
	"incendiary": {"name": "Fire Grenade", "dmg": 14.0, "radius": 5.0, "fuse": 1.4, "burn": 7.0, "carry": 2, "unlock": 7, "text": "Leaves the ground burning a while. The forms will not cross it unharmed."},
}

const GADGETS := {
	"bandages": {"name": "Field Dressing", "charges": 2, "recharge": 50.0, "unlock": 2, "text": "Used with T. Restores forty health over a few seconds."},
	"flare": {"name": "Flare", "charges": 2, "recharge": 40.0, "unlock": 4, "text": "Thrown with T. A red light that burns a long while and shows what moves near it."},
	"mine": {"name": "Salt Mine", "charges": 2, "recharge": 45.0, "unlock": 8, "text": "Set with T. Bursts when a form steps near."},
}

## What may be fitted to a gun. One thing to each slot: a sight above, something on the muzzle,
## a grip under the fore-end, a longer magazine.
const ATTACHMENTS := {
	"red_dot": {"name": "Red Dot", "slot": "sight", "unlock": 2, "text": "Tighter spread, and a steadier aim down the sight."},
	"foregrip": {"name": "Foregrip", "slot": "grip", "unlock": 3, "text": "Less kick and less climb. The shots keep closer together."},
	"suppressor": {"name": "Suppressor", "slot": "muzzle", "unlock": 5, "text": "Quiets the shot and hides the flash. A little less force."},
	"ext_mag": {"name": "Long Magazine", "slot": "mag", "unlock": 6, "text": "Holds half as many rounds again."},
	"scope": {"name": "Scope", "slot": "sight", "unlock": 7, "text": "Looks further when you aim."},
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
const SIGHTS := {"": {"zoom": 1.25, "spread": 0.6}, "red_dot": {"zoom": 1.4, "spread": 0.35}, "scope": {"zoom": 3.5, "spread": 0.15}}

const DEFAULT := {"primary": "shotgun", "secondary": "pistol", "melee": "hatchet", "grenade": "frag", "gadget": "bandages", "mounts": {}}

const MAX_LEVEL := 40


static func need(lv: int) -> int:
	## Profile experience from this level to the next.
	return int(round(250.0 * pow(lv, 1.25)))


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
