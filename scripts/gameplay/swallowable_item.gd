extends Node3D
class_name SwallowableItem

signal swallowed(item_key: String, tier: int, xp: float, world_pos: Vector3, tint: Color)

enum State { IDLE, PULLING, SWALLOWED }

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
var _lock_label: Label3D
var _bounce: float = 0.0

static var _shared_shadow_mat: ShaderMaterial = null


func setup(key: String, def: Dictionary, spawn_pos: Vector3, color_idx: int = 0, p_is_objective: bool = false) -> void:
	item_key = key
	tier = int(def.get("tier", 1))
	xp_value = float(def.get("xp", 5.0))
	item_radius = float(def.get("radius", 0.3))
	item_height = float(def.get("height", 0.4))
	is_objective = p_is_objective
	var colors: Array = def.get("colors", ["#DF85A5"])
	tint_color = Color(str(colors[color_idx % colors.size()]))
	position = spawn_pos

	_visual_root = Node3D.new()
	add_child(_visual_root)

	_build_contact_shadow()
	if is_objective:
		_build_target_ring()
	if tier >= 3:
		_build_lock_badge()

	var model_path: String = str(def.get("model", ""))
	if model_path != "" and ResourceLoader.exists(model_path):
		var packed: PackedScene = load(model_path)
		if packed:
			var inst := packed.instantiate()
			if item_key in ["w1_grand_cake", "w3_grand_bento", "w4_grand_cauldron"]:
				inst.scale = Vector3(1.26, 1.26, 1.26)
			elif item_key == "w3_big_ramen":
				inst.scale = Vector3(1.34, 1.34, 1.34)
			elif item_key in ["w1_sprinkle", "w2_block", "w4_d20"]:
				inst.rotation.y = randf() * TAU
				# Pure single-color props: clear palette texture so variant colors NEVER multiply into muddy purple!
				_apply_solid_variant_color(inst, tint_color)
			elif item_key == "w1_gummy_bear":
				inst.rotation.y = randf_range(-0.8, 0.8)
				_apply_solid_variant_color(inst, tint_color)
			elif item_key in ["w2_duck", "w2_arcade", "w2_unicorn", "w3_sushi", "w4_spellbook"]:
				inst.rotation.y = randf_range(-0.6, 0.6)
			# Multi-color hero models (donuts, boba, macarons, cakes, sushi, bento, potions, cauldrons)
			# keep their authentic Blender palette atlas intact with a soft matte ceramic/vinyl finish!
			_soften_material_recursive(inst, item_key in ["w1_sprinkle", "w2_block", "w4_d20", "w1_gummy_bear"])
			_visual_root.add_child(inst)
			return

	_build_fallback_mesh()


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
	_target_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.outer_radius = item_radius * 1.16 + 0.095
	tor.inner_radius = item_radius * 1.16 + 0.025
	_target_ring.mesh = tor
	_target_ring.position.y = 0.032
	_target_ring_mat = StandardMaterial3D.new()
	_target_ring_mat.albedo_color = Color(0.99, 0.97, 0.92, 0.78)
	_target_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_target_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_ring.material_override = _target_ring_mat
	add_child(_target_ring)


func _build_lock_badge() -> void:
	_lock_label = Label3D.new()
	_lock_label.text = "Lv.%d" % tier
	_lock_label.font_size = 46
	_lock_label.outline_size = 13
	_lock_label.modulate = Color("#FFFBF4")
	_lock_label.outline_modulate = Color("#4A3F38")
	_lock_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_lock_label.no_depth_test = true
	_lock_label.position = Vector3(0.0, item_height + 0.48, 0.0)
	add_child(_lock_label)


func _apply_solid_variant_color(node: Node, col: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var src_mat := mi.get_active_material(0)
		if src_mat is StandardMaterial3D:
			var dup := src_mat.duplicate() as StandardMaterial3D
			dup.albedo_texture = null
			dup.albedo_color = col
			mi.set_surface_override_material(0, dup)
	for child in node.get_children():
		_apply_solid_variant_color(child, col)


func _soften_material_recursive(node: Node, is_solid_variant: bool = false) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var src_mat := mi.get_active_material(0)
		if src_mat is BaseMaterial3D:
			var dup := src_mat.duplicate() as BaseMaterial3D
			# Cozy matte ceramic/vinyl finish: grounded, clean, zero harsh specular blowout
			dup.roughness = maxf(dup.roughness, 0.42)
			dup.metallic = minf(dup.metallic, 0.06)
			if not is_solid_variant:
				dup.albedo_color = Color(0.95, 0.94, 0.92)
			if dup.emission_enabled:
				dup.emission_energy_multiplier = minf(dup.emission_energy_multiplier, 0.02)
			mi.set_surface_override_material(0, dup)
	for child in node.get_children():
		_soften_material_recursive(child, is_solid_variant)


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


func step_interaction(hole: HoleController, delta: float, board_bounds: Vector2) -> void:
	if state == State.SWALLOWED:
		return

	var can_eat := tier <= hole.hole_level
	if _target_ring and state == State.IDLE:
		_target_ring_mat.albedo_color = Color(0.18, 0.62, 0.40, 0.82) if can_eat else Color(0.98, 0.96, 0.92, 0.56)
	if _lock_label:
		_lock_label.visible = (not can_eat) and (state == State.IDLE)

	if _bounce > 0.0:
		_bounce = maxf(_bounce - delta * 5.0, 0.0)
		if state == State.IDLE:
			var s := 1.0 + sin(_bounce * PI) * 0.14
			_visual_root.scale = Vector3(s, 1.0 / s, s)
	elif state == State.IDLE:
		_visual_root.scale = Vector3.ONE

	var to_hole := Vector3(hole.position.x - position.x, 0.0, hole.position.z - position.z)
	var dist := to_hole.length()

	if state == State.IDLE:
		var magnet_r := hole.get_magnet_radius()
		if can_eat and magnet_r > 0.0 and dist < magnet_r and dist > 0.05:
			var pull_dir := to_hole / dist
			position += pull_dir * 7.6 * delta

		# Calibrated eat threshold matching gobble-pop-demo: (hole_r * 1.05 - item_r * 0.25) * pullFactor
		var suction_r := maxf(0.48, hole.get_suction_radius() - item_radius * 0.24)
		if can_eat and dist < suction_r:
			state = State.PULLING
			if _contact_shadow:
				_contact_shadow.visible = false
			if _target_ring:
				_target_ring.visible = false
			if _lock_label:
				_lock_label.visible = false
			_tilt_axis = Vector3(-to_hole.z, 0.0, to_hole.x).normalized()
			if _tilt_axis.length_squared() < 0.01:
				_tilt_axis = Vector3.RIGHT
		elif (not can_eat) and dist < (hole.current_radius + item_radius * 0.85) and dist > 0.02:
			# Solid oversized bump pushback (just like demo & Hole Stars!)
			var push := (hole.current_radius + item_radius * 0.85 - dist) * 0.26
			position.x -= (to_hole.x / dist) * push
			position.z -= (to_hole.z / dist) * push
			position.x = clampf(position.x, -board_bounds.x + item_radius, board_bounds.x - item_radius)
			position.z = clampf(position.z, -board_bounds.y + item_radius, board_bounds.y - item_radius)
			_bounce = 1.0
	elif state == State.PULLING:
		var pull_dir := to_hole.normalized() if dist > 0.01 else Vector3.ZERO
		_fall_vel.x = lerpf(_fall_vel.x, pull_dir.x * 11.5, minf(delta * 13.0, 1.0))
		_fall_vel.z = lerpf(_fall_vel.z, pull_dir.z * 11.5, minf(delta * 13.0, 1.0))
		_fall_vel.y -= 29.0 * delta
		position += _fall_vel * delta

		_visual_root.rotate(_tilt_axis, delta * 8.2)
		var shrink := clampf(1.0 + position.y * 0.44, 0.18, 1.0)
		_visual_root.scale = Vector3.ONE * shrink

		if position.y < -1.15:
			state = State.SWALLOWED
			swallowed.emit(item_key, tier, xp_value, Vector3(hole.position.x, 0.16, hole.position.z), tint_color)
			queue_free()
