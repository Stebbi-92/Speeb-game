extends Level
## VIII. The Sealed Stone. Brelm places his hand upon the stone and keeps the vigil. To move is to break the silence.

const STONE := Vector3(0, 0, -30)
const VIGIL := 30.0
const VOWS := [
	"The First Vow: to Uphold Balance. To act neither in excess nor in apathy; to temper every deed with unseen measure.",
	"The Second Vow: to Guard the Sacred Silence. To refrain from idle talk, from boasting and from pleading.",
	"The Third Vow: to Accept Judgment Without Plea. To embrace the purring or the claw with the same bowed head.",
]

var vigil := false
var progress := 0.0
var vow_shown := -1
var rune_sets: Array = []
var rune_mat_on: StandardMaterial3D
var rune_mat_off: StandardMaterial3D
var heart: AudioStreamPlayer
var stone_body: StaticBody3D
var grace := 0.0


func build() -> void:
	numeral = "VIII"
	max_alive = 4
	place = "The Sealed Stone"
	verse = "Eighth, he stood before the Sealed Stone and took an oath before Runespeeb, swearing to bear the truths he had gathered even unto madness."
	setup_env(Color(0.01, 0.015, 0.04), Color(0.06, 0.07, 0.12), Color(0.01, 0.01, 0.02), Color(0.05, 0.06, 0.1), 0.012, 0.8)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	set_sky_stars()
	add_sun(Vector3(-35, 30, 0), Color(0.55, 0.62, 0.85), 0.7)
	var grass := mat(Color(0.12, 0.14, 0.12), 1.0, 0.4, 0.05)
	box(Vector3(0, -0.5, -20), Vector3(200, 1, 200), grass)
	var stone := mat(Color(0.38, 0.38, 0.4), 0.9, 0.45, 0.25)
	rune_mat_off = StandardMaterial3D.new()
	rune_mat_off.albedo_color = Color(0.12, 0.12, 0.14)
	rune_mat_on = glow_mat(Color(0.55, 0.75, 1.0), 4.0)
	# The Sealed Stone
	var mono := box(STONE + Vector3(0, 3.2, 0), Vector3(2.4, 6.4, 1.2), stone)
	stone_body = mono.get_child(0)
	pawprint(STONE + Vector3(0, 1.5, 0.61), 0.0, 0.7, glow_mat(Color(0.7, 0.8, 1.0), 1.0), true)
	# Nine standing stones in a ring; three runes kindle with each vow
	for k in 9:
		var a := PI * 0.5 + k * TAU / 9.0
		var p := STONE + Vector3(cos(a) * 9.0, 0, sin(a) * 9.0)
		var h := _rng.randf_range(2.6, 3.6)
		var s := box(p + Vector3(0, h * 0.5, 0), Vector3(1.1, h, 0.7), stone)
		s.rotation.y = yaw_to(p, STONE)
		var r := rune(p + Vector3(0, h * 0.6, 0) + (STONE - p).normalized() * 0.37, yaw_to(p, STONE) + PI, 1.0, rune_mat_off)
		rune_sets.append(r)
	for k in 6:
		rune(STONE + Vector3(-0.6 + (k % 2) * 1.2, 2.6 + (k / 2) * 1.2, 0.62), 0.0, 0.8, rune_mat_off)
	make_interactable(stone_body, "Place your hand upon the Sealed Stone", _begin, 1.5)
	label3d("Those who broke their word felt their spirits crack and crumble.\nThose who honoured their promises were strengthened with an invisible armour against despair.",
		Vector3(0, 0.6, -12), 0.22, Color(0.5, 0.55, 0.7), 0.0, true)
	lesser("oathspeeb", STONE + Vector3(-12, 1.4, 6))
	lesser("glyphspeeb", STONE + Vector3(10, 1.4, -10))
	lesser("thirdeyespeeb", Vector3(14, 1.4, 4))
	lesser("wizardspeebii", Vector3(-16, 1.4, -44))
	ambient("wind", -18)
	heart = ambient("heartbeat", -60)
	spawn_pos = Vector3(0, 0.1, 6)
	spawn_yaw = 0.0


func intro() -> void:
	hud.set_objective("Go to the Sealed Stone")
	await super.intro()


func _begin() -> void:
	if vigil:
		return
	vigil = true
	combat_frozen = true
	clear_enemies()
	hud.say("The lesser forms fall still. The silence holds them.", 4.0)
	stone_body.set_meta("prompt", "")
	player.place(STONE + Vector3(0, 0.1, 1.6), 0.0)
	player.look_toward(STONE + Vector3(0, 2.2, 0), 1.0)
	grace = 1.4
	progress = 0.0
	vow_shown = -1
	player.look_motion = 0.0
	hud.set_objective("Keep the vigil. Do not move. Do not look away.")
	create_tween().tween_property(heart, "volume_db", -6.0, 3.0)


func trial_tick(delta: float) -> void:
	if not vigil:
		return
	if grace > 0.0:
		grace -= delta
		player.look_motion = 0.0
		return
	var moving := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.1 or Input.is_action_pressed("jump")
	var looked := player.look_motion > 40.0
	player.look_motion = maxf(0.0, player.look_motion - delta * 60.0)
	if moving or looked:
		_broken()
		return
	progress += delta
	hud.set_meter("The Oath", progress / VIGIL)
	var stage := int(progress / (VIGIL / 3.0))
	if stage > vow_shown and stage < 3:
		vow_shown = stage
		hud.say(VOWS[stage], VIGIL / 3.0 - 1.0)
		sfx("bell", -16)
		for k in 3:
			_kindle(rune_sets[stage * 3 + k])
	if progress >= VIGIL:
		_sworn()


func _kindle(n: Node3D) -> void:
	for c in n.get_children():
		c.material_override = rune_mat_on


func _broken() -> void:
	vigil = false
	combat_frozen = false
	sfx("deny", -6)
	hud.clear_say()
	hud.say("The silence is broken. The stone grows cold beneath his hand.", 4.0)
	hud.set_meter("", 0.0)
	hud.set_objective("Place your hand upon the Sealed Stone once more")
	create_tween().tween_property(heart, "volume_db", -60.0, 2.0)
	for r in rune_sets:
		for c in r.get_children():
			c.material_override = rune_mat_off
	stone_body.set_meta("prompt", "Place your hand upon the Sealed Stone")


func _sworn() -> void:
	vigil = false
	create_tween().tween_property(heart, "volume_db", -60.0, 4.0)
	hud.set_meter("", 0.0)
	reveal("runespeeb", STONE + Vector3(0, 8.6, 0), 3.4, false)
