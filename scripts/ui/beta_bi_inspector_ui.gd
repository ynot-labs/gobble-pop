extends Control
class_name BetaBIInspectorUI

## Beta-Only Live BI Funnel & Ad No-Fill QA Inspector
## Never instantiated in Release builds (zero overhead in production!).

var _summary_lbl: Label
var _log_rtl: RichTextLabel
var _btn_sim_fail: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()
	AnalyticsManager.event_logged.connect(func(_e):
		if visible:
			refresh()
	)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.06, 0.14, 0.72)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(920, 1180)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0F172A")
	sb.border_color = Color("#38BDF8")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(26)
	sb.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 12)
	vb.add_child(hdr)

	var title := Label.new()
	title.text = "BETA BI FUNNEL & SDK INSPECTOR"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	CandyUI.apply_outlined_label(title, 28, Color("#FDE047"), Color("#020617"), 4)
	hdr.add_child(title)

	var btn_close := CandyUI.create_beta_chip("CLOSE", Color("#DC2626"))
	btn_close.add_theme_font_size_override("font_size", 22)
	btn_close.pressed.connect(func(): visible = false)
	hdr.add_child(btn_close)

	_summary_lbl = Label.new()
	_summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_lbl.add_theme_font_size_override("font_size", 20)
	_summary_lbl.add_theme_color_override("font_color", Color("#7DD3FC"))
	vb.add_child(_summary_lbl)

	# QA Action Row: Simulate Ad No-Fill | Clear BI Log
	var qa_row := HBoxContainer.new()
	qa_row.add_theme_constant_override("separation", 12)
	vb.add_child(qa_row)

	_btn_sim_fail = CandyUI.create_beta_chip("SIMULATE AD NO-FILL: OFF", Color("#334155"))
	_btn_sim_fail.add_theme_font_size_override("font_size", 20)
	_btn_sim_fail.pressed.connect(func():
		AdManager.simulate_ad_fail = not AdManager.simulate_ad_fail
		refresh()
	)
	qa_row.add_child(_btn_sim_fail)

	var btn_clear := CandyUI.create_beta_chip("CLEAR LOG", Color("#475569"))
	btn_clear.add_theme_font_size_override("font_size", 20)
	btn_clear.pressed.connect(func():
		AnalyticsManager.clear_log()
		refresh()
	)
	qa_row.add_child(btn_clear)

	var log_bg := PanelContainer.new()
	log_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color("#020617")
	lsb.set_corner_radius_all(16)
	lsb.set_content_margin_all(14)
	log_bg.add_theme_stylebox_override("panel", lsb)
	vb.add_child(log_bg)

	_log_rtl = RichTextLabel.new()
	_log_rtl.scroll_active = true
	_log_rtl.add_theme_font_size_override("normal_font_size", 19)
	_log_rtl.add_theme_color_override("default_color", Color("#E2E8F0"))
	log_bg.add_child(_log_rtl)


func open_inspector() -> void:
	visible = true
	refresh()


func refresh() -> void:
	var c := AnalyticsManager.counters
	var m := PlatformBridge.get_safe_margins()
	_summary_lbl.text = (
		"Platform: %s  |  Consent: analytics=%s ads=%s  |  SafeArea: T=%.0f B=%.0f\n"
		+ "Starts: %d  |  Wins: %d  |  Fails: %d  |  RV Offer/OK/Fail: %d/%d/%d  |  Inter: %d  |  NoAds: %s"
	) % [
		PlatformBridge.get_platform_name(),
		str(GameManager.consent_analytics), str(GameManager.consent_personalized_ads),
		float(m["top"]), float(m["bottom"]),
		int(c["levels_started"]), int(c["levels_won"]), int(c["levels_failed"]),
		int(c["rv_offers"]), int(c["rv_completed"]), int(c["rv_failed"]),
		int(c["interstitials"]), str(GameManager.no_forced_ads),
	]
	_btn_sim_fail.text = "SIMULATE AD NO-FILL: ON" if AdManager.simulate_ad_fail else "SIMULATE AD NO-FILL: OFF"
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color("#DC2626") if AdManager.simulate_ad_fail else Color("#334155")
	ssb.set_corner_radius_all(10)
	ssb.set_content_margin_all(8)
	_btn_sim_fail.add_theme_stylebox_override("normal", ssb)

	var lines: Array[String] = []
	for e in AnalyticsManager.get_recent_events(24):
		lines.append("• [%s]  %s" % [str(e.get("event", "")), JSON.stringify(e.get("params", {}))])
	_log_rtl.text = "\n".join(lines) if lines.size() > 0 else "(No events logged yet — consent_analytics may be OFF)"
