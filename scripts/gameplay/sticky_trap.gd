extends Node3D
class_name StickyTrap

var trap_radius: float = 0.94
var trap_color: Color = Color("#D85B88")
var trap_label: String = "STICKY GUM!"
var _mat: ShaderMaterial
var _cleared: bool = false
var _cooldown: float = 0.0
var _pulse: float = 0.0


func setup(spawn_pos: Vector3, world_id: int = 1) -> void:
	position = spawn_pos
	_pulse = randf() * TAU

	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/sticky_gum.gdshader")
	var model_path := "res://assets/models/world1/w1_09_bubblegum.glb"

	if world_id == 3:
		trap_color = Color("#FFC229")
		trap_label = "MELTED CHEESE!"
		_mat.set_shader_parameter("gum_color", Color("#FFC229"))
		_mat.set_shader_parameter("highlight_color", Color("#FFF6C4"))
		model_path = "res://assets/models/world3/w3_06_cheese.glb"
	elif world_id == 4:
		trap_color = Color("#38E578")
		trap_label = "STICKY SLIME!"
		_mat.set_shader_parameter("gum_color", Color("#38E578"))
		_mat.set_shader_parameter("highlight_color", Color("#D8FFE6"))
		model_path = "res://assets/models/world4/w4_07_slime_trap.glb"
	else:
		trap_color = Color("#FF52A8")
		trap_label = "STICKY GUM!"
		_mat.set_shader_parameter("gum_color", Color("#FF52A8"))
		_mat.set_shader_parameter("highlight_color", Color("#FFDDF2"))

	if ResourceLoader.exists(model_path):
		var packed: PackedScene = load(model_path)
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


func step_interaction(hole: HoleController, level_number: int, delta: float) -> void:
	if _cleared:
		return
	_pulse += delta * 3.2
	var s := 1.0 + sin(_pulse) * 0.05
	scale = Vector3(s, 1.0, s)

	if _cooldown > 0.0:
		_cooldown = maxf(_cooldown - delta, 0.0)

	var diff := Vector3(hole.position.x - position.x, 0.0, hole.position.z - position.z)
	var dist := diff.length()
	var trigger_dist := trap_radius * 0.78 + hole.current_radius * 0.72

	if dist < trigger_dist and _cooldown <= 0.0:
		_cooldown = 3.1
		hole.trigger_sticky_trap(self, DDAController.get_sticky_slow_duration(level_number), trap_color, trap_label)

	if hole.sticky_timer > 0.0 and hole.active_gum_trap == self:
		var pull := diff.normalized() * minf(dist, 1.15) if dist > 0.05 else Vector3.ZERO
		_mat.set_shader_parameter("pull_offset", pull)
		_mat.set_shader_parameter("pull_strength", 0.85)
	else:
		_mat.set_shader_parameter("pull_strength", 0.0)


func pop_and_clear() -> void:
	if _cleared:
		return
	_cleared = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.38, 1.38, 1.38), 0.10)
	tw.tween_property(self, "scale", Vector3.ZERO, 0.15)
	tw.tween_callback(queue_free)
