extends Control
class_name JoystickOverlay

var hole: HoleController = null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if hole == null or not hole.joy_active or not hole.is_controllable:
		return
	var origin := hole.joy_origin
	var knob := origin + hole.joy_dir * 42.0
	var is_gum := hole.sticky_timer > 0.0
	var is_fever := hole.is_fever_active()

	draw_arc(origin, 54.0, 0.0, TAU, 36, Color(0.06, 0.09, 0.17, 0.25), 3.0, true)
	var knob_col := Color(1.0, 0.18, 0.58, 0.72) if is_gum else (Color(0.98, 0.45, 0.09, 0.75) if is_fever else Color(0.08, 0.72, 0.65, 0.62))
	draw_circle(knob, 20.0, knob_col)
	draw_arc(knob, 20.0, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.85), 2.5, true)
