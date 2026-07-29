shader_type canvas_item;
render_mode unshaded;

uniform float wave_strength : hint_range(0.0, 1.0) = 0.85;

float soft_box(vec2 uv, vec2 center, vec2 half_size, float feather) {
	vec2 distance_to_edge = abs(uv - center) - half_size;
	float outside = length(max(distance_to_edge, vec2(0.0)));
	float inside = min(max(distance_to_edge.x, distance_to_edge.y), 0.0);
	return 1.0 - smoothstep(0.0, feather, outside + inside);
}

void fragment() {
	float left_flag = soft_box(UV, vec2(0.16, 0.445), vec2(0.145, 0.235), 0.02);
	float right_flag = soft_box(UV, vec2(0.84, 0.445), vec2(0.145, 0.235), 0.02);
	float loose_edge = smoothstep(0.245, 0.665, UV.y);

	float left_wave = sin(TIME * 1.15 + UV.y * 18.0) * 0.0050;
	left_wave += sin(TIME * 0.63 + UV.y * 31.0) * 0.0018;
	float right_wave = sin(TIME * 1.08 + 1.7 + UV.y * 19.0) * 0.0050;
	right_wave += sin(TIME * 0.69 + 0.8 + UV.y * 29.0) * 0.0018;

	vec2 sample_uv = UV;
	sample_uv.x -= (left_wave * left_flag + right_wave * right_flag) * loose_edge * wave_strength;
	COLOR = texture(TEXTURE, sample_uv);
}
