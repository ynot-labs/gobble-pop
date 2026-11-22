extends Node3D

## Main playable stage for Gobble Pop! (World 1 H5-first vertical slice + full core loop)

var _camera: Camera3D
var _table_mat: ShaderMaterial
var _hole: HoleController
var _entities_root: Node3D
var _particles_root: Node3D

var _items: Array[SwallowableItem] = []
var _powerups: Array[PowerupItem] = []
var _traps: Array[StickyTrap] = []

var _level_data: Dictionary = {}
var _level_number: int = 1
var _remaining_targets: Dictionary = {}
var _target_labels: Dictionary = {}

var _time_left: float = 45.0
var _ice_freeze_timer: float = 0.0
var _last_tick_sec: int = 6
var _playing: bool = false
var _used_rv_this_run: bool = false
var _attempts_this_level: int = 0
var _camera_shake: float = 0.0
var _target_cam_height: float = 16.5

# UI references
var _hud_layer: CanvasLayer
var _timer_label: Label
var _level_label: Label
var _streak_label: Label
var _hole_lvl_label: Label
var _fever_bar: ProgressBar
var _targets_box: HBoxContainer
var _frost_rect: ColorRect
var _frost_mat: ShaderMaterial
var _overlay_panel: PanelContainer
var _overlay_title: Label
var _overlay_desc: Label
var _btn_primary: Button
var _btn_secondary: Button
var _btn_mute: Button
var _buff_label: Label


func _ready() -> void:
	_build_hud()
	_build_3d_stage()
	AdManager.rewarded_ad_completed.connect(_on_rewarded_completed)
	_load_level(GameManager.current_level, true)
	PlatformBridge.notify_game_ready()


func _build_3d_stage() -> void:
	# Bright candy studio environment
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#E8F8F2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.98, 0.96)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 32, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	# 60-degree top-down mobile camera
	_camera = Camera3D.new()
	_camera.fov = 46.0
	add_child(_camera)
	_camera.look_at_from_position(Vector3(0.0, 16.5, 9.5), Vector3(0.0, 0.0, 0.0), Vector3.UP)

	# Checkered marble tabletop with dynamic hole cutout shader + baked W1-01 marble tile texture
	var table := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(15.0, 22.0)
	table.mesh = plane
	_table_mat = ShaderMaterial.new()
	_table_mat.shader = load("res://shaders/tabletop_cutout.gdshader")
	if ResourceLoader.exists("res://assets/textures/w1_01_marble_tile.png"):
		_table_mat.set_shader_parameter("albedo_tex", load("res://assets/textures/w1_01_marble_tile.png"))
		_table_mat.set_shader_parameter("use_albedo_tex", true)
	table.material_override = _table_mat
	add_child(table)

	# Hole controller
	_hole = HoleController.new()
	_hole.level_changed.connect(_on_hole_level_changed)
	_hole.fever_changed.connect(_on_fever_changed)
	_hole.buff_changed.connect(_on_buff_changed)
	add_child(_hole)

	_entities_root = Node3D.new()
	add_child(_entities_root)

	_particles_root = Node3D.new()
	add_child(_particles_root)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)

	# Frost vignette overlay for Ice Cube freeze
	_frost_rect = ColorRect.new()
	_frost_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost_mat = ShaderMaterial.new()
	_frost_mat.shader = load("res://shaders/frost_overlay.gdshader")
	_frost_rect.material = _frost_mat
	_hud_layer.add_child(_frost_rect)

	# Top bar
	var top_margin := MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_left", 24)
	top_margin.add_theme_constant_override("margin_right", 24)
	top_margin.add_theme_constant_override("margin_top", 28)
	_hud_layer.add_child(top_margin)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 12)
	top_margin.add_child(top_vbox)

	# Row 1: Level | Timer | Streak + Mute
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	top_vbox.add_child(row1)

	_level_label = _make_pill_label("LV.1", Color("#3B82F6"), 34)
	row1.add_child(_level_label)

	var sp1 := Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sp1)

	_timer_label = _make_pill_label("00:45", Color("#FF4D8D"), 44)
	row1.add_child(_timer_label)

	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(sp2)

	_streak_label = _make_pill_label("STREAK 0", Color("#F59E0B"), 30)
	row1.add_child(_streak_label)

	_btn_mute = Button.new()
	_btn_mute.text = "SFX ON"
	_btn_mute.add_theme_font_size_override("font_size", 24)
	_btn_mute.pressed.connect(_on_mute_pressed)
	row1.add_child(_btn_mute)

	# Row 2: Target Checklist
	_targets_box = HBoxContainer.new()
	_targets_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_targets_box.add_theme_constant_override("separation", 16)
	top_vbox.add_child(_targets_box)

	# Row 3: Hole Level + Fever progress bar
	var row3 := HBoxContainer.new()
	row3.alignment = BoxContainer.ALIGNMENT_CENTER
	row3.add_theme_constant_override("separation", 14)
	top_vbox.add_child(row3)

	_hole_lvl_label = _make_pill_label("HOLE LV.1", Color("#10B981"), 26)
	row3.add_child(_hole_lvl_label)

	_fever_bar = ProgressBar.new()
	_fever_bar.custom_minimum_size = Vector2(360, 28)
	_fever_bar.max_value = 100.0
	_fever_bar.value = 0.0
	_fever_bar.show_percentage = false
	row3.add_child(_fever_bar)

	_buff_label = Label.new()
	_buff_label.add_theme_font_size_override("font_size", 28)
	_buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buff_label.modulate = Color("#1E293B")
	top_vbox.add_child(_buff_label)

	# Bottom quick-test level switcher & emergency RV booster bar
	var bot_bar := HBoxContainer.new()
	bot_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_bar.offset_top = -120
	bot_bar.offset_bottom = -28
	bot_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_bar.add_theme_constant_override("separation", 18)
	_hud_layer.add_child(bot_bar)

	var btn_rv_ice := _make_action_button("[AD] FREEZE 5s", Color("#0EA5E9"))
	btn_rv_ice.pressed.connect(func(): AdManager.show_rewarded("in_level_ice"))
	bot_bar.add_child(btn_rv_ice)

	var btn_rv_mag := _make_action_button("[AD] MAGNET", Color("#EC4899"))
	btn_rv_mag.pressed.connect(func(): AdManager.show_rewarded("in_level_magnet"))
	bot_bar.add_child(btn_rv_mag)

	var btn_next_test := _make_action_button("NEXT LV >", Color("#64748B"))
	btn_next_test.pressed.connect(func(): _load_level((_level_number % 20) + 1, false))
	bot_bar.add_child(btn_next_test)

	# Modal Overlay (Start / Win / Fail RV Rescue)
	_overlay_panel = PanelContainer.new()
	_overlay_panel.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_panel.custom_minimum_size = Vector2(760, 560)
	_overlay_panel.offset_left = -380
	_overlay_panel.offset_right = 380
	_overlay_panel.offset_top = -280
	_overlay_panel.offset_bottom = 280
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.99, 0.97, 0.96)
	style.border_color = Color("#FF6FA5")
	style.set_border_width_all(6)
	style.set_corner_radius_all(36)
	style.set_content_margin_all(36)
	_overlay_panel.add_theme_stylebox_override("panel", style)
	_hud_layer.add_child(_overlay_panel)

	var ov_box := VBoxContainer.new()
	ov_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ov_box.add_theme_constant_override("separation", 24)
	_overlay_panel.add_child(ov_box)

	_overlay_title = Label.new()
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title.add_theme_font_size_override("font_size", 56)
	_overlay_title.modulate = Color("#FF3B7A")
	ov_box.add_child(_overlay_title)

	_overlay_desc = Label.new()
	_overlay_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_desc.add_theme_font_size_override("font_size", 32)
	_overlay_desc.modulate = Color("#334155")
	ov_box.add_child(_overlay_desc)

	_btn_primary = _make_action_button("开始吞噬!", Color("#10B981"))
	_btn_primary.custom_minimum_size = Vector2(540, 96)
	ov_box.add_child(_btn_primary)

	_btn_secondary = _make_action_button("重玩本关", Color("#94A3B8"))
	_btn_secondary.custom_minimum_size = Vector2(420, 76)
	ov_box.add_child(_btn_secondary)


func _make_pill_label(txt: String, bg: Color, font_sz: int) -> Label:
	var lbl := Label.new()
	lbl.text = "  %s  " % txt
	lbl.add_theme_font_size_override("font_size", font_sz)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(10)
	lbl.add_theme_stylebox_override("normal", sb)
	lbl.modulate = Color.WHITE
	return lbl


func _make_action_button(txt: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 32)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(24)
	sb.set_content_margin_all(14)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	return b


func _clear_entities() -> void:
	for c in _entities_root.get_children():
		c.queue_free()
	_items.clear()
	_powerups.clear()
	_traps.clear()


func _load_level(num: int, show_start_modal: bool) -> void:
	_clear_entities()
	_level_number = clampi(num, 1, 20)
	_used_rv_this_run = false
	_attempts_this_level += 1
	_ice_freeze_timer = 0.0
	_frost_mat.set_shader_parameter("frost_amount", 0.0)

	var path := "res://data/levels/level_%03d.json" % _level_number
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Failed to load level: " + path)
		return
	_level_data = parsed

	var base_dur := float(_level_data.get("duration", 45.0))
	var tag := str(_level_data.get("difficulty_tag", "NORMAL"))
	_time_left = base_dur + DDAController.get_timer_adjustment(_level_number, tag)
	_last_tick_sec = 6

	_hole.reset_for_level(1)
	_target_cam_height = 16.5

	# Spawn items
	for entry in _level_data.get("items", []):
		var key := str(entry["key"])
		var def := GameManager.get_item_def(key)
		if def.is_empty():
			continue
		var p: Array = entry["pos"]
		var item := SwallowableItem.new()
		item.setup(key, def, Vector3(float(p[0]), 0.0, float(p[1])), int(entry.get("color_idx", 0)))
		item.swallowed.connect(_on_item_swallowed)
		_entities_root.add_child(item)
		_items.append(item)

	# Spawn powerups
	for pu in _level_data.get("powerups", []):
		var p: Array = pu["pos"]
		var node := PowerupItem.new()
		node.setup(str(pu["kind"]), Vector3(float(p[0]), 0.0, float(p[1])))
		node.collected.connect(_on_powerup_collected)
		_entities_root.add_child(node)
		_powerups.append(node)

	# Spawn sticky traps
	var world_id := int(_level_data.get("world", 1))
	for tr in _level_data.get("traps", []):
		var p: Array = tr["pos"]
		var trap := StickyTrap.new()
		trap.setup(Vector3(float(p[0]), 0.0, float(p[1])), world_id)
		_entities_root.add_child(trap)
		_traps.append(trap)

	# Build targets UI
	_remaining_targets.clear()
	_target_labels.clear()
	for child in _targets_box.get_children():
		child.queue_free()

	var targets: Dictionary = _level_data.get("targets", {})
	for t_key in targets:
		var count := int(targets[t_key])
		_remaining_targets[t_key] = count
		var def := GameManager.get_item_def(t_key)
		var label_name := str(def.get("name", t_key))
		var lbl := _make_pill_label("%s x%d" % [label_name, count], Color("#8B5CF6"), 24)
		_targets_box.add_child(lbl)
		_target_labels[t_key] = lbl

	var tag_suffix := " - SUPER HARD!" if tag == "SUPER_HARD" else (" - HARD" if tag == "HARD" else "")
	_level_label.text = "  LV.%d%s  " % [_level_number, tag_suffix]
	_streak_label.text = "  STREAK %d  " % GameManager.win_streak
	_update_timer_ui()

	if show_start_modal:
		_show_start_overlay(tag)
	else:
		_begin_play()


func _show_start_overlay(tag: String) -> void:
	_playing = false
	_hole.is_controllable = false
	_overlay_panel.visible = true
	_overlay_title.text = "GOBBLE POP! LV.%d" % _level_number
	if tag == "SUPER_HARD":
		_overlay_desc.text = "SUPER HARD CHALLENGE!\nTime: %.0fs | Dodge sticky bubblegum & grow to Lv.5!" % _time_left
	else:
		_overlay_desc.text = "Drag to move the vortex hole.\nGobble sweets to grow & clear all goals before time runs out!"

	_rebind_button(_btn_primary, "TAP TO PLAY!", Color("#10B981"), func():
		AudioManager.start_bgm()
		_begin_play()
	)
	_btn_secondary.visible = true
	_rebind_button(_btn_secondary, "[AD] START AT LV.2", Color("#F59E0B"), func():
		AudioManager.start_bgm()
		AdManager.show_rewarded("pre_level_lv2")
	)


func _begin_play() -> void:
	_overlay_panel.visible = false
	_playing = true
	_hole.is_controllable = true
	PlatformBridge.notify_gameplay_start()


func _process(delta: float) -> void:
	# Update tabletop cutout shader with live hole state
	_table_mat.set_shader_parameter("hole_world_pos", _hole.position)
	_table_mat.set_shader_parameter("hole_radius", _hole.current_radius)

	# Smooth camera follow & dynamic zoom + subtle shake
	var desired_cam := Vector3(
		clampf(_hole.position.x * 0.42, -3.0, 3.0),
		_target_cam_height,
		clampf(_hole.position.z * 0.42 + 9.2, 4.0, 14.5)
	)
	if _camera_shake > 0.0:
		_camera_shake = maxf(_camera_shake - delta * 3.5, 0.0)
		desired_cam.x += randf_range(-0.25, 0.25) * _camera_shake
		desired_cam.z += randf_range(-0.25, 0.25) * _camera_shake

	_camera.position = _camera.position.lerp(desired_cam, minf(delta * 5.0, 1.0))
	_camera.look_at(Vector3(_hole.position.x * 0.35, 0.0, _hole.position.z * 0.35), Vector3.UP)

	if not _playing:
		return

	# Step items / powerups / traps
	for i in range(_items.size() - 1, -1, -1):
		if is_instance_valid(_items[i]):
			_items[i].step_interaction(_hole, delta)
		else:
			_items.remove_at(i)

	for i in range(_powerups.size() - 1, -1, -1):
		if is_instance_valid(_powerups[i]):
			_powerups[i].step_interaction(_hole, delta)
		else:
			_powerups.remove_at(i)

	for i in range(_traps.size() - 1, -1, -1):
		if is_instance_valid(_traps[i]):
			_traps[i].step_interaction(_hole, _level_number)
		else:
			_traps.remove_at(i)

	# Timer & Ice freeze
	if _ice_freeze_timer > 0.0:
		_ice_freeze_timer = maxf(_ice_freeze_timer - delta, 0.0)
		_frost_mat.set_shader_parameter("frost_amount", clampf(_ice_freeze_timer, 0.0, 1.0))
		if _ice_freeze_timer <= 0.0:
			_buff_label.text = ""
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
	var s := int(ceil(_time_left))
	_timer_label.text = "  %02d:%02d  " % [s / 60, s % 60]
	if _ice_freeze_timer > 0.0:
		_timer_label.modulate = Color("#BAE6FD")
	elif s <= 5:
		_timer_label.modulate = Color("#FEF08A")
	else:
		_timer_label.modulate = Color.WHITE


func _on_item_swallowed(item_key: String, tier: int, xp: float, pos: Vector3, tint: Color) -> void:
	AudioManager.play_swallow(tier)
	_hole.add_xp(xp)
	_spawn_pop_particles(pos, tint, clampi(6 + tier * 3, 6, 22))
	if tier >= 4:
		_camera_shake = 0.65
		PlatformBridge.trigger_haptic(45)

	if _remaining_targets.has(item_key) and _remaining_targets[item_key] > 0:
		_remaining_targets[item_key] -= 1
		var left: int = _remaining_targets[item_key]
		var lbl: Label = _target_labels[item_key]
		var def := GameManager.get_item_def(item_key)
		var label_name := str(def.get("name", item_key))
		if left <= 0:
			lbl.text = "  [OK] %s  " % label_name
			AudioManager.play_sfx("goal_done")
		else:
			lbl.text = "  %s x%d  " % [label_name, left]
		_check_victory()


func _spawn_pop_particles(pos: Vector3, tint: Color, count: int) -> void:
	# Lightweight shared-atlas VFX-M1 particle burst capped <= 24 particles
	var vfx_tex: Texture2D = load("res://assets/textures/vfx_m1_atlas.png") if ResourceLoader.exists("res://assets/textures/vfx_m1_atlas.png") else null
	for i in range(mini(count, 24)):
		var p := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.32, 0.32)
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
		var target := pos + Vector3(cos(ang) * randf_range(0.6, 1.55), randf_range(0.75, 1.65), sin(ang) * randf_range(0.6, 1.55))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", target, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "scale", Vector3.ZERO, 0.36)
		tw.chain().tween_callback(p.queue_free)


func _on_powerup_collected(kind: String, _pos: Vector3) -> void:
	if kind == "ice":
		_ice_freeze_timer = 5.0
		_frost_mat.set_shader_parameter("frost_amount", 1.0)
		AudioManager.play_sfx("ice")
		_buff_label.text = "ICE FREEZE! 5.0s"
	elif kind == "magnet":
		_hole.activate_magnet()
		_buff_label.text = "MAGNET ACTIVE!"


func _on_hole_level_changed(new_level: int, _radius: float) -> void:
	_hole_lvl_label.text = "  HOLE LV.%d  " % new_level
	_target_cam_height = 16.5 + (new_level - 1) * 2.1


func _on_fever_changed(ratio: float, active: bool) -> void:
	_fever_bar.value = ratio * 100.0
	if active:
		_buff_label.text = "FEVER MODE! +24% SPEED  +25% SUCTION"
	elif _ice_freeze_timer <= 0.0 and _hole.magnet_timer <= 0.0 and _hole.sticky_timer <= 0.0:
		_buff_label.text = ""


func _on_buff_changed(buff_name: String, remaining: float) -> void:
	if buff_name == "sticky" and remaining > 0.0:
		_buff_label.text = "STICKY BUBBLEGUM! SLOW %.1fs" % remaining
	elif buff_name == "magnet" and remaining > 0.0:
		_buff_label.text = "MAGNET ACTIVE %.1fs" % remaining
	elif remaining <= 0.0 and not _hole.is_fever_active() and _ice_freeze_timer <= 0.0:
		_buff_label.text = ""


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
	GameManager.current_level = (_level_number % 20) + 1
	if _level_number == 20 and GameManager.unlocked_worlds < 2:
		GameManager.unlocked_worlds = 2
	GameManager.save_progress()

	_overlay_panel.visible = true
	if _level_number == 20:
		_overlay_title.text = "WORLD 1 CLEARED!"
		_overlay_desc.text = "Sugar Rush Bakery Mastered! World 2 Unlocked!\nWin Streak: %d" % GameManager.win_streak
	else:
		_overlay_title.text = "LEVEL %d CLEAR!" % _level_number
		_overlay_desc.text = "All targets gobbled!\nCurrent Win Streak: %d" % GameManager.win_streak

	_rebind_button(_btn_primary, "NEXT LEVEL (LV.%d)" % GameManager.current_level, Color("#10B981"), func():
		AdManager.show_interstitial("level_complete", _level_number)
		_load_level(GameManager.current_level, false)
	)
	_btn_secondary.visible = false


func _on_level_timeout() -> void:
	_playing = false
	_hole.is_controllable = false
	PlatformBridge.notify_gameplay_stop()
	AudioManager.play_sfx("fail")

	_overlay_panel.visible = true
	_overlay_title.text = "SO CLOSE!"
	_overlay_desc.text = "Watch an ad for an epic comeback:\n+15s Time + Clear All Gum + +20% Bigger Hole!"

	_rebind_button(_btn_primary, "[AD] +15s + CLEAR + GROW!", Color("#F59E0B"), func():
		AdManager.show_rewarded("fail_rescue")
	)
	_btn_secondary.visible = true
	_rebind_button(_btn_secondary, "Retry Level (Reset Streak)", Color("#94A3B8"), func():
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
					tr.pop_and_clear()
			_traps.clear()
			_hole.apply_rv_rescue_boost()
			AudioManager.play_sfx("rv_blast")
			_begin_play()
		"pre_level_lv2":
			_hole.reset_for_level(2)
			_begin_play()
		"in_level_ice":
			_on_powerup_collected("ice", Vector3.ZERO)
		"in_level_magnet":
			_on_powerup_collected("magnet", Vector3.ZERO)


func _on_mute_pressed() -> void:
	var muted := AudioManager.toggle_user_mute()
	_btn_mute.text = "MUTED" if muted else "SFX ON"


func _rebind_button(btn: Button, txt: String, bg: Color, cb: Callable) -> void:
	btn.text = txt
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(24)
	sb.set_content_margin_all(14)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn["callable"])
	btn.pressed.connect(cb)
