class_name WGlyph
extends Control
## A small picture of a thing, on a dark tile with a rim of its colour. Things with a kit model show a
## picture rendered from it (assets/icons); the rest are drawn here from plain shapes.

var id := ""
var tile := true        ## draw the tile behind the picture
var dim := false        ## greyed, for what cannot be had or made here
var rim := Color(0, 0, 0, 0)   ## when set, the tile's rim takes this colour (a grade, a selection)


static func make(item: String, px := 40, with_tile := true) -> WGlyph:
	var g := WGlyph.new()
	g.id = item
	g.tile = with_tile
	g.custom_minimum_size = Vector2(px, px)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


var _s := 1.0
var _o := Vector2.ZERO
var _ink := Color.WHITE


## A point in the picture's own 0..1 square.
func P(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s


func _poly(pts: Array, c: Color) -> void:
	var v := PackedVector2Array()
	for p in pts:
		v.append(P(p[0], p[1]))
	draw_colored_polygon(v, c)


func _ln(a: Array, b: Array, c: Color, wdt := 0.06) -> void:
	draw_line(P(a[0], a[1]), P(b[0], b[1]), c, maxf(1.0, wdt * _s), true)


func _dot(x: float, y: float, r: float, c: Color) -> void:
	draw_circle(P(x, y), r * _s, c)


func _ring(x: float, y: float, r: float, c: Color, wdt := 0.05) -> void:
	draw_arc(P(x, y), r * _s, 0, TAU, 28, c, maxf(1.0, wdt * _s), true)


func _box(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(P(x, y), Vector2(w, h) * _s), c)


func _draw() -> void:
	var info: Dictionary = Items.info(id) if id != "" else {"color": Color.GRAY, "kind": "material"}
	var base: Color = info.color
	var side := minf(size.x, size.y)
	if tile:
		var r := Rect2(Vector2.ZERO, Vector2(side, side))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.085, 0.08, 0.95).lerp(base.darkened(0.6), 0.25)
		sb.border_color = rim if rim.a > 0.0 else Color(base.lightened(0.1), 0.55)
		sb.set_border_width_all(2 if rim.a > 0.0 else 1)
		sb.set_corner_radius_all(int(side * 0.14))
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 2
		draw_style_box(sb, r)
		# A soft light from above
		draw_rect(Rect2(Vector2(side * 0.12, side * 0.06), Vector2(side * 0.76, side * 0.05)), Color(1, 1, 1, 0.05))
	_s = side * (0.72 if tile else 0.96)
	_o = Vector2(side, side) * 0.5 - Vector2(_s, _s) * 0.5
	_ink = base.lightened(0.25)
	var a := 0.35 if dim else 1.0
	modulate.a = a
	var tex := icon(id)
	if tex:
		var k := 1.12 if tile else 1.0
		var sz := Vector2(_s, _s) * k
		draw_texture_rect(tex, Rect2(Vector2(side, side) * 0.5 - sz * 0.5, sz), false)
		return
	_picture(id, info, base)


static var _icons := {}


## A picture made from the thing's own 3D model (tools/icons.gd renders them), when there is one.
static func icon(item: String) -> Texture2D:
	if not _icons.has(item):
		var path := "res://assets/icons/%s.png" % item
		_icons[item] = load(path) if Items.MODELS.has(item) and ResourceLoader.exists(path) else null
	return _icons[item]


func _picture(item: String, info: Dictionary, c: Color) -> void:
	var lt := c.lightened(0.35)
	var dk := c.darkened(0.45)
	var steel := Color(0.72, 0.73, 0.75)
	var wood := Color(0.55, 0.38, 0.24)
	var paper := Color(0.9, 0.86, 0.76)
	match item:
		"wood":
			for i in 2:
				var y := 0.38 + i * 0.26
				_box(0.12, y - 0.1, 0.7, 0.2, wood.darkened(0.1 * i))
				_dot(0.82, y, 0.1, Color(0.72, 0.56, 0.38))
				_ring(0.82, y, 0.05, wood.darkened(0.3), 0.025)
		"stone":
			_poly([[0.15, 0.7], [0.25, 0.35], [0.5, 0.22], [0.78, 0.32], [0.88, 0.65], [0.6, 0.82], [0.3, 0.82]], Color(0.55, 0.53, 0.5))
			_poly([[0.25, 0.35], [0.5, 0.22], [0.55, 0.45], [0.35, 0.5]], Color(0.68, 0.66, 0.62))
		"scrap":
			_dot(0.5, 0.5, 0.3, Color(0.55, 0.38, 0.28))
			for i in 8:
				var ang := i * TAU / 8.0
				_ln([0.5 + cos(ang) * 0.28, 0.5 + sin(ang) * 0.28], [0.5 + cos(ang) * 0.4, 0.5 + sin(ang) * 0.4], Color(0.55, 0.38, 0.28), 0.12)
			_dot(0.5, 0.5, 0.11, Color(0.1, 0.09, 0.08))
		"salt":
			_poly([[0.5, 0.12], [0.75, 0.42], [0.62, 0.86], [0.38, 0.86], [0.25, 0.42]], Color(0.92, 0.92, 0.9))
			_poly([[0.5, 0.12], [0.75, 0.42], [0.5, 0.5]], Color(1, 1, 1))
			_poly([[0.25, 0.42], [0.38, 0.86], [0.5, 0.5]], Color(0.78, 0.78, 0.76))
		"cloth", "hide":
			_poly([[0.15, 0.3], [0.85, 0.22], [0.82, 0.78], [0.18, 0.82]], c)
			_ln([0.2, 0.5], [0.8, 0.45], dk, 0.04)
			_ln([0.22, 0.65], [0.78, 0.6], dk, 0.04)
		"herb", "herb_seed":
			_ln([0.5, 0.9], [0.5, 0.45], Color(0.4, 0.55, 0.3), 0.06)
			for sx in [-1, 1]:
				_poly([[0.5, 0.62], [0.5 + sx * 0.3, 0.5], [0.5 + sx * 0.12, 0.72]], Color(0.45, 0.62, 0.36))
			for i in 5:
				var ang := i * TAU / 5.0 - PI / 2
				_dot(0.5 + cos(ang) * 0.13, 0.32 + sin(ang) * 0.13, 0.09, Color(0.88, 0.88, 0.8))
			_dot(0.5, 0.32, 0.06, Color(0.95, 0.8, 0.4))
			if item == "herb_seed":
				_seeds(Color(0.65, 0.7, 0.58))
		"bone":
			_ln([0.25, 0.75], [0.75, 0.25], Color(0.88, 0.85, 0.76), 0.14)
			for p in [[0.2, 0.7], [0.3, 0.8], [0.7, 0.2], [0.8, 0.3]]:
				_dot(p[0], p[1], 0.1, Color(0.88, 0.85, 0.76))
		"oil", "beacon_oil":
			_flask(c, item == "beacon_oil")
		"raw_meat", "roast", "meat", "pie":
			_poly([[0.2, 0.5], [0.35, 0.25], [0.65, 0.2], [0.8, 0.4], [0.7, 0.7], [0.4, 0.78]], c)
			_poly([[0.35, 0.32], [0.6, 0.28], [0.68, 0.42], [0.45, 0.5]], c.lightened(0.2))
			_ln([0.62, 0.68], [0.82, 0.86], Color(0.9, 0.86, 0.76), 0.08)
			_dot(0.85, 0.88, 0.06, Color(0.9, 0.86, 0.76))
		"tuber", "tuber_seed":
			_poly([[0.22, 0.55], [0.35, 0.3], [0.65, 0.28], [0.8, 0.5], [0.68, 0.76], [0.35, 0.78]], c)
			for p in [[0.42, 0.45], [0.6, 0.55], [0.45, 0.65]]:
				_dot(p[0], p[1], 0.03, dk)
			_ln([0.5, 0.3], [0.45, 0.14], Color(0.45, 0.6, 0.35), 0.05)
			if item == "tuber_seed":
				_seeds(lt)
		"stew", "broth", "tea":
			_poly([[0.12, 0.45], [0.88, 0.45], [0.75, 0.82], [0.25, 0.82]], Color(0.42, 0.3, 0.22))
			_box(0.12, 0.42, 0.76, 0.07, c.lightened(0.15))
			for i in 3:
				_ln([0.35 + i * 0.15, 0.36], [0.38 + i * 0.15, 0.15], Color(1, 1, 1, 0.35), 0.04)
		"torchwood":
			_ln([0.35, 0.88], [0.6, 0.38], wood, 0.1)
			_poly([[0.52, 0.42], [0.58, 0.1], [0.75, 0.3], [0.72, 0.45]], Color(1.0, 0.65, 0.2))
			_poly([[0.58, 0.4], [0.62, 0.22], [0.7, 0.35]], Color(1.0, 0.9, 0.5))
		"milk":
			_poly([[0.14, 0.48], [0.86, 0.48], [0.72, 0.8], [0.28, 0.8]], Color(0.75, 0.62, 0.48))
			_box(0.14, 0.44, 0.72, 0.07, Color(0.97, 0.96, 0.92))
		"bandage":
			_poly([[0.2, 0.32], [0.68, 0.2], [0.8, 0.68], [0.32, 0.8]], Color(0.9, 0.87, 0.8))
			_box(0.44, 0.3, 0.12, 0.4, Color(0.75, 0.2, 0.18))
			_box(0.3, 0.44, 0.4, 0.12, Color(0.75, 0.2, 0.18))
		"salve":
			_dot(0.5, 0.58, 0.3, Color(0.4, 0.42, 0.38))
			_dot(0.5, 0.55, 0.24, Color(0.62, 0.72, 0.5))
			_box(0.24, 0.3, 0.52, 0.1, Color(0.3, 0.3, 0.28))
		"salts":
			_flask(Color(0.85, 0.85, 0.95), false)
			_dot(0.5, 0.62, 0.05, Color(1, 1, 1))
		"shells":
			for i in 3:
				var x := 0.24 + i * 0.22
				_box(x, 0.28, 0.16, 0.42, Color(0.75, 0.2, 0.15))
				_box(x, 0.66, 0.16, 0.14, Color(0.78, 0.62, 0.32))
		"rounds", "rifle":
			var n := 3 if item == "rounds" else 2
			for i in n:
				var x := 0.3 + i * (0.2 if n == 3 else 0.26)
				var top := 0.36 if item == "rounds" else 0.18
				_box(x - 0.07, top + 0.1, 0.14, 0.82 - top - 0.1, Color(0.78, 0.62, 0.32))
				_poly([[x - 0.07, top + 0.1], [x + 0.07, top + 0.1], [x, top - 0.02]], Color(0.65, 0.45, 0.3))
		"rockets":
			_poly([[0.5, 0.08], [0.62, 0.3], [0.62, 0.75], [0.38, 0.75], [0.38, 0.3]], Color(0.45, 0.48, 0.38))
			_poly([[0.38, 0.62], [0.24, 0.85], [0.38, 0.78]], Color(0.3, 0.3, 0.28))
			_poly([[0.62, 0.62], [0.76, 0.85], [0.62, 0.78]], Color(0.3, 0.3, 0.28))
			_box(0.38, 0.32, 0.24, 0.06, Color(0.75, 0.2, 0.15))
		"pick":
			_ln([0.3, 0.88], [0.62, 0.3], wood, 0.09)
			draw_arc(P(0.58, 0.45), 0.36 * _s, -PI * 0.95, -PI * 0.12, 16, steel, 0.09 * _s, true)
		"hatchet":
			_ln([0.32, 0.9], [0.6, 0.2], wood, 0.09)
			_poly([[0.5, 0.2], [0.82, 0.12], [0.86, 0.45], [0.56, 0.36]], steel)
		"prybar":
			_ln([0.25, 0.85], [0.7, 0.2], steel, 0.08)
			draw_arc(P(0.62, 0.2), 0.1 * _s, -PI, 0.3, 10, steel, 0.08 * _s, true)
		"coin", "order_seal":
			_dot(0.5, 0.5, 0.33, Color(0.82, 0.68, 0.32))
			_ring(0.5, 0.5, 0.25, Color(0.6, 0.46, 0.18), 0.04)
			_poly([[0.5, 0.33], [0.62, 0.5], [0.5, 0.67], [0.38, 0.5]], Color(0.6, 0.46, 0.18))
		"icon":
			_box(0.25, 0.15, 0.5, 0.7, Color(0.62, 0.45, 0.2))
			_box(0.3, 0.2, 0.4, 0.6, Color(0.3, 0.2, 0.15))
			_dot(0.5, 0.4, 0.1, Color(0.9, 0.75, 0.4))
			_poly([[0.36, 0.75], [0.5, 0.5], [0.64, 0.75]], Color(0.55, 0.25, 0.2))
		"bell":
			_poly([[0.5, 0.15], [0.68, 0.3], [0.72, 0.65], [0.85, 0.75], [0.15, 0.75], [0.28, 0.65], [0.32, 0.3]], Color(0.85, 0.86, 0.88))
			_dot(0.5, 0.82, 0.07, Color(0.6, 0.6, 0.62))
		"ledger", "letter":
			_box(0.2, 0.18, 0.6, 0.66, paper if item == "letter" else Color(0.45, 0.3, 0.2))
			if item == "ledger":
				_box(0.25, 0.22, 0.5, 0.58, paper)
			for i in 4:
				_ln([0.3, 0.32 + i * 0.12], [0.7, 0.32 + i * 0.12], Color(0.35, 0.3, 0.25), 0.03)
			if item == "letter":
				_dot(0.5, 0.72, 0.09, Color(0.7, 0.15, 0.12))
		"goods":
			_box(0.18, 0.35, 0.64, 0.48, Color(0.6, 0.48, 0.32))
			_ln([0.5, 0.35], [0.5, 0.83], Color(0.35, 0.25, 0.15), 0.05)
			_ln([0.18, 0.55], [0.82, 0.55], Color(0.35, 0.25, 0.15), 0.05)
			_poly([[0.35, 0.35], [0.5, 0.2], [0.65, 0.35]], Color(0.35, 0.25, 0.15))
		"keepsake", "piet_ring":
			_ring(0.5, 0.58, 0.24, Color(0.85, 0.7, 0.35), 0.09)
			_poly([[0.5, 0.18], [0.62, 0.32], [0.5, 0.42], [0.38, 0.32]], Color(0.6, 0.8, 0.9))
		"fittings_fine", "fittings_rare", "fittings_storied":
			_dot(0.38, 0.42, 0.2, c)
			_dot(0.38, 0.42, 0.08, Color(0.1, 0.1, 0.1))
			for i in 6:
				var ang := i * TAU / 6.0
				_ln([0.38 + cos(ang) * 0.18, 0.42 + sin(ang) * 0.18], [0.38 + cos(ang) * 0.27, 0.42 + sin(ang) * 0.27], c, 0.08)
			_ln([0.55, 0.78], [0.85, 0.48], steel, 0.06)
			_ln([0.6, 0.85], [0.88, 0.62], steel, 0.04)
		"shotgun", "machine_gun", "sniper", "pistol", "revolver", "rocket", "minigun", "flamer":
			_gun(item)
		"knife":
			_ln([0.3, 0.82], [0.44, 0.66], wood, 0.1)
			_poly([[0.42, 0.66], [0.74, 0.28], [0.78, 0.34], [0.48, 0.7]], steel)
		"sword":
			_ln([0.18, 0.92], [0.3, 0.78], wood, 0.08)
			_ln([0.2, 0.7], [0.4, 0.88], steel, 0.06)
			_poly([[0.29, 0.77], [0.86, 0.1], [0.9, 0.14], [0.33, 0.81]], steel)
		"glaive":
			_ln([0.18, 0.95], [0.66, 0.3], wood, 0.07)
			_poly([[0.62, 0.34], [0.86, 0.04], [0.8, 0.3], [0.68, 0.4]], Color(0.2, 0.18, 0.24))
		"battle_axe":
			_ln([0.22, 0.92], [0.7, 0.14], wood, 0.08)
			_poly([[0.58, 0.3], [0.78, 0.12], [0.92, 0.38], [0.74, 0.5]], Color(0.55, 0.55, 0.58))
			_poly([[0.58, 0.3], [0.48, 0.2], [0.6, 0.14]], Color(0.55, 0.55, 0.58))
		"fuel":
			_box(0.3, 0.3, 0.4, 0.55, Color(0.55, 0.22, 0.12))
			_box(0.42, 0.2, 0.16, 0.1, Color(0.3, 0.3, 0.32))
			_box(0.34, 0.52, 0.32, 0.08, Color(0.85, 0.65, 0.25))
		"machete":
			_ln([0.25, 0.85], [0.38, 0.68], wood, 0.1)
			_poly([[0.36, 0.7], [0.82, 0.12], [0.88, 0.2], [0.42, 0.74]], steel)
		"sledge":
			_ln([0.3, 0.9], [0.62, 0.3], wood, 0.08)
			_poly([[0.45, 0.25], [0.7, 0.1], [0.85, 0.35], [0.6, 0.5]], Color(0.5, 0.5, 0.52))
		"frag", "incendiary":
			_dot(0.5, 0.58, 0.28, Color(0.35, 0.4, 0.3) if item == "frag" else Color(0.6, 0.3, 0.15))
			_box(0.42, 0.18, 0.16, 0.16, Color(0.6, 0.6, 0.62))
			_ring(0.68, 0.22, 0.08, Color(0.75, 0.75, 0.78), 0.03)
			if item == "incendiary":
				_poly([[0.42, 0.6], [0.5, 0.42], [0.58, 0.6], [0.5, 0.7]], Color(1.0, 0.7, 0.25))
		"bandages":
			_picture("bandage", info, c)
		"flare":
			_box(0.4, 0.35, 0.2, 0.55, Color(0.75, 0.2, 0.15))
			_poly([[0.4, 0.35], [0.5, 0.1], [0.6, 0.35]], Color(1.0, 0.45, 0.3))
			_dot(0.5, 0.2, 0.08, Color(1, 0.9, 0.7))
		"mine":
			_poly([[0.12, 0.7], [0.25, 0.48], [0.75, 0.48], [0.88, 0.7]], Color(0.4, 0.42, 0.36))
			_box(0.44, 0.38, 0.12, 0.1, Color(0.75, 0.2, 0.15))
		"claw":
			_ln([0.5, 0.9], [0.5, 0.45], Color(0.5, 0.42, 0.32), 0.05)
			for sx in [-1, 0, 1]:
				draw_arc(P(0.5 + sx * 0.14, 0.32), 0.14 * _s, PI * 0.6 if sx < 0 else (PI * 1.1 if sx == 0 else PI * 1.6), PI * 1.4 if sx < 0 else (PI * 1.9 if sx == 0 else PI * 2.4), 10, steel, 0.06 * _s, true)
		"raft":
			for i in 5:
				_box(0.14 + i * 0.15, 0.45, 0.12, 0.38, Color(0.5, 0.38, 0.26).darkened(0.1 * (i % 2)))
			_box(0.1, 0.52, 0.8, 0.05, Color(0.3, 0.22, 0.15))
			_box(0.1, 0.72, 0.8, 0.05, Color(0.3, 0.22, 0.15))
			_ln([0.8, 0.15], [0.55, 0.6], Color(0.35, 0.26, 0.18), 0.05)
		"longboat":
			_poly([[0.05, 0.66], [0.95, 0.66], [0.84, 0.82], [0.16, 0.82]], Color(0.33, 0.24, 0.17))
			_ln([0.5, 0.18], [0.5, 0.66], Color(0.3, 0.22, 0.15), 0.05)
			_poly([[0.53, 0.2], [0.8, 0.6], [0.53, 0.6]], Color(0.82, 0.78, 0.68))
			for i in 4:
				_ln([0.22 + i * 0.17, 0.74], [0.14 + i * 0.17, 0.92], Color(0.3, 0.22, 0.15), 0.03)
		"sloop":
			_poly([[0.1, 0.68], [0.9, 0.68], [0.78, 0.86], [0.2, 0.86]], Color(0.35, 0.25, 0.18))
			_ln([0.5, 0.1], [0.5, 0.68], Color(0.3, 0.22, 0.15), 0.05)
			_poly([[0.53, 0.14], [0.85, 0.6], [0.53, 0.6]], Color(0.82, 0.78, 0.68))
			_poly([[0.47, 0.22], [0.2, 0.6], [0.47, 0.6]], Color(0.72, 0.68, 0.6))
		"tempered":
			_poly([[0.15, 0.55], [0.7, 0.4], [0.85, 0.55], [0.3, 0.7]], c)
			_poly([[0.15, 0.55], [0.7, 0.4], [0.72, 0.46], [0.2, 0.6]], c.lightened(0.35))
		"clockwork":
			_ring(0.5, 0.5, 0.28, c, 0.08)
			for i in 8:
				var an := i * TAU / 8.0
				_dot(0.5 + cos(an) * 0.34, 0.5 + sin(an) * 0.34, 0.06, c)
			_dot(0.5, 0.5, 0.07, c.darkened(0.3))
		"feast":
			_poly([[0.12, 0.6], [0.88, 0.6], [0.75, 0.82], [0.25, 0.82]], Color(0.55, 0.42, 0.3))
			_dot(0.38, 0.5, 0.15, c)
			_dot(0.6, 0.48, 0.13, c.lightened(0.2))
			_dot(0.5, 0.42, 0.1, Color(0.5, 0.65, 0.3))
		"elixir":
			_box(0.44, 0.1, 0.12, 0.16, Color(0.45, 0.32, 0.2))
			_poly([[0.44, 0.26], [0.56, 0.26], [0.56, 0.4], [0.76, 0.6], [0.7, 0.88], [0.3, 0.88], [0.24, 0.6], [0.44, 0.4]], Color(0.75, 0.85, 0.8, 0.5))
			_poly([[0.27, 0.6], [0.73, 0.6], [0.69, 0.86], [0.31, 0.86]], c)
		"censer":
			_ln([0.5, 0.08], [0.5, 0.3], Color(0.6, 0.6, 0.6), 0.03)
			_poly([[0.3, 0.35], [0.7, 0.35], [0.64, 0.7], [0.36, 0.7]], Color(0.75, 0.6, 0.3))
			for i in 3:
				_dot(0.42 + i * 0.08, 0.8 + (i % 2) * 0.06, 0.05, Color(0.85, 0.85, 0.85, 0.5))
		"red_dot", "scope", "foregrip", "suppressor", "ext_mag":
			_part(item)
		_:
			if item.begins_with("brew_"):
				# A stoppered flask of the draught's colour
				_box(0.44, 0.12, 0.12, 0.2, wood)
				_poly([[0.42, 0.3], [0.58, 0.3], [0.8, 0.62], [0.74, 0.88], [0.26, 0.88], [0.2, 0.62]], Color(0.75, 0.8, 0.78, 0.5))
				_poly([[0.26, 0.58], [0.74, 0.58], [0.78, 0.66], [0.72, 0.86], [0.28, 0.86], [0.22, 0.66]], c)
			elif item.begins_with("spirit_"):
				# A cat's skull-charm, glowing in the spirit's colour
				_ring(0.5, 0.52, 0.36, Color(c, 0.45), 0.05)
				_poly([[0.28, 0.38], [0.34, 0.16], [0.44, 0.32], [0.56, 0.32], [0.66, 0.16], [0.72, 0.38], [0.66, 0.72], [0.34, 0.72]], c)
				_dot(0.41, 0.48, 0.05, Color(0.1, 0.1, 0.15))
				_dot(0.59, 0.48, 0.05, Color(0.1, 0.1, 0.15))
				_poly([[0.46, 0.6], [0.54, 0.6], [0.5, 0.65]], Color(0.1, 0.1, 0.15))
			elif item.begins_with("pc_"):
				_piece(item.substr(3))
			elif item.begins_with("t_"):
				# A trophy of a great one: a shard of its land's colour
				_poly([[0.5, 0.1], [0.75, 0.45], [0.55, 0.9], [0.3, 0.55]], c)
				_poly([[0.5, 0.1], [0.75, 0.45], [0.52, 0.5]], c.lightened(0.35))
				_ring(0.5, 0.5, 0.42, Color(c, 0.4), 0.03)
			elif item.begins_with("book_") or item.begins_with("jpage_"):
				# A lost book: a worn cover, its spine, and the edge of its pages
				_poly([[0.22, 0.14], [0.78, 0.14], [0.78, 0.86], [0.22, 0.86]], c)
				_box(0.22, 0.14, 0.08, 0.72, c.darkened(0.35))
				_box(0.74, 0.18, 0.04, 0.64, Color(0.86, 0.82, 0.7))
				_ring(0.52, 0.45, 0.12, Color(0.9, 0.78, 0.4, 0.8), 0.03)
			elif WArms.WEAR.has(item):
				_wear(WArms.WEAR[item].slot, c)
			else:
				_dot(0.5, 0.5, 0.28, c)


func _seeds(c: Color) -> void:
	for p in [[0.2, 0.85], [0.3, 0.9], [0.8, 0.86]]:
		_dot(p[0], p[1], 0.05, c)


func _flask(c: Color, glow: bool) -> void:
	_box(0.42, 0.1, 0.16, 0.16, Color(0.45, 0.32, 0.2))
	_poly([[0.42, 0.26], [0.58, 0.26], [0.82, 0.62], [0.72, 0.88], [0.28, 0.88], [0.18, 0.62]], Color(0.75, 0.8, 0.82, 0.45))
	_poly([[0.25, 0.6], [0.75, 0.6], [0.7, 0.85], [0.3, 0.85]], c)
	if glow:
		_dot(0.5, 0.7, 0.08, Color(1, 1, 0.9))


func _wear(slot: String, c: Color) -> void:
	var cl := Color(0.55, 0.48, 0.4)
	match slot:
		"head":
			draw_arc(P(0.5, 0.62), 0.3 * _s, PI, TAU, 18, cl, 0.18 * _s, true)
			_box(0.12, 0.62, 0.76, 0.08, cl.darkened(0.2))
		"body":
			_poly([[0.3, 0.18], [0.7, 0.18], [0.88, 0.38], [0.76, 0.46], [0.72, 0.88], [0.28, 0.88], [0.24, 0.46], [0.12, 0.38]], cl)
			_poly([[0.42, 0.18], [0.58, 0.18], [0.5, 0.32]], cl.darkened(0.4))
		"feet":
			_poly([[0.3, 0.2], [0.5, 0.2], [0.5, 0.65], [0.85, 0.7], [0.85, 0.85], [0.3, 0.85]], cl)
		"eyes":
			_box(0.08, 0.44, 0.84, 0.08, cl.darkened(0.3))
			_dot(0.32, 0.48, 0.16, Color(0.78, 0.58, 0.32))
			_dot(0.68, 0.48, 0.16, Color(0.78, 0.58, 0.32))
			_dot(0.28, 0.44, 0.05, Color(1, 1, 1, 0.5))
			_dot(0.64, 0.44, 0.05, Color(1, 1, 1, 0.5))
		"face":
			_poly([[0.22, 0.3], [0.78, 0.3], [0.82, 0.58], [0.5, 0.8], [0.18, 0.58]], cl.darkened(0.15))
			_dot(0.36, 0.44, 0.08, Color(0.6, 0.66, 0.62))
			_dot(0.64, 0.44, 0.08, Color(0.6, 0.66, 0.62))
			_dot(0.5, 0.74, 0.12, cl.darkened(0.5))
		"neck":
			_poly([[0.15, 0.3], [0.85, 0.3], [0.8, 0.5], [0.2, 0.5]], cl)
			_poly([[0.55, 0.45], [0.72, 0.45], [0.68, 0.88], [0.52, 0.85]], cl.darkened(0.2))
		"cloak":
			_poly([[0.38, 0.14], [0.62, 0.14], [0.86, 0.88], [0.14, 0.88]], Color(0.5, 0.2, 0.15) if c.r > 0.5 else cl)
			_box(0.36, 0.14, 0.28, 0.07, cl.darkened(0.4))
		"hands":
			_poly([[0.3, 0.85], [0.3, 0.4], [0.38, 0.22], [0.46, 0.4], [0.5, 0.18], [0.58, 0.4], [0.64, 0.24], [0.7, 0.42], [0.82, 0.5], [0.72, 0.85]], cl)


func _gun(g: String) -> void:
	var dark := Color(0.42, 0.43, 0.46)
	var steel := Color(0.75, 0.77, 0.8)
	var wood := Color(0.66, 0.44, 0.26)
	var olive := Color(0.5, 0.56, 0.4)
	match g:
		"shotgun":
			_poly([[0.05, 0.42], [0.62, 0.42], [0.62, 0.5], [0.05, 0.5]], steel)
			_box(0.24, 0.5, 0.2, 0.07, wood)
			_poly([[0.6, 0.4], [0.72, 0.4], [0.95, 0.5], [0.92, 0.68], [0.72, 0.56], [0.6, 0.56]], wood)
		"machine_gun":
			_box(0.05, 0.4, 0.55, 0.08, dark)
			_box(0.25, 0.48, 0.12, 0.22, dark)
			_box(0.55, 0.36, 0.2, 0.16, olive)
			_poly([[0.75, 0.38], [0.95, 0.4], [0.95, 0.58], [0.75, 0.52]], olive)
		"sniper":
			_box(0.02, 0.46, 0.62, 0.05, dark)
			_box(0.38, 0.32, 0.28, 0.08, dark)
			_poly([[0.3, 0.5], [0.66, 0.48], [0.98, 0.52], [0.95, 0.68], [0.66, 0.58], [0.3, 0.56]], wood)
		"pistol":
			_box(0.22, 0.32, 0.56, 0.14, dark)
			_poly([[0.52, 0.46], [0.72, 0.46], [0.78, 0.78], [0.58, 0.78]], wood)
		"revolver":
			_box(0.12, 0.36, 0.4, 0.08, steel)
			_dot(0.56, 0.42, 0.11, steel)
			_poly([[0.58, 0.46], [0.76, 0.46], [0.84, 0.78], [0.64, 0.78]], wood)
		"rocket":
			_box(0.05, 0.38, 0.9, 0.16, olive)
			_box(0.3, 0.54, 0.08, 0.16, dark)
			_poly([[0.0, 0.36], [0.12, 0.36], [0.12, 0.56], [0.0, 0.56]], Color(0.45, 0.42, 0.36))
		"flamer":
			_box(0.08, 0.42, 0.62, 0.08, steel)
			_box(0.5, 0.5, 0.28, 0.22, Color(0.55, 0.22, 0.12))
			_box(0.7, 0.46, 0.08, 0.26, dark)
			_dot(0.08, 0.46, 0.06, Color(1.0, 0.6, 0.2))
		"minigun":
			for i in 3:
				_box(0.05, 0.38 + i * 0.06, 0.5, 0.04, steel)
			_box(0.5, 0.32, 0.3, 0.3, dark)
			_box(0.8, 0.5, 0.08, 0.2, dark)


func _part(m: String) -> void:
	var dark := Color(0.5, 0.51, 0.54)
	match m:
		"red_dot":
			_box(0.25, 0.55, 0.5, 0.12, dark)
			_ring(0.5, 0.42, 0.18, dark, 0.07)
			_dot(0.5, 0.42, 0.05, Color(1, 0.2, 0.15))
		"scope":
			_box(0.15, 0.4, 0.7, 0.16, dark)
			_box(0.08, 0.36, 0.12, 0.24, dark)
			_box(0.8, 0.36, 0.12, 0.24, dark)
			_box(0.35, 0.56, 0.06, 0.12, dark)
			_box(0.6, 0.56, 0.06, 0.12, dark)
		"foregrip":
			_box(0.2, 0.25, 0.6, 0.1, dark)
			_poly([[0.42, 0.35], [0.6, 0.35], [0.58, 0.85], [0.44, 0.85]], dark)
		"suppressor":
			_box(0.1, 0.38, 0.8, 0.22, dark)
			for i in 4:
				_box(0.2 + i * 0.16, 0.38, 0.02, 0.22, Color(0.4, 0.4, 0.42))
		"ext_mag":
			_poly([[0.38, 0.1], [0.62, 0.1], [0.7, 0.9], [0.46, 0.9]], dark)
			for i in 4:
				_box(0.44, 0.2 + i * 0.16, 0.18, 0.03, Color(0.78, 0.62, 0.32))


func _piece(k: String) -> void:
	var wood := Color(0.55, 0.38, 0.24)
	var stone := Color(0.55, 0.53, 0.5)
	var cloth := Color(0.6, 0.55, 0.45)
	match k:
		"floor":
			_poly([[0.05, 0.6], [0.5, 0.38], [0.95, 0.6], [0.5, 0.82]], wood)
			_ln([0.27, 0.49], [0.72, 0.71], wood.darkened(0.3), 0.02)
		"wall", "window", "doorway", "stonewall", "palisade":
			var c := stone if k == "stonewall" else wood
			_box(0.15, 0.18, 0.7, 0.66, c)
			for i in 3:
				_ln([0.15, 0.36 + i * 0.16], [0.85, 0.36 + i * 0.16], c.darkened(0.3), 0.02)
			if k == "window":
				_box(0.38, 0.32, 0.24, 0.2, Color(0.15, 0.2, 0.25))
			elif k == "doorway":
				_box(0.38, 0.44, 0.24, 0.4, Color(0.08, 0.08, 0.08))
			elif k == "palisade":
				for i in 5:
					_poly([[0.15 + i * 0.14, 0.18], [0.22 + i * 0.14, 0.06], [0.29 + i * 0.14, 0.18]], c)
		"door":
			_box(0.3, 0.12, 0.4, 0.76, wood)
			_dot(0.62, 0.52, 0.04, Color(0.75, 0.62, 0.3))
		"roof":
			_poly([[0.05, 0.7], [0.5, 0.2], [0.95, 0.7]], wood.darkened(0.15))
			_box(0.05, 0.7, 0.9, 0.06, wood.darkened(0.35))
		"stairs":
			for i in 4:
				_box(0.15 + i * 0.175, 0.75 - i * 0.18, 0.175, 0.13 + i * 0.18, wood.darkened(0.06 * i))
		"campfire":
			_ln([0.2, 0.82], [0.8, 0.7], wood, 0.07)
			_ln([0.2, 0.7], [0.8, 0.82], wood, 0.07)
			_poly([[0.3, 0.72], [0.45, 0.25], [0.55, 0.45], [0.62, 0.2], [0.72, 0.72]], Color(1.0, 0.6, 0.2))
			_poly([[0.42, 0.72], [0.5, 0.42], [0.6, 0.72]], Color(1.0, 0.88, 0.45))
		"cookpot", "stove":
			_ln([0.2, 0.2], [0.2, 0.85], Color(0.4, 0.4, 0.42), 0.04)
			_ln([0.8, 0.2], [0.8, 0.85], Color(0.4, 0.4, 0.42), 0.04)
			_ln([0.18, 0.22], [0.82, 0.22], Color(0.4, 0.4, 0.42), 0.04)
			_poly([[0.3, 0.4], [0.7, 0.4], [0.65, 0.7], [0.35, 0.7]], Color(0.25, 0.25, 0.27))
		"torch", "lamp":
			_picture("torchwood" if k == "torch" else "oil", {}, Color(0.75, 0.55, 0.2))
		"bedroll", "bed":
			_poly([[0.08, 0.62], [0.92, 0.52], [0.92, 0.7], [0.08, 0.8]], cloth)
			_dot(0.2, 0.66, 0.1, cloth.lightened(0.2))
		"chest":
			_box(0.15, 0.4, 0.7, 0.42, wood)
			_box(0.15, 0.28, 0.7, 0.14, wood.lightened(0.1))
			_box(0.45, 0.42, 0.1, 0.1, Color(0.75, 0.62, 0.3))
		"bench":
			_box(0.08, 0.38, 0.84, 0.1, wood)
			_box(0.14, 0.48, 0.07, 0.4, wood.darkened(0.2))
			_box(0.79, 0.48, 0.07, 0.4, wood.darkened(0.2))
			_ln([0.4, 0.35], [0.6, 0.15], Color(0.6, 0.62, 0.64), 0.05)
		"planter":
			_box(0.12, 0.55, 0.76, 0.3, wood)
			for i in 3:
				_ln([0.3 + i * 0.2, 0.55], [0.3 + i * 0.2, 0.3], Color(0.45, 0.62, 0.36), 0.05)
				_dot(0.3 + i * 0.2, 0.28, 0.06, Color(0.5, 0.7, 0.4))
		"portal":
			_poly([[0.3, 0.9], [0.35, 0.2], [0.5, 0.08], [0.65, 0.2], [0.7, 0.9]], stone)
			_dot(0.5, 0.4, 0.08, Color(0.6, 0.85, 1.0))
		"shrine":
			_box(0.15, 0.6, 0.7, 0.26, stone)
			_poly([[0.42, 0.6], [0.45, 0.12], [0.5, 0.06], [0.55, 0.12], [0.58, 0.6]], stone.darkened(0.2))
			_dot(0.5, 0.52, 0.08, Color(1.0, 0.7, 0.35))
		"spikes":
			for i in 3:
				_ln([0.15 + i * 0.3, 0.85], [0.3 + i * 0.25, 0.2], wood, 0.07)
			_ln([0.1, 0.65], [0.9, 0.65], wood.darkened(0.3), 0.06)
		_:
			_dot(0.5, 0.5, 0.25, wood)
