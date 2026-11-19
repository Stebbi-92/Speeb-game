class_name WDeep
extends RefCounted
## What lives far out on the Grey Sea, besides the Grey Wyrm:
## the Lamp-Eater, which rises under any boat that carries a lit lamp by night, and
## the Drowned Fleet, a grey ship of the old Lamp Fleet met on calm nights, crewed by Lost Vigils
## still looking for the Still Star. It can be boarded; what it carried is in its hold until dawn.

const FAR_OUT := 160.0   ## open water needed all round before the deep takes notice

var w
var _t := 10.0
var _hinted := false
var _fleet_night := -1          ## the night a grey ship was last seen (host)
var fleet: Node3D = null        ## the grey ship, while it sails tonight
var fleet_deck := Vector3.ZERO
var fleet_crate := ""
var _crewed := false
var paused := false             ## testing aid: hold the deep still for a picture


func _init(world) -> void:
	w = world


## The host, about once a second while the world turns.
func host_tick(delta: float) -> void:
	if not Net.authority() or paused:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 10.0
	if not w.night:
		if is_instance_valid(fleet):
			w.shared("_w_fleet_gone", [])
		for e in w.enemies:
			if is_instance_valid(e) and e.is_alive() and e.kind == "lampeater":
				e.die(false)   # it goes down again with the light
		return
	_lamp_watch()
	_fleet_watch()
	_crew_watch()


func _far_out(p: Vector3) -> bool:
	if w.lights and w.lights.lane_safe(p):
		return false   # a lit sea lane: the deep keeps off it
	return w.terrain.is_water(p.x, p.z, 4.0) and w.sea.open_water(p, 240.0) >= FAR_OUT


## A lit lamp on open water by night: the pale thing comes up beneath it.
func _lamp_watch() -> void:
	for e in w.enemies:
		if is_instance_valid(e) and e.is_alive() and e.kind == "lampeater":
			return
	for b in w.boats.values():
		if not is_instance_valid(b) or b.riders.is_empty() or not b.shows_light():
			continue
		if not _far_out(b.global_position) or randf() > 0.2:
			continue
		var at: Vector3 = b.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		at.y = WIsles.SEA_Y - 2.0
		var e = w.spawn_at("lampeater", at)
		if e:
			w.crowd_great(e)
			e.set_meta("raid", true)
			w.shared("_w_note", ["The water under the lamp goes pale."])
			w.sfx("horror_deep", -2, at, 0.55)
		return


## On a quiet night, far out, grey sails.
func _fleet_watch() -> void:
	if is_instance_valid(fleet) or _fleet_night == w.nights or w.nights < 2 or w.weather.kind in ["gale", "ashstorm"]:
		return
	for b in w.boats.values():
		if not is_instance_valid(b) or b.riders.is_empty() or not _far_out(b.global_position):
			continue
		if randf() > 0.08:
			continue
		for tries in 8:
			var a := randf() * TAU
			var at: Vector3 = b.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(70.0, 95.0)
			if _far_out(at):
				_fleet_night = w.nights
				w.shared("_w_fleet", [Vector3(at.x, WIsles.SEA_Y, at.z), randf() * TAU, w.day])
				return
		return


## Everyone: the grey ship is built where the host says, for tonight only.
func build_fleet(at: Vector3, yaw: float, d: int) -> void:
	clear_fleet()
	_crewed = false
	fleet = Node3D.new()
	fleet.position = at
	fleet.rotation.y = yaw
	w.add_child(fleet)
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.62, 0.66, 0.66, 0.82)
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grey.emission_enabled = true
	grey.emission = Color(0.45, 0.55, 0.6)
	grey.emission_energy_multiplier = 0.25
	var ship := WIsleLife.put(fleet, "pirate", "ship-ghost", Vector3(0, -1.2, 0), 0.0, 1.0, false, Vector3.ZERO, grey, 600.0)
	# Sized to some twenty paces from stem to stern, whatever the model's own measure
	var bb := WIsleLife.bounds("pirate/ship-ghost", ship)
	var s := 22.0 / maxf(1.0, maxf(bb.size.x, bb.size.z))
	ship.scale = Vector3.ONE * s
	var deck_y := -1.2 + (bb.position.y + bb.size.y * 0.32) * s
	var long_x := bb.size.x > bb.size.z
	var deck := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(bb.size.x * s * 0.7, 0.4, bb.size.z * s * 0.3) if long_x else Vector3(bb.size.x * s * 0.3, 0.4, bb.size.z * s * 0.7)
	cs.shape = bs
	cs.position = Vector3((bb.position.x + bb.size.x * 0.5) * s, deck_y - 0.2, (bb.position.z + bb.size.z * 0.5) * s)
	deck.add_child(cs)
	fleet.add_child(deck)
	fleet_deck = fleet.to_global(cs.position + Vector3(0, 0.5, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.85, 0.95)
	l.light_energy = 1.5
	l.omni_range = 26.0
	l.position = cs.position + Vector3(0, 6, 0)
	fleet.add_child(l)
	# A rope over the side, and the hold's chest on deck
	var side := Vector3(0, 0, bs.size.z * 0.5 + 0.8) if long_x else Vector3(bs.size.x * 0.5 + 0.8, 0, 0)
	var a: Area3D = w.interact_area(fleet.to_global(cs.position + side + Vector3(0, -deck_y + 0.3, 0)), 3.0, "Climb aboard the grey ship", func(): board(), 0.0, false)
	a.set_meta("prompt", "Climb aboard the grey ship")
	a.reparent(fleet)
	var down: Area3D = w.interact_area(fleet_deck + fleet.global_basis * (side * 0.8), 1.4, "Climb down into the sea", func(): leave(), 0.0, false)
	down.set_meta("prompt", "Climb down into the sea")
	down.reparent(fleet)
	fleet_crate = "fleet_%d" % d
	w._crate(fleet_crate, fleet_deck + Vector3(0, -0.5, 0) - fleet.global_basis * (side * 0.4), "vault", yaw, false)
	var lbl: Label3D = w.label3d("A ship of the Lamp Fleet", fleet_deck + Vector3(0, 7.0, 0), 0.7, Color(0.75, 0.85, 0.9), 0.0, true)
	lbl.visibility_range_end = 120.0
	lbl.reparent(fleet)
	w.hud.notify("Grey sails on the water. A ship of the old Lamp Fleet, still looking for the Still Star.")
	w.sfx("bell", -6, at, 0.6)


func clear_fleet() -> void:
	if is_instance_valid(fleet):
		fleet.queue_free()
	fleet = null
	if fleet_crate != "" and w.crates.has(fleet_crate):
		var c: Dictionary = w.crates[fleet_crate]
		if is_instance_valid(c.body) and c.body.get_parent():
			c.body.get_parent().queue_free()
		w.crates.erase(fleet_crate)
		w.containers.erase(fleet_crate)
	fleet_crate = ""


func board() -> void:
	if w.player.vessel != null and is_instance_valid(w.player.vessel):
		w._leave_boat(w.player.vessel)
	w.player.place(fleet_deck + Vector3(0, 0.4, 0), w.player.yaw)
	w.hud.say("The deck is wet, and the lamps are all out. Someone is still keeping watch.", 4.0)


func leave() -> void:
	var b := fleet.global_basis
	w.player.place(fleet.global_position + b * Vector3(0, 0, 14.0) + Vector3(0, 0.5, 0), w.player.yaw)


## The host: the grey ship's watch stands up when the living come aboard.
func _crew_watch() -> void:
	if not is_instance_valid(fleet) or _crewed:
		return
	for t in w.targets():
		if t.global_position.distance_to(fleet_deck) < 9.0:
			_crewed = true
			for k in WCrowd.scale_near(w, fleet_deck, 5):
				var e = w.spawn_at(["vigil", "vigil", "saltbone", "vigil", "warden"][k % 5], fleet_deck + Vector3(randf_range(-4, 4), 1.0, randf_range(-4, 4)))
				if e:
					e.set_meta("raid", true)
			w.shared("_w_note", ["The watch turns to look at you. They have been waiting a long time."])
			return


## Every machine: a word the first time a lit boat is far out at night.
func local_tick() -> void:
	if _hinted or w.player == null or not w.night:
		return
	var v = w.player.vessel
	if v != null and is_instance_valid(v) and v.shows_light() and _far_out(w.player.global_position):
		_hinted = true
		w.hud.notify("Far out at night, a lit lamp draws things up from the deep. Hold %s aboard to douse it." % Game.key_text("interact"))
