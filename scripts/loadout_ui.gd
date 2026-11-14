class_name LoadoutUI
extends PanelContainer
## The choosing of arms before a trial: two guns and their sights, a blade, grenades and a gadget.
## What is not yet earned shows the rank that earns it.

signal done

const SLOTS := [["primary", "Primary"], ["secondary", "Secondary"], ["melee", "Melee"], ["grenade", "Grenade"], ["gadget", "Gadget"]]

var hud
var _body: VBoxContainer
var _info: Label
var _go: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.035, 0.92)
	sb.set_content_margin_all(40)
	add_theme_stylebox_override("panel", sb)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(1180, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var t: Label = hud._label("Arms", 46, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	t.add_theme_font_override("font", hud.title_font)
	box.add_child(t)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(1180, 6)
	bar.max_value = ArmsDB.need(Game.plevel)
	bar.value = Game.pxp
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(hud.GOLD, 0.7)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	box.add_child(bar)
	var next := ""
	for lv in range(Game.plevel + 1, ArmsDB.MAX_LEVEL + 1):
		var u := ArmsDB.unlocked_at(lv)
		if not u.is_empty():
			next = "   Rank %d brings %s." % [lv, ", ".join(u)]
			break
	box.add_child(hud._label("Rank %d.   %d of %d toward the next.%s" % [Game.plevel, Game.pxp, ArmsDB.need(Game.plevel), next], 17, hud.DIM, HORIZONTAL_ALIGNMENT_LEFT))
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	box.add_child(_body)
	_info = hud._label("", 17, hud.DIM, HORIZONTAL_ALIGNMENT_LEFT)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(1180, 52)
	box.add_child(_info)
	_go = _btn("Go", _finish, 30, hud.GOLD)
	_go.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(_go)
	_rebuild()
	_go.grab_focus.call_deferred()


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		_finish()


func _finish() -> void:
	Game._fix_loadout()
	Game.save()
	done.emit()
	queue_free()


func _btn(text: String, cb: Callable, size := 18, color: Color = Color(0.93, 0.92, 0.88)) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", hud.GOLD)
	b.add_theme_color_override("font_disabled_color", Color(hud.DIM, 0.45))
	b.pressed.connect(cb)
	return b


func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	for sl in SLOTS:
		var kind: String = sl[0]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_body.add_child(row)
		var head: Label = hud._label(sl[1], 20, hud.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		head.custom_minimum_size.x = 150
		row.add_child(head)
		var t := ArmsDB.table(kind)
		for id in ArmsDB.choices(kind):
			var have: bool = Game.unlocked(t, id)
			var chosen: bool = Game.loadout.get(kind) == id
			var label: String = t[id].name if have else "%s  (rank %d)" % [t[id].name, int(t[id].unlock)]
			var b := _btn(("◆ " if chosen else "") + label, _choose.bind(kind, id), 18, hud.GOLD if chosen else (hud.PALE if have else hud.DIM))
			b.disabled = not have
			b.mouse_entered.connect(func(): _info.text = t[id].text)
			row.add_child(b)
		# The sights and barrels the chosen gun can take
		if kind in ["primary", "secondary"]:
			var g: String = Game.loadout[kind]
			var mounts: Array = ArmsDB.GUNS[g].mounts
			if mounts.is_empty():
				continue
			var mrow := HBoxContainer.new()
			mrow.add_theme_constant_override("separation", 6)
			_body.add_child(mrow)
			var pad := Control.new()
			pad.custom_minimum_size.x = 150
			mrow.add_child(pad)
			mrow.add_child(hud._label("on the %s:" % ArmsDB.GUNS[g].name.to_lower(), 15, hud.DIM, HORIZONTAL_ALIGNMENT_LEFT))
			var on: Array = Game.mounts_of(g)
			for m in mounts:
				var a: Dictionary = ArmsDB.ATTACHMENTS[m]
				var have: bool = Game.unlocked(ArmsDB.ATTACHMENTS, m)
				var lab: String = a.name if have else "%s  (rank %d)" % [a.name, int(a.unlock)]
				var b := _btn(("◆ " if m in on else "") + lab, _mount.bind(g, m), 15, hud.GOLD if m in on else (hud.PALE if have else hud.DIM))
				b.disabled = not have
				b.mouse_entered.connect(func(): _info.text = "%s: %s" % [ArmsDB.SLOT_NAMES[a.slot], a.text])
				mrow.add_child(b)


func _choose(kind: String, id: String) -> void:
	Game.loadout[kind] = id
	_info.text = ArmsDB.table(kind)[id].text
	_rebuild()


## Fits or removes one thing. A gun takes one thing to each slot, so a new sight replaces the old.
func _mount(g: String, m: String) -> void:
	var on: Array = Game.mounts_of(g).duplicate()
	if m in on:
		on.erase(m)
	else:
		on = on.filter(func(x): return ArmsDB.ATTACHMENTS[x].slot != ArmsDB.ATTACHMENTS[m].slot)
		on.append(m)
	if not Game.loadout.get("mounts") is Dictionary:
		Game.loadout.mounts = {}
	if on.is_empty():
		Game.loadout.mounts.erase(g)
	else:
		Game.loadout.mounts[g] = on
	_rebuild()
