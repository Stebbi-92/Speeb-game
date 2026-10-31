extends Level
## I. The Cliffs of Echoing Cries. The cravings drift toward Brelm; he must take none of them.

const PATH := [
	Vector3(0, 0, 4), Vector3(0, 0, -18), Vector3(8, 0.6, -32), Vector3(8, 1.2, -48), Vector3(-2, 1.8, -62),
	Vector3(-2, 2.4, -80), Vector3(7, 3.0, -93), Vector3(7, 3.6, -108), Vector3(0, 4.2, -120),
]
const SHRINE := Vector3(0, 4.2, -128)

var orbs: Array = []
var fasting := false
var stone_area: Area3D


func build() -> void:
	spiders = false
	numeral = "I"
	max_alive = 3
	spawn_interval = 6.0
	place = "The Cliffs of Echoing Cries"
	verse = "First, he sought the Face of Consuming Desire. Upon the Cliffs of Echoing Cries, Brelm fasted for nine days, surrounded by whispers of longing and temptation."
	setup_env(Color(0.12, 0.08, 0.14), Color(0.55, 0.24, 0.2), Color(0.05, 0.03, 0.04), Color(0.35, 0.16, 0.16), 0.02, 0.5)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.9, 0.6, 0.55)
	add_sun(Vector3(-8, -60, 0), Color(1.0, 0.5, 0.35), 1.4)
	kill_y = -14.0

	var rock := mat(Color(0.32, 0.26, 0.25), 0.95, 0.45, 0.12)
	var dark_rock := mat(Color(0.18, 0.14, 0.14), 0.95, 0.4, 0.06)
	for i in PATH.size() - 1:
		_ledge(PATH[i], PATH[i + 1], rock)
	for p in PATH:
		cyl(p + Vector3(0, -0.75, 0), 2.1, 1.5, rock)
	cyl(SHRINE + Vector3(0, -1.0, 0), 7.0, 2.0, rock)
	# The cliff wall rising on the west, the abyss falling to the east
	for i in 14:
		var z := 10.0 - i * 11.0
		var h := _rng.randf_range(30, 55)
		box(Vector3(-16 - _rng.randf_range(0, 6), h * 0.5 - 20, z), Vector3(10, h, 12), dark_rock, true, Vector3(0, _rng.randf_range(-8, 8), 0))
	for i in 10:
		var z := -i * 15.0
		box(Vector3(_rng.randf_range(30, 70), _rng.randf_range(-30, -10), z - 20), Vector3(_rng.randf_range(6, 14), _rng.randf_range(20, 40), _rng.randf_range(6, 14)), dark_rock, false)
	box(Vector3(0, -60, -60), Vector3(400, 2, 400), mat(Color(0.05, 0.03, 0.03), 1.0, 0.2), false)

	# The fasting stone, ringed by nine small cairns
	var stone := cyl(SHRINE + Vector3(0, 0.25, 0), 1.0, 0.5, mat(Color(0.5, 0.45, 0.42), 0.8, 0.2, 0.4))
	for k in 9:
		var a := k * TAU / 9.0
		cyl(SHRINE + Vector3(cos(a) * 4.0, 0.4, sin(a) * 4.0), 0.25, 0.8, rock, true, 0.12, 6)
	stone_area = interact_area(SHRINE + Vector3(0, 0.6, 0), 1.2, "Sit upon the stone and fast", _fast)
	label3d("Restraint is spared.\nIndulgence is devoured.", SHRINE + Vector3(0, 1.6, 5.5), 0.35, Color(0.85, 0.6, 0.55), PI, true)

	# The cravings
	var spots := [[-0.5, 1.2], [0.3, 1.0], [0.6, -1.2], [0.2, 1.5], [0.5, -1.0], [0.8, 1.3], [0.4, -1.4], [0.7, 1.1],
		[0.3, -1.0], [0.6, 1.4], [0.5, -1.3], [0.2, 1.0], [0.85, -1.2], [0.45, 1.1]]
	var seg := 0
	for s in spots:
		var a: Vector3 = PATH[seg % (PATH.size() - 1)]
		var b: Vector3 = PATH[seg % (PATH.size() - 1) + 1]
		var t: float = absf(s[0])
		var side := (b - a).normalized().cross(Vector3.UP)
		_make_orb(a.lerp(b, t) + side * float(s[1]) * 2.6 + Vector3(0, 1.3, 0))
		seg += 1 if seg < 7 else -6
	lesser("emberspeeb", PATH[3] + Vector3(-2.6, 1.2, 0))
	lesser("lovestruckspeeb", PATH[6] + Vector3(0, 1.3, 2.2))
	lesser("wrathspeeb", SHRINE + Vector3(5.5, 1.3, -2))
	ambient("wind", -10)
	ambient("whispers", -20)
	spawn_pos = PATH[0] + Vector3(0, 0.1, 0)
	spawn_yaw = 0.0


func _ledge(a: Vector3, b: Vector3, m: Material) -> void:
	var d := b - a
	var len := Vector2(d.x, d.z).length()
	var mid := (a + b) * 0.5
	var mi := box(mid + Vector3(0, -0.75, 0), Vector3(3.2, 1.5, len), m)
	mi.look_at_from_position(mid + Vector3(0, -0.75, 0), b + Vector3(0, -0.75, 0), Vector3.UP)


func _make_orb(pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	core.mesh = sm
	core.material_override = glow_mat(Color(1.0, 0.55, 0.45), 4.0)
	n.add_child(core)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.4)
	l.light_energy = 1.4
	l.omni_range = 5
	n.add_child(l)
	var w := AudioStreamPlayer3D.new()
	var s = load("res://assets/audio/whispers.ogg")
	s.loop = true
	w.stream = s
	w.unit_size = 2.5
	w.volume_db = -4
	w.autoplay = true
	n.add_child(w)
	var a := Area3D.new()
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.5
	cs.shape = sh
	a.add_child(cs)
	n.add_child(a)
	make_interactable(a, "Take what you crave", func(): fail("He reached, and the hunger reached back. Those who succumb find their lives devoured by the very hunger they embrace."))
	orbs.append({"node": n, "home": pos, "phase": _rng.randf() * TAU})


func trial_tick(delta: float) -> void:
	var p := player.global_position + Vector3(0, 1.2, 0)
	var t := Time.get_ticks_msec() / 1000.0
	for o in orbs:
		var n: Node3D = o.node
		var home: Vector3 = o.home
		var to := p - n.position
		var want := home + Vector3(sin(t * 0.7 + o.phase) * 0.6, sin(t * 1.1 + o.phase) * 0.3, cos(t * 0.5 + o.phase) * 0.6)
		if to.length() < 7.0 and not fasting:
			want = n.position + to.normalized() * 1.25 * delta * 60.0
			if want.distance_to(home) > 5.0:
				want = home + (want - home).normalized() * 5.0
		n.position = n.position.move_toward(want, 1.25 * delta)
		if to.length() < 0.7 and not fasting:
			fail("A craving touched him, and he did not turn away. Those who gazed upon her saw their deepest cravings laid bare.")
			return
	if player.global_position.z < PATH[4].z and spawn_pos.z > PATH[4].z:
		checkpoint(PATH[4] + Vector3(0, 0.1, 0), yaw_to(PATH[4], PATH[5]))
		hud.notify("The whispers grow louder.")


func reset_trial() -> void:
	for o in orbs:
		o.node.position = o.home


func intro() -> void:
	hud.set_objective("Walk the cliff path to the fasting stone. Take nothing that is offered.")
	await super.intro()


func _fast() -> void:
	if fasting:
		return
	fasting = true
	combat_frozen = true
	clear_enemies()
	stone_area.set_meta("prompt", "")
	player.input_locked = true
	player.place(SHRINE + Vector3(0, 0.6, 0), 0.0)
	var tw := create_tween()
	tw.tween_property(player.head, "position:y", 1.05, 1.5)
	hud.set_objective("")
	for o in orbs:
		create_tween().tween_property(o.node, "position", SHRINE + Vector3(cos(o.phase) * 6.0, 1.6 + sin(o.phase), sin(o.phase) * 6.0), 6.0)
	var days := ["The first day.", "The second day.", "The third day.", "The fourth day.", "The fifth day.",
		"The sixth day.", "The seventh day.", "The eighth day.", "On the ninth night..."]
	for i in days.size():
		hud.set_fx("dark", 0.15 + i * 0.06)
		hud.say(days[i], 1.6)
		await get_tree().create_timer(2.2, false).timeout
	hud.set_fx("dark", 0.0)
	for o in orbs:
		create_tween().tween_property(o.node, "scale", Vector3.ONE * 0.01, 3.0)
	hud.say("And Brelm's heart nearly broke from the onslaught of his own secret hungers.", 5.0)
	await get_tree().create_timer(6.0, false).timeout
	player.input_locked = false
	create_tween().tween_property(player.head, "position:y", 1.6, 1.0)
	await survive("speebbang", SHRINE + Vector3(0, 3.2, -4.5), "volley")
	reveal("speebbang", SHRINE + Vector3(0, 3.2, -4.5), 3.2)
