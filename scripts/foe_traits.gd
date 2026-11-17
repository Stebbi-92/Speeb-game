class_name FoeTraits
extends RefCounted
## The ways of the 0.10 forms, each named by a "trait" in its spec (see LesserSpeeb.VARIANTS). The host
## runs tick(); everyone runs look() for what is only seen. Each trait is one thing to learn about a form.
##
##   phase    there only part of the time; when it comes back it is behind you (the Flicker)
##   thief    its grip tears ammunition from you, and it runs; slay it to get it back
##   burrow   goes down into the ground and comes up again at your back
##   vent     hides in the ground until you are near, then bursts up in scalding steam, and again now and then
##   ravens   calls ravens to your face: for a moment you can hardly see
##   leap     springs at you from far off
##   choir    while it sings, the forms about it heal; comes in threes
##   split    slain, it cracks into two smaller ones
##   stealth  cannot be seen in the open past a few metres
##   pair     comes in twos; each strikes harder while the other stands near
##   stampede charges in straight lines, over and over; do not stand in its way. It fades after a while.

const PHASE_ON := 4.0
const PHASE_OFF := 2.2
const LIFE_STAMPEDE := 26.0
## How long before a way is done its warning comes: a sound and a sign where it will happen.
const TELL := {"phase": 0.7, "burrow": 0.9, "vent": 1.0, "ravens": 1.0}


static func trait_of(e) -> String:
	return str(e.spec.get("trait", ""))


## The host, when a form with a trait first stands up: the others of its band come with it.
static func start(e) -> void:
	var tr := trait_of(e)
	if tr == "":
		return
	e.set_meta("trait_t", randf_range(1.0, 3.0))
	if tr == "vent":
		e.set_hidden(true)
	var n := int(e.spec.get("pack", 1))
	if n > 1 and not e.has_meta("packed") and not e.puppet:
		e.set_meta("packed", true)
		var lvl = e.level
		var v: String = e.variant
		var at: Vector3 = e.global_position
		var raid: bool = e.has_meta("raid")
		lvl.get_tree().create_timer(0.1, false).timeout.connect(func():
			for i in n - 1:
				var q := at + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
				var o = lvl.spawn_at(v, q)
				if o:
					o.set_meta("packed", true)
					if raid:
						o.set_meta("raid", true))


## The host, each frame, after it has found its quarry. Returns true when the form should do nothing
## else this frame (it is under the ground, or between places).
static func tick(e, delta: float, p: Node3D, dist: float) -> bool:
	var tr := trait_of(e)
	if tr == "":
		return false
	var t: float = float(e.get_meta("trait_t", 0.0)) - delta
	e.set_meta("trait_t", t)
	# A form still wandering its ground, not yet roused, keeps its ways to itself
	if not e.hidden and tr != "vent" and e.mind not in ["hunt", "flee"]:
		return false
	match tr:
		"phase":
			if e.hidden:
				if t <= TELL.phase and not e.has_meta("told"):
					var back: Vector3 = p.global_basis.z
					back.y = 0.0
					e.set_meta("rise_at", p.global_position + back.normalized() * 3.0 + Vector3(0, 0.6, 0))
					_tell(e, "phase", e.get_meta("rise_at"))
				if t <= 0.0:
					_appear(e, e.get_meta("rise_at", p.global_position + Vector3(0, 0.6, 3)))
					_untold(e)
					e.set_meta("trait_t", PHASE_ON)
					e._attack_cd = 0.4
				return true
			if t <= 0.0 and dist < 30.0:
				e.set_hidden(true)
				e.set_meta("trait_t", PHASE_OFF)
				e.level.sfx("glitch", -12, e.global_position, 1.6)
				return true
		"burrow":
			if e.hidden:
				if t <= TELL.burrow and not e.has_meta("told"):
					var back: Vector3 = p.global_basis.z
					back.y = 0.0
					e.set_meta("rise_at", p.global_position + back.normalized() * 8.0)
					_tell(e, "burrow", e.get_meta("rise_at"))
				if t <= 0.0:
					_appear(e, e.get_meta("rise_at", p.global_position + Vector3(0, 0, 8)))
					_untold(e)
					e.set_meta("trait_t", randf_range(8.0, 11.0))
					e.level.sfx("crumble", -2, e.global_position)
					e.level.burst(e.global_position, Color(0.5, 0.45, 0.38))
				return true
			if t <= 0.0 and dist < 40.0 and dist > 6.0:
				e.level.sfx("crumble", -4, e.global_position, 0.8)
				e.level.burst(e.global_position, Color(0.5, 0.45, 0.38))
				e.set_hidden(true)
				e.set_meta("trait_t", 2.5)
				return true
		"vent":
			if e.hidden:
				if dist < 15.0 and not e.has_meta("told"):
					_tell(e, "vent", e.global_position)   # the ground rumbles and smokes before it bursts
				if dist < 9.0:
					_appear(e, e.global_position)
					_steam(e)
					_untold(e)
					e.set_meta("trait_t", randf_range(10.0, 14.0))
				return true
			if t <= TELL.vent and dist < 9.0 and not e.has_meta("told"):
				_tell(e, "vent", e.global_position)
			if t <= 0.0 and dist < 7.0:
				_steam(e)
				_untold(e)
				e.set_meta("trait_t", randf_range(10.0, 14.0))
		"ravens":
			if t <= TELL.ravens and dist < 25.0 and not e.has_meta("told"):
				_tell(e, "ravens", e.global_position + Vector3(0, 1.5, 0))   # it calls; the ravens gather over it
			if t <= 0.0 and dist < 25.0:
				_untold(e)
				e.set_meta("trait_t", randf_range(10.0, 13.0))
				e.level.sfx("critter_1", 0, p.global_position, 0.7)
				_afflict_target(e, p, "blind", 3.0)
		"leap":
			e._leap_cd = minf(e._leap_cd, 1.2)
		"choir":
			if t <= 0.0:
				e.set_meta("trait_t", 1.0)
				var sing: float = float(e.get_meta("sing_t", 0.0)) - 1.0
				e.set_meta("sing_t", sing)
				if sing <= 0.0:
					e.set_meta("sing_t", 4.0)
					_tell(e, "choir", e.global_position + Vector3(0, 1.2, 0))   # heard singing: find it and silence it
				for o in e.level.enemies:
					if o != e and is_instance_valid(o) and o.is_alive() and o.global_position.distance_to(e.global_position) < 12.0:
						o.hp = minf(o.max_hp, o.hp + 4.0)
		"stealth":
			# Unseen in the grass, but heard: a rustle where it moves
			if t <= 0.0 and dist < 18.0:
				e.set_meta("trait_t", randf_range(2.5, 4.0))
				_tell(e, "stealth", e.global_position)
		"stampede":
			e._busy = maxf(0.0, e._busy - delta)
			if e._charge_t <= 0.0 and e._busy <= 0.0 and e._spent <= 0.0 and t <= 0.0 and dist > 3.0:
				e.set_meta("trait_t", randf_range(3.0, 4.5))
				e._start_charge(p)
			var life: float = float(e.get_meta("life", LIFE_STAMPEDE)) - delta
			e.set_meta("life", life)
			if life <= 0.0:
				e.die(false)
				return true
	return false


## What its blow does beyond the harm. True if the form has taken something and should run.
static func on_bite(e, p: Node3D) -> void:
	match trait_of(e):
		"thief":
			if e.has_meta("stolen"):
				return
			_afflict_target(e, p, "rob", 0.0)
			e.set_meta("stolen", [p.get("peer_id") if p is Companion else Net.me()])
			e.mind = "flee"
			e._flee_t = 6.0


## How hard it strikes now: a pair together strikes harder.
static func bite_mult(e) -> float:
	if trait_of(e) != "pair":
		return 1.0
	for o in e.level.enemies:
		if o != e and is_instance_valid(o) and o.is_alive() and o.variant == e.variant and o.global_position.distance_to(e.global_position) < 8.0:
			return 1.3
	return 1.0


## Slain: a husk splits; a thief gives back what it took.
static func on_die(e, slain: bool) -> void:
	if not slain or e.puppet:
		return
	match trait_of(e):
		"split":
			if e.has_meta("shard"):
				return
			var lvl = e.level
			var v: String = e.variant
			var at: Vector3 = e.global_position
			lvl.get_tree().create_timer(0.2, false).timeout.connect(func():
				for i in 2:
					var o = lvl.spawn_at(v, at + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2)))
					if o:
						o.set_meta("shard", true)
						o.max_hp *= 0.4
						o.hp = o.max_hp
						var shrink: Tween = o.create_tween()
						shrink.tween_interval(0.9)
						shrink.tween_property(o, "scale", Vector3.ONE * 0.7, 0.2))
		"thief":
			var st = e.get_meta("stolen", [])
			if st is Array and not st.is_empty():
				Net.call_peer(int(st[0]), "_w_afflict", ["unrob", 0.0])


## Seen by everyone: a stalker in the grass fades from sight past a few metres.
static func look(e, delta: float) -> void:
	if trait_of(e) != "stealth" or e.hidden or e.level.player == null:
		return
	var d: float = e.global_position.distance_to(e.level.player.global_position)
	var shown: bool = d < 7.0 or e._flash > 0.05 or e.get_meta("struck_t", 0.0) > 0.0
	e.set_meta("struck_t", maxf(0.0, float(e.get_meta("struck_t", 0.0)) - delta))
	if e.visible != shown:
		e.visible = shown


## A warning everyone sees and hears: what is about to happen, and where.
static func _tell(e, what: String, at: Vector3) -> void:
	e.set_meta("told", true)
	if e.level.has_method("_w_tell"):
		e.level.shared("_w_tell", [what, at])


static func _untold(e) -> void:
	e.remove_meta("told")
	e.remove_meta("rise_at")


static func _appear(e, at: Vector3) -> void:
	var lv = e.level
	var y: float = at.y
	if lv.has_method("gpos") and lv.get("terrain") != null:
		y = maxf(at.y, lv.terrain.height_at(at.x, at.z) + 0.6)
	e.global_position = Vector3(at.x, y, at.z)
	e.set_hidden(false)


## Scalding steam about it: harm and burning to anyone near.
static func _steam(e) -> void:
	e.level.sfx("hiss", 2, e.global_position, 0.7)
	e.level.burst(e.global_position + Vector3(0, 1.0, 0), Color(0.9, 0.92, 0.95))
	for t in e.level.targets():
		if t.global_position.distance_to(e.global_position) < 4.5:
			e.level.hurt_target(t, 18.0, e.global_position)
			_afflict_target(e, t, "burn", 3.0)


static func _afflict_target(e, t: Node3D, what: String, secs: float) -> void:
	if t == e.level.player:
		if e.level.has_method("_w_afflict"):
			e.level._w_afflict(what, secs)
	elif t is Companion:
		Net.call_peer(t.peer_id, "_w_afflict", [what, secs])
