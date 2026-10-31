extends Node3D
## The opening: the White Cat in the dark, unblinking.

var hud
var cam: Camera3D
var speeb: Emoji3D
var _t := 0.0
var _menu: VBoxContainer
var _chapters: VBoxContainer

const PLACES := [
	"Prologue: The Plateau of Mirrors", "I. The Cliffs of Echoing Cries", "II. The Ruins of the Fallen Kings",
	"III. The Verdant Wastes", "IV. The Heights of Sorrows", "V. The Fields of Forgetting", "VI. The Mirror Caves",
	"VII. The Hollow of False Comfort", "VIII. The Sealed Stone", "IX. The Silent Lake", "The Forgotten Cave",
]


func _ready() -> void:
	hud = Game.main.hud
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.05, 0.06)
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.03, 0.035)
	env.fog_density = 0.04
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.8, 0.8, 0.85)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	speeb = Emoji3D.new().setup("_speeb", 3.2, 0.4)
	speeb.position = Vector3(0, 2.6, 0)
	speeb.glow = 0.15
	add_child(speeb)
	var ped := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.4
	cm.bottom_radius = 1.6
	cm.height = 0.9
	ped.mesh = cm
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.85, 0.85, 0.82)
	pm.roughness = 0.6
	ped.material_override = pm
	ped.position.y = 0.45
	add_child(ped)
	var floor_m := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(80, 80)
	floor_m.mesh = pl
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.05, 0.05, 0.055)
	fm.roughness = 0.15
	fm.metallic = 0.4
	floor_m.material_override = fm
	add_child(floor_m)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 9, 2)
	spot.rotation_degrees = Vector3(-80, 0, 0)
	spot.spot_angle = 22
	spot.light_energy = 6
	spot.spot_range = 20
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 3.0
	add_child(spot)
	cam = Camera3D.new()
	cam.position = Vector3(0, 2.4, 8.5)
	cam.fov = 50
	add_child(cam)
	cam.current = true
	var drone := AudioStreamPlayer.new()
	var s = load("res://assets/audio/drone.ogg")
	s.loop = true
	drone.stream = s
	drone.volume_db = -10
	drone.autoplay = true
	add_child(drone)
	_build_menu()


func _build_menu() -> void:
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.menu_box.add_child(box)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(110, -250)
	v.size = Vector2(620, 500)
	v.add_theme_constant_override("separation", 6)
	box.add_child(v)
	var t: Label = hud._label("BRELM", 96, hud.PALE, HORIZONTAL_ALIGNMENT_LEFT)
	t.add_theme_font_override("font", hud.title_font)
	v.add_child(t)
	var st: Label = hud._label("The Hermit of Nine Visions", 34, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	st.add_theme_font_override("font", hud.title_font)
	v.add_child(st)
	var sp := Control.new()
	sp.custom_minimum_size.y = 40
	v.add_child(sp)
	_menu = VBoxContainer.new()
	v.add_child(_menu)
	_menu.add_child(_btn("Begin the Pilgrimage", func(): Game.main.begin_pilgrimage()))
	if Game.reached > 0:
		_menu.add_child(_btn("Return to a Trial", _show_chapters))
	_menu.add_child(_btn("Options", func(): hud.show_options()))
	if Game.tenth_unlocked():
		_menu.add_child(_btn("The Tenth Trial", func(): Game.main.start_level(11)))
	_menu.add_child(_btn("The Book of Emojis", func(): hud.toggle_codex()))
	_menu.add_child(_btn("Leave", func(): get_tree().quit()))
	_chapters = VBoxContainer.new()
	_chapters.visible = false
	v.add_child(_chapters)
	for i in range(Game.reached + 1):
		var idx := i
		_chapters.add_child(_btn(PLACES[i], func(): Game.main.start_level(idx), 22))
	_chapters.add_child(_btn("Back", func(): _chapters.visible = false; _menu.visible = true, 22))

	var q: Label = hud._label("\"Speeb sees. Speeb is. Do not try to please him. Only survive him.\"\n— scratched in claw-marks upon a cave wall", 20, hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	q.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	q.position = Vector2(-900, -110)
	q.size = Vector2(860, 80)
	box.add_child(q)
	var ver: Label = hud._label("v" + str(ProjectSettings.get_setting("application/config/version", "")), 14, hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	ver.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ver.position = Vector2(-140, 20)
	ver.size = Vector2(110, 24)
	box.add_child(ver)
	var c: Label = hud._label("WASD walk  ·  Mouse look  ·  LMB use  ·  1–6 or wheel relics  ·  E interact  ·  Shift hasten  ·  Tab the Book of Emojis  ·  Esc stillness", 16, hud.DIM, HORIZONTAL_ALIGNMENT_LEFT)
	c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	c.position = Vector2(110, -60)
	c.size = Vector2(1200, 30)
	box.add_child(c)


func _btn(text: String, cb: Callable, size := 30) -> Button:
	var b: Button = hud.button(text, cb, size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


func _show_chapters() -> void:
	_menu.visible = false
	_chapters.visible = true


func _process(delta: float) -> void:
	_t += delta
	speeb.rotation.y = sin(_t * 0.15) * 0.35
	cam.position.x = sin(_t * 0.07) * 1.2
	cam.look_at(Vector3(0, 2.6, 0))
