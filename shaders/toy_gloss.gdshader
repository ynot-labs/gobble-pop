shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool use_albedo_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_vertex_color = false;
uniform float roughness_val : hint_range(0.05, 0.95) = 0.34;
uniform float rim_strength : hint_range(0.0, 1.2) = 0.28;
uniform float sat_boost : hint_range(0.8, 1.6) = 1.18;
uniform vec3 rim_color : source_color = vec3(1.0, 0.97, 0.92);
uniform float wobble_time = 0.0;
uniform float wobble_amp = 0.0;

void vertex() {
	if (wobble_amp > 0.001) {
		float h = max(VERTEX.y, 0.0);
		VERTEX.x += sin(wobble_time * 18.0 + h * 4.0) * wobble_amp * h;
		VERTEX.z += cos(wobble_time * 15.0 + h * 4.0) * wobble_amp * h;
	}
}

void fragment() {
	vec3 col = albedo_tint.rgb;
	if (use_albedo_tex) {
		col *= texture(albedo_tex, UV).rgb;
	}
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	// Cozy Low-Poly Toy Saturation Boost (makes Kenney palettes pop like Overcooked / Captain Toad!)
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = clamp(mix(vec3(luma), col, sat_boost), vec3(0.0), vec3(1.0));

	float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, 2.8);

	ALBEDO = col;
	ROUGHNESS = roughness_val;
	METALLIC = 0.02;
	SPECULAR = 0.42;
	EMISSION = col * 0.05 + rim_color * fresnel * rim_strength * 0.45;
}
