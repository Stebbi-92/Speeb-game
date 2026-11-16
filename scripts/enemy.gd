class_name LesserSpeeb
extends CharacterBody3D
## A lesser form of Speeb, hostile to the seeker.
## rusher: closes in to bite.  spitter: keeps its distance and casts bolts.
## idol: gilded, slow, its face proof against shot; strike it from the side or behind.
## swarm: small and quick, comes in numbers.  elite: a great form, one to a land.
## spider: a cat head on eight legs; it skitters along the ground and leaps.
## saucer: a disc of the lesser that hovers out of reach and lets down mites, small forms that swarm.
## unseen: a tall thing that is barely there. It does not move while it is looked upon.

signal died

## Each kind: its name, its numbers, how it fights, and what it fears ("weak") or shrugs off ("tough"),
## by the kind of harm: shot (pellets), bullet, blast, fire, blade. "body" is "cat" for those that walk
## on four legs; the rest are heads that drift through the air.
const KINDS := {
	"rusher": {"name": "Ash Stalker", "hp": 52.0, "size": 1.0, "speed": 5.6, "bite": 18.0, "radius": 0.45, "body": "cat",
		"weak": {"shot": 1.3}, "tough": {}, "text": "Runs you down and springs at the last."},
	"spitter": {"name": "Bile Choir", "hp": 38.0, "size": 0.85, "speed": 3.2, "bite": 0.0, "radius": 0.4,
		"weak": {"bullet": 1.4}, "tough": {"shot": 0.7}, "text": "Keeps its distance and spits. Pick it off."},
	"idol": {"name": "Gilt Idol", "hp": 90.0, "size": 1.25, "speed": 2.6, "bite": 26.0, "radius": 0.55, "body": "cat",
		"weak": {"blast": 1.6, "blade": 1.4}, "tough": {"shot": 0.6}, "text": "Its golden face turns shot. Strike from the side, or with a blade or a blast."},
	"swarm": {"name": "Cinder Mote", "hp": 12.0, "size": 0.5, "speed": 7.0, "bite": 7.0, "radius": 0.25,
		"weak": {"shot": 1.5, "fire": 2.0}, "tough": {}, "text": "Small, quick and many. A spread of shot clears them."},
	"elite": {"name": "Ash Lion", "hp": 320.0, "size": 2.0, "speed": 4.0, "bite": 30.0, "radius": 0.9, "body": "cat",
		"weak": {"blast": 1.5}, "tough": {"shot": 0.75, "fire": 0.7}, "text": "Great and slow to fall. It spits fire in a fan."},
	"saucer": {"name": "Watching Disc", "hp": 150.0, "size": 1.0, "speed": 4.5, "bite": 0.0, "radius": 1.6,
		"weak": {"bullet": 1.3, "blast": 1.3}, "tough": {"fire": 0.5}, "text": "Hangs above and lets down its brood."},
	"mite": {"name": "Mite", "hp": 9.0, "size": 0.42, "speed": 7.6, "bite": 5.0, "radius": 0.22,
		"weak": {"shot": 1.5}, "tough": {}, "text": "Let down by the discs."},
	"spider": {"name": "Tar Crawler", "hp": 44.0, "size": 0.8, "speed": 7.2, "bite": 15.0, "radius": 0.55,
		"weak": {"fire": 2.0}, "tough": {"bullet": 0.8}, "text": "Climbs what you build. Fire undoes it."},
	"unseen": {"name": "The Unseen", "hp": 140.0, "size": 1.3, "speed": 5.0, "bite": 34.0, "radius": 0.6,
		"weak": {"fire": 1.5}, "tough": {}, "text": "Moves only when not watched. Keep your eyes on it."},
	"brute": {"name": "Bone Hauler", "hp": 210.0, "size": 1.6, "speed": 2.8, "bite": 32.0, "radius": 0.8, "body": "cat",
		"weak": {"blade": 1.5, "blast": 1.3}, "tough": {"shot": 0.6, "bullet": 0.8}, "text": "Slow, until it charges. Step aside and cut at it."},
	"howler": {"name": "Howler", "hp": 70.0, "size": 1.1, "speed": 4.6, "bite": 14.0, "radius": 0.5, "body": "cat",
		"weak": {"bullet": 1.5}, "tough": {"fire": 0.6}, "text": "Stands back and screams. The cry hurts and drives the others on."},
	"bloater": {"name": "Ember Sack", "hp": 30.0, "size": 1.15, "speed": 2.4, "bite": 0.0, "radius": 0.55,
		"weak": {"bullet": 1.5}, "tough": {"blade": 0.5}, "text": "Bursts into fire when it reaches you, or when it dies. Shoot it far off."},
	"lurker": {"name": "Dune Lurker", "hp": 80.0, "size": 1.0, "speed": 6.0, "bite": 24.0, "radius": 0.5, "body": "cat",
		"weak": {"shot": 1.4}, "tough": {"bullet": 0.7}, "text": "Swims under the sand and rises at your feet."},
	# Not lesser forms: men and the dead, with bodies of their own (see FoeBody)
	"unlit_gun": {"name": "Unlit Gunman", "hp": 60.0, "size": 1.0, "speed": 4.2, "bite": 9.0, "radius": 0.45, "body": "model", "role": "gun", "head_y": 0.62, "plate": 30.0,
		"weak": {"bullet": 1.2, "blade": 1.3}, "tough": {}, "text": "One of those who put out the beacons. Keeps its distance and shoots. Close in, or out-shoot it."},
	"unlit_blade": {"name": "Unlit Blade", "hp": 85.0, "size": 1.0, "speed": 5.0, "bite": 20.0, "radius": 0.45, "body": "model", "role": "melee", "head_y": 0.65, "plate": 50.0,
		"weak": {"blast": 1.4}, "tough": {}, "text": "Guards against shots from the front. Strike when it swings, or turn its blade with your own guard."},
	"unlit_brute": {"name": "Unlit Breaker", "hp": 200.0, "size": 1.3, "speed": 3.4, "bite": 34.0, "radius": 0.6, "body": "model", "role": "melee", "head_y": 0.95, "plate": 120.0,
		"weak": {"blade": 1.3}, "tough": {"shot": 0.8}, "text": "A great maul, a slow swing, and thick plate. Step out of the swing, then strike."},
	"hollow": {"name": "The Hollowed", "hp": 55.0, "size": 1.0, "speed": 2.4, "bite": 15.0, "radius": 0.45, "body": "model", "role": "melee", "head_y": 0.7,
		"weak": {"fire": 1.8, "shot": 1.2}, "tough": {}, "text": "Pilgrims the night took. Slow, and never alone."},
	"saltbone": {"name": "Salt-Bones", "hp": 40.0, "size": 0.9, "speed": 6.0, "bite": 13.0, "radius": 0.4, "body": "model", "role": "melee", "head_y": 0.62,
		"weak": {"blade": 1.6, "blast": 1.5, "shot": 1.3}, "tough": {"bullet": 0.6}, "text": "Bones the salt kept. Quick, and bullets slip through them. Use shot or the blade."},
	"vigil": {"name": "Lost Vigil", "hp": 70.0, "size": 1.0, "speed": 3.4, "bite": 12.0, "radius": 0.5, "body": "model", "role": "float", "head_y": 0.5,
		"weak": {"fire": 1.6, "blade": 1.6}, "tough": {"bullet": 0.5, "shot": 0.6}, "text": "A beacon-keeper who never left the dark. It drifts through, and steals warmth."},
	"warden": {"name": "Gravewarden", "hp": 260.0, "size": 1.4, "speed": 3.0, "bite": 30.0, "radius": 0.7, "body": "model", "role": "melee", "head_y": 1.1,
		"weak": {"fire": 1.4}, "tough": {"bullet": 0.8}, "text": "It keeps the Hollowed. Where it walks, more of them rise."},
	# 0.7: more of the waste's foes. Each has one thing to learn about it.
	"unlit_mark": {"name": "Unlit Marksman", "hp": 55.0, "size": 1.0, "speed": 3.8, "bite": 24.0, "radius": 0.45, "body": "model", "role": "gun", "head_y": 0.62,
		"sight": 75.0, "burst": 1, "aim": 1.4, "mag": 5, "aimed": 0.55,
		"weak": {"bullet": 1.2, "blade": 1.5}, "tough": {}, "text": "Shoots from far off, one careful shot at a time. Watch for the glint, then move."},
	"unlit_flame": {"name": "Unlit Firebrand", "hp": 75.0, "size": 1.0, "speed": 5.2, "bite": 14.0, "radius": 0.45, "body": "model", "role": "melee", "head_y": 0.65,
		"burn": 4.0, "weak": {"shot": 1.3}, "tough": {"fire": 0.2}, "text": "Its blade is lit. A cut sets you burning for a while."},
	"deacon": {"name": "Pale Deacon", "hp": 110.0, "size": 1.0, "speed": 4.6, "bite": 18.0, "radius": 0.45, "body": "model", "role": "melee", "head_y": 0.7,
		"drain": 1.0, "weak": {"fire": 1.8, "blade": 1.3}, "tough": {"bullet": 0.8}, "text": "It walks only by night, and every wound it gives closes its own."},
	"drowned": {"name": "Tar-Drowned", "hp": 70.0, "size": 1.0, "speed": 2.8, "bite": 12.0, "radius": 0.45, "body": "model", "role": "melee", "head_y": 0.7,
		"slow": 3.0, "weak": {"fire": 2.0}, "tough": {"bullet": 0.8, "shot": 0.8}, "text": "Risen from the marsh, still dripping. Its grip leaves tar on your legs and slows you."},
	"colossus": {"name": "Hollow Colossus", "hp": 480.0, "size": 1.8, "speed": 2.2, "bite": 42.0, "radius": 0.9, "body": "model", "role": "melee", "head_y": 1.6,
		"weak": {"blast": 1.6, "fire": 1.3}, "tough": {"bullet": 0.7, "blade": 0.8}, "text": "Many Hollowed, grown into one. Slow, and each blow lands like a falling wall. Keep away."},
	"wisp": {"name": "Ember Wisp", "hp": 45.0, "size": 0.9, "speed": 4.6, "bite": 8.0, "radius": 0.45, "body": "model", "role": "float", "head_y": 0.45,
		"burn": 3.0, "weak": {"shot": 1.6, "blade": 1.4}, "tough": {"fire": 0.0, "bullet": 0.7}, "text": "A live coal with a will. It drifts close and sets you burning."},
	"serpent": {"name": "Grey Wyrm", "hp": 420.0, "size": 2.2, "speed": 7.0, "bite": 26.0, "radius": 1.0,
		"weak": {"blast": 1.5, "bullet": 1.2}, "tough": {"fire": 0.3}, "text": "It lives under the Grey Sea and follows boats that stray far from land. Shoot it as it rises."},
	"knight": {"name": "Ashen Knight", "hp": 240.0, "size": 1.4, "speed": 3.2, "bite": 30.0, "radius": 0.7, "body": "model", "role": "melee", "head_y": 1.1, "plate": 160.0,
		"weak": {"blast": 1.3}, "tough": {"shot": 0.7}, "text": "Old iron, filled with ash. Its plate turns most things; piercing rounds or a blast will open it."},
	"saltrifle": {"name": "Salt Rifleman", "hp": 45.0, "size": 0.9, "speed": 4.4, "bite": 11.0, "radius": 0.4, "body": "model", "role": "gun", "head_y": 0.62,
		"weak": {"blade": 1.6, "blast": 1.5, "shot": 1.3}, "tough": {"bullet": 0.6}, "text": "A soldier the salt kept, still holding its rifle. Bullets slip through; use shot."},
}
## The kind of harm now being dealt. Set by whatever deals it, just before it does.
static var harm_kind := ""
static var harm_head := false    ## the blow is a head shot: it goes over any plate
static var harm_pierce := 1.0    ## the load's bite on plate: above 1 goes through, below 1 is stopped more
static var _smoke: Texture2D
static var _blot: Texture2D
static var blood_shown := 0   ## for the tests

## What each kind bleeds: the ash forms run dark, the gilded ones shed gold, the discs only spark.
const BLOOD := {
	"idol": Color(0.85, 0.65, 0.2), "saucer": Color(0.9, 0.85, 0.6), "mite": Color(0.9, 0.85, 0.6),
	"swarm": Color(0.95, 0.45, 0.1), "bloater": Color(0.95, 0.45, 0.1), "spider": Color(0.08, 0.06, 0.05),
	"unseen": Color(0.1, 0.1, 0.12), "spitter": Color(0.45, 0.5, 0.12),
}


static func smoke_tex() -> Texture2D:
	if _smoke == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
		_smoke = ImageTexture.create_from_image(img)
	return _smoke


## The great ones of the waste, one to a land, each in its lair. Each wears the body of a lesser kind
## ("base") grown vast, and has ways of its own: slam (the ground breaks around it), brood (it brings
## forth lesser forms), volley (a fan of bolts), blink (watched too long, it is suddenly elsewhere).
const BOSSES := {
	"boss_ash": {"name": "The Cinder Matron", "base": "elite", "hp": 2400.0, "size": 3.2, "speed": 3.2, "bite": 40.0, "radius": 1.6, "grow": 1.0, "ways": ["slam", "brood", "charge"], "brood": "swarm", "land": "ash"},
	"boss_dunes": {"name": "The Sand Choir", "base": "spitter", "hp": 1700.0, "size": 2.6, "speed": 4.0, "bite": 0.0, "radius": 1.3, "grow": 1.0, "ways": ["volley", "brood", "rain"], "brood": "spider", "land": "dunes"},
	"boss_salt": {"name": "The White Disc", "base": "saucer", "hp": 2000.0, "size": 1.0, "speed": 4.0, "bite": 0.0, "radius": 3.2, "grow": 2.0, "ways": ["volley", "rain", "charge"], "land": "salt"},
	"boss_forest": {"name": "The Long Watcher", "base": "unseen", "hp": 1600.0, "size": 1.3, "speed": 5.5, "bite": 50.0, "radius": 1.1, "grow": 1.9, "ways": ["blink", "charge"], "land": "forest"},
	"boss_basalt": {"name": "The Basalt Idol", "base": "idol", "hp": 2600.0, "size": 3.0, "speed": 2.2, "bite": 45.0, "radius": 1.5, "grow": 1.0, "ways": ["slam", "volley", "charge"], "land": "basalt"},
	"boss_marsh": {"name": "The Tar Mother", "base": "spider", "hp": 1800.0, "size": 0.8, "speed": 6.0, "bite": 35.0, "radius": 1.3, "grow": 2.6, "ways": ["brood", "rain", "charge"], "brood": "spider", "land": "marsh"},
}
const IDOL_CODES := ["goldspeeb", "marblespeeb", "jadespeeb", "obsidianspeeb", "fossilspeeb"]

var code := ""
var kind := "rusher"
var hp := 40.0
var level: Level
var head: LesserHead
var _legs: Array = []
var _leap_cd := 2.0
var spec: Dictionary
var _attack_cd := 1.0
var _flash := 0.0
var _alive := true
var _t := 0.0
var _knock := Vector3.ZERO
var _knock_on := Vector3.ZERO   ## the push already in the velocity, so it is added once and not every frame
var _shot_slow := 0.0            ## a heavy form under fire slows for a moment, and keeps coming
var _strafe := 1.0
var _disc: Node3D
var _beam: MeshInstance3D
var _mites: Array = []
var _cry_cd := 0.0
var boss := ""        ## the great one this is, or "" for a lesser form
var max_hp := 1.0
var hp_frac := 1.0    ## for puppets, as the host tells it
var _way_cd := {}
var _busy := 0.0      ## a great one winding up a way: it does nothing else meanwhile
var _charge_t := 0.0  ## running down a line
var _charge_dir := Vector3.ZERO
var _charge_hit := {}
var plate := 0.0      ## iron on the body: it soaks shots and cuts until it breaks
var _spent := 0.0     ## worn out after a charge or a slam: it stands still and takes more harm
var _wroth := false   ## past half its life: quicker in all its ways
var _brood: Array = []
var _watched_t := 0.0
var _bar: MeshInstance3D
var _bar_t := 0.0
static var _bar_mat: ShaderMaterial
var _shimmer: ShaderMaterial
var _seen := 0.08
var _watched := false
var _breath_cd := 0.0
# In a fellowship the host runs every form; the others see puppets that follow what the host tells them
var net_id := 0
var _wind := 0.0          ## a bite gathering: seconds until it lands. Step out of reach and it misses
var _wind_total := 0.0
var _stagger := 0.0       ## reeling from heavy harm: it neither moves on you nor bites
var _dmg_win := 0.0       ## harm taken lately, which drains away; enough at once staggers it
## What a foe of the waste has in mind: "calm" (keeps to its place), "search" (goes to look where
## something was heard or last seen), "hunt" (knows where you are) or "flee" (hurt, and running).
## Lesser forms and great ones always hunt; so do raiders sent against a base.
var mind := "hunt"
var _home := Vector3.ZERO
var _last_known := Vector3.ZERO
var _lost_t := 0.0
var _search_t := 0.0
var _look_t := 0.0
var _wander := Vector3.ZERO
var _fled := false
var _flee_t := 0.0
var _mark: Label3D
var _mark_t := 0.0
var _flank := 0.0         ## which side it swings out to as it closes
var _head_base := Vector3.ONE
## How long each kind gathers itself before it bites. The quick ones barely pause; the heavy ones show it.
const WINDUP := {"rusher": 0.38, "idol": 0.6, "swarm": 0.2, "mite": 0.18, "elite": 0.55, "spider": 0.3,
	"brute": 0.65, "howler": 0.4, "lurker": 0.3, "unlit_blade": 0.45, "unlit_brute": 0.85, "hollow": 0.6, "saltbone": 0.35, "vigil": 0.4, "warden": 0.8,
	"unlit_flame": 0.45, "deacon": 0.4, "drowned": 0.6, "colossus": 1.1, "wisp": 0.35, "knight": 0.8}
var puppet := false
var credit := false
var last_hitter := 1
var heard_at := 0
var _net_to := Vector3.ZERO
var _net_body_y := 0.0
var _net_head := Vector2.ZERO
var _net_v := Vector3.ZERO


func setup(c: String, k: String, lvl: Level) -> LesserSpeeb:
	if BOSSES.has(k):
		boss = k
		k = BOSSES[k].base
	kind = k
	code = IDOL_CODES[randi() % IDOL_CODES.size()] if k == "idol" else c
	level = lvl
	spec = BOSSES[boss] if boss != "" else KINDS[k]
	hp = spec.hp * Game.difficulty_scale("hp")
	if boss != "":
		hp *= 1.0 + 0.6 * maxi(0, lvl.targets().size() - 1)
	max_hp = hp
	return self


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0 if puppet else (1 | 2)
	_net_to = position
	heard_at = Time.get_ticks_msec()
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED if walks() else CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	if kind == "saucer":
		var cy := CylinderShape3D.new()
		cy.radius = spec.radius
		cy.height = 1.5
		cs.shape = cy
		cs.position.y = 0.15
	else:
		var s := SphereShape3D.new()
		s.radius = spec.radius
		cs.shape = s
	add_child(cs)
	head = LesserHead.new().setup(code, spec.size)
	head.position.y = 0.42 if kind == "saucer" else -0.05 * spec.size
	add_child(head)
	if kind == "idol":
		head.set_gild(1.0)
	if kind == "unseen":
		_build_unseen()
	if kind == "spider":
		_build_spider()
	if spec.get("body", "") == "cat":
		_build_cat()
	if kind == "bloater":
		_build_sack()
	if kind == "serpent":
		_build_serpent()
	if spec.get("body", "") == "model":
		_fb = FoeBody.make(kind)
		_fb.position.y = -float(spec.radius)
		add_child(_fb)
		head.visible = false
		head.position.y = float(spec.head_y)
		_flank = randf_range(-PI, PI)
		_ammo = 9
		if Game.wasteland and boss == "":
			mind = "calm"
			_home = global_position
			_wander = global_position
		plate = float(spec.get("plate", 0.0))
		if plate > 0.0:
			_fb.wear_plate(kind in ["unlit_brute", "knight"])
		_fit_shape(cs)
		# Once its arms and plate are on and it has found its stance, fitted again
		get_tree().create_timer(0.4, false).timeout.connect(func(): if is_instance_valid(cs): _fit_shape(cs))
	if kind != "unseen":
		_make_name()
	if kind == "saucer":
		_build_saucer()
	if boss != "":
		_grow_into_boss()
	elif spec.hp >= 30.0:
		_make_bar()
	if _fb:
		if _name_l:
			_name_l.position.y = float(spec.head_y) + 0.8 * spec.size
		if _bar:
			_bar.position.y = float(spec.head_y) + 0.6 * spec.size
	_remember_head()
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_strafe = 1.0 if randf() < 0.5 else -1.0
	_attack_cd = randf_range(1.0, 2.5)
	_cry_cd = randf_range(0.5, 2.0)
	if boss != "":
		level.sfx("great_roar", 6, global_position, 0.9)
		level.sfx("horror_deep", 0, global_position, 0.8)
	elif kind == "elite":
		level.sfx("roar", 2, global_position, 0.9)
	elif kind == "saucer":
		var hum := AudioStreamPlayer3D.new()
		var st = load("res://assets/audio/saucer_hum.ogg")
		st.loop = true
		hum.stream = st
		hum.unit_size = 14
		hum.volume_db = -2
		hum.autoplay = true
		add_child(hum)
	elif kind == "spider":
		_cry("critter_%d" % (randi() % 3), -2)
	elif kind == "unseen":
		level.sfx("unseen_call", 2, global_position, randf_range(0.9, 1.05))
		_cry_cd = randf_range(12.0, 20.0)
	elif kind != "mite":
		_cry("growl_%d" % (randi() % 3), -4)


## A cry from the lesser form, pitched by its size: the small shriek high, the great ones low.
func _remember_head() -> void:
	if head:
		_head_base = head.scale
	_flank = randf_range(-1.0, 1.0)


func _cry(sound: String, vol := 0.0) -> void:
	var pitch: float = clampf(1.0 / spec.size, 0.6, 1.7) * randf_range(0.85, 1.15)
	level.sfx(sound, vol, global_position, pitch)



func _physics_process(delta: float) -> void:
	if not _alive or level.player == null:
		return
	if puppet:
		_puppet_tick(delta)
		return
	delta *= level.enemy_time
	_t += delta
	seen_t -= delta
	smoke_t -= delta
	# It hunts the nearest pilgrim still standing; with none, it waits
	var p: Node3D = level.nearest_target(global_position)
	var idle := p == null
	if idle:
		p = level.player
	# A form that falls from the world, or strays too far from it, is simply unmade
	if global_position.y < level.kill_y or (not idle and global_position.distance_to(p.global_position) > 90.0):
		die(false)
		return
	var target := p.global_position + Vector3(0, 1.3, 0)
	_rescue(delta, idle)
	var to := target - global_position
	var dist := to.length()
	var dir := to / maxf(dist, 0.01)
	var turn := 1.5 if kind == "idol" else 12.0
	head.rotation.y = lerp_angle(head.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * turn))
	head.rotation.x = -asin(clampf(dir.y, -0.6, 0.6)) * 0.6
	var want := Vector3.ZERO
	_dmg_win = maxf(0.0, _dmg_win - max_hp * 0.25 * delta)
	if _stagger > 0.0:
		_stagger -= delta
		head.rotation.z = sin(_t * 18.0) * 0.25 * minf(1.0, _stagger * 2.0)
	elif head.rotation.z != 0.0:
		head.rotation.z = 0.0
	if _spent > 0.0:
		_spent -= delta
		head.rotation.x = 0.5 * minf(1.0, _spent * 2.0)
	if _charge_t > 0.0 and not level.combat_frozen:
		_charge_tick(delta)
		return
	var frozen: bool = level.combat_frozen or idle or _stagger > 0.0 or _spent > 0.0 or _busy > 0.0
	if boss != "" and not level.combat_frozen and not idle and not level.completed:
		_boss_tick(delta, p, dist)
	if _fb:
		_foe_move(delta, p, dist, dir, frozen)
		return
	if walks():
		_spider_move(delta, p, dist, frozen)
		return
	var speed: float = spec.speed * Game.difficulty_scale("speed") * (0.55 if _shot_slow > 0.0 else 1.0)
	if not frozen:
		match kind:
			"spitter":
				var side := dir.cross(Vector3.UP) * _strafe * 2.2
				if dist > 14.0:
					want = dir * speed + side
				elif dist < 8.0:
					want = -dir * speed * 0.9 + side
				else:
					want = side
				want.y += (target.y + 1.5 - global_position.y) * 1.2
			"saucer":
				var ang := _t * 0.3 * _strafe
				var hover := p.global_position + Vector3(cos(ang) * 11.0, 7.5, sin(ang) * 11.0)
				want = (hover - global_position).limit_length(speed)
			"elite":
				want = dir * speed if dist > 4.0 else dir.cross(Vector3.UP) * _strafe * 3.0
				want.y += (target.y + 0.8 - global_position.y) * 1.0
			"serpent":
				# It swims at the surface, then rears up out of the water to strike
				want = dir * speed * (1.0 if dist > 5.0 else 0.4)
				var sy := WIsles.SEA_Y + 0.4 if dist > 7.0 else target.y - 0.8
				want.y = (sy - global_position.y) * 2.5
			"unseen":
				# Still as a post while it is watched; when the eye leaves it, it comes on fast
				var w := dist < 30.0 and _is_watched(p)
				if w and not _watched and dist < 22.0:
					level.sfx("unseen_click", -3, global_position, randf_range(0.9, 1.1))
				_watched = w
				if not w:
					want = dir * speed * (1.7 if dist > 9.0 else 1.0)
					want.y = (target.y - 0.2 - global_position.y) * 2.0
			_:
				# They come at you from the sides as well as the front, closing straight only near
				var d2 := dir.rotated(Vector3.UP, _flank * 0.7) if dist > 7.0 and (not Game.wasteland or WRules.flanks()) else dir
				want = d2 * speed
				want += dir.cross(Vector3.UP) * sin(_t * 2.0 + _strafe) * (2.5 if kind == "swarm" else 1.2)
	if kind == "unseen":
		_shade_tick(delta, dist)
		if _watched:
			velocity = Vector3.ZERO
	else:
		want.y += sin(_t * 2.6) * 0.4
	if kind == "serpent":
		_coil_tick()
	_shot_slow = maxf(0.0, _shot_slow - delta)
	velocity = (velocity - _knock_on).lerp(want, minf(1.0, delta * (8.0 if kind == "unseen" else 3.0))) + _knock
	_knock_on = _knock
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	var real_v := velocity
	velocity *= level.enemy_time
	move_and_slide()
	velocity = real_v
	if is_on_wall():
		velocity.y += 6.0 * delta * 10.0
		_claw_at_wall()
	_flash = maxf(0.0, _flash - delta * 5.0)
	head.set_flash(_flash)
	_bar_tick(delta)
	if frozen or level.completed or level.failing:
		return
	_attack_cd -= delta
	_cry_cd -= delta
	if kind == "unseen":
		_unseen_noise(delta, dist)
	# The forms scream as they close on him
	if _cry_cd <= 0.0 and dist < 16.0:
		match kind:
			"rusher", "swarm", "idol":
				_cry("shriek_%d" % (randi() % 4), 0 if kind != "swarm" else -6)
				_cry_cd = randf_range(3.5, 7.0)
			"mite":
				_cry("chitter", -4)
				_cry_cd = randf_range(1.5, 3.5)
			"elite":
				level.sfx("roar", 0, global_position, randf_range(0.85, 1.05))
				_cry_cd = randf_range(7.0, 11.0)
			"spitter":
				_cry("growl_%d" % (randi() % 3), -2)
				_cry_cd = randf_range(5.0, 9.0)
	if kind == "bloater" and dist < 2.4:
		die(true)
		return
	var reach: float = 1.0 + spec.radius
	if kind == "unseen" and spec.bite > 0.0 and dist < reach and _attack_cd <= 0.0:
		# The Unseen gives no warning: its warning is that you looked away
		_attack_cd = 0.9
		level.sfx("bite", -2, global_position)
		level.sfx("unseen_scream", 2, global_position, randf_range(0.9, 1.1))
		_seen = 1.0
		level.hurt_target(p, spec.bite, global_position)
		_knock = -dir * 6.0
	elif spec.bite > 0.0 and kind != "unseen":
		_bite_tick(delta, p, dist, dir, reach, 1.3 if kind == "idol" else 0.9, spec.bite)
	if kind == "saucer":
		_disc.rotation.y += delta * 2.5
		_mites = _mites.filter(func(m): return is_instance_valid(m) and m.is_alive())
		if _attack_cd <= 0.0:
			_attack_cd = randf_range(5.0, 6.5)
			if _mites.size() < 6:
				_let_down()
		return
	if (kind == "spitter" or kind == "elite") and _attack_cd <= 0.0 and dist < 26.0 and _can_see(target):
		_attack_cd = randf_range(1.5, 2.3)
		if kind == "elite":
			for k in [-0.2, 0.0, 0.2]:
				_spit(global_position + (target - global_position).rotated(Vector3.UP, k))
		else:
			_spit(target)


var _coils: Array = []


## A long dark body trailing behind the face, in coils that rise and fall as it swims.
func _build_serpent() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.14, 0.17, 0.17)
	m.roughness = 0.4
	m.metallic = 0.2
	for i in 9:
		var seg := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var r := 0.9 * (1.0 - i * 0.08)
		sm.radius = r
		sm.height = r * 2.0
		seg.mesh = sm
		seg.material_override = m
		add_child(seg)
		seg.position = Vector3(0, -0.3, -1.3 * (i + 1))
		_coils.append(seg)
	head.set_flash(0.0)


func _coil_tick() -> void:
	var back := -Vector3(velocity.x, 0, velocity.z).normalized() if Vector2(velocity.x, velocity.z).length() > 0.3 else Vector3(0, 0, -1)
	for i in _coils.size():
		var seg: MeshInstance3D = _coils[i]
		var along := back * 1.3 * (i + 1)
		seg.position = Vector3(along.x, -0.3 + sin(_t * 3.0 - i * 0.8) * 0.6 - i * 0.05, along.z)


## Eight legs about a dark abdomen, the head carried low in front.
func _build_spider() -> void:
	head.position = Vector3(0, 0.1, 0.25)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = head.fur.darkened(0.85)
	dark.roughness = 0.5
	dark.metallic = 0.2
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.45
	sm.height = 0.8
	body.mesh = sm
	body.material_override = dark
	body.position = Vector3(0, 0.15, -0.5)
	body.scale = Vector3(1.0, 0.8, 1.25)
	add_child(body)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.08, 0.04)
	var mark := MeshInstance3D.new()
	var mm := PrismMesh.new()
	mm.size = Vector3(0.22, 0.2, 0.05)
	mark.mesh = mm
	mark.material_override = red
	mark.position = Vector3(0, 0.5, -0.55)
	mark.rotation.x = -PI / 2
	add_child(mark)
	for side in [-1.0, 1.0]:
		for i in 4:
			var hip := Node3D.new()
			hip.position = Vector3(side * 0.22, 0.15, 0.05 - i * 0.22)
			add_child(hip)
			var knee := Vector3(side * 0.55, 0.38, 0.28 - i * 0.18)
			var foot := knee + Vector3(side * 0.35, -1.05, 0.16 - i * 0.1)
			_segment(hip, Vector3.ZERO, knee, 0.05, dark)
			_segment(hip, knee, foot, 0.035, dark)
			_legs.append({"pivot": hip, "phase": i * 1.6 + (0.0 if side > 0 else PI)})


func _segment(parent: Node3D, from: Vector3, to: Vector3, r: float, m: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r * 0.7
	c.bottom_radius = r
	c.height = from.distance_to(to)
	c.radial_segments = 6
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	var y := (to - from).normalized()
	var x := y.cross(Vector3.FORWARD).normalized()
	if x.length() < 0.1:
		x = Vector3.RIGHT
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y, z), (from + to) * 0.5)
	parent.add_child(mi)


func walks() -> bool:
	return kind == "spider" or spec.get("body", "") == "cat" or (spec.get("body", "") == "model" and spec.get("role", "") != "float")


var _buried := 0.0       ## a lurker under the sand: 1 hidden, 0 risen
var _fb: FoeBody         ## the body of a foe that is not a lesser form
var _ammo := 9           ## a gunman's rounds before it must reload
var _aim := 0.0          ## a gunman drawing a bead: seconds left before it fires
var _burst := 0          ## shots left in the burst
var _guard := false      ## an Unlit Blade with its blade up: shots from the front are turned
var _charge := 0.0       ## a hauler's charge, seconds left
var _howl_cd := 4.0
var seen_t := 0.0        ## shown by a flare or the censer: its name stands over it and it is marked
var smoke_t := 0.0       ## in the censer's smoke: it chokes and slows, and cannot hide under the sand


## A flare's light or the censer's smoke shows it for a while; smoke also chokes it.
func reveal(secs: float, smoke := false) -> void:
	seen_t = maxf(seen_t, secs)
	if smoke:
		smoke_t = maxf(smoke_t, secs)


## Those that walk run the ground, legs rippling, and spring when near. Each kind has its own way.
func _spider_move(delta: float, p: Node3D, dist: float, frozen: bool) -> void:
	var flat := p.global_position - global_position
	flat.y = 0
	var fd := flat.length()
	var dir := flat / maxf(fd, 0.01)
	var speed: float = spec.speed * Game.difficulty_scale("speed") * (0.65 if smoke_t > 0.0 else 1.0) * (0.55 if _shot_slow > 0.0 else 1.0)
	_shot_slow = maxf(0.0, _shot_slow - delta)
	var on_floor := is_on_floor()
	var cat := kind != "spider"
	if _charge <= 0.0:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * (10.0 if kind != "brute" else 4.0)))
	if not frozen:
		var d2 := dir.rotated(Vector3.UP, _flank * 0.7) if fd > 7.0 and kind in ["rusher", "spider", "idol"] and (not Game.wasteland or WRules.flanks()) else dir
		var want := d2 * speed + dir.cross(Vector3.UP) * sin(_t * 3.0 + _strafe) * (2.5 if not cat else 1.0)
		match kind:
			"howler":
				# It keeps to the middle distance, where its cry carries
				if fd < 9.0:
					want = -dir * speed * 0.8 + dir.cross(Vector3.UP) * _strafe * 2.0
				elif fd < 15.0:
					want = dir.cross(Vector3.UP) * _strafe * 2.5
			"lurker":
				var under := fd > 6.0 and seen_t <= 0.0
				_buried = move_toward(_buried, 1.0 if under else 0.0, delta * (1.5 if under else 3.0))
				if under:
					want = dir * speed * 1.3
			"brute":
				if _charge > 0.0:
					_charge -= delta
					want = Vector3(sin(rotation.y), 0, cos(rotation.y)) * speed * 4.2
		if on_floor:
			velocity.x = lerpf(velocity.x, want.x, minf(1.0, delta * 8.0))
			velocity.z = lerpf(velocity.z, want.z, minf(1.0, delta * 8.0))
		_leap_cd -= delta
		if kind == "brute":
			if on_floor and fd < 16.0 and fd > 4.0 and _leap_cd <= 0.0 and _charge <= 0.0:
				_leap_cd = randf_range(4.0, 6.0)
				_charge = 1.1
				level.sfx("roar", 0, global_position, 0.75)
		elif kind in ["rusher", "spider", "lurker", "elite"]:
			if on_floor and fd < 7.5 and fd > 2.0 and _leap_cd <= 0.0 and _buried < 0.5 and _wind <= 0.0:
				_leap_cd = randf_range(2.0, 3.5) * (1.6 if kind == "elite" else 1.0)
				velocity = dir * 11.0 + Vector3(0, 6.5, 0)
				_cry("spider_hiss" if kind == "spider" else "shriek_%d" % (randi() % 4), 0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
	velocity.y -= 22.0 * delta
	velocity += _knock - _knock_on
	_knock_on = _knock
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	var real_v := velocity
	velocity *= level.enemy_time
	move_and_slide()
	velocity = real_v
	if is_on_wall():
		_claw_at_wall()
		_charge = 0.0
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	# Spiders climb what stands in their way; cats scramble over the low things
	if is_on_wall() and not frozen:
		velocity.y = 4.5 if not cat else 3.0
	# The legs ripple with its pace
	var pace := Vector2(velocity.x, velocity.z).length()
	for leg in _legs:
		var ph: float = _t * (6.0 + pace * 2.0) + leg.phase
		if cat:
			leg.pivot.rotation.x = sin(ph) * minf(0.7, 0.1 + pace * 0.08)
		else:
			var amp := minf(0.4, 0.08 + pace * 0.05)
			leg.pivot.rotation.y = sin(ph) * amp
			leg.pivot.rotation.x = maxf(0.0, cos(ph)) * amp * -0.6
	if _tail:
		_tail.rotation.x = -0.6 + sin(_t * 2.2) * 0.25
		_tail.rotation.y = sin(_t * 1.7) * 0.4
	if _body_node:
		_body_node.position.y = _lift - _buried * 1.6 * spec.size
		_body_node.visible = _buried < 0.95
		if _dust:
			_dust.emitting = _buried > 0.3 and pace > 1.0
	head.rotation.y = 0.0
	head.rotation.x = -asin(clampf((p.global_position.y + 1.3 - global_position.y) / maxf(dist, 0.1), -0.6, 0.6)) * 0.5
	_flash = maxf(0.0, _flash - delta * 5.0)
	head.set_flash(_flash)
	_bar_tick(delta)
	if frozen or level.completed or level.failing:
		return
	_attack_cd -= delta
	_cry_cd -= delta
	if _cry_cd <= 0.0 and dist < 18.0 and _buried < 0.5:
		_cry_cd = randf_range(1.2, 3.0) if not cat else randf_range(3.5, 7.0)
		if cat:
			_cry("growl_%d" % (randi() % 3) if randf() < 0.5 else "shriek_%d" % (randi() % 4), -2)
		else:
			_cry("skitter" if randf() < 0.5 else "critter_%d" % (randi() % 3), -2)
	if kind == "howler":
		_howl_cd -= delta
		if _howl_cd <= 0.0 and dist < 18.0 and _can_see(p.global_position + Vector3(0, 1.3, 0)):
			_howl_cd = randf_range(5.0, 7.0)
			_howl(p)
	if kind == "elite" and _attack_cd <= 0.0 and dist < 22.0 and dist > 4.0 and _can_see(p.global_position + Vector3(0, 1.3, 0)):
		_attack_cd = randf_range(2.0, 3.0)
		for k in [-0.2, 0.0, 0.2]:
			_spit(global_position + Vector3(0, 0.8, 0) + (p.global_position + Vector3(0, 1.3, 0) - global_position).rotated(Vector3.UP, k))
		return
	var reach: float = 1.2 + spec.radius
	if _charge > 0.0:
		# A hauler's charge strikes as it comes, with no pause: the roar before it was the warning
		if dist < reach and _attack_cd <= 0.0:
			_attack_cd = 1.4
			level.sfx("bite", -2, global_position)
			level.hurt_target(p, spec.bite * 1.8, global_position)
			if p == level.player:
				level.player.velocity += dir * 14.0 + Vector3(0, 5, 0)
			_charge = 0.0
			_knock = -dir * 5.0
	elif _buried < 0.3:
		_bite_tick(delta, p, dist, dir, reach, 0.8 if kind != "brute" else 1.4, spec.bite)


## The howler's cry: it hurts what hears it close, and the forms near it come on faster a while.
func _howl(p: Node3D) -> void:
	level.sfx("roar", 2, global_position, 1.35)
	head.set_flash(1.0)
	var d := global_position.distance_to(p.global_position)
	if d < 14.0:
		level.hurt_target(p, 10.0 * (1.0 - d / 16.0) + 4.0, global_position)
		if p == level.player:
			level.player.shake(0.6)
	for e in level.enemies:
		if is_instance_valid(e) and e != self and e.is_alive() and e.global_position.distance_to(global_position) < 16.0:
			e._knock += (p.global_position - e.global_position).normalized() * 3.0
			e._leap_cd = 0.0


var _legs_m: Material
var _tail: Node3D
var _body_node: Node3D
var _lift := 0.0
var _dust: CPUParticles3D


## Four legs and a long back under the head, a tail that will not keep still: a cat gone wrong.
func _build_cat() -> void:
	var s: float = spec.size
	var coat: Color = head.coat if head.coat != Color() else head.fur.darkened(0.8)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = coat
	fur.roughness = 0.95
	fur.rim_enabled = true
	fur.rim = 0.25
	fur.rim_tint = 0.0
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color(0.25, 0.04, 0.02)
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.28, 0.08)
	ember.emission_energy_multiplier = 1.4
	_legs_m = fur
	_body_node = Node3D.new()
	add_child(_body_node)
	head.reparent(_body_node, false)
	head.position = Vector3(0, 0.15 * s, 0.55 * s)
	head.scale = Vector3.ONE * 0.72
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32 * s
	cap.height = 1.25 * s
	torso.mesh = cap
	torso.material_override = fur
	torso.rotation.x = PI / 2
	torso.position = Vector3(0, -0.05 * s, -0.12 * s)
	_body_node.add_child(torso)
	# Cracks of ember along the spine: the mark of a lesser form
	for i in 4:
		var c := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.03, 0.16) * s
		c.mesh = bm
		c.material_override = ember
		c.position = Vector3(sin(i * 2.3) * 0.06 * s, 0.24 * s, (0.25 - i * 0.2) * s)
		c.rotation.y = sin(i * 1.7) * 0.5
		_body_node.add_child(c)
	if kind == "idol":
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(0.85, 0.66, 0.3)
		gold.metallic = 0.9
		gold.roughness = 0.3
		torso.material_override = gold
		fur = gold
	if kind == "brute":
		# Plates of bone over the shoulders
		var bone := StandardMaterial3D.new()
		bone.albedo_color = Color(0.82, 0.78, 0.68)
		for sx in [-1.0, 1.0]:
			var pl := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.25, 0.1, 0.45) * s
			pl.mesh = bm
			pl.material_override = bone
			pl.position = Vector3(sx * 0.18 * s, 0.22 * s, 0.2 * s)
			pl.rotation.z = sx * 0.5
			_body_node.add_child(pl)
	for fz in [0.38, -0.55]:
		for sx in [-1.0, 1.0]:
			var hip := Node3D.new()
			hip.position = Vector3(sx * 0.17 * s, -0.12 * s, fz * s)
			_body_node.add_child(hip)
			_segment(hip, Vector3.ZERO, Vector3(0, -0.32 * s, 0.05 * s), 0.1 * s, fur)
			_segment(hip, Vector3(0, -0.32 * s, 0.05 * s), Vector3(0, -0.62 * s, -0.02 * s), 0.07 * s, fur)
			_legs.append({"pivot": hip, "phase": (0.0 if sx > 0 else PI) + (PI * 0.5 if fz < 0 else 0.0)})
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.05 * s, -0.75 * s)
	_body_node.add_child(_tail)
	_segment(_tail, Vector3.ZERO, Vector3(0, 0.1 * s, -0.7 * s), 0.05 * s, fur)
	if kind == "lurker":
		_dust = CPUParticles3D.new()
		_dust.amount = 24
		_dust.lifetime = 0.9
		_dust.emitting = false
		_dust.direction = Vector3.UP
		_dust.spread = 40.0
		_dust.initial_velocity_min = 1.0
		_dust.initial_velocity_max = 2.5
		_dust.gravity = Vector3(0, -4, 0)
		var dq := QuadMesh.new()
		dq.size = Vector2.ONE * 0.3
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		dm.albedo_texture = smoke_tex()
		dm.albedo_color = Color(0.7, 0.6, 0.45, 0.6)
		dq.material = dm
		_dust.mesh = dq
		_dust.position.y = -0.6 * s
		add_child(_dust)
		_buried = 1.0
	# It stands on its legs: lift the body so the feet meet the ground below the round of its collision
	_lift = 0.74 * s - float(spec.radius)
	_body_node.position.y = _lift
	if puppet:
		_buried = 0.0


## The ember sack: a head swollen with fire, glowing through its skin.
func _build_sack() -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.9, 0.35, 0.1, 0.55)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.4, 0.1)
	glow.emission_energy_multiplier = 2.0
	var sack := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.42 * spec.size
	sm.height = 0.84 * spec.size
	sack.mesh = sm
	sack.material_override = glow
	sack.position = Vector3(0, -0.45 * spec.size, -0.1)
	add_child(sack)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = 1.2
	l.omni_range = 4.0
	l.position = sack.position
	add_child(l)


var _name_l: Label3D


## Its name, shown in the colour of the forms when it is hurt or close by.
func _make_name() -> void:
	_name_l = Label3D.new()
	_name_l.text = str(spec.get("name", "")) if boss == "" else ""
	_name_l.font = load("res://assets/fonts/Marcellus-Regular.ttf")
	_name_l.font_size = 36
	_name_l.pixel_size = 0.005
	_name_l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_l.no_depth_test = false
	_name_l.modulate = Color(1.0, 0.55, 0.45, 0.0)
	_name_l.outline_size = 6
	_name_l.outline_modulate = Color(0, 0, 0, 0.0)
	_name_l.position.y = (1.4 if kind == "saucer" else 0.75 * spec.size + 0.55) + (1.1 if kind == "unseen" else 0.0)
	add_child(_name_l)


## The hull of a saucer: a spinning disc ringed with red lights, a glass dome over its head.
func _build_saucer() -> void:
	_disc = Node3D.new()
	add_child(_disc)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.32, 0.31, 0.33)
	steel.metallic = 0.85
	steel.roughness = 0.3
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.95
	tm.bottom_radius = 1.75
	tm.height = 0.32
	top.mesh = tm
	top.material_override = steel
	top.position.y = 0.0
	_disc.add_child(top)
	var under := MeshInstance3D.new()
	var um := CylinderMesh.new()
	um.top_radius = 1.75
	um.bottom_radius = 0.8
	um.height = 0.28
	under.mesh = um
	under.material_override = steel
	under.position.y = -0.3
	_disc.add_child(under)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.12, 0.06)
	for i in 10:
		var a := TAU * i / 10.0
		var lamp := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.09
		lm.height = 0.18
		lamp.mesh = lm
		lamp.material_override = red
		lamp.position = Vector3(cos(a) * 1.68, -0.16, sin(a) * 1.68)
		_disc.add_child(lamp)
	var dome := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.78
	dm.height = 1.56
	dome.mesh = dm
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.2, 0.18, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.4
	glass.roughness = 0.05
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	dome.material_override = glass
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.position.y = 0.4
	add_child(dome)
	_beam = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.6
	bm.bottom_radius = 2.2
	bm.height = 7.0
	_beam.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.albedo_color = Color(1.0, 0.2, 0.12, 0.0)
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = bmat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = -3.9
	add_child(_beam)
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.2, 0.1)
	spot.light_energy = 3.0
	spot.spot_range = 14.0
	spot.spot_angle = 28.0
	spot.rotation_degrees.x = -90
	add_child(spot)


## A red beam falls, and three mites are let down to swarm the seeker.
func _let_down() -> void:
	level.sfx("beam", 0, global_position)
	var m: StandardMaterial3D = _beam.material_override
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.35, 0.3)
	tw.tween_interval(0.9)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	for i in 3:
		var at := global_position + Vector3(randf_range(-0.8, 0.8), -1.2 - i * 0.6, randf_range(-0.8, 0.8))
		_mites.append(level.spawn_at("mite", at))


func _can_see(target: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, target, 1)
	q.exclude = [get_rid(), level.player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _spit(target: Vector3) -> void:
	level.sfx("spit", -6, global_position)
	if randf() < 0.6:
		_cry("screech", -2)
	var b := Bolt.new()
	b.level = level
	b.velocity = (target - global_position).normalized() * 14.0
	level.add_child(b)
	b.global_position = global_position + (target - global_position).normalized() * (spec.radius + 0.2)
	if Net.online:
		Net.bolt(b.global_position, b.velocity, b.damage)


## Returns true if the blow landed with force (false when a gilded face turned it aside).
## A blow that lands on the plate: most of it is soaked and the plate is worn. Piercing rounds go
## through nearly untouched, soft ones are stopped. The head is never covered.
func _on_plate(amount: float) -> float:
	var through := clampf(0.35 * harm_pierce * harm_pierce, 0.1, 1.0) if harm_kind != "blade" else 0.5
	var soak := minf(plate, amount * (1.0 - through))
	plate -= soak
	level.sfx("hit_metal", -6, global_position + Vector3(0, 0.4, 0))
	if plate <= 0.0:
		plate = 0.0
		if _fb:
			_fb.break_plate()
		level.sfx("hit_metal", 0, global_position + Vector3(0, 0.4, 0), 0.7)
	return amount - soak


func hurt(amount: float, from_dir: Vector3) -> bool:
	if not _alive:
		return false
	if harm_kind != "" and boss == "":
		amount *= float(spec.get("weak", {}).get(harm_kind, 1.0)) * float(spec.get("tough", {}).get(harm_kind, 1.0))
	if kind == "lurker" and _buried > 0.5:
		amount *= 0.2
	var full := true
	if kind == "idol":
		var facing := Vector3(sin(head.rotation.y), 0, cos(head.rotation.y))
		var incoming := -from_dir
		incoming.y = 0
		if facing.dot(incoming.normalized()) > 0.35:
			full = false
	_bar_t = 8.0
	var plated := false
	if plate > 0.0 and harm_kind in ["bullet", "shot", "blade"] and not harm_head:
		amount = _on_plate(amount)
		plated = plate > 0.0
	if full and not plated and amount > 0.5:
		bleed(from_dir, amount)
	if puppet:
		# The blow is sent to the host, who alone decides whether the form is undone
		Net.hit(net_id, amount, from_dir)
		_flash = 1.0 if full else 0.3
		return full and not plated
	if not full:
		amount *= 0.12
	if plated:
		full = false   # the hit marker shows it rang off iron
	if _guard and harm_kind in ["bullet", "shot"]:
		var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
		var inc := -from_dir
		inc.y = 0.0
		if fwd.dot(inc.normalized()) > 0.4:
			amount *= 0.3
			full = false
			level.sfx("hit_metal", -4, global_position + Vector3(0, 0.6, 0))
	if _spent > 0.0:
		amount *= 1.6
	if mind != "hunt" and mind != "flee":
		var by: Node3D = level.nearest_target(global_position)
		_alarm(by.global_position if by else global_position)
	hp -= amount
	_flash = 1.0 if full else 0.3
	# Heavy forms barely give ground unless the blow is a heavy one; they slow under fire instead
	var heavy_blow := amount >= 60.0 or harm_kind == "blast"
	var steady := kind in ["idol", "brute", "elite"]
	_knock += from_dir.normalized() * minf(amount, 80.0) * (0.0 if boss != "" else (0.03 if steady and not heavy_blow else (0.08 if kind == "elite" else 0.2)))
	if steady:
		_shot_slow = 0.6
	# Enough harm at once, or a blade to something not too great, and it reels: its bite is broken off
	_dmg_win += amount
	if boss == "" and full and _stagger <= 0.0 and not kind in ["saucer", "unseen"] and \
			(_dmg_win > max_hp * (WRules.stagger_at() if Game.wasteland else 0.3) or (harm_kind == "blade" and spec.hp < 150.0)):
		_stagger = 0.9 if kind != "elite" else 0.6
		_dmg_win = 0.0
		if _wind > 0.0:
			_wind = 0.0
			_show_wind(-1.0)
		if not steady or heavy_blow:
			_knock += from_dir.normalized() * 3.0
	hp_frac = hp / max_hp
	if hp <= 0.0:
		die(true)
	return full


func is_alive() -> bool:
	return _alive


## A spray where the blow landed and a stain on the ground under it, unless blood is turned off.
func bleed(from_dir: Vector3, amount: float) -> void:
	if not Game.blood or Net.dedicated or not is_inside_tree():
		return
	blood_shown += 1
	var c: Color = BLOOD.get(kind, Color(0.34, 0.02, 0.02))
	var r: float = spec.get("radius", 0.5)
	var d := from_dir.normalized() if from_dir.length() > 0.01 else Vector3.FORWARD
	var at := global_position + Vector3(0, r * 1.2, 0) - d * r * 0.8
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = clampi(int(amount * 0.9), 8, 32)
	p.lifetime = 0.8
	p.explosiveness = 0.95
	p.direction = d
	p.spread = 35.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.albedo_texture = _blot_tex()
	q.material = m
	p.mesh = q
	level.add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)
	# A stain on the ground behind, if the blow was a hard one
	if amount >= 8.0 and kind != "saucer" and randf() < 0.6:
		var dec := Decal.new()
		dec.texture_albedo = _blot_tex()
		dec.modulate = Color(c.darkened(0.35), 0.8)
		var s := clampf(0.3 + amount * 0.012, 0.35, 1.0) * maxf(1.0, r * 1.5)
		dec.size = Vector3(s, 1.2, s)
		dec.normal_fade = 0.9
		dec.upper_fade = 0.2
		dec.lower_fade = 0.2
		level.add_child(dec)
		var g := global_position + d * randf_range(0.3, 1.2)
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(g + Vector3(0, 2, 0), g - Vector3(0, 6, 0), 1))
		if not hit.is_empty():
			g.y = hit.position.y
		dec.global_position = g
		dec.rotation.y = randf() * TAU
		var tw := dec.create_tween()
		tw.tween_interval(18.0)
		tw.tween_property(dec, "modulate:a", 0.0, 4.0)
		tw.tween_callback(dec.queue_free)


static func _blot_tex() -> Texture2D:
	if _blot:
		return _blot
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var blobs: Array = [[Vector2(32, 32), 18.0]]
	for i in 7:
		blobs.append([Vector2(32, 32) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(10, 22), rng.randf_range(3, 8)])
	for y in n:
		for x in n:
			var a := 0.0
			for b in blobs:
				a = maxf(a, clampf(1.0 - (Vector2(x, y).distance_to(b[0]) - b[1]) / 3.0, 0.0, 1.0))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_blot = ImageTexture.create_from_image(img)
	return _blot


func die(slain: bool) -> void:
	if not _alive:
		return
	_alive = false
	if kind == "bloater" and slain and not puppet:
		_burst_fire()
	collision_layer = 0
	level.sfx("dissolve", -4, global_position)
	if slain:
		level.sfx("fall_heavy" if spec.get("size", 1.0) >= 1.5 else "fall", -4, global_position)
	var mine := credit if puppet else last_hitter == Net.me()
	if Net.is_host() and not puppet:
		level.foes.erase(net_id)
		Net.foe_died(net_id, slain, last_hitter)
	if slain:
		level.burst(global_position, head.fur)
		if mine:
			level.on_enemy_slain(self)
			if Game.find_emoji(code) and Game.lesser.has(code):
				var e: Dictionary = Game.lesser[code]
				level.hud.notify("Recorded in the Book of Emojis\n%s: %s" % [e.name, e.decree])
		elif not puppet:
			level.team_kill(self)
	died.emit()
	if _fb and slain:
		_fb.act("die")
		var tf := create_tween()
		tf.tween_interval(1.6)
		tf.tween_property(self, "scale", Vector3.ONE * 0.01, 0.6)
		tf.tween_callback(queue_free)
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.4, 0.05, 1.4) if slain else Vector3.ONE * 0.01, 0.35)
	tw.tween_callback(queue_free)


## The ember sack bursts: fire on everything near, the forms included.
func _burst_fire() -> void:
	var at := global_position
	Arms.blast(level, at, 4.0, 40.0, null, "fire")
	Arms.Thrown.burn(level, at, 3.5, 10.0, 5.0, true)
	for t in level.targets():
		var d: float = t.global_position.distance_to(at)
		if d < 4.5:
			level.hurt_target(t, 28.0 * (1.0 - d / 5.5), at)


## A form pressed against something built tears at it.
func _claw_at_wall() -> void:
	if _attack_cd > 0.0 or spec.bite <= 0.0:
		return
	var c := get_last_slide_collision()
	if c and level.on_blocked(self, c.get_collider(), spec.bite * 1.5):
		_attack_cd = 0.9
		level.sfx("bite", -6, global_position, 0.7)


var _cut_off := 0.0
var _sight_t := 0.0


## A form walled off from every pilgrim for long (taken shape behind a wall, or wandered through a gap)
## is drawn back into the open near them, so that every gathering can be finished.
func _rescue(delta: float, idle: bool) -> void:
	if idle or kind == "mite":
		return
	_sight_t -= delta
	if _sight_t > 0.0:
		return
	_sight_t = 0.5
	if level.reachable(global_position):
		_cut_off = 0.0
		return
	_cut_off += 0.5
	if _cut_off >= (6.0 if kind in ["elite", "saucer"] else 10.0):
		_cut_off = 0.0
		var spot = level.open_spot_near(level.focus_pos(), 7.0, 14.0, kind == "saucer")
		if spot != null:
			global_position = spot
			velocity = Vector3.ZERO
			level.sfx("hiss", -6, spot)


## What the host tells the others of this form, fifteen times a second.
## A bite in two beats: it gathers itself (the head swells and glows), then lunges. Out of reach when it
## lands, it misses. Staggered, it does not bite at all.
func _bite_tick(delta: float, p: Node3D, dist: float, dir: Vector3, reach: float, cd: float, dmg: float) -> void:
	if _wind > 0.0:
		_wind -= delta
		_show_wind(1.0 - _wind / maxf(_wind_total, 0.01))
		if _wind <= 0.0:
			_show_wind(-1.0)
			_attack_cd = cd
			_knock += dir * 4.0
			if dist < reach + 0.7:
				level.sfx("bite", -2, global_position)
				if randf() < 0.5:
					_cry("growl_%d" % (randi() % 3), 0)
				level.hurt_target(p, dmg, global_position)
				_knock = -dir * 5.0
			else:
				level.sfx("swing", -8, global_position, 1.4)
		return
	if dist < reach + 0.4 and _attack_cd <= 0.0 and _stagger <= 0.0:
		_wind_total = float(WINDUP.get(kind, 0.35)) / sqrt(Game.difficulty_scale("speed")) * (WRules.windup() if Game.wasteland else 1.0)
		_wind = _wind_total
		_cry("growl_%d" % (randi() % 3), -4)


## The swelling and glow of a gathering bite (k from 0 to 1), or back to rest (k below 0).
func _show_wind(k: float) -> void:
	if k < 0.0:
		head.scale = _head_base
		return
	head.scale = _head_base * (1.0 + 0.2 * sin(k * PI * 0.5))
	head.set_flash(maxf(_flash, 0.2 + 0.4 * k))


## A foe with a body is struck all over it, not only about its middle: a capsule from its feet to the
## crown of its head, as wide as it was (so it walks as it did).
func _fit_shape(cs: CollisionShape3D) -> void:
	var to_me := global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	var top := float(spec.radius)
	for mi in _fb.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var ab: AABB = (to_me * m.global_transform) * m.get_aabb() if is_inside_tree() else m.get_aabb()
		top = maxf(top, ab.end.y)
	var r := float(spec.radius)
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = maxf(2.0 * r, top + 0.12 + r)   # a little over the crown, so a shot at the top of the head lands
	cs.shape = c
	cs.position.y = -r + c.height * 0.5


## Where a shot does the most harm: the head, and how near to its middle counts.
func weak_point() -> Array:
	if not is_instance_valid(head) or kind in ["saucer", "bloater"]:
		return []
	if _fb and is_instance_valid(_fb.head_node) and _fb.head_node is MeshInstance3D:
		# The model's own head, wherever its walk and swing have carried it
		var mh: MeshInstance3D = _fb.head_node
		var ab: AABB = mh.global_transform * mh.get_aabb()
		return [ab.get_center(), 0.45 * maxf(ab.size.x, ab.size.y)]
	return [head.global_position, 0.42 * float(spec.size) * _head_base.x * scale.x]


func net_state() -> Array:
	return [net_id, boss if boss != "" else kind, code, global_position, rotation.y, head.rotation.y, head.rotation.x, _flash, hp / max_hp, _wind > 0.0, _stagger > 0.0]


func net_apply(st: Array) -> void:
	var to: Vector3 = st[3]
	_net_v = (to - _net_to) * 15.0
	_net_to = to
	_net_body_y = st[4]
	_net_head = Vector2(st[5], st[6])
	_flash = maxf(_flash, st[7])
	if st.size() > 8:
		hp_frac = st[8]
	if st.size() > 10:
		_wind = 0.3 if st[9] else 0.0
		_stagger = 0.3 if st[10] else 0.0
	if global_position.distance_to(to) > 6.0:
		global_position = to


## A puppet glides toward where the host says the form is, and keeps its cries and its legs.
func _puppet_tick(delta: float) -> void:
	_t += delta
	global_position = global_position.lerp(_net_to + _net_v * 0.03, minf(1.0, delta * 12.0))
	rotation.y = lerp_angle(rotation.y, _net_body_y, minf(1.0, delta * 12.0))
	head.rotation.y = lerp_angle(head.rotation.y, _net_head.x, minf(1.0, delta * 12.0))
	head.rotation.x = lerpf(head.rotation.x, _net_head.y, minf(1.0, delta * 12.0))
	_flash = maxf(0.0, _flash - delta * 5.0)
	head.set_flash(_flash)
	if _fb:
		var pv := Vector2(_net_v.x, _net_v.z).length()
		_fb.play("sprint" if pv > 4.5 else ("walk" if pv > 0.4 else "idle"))
		if _wind > 0.0 and _fb._once <= 0.0:
			_fb.act("attack-melee-right")
	if _wind > 0.0:
		_wind -= delta
		_show_wind(0.8)
		if _wind <= 0.0:
			_show_wind(-1.0)
	if _stagger > 0.0:
		_stagger -= delta
	head.rotation.z = sin(_t * 18.0) * 0.2 if _stagger > 0.0 else 0.0
	_bar_tick(delta)
	if kind == "saucer" and _disc:
		_disc.rotation.y += delta * 2.5
	if kind == "unseen":
		var d := global_position.distance_to(level.player.global_position)
		_shade_tick(delta, d)
		_unseen_noise(delta, d)
	if kind == "spider":
		var pace := Vector2(_net_v.x, _net_v.z).length()
		for leg in _legs:
			var ph: float = _t * (6.0 + pace * 2.0) + leg.phase
			var amp := minf(0.4, 0.08 + pace * 0.05)
			leg.pivot.rotation.y = sin(ph) * amp
			leg.pivot.rotation.x = maxf(0.0, cos(ph)) * amp * -0.6
	_cry_cd -= delta
	var dist := global_position.distance_to(level.player.global_position)
	if _cry_cd <= 0.0 and dist < 16.0 and not level.combat_frozen and kind != "unseen":
		_cry_cd = randf_range(3.5, 7.0)
		match kind:
			"rusher", "swarm", "idol":
				_cry("shriek_%d" % (randi() % 4), 0 if kind != "swarm" else -6)
			"mite":
				_cry("chitter", -4)
			"elite":
				level.sfx("roar", 0, global_position, randf_range(0.85, 1.05))
			"spitter":
				_cry("growl_%d" % (randi() % 3), -2)
			"spider":
				_cry("skitter" if randf() < 0.5 else "critter_%d" % (randi() % 3), -2)


## The unseen: a long dark figure of bent light, arms to its knees, a narrow head with no face.
func _build_unseen() -> void:
	head.visible = false
	_shimmer = ShaderMaterial.new()
	_shimmer.shader = load("res://scripts/shimmer.gdshader")
	var parts := [
		[CapsuleMesh, Vector3(0, -0.25, 0), Vector3(0.34, 2.3, 0), Vector3.ZERO],
		[CapsuleMesh, Vector3(0, 1.2, 0.04), Vector3(0.19, 0.62, 0), Vector3(0.2, 0, 0)],
		[CapsuleMesh, Vector3(0.42, -0.35, 0.1), Vector3(0.07, 2.1, 0), Vector3(0.15, 0, 0.12)],
		[CapsuleMesh, Vector3(-0.42, -0.35, 0.1), Vector3(0.07, 2.1, 0), Vector3(0.15, 0, -0.12)],
	]
	for pt in parts:
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = pt[2].x
		cm.height = pt[2].y
		mi.mesh = cm
		mi.position = pt[1]
		mi.rotation = pt[3]
		mi.material_override = _shimmer
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## Does the one it hunts look upon it?
func _is_watched(p: Node3D) -> bool:
	var face: Vector3 = -p.global_transform.basis.z if p is Player else p.global_transform.basis.z
	if p is Player and p.cam:
		face = -p.cam.global_transform.basis.z
	var to_it := global_position - (p.global_position + Vector3(0, 1.5, 0))
	face.y = 0.0
	to_it.y = 0.0
	return face.normalized().dot(to_it.normalized()) > 0.85


## Near, or struck, it shows plainly; otherwise it is only a bending of the air.
func _shade_tick(delta: float, dist: float) -> void:
	var want := 0.08
	if dist < 7.0:
		want = lerpf(1.0, 0.08, dist / 7.0)
	want = maxf(want, _flash)
	_seen = lerpf(_seen, want, minf(1.0, delta * 3.0))
	_shimmer.set_shader_parameter("seen", _seen)
	_shimmer.set_shader_parameter("flash", _flash)
	# It sways where it stands, as if listening
	rotation.z = sin(_t * 0.7) * 0.04


func _unseen_noise(delta: float, dist: float) -> void:
	_breath_cd -= delta
	if _cry_cd <= 0.0:
		level.sfx("unseen_call", 0, global_position, randf_range(0.85, 1.05))
		_cry_cd = randf_range(12.0, 20.0)
	if dist < 12.0 and _breath_cd <= 0.0:
		level.sfx("unseen_breath", -4, global_position, randf_range(0.9, 1.1))
		_breath_cd = randf_range(3.0, 5.0)


## A thin bar of life over the form, shown once it has been struck (great ones have theirs across the sight).
func _make_bar() -> void:
	if _bar_mat == null:
		_bar_mat = ShaderMaterial.new()
		_bar_mat.shader = load("res://scripts/foe_bar.gdshader")
	_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(clampf(0.7 * spec.size + 0.3, 0.6, 1.6), 0.09)
	_bar.mesh = q
	_bar.material_override = _bar_mat
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.position.y = (1.25 if kind == "saucer" else 0.75 * spec.size + 0.35) + (1.1 if kind == "unseen" else 0.0)
	_bar.set_instance_shader_parameter("shown", 0.0)
	_bar.visible = false
	add_child(_bar)


func _bar_tick(delta: float) -> void:
	if _name_l:
		var near: bool = _alive and level.player != null and (seen_t > 0.0 or global_position.distance_to(level.player.global_position) < 10.0)
		var a := maxf(clampf(_bar_t, 0.0, 1.0) if _alive else 0.0, 0.85 if near else 0.0) * (1.0 - _buried)
		_name_l.modulate.a = move_toward(_name_l.modulate.a, a, delta * 3.0)
		_name_l.outline_modulate.a = _name_l.modulate.a * 0.8
	if _bar == null:
		return
	_bar_t -= delta
	var show := clampf(_bar_t, 0.0, 1.0) if _alive else 0.0
	_bar.visible = show > 0.0
	if show > 0.0:
		_bar.set_instance_shader_parameter("shown", show)
		_bar.set_instance_shader_parameter("frac", clampf(hp_frac if puppet else hp / max_hp, 0.0, 1.0))


## A great one is a lesser body made vast: its flesh, legs and disc are grown, its shape for collision set by spec.
func _grow_into_boss() -> void:
	var g: float = spec.get("grow", 1.0)
	if g == 1.0:
		return
	for c in get_children():
		if c is Node3D and not c is CollisionShape3D:
			c.scale *= g
			c.position *= g


func is_boss() -> bool:
	return boss != ""


func _ready_way(w: String, cd: float) -> bool:
	if not spec.ways.has(w) or _busy > 0.0 or _spent > 0.0 or _charge_t > 0.0:
		return false
	if _wroth:
		cd *= 0.7
	var t: float = _way_cd.get(w, randf_range(2.0, cd))
	t -= get_physics_process_delta_time() * level.enemy_time
	_way_cd[w] = t
	if t > 0.0:
		return false
	_way_cd[w] = cd * randf_range(0.85, 1.15)
	return true


## The ways of the great ones, run by the host.
func _boss_tick(delta: float, p: Node3D, dist: float) -> void:
	_busy = maxf(0.0, _busy - delta)
	if not _wroth and hp < max_hp * 0.5:
		_wroth = true
		level.sfx("great_roar", 8, global_position, 0.8)
		level.shared("_w_boss_wroth", [boss])
	if dist < 10.0 + spec.radius and _ready_way("slam", 7.5):
		_slam()
	if dist < 40.0 and _ready_way("volley", 4.0):
		# A breath drawn and a glow before the bolts fly
		_busy = 0.6
		_flash = 0.8
		level.sfx("hiss", -2, global_position, 1.3)
		get_tree().create_timer(0.55, false).timeout.connect(func():
			if not _alive or not is_instance_valid(p):
				return
			var target := p.global_position + Vector3(0, 1.2, 0)
			for k in ([-0.4, -0.2, 0.0, 0.2, 0.4] if _wroth else [-0.3, -0.15, 0.0, 0.15, 0.3]):
				_spit(global_position + (target - global_position).rotated(Vector3.UP, k)))
	if dist > 6.0 and dist < 34.0 and _ready_way("charge", 9.0):
		_start_charge(p)
	if dist < 45.0 and _ready_way("rain", 8.0):
		_rain()
	if _ready_way("brood", 9.0):
		_brood = _brood.filter(func(m): return is_instance_valid(m) and m.is_alive())
		if _brood.size() < 6:
			level.sfx("roar", -2, global_position, 1.3)
			for k in 3:
				var at := global_position + Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3))
				var e: LesserSpeeb = level.spawn_at(str(spec.get("brood", "swarm")), at)
				if e:
					_brood.append(e)
	if spec.ways.has("blink"):
		_watched_t = _watched_t + get_physics_process_delta_time() if _watched else 0.0
		if _watched_t > 4.5:
			_watched_t = 0.0
			var back := -p.global_transform.basis.z
			if p is Player and p.cam:
				back = -p.cam.global_transform.basis.z
			back.y = 0.0
			var to := p.global_position - back.normalized() * 7.0 + Vector3(0, 1.5, 0)
			level.sfx("unseen_click", 2, global_position, 0.7)
			global_position = to
			level.sfx("unseen_scream", 0, to, 0.75)
			_seen = 1.0


## The great one strikes the ground: everything near is thrown down, and the earth is seen to break.
func _slam() -> void:
	level.sfx("great_roar", 4, global_position, 1.0)
	_flash = 1.0
	_busy = 1.0
	var at := global_position
	var r: float = 9.0 + spec.radius
	level.shared("_w_warn", [at, r, 0.9, 0])
	get_tree().create_timer(0.9, false).timeout.connect(func():
		if not _alive:
			return
		_spent = 1.2
		level.sfx("boom", 4, at, 0.6)
		level.shared("_w_slam_fx", [at, r])
		for t in level.targets():
			var d: float = t.global_position.distance_to(at)
			if d < r and absf(t.global_position.y - at.y) < 6.0:
				level.hurt_target(t, lerpf(36.0, 12.0, d / r), at))


## The great one marks a line toward a pilgrim, rears, then runs it down. It stands spent at the end.
func _start_charge(p: Node3D) -> void:
	var d := p.global_position - global_position
	d.y = 0.0
	if d.length() < 1.0:
		return
	_charge_dir = d.normalized()
	var reach := minf(d.length() + 8.0, 34.0)
	_busy = 0.9
	_flash = 1.0
	level.sfx("great_roar", 2, global_position, 1.1)
	level.shared("_w_warn", [global_position + _charge_dir * reach * 0.5, reach * 0.5, 0.85, 1, atan2(_charge_dir.x, _charge_dir.z), spec.radius + 1.0])
	get_tree().create_timer(0.85, false).timeout.connect(func():
		if not _alive:
			return
		_charge_t = reach / 24.0
		_charge_hit = {})


## Running the marked line: anyone in the way is struck once and thrown aside.
func _charge_tick(delta: float) -> void:
	_charge_t -= delta
	velocity = _charge_dir * 24.0 * level.enemy_time
	velocity.y = -4.0 if walks() or not kind in ["saucer", "unseen"] else 0.0
	move_and_slide()
	for t in level.targets():
		if _charge_hit.has(t):
			continue
		var off: Vector3 = t.global_position - global_position
		off.y = 0.0
		if off.length() < spec.radius + 1.3:
			_charge_hit[t] = true
			level.hurt_target(t, float(spec.bite) * 0.9 + 10.0, global_position)
	if _charge_t <= 0.0 or is_on_wall():
		_charge_t = 0.0
		_spent = 1.6
		level.sfx("thud", 2, global_position, 0.6)
		level.shared("_w_slam_fx", [global_position, 4.0])


## Marks a burning circle under each pilgrim near, and a few about, then brings fire down on them.
func _rain() -> void:
	_busy = 0.5
	_flash = 0.7
	level.sfx("beam", -2, global_position, 0.7)
	var spots: Array = []
	for t in level.targets():
		if t.global_position.distance_to(global_position) < 50.0:
			spots.append(t.global_position)
			for k in (2 if _wroth else 1):
				spots.append(t.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)))
	for at in spots:
		level.shared("_w_warn", [at, 2.6, 1.3, 2])
	get_tree().create_timer(1.3, false).timeout.connect(func():
		if not _alive:
			return
		for at in spots:
			level.shared("_w_slam_fx", [at, 3.0])
			level.sfx("boom", -4, at, 1.2)
			for t in level.targets():
				var off: Vector3 = t.global_position - at
				if Vector2(off.x, off.z).length() < 2.6 and absf(off.y) < 4.0:
					level.hurt_target(t, 24.0, at))


## A spat bolt of burning light.
class Bolt extends Area3D:
	var velocity := Vector3.ZERO
	var damage := 13.0
	var level: Level
	var life := 4.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		var cs := CollisionShape3D.new()
		var s := SphereShape3D.new()
		s.radius = 0.22
		cs.shape = s
		add_child(cs)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.35, 0.2)
		mi.material_override = m
		add_child(mi)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.3, 0.15)
		l.light_energy = 1.2
		l.omni_range = 3.5
		add_child(l)
		body_entered.connect(_hit)

	func _physics_process(delta: float) -> void:
		global_position += velocity * delta * level.enemy_time
		life -= delta * level.enemy_time
		if life <= 0.0:
			queue_free()

	func _hit(b: Node) -> void:
		if b is Player:
			level.damage_player(damage, global_position)
		queue_free()


# ------------------------------------------------------------------ foes with bodies of their own

## How the Unlit and the dead move and fight. Melee foes close in and spread around their prey
## instead of queueing; a gunman keeps its distance, draws a bead and fires in bursts, reloads, and
## backs off when badly hurt; the Lost Vigil drifts through the air.
## Whether it can see the pilgrim: near enough (less at night, or treading softly), in front of it
## (or very close), and nothing in the way.
func sees(p: Node3D) -> bool:
	var to := p.global_position - global_position
	var d := to.length()
	var reach := 48.0 if spec.get("role", "") == "gun" else 34.0
	if level.get("night"):
		reach *= 0.6
	if p == level.player and Input.is_action_pressed("soft"):
		reach *= 0.55
	if d > reach:
		return false
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var flat := Vector3(to.x, 0, to.z).normalized()
	if d > 6.0 and fwd.dot(flat) < 0.2:
		return false
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.8, 0), p.global_position + Vector3(0, 1.3, 0))
	q.exclude = [get_rid(), p.get_rid()]
	q.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## A noise at a place, carrying radius far. Near, it knows where it came from; further, it goes to look.
func hear(at: Vector3, radius: float) -> void:
	if not _alive or puppet or mind == "hunt" or mind == "flee" or _fb == null:
		return
	var d := global_position.distance_to(at)
	if d > radius:
		return
	if d < radius * 0.3:
		_alarm(at)
	else:
		mind = "search"
		_search_t = 14.0
		_last_known = at + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * d * 0.15
		_show_mark("?")


## Sent to look somewhere (the night's walkers, drawn to the living).
func seek(at: Vector3, for_t: float) -> void:
	if _fb == null or mind == "hunt":
		return
	mind = "search"
	_search_t = for_t
	_last_known = at


## It knows where the pilgrim is, and calls the others of its band near it.
func _alarm(at: Vector3, call := true) -> void:
	if mind == "hunt" or mind == "flee":
		return
	mind = "hunt"
	_last_known = at
	_lost_t = 0.0
	_show_mark("!")
	if kind.begins_with("unlit"):
		_cry("growl_%d" % (randi() % 3), -4)
	if call:
		for e in level.enemies:
			if is_instance_valid(e) and e != self and e.get("_fb") != null and e.global_position.distance_to(global_position) < 22.0:
				e._alarm(at, false)


func _show_mark(t: String) -> void:
	if _mark == null:
		_mark = Label3D.new()
		_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_mark.no_depth_test = true
		_mark.font_size = 96
		_mark.outline_size = 18
		_mark.pixel_size = 0.006
		_mark.position.y = float(spec.get("head_y", 1.0)) + 1.0
		add_child(_mark)
	_mark.text = t
	_mark.modulate = Color(1, 0.35, 0.2) if t == "!" else Color(1, 0.85, 0.4)
	_mark.visible = true
	_mark_t = 2.5


## The foe's mind, each frame: what it notices, and where it goes when it is not hunting.
## Returns the way it wants to go, or null when it hunts and the usual closing in applies.
func _think(delta: float, p: Node3D, fd: float, speed: float):
	_mark_t -= delta
	if _mark and _mark_t <= 0.0:
		_mark.visible = false
	if has_meta("raid") or not Game.wasteland or boss != "":
		mind = "hunt"
		return null
	_look_t -= delta
	var seen := false
	if _look_t <= 0.0:
		_look_t = 0.3
		seen = sees(p)
		if seen:
			_last_known = p.global_position
			_lost_t = 0.0
			if mind in ["calm", "search"]:
				_alarm(p.global_position)
		elif mind == "hunt":
			_lost_t += 0.3
	if mind == "hunt" and fd < 5.0:
		_lost_t = 0.0   # close enough to hear its breathing
	# Badly hurt, an Unlit breaks off and runs, once, then comes back at you
	if mind == "hunt" and not _fled and kind.begins_with("unlit") and hp < max_hp * 0.3:
		_fled = true
		mind = "flee"
		_flee_t = 5.0
	match mind:
		"flee":
			_flee_t -= delta
			if _flee_t <= 0.0:
				mind = "hunt"
				return null
			var away := global_position - p.global_position
			away.y = 0.0
			return away.normalized() * speed * 1.15
		"hunt":
			if _lost_t > 7.0:
				mind = "search"
				_search_t = 12.0
				_show_mark("?")
			return null
		"search":
			_search_t -= delta
			if _search_t <= 0.0:
				mind = "calm"
				_home = global_position
				_wander = global_position
				return Vector3.ZERO
			var to := _last_known - global_position
			to.y = 0.0
			if to.length() > 2.0:
				return to.normalized() * speed * 0.7
			# There: it turns about, looking
			rotation.y += delta * 1.2
			return Vector3.ZERO
		_:
			var to := _wander - global_position
			to.y = 0.0
			if to.length() < 1.0:
				if randf() < delta * 0.25:
					_wander = _home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
				return Vector3.ZERO
			return to.normalized() * speed * 0.3


func _foe_move(delta: float, p: Node3D, dist: float, dir: Vector3, frozen: bool) -> void:
	var role: String = spec.get("role", "melee")
	var flat := p.global_position - global_position
	flat.y = 0.0
	var fd := flat.length()
	var fdir := flat / maxf(fd, 0.01)
	var speed: float = spec.speed * Game.difficulty_scale("speed") * (0.55 if _shot_slow > 0.0 else 1.0) * (0.6 if _guard else 1.0)
	_shot_slow = maxf(0.0, _shot_slow - delta)
	_flash = maxf(0.0, _flash - delta * 5.0)
	_bar_tick(delta)
	var want := Vector3.ZERO
	var hurt_bad := hp < max_hp * 0.35
	var away = null if frozen else _think(delta, p, fd, speed)
	if away != null:
		# Not hunting: it goes its own way, faces where it walks, and strikes at nothing
		_guard = false
		if role == "float":
			away.y = sin(_t * 1.7) * 0.4
			velocity = velocity.lerp(away, minf(1.0, delta * 3.0))
		else:
			velocity.x = lerpf(velocity.x, away.x, minf(1.0, delta * 6.0))
			velocity.z = lerpf(velocity.z, away.z, minf(1.0, delta * 6.0))
			velocity.y -= 22.0 * delta
		if Vector2(away.x, away.z).length() > 0.2:
			rotation.y = lerp_angle(rotation.y, atan2(away.x, away.z), minf(1.0, delta * 6.0))
		move_and_slide()
		if is_on_floor() and velocity.y < 0.0:
			velocity.y = 0.0
		if is_on_wall() and role != "float":
			velocity.y = 3.5
		var pc := Vector2(velocity.x, velocity.z).length()
		_fb.play("sprint" if pc > 4.5 else ("walk" if pc > 0.4 else "idle"), clampf(pc / 3.0, 0.7, 1.6) if pc > 0.4 else 1.0)
		return
	if not frozen:
		match role:
			"gun":
				var keep := 30.0 if hurt_bad else 18.0
				var side := fdir.cross(Vector3.UP) * _strafe
				if fd > keep + 6.0:
					want = fdir * speed
				elif fd < keep - 6.0:
					want = -fdir * speed * 0.9 + side * 1.5
				else:
					want = side * speed * 0.6
				if randf() < delta * 0.3:
					_strafe = -_strafe
			"float":
				want = fdir * speed
				want.y = (p.global_position.y + 1.2 - global_position.y) * 1.5 + sin(_t * 1.7) * 0.6
			_:
				# Close from its own side: a ring about the prey, each foe to its own place on it
				var slot := p.global_position + Vector3(cos(_flank), 0, sin(_flank)) * (1.6 if fd < 6.0 else 5.0)
				var to_slot := slot - global_position
				to_slot.y = 0.0
				want = (fdir if fd > 12.0 else to_slot.normalized()) * speed * (1.0 if fd > 3.0 else 0.6)
				if fd < 1.2 + spec.radius:
					want = Vector3.ZERO
				# An Unlit Blade raises its guard against a gun pointed at it
				if kind == "unlit_blade":
					var aim_at: bool = p == level.player and fd > 3.5 and fd < 18.0 and (-level.player.cam.global_transform.basis.z).dot(-fdir) > 0.93
					_guard = aim_at and _wind <= 0.0
		if role == "float":
			velocity = velocity.lerp(want, minf(1.0, delta * 3.0))
		elif is_on_floor():
			velocity.x = lerpf(velocity.x, want.x, minf(1.0, delta * 8.0))
			velocity.z = lerpf(velocity.z, want.z, minf(1.0, delta * 8.0))
		rotation.y = lerp_angle(rotation.y, atan2(fdir.x, fdir.z), minf(1.0, delta * 8.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 20.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 20.0)
	if role != "float":
		velocity.y -= 22.0 * delta
	velocity += _knock - _knock_on
	_knock_on = _knock
	_knock = _knock.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))
	var real_v := velocity
	velocity *= level.enemy_time
	move_and_slide()
	velocity = real_v
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	if is_on_wall() and not frozen and role != "float":
		velocity.y = 3.5
	var pace := Vector2(velocity.x, velocity.z).length()
	_fb.play("sprint" if pace > 4.5 else ("walk" if pace > 0.4 else ("holding-both" if role == "gun" and fd < 40.0 else "idle")), clampf(pace / 3.0, 0.7, 1.6) if pace > 0.4 else 1.0)
	if frozen or level.completed or level.failing:
		return
	_attack_cd -= delta
	_cry_cd -= delta
	if _cry_cd <= 0.0 and dist < 18.0:
		_cry_cd = randf_range(4.0, 8.0)
		match kind:
			"hollow", "warden":
				_cry("troll", -6)
			"vigil":
				_cry("whispers", -8)
			"saltbone":
				_cry("skitter", -4)
	if role == "gun":
		_gun_tick(delta, p, dist)
		return
	var reach: float = 1.3 + spec.radius
	_foe_strike(delta, p, dist, dir, reach)


## A melee foe's blow: it raises its arm (the warning), and strikes if you are still in reach. A
## pilgrim who turns the blow with a raised guard staggers it, and it stands open a while.
func _foe_strike(delta: float, p: Node3D, dist: float, dir: Vector3, reach: float) -> void:
	if _wind > 0.0:
		_wind -= delta
		if _wind <= 0.0:
			_attack_cd = 2.2 if kind in ["unlit_brute", "knight", "colossus"] else 1.3
			if dist < reach + 0.7:
				var turned := false
				if p == level.player and level.player.weapon and level.player.weapon.guarding:
					var pf := -level.player.global_transform.basis.z
					var to := global_position - level.player.global_position
					to.y = 0.0
					turned = pf.dot(to.normalized()) > 0.4
				if turned:
					# Parried: the blade is turned, the foe reels, and the pilgrim's stamina pays a little
					level.sfx("parry", 0, global_position)
					_stagger = 1.3
					_wind = 0.0
					level.player.spend(8.0)
					level.player.shake(0.2)
					level.hud.hitmarker(false, true)
					_knock = -dir * 3.0
				else:
					level.sfx("chop" if kind.begins_with("unlit") or kind in ["warden", "knight"] else "bite", -3, global_position)
					level.hurt_target(p, spec.bite, global_position)
					_afflict(p)
			else:
				level.sfx("swing", -6, global_position, 0.9)
		return
	if dist < reach + 0.4 and _attack_cd <= 0.0 and _stagger <= 0.0:
		_wind_total = float(WINDUP.get(kind, 0.5)) / sqrt(Game.difficulty_scale("speed")) * (WRules.windup() if Game.wasteland else 1.0)
		_wind = _wind_total
		_guard = false
		_fb.act("attack-melee-right", 0.55 / maxf(_wind_total, 0.2))
		level.sfx("swing", -10, global_position, 0.8)


## What a blow leaves behind: fire, tar on the legs, or the foe's own wounds closing.
func _afflict(p: Node3D) -> void:
	if spec.has("drain"):
		hp = minf(max_hp, hp + float(spec.bite) * float(spec.drain))
	if p == level.player and level.has_method("afflict"):
		if spec.has("burn"):
			level.afflict("burn", float(spec.burn))
		if spec.has("slow"):
			level.afflict("slow", float(spec.slow))


## A gunman: it draws a bead with a glint at the muzzle (the warning), then fires a short burst.
## Each shot may miss, more so at range and against a moving target. It reloads after nine.
func _gun_tick(delta: float, p: Node3D, dist: float) -> void:
	if _aim > 0.0:
		_aim -= delta
		if _aim <= 0.0:
			_burst = int(spec.get("burst", 3))
			_attack_cd = 0.0
		return
	if _burst > 0:
		_attack_cd -= delta
		if _attack_cd <= 0.0:
			_attack_cd = 0.16
			_burst -= 1
			_ammo -= 1
			_shoot_at(p, dist)
			if _ammo <= 0:
				_ammo = int(spec.get("mag", 9))
				_burst = 0
				_attack_cd = 2.6
				level.sfx("pump", -6, global_position, 0.9)
			elif _burst == 0:
				_attack_cd = randf_range(1.4, 2.4)
		return
	if _attack_cd <= 0.0 and dist < float(spec.get("sight", 45.0)) and _can_see(p.global_position + Vector3(0, 1.3, 0)):
		_aim = float(spec.get("aim", 0.75))
		level.shared("_w_glint", [net_id])


func _shoot_at(p: Node3D, dist: float) -> void:
	var from: Vector3 = _fb.muzzle.global_position if _fb and _fb.muzzle else global_position + Vector3(0, 0.6, 0)
	var at := p.global_position + Vector3(0, 1.2, 0)
	var moving := 0.0
	if p is CharacterBody3D:
		moving = Vector2(p.velocity.x, p.velocity.z).length()
	var miss := clampf((0.2 + dist * 0.012 + moving * 0.04) * float(spec.get("aimed", 1.0)), 0.1, 0.8)
	var hit := randf() > miss
	if not hit:
		at += Vector3(randf_range(-1.5, 1.5), randf_range(-0.8, 1.2), randf_range(-1.5, 1.5))
	_fb.act("holding-both-shoot")
	level.sfx("mg", -4, from, 0.85)
	level.shared("_w_tracer", [from, at])
	if hit:
		level.hurt_target(p, spec.bite, from)
