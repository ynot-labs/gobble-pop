shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float xp_progress : hint_range(0.0, 1.0) = 0.0;
uniform float fever_mix : hint_range(0.0, 1.0) = 0.0;
uniform float gum_mix : hint_range(0.0, 1.0) = 0.0;
uniform float spin_phase = 0.0;
uniform float pulse_boost = 0.0;

// Refined Brushed Champagne-Gold Bezel + Deep Luminous Turquoise Vortex (matches Option 2 concept!)
uniform vec3 gold_dark : source_color = vec3(0.46, 0.31, 0.12);
uniform vec3 gold_mid : source_color = vec3(0.84, 0.68, 0.34);
uniform vec3 gold_shine : source_color = vec3(1.00, 0.96, 0.80);
uniform vec3 rim_gum : source_color = vec3(0.95, 0.30, 0.64);
uniform vec3 xp_cyan : source_color = vec3(0.30, 0.96, 1.00);
uniform vec3 vortex_abyss : source_color = vec3(0.02, 0.16, 0.24);
uniform vec3 vortex_teal : source_color = vec3(0.07, 0.62, 0.72);
uniform vec3 vortex_aqua : source_color = vec3(0.45, 0.95, 0.98);

vec3 candy_rainbow(float t) {
	return 0.60 + 0.36 * cos(6.28318 * (t + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}

	float angle = atan(p.y, p.x);
	float norm_ang = fract((angle + 1.5707963) / 6.2831853);
	// Directional metallic light from upper-left (-0.65, -0.76) in UV space
	float dir_light = dot(normalize(p + vec2(0.0001)), normalize(vec2(-0.65, -0.76)));
	float sheen_band = pow(max(0.0, dir_light), 3.0);
	float secondary_glint = pow(max(0.0, -dir_light), 5.0) * 0.45;
	vec3 col = vec3(0.0);

	if (r < 0.79) {
		// Deep luminous turquoise-aqua swirling vortex with 3D recessed inner rim shadow!
		float swirl1 = sin(angle * 3.0 - r * 12.5 + spin_phase) * 0.5 + 0.5;
		float swirl2 = sin(angle * 2.0 - r * 7.5 + spin_phase * 1.35) * 0.5 + 0.5;
		float radial_fade = smoothstep(0.05, 0.76, r);

		vec3 base_vortex = mix(vortex_abyss, vortex_teal, radial_fade * (0.45 + 0.55 * swirl1));
		float ribbon = smoothstep(0.68, 0.96, swirl1 * 0.65 + swirl2 * 0.35) * smoothstep(0.16, 0.72, r);
		base_vortex = mix(base_vortex, vortex_aqua, ribbon * 0.72);

		// Deep abyss center
		base_vortex *= smoothstep(0.0, 0.28, r);

		// Recessed inner drop-shadow right under the gold lip (gives true 3D depth!)
		float inner_shadow = 1.0 - smoothstep(0.67, 0.79, r) * 0.52;
		base_vortex *= inner_shadow;

		vec3 fever_vortex = mix(vec3(0.14, 0.06, 0.28), candy_rainbow(norm_ang + spin_phase * 0.26 - r * 0.8), radial_fade * (0.55 + 0.45 * swirl1));
		col = mix(base_vortex, fever_vortex, fever_mix);
		col = mix(col, mix(vec3(0.32, 0.06, 0.20), rim_gum, swirl1 * radial_fade), gum_mix * 0.55);
	} else if (r < 0.83) {
		// Inner chamfer shadow wall transitioning from vortex into brushed gold lip
		float t = smoothstep(0.79, 0.83, r);
		vec3 chamfer = mix(gold_dark * 0.75, gold_mid, t * (0.65 + 0.35 * max(0.0, dir_light)));
		col = mix(chamfer, rim_gum * 0.85, gum_mix * 0.55);
	} else if (r < 0.96) {
		// Sleek 3D Brushed Champagne-Gold Beveled Ring!
		float ring_u = (r - 0.83) / 0.13; // 0 = inner edge, 1 = outer edge
		float dome = sin(ring_u * 3.14159); // smooth rounded bevel profile
		vec3 brushed = mix(gold_dark, gold_mid, 0.45 + 0.40 * dome + 0.25 * dir_light);
		brushed = mix(brushed, gold_shine, (sheen_band * 0.78 + secondary_glint) * (0.35 + 0.65 * dome));
		// Subtle metallic brushed grain
		brushed *= (0.97 + 0.03 * sin(r * 260.0));

		vec3 fever_rim = mix(brushed, candy_rainbow(norm_ang - spin_phase * 0.22), fever_mix * 0.65);
		col = mix(fever_rim, rim_gum, gum_mix * 0.82);

		// Crisp inlaid luminous XP progress arc right inside the sleek metallic bezel!
		float in_arc = step(norm_ang, xp_progress);
		float xp_band = smoothstep(0.865, 0.880, r) * (1.0 - smoothstep(0.915, 0.930, r));
		col = mix(col, mix(xp_cyan, vec3(1.0, 0.99, 0.90), 0.35), in_arc * xp_band * 0.92);
	} else {
		// Dark warm bronze contact outline grounding the bezel into the tabletop tile
		float edge_t = smoothstep(0.96, 1.0, r);
		col = mix(gold_dark * 0.85, gold_dark * 0.50, edge_t);
		col = mix(col, rim_gum * 0.65, gum_mix * 0.5);
	}

	ALBEDO = col + vec3(pulse_boost * 0.14);
}
