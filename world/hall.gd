class_name WHall
extends RefCounted
## The Tenth Hall: under the ninth beacon, across a lake that has never had light on it.
## The Lake Stair goes down from beside the ninth beacon. Lena rows the survivor over the dark
## water to the hall where the five High Clerics sat down to write the tenth page, and never stood up.
## At the head of their table the page waits, with a pen. What is done with it ends the story.

const DEPTH := -300.0    ## the floor of the hall, far below the waste
const VOICES := [
	"Maud's voice, from the dark: \"Come home, child. You have done enough.\"",
	"Tobin's voice: \"Nobody is watching. You can put it down.\"",
	"Wren's voice: \"Let go. I did. It was easy.\"",
	"Ione's voice: \"The dead are so tired. So are you.\"",
	"Lena's voice, though Lena is behind you: \"Aron is here. Stay with us.\"",
	"Your own voice: \"You will get tired too.\"",
]

var w
var mid := Vector3.ZERO        ## the middle of the hall, where it answers
var page_pos := Vector3.ZERO   ## the page, at the head of the table
var stair_top := Vector3.ZERO  ## the Lake Stair, up in the waste
var shore_a := Vector3.ZERO    ## the foot of the stair
var shore_b := Vector3.ZERO    ## where Lena sets you down
var _o := Vector3.ZERO
var _dir := 0.0
var _voice_t := 20.0
var _spawn_t := 3.0
var _rock: StandardMaterial3D
var _void: StandardMaterial3D
var _water: StandardMaterial3D
var _stone: StandardMaterial3D   ## the hall's own stone: dark, never lit by the sun


func _init(world) -> void:
	w = world


## Where a spot in the hall's own frame lies in the world.
func at(x: float, y: float, z: float) -> Vector3:
	return _o + Vector3(x, y, z).rotated(Vector3.UP, _dir)


func inside(p: Vector3) -> bool:
	return p.y < DEPTH + 60.0


func build() -> void:
	var b: Vector2 = WPlaces.bpos(8)
	var g: Vector2 = WPlaces.spos("gallowmere")
	var to := (g - b).normalized()
	_o = Vector3(b.x, DEPTH, b.y)
	# The hall runs from the stair (nearest Gallowmere) out under the beacon
	_dir = atan2(-to.x, -to.y)
	_rock = StandardMaterial3D.new()
	_rock.albedo_color = Color(0.09, 0.085, 0.08)
	_rock.roughness = 1.0
	_void = StandardMaterial3D.new()
	_void.albedo_color = Color(0, 0, 0)
	_void.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.2, 0.19, 0.18)
	_stone.roughness = 1.0
	_water = StandardMaterial3D.new()
	_water.albedo_color = Color(0.015, 0.02, 0.03)
	_water.metallic = 0.6
	_water.roughness = 0.08
	_stair_head(b + to * 24.0)
	_cavern()
	_table()
	shore_a = at(0, 0.2, -44)
	shore_b = at(0, 0.2, 8)
	mid = at(0, 1.0, 26)
	page_pos = at(0, 0.0, 44)


## The Lake Stair: a low stone house over a stair that goes down into the dry lake's bed.
func _stair_head(q: Vector2) -> void:
	var n := Node3D.new()
	n.position = w.gpos(q)
	n.rotation.y = _dir + PI
	w.add_child(n)
	WDress.kp(n, "grave", "crypt", Vector3(0, -0.3, 0), 0.0, 4.2, true, Vector3.ZERO, 400.0)
	WDress.kp(n, "grave", "lantern-candle", Vector3(-3.2, 0.0, 3.4), 0.0, 2.2)
	WDress.kp(n, "grave", "lantern-candle", Vector3(3.2, 0.0, 3.4), 0.0, 2.2)
	WDress.kp(n, "pirate", "tool-paddle", Vector3(2.4, 0.4, 3.0), 0.4, 0.9, false, Vector3(0, 0, 1.2))
	stair_top = n.position + Vector3(0, 0.2, 0) + Vector3(0, 0, 5.0).rotated(Vector3.UP, n.rotation.y)
	var lbl: Label3D = w.label3d("The Lake Stair", stair_top + Vector3(0, 3.2, 0), 0.5, Color(0.85, 0.82, 0.75), 0.0, true)
	lbl.visibility_range_end = 40.0
	var a: Area3D = w.interact_area(n.position + Vector3(0, 1.4, 0) + Vector3(0, 0, 3.0).rotated(Vector3.UP, n.rotation.y), 2.2, "Go down the Lake Stair", func(): go_down(), 0.0, false)
	a.set_meta("prompt", "Go down the Lake Stair")


func _slab(c: Vector3, size: Vector3, m: Material, collide := true) -> MeshInstance3D:
	var mi: MeshInstance3D = w.box(at(c.x, c.y, c.z), size, m, collide)
	mi.rotation.y = _dir
	return mi


## The dark under the waste: two shores, black water between, and a roof of rock.
func _cavern() -> void:
	_slab(Vector3(0, -0.5, -45), Vector3(30, 1, 22), _rock)        # the stair's shore
	_slab(Vector3(0, -3.5, -15), Vector3(30, 1, 40), _rock)        # the lake bed
	_slab(Vector3(0, -0.5, 30), Vector3(30, 1, 50), _rock)         # the hall's floor
	_slab(Vector3(0, -0.35, -15), Vector3(30, 0.1, 40), _water, false)
	for x in [-15.5, 15.5]:
		_slab(Vector3(x, 7, 0), Vector3(1, 16, 112), _rock)
	_slab(Vector3(0, 7, -56.5), Vector3(32, 16, 1), _rock)
	_slab(Vector3(0, 7, 56.5), Vector3(32, 16, 1), _rock)
	_slab(Vector3(0, 15.5, 0), Vector3(32, 1, 114), _rock)
	# No one wades the black water: it is crossed by boat or not at all
	for z in [-34.2, 4.8]:
		var edge := _slab(Vector3(0, 1.5, z), Vector3(30, 4, 0.4), _void, true)
		edge.transparency = 1.0   # felt, not seen
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var holder := Node3D.new()
	holder.position = _o
	holder.rotation.y = _dir
	w.add_child(holder)
	for wall in [-1, 1]:
		for k in 9:
			WIsleLife.put(holder, "castle", "rocks-large", Vector3(wall * 13.2, -0.5, -50 + k * 12.5), k * 1.7, 3.4 + (k % 3) * 0.6, false, Vector3.ZERO, _stone, 120.0)
	# The stair down which one comes, against the near wall
	for k in 4:
		WDress.kp(holder, "castle", "stairs-stone", Vector3(0, k * 1.5 - 1.2, -54.0 + k * 0.1), PI, 2.4, false)
	var up: Area3D = w.interact_area(at(0, 1.4, -51.5), 2.4, "Climb the Lake Stair", func(): go_up(), 0.0, false)
	up.set_meta("prompt", "Climb the Lake Stair")
	# Lena's boat at either shore, her lantern lit
	for side in [[-32.8, 0.0, "Cross the dark water with Lena", true], [6.5, PI, "Cross back with Lena", false]]:
		var bz: float = side[0]
		WDress.kp(holder, "pirate", "boat-row-small", Vector3(3.0, -0.55, bz), side[1] + PI * 0.5, 1.2, false)
		var lena := Figure.new().setup(Figure.townsman("ash_lena".hash(), "gallowmere"))
		lena.arms_forward = false
		holder.add_child(lena)
		lena.position = Vector3(3.0, -0.25, bz)
		lena.rotation.y = side[1]
		WDress.kp(holder, "grave", "lantern-glass", Vector3(4.2, 0.1, bz), 0.0, 1.4)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.55)
		l.light_energy = 1.4
		l.omni_range = 9.0
		l.position = Vector3(4.2, 1.2, bz)
		holder.add_child(l)
		var over: bool = side[3]
		var a: Area3D = w.interact_area(at(3.0, 1.0, bz - (1.5 if over else -1.5)), 2.6, side[2], func(): cross(over), 0.0, false)
		a.set_meta("prompt", side[2])
	var foot := OmniLight3D.new()
	foot.light_color = Color(0.9, 0.75, 0.55)
	foot.light_energy = 0.8
	foot.omni_range = 12.0
	foot.position = Vector3(0, 3.0, -50)
	holder.add_child(foot)


## Five chairs, a long table, candles burned to nothing; the page at its head, and the Mouth beyond.
func _table() -> void:
	var holder := Node3D.new()
	holder.position = _o
	holder.rotation.y = _dir
	w.add_child(holder)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.16, 0.11, 0.08)
	wood.roughness = 0.9
	var top := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 0.14, 11.0)
	top.mesh = bm
	top.material_override = wood
	top.position = Vector3(0, 0.95, 34)
	holder.add_child(top)
	for lz in [29.0, 39.0]:
		for lx in [-1.0, 1.0]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.16, 0.9, 0.16)
			leg.mesh = lm
			leg.material_override = wood
			leg.position = Vector3(lx, 0.45, lz)
			holder.add_child(leg)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 1.0, 11.0)
	cs.shape = bs
	cs.position = Vector3(0, 0.5, 34)
	body.add_child(cs)
	holder.add_child(body)
	# The five, slumped over what they wrote
	var seats := [Vector3(-1.9, 0, 30.5), Vector3(-1.9, 0, 34.0), Vector3(-1.9, 0, 37.5), Vector3(1.9, 0, 32.0), Vector3(1.9, 0, 36.0)]
	for i in seats.size():
		var sp: Vector3 = seats[i]
		var face := PI * 0.5 if sp.x < 0 else -PI * 0.5
		WDress.kp(holder, "grave", "bench-damaged", sp + Vector3(sign(sp.x) * 0.3, 0, 0), face + PI * 0.5, 1.6, true)
		WDress.kp(holder, "grave", "character-skeleton", sp + Vector3(0, -0.35, 0), face, 2.0, false, Vector3(0.45, 0, 0))
		WDress.kp(holder, "furn", "books", Vector3(sign(sp.x) * 0.6, 1.03, sp.z), randf() * TAU, 0.5)
	for k in 3:
		WDress.kp(holder, "grave", "candle-multiple", Vector3(0, 1.02, 30.0 + k * 4.0), k * 1.3, 1.6)
	# The pillars of a hall cut by no hand
	for k in 6:
		for x in [-8.0, 8.0]:
			WIsleLife.put(holder, "grave", "pillar-large", Vector3(x, 0, 10.0 + k * 7.5), 0.0, 3.2, true, Vector3.ZERO, _stone, 120.0)
	# The page, and its pen
	WDress.kp(holder, "grave", "altar-stone", Vector3(0, 0, 44), 0.0, 2.6, true)
	var page := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.7, 0.02, 0.95)
	page.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.96, 0.94, 0.88)
	pmat.emission_enabled = true
	pmat.emission = Color(0.9, 0.9, 0.85)
	pmat.emission_energy_multiplier = 0.35
	page.material_override = pmat
	page.position = Vector3(0, 1.28, 44)
	holder.add_child(page)
	var pen := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.004
	cm.height = 0.4
	pen.mesh = cm
	pen.material_override = wood
	pen.position = Vector3(0.45, 1.3, 44)
	pen.rotation = Vector3(PI * 0.5, 0.3, 0)
	holder.add_child(pen)
	var pl := OmniLight3D.new()
	pl.light_color = Color(0.85, 0.88, 1.0)
	pl.light_energy = 1.1
	pl.omni_range = 7.0
	pl.position = Vector3(0, 2.6, 44)
	holder.add_child(pl)
	var a: Area3D = w.interact_area(at(0, 1.2, 42.6), 2.0, "Look at the page", func(): touch_page(), 0.0, false)
	a.set_meta("prompt", "Look at the page")
	# The Mouth: where Speeb's gaze does not fall. The light goes into it and does not come back.
	var mouth := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 6.0
	mm.bottom_radius = 6.0
	mm.height = 0.04
	mouth.mesh = mm
	mouth.material_override = _void
	mouth.position = Vector3(0, 0.02, 51.0)
	holder.add_child(mouth)
	for k in 8:
		var ang := k * TAU / 8.0
		WIsleLife.put(holder, "castle", "rocks-small", Vector3(cos(ang) * 6.6, -0.2, 51.0 + sin(ang) * 6.6), ang, 1.6, false, Vector3.ZERO, _stone, 120.0)


# ------------------------------------------------------------------ going there

func _ferry() -> Dictionary:
	return w.quests.quests.get("story_ferryway", {})


## Whether Lena has agreed to take the fellowship down.
func open() -> bool:
	var q := _ferry()
	return w.flags.has("done_ferryway") or (not q.is_empty() and q.state == "active" and int(q.stage) >= 1)


func go_down() -> void:
	if not open():
		w.hud.say("The door is barred from below. Lena at Gallowmere may know the way down.", 4.5)
		return
	w.sfx("whoosh", -10)
	w.player.place(shore_a + Vector3(0, 0.6, 0) + Vector3(0, 0, 4.0).rotated(Vector3.UP, _dir), _dir + PI)
	w.hud.say("The stair goes down a long way. At the bottom, black water, and a lantern.", 4.5)


func go_up() -> void:
	w.sfx("whoosh", -10)
	w.player.place(stair_top + Vector3(0, 0.6, 0), _dir)


func cross(over: bool) -> void:
	w.sfx("splash", -14)
	if over:
		w.player.place(shore_b + Vector3(0, 0.6, 0) + Vector3(0, 0, 3.0).rotated(Vector3.UP, _dir + PI), _dir + PI)
		w.hud.say("Lena rows without a word. The lantern does not reach the walls.", 4.0)
	else:
		w.player.place(shore_a + Vector3(0, 0.6, 0), _dir + PI)


func touch_page() -> void:
	if w.flags.has("ending"):
		w.hud.say("The page is as you left it.", 3.0)
		return
	var q := _ferry()
	if q.is_empty() or q.state != "active" or w.quests.step_of(q).get("t", "") != "page":
		w.hud.say("Something in the hall does not want you near the page. Not yet.", 3.5)
		return
	if not w.flags.has("page_7"):
		w.shared("_w_book", ["page_7", Net.me()])
	w.ui.open_page()


## How many of the Tenth Page's six fragments the fellowship has read.
func pages_read() -> int:
	var n := 0
	for k in 6:
		if w.flags.has("page_%d" % (k + 1)):
			n += 1
	return n


# ------------------------------------------------------------------ while one is down here

## Every machine: the dark speaks to those in the hall while it fights them.
func local_tick(delta: float) -> void:
	if w.player == null or not inside(w.player.global_position):
		return
	var q := _ferry()
	if q.is_empty() or q.state != "active" or w.quests.step_of(q).get("t", "") != "kill":
		return
	_voice_t -= delta
	if _voice_t <= 0.0:
		_voice_t = randf_range(14.0, 22.0)
		w.hud.say(VOICES[randi() % VOICES.size()], 4.5)
		w.sfx("horror_deep", -8, w.player.global_position + Vector3(randf_range(-10, 10), 0, randf_range(-10, 10)), 0.8)


## The host: while the step asks it, the hall sends forms at whoever stands in it.
func host_tick(delta: float) -> void:
	if not Net.authority():
		return
	var q := _ferry()
	if q.is_empty() or q.state != "active" or w.quests.step_of(q).get("t", "") != "kill":
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	_spawn_t = 4.0
	var down := false
	for t in w.targets():
		if inside(t.global_position) and t.global_position.distance_to(mid) < 45.0:
			down = true
	if not down:
		return
	var here := 0
	for e in w.enemies:
		if is_instance_valid(e) and e.is_alive() and inside(e.global_position):
			here += 1
	var left := int(w.quests.step_of(q).n) - int(q.get("have", 0))
	for k in mini(2, mini(4, left) - here):
		var kind: String = ["hollow", "vigil", "deacon", "saltbone", "hollow", "warden"][randi() % 6]
		var e = w.spawn_at(kind, at(randf_range(-9, 9), 1.6, randf_range(40, 50)))
		if e and e.has_method("seek"):
			e.seek(mid, 40.0)
