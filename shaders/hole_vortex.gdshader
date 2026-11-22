shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float xp_progress : hint_range(0.0, 1.0) = 0.0;
uniform float fever_mix : hint_range(0.0, 1.0) = 0.0;
uniform float gum_mix : hint_range(0.0, 1.0) = 0.0;
uniform float spin_phase = 0.0;
uniform float pulse_boost = 0.0;

// Option 2: Luminous Turquoise-Cyan Vortex + Gleaming Gold Outer Rim!
uniform vec3 rim_blue : source_color = vec3(0.05, 0.78, 0.90);
uniform vec3 rim_gold : source_color = vec3(1.00, 0.84, 0.22);
uniform vec3 rim_gold_shine : source_color = vec3(1.00, 0.97, 0.72);
uniform vec3 rim_gum : source_color = vec3(1.00, 0.30, 0.66);
uniform vec3 xp_yellow : source_color = vec3(1.00, 0.92, 0.24);
uniform vec3 vortex_deep : source_color = vec3(0.03, 0.28, 0.38);
uniform vec3 vortex_cyan : source_color = vec3(0.12, 0.88, 0.94);

vec3 candy_rainbow(float t) {
	return 0.58 + 0.40 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
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

	if (r < 0.73) {
		float swirl = sin(angle * 3.0 - r * 11.5 + spin_phase) * 0.5 + 0.5;
		float radial_fade = smoothstep(0.06, 0.73, r);
		vec3 base_vortex = mix(vortex_deep, vortex_cyan, swirl * radial_fade);
		// Luminous cyan-white spiral sheen matching Option 2!
		float sheen = smoothstep(0.80, 0.98, sin(angle * 3.0 - r * 8.0 + spin_phase)) * smoothstep(0.16, 0.66, r);
		base_vortex = mix(base_vortex, vec3(0.76, 0.99, 1.0), sheen * 0.55);

		vec3 fever_vortex = mix(vec3(0.18, 0.08, 0.36), candy_rainbow(norm_ang + spin_phase * 0.28 - r * 0.8), radial_fade * (0.55 + 0.45 * swirl));
		col = mix(base_vortex, fever_vortex, fever_mix);
		col = mix(col, mix(vec3(0.38, 0.08, 0.24), rim_gum, swirl * radial_fade), gum_mix * 0.55);
		col *= smoothstep(0.0, 0.32, r);
	} else if (r < 0.82) {
		// Gleaming beveled gold inner lip
		float spec = smoothstep(0.73, 0.78, r) * (1.0 - smoothstep(0.79, 0.82, r));
		vec3 gold_c = mix(rim_gold, rim_gold_shine, spec * 0.7);
		col = mix(gold_c, rim_gum, gum_mix * 0.55) + vec3(pulse_boost * 0.22);
	} else if (r < 0.95) {
		// Outer gleaming golden-cyan candy ring + XP fill arc
		vec3 base_rim = mix(mix(rim_gold, rim_blue, 0.25), candy_rainbow(norm_ang - spin_phase * 0.22), fever_mix);
		base_rim = mix(base_rim, rim_gum, gum_mix);
		float highlight = smoothstep(0.95, 0.85, r) * 0.20;
		col = base_rim + vec3(highlight);

		float in_arc = step(norm_ang, xp_progress);
		float xp_band = smoothstep(0.83, 0.85, r) * (1.0 - smoothstep(0.92, 0.94, r));
		col = mix(col, xp_yellow + vec3(0.14), in_arc * xp_band);
	} else {
		col = mix(rim_gold * 0.85, rim_gum, gum_mix * 0.4);
	}

	ALBEDO = col + vec3(pulse_boost * 0.18);
}
