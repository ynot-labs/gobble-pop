extends Node3D
class_name HoleController

signal level_changed(new_level: int, radius: float)
signal xp_changed(current_xp: float, next_threshold: float, progress: float)
signal fever_changed(ratio: float, active: bool)
signal buff_changed(buff_name: String, remaining: float)

## Exact GDD Section 3 Growth Table
const LEVEL_RADIUS_MULT: Array[float] = [1.0, 1.45, 2.0, 2.65, 3.5]
const LEVEL_XP_REQ: Array[float] = [95.0, 250.0, 480.0, 820.0, 999999.0]

const BASE_RADIUS: float = 0.85
const BASE_MOVE_SPEED: float = 11.5
const FEVER_DURATION: float = 4.5
const FEVER_SPEED_BONUS: float = 1.24
const FEVER_SUCTION_BONUS: float = 1.25
const MAGNET_DURATION: float = 5.5
const STICKY_SPEED_MULT: float = 0.42 # -58% move speed

var hole_level: int = 1
var current_xp: float = 0.0
var radius_bonus_mult: float = 1.0 # +20% on RV rescue
var current_radius: float = BASE_RADIUS
var target_radius: float = BASE_RADIUS

var fever_charge: float = 0.0
var fever_timer: float = 0.0
var magnet_timer: float = 0.0
var sticky_timer: float = 0.0

var board_bounds := Vector2(6.4, 9.8)
var is_controllable: bool = false
var _dragging: bool = false
var _drag_velocity := Vector3.ZERO

var _vortex_mesh: MeshInstance3D
var _vortex_mat: ShaderMaterial
var _rim_base_model: Node3D
var _rim_fever_model: Node3D
var _pulse_boost: float = 0.0


func _ready() -> void:
	_build_vortex_visual()
	reset_for_level(1)


func _build_vortex_visual() -> void:
	_vortex_mesh = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_vortex_mesh.mesh = quad
	_vortex_mesh.position.y = 0.02

	_vortex_mat = ShaderMaterial.new()
	_vortex_mat.shader = load("res://shaders/hole_vortex.gdshader")
	_vortex_mesh.material_override = _vortex_mat
	add_child(_vortex_mesh)

	# Attach Blender MCP 3D hole rims (CORE-01 base & CORE-02 Fever)
	if ResourceLoader.exists("res://assets/models/core/core_01_base_hole.glb"):
		var p1: PackedScene = load("res://assets/models/core/core_01_base_hole.glb")
		if p1:
			_rim_base_model = p1.instantiate()
			_rim_base_model.position.y = -0.04
			add_child(_rim_base_model)
	if ResourceLoader.exists("res://assets/models/core/core_02_fever_hole.glb"):
		var p2: PackedScene = load("res://assets/models/core/core_02_fever_hole.glb")
		if p2:
			_rim_fever_model = p2.instantiate()
			_rim_fever_model.position.y = -0.04
			_rim_fever_model.visible = false
			add_child(_rim_fever_model)


func reset_for_level(start_level: int = 1) -> void:
	hole_level = clampi(start_level, 1, 5)
	current_xp = 0.0
	radius_bonus_mult = 1.0
	fever_charge = 0.0
	fever_timer = 0.0
	magnet_timer = 0.0
	sticky_timer = 0.0
	_dragging = false
	_drag_velocity = Vector3.ZERO
	position = Vector3(0.0, 0.0, 2.5)
	_recompute_target_radius(true)
	_update_shader_uniforms()
	level_changed.emit(hole_level, current_radius)
	xp_changed.emit(0.0, get_next_xp_req(), 0.0)
	fever_changed.emit(0.0, false)


func _recompute_target_radius(snap: bool = false) -> void:
	target_radius = BASE_RADIUS * LEVEL_RADIUS_MULT[hole_level - 1] * radius_bonus_mult
	if snap:
		current_radius = target_radius
		_vortex_mesh.scale = Vector3(current_radius, 1.0, current_radius)


func get_next_xp_req() -> float:
	return LEVEL_XP_REQ[hole_level - 1]


func get_suction_radius() -> float:
	var r := current_radius * 1.12
	if fever_timer > 0.0:
		r *= FEVER_SUCTION_BONUS
	if sticky_timer > 0.0:
		r *= 0.90
	return r


func get_magnet_radius() -> float:
	if magnet_timer <= 0.0:
		return 0.0
	return current_radius * 2.95


func is_fever_active() -> bool:
	return fever_timer > 0.0


func add_xp(amount: float) -> void:
	# Fever combo build-up
	if fever_timer <= 0.0:
		fever_charge = minf(fever_charge + 0.075, 1.0)
		if fever_charge >= 1.0:
			activate_fever()
		else:
			fever_changed.emit(fever_charge, false)

	if hole_level >= 5:
		xp_changed.emit(current_xp, 1.0, 1.0)
		return

	current_xp += amount
	var req := get_next_xp_req()
	while hole_level < 5 and current_xp >= req:
		current_xp -= req
		hole_level += 1
		req = get_next_xp_req()
		_recompute_target_radius(false)
		_pulse_boost = 1.0
		AudioManager.play_sfx("level_up")
		PlatformBridge.trigger_haptic(35)
		level_changed.emit(hole_level, target_radius)

	var prog := 1.0 if hole_level >= 5 else clampf(current_xp / req, 0.0, 1.0)
	xp_changed.emit(current_xp, req, prog)


func activate_fever() -> void:
	fever_timer = FEVER_DURATION
	fever_charge = 1.0
	_pulse_boost = 1.0
	AudioManager.play_sfx("fever")
	fever_changed.emit(1.0, true)


func activate_magnet() -> void:
	magnet_timer = MAGNET_DURATION
	AudioManager.play_sfx("magnet")
	buff_changed.emit("magnet", magnet_timer)


func apply_sticky_slow(duration: float) -> void:
	if sticky_timer <= 0.05:
		AudioManager.play_sfx("sticky")
	sticky_timer = maxf(sticky_timer, duration)
	buff_changed.emit("sticky", sticky_timer)


func apply_rv_rescue_boost() -> void:
	sticky_timer = 0.0
	radius_bonus_mult = minf(radius_bonus_mult * 1.20, 1.35)
	_recompute_target_radius(false)
	_pulse_boost = 1.2
	level_changed.emit(hole_level, target_radius)
	buff_changed.emit("sticky", 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not is_controllable:
		return
	if event is InputEventScreenTouch:
		_dragging = event.pressed
		if not _dragging:
			_drag_velocity = Vector3.ZERO
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if not _dragging:
			_drag_velocity = Vector3.ZERO
	elif event is InputEventScreenDrag and _dragging:
		_apply_drag_delta(event.relative)
	elif event is InputEventMouseMotion and _dragging:
		_apply_drag_delta(event.relative)


func _apply_drag_delta(rel: Vector2) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	var scale_factor := 14.5 / maxf(vp_size.x, 320.0)
	var speed_mult := 1.0
	if fever_timer > 0.0:
		speed_mult *= FEVER_SPEED_BONUS
	if sticky_timer > 0.0:
		speed_mult *= STICKY_SPEED_MULT
	var move := Vector3(rel.x * scale_factor, 0.0, rel.y * scale_factor) * speed_mult * 1.25
	position += move
	_clamp_to_board()


func _process(delta: float) -> void:
	# Keyboard arrow/WASD support for desktop testing & accessibility
	if is_controllable:
		var inp := Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		)
		if inp.length_squared() > 0.01:
			var speed := BASE_MOVE_SPEED
			if fever_timer > 0.0:
				speed *= FEVER_SPEED_BONUS
			if sticky_timer > 0.0:
				speed *= STICKY_SPEED_MULT
			var dir := inp.normalized()
			position += Vector3(dir.x, 0.0, dir.y) * speed * delta
			_clamp_to_board()

	# Smooth hole radius scaling
	current_radius = lerpf(current_radius, target_radius, minf(delta * 9.0, 1.0))
	_vortex_mesh.scale = Vector3(current_radius * 1.06, 1.0, current_radius * 1.06)
	var rim_s := Vector3(current_radius * 1.04, current_radius * 0.75, current_radius * 1.04)
	if _rim_base_model:
		_rim_base_model.scale = rim_s
		_rim_base_model.visible = fever_timer <= 0.0
	if _rim_fever_model:
		_rim_fever_model.scale = rim_s
		_rim_fever_model.visible = fever_timer > 0.0
		if fever_timer > 0.0:
			_rim_fever_model.rotation.y += delta * 2.4

	# Decay pulse
	_pulse_boost = maxf(_pulse_boost - delta * 2.5, 0.0)

	# Timers
	if fever_timer > 0.0:
		fever_timer = maxf(fever_timer - delta, 0.0)
		fever_charge = fever_timer / FEVER_DURATION
		fever_changed.emit(fever_charge, fever_timer > 0.0)
	elif fever_charge > 0.0:
		fever_charge = maxf(fever_charge - delta * 0.08, 0.0)
		fever_changed.emit(fever_charge, false)

	if magnet_timer > 0.0:
		magnet_timer = maxf(magnet_timer - delta, 0.0)
		buff_changed.emit("magnet", magnet_timer)

	if sticky_timer > 0.0:
		sticky_timer = maxf(sticky_timer - delta, 0.0)
		buff_changed.emit("sticky", sticky_timer)

	_update_shader_uniforms()


func _clamp_to_board() -> void:
	var pad := current_radius * 0.85
	position.x = clampf(position.x, -board_bounds.x + pad, board_bounds.x - pad)
	position.z = clampf(position.z, -board_bounds.y + pad, board_bounds.y - pad)


func _update_shader_uniforms() -> void:
	if not _vortex_mat:
		return
	var prog := 1.0 if hole_level >= 5 else clampf(current_xp / get_next_xp_req(), 0.0, 1.0)
	_vortex_mat.set_shader_parameter("xp_progress", prog)
	_vortex_mat.set_shader_parameter("fever_mix", 1.0 if fever_timer > 0.0 else 0.0)
	_vortex_mat.set_shader_parameter("pulse_boost", _pulse_boost)
