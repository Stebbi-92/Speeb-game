extends Level
## V. The Fields of Forgetting. A maze of grey grass where memory and time twist. Faint pawprints are the whispers of Speeb.

const N := 9
const CELL := 5.0

var walls := {}
var path: Array = []
var path_index := {}
var furthest := 0
var glitch_t := 3.0
var glitch_on := 0.0
var rifts: Array = []
var _name_t := 0.0


func build() -> void:
	numeral = "V"
	place = "The Fields of Forgetting"
	verse = "Fifth, he wandered the Fields of Forgetting, where Glitchspeeb twisted memory and time. For seven days he did not know his own name, nor his purpose, until the whispers of Speeb drew him back."
	setup_env(Color(0.5, 0.52, 0.55), Color(0.7, 0.71, 0.72), Color(0.4, 0.4, 0.4), Color(0.68, 0.69, 0.7), 0.06, 0.9)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	add_sun(Vector3(-50, 30, 0), Color(0.9, 0.9, 0.92), 0.8)
	box(Vector3(N * CELL * 0.5, -0.5, -N * CELL * 0.5), Vector3(200, 1, 200), mat(Color(0.36, 0.38, 0.33), 1.0, 0.4, 0.08))
	_generate()
	var hedge := mat(Color(0.42, 0.44, 0.38), 1.0, 0.5, 0.35)
	for key in walls:
		if not walls[key]:
			continue
		var parts: PackedStringArray = key.split(",")
		var x := int(parts[0])
		var z := int(parts[1])
		var horizontal := parts[2] == "h"
		var pos := Vector3(x * CELL, 1.6, -z * CELL)
		if horizontal:
			box(pos + Vector3(CELL * 0.5, 0, 0), Vector3(CELL + 0.8, 3.2, 0.8), hedge)
		else:
			box(pos + Vector3(0, 0, -CELL * 0.5), Vector3(0.8, 3.2, CELL + 0.8), hedge)
	# Pawprints along the true way
	var paw := glow_mat(Color(0.95, 0.95, 0.92), 0.6)
	for i in path.size() - 1:
		var a := _cell_center(path[i])
		var b := _cell_center(path[i + 1])
		var yaw := yaw_to(a, b)
		for t in [0.25, 0.75]:
			var side := (b - a).normalized().cross(Vector3.UP) * (0.25 if t < 0.5 else -0.25)
			veil(pawprint(a.lerp(b, t) + side, yaw, 0.32, paw))
	# Rifts in the dead ends: they return Brelm to the last place he remembers
	for x in N:
		for z in N:
			var c := Vector2i(x, z)
			if path_index.has(c) or _openings(c) != 1 or _rng.randf() > 0.6:
				continue
			var a := trigger_area(_cell_center(c) + Vector3(0, 1, 0), Vector3(2.5, 2, 2.5), _rift, false, false)
			rifts.append(a)
	# Scattered memories, half-remembered
	var props := mat(Color(0.5, 0.5, 0.52), 0.9, 0.3)
	for i in 14:
		var c := Vector2i(_rng.randi() % N, _rng.randi() % N)
		box(_cell_center(c) + Vector3(_rng.randf_range(-1.5, 1.5), 0.4, _rng.randf_range(-1.5, 1.5)), Vector3(0.6, 0.8, 0.6), props, true, Vector3(0, _rng.randf() * 90, 0))
	lesser("staticspeeb", _cell_center(Vector2i(4, 1)) + Vector3(1.4, 1.2, 0))
	lesser("fadespeeb", _cell_center(Vector2i(1, 6)) + Vector3(0, 1.2, 0))
	lesser("ghostspeeb", _cell_center(Vector2i(7, 3)) + Vector3(0, 1.2, 0))
	lesser("negaspeeb", _cell_center(Vector2i(6, 7)) + Vector3(0, 1.2, 0))
	trigger_area(_cell_center(Vector2i(N - 1, N - 1)) + Vector3(0, 1, 0), Vector3(3, 2, 3), _found_way)
	relic_pickup("censer", _cell_center(Vector2i(0, 0)) + Vector3(-1.4, 0.5, -1.4))
	ambient("glitchbed", -14)
	ambient("wind", -18)
	spawn_pos = _cell_center(Vector2i(0, 0)) + Vector3(0, 0.1, 0)
	spawn_yaw = yaw_to(_cell_center(path[0]), _cell_center(path[1]))


func _cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL + CELL * 0.5, 0, -(c.y * CELL + CELL * 0.5))


func _wkey(x: int, z: int, h: bool) -> String:
	return "%d,%d,%s" % [x, z, "h" if h else "v"]


## Recursive backtracker over the grid; the true way is found by breadth-first search.
func _generate() -> void:
	for x in N + 1:
		for z in N + 1:
			if x < N:
				walls[_wkey(x, z, true)] = true
			if z < N:
				walls[_wkey(x, z, false)] = true
	var r := RandomNumberGenerator.new()
	r.seed = 1205
	var seen := {Vector2i(0, 0): true}
	var stack := [Vector2i(0, 0)]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var opts := []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < N and n.y < N and not seen.has(n):
				opts.append(n)
		if opts.is_empty():
			stack.pop_back()
			continue
		var n: Vector2i = opts[r.randi() % opts.size()]
		walls[_between(c, n)] = false
		seen[n] = true
		stack.append(n)
	# Breadth-first search for the way out
	var prev := {Vector2i(0, 0): Vector2i(-1, -1)}
	var q := [Vector2i(0, 0)]
	var goal := Vector2i(N - 1, N - 1)
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == goal:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= N or n.y >= N or prev.has(n) or walls[_between(c, n)]:
				continue
			prev[n] = c
			q.append(n)
	var c := goal
	while c != Vector2i(-1, -1):
		path.push_front(c)
		c = prev[c]
	for i in path.size():
		path_index[path[i]] = i


func _between(a: Vector2i, b: Vector2i) -> String:
	if a.x != b.x:
		return _wkey(maxi(a.x, b.x), a.y, false)
	return _wkey(a.x, maxi(a.y, b.y), true)


func _openings(c: Vector2i) -> int:
	var n := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var o: Vector2i = c + d
		if o.x >= 0 and o.y >= 0 and o.x < N and o.y < N and not walls[_between(c, o)]:
			n += 1
	return n


func intro() -> void:
	hud.set_objective("Light the censer [5]. Its smoke shows the faint pawprints. Remember your name.")
	await super.intro()


func trial_tick(delta: float) -> void:
	var p := player.global_position
	var c := Vector2i(int(floor(p.x / CELL)), int(floor(-p.z / CELL)))
	if path_index.has(c) and path_index[c] > furthest:
		furthest = path_index[c]
	# The Riftwalker's touch comes and goes
	glitch_t -= delta
	if glitch_t <= 0.0:
		glitch_t = _rng.randf_range(5.0, 11.0)
		glitch_on = _rng.randf_range(0.4, 1.0)
		sfx("glitch", -10)
	if glitch_on > 0.0:
		glitch_on -= delta
		hud.set_fx("glitch", 1.0)
	else:
		hud.set_fx("glitch", 0.08)
	hud.set_fx("desat", 0.6)
	# His name returns to him as he nears the way out
	_name_t -= delta
	if _name_t <= 0.0:
		_name_t = 0.25
		var forget := 1.0 - float(furthest) / float(path.size() - 1)
		var name := "Brelm"
		var out := ""
		for ch in name:
			out += ch if _rng.randf() > forget * 0.9 else ["#", "?", "_", "/", "%", "*", "&"][_rng.randi() % 7]
		hud.name_label.text = out
		var day := clampi(int(float(furthest) / path.size() * 7.0) + 1, 1, 7)
		hud.set_objective("Day %d of forgetting. Follow the faint pawprints in the censer's smoke." % day)


func _rift() -> void:
	if completed or failing:
		return
	sfx("glitch", -2)
	hud.set_fx("glitch", 1.0)
	glitch_on = 0.8
	hud.say("The past unravelled. He stood again where he had stood before, and did not know how long ago.", 5.0)
	var back: Vector2i = path[maxi(0, furthest - 1)]
	player.place(_cell_center(back) + Vector3(0, 0.1, 0), yaw_to(_cell_center(back), _cell_center(path[mini(furthest, path.size() - 1)])))


func _found_way() -> void:
	Game.reveal_deed("censer")
	hud.set_fx("glitch", 0.0)
	hud.set_fx("desat", 0.0)
	hud.name_label.text = "Brelm"
	completed = true
	hud.say("And the whispers of Speeb drew him back.", 4.0)
	await get_tree().create_timer(4.5, false).timeout
	completed = false
	await survive("glitchspeeb", _cell_center(Vector2i(N - 1, N - 1)) + Vector3(0, 2.8, -1.0), "blink")
	reveal("glitchspeeb", _cell_center(Vector2i(N - 1, N - 1)) + Vector3(0, 2.8, -1.0), 3.0, false)
