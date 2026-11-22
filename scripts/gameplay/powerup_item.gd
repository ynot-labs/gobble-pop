extends Node3D
class_name PowerupItem

signal collected(kind: String, world_pos: Vector3)

var kind: String = "ice" # "ice" or "magnet"
var _collected: bool = false
var _visual: Node3D
var _phase: float = 0.0


func setup(p_kind: String, spawn_pos: Vector3) -> void:
	kind = p_kind
	position = spawn_pos
	_phase = randf() * TAU

	_visual = Node3D.new()
	add_child(_visual)

	var model_path := "res://assets/models/core/core_03_ice_cube.glb" if kind == "ice" else "res://assets/models/core/core_04_magnet.glb"
	if ResourceLoader.exists(model_path):
		var packed: PackedScene = load(model_path)
		if packed:
			_visual.add_child(packed.instantiate())
			return

	var mat := StandardMaterial3D.new()
	if kind == "ice":
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.68, 0.68, 0.68)
		box.mesh = bm
		mat.albedo_color = Color(0.32, 0.88, 1.0, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.1
		mat.emission_enabled = true
		mat.emission = Color(0.18, 0.72, 1.0)
		mat.emission_energy_multiplier = 0.55
		box.material_override = mat
		box.position.y = 0.42
		_visual.add_child(box)
	else:
		var m := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.outer_radius = 0.48
		tor.inner_radius = 0.25
		m.mesh = tor
		mat.albedo_color = Color("#FF3B5C")
		mat.roughness = 0.2
		mat.emission_enabled = true
		mat.emission = Color("#4CC9F0")
		mat.emission_energy_multiplier = 0.35
		m.material_override = mat
		m.position.y = 0.44
		_visual.add_child(m)


func step_interaction(hole: HoleController, delta: float) -> void:
	if _collected:
		return
	_phase += delta * 3.0
	_visual.position.y = sin(_phase) * 0.12
	_visual.rotation.y += delta * 1.6

	var d := Vector2(hole.position.x - position.x, hole.position.z - position.z).length()
	if d < hole.get_suction_radius() + 0.35:
		_collected = true
		collected.emit(kind, position)
		queue_free()
