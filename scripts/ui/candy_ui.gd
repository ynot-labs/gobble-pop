extends Object
class_name CandyUI

## Commercial-Grade 3D Beveled Candy Toy UI Builder (Option 2: High-Energy Bright Candy Pop)
## Produces chunky glossy pills, 3D extruded arcade buttons with top glass specular highlight,
## crisp outlined typography, and soft drop shadows matching Royal Match / Hole Stars polish.


static func make_pill_style(bg: Color, bottom_bevel: Color, top_rim: Color = Color(1, 1, 1, 0.72), radius: int = 24, pad_h: int = 16, pad_v: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = bottom_bevel
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 7
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v + 2
	sb.shadow_color = Color(0.06, 0.14, 0.22, 0.24)
	sb.shadow_size = 7
	sb.shadow_offset = Vector2(0, 4)
	# Subtle crisp inner top sheen via anti-aliased edge
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.5
	if top_rim.a > 0.0:
		sb.border_blend = false
	return sb


static func make_button_style(bg: Color, bevel: Color, pressed: bool = false, radius: int = 26, pad_h: int = 20, pad_v: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg.lightened(0.06) if not pressed else bg.darkened(0.06)
	sb.border_color = bevel
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4 if pressed else 10
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v + (5 if pressed else 0)
	sb.content_margin_bottom = pad_v + (0 if pressed else 4)
	sb.shadow_color = Color(0.05, 0.10, 0.20, 0.22 if pressed else 0.30)
	sb.shadow_size = 5 if pressed else 10
	sb.shadow_offset = Vector2(0, 2 if pressed else 6)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.5
	return sb


static func apply_outlined_label(lbl: Label, font_sz: int, text_col: Color = Color.WHITE, outline_col: Color = Color("#16324F"), outline_sz: int = 6) -> void:
	lbl.add_theme_font_size_override("font_size", font_sz)
	lbl.add_theme_color_override("font_color", text_col)
	lbl.add_theme_color_override("font_outline_color", outline_col)
	lbl.add_theme_constant_override("outline_size", outline_sz)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.28))
	lbl.add_theme_constant_override("shadow_offset_y", 2)


static func create_candy_pill(txt: String, bg: Color, bevel: Color, font_sz: int = 24, outline_col: Color = Color("#13304A")) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_pill_style(bg, bevel, Color(1, 1, 1, 0.7), 24, 16, 7))
	panel.clip_contents = false

	var lbl := Label.new()
	lbl.name = "Text"
	lbl.text = txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apply_outlined_label(lbl, font_sz, Color.WHITE, outline_col, 4 if font_sz <= 22 else 5)
	panel.add_child(lbl)
	return panel


static func update_candy_pill(panel: PanelContainer, txt: String, bg: Color, bevel: Color, outline_col: Color = Color("#13304A")) -> void:
	panel.add_theme_stylebox_override("panel", make_pill_style(bg, bevel, Color(1, 1, 1, 0.7), 24, 16, 7))
	var lbl := panel.get_node_or_null("Text") as Label
	if lbl:
		lbl.text = txt
		lbl.add_theme_color_override("font_outline_color", outline_col)


static func create_candy_button(txt: String, bg: Color, bevel: Color, font_sz: int = 25, outline_col: Color = Color("#16324A"), min_sz: Vector2 = Vector2(0, 68)) -> Button:
	var b := Button.new()
	b.text = txt
	if min_sz.x > 0.0 or min_sz.y > 0.0:
		b.custom_minimum_size = min_sz
	b.add_theme_font_size_override("font_size", font_sz)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color("#FFFDF0"))
	b.add_theme_color_override("font_pressed_color", Color("#FFF4CC"))
	b.add_theme_color_override("font_outline_color", outline_col)
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_stylebox_override("normal", make_button_style(bg, bevel, false))
	b.add_theme_stylebox_override("hover", make_button_style(bg.lightened(0.05), bevel, false))
	b.add_theme_stylebox_override("pressed", make_button_style(bg, bevel, true))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Glossy curved top candy sheen bar inside the button
	var gloss := Panel.new()
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.set_anchors_preset(Control.PRESET_TOP_WIDE)
	gloss.offset_left = 14
	gloss.offset_right = -14
	gloss.offset_top = 6
	gloss.offset_bottom = 18
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(1.0, 1.0, 1.0, 0.34)
	gsb.set_corner_radius_all(9)
	gloss.add_theme_stylebox_override("panel", gsb)
	b.add_child(gloss)
	return b


static func style_candy_button(b: Button, txt: String, bg: Color, bevel: Color, outline_col: Color = Color("#16324A")) -> void:
	b.text = txt
	b.add_theme_color_override("font_outline_color", outline_col)
	b.add_theme_stylebox_override("normal", make_button_style(bg, bevel, false))
	b.add_theme_stylebox_override("hover", make_button_style(bg.lightened(0.05), bevel, false))
	b.add_theme_stylebox_override("pressed", make_button_style(bg, bevel, true))


static func create_beta_chip(txt: String, bg: Color, text_col: Color = Color.WHITE) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", text_col)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
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
	sb.set_content_margin_all(32)
	sb.shadow_color = Color(border_bevel.r * 0.4, border_bevel.g * 0.4, border_bevel.b * 0.4, 0.38)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 10)
	return sb
