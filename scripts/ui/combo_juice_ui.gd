extends Control
class_name ComboJuiceUI

## V2.0 Live Combo Multiplier Badge + Sugar Rush Visual Excitement Feedback
## Turns the pentatonic ASMR swallow streak into punchy on-screen CrazyGames-grade juice!

var _combo_count: int = 0
var _combo_timer: float = 0.0
const COMBO_WINDOW: float = 1.45

var _badge_panel: PanelContainer
var _combo_num_lbl: Label
var _combo_tag_lbl: Label
var _pulse_tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_badge_panel = PanelContainer.new()
	_badge_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge_panel.offset_left = -310
	_badge_panel.offset_right = -26
	_badge_panel.offset_top = 148
	_badge_panel.offset_bottom = 264
	_badge_panel.visible = false
	add_child(_badge_panel)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_panel.add_child(v)

	_combo_num_lbl = Label.new()
	_combo_num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(_combo_num_lbl, 46, Color("#FFF480"), Color("#881337"), 8)
	v.add_child(_combo_num_lbl)

	_combo_tag_lbl = Label.new()
	_combo_tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(_combo_tag_lbl, 20, Color.WHITE, Color("#4C1D95"), 5)
	v.add_child(_combo_tag_lbl)


func reset_combo() -> void:
	_combo_count = 0
	_combo_timer = 0.0
	if _badge_panel:
		_badge_panel.visible = false


func register_swallow(tier: int) -> int:
	_combo_count += 1
	_combo_timer = COMBO_WINDOW

	if _combo_count >= 3:
		_badge_panel.visible = true
		_combo_num_lbl.text = "x%d" % _combo_count

		var bg := Color("#FF8A2B")
		var bevel := Color("#C2410C")
		var tag := "COMBO!"
		if _combo_count >= 18:
			bg = Color("#EC36A0")
			bevel = Color("#831843")
			tag = "MEGA FEAST!!"
		elif _combo_count >= 10:
			bg = Color("#A855F7")
			bevel = Color("#581C87")
			tag = "SUGAR RUSH!"
		elif _combo_count >= 6:
			bg = Color("#22B8EE")
			bevel = Color("#0B78A8")
			tag = "SWEET CHAIN!"

		_combo_tag_lbl.text = tag
		_badge_panel.add_theme_stylebox_override("panel", CandyUI.make_pill_style(bg, bevel, 24, 14, 6))
		_badge_panel.pivot_offset = _badge_panel.size * 0.5
		if _pulse_tween and _pulse_tween.is_valid():
			_pulse_tween.kill()
		var peak := 1.24 if tier >= 3 else 1.15
		_badge_panel.scale = Vector2(peak, peak)
		_badge_panel.rotation = deg_to_rad(randf_range(-4.5, 4.5))
		_pulse_tween = create_tween()
		_pulse_tween.set_parallel(true)
		_pulse_tween.tween_property(_badge_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pulse_tween.tween_property(_badge_panel, "rotation", 0.0, 0.22)
	return _combo_count


func _process(delta: float) -> void:
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			reset_combo()
		elif _badge_panel.visible and _combo_timer < 0.35:
			_badge_panel.modulate.a = clampf(_combo_timer / 0.35, 0.0, 1.0)
		elif _badge_panel.visible:
			_badge_panel.modulate.a = 1.0
