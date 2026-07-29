shader_type canvas_item;
render_mode unshaded;

uniform float glint_strength : hint_range(0.0, 1.0) = 0.75;
uniform vec4 glint_color : source_color = vec4(0.64, 0.88, 1.0, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float blue_mask = smoothstep(0.05, 0.30, base.b - max(base.r, base.g));
	float sweep_position = mix(-0.15, 1.25, fract(TIME * 0.13));
	float sweep = 1.0 - smoothstep(0.0, 0.055, abs((UV.x + UV.y * 0.35) - sweep_position));
	base.rgb += glint_color.rgb * blue_mask * sweep * glint_strength;
	COLOR = base;
}
