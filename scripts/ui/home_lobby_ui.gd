extends Control
class_name HomeLobbyUI

## Commercial Home Lobby + World Progression Map + Hole Skin Shop (Phase 1)
## Floats over the live 3D arena so players see their world & equipped hole skin in real time.

signal play_level_requested(level_num: int)
signal settings_requested()
signal world_preview_requested(world_id: int)
signal confetti_requested(count: int)

const WORLD_THEMES := {
	1: {"title": "SUGAR RUSH BAKERY", "short": "W1", "icon": "item_w1_donut", "range": [1, 20],  "bg": Color("#FF6EB3"), "bevel": Color("#B01C65"), "out": Color("#630B38")},
	2: {"title": "GACHA TOYBOX",      "short": "W2", "icon": "item_w2_duck",  "range": [21, 30], "bg": Color("#F7AD26"), "bevel": Color("#B86D0A"), "out": Color("#663804")},
	3: {"title": "NEON BENTO STREET", "short": "W3", "icon": "item_w3_bento", "range": [31, 40], "bg": Color("#22B8EE"), "bevel": Color("#0B78A8"), "out": Color("#0A4266")},
	4: {"title": "ALCHEMIST DESK",    "short": "W4", "icon": "item_w4_potion","range": [41, 50], "bg": Color("#A855F7"), "bevel": Color("#6B21A8"), "out": Color("#3B0764")},
}

var _home_root: Control
var _star_pill: PanelContainer
var _coin_pill: PanelContainer
var _shard_pill: PanelContainer
var _world_badge: PanelContainer
var _play_btn: Button
var _streak_label: Label
var _chest_bar: ProgressBar
var _chest_btn: Button
var _stash_mag_lbl: Label
var _stash_ice_lbl: Label
var _shop_dot: Panel
var _toast_pill: PanelContainer
var _toast_tween: Tween

var _map_overlay: Control
var _map_world_tabs: Dictionary = {}
var _map_world_title: Label
var _map_world_stars: Label
var _map_grid: GridContainer
var _selected_map_world: int = 1

var _shop_overlay: Control
var _shop_coin_pill: PanelContainer
var _shop_shard_pill: PanelContainer
var _shop_grid: GridContainer

var _pulse_time: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_home_view()
	_build_map_overlay()
	_build_shop_overlay()
	GameManager.economy_changed.connect(refresh_all)
	GameManager.skin_equipped.connect(func(_id): _rebuild_shop_cards())
	refresh_all()


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse_time += delta
	if _play_btn and _home_root.visible:
		_play_btn.pivot_offset = _play_btn.size * 0.5
		var s := 1.0 + 0.028 * sin(_pulse_time * 3.4)
		_play_btn.scale = Vector2(s, s)
	if _chest_btn and _home_root.visible:
		_chest_btn.pivot_offset = _chest_btn.size * 0.5
		if GameManager.is_streak_chest_ready():
			var cs := 1.0 + 0.09 * absf(sin(_pulse_time * 5.2))
			_chest_btn.scale = Vector2(cs, cs)
			_chest_btn.rotation = sin(_pulse_time * 9.0) * 0.08
		else:
			_chest_btn.scale = Vector2.ONE
			_chest_btn.rotation = 0.0


func open_home() -> void:
	visible = true
	_home_root.visible = true
	_map_overlay.visible = false
	_shop_overlay.visible = false
	_selected_map_world = _world_for_level(GameManager.current_level)
	refresh_all()


func open_map(world_id: int = 0) -> void:
	visible = true
	_home_root.visible = false
	_shop_overlay.visible = false
	_map_overlay.visible = true
	_selected_map_world = world_id if world_id in [1, 2, 3, 4] else _world_for_level(GameManager.current_level)
	_refresh_map()


func open_shop() -> void:
	visible = true
	_home_root.visible = false
	_map_overlay.visible = false
	_shop_overlay.visible = true
	_rebuild_shop_cards()


func close_all() -> void:
	visible = false
	_map_overlay.visible = false
	_shop_overlay.visible = false


func refresh_all() -> void:
	if not _star_pill:
		return
	CandyUI.update_icon_pill(_star_pill, str(GameManager.get_total_stars()), Color("#F7AD26"), Color("#B86D0A"), Color("#663804"))
	CandyUI.update_icon_pill(_coin_pill, str(GameManager.coins), Color("#FF8A2B"), Color("#C2410C"), Color("#662004"))
	CandyUI.update_icon_pill(_shard_pill, str(GameManager.skin_shards), Color("#A855F7"), Color("#6B21A8"), Color("#3B0764"))

	var cur_lv := clampi(GameManager.current_level, 1, 50)
	var wid := _world_for_level(cur_lv)
	var wt: Dictionary = WORLD_THEMES[wid]
	CandyUI.update_icon_pill(_world_badge, "%s · %s" % [wt["short"], wt["title"]], wt["bg"], wt["bevel"], wt["out"], wt["icon"])

	var is_mega := cur_lv in [20, 30, 40, 50]
	CandyUI.update_cta_button(
		_play_btn,
		"icon_crown" if is_mega else "icon_play",
		"MEGA LV.%d" % cur_lv if is_mega else "PLAY  LV.%d" % cur_lv,
		Color("#EC36A0") if is_mega else Color("#25CF65"),
		Color("#9B1464") if is_mega else Color("#12853E"),
		Color("#5E093C") if is_mega else Color("#0A4C22")
	)

	var prog := mini(GameManager.streak_chest_progress, GameManager.STREAK_CHEST_STEP)
	_chest_bar.value = float(prog) / float(GameManager.STREAK_CHEST_STEP) * 100.0
	if GameManager.is_streak_chest_ready():
		_streak_label.text = "CHEST READY! TAP!"
		CandyUI.apply_outlined_label(_streak_label, 22, Color("#FFF3A1"), Color("#9B1464"), 4)
	else:
		_streak_label.text = "STREAK %d  ·  %d/%d" % [GameManager.win_streak, prog, GameManager.STREAK_CHEST_STEP]
		CandyUI.apply_outlined_label(_streak_label, 22, Color.WHITE, Color("#662004"), 4)

	_stash_mag_lbl.text = "x%d" % GameManager.inv_magnet
	_stash_ice_lbl.text = "x%d" % GameManager.inv_ice
	_shop_dot.visible = GameManager.has_affordable_unowned_skin()

	if _map_overlay.visible:
		_refresh_map()
	if _shop_overlay.visible:
		_rebuild_shop_cards()


func _world_for_level(lv: int) -> int:
	if lv <= 20: return 1
	if lv <= 30: return 2
	if lv <= 40: return 3
	return 4


func _build_home_view() -> void:
	_home_root = Control.new()
	_home_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_home_root)

	# Silky vertical gradient veils (zero hard horizontal seams; lets live 3D board & hole breathe!)
	var top_grad := Gradient.new()
	top_grad.colors = PackedColorArray([Color(0.04, 0.14, 0.24, 0.44), Color(0.04, 0.14, 0.24, 0.18), Color(0.04, 0.14, 0.24, 0.0)])
	top_grad.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	var top_tex := GradientTexture2D.new()
	top_tex.gradient = top_grad
	top_tex.fill_from = Vector2(0.5, 0.0)
	top_tex.fill_to = Vector2(0.5, 1.0)
	var top_veil := TextureRect.new()
	top_veil.texture = top_tex
	top_veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_veil.stretch_mode = TextureRect.STRETCH_SCALE
	top_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_veil.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_veil.offset_bottom = 520
	_home_root.add_child(top_veil)

	var bot_grad := Gradient.new()
	bot_grad.colors = PackedColorArray([Color(0.04, 0.14, 0.24, 0.0), Color(0.04, 0.14, 0.24, 0.24), Color(0.04, 0.14, 0.24, 0.52)])
	bot_grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var bot_tex := GradientTexture2D.new()
	bot_tex.gradient = bot_grad
	bot_tex.fill_from = Vector2(0.5, 0.0)
	bot_tex.fill_to = Vector2(0.5, 1.0)
	var bot_veil := TextureRect.new()
	bot_veil.texture = bot_tex
	bot_veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bot_veil.stretch_mode = TextureRect.STRETCH_SCALE
	bot_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_veil.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_veil.offset_top = -620
	_home_root.add_child(bot_veil)

	# === TOP CURRENCY & SETTINGS BAR ===
	var top_margin := MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_left", 20)
	top_margin.add_theme_constant_override("margin_right", 20)
	top_margin.add_theme_constant_override("margin_top", 120 if GameManager.is_beta_build() else 28)
	_home_root.add_child(top_margin)

	var top_v := VBoxContainer.new()
	top_v.add_theme_constant_override("separation", 18)
	top_margin.add_child(top_v)

	var res_row := HBoxContainer.new()
	res_row.alignment = BoxContainer.ALIGNMENT_CENTER
	res_row.add_theme_constant_override("separation", 14)
	top_v.add_child(res_row)

	_star_pill = CandyUI.create_icon_pill("icon_star", "0", Color("#F7AD26"), Color("#B86D0A"), 28, 42, Color("#663804"))
	res_row.add_child(_star_pill)

	_coin_pill = CandyUI.create_icon_pill("icon_coin", "150", Color("#FF8A2B"), Color("#C2410C"), 28, 42, Color("#662004"))
	res_row.add_child(_coin_pill)

	_shard_pill = CandyUI.create_icon_pill("icon_shard", "2", Color("#A855F7"), Color("#6B21A8"), 28, 42, Color("#3B0764"))
	res_row.add_child(_shard_pill)

	var btn_gear := CandyUI.create_square_icon_button("icon_gear", "", false, Color("#38BDF8"), Color("#0284C7"), Color("#0A4266"), 82, 46)
	btn_gear.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		settings_requested.emit()
	)
	res_row.add_child(btn_gear)

	# === HERO LOGO TITLE ===
	var logo_box := VBoxContainer.new()
	logo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_box.add_theme_constant_override("separation", 10)
	top_v.add_child(logo_box)

	var title_lbl := Label.new()
	title_lbl.text = "GOBBLE POP!"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(title_lbl, 82, Color("#FFF3A1"), Color("#C01E6D"), 14)
	logo_box.add_child(title_lbl)

	_world_badge = CandyUI.create_icon_pill("item_w1_donut", "W1 · SUGAR RUSH BAKERY", Color("#FF6EB3"), Color("#B01C65"), 22, 36, Color("#630B38"))
	_world_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_box.add_child(_world_badge)

	# === BOTTOM HERO CTA + STREAK CHEST + DOCK ===
	var bot_margin := MarginContainer.new()
	bot_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_margin.offset_top = -500
	bot_margin.add_theme_constant_override("margin_left", 28)
	bot_margin.add_theme_constant_override("margin_right", 28)
	bot_margin.add_theme_constant_override("margin_bottom", 34)
	_home_root.add_child(bot_margin)

	var bot_v := VBoxContainer.new()
	bot_v.alignment = BoxContainer.ALIGNMENT_END
	bot_v.add_theme_constant_override("separation", 20)
	bot_margin.add_child(bot_v)

	# Win-Streak Milestone Chest Strip
	var chest_card := PanelContainer.new()
	chest_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chest_card.custom_minimum_size = Vector2(680, 102)
	chest_card.add_theme_stylebox_override("panel", CandyUI.make_pill_style(Color(1.0, 0.98, 0.93, 0.96), Color("#E08E22"), 30, 20, 12))
	bot_v.add_child(chest_card)

	var ch_row := HBoxContainer.new()
	ch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ch_row.add_theme_constant_override("separation", 16)
	chest_card.add_child(ch_row)

	ch_row.add_child(CandyUI.make_icon_rect(CandyUI.get_icon("icon_flame"), 54))

	var ch_mid := VBoxContainer.new()
	ch_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch_mid.add_theme_constant_override("separation", 8)
	ch_row.add_child(ch_mid)

	_streak_label = Label.new()
	_streak_label.text = "STREAK 0 · 0/3"
	CandyUI.apply_outlined_label(_streak_label, 25, Color.WHITE, Color("#662004"), 4)
	ch_mid.add_child(_streak_label)

	_chest_bar = ProgressBar.new()
	_chest_bar.custom_minimum_size = Vector2(390, 26)
	_chest_bar.max_value = 100.0
	_chest_bar.show_percentage = false
	var cb_bg := StyleBoxFlat.new()
	cb_bg.bg_color = Color("#E2E8F0")
	cb_bg.border_color = Color("#CBD5E1")
	cb_bg.set_border_width_all(2)
	cb_bg.set_corner_radius_all(12)
	var cb_fill := StyleBoxFlat.new()
	cb_fill.bg_color = Color("#FF8A2B")
	cb_fill.set_corner_radius_all(10)
	_chest_bar.add_theme_stylebox_override("background", cb_bg)
	_chest_bar.add_theme_stylebox_override("fill", cb_fill)
	ch_mid.add_child(_chest_bar)

	_chest_btn = CandyUI.create_square_icon_button("icon_chest", "", false, Color("#F7AD26"), Color("#B86D0A"), Color("#663804"), 92, 60)
	_chest_btn.pressed.connect(_on_claim_chest_pressed)
	ch_row.add_child(_chest_btn)

	# Massive Glossy Green PLAY LV.X Hero Button (Mobile-sized!)
	_play_btn = CandyUI.create_cta_button("icon_play", "PLAY  LV.1", Color("#25CF65"), Color("#12853E"), Color("#0A4C22"), Vector2(660, 128), 44)
	_play_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_btn.pressed.connect(func():
		AudioManager.start_bgm()
		AudioManager.play_sfx("ui_click")
		play_level_requested.emit(GameManager.current_level)
	)
	bot_v.add_child(_play_btn)

	# Bottom Navigation Dock: MAP | FREE BOOSTERS STASH | SKINS (Chunky Mobile Sizing!)
	var dock := HBoxContainer.new()
	dock.alignment = BoxContainer.ALIGNMENT_CENTER
	dock.add_theme_constant_override("separation", 26)
	bot_v.add_child(dock)

	var btn_map := CandyUI.create_square_icon_button("icon_map", "MAP", false, Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"), 152, 74)
	btn_map.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		open_map()
	)
	dock.add_child(btn_map)

	# Booster Stash Capsule
	var stash := PanelContainer.new()
	stash.custom_minimum_size = Vector2(280, 136)
	stash.add_theme_stylebox_override("panel", CandyUI.make_pill_style(Color(1.0, 0.99, 0.95, 0.95), Color("#28B9E8"), 30, 18, 12))
	dock.add_child(stash)

	var stash_h := HBoxContainer.new()
	stash_h.alignment = BoxContainer.ALIGNMENT_CENTER
	stash_h.add_theme_constant_override("separation", 24)
	stash.add_child(stash_h)

	var mag_v := VBoxContainer.new()
	mag_v.alignment = BoxContainer.ALIGNMENT_CENTER
	mag_v.add_child(CandyUI.make_icon_rect(CandyUI.get_icon("icon_magnet"), 58))
	_stash_mag_lbl = Label.new()
	_stash_mag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(_stash_mag_lbl, 26, Color("#EC36A0"), Color("#4A072D"), 4)
	mag_v.add_child(_stash_mag_lbl)
	stash_h.add_child(mag_v)

	var ice_v := VBoxContainer.new()
	ice_v.alignment = BoxContainer.ALIGNMENT_CENTER
	ice_v.add_child(CandyUI.make_icon_rect(CandyUI.get_icon("icon_ice"), 58))
	_stash_ice_lbl = Label.new()
	_stash_ice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(_stash_ice_lbl, 26, Color("#0EA5E9"), Color("#083344"), 4)
	ice_v.add_child(_stash_ice_lbl)
	stash_h.add_child(ice_v)

	var btn_skins := CandyUI.create_square_icon_button("icon_shop", "SKINS", false, Color("#EC36A0"), Color("#9B1464"), Color("#5E093C"), 152, 74)
	btn_skins.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		open_shop()
	)
	dock.add_child(btn_skins)

	# Red/Gold notification dot on Skins button when player can afford a new skin!
	_shop_dot = Panel.new()
	_shop_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shop_dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_shop_dot.offset_left = -28
	_shop_dot.offset_right = 4
	_shop_dot.offset_top = -6
	_shop_dot.offset_bottom = 26
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color("#FACC15")
	dsb.border_color = Color("#DC2626")
	dsb.set_border_width_all(4)
	dsb.set_corner_radius_all(16)
	_shop_dot.add_theme_stylebox_override("panel", dsb)
	btn_skins.add_child(_shop_dot)

	# Toast pill for chest reward feedback
	_toast_pill = CandyUI.create_icon_pill("icon_chest", "+120 COINS!", Color("#25CF65"), Color("#12853E"), 24, 36, Color("#0A4C22"))
	_toast_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_pill.visible = false
	add_child(_toast_pill)


func _on_claim_chest_pressed() -> void:
	if not GameManager.is_streak_chest_ready():
		AudioManager.play_sfx("ui_click")
		var need := GameManager.STREAK_CHEST_STEP - GameManager.streak_chest_progress
		_show_toast("icon_chest", "WIN %d MORE FOR CHEST!" % need, Color("#F7AD26"), Color("#B86D0A"), Color("#663804"))
		return
	var r := GameManager.claim_streak_chest()
	if r.is_empty():
		return
	AudioManager.play_sfx("chest_open")
	confetti_requested.emit(52)
	_show_toast("icon_chest", "+%d COINS  +%d SHARDS  +1 MAG/ICE!" % [int(r["coins"]), int(r["shards"])], Color("#25CF65"), Color("#12853E"), Color("#0A4C22"))
	refresh_all()


func _show_toast(icon_name: String, txt: String, bg: Color, bevel: Color, outline: Color) -> void:
	CandyUI.update_icon_pill(_toast_pill, txt, bg, bevel, outline, icon_name)
	_toast_pill.visible = true
	_toast_pill.modulate.a = 1.0
	var vp := get_viewport_rect().size
	_toast_pill.reset_size()
	var w := maxf(_toast_pill.size.x, 340.0)
	_toast_pill.position = Vector2((vp.x - w) * 0.5, vp.y * 0.44)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.9)
	_toast_tween.tween_property(_toast_pill, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func(): _toast_pill.visible = false)


func _build_map_overlay() -> void:
	_map_overlay = Control.new()
	_map_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_overlay.visible = false
	add_child(_map_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.12, 0.22, 0.58)
	_map_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(920, 1280)
	card.add_theme_stylebox_override("panel", CandyUI.create_candy_card_style(Color("#22B8EE"), Color("#0B78A8")))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	card.add_child(vb)

	# Header Row
	var hdr := HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_theme_constant_override("separation", 14)
	vb.add_child(hdr)

	var badge := CandyUI.create_icon_pill("icon_map", "WORLD MAP", Color("#22B8EE"), Color("#0B78A8"), 28, 38, Color("#0A4266"))
	hdr.add_child(badge)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(spacer)

	var btn_back := CandyUI.create_square_icon_button("icon_home", "", false, Color("#EC36A0"), Color("#9B1464"), Color("#5E093C"), 78, 44)
	btn_back.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		open_home()
	)
	hdr.add_child(btn_back)

	# 4 World Tabs
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 12)
	vb.add_child(tabs)

	for wid in [1, 2, 3, 4]:
		var wt: Dictionary = WORLD_THEMES[wid]
		var tb := CandyUI.create_square_icon_button(wt["icon"], wt["short"], false, wt["bg"], wt["bevel"], wt["out"], 192, 58)
		tb.custom_minimum_size = Vector2(192, 114)
		var target_w: int = wid
		tb.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			_selected_map_world = target_w
			if GameManager.is_world_unlocked(target_w):
				world_preview_requested.emit(target_w)
			_refresh_map()
		)
		tabs.add_child(tb)
		_map_world_tabs[wid] = tb

	# Selected World Banner
	var w_info := HBoxContainer.new()
	w_info.alignment = BoxContainer.ALIGNMENT_CENTER
	w_info.add_theme_constant_override("separation", 18)
	vb.add_child(w_info)

	_map_world_title = Label.new()
	CandyUI.apply_outlined_label(_map_world_title, 34, Color("#FF6EB3"), Color("#2E1042"), 6)
	w_info.add_child(_map_world_title)

	_map_world_stars = Label.new()
	CandyUI.apply_outlined_label(_map_world_stars, 28, Color("#F7AD26"), Color("#663804"), 5)
	w_info.add_child(_map_world_stars)

	# Scrollable Level Grid
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid_center)

	_map_grid = GridContainer.new()
	_map_grid.columns = 4
	_map_grid.add_theme_constant_override("h_separation", 20)
	_map_grid.add_theme_constant_override("v_separation", 20)
	grid_center.add_child(_map_grid)


func _refresh_map() -> void:
	for wid_v in [1, 2, 3, 4]:
		var wid: int = int(wid_v)
		var wt: Dictionary = WORLD_THEMES[wid]
		var tb: Button = _map_world_tabs[wid]
		var unlocked: bool = GameManager.is_world_unlocked(wid)
		var active: bool = (wid == _selected_map_world)
		var bg: Color = wt["bg"] if unlocked else Color("#94A3B8")
		var bev: Color = wt["bevel"] if unlocked else Color("#475569")
		if active and unlocked:
			bg = bg.lightened(0.08)
		tb.add_theme_stylebox_override("normal", CandyUI.make_button_style(bg, bev, active, 24, 6, 6))
		var ic := tb.find_child("MainIcon", true, false) as TextureRect
		if ic:
			ic.texture = CandyUI.get_icon(wt["icon"] if unlocked else "icon_lock")

	var cur_wt: Dictionary = WORLD_THEMES[_selected_map_world]
	var stars_v := GameManager.get_world_stars(_selected_map_world)
	_map_world_title.text = "%s · %s" % [cur_wt["short"], cur_wt["title"]]
	_map_world_stars.text = "★ %d / %d" % [stars_v.x, stars_v.y]

	for c in _map_grid.get_children():
		c.queue_free()

	var rng: Array = cur_wt["range"]
	for lv in range(int(rng[0]), int(rng[1]) + 1):
		var unlocked := GameManager.is_level_unlocked(lv)
		var stars := GameManager.get_level_stars(lv)
		var is_cur := (lv == GameManager.current_level)
		var is_mega := lv in [20, 30, 40, 50]

		var tile := Button.new()
		tile.custom_minimum_size = Vector2(184, 152)
		var bg := Color("#CBD5E1")
		var bev := Color("#64748B")
		var out := Color("#334155")
		if unlocked:
			if is_mega:
				bg = Color("#F7AD26")
				bev = Color("#B86D0A")
				out = Color("#663804")
			elif is_cur:
				bg = Color("#EC36A0")
				bev = Color("#9B1464")
				out = Color("#5E093C")
			elif stars > 0:
				bg = Color("#25CF65")
				bev = Color("#12853E")
				out = Color("#0A4C22")
			else:
				bg = Color("#22B8EE")
				bev = Color("#0B78A8")
				out = Color("#0A4266")

		tile.add_theme_stylebox_override("normal", CandyUI.make_button_style(bg, bev, false, 26, 8, 8))
		tile.add_theme_stylebox_override("hover", CandyUI.make_button_style(bg.lightened(0.05), bev, false, 26, 8, 8))
		tile.add_theme_stylebox_override("pressed", CandyUI.make_button_style(bg, bev, true, 26, 8, 8))
		tile.add_theme_stylebox_override("disabled", CandyUI.make_button_style(Color("#D6DEE8"), Color("#94A3B8"), false, 26, 8, 8))
		tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tile.disabled = not unlocked

		var tv := VBoxContainer.new()
		tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_theme_constant_override("separation", 6)
		tile.add_child(tv)

		if not unlocked:
			tv.add_child(CandyUI.make_icon_rect(CandyUI.get_icon("icon_lock"), 52))
			var lv_lbl := Label.new()
			lv_lbl.text = "LV.%d" % lv
			lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			CandyUI.apply_outlined_label(lv_lbl, 22, Color("#F1F5F9"), out, 4)
			tv.add_child(lv_lbl)
		else:
			if is_mega:
				var crown_row := HBoxContainer.new()
				crown_row.alignment = BoxContainer.ALIGNMENT_CENTER
				crown_row.add_child(CandyUI.make_icon_rect(CandyUI.get_icon("icon_crown"), 34))
				var m_lbl := Label.new()
				m_lbl.text = "BOSS"
				CandyUI.apply_outlined_label(m_lbl, 18, Color("#FFF3A1"), out, 3)
				crown_row.add_child(m_lbl)
				tv.add_child(crown_row)

			var num_lbl := Label.new()
			num_lbl.text = str(lv)
			num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			CandyUI.apply_outlined_label(num_lbl, 42, Color.WHITE, out, 6)
			tv.add_child(num_lbl)

			var star_row := HBoxContainer.new()
			star_row.alignment = BoxContainer.ALIGNMENT_CENTER
			star_row.add_theme_constant_override("separation", 4)
			for si in range(3):
				star_row.add_child(CandyUI.make_icon_rect(CandyUI.get_icon("icon_star" if si < stars else "icon_star_empty"), 30))
			tv.add_child(star_row)

			var target_lv: int = lv
			tile.pressed.connect(func():
				AudioManager.start_bgm()
				AudioManager.play_sfx("ui_click")
				play_level_requested.emit(target_lv)
			)

		_map_grid.add_child(tile)


func _build_shop_overlay() -> void:
	_shop_overlay = Control.new()
	_shop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.visible = false
	add_child(_shop_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.12, 0.22, 0.56)
	_shop_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(900, 1180)
	card.add_theme_stylebox_override("panel", CandyUI.create_candy_card_style(Color("#EC36A0"), Color("#9B1464")))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	card.add_child(vb)

	# Header Row
	var hdr := HBoxContainer.new()
	hdr.alignment = BoxContainer.ALIGNMENT_CENTER
	hdr.add_theme_constant_override("separation", 12)
	vb.add_child(hdr)

	hdr.add_child(CandyUI.create_icon_pill("icon_shop", "HOLE SKINS", Color("#EC36A0"), Color("#9B1464"), 26, 38, Color("#5E093C")))

	_shop_coin_pill = CandyUI.create_icon_pill("icon_coin", "150", Color("#FF8A2B"), Color("#C2410C"), 24, 32, Color("#662004"))
	hdr.add_child(_shop_coin_pill)

	_shop_shard_pill = CandyUI.create_icon_pill("icon_shard", "2", Color("#A855F7"), Color("#6B21A8"), 24, 32, Color("#3B0764"))
	hdr.add_child(_shop_shard_pill)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(spacer)

	var btn_back := CandyUI.create_square_icon_button("icon_home", "", false, Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"), 76, 44)
	btn_back.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		open_home()
	)
	hdr.add_child(btn_back)

	# 2x3 Skin Cards Grid
	var grid_center := CenterContainer.new()
	grid_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(grid_center)

	_shop_grid = GridContainer.new()
	_shop_grid.columns = 2
	_shop_grid.add_theme_constant_override("h_separation", 26)
	_shop_grid.add_theme_constant_override("v_separation", 24)
	grid_center.add_child(_shop_grid)


func _rebuild_shop_cards() -> void:
	if not _shop_grid:
		return
	CandyUI.update_icon_pill(_shop_coin_pill, str(GameManager.coins), Color("#FF8A2B"), Color("#C2410C"), Color("#662004"))
	CandyUI.update_icon_pill(_shop_shard_pill, str(GameManager.skin_shards), Color("#A855F7"), Color("#6B21A8"), Color("#3B0764"))

	for c in _shop_grid.get_children():
		c.queue_free()

	for s in GameManager.SKIN_CATALOG:
		var sid := str(s["id"])
		var sname := str(s["name"])
		var owned := GameManager.is_skin_owned(sid)
		var equipped := (GameManager.equipped_skin == sid)
		var affordable := GameManager.can_afford_skin(sid)
		var cur := str(s["currency"])
		var cost := int(s["cost"])

		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(380, 290)
		var border := Color("#25CF65") if equipped else (Color("#22B8EE") if owned else (Color("#F7AD26") if affordable else Color("#CBD5E1")))
		slot.add_theme_stylebox_override("panel", CandyUI.make_pill_style(Color("#FFFDF9"), border, 28, 16, 14))

		var sv := VBoxContainer.new()
		sv.alignment = BoxContainer.ALIGNMENT_CENTER
		sv.add_theme_constant_override("separation", 10)
		slot.add_child(sv)

		var ic := CandyUI.make_icon_rect(CandyUI.get_icon(str(s["icon"])), 124)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sv.add_child(ic)

		var nl := Label.new()
		nl.text = sname
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		CandyUI.apply_outlined_label(nl, 26, Color("#334155"), Color.WHITE, 3)
		sv.add_child(nl)

		var act_btn: Button
		if equipped:
			act_btn = CandyUI.create_cta_button("icon_check", "EQUIPPED", Color("#25CF65"), Color("#12853E"), Color("#0A4C22"), Vector2(280, 66), 22)
		elif owned:
			act_btn = CandyUI.create_cta_button("icon_hole", "EQUIP", Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"), Vector2(280, 66), 24)
		else:
			var cur_icon := "icon_shard" if cur == "shards" else "icon_coin"
			var bg := Color("#A855F7") if (cur == "shards" and affordable) else (Color("#F7AD26") if affordable else Color("#94A3B8"))
			var bev := Color("#6B21A8") if (cur == "shards" and affordable) else (Color("#B86D0A") if affordable else Color("#475569"))
			var out := Color("#3B0764") if (cur == "shards" and affordable) else (Color("#663804") if affordable else Color("#1E293B"))
			act_btn = CandyUI.create_cta_button(cur_icon, str(cost), bg, bev, out, Vector2(280, 66), 26)
			act_btn.add_theme_stylebox_override("disabled", CandyUI.make_button_style(Color("#B8C4D4"), Color("#7B8BA1"), false, 24, 14, 8))
			act_btn.disabled = not affordable

		act_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var target_sid := sid
		var was_owned := owned
		act_btn.pressed.connect(func():
			if GameManager.buy_or_equip_skin(target_sid):
				if not was_owned:
					AudioManager.play_sfx("chest_open")
					confetti_requested.emit(42)
				else:
					AudioManager.play_sfx("star_pop")
				_rebuild_shop_cards()
		)
		sv.add_child(act_btn)
		_shop_grid.add_child(slot)
