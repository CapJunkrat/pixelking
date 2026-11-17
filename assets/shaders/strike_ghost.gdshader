shader_type canvas_item;
render_mode blend_add;

// White additive afterimage of a piece, used for motion trails during strikes.

uniform float alpha = 0.2;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(1.0, 1.0, 1.0, tex.a * alpha);
}
