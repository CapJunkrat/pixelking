shader_type canvas_item;
render_mode unshaded;

uniform float moonlight_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec4 moonlight_color : source_color = vec4(0.28, 0.43, 0.82, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	// Keep the motion in the open archway above the menu. The long, quiet pulse
	// reads as changing moonlight without competing with button text.
	vec2 centered = (UV - vec2(0.5, 0.475)) / vec2(0.23, 0.20);
	float arch_mask = 1.0 - smoothstep(0.35, 1.0, length(centered));
	float breathing = 0.5 + 0.5 * sin(TIME * 0.58);
	float vertical_falloff = smoothstep(0.62, 0.38, UV.y);
	float light = arch_mask * vertical_falloff * breathing * moonlight_strength;

	base.rgb += moonlight_color.rgb * light;
	COLOR = base;
}
