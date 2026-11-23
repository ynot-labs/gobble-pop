extends Node3D
class_name FloatingIslandBuilder

## Builds a Cover-Art-Quality 3D Rounded Floating Wooden Tabletop Island + Pastel Sky Clouds
## + World-Themed Surrounding Diorama Props so PC 16:9 Landscape & Mobile Portrait frames
## look lush, grounded, and completely free of empty solid-color void!

const ISLAND_THEMES := {
	1: {
		"wood_top": Color("#ECA963"),
		"wood_mid": Color("#D1853F"),
		"wood_bot": Color("#9F5C24"),
		"trim": Color("#FFFBF0"),
		"cloud": Color("#FFFFFF"),
		"accent_a": Color("#FF6EB3"),
		"accent_b": Color("#4DE2BE"),
		"accent_c": Color("#FFD94A"),
	},
	2: {
		"wood_top": Color("#F5C05A"),
		"wood_mid": Color("#D8942E"),
		"wood_bot": Color("#A36616"),
		"trim": Color("#FFFDF4"),
		"cloud": Color("#FFFFFF"),
		"accent_a": Color("#38BDF8"),
		"accent_b": Color("#FF6EB3"),
		"accent_c": Color("#A855F7"),
	},
	3: {
		"wood_top": Color("#E09658"),
		"wood_mid": Color("#B8662E"),
		"wood_bot": Color("#7F3F1A"),
		"trim": Color("#FFF4E4"),
		"cloud": Color("#FFF9F0"),
		"accent_a": Color("#FF5A79"),
		"accent_b": Color("#FACC15"),
		"accent_c": Color("#38BDF8"),
	},
	4: {
		"wood_top": Color("#9A84E0"),
		"wood_mid": Color("#715AC0"),
		"wood_bot": Color("#4C3892"),
		"trim": Color("#F6F0FF"),
		"cloud": Color("#FAF6FF"),
		"accent_a": Color("#C084FC"),
		"accent_b": Color("#38BDF8"),
		"accent_c": Color("#FDE047"),
	},
	5: {
		"wood_top": Color("#56BFFA"),
		"wood_mid": Color("#2E8CE0"),
		"wood_bot": Color("#1856A8"),
		"trim": Color("#F0FAFF"),
		"cloud": Color("#FFFFFF"),
		"accent_a": Color("#FF4D94"),
		"accent_b": Color("#FFD93D"),
		"accent_c": Color("#4ADE80"),
	},
}

var _island_root: Node3D
var _floaters_root: Node3D
var _floaters: Array[Dictionary] = []
var _time: float = 0.0


func _ready() -> void:
	_island_root = Node3D.new()
	add_child(_island_root)
	_floaters_root = Node3D.new()
	add_child(_floaters_root)


func _process(delta: float) -> void:
	_time += delta
	for f in _floaters:
		var node: Node3D = f["node"]
		if is_instance_valid(node):
			var base_y: float = f["base_y"]
			var amp: float = f["amp"]
			var spd: float = f["spd"]
			var ph: float = f["phase"]
			node.position.y = base_y + sin(_time * spd + ph) * amp
			var rot_spd: float = f["rot_spd"]
			if absf(rot_spd) > 0.001:
				node.rotation.y += delta * rot_spd


func rebuild(board_half: Vector2, world_id: int, corner_radius: float = 1.65) -> void:
	for c in _island_root.get_children():
		c.queue_free()
	for c in _floaters_root.get_children():
		c.queue_free()
	_floaters.clear()

	var theme: Dictionary = ISLAND_THEMES.get(world_id, ISLAND_THEMES[1])
	var toy_shader: Shader = load("res://shaders/toy_gloss.gdshader")

	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = theme["trim"]
	trim_mat.roughness = 0.28
	trim_mat.emission_enabled = true
	trim_mat.emission = theme["trim"]
	trim_mat.emission_energy_multiplier = 0.34
	var wood_top_mat := _make_toy_mat(toy_shader, theme["wood_top"], 0.36, 0.20)
	var wood_mid_mat := _make_toy_mat(toy_shader, theme["wood_mid"], 0.40, 0.16)
	var wood_bot_mat := _make_toy_mat(toy_shader, theme["wood_bot"], 0.46, 0.10)

	# 1. Outer glossy ceramic lip rim (wraps right around the rounded tabletop edge!)
	_build_rounded_slab(
		board_half + Vector2(0.44, 0.44),
		corner_radius + 0.38,
		-0.38, -0.02,
		trim_mat, 10
	)

	# 2. Thick warm maple wooden floating island body (3 stepped beveled tiers just like cover_splash.jpg!)
	_build_rounded_slab(
		board_half + Vector2(0.66, 0.66),
		corner_radius + 0.56,
		-1.35, -0.26,
		wood_top_mat, 10
	)
	_build_rounded_slab(
		board_half + Vector2(0.50, 0.50),
		corner_radius + 0.44,
		-2.05, -1.28,
		wood_mid_mat, 10
	)
	_build_rounded_slab(
		board_half + Vector2(0.18, 0.18),
		corner_radius + 0.20,
		-2.55, -1.98,
		wood_bot_mat, 10
	)

	# 3. Surrounding Fluffy Pastel Clouds & Floating Candy Diorama Islands (fills PC 16:9 sides lushly!)
	var cloud_mat := _make_toy_mat(toy_shader, theme["cloud"], 0.55, 0.42)
	var accent_mats := [
		_make_toy_mat(toy_shader, theme["accent_a"], 0.18, 0.40),
		_make_toy_mat(toy_shader, theme["accent_b"], 0.18, 0.40),
		_make_toy_mat(toy_shader, theme["accent_c"], 0.18, 0.40),
	]

	var rng := RandomNumberGenerator.new()
	rng.seed = 4200 + world_id * 137 + int(board_half.x * 10.0)

	# Ring of 16 fluffy stylized cloud clusters around the left/right/back/front perimeter
	var cloud_count := 16
	for i in range(cloud_count):
		var ang := (float(i) / float(cloud_count)) * TAU + rng.randf_range(-0.14, 0.14)
		var ring_x := board_half.x + rng.randf_range(3.6, 8.8)
		var ring_z := board_half.y + rng.randf_range(3.2, 7.6)
		var cx := cos(ang) * ring_x
		var cz := sin(ang) * ring_z
		var cy := rng.randf_range(-3.6, -1.2)
		var cloud := _create_cloud_cluster(cloud_mat, rng.randf_range(1.15, 2.15), rng)
		cloud.position = Vector3(cx, cy, cz)
		cloud.rotation.y = rng.randf() * TAU
		_floaters_root.add_child(cloud)
		_floaters.append({
			"node": cloud,
			"base_y": cy,
			"amp": rng.randf_range(0.18, 0.42),
			"spd": rng.randf_range(0.65, 1.25),
			"phase": rng.randf() * TAU,
			"rot_spd": 0.0,
		})

	# 12 Floating miniature pastel candy islands / sparkles on the left & right flanks (hero framing on 16:9!)
	var side_spots := [
		Vector2(-board_half.x - 3.0, -board_half.y * 0.55),
		Vector2(-board_half.x - 4.8, 0.2),
		Vector2(-board_half.x - 3.2, board_half.y * 0.52),
		Vector2(-board_half.x - 6.8, -board_half.y * 0.15),
		Vector2(-board_half.x - 6.2, board_half.y * 0.45),
		Vector2(board_half.x + 3.0, -board_half.y * 0.55),
		Vector2(board_half.x + 4.8, 0.2),
		Vector2(board_half.x + 3.2, board_half.y * 0.52),
		Vector2(board_half.x + 6.8, -board_half.y * 0.15),
		Vector2(board_half.x + 6.2, board_half.y * 0.45),
		Vector2(-board_half.x * 0.45, -board_half.y - 3.4),
		Vector2(board_half.x * 0.45, -board_half.y - 3.4),
	]
	for idx in range(side_spots.size()):
		var pt: Vector2 = side_spots[idx]
		var deco := Node3D.new()
		var py := rng.randf_range(-1.4, 0.4)
		deco.position = Vector3(pt.x, py, pt.y)
		var mat: ShaderMaterial = accent_mats[idx % accent_mats.size()]

		if idx % 3 == 0:
			# Floating glossy donut/candy ring!
			var tor := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.outer_radius = rng.randf_range(0.75, 1.15)
			tm.inner_radius = tm.outer_radius * 0.42
			tor.mesh = tm
			tor.material_override = mat
			tor.rotation_degrees = Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 360), rng.randf_range(-25, 25))
			deco.add_child(tor)
		elif idx % 3 == 1:
			# Floating pastel candy stepping-stone mini-island!
			var cyl := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = rng.randf_range(0.95, 1.45)
			cm.bottom_radius = cm.top_radius * 0.78
			cm.height = 0.65
			cm.radial_segments = 20
			cyl.mesh = cm
			cyl.material_override = wood_top_mat
			deco.add_child(cyl)

			var cap := MeshInstance3D.new()
			var cap_m := CylinderMesh.new()
			cap_m.top_radius = cm.top_radius * 0.92
			cap_m.bottom_radius = cm.top_radius * 0.96
			cap_m.height = 0.22
			cap_m.radial_segments = 20
			cap.mesh = cap_m
			cap.position.y = 0.36
			cap.material_override = mat
			deco.add_child(cap)
		else:
			# Floating sparkling star-gem octahedron!
			var gem := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = rng.randf_range(0.42, 0.68)
			sm.height = sm.radius * 2.4
			sm.radial_segments = 4
			sm.rings = 2
			gem.mesh = sm
			gem.material_override = mat
			deco.add_child(gem)

		_floaters_root.add_child(deco)
		_floaters.append({
			"node": deco,
			"base_y": py,
			"amp": rng.randf_range(0.22, 0.50),
			"spd": rng.randf_range(0.9, 1.7),
			"phase": rng.randf() * TAU,
			"rot_spd": rng.randf_range(0.25, 0.65) * (1.0 if idx % 2 == 0 else -1.0),
		})


func _make_toy_mat(shader: Shader, col: Color, rough: float, rim: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("albedo_tint", col)
	m.set_shader_parameter("use_albedo_tex", false)
	m.set_shader_parameter("use_vertex_color", false)
	m.set_shader_parameter("roughness_val", rough)
	m.set_shader_parameter("rim_strength", rim)
	return m


func _create_cloud_cluster(mat: Material, s: float, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var puffs := [
		Vector3(0.0, 0.0, 0.0),
		Vector3(-0.95, -0.12, 0.18),
		Vector3(0.95, -0.10, -0.15),
		Vector3(0.35, 0.16, 0.58),
		Vector3(-0.42, 0.10, -0.52),
	]
	var radii := [1.05, 0.78, 0.82, 0.68, 0.72]
	for i in range(puffs.size()):
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = radii[i] * s
		sp.height = radii[i] * 1.42 * s
		sp.radial_segments = 16
		sp.rings = 10
		mi.mesh = sp
		mi.position = puffs[i] * s + Vector3(0, rng.randf_range(-0.05, 0.05), 0)
		mi.material_override = mat
		root.add_child(mi)
	return root


func _build_rounded_slab(half: Vector2, r: float, y_bot: float, y_top: float, mat: Material, corner_segs: int = 8) -> void:
	var cr := minf(r, minf(half.x * 0.45, half.y * 0.45))
	var pts: Array[Vector2] = []
	var corners := [
		{"c": Vector2(half.x - cr, half.y - cr), "a0": 0.0, "a1": PI * 0.5},
		{"c": Vector2(-half.x + cr, half.y - cr), "a0": PI * 0.5, "a1": PI},
		{"c": Vector2(-half.x + cr, -half.y + cr), "a0": PI, "a1": PI * 1.5},
		{"c": Vector2(half.x - cr, -half.y + cr), "a0": PI * 1.5, "a1": TAU},
	]
	for cn in corners:
		var center: Vector2 = cn["c"]
		var a0: float = cn["a0"]
		var a1: float = cn["a1"]
		for k in range(corner_segs + 1):
			var a := lerpf(a0, a1, float(k) / float(corner_segs))
			pts.append(center + Vector2(cos(a) * cr, sin(a) * cr))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var n := pts.size()
	# Top cap (slightly inset bevel look handled by stepped slabs)
	var center_top := Vector3(0.0, y_top, 0.0)
	for i in range(n):
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		st.set_normal(Vector3.UP)
		st.add_vertex(center_top)
		st.add_vertex(Vector3(p1.x, y_top, p1.y))
		st.add_vertex(Vector3(p0.x, y_top, p0.y))

	# Outer curved walls with smooth outward normals
	for i in range(n):
		var p0 := pts[i]
		var p1 := pts[(i + 1) % n]
		var edge := Vector3(p1.x - p0.x, 0.0, p1.y - p0.y)
		var nrm := Vector3(-edge.z, 0.0, edge.x).normalized()
		if nrm.dot(Vector3(p0.x, 0.0, p0.y)) < 0.0:
			nrm = -nrm

		var t0 := Vector3(p0.x, y_top, p0.y)
		var t1 := Vector3(p1.x, y_top, p1.y)
		var b0 := Vector3(p0.x, y_bot, p0.y)
		var b1 := Vector3(p1.x, y_bot, p1.y)

		st.set_normal(nrm)
		st.add_vertex(t0)
		st.add_vertex(t1)
		st.add_vertex(b1)
		st.add_vertex(t0)
		st.add_vertex(b1)
		st.add_vertex(b0)

	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_island_root.add_child(mi)
