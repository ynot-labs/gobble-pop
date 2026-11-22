shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float xp_progress : hint_range(0.0, 1.0) = 0.0;
uniform float fever_mix : hint_range(0.0, 1.0) = 0.0;
uniform float gum_mix : hint_range(0.0, 1.0) = 0.0;
uniform float spin_phase = 0.0;
uniform float pulse_boost = 0.0;

uniform vec3 rim_blue : source_color = vec3(0.08, 0.72, 0.65);
uniform vec3 rim_gold : source_color = vec3(0.98, 0.80, 0.22);
uniform vec3 rim_gum : source_color = vec3(1.0, 0.18, 0.58);
uniform vec3 xp_yellow : source_color = vec3(1.0, 0.90, 0.16);
uniform vec3 vortex_deep : source_color = vec3(0.02, 0.16, 0.18);
uniform vec3 vortex_cyan : source_color = vec3(0.14, 0.82, 0.76);

vec3 rainbow(float t) {
	return 0.55 + 0.45 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}

	float angle = atan(p.y, p.x);
	float norm_ang = fract((angle + 1.5707963) / 6.2831853);
	vec3 col = vec3(0.0);

	if (r < 0.72) {
		float swirl = sin(angle * 3.0 - r * 11.5 + spin_phase) * 0.5 + 0.5;
		float radial_fade = smoothstep(0.05, 0.72, r);
		vec3 base_vortex = mix(vortex_deep, vortex_cyan, swirl * radial_fade);
		// Golden spiral accent streaks
		float gold_arc = smoothstep(0.86, 0.98, sin(angle * 3.0 - r * 7.5 + spin_phase)) * smoothstep(0.18, 0.62, r);
		base_vortex = mix(base_vortex, rim_gold, gold_arc * 0.65);

		vec3 fever_vortex = mix(vec3(0.15, 0.04, 0.30), rainbow(norm_ang + spin_phase * 0.25 - r * 0.8), radial_fade * (0.55 + 0.45 * swirl));
		col = mix(base_vortex, fever_vortex, fever_mix);
		col = mix(col, mix(vec3(0.35, 0.04, 0.22), rim_gum, swirl * radial_fade), gum_mix * 0.55);
		col *= smoothstep(0.0, 0.36, r);
	} else if (r < 0.79) {
		col = mix(rim_gold, rim_gum, gum_mix * 0.6) + vec3(pulse_boost * 0.3);
	} else if (r < 0.95) {
		vec3 base_rim = mix(rim_blue, rainbow(norm_ang - spin_phase * 0.2), fever_mix);
		base_rim = mix(base_rim, rim_gum, gum_mix);
		float highlight = smoothstep(0.95, 0.84, r) * 0.18;
		col = base_rim + vec3(highlight);

		float in_arc = step(norm_ang, xp_progress);
		float xp_band = smoothstep(0.81, 0.83, r) * (1.0 - smoothstep(0.91, 0.93, r));
		col = mix(col, xp_yellow + vec3(0.12), in_arc * xp_band);
	} else {
		col = mix(rim_gold, rim_gum, gum_mix * 0.4);
	}

	ALBEDO = col + vec3(pulse_boost * 0.25);
}
