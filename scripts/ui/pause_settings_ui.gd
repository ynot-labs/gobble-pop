extends Control
class_name PauseSettingsUI

## Commercial Icon-First Pause & Settings Modal
## Works both in Home Lobby (Settings mode) and In-Game (Pause mode with Resume / Restart / Home).

signal resumed()
signal restarted()
signal go_home()
signal closed()

var _is_pause_mode: bool = false
var _dimmer: ColorRect
var _card: PanelContainer
var _badge: PanelContainer
var _title_lbl: Label
var _btn_bgm: Button
var _btn_sfx: Button
var _btn_haptics: Button
var _actions_box: VBoxContainer
var _version_lbl: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()


func _build_ui() -> void:
	_dimmer = ColorRect.new()
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0.05, 0.12, 0.22, 0.56)
	add_child(_dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(680, 520)
	_card.add_theme_stylebox_override("panel", CandyUI.create_candy_card_style(Color("#38BDF8"), Color("#0284C7")))
	center.add_child(_card)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 22)
	_card.add_child(vb)

	_badge = CandyUI.create_icon_pill("icon_pause", "PAUSED", Color("#22B8EE"), Color("#0B78A8"), 24, 34, Color("#0A4266"))
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(_badge)

	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(_title_lbl, 42, Color("#38BDF8"), Color("#0C2D48"), 6)
	vb.add_child(_title_lbl)

	# 3 Chunky Icon Toggles: BGM | SFX | HAPTICS
	var toggles := HBoxContainer.new()
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	toggles.add_theme_constant_override("separation", 26)
	vb.add_child(toggles)

	_btn_bgm = CandyUI.create_square_icon_button("icon_bgm", "BGM", false, Color("#A855F7"), Color("#6B21A8"), Color("#3B0764"), 118, 56)
	_btn_bgm.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		GameManager.set_bgm_enabled(not GameManager.bgm_enabled)
		_refresh_toggles()
	)
	toggles.add_child(_btn_bgm)

	_btn_sfx = CandyUI.create_square_icon_button("icon_sound_on", "SFX", false, Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"), 118, 56)
	_btn_sfx.pressed.connect(func():
		GameManager.set_sfx_enabled(not GameManager.sfx_enabled)
		if GameManager.sfx_enabled:
			AudioManager.play_sfx("ui_click")
		_refresh_toggles()
	)
	toggles.add_child(_btn_sfx)

	_btn_haptics = CandyUI.create_square_icon_button("icon_fever", "VIBE", false, Color("#F59E0B"), Color("#B45309"), Color("#5C2804"), 118, 56)
	_btn_haptics.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		GameManager.set_haptics_enabled(not GameManager.haptics_enabled)
		if GameManager.haptics_enabled:
			PlatformBridge.trigger_haptic(25)
		_refresh_toggles()
	)
	toggles.add_child(_btn_haptics)

	_actions_box = VBoxContainer.new()
	_actions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions_box.add_theme_constant_override("separation", 14)
	vb.add_child(_actions_box)

	_version_lbl = Label.new()
	_version_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_lbl.add_theme_font_size_override("font_size", 18)
	_version_lbl.add_theme_color_override("font_color", Color("#94A3B8"))
	vb.add_child(_version_lbl)


func open_pause(level_num: int) -> void:
	_is_pause_mode = true
	CandyUI.update_icon_pill(_badge, "LV.%d" % level_num, Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"), "icon_pause")
	_title_lbl.text = "PAUSED"
	_rebuild_actions()
	_refresh_toggles()
	_version_lbl.text = "Gobble Pop!  v%s  (%s)" % [GameManager.build_version, GameManager.build_channel.to_upper()]
	visible = true
	_animate_open()


func open_settings() -> void:
	_is_pause_mode = false
	CandyUI.update_icon_pill(_badge, "OPTIONS", Color("#A855F7"), Color("#6B21A8"), Color("#3B0764"), "icon_gear")
	_title_lbl.text = "SETTINGS"
	_rebuild_actions()
	_refresh_toggles()
	_version_lbl.text = "Gobble Pop!  v%s  (%s)" % [GameManager.build_version, GameManager.build_channel.to_upper()]
	visible = true
	_animate_open()


func close_modal() -> void:
	visible = false


func _animate_open() -> void:
	_card.pivot_offset = _card.custom_minimum_size * 0.5
	_card.scale = Vector2(0.86, 0.86)
	var tw := create_tween()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _rebuild_actions() -> void:
	for c in _actions_box.get_children():
		c.queue_free()

	if _is_pause_mode:
		var btn_resume := CandyUI.create_cta_button("icon_play", "RESUME", Color("#25CF65"), Color("#12853E"), Color("#0A4C22"), Vector2(500, 86), 30)
		btn_resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_resume.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			visible = false
			resumed.emit()
		)
		_actions_box.add_child(btn_resume)

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 18)
		_actions_box.add_child(row)

		var btn_restart := CandyUI.create_cta_button("icon_restart", "RETRY", Color("#F7A526"), Color("#B8670A"), Color("#663404"), Vector2(240, 78), 24)
		btn_restart.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			visible = false
			restarted.emit()
		)
		row.add_child(btn_restart)

		var btn_home := CandyUI.create_cta_button("icon_home", "HOME", Color("#EC36A0"), Color("#9B1464"), Color("#5E093C"), Vector2(240, 78), 24)
		btn_home.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			visible = false
			go_home.emit()
		)
		row.add_child(btn_home)
	else:
		var btn_done := CandyUI.create_cta_button("icon_check", "DONE", Color("#25CF65"), Color("#12853E"), Color("#0A4C22"), Vector2(460, 84), 30)
		btn_done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn_done.pressed.connect(func():
			AudioManager.play_sfx("ui_click")
			visible = false
			closed.emit()
		)
		_actions_box.add_child(btn_done)


func _refresh_toggles() -> void:
	_style_toggle(_btn_bgm, GameManager.bgm_enabled, "icon_bgm", "BGM", Color("#A855F7"), Color("#6B21A8"), Color("#3B0764"))
	_style_toggle(_btn_sfx, GameManager.sfx_enabled, "icon_sound_on" if GameManager.sfx_enabled else "icon_sound_off", "SFX", Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"))
	_style_toggle(_btn_haptics, GameManager.haptics_enabled, "icon_fever", "VIBE", Color("#F59E0B"), Color("#B45309"), Color("#5C2804"))


func _style_toggle(btn: Button, is_on: bool, icon_name: String, label_txt: String, bg: Color, bevel: Color, outline: Color) -> void:
	var use_bg := bg if is_on else Color("#94A3B8")
	var use_bevel := bevel if is_on else Color("#475569")
	var use_out := outline if is_on else Color("#1E293B")
	btn.add_theme_stylebox_override("normal", CandyUI.make_button_style(use_bg, use_bevel, false, 28, 6, 6))
	btn.add_theme_stylebox_override("hover", CandyUI.make_button_style(use_bg.lightened(0.05), use_bevel, false, 28, 6, 6))
	btn.add_theme_stylebox_override("pressed", CandyUI.make_button_style(use_bg, use_bevel, true, 28, 6, 6))
	var ic := btn.find_child("MainIcon", true, false) as TextureRect
	if ic:
		ic.texture = CandyUI.get_icon(icon_name)
		ic.modulate = Color.WHITE if is_on else Color(0.85, 0.88, 0.92, 0.72)
	var sub := btn.find_child("SubLabel", true, false) as Label
	if sub:
		sub.text = "%s %s" % [label_txt, "ON" if is_on else "OFF"]
		CandyUI.apply_outlined_label(sub, 16, Color.WHITE, use_out, 3)
