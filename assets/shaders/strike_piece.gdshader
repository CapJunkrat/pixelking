shader_type canvas_item;

// Presentation-only shader for a piece taking part in a strike animation.
// It can flash the piece white and cut it into parts (half-plane, jagged waist line,
// row clipping, a pierced hole, a knocked-out base brick) without extra art.
//
// Masks work on a coarse grid ("chunks") laid over the painted area of the texture so
// that cuts look like pixel art and line up with the debris spawned from script.
// Coordinates named `p` are isotropic: x and y are both measured in sprite heights,
// with (0, 0) at the top-left of the painted area.

uniform vec4 used = vec4(0.0, 0.0, 1.0, 1.0);
uniform float aspect = 1.0;
uniform float grid = 16.0;
uniform float alpha = 1.0;
uniform float flash = 0.0;

uniform vec2 clip_y = vec2(0.0, 1.0);

uniform vec2 plane_origin = vec2(0.5, 0.5);
uniform vec2 plane_dir = vec2(1.0, 0.0);
uniform float plane_keep = 0.0;
uniform float edge_glow = 0.0;

uniform float jag_keep = 0.0;
uniform float jag_base = 0.42;
uniform float jag_seed = 0.0;
uniform float crack_progress = 0.0;
uniform float crack_from_right = 0.0;

uniform vec2 hole_center = vec2(0.5, 0.5);
uniform float hole_radius = 0.0;
uniform float hole_glow = 0.0;
uniform float web_progress = 0.0;

uniform vec4 brick = vec4(0.0);
uniform float brick_mode = 0.0;

uniform float sparkle = 0.0;
uniform float sparkle_time = 0.0;

const vec3 CRACK_DARK = vec3(0.043, 0.027, 0.063);
const vec3 WARM_WHITE = vec3(1.0, 0.94, 0.78);

float jag(float x) {
	float q = (floor(x * grid) + 0.5) / grid;
	float row = floor(jag_base * grid) + floor(sin(q * 19.0 + jag_seed) * 1.6 + 0.5) + floor(sin(q * 47.0 + jag_seed * 1.7) * 0.9 + 0.5);
	return (row + 0.5) / grid;
}

float hash(vec2 v) {
	return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 n = (UV - used.xy) / used.zw;
	vec2 p = vec2(n.x * aspect, n.y);
	vec2 pq = (floor(p * grid) + 0.5) / grid;
	vec3 rgb = tex.rgb;
	float a = tex.a;

	if (pq.y < clip_y.x || pq.y > clip_y.y) {
		a = 0.0;
	}

	if (plane_keep != 0.0) {
		float side = (pq.x - plane_origin.x) * plane_dir.y - (pq.y - plane_origin.y) * plane_dir.x;
		if (side * plane_keep < 0.6 / grid) {
			a = 0.0;
		} else if (abs(side) < 2.2 / grid) {
			rgb = mix(rgb, WARM_WHITE, edge_glow);
		}
	}

	float jy = jag(p.x);
	if (jag_keep > 0.0 && pq.y > jy - 0.25 / grid) {
		a = 0.0;
	}
	if (jag_keep < 0.0 && pq.y < jy + 0.25 / grid) {
		a = 0.0;
	}
	if (crack_progress > 0.0) {
		float along = p.x / aspect;
		if (crack_from_right > 0.5) {
			along = 1.0 - along;
		}
		if (along < crack_progress) {
			if (abs(pq.y - jy) < 0.25 / grid) {
				rgb = CRACK_DARK;
			} else if (abs(pq.y - (jy - 1.0 / grid)) < 0.25 / grid) {
				rgb = mix(rgb, WARM_WHITE, 0.9);
			}
		}
	}

	if (hole_radius > 0.0) {
		vec2 delta = pq - hole_center;
		float dist = length(delta);
		if (dist < hole_radius) {
			a = 0.0;
		} else if (dist < hole_radius + 1.3 / grid) {
			rgb = mix(rgb, vec3(1.0, 0.886, 0.588), hole_glow);
		} else if (web_progress > 0.0 && dist < web_progress) {
			float segment = TAU / 7.0;
			float angle = atan(delta.y, delta.x) + sin(dist * grid * 0.9 + jag_seed) * 0.35;
			float off = abs(mod(angle + jag_seed, segment) - segment * 0.5);
			if (off * dist < 0.5 / grid) {
				rgb = CRACK_DARK;
			}
		}
	}

	if (brick_mode > 0.5) {
		bool inside = pq.x >= brick.x && pq.x <= brick.z && pq.y >= brick.y && pq.y <= brick.w;
		if ((brick_mode < 1.5 && inside) || (brick_mode > 1.5 && !inside)) {
			a = 0.0;
		}
	}

	if (sparkle > 0.0 && hash(pq * grid + floor(sparkle_time * 30.0)) < sparkle) {
		rgb = WARM_WHITE;
	}

	rgb = mix(rgb, vec3(1.0), flash);
	COLOR = vec4(rgb, a * alpha);
}
