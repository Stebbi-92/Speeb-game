class_name Velm
extends Node3D
## Velm, the hermit who went before. A hooded shape at the edge of the fog that is gone when looked at twice.

var _mats: Array = []


func _ready() -> void:
	var robe := StandardMaterial3D.new()
	robe.albedo_color = Color(0.03, 0.03, 0.035)
	robe.roughness = 1.0
	robe.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats.append(robe)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.5
	cm.height = 1.75
	body.mesh = cm
	body.material_override = robe
	body.position.y = 0.875
	add_child(body)
	var hood := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.58
	hood.mesh = sm
	hood.material_override = robe
	hood.position = Vector3(0, 1.95, 0.0)
	add_child(hood)
	var eye_m := StandardMaterial3D.new()
	eye_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_m.albedo_color = Color(0.85, 0.88, 0.95)
	eye_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats.append(eye_m)
	for sx in [-0.07, 0.07]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.02
		em.height = 0.04
		e.mesh = em
		e.material_override = eye_m
		e.position = Vector3(sx, 1.95, 0.2)
		add_child(e)
	for c in find_children("*", "MeshInstance3D", true, false):
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_alpha(0.0)


func set_alpha(a: float) -> void:
	for m in _mats:
		m.albedo_color.a = a


func appear(dur := 1.5) -> void:
	visible = true
	var tw := create_tween()
	tw.tween_method(set_alpha, 0.0, 0.92, dur)


## Gone between one glance and the next.
func vanish() -> void:
	set_alpha(0.0)
	visible = false
