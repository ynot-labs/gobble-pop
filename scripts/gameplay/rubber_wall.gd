extends Node3D
class_name RubberWall

## World 2 Elastic Rubber Band Barrier Wall: blocks hole shortcuts with juicy spring recoil + twang!

var half_length: float = 1.95
var thickness: float = 0.28
var _visual: Node3D
var _twang_amp: float = 0.0
var _twang_phase: float = 0.0
var _bounce_cd: float = 0.0


func setup(spawn_pos: Vector3, rot_deg: float) -> void:
	position = spawn_pos
	rotation_degrees.y = rot_deg
	_visual = Node3D.new()
	add_child(_visual)

	if ResourceLoader.exists("res://assets/models/world2/w2_08_rubber_wall.glb"):
		var p: PackedScene = load("res://assets/models/world2/w2_08_rubber_wall.glb")
		if p:
			_visual.add_child(p.instantiate())
			return

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(half_length * 2.0, 0.55, thickness)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#A855F7")
	mat.roughness = 0.2
	mi.material_override = mat
	mi.position.y = 0.28
	_visual.add_child(mi)


func step_interaction(hole: HoleController, delta: float) -> bool:
	if _bounce_cd > 0.0:
		_bounce_cd -= delta
	if _twang_amp > 0.001:
		_twang_phase += delta * 36.0
		_twang_amp = maxf(_twang_amp - delta * 2.8, 0.0)
		_visual.scale = Vector3(1.0, 1.0, 1.0 + sin(_twang_phase) * _twang_amp)
	else:
		_visual.scale = Vector3.ONE

	# Transform hole into wall local XZ space
	var rel := hole.position - position
	var ang := -rotation.y
	var ca := cos(ang)
	var sa := sin(ang)
	var lx := rel.x * ca - rel.z * sa
	var lz := rel.x * sa + rel.z * ca

	# Closest point on the finite wall segment [-half_length, +half_length]
	var cx := clampf(lx, -half_length, half_length)
	var dx := lx - cx
	var dz := lz
	var dist := sqrt(dx * dx + dz * dz)
	var min_dist := hole.current_radius * 0.88 + thickness

	if dist < min_dist:
		var nx := 0.0
		var nz := 1.0 if lz >= 0.0 else -1.0
		if dist > 0.001:
			nx = dx / dist
			nz = dz / dist
		var push := min_dist - dist + 0.05
		# Transform normal back to world XZ
		var wa := rotation.y
		var wca := cos(wa)
		var wsa := sin(wa)
		var wnx := nx * wca - nz * wsa
		var wnz := nx * wsa + nz * wca

		hole.position.x += wnx * push
		hole.position.z += wnz * push
		# Juicy elastic spring recoil impulse!
		hole.apply_rubber_bounce(Vector3(wnx, 0.0, wnz))
		if _bounce_cd <= 0.0:
			_bounce_cd = 0.22
			_twang_amp = 0.55
			_twang_phase = 0.0
			AudioManager.play_sfx("sticky", 1.55)
			return true
	return false
