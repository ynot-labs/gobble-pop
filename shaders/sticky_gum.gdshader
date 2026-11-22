shader_type spatial;
render_mode unshaded;

uniform vec3 gum_color : source_color = vec3(1.0, 0.22, 0.68);
uniform vec3 highlight_color : source_color = vec3(1.0, 0.76, 0.92);
uniform vec3 pull_offset = vec3(0.0, 0.0, 0.0);
uniform float pull_strength = 0.0;

void vertex() {
	// Stretch outer vertices slightly toward the hole when stuck
	float dist_center = length(VERTEX.xz);
	float weight = clamp(dist_center * 0.85, 0.0, 1.0);
	VERTEX += pull_offset * weight * pull_strength;
	VERTEX.y += sin(TIME * 4.5 + dist_center * 6.0) * 0.015;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float gloss = smoothstep(0.55, 0.95, dot(NORMAL, normalize(vec3(0.4, 0.85, 0.35))));
	vec3 col = mix(gum_color, highlight_color, fresnel * 0.45 + gloss * 0.55);
	ALBEDO = col;
}
