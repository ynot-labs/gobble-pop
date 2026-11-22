shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

uniform float shadow_alpha : hint_range(0.0, 0.6) = 0.38;

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float a = smoothstep(1.0, 0.18, r);
	ALBEDO = vec3(0.14, 0.13, 0.12);
	ALPHA = a * a * shadow_alpha;
}
