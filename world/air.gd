class_name WAir
extends Node3D
## Each land's own air: the colour and thickness of its haze, and what drifts in it about the pilgrim.
## Ash flakes on the Ash Plains, blown red sand in the Rust Dunes, glints over the Salt Flats, spores
## in the Dead Forest, embers over the Basalt Heights, and low mist and marsh-lights in the Tar Marsh.

const LOOK := {
	# fog tint by day, how much thicker than plain, what drifts: [colour, size, count, fall, sideways, glow]
	"ash": {"fog": Color(0.56, 0.53, 0.5), "thick": 1.3, "drift": [Color(0.32, 0.3, 0.29, 0.85), 0.06, 70, -0.5, 0.4, false]},
	"dunes": {"fog": Color(0.8, 0.58, 0.38), "thick": 1.1, "drift": [Color(0.72, 0.45, 0.28, 0.5), 0.04, 120, -0.2, 3.5, false]},
	"salt": {"fog": Color(0.86, 0.88, 0.9), "thick": 0.65, "drift": [Color(1.0, 1.0, 1.0, 0.9), 0.035, 50, 0.05, 0.3, true]},
	"forest": {"fog": Color(0.42, 0.49, 0.43), "thick": 1.9, "drift": [Color(0.75, 0.82, 0.55, 0.7), 0.05, 60, 0.12, 0.25, true]},
	"basalt": {"fog": Color(0.5, 0.38, 0.34), "thick": 1.35, "drift": [Color(1.0, 0.45, 0.15, 1.0), 0.05, 45, 0.6, 0.5, true]},
	"marsh": {"fog": Color(0.42, 0.47, 0.4), "thick": 2.3, "drift": [Color(0.7, 0.95, 0.55, 1.0), 0.06, 35, 0.08, 0.35, true]},
}

var w
var land := ""
var tint := Color(0.62, 0.55, 0.46)
var thick := 1.0
var _want_tint := tint
var _want_thick := 1.0
var _t := 0.0
var _drift: CPUParticles3D
var _mist: CPUParticles3D
var _mat: StandardMaterial3D


func setup(world) -> WAir:
	w = world
	return self


func _ready() -> void:
	_drift = CPUParticles3D.new()
	_drift.amount = 120
	_drift.lifetime = 6.0
	_drift.preprocess = 6.0
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	_drift.mesh = q
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_texture = Relics._soft_dot()
	_drift.material_override = _mat
	_drift.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_drift.emission_box_extents = Vector3(22, 7, 22)
	_drift.local_coords = false
	_drift.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drift)
	# The marsh's mist lies low on the water, in slow banks
	_mist = CPUParticles3D.new()
	_mist.amount = 24
	_mist.lifetime = 14.0
	_mist.preprocess = 14.0
	var mq := QuadMesh.new()
	mq.size = Vector2(9, 9)
	_mist.mesh = mq
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.vertex_color_use_as_albedo = true
	mm.albedo_texture = Relics._soft_dot()
	_mist.material_override = mm
	_mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_mist.emission_box_extents = Vector3(30, 0.6, 30)
	_mist.local_coords = false
	_mist.gravity = Vector3(0.3, 0, 0.1)
	_mist.color = Color(0.75, 0.8, 0.72, 0.16)
	_mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mist.emitting = false
	add_child(_mist)


func _process(delta: float) -> void:
	if w == null or w.player == null or w.terrain == null or Net.dedicated:
		return
	var p: Vector3 = w.player.global_position
	_drift.global_position = p + Vector3(0, 2.0, 0)
	_mist.global_position = Vector3(p.x, w.terrain.height_at(p.x, p.z) + 0.6, p.z)
	_t -= delta
	if _t <= 0.0:
		_t = 0.5
		var under: bool = w.hall != null and w.hall.inside(p)
		var bn: String = "" if under else w.land_at(p)
		if not LOOK.has(bn):
			bn = ""
		if bn != land:
			land = bn
			_set_drift()
		# The haze is the land's own, blended across the border between lands
		var wts: PackedFloat32Array = w.terrain.weights(p.x, p.z)
		var c := Color(0, 0, 0)
		var th := 0.0
		for i in 6:
			var lk: Dictionary = LOOK[WTerrain.BIOMES[i]]
			c += lk.fog * wts[i]
			th += float(lk.thick) * wts[i]
		_want_tint = c if bn != "" else Color(0.62, 0.55, 0.46)
		_want_thick = th if bn != "" else 1.0
	tint = tint.lerp(_want_tint, minf(1.0, delta * 0.6))
	thick = lerpf(thick, _want_thick, minf(1.0, delta * 0.6))


func _set_drift() -> void:
	if land == "":
		_drift.emitting = false
		_mist.emitting = false
		return
	var d: Array = LOOK[land].drift
	_drift.emitting = true
	_drift.amount = int(d[2])
	_drift.color = d[0]
	_drift.scale_amount_min = float(d[1]) * 0.6 / 1.0
	_drift.scale_amount_max = float(d[1]) * 1.4
	_drift.gravity = Vector3(float(d[4]), float(d[3]), float(d[4]) * 0.4)
	_drift.initial_velocity_min = 0.0
	_drift.initial_velocity_max = 0.3
	_drift.direction = Vector3(1, 0, 0.3)
	_drift.spread = 180.0
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if d[5] else BaseMaterial3D.BLEND_MODE_MIX
	_mist.emitting = land == "marsh" or land == "forest"


## The land's haze laid over the hour's: called after the sun and sky are set.
func apply_env(env: Environment, day_k: float) -> void:
	env.fog_light_color = env.fog_light_color.lerp(tint.lerp(env.fog_light_color, 1.0 - day_k), 0.65)
	env.fog_density *= thick
