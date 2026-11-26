class_name Stride
extends RefCounted
## How fast a body's walk (or run) carries it over the ground when played at its own speed, measured from the
## clip itself: while a foot bears the weight it moves back under the body exactly as fast as the body goes
## forward. Played at pace / Stride.of(...), the feet stay where they are set down and do not skate. Measured
## once for each clip and rig (the clip is sampled on the body's own player, which is then put back as it was).

static var _cache := {}   ## "<clip's id>:<rig>" -> speed in the skeleton's own units a second (0 if it does not walk)
static var _feet := {}    ## rig -> its foot bones
static var _back := {}    ## "<clip's id>:<rig>" -> the way its planted feet go, in the skeleton's space


## Metres a second the clip covers at speed 1 on this body as it stands now (its scale), or 0 when the clip
## has no step in it (a pose held, a hover).
static func of(sk: Skeleton3D, ap: AnimationPlayer, clip: String) -> float:
	if sk == null or ap == null or not ap.has_animation(clip) or not sk.is_inside_tree():
		return 0.0
	var an := ap.get_animation(clip)
	var key := "%d:%s" % [an.get_instance_id(), _rig(sk)]
	if not _cache.has(key):
		_cache[key] = _measure(sk, ap, clip)
	# (a planted foot rolls from heel to toe while down, which reads a little fast: carried along by hand at
	# trial paces, the feet of the clips here hold stillest at about nine tenths of the measure)
	return float(_cache[key]) * sk.global_basis.get_scale().x * 0.9


## The way the body goes when this clip walks it (opposite to its planted feet), in the world as it stands now;
## zero if unknown. A body set the wrong way about walks crabwise or backward against it.
static func ahead(sk: Skeleton3D, ap: AnimationPlayer, clip: String) -> Vector3:
	if of(sk, ap, clip) <= 0.0:
		return Vector3.ZERO
	var b: Vector3 = _back.get("%d:%s" % [ap.get_animation(clip).get_instance_id(), _rig(sk)], Vector3.ZERO)
	var w := -(sk.global_basis * b)
	w.y = 0.0
	return w.normalized() if w.length() > 1e-6 else Vector3.ZERO


## The speed to play a clip at so its steps keep to this pace (between lo and hi), or 1 if it has no steps.
static func scale_for(sk: Skeleton3D, ap: AnimationPlayer, clip: String, pace: float, lo := 0.4, hi := 2.5) -> float:
	var s := of(sk, ap, clip)
	if s < 0.05:
		return 1.0
	return clampf(pace / s, lo, hi)


static func _rig(sk: Skeleton3D) -> String:
	return "%d:%s:%s" % [sk.get_bone_count(), sk.get_bone_name(0), sk.get_bone_name(sk.get_bone_count() - 1)]


## The bones it stands on: feet, toes, paws and hooves by name (the deforming ones, where a rig has both).
static func feet_of(sk: Skeleton3D) -> Array:
	var r := _rig(sk)
	if _feet.has(r):
		return _feet[r]
	var out := []
	for bi in sk.get_bone_count():
		var nm := sk.get_bone_name(bi).to_lower()
		if "tail" in nm or "wing" in nm or "weapon" in nm or "hair" in nm or "pole" in nm or "target" in nm or "ik" in nm.get_slice("_", 0):
			continue
		for w in ["foot", "toe", "ankle", "heel", "paw", "hoof", "feet", "talon"]:
			if w in nm:
				out.append(bi)
				break
	var defs := out.filter(func(b): return sk.get_bone_name(b).begins_with("DEF"))
	if not defs.is_empty():
		out = defs
	_feet[r] = out
	return out


## Samples the clip over one loop: for each foot, the stretches it is down (near its lowest), and how fast it
## goes back then; the middle of those is the clip's pace in the skeleton's units.
static func _measure(sk: Skeleton3D, ap: AnimationPlayer, clip: String) -> float:
	var feet := feet_of(sk)
	if feet.is_empty():
		return 0.0
	var was := ap.current_animation
	var was_t := ap.current_animation_position if was != "" else 0.0
	var was_sp := ap.speed_scale
	var was_on := ap.is_playing()
	var up := (sk.global_basis.inverse() * Vector3.UP).normalized()
	var an := ap.get_animation(clip)
	var n := 48
	var dt := an.length / n
	if dt <= 0.0:
		return 0.0
	var tr := {}
	for b in feet:
		tr[b] = []
	var top := -1e9
	var low := 1e9
	for bi in sk.get_bone_count():
		var y := sk.get_bone_global_rest(bi).origin.dot(up)
		top = maxf(top, y)
		low = minf(low, y)
	var H := maxf(top - low, 1e-4)
	ap.play(clip, 0.0)
	for k in n + 1:
		ap.seek(k * dt, true)
		for b in feet:
			tr[b].append(sk.get_bone_global_pose(b).origin)
	# The way a planted foot goes (back under the body): the mean motion of the feet at their very lowest.
	# A foot skimming low as it swings goes the other way, and is not counted
	var back := Vector3.ZERO
	var near := []   ## [foot height over its lowest, its motion over the ground]
	for b in feet:
		var a: Array = tr[b]
		var mn := 1e9
		for p in a:
			mn = minf(mn, (p as Vector3).dot(up))
		for k in range(1, a.size()):
			var p0: Vector3 = a[k - 1]
			var p1: Vector3 = a[k]
			var hh := maxf(p0.dot(up), p1.dot(up)) - mn
			if hh < 0.025 * H:
				var d := p1 - p0
				d -= up * d.dot(up)
				near.append([hh, d / dt])
				if hh < 0.01 * H:
					back += d
	var sp := []
	if back.length() > 1e-6:
		back = back.normalized()
		_back["%d:%s" % [ap.get_animation(clip).get_instance_id(), _rig(sk)]] = back
		for e in near:
			var v: float = (e[1] as Vector3).dot(back)
			if v > 0.0:
				sp.append(v)
	# put the player back as it was
	if was != "":
		ap.play(was, 0.0)
		ap.seek(was_t, true)
		ap.speed_scale = was_sp
		if not was_on:
			ap.pause()
	if sp.size() < 4:
		return 0.0
	sp.sort()
	var v: float = sp[sp.size() / 2]
	# A pose held still (or a hover) shows feet that hardly move while down: no step in it
	return v if v / H > 0.08 else 0.0
