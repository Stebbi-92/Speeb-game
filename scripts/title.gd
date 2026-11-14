extends Node3D
## The opening: the White Cat in the dark, unblinking.

var hud
var cam: Camera3D
var speeb: Emoji3D
var _t := 0.0
var _menu: VBoxContainer
var _chapters: VBoxContainer
var _together: VBoxContainer
var _lobby: VBoxContainer
var _status: Label
var _found: VBoxContainer
var _roster: VBoxContainer
var _lobby_info: Label
var _choose: Control
var _col: VBoxContainer
var _spacer: Control
var _hint: Label

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
	v.grow_vertical = Control.GROW_DIRECTION_END
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
	_col = v
	_spacer = sp
	_menu = VBoxContainer.new()
	v.add_child(_menu)
	_menu.add_child(_btn("Begin the Pilgrimage", func(): Game.main.begin_pilgrimage()))
	if Game.reached > 0:
		_menu.add_child(_btn("Return to a Trial", _show_chapters))
	_menu.add_child(_btn("The Ashen Waste", _show_waste))
	_menu.add_child(_btn("Walk Together", _show_together))
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
	_waste = VBoxContainer.new()
	_waste.visible = false
	_waste.add_theme_constant_override("separation", 4)
	v.add_child(_waste)
	_together = VBoxContainer.new()
	_together.visible = false
	_together.add_theme_constant_override("separation", 6)
	v.add_child(_together)
	_build_together()
	_lobby = VBoxContainer.new()
	_lobby.visible = false
	_lobby.add_theme_constant_override("separation", 6)
	v.add_child(_lobby)
	Net.roster_changed.connect(_on_roster)
	Net.status_changed.connect(func(t): if _status: _status.text = t)
	Net.servers_changed.connect(_list_servers)
	if Net.online:
		_show_lobby.call_deferred()
	elif Net._joining or "together" in OS.get_cmdline_user_args():
		_show_together.call_deferred()

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
	_hint = c


func _btn(text: String, cb: Callable, size := 30) -> Button:
	var b: Button = hud.button(text, cb, size)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


var _waste: VBoxContainer


## The open waste: three worlds may be kept, each with its own days, beacons and shelters.
func _show_waste() -> void:
	_menu.visible = false
	_waste.visible = true
	for c in _waste.get_children():
		c.queue_free()
	_waste.add_child(_heading("The Ashen Waste"))
	_waste.add_child(_small("Cast out into the waste, you gather, build and live through its nights,\nwhile nine dead beacons wait to be kindled. The world is kept between walks."))
	for i in 3:
		var slot := str(i + 1)
		var d := Wasteland.describe(slot)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 14)
		var seed_e: LineEdit = null
		if d == "":
			seed_e = _field("", "seed (empty for a new land)", 220)
		hb.add_child(_btn("World %s:  %s" % [["I", "II", "III"][i], d if d != "" else "unwalked"], func():
			Game.world_slot = slot
			Game.new_world_seed = 0
			if seed_e and seed_e.text.strip_edges().is_valid_int():
				Game.new_world_seed = absi(int(seed_e.text.strip_edges()))
			elif seed_e and seed_e.text.strip_edges() != "":
				Game.new_world_seed = absi(seed_e.text.strip_edges().hash()) % 99999999 + 1
			Game.main.start_level(Game.WASTELAND), 22))
		if seed_e:
			hb.add_child(seed_e)
		if d != "":
			hb.add_child(_btn("forget", func():
				DirAccess.remove_absolute(Wasteland.world_path(slot))
				_show_waste(), 16))
		_waste.add_child(hb)
	_waste.add_child(_btn("Back", func(): _waste.visible = false; _menu.visible = true, 22))


func _show_chapters() -> void:
	_menu.visible = false
	_chapters.visible = true


func _process(delta: float) -> void:
	_t += delta
	speeb.rotation.y = sin(_t * 0.15) * 0.35
	cam.position.x = sin(_t * 0.07) * 1.2
	cam.look_at(Vector3(0, 2.6, 0))


# ------------------------------------------------------------------ walking together

func _small(text: String, color := Color(0.62, 0.60, 0.56), size := 18) -> Label:
	var l: Label = hud._label(text, size, color, HORIZONTAL_ALIGNMENT_LEFT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	return l


func _field(value: String, hint: String, width := 260) -> LineEdit:
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = hint
	e.custom_minimum_size = Vector2(width, 36)
	e.add_theme_font_size_override("font_size", 19)
	return e


func _heading(text: String) -> Label:
	var l: Label = hud._label(text, 24, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	l.add_theme_font_override("font", hud.title_font)
	return l


func _build_together() -> void:
	_together.add_child(_heading("Walk Together"))
	_together.add_child(_small("Up to four pilgrims may walk the trials as one fellowship. One hosts; the others join."))
	var nh := HBoxContainer.new()
	nh.add_child(_small("Your name", hud.PALE, 19))
	nh.get_child(0).custom_minimum_size.x = 150
	var name_e := _field(Game.player_name, "Pilgrim", 260)
	name_e.text_changed.connect(func(t): Game.player_name = t.strip_edges().left(20); Game.save())
	nh.add_child(name_e)
	_together.add_child(nh)
	# Hosting
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 8)
	var sname := _field("", "Name of the fellowship", 250)
	var port := _field(str(Net.DEFAULT_PORT), "Port", 90)
	var listed := CheckBox.new()
	listed.text = "List on the internet"
	listed.add_theme_font_size_override("font_size", 17)
	listed.disabled = Net.lobby_url() == ""
	listed.tooltip_text = "Set an internet list address in Options to list fellowships publicly." if listed.disabled else ""
	hh.add_child(sname)
	hh.add_child(port)
	hh.add_child(listed)
	_together.add_child(hh)
	_together.add_child(_btn("Host a fellowship", func():
		var n: String = sname.text.strip_edges()
		if n == "":
			n = "%s's fellowship" % Net.my_name()
		var p := int(port.text) if port.text.is_valid_int() else Net.DEFAULT_PORT
		if Net.host(p, n, listed.button_pressed) == OK:
			_show_lobby()
		else:
			_status.text = Net.last_error, 24))
	# Joining by address
	var jh := HBoxContainer.new()
	jh.add_theme_constant_override("separation", 8)
	var addr := _field("", "Address, or address:port", 350)
	jh.add_child(addr)
	jh.add_child(_btn("Join", func():
		if addr.text.strip_edges() == "":
			_status.text = "Give the host's address. They will find it in their gathering place."
			return
		var hp := Net.split_address(addr.text)
		Net.join(hp[0], hp[1]), 24))
	_together.add_child(jh)
	# The list of fellowships
	var lh := HBoxContainer.new()
	lh.add_child(_heading("Fellowships found"))
	lh.add_child(_btn("Look again", func(): Net.refresh_servers(), 20))
	_together.add_child(lh)
	_found = VBoxContainer.new()
	_found.add_theme_constant_override("separation", 0)
	_together.add_child(_found)
	_status = _small("")
	_status.add_theme_color_override("font_color", hud.GOLD)
	_together.add_child(_status)
	_together.add_child(_btn("Back", func(): _together.visible = false; _menu.visible = true; _raise_column(false), 22))


## The fellowship's pages are long: the column rises to make room for them.
func _raise_column(up: bool) -> void:
	_col.position.y = _col.get_parent().size.y * 0.5 + (-415.0 if up else -250.0)
	_spacer.visible = not up
	_hint.visible = not up


func _show_together() -> void:
	_raise_column(true)
	_menu.visible = false
	_chapters.visible = false
	_lobby.visible = false
	_together.visible = true
	if Net.last_error != "" and not Net._joining:
		_status.text = Net.last_error
	Net.refresh_servers()
	_list_servers()


func _list_servers() -> void:
	if _found == null:
		return
	for c in _found.get_children():
		c.queue_free()
	if Net.servers.is_empty():
		_found.add_child(_small("None yet. Fellowships on this network appear here; with an internet list set in Options, so do public ones."))
		return
	for key in Net.servers:
		var d: Dictionary = Net.servers[key]
		var lvl := int(d.get("level", -1))
		var where: String = "gathering" if lvl < 0 or lvl >= PLACES.size() else PLACES[lvl].get_slice(":", 0).get_slice(".", 0)
		if lvl >= 0 and lvl < PLACES.size():
			where = PLACES[lvl]
		var full := int(d.get("players", 0)) >= int(d.get("max", 4))
		var text := "%s   ·   %d of %d   ·   %s   ·   %s" % [str(d.get("name", "?")).left(28), int(d.get("players", 0)), int(d.get("max", 4)), where, d.get("source", "")]
		var ip: String = d.ip
		var p := int(d.port)
		var b := _btn(text, func(): Net.join(ip, p), 19)
		b.disabled = full or d.get("proto", Net.PROTOCOL) != Net.PROTOCOL
		_found.add_child(b)


func _show_lobby() -> void:
	_raise_column(true)
	_menu.visible = false
	_chapters.visible = false
	_together.visible = false
	_lobby.visible = true
	_on_roster()


func _on_roster() -> void:
	if not Net.online:
		if _lobby.visible:
			_lobby.visible = false
			_menu.visible = true
			_raise_column(false)
		return
	if not _lobby.visible:
		_show_lobby()
		return
	for c in _lobby.get_children():
		c.queue_free()
	_lobby.add_child(_heading(Net.server_name))
	var info := ""
	if Net.is_host():
		info = "You are hosting on port %d." % Net.port
		var locals := Net.local_addresses()
		if not locals.is_empty():
			info += "\nOn this network, others join at: %s" % ", ".join(locals.map(func(a): return "%s:%d" % [a, Net.port]))
		if Net.external_ip != "":
			info += "\nFrom the internet: %s:%d" % [Net.external_ip, Net.port]
		if Net.upnp_state != "":
			info += "\n" + Net.upnp_state
	else:
		info = "You walk with this fellowship. The host decides the way."
	_lobby.add_child(_small(info))
	_lobby.add_child(_heading("The fellowship  (%d of %d)" % [Net.players.size(), Net.MAX_PLAYERS]))
	for id in Net.players:
		var mark := ""
		if id == 1:
			mark = "  · host"
		elif id == Net.leader and Net.leader != 1:
			mark = "  · chooses the way"
		if id == Net.me():
			mark += "  · you"
		var l := _small(Net.name_of(id) + mark, Net.color_of(id).lightened(0.25), 21)
		l.add_theme_font_override("font", hud.title_font)
		_lobby.add_child(l)
	if Net.may_choose():
		_lobby.add_child(_heading("Choose the trial"))
		if Net.is_host():
			var o := OptionButton.new()
			for d in Game.DIFFICULTIES:
				o.add_item(d)
			o.selected = Game.difficulty
			o.custom_minimum_size.x = 220
			o.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			o.add_theme_font_size_override("font_size", 18)
			o.item_selected.connect(func(i): Game.difficulty = i; Game.save())
			_lobby.add_child(o)
		var grid := GridContainer.new()
		grid.columns = 2
		_lobby.add_child(grid)
		for i in range(mini(Game.reached, 10) + 1):
			var idx := i
			grid.add_child(_btn(PLACES[i], func(): Net.begin(idx), 18))
		if Game.tenth_unlocked():
			grid.add_child(_btn("The Tenth Trial", func(): Net.begin(11), 18))
		if Net.is_host():
			_lobby.add_child(_heading("Or walk the open waste"))
			var wh := HBoxContainer.new()
			wh.add_theme_constant_override("separation", 10)
			var ws := OptionButton.new()
			for i in 3:
				var d := Wasteland.describe(str(i + 1))
				ws.add_item("World %s  (%s)" % [["I", "II", "III"][i], d if d != "" else "unwalked"])
			ws.selected = int(Game.world_slot) - 1
			ws.add_theme_font_size_override("font_size", 17)
			ws.item_selected.connect(func(i): Game.world_slot = str(i + 1))
			wh.add_child(ws)
			wh.add_child(_btn("The Ashen Waste", func(): Net.begin(Game.WASTELAND), 18))
			_lobby.add_child(wh)
	else:
		_lobby.add_child(_small("Waiting for the host to choose a trial.", hud.PALE, 19))
	_lobby.add_child(_btn("Leave the fellowship", func(): Net.leave(""); _lobby.visible = false; _menu.visible = true; _raise_column(false), 22))
