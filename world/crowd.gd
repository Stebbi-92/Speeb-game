class_name WCrowd
extends RefCounted
## The size of the fellowship, and what it asks of the waste. One to eight may walk together; the more
## there are, the more the night sends, and the harder each form and each great one is to bring down.
## The first four count in full; past four each counts for less, so eight is a hard night, not a flood.

const MAX := 8
const PER_FOE := 0.35       ## more forms sent, for each pilgrim past the first
const PER_HP := 0.07        ## each form a little harder to bring down, for each pilgrim past the first
const PER_BOSS := 0.5       ## a great one's strength, for each pilgrim past the first
const ALIVE_CAP := 90       ## never more forms than this awake at once, however many walk

static var fake := 0        ## the dev menu's pretend fellowship, for trying a crowd alone (0 = off)


## How many walk the waste now (at least one).
static func count(w) -> int:
	if fake > 0:
		return fake
	var n := 1
	if w != null and w.has_method("targets"):
		n = maxi(1, w.targets().size())
	return clampi(n, 1, MAX)


## How many walk within reach of a place (at least one): a crowd at a ruin is met by a crowd.
static func near(w, at: Vector3, reach := 70.0) -> int:
	if fake > 0:
		return fake
	var n := 0
	if w != null and w.has_method("targets"):
		for t in w.targets():
			if t.global_position.distance_to(at) < reach:
				n += 1
	return clampi(n, 1, MAX)


## A fellowship of n as the waste reckons it: the first four in full, the rest at half.
static func weight_of(n: int) -> float:
	return float(n) if n <= 4 else 4.0 + (n - 4) * 0.5


static func weight(w) -> float:
	return weight_of(count(w))


## How many forms a fellowship of n meets, as a multiple of what one pilgrim meets.
static func foes_of(n: int) -> float:
	return 1.0 + PER_FOE * (weight_of(n) - 1.0)


static func foes(w) -> float:
	return foes_of(count(w))


## A number of forms, grown for the whole fellowship.
static func scale(w, n: float) -> int:
	return maxi(1, int(round(n * foes(w))))


## A number of forms, grown for those near a place.
static func scale_near(w, at: Vector3, n: float, reach := 70.0) -> int:
	return maxi(1, int(round(n * foes_of(near(w, at, reach)))))


## What one pilgrim of those near a place calls up: their share of what the group meets.
static func share(w, at: Vector3, reach := 70.0) -> float:
	var k := near(w, at, reach)
	return foes_of(k) / float(k)


static func hp(w) -> float:
	return 1.0 + PER_HP * (weight(w) - 1.0)


static func boss(w) -> float:
	return 1.0 + PER_BOSS * (weight(w) - 1.0)


## The line to show the fellowship of what it faces, or "" for one alone.
static func describe(w) -> String:
	var n := count(w)
	if n <= 1:
		return ""
	return "%d walk together: %d%% more forms, each %d%% harder." % [n, int(round((foes(w) - 1.0) * 100.0)), int(round((hp(w) - 1.0) * 100.0))]
