extends Level
## II. The Ruins of the Fallen Kings. Brelm carves warnings into three broken thrones. The tower of the proud will not bear him.

const THRONES := [Vector3(-20, 0, -22), Vector3(22, 0, -30), Vector3(2, 0, -58)]
const WARNINGS := ["PRIDE IS A CROWN\nOF DUST", "WHO SITS ABOVE\nSHALL BE LAID LOW", "THE THRONE DOES NOT\nREMEMBER THE KING"]
const TOWER := Vector3(-34, 0, -52)

var carved := 0
var tower_top := 15.0
var tower_parts: Array = []
var birds: AudioStreamPlayer


func build() -> void:
	numeral = "II"
	place = "The Ruins of the Fallen Kings"
	verse = "Second, he journeyed to the Ruins of the Fallen Kings, where Emospeeb wept among broken thrones. Brelm tasted the bitterness of pride undone, and carved warnings into the stone with his own bleeding fingers."
	setup_env(Color(0.36, 0.39, 0.44), Color(0.62, 0.63, 0.64), Color(0.2, 0.2, 0.2), Color(0.58, 0.6, 0.62), 0.014, 0.8)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	add_sun(Vector3(-35, 140, 0), Color(0.85, 0.87, 0.9), 0.9)

	var stone := mat(Color(0.56, 0.54, 0.5), 0.95, 0.4, 0.15)
	var marble := mat(Color(0.75, 0.73, 0.69), 0.7, 0.3, 0.12)
	var gold := mat(Color(0.75, 0.6, 0.28), 0.35, 0.15, 0.5, 0.9)
	box(Vector3(0, -0.5, -30), Vector3(220, 1, 220), mat(Color(0.36, 0.35, 0.32), 1.0, 0.45, 0.06))
	# Fallen colonnades
	for i in 46:
		var p := Vector3(_rng.randf_range(-60, 60), 0, _rng.randf_range(-100, 30))
		if p.distance_to(Vector3(0, 0, 0)) < 6:
			continue
		var h := _rng.randf_range(1.0, 7.0)
		if _rng.randf() < 0.3:
			var c := cyl(p + Vector3(0, 0.6, 0), 0.6, _rng.randf_range(4, 8), marble)
			c.rotation = Vector3(PI / 2, _rng.randf() * TAU, 0)
		else:
			cyl(p + Vector3(0, h * 0.5, 0), 0.6, h, marble)
	for i in 18:
		var p := Vector3(_rng.randf_range(-55, 55), 0, _rng.randf_range(-95, 25))
		box(p + Vector3(0, 1.5, 0), Vector3(_rng.randf_range(4, 10), _rng.randf_range(1.5, 4.5), 1.0), stone, true, Vector3(0, _rng.randf() * 180, _rng.randf_range(-6, 6)))
	# Broken statues of kings, toppled
	for i in 6:
		var p := Vector3(_rng.randf_range(-40, 40), 0, _rng.randf_range(-80, -5))
		var f := figure(p, _rng.randf() * TAU, Color(0.6, 0.58, 0.55))
		f.scale = Vector3.ONE * 2.2
		if i % 2 == 0:
			f.rotation.x = PI / 2 * 0.95
			f.position.y = 0.9
	# The three thrones
	for i in THRONES.size():
		_throne(THRONES[i], i, stone, gold)
	# The central dais where the Sorrow of Pride will walk
	cyl(Vector3(0, 0.3, -38), 6.0, 0.6, marble)
	cyl(Vector3(0, 0.75, -38), 4.5, 0.3, marble)
	# The tower of the proud, with its winding stair
	cyl(TOWER + Vector3(0, 8, 0), 3.2, 16, stone, true, 2.8)
	for k in 44:
		var a := k * 0.42
		var y := 0.35 + k * 0.35
		var p := TOWER + Vector3(cos(a) * 4.2, y, sin(a) * 4.2)
		var b := box(p, Vector3(2.2, 0.3, 1.3), stone)
		b.rotation.y = -a
		tower_parts.append(b)
	var top := cyl(TOWER + Vector3(0, 16.2, 0), 4.0, 0.4, marble)
	tower_parts.append(top)
	box(TOWER + Vector3(0, 18, 0), Vector3(0.5, 3, 0.5), gold)
	label3d("Here the kings of Auraleth\nlooked down upon their people.", TOWER + Vector3(0, 2.5, 4.3), 0.3, Color(0.25, 0.24, 0.22), 0.0)

	lesser("crownspeeb", TOWER + Vector3(cos(30 * 0.42) * 4.2, 11.9, sin(30 * 0.42) * 4.2))
	lesser("laurelspeeb", Vector3(-38, 1.2, -12))
	lesser("fossilspeeb", Vector3(30, 0.9, -70))
	lesser("deadspeeb", Vector3(12, 1.0, 6))
	birds = ambient("birds", -12)
	ambient("wind", -18)
	spawn_pos = Vector3(0, 0.1, 10)
	spawn_yaw = 0.0
	kill_y = -20


func _throne(p: Vector3, i: int, stone: Material, gold: Material) -> void:
	var yaw := yaw_to(p, Vector3(0, 0, -38))
	var n := Node3D.new()
	n.position = p
	n.rotation.y = yaw
	add_child(n)
	var parts := [[Vector3(0, 0.4, 0), Vector3(3.6, 0.8, 3.0)], [Vector3(0, 1.3, 0.2), Vector3(1.8, 1.0, 1.4)], [Vector3(0, 3.0, 1.1), Vector3(1.9, 4.2, 0.5)],
		[Vector3(-1.0, 1.9, 0.2), Vector3(0.3, 0.6, 1.4)], [Vector3(1.0, 1.9, 0.2), Vector3(0.3, 0.6, 1.4)]]
	var back: MeshInstance3D
	for pt in parts:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pt[1]
		mi.mesh = bm
		mi.material_override = stone
		mi.position = pt[0]
		n.add_child(mi)
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = pt[1]
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
		back = mi
	# The back is broken: a sheared top
	var shard := MeshInstance3D.new()
	var bm2 := BoxMesh.new()
	bm2.size = Vector3(1.0, 1.4, 0.5)
	shard.mesh = bm2
	shard.material_override = stone
	shard.position = Vector3(1.6, 0.25, 2.2)
	shard.rotation = Vector3(0.3, 0.6, 1.2)
	n.add_child(shard)
	# A cracked crown lies at its foot
	var crown := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.28
	tm.outer_radius = 0.4
	crown.mesh = tm
	crown.material_override = gold
	crown.position = Vector3(-0.8, 0.9, -1.0)
	crown.rotation = Vector3(0.4, 0, 0.2)
	n.add_child(crown)
	var target: StaticBody3D = n.get_child(2).get_child(0)
	target.set_meta("index", i)
	make_interactable(target, "Carve a warning into the throne", func(): _carve(target, n), 2.5)


func _carve(target: StaticBody3D, n: Node3D) -> void:
	var i: int = target.get_meta("index")
	target.set_meta("prompt", "")
	sfx("carve", -2)
	var l := Label3D.new()
	l.text = WARNINGS[i]
	l.font = load("res://assets/fonts/Marcellus-Regular.ttf")
	l.font_size = 64
	l.pixel_size = 0.004
	l.modulate = Color(0.45, 0.08, 0.06)
	l.position = Vector3(0, 3.2, 0.84)
	l.rotation.y = PI
	l.shaded = true
	l.double_sided = false
	n.add_child(l)
	l.position.z = 0.84
	carved += 1
	hud.set_objective("Carve warnings into the broken thrones   %d / 3" % carved)
	if carved == 3:
		birds_fall_silent()


func birds_fall_silent() -> void:
	completed = true
	create_tween().tween_property(birds, "volume_db", -60.0, 6.0)
	hud.say("His passage was a silence so profound that even birds forgot their songs.", 7.0)
	await get_tree().create_timer(7.0, false).timeout
	completed = false
	await survive("emospeeb", Vector3(0, 3.6, -38), "rain")
	reveal("emospeeb", Vector3(0, 3.6, -38), 3.2)


func intro() -> void:
	hud.set_objective("Carve warnings into the broken thrones   0 / 3")
	await super.intro()


func trial_tick(_delta: float) -> void:
	var p := player.global_position
	if p.y > tower_top and Vector2(p.x - TOWER.x, p.z - TOWER.z).length() < 6.0:
		_tower_falls()


func _tower_falls() -> void:
	failing = true
	sfx("crumble", 0)
	player.input_locked = true
	for b in tower_parts:
		var tw := create_tween()
		tw.tween_property(b, "position:y", b.position.y - 3.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var shake := create_tween()
	for k in 10:
		shake.tween_property(player.cam, "h_offset", randf_range(-0.15, 0.15), 0.08)
	await get_tree().create_timer(1.0, false).timeout
	await hud.fade_to(1.0, 0.8)
	hud.raise_text(true)
	hud.say("Those who placed themselves above others found themselves laid low, as mirrors shattered and crowns crumbled into dust.", 5.0)
	await get_tree().create_timer(6.0, false).timeout
	hud.raise_text(false)
	player.cam.h_offset = 0
	for b in tower_parts:
		b.position.y += 3.0
	player.place(spawn_pos, spawn_yaw)
	player.input_locked = false
	failing = false
	hud.fade_to(0.0, 1.5)
