shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 hole_world_pos = vec3(0.0, 0.0, 0.0);
uniform float hole_radius = 0.85;
uniform vec3 color_a : source_color = vec3(0.776, 0.859, 0.820);
uniform vec3 color_b : source_color = vec3(0.718, 0.812, 0.769);
uniform vec3 border_color : source_color = vec3(0.553, 0.659, 0.612);
uniform float tile_scale = 0.50;
uniform vec2 board_half_size = vec2(7.0, 10.5);
uniform bool use_albedo_tex = false;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
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

	// Subtle studio falloff toward table edges (cozy focus without glare)
	vec2 norm_p = world_pos.xz / max(board_half_size, vec2(1.0));
	float vig = clamp(dot(norm_p, norm_p), 0.0, 1.5);
	base_col *= (1.0 - vig * 0.07);

	// Grounded cozy table frame border
	vec2 edge_d = board_half_size - abs(world_pos.xz);
	float frame_mask = 1.0 - smoothstep(0.0, 0.58, min(edge_d.x, edge_d.y));
	base_col = mix(base_col, border_color, frame_mask * 0.82);

	// Soft contact shadow around hole rim
	float rim_ao = smoothstep(hole_radius * 0.97, hole_radius * 1.36, dist);
	base_col *= mix(0.74, 1.0, rim_ao);

	ALBEDO = base_col;
}
