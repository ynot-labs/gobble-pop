extends Control
class_name GameplayHelpersUI

## Commercial In-Game Polish Layer:
## 1. FTUE Lv.1 Animated Drag Hand Guide (infinity/circle sweep until first move)
## 2. Contextual 1-Second Mechanic Tip Pills (Gum / Wall / Bomb / Fever)
## 3. Off-Screen Target Radar Arrows (critical for 30x34 Mega Boss stages!)
## 4. 2D Celebration Confetti Burst (Victory / Chest / Skin Unlock)

var _ftue_root: Control
var _ftue_hand: TextureRect
var _ftue_pill: PanelContainer
var _ftue_active: bool = false
var _ftue_time: float = 0.0
var _ftue_dragged_time: float = 0.0

var _tip_pill: PanelContainer
var _tip_tween: Tween

var _radar_root: Control
var _radar_pool: Array[Control] = []

var _confetti_root: Control
var _confetti_pieces: Array[Dictionary] = []

const CONFETTI_COLORS := [
	Color("#FF52A8"), Color("#22B8EE"), Color("#FACC15"),
	Color("#25CF65"), Color("#A855F7"), Color("#FF8A2B"),
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_radar_root = Control.new()
	_radar_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_radar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_radar_root)

	# Pre-allocate 3 glossy off-screen radar arrow badges
	for i in range(3):
		var badge := _create_radar_badge()
		badge.visible = false
		_radar_root.add_child(badge)
		_radar_pool.append(badge)

	# FTUE Drag Hand Guide
	_ftue_root = Control.new()
	_ftue_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ftue_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ftue_root.visible = false
	add_child(_ftue_root)

	_ftue_hand = CandyUI.make_icon_rect(CandyUI.get_icon("icon_hand"), 96)
	_ftue_hand.pivot_offset = Vector2(48, 48)
	_ftue_root.add_child(_ftue_hand)

	_ftue_pill = CandyUI.create_icon_pill("icon_hole", "DRAG TO GOBBLE!", Color("#22B8EE"), Color("#0B78A8"), 24, 34, Color("#0A4266"))
	_ftue_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ftue_root.add_child(_ftue_pill)

	# Contextual 1-second mechanic tip pill
	_tip_pill = CandyUI.create_icon_pill("icon_fever", "TIP", Color("#EC36A0"), Color("#9B1464"), 24, 36, Color("#5E093C"))
	_tip_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_pill.visible = false
	add_child(_tip_pill)

	# 2D Confetti layer
	_confetti_root = Control.new()
	_confetti_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confetti_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_confetti_root)


func _create_radar_badge() -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(82, 82)

	var ring := PanelContainer.new()
	ring.name = "Bubble"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = Vector2(-34, -34)
	ring.custom_minimum_size = Vector2(68, 68)
	ring.add_theme_stylebox_override("panel", CandyUI.make_pill_style(Color("#FFFDF7"), Color("#EC36A0"), 34, 8, 8))
	root.add_child(ring)

	var item_ic := CandyUI.make_icon_rect(CandyUI.get_icon("item_w1_donut"), 44)
	item_ic.name = "ItemIcon"
	ring.add_child(item_ic)

	var arrow := CandyUI.make_icon_rect(CandyUI.get_icon("icon_arrow"), 40)
	arrow.name = "Arrow"
	arrow.pivot_offset = Vector2(20, 20)
	arrow.position = Vector2(-20, -60)
	arrow.z_index = 2
	root.add_child(arrow)
	return root


func start_ftue_drag_guide() -> void:
	_ftue_active = true
	_ftue_time = 0.0
	_ftue_dragged_time = 0.0
	_ftue_root.visible = true
	_ftue_root.modulate.a = 1.0


func stop_ftue_drag_guide() -> void:
	_ftue_active = false
	_ftue_root.visible = false


func show_mechanic_tip(tip_key: String, icon_name: String, text: String, bg: Color, bevel: Color, outline: Color, force: bool = false) -> void:
	if not force and GameManager.has_seen_tutorial(tip_key):
		return
	GameManager.mark_tutorial_seen(tip_key)
	CandyUI.update_icon_pill(_tip_pill, text, bg, bevel, outline, icon_name)
	_tip_pill.visible = true
	_tip_pill.modulate.a = 1.0
	var vp := get_viewport_rect().size
	_tip_pill.reset_size()
	var w := maxf(_tip_pill.size.x, 300.0)
	_tip_pill.position = Vector2((vp.x - w) * 0.5, vp.y * 0.23)
	if _tip_tween and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_pill.scale = Vector2(0.8, 0.8)
	_tip_pill.pivot_offset = Vector2(w * 0.5, 32.0)
	_tip_tween = create_tween()
	_tip_tween.tween_property(_tip_pill, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tip_tween.tween_interval(1.65)
	_tip_tween.tween_property(_tip_pill, "modulate:a", 0.0, 0.35)
	_tip_tween.tween_callback(func(): _tip_pill.visible = false)


func spawn_confetti(count: int = 48) -> void:
	var vp := get_viewport_rect().size
	for i in range(count):
		var rect := ColorRect.new()
		var sz := randf_range(12.0, 22.0)
		rect.size = Vector2(sz, sz * randf_range(0.55, 1.0))
		rect.pivot_offset = rect.size * 0.5
		rect.color = CONFETTI_COLORS[i % CONFETTI_COLORS.size()]
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.position = Vector2(vp.x * randf_range(0.15, 0.85), vp.y * randf_range(0.18, 0.42))
		_confetti_root.add_child(rect)
		var ang := randf_range(-PI * 0.88, -PI * 0.12)
		var spd := randf_range(380.0, 920.0)
		_confetti_pieces.append({
			"node": rect,
			"vel": Vector2(cos(ang) * spd, sin(ang) * spd),
			"rot_spd": randf_range(-10.0, 10.0),
			"life": randf_range(1.3, 2.2),
		})


func hide_radars() -> void:
	for b in _radar_pool:
		b.visible = false


func step_helpers(delta: float, playing: bool, camera: Camera3D, hole: HoleController, items: Array[SwallowableItem], remaining_targets: Dictionary) -> void:
	# 1. Step 2D confetti even when modal is visible!
	for i in range(_confetti_pieces.size() - 1, -1, -1):
		var p: Dictionary = _confetti_pieces[i]
		var n: ColorRect = p["node"]
		p["life"] -= delta
		if p["life"] <= 0.0 or not is_instance_valid(n):
			if is_instance_valid(n):
				n.queue_free()
			_confetti_pieces.remove_at(i)
			continue
		var v: Vector2 = p["vel"]
		v.y += 1280.0 * delta
		v.x *= (1.0 - delta * 1.1)
		p["vel"] = v
		n.position += v * delta
		n.rotation += float(p["rot_spd"]) * delta
		n.modulate.a = clampf(float(p["life"]) * 1.4, 0.0, 1.0)

	# 2. FTUE Drag Hand Guide (infinity-loop motion near screen center)
	if _ftue_active and playing:
		_ftue_time += delta
		var vp := get_viewport_rect().size
		var cx := vp.x * 0.5
		var cy := vp.y * 0.60
		var ox := sin(_ftue_time * 2.4) * 145.0
		var oy := sin(_ftue_time * 4.8) * 58.0
		_ftue_hand.position = Vector2(cx + ox - 30.0, cy + oy - 18.0)
		var s := 0.94 + 0.08 * sin(_ftue_time * 5.0)
		_ftue_hand.scale = Vector2(s, s)
		_ftue_pill.reset_size()
		_ftue_pill.position = Vector2((vp.x - _ftue_pill.size.x) * 0.5, cy + 95.0)

		if hole and (hole.joy_active or hole.position.length() > 1.2):
			_ftue_dragged_time += delta
			if _ftue_dragged_time > 0.35:
				GameManager.mark_tutorial_seen("drag")
				_ftue_active = false
				var tw := create_tween()
				tw.tween_property(_ftue_root, "modulate:a", 0.0, 0.25)
				tw.tween_callback(func(): _ftue_root.visible = false)
	elif not playing and _ftue_active:
		_ftue_root.visible = false

	# 3. Off-Screen Target Radar Arrows (shows up to 3 nearest off-screen remaining targets)
	if not playing or camera == null or hole == null:
		hide_radars()
		return

	var vp_size := get_viewport_rect().size
	var pad_x := 64.0
	var pad_top := 240.0
	var pad_bot := 185.0
	var offscreen: Array[Dictionary] = []

	for it in items:
		if not is_instance_valid(it) or not it.is_objective:
			continue
		if int(remaining_targets.get(it.item_key, 0)) <= 0:
			continue
		var sp := camera.unproject_position(it.global_position)
		var behind := camera.is_position_behind(it.global_position)
		var in_view := (not behind) and sp.x >= 28.0 and sp.x <= vp_size.x - 28.0 and sp.y >= 170.0 and sp.y <= vp_size.y - 140.0
		if not in_view:
			if behind:
				sp = vp_size - sp
			offscreen.append({
				"dist": hole.position.distance_to(it.position),
				"sp": sp,
				"key": it.item_key,
			})

	offscreen.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))

	var center := vp_size * 0.5
	var pulse := 1.0 + 0.07 * sin(Time.get_ticks_msec() * 0.008)
	for i in range(_radar_pool.size()):
		var badge := _radar_pool[i]
		if i >= offscreen.size():
			badge.visible = false
			continue
		var entry: Dictionary = offscreen[i]
		var sp: Vector2 = entry["sp"]
		var dir := (sp - center)
		if dir.length_squared() < 1.0:
			dir = Vector2.UP
		dir = dir.normalized()

		# Clamp onto inner safe frame along ray from center
		var rx := (vp_size.x * 0.5 - pad_x) / maxf(absf(dir.x), 0.001)
		var ry_top := (center.y - pad_top) / maxf(absf(dir.y), 0.001)
		var ry_bot := (vp_size.y - pad_bot - center.y) / maxf(absf(dir.y), 0.001)
		var ry := ry_top if dir.y < 0.0 else ry_bot
		var t := minf(rx, ry)
		var edge_pos := center + dir * t

		badge.visible = true
		badge.position = edge_pos
		badge.scale = Vector2(pulse, pulse)

		var bubble := badge.get_node_or_null("Bubble")
		if bubble:
			var ic := bubble.get_node_or_null("ItemIcon") as TextureRect
			if ic:
				ic.texture = CandyUI.get_item_icon(str(entry["key"]))
		var arrow := badge.get_node_or_null("Arrow") as TextureRect
		if arrow:
			# icon_arrow points straight UP (0 rad = UP = (0, -1))
			arrow.rotation = dir.angle() + PI * 0.5
			arrow.position = dir * 48.0 - Vector2(20.0, 20.0)
