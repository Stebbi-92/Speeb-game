class_name WEndings
extends RefCounted
## The two last ways off the road. Mother Ruth of the Unlit waits in a ruin of the Dead Forest: put out
## one beacon for her and, at the page, you may go down into the Mouth instead. And Brelm's journal lies
## torn across the waste in nine leaves: read them all, and the six leaves of the Tenth Page, and the
## hermit's own way is open at the page: the Second Vow, the same world again and harder.

const LEAVES := 9

var w
var ruth: WTownsfolk = null
var ruth_at := Vector3.INF


func _init(world) -> void:
	w = world


## Ruth's ruin: the first ruin of the Dead Forest, the same in every world of the same seed.
func find_ruth() -> Vector3:
	var best: Dictionary = {}
	for r in w.ruins:
		if r.has("isle") or r.kind == "vault":
			continue
		if w.terrain.biome_name(r.pos.x, r.pos.z) != "forest":
			continue
		if best.is_empty() or str(r.id) < str(best.id):
			best = r
	if best.is_empty():
		return Vector3.INF
	return Vector3(best.pos.x + 7.0, 0, best.pos.z + 5.0)


func build() -> void:
	ruth_at = find_ruth()
	if ruth_at == Vector3.INF or Net.dedicated:
		return
	ruth = WTownsfolk.new().setup(w, w.gpos(Vector2(ruth_at.x, ruth_at.z)), 2.0, 4711)
	ruth.on_talk = talk
	w.add_child(ruth)
	ruth.global_position = w.gpos(Vector2(ruth_at.x, ruth_at.z))
	var lbl: Label3D = w.label3d("Mother Ruth", ruth.global_position + Vector3(0, 2.3, 0), 0.5, Color(0.75, 0.7, 0.8), 0.0, true)
	lbl.visibility_range_end = 40.0
	lbl.reparent(ruth)


## What Ruth says, by how far the pilgrim has come.
func talk() -> String:
	if w.flags.has("ending"):
		return "It is done, one way or another. Sit, if you like."
	if w.flags.has("unlit_pact"):
		return "You put one out. I felt it. When you stand at the page, there is a stair down. Take it."
	if w.lit.is_empty():
		return "Light a fire first. Then come back, and I will ask you to put one out."
	w.shared("_w_flag", ["ruth_met"])
	return "Every fire you light, it has to look at. Put one out. Just one. Then at the page, come down to us."


## Ruth asked for it: the nearest burning beacon is put out. Returns the beacon, or -1.
func put_out_near() -> int:
	if not w.flags.has("ruth_met") or w.flags.has("unlit_pact"):
		return -1
	var best := -1
	for i in w.lit:
		if i == 8:
			continue
		if w.player.global_position.distance_to(w.beacon_nodes[i].pos) < 30.0:
			best = i
	if best >= 0:
		w.shared("_w_beacon_out", [best])
	return best


func leaves_read() -> int:
	var n := 0
	for k in LEAVES:
		if w.flags.has("jpage_%d" % (k + 1)):
			n += 1
	return n


## The next leaf of Brelm's journal not yet found, or "".
func next_leaf() -> String:
	for k in LEAVES:
		var id := "jpage_%d" % (k + 1)
		if not w.flags.has("found_" + id) and not w.flags.has(id):
			return id
	return ""


func can_pilgrim() -> bool:
	return leaves_read() >= LEAVES and w.hall != null and w.hall.pages_read() >= 6
