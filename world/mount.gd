class_name WCat
extends Area3D
## A riding cat of the waste: a great, patient cat with a Speeb's face. Strays wander near the towns;
## feed one three times and it is yours. Saddled, it carries you a little faster than walking, and much
## faster for a short sprint on its own breath. It waits where you leave it, and comes when you whistle.
## Each pilgrim sees their own cat; friends see it under you while you ride.

const FACES := ["_speeb", "floofspeeb", "bunnyspeeb", "chillspeeb", "dapperspeeb", "scarfspeeb", "vikingspeeb",
	"autumnspeeb", "snowspeeb", "mintspeeb", "jadespeeb", "moonspeeb", "rosespeeb", "serenespeeb", "blushspeeb"]
const NAMES := ["Ember", "Soot", "Pebble", "Ashpaw", "Dune", "Biscuit", "Thistle", "Mote", "Cinder", "Saltwhisker",
	"Bramble", "Nutmeg", "Tallow", "Wick", "Juniper", "Clove", "Moth", "Fennel"]
## Armour a cat can wear: what it turns aside of the harm that reaches it, and its cost.
const BARDING := {
	"": {"name": "None", "guard": 0.0},
	"hide_barding": {"name": "Hide Barding", "guard": 0.2, "cost": {"hide": 6, "cloth": 2}},
	"bone_barding": {"name": "Bone Barding", "guard": 0.35, "cost": {"bone": 10, "hide": 4}},
	"iron_barding": {"name": "Iron Barding", "guard": 0.5, "cost": {"scrap": 20, "hide": 4}},
}
const WALK := 1.8         ## times the rider's walking pace
const SPRINT := 2.8       ## times the rider's walking pace, on the cat's breath
const BREATH_MAX := 100.0
const HP_MAX := 160.0
const SOLID_LAYER := 64   ## the cat's body: only foes collide with it
const REST_HURT := 30.0   ## seconds a hurt-out cat sulks before it will carry you again (meat ends it at once)

var w                       ## the wasteland
var face := "_speeb"
var cat_name := ""
var wild := true
var fed := 0               ## a stray's meals so far; three and it follows you
var barding := ""
var hp := HP_MAX
var breath := BREATH_MAX
var winded := false
var ridden := false
var puppet := false        ## a friend's cat, drawn under them: it only moves its legs
var _last := Vector3.ZERO
var _going := Vector3.ZERO  ## where it trots to when called (or a stray wanders to)
var _call := false
var _t := 0.0
var _speed := 0.0
var _ph := 0.0
var _body: Node3D
var _legs: Array = []
var _tail: Node3D
var _head: Emoji3D
var _bard: Node3D
var _label: Label3D
var _rest := 0.0           ## hurt out, it sulks a while before it can be ridden again
var _shy := 0.0
var _sprint_t := 0.0       ## time since the last sprint step; breath only returns once it runs out


func setup(lvl, f: String, is_wild: bool) -> WCat:
	w = lvl
	face = f
	wild = is_wild
	return self


func _ready() -> void:
	collision_layer = 0 if puppet else 1
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.9, 1.1, 1.8)
	cs.shape = sh
	cs.position.y = 0.75
	add_child(cs)
	# A solid body foes run into (and not through); the rider's own step ignores it
	var solid := AnimatableBody3D.new()
	solid.sync_to_physics = false   # on, a body moved outside the physics step lags behind it and foes pass through
	solid.collision_layer = SOLID_LAYER
	solid.collision_mask = 0
	var scs := CollisionShape3D.new()
	scs.shape = sh
	scs.position.y = 0.75
	solid.add_child(scs)
	add_child(solid)
	_build()
	_label = Label3D.new()
	_label.font_size = 40
	_label.pixel_size = 0.005
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.15
	add_child(_label)
	_refresh()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(size: Vector3, pos: Vector3, m: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## A big cat of plain shapes, in the colours of its face; the face itself is a Speeb's, alive.
func _build() -> void:
	var tex: Texture2D = load("res://assets/emoji/%s.png" % face)
	var coat: Color = Emoji3D._fur(face, tex) if tex else Color(0.7, 0.6, 0.5)
	var fur := _mat(coat)
	var dark := _mat(coat.darkened(0.35))
	var pale := _mat(coat.lightened(0.3))
	_body = Node3D.new()
	add_child(_body)
	_box(Vector3(0.62, 0.55, 1.35), Vector3(0, 0.95, 0), fur, _body)
	_box(Vector3(0.5, 0.18, 1.0), Vector3(0, 0.66, 0.05), pale, _body)      # the pale belly
	_box(Vector3(0.56, 0.6, 0.4), Vector3(0, 1.08, 0.62), fur, _body)       # the chest, a little higher
	for z in [0.48, -0.5]:
		for x in [-0.2, 0.2]:
			var leg := Node3D.new()
			leg.position = Vector3(x, 0.78, z)
			_body.add_child(leg)
			_box(Vector3(0.17, 0.7, 0.19), Vector3(0, -0.35, 0), fur, leg)
			_box(Vector3(0.2, 0.08, 0.24), Vector3(0, -0.74, 0.03), pale, leg)  # the paw
			_legs.append(leg)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.1, -0.66)
	_body.add_child(_tail)
	# Up and back from the rump, then curling higher at the tip
	_box(Vector3(0.12, 0.12, 0.62), Vector3(0, 0.17, -0.25), dark, _tail).rotation.x = 0.6
	_box(Vector3(0.13, 0.13, 0.38), Vector3(0, 0.5, -0.56), dark, _tail).rotation.x = 1.2
	_head = Emoji3D.new().setup(face, 0.95)
	_head.glow = 0.05
	_head.position = Vector3(0, 1.48, 0.95)
	_body.add_child(_head)
	# The saddle, once it is yours
	_bard = Node3D.new()
	_body.add_child(_bard)


## Saddle and barding as worn now.
func _refresh() -> void:
	for c in _bard.get_children():
		c.queue_free()
	if not wild:
		var leather := _mat(Color(0.32, 0.2, 0.12))
		_box(Vector3(0.66, 0.08, 0.5), Vector3(0, 1.25, -0.05), leather, _bard)
		_box(Vector3(0.05, 0.32, 0.05), Vector3(0.34, 1.05, -0.05), leather, _bard)
		_box(Vector3(0.05, 0.32, 0.05), Vector3(-0.34, 1.05, -0.05), leather, _bard)
		match barding:
			"hide_barding":
				_box(Vector3(0.7, 0.4, 0.9), Vector3(0, 1.0, 0.05), _mat(Color(0.45, 0.36, 0.26)), _bard)
			"bone_barding":
				var bone := _mat(Color(0.86, 0.82, 0.72))
				for i in 4:
					_box(Vector3(0.7, 0.36, 0.12), Vector3(0, 1.0, 0.45 - i * 0.26), bone, _bard)
			"iron_barding":
				var iron := _mat(Color(0.42, 0.4, 0.38))
				iron.metallic = 0.6
				_box(Vector3(0.72, 0.5, 1.2), Vector3(0, 0.98, 0.05), iron, _bard)
				_box(Vector3(0.6, 0.2, 0.3), Vector3(0, 1.62, 0.95), iron, _bard)
	_label.text = cat_name if not wild else ("A stray cat" + (" (fed %d of 3)" % fed if fed > 0 else ""))
	_label.modulate = Color(0.95, 0.85, 0.55) if not wild else Color(0.85, 0.82, 0.75)
	_label.visible = not ridden
	if puppet:
		set_meta("prompt", "")
		return
	set_meta("prompt", "" if ridden else ("Ride %s" % cat_name if not wild else "Feed the stray cat"))
	set_meta("hold", 0.0)
	set_meta("on_interact", func(): w.cat_used(self))
	set_meta("hold_prompt", "")
	if not wild and not ridden:
		set_meta("on_hold", func(): w.cat_menu(self))
		set_meta("hold_prompt", "Name and gear")
	elif has_meta("on_hold"):
		remove_meta("on_hold")


## The pace it carries its rider at, this moment; a sprint spends its breath.
func pace(sprint: bool, delta: float) -> float:
	var base: float = w.player.walk_speed
	if sprint and not winded and breath > 0.0:
		_sprint_t = 0.6
		breath = maxf(0.0, breath - delta * (3.5 if w.skills.has_boon("cat_kin") else 7.0))
		if breath <= 0.0:
			winded = true
		return base * SPRINT
	return base * WALK


func _process(delta: float) -> void:
	_t += delta
	_shy = maxf(0.0, _shy - delta)
	if _rest > 0.0:
		_rest = maxf(0.0, _rest - delta)
		if not puppet and not wild and _label:
			_label.text = "%s (hurt: rests %ds, or feed it meat)" % [cat_name, ceili(_rest)]
			if _rest <= 0.0:
				_refresh()
	if puppet:
		pass
	elif _sprint_t > 0.0:
		_sprint_t = maxf(0.0, _sprint_t - delta)   # a sprint just now: no breath comes back yet
	else:
		breath = minf(BREATH_MAX, breath + delta * 14.0)
		if winded and breath >= 25.0:
			winded = false
	if puppet:
		_speed = lerpf(_speed, (global_position - _last).length() / maxf(delta, 0.001), minf(1.0, delta * 6.0))
		_last = global_position
	elif ridden:
		var p: Player = w.player
		global_position = p.global_position
		rotation.y = p.yaw + PI
		_speed = p.cur_speed
	else:
		_walk(delta)
	# The gait: legs swing faster and further the quicker it goes; the tail sways at rest
	# A long, loping stride: the paws turn over about once and a half a second at full run
	var k := clampf(_speed / 4.0, 0.0, 1.1)
	_ph += delta * (2.5 + _speed * 0.5)
	var ph := _ph
	for i in _legs.size():
		var leg: Node3D = _legs[i]
		leg.rotation.x = sin(ph + (PI if i in [1, 2] else 0.0)) * 0.55 * k
	_body.position.y = absf(sin(ph)) * 0.05 * k
	_tail.rotation.y = sin(_t * (1.5 + k * 3.0)) * 0.35
	_tail.rotation.x = -0.15 * k


## On its own: a stray wanders and shies away; your cat waits, or trots to you when called.
func _walk(delta: float) -> void:
	var p: Player = w.player
	var to_p := p.global_position - global_position
	to_p.y = 0.0
	var want := Vector3.ZERO
	if wild:
		# Shy of running feet; it keeps its distance unless you come softly or have fed it
		if to_p.length() < 9.0 and p.cur_speed > p.walk_speed * 1.1 and fed == 0:
			_shy = 3.0
		if _shy > 0.0:
			want = -to_p.normalized() * 5.0
		elif _going.distance_to(global_position) < 1.0 or randf() < delta * 0.05:
			_going = global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10))
		else:
			want = (_going - global_position) * Vector3(1, 0, 1)
			want = want.normalized() * 1.2
	elif _call:
		if to_p.length() < 4.0:
			_call = false
		else:
			want = to_p.normalized() * (7.5 if to_p.length() > 12.0 else 3.5)
	_speed = lerpf(_speed, want.length(), minf(1.0, delta * 4.0))
	if want.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(want.x, want.z), minf(1.0, delta * 5.0))
		var step := want.normalized() * _speed * delta
		var at := global_position + step
		global_position = w.gpos(Vector2(at.x, at.z))
	elif to_p.length() < 6.0 and not wild:
		# It turns its head toward you when you are near
		_head.face_target = p
	else:
		_head.face_target = null


## Whistled for: far off, it comes running from just out of sight; near, it trots to you.
func call_to(p: Node3D) -> void:
	if wild or _rest > 0.0:
		return
	var d := global_position.distance_to(p.global_position)
	if d > 90.0:
		var back := p.global_transform.basis.z
		back.y = 0.0
		var at: Vector3 = p.global_position + back.normalized() * 30.0
		global_position = w.gpos(Vector2(at.x, at.z))
	_call = true


## Harm that reaches it while ridden: its barding turns part. Hurt out, it throws you and runs off a while.
func take(amount: float) -> bool:
	hp -= amount * (1.0 - float(BARDING.get(barding, {}).get("guard", 0.0)))
	if hp <= 0.0:
		hp = HP_MAX * 0.5
		_rest = REST_HURT
		return true
	return false


func can_ride() -> bool:
	return not wild and _rest <= 0.0


func to_data() -> Dictionary:
	return {"face": face, "name": cat_name, "barding": barding, "hp": hp, "pos": [global_position.x, global_position.z]}
