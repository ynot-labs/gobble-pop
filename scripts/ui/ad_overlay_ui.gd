extends Control
class_name AdOverlayUI

## Commercial Ad Loading Spinner & No-Fill / IAP Toast Notice Layer (Phase 2)
## Prevents double-taps during ad requests and gives clear feedback on No-Fill / Offline / IAP.

var _loading_root: Control
var _spinner_icon: TextureRect
var _loading_label: Label
var _notice_pill: PanelContainer
var _notice_tween: Tween
var _spin_t: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	AdManager.ad_loading_changed.connect(_on_ad_loading_changed)
	AdManager.ad_notice.connect(_on_ad_notice)


func _process(delta: float) -> void:
	if _loading_root and _loading_root.visible:
		_spin_t += delta
		_spinner_icon.rotation = _spin_t * 5.2


func _build_ui() -> void:
	_loading_root = Control.new()
	_loading_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_root.visible = false
	add_child(_loading_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.10, 0.20, 0.62)
	_loading_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_root.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 240)
	card.add_theme_stylebox_override("panel", CandyUI.create_candy_card_style(Color("#F7AD26"), Color("#B86D0A")))
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	card.add_child(vb)

	_spinner_icon = CandyUI.make_icon_rect(CandyUI.get_icon("icon_hole"), 84)
	_spinner_icon.pivot_offset = Vector2(42, 42)
	_spinner_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(_spinner_icon)

	_loading_label = Label.new()
	_loading_label.text = "LOADING AD..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(_loading_label, 30, Color("#F7AD26"), Color("#5C2804"), 5)
	vb.add_child(_loading_label)

	# Non-blocking bottom-middle candy toast for No-Fill / IAP feedback
	_notice_pill = CandyUI.create_icon_pill("icon_ad", "AD UNAVAILABLE", Color("#F43F5E"), Color("#9F1239"), 24, 38, Color("#580A20"))
	_notice_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_pill.visible = false
	add_child(_notice_pill)


func _on_ad_loading_changed(is_loading: bool, message: String) -> void:
	_loading_root.visible = is_loading
	if is_loading and message != "":
		_loading_label.text = message


func _on_ad_notice(message: String, is_error: bool) -> void:
	var bg := Color("#F43F5E") if is_error else Color("#25CF65")
	var bev := Color("#9F1239") if is_error else Color("#12853E")
	var out := Color("#580A20") if is_error else Color("#0A4C22")
	var ic := "icon_ad" if is_error else "icon_check"
	CandyUI.update_icon_pill(_notice_pill, message, bg, bev, out, ic)
	_notice_pill.visible = true
	_notice_pill.modulate.a = 1.0
	var vp := get_viewport_rect().size
	_notice_pill.reset_size()
	var w := maxf(_notice_pill.size.x, 380.0)
	_notice_pill.position = Vector2((vp.x - w) * 0.5, vp.y * 0.74)
	if _notice_tween and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(2.2)
	_notice_tween.tween_property(_notice_pill, "modulate:a", 0.0, 0.35)
	_notice_tween.tween_callback(func(): _notice_pill.visible = false)


func show_qa_notice(message: String, is_error: bool = true) -> void:
	_on_ad_notice(message, is_error)
