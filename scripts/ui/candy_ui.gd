extends Object
class_name CandyUI

## Commercial-Grade Icon-First 3D Beveled Candy UI Library (Option 2: High-Energy Bright Candy Pop)
## Designed for shippable App Store / YouTube Playables polish: minimal text, rich 3D icons,
## chunky extruded 3D buttons, crisp outlines, and zero demo feel.

const ICON_DIR := "res://assets/ui/icons/"

static var _icon_cache: Dictionary = {}

const ITEM_ICON_MAP := {
	"w1_sprinkle": "item_w1_strawberry",
	"w1_strawberry": "item_w1_strawberry",
	"w1_gummy_bear": "item_w1_strawberry",
	"w1_macaron": "item_w1_macaron",
	"w1_boba_tea": "item_w1_boba_tea",
	"w1_donut": "item_w1_donut",
	"w1_cake": "item_w1_pancakes",
	"w1_grand_cake": "item_w1_cake",
	"w2_block": "item_w2_duck",
	"w2_duck": "item_w2_duck",
	"w2_figurine": "item_w2_figurine",
	"w2_arcade": "item_w2_arcade",
	"w2_unicorn": "item_w2_unicorn",
	"w2_golden_gacha": "item_w2_golden_gacha",
	"w3_sushi": "item_w3_sushi",
	"w3_takoyaki": "item_w3_sushi",
	"w3_ramen": "item_w3_ramen",
	"w3_big_ramen": "item_w3_burger",
	"w3_bento": "item_w3_bento",
	"w3_grand_bento": "item_w3_bento",
	"w4_d20": "item_w4_jewel",
	"w4_slime": "item_w4_jewel",
	"w4_potion": "item_w4_potion",
	"w4_spellbook": "item_w4_spellbook",
	"w4_cauldron": "item_w4_cauldron",
	"w4_grand_cauldron": "item_w4_cauldron",
	"w5_pixel_coin": "item_w5_coin",
	"w5_cartridge": "item_w5_cartridge",
	"w5_gamepad": "item_w5_gamepad",
	"w5_handheld": "item_w5_handheld",
	"w5_vr_headset": "item_w5_vr",
	"w5_arcade_boss": "item_w5_arcade_boss",
}


static func get_icon(icon_name: String) -> Texture2D:
	if _icon_cache.has(icon_name):
		return _icon_cache[icon_name]
	var path := ICON_DIR + icon_name + ".png"
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		_icon_cache[icon_name] = tex
		return tex
	return null


static func get_item_icon(item_key: String) -> Texture2D:
	var mapped := str(ITEM_ICON_MAP.get(item_key, "item_w1_donut"))
	return get_icon(mapped)


static func make_icon_rect(tex: Texture2D, sz: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = Vector2(sz, sz)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func make_pill_style(bg: Color, bottom_bevel: Color, radius: int = 18, pad_h: int = 14, pad_v: int = 6) -> StyleBoxFlat:
	# V2.1 Status Readout Style: sleek, flat frosted-glass / soft-matte display (ZERO 3D button bevel!)
	# Visually distinct from clickable extruded 3D buttons so players immediately recognize info vs actions.
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = bottom_bevel
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.shadow_color = Color(0.04, 0.08, 0.16, 0.14)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.5
	return sb


static func make_hud_glass_dock_style(radius: int = 24, pad_h: int = 16, pad_v: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.14, 0.24, 0.72)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.24)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.shadow_color = Color(0.03, 0.07, 0.14, 0.22)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.5
	return sb


static func make_status_chip_style(accent: Color, radius: int = 16, pad_h: int = 12, pad_v: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.16, 0.26, 0.70)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.5
	return sb


static func make_button_style(bg: Color, bevel: Color, pressed: bool = false, radius: int = 22, pad_h: int = 18, pad_v: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg.lightened(0.04) if not pressed else bg.darkened(0.06)
	sb.border_color = bevel
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3 if pressed else 8
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v + (4 if pressed else 0)
	sb.content_margin_bottom = pad_v + (0 if pressed else 4)
	sb.shadow_color = Color(0.09, 0.13, 0.22, 0.18 if pressed else 0.26)
	sb.shadow_size = 5 if pressed else 10
	sb.shadow_offset = Vector2(0, 2 if pressed else 5)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.5
	return sb


static func apply_outlined_label(lbl: Label, font_sz: int, text_col: Color = Color.WHITE, outline_col: Color = Color("#1D2D44"), outline_sz: int = 4) -> void:
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", text_col)
	lbl.add_theme_color_override("font_outline_color", outline_col)
	lbl.add_theme_constant_override("outline_size", outline_sz)
	lbl.add_theme_color_override("font_shadow_color", Color(0.06, 0.10, 0.18, 0.22))
	lbl.add_theme_constant_override("shadow_offset_y", 2)


static func create_icon_pill(icon_name: String, txt: String, bg: Color, bevel: Color, font_sz: int = 24, icon_sz: int = 34, outline_col: Color = Color("#1D2D44")) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_status_chip_style(bg, 16, 11, 4))

	var hb := HBoxContainer.new()
	hb.name = "Box"
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	panel.add_child(hb)

	var tex := get_icon(icon_name)
	if tex:
		var tr := make_icon_rect(tex, icon_sz)
		tr.name = "Icon"
		hb.add_child(tr)

	var lbl := Label.new()
	lbl.name = "Text"
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_outlined_label(lbl, font_sz, Color.WHITE, Color(0.05, 0.10, 0.18, 0.85), 2)
	hb.add_child(lbl)
	return panel


static func create_target_chip(item_key: String, count: int, tier: int, bg: Color, bevel: Color, outline_col: Color) -> PanelContainer:
	# Clean flat matte-ivory target readout chip (visually distinct from clickable 3D extruded buttons!)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.99, 0.96, 0.95)
	sb.border_color = Color(bg.r, bg.g, bg.b, 0.78)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 11
	sb.content_margin_right = 11
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.name = "Box"
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 7)
	panel.add_child(hb)

	var tr := make_icon_rect(get_item_icon(item_key), 46)
	tr.name = "Icon"
	hb.add_child(tr)

	var lbl := Label.new()
	lbl.name = "Count"
	lbl.text = str(count)
	apply_outlined_label(lbl, 28, Color("#1E293B"), Color(1, 1, 1, 0.85), 2)
	hb.add_child(lbl)

	if tier >= 2:
		var lv_lbl := Label.new()
		lv_lbl.name = "TierTag"
		lv_lbl.text = "Lv.%d" % tier
		apply_outlined_label(lv_lbl, 15, bg.darkened(0.22), Color(1, 1, 1, 0.90), 2)
		hb.add_child(lv_lbl)

	var chk := make_icon_rect(get_icon("icon_check"), 36)
	chk.name = "Check"
	chk.visible = false
	hb.add_child(chk)
	return panel


static func add_keycap_badge(btn: Button, key_txt: String) -> PanelContainer:
	var cap := PanelContainer.new()
	cap.name = "KeycapBadge"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	cap.offset_left = -8
	cap.offset_top = -8
	cap.offset_right = 30
	cap.offset_bottom = 26
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFDF7")
	sb.border_color = Color("#94A3B8")
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	cap.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = key_txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color("#1E293B"))
	cap.add_child(lbl)
	btn.add_child(cap)
	return cap


static func update_icon_pill(panel: PanelContainer, txt: String, bg: Color, bevel: Color, outline_col: Color = Color("#13304A"), new_icon_name: String = "") -> void:
	panel.add_theme_stylebox_override("panel", make_status_chip_style(bg, 16, 11, 4))
	var hb := panel.get_node_or_null("Box")
	if hb:
		var lbl := hb.get_node_or_null("Text") as Label
		if lbl:
			lbl.text = txt
		if new_icon_name != "":
			var tr := hb.get_node_or_null("Icon") as TextureRect
			if tr:
				tr.texture = get_icon(new_icon_name)


static func create_square_icon_button(icon_name: String, badge_txt: String, show_ad: bool, bg: Color, bevel: Color, outline_col: Color, btn_size: int = 104, icon_sz: int = 58) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(btn_size, btn_size)
	b.add_theme_stylebox_override("normal", make_button_style(bg, bevel, false, 28, 6, 6))
	b.add_theme_stylebox_override("hover", make_button_style(bg.lightened(0.05), bevel, false, 28, 6, 6))
	b.add_theme_stylebox_override("pressed", make_button_style(bg, bevel, true, 28, 6, 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Top curved candy specular highlight
	var gloss := Panel.new()
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 12
	gloss.offset_right = -12
	gloss.offset_top = 6
	gloss.offset_bottom = 18
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(1.0, 1.0, 1.0, 0.34)
	gsb.set_corner_radius_all(8)
	gloss.add_theme_stylebox_override("panel", gsb)
	b.add_child(gloss)

	# Centered 3D glossy icon
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -14 if badge_txt != "" else -4
	b.add_child(center)

	var tr := make_icon_rect(get_icon(icon_name), icon_sz)
	tr.name = "MainIcon"
	center.add_child(tr)

	# Optional crisp tiny bottom counter (e.g. "7s" or "+6s")
	if badge_txt != "":
		var lbl := Label.new()
		lbl.name = "SubLabel"
		lbl.text = badge_txt
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		lbl.offset_top = -38
		lbl.offset_bottom = -8
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		apply_outlined_label(lbl, 23 if btn_size >= 120 else 20, Color.WHITE, outline_col, 4)
		b.add_child(lbl)

	# Optional compact golden video-ad icon badge in top-right corner
	var ad_sz := 38 if btn_size >= 120 else 30
	var ad_icon := make_icon_rect(get_icon("icon_ad"), ad_sz)
	ad_icon.name = "AdBadge"
	ad_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ad_icon.offset_left = -ad_sz + 2
	ad_icon.offset_right = 4
	ad_icon.offset_top = -8
	ad_icon.offset_bottom = ad_sz - 6
	ad_icon.visible = show_ad
	b.add_child(ad_icon)

	# Optional free-inventory count badge in top-right corner (hidden unless count > 0)
	var cnt_pill := PanelContainer.new()
	cnt_pill.name = "CountBadge"
	cnt_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cnt_pill.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cnt_pill.offset_left = -46 if btn_size >= 120 else -38
	cnt_pill.offset_right = 8
	cnt_pill.offset_top = -10
	cnt_pill.offset_bottom = 30 if btn_size >= 120 else 26
	cnt_pill.add_theme_stylebox_override("panel", make_pill_style(Color("#25CF65"), Color("#12853E"), 16, 8, 2))
	var cnt_lbl := Label.new()
	cnt_lbl.name = "CountText"
	cnt_lbl.text = "x1"
	cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	apply_outlined_label(cnt_lbl, 20 if btn_size >= 120 else 16, Color.WHITE, Color("#0A4C22"), 3)
	cnt_pill.add_child(cnt_lbl)
	cnt_pill.visible = false
	b.add_child(cnt_pill)

	return b


static func set_booster_button_stock(b: Button, stock_count: int) -> void:
	var ad_icon := b.get_node_or_null("AdBadge") as Control
	var cnt_pill := b.get_node_or_null("CountBadge") as PanelContainer
	if stock_count > 0:
		if ad_icon: ad_icon.visible = false
		if cnt_pill:
			cnt_pill.visible = true
			cnt_pill.add_theme_stylebox_override("panel", make_pill_style(Color("#25CF65"), Color("#12853E"), 16, 8, 2))
			var lbl := cnt_pill.get_node_or_null("CountText") as Label
			if lbl: lbl.text = "x%d" % stock_count
	elif is_instance_valid(AdManager) and not AdManager.reward_ads_available:
		# Coin fallback badge when ads are disabled (Basic Launch / AdBlock)
		if ad_icon: ad_icon.visible = false
		if cnt_pill:
			cnt_pill.visible = true
			cnt_pill.add_theme_stylebox_override("panel", make_pill_style(Color("#F7A526"), Color("#B8670A"), 16, 8, 2))
			var lbl := cnt_pill.get_node_or_null("CountText") as Label
			if lbl: lbl.text = "50c"
	else:
		if ad_icon: ad_icon.visible = true
		if cnt_pill: cnt_pill.visible = false


static func create_cta_button(icon_name: String, txt: String, bg: Color, bevel: Color, outline_col: Color, min_sz: Vector2 = Vector2(540, 88), font_sz: int = 30, extra_icon: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_sz
	b.add_theme_stylebox_override("normal", make_button_style(bg, bevel, false, 28, 18, 10))
	b.add_theme_stylebox_override("hover", make_button_style(bg.lightened(0.05), bevel, false, 28, 18, 10))
	b.add_theme_stylebox_override("pressed", make_button_style(bg, bevel, true, 28, 18, 10))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var gloss := Panel.new()
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 16
	gloss.offset_right = -16
	gloss.offset_top = 6
	gloss.offset_bottom = 18
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(1.0, 1.0, 1.0, 0.34)
	gsb.set_corner_radius_all(9)
	gloss.add_theme_stylebox_override("panel", gsb)
	b.add_child(gloss)

	var hb := HBoxContainer.new()
	hb.name = "Content"
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_bottom = -6
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	b.add_child(hb)

	if icon_name != "":
		var ic := make_icon_rect(get_icon(icon_name), 44)
		ic.name = "Icon1"
		hb.add_child(ic)

	if extra_icon != "":
		var ic2 := make_icon_rect(get_icon(extra_icon), 42)
		ic2.name = "Icon2"
		hb.add_child(ic2)

	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = txt
	apply_outlined_label(lbl, font_sz, Color.WHITE, outline_col, 5)
	hb.add_child(lbl)
	return b


static func update_cta_button(b: Button, icon_name: String, txt: String, bg: Color, bevel: Color, outline_col: Color, extra_icon: String = "") -> void:
	b.add_theme_stylebox_override("normal", make_button_style(bg, bevel, false, 30, 20, 12))
	b.add_theme_stylebox_override("hover", make_button_style(bg.lightened(0.05), bevel, false, 30, 20, 12))
	b.add_theme_stylebox_override("pressed", make_button_style(bg, bevel, true, 30, 20, 12))
	var hb := b.get_node_or_null("Content")
	if hb:
		for c in hb.get_children():
			c.queue_free()
		var ic_sz := 54 if b.custom_minimum_size.y >= 100 else 46
		var f_sz := 38 if b.custom_minimum_size.y >= 115 else (34 if b.custom_minimum_size.y >= 100 else 30)
		if icon_name != "":
			hb.add_child(make_icon_rect(get_icon(icon_name), ic_sz))
		if extra_icon != "":
			hb.add_child(make_icon_rect(get_icon(extra_icon), ic_sz - 2))
		var lbl := Label.new()
		lbl.text = txt
		apply_outlined_label(lbl, f_sz, Color.WHITE, outline_col, 6)
		hb.add_child(lbl)


static func create_beta_chip(txt: String, bg: Color, text_col: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func create_candy_card_style(border_col: Color = Color("#28B9E8"), border_bevel: Color = Color("#0F769E")) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#FFFDF7")
	sb.border_color = border_col
	sb.border_width_left = 7
	sb.border_width_right = 7
	sb.border_width_top = 7
	sb.border_width_bottom = 14
	sb.set_corner_radius_all(36)
	sb.set_content_margin_all(30)
	sb.shadow_color = Color(border_bevel.r * 0.4, border_bevel.g * 0.4, border_bevel.b * 0.4, 0.38)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 10)
	return sb
