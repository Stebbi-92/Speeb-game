extends RefCounted
## Testing aid: fills the HUD with the longest lines it can be given (quest, weather, notices, names on the
## compass, the fellowship, a great one's bar, prompts) and checks, at the common screen sizes and every
## text size of the settings, that no words are drawn over other words or over a bar, and none leave the screen.
## Headless, each screen size is stood in for by the size the game lays its HUD out at (900 high, wider
## for a wide screen, smaller for larger text). With a window (SHOT_OUT set), it saves a picture instead.

## [width, height] of the screens checked
const SCREENS := [[1920, 1080], [2560, 1440], [1280, 720], [3440, 1440]]

var w
var hud
var ui
var _long_quest := ""


func run(world) -> void:
	w = world
	hud = w.hud
	ui = w.ui
	while not w.ready_world:
		await w.get_tree().create_timer(1.0).timeout
	await w.get_tree().create_timer(1.0).timeout
	_long_quest = _longest_quest_step()
	w.get_tree().paused = true   # nothing in the world writes over the lines while they are measured
	var shot: String = OS.get_environment("SHOT_OUT")
	if shot != "":
		await _shoot(shot)
		w.get_tree().quit()
		return
	var win: Window = w.get_window()
	var all_ok := true
	var n := 0
	for scr in SCREENS:
		for f in Game.UI_SCALES:
			# The size the HUD is laid out at: 1600 x 900 stretched to the screen's shape, over the text size
			var k: float = minf(scr[0] / 1600.0, scr[1] / 900.0) * float(f)
			var logical := Vector2i(roundi(scr[0] / k), roundi(scr[1] / k))
			win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
			win.content_scale_factor = 1.0
			win.content_scale_size = logical
			win.size = logical   # one pixel to a point, so the fonts measure as they draw
			for mode in ["walk", "build"]:
				fill(mode)
				for i in 3:
					await w.get_tree().process_frame
				fill(mode)   # once more, after the containers have taken their sizes
				await w.get_tree().process_frame
				var bad := overlaps(Rect2(Vector2.ZERO, Vector2(logical)))
				if n == 0:
					var fl: Label = ui._xp_text
					print("HUDFIT compass names=%s" % [ui._compass.labels.map(func(l): return l[1]) if ui._compass.get("labels") != null else "-"])
				n += 1
				if not bad.is_empty():
					all_ok = false
					print("HUDFIT %dx%d text=%d%% %s (%dx%d): %d" % [scr[0], scr[1], roundi(f * 100.0), mode, logical.x, logical.y, bad.size()])
					for b in bad:
						print("    ", b)
	var picked := filter_check()
	print("HUDFIT layouts=%d all=%s" % [n, all_ok])
	print("HUDFIT search=%s" % picked)
	w.get_tree().paused = false
	w.get_tree().quit()


## The longest step of any quest, as it is written on the screen.
func _longest_quest_step() -> String:
	var best := ""
	var src := FileAccess.get_file_as_string("res://world/quests.gd")
	var re := RegEx.create_from_string("\"text\": \"([^\"]+)\"")
	for m in re.search_all(src):
		var t: String = WPlaces.words(m.get_string(1))
		if t.length() > best.length():
			best = t
	return best


## Every worst case at once: what a busy moment in the waste can put on the screen.
func fill(mode: String) -> void:
	hud.set_objective("The Long Road to the Ninth Beacon of the Waste\n%s\nNext: carry your oil (3) to the Beacon of Restraint.\n1234 m north-west\n+9 more in the journal [%s]" % [_long_quest, Game.key_text("journal")])
	hud.toast.text = "+12 Deadwood,  +8 Stone,  +6 Scrap Iron,  +4 Cloth,  +3 Bone,  +2 Beacon Oil,  +1 Salt Crystal"
	hud.toast.modulate.a = 1.0
	if hud._feed == null or hud._feed.get_child_count() < 3:
		for i in 3:
			hud.feed("Pílu-Grímur Ashenhand has joined the fellowship.")
	# A great one near while walking (building in a fight is not looked for)
	hud.boss_bar("Velm, the Hermit's Last Long-Named Shadow" if mode == "walk" else "", 0.6)
	# The use prompt; while building the aimed wall's tip takes its place (a wall has no use prompt)
	hud.set_prompt("[E]  Open the Storage Chest of Cinderwick      Hold [E]  Pick it up" if mode == "walk" else "", 0.5)
	hud.subtitle_l.text = "Pílu-Grímur: \"Keep to the road, and keep the flame until it holds.\""
	hud.subtitle_l.modulate.a = 1.0
	hud.narration.text = "The ninth flame takes, and the ground beneath it groans. Something is climbing out of the mouth to put it out, and the night leans in close."
	hud.narration.modulate.a = 1.0
	hud.set_ammo(7, 8, 240)
	hud.set_kit("Salt Rifle · Long Glass · Muzzle Brake     Fire 3     Smoke Kit 2     [H] Gunship +2")
	hud.set_streak(9)
	hud.streak_label.scale = Vector2.ONE
	hud.streak_label.modulate.a = 1.0
	hud.fellowship_open = true
	var rows: Array = []
	for i in 8:
		rows.append(["Pílu-Grímur the %d" % i, 0.7, i == 3, Color.from_hsv(i / 8.0, 0.6, 0.9), "1234 m"])
	hud.set_fellowship(rows)
	hud.set_hotbar(0, 1.0, 3)
	hud.set_relic_hint("Faith gathers as you kill enemies")
	hud.set_health(0.6, true)
	ui._clock.text = "Day 128   23:59   Dusk\nHigh Ember,  ash storm"
	ui.set_hazard("The salt burns: you lose health while on the flats. A sheepskin wards it.")
	ui._boons.text = "Hearty Stew 58m   Roast Boar 44m (thin)   Ember Tea 12m   Rested 40m"
	ui._xp_text.text = "Level 50   Renown 12    3 to spend  [K]    a renown reward to choose  [K]"
	ui._xp_pop.text = "+1234"
	ui._xp_pop.modulate.a = 1.0
	ui._saved.text = "Saved"
	ui._saved.modulate.a = 1.0
	if ui._compass.get("test_marks") != null:
		ui._compass.test_marks = _crowd()
	else:   # the HUD as it was before the names were laid out: the crowd as marks on the map
		w.map_marks = _crowd().map(func(m): return [m[0], 0])
	ui._compass.queue_redraw()
	if mode == "build":
		if not w.builder.active:
			w.builder.toggle()
		w.builder.sel = Items.PIECE_ORDER.find("wall")
		ui.set_build_bar("wall", w.builder.sel)
		if ui.has_method("set_upgrade_tip"):
			ui.set_upgrade_tip("wall", 0)
	else:
		if w.builder.active:
			w.builder.toggle()
		if ui.has_method("set_upgrade_tip"):
			ui.set_upgrade_tip("", 0)
	ui._keys.visible = not w.builder.active
	ui._refresh_keys()
	if w.get("guide") and w.guide.has_method("follow_quest"):
		w.guide.follow_quest()
	if ui.has_method("stack_left"):
		ui.stack_left()   # the world is paused: the screens do not stack these by themselves


## Many marks close together on the compass, some named, ahead of the player.
func _crowd() -> Array:
	var out: Array = []
	var me: Vector3 = w.player.global_position
	var fwd: Vector3 = -w.player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var side := fwd.cross(Vector3.UP)
	var names := ["Pílu-Grímur", "Ashenhand the Long-Wandering", "", "", "Mother Velm", ""]
	for i in 14:
		var p: Vector3 = me + fwd * (40.0 + i * 23.0) + side * ((i % 5) - 2) * 6.0
		var nm: String = names[i % names.size()]
		if i == 0:
			out.append([p, Color(0.95, 0.82, 0.5), 7.0])
		elif nm != "":
			out.append([p, Color.from_hsv(i / 14.0, 0.5, 1.0), 6.0, nm])
		else:
			out.append([p, Color(0.95, 0.5, 0.35, 0.9), 6.0])
	return out


## The parts of the screen that hold words or bars, then each pair of words that touch, or touch a bar.
func overlaps(screen: Rect2) -> Array:
	var texts: Array = []   # [name, Rect2]
	var bars: Array = []
	var skip: Array = [hud.menu_box, hud.loading, hud.card_box, hud.reveal_box, hud.pause_panel, hud.options_panel, hud.codex_panel, hud.results_panel, ui._frame, ui._shade]
	_collect(hud.root, skip, texts, bars)
	for c in hud.root.find_children("*", "", true, false):
		c.remove_meta("hudfit")
	# Words drawn by hand: the names under the compass and the name under the belt
	var cr: Rect2 = ui._compass.get_global_rect()
	for l in ui._compass.get("labels") if ui._compass.get("labels") != null else []:
		texts.append(["compass:" + l[1], Rect2(cr.position + l[0].position, l[0].size)])
	bars.append(["compass band", Rect2(cr.position, Vector2(cr.size.x, 34))])
	var hb: Control = hud.hotbar
	if hb.visible:
		bars.append(["belt", Rect2(hb.global_position, Vector2(hb.size.x, hud.Hotbar.W))])
		if hb.get("name_rect") != null and hb.name_rect.size.x > 0.0:
			texts.append(["belt name", Rect2(hb.global_position + hb.name_rect.position, hb.name_rect.size)])
	var bad: Array = []
	for i in texts.size():
		var a: Rect2 = texts[i][1]
		if not screen.grow(1.0).encloses(a):
			bad.append("%s off the screen %s" % [texts[i][0], a])
		for j in range(i + 1, texts.size()):
			if a.grow(-1.0).intersects(texts[j][1].grow(-1.0)):
				bad.append("%s %s  over  %s %s" % [texts[i][0], a, texts[j][0], texts[j][1]])
		for b in bars:
			if a.grow(-1.0).intersects(b[1]):
				bad.append("%s %s  over bar %s %s" % [texts[i][0], a, b[0], b[1]])
	return bad


func _shown(c: CanvasItem) -> bool:
	var a := 1.0
	var n: Node = c
	while n is CanvasItem:
		if not (n as CanvasItem).visible:
			return false
		a *= (n as CanvasItem).modulate.a * (n as CanvasItem).self_modulate.a
		n = n.get_parent()
	return a > 0.05


func _collect(n: Node, skip: Array, texts: Array, bars: Array) -> void:
	for c in n.get_children():
		if c in skip or not c is CanvasItem or not (c as CanvasItem).visible or c.has_meta("hudfit"):
			continue
		c.set_meta("hudfit", true)
		if c is Label and _shown(c) and (c as Label).text.strip_edges() != "":
			for r in ink(c):
				texts.append([_name(c), r])
		elif c is RichTextLabel and _shown(c) and (c as RichTextLabel).get_parsed_text().strip_edges() != "":
			texts.append([_name(c), rich_ink(c)])
		elif c is ProgressBar and _shown(c):
			bars.append([_name(c), (c as Control).get_global_rect()])
		_collect(c, skip, texts, bars)


func _name(c: Control) -> String:
	var t: String = c.text if c is Label else (c as RichTextLabel).get_parsed_text() if c is RichTextLabel else str(c.name)
	return "\"%s\"" % t.left(28).replace("\n", " / ")


## Where a label's words are, line by line, on the screen (not the whole box it is given).
static func ink(l: Label) -> Array:
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var sp := l.get_theme_constant("line_spacing")
	var widths: Array = []
	var para := TextParagraph.new()
	for line in l.text.split("\n"):
		para.clear()
		para.add_string(line, font, fs)
		if l.autowrap_mode != TextServer.AUTOWRAP_OFF:
			para.width = l.size.x
			para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_TRIM_EDGE_SPACES
		for i in para.get_line_count():
			widths.append(para.get_line_width(i))
	if l.max_lines_visible >= 0:
		widths = widths.slice(0, l.max_lines_visible)
	var lh := font.get_height(fs) + sp
	var total := lh * widths.size() - sp
	var r := l.get_global_rect()
	var y := r.position.y
	match l.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			y += floorf((r.size.y - total) * 0.5)
		VERTICAL_ALIGNMENT_BOTTOM:
			y += r.size.y - total
	var out: Array = []
	for wd in widths:
		var x := r.position.x
		if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
			x += (r.size.x - wd) * 0.5
		elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			x += r.size.x - wd
		if wd > 0.0:
			# The letters themselves: from the tops of the capitals to the tails below the line
			var base := y + font.get_ascent(fs)
			out.append(Rect2(x, base - fs * 0.8, wd, fs * 1.05))
		y += lh
	return out


static func rich_ink(l: RichTextLabel) -> Rect2:
	var r := l.get_global_rect()
	var cw := float(l.get_content_width())
	var x := r.position.x + ((r.size.x - cw) * 0.5 if l.text.begins_with("[center]") else 0.0)
	return Rect2(x, r.position.y, cw, float(l.get_content_height()))


## The search boxes of the build and making menus keep the right entries. Returns "true" or what failed.
func filter_check() -> String:
	var fails: Array = []
	if not ui.has_method("build_list"):
		return "no search"
	var W = ui.get_script()
	if not W.search_hit("grim", ["Pílu-Grímur"]) or not W.search_hit("GRÍM pilu", ["Pílu-Grímur"]) or W.search_hit("grim x", ["Pílu-Grímur"]):
		fails.append("fold")
	# The build list: across every group, by name, group and text
	var walls: Array = ui.build_list("wall")
	for k in ["wall", "window", "stonewall", "palisade"]:
		if not k in walls:
			fails.append("build wall lacks " + k)
	if "chair" in walls or "campfire" in walls:
		fails.append("build wall too many")
	var snug: Array = ui.build_list("snug")
	for k in ["table", "chair", "rug", "bed"]:
		if not k in snug:
			fails.append("build snug lacks " + k)
	if not ui.build_list("zzqx").is_empty():
		fails.append("build zzqx")
	# On the screens themselves: a known name finds its card, nonsense says so
	var finds := {"build": "Stone Wall", "craft": Items.iname(Items.RECIPES[0].id), "arms": ArmsDB.GUNS.values()[0].name, "wear": WArms.WEAR.values()[0].name}
	for tab in finds:
		ui.open_inventory(tab)
		ui._search[tab] = fold_case(finds[tab])
		ui._redraw()
		if not _has_label(ui._body, finds[tab], true):
			fails.append("%s cannot find %s" % [tab, finds[tab]])
		ui._search[tab] = "zzqx"
		ui._redraw()
		if not _has_label(ui._body, "Nothing matches", true):
			fails.append(tab + " says nothing")
		ui._search[tab] = ""
		ui._redraw()
		ui.close_all()
	return "true" if fails.is_empty() else ", ".join(fails)


## A name as a player might type it: lower case, without its marks.
static func fold_case(t: String) -> String:
	return t.to_lower().left(maxi(4, t.length() - 2))


func _has_label(n: Node, text: String, prefix: bool) -> bool:
	for c in n.find_children("*", "Label", true, false):
		var t: String = (c as Label).text
		if (prefix and t.begins_with(text)) or (not prefix and t == text):
			return true
	return false


## Pictures of the crowded HUD, at the window's size: walking, then building; then (where the menus
## have them) the build guide with the building-up tip, and each list with a search typed.
func _shoot(out: String) -> void:
	for mode in ["walk", "build"]:
		fill(mode)
		for i in 4:
			await w.get_tree().process_frame
		fill(mode)
		for i in 3:
			await w.get_tree().process_frame
		var bad := overlaps(w.get_viewport().get_visible_rect())
		print("HUDSHOT %s %s overlaps=%d" % [mode, w.get_viewport().get_visible_rect().size, bad.size()])
		for b in bad:
			print("    ", b)
		_save(out + "_" + mode)
	if not ui.has_method("build_list"):
		return
	# The build guide on a timber wall, with the tip of its building-up box shown as it is drawn
	w.inv.add("stone", 5)
	ui.open_inventory("build")
	w.builder.sel = Items.PIECE_ORDER.find("wall")
	ui._bcat = "Frame"
	ui._redraw()
	await _frames(3)
	var boxes: Array = ui._body.find_children("*", "PanelContainer", true, false).filter(func(c): return c.get("bb") != null and str(c.tooltip_text) == "Build it up")
	if not boxes.is_empty():
		_show_tip(boxes[0])
	await _frames(3)
	_save(out + "_buildmenu_tip")
	_clear_tips()
	var cards: Array = ui._body.find_children("*", "PanelContainer", true, false).filter(func(c): return c.get("bb") != null and str(c.tooltip_text).begins_with("Timber Wall"))
	if not cards.is_empty():
		_show_tip(cards[0])
	await _frames(3)
	_save(out + "_buildmenu_card_tip")
	_clear_tips()
	for tab in ["build", "craft", "arms", "wear"]:
		ui.open_inventory(tab)
		ui._search[tab] = {"build": "stone", "craft": "band", "arms": "rifle", "wear": "hood"}[tab]
		ui._redraw()
		await _frames(3)
		_save(out + "_search_" + tab)
		ui._search[tab] = ""
	ui.close_all()


var _tips: Array = []


## A control's own tip, drawn beside it in the tip's frame (as it shows when the pointer rests on it).
func _show_tip(c: Control) -> void:
	var tip = c._make_custom_tooltip(c.tooltip_text)
	if tip == null:
		return
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", hud.root.theme.get_stylebox("panel", "TooltipPanel"))
	frame.add_child(tip)
	hud.root.add_child(frame)
	var r := c.get_global_rect()
	frame.position = Vector2(r.position.x + 24.0, r.end.y + 4.0)
	_tips.append(frame)
	await _frames(1)
	frame.position.x = minf(frame.position.x, w.get_viewport().get_visible_rect().size.x - frame.size.x - 8.0)
	frame.position.y = minf(frame.position.y, w.get_viewport().get_visible_rect().size.y - frame.size.y - 8.0)


func _clear_tips() -> void:
	for t in _tips:
		t.queue_free()
	_tips.clear()


func _frames(n: int) -> void:
	for i in n:
		await w.get_tree().process_frame


func _save(path: String) -> void:
	var img: Image = w.get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(path + ".jpg", 0.8)
	print("HUDSHOT saved ", path)
