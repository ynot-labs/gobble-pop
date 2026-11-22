shader_type spatial;
render_mode cull_disabled;

uniform vec3 gum_color : source_color = vec3(0.847, 0.357, 0.533);
uniform vec3 highlight_color : source_color = vec3(0.972, 0.863, 0.902);
uniform vec3 pull_offset = vec3(0.0, 0.0, 0.0);
uniform float pull_strength = 0.0;

void vertex() {
	// Stretch outer vertices slightly toward the hole when stuck
	float dist_center = length(VERTEX.xz);
	float weight = clamp(dist_center * 0.85, 0.0, 1.0);
	VERTEX += pull_offset * weight * pull_strength;
	VERTEX.y += sin(TIME * 3.8 + dist_center * 5.0) * 0.012;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	float gloss = smoothstep(0.58, 0.95, dot(NORMAL, normalize(vec3(0.4, 0.85, 0.35))));
	vec3 col = mix(gum_color, highlight_color, fresnel * 0.28 + gloss * 0.30);
	ALBEDO = col;
	ROUGHNESS = 0.34;
	SPECULAR = 0.25;
}
