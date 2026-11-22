shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float xp_progress : hint_range(0.0, 1.0) = 0.0;
uniform float fever_mix : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_boost = 0.0;

uniform vec3 rim_blue : source_color = vec3(0.24, 0.72, 1.0);
uniform vec3 rim_gold : source_color = vec3(0.98, 0.80, 0.26);
uniform vec3 xp_yellow : source_color = vec3(1.0, 0.90, 0.16);
uniform vec3 vortex_deep : source_color = vec3(0.02, 0.09, 0.28);
uniform vec3 vortex_cyan : source_color = vec3(0.06, 0.68, 0.96);

vec3 rainbow(float t) {
	return 0.55 + 0.45 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}

	float angle = atan(p.y, p.x); // -PI..PI
	// Normalized clockwise angle starting at top (12 o'clock)
	float norm_ang = fract((angle + 1.5707963) / 6.2831853);

	vec3 col = vec3(0.0);

	if (r < 0.72) {
		// Swirling vortex core
		float swirl = sin(angle * 3.0 - r * 11.0 + TIME * 5.0) * 0.5 + 0.5;
		float radial_fade = smoothstep(0.05, 0.72, r);
		vec3 base_vortex = mix(vortex_deep, vortex_cyan, swirl * radial_fade);
		vec3 fever_vortex = mix(vec3(0.15, 0.04, 0.30), rainbow(norm_ang + TIME * 0.65 - r * 0.8), radial_fade * (0.55 + 0.45 * swirl));
		col = mix(base_vortex, fever_vortex, fever_mix);
		// Deep pit darkening at center
		col *= smoothstep(0.0, 0.38, r);
	} else if (r < 0.79) {
		// Inner gold trim ring
		col = mix(rim_gold, vec3(1.0, 0.96, 0.82), 0.35 + pulse_boost * 0.4);
	} else if (r < 0.95) {
		// Outer glossy rim with XP progress arc
		vec3 base_rim = mix(rim_blue, rainbow(norm_ang - TIME * 0.5), fever_mix);
		float highlight = smoothstep(0.95, 0.84, r) * 0.18;
		col = base_rim + vec3(highlight);

		// XP Yellow Progress Ring (fills clockwise)
		float in_arc = step(norm_ang, xp_progress);
		float xp_band = smoothstep(0.81, 0.83, r) * (1.0 - smoothstep(0.91, 0.93, r));
		col = mix(col, xp_yellow + vec3(0.12), in_arc * xp_band);
	} else {
		// Outer gold bevel lip
		col = rim_gold;
	}

	ALBEDO = col + vec3(pulse_boost * 0.25);
}
