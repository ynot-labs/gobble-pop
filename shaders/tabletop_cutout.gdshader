shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec3 hole_world_pos = vec3(0.0, 0.0, 0.0);
uniform float hole_radius = 0.85;
uniform vec3 color_a : source_color = vec3(0.62, 0.88, 0.78);
uniform vec3 color_b : source_color = vec3(0.95, 0.97, 0.93);
uniform vec3 border_color : source_color = vec3(0.463, 0.843, 0.745);
uniform float tile_scale = 0.52;
uniform vec2 board_half_size = vec2(7.0, 10.5);
uniform float corner_radius = 1.65;
uniform bool use_albedo_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float corner_d = sd_round_box(world_pos.xz, board_half_size, corner_radius);
	if (corner_d > 0.0) {
		discard;
	}

	float dist = length(world_pos.xz - hole_world_pos.xz);
	if (dist < hole_radius * 0.97) {
		discard;
	}

	vec3 base_col;
	if (use_albedo_tex) {
		base_col = texture(albedo_tex, world_pos.xz * tile_scale * 0.25).rgb;
	} else {
		vec2 cell = floor(world_pos.xz * tile_scale);
		float checker = mod(cell.x + cell.y, 2.0);
		float vein = sin(world_pos.x * 1.9 + sin(world_pos.z * 1.3)) * 0.012;
		base_col = mix(color_a, color_b, checker) + vec3(vein);
	}

	// Keep rich creamy mint-and-marble contrast without washing out under studio lights!
	vec2 norm_p = world_pos.xz / max(board_half_size, vec2(1.0));
	float vig = clamp(dot(norm_p, norm_p), 0.0, 1.5);
	base_col *= (0.82 - vig * 0.07);

	// Crisp bevel lip right inside the rounded wooden island frame
	float rim_mask = smoothstep(-0.62, -0.05, corner_d);
	base_col = mix(base_col, mix(border_color, vec3(0.95, 0.99, 0.96), 0.20), rim_mask * 0.65);

	// Clean grounded contact shadow around hole rim
	float rim_ao = smoothstep(hole_radius * 0.97, hole_radius * 1.44, dist);
	base_col *= mix(0.62, 1.0, rim_ao);

	ALBEDO = base_col;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
	SPECULAR = 0.08;
	EMISSION = vec3(0.0);
}
