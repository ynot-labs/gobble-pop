extends Node3D
class_name BombHazard

signal detonated(world_pos: Vector3, penalty_sec: float)

## World 3 & World 4 Candy Time Bomb Hazard: Lv.1 swallowable, blasts -3.0s if accidentally eaten!
## Cleared harmlessly with a celebratory pop when player uses RV Rescue!

const TIME_PENALTY: float = 3.0

var _triggered: bool = false
var _visual: Node3D
var _phase: float = 0.0
var _warn_ring: MeshInstance3D


func setup(spawn_pos: Vector3) -> void:
	position = spawn_pos
	_phase = randf() * TAU

	_visual = Node3D.new()
	add_child(_visual)

	# Soft coral warning ring on tabletop (gentle breathing, zero harsh strobe)
	_warn_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.outer_radius = 0.58
	tor.inner_radius = 0.50
	_warn_ring.mesh = tor
	_warn_ring.position.y = 0.036
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.84, 0.28, 0.28, 0.65)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warn_ring.material_override = rmat
	add_child(_warn_ring)

	var lbl := Label3D.new()
	lbl.text = "-3s"
	lbl.font_size = 44
	lbl.outline_size = 12
	lbl.modulate = Color("#D64545")
	lbl.outline_modulate = Color("#FAF7F2")
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 1.24, 0.0)
	add_child(lbl)

	if ResourceLoader.exists("res://assets/models/core/core_05_bomb.glb"):
		var p: PackedScene = load("res://assets/models/core/core_05_bomb.glb")
		if p:
			_visual.add_child(p.instantiate())
			return

	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.40
	sp.height = 0.80
	mi.mesh = sp
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#1E293B")
	mi.material_override = mat
	mi.position.y = 0.40
	_visual.add_child(mi)


func step_interaction(hole: HoleController, delta: float) -> void:
	if _triggered:
		return
	_phase += delta * 2.6
	var pulse := 1.0 + sin(_phase) * 0.05
	_visual.scale = Vector3.ONE * pulse
	_warn_ring.scale = Vector3(1.0 + sin(_phase * 1.1) * 0.08, 1.0, 1.0 + sin(_phase * 1.1) * 0.08)

	var d := Vector2(hole.position.x - position.x, hole.position.z - position.z).length()
	if d < maxf(0.45, hole.current_radius * 0.72):
		_triggered = true
		detonated.emit(position, TIME_PENALTY)
		queue_free()


func pop_and_clear() -> void:
	if _triggered:
		return
	_triggered = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ZERO, 0.18)
	tw.tween_callback(queue_free)
