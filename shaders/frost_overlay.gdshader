shader_type canvas_item;

uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float edge = max(abs(centered.x), abs(centered.y)) * 2.0;
	float vignette = smoothstep(0.62, 1.02, edge);
	float crystal = sin(UV.x * 48.0 + TIME * 1.5) * cos(UV.y * 48.0 - TIME * 1.2) * 0.08;
	float alpha = clamp((vignette + crystal * vignette) * frost_amount * 0.78, 0.0, 0.85);
	COLOR = vec4(0.62, 0.92, 1.0, alpha);
}
