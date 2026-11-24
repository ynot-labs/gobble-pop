extends Node3D

## Main Stage for Gobble Pop! — All 4 Worlds (Lv.1 - Lv.50) + 4 Epic MEGA BOSS Stages!
## Phase 1 Commercial Loop: Home Lobby, World Map, Hole Skin Shop, Pause/Auto-Freeze,
## FTUE Drag Hand Guide, Contextual Mechanic Tips, Off-Screen Radar Arrows,
## 1-3 Star Victory Celebration, Coins/Shards Economy, Free Starter Booster Stock.
## Strict Beta (top QA bar) vs Release (sequential unlock only) via GameManager.is_beta_build().

const WORLD_META := {
	1: {"name": "SWEET BAKERY",      "short": "W1 Bakery",  "start": 1,  "hard": 5,  "cliff": 10, "mega": 20, "trap_name": "BUBBLEGUM"},
	2: {"name": "CUBE PETS TOYBOX",  "short": "W2 Pets",    "start": 21, "hard": 25, "cliff": 29, "mega": 30, "trap_name": "BUBBLEGUM"},
	3: {"name": "STREET FOOD BENTO", "short": "W3 Street",  "start": 31, "hard": 35, "cliff": 39, "mega": 40, "trap_name": "CHEESE"},
	4: {"name": "MINI TOY CITY",     "short": "W4 City",    "start": 41, "hard": 45, "cliff": 49, "mega": 50, "trap_name": "WET TAR"},
	5: {"name": "ARCADE HALL",       "short": "W5 Arcade",  "start": 51, "hard": 55, "cliff": 59, "mega": 60, "trap_name": "GLITCH GOO"},
}

const TARGET_PILL_THEMES := [
	{"bg": Color("#F24C9B"), "bevel": Color("#B01C65"), "outline": Color("#630B38")},
	{"bg": Color("#5B78F5"), "bevel": Color("#2E44B3"), "outline": Color("#17236B")},
	{"bg": Color("#A855F7"), "bevel": Color("#6B21A8"), "outline": Color("#3B0764")},
]

var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _island_builder: FloatingIslandBuilder
var _camera: Camera3D
var _table_mesh: MeshInstance3D
var _table_mat: ShaderMaterial
var _hole: HoleController
var _entities_root: Node3D
var _particles_root: Node3D
var _popups_root: Node3D
var _ab_mode: String = "" # "", "a", or "b" for Option A vs Option B visual showcase
var _fov_punch: float = 0.0

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
var _target_pills: Dictionary = {}

var _base_duration: float = 45.0
var _time_left: float = 45.0
var _ice_freeze_timer: float = 0.0
var _bomb_flash_timer: float = 0.0
var _last_tick_sec: int = 6
var _playing: bool = false
var _paused: bool = false
var _in_lobby: bool = true
var _used_rv_this_run: bool = false
var _attempts_this_level: int = 0
var _camera_shake: float = 0.0
var _target_cam_height: float = 17.5
var _cam_look_pos := Vector3.ZERO
var _cam_snap_next: bool = true
var _lobby_orbit_time: float = 0.0
var _is_mobile_perf: bool = false
var _last_fps_cap: int = 0

# Zero-allocation pooled particle system (prevents WebGL2 GC & material churn during waterfall combos!)
const PARTICLE_POOL_SIZE: int = 48
var _particle_pool: Array[Dictionary] = []
var _particle_quad: QuadMesh = null
var _particle_tex: Texture2D = null
var _particle_mat_cache: Dictionary = {}
var _particle_cursor: int = 0
var _last_particle_burst_ms: int = 0

# UI References
var _hud_layer: CanvasLayer
var _gameplay_hud_root: Control
var _gameplay_top_margin: MarginContainer
var _gameplay_bot_bar: HBoxContainer
var _beta_bar_container: MarginContainer
var _joystick_overlay: JoystickOverlay
var _helpers_ui: GameplayHelpersUI
var _combo_ui: ComboJuiceUI
var _ab_switcher_bar: HBoxContainer
var _pc_hint_label: Label
var _home_lobby_ui: HomeLobbyUI
var _pause_settings_ui: PauseSettingsUI
var _consent_ui: ConsentLegalUI
var _ad_overlay_ui: AdOverlayUI
var _beta_bi_ui: BetaBIInspectorUI

var _world_buttons: Dictionary = {}
var _stage_buttons: Dictionary = {}
var _bomb_flash_rect: ColorRect
var _timer_pill: PanelContainer
var _level_pill: PanelContainer
var _streak_pill: PanelContainer
var _hole_lvl_pill: PanelContainer
var _fever_bar: ProgressBar
var _targets_box: HBoxContainer
var _frost_rect: ColorRect
var _frost_mat: ShaderMaterial
var _btn_pause: Button
var _btn_rv_mag: Button
var _btn_rv_ice: Button
var _btn_retry_hud: Button
var _keycap_badges: Array[PanelContainer] = []
var _buff_label: Label

# Modal Card References (Pre-level / Victory / Fail)
var _overlay_dimmer: ColorRect
var _overlay_panel: PanelContainer
var _overlay_badge: PanelContainer
var _overlay_title: Label
var _modal_stars_box: HBoxContainer
var _modal_targets_box: HBoxContainer
var _modal_rewards_box: HBoxContainer
var _overlay_desc: Label
var _btn_primary: Button
var _btn_secondary: Button
var _btn_tertiary_home: Button


func _ready() -> void:
	var qa_vp := OS.get_environment("QA_VIEWPORT")
	if qa_vp != "" and qa_vp.contains("x"):
		var parts := qa_vp.split("x")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			get_window().size = Vector2i(int(parts[0]), int(parts[1]))

	_is_mobile_perf = _detect_mobile_device()
	SwallowableItem.mobile_low_power = _is_mobile_perf
	if _is_mobile_perf:
		# P0 Mobile Thermal Optimization: disable 2x MSAA on high-PPI mobile screens & cap 120Hz -> 60 FPS!
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		Engine.max_fps = 60
		_last_fps_cap = 60

	_build_hud()
	_build_3d_stage()
	_init_particle_pool()
	_joystick_overlay.hole = _hole
	AdManager.rewarded_ad_completed.connect(_on_rewarded_completed)
	PlatformBridge.visibility_changed.connect(_on_app_visibility_changed)
	PlatformBridge.safe_area_changed.connect(_apply_safe_area_margins)
	GameManager.economy_changed.connect(_refresh_booster_buttons)
	get_viewport().size_changed.connect(_update_responsive_layout)
	_apply_safe_area_margins(PlatformBridge.get_safe_margins())
	_update_responsive_layout()

	var start_lv := clampi(GameManager.current_level, 1, GameManager.MAX_LEVEL)
	var qa_env := OS.get_environment("QA_START_LEVEL")
	var qa_screen := OS.get_environment("QA_SCREEN")
	var web_style := _get_web_style_query()

	if qa_screen != "":
		var lv := clampi(int(qa_env), 1, GameManager.MAX_LEVEL) if qa_env.is_valid_int() else start_lv
		_run_qa_screen(qa_screen, lv)
	elif web_style in ["a", "b"]:
		_open_ab_showcase(web_style)
	elif qa_env.is_valid_int():
		start_lv = clampi(int(qa_env), 1, GameManager.MAX_LEVEL)
		var show_modal := (OS.get_environment("QA_SHOW_MODAL") == "1")
		_in_lobby = false
		_home_lobby_ui.close_all()
		_gameplay_hud_root.visible = true
		_load_level(start_lv, show_modal)
	else:
		if PlatformBridge.current_platform in [PlatformBridge.PlatformType.WEB_CRAZYGAMES, PlatformBridge.PlatformType.WEB_YOUTUBE]:
			# CrazyGames & YouTube Playables handle platform consent natively and prohibit additional blocking user agreements
			if not GameManager.consent_accepted:
				GameManager.set_consent(true, true)
		# V2.0 Instant Play: Brand-new players drop straight into Lv.1 on the 3D Floating Island (0 modal walls!)
		var is_first_session := (GameManager.max_unlocked_level == 1 and GameManager.level_stars.is_empty() and not GameManager.is_beta_build())
		if is_first_session and GameManager.consent_accepted:
			_in_lobby = false
			_home_lobby_ui.close_all()
			_gameplay_hud_root.visible = true
			_load_level(1, false)
		else:
			_load_level(start_lv, false, true)
			_show_home_lobby()
			if not GameManager.consent_accepted:
				_consent_ui.open_consent()

	PlatformBridge.notify_game_ready()


func _get_web_style_query() -> String:
	if not OS.has_feature("web"):
		return ""
	var res = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('style') || ''", true)
	return str(res).to_lower()


func _is_landscape_desktop() -> bool:
	var sz := get_viewport().get_visible_rect().size
	return sz.x > sz.y * 1.15


func _update_responsive_layout() -> void:
	var is_land := _is_landscape_desktop()
	if _camera:
		_camera.fov = 38.0 if is_land else 45.0
	if _gameplay_bot_bar:
		# Never scale top-left-anchored HBoxContainer (shifts off-center); cleanly adjust button sizes instead!
		var b_sz := Vector2(106, 106) if is_land else Vector2(138, 138)
		for b in [_btn_rv_mag, _btn_rv_ice, _btn_retry_hud]:
			if b:
				b.custom_minimum_size = b_sz
		_gameplay_bot_bar.offset_top = (-146 if is_land else -176)
		_gameplay_bot_bar.offset_bottom = (-34 if is_land else -26)
		_gameplay_bot_bar.add_theme_constant_override("separation", 24 if is_land else 34)
	for cap in _keycap_badges:
		if is_instance_valid(cap):
			cap.visible = is_land
	if _pc_hint_label:
		_pc_hint_label.visible = is_land and _playing and not _in_lobby and not _paused


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var kc := (event as InputEventKey).keycode
	if _playing and not _paused and not _in_lobby:
		if kc == KEY_Q:
			_on_magnet_booster_pressed()
		elif kc == KEY_E:
			_on_ice_booster_pressed()
		elif kc == KEY_R:
			AudioManager.play_sfx("ui_click")
			if _ab_mode != "":
				_open_ab_showcase(_ab_mode)
			else:
				_load_level(_level_number, false)
		elif kc == KEY_ESCAPE or kc == KEY_P:
			_pause_gameplay()
	elif _paused and (kc == KEY_ESCAPE or kc == KEY_P):
		_pause_settings_ui.close_modal()
		_resume_gameplay()


func _open_ab_showcase(style: String) -> void:
	_ab_mode = "b" if style == "b" else "a"
	_in_lobby = false
	_paused = false
	_hole.is_paused = false
	_home_lobby_ui.close_all()
	_gameplay_hud_root.visible = true
	if _ab_switcher_bar:
		_ab_switcher_bar.visible = true
		_refresh_ab_switcher_styles()
	_load_level(1 if _ab_mode == "a" else 2, false, false, "res://data/levels/level_ab_option_%s.json" % _ab_mode)


func _run_qa_screen(screen: String, lv: int) -> void:
	match screen:
		"home":
			# Give a realistic showcase state in QA without modifying user save
			_load_level(lv, false, true)
			_show_home_lobby()
		"map":
			_load_level(lv, false, true)
			_show_home_lobby()
			_home_lobby_ui.open_map(1)
		"shop":
			_load_level(lv, false, true)
			_show_home_lobby()
			_home_lobby_ui.open_shop()
		"pause":
			_in_lobby = false
			_home_lobby_ui.close_all()
			_gameplay_hud_root.visible = true
			_load_level(lv, false)
			_pause_gameplay()
		"exit":
			_in_lobby = false
			_home_lobby_ui.close_all()
			_gameplay_hud_root.visible = true
			_load_level(lv, false)
			_request_exit_confirm()
		"ftue":
			_in_lobby = false
			_home_lobby_ui.close_all()
			_gameplay_hud_root.visible = true
			_load_level(1, false)
			_helpers_ui.start_ftue_drag_guide()
		"radar":
			_in_lobby = false
			_home_lobby_ui.close_all()
			_gameplay_hud_root.visible = true
			_load_level(20, false)
		"win":
			_in_lobby = false
			_home_lobby_ui.close_all()
			_gameplay_hud_root.visible = true
			_load_level(lv, false)
			for k in _remaining_targets:
				_remaining_targets[k] = 0
			_check_victory()
		"consent":
			_load_level(lv, false, true)
			_show_home_lobby()
			_consent_ui.open_consent()
		"settings":
			_load_level(lv, false, true)
			_show_home_lobby()
			_pause_settings_ui.open_settings()
		"bi":
			_load_level(lv, false, true)
			_show_home_lobby()
			if _beta_bi_ui:
				_beta_bi_ui.open_inspector()
		"ad_fail":
			_in_lobby = false
			_home_lobby_ui.close_all()
			_gameplay_hud_root.visible = true
			_load_level(lv, false)
			_ad_overlay_ui.show_qa_notice("AD UNAVAILABLE · TRY AGAIN", true)
		"ab_a":
			_open_ab_showcase("a")
		"ab_b":
			_open_ab_showcase("b")
		_:
			_load_level(lv, false, true)
			_show_home_lobby()


func _build_3d_stage() -> void:
	var env_node := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = Color("#5EC8F8")
	_sky_mat.sky_horizon_color = Color("#FFF7DC")
	_sky_mat.ground_horizon_color = Color("#FFF4D2")
	_sky_mat.ground_bottom_color = Color("#FFE3D6")
	_sky_mat.sky_curve = 0.22
	_sky_mat.ground_curve = 0.18
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color("#FFF7EB")
	_env.ambient_light_energy = 0.42 if _is_mobile_perf else 0.28
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 0.96
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.15
	_env.adjustment_contrast = 1.05
	_env.adjustment_brightness = 1.00
	env_node.environment = _env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 34, 0)
	sun.light_color = Color("#FFF4E2")
	sun.light_energy = 0.80 if _is_mobile_perf else 0.68
	# P0 Mobile Thermal Optimization: skip expensive 2048 real-time shadow pass on mobile (use cheap contact shadows!)
	sun.shadow_enabled = not _is_mobile_perf
	if sun.shadow_enabled:
		sun.shadow_opacity = 0.30
		sun.shadow_blur = 2.4
		sun.directional_shadow_max_distance = 62.0
	add_child(sun)

	if not _is_mobile_perf:
		# Desktop keeps 3-point studio lighting; Mobile uses single key light + built-in Fresnel rim shader!
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-28, -142, 0)
		fill.light_color = Color("#CFEAFF")
		fill.light_energy = 0.16
		fill.shadow_enabled = false
		add_child(fill)

		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-20, 165, 0)
		rim.light_color = Color("#FFD6EC")
		rim.light_energy = 0.10
		rim.shadow_enabled = false
		add_child(rim)

	_camera = Camera3D.new()
	_camera.fov = 38.0 if _is_landscape_desktop() else 45.0
	add_child(_camera)
	_camera.look_at_from_position(Vector3(0.0, 17.5, 9.8), Vector3.ZERO, Vector3.UP)

	_island_builder = FloatingIslandBuilder.new()
	add_child(_island_builder)

	_table_mesh = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24.0, 28.0)
	_table_mesh.mesh = plane
	_table_mat = ShaderMaterial.new()
	_table_mat.shader = load("res://shaders/tabletop_cutout.gdshader")
	_table_mesh.material_override = _table_mat
	_table_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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

	# Fullscreen atmospheric overlays
	_frost_rect = ColorRect.new()
	_hud_layer.add_child(_frost_rect)
	_frost_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost_mat = ShaderMaterial.new()
	_frost_mat.shader = load("res://shaders/frost_overlay.gdshader")
	_frost_rect.material = _frost_mat

	_bomb_flash_rect = ColorRect.new()
	_hud_layer.add_child(_bomb_flash_rect)
	_bomb_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bomb_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bomb_flash_rect.color = Color(0.95, 0.22, 0.28, 0.0)

	_joystick_overlay = JoystickOverlay.new()
	_hud_layer.add_child(_joystick_overlay)
	_joystick_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_joystick_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# In-Game Gameplay HUD Container (hidden while in Home Lobby!)
	_gameplay_hud_root = Control.new()
	_gameplay_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gameplay_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_gameplay_hud_root)

	_gameplay_top_margin = MarginContainer.new()
	_gameplay_hud_root.add_child(_gameplay_top_margin)
	_gameplay_top_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_gameplay_top_margin.add_theme_constant_override("margin_left", 16)
	_gameplay_top_margin.add_theme_constant_override("margin_right", 16)
	_gameplay_top_margin.add_theme_constant_override("margin_top", 112 if GameManager.is_beta_build() else 18)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 9)
	_gameplay_top_margin.add_child(top_vbox)

	# === ROW 1: Clear Button vs Status Separation! [Home Btn] | [Unified Frosted HUD Status Dock] | [Pause Btn] ===
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.add_theme_constant_override("separation", 14)
	top_vbox.add_child(row1)

	var btn_exit_home := CandyUI.create_square_icon_button("icon_home", "", false, Color("#F45D94"), Color("#B83264"), Color("#5C1430"), 78, 44)
	btn_exit_home.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_request_exit_confirm()
	)
	row1.add_child(btn_exit_home)

	# Unified Translucent Frosted Status Dock (visually unmistakable as read-only HUD status!)
	var status_dock := PanelContainer.new()
	status_dock.add_theme_stylebox_override("panel", CandyUI.make_hud_glass_dock_style(22, 12, 6))
	row1.add_child(status_dock)

	var status_row := HBoxContainer.new()
	status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	status_row.add_theme_constant_override("separation", 10)
	status_dock.add_child(status_row)

	_timer_pill = CandyUI.create_icon_pill("icon_timer", "0:45", Color("#38BDF8"), Color("#0B78A8"), 32, 38, Color("#0A4266"))
	status_row.add_child(_timer_pill)

	_targets_box = HBoxContainer.new()
	_targets_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_targets_box.add_theme_constant_override("separation", 8)
	status_row.add_child(_targets_box)

	_streak_pill = CandyUI.create_icon_pill("icon_flame", "0", Color("#FF8A2B"), Color("#C2410C"), 26, 36, Color("#662004"))
	status_row.add_child(_streak_pill)

	_btn_pause = CandyUI.create_square_icon_button("icon_pause", "", false, Color("#22B8E8"), Color("#0B78A8"), Color("#0A4266"), 78, 44)
	_btn_pause.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_pause_gameplay()
	)
	row1.add_child(_btn_pause)

	# === ROW 2: Sleek Slim Status Sub-Strip (LV · Hole Size · Fever Gauge) ===
	var row2_panel := PanelContainer.new()
	row2_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row2_panel.add_theme_stylebox_override("panel", CandyUI.make_hud_glass_dock_style(16, 12, 4))
	top_vbox.add_child(row2_panel)

	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.add_theme_constant_override("separation", 12)
	row2_panel.add_child(row2)

	_level_pill = CandyUI.create_icon_pill("icon_crown", "LV.1", Color("#F7AD26"), Color("#B86D0A"), 20, 28, Color("#663804"))
	row2.add_child(_level_pill)

	_hole_lvl_pill = CandyUI.create_icon_pill("icon_hole", "Lv.1", Color("#24C964"), Color("#12823D"), 20, 28, Color("#094A22"))
	row2.add_child(_hole_lvl_pill)

	var fever_wrap := HBoxContainer.new()
	fever_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	fever_wrap.add_theme_constant_override("separation", 6)
	row2.add_child(fever_wrap)

	fever_wrap.add_child(CandyUI.make_icon_rect(CandyUI.get_icon("icon_fever"), 30))

	_fever_bar = ProgressBar.new()
	_fever_bar.custom_minimum_size = Vector2(210, 22)
	_fever_bar.max_value = 100.0
	_fever_bar.value = 0.0
	_fever_bar.show_percentage = false
	var fb_bg := StyleBoxFlat.new()
	fb_bg.bg_color = Color(0.05, 0.10, 0.18, 0.72)
	fb_bg.border_color = Color(1.0, 1.0, 1.0, 0.25)
	fb_bg.set_border_width_all(2)
	fb_bg.set_corner_radius_all(10)
	var fb_fill := StyleBoxFlat.new()
	fb_fill.bg_color = Color("#FFBE2E")
	fb_fill.set_corner_radius_all(8)
	_fever_bar.add_theme_stylebox_override("background", fb_bg)
	_fever_bar.add_theme_stylebox_override("fill", fb_fill)
	fever_wrap.add_child(_fever_bar)

	_buff_label = Label.new()
	_buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(_buff_label, 24, Color("#FFF4B8"), Color("#881337"), 5)
	top_vbox.add_child(_buff_label)

	# === BOTTOM BAR: Large Mobile-Friendly 3D Arcade Icon Buttons (Magnet | Freeze | Retry) ===
	_gameplay_bot_bar = HBoxContainer.new()
	_gameplay_hud_root.add_child(_gameplay_bot_bar)
	_gameplay_bot_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_gameplay_bot_bar.offset_top = -176
	_gameplay_bot_bar.offset_bottom = -26
	_gameplay_bot_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_gameplay_bot_bar.add_theme_constant_override("separation", 34)

	_btn_rv_mag = CandyUI.create_square_icon_button("icon_magnet", "7s", true, Color("#F45D94"), Color("#B83264"), Color("#5C1430"), 138, 70)
	_btn_rv_mag.pressed.connect(_on_magnet_booster_pressed)
	_keycap_badges.append(CandyUI.add_keycap_badge(_btn_rv_mag, "Q"))
	_gameplay_bot_bar.add_child(_btn_rv_mag)

	_btn_rv_ice = CandyUI.create_square_icon_button("icon_ice", "+6s", true, Color("#24C97A"), Color("#12854E"), Color("#094A2A"), 138, 70)
	_btn_rv_ice.pressed.connect(_on_ice_booster_pressed)
	_keycap_badges.append(CandyUI.add_keycap_badge(_btn_rv_ice, "E"))
	_gameplay_bot_bar.add_child(_btn_rv_ice)

	_btn_retry_hud = CandyUI.create_square_icon_button("icon_restart", "", false, Color("#22B8E8"), Color("#0B78A8"), Color("#0A4266"), 138, 66)
	_btn_retry_hud.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		if _ab_mode != "":
			_open_ab_showcase(_ab_mode)
		else:
			_load_level(_level_number, false)
	)
	_keycap_badges.append(CandyUI.add_keycap_badge(_btn_retry_hud, "R"))
	_gameplay_bot_bar.add_child(_btn_retry_hud)

	# === IN-GAME POLISH HELPERS LAYER (Radar Arrows, FTUE Drag Hand, Mechanic Tips, Confetti) ===
	_helpers_ui = GameplayHelpersUI.new()
	_hud_layer.add_child(_helpers_ui)

	_combo_ui = ComboJuiceUI.new()
	_hud_layer.add_child(_combo_ui)

	# PC Desktop subtle control hint strip (hidden on mobile!)
	_pc_hint_label = Label.new()
	_pc_hint_label.text = "DRAG MOUSE or WASD  ·  [Q] MAGNET  ·  [E] FREEZE  ·  [R] RESTART"
	_pc_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pc_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_pc_hint_label.offset_top = -28
	_pc_hint_label.offset_bottom = -4
	_pc_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CandyUI.apply_outlined_label(_pc_hint_label, 18, Color(1.0, 0.99, 0.94, 0.92), Color(0.08, 0.16, 0.28, 0.85), 4)
	_gameplay_hud_root.add_child(_pc_hint_label)

	# Option A vs Option B Live Visual Comparison Toggle Bar (centered cleanly right above bottom dock!)
	_ab_switcher_bar = HBoxContainer.new()
	_ab_switcher_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_ab_switcher_bar.offset_top = -246
	_ab_switcher_bar.offset_bottom = -182
	_ab_switcher_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_ab_switcher_bar.add_theme_constant_override("separation", 14)
	_ab_switcher_bar.visible = false
	_hud_layer.add_child(_ab_switcher_bar)

	var btn_a := CandyUI.create_cta_button("icon_crown", "OPTION A · SCULPTED", Color("#EC36A0"), Color("#9B1464"), Color("#5E093C"), Vector2(252, 60), 18)
	btn_a.name = "BtnA"
	btn_a.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_open_ab_showcase("a")
	)
	_ab_switcher_bar.add_child(btn_a)

	var btn_b := CandyUI.create_cta_button("icon_star", "OPTION B · CC0 KENNEY", Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"), Vector2(264, 60), 18)
	btn_b.name = "BtnB"
	btn_b.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_open_ab_showcase("b")
	)
	_ab_switcher_bar.add_child(btn_b)

	# === STAGE MODAL CARD (Start / 3-Star Victory / Time-Up Rescue) ===
	_overlay_dimmer = ColorRect.new()
	_overlay_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_dimmer.color = Color(0.05, 0.12, 0.22, 0.45)
	_overlay_dimmer.visible = false
	_hud_layer.add_child(_overlay_dimmer)

	_overlay_panel = PanelContainer.new()
	_hud_layer.add_child(_overlay_panel)
	_overlay_panel.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_panel.custom_minimum_size = Vector2(780, 620)
	_overlay_panel.offset_left = -390
	_overlay_panel.offset_right = 390
	_overlay_panel.offset_top = -310
	_overlay_panel.offset_bottom = 310
	_overlay_panel.add_theme_stylebox_override("panel", CandyUI.create_candy_card_style(Color("#28B9E8"), Color("#0F769E")))
	_overlay_panel.visible = false

	var ov_box := VBoxContainer.new()
	ov_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ov_box.add_theme_constant_override("separation", 16)
	_overlay_panel.add_child(ov_box)

	_overlay_badge = CandyUI.create_icon_pill("icon_crown", "LV.1", Color("#F24C9B"), Color("#B01C65"), 24, 34, Color("#630B38"))
	_overlay_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ov_box.add_child(_overlay_badge)

	# 3-Star Victory Showcase Row (visible on Victory!)
	_modal_stars_box = HBoxContainer.new()
	_modal_stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_modal_stars_box.add_theme_constant_override("separation", 14)
	_modal_stars_box.visible = false
	ov_box.add_child(_modal_stars_box)

	_overlay_title = Label.new()
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(_overlay_title, 46, Color("#FF6EB3"), Color("#2E1042"), 7)
	ov_box.add_child(_overlay_title)

	# Visual 3D Target Icons row right inside the modal!
	_modal_targets_box = HBoxContainer.new()
	_modal_targets_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_modal_targets_box.add_theme_constant_override("separation", 14)
	ov_box.add_child(_modal_targets_box)

	# Reward Pills row (Coins / Shards / Chest Ready on Victory!)
	_modal_rewards_box = HBoxContainer.new()
	_modal_rewards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_modal_rewards_box.add_theme_constant_override("separation", 14)
	_modal_rewards_box.visible = false
	ov_box.add_child(_modal_rewards_box)

	_overlay_desc = Label.new()
	_overlay_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_desc.add_theme_font_size_override("font_size", 24)
	_overlay_desc.add_theme_color_override("font_color", Color("#4B5563"))
	ov_box.add_child(_overlay_desc)

	_btn_primary = CandyUI.create_cta_button("icon_play", "PLAY", Color("#25CF65"), Color("#12853E"), Color("#0A4C22"), Vector2(620, 108), 38)
	_btn_primary.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ov_box.add_child(_btn_primary)

	var sub_row := HBoxContainer.new()
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 18)
	ov_box.add_child(sub_row)

	_btn_secondary = CandyUI.create_cta_button("icon_ad", "LV.2 + 7s", Color("#F7A526"), Color("#B8670A"), Color("#663404"), Vector2(490, 96), 32, "icon_magnet")
	sub_row.add_child(_btn_secondary)

	_btn_tertiary_home = CandyUI.create_square_icon_button("icon_home", "", false, Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"), 96, 54)
	_btn_tertiary_home.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_show_home_lobby()
	)
	sub_row.add_child(_btn_tertiary_home)

	# === HOME LOBBY + WORLD MAP + HOLE SKIN SHOP ===
	_home_lobby_ui = HomeLobbyUI.new()
	_home_lobby_ui.play_level_requested.connect(_on_lobby_play_level)
	_home_lobby_ui.settings_requested.connect(func(): _pause_settings_ui.open_settings())
	_home_lobby_ui.world_preview_requested.connect(func(wid: int): _load_level(int(WORLD_META[wid]["start"]), false, true))
	_home_lobby_ui.confetti_requested.connect(func(cnt: int): _helpers_ui.spawn_confetti(cnt))
	_home_lobby_ui.upgrade_purchased.connect(func(_k: String):
		if _hole:
			_hole.reset_for_level(1, _hole.position)
			_hole.apply_skin(GameManager.equipped_skin)
	)
	_hud_layer.add_child(_home_lobby_ui)

	# === PAUSE / SETTINGS / EXIT MODAL (topmost over lobby & gameplay) ===
	_pause_settings_ui = PauseSettingsUI.new()
	_pause_settings_ui.resumed.connect(_resume_gameplay)
	_pause_settings_ui.restarted.connect(func():
		_paused = false
		_hole.is_paused = false
		_load_level(_level_number, false)
	)
	_pause_settings_ui.go_home.connect(_show_home_lobby)
	_pause_settings_ui.privacy_requested.connect(func(): _consent_ui.open_consent())
	_hud_layer.add_child(_pause_settings_ui)

	# === PRIVACY / GDPR CONSENT & IN-APP LEGAL READER ===
	_consent_ui = ConsentLegalUI.new()
	_hud_layer.add_child(_consent_ui)

	# === AD LOADING SPINNER & NO-FILL / IAP NOTICE LAYER ===
	_ad_overlay_ui = AdOverlayUI.new()
	_hud_layer.add_child(_ad_overlay_ui)

	# === BETA-ONLY FLOATING QA BAR & BI INSPECTOR (Zero pixels rendered in Release!) ===
	if GameManager.is_beta_build():
		_beta_bi_ui = BetaBIInspectorUI.new()
		_hud_layer.add_child(_beta_bi_ui)
		_build_beta_bar()

	_refresh_booster_buttons()


func _build_beta_bar() -> void:
	_beta_bar_container = MarginContainer.new()
	_beta_bar_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_beta_bar_container.add_theme_constant_override("margin_top", 8)
	_beta_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_beta_bar_container)

	var beta_card := PanelContainer.new()
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.08, 0.12, 0.20, 0.82)
	bsb.border_color = Color(1.0, 0.82, 0.25, 0.72)
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(14)
	bsb.set_content_margin_all(5)
	beta_card.add_theme_stylebox_override("panel", bsb)
	beta_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_beta_bar_container.add_child(beta_card)

	var beta_v := VBoxContainer.new()
	beta_v.add_theme_constant_override("separation", 4)
	beta_card.add_child(beta_v)

	var world_row := HBoxContainer.new()
	world_row.alignment = BoxContainer.ALIGNMENT_CENTER
	world_row.add_theme_constant_override("separation", 5)
	beta_v.add_child(world_row)

	var b_tag := Label.new()
	b_tag.text = " BETA "
	CandyUI.apply_outlined_label(b_tag, 14, Color("#FDE047"), Color("#0F172A"), 4)
	world_row.add_child(b_tag)

	var btn_b_home := CandyUI.create_beta_chip("HOME", Color("#0284C7"))
	btn_b_home.pressed.connect(func(): _show_home_lobby())
	world_row.add_child(btn_b_home)

	var btn_b_reset := CandyUI.create_beta_chip("RESET", Color("#DC2626"))
	btn_b_reset.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		GameManager.reset_all_progress()
		_attempts_this_level = 0
		_load_level(1, false, true)
		_show_home_lobby()
	)
	world_row.add_child(btn_b_reset)

	var btn_b_bi := CandyUI.create_beta_chip("BI", Color("#7C3AED"))
	btn_b_bi.pressed.connect(func():
		if _beta_bi_ui:
			_beta_bi_ui.open_inspector()
	)
	world_row.add_child(btn_b_bi)

	for wid in [1, 2, 3, 4, 5]:
		var wb := CandyUI.create_beta_chip(str(WORLD_META[wid]["short"]), Color("#1E293B"))
		var target_w: int = wid
		wb.pressed.connect(func(): _beta_jump_level(int(WORLD_META[target_w]["start"])))
		world_row.add_child(wb)
		_world_buttons[wid] = wb

	var stage_row := HBoxContainer.new()
	stage_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_row.add_theme_constant_override("separation", 5)
	beta_v.add_child(stage_row)

	var btn_prev := CandyUI.create_beta_chip("< Prev", Color("#334155"))
	btn_prev.pressed.connect(func(): _beta_jump_level(GameManager.MAX_LEVEL if _level_number <= 1 else _level_number - 1))
	stage_row.add_child(btn_prev)

	for kind in ["start", "hard", "cliff", "mega"]:
		var txt := "MEGA" if kind == "mega" else ("CLIFF" if kind == "cliff" else ("HARD" if kind == "hard" else "START"))
		var sb := CandyUI.create_beta_chip(txt, Color("#334155"))
		var k: String = kind
		sb.pressed.connect(func(): _beta_jump_level(int(WORLD_META[_world_id][k])))
		stage_row.add_child(sb)
		_stage_buttons[kind] = sb

	var btn_next := CandyUI.create_beta_chip("Next >", Color("#334155"))
	btn_next.pressed.connect(func(): _beta_jump_level((_level_number % GameManager.MAX_LEVEL) + 1))
	stage_row.add_child(btn_next)


func _beta_jump_level(lv: int) -> void:
	_in_lobby = false
	_paused = false
	_hole.is_paused = false
	_home_lobby_ui.close_all()
	_pause_settings_ui.close_modal()
	_gameplay_hud_root.visible = true
	_load_level(lv, true)


func _show_home_lobby() -> void:
	_in_lobby = true
	_playing = false
	_paused = false
	if _hole:
		_hole.is_controllable = false
		_hole.is_paused = false
	_overlay_panel.visible = false
	_overlay_dimmer.visible = false
	_pause_settings_ui.close_modal()
	_gameplay_hud_root.visible = false
	_helpers_ui.stop_ftue_drag_guide()
	_helpers_ui.hide_radars()
	_home_lobby_ui.open_home()
	PlatformBridge.notify_gameplay_stop()


func _on_lobby_play_level(lv_num: int) -> void:
	_in_lobby = false
	_paused = false
	_hole.is_paused = false
	_home_lobby_ui.close_all()
	_gameplay_hud_root.visible = true
	_load_level(lv_num, true)


func _pause_gameplay() -> void:
	if _in_lobby or _overlay_panel.visible:
		return
	_paused = true
	_playing = false
	_hole.is_controllable = false
	_hole.is_paused = true
	_helpers_ui.hide_radars()
	_pause_settings_ui.open_pause(_level_number)
	PlatformBridge.notify_gameplay_stop()


func _request_exit_confirm() -> void:
	if _in_lobby:
		return
	if _overlay_panel.visible:
		_show_home_lobby()
		return
	_paused = true
	_playing = false
	_hole.is_controllable = false
	_hole.is_paused = true
	_helpers_ui.hide_radars()
	_pause_settings_ui.open_exit_confirm(_level_number)
	PlatformBridge.notify_gameplay_stop()


func _resume_gameplay() -> void:
	if _in_lobby:
		return
	_paused = false
	_hole.is_paused = false
	_playing = true
	_hole.is_controllable = true
	PlatformBridge.notify_gameplay_start()


func _on_app_visibility_changed(is_visible: bool) -> void:
	if OS.get_environment("QA_SCREEN") != "" or OS.get_environment("QA_START_LEVEL") != "":
		return
	if not is_visible and _playing and not _paused and not _in_lobby:
		_pause_gameplay()


func _apply_safe_area_margins(margins: Dictionary) -> void:
	var st := int(round(float(margins.get("top", 0.0))))
	var sb := int(round(float(margins.get("bottom", 0.0))))
	if _beta_bar_container:
		_beta_bar_container.add_theme_constant_override("margin_top", 8 + st)
	if _gameplay_top_margin:
		var base_top := 112 if GameManager.is_beta_build() else 18
		_gameplay_top_margin.add_theme_constant_override("margin_top", base_top + st)
	if _gameplay_bot_bar:
		_gameplay_bot_bar.offset_top = -176 - sb
		_gameplay_bot_bar.offset_bottom = -26 - sb
	if _home_lobby_ui:
		_home_lobby_ui.apply_safe_margins(margins)


func _refresh_booster_buttons() -> void:
	if _btn_rv_mag:
		CandyUI.set_booster_button_stock(_btn_rv_mag, GameManager.inv_magnet)
	if _btn_rv_ice:
		CandyUI.set_booster_button_stock(_btn_rv_ice, GameManager.inv_ice)


func _on_magnet_booster_pressed() -> void:
	if not _playing or AdManager.is_ad_playing:
		return
	if GameManager.consume_booster("magnet"):
		_hole.activate_magnet(7.0)
		_spawn_popup(_hole.position, "MAGNET 7s!", Color("#EC36A0"))
		_update_buff_banner()
		_refresh_booster_buttons()
		AnalyticsManager.track("booster_use", {"kind": "magnet", "source": "inventory", "level": _level_number})
	elif not AdManager.reward_ads_available:
		if GameManager.coins >= 50:
			GameManager.coins -= 50
			GameManager.save_progress()
			GameManager.economy_changed.emit()
			_hole.activate_magnet(7.0)
			_spawn_popup(_hole.position, "MAGNET 7s! (-50c)", Color("#EC36A0"))
			_update_buff_banner()
			_refresh_booster_buttons()
			AnalyticsManager.track("booster_use", {"kind": "magnet", "source": "coins", "level": _level_number})
		else:
			AdManager.ad_notice.emit("NEED 50 COINS FOR MAGNET", true)
	else:
		AdManager.note_rv_offer("in_level_magnet", _level_number)
		AdManager.show_rewarded("in_level_magnet", _level_number)


func _on_ice_booster_pressed() -> void:
	if not _playing or AdManager.is_ad_playing:
		return
	if GameManager.consume_booster("ice"):
		_ice_freeze_timer = maxf(_ice_freeze_timer, 6.0)
		_frost_mat.set_shader_parameter("frost_amount", 1.0)
		AudioManager.play_sfx("ice")
		_spawn_popup(_hole.position, "+6s FREEZE!", Color("#0EA5E9"))
		_update_buff_banner()
		_refresh_booster_buttons()
		AnalyticsManager.track("booster_use", {"kind": "ice", "source": "inventory", "level": _level_number})
	elif not AdManager.reward_ads_available:
		if GameManager.coins >= 50:
			GameManager.coins -= 50
			GameManager.save_progress()
			GameManager.economy_changed.emit()
			_ice_freeze_timer = maxf(_ice_freeze_timer, 6.0)
			_frost_mat.set_shader_parameter("frost_amount", 1.0)
			AudioManager.play_sfx("ice")
			_spawn_popup(_hole.position, "+6s FREEZE! (-50c)", Color("#0EA5E9"))
			_update_buff_banner()
			_refresh_booster_buttons()
			AnalyticsManager.track("booster_use", {"kind": "ice", "source": "coins", "level": _level_number})
		else:
			AdManager.ad_notice.emit("NEED 50 COINS FOR FREEZE", true)
	else:
		AdManager.note_rv_offer("in_level_ice", _level_number)
		AdManager.show_rewarded("in_level_ice", _level_number)


func _refresh_ab_switcher_styles() -> void:
	if not _ab_switcher_bar:
		return
	var ba := _ab_switcher_bar.get_node_or_null("BtnA") as Button
	var bb := _ab_switcher_bar.get_node_or_null("BtnB") as Button
	if ba:
		ba.modulate = Color.WHITE if _ab_mode == "a" else Color(0.76, 0.80, 0.88, 0.88)
	if bb:
		bb.modulate = Color.WHITE if _ab_mode == "b" else Color(0.76, 0.80, 0.88, 0.88)


func _apply_world_theme(world_id: int) -> void:
	_world_id = world_id
	var tex_path := ""
	match world_id:
		2:
			_sky_mat.sky_top_color = Color("#5EC6FA")
			_sky_mat.sky_horizon_color = Color("#FFF4C2")
			_sky_mat.ground_horizon_color = Color("#FFE6A8")
			_sky_mat.ground_bottom_color = Color("#F5C26B")
			_table_mat.set_shader_parameter("border_color", Color("#EBBF58"))
			tex_path = "res://assets/textures/w2_01_playmat_tile.png"
		3:
			_sky_mat.sky_top_color = Color("#1E4E8C")
			_sky_mat.sky_horizon_color = Color("#7EC4EA")
			_sky_mat.ground_horizon_color = Color("#9CD8F2")
			_sky_mat.ground_bottom_color = Color("#4D8BB8")
			_table_mat.set_shader_parameter("border_color", Color("#436278"))
			tex_path = "res://assets/textures/w3_01_table_tile.png"
		4:
			_sky_mat.sky_top_color = Color("#2FA687")
			_sky_mat.sky_horizon_color = Color("#A6F0DC")
			_sky_mat.ground_horizon_color = Color("#C8F7E8")
			_sky_mat.ground_bottom_color = Color("#5EC9A8")
			_table_mat.set_shader_parameter("border_color", Color("#52C478"))
			tex_path = "res://assets/textures/w4_01_desk_tile.png"
		5:
			_sky_mat.sky_top_color = Color("#2F88E8")
			_sky_mat.sky_horizon_color = Color("#C6F0FF")
			_sky_mat.ground_horizon_color = Color("#A8E6FF")
			_sky_mat.ground_bottom_color = Color("#6BC4F8")
			_table_mat.set_shader_parameter("border_color", Color("#7AD0FA"))
			tex_path = "res://assets/textures/w5_01_arcade_tile.png"
		_:
			_sky_mat.sky_top_color = Color("#46B8F5")
			_sky_mat.sky_horizon_color = Color("#9BE2FF")
			_sky_mat.ground_horizon_color = Color("#9BE2FF")
			_sky_mat.ground_bottom_color = Color("#CBEFFF")
			_table_mat.set_shader_parameter("border_color", Color("#64D4B8"))
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
	for entry in _particle_pool:
		entry["active"] = false
		var mi: MeshInstance3D = entry["node"]
		if is_instance_valid(mi):
			mi.visible = false
	_items.clear()
	_powerups.clear()
	_traps.clear()
	_walls.clear()
	_bombs.clear()


func _load_level(num: int, show_start_modal: bool, lobby_backdrop: bool = false, custom_path: String = "") -> void:
	_clear_entities()
	_level_number = clampi(num, 1, GameManager.MAX_LEVEL)
	if custom_path == "":
		_ab_mode = ""
		if _ab_switcher_bar:
			_ab_switcher_bar.visible = false
	_used_rv_this_run = false
	if not lobby_backdrop:
		_attempts_this_level += 1
	_ice_freeze_timer = 0.0
	_bomb_flash_timer = 0.0
	_paused = false
	_hole.is_paused = false
	_frost_mat.set_shader_parameter("frost_amount", 0.0)
	_bomb_flash_rect.color.a = 0.0
	_buff_label.text = ""
	_helpers_ui.stop_ftue_drag_guide()
	_helpers_ui.hide_radars()
	if _combo_ui:
		_combo_ui.reset_combo()

	var path := custom_path if custom_path != "" else ("res://data/levels/level_%03d.json" % _level_number)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Failed to load level: " + path)
		return
	_level_data = parsed

	var world_id := int(_level_data.get("world", 1))
	_apply_world_theme(world_id)
	var tag := str(_level_data.get("difficulty_tag", "NORMAL"))
	_is_mega_stage = (tag == "MEGA_BOSS")

	var arena_arr: Array = _level_data.get("arena", [18.0, 22.0])
	var aw := float(arena_arr[0])
	var ah := float(arena_arr[1])
	_board_half = Vector2(aw * 0.5, ah * 0.5)
	var plane := PlaneMesh.new()
	plane.size = Vector2(aw, ah)
	_table_mesh.mesh = plane
	_table_mat.set_shader_parameter("board_half_size", _board_half)
	_table_mat.set_shader_parameter("corner_radius", 1.65)
	_hole.board_bounds = _board_half
	if _island_builder:
		_island_builder.rebuild(_board_half, world_id, 1.65)

	_base_duration = float(_level_data.get("duration", 45.0))
	_time_left = _base_duration + GameManager.get_upgrade_bonus_time() + DDAController.get_timer_adjustment(_level_number, tag)
	_last_tick_sec = 6

	var sp_arr: Array = _level_data.get("spawn", [0.0, 0.0])
	_hole.reset_for_level(1, Vector3(float(sp_arr[0]), 0.0, float(sp_arr[1])))
	_hole.apply_skin(GameManager.equipped_skin)
	_target_cam_height = 18.5 if _is_mega_stage else (15.4 if _is_landscape_desktop() else 16.8)
	_cam_snap_next = true

	var targets: Dictionary = _level_data.get("targets", {})

	var max_stack_y := 0.0
	for entry in _level_data.get("items", []):
		var key := str(entry["key"])
		var def := GameManager.get_item_def(key)
		if def.is_empty():
			continue
		var p: Array = entry["pos"]
		var sy := float(entry.get("y", 0.0))
		max_stack_y = maxf(max_stack_y, sy)
		var rot_d: float = float(entry["rot_deg"]) if entry.has("rot_deg") else NAN
		var item := SwallowableItem.new()
		item.setup(key, def, Vector3(float(p[0]), sy, float(p[1])), int(entry.get("color_idx", 0)), targets.has(key), rot_d)
		item.swallowed.connect(_on_item_swallowed)
		_entities_root.add_child(item)
		_items.append(item)

	if max_stack_y >= 1.8:
		_target_cam_height += minf((max_stack_y - 1.2) * 0.45, 1.85)

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

	# Rebuild Icon-First Target Chips in Top Row 1
	_remaining_targets.clear()
	_target_pills.clear()
	for child in _targets_box.get_children():
		child.queue_free()

	var t_idx := 0
	for t_key in targets:
		var count := int(targets[t_key])
		_remaining_targets[t_key] = count
		var def := GameManager.get_item_def(t_key)
		var t_lv := int(def.get("tier", 1))
		var th: Dictionary = TARGET_PILL_THEMES[t_idx % TARGET_PILL_THEMES.size()]
		var chip := CandyUI.create_target_chip(t_key, count, t_lv, th["bg"], th["bevel"], th["outline"])
		_targets_box.add_child(chip)
		_target_pills[t_key] = chip
		t_idx += 1

	# Highlight Beta bar tabs (only exists in Beta build)
	if GameManager.is_beta_build():
		for wid in _world_buttons:
			var wb: Button = _world_buttons[wid]
			var is_cur: bool = (wid == world_id)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("#22B8EE") if is_cur else Color("#1E293B")
			sb.border_color = Color("#7DD3FC") if is_cur else Color(1, 1, 1, 0.22)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(10)
			sb.content_margin_left = 9
			sb.content_margin_right = 9
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			wb.add_theme_stylebox_override("normal", sb)
			wb.add_theme_stylebox_override("hover", sb)
			wb.add_theme_stylebox_override("pressed", sb)

		var wmeta: Dictionary = WORLD_META[world_id]
		for k in _stage_buttons:
			var btn: Button = _stage_buttons[k]
			var active: bool = (int(wmeta[k]) == _level_number)
			var is_boss: bool = (k == "cliff" or k == "mega")
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("#EC36A0") if (active and is_boss) else (Color("#25CF65") if active else (Color("#6B1D45") if is_boss else Color("#334155")))
			sb.border_color = Color(1, 1, 1, 0.45 if active else 0.20)
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(10)
			sb.content_margin_left = 9
			sb.content_margin_right = 9
			sb.content_margin_top = 4
			sb.content_margin_bottom = 4
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("hover", sb)
			btn.add_theme_stylebox_override("pressed", sb)

	var fname := str(_level_data.get("formation_name", "Stage"))
	var lv_icon := "icon_crown" if tag in ["SUPER_HARD", "MEGA_BOSS"] else "icon_hole"
	CandyUI.update_icon_pill(_level_pill, "LV.%d" % _level_number, Color("#F7AD26"), Color("#B86D0A"), Color("#663804"), lv_icon)
	var shown_streak := maxi(GameManager.win_streak, int(_level_data.get("streak_hint", 0)))
	CandyUI.update_icon_pill(_streak_pill, str(shown_streak), Color("#FF8A2B"), Color("#C2410C"), Color("#662004"))
	_update_timer_ui()
	_refresh_booster_buttons()

	if lobby_backdrop:
		_playing = false
		_hole.is_controllable = false
		_overlay_panel.visible = false
		_overlay_dimmer.visible = false
		return

	if show_start_modal:
		_show_start_overlay(tag, fname, world_id, targets)
	else:
		_begin_play()


func _populate_modal_targets(targets: Dictionary) -> void:
	for c in _modal_targets_box.get_children():
		c.queue_free()
	var idx := 0
	for t_key in targets:
		var count := int(targets[t_key])
		var def := GameManager.get_item_def(t_key)
		var t_lv := int(def.get("tier", 1))
		var th: Dictionary = TARGET_PILL_THEMES[idx % TARGET_PILL_THEMES.size()]
		var chip := CandyUI.create_target_chip(t_key, count, t_lv, th["bg"], th["bevel"], th["outline"])
		_modal_targets_box.add_child(chip)
		idx += 1


func _animate_modal_open() -> void:
	_overlay_dimmer.visible = true
	_overlay_panel.visible = true
	_overlay_panel.pivot_offset = _overlay_panel.custom_minimum_size * 0.5
	_overlay_panel.scale = Vector2(0.86, 0.86)
	var tw := create_tween()
	tw.tween_property(_overlay_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_start_overlay(tag: String, fname: String, world_id: int, targets: Dictionary) -> void:
	_playing = false
	_hole.is_controllable = false
	_modal_stars_box.visible = false
	_modal_rewards_box.visible = false
	var is_hard_tier := tag in ["HARD", "SUPER_HARD", "MEGA_BOSS"]
	var badge_icon := "icon_crown" if tag in ["SUPER_HARD", "MEGA_BOSS"] else "icon_hole"
	var badge_txt := "W%d · %s" % [world_id, tag.replace("_", " ")]
	CandyUI.update_icon_pill(
		_overlay_badge, badge_txt,
		Color("#EC36A0") if is_hard_tier else Color("#22B8EE"),
		Color("#9B1464") if is_hard_tier else Color("#0B78A8"),
		Color("#5E093C") if is_hard_tier else Color("#0A4266"),
		badge_icon
	)
	_overlay_title.text = "LV.%d · %s" % [_level_number, fname]
	_modal_targets_box.visible = true
	_populate_modal_targets(targets)

	if tag == "MEGA_BOSS":
		_overlay_desc.text = "MEGA %.0fx%.0f  ·  %.0fs" % [_board_half.x * 2.0, _board_half.y * 2.0, _time_left]
	elif _bombs.size() > 0:
		_overlay_desc.text = "%.0fs  ·  Avoid -3s Bombs!" % _time_left
	else:
		_overlay_desc.text = "%.0fs  ·  Drag to Gobble!" % _time_left

	_rebind_button(_btn_primary, "icon_play", "PLAY", Color("#25CF65"), Color("#12853E"), Color("#0A4C22"), "", func():
		AudioManager.start_bgm()
		AudioManager.play_sfx("ui_click")
		_begin_play()
	)
	_btn_secondary.visible = true
	AdManager.note_rv_offer("pre_level_boost", _level_number)
	_rebind_button(_btn_secondary, "icon_ad", "LV.2 + 7s", Color("#F7A526"), Color("#B8670A"), Color("#663404"), "icon_magnet", func():
		AudioManager.start_bgm()
		AudioManager.play_sfx("ui_click")
		AdManager.show_rewarded("pre_level_boost", _level_number)
	)
	_animate_modal_open()


func _begin_play() -> void:
	_overlay_panel.visible = false
	_overlay_dimmer.visible = false
	_playing = true
	_paused = false
	_hole.is_paused = false
	_hole.is_controllable = true
	PlatformBridge.notify_gameplay_start()
	AnalyticsManager.track("level_start", {
		"level": _level_number,
		"world": _world_id,
		"tag": str(_level_data.get("difficulty_tag", "NORMAL")),
		"attempt": _attempts_this_level,
		"skin": GameManager.equipped_skin,
		"streak": GameManager.win_streak,
	})

	# FTUE Lv.1 drag hand guide (shows until player starts dragging!)
	if _level_number == 1 and not GameManager.has_seen_tutorial("drag"):
		_helpers_ui.start_ftue_drag_guide()
	elif _bombs.size() > 0 and not GameManager.has_seen_tutorial("bomb"):
		_helpers_ui.show_mechanic_tip("bomb", "icon_timer", "AVOID -3s BOMBS!", Color("#F43F5E"), Color("#9F1239"), Color("#580A20"))


func _process(delta: float) -> void:
	_table_mat.set_shader_parameter("hole_world_pos", _hole.position)
	_table_mat.set_shader_parameter("hole_radius", _hole.current_radius)

	if _bomb_flash_timer > 0.0:
		_bomb_flash_timer = maxf(_bomb_flash_timer - delta * 2.4, 0.0)
		_bomb_flash_rect.color.a = _bomb_flash_timer * 0.28

	# Gentle scenic camera sway in Home Lobby; tight responsive follow in Gameplay (adaptive PC 16:9 vs Mobile 9:16!)
	var is_land := _is_landscape_desktop()
	var base_fov := 38.0 if is_land else 45.0
	if _fov_punch > 0.0:
		_fov_punch = maxf(_fov_punch - delta * 6.5, 0.0)
	_camera.fov = lerpf(_camera.fov, base_fov + _fov_punch, minf(delta * 10.0, 1.0))

	if _in_lobby:
		_lobby_orbit_time += delta
		var lx := sin(_lobby_orbit_time * 0.45) * 2.4
		var lz := cos(_lobby_orbit_time * 0.35) * 1.4
		var lobby_cam := Vector3(lx, 17.5 if is_land else 19.2, lz + (18.5 if is_land else 12.8))
		_camera.position = _camera.position.lerp(lobby_cam, minf(delta * 3.5, 1.0))
		_camera.look_at(Vector3(0.0, -0.6, 0.0), Vector3.UP)
	else:
		# Mathematically guaranteed 1:1 Hole Follow Camera for ALL map sizes (17x21 -> 42x48) & ALL screen ratios!
		var vp_sz := get_viewport().get_visible_rect().size
		var aspect := clampf(vp_sz.x / maxf(vp_sz.y, 1.0), 0.45, 2.4)
		var z_off := 15.8 if is_land else 11.4
		var cam_h := (_target_cam_height * 1.08) if is_land else (_target_cam_height * 1.05)
		var dist_cam := sqrt(cam_h * cam_h + z_off * z_off)
		var tan_half_v := tan(deg_to_rad(_camera.fov * 0.5))
		var sin_pitch := cam_h / maxf(dist_cam, 0.01)

		# Live visible ground half-spans at Y=0 for current FOV, height, pitch & viewport aspect
		var vis_half_x := dist_cam * tan_half_v * aspect
		var vis_half_z := (dist_cam * tan_half_v) / maxf(sin_pitch, 0.35)

		# Edge clamp limits: keep board nicely framed on small maps while panning fully across giant maps
		var pad_x := maxf(1.5, vis_half_x * 0.48)
		var pad_z := maxf(1.5, vis_half_z * 0.36)
		var lim_x := maxf(0.0, _board_half.x - pad_x)
		var lim_z := maxf(0.0, _board_half.y - pad_z)

		# Follow the hole 1:1 (never 0.34x lag!) with a subtle -Z look-ahead for tall 3D stacks
		var look_x := clampf(_hole.position.x, -lim_x, lim_x)
		var look_z := clampf(_hole.position.z - (0.65 if is_land else 0.50), -lim_z, lim_z)

		# Hard safety envelope: hole can NEVER drift outside the clear inner safe zone (below HUD, above Q/E/R!)
		var safe_x := maxf(1.8, vis_half_x * 0.52)
		var safe_z_top := maxf(1.8, vis_half_z * 0.34)
		var safe_z_bot := maxf(1.8, vis_half_z * 0.40)
		look_x = clampf(look_x, _hole.position.x - safe_x, _hole.position.x + safe_x)
		look_z = clampf(look_z, _hole.position.z - safe_z_bot, _hole.position.z + safe_z_top)

		var target_look := Vector3(look_x, -0.45 if is_land else -0.20, look_z)
		var desired_cam := Vector3(look_x, cam_h, look_z + z_off)

		if _camera_shake > 0.0:
			_camera_shake = maxf(_camera_shake - delta * 20.0, 0.0)
			desired_cam.x += randf_range(-0.12, 0.12) * _camera_shake
			desired_cam.z += randf_range(-0.12, 0.12) * _camera_shake

		if _cam_snap_next:
			_cam_snap_next = false
			_cam_look_pos = target_look
			_camera.position = desired_cam
		else:
			var t_cam := minf(delta * 8.5, 1.0)
			_cam_look_pos = _cam_look_pos.lerp(target_look, t_cam)
			_camera.position = _camera.position.lerp(desired_cam, t_cam)
		_camera.look_at(_cam_look_pos, Vector3.UP)

	if _pc_hint_label:
		_pc_hint_label.visible = is_land and _playing and not _in_lobby and not _paused

	# Always step helpers & pooled particles (keeps confetti fluttering & zero GC allocations!)
	var active_play := _playing and not _paused and not AdManager.is_ad_playing
	_update_thermal_fps(active_play)
	_step_particle_pool(delta)
	_helpers_ui.step_helpers(delta, active_play, _camera, _hole, _items, _remaining_targets)

	if not active_play:
		return

	for wall in _walls:
		if is_instance_valid(wall):
			if wall.step_interaction(_hole, delta):
				_camera_shake = maxf(_camera_shake, 3.0)
				_spawn_popup(_hole.position + Vector3(0, 1.0, 0), "BOING!", Color("#A855F7"))
				_helpers_ui.show_mechanic_tip("wall", "icon_fever", "RUBBER BOUNCE WALL!", Color("#A855F7"), Color("#6B21A8"), Color("#3B0764"))

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


func _format_clock(sec: float) -> String:
	if sec < 10.0:
		return "%.1f" % sec
	var total := int(ceil(sec))
	return "%d:%02d" % [total / 60, total % 60]


func _update_timer_ui() -> void:
	var txt := _format_clock(_time_left)
	if _ice_freeze_timer > 0.0:
		CandyUI.update_icon_pill(_timer_pill, txt, Color("#38BDF8"), Color("#0284C7"), Color("#083344"), "icon_ice")
	elif _time_left <= 8.0:
		CandyUI.update_icon_pill(_timer_pill, txt, Color("#F43F5E"), Color("#9F1239"), Color("#580A20"), "icon_timer")
	else:
		CandyUI.update_icon_pill(_timer_pill, txt, Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"), "icon_timer")


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
	_spawn_pop_particles(trap_pos + Vector3(0, 0.25, 0), trap_col, 14)
	_spawn_popup(_hole.position, "%s PULL!" % trap_lbl, trap_col)
	_helpers_ui.show_mechanic_tip("gum", "icon_hole", "PULL TO SNAP FREE!", Color("#EC36A0"), Color("#9B1464"), Color("#5E093C"))


func _on_bomb_detonated(world_pos: Vector3, penalty: float) -> void:
	_time_left = maxf(0.1, _time_left - penalty)
	_bomb_flash_timer = 1.0
	_camera_shake = 8.5
	AudioManager.play_sfx("fail", 1.35)
	PlatformBridge.trigger_haptic(55)
	_spawn_pop_particles(world_pos + Vector3(0, 0.3, 0), Color("#F43F5E"), 20)
	_spawn_popup(world_pos, "-%.0fs!" % penalty, Color("#F43F5E"))
	_update_timer_ui()


func _on_item_swallowed(item_key: String, tier: int, xp: float, pos: Vector3, tint: Color) -> void:
	AudioManager.play_swallow(tier)
	_hole.add_xp(xp)
	_spawn_pop_particles(pos, tint, clampi(10 + tier * 4, 10, 26))

	# Trigger staggered domino-waterfall cascade for stacked monument items perched above!
	for other in _items:
		if is_instance_valid(other) and other.state == SwallowableItem.State.IDLE and other.position.y > 0.06:
			var dxz := Vector2(other.position.x - pos.x, other.position.z - pos.z)
			if dxz.length() < 1.55:
				var imp := Vector3(pos.x - other.position.x, 0.0, pos.z - other.position.z)
				var delay := clampf((other.position.y - pos.y) * 0.032, 0.0, 0.28)
				other.trigger_stack_collapse(imp.normalized() if imp.length() > 0.05 else Vector3.FORWARD, delay)

	if _combo_ui:
		var combo := _combo_ui.register_swallow(tier)
		if combo >= 5:
			_fov_punch = minf(_fov_punch + 0.65, 2.8)

	if tier >= 3:
		_camera_shake = maxf(_camera_shake, float(tier) * 1.6)
		_fov_punch = maxf(_fov_punch, 1.8)
		PlatformBridge.trigger_haptic(35)

	if _remaining_targets.has(item_key) and _remaining_targets[item_key] > 0:
		_remaining_targets[item_key] -= 1
		var left: int = _remaining_targets[item_key]
		var chip: PanelContainer = _target_pills[item_key]
		var box := chip.get_node_or_null("Box")
		if left <= 0:
			chip.add_theme_stylebox_override("panel", CandyUI.make_pill_style(Color("#24C964"), Color("#12823D"), 24, 12, 4))
			if box:
				var c_lbl := box.get_node_or_null("Count") as Label
				var t_lbl := box.get_node_or_null("TierTag") as Label
				var chk := box.get_node_or_null("Check") as TextureRect
				if c_lbl: c_lbl.visible = false
				if t_lbl: t_lbl.visible = false
				if chk: chk.visible = true
			AudioManager.play_sfx("goal_done")
		elif box:
			var c_lbl := box.get_node_or_null("Count") as Label
			if c_lbl:
				c_lbl.text = str(left)
		_check_victory()


func _detect_mobile_device() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("web"):
		var res = JavaScriptBridge.eval("(window.matchMedia && window.matchMedia('(pointer: coarse)').matches) || /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent || '')")
		return bool(res)
	return false


func _update_thermal_fps(active_play: bool) -> void:
	if not _is_mobile_perf:
		return
	var want_fps := 60 if active_play else 35
	if want_fps != _last_fps_cap:
		_last_fps_cap = want_fps
		Engine.max_fps = want_fps


func _init_particle_pool() -> void:
	_particle_quad = QuadMesh.new()
	_particle_quad.size = Vector2(0.36, 0.36)
	_particle_tex = load("res://assets/textures/vfx_m1_atlas.png") if ResourceLoader.exists("res://assets/textures/vfx_m1_atlas.png") else null
	_particle_pool.clear()
	for i in range(PARTICLE_POOL_SIZE):
		var mi := MeshInstance3D.new()
		mi.mesh = _particle_quad
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		_particles_root.add_child(mi)
		_particle_pool.append({
			"node": mi,
			"active": false,
			"t": 0.0,
			"dur": 0.36,
			"start": Vector3.ZERO,
			"target": Vector3.ZERO,
		})


func _get_pooled_particle_mat(tint: Color, variant: int) -> StandardMaterial3D:
	var key := "%s_%d" % [tint.to_html(false), variant % 4]
	var cached: StandardMaterial3D = _particle_mat_cache.get(key, null)
	if cached != null:
		return cached
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if _particle_tex:
		mat.albedo_texture = _particle_tex
		mat.uv1_scale = Vector3(0.5, 0.5, 1.0)
		mat.uv1_offset = Vector3(0.5 * (variant % 2), 0.5 * ((variant / 2) % 2), 0.0)
	_particle_mat_cache[key] = mat
	return mat


func _step_particle_pool(delta: float) -> void:
	for entry in _particle_pool:
		if not entry["active"]:
			continue
		var t: float = float(entry["t"]) + delta
		var dur: float = float(entry["dur"])
		var mi: MeshInstance3D = entry["node"]
		if t >= dur:
			entry["active"] = false
			mi.visible = false
		else:
			entry["t"] = t
			var p := t / dur
			var ease_out := 1.0 - (1.0 - p) * (1.0 - p)
			mi.position = (entry["start"] as Vector3).lerp(entry["target"] as Vector3, ease_out)
			var sc := maxf(0.01, 1.0 - p)
			mi.scale = Vector3(sc, sc, sc)


func _spawn_pop_particles(pos: Vector3, tint: Color, count: int) -> void:
	if _particle_pool.is_empty():
		return
	# Throttle waterfall bursts (< 65ms between swallows) to 3-4 crisp pooled particles -> zero CPU/GC spikes!
	var now_ms := Time.get_ticks_msec()
	var rapid := (now_ms - _last_particle_burst_ms) < 65
	_last_particle_burst_ms = now_ms
	var cap := (3 if rapid else 8) if _is_mobile_perf else (5 if rapid else 14)
	var spawn_n := mini(count, cap)

	for i in range(spawn_n):
		var slot: Dictionary = _particle_pool[_particle_cursor]
		_particle_cursor = (_particle_cursor + 1) % PARTICLE_POOL_SIZE
		var mi: MeshInstance3D = slot["node"]
		mi.material_override = _get_pooled_particle_mat(tint, i)
		mi.position = pos
		mi.scale = Vector3.ONE
		mi.visible = true
		var ang := randf() * TAU
		slot["active"] = true
		slot["t"] = 0.0
		slot["dur"] = 0.34
		slot["start"] = pos
		slot["target"] = pos + Vector3(cos(ang) * randf_range(0.65, 1.65), randf_range(0.75, 1.75), sin(ang) * randf_range(0.65, 1.65))


func _on_powerup_collected(kind: String, _pos: Vector3) -> void:
	if kind == "ice":
		_ice_freeze_timer = maxf(_ice_freeze_timer, 5.0)
		_frost_mat.set_shader_parameter("frost_amount", 1.0)
		AudioManager.play_sfx("ice")
		_spawn_popup(_hole.position, "+5s FREEZE!", Color("#0EA5E9"))
		_update_buff_banner()
	elif kind == "magnet":
		_hole.activate_magnet(5.5)
		_spawn_popup(_hole.position, "MAGNET!", Color("#EC36A0"))
		_update_buff_banner()


func _on_hole_level_changed(new_level: int, _radius: float) -> void:
	CandyUI.update_icon_pill(_hole_lvl_pill, "Lv.%d" % new_level, Color("#24C964"), Color("#12823D"), Color("#094A22"))
	var base_h := 18.5 if _is_mega_stage else 16.8
	_target_cam_height = base_h + float(new_level - 1) * (2.5 if _is_mega_stage else 2.2)
	if _playing:
		_camera_shake = maxf(_camera_shake, 6.0)
		_spawn_pop_particles(_hole.position + Vector3(0, 0.2, 0), Color("#FFD23F"), 22)
		_spawn_popup(_hole.position, "LV.%d!" % new_level, Color("#F59E0B"))


func _on_fever_changed(ratio: float, active: bool) -> void:
	_fever_bar.value = ratio * 100.0
	if active and _playing and ratio > 0.96:
		_spawn_popup(_hole.position, "FEVER!", Color("#EC36A0"))
		_helpers_ui.show_mechanic_tip("fever", "icon_fever", "FEVER SPEED + SIZE!", Color("#F7AD26"), Color("#B86D0A"), Color("#663804"))
	_update_buff_banner()


func _on_buff_changed(_buff_name: String, _remaining: float) -> void:
	_update_buff_banner()


func _update_buff_banner() -> void:
	var parts: Array[String] = []
	if _hole.sticky_timer > 0.0:
		parts.append("STICKY %.1fs" % _hole.sticky_timer)
	if _ice_freeze_timer > 0.0:
		parts.append("ICE %.1fs" % _ice_freeze_timer)
	if _hole.magnet_timer > 0.0:
		parts.append("MAGNET %.1fs" % _hole.magnet_timer)
	if _hole.is_fever_active():
		parts.append("FEVER %.1fs" % _hole.fever_timer)
	_buff_label.text = "  ·  ".join(parts)


func _compute_earned_stars() -> int:
	var ratio := _time_left / maxf(_base_duration, 1.0)
	if ratio >= 0.26 or _time_left >= 10.0:
		return 3
	if ratio >= 0.11 or _time_left >= 4.5:
		return 2
	return 1


func _populate_victory_stars(stars: int) -> void:
	for c in _modal_stars_box.get_children():
		c.queue_free()
	_modal_stars_box.visible = true
	for i in range(3):
		var earned := (i < stars)
		var sz := 104 if i == 1 else 86
		var tr := CandyUI.make_icon_rect(CandyUI.get_icon("icon_star" if earned else "icon_star_empty"), sz)
		tr.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
		_modal_stars_box.add_child(tr)
		if earned:
			tr.scale = Vector2(0.1, 0.1)
			var tw := create_tween()
			tw.tween_interval(0.12 + float(i) * 0.16)
			tw.tween_callback(func(): AudioManager.play_sfx("star_pop", 1.0 + float(i) * 0.12))
			tw.tween_property(tr, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _populate_victory_rewards(res: Dictionary) -> void:
	for c in _modal_rewards_box.get_children():
		c.queue_free()
	_modal_rewards_box.visible = true

	var coins_gained := int(res.get("coins", 0))
	if coins_gained > 0:
		_modal_rewards_box.add_child(CandyUI.create_icon_pill("icon_coin", "+%d" % coins_gained, Color("#FF8A2B"), Color("#C2410C"), 26, 36, Color("#662004")))

	var shards_gained := int(res.get("shards", 0))
	if shards_gained > 0:
		_modal_rewards_box.add_child(CandyUI.create_icon_pill("icon_shard", "+%d" % shards_gained, Color("#A855F7"), Color("#6B21A8"), 26, 36, Color("#3B0764")))

	if bool(res.get("chest_ready", false)):
		_modal_rewards_box.add_child(CandyUI.create_icon_pill("icon_chest", "READY!", Color("#25CF65"), Color("#12853E"), 24, 36, Color("#0A4C22")))


func _check_victory() -> void:
	for k in _remaining_targets:
		if _remaining_targets[k] > 0:
			return
	_playing = false
	_hole.is_controllable = false
	_helpers_ui.hide_radars()
	PlatformBridge.notify_gameplay_stop()
	AudioManager.play_sfx("win")

	DDAController.record_level_win(_level_number, _used_rv_this_run, _attempts_this_level == 1)
	_attempts_this_level = 0
	var stars := _compute_earned_stars()
	var res := GameManager.record_level_clear(_level_number, stars, _is_mega_stage)
	var next_lv := GameManager.current_level
	var new_world := int(res.get("new_world", 0))

	if stars >= 3 or _is_mega_stage or new_world > 0:
		PlatformBridge.notify_happytime()

	AnalyticsManager.track("level_win", {
		"level": _level_number,
		"world": _world_id,
		"stars": stars,
		"time_left": snappedf(_time_left, 0.1),
		"used_rv": _used_rv_this_run,
		"coins": int(res.get("coins", 0)),
		"shards": int(res.get("shards", 0)),
		"streak": GameManager.win_streak,
	})

	_modal_targets_box.visible = false
	_populate_victory_stars(stars)
	_populate_victory_rewards(res)
	_helpers_ui.spawn_confetti(64 if (_is_mega_stage or new_world > 0) else 44)

	CandyUI.update_icon_pill(
		_overlay_badge,
		"NEW WORLD!" if new_world > 0 else ("MEGA CLEAR!" if _is_mega_stage else "CLEAR!"),
		Color("#F7AD26") if new_world > 0 else Color("#25CF65"),
		Color("#B86D0A") if new_world > 0 else Color("#12853E"),
		Color("#663804") if new_world > 0 else Color("#0A4C22"),
		"icon_crown" if (_is_mega_stage or new_world > 0) else "icon_check"
	)
	if _level_number == GameManager.MAX_LEVEL:
		_overlay_title.text = "ALL 5 WORLDS!"
	elif new_world > 0:
		_overlay_title.text = "WORLD %d UNLOCKED!" % new_world
	else:
		_overlay_title.text = "LV.%d CLEAR!" % _level_number
	_overlay_desc.text = "%.1fs left  ·  Streak %d" % [_time_left, GameManager.win_streak]

	_rebind_button(_btn_primary, "icon_play", "NEXT  LV.%d" % next_lv, Color("#25CF65"), Color("#12853E"), Color("#0A4C22"), "", func():
		AudioManager.play_sfx("ui_click")
		AdManager.show_interstitial("level_complete", _level_number)
		_load_level(next_lv, true)
	)
	_btn_secondary.visible = true
	_rebind_button(_btn_secondary, "icon_restart", "REPLAY", Color("#38BDF8"), Color("#0284C7"), Color("#0A4266"), "", func():
		AudioManager.play_sfx("ui_click")
		_load_level(_level_number, false)
	)
	_animate_modal_open()


func _on_level_timeout() -> void:
	_playing = false
	_hole.is_controllable = false
	_helpers_ui.hide_radars()
	PlatformBridge.notify_gameplay_stop()
	AudioManager.play_sfx("fail")

	var rem_total := 0
	for k in _remaining_targets:
		rem_total += maxi(0, int(_remaining_targets[k]))

	_modal_stars_box.visible = false
	_modal_rewards_box.visible = false
	_modal_targets_box.visible = true
	_populate_modal_targets(_remaining_targets)
	CandyUI.update_icon_pill(_overlay_badge, "TIME UP!", Color("#F43F5E"), Color("#9F1239"), Color("#580A20"), "icon_timer")
	_overlay_title.text = "%d LEFT!" % rem_total
	if GameManager.win_streak >= 2:
		_overlay_desc.text = "Save Streak %d!  +15s · Clear Hazards · +20%% Size" % GameManager.win_streak
	else:
		_overlay_desc.text = "+15s  ·  Clear Hazards  ·  +20% Size"

	AdManager.note_rv_offer("fail_rescue", _level_number)
	_rebind_button(_btn_primary, "icon_ad", "+15s RESCUE!", Color("#25CF65"), Color("#12853E"), Color("#0A4C22"), "icon_timer", func():
		AudioManager.play_sfx("ui_click")
		AdManager.show_rewarded("fail_rescue", _level_number)
	)
	_btn_secondary.visible = true
	_rebind_button(_btn_secondary, "icon_restart", "RETRY", Color("#94A3B8"), Color("#475569"), Color("#1E293B"), "", func():
		AudioManager.play_sfx("ui_click")
		var lost_streak := GameManager.win_streak
		AnalyticsManager.track("level_fail", {
			"level": _level_number,
			"world": _world_id,
			"rem_targets": rem_total,
			"attempt": _attempts_this_level,
			"used_rv": _used_rv_this_run,
			"streak_lost": lost_streak,
		})
		DDAController.record_level_fail(_level_number, _used_rv_this_run)
		GameManager.win_streak = 0
		GameManager.streak_chest_progress = 0
		GameManager.save_progress()
		_load_level(_level_number, false)
	)
	_animate_modal_open()


func _on_rewarded_completed(placement: String, success: bool) -> void:
	_refresh_booster_buttons()
	if not success:
		# CrazyGames Basic Launch / AdBlock compliance: never leave a Rewarded Ad button clickable without effect!
		# Switch modal ad buttons immediately to Coin alternative or hide if insufficient coins.
		if placement == "pre_level_boost" and _overlay_panel and _overlay_panel.visible:
			if GameManager.coins >= 50:
				_rebind_button(_btn_secondary, "icon_coin", "50 · LV.2 + 7s", Color("#F7A526"), Color("#B8670A"), Color("#663404"), "icon_magnet", func():
					if GameManager.coins >= 50:
						GameManager.coins -= 50
						GameManager.save_progress()
						GameManager.economy_changed.emit()
						AudioManager.start_bgm()
						AudioManager.play_sfx("ui_click")
						_on_rewarded_completed("pre_level_boost", true)
				)
			else:
				_btn_secondary.visible = false
		elif placement == "fail_rescue" and _overlay_panel and _overlay_panel.visible:
			if GameManager.coins >= 60:
				_rebind_button(_btn_primary, "icon_coin", "60 · +15s RESCUE!", Color("#25CF65"), Color("#12853E"), Color("#0A4C22"), "icon_timer", func():
					if GameManager.coins >= 60:
						GameManager.coins -= 60
						GameManager.save_progress()
						GameManager.economy_changed.emit()
						AudioManager.play_sfx("ui_click")
						_on_rewarded_completed("fail_rescue", true)
				)
			else:
				_btn_primary.visible = false
		return
	_used_rv_this_run = true
	match placement:
		"fail_rescue":
			_time_left += 15.0
			_last_tick_sec = 6
			for tr in _traps:
				if is_instance_valid(tr):
					_spawn_pop_particles(tr.position + Vector3(0, 0.3, 0), tr.trap_color, 12)
					tr.pop_and_clear()
			_traps.clear()
			for bm in _bombs:
				if is_instance_valid(bm):
					_spawn_pop_particles(bm.position + Vector3(0, 0.3, 0), Color("#FACC15"), 12)
					bm.pop_and_clear()
			_bombs.clear()
			_hole.apply_rv_rescue_boost()
			AudioManager.play_sfx("rv_blast")
			_camera_shake = 7.0
			_spawn_popup(_hole.position, "+15s!", Color("#25CF65"))
			_begin_play()
		"pre_level_boost":
			var sp_arr: Array = _level_data.get("spawn", [0.0, 0.0])
			_hole.reset_for_level(2, Vector3(float(sp_arr[0]), 0.0, float(sp_arr[1])))
			_hole.activate_magnet(7.0)
			AudioManager.play_sfx("level_up")
			_spawn_popup(_hole.position, "LV.2 + MAGNET!", Color("#25CF65"))
			_begin_play()
		"in_level_ice":
			_ice_freeze_timer = maxf(_ice_freeze_timer, 6.0)
			_frost_mat.set_shader_parameter("frost_amount", 1.0)
			AudioManager.play_sfx("ice")
			_spawn_popup(_hole.position, "+6s FREEZE!", Color("#0EA5E9"))
			_update_buff_banner()
			AnalyticsManager.track("booster_use", {"kind": "ice", "source": "rv", "level": _level_number})
		"in_level_magnet":
			_hole.activate_magnet(7.0)
			_spawn_popup(_hole.position, "MAGNET 7s!", Color("#EC36A0"))
			_update_buff_banner()
			AnalyticsManager.track("booster_use", {"kind": "magnet", "source": "rv", "level": _level_number})


func _rebind_button(btn: Button, icon_name: String, txt: String, bg: Color, bevel: Color, outline: Color, extra_icon: String, cb: Callable) -> void:
	CandyUI.update_cta_button(btn, icon_name, txt, bg, bevel, outline, extra_icon)
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn["callable"])
	btn.pressed.connect(cb)
