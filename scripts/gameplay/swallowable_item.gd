extends Node3D
class_name SwallowableItem

signal swallowed(item_key: String, tier: int, xp: float, world_pos: Vector3, tint: Color)

enum State { IDLE, FALLING_STACK, PULLING, SWALLOWED }

var item_key: String = ""
var tier: int = 1
var xp_value: float = 5.0
var item_radius: float = 0.3
var item_height: float = 0.4
var tint_color: Color = Color.WHITE
var is_objective: bool = false
var state: State = State.IDLE

var _fall_vel := Vector3.ZERO
var _tilt_axis := Vector3.RIGHT
var _visual_root: Node3D
var _contact_shadow: MeshInstance3D
var _target_ring: MeshInstance3D
var _target_ring_mat: StandardMaterial3D
var _target_outer_ring: MeshInstance3D
var _target_outer_mat: StandardMaterial3D
var _lock_label: Label3D
var _bounce: float = 0.0
var _shimmer_phase: float = 0.0
var _wobble_time: float = 0.0
var _wobble_active: bool = false
var _stacked_base_y: float = 0.0
var _collapse_delay: float = 0.0
var _pending_collapse: bool = false
var _pending_impulse: Vector3 = Vector3.ZERO

static var mobile_low_power: bool = false
static var _shared_shadow_mat: ShaderMaterial = null
static var _shared_toy_shader: Shader = null
static var _shared_mat_cache: Dictionary = {}


func setup(key: String, def: Dictionary, spawn_pos: Vector3, color_idx: int = 0, p_is_objective: bool = false, rot_deg: float = NAN) -> void:
	item_key = key
	tier = int(def.get("tier", 1))
	xp_value = float(def.get("xp", 5.0))
	item_radius = float(def.get("radius", 0.3))
	item_height = float(def.get("height", 0.4))
	is_objective = p_is_objective
	var colors: Array = def.get("colors", ["#DF85A5"])
	tint_color = Color(str(colors[color_idx % colors.size()]))
	position = spawn_pos
	_stacked_base_y = spawn_pos.y
	_wobble_time = randf() * TAU

	_visual_root = Node3D.new()
	add_child(_visual_root)

	_build_contact_shadow()
	if _stacked_base_y > 0.06 and _contact_shadow:
		_contact_shadow.visible = false
	if is_objective:
		_build_target_ring()
		if _stacked_base_y > 0.06:
			# Keep towering stacked monuments crisp and uncluttered; reveal ring once landed!
			_target_ring.visible = false
			if _target_outer_ring:
				_target_outer_ring.visible = false
	if tier >= 3:
		_build_lock_badge()

	var model_path: String = str(def.get("model", ""))
	if model_path != "" and ResourceLoader.exists(model_path):
		var packed: PackedScene = load(model_path)
		if packed:
			var inst := packed.instantiate()
			var auto_fit := bool(def.get("auto_fit", false))
			var use_vcol := bool(def.get("use_vertex_color", false))
			var solid_tint := bool(def.get("solid_tint", false))

			if auto_fit:
				_auto_normalize_model(inst, item_radius, item_height)
				if not is_nan(rot_deg):
					inst.rotation.y = deg_to_rad(rot_deg)
				elif item_key in ["w1_sprinkle", "w2_block", "w4_d20", "w4_slime", "w5_pixel_coin"]:
					inst.rotation.y = randf() * TAU
				else:
					inst.rotation.y = randf_range(-0.55, 0.55)
			else:
				if item_key in ["w1_grand_cake", "w3_grand_bento", "w4_grand_cauldron"]:
					inst.scale = Vector3(1.26, 1.26, 1.26)
				elif item_key == "w3_big_ramen":
					inst.scale = Vector3(1.34, 1.34, 1.34)
				elif item_key in ["w1_sprinkle", "w2_block", "w4_d20"]:
					inst.rotation.y = randf() * TAU
				elif item_key == "w1_gummy_bear":
					inst.rotation.y = randf_range(-0.8, 0.8)
				elif item_key in ["w2_duck", "w2_arcade", "w2_unicorn", "w3_sushi", "w4_spellbook"]:
					inst.rotation.y = randf_range(-0.6, 0.6)

			_apply_toy_gloss_recursive(inst, solid_tint, use_vcol)
			_visual_root.add_child(inst)
			return

	_build_fallback_mesh()


func _auto_normalize_model(root: Node3D, target_radius: float, target_height: float) -> void:
	var bounds := _compute_merged_aabb(root, Transform3D.IDENTITY)
	if not bounds["valid"]:
		return
	var aabb: AABB = bounds["aabb"]
	var horiz_max := maxf(aabb.size.x, aabb.size.z)
	if horiz_max < 0.001:
		return
	var s := (target_radius * 2.02) / horiz_max
	# Guard against overly tall thin models clipping sky-high
	if aabb.size.y * s > target_height * 1.45 and target_height > 0.1:
		s = (target_height * 1.35) / maxf(aabb.size.y, 0.001)
	root.scale = Vector3(s, s, s)
	var center_x := (aabb.position.x + aabb.size.x * 0.5) * s
	var center_z := (aabb.position.z + aabb.size.z * 0.5) * s
	var min_y := aabb.position.y * s
	# Clear +0.052m above Y=0 tabletop, Y=0.014 contact shadow, and Y=0.032 target ring so flat-bottom meshes
	# (like pancakes.glb syrup puddle, cookies, and pizza) NEVER Z-fight or flicker against the plane!
	root.position = Vector3(-center_x, -min_y + 0.052, -center_z)


func _compute_merged_aabb(node: Node, parent_xform: Transform3D) -> Dictionary:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	var res := {"valid": false, "aabb": AABB()}
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var local_bb := mi.mesh.get_aabb()
			var corners := [
				Vector3(local_bb.position.x, local_bb.position.y, local_bb.position.z),
				Vector3(local_bb.end.x, local_bb.position.y, local_bb.position.z),
				Vector3(local_bb.position.x, local_bb.end.y, local_bb.position.z),
				Vector3(local_bb.position.x, local_bb.position.y, local_bb.end.z),
				Vector3(local_bb.end.x, local_bb.end.y, local_bb.position.z),
				Vector3(local_bb.end.x, local_bb.position.y, local_bb.end.z),
				Vector3(local_bb.position.x, local_bb.end.y, local_bb.end.z),
				Vector3(local_bb.end.x, local_bb.end.y, local_bb.end.z),
			]
			var wb := AABB(xform * corners[0], Vector3.ZERO)
			for c in corners:
				wb = wb.expand(xform * c)
			res["valid"] = true
			res["aabb"] = wb
	for child in node.get_children():
		var cb := _compute_merged_aabb(child, xform)
		if cb["valid"]:
			if not res["valid"]:
				res["valid"] = true
				res["aabb"] = cb["aabb"]
			else:
				res["aabb"] = (res["aabb"] as AABB).merge(cb["aabb"] as AABB)
	return res


func _apply_toy_gloss_recursive(node: Node, solid_tint: bool, use_vcol: bool) -> void:
	if _shared_toy_shader == null:
		_shared_toy_shader = load("res://shaders/toy_gloss.gdshader")
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if mobile_low_power else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var surf_cnt := mi.mesh.get_surface_count() if mi.mesh else 1
		for s_idx in range(surf_cnt):
			var src_mat := mi.get_active_material(s_idx)
			var tex: Texture2D = null
			var tint_col := Color.WHITE
			var has_tex := false
			if not solid_tint and src_mat is StandardMaterial3D:
				var std := src_mat as StandardMaterial3D
				if std.albedo_texture != null:
					tex = std.albedo_texture
					has_tex = true
				tint_col = std.albedo_color if not use_vcol else Color.WHITE
			elif solid_tint:
				tint_col = tint_color

			var use_vc := use_vcol and (not has_tex) and (not solid_tint)
			var cache_key := "%d_%s_%d_%d" % [tex.get_rid().get_id() if tex else 0, tint_col.to_html(false), 1 if has_tex else 0, 1 if use_vc else 0]
			var sm: ShaderMaterial = _shared_mat_cache.get(cache_key, null)
			if sm == null:
				sm = ShaderMaterial.new()
				sm.shader = _shared_toy_shader
				if has_tex:
					sm.set_shader_parameter("albedo_tex", tex)
				sm.set_shader_parameter("use_albedo_tex", has_tex)
				sm.set_shader_parameter("albedo_tint", tint_col)
				sm.set_shader_parameter("use_vertex_color", use_vc)
				sm.set_shader_parameter("roughness_val", 0.20)
				sm.set_shader_parameter("rim_strength", 0.38)
				_shared_mat_cache[cache_key] = sm
			mi.set_surface_override_material(s_idx, sm)
	for child in node.get_children():
		_apply_toy_gloss_recursive(child, solid_tint, use_vcol)


func _build_contact_shadow() -> void:
	if _shared_shadow_mat == null:
		_shared_shadow_mat = ShaderMaterial.new()
		_shared_shadow_mat.shader = load("res://shaders/contact_shadow.gdshader")
	_contact_shadow = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	var sz := maxf(0.55, item_radius * 2.55)
	quad.size = Vector2(sz, sz)
	_contact_shadow.mesh = quad
	_contact_shadow.material_override = _shared_shadow_mat
	_contact_shadow.position.y = 0.014
	add_child(_contact_shadow)


func _build_target_ring() -> void:
	_shimmer_phase = randf() * TAU
	_target_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.outer_radius = item_radius * 1.15 + 0.095
	tor.inner_radius = item_radius * 1.15 + 0.025
	_target_ring.mesh = tor
	_target_ring.position.y = 0.032
	_target_ring_mat = StandardMaterial3D.new()
	_target_ring_mat.albedo_color = Color(1.0, 0.84, 0.25, 0.92)
	_target_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_target_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_ring.material_override = _target_ring_mat
	add_child(_target_ring)

	_target_outer_ring = MeshInstance3D.new()
	var tor2 := TorusMesh.new()
	tor2.outer_radius = item_radius * 1.24 + 0.16
	tor2.inner_radius = item_radius * 1.24 + 0.095
	_target_outer_ring.mesh = tor2
	_target_outer_ring.position.y = 0.026
	_target_outer_mat = StandardMaterial3D.new()
	_target_outer_mat.albedo_color = Color(1.0, 0.90, 0.42, 0.42)
	_target_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_target_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_outer_ring.material_override = _target_outer_mat
	add_child(_target_outer_ring)


func _build_lock_badge() -> void:
	_lock_label = Label3D.new()
	_lock_label.text = "Lv.%d" % tier
	_lock_label.font_size = 48
	_lock_label.outline_size = 15
	_lock_label.modulate = Color("#FFF08A")
	_lock_label.outline_modulate = Color("#3D2114")
	_lock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lock_label.no_depth_test = true
	_lock_label.position = Vector3(0.0, item_height + 0.50, 0.0)
	add_child(_lock_label)


func _build_fallback_mesh() -> void:
	var m := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = item_radius
	sph.height = item_height
	m.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint_color
	mat.roughness = 0.22
	m.material_override = mat
	m.position.y = item_height * 0.5
	_visual_root.add_child(m)


func trigger_stack_collapse(impulse_dir: Vector3, delay: float = 0.0) -> void:
	if state != State.IDLE or position.y <= 0.04:
		return
	if delay > 0.005:
		if not _pending_collapse or delay < _collapse_delay:
			_pending_collapse = true
			_collapse_delay = delay
			_pending_impulse = impulse_dir
		return
	_start_collapse_now(impulse_dir)


func _start_collapse_now(impulse_dir: Vector3) -> void:
	_pending_collapse = false
	state = State.FALLING_STACK
	# Tight inward waterfall drop so tall All-in-Hole towers pour straight into the vortex!
	_fall_vel = Vector3(impulse_dir.x * randf_range(0.22, 0.72), randf_range(0.10, 0.42), impulse_dir.z * randf_range(0.22, 0.72))
	var perp := Vector3(-impulse_dir.z, 0.0, impulse_dir.x)
	_tilt_axis = perp.normalized() if perp.length() > 0.05 else Vector3.RIGHT


func step_interaction(hole: HoleController, delta: float, board_bounds: Vector2) -> void:
	if state == State.SWALLOWED:
		return

	var can_eat := tier <= hole.hole_level
	if _target_ring and (state == State.IDLE or state == State.FALLING_STACK):
		_shimmer_phase += delta * (4.2 if can_eat else 2.2)
		var pulse := 1.0 + sin(_shimmer_phase) * (0.06 if can_eat else 0.025)
		_target_ring.scale = Vector3(pulse, 1.0, pulse)
		if can_eat:
			_target_ring_mat.albedo_color = Color(0.18, 0.90, 0.48, 0.95)
			if _target_outer_ring:
				_target_outer_ring.scale = Vector3(pulse * 1.03, 1.0, pulse * 1.03)
				_target_outer_mat.albedo_color = Color(0.32, 0.96, 0.58, 0.46)
		else:
			_target_ring_mat.albedo_color = Color(1.0, 0.84, 0.25, 0.92)
			if _target_outer_ring:
				_target_outer_ring.scale = Vector3(pulse, 1.0, pulse)
				_target_outer_mat.albedo_color = Color(1.0, 0.90, 0.42, 0.40)
	if _lock_label:
		_lock_label.visible = (not can_eat) and (state == State.IDLE or state == State.FALLING_STACK)

	var to_hole := Vector3(hole.position.x - position.x, 0.0, hole.position.z - position.z)
	var dist := to_hole.length()

	# Cute anticipation wobble when hole approaches near rim (zero per-frame shader uniform writes -> 100% shared GPU materials!)
	var suction_r := maxf(0.48, hole.get_suction_radius() - item_radius * 0.24)
	if state == State.IDLE and dist < suction_r + 1.35:
		_wobble_time += delta
		_wobble_active = true
		var amp := clampf(1.0 - (dist - suction_r) / 1.35, 0.0, 1.0) * (0.14 if can_eat else 0.08)
		_visual_root.rotation.z = sin(_wobble_time * 18.0) * amp
		_visual_root.rotation.x = cos(_wobble_time * 15.0) * amp * 0.7
	elif state == State.IDLE and _wobble_active:
		_wobble_active = false
		_visual_root.rotation.z = 0.0
		_visual_root.rotation.x = 0.0

	if _bounce > 0.0:
		_bounce = maxf(_bounce - delta * 5.0, 0.0)
		if state == State.IDLE:
			var s := 1.0 + sin(_bounce * PI) * 0.16
			_visual_root.scale = Vector3(s, 1.0 / s, s)
	elif state == State.IDLE:
		_visual_root.scale = Vector3.ONE

	# Staggered domino countdown for stacked monuments!
	if state == State.IDLE and _pending_collapse:
		_collapse_delay -= delta
		if _collapse_delay <= 0.0:
			_start_collapse_now(_pending_impulse)
			return

	# Handle stacked tower cascade collapse!
	if state == State.FALLING_STACK:
		_fall_vel.y -= 28.0 * delta
		position += _fall_vel * delta
		_visual_root.rotate(_tilt_axis, delta * 5.8)
		# Pull smoothly toward hole if directly above it during waterfall drop!
		if can_eat and dist < suction_r * 1.45 and dist > 0.04:
			var pull_xz := to_hole / dist
			position.x += pull_xz.x * 3.8 * delta
			position.z += pull_xz.z * 3.8 * delta
		# If edible and falling over the hole, seamlessly suck right in mid-cascade!
		if can_eat and dist < suction_r * 1.25 and position.y < 1.85:
			_enter_pulling(to_hole, dist)
			return
		if position.y <= 0.0:
			position.y = 0.0
			_stacked_base_y = 0.0
			_visual_root.rotation = Vector3.ZERO
			_bounce = 1.0
			if _contact_shadow:
				_contact_shadow.visible = true
			if _target_ring:
				_target_ring.visible = true
				_target_ring.position.y = 0.032
			if _target_outer_ring:
				_target_outer_ring.visible = true
				_target_outer_ring.position.y = 0.026
			state = State.IDLE
		return

	if state == State.IDLE:
		# If stacked high up and hole undercuts underneath, collapse immediately with crisp height stagger!
		if position.y > 0.06 and dist < hole.get_suction_radius() + item_radius * 0.95:
			var push_dir := (to_hole / maxf(dist, 0.01))
			trigger_stack_collapse(push_dir, clampf(position.y * 0.028, 0.0, 0.24))
			return

		var magnet_r := hole.get_magnet_radius()
		if can_eat and magnet_r > 0.0 and dist < magnet_r and dist > 0.05:
			var pull_dir := to_hole / dist
			position += pull_dir * 7.8 * delta

		if can_eat and dist < suction_r:
			_enter_pulling(to_hole, dist)
		elif (not can_eat) and dist < (hole.current_radius + item_radius * 0.65) and dist > 0.01:
			var push := -to_hole / dist
			position += push * 4.2 * delta
			position.x = clampf(position.x, -board_bounds.x + 0.6, board_bounds.x - 0.6)
			position.z = clampf(position.z, -board_bounds.y + 0.6, board_bounds.y - 0.6)
			_bounce = 1.0

	elif state == State.PULLING:
		var pull_vec := Vector3(hole.position.x - position.x, 0.0, hole.position.z - position.z)
		position.x += pull_vec.x * minf(delta * 10.5, 1.0)
		position.z += pull_vec.z * minf(delta * 10.5, 1.0)

		_fall_vel.y -= 26.0 * delta
		position.y += _fall_vel.y * delta
		_visual_root.rotate(_tilt_axis, delta * 9.5)

		# Juicy stretch vertically as it gets sucked into the vortex!
		var depth_t := clampf(-position.y / 2.2, 0.0, 1.0)
		var sx := lerpf(1.0, 0.12, depth_t)
		var sy := lerpf(1.18, 0.25, depth_t)
		_visual_root.scale = Vector3(sx, sy, sx)

		if position.y < -1.85:
			state = State.SWALLOWED
			swallowed.emit(item_key, tier, xp_value, Vector3(hole.position.x, 0.15, hole.position.z), tint_color)
			queue_free()


func _enter_pulling(to_hole: Vector3, dist: float) -> void:
	state = State.PULLING
	_fall_vel = Vector3(0.0, 0.85, 0.0)
	if dist > 0.01:
		var dir := to_hole / dist
		_tilt_axis = Vector3(-dir.z, 0.0, dir.x).normalized()
	if _contact_shadow:
		_contact_shadow.visible = false
	if _target_ring:
		_target_ring.visible = false
	if _target_outer_ring:
		_target_outer_ring.visible = false
	if _lock_label:
		_lock_label.visible = false
