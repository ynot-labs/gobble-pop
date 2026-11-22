shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 gum_color : source_color = vec3(1.0, 0.36, 0.72);
uniform vec3 highlight_color : source_color = vec3(1.0, 0.88, 0.96);
uniform vec3 pull_offset = vec3(0.0, 0.0, 0.0);
uniform float pull_strength = 0.0;

void vertex() {
	float dist_center = length(VERTEX.xz);
	float weight = clamp(dist_center * 0.85, 0.0, 1.0);
	VERTEX += pull_offset * weight * pull_strength;
	VERTEX.y += sin(TIME * 4.2 + dist_center * 5.5) * 0.014;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.1);
	float gloss = smoothstep(0.55, 0.92, dot(NORMAL, normalize(vec3(0.35, 0.88, 0.32))));
	float soft_shade = 0.86 + 0.14 * clamp(dot(NORMAL, normalize(vec3(0.2, 0.9, 0.3))), 0.0, 1.0);
	vec3 col = mix(gum_color * soft_shade, highlight_color, fresnel * 0.35 + gloss * 0.58);
	ALBEDO = col;
}
