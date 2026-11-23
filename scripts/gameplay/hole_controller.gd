extends Node3D
class_name HoleController

signal level_changed(new_level: int, radius: float)
signal xp_changed(current_xp: float, next_threshold: float, progress: float)
signal fever_changed(ratio: float, active: bool)
signal buff_changed(buff_name: String, remaining: float)
signal sticky_triggered(trap_pos: Vector3, trap_color: Color, trap_label: String)

## Calibrated cumulative XP thresholds matching gobble-pop-demo & GDD (Lv.1 -> Lv.5)
const LEVEL_RADIUS_MULT: Array[float] = [1.0, 1.45, 2.0, 2.65, 3.5]
const LEVEL_CUMULATIVE_XP: Array[float] = [95.0, 245.0, 475.0, 810.0, 999999.0]

const BASE_RADIUS: float = 0.82
const BASE_MOVE_SPEED: float = 6.35
const SPEED_PER_LEVEL: float = 0.36
const FEVER_DURATION: float = 4.5
const FEVER_SPEED_BONUS: float = 1.24
const FEVER_SUCTION_BONUS: float = 1.25
const MAGNET_DURATION: float = 5.5
const STICKY_SPEED_MULT: float = 0.45 # -55% speed (firm drag, still escapable!)
const STICKY_SNAP_DIST: float = 3.35  # Strain steadily ~0.9s to snap the strands free!
const JOYSTICK_MAX_R: float = 56.0

var hole_level: int = 1
var total_xp: float = 0.0
var radius_bonus_mult: float = 1.0
var current_radius: float = BASE_RADIUS
var target_radius: float = BASE_RADIUS

var fever_charge: float = 0.0
var fever_timer: float = 0.0
var magnet_timer: float = 0.0
var sticky_timer: float = 0.0
var active_gum_trap: Node3D = null

var board_bounds := Vector2(8.0, 10.0)
var is_controllable: bool = false
var is_paused: bool = false

# Floating virtual joystick state (exposed for HUD rendering!)
var joy_active: bool = false
var joy_origin := Vector2.ZERO
var joy_dir := Vector2.ZERO
# V2.0 PC Native Mouse Cursor Chase (no click-drag required on desktop!)
var _using_touch: bool = false
var _mouse_chase_active: bool = false
var _mouse_screen_pos := Vector2.ZERO
var _velocity := Vector3.ZERO
var _spin_phase: float = 0.0

var _vortex_mesh: MeshInstance3D
var _vortex_mat: ShaderMaterial
var _rim_base_model: Node3D
var _rim_fever_model: Node3D
var _rim_goo_blob: MeshInstance3D
var _rim_goo_mat: StandardMaterial3D
var _magnet_ring: MeshInstance3D
var _strand_mesh_inst: MeshInstance3D
var _strand_mesh: ImmediateMesh
var _strand_mat: StandardMaterial3D
var _pulse_boost: float = 0.0


func _ready() -> void:
	_build_vortex_visual()
	_build_sticky_strands_and_goo()
	if not GameManager.skin_equipped.is_connected(apply_skin):
		GameManager.skin_equipped.connect(apply_skin)
	apply_skin(GameManager.equipped_skin)
	reset_for_level(1, Vector3.ZERO)


func apply_skin(skin_id: String) -> void:
	if not _vortex_mat:
		return
	var def := GameManager.get_skin_def(skin_id)
	_vortex_mat.set_shader_parameter("gold_dark", def.get("gold_dark", Color(0.46, 0.31, 0.12)))
	_vortex_mat.set_shader_parameter("gold_mid", def.get("gold_mid", Color(0.84, 0.68, 0.34)))
	_vortex_mat.set_shader_parameter("gold_shine", def.get("gold_shine", Color(1.0, 0.96, 0.80)))
	_vortex_mat.set_shader_parameter("xp_cyan", def.get("xp_cyan", Color(0.30, 0.96, 1.0)))
	_vortex_mat.set_shader_parameter("vortex_abyss", def.get("vortex_abyss", Color(0.02, 0.16, 0.24)))
	_vortex_mat.set_shader_parameter("vortex_teal", def.get("vortex_teal", Color(0.07, 0.62, 0.72)))
	_vortex_mat.set_shader_parameter("vortex_aqua", def.get("vortex_aqua", Color(0.45, 0.95, 0.98)))
	_pulse_boost = 0.85


func _build_vortex_visual() -> void:
	_vortex_mesh = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(2.0, 2.0)
	_vortex_mesh.mesh = quad
	_vortex_mesh.position.y = 0.025

	_vortex_mat = ShaderMaterial.new()
	_vortex_mat.shader = load("res://shaders/hole_vortex.gdshader")
	_vortex_mesh.material_override = _vortex_mat
	add_child(_vortex_mesh)

	# Keep the hole sleek and flush-embedded using the directional brushed-gold shader bezel
	# (eliminates the chunky flat-yellow plastic 3D ring!).
	_rim_base_model = null
	_rim_fever_model = null

	# Luminous candy magenta magnet aura ring
	_magnet_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.outer_radius = 1.0
	tor.inner_radius = 0.94
	_magnet_ring.mesh = tor
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(0.92, 0.25, 0.68, 0.52)
	mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_magnet_ring.material_override = mmat
	_magnet_ring.position.y = 0.055
	_magnet_ring.visible = false
	add_child(_magnet_ring)


func _apply_gold_rim_finish(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#FFD644")
		mat.roughness = 0.20
		mat.metallic = 0.32
		mi.set_surface_override_material(0, mat)
	for child in node.get_children():
		_apply_gold_rim_finish(child)


func _build_sticky_strands_and_goo() -> void:
	# Juicy candy sticky glob visibly stuck on the hole rim when trapped (adapts to W1-W4 trap color!)
	_rim_goo_blob = MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.36
	sp.height = 0.42
	_rim_goo_blob.mesh = sp
	_rim_goo_mat = StandardMaterial3D.new()
	_rim_goo_mat.albedo_color = Color("#FF52A8")
	_rim_goo_mat.roughness = 0.16
	_rim_goo_mat.emission_enabled = true
	_rim_goo_mat.emission = Color("#FF52A8")
	_rim_goo_mat.emission_energy_multiplier = 0.16
	_rim_goo_blob.material_override = _rim_goo_mat
	_rim_goo_blob.visible = false
	add_child(_rim_goo_blob)

	# Live 3D stretchy curved strands connecting active_gum_trap -> hole rim
	_strand_mesh = ImmediateMesh.new()
	_strand_mesh_inst = MeshInstance3D.new()
	_strand_mesh_inst.mesh = _strand_mesh
	_strand_mesh_inst.top_level = true
	_strand_mat = StandardMaterial3D.new()
	_strand_mat.albedo_color = Color("#FF52A8")
	_strand_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_strand_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_strand_mesh_inst.material_override = _strand_mat
	add_child(_strand_mesh_inst)


func reset_for_level(start_level: int = 1, spawn_pos: Vector3 = Vector3.ZERO) -> void:
	hole_level = clampi(start_level, 1, 5)
	total_xp = 0.0 if hole_level <= 1 else LEVEL_CUMULATIVE_XP[hole_level - 2]
	radius_bonus_mult = 1.0
	fever_charge = 0.0
	fever_timer = 0.0
	magnet_timer = 0.0
	sticky_timer = 0.0
	active_gum_trap = null
	joy_active = false
	joy_dir = Vector2.ZERO
	_velocity = Vector3.ZERO
	position = spawn_pos
	_recompute_target_radius(true)
	_update_shader_uniforms()
	_strand_mesh.clear_surfaces()
	level_changed.emit(hole_level, current_radius)
	xp_changed.emit(total_xp, get_next_xp_req(), get_xp_progress())
	fever_changed.emit(0.0, false)


func _recompute_target_radius(snap: bool = false) -> void:
	var upg_r := GameManager.get_upgrade_radius_mult() if is_instance_valid(GameManager) else 1.0
	target_radius = BASE_RADIUS * LEVEL_RADIUS_MULT[hole_level - 1] * radius_bonus_mult * upg_r
	if snap:
		current_radius = target_radius
		_vortex_mesh.scale = Vector3(current_radius * 1.06, 1.0, current_radius * 1.06)


func get_prev_xp_req() -> float:
	return 0.0 if hole_level <= 1 else LEVEL_CUMULATIVE_XP[hole_level - 2]


func get_next_xp_req() -> float:
	return LEVEL_CUMULATIVE_XP[hole_level - 1]


func get_xp_progress() -> float:
	if hole_level >= 5:
		return 1.0
	var prev := get_prev_xp_req()
	var nxt := get_next_xp_req()
	return clampf((total_xp - prev) / maxf(nxt - prev, 1.0), 0.0, 1.0)


func get_suction_radius() -> float:
	var r := current_radius * 1.06
	if fever_timer > 0.0:
		r *= FEVER_SUCTION_BONUS
	if sticky_timer > 0.0:
		r *= 0.80 # Matches demo's 0.80x suction penalty when stuck!
	return r


func get_magnet_radius() -> float:
	if magnet_timer <= 0.0:
		return 0.0
	return current_radius + 3.85


func is_fever_active() -> bool:
	return fever_timer > 0.0


func add_xp(amount: float) -> void:
	if fever_timer <= 0.0:
		fever_charge = minf(fever_charge + 0.08, 1.0)
		if fever_charge >= 1.0:
			activate_fever()
		else:
			fever_changed.emit(fever_charge, false)

	total_xp += amount
	while hole_level < 5 and total_xp >= LEVEL_CUMULATIVE_XP[hole_level - 1]:
		hole_level += 1
		_recompute_target_radius(false)
		_pulse_boost = 1.0
		AudioManager.play_sfx("level_up")
		PlatformBridge.trigger_haptic(35)
		level_changed.emit(hole_level, target_radius)

	xp_changed.emit(total_xp, get_next_xp_req(), get_xp_progress())


func activate_fever() -> void:
	fever_timer = FEVER_DURATION
	fever_charge = 1.0
	_pulse_boost = 1.0
	AudioManager.play_sfx("fever")
	fever_changed.emit(1.0, true)


func activate_magnet(dur: float = MAGNET_DURATION) -> void:
	magnet_timer = maxf(magnet_timer, dur)
	AudioManager.play_sfx("magnet")
	buff_changed.emit("magnet", magnet_timer)


func trigger_sticky_trap(trap_node: Node3D, duration: float, trap_col: Color = Color("#FF2E93"), trap_lbl: String = "STICKY GUM!") -> void:
	sticky_timer = maxf(sticky_timer, duration)
	active_gum_trap = trap_node
	_velocity *= 0.45 # Noticeable sticky snag without total dead-stop!
	_rim_goo_mat.albedo_color = trap_col
	_rim_goo_mat.emission = trap_col
	_strand_mat.albedo_color = trap_col
	if _vortex_mat:
		_vortex_mat.set_shader_parameter("rim_gum", trap_col)
	AudioManager.play_sfx("sticky")
	PlatformBridge.trigger_haptic(35)
	sticky_triggered.emit(trap_node.position, trap_col, trap_lbl)
	buff_changed.emit("sticky", sticky_timer)


func apply_rubber_bounce(world_normal: Vector3) -> void:
	_velocity = world_normal * 8.5


func apply_rv_rescue_boost() -> void:
	sticky_timer = 0.0
	active_gum_trap = null
	_strand_mesh.clear_surfaces()
	radius_bonus_mult = minf(radius_bonus_mult * 1.20, 1.45)
	_recompute_target_radius(false)
	_pulse_boost = 1.25
	level_changed.emit(hole_level, target_radius)
	buff_changed.emit("sticky", 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not is_controllable:
		joy_active = false
		joy_dir = Vector2.ZERO
		_mouse_chase_active = false
		return

	if event is InputEventScreenTouch:
		_using_touch = true
		_mouse_chase_active = false
		if event.pressed:
			joy_active = true
			joy_origin = event.position
			joy_dir = Vector2.ZERO
		else:
			joy_active = false
			joy_dir = Vector2.ZERO
	elif event is InputEventScreenDrag and joy_active:
		_using_touch = true
		_update_virtual_joystick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if GameManager.mouse_follow_enabled and not _using_touch:
			_mouse_screen_pos = event.position
			_mouse_chase_active = true
		else:
			if event.pressed:
				joy_active = true
				joy_origin = event.position
				joy_dir = Vector2.ZERO
			else:
				joy_active = false
				joy_dir = Vector2.ZERO
	elif event is InputEventMouseMotion:
		if not _using_touch and GameManager.mouse_follow_enabled:
			_mouse_screen_pos = event.position
			_mouse_chase_active = true
			joy_active = false
		elif joy_active:
			_update_virtual_joystick(event.position)


func _get_mouse_chase_vector() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return Vector2.ZERO
	var ray_o := cam.project_ray_origin(_mouse_screen_pos)
	var ray_d := cam.project_ray_normal(_mouse_screen_pos)
	if absf(ray_d.y) < 0.001:
		return Vector2.ZERO
	var t := -ray_o.y / ray_d.y
	if t <= 0.0:
		return Vector2.ZERO
	var hit := ray_o + ray_d * t
	var delta_xz := Vector2(hit.x - position.x, hit.z - position.z)
	var dist := delta_xz.length()
	if dist < 0.22:
		return Vector2.ZERO
	var mag := clampf((dist - 0.22) / 1.45, 0.0, 1.0)
	return (delta_xz / dist) * mag


func _update_virtual_joystick(pointer_pos: Vector2) -> void:
	var v := pointer_pos - joy_origin
	var dist := v.length()
	if dist > 4.0:
		var mag := minf(1.0, dist / JOYSTICK_MAX_R)
		joy_dir = (v / dist) * mag
		# Floating joystick follows finger smoothly past 1.45 * maxR (exact demo feel!)
		if dist > JOYSTICK_MAX_R * 1.45:
			joy_origin = pointer_pos - (v / dist) * JOYSTICK_MAX_R
	else:
		joy_dir = Vector2.ZERO


func _process(delta: float) -> void:
	if is_paused:
		return
	# Compute desired input vector (Keyboard WASD/Arrows -> Touch Joystick -> PC Mouse Cursor Chase)
	var inp := Vector2.ZERO
	if is_controllable:
		var kx := Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		var kz := Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		if Input.is_key_pressed(KEY_D): kx += 1.0
		if Input.is_key_pressed(KEY_A): kx -= 1.0
		if Input.is_key_pressed(KEY_S): kz += 1.0
		if Input.is_key_pressed(KEY_W): kz -= 1.0
		var kb := Vector2(kx, kz)
		if kb.length() > 0.05:
			_mouse_chase_active = false
			inp = kb.normalized() if kb.length() > 1.0 else kb
		elif joy_active:
			inp = joy_dir
		elif _mouse_chase_active and GameManager.mouse_follow_enabled and not _using_touch:
			inp = _get_mouse_chase_vector()

	var upg_spd := GameManager.get_upgrade_speed_mult() if is_instance_valid(GameManager) else 1.0
	var speed := (BASE_MOVE_SPEED + float(hole_level - 1) * SPEED_PER_LEVEL) * upg_spd
	if fever_timer > 0.0:
		speed *= FEVER_SPEED_BONUS
	if sticky_timer > 0.0:
		speed *= STICKY_SPEED_MULT

	var target_vel := Vector3(inp.x * speed, 0.0, inp.y * speed)

	# Balanced elastic spring tug-back: strongly felt, yet ALWAYS weaker than max slowed speed so pulling steadily snaps free!
	if sticky_timer > 0.0 and is_instance_valid(active_gum_trap):
		var from_gum := Vector3(position.x - active_gum_trap.position.x, 0.0, position.z - active_gum_trap.position.z)
		var gdist := from_gum.length()
		if gdist > STICKY_SNAP_DIST:
			# Snapped free! Reward player with immediate speed relief!
			active_gum_trap = null
			sticky_timer = minf(sticky_timer, 0.25)
			AudioManager.play_sfx("pop_small", 1.35)
		elif gdist > 0.45:
			var max_tug := speed * 0.42
			var tug_strength := clampf((gdist - 0.45) * 0.68, 0.0, max_tug)
			target_vel -= (from_gum / gdist) * tug_strength

	_velocity = _velocity.lerp(target_vel, minf(delta * 13.5, 1.0))
	if is_controllable:
		position += _velocity * delta
		_clamp_to_board()

	# Smooth hole radius & spin phase (chokes slow when stuck in gum!)
	current_radius = lerpf(current_radius, target_radius, minf(delta * 8.5, 1.0))
	var spin_rate := 5.2 if fever_timer > 0.0 else (0.75 if sticky_timer > 0.0 else 2.6)
	_spin_phase += delta * spin_rate

	_vortex_mesh.scale = Vector3(current_radius * 1.06, 1.0, current_radius * 1.06)
	var rim_s := Vector3(current_radius * 1.04, current_radius * 0.75, current_radius * 1.04)
	if _rim_base_model:
		_rim_base_model.scale = rim_s
		_rim_base_model.visible = fever_timer <= 0.0
	if _rim_fever_model:
		_rim_fever_model.scale = rim_s
		_rim_fever_model.visible = fever_timer > 0.0
		if fever_timer > 0.0:
			_rim_fever_model.rotation.y += delta * 2.8

	# Magnet aura visual
	_magnet_ring.visible = magnet_timer > 0.0
	if _magnet_ring.visible:
		var mr := get_magnet_radius()
		_magnet_ring.scale = Vector3(mr, 1.0, mr)
		_magnet_ring.rotation.y += delta * 1.8

	# Sticky rim goo blob + live 3D stretchy strands
	_rim_goo_blob.visible = sticky_timer > 0.0
	if _rim_goo_blob.visible:
		var blob_pos := Vector3(current_radius * 0.75, 0.14, -current_radius * 0.35)
		if is_instance_valid(active_gum_trap):
			var to_g := (active_gum_trap.position - position)
			to_g.y = 0.0
			if to_g.length() > 0.05:
				blob_pos = to_g.normalized() * (current_radius * 0.88) + Vector3(0, 0.14, 0)
		_rim_goo_blob.position = blob_pos
		_rim_goo_blob.scale = Vector3.ONE * clampf(current_radius * 0.85, 0.65, 1.6)
	_redraw_sticky_strands()

	_pulse_boost = maxf(_pulse_boost - delta * 2.5, 0.0)

	# Update timers
	if fever_timer > 0.0:
		fever_timer = maxf(fever_timer - delta, 0.0)
		fever_charge = fever_timer / FEVER_DURATION
		fever_changed.emit(fever_charge, fever_timer > 0.0)
	elif fever_charge > 0.0:
		fever_charge = maxf(fever_charge - delta * 0.05, 0.0)
		fever_changed.emit(fever_charge, false)

	if magnet_timer > 0.0:
		magnet_timer = maxf(magnet_timer - delta, 0.0)
		buff_changed.emit("magnet", magnet_timer)

	if sticky_timer > 0.0:
		sticky_timer = maxf(sticky_timer - delta, 0.0)
		if sticky_timer <= 0.0:
			active_gum_trap = null
		buff_changed.emit("sticky", sticky_timer)

	_update_shader_uniforms()


func _redraw_sticky_strands() -> void:
	_strand_mesh.clear_surfaces()
	if sticky_timer <= 0.0 or not is_instance_valid(active_gum_trap):
		return

	var p0 := active_gum_trap.position + Vector3(0.0, 0.14, 0.0)
	var diff := position - active_gum_trap.position
	diff.y = 0.0
	var dist := diff.length()
	if dist < 0.25 or dist > STICKY_SNAP_DIST + 0.4:
		return

	var dir := diff / dist
	var perp := Vector3(-dir.z, 0.0, dir.x)
	var p1 := position - dir * (current_radius * 0.86) + Vector3(0.0, 0.14, 0.0)

	# Draw 3 parallel curved stretchy hot-pink bubblegum ribbons!
	_strand_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets := [-0.32, 0.0, 0.32]
	var widths := [0.065, 0.105, 0.065]
	var thin_factor := clampf(1.0 - dist / (STICKY_SNAP_DIST * 1.25), 0.28, 1.0)
	var segs := 10

	for s_idx in range(3):
		var off: float = offsets[s_idx]
		var w: float = widths[s_idx] * thin_factor
		var a := p0 + perp * (off * 0.65)
		var b := p1 + perp * off
		var ctrl := (a + b) * 0.5 + Vector3(0.0, -0.04, 0.22)

		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for i in range(segs + 1):
			var t := float(i) / float(segs)
			var omt := 1.0 - t
			var pt := omt * omt * a + 2.0 * omt * t * ctrl + t * t * b
			# Pinch thinner right in the middle like real stretched bubblegum!
			var mid_pinch := 1.0 - 0.45 * sin(t * PI)
			var hw := w * mid_pinch
			var cur_l := pt - perp * hw
			var cur_r := pt + perp * hw
			if i > 0:
				_strand_mesh.surface_add_vertex(prev_l)
				_strand_mesh.surface_add_vertex(prev_r)
				_strand_mesh.surface_add_vertex(cur_r)
				_strand_mesh.surface_add_vertex(prev_l)
				_strand_mesh.surface_add_vertex(cur_r)
				_strand_mesh.surface_add_vertex(cur_l)
			prev_l = cur_l
			prev_r = cur_r
	_strand_mesh.surface_end()


func _clamp_to_board() -> void:
	var pad := current_radius * 0.88 + 0.35
	position.x = clampf(position.x, -board_bounds.x + pad, board_bounds.x - pad)
	position.z = clampf(position.z, -board_bounds.y + pad, board_bounds.y - pad)


func _update_shader_uniforms() -> void:
	if not _vortex_mat:
		return
	_vortex_mat.set_shader_parameter("xp_progress", get_xp_progress())
	_vortex_mat.set_shader_parameter("fever_mix", 1.0 if fever_timer > 0.0 else 0.0)
	_vortex_mat.set_shader_parameter("gum_mix", 1.0 if sticky_timer > 0.0 else 0.0)
	_vortex_mat.set_shader_parameter("spin_phase", _spin_phase)
	_vortex_mat.set_shader_parameter("pulse_boost", _pulse_boost)
