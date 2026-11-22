extends Node3D

## Main Stage for Gobble Pop! — All 4 Worlds (Lv.1 - Lv.50) + 4 Epic MEGA BOSS Stages!
## World 1: Sugar Rush Bakery (Lv.1-20)   | World 2: Gacha Toybox (Lv.21-30)
## World 3: Neon Bento Street (Lv.31-40)  | World 4: Cozy Alchemist Desk (Lv.41-50)

const WORLD_META := {
	1: {"name": "WORLD 1: SUGAR RUSH BAKERY", "short": "W1 Bakery", "start": 1,  "hard": 5,  "cliff": 10, "mega": 20, "trap_name": "BUBBLEGUM"},
	2: {"name": "WORLD 2: GACHA TOYBOX",      "short": "W2 Toybox", "start": 21, "hard": 25, "cliff": 29, "mega": 30, "trap_name": "BUBBLEGUM"},
	3: {"name": "WORLD 3: NEON BENTO STREET", "short": "W3 Bento",  "start": 31, "hard": 35, "cliff": 39, "mega": 40, "trap_name": "CHEESE"},
	4: {"name": "WORLD 4: ALCHEMIST DESK",    "short": "W4 Magic",  "start": 41, "hard": 45, "cliff": 49, "mega": 50, "trap_name": "SLIME"},
}

var _env: Environment
var _camera: Camera3D
var _table_mesh: MeshInstance3D
var _table_mat: ShaderMaterial
var _hole: HoleController
var _entities_root: Node3D
var _particles_root: Node3D
var _popups_root: Node3D

var _items: Array[SwallowableItem] = []
var _powerups: Array[PowerupItem] = []
var _traps: Array[StickyTrap] = []
var _walls: Array[RubberWall] = []
var _bombs: Array[BombHazard] = []

var _level_data: Dictionary = {}
var _level_number: int = 1
var _world_id: int = 1
var _is_mega_stage: bool = false
var _board_half := Vector2(8.0, 10.0)
var _remaining_targets: Dictionary = {}
var _target_labels: Dictionary = {}

var _time_left: float = 45.0
var _ice_freeze_timer: float = 0.0
var _bomb_flash_timer: float = 0.0
var _last_tick_sec: int = 6
var _playing: bool = false
var _used_rv_this_run: bool = false
var _attempts_this_level: int = 0
var _camera_shake: float = 0.0
var _target_cam_height: float = 17.5

# UI References
var _hud_layer: CanvasLayer
var _joystick_overlay: JoystickOverlay
var _world_buttons: Dictionary = {}
var _stage_buttons: Dictionary = {}
var _bomb_flash_rect: ColorRect
var _timer_label: Label
var _level_label: Label
var _streak_label: Label
var _hole_lvl_label: Label
var _fever_bar: ProgressBar
var _targets_box: HBoxContainer
var _frost_rect: ColorRect
var _frost_mat: ShaderMaterial
var _overlay_panel: PanelContainer
var _overlay_badge: Label
var _overlay_title: Label
var _overlay_desc: Label
var _btn_primary: Button
var _btn_secondary: Button
var _btn_mute: Button
var _buff_label: Label


func _ready() -> void:
	_build_hud()
	_build_3d_stage()
	_joystick_overlay.hole = _hole
	AdManager.rewarded_ad_completed.connect(_on_rewarded_completed)
	_load_level(clampi(GameManager.current_level, 1, 50), true)
	PlatformBridge.notify_game_ready()


func _build_3d_stage() -> void:
	var env_node := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color("#B7F4DD")
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(1.0, 0.99, 0.97)
	_env.ambient_light_energy = 0.88
	env_node.environment = _env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-56, 30, 0)
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	add_child(sun)

	_camera = Camera3D.new()
	_camera.fov = 45.0
	add_child(_camera)
	_camera.look_at_from_position(Vector3(0.0, 17.5, 9.8), Vector3.ZERO, Vector3.UP)

	_table_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 28.0)
	_table_mesh.mesh = plane
	_table_mat = ShaderMaterial.new()
	_table_mat.shader = load("res://shaders/tabletop_cutout.gdshader")
	_table_mesh.material_override = _table_mat
	add_child(_table_mesh)

	_hole = HoleController.new()
	_hole.level_changed.connect(_on_hole_level_changed)
	_hole.fever_changed.connect(_on_fever_changed)
	_hole.buff_changed.connect(_on_buff_changed)
	_hole.sticky_triggered.connect(_on_sticky_triggered)
	add_child(_hole)

	_entities_root = Node3D.new()
	add_child(_entities_root)
	_particles_root = Node3D.new()
	add_child(_particles_root)
	_popups_root = Node3D.new()
	add_child(_popups_root)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)

	_frost_rect = ColorRect.new()
	_frost_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost_mat = ShaderMaterial.new()
	_frost_mat.shader = load("res://shaders/frost_overlay.gdshader")
	_frost_rect.material = _frost_mat
	_hud_layer.add_child(_frost_rect)

	_bomb_flash_rect = ColorRect.new()
	_bomb_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bomb_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bomb_flash_rect.color = Color(1.0, 0.12, 0.18, 0.0)
	_hud_layer.add_child(_bomb_flash_rect)

	_joystick_overlay = JoystickOverlay.new()
	_joystick_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_joystick_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_joystick_overlay)

	var top_margin := MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_left", 14)
	top_margin.add_theme_constant_override("margin_right", 14)
	top_margin.add_theme_constant_override("margin_top", 12)
	_hud_layer.add_child(top_margin)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 8)
	top_margin.add_child(top_vbox)

	# Row 0A: 4-World Selector Bar
	var world_row := HBoxContainer.new()
	world_row.alignment = BoxContainer.ALIGNMENT_CENTER
	world_row.add_theme_constant_override("separation", 6)
	top_vbox.add_child(world_row)

	for wid in [1, 2, 3, 4]:
		var wb := _make_small_tab(str(WORLD_META[wid]["short"]), Color("#1E293B"))
		var target_w: int = wid
		wb.pressed.connect(func(): _load_level(int(WORLD_META[target_w]["start"]), true))
		world_row.add_child(wb)
		_world_buttons[wid] = wb

	# Row 0B: Active World Key Stage Jumpers (< | Start | Hard | CLIFF | MEGA! | >)
	var stage_row := HBoxContainer.new()
	stage_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_row.add_theme_constant_override("separation", 6)
	top_vbox.add_child(stage_row)

	var btn_prev := _make_small_tab("< Prev", Color("#334155"))
	btn_prev.pressed.connect(func(): _load_level(50 if _level_number <= 1 else _level_number - 1, true))
	stage_row.add_child(btn_prev)

	for kind in ["start", "hard", "cliff", "mega"]:
		var col := Color("#9F1239") if kind == "mega" else (Color("#BE123C") if kind == "cliff" else Color("#334155"))
		var txt := "MEGA BOSS" if kind == "mega" else ("CLIFF" if kind == "cliff" else ("HARD" if kind == "hard" else "START"))
		var sb := _make_small_tab(txt, col)
		var k: String = kind
		sb.pressed.connect(func(): _load_level(int(WORLD_META[_world_id][k]), true))
		stage_row.add_child(sb)
		_stage_buttons[kind] = sb

	var btn_next := _make_small_tab("Next >", Color("#334155"))
	btn_next.pressed.connect(func(): _load_level((_level_number % 50) + 1, true))
	stage_row.add_child(btn_next)

	# Row 1: Level Badge | Timer | Streak + Mute
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	top_vbox.add_child(row1)

	_level_label = _make_pill_label("W1 L1", Color("#0EA5E9"), 24)
	row1.add_child(_level_label)

	var sp1 := Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sp1)

	_timer_label = _make_pill_label("45.0s", Color("#14B8A6"), 36)
	row1.add_child(_timer_label)

	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sp2)

	_streak_label = _make_pill_label("STREAK 0", Color("#F59E0B"), 22)
	row1.add_child(_streak_label)

	_btn_mute = _make_small_tab("SFX ON", Color("#0284C7"))
	_btn_mute.pressed.connect(_on_mute_pressed)
	row1.add_child(_btn_mute)

	# Row 2: Target Checklist
	_targets_box = HBoxContainer.new()
	_targets_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_targets_box.add_theme_constant_override("separation", 10)
	top_vbox.add_child(_targets_box)

	# Row 3: Hole Level + Fever Bar
	var row3 := HBoxContainer.new()
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	row3.add_theme_constant_override("separation", 12)
	top_vbox.add_child(row3)

	_hole_lvl_label = _make_pill_label("HOLE LV.1", Color("#10B981"), 22)
	row3.add_child(_hole_lvl_label)

	_fever_bar = ProgressBar.new()
	_fever_bar.custom_minimum_size = Vector2(300, 22)
	_fever_bar.max_value = 100.0
	_fever_bar.value = 0.0
	_fever_bar.show_percentage = false
	row3.add_child(_fever_bar)

	_buff_label = Label.new()
	_buff_label.add_theme_font_size_override("font_size", 26)
	_buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buff_label.modulate = Color("#BE123C")
	top_vbox.add_child(_buff_label)

	# Bottom Booster Row
	var bot_bar := HBoxContainer.new()
	bot_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_bar.offset_top = -108
	bot_bar.offset_bottom = -20
	bot_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_bar.add_theme_constant_override("separation", 16)
	_hud_layer.add_child(bot_bar)

	var btn_rv_ice := _make_action_button("[AD] FREEZE +6s", Color("#0EA5E9"))
	btn_rv_ice.pressed.connect(func(): AdManager.show_rewarded("in_level_ice"))
	bot_bar.add_child(btn_rv_ice)

	var btn_rv_mag := _make_action_button("[AD] MAGNET 7s", Color("#9333EA"))
	btn_rv_mag.pressed.connect(func(): AdManager.show_rewarded("in_level_magnet"))
	bot_bar.add_child(btn_rv_mag)

	# Modal Overlay
	_overlay_panel = PanelContainer.new()
	_overlay_panel.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_panel.custom_minimum_size = Vector2(820, 620)
	_overlay_panel.offset_left = -410
	_overlay_panel.offset_right = 410
	_overlay_panel.offset_top = -310
	_overlay_panel.offset_bottom = 310
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.99, 0.97, 0.97)
	style.border_color = Color("#14B8A6")
	style.set_border_width_all(6)
	style.set_corner_radius_all(34)
	style.set_content_margin_all(34)
	_overlay_panel.add_theme_stylebox_override("panel", style)
	_hud_layer.add_child(_overlay_panel)

	var ov_box := VBoxContainer.new()
	ov_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ov_box.add_theme_constant_override("separation", 18)
	_overlay_panel.add_child(ov_box)

	_overlay_badge = _make_pill_label("WORLD 1", Color("#0F766E"), 24)
	_overlay_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov_box.add_child(_overlay_badge)

	_overlay_title = Label.new()
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 46)
	_overlay_title.modulate = Color("#0F172A")
	ov_box.add_child(_overlay_title)

	_overlay_desc = Label.new()
	_overlay_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_desc.add_theme_font_size_override("font_size", 26)
	_overlay_desc.modulate = Color("#475569")
	ov_box.add_child(_overlay_desc)

	_btn_primary = _make_action_button("PLAY!", Color("#10B981"))
	_btn_primary.custom_minimum_size = Vector2(620, 86)
	ov_box.add_child(_btn_primary)

	_btn_secondary = _make_action_button("[AD] START AT LV.2 + MAGNET", Color("#F59E0B"))
	_btn_secondary.custom_minimum_size = Vector2(620, 76)
	ov_box.add_child(_btn_secondary)


func _make_small_tab(txt: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 19)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(7)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b


func _make_pill_label(txt: String, bg: Color, font_sz: int) -> Label:
	var lbl := Label.new()
	lbl.text = "  %s  " % txt
	lbl.add_theme_font_size_override("font_size", font_sz)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(9)
	lbl.add_theme_stylebox_override("normal", sb)
	lbl.modulate = Color.WHITE
	return lbl


func _make_action_button(txt: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 26)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(12)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b


func _apply_world_theme(world_id: int) -> void:
	_world_id = world_id
	var tex_path := ""
	match world_id:
		2:
			_env.background_color = Color("#4C1D95")
			_table_mat.set_shader_parameter("border_color", Color("#F59E0B"))
			tex_path = "res://assets/textures/w2_01_playmat_tile.png"
		3:
			_env.background_color = Color("#7C2D12")
			_table_mat.set_shader_parameter("border_color", Color("#FB7185"))
			tex_path = "res://assets/textures/w3_01_table_tile.png"
		4:
			_env.background_color = Color("#2E1065")
			_table_mat.set_shader_parameter("border_color", Color("#C084FC"))
			tex_path = "res://assets/textures/w4_01_desk_tile.png"
		_:
			_env.background_color = Color("#A7F3D0")
			_table_mat.set_shader_parameter("border_color", Color("#6EE7B7"))
			tex_path = "res://assets/textures/w1_01_marble_tile.png"

	if ResourceLoader.exists(tex_path):
		_table_mat.set_shader_parameter("albedo_tex", load(tex_path))
		_table_mat.set_shader_parameter("use_albedo_tex", true)
	else:
		_table_mat.set_shader_parameter("use_albedo_tex", false)


func _clear_entities() -> void:
	for c in _entities_root.get_children():
		c.queue_free()
	for c in _popups_root.get_children():
		c.queue_free()
	_items.clear()
	_powerups.clear()
	_traps.clear()
	_walls.clear()
	_bombs.clear()


func _load_level(num: int, show_start_modal: bool) -> void:
	_clear_entities()
	_level_number = clampi(num, 1, 50)
	_used_rv_this_run = false
	_attempts_this_level += 1
	_ice_freeze_timer = 0.0
	_bomb_flash_timer = 0.0
	_frost_mat.set_shader_parameter("frost_amount", 0.0)
	_bomb_flash_rect.color.a = 0.0
	_buff_label.text = ""

	var path := "res://data/levels/level_%03d.json" % _level_number
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Failed to load level: " + path)
		return
	_level_data = parsed

	var world_id := int(_level_data.get("world", 1))
	_apply_world_theme(world_id)
	var tag := str(_level_data.get("difficulty_tag", "NORMAL"))
	_is_mega_stage = (tag == "MEGA_BOSS")

	# Dynamic arena dimensions (including 30x34 MEGA BOSS STAGES!)
	var arena_arr: Array = _level_data.get("arena", [18.0, 22.0])
	var aw := float(arena_arr[0])
	var ah := float(arena_arr[1])
	_board_half = Vector2(aw * 0.5, ah * 0.5)
	var plane := PlaneMesh.new()
	plane.size = Vector2(aw, ah)
	_table_mesh.mesh = plane
	_table_mat.set_shader_parameter("board_half_size", _board_half)
	_hole.board_bounds = _board_half

	var base_dur := float(_level_data.get("duration", 45.0))
	_time_left = base_dur + DDAController.get_timer_adjustment(_level_number, tag)
	_last_tick_sec = 6

	var sp_arr: Array = _level_data.get("spawn", [0.0, 0.0])
	_hole.reset_for_level(1, Vector3(float(sp_arr[0]), 0.0, float(sp_arr[1])))
	_target_cam_height = 18.5 if _is_mega_stage else 16.8

	var targets: Dictionary = _level_data.get("targets", {})

	for entry in _level_data.get("items", []):
		var key := str(entry["key"])
		var def := GameManager.get_item_def(key)
		if def.is_empty():
			continue
		var p: Array = entry["pos"]
		var item := SwallowableItem.new()
		item.setup(key, def, Vector3(float(p[0]), 0.0, float(p[1])), int(entry.get("color_idx", 0)), targets.has(key))
		item.swallowed.connect(_on_item_swallowed)
		_entities_root.add_child(item)
		_items.append(item)

	for pu in _level_data.get("powerups", []):
		var p: Array = pu["pos"]
		var node := PowerupItem.new()
		node.setup(str(pu["kind"]), Vector3(float(p[0]), 0.0, float(p[1])))
		node.collected.connect(_on_powerup_collected)
		_entities_root.add_child(node)
		_powerups.append(node)

	for tr in _level_data.get("traps", []):
		var p: Array = tr["pos"]
		var trap := StickyTrap.new()
		trap.setup(Vector3(float(p[0]), 0.0, float(p[1])), world_id)
		_entities_root.add_child(trap)
		_traps.append(trap)

	for wl in _level_data.get("walls", []):
		var p: Array = wl["pos"]
		var wall := RubberWall.new()
		wall.setup(Vector3(float(p[0]), 0.0, float(p[1])), float(wl.get("rot_deg", 0.0)))
		_entities_root.add_child(wall)
		_walls.append(wall)

	for bm in _level_data.get("bombs", []):
		var p: Array = bm["pos"]
		var bomb := BombHazard.new()
		bomb.setup(Vector3(float(p[0]), 0.0, float(p[1])))
		bomb.detonated.connect(_on_bomb_detonated)
		_entities_root.add_child(bomb)
		_bombs.append(bomb)

	# Rebuild Targets HUD
	_remaining_targets.clear()
	_target_labels.clear()
	for child in _targets_box.get_children():
		child.queue_free()

	for t_key in targets:
		var count := int(targets[t_key])
		_remaining_targets[t_key] = count
		var def := GameManager.get_item_def(t_key)
		var label_name := str(def.get("name", t_key))
		var t_lv := int(def.get("tier", 1))
		var lbl := _make_pill_label("%s x%d (Lv.%d)" % [label_name, count, t_lv], Color("#7C3AED"), 21)
		_targets_box.add_child(lbl)
		_target_labels[t_key] = lbl

	# Highlight active World & Stage pills
	for wid in _world_buttons:
		var wb: Button = _world_buttons[wid]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#0EA5E9") if wid == world_id else Color("#1E293B")
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(7)
		wb.add_theme_stylebox_override("normal", sb)

	var wmeta: Dictionary = WORLD_META[world_id]
	for k in _stage_buttons:
		var btn: Button = _stage_buttons[k]
		var lv_target := int(wmeta[k])
		var active := lv_target == _level_number
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#E11D48") if (active and (k == "cliff" or k == "mega")) else (Color("#14B8A6") if active else (Color("#881337") if k == "mega" else Color("#334155")))
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(7)
		btn.add_theme_stylebox_override("normal", sb)

	var fname := str(_level_data.get("formation_name", "Stage"))
	_level_label.text = "  W%d L%d: %s  " % [world_id, _level_number, fname]
	var shown_streak := maxi(GameManager.win_streak, int(_level_data.get("streak_hint", 0)))
	_streak_label.text = "  STREAK %d  " % shown_streak
	_update_timer_ui()

	if show_start_modal:
		_show_start_overlay(tag, fname, world_id)
	else:
		_begin_play()


func _show_start_overlay(tag: String, fname: String, world_id: int) -> void:
	_playing = false
	_hole.is_controllable = false
	_overlay_panel.visible = true
	var w_name := str(WORLD_META[world_id]["name"])
	var trap_nm := str(WORLD_META[world_id]["trap_name"])
	_overlay_badge.text = "  %s · %s  " % [w_name, tag]
	_overlay_title.text = "LV.%d · %s" % [_level_number, fname]

	var extras := ""
	if _walls.size() > 0:
		extras += " | %d Rubber Walls" % _walls.size()
	if _bombs.size() > 0:
		extras += " | %d Time Bombs (-3s)" % _bombs.size()

	if tag == "MEGA_BOSS":
		_overlay_desc.text = "EPIC MEGA BOSS ARENA (%.0fx%.0f)!\n%.0fs clock | %d %s Traps%s\nTight XP budget — master the grand formation to clear all Bosses!" % [
			_board_half.x * 2.0, _board_half.y * 2.0, _time_left, _traps.size(), trap_nm, extras
		]
	elif tag == "SUPER_HARD":
		_overlay_desc.text = "SUPER HARD CLIFF STAGE!\nTight %.0fs timer | %d %s Traps%s\nRoute every XP cluster cleanly to unlock Lv.5 in time!" % [
			_time_left, _traps.size(), trap_nm, extras
		]
	elif tag == "HARD":
		_overlay_desc.text = "HARD PINCH STAGE!\nTight %.0fs clock | %d %s Traps%s." % [_time_left, _traps.size(), trap_nm, extras]
	else:
		_overlay_desc.text = "Hold & drag (floating joystick) or WASD.\nGobble small items to level up, then swallow all goal targets!%s" % (
			"\nWatch out for -3s Time Bombs!" if _bombs.size() > 0 else ""
		)

	_rebind_button(_btn_primary, "PLAY STAGE!", Color("#14B8A6"), func():
		AudioManager.start_bgm()
		_begin_play()
	)
	_btn_secondary.visible = true
	_rebind_button(_btn_secondary, "[AD] START AT LV.2 + MAGNET 7s", Color("#22C55E"), func():
		AudioManager.start_bgm()
		AdManager.show_rewarded("pre_level_boost")
	)


func _begin_play() -> void:
	_overlay_panel.visible = false
	_playing = true
	_hole.is_controllable = true
	PlatformBridge.notify_gameplay_start()


func _process(delta: float) -> void:
	_table_mat.set_shader_parameter("hole_world_pos", _hole.position)
	_table_mat.set_shader_parameter("hole_radius", _hole.current_radius)

	if _bomb_flash_timer > 0.0:
		_bomb_flash_timer = maxf(_bomb_flash_timer - delta * 2.4, 0.0)
		_bomb_flash_rect.color.a = _bomb_flash_timer * 0.45

	var cam_lim_x := maxf(1.5, _board_half.x - 4.4)
	var cam_lim_z := maxf(1.5, _board_half.y - 5.0)
	var look_x := clampf(_hole.position.x * 0.80, -cam_lim_x, cam_lim_x)
	var look_z := clampf(_hole.position.z * 0.80, -cam_lim_z, cam_lim_z)
	var desired_cam := Vector3(look_x, _target_cam_height, look_z + 9.4)

	if _camera_shake > 0.0:
		_camera_shake = maxf(_camera_shake - delta * 20.0, 0.0)
		desired_cam.x += randf_range(-0.12, 0.12) * _camera_shake
		desired_cam.z += randf_range(-0.12, 0.12) * _camera_shake

	_camera.position = _camera.position.lerp(desired_cam, minf(delta * 6.5, 1.0))
	_camera.look_at(Vector3(look_x, 0.0, look_z), Vector3.UP)

	if not _playing:
		return

	for wall in _walls:
		if is_instance_valid(wall):
			if wall.step_interaction(_hole, delta):
				_camera_shake = maxf(_camera_shake, 3.0)
				_spawn_popup(_hole.position + Vector3(0, 1.0, 0), "BOING!", Color("#A855F7"))

	for i in range(_items.size() - 1, -1, -1):
		if is_instance_valid(_items[i]):
			_items[i].step_interaction(_hole, delta, _board_half)
		else:
			_items.remove_at(i)

	for i in range(_powerups.size() - 1, -1, -1):
		if is_instance_valid(_powerups[i]):
			_powerups[i].step_interaction(_hole, delta)
		else:
			_powerups.remove_at(i)

	for i in range(_traps.size() - 1, -1, -1):
		if is_instance_valid(_traps[i]):
			_traps[i].step_interaction(_hole, _level_number, delta)
		else:
			_traps.remove_at(i)

	for i in range(_bombs.size() - 1, -1, -1):
		if is_instance_valid(_bombs[i]):
			_bombs[i].step_interaction(_hole, delta)
		else:
			_bombs.remove_at(i)

	if _ice_freeze_timer > 0.0:
		_ice_freeze_timer = maxf(_ice_freeze_timer - delta, 0.0)
		_frost_mat.set_shader_parameter("frost_amount", clampf(_ice_freeze_timer, 0.0, 1.0))
		if _ice_freeze_timer <= 0.0:
			_update_buff_banner()
	else:
		_time_left = maxf(_time_left - delta, 0.0)
		_update_timer_ui()
		var sec_ceil := int(ceil(_time_left))
		if sec_ceil <= 5 and sec_ceil > 0 and sec_ceil < _last_tick_sec:
			_last_tick_sec = sec_ceil
			AudioManager.play_sfx("tick")
		if _time_left <= 0.0:
			_on_level_timeout()


func _update_timer_ui() -> void:
	_timer_label.text = "  %.1fs  " % _time_left
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(9)
	if _ice_freeze_timer > 0.0:
		sb.bg_color = Color("#0284C7")
	elif _time_left <= 8.0:
		sb.bg_color = Color("#E11D48")
	else:
		sb.bg_color = Color("#14B8A6")
	_timer_label.add_theme_stylebox_override("normal", sb)


func _spawn_popup(world_pos: Vector3, text: String, col: Color) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 64
	lbl.outline_size = 18
	lbl.modulate = col
	lbl.outline_modulate = Color.WHITE
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = world_pos + Vector3(0.0, 1.25, 0.0)
	_popups_root.add_child(lbl)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 1.8, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(lbl.queue_free)


func _on_sticky_triggered(trap_pos: Vector3, trap_col: Color, trap_lbl: String) -> void:
	_camera_shake = 4.5
	_spawn_pop_particles(trap_pos + Vector3(0, 0.25, 0), trap_col, 12)
	_spawn_popup(_hole.position, "%s PULL FREE!" % trap_lbl, trap_col)


func _on_bomb_detonated(world_pos: Vector3, penalty: float) -> void:
	_time_left = maxf(0.1, _time_left - penalty)
	_bomb_flash_timer = 1.0
	_camera_shake = 8.5
	AudioManager.play_sfx("fail", 1.35)
	PlatformBridge.trigger_haptic(55)
	_spawn_pop_particles(world_pos + Vector3(0, 0.3, 0), Color("#FF3B30"), 18)
	_spawn_popup(world_pos, "BOOM! -%.0fs!" % penalty, Color("#FF3B30"))
	_update_timer_ui()


func _on_item_swallowed(item_key: String, tier: int, xp: float, pos: Vector3, tint: Color) -> void:
	AudioManager.play_swallow(tier)
	_hole.add_xp(xp)
	_spawn_pop_particles(pos, tint, clampi(7 + tier * 3, 7, 24))
	if tier >= 3:
		_camera_shake = maxf(_camera_shake, float(tier) * 1.6)
		PlatformBridge.trigger_haptic(35)

	if _remaining_targets.has(item_key) and _remaining_targets[item_key] > 0:
		_remaining_targets[item_key] -= 1
		var left: int = _remaining_targets[item_key]
		var lbl: Label = _target_labels[item_key]
		var def := GameManager.get_item_def(item_key)
		var label_name := str(def.get("name", item_key))
		var t_lv := int(def.get("tier", 1))
		if left <= 0:
			lbl.text = "  [OK] %s  " % label_name
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("#16A34A")
			sb.set_corner_radius_all(20)
			sb.set_content_margin_all(9)
			lbl.add_theme_stylebox_override("normal", sb)
			AudioManager.play_sfx("goal_done")
		else:
			lbl.text = "  %s x%d (Lv.%d)  " % [label_name, left, t_lv]
		_check_victory()


func _spawn_pop_particles(pos: Vector3, tint: Color, count: int) -> void:
	var vfx_tex: Texture2D = load("res://assets/textures/vfx_m1_atlas.png") if ResourceLoader.exists("res://assets/textures/vfx_m1_atlas.png") else null
	for i in range(mini(count, 24)):
		var p := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.34, 0.34)
		p.mesh = q
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if vfx_tex:
			mat.albedo_texture = vfx_tex
			mat.uv1_scale = Vector3(0.5, 0.5, 1.0)
			mat.uv1_offset = Vector3(0.5 * (i % 2), 0.5 * ((i / 2) % 2), 0.0)
		p.material_override = mat
		p.position = pos
		_particles_root.add_child(p)

		var ang := randf() * TAU
		var target := pos + Vector3(cos(ang) * randf_range(0.7, 1.7), randf_range(0.8, 1.8), sin(ang) * randf_range(0.7, 1.7))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", target, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector3.ZERO, 0.38)
		tw.chain().tween_callback(p.queue_free)


func _on_powerup_collected(kind: String, _pos: Vector3) -> void:
	if kind == "ice":
		_ice_freeze_timer = maxf(_ice_freeze_timer, 5.0)
		_frost_mat.set_shader_parameter("frost_amount", 1.0)
		AudioManager.play_sfx("ice")
		_spawn_popup(_hole.position, "ICE FREEZE 5s!", Color("#0284C7"))
		_update_buff_banner()
	elif kind == "magnet":
		_hole.activate_magnet(5.5)
		_spawn_popup(_hole.position, "SUPER MAGNET 5.5s!", Color("#9333EA"))
		_update_buff_banner()


func _on_hole_level_changed(new_level: int, _radius: float) -> void:
	_hole_lvl_label.text = "  HOLE LV.%d  " % new_level
	var base_h := 18.5 if _is_mega_stage else 16.8
	_target_cam_height = base_h + float(new_level - 1) * (2.5 if _is_mega_stage else 2.2)
	if _playing:
		_camera_shake = maxf(_camera_shake, 6.0)
		_spawn_pop_particles(_hole.position + Vector3(0, 0.2, 0), Color("#2DD4BF"), 20)
		_spawn_popup(_hole.position, "POP! LEVEL UP LV.%d!" % new_level, Color("#0284C7"))


func _on_fever_changed(ratio: float, active: bool) -> void:
	_fever_bar.value = ratio * 100.0
	if active and _playing and ratio > 0.96:
		_spawn_popup(_hole.position, "FEVER MODE! +24% SPEED!", Color("#EC4899"))
	_update_buff_banner()


func _on_buff_changed(_buff_name: String, _remaining: float) -> void:
	_update_buff_banner()


func _update_buff_banner() -> void:
	var parts: Array[String] = []
	if _hole.sticky_timer > 0.0:
		var tname := str(WORLD_META[_world_id]["trap_name"])
		parts.append("STICKY %s %.1fs (-55%% SPD)" % [tname, _hole.sticky_timer])
	if _ice_freeze_timer > 0.0:
		parts.append("FROZEN %.1fs" % _ice_freeze_timer)
	if _hole.magnet_timer > 0.0:
		parts.append("MAGNET %.1fs" % _hole.magnet_timer)
	if _hole.is_fever_active():
		parts.append("FEVER %.1fs" % _hole.fever_timer)
	_buff_label.text = "  |  ".join(parts)


func _check_victory() -> void:
	for k in _remaining_targets:
		if _remaining_targets[k] > 0:
			return
	_playing = false
	_hole.is_controllable = false
	PlatformBridge.notify_gameplay_stop()
	AudioManager.play_sfx("win")

	DDAController.record_level_win(_level_number, _used_rv_this_run, _attempts_this_level == 1)
	_attempts_this_level = 0
	GameManager.win_streak += 1
	var next_lv := (_level_number % 50) + 1
	GameManager.current_level = next_lv
	if _level_number in [20, 30, 40]:
		GameManager.unlocked_worlds = maxi(GameManager.unlocked_worlds, _world_id + 1)
	GameManager.save_progress()

	_overlay_panel.visible = true
	_overlay_badge.text = "  MEGA BOSS CLEARED!  " if _is_mega_stage else "  STAGE CLEARED!  "
	if _level_number == 50:
		_overlay_title.text = "ALL 4 WORLDS MASTERED!"
		_overlay_desc.text = "Grand Alchemist Finale Conquered!\nTime Left: %.1fs | Final Hole: Lv.%d | Streak: %d" % [_time_left, _hole.hole_level, GameManager.win_streak]
	elif _level_number in [20, 30, 40]:
		_overlay_title.text = "WORLD %d UNLOCKED!" % (_world_id + 1)
		_overlay_desc.text = "MEGA STAGE CLEARED! Time Left: %.1fs\nNext up: %s!" % [_time_left, str(WORLD_META[_world_id + 1]["name"])]
	else:
		_overlay_title.text = "POP! LV.%d CLEAR!" % _level_number
		_overlay_desc.text = "Time Left: %.1fs | Hole Lv.%d | Streak: %d" % [_time_left, _hole.hole_level, GameManager.win_streak]

	_rebind_button(_btn_primary, "NEXT STAGE (LV.%d) >" % next_lv, Color("#14B8A6"), func():
		AdManager.show_interstitial("level_complete", _level_number)
		_load_level(next_lv, true)
	)
	_btn_secondary.visible = true
	_rebind_button(_btn_secondary, "Replay This Stage", Color("#64748B"), func():
		_load_level(_level_number, false)
	)


func _on_level_timeout() -> void:
	_playing = false
	_hole.is_controllable = false
	PlatformBridge.notify_gameplay_stop()
	AudioManager.play_sfx("fail")

	var rem_total := 0
	for k in _remaining_targets:
		rem_total += maxi(0, int(_remaining_targets[k]))
	var tag := str(_level_data.get("difficulty_tag", ""))
	var is_high := tag in ["SUPER_HARD", "MEGA_BOSS"]
	var trap_nm := str(WORLD_META[_world_id]["trap_name"])

	_overlay_panel.visible = true
	_overlay_badge.text = "  HIGH-STAKES CLIFF!  " if is_high else "  OUT OF TIME!  "
	_overlay_title.text = "ONLY %d TARGETS LEFT!" % rem_total
	if is_high:
		_overlay_desc.text = "So close (Hole Lv.%d)!\nWatch 1 free RV to EXPLODE ALL %d %s TRAPS%s + +15s + +20%% BIGGER HOLE!" % [
			_hole.hole_level, _traps.size(), trap_nm, (" & BOMBS" if _bombs.size() > 0 else "")
		]
	else:
		_overlay_desc.text = "Almost there! Watch 1 free RV for +15s Time + Clear Traps + +20%% Bigger Hole!"

	_rebind_button(_btn_primary, "[AD] +15s + CLEAR ALL TRAPS + GROW 20%!", Color("#22C55E"), func():
		AdManager.show_rewarded("fail_rescue")
	)
	_btn_secondary.visible = true
	_rebind_button(_btn_secondary, "Give Up & Retry Stage", Color("#94A3B8"), func():
		DDAController.record_level_fail(_level_number, _used_rv_this_run)
		GameManager.win_streak = 0
		GameManager.save_progress()
		_load_level(_level_number, false)
	)


func _on_rewarded_completed(placement: String, success: bool) -> void:
	if not success:
		return
	_used_rv_this_run = true
	match placement:
		"fail_rescue":
			_time_left += 15.0
			_last_tick_sec = 6
			for tr in _traps:
				if is_instance_valid(tr):
					_spawn_pop_particles(tr.position + Vector3(0, 0.3, 0), tr.trap_color, 10)
					tr.pop_and_clear()
			_traps.clear()
			for bm in _bombs:
				if is_instance_valid(bm):
					_spawn_pop_particles(bm.position + Vector3(0, 0.3, 0), Color("#FACC15"), 10)
					bm.pop_and_clear()
			_bombs.clear()
			_hole.apply_rv_rescue_boost()
			AudioManager.play_sfx("rv_blast")
			_camera_shake = 7.0
			_spawn_popup(_hole.position, "ALL HAZARDS CLEARED! +15s!", Color("#16A34A"))
			_begin_play()
		"pre_level_boost":
			var sp_arr: Array = _level_data.get("spawn", [0.0, 0.0])
			_hole.reset_for_level(2, Vector3(float(sp_arr[0]), 0.0, float(sp_arr[1])))
			_hole.activate_magnet(7.0)
			AudioManager.play_sfx("level_up")
			_spawn_popup(_hole.position, "LV.2 HOLE + MAGNET 7s!", Color("#16A34A"))
			_begin_play()
		"in_level_ice":
			_ice_freeze_timer = maxf(_ice_freeze_timer, 6.0)
			_frost_mat.set_shader_parameter("frost_amount", 1.0)
			AudioManager.play_sfx("ice")
			_spawn_popup(_hole.position, "ICE FREEZE +6s!", Color("#0284C7"))
			_update_buff_banner()
		"in_level_magnet":
			_hole.activate_magnet(7.0)
			_spawn_popup(_hole.position, "SUPER MAGNET 7s!", Color("#9333EA"))
			_update_buff_banner()


func _on_mute_pressed() -> void:
	var muted := AudioManager.toggle_user_mute()
	_btn_mute.text = "MUTED" if muted else "SFX ON"


func _rebind_button(btn: Button, txt: String, bg: Color, cb: Callable) -> void:
	btn.text = txt
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn["callable"])
	btn.pressed.connect(cb)
