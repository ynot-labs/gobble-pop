extends Control
class_name ConsentLegalUI

## Phase 2 Privacy / GDPR Consent Gate & In-App Legal Reader
## 100% self-contained in-game legal text (zero external outbound URLs -> YouTube Playables safe!).

signal consent_completed()

const PRIVACY_TEXT := """GOBBLE POP! — PRIVACY POLICY (Summary)

1. Game Progress & Cloud Save
We store your level progress, stars, unlocked skins, and audio preferences locally on your device and (when available) via your platform host's cloud storage (YouTube Playables / CrazyGames).

2. Gameplay Analytics (Optional)
With your consent, anonymous gameplay events (e.g. level clear rate, booster usage) help us tune level difficulty and fix bugs. No personally identifiable information is collected.

3. Advertising & Rewarded Bonuses
Rewarded videos are strictly opt-in. Forced interstitials only appear after early onboarding and can be disabled via Remove Ads. You may toggle Personalized Ads below at any time.

4. Your Rights (GDPR / CCPA / UK)
You can update or withdraw your consent at any time in Settings -> Privacy & Terms, or clear local data from your browser/device settings."""

const TERMS_TEXT := """GOBBLE POP! — TERMS OF SERVICE (Summary)

1. License
Gobble Pop! is provided for personal, non-commercial entertainment across supported web and mobile platforms.

2. Virtual Items
Coins, Skin Shards, Boosters, and Hole Skins are virtual game items with no real-world monetary value and cannot be transferred or exchanged for cash.

3. Fair Play & Platform Rules
When playing via YouTube Playables, CrazyGames, App Store, or Google Play, your platform's Terms of Service and refund policies also apply.

4. Support & Updates
Game balance, worlds, and features may be updated periodically to improve player experience."""

var _card: PanelContainer
var _consent_view: VBoxContainer
var _legal_view: VBoxContainer
var _legal_title: Label
var _legal_body: RichTextLabel
var _btn_analytics: Button
var _btn_ads: Button
var _draft_analytics: bool = true
var _draft_ads: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.10, 0.20, 0.68)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(840, 820)
	_card.add_theme_stylebox_override("panel", CandyUI.create_candy_card_style(Color("#22B8EE"), Color("#0B78A8")))
	center.add_child(_card)

	var root_v := VBoxContainer.new()
	root_v.alignment = BoxContainer.ALIGNMENT_CENTER
	root_v.add_theme_constant_override("separation", 18)
	_card.add_child(root_v)

	# === CONSENT VIEW ===
	_consent_view = VBoxContainer.new()
	_consent_view.alignment = BoxContainer.ALIGNMENT_CENTER
	_consent_view.add_theme_constant_override("separation", 20)
	root_v.add_child(_consent_view)

	var badge := CandyUI.create_icon_pill("icon_gear", "PRIVACY & CONSENT", Color("#22B8EE"), Color("#0B78A8"), 26, 36, Color("#0A4266"))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_consent_view.add_child(badge)

	var title := Label.new()
	title.text = "WELCOME TO GOBBLE POP!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(title, 40, Color("#FF6EB3"), Color("#2E1042"), 6)
	_consent_view.add_child(title)

	var desc := Label.new()
	desc.text = "We use local/cloud save to keep your progress.\nChoose your privacy preferences below (changeable anytime in Settings)."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 24)
	desc.add_theme_color_override("font_color", Color("#334155"))
	_consent_view.add_child(desc)

	var toggle_row := HBoxContainer.new()
	toggle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	toggle_row.add_theme_constant_override("separation", 20)
	_consent_view.add_child(toggle_row)

	_btn_analytics = CandyUI.create_cta_button("icon_check", "ANALYTICS: ON", Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"), Vector2(350, 86), 24)
	_btn_analytics.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_draft_analytics = not _draft_analytics
		_refresh_toggle_buttons()
	)
	toggle_row.add_child(_btn_analytics)

	_btn_ads = CandyUI.create_cta_button("icon_ad", "ADS PREFS: ON", Color("#A855F7"), Color("#6B21A8"), Color("#3B0764"), Vector2(350, 86), 24)
	_btn_ads.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_draft_ads = not _draft_ads
		_refresh_toggle_buttons()
	)
	toggle_row.add_child(_btn_ads)

	var btn_accept := CandyUI.create_cta_button("icon_play", "ACCEPT & PLAY", Color("#25CF65"), Color("#12853E"), Color("#0A4C22"), Vector2(620, 104), 34)
	btn_accept.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_accept.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		GameManager.set_consent(true, true)
		visible = false
		consent_completed.emit()
	)
	_consent_view.add_child(btn_accept)

	var btn_save := CandyUI.create_cta_button("icon_check", "SAVE MY CHOICES", Color("#F7A526"), Color("#B8670A"), Color("#663404"), Vector2(620, 88), 28)
	btn_save.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_save.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		GameManager.set_consent(_draft_analytics, _draft_ads)
		visible = false
		consent_completed.emit()
	)
	_consent_view.add_child(btn_save)

	# In-App Legal Reader links (zero external network calls!)
	var legal_row := HBoxContainer.new()
	legal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	legal_row.add_theme_constant_override("separation", 24)
	_consent_view.add_child(legal_row)

	var btn_priv := CandyUI.create_beta_chip("Privacy Policy", Color("#475569"))
	btn_priv.add_theme_font_size_override("font_size", 22)
	btn_priv.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_show_legal_doc("PRIVACY POLICY", PRIVACY_TEXT)
	)
	legal_row.add_child(btn_priv)

	var btn_tos := CandyUI.create_beta_chip("Terms of Service", Color("#475569"))
	btn_tos.add_theme_font_size_override("font_size", 22)
	btn_tos.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_show_legal_doc("TERMS OF SERVICE", TERMS_TEXT)
	)
	legal_row.add_child(btn_tos)

	# === IN-APP LEGAL READER VIEW ===
	_legal_view = VBoxContainer.new()
	_legal_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_legal_view.add_theme_constant_override("separation", 16)
	_legal_view.visible = false
	root_v.add_child(_legal_view)

	_legal_title = Label.new()
	_legal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	CandyUI.apply_outlined_label(_legal_title, 36, Color("#22B8EE"), Color("#0A4266"), 6)
	_legal_view.add_child(_legal_title)

	var reader_box := PanelContainer.new()
	reader_box.custom_minimum_size = Vector2(740, 520)
	reader_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reader_box.add_theme_stylebox_override("panel", CandyUI.make_pill_style(Color("#F8FAFC"), Color("#CBD5E1"), 22, 18, 16))
	_legal_view.add_child(reader_box)

	_legal_body = RichTextLabel.new()
	_legal_body.fit_content = false
	_legal_body.scroll_active = true
	_legal_body.add_theme_font_size_override("normal_font_size", 22)
	_legal_body.add_theme_color_override("default_color", Color("#1E293B"))
	reader_box.add_child(_legal_body)

	var btn_back := CandyUI.create_cta_button("icon_check", "BACK", Color("#22B8EE"), Color("#0B78A8"), Color("#0A4266"), Vector2(360, 86), 30)
	btn_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_back.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		_legal_view.visible = false
		_consent_view.visible = true
	)
	_legal_view.add_child(btn_back)


func open_consent() -> void:
	_draft_analytics = GameManager.consent_analytics
	_draft_ads = GameManager.consent_personalized_ads
	_consent_view.visible = true
	_legal_view.visible = false
	_refresh_toggle_buttons()
	visible = true
	_card.pivot_offset = _card.custom_minimum_size * 0.5
	_card.scale = Vector2(0.88, 0.88)
	var tw := create_tween()
	tw.tween_property(_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_legal_doc(doc_title: String, body: String) -> void:
	_legal_title.text = doc_title
	_legal_body.text = body
	_consent_view.visible = false
	_legal_view.visible = true


func _refresh_toggle_buttons() -> void:
	CandyUI.update_cta_button(
		_btn_analytics,
		"icon_check" if _draft_analytics else "icon_lock",
		"ANALYTICS: ON" if _draft_analytics else "ANALYTICS: OFF",
		Color("#22B8EE") if _draft_analytics else Color("#94A3B8"),
		Color("#0B78A8") if _draft_analytics else Color("#475569"),
		Color("#0A4266") if _draft_analytics else Color("#1E293B")
	)
	CandyUI.update_cta_button(
		_btn_ads,
		"icon_ad" if _draft_ads else "icon_lock",
		"ADS PREFS: ON" if _draft_ads else "ADS PREFS: OFF",
		Color("#A855F7") if _draft_ads else Color("#94A3B8"),
		Color("#6B21A8") if _draft_ads else Color("#475569"),
		Color("#3B0764") if _draft_ads else Color("#1E293B")
	)
