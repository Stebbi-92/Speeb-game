extends Level
## VI. The Mirror Caves. Three bright tunnels offer power, peace and beauty, and each is a snare. Only the bare dark way is true.

const VISIONS := [
	{"angle": 0.0, "name": "power", "color": Color(1.0, 0.75, 0.3),
		"whisper": "Take the crown, Brelm. Rule them all, and you will never again be weighed."},
	{"angle": PI * 0.5, "name": "peace", "color": Color(0.45, 0.8, 0.65),
		"whisper": "Lay down your seeking, Brelm. Rest here, where nothing will ever be asked of you."},
	{"angle": PI, "name": "beauty", "color": Color(1.0, 0.5, 0.6),
		"whisper": "Look upon yourself, Brelm. Have you ever been so fair?"},
]
const TRUE_ANGLE := PI * 1.5
const HUB_R := 10.0
const TUNNEL_LEN := 28.0

var snared := 0
var shroud: MeshInstance3D
var _shroud_warned := false
var _velm_stage := 0


var _asked := false

func build() -> void:
	numeral = "VI"
	max_alive = 4
	place = "The Mirror Caves"
	verse = "Sixth, Brelm faced the Mirror Caves, where Speebsnek coiled around him in visions of power and peace, each one a snare for his spirit."
	setup_env(Color(0, 0, 0), Color(0.01, 0.01, 0.015), Color(0, 0, 0), Color(0.02, 0.02, 0.03), 0.03, 0.05)
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.09, 0.09, 0.11)
	env.ambient_light_energy = 1.0
	env.ssr_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	var rock := mat(Color(0.2, 0.19, 0.2), 0.95, 0.5, 0.15)
	var mirror := mat(Color(0.03, 0.03, 0.04), 0.03, 0.0, 1.0, 1.0)
	# The hub chamber
	cyl(Vector3(0, -0.5, 0), HUB_R + 1.0, 1.0, rock, true, -1.0, 32)
	cyl(Vector3(0, 7.5, 0), HUB_R + 1.0, 1.0, rock, true, -1.0, 32)
	var openings := [TRUE_ANGLE]
	for v in VISIONS:
		openings.append(v.angle)
	for k in 32:
		var a := k * TAU / 32.0
		var open := false
		for o in openings:
			if absf(wrapf(a - o, -PI, PI)) < 0.17:
				open = true
		if open:
			continue
		var p := Vector3(cos(a) * HUB_R, 3.5, sin(a) * HUB_R)
		var w := box(p, Vector3(0.6, 7, 2.1), mirror if k % 2 == 0 else rock)
		w.rotation.y = -a
	cyl(Vector3(0, 0.4, 0), 1.2, 0.8, rock)
	omni(Vector3(0, 5.5, 0), Color(0.6, 0.65, 0.8), 1.2, 14)
	label3d("Interpret as mirror,\nnot as lens.", Vector3(0, 1.4, 0), 0.32, Color(0.7, 0.68, 0.62), 0.0, true)
	# Tunnels
	for v in VISIONS:
		_tunnel(v.angle, TUNNEL_LEN, rock, v.color)
		_vision(v)
	_tunnel(TRUE_ANGLE, TUNNEL_LEN + 14.0, rock, Color(0, 0, 0), false)
	# The true way is shut by a darkness the eye cannot part; only the Lantern of Vigil opens it
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.0, 0.0, 0.0)
	sm.roughness = 1.0
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shroud = box(_dir(TRUE_ANGLE) * (HUB_R + 1.2) + Vector3(0, 2.75, 0), Vector3(4.8, 5.5, 0.5), sm, true, Vector3(0, rad_to_deg(-TRUE_ANGLE + PI * 0.5), 0))
	relic_pickup("lantern", Vector3(2.6, 0.5, 3.5))
	var inner := _dir(TRUE_ANGLE) * (HUB_R + TUNNEL_LEN + 22.0)
	cyl(inner + Vector3(0, -0.5, 0), 9.0, 1.0, rock, true, -1.0, 24)
	cyl(inner + Vector3(0, 8.5, 0), 9.0, 1.0, rock, true, -1.0, 24)
	for k in 24:
		var a := k * TAU / 24.0
		if absf(wrapf(a - (TRUE_ANGLE + PI), -PI, PI)) < 0.25:
			continue
		var w := box(inner + Vector3(cos(a) * 8.6, 4, sin(a) * 8.6), Vector3(0.8, 8, 2.4), rock)
		w.rotation.y = -a
	box(inner + Vector3(0, 0.02, 0), Vector3(7, 0.04, 7), mat(Color(0.02, 0.02, 0.03), 0.02, 0.0, 1.0, 1.0), false)
	trigger_area(inner, Vector3(8, 3, 8), _sanctum)
	trigger_area(_dir(TRUE_ANGLE) * (HUB_R + 6.0) + Vector3(0, 1, 0), Vector3(4, 3, 4), func():
		hud.say("No whisper called him here. No light. Only the plain dark, which promised nothing.", 6.0))

	lesser("goldspeeb", _dir(0.0) * (HUB_R + 12) + _side(0.0) * 1.6 + Vector3(0, 1.3, 0))
	lesser("jadespeeb", _dir(PI * 0.5) * (HUB_R + 10) + _side(PI * 0.5) * -1.6 + Vector3(0, 1.3, 0))
	lesser("richspeeb", _dir(PI) * (HUB_R + 14) + _side(PI) * 1.6 + Vector3(0, 1.3, 0))
	lesser("hypnospeeb", inner + Vector3(5, 1.4, 0))
	ambient("cave", -6)
	ambient("whispers", -26)
	spawn_pos = Vector3(0, 0.1, 6)
	spawn_yaw = 0.0
	kill_y = -20


func _dir(a: float) -> Vector3:
	return Vector3(cos(a), 0, sin(a))


func _side(a: float) -> Vector3:
	return Vector3(-sin(a), 0, cos(a))


func _tunnel(a: float, length: float, m: Material, light: Color, cap := true) -> void:
	var d := _dir(a)
	var s := _side(a)
	var start := d * (HUB_R - 0.5)
	var mid := start + d * length * 0.5
	var yaw := -a + PI * 0.5
	box(mid + Vector3(0, -0.5, 0), Vector3(4, 1, length), m, true, Vector3(0, rad_to_deg(yaw), 0))
	box(mid + Vector3(0, 6.0, 0), Vector3(4, 1, length), m, true, Vector3(0, rad_to_deg(yaw), 0))
	box(mid + s * 2.4 + Vector3(0, 2.75, 0), Vector3(0.8, 5.5, length), m, true, Vector3(0, rad_to_deg(yaw), 0))
	box(mid - s * 2.4 + Vector3(0, 2.75, 0), Vector3(0.8, 5.5, length), m, true, Vector3(0, rad_to_deg(yaw), 0))
	if cap:
		box(start + d * length + Vector3(0, 2.75, 0), Vector3(4.8, 5.5, 0.8), m, true, Vector3(0, rad_to_deg(yaw), 0))
	if light != Color(0, 0, 0):
		for k in 4:
			omni(start + d * (6 + k * 7) + Vector3(0, 4, 0), light, 0.5 + k * 0.35, 8)


func _vision(v: Dictionary) -> void:
	var a: float = v.angle
	var end := _dir(a) * (HUB_R + TUNNEL_LEN - 3.5)
	var c: Color = v.color
	match v.name:
		"power":
			box(end + Vector3(0, 0.6, 0), Vector3(1.6, 1.2, 1.6), mat(Color(0.3, 0.25, 0.2), 0.8, 0.2))
			var crown := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.42
			tm.outer_radius = 0.6
			crown.mesh = tm
			crown.material_override = glow_mat(c, 3.0)
			crown.position = end + Vector3(0, 2.4, 0)
			add_child(crown)
		"peace":
			for k in 7:
				sphere(end + Vector3(_rng.randf_range(-1.5, 1.5), 0.6, _rng.randf_range(-1.5, 1.5)), _rng.randf_range(0.5, 0.9), glow_mat(c * 0.6, 0.8))
		"beauty":
			box(end + Vector3(0, 2.2, 0), Vector3(2.0, 3.6, 0.1), glow_mat(c, 1.6), true, Vector3(0, rad_to_deg(-a + PI * 0.5), 0))
	omni(end + Vector3(0, 2.5, 0), c, 3.0, 9)
	trigger_area(_dir(a) * (HUB_R + 4.0) + Vector3(0, 1, 0), Vector3(4, 3, 4), func(): hud.say("\"%s\"" % v.whisper, 6.0), false, false)
	trigger_area(end + Vector3(0, 1, 0), Vector3(4, 3, 4), func(): _snare(v), false, false)


func _snare(v: Dictionary) -> void:
	if failing or completed:
		return
	snared += 1
	fail(["It was a snare. The whisper coiled tighter, and Brelm found himself again in the hall of mirrors.",
		"Again the vision. Again the coil. The mirror shows the soul, not the world.",
		"Few could resist the soft pull of the whisper. Fewer still could discern whether it led to revelation or ruin."][mini(snared - 1, 2)], "glitch")


func intro() -> void:
	lantern(1.0)
	hud.set_objective("Find the true way through the Mirror Caves. The dark way parts only for a light carried by hand.")
	await super.intro()


func trial_tick(_d: float) -> void:
	_velm_in_the_dark()
	if shroud == null:
		return
	var d := Vector2(player.global_position.x - shroud.global_position.x, player.global_position.z - shroud.global_position.z).length()
	if d > 7.0:
		return
	if player.relics and player.relics.lantern_lit:
		if not _asked:
			_asked = true
			shared("_part_shroud")
	elif not _shroud_warned:
		_shroud_warned = true
		hud.say("A darkness hangs in the fourth way, thicker than shadow. The eye cannot part it. Perhaps a light, carried by his own hand.", 7.0)


## The lantern shows the dark for a door, and it opens for the whole fellowship.
func _part_shroud() -> void:
	if shroud == null:
		return
	var s := shroud
	shroud = null
	s.get_child(0).queue_free()
	sfx("ripple", -4)
	Game.reveal_deed("lantern")
	hud.say("The lantern did not banish the dark. It only showed that the dark was a door.", 6.0)
	var tw := create_tween()
	tw.tween_property(s.material_override, "albedo_color:a", 0.0, 2.5)
	tw.tween_callback(s.queue_free)
	_velm_stage = 1


## Beyond the dark door, the one who has been following him waits, and speaks.
func _velm_in_the_dark() -> void:
	if _velm_stage == 1:
		if velm == null:
			velm = Velm.new()
			add_child(velm)
		velm_scripted = true
		_velm_stage = 2
		var at := _dir(TRUE_ANGLE) * (HUB_R + 18.0)
		velm.global_position = at
		velm.rotation.y = yaw_to(at, player.global_position) + PI
		velm.appear(3.0)
	elif _velm_stage == 2 and player.global_position.distance_to(velm.global_position) < 8.0:
		_velm_stage = 3
		_velm_speaks()


func _velm_speaks() -> void:
	player.speed_cap = 0.8
	sfx("whispers", -10)
	var lines := [
		"Velm:\n\"I took the dark way too, Brelm. I have taken it more times than you have breathed.\"",
		"Velm:\n\"Every time I came out of the dark, I was a little more of me, and a little less of you.\"",
		"Velm:\n\"You have been reading my hand. Did you think the Leaves were yours? Look closer at the next one.\"",
	]
	for l in lines:
		hud.say(l, 5.5)
		await get_tree().create_timer(6.0, false).timeout
	velm.vanish()
	sfx("ripple", -6, null, 0.5)
	hud.set_fx("glitch", 0.6)
	get_tree().create_timer(0.3, false).timeout.connect(func(): hud.set_fx("glitch", 0.0))
	hud.say("Under the hood, for a breath, he had seen his own face, older than he would ever be.", 6.0)
	player.speed_cap = -1.0
	Game.stats["velm_caves"] = 1
	Game.save()


func _sanctum() -> void:
	var inner := _dir(TRUE_ANGLE) * (HUB_R + TUNNEL_LEN + 22.0)
	await survive("speebsnek", inner + Vector3(0, 3.0, 0), "volley")
	reveal("speebsnek", inner + Vector3(0, 3.0, 0), 3.2, false)
