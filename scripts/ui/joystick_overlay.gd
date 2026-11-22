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

	draw_arc(origin, 54.0, 0.0, TAU, 36, Color(0.24, 0.27, 0.32, 0.22), 2.5, true)
	var knob_col := Color(0.84, 0.36, 0.53, 0.68) if is_gum else (Color(0.86, 0.60, 0.30, 0.72) if is_fever else Color(0.24, 0.61, 0.52, 0.58))
	draw_circle(knob, 20.0, knob_col)
	draw_arc(knob, 20.0, 0.0, TAU, 24, Color(0.99, 0.98, 0.96, 0.80), 2.2, true)
