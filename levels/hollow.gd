extends Level
## VII. The Hollow of False Comfort. Softness everywhere, and the will to go on slowly eroding. Brelm must not sleep.

const EXIT := Vector3(0, 0, -120)

var drowsy := 0.0
var clouds: Array = []
var beds: Array = []
var escaped := false


func build() -> void:
	numeral = "VII"
	place = "The Hollow of False Comfort"
	verse = "Seventh, he passed through the Hollow of False Comfort, where Floofspeeb offered sweetness without substance, comfort without challenge."
	setup_env(Color(0.55, 0.48, 0.62), Color(0.95, 0.8, 0.78), Color(0.6, 0.5, 0.55), Color(0.92, 0.82, 0.84), 0.018, 1.0)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(1.0, 0.9, 0.92)
	add_sun(Vector3(-20, 40, 0), Color(1.0, 0.85, 0.75), 1.3)
	kill_y = -20
	var soft_ground := mat(Color(0.62, 0.55, 0.6), 1.0, 0.25, 0.06)
	box(Vector3(0, -0.5, -60), Vector3(80, 1, 180), soft_ground)
	# The walls of the hollow, rounded and gentle
	for i in 20:
		var z := 15.0 - i * 8.0
		sphere(Vector3(-22 - _rng.randf_range(0, 6), 2, z), _rng.randf_range(9, 14), soft_ground, true, 0.7)
		sphere(Vector3(22 + _rng.randf_range(0, 6), 2, z), _rng.randf_range(9, 14), soft_ground, true, 0.7)
	sphere(Vector3(0, 2, 26), 16, soft_ground, true, 0.7)
	# Clouds resting on the ground, and beds of cloud along the way
	var cloud := StandardMaterial3D.new()
	cloud.albedo_color = Color(1, 0.97, 0.97)
	cloud.roughness = 1.0
	cloud.emission_enabled = true
	cloud.emission = Color(1.0, 0.9, 0.92)
	cloud.emission_energy_multiplier = 0.25
	cloud.rim_enabled = true
	cloud.rim = 0.6
	for i in 26:
		var p := Vector3(_rng.randf_range(-13, 13), 0.0, -8.0 - i * 4.2)
		if absf(p.x) < 3.5:
			p.x = 3.5 * signf(p.x if p.x != 0 else 1.0) + p.x
		var n := Node3D.new()
		n.position = p
		add_child(n)
		for k in 6:
			var r := _rng.randf_range(0.9, 2.0)
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = r
			sm.height = r * 1.6
			mi.mesh = sm
			mi.material_override = cloud
			mi.position = Vector3(_rng.randf_range(-1.8, 1.8), r * 0.5 + _rng.randf_range(0, 1.0), _rng.randf_range(-1.2, 1.2))
			n.add_child(mi)
		clouds.append(p)
	for i in 5:
		var p := Vector3(-5 if i % 2 == 0 else 5, 0.4, -18 - i * 22)
		var b := sphere(p, 1.4, cloud, true, 0.45)
		b.scale = Vector3(1.6, 1, 1.0)
		var body: StaticBody3D = b.get_child(0)
		make_interactable(body, "Lie down and rest awhile", func(): _sleep("He lay down upon the clouds, only for a moment. The moment did not end."))
		beds.append(p)
	# The way out: a plain stone arch, unadorned
	var stone := mat(Color(0.45, 0.43, 0.42), 0.95, 0.35, 0.2)
	box(EXIT + Vector3(-2.2, 2.5, 0), Vector3(0.9, 5, 0.9), stone)
	box(EXIT + Vector3(2.2, 2.5, 0), Vector3(0.9, 5, 0.9), stone)
	box(EXIT + Vector3(0, 5.3, 0), Vector3(5.4, 0.7, 0.9), stone)
	trigger_area(EXIT + Vector3(0, 1.5, -1.5), Vector3(4, 3, 2), _through)

	lesser("sleepyspeeb", beds[1] + Vector3(0, 1.6, 0))
	lesser("serenespeeb", Vector3(-10, 1.4, -70))
	lesser("scarfspeeb", Vector3(11, 1.4, -38))
	lesser("moonspeeb", EXIT + Vector3(-4, 4.5, 2))
	ambient("lull", -6)
	spawn_pos = Vector3(0, 0.1, 6)
	spawn_yaw = 0.0


func intro() -> void:
	hud.set_objective("Pass through the Hollow. Keep moving. Do not rest.")
	hud.set_meter("Drowsiness", 0.0)
	await super.intro()


func trial_tick(delta: float) -> void:
	if escaped:
		return
	var p := player.global_position
	var near := 99.0
	for c in clouds:
		near = minf(near, Vector2(p.x - c.x, p.z - c.z).length())
	for b in beds:
		near = minf(near, Vector2(p.x - b.x, p.z - b.z).length() - 1.0)
	var rate := 0.018
	if player.cur_speed < 0.4:
		rate += 0.07
	elif player.cur_speed > 2.0:
		rate -= 0.06
	if near < 4.5:
		rate += 0.11 * (1.0 - near / 4.5) + 0.03
	drowsy = clampf(drowsy + rate * delta, 0.0, 1.0)
	hud.set_meter("Drowsiness", drowsy)
	hud.set_fx("dark", drowsy * 0.55)
	hud.set_fx("blur", drowsy * 2.0)
	hud.set_fx("vignette", 0.35 + drowsy * 1.2)
	player.speed_cap = lerpf(6.0, 2.2, drowsy)
	if drowsy >= 1.0:
		_sleep("Brelm slept upon a bed of clouded dreams, and the seasons passed over him unseen.")


func _sleep(msg: String) -> void:
	fail(msg, "")


func reset_trial() -> void:
	drowsy = 0.0
	hud.set_fx("dark", 0.0)
	hud.set_fx("blur", 0.0)
	hud.set_fx("vignette", 0.35)


func _through() -> void:
	if completed:
		return
	completed = true
	hud.set_fx("blur", 0.0)
	hud.set_fx("dark", 0.0)
	hud.set_fx("vignette", 0.35)
	player.speed_cap = -1
	hud.say("He passed beneath the plain stone, and turned. The softness was still there, waiting, as it always would be.", 6.0)
	await get_tree().create_timer(6.0, false).timeout
	completed = false
	escaped = true
	await survive("floofspeeb", EXIT + Vector3(0, 3.0, 10), "pulse")
	reveal("floofspeeb", EXIT + Vector3(0, 3.0, 10), 3.2, false)
