shader_type canvas_item;

// A piece held in place by a gorgon: turns to grey stone from the feet up, then cracks.
// Coordinates follow strike_piece.gdshader (isotropic, measured in sprite heights).

uniform vec4 used = vec4(0.0, 0.0, 1.0, 1.0);
uniform float aspect = 1.0;
uniform float grid = 16.0;
uniform float progress = 1.0;
uniform float crack = 0.0;
uniform float seed = 0.0;

const vec3 CRACK_DARK = vec3(0.17, 0.165, 0.19);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 n = (UV - used.xy) / used.zw;
	vec2 p = vec2(n.x * aspect, n.y);
	vec2 pq = (floor(p * grid) + 0.5) / grid;
	vec3 rgb = tex.rgb;
	if (pq.y > 1.0 - progress) {
		float light = dot(rgb, vec3(0.3, 0.59, 0.11));
		rgb = vec3(0.3, 0.3, 0.33) + light * vec3(0.55, 0.55, 0.57);
		if (crack > 0.0) {
			vec2 delta = pq - vec2(aspect * 0.5, 0.45);
			float dist = length(delta);
			if (dist < crack * 0.55) {
				float segment = TAU / 6.0;
				float angle = atan(delta.y, delta.x) + sin(dist * grid * 0.9 + seed) * 0.35;
				float off = abs(mod(angle + seed, segment) - segment * 0.5);
				if (off * dist < 0.5 / grid) {
					rgb = CRACK_DARK;
				}
			}
		}
	}
	COLOR = vec4(rgb, tex.a);
}
