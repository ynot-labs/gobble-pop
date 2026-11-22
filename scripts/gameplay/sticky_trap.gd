extends Node3D
class_name StickyTrap

var trap_radius: float = 0.92
var _mat: ShaderMaterial
var _cleared: bool = false


func setup(spawn_pos: Vector3, world_id: int = 1) -> void:
	position = spawn_pos

	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/sticky_gum.gdshader")
	if world_id == 3:
		_mat.set_shader_parameter("gum_color", Color("#FFC107"))
		_mat.set_shader_parameter("highlight_color", Color("#FFF3B0"))
	elif world_id == 4:
		_mat.set_shader_parameter("gum_color", Color("#39FF14"))
		_mat.set_shader_parameter("highlight_color", Color("#C8FFBE"))

	if ResourceLoader.exists("res://assets/models/world1/w1_09_bubblegum.glb"):
		var packed: PackedScene = load("res://assets/models/world1/w1_09_bubblegum.glb")
		if packed:
			var inst := packed.instantiate()
			inst.rotation.y = randf() * TAU
			_apply_shader_recursive(inst, _mat)
			add_child(inst)
			return

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = trap_radius
	cyl.bottom_radius = trap_radius * 1.08
	cyl.height = 0.08
	cyl.radial_segments = 24
	mesh_inst.mesh = cyl
	mesh_inst.position.y = 0.04
	mesh_inst.material_override = _mat
	add_child(mesh_inst)


func _apply_shader_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_shader_recursive(child, mat)


func step_interaction(hole: HoleController, level_number: int) -> void:
	if _cleared:
		return
	var diff := Vector3(hole.position.x - position.x, 0.0, hole.position.z - position.z)
	var dist := diff.length()
	var trigger_dist := trap_radius + hole.current_radius * 0.55

	if dist < trigger_dist:
		hole.apply_sticky_slow(DDAController.get_sticky_slow_duration(level_number))
		var pull := diff.normalized() * minf(dist, 0.9)
		_mat.set_shader_parameter("pull_offset", pull)
		_mat.set_shader_parameter("pull_strength", 0.75)
	else:
		_mat.set_shader_parameter("pull_strength", 0.0)


func pop_and_clear() -> void:
	if _cleared:
		return
	_cleared = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.35, 1.35, 1.35), 0.12)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.16)
	tw.tween_callback(queue_free)
