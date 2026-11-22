extends Node3D
class_name SwallowableItem

signal swallowed(item_key: String, tier: int, xp: float, world_pos: Vector3, tint: Color)

enum State { IDLE, PULLING, SWALLOWED }

var item_key: String = ""
var tier: int = 1
var xp_value: float = 10.0
var item_radius: float = 0.3
var tint_color: Color = Color.WHITE
var state: State = State.IDLE

var _fall_vel := Vector3.ZERO
var _tilt_axis := Vector3.RIGHT
var _visual_root: Node3D
var _bump_cooldown: float = 0.0


func setup(key: String, def: Dictionary, spawn_pos: Vector3, color_idx: int = 0) -> void:
	item_key = key
	tier = int(def.get("tier", 1))
	xp_value = float(def.get("xp", 10.0))
	item_radius = float(def.get("radius", 0.3))
	var colors: Array = def.get("colors", ["#FF6FA5"])
	var hex: String = colors[color_idx % colors.size()]
	tint_color = Color(hex)
	position = spawn_pos

	_visual_root = Node3D.new()
	add_child(_visual_root)

	# Auto-load Blender GLB if present (Phase 2+), otherwise stylized vinyl greybox
	var model_path: String = str(def.get("model", ""))
	if model_path != "" and ResourceLoader.exists(model_path):
		var packed: PackedScene = load(model_path)
		if packed:
			var inst := packed.instantiate()
			if item_key == "w1_grand_cake":
				inst.scale = Vector3(1.28, 1.28, 1.28)
			elif item_key == "w1_sprinkle":
				inst.rotation.y = randf() * TAU
				_apply_variant_tint(inst, tint_color)
			elif item_key == "w1_gummy_bear" or item_key == "w1_macaron":
				if color_idx > 0:
					_apply_variant_tint(inst, tint_color)
			elif item_key == "w1_donut" and color_idx == 1:
				_apply_variant_tint(inst, Color("#8CE0FF"))
			_visual_root.add_child(inst)
			return

	_build_stylized_greybox(str(def.get("shape", "sphere")), float(def.get("height", 0.4)))


func _apply_variant_tint(node: Node, col: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var src_mat := mi.get_active_material(0)
		if src_mat is BaseMaterial3D:
			var dup := src_mat.duplicate() as BaseMaterial3D
			dup.albedo_color = col
			mi.set_surface_override_material(0, dup)
	for child in node.get_children():
		_apply_variant_tint(child, col)


func _build_stylized_greybox(shape: String, h: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint_color
	mat.roughness = 0.24
	mat.metallic = 0.05

	match shape:
		"capsule":
			var m := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = item_radius * 0.55
			cap.height = item_radius * 2.1
			m.mesh = cap
			m.material_override = mat
			m.rotation_degrees = Vector3(90, randf() * 180.0, 0)
			m.position.y = cap.radius
			_visual_root.add_child(m)
		"strawberry":
			var body := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = item_radius
			sph.height = h
			body.mesh = sph
			body.material_override = mat
			body.position.y = h * 0.5
			_visual_root.add_child(body)

			var leaf := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = item_radius * 0.65
			cyl.bottom_radius = item_radius * 0.2
			cyl.height = 0.09
			leaf.mesh = cyl
			var gmat := StandardMaterial3D.new()
			gmat.albedo_color = Color("#34C759")
			gmat.roughness = 0.3
			leaf.material_override = gmat
			leaf.position.y = h * 0.92
			_visual_root.add_child(leaf)
		"macaron":
			var cream_mat := StandardMaterial3D.new()
			cream_mat.albedo_color = Color("#FFF9EE")
			cream_mat.roughness = 0.2
			for idx in range(3):
				var disc := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = item_radius * (0.94 if idx == 1 else 1.0)
				cyl.bottom_radius = cyl.top_radius
				cyl.height = h * (0.28 if idx == 1 else 0.34)
				disc.mesh = cyl
				disc.material_override = cream_mat if idx == 1 else mat
				disc.position.y = h * (0.18 + idx * 0.31)
				_visual_root.add_child(disc)
		"donut":
			var m := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.outer_radius = item_radius
			tor.inner_radius = item_radius * 0.42
			m.mesh = tor
			m.material_override = mat
			m.position.y = h * 0.5
			_visual_root.add_child(m)
		"cake":
			var pink_mat := StandardMaterial3D.new()
			pink_mat.albedo_color = Color("#FF74A4")
			pink_mat.roughness = 0.22
			var red_mat := StandardMaterial3D.new()
			red_mat.albedo_color = Color("#FF2E4C")
			red_mat.roughness = 0.2

			var tier1 := MeshInstance3D.new()
			var c1 := CylinderMesh.new()
			c1.top_radius = item_radius
			c1.bottom_radius = item_radius * 1.03
			c1.height = h * 0.48
			tier1.mesh = c1
			tier1.material_override = mat
			tier1.position.y = c1.height * 0.5
			_visual_root.add_child(tier1)

			var tier2 := MeshInstance3D.new()
			var c2 := CylinderMesh.new()
			c2.top_radius = item_radius * 0.68
			c2.bottom_radius = item_radius * 0.72
			c2.height = h * 0.38
			tier2.mesh = c2
			tier2.material_override = pink_mat
			tier2.position.y = c1.height + c2.height * 0.5
			_visual_root.add_child(tier2)

			var berry := MeshInstance3D.new()
			var bs := SphereMesh.new()
			bs.radius = item_radius * 0.24
			bs.height = item_radius * 0.52
			berry.mesh = bs
			berry.material_override = red_mat
			berry.position.y = c1.height + c2.height + bs.radius * 0.75
			_visual_root.add_child(berry)
		"cup":
			var cup := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = item_radius
			cyl.bottom_radius = item_radius * 0.78
			cyl.height = h * 0.75
			cup.mesh = cyl
			cup.material_override = mat
			cup.position.y = cyl.height * 0.5
			_visual_root.add_child(cup)

			var straw := MeshInstance3D.new()
			var sc := CylinderMesh.new()
			sc.top_radius = 0.08
			sc.bottom_radius = 0.08
			sc.height = h * 0.55
			straw.mesh = sc
			var smat := StandardMaterial3D.new()
			smat.albedo_color = Color("#FF9EC4")
			straw.material_override = smat
			straw.position = Vector3(0.06, h * 0.82, 0.0)
			straw.rotation_degrees.z = -12.0
			_visual_root.add_child(straw)
		_:
			var m := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = item_radius
			sph.height = h
			m.mesh = sph
			m.material_override = mat
			m.position.y = h * 0.5
			_visual_root.add_child(m)


func step_interaction(hole: HoleController, delta: float) -> void:
	if state == State.SWALLOWED:
		return

	if _bump_cooldown > 0.0:
		_bump_cooldown -= delta

	var to_hole := Vector3(hole.position.x - position.x, 0.0, hole.position.z - position.z)
	var dist := to_hole.length()

	if state == State.IDLE:
		var can_eat := tier <= hole.hole_level
		var magnet_r := hole.get_magnet_radius()

		# Magnet gently drags edible objects toward the hole
		if can_eat and magnet_r > 0.0 and dist < magnet_r and dist > 0.05:
			var pull_dir := to_hole / dist
			position += pull_dir * 7.8 * delta

		var capture_r := hole.get_suction_radius()
		if dist < capture_r:
			if can_eat:
				state = State.PULLING
				_tilt_axis = Vector3(-to_hole.z, 0.0, to_hole.x).normalized()
				if _tilt_axis.length_squared() < 0.01:
					_tilt_axis = Vector3.RIGHT
			elif _bump_cooldown <= 0.0:
				# Too large: playful bump feedback
				_bump_cooldown = 0.35
				var tw := create_tween()
				tw.tween_property(_visual_root, "scale", Vector3(1.12, 0.88, 1.12), 0.07)
				tw.tween_property(_visual_root, "scale", Vector3.ONE, 0.12)
	elif state == State.PULLING:
		var pull_dir := to_hole.normalized() if dist > 0.01 else Vector3.ZERO
		_fall_vel.x = lerpf(_fall_vel.x, pull_dir.x * 11.0, minf(delta * 12.0, 1.0))
		_fall_vel.z = lerpf(_fall_vel.z, pull_dir.z * 11.0, minf(delta * 12.0, 1.0))
		_fall_vel.y -= 28.0 * delta
		position += _fall_vel * delta

		_visual_root.rotate(_tilt_axis, delta * 7.5)
		var shrink := clampf(1.0 + position.y * 0.42, 0.22, 1.0)
		_visual_root.scale = Vector3.ONE * shrink

		if position.y < -1.15:
			state = State.SWALLOWED
			swallowed.emit(item_key, tier, xp_value, Vector3(hole.position.x, 0.15, hole.position.z), tint_color)
			queue_free()
