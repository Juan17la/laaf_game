shader_type canvas_item;
// PS2-era look: film grain, vignette, Bayer-dithered 16-bit-ish color quantization.
// Driven from code (player/screen_fx.gd, values from scripts/feel.gd); every effect uniform at 0 = the plain look:
//   vignette_extra + pulse  the Mark >= 50 %: a tighter vignette that throbs with the heartbeat
//   aberration + warp       the Mark >= 75 %: the colours split toward the edges and the picture wobbles
//   hurt                    after a hit / at low health: blurred, reddened edges

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float grain = 0.07;
uniform float vignette = 0.6;
uniform float levels = 32.0;
uniform float vignette_extra = 0.0;
uniform float pulse = 0.0;
uniform float aberration = 0.0;
uniform float warp = 0.0;
uniform float hurt = 0.0;
uniform vec3 hurt_color = vec3(0.5, 0.0, 0.0);

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (warp > 0.0) {
		uv += vec2(sin(uv.y * 17.0 + TIME * 1.7), cos(uv.x * 13.0 + TIME * 1.3)) * warp;
	}
	vec2 e = uv - 0.5;
	float edge = clamp(dot(e, e) * 4.0, 0.0, 1.0);  // 0 at the centre, 1 at the corners' reach
	vec3 c;
	if (aberration > 0.0) {
		vec2 off = e * aberration * 2.0;
		c = vec3(texture(screen, uv + off).r, texture(screen, uv).g, texture(screen, uv - off).b);
	} else {
		c = texture(screen, uv).rgb;
	}
	if (hurt > 0.0) {
		float b = 0.006 * hurt * edge;
		vec3 blur = (texture(screen, uv + vec2(b, 0.0)).rgb + texture(screen, uv - vec2(b, 0.0)).rgb
			+ texture(screen, uv + vec2(0.0, b)).rgb + texture(screen, uv - vec2(0.0, b)).rgb) * 0.25;
		c = mix(c, blur, clamp(edge * hurt * 1.5, 0.0, 1.0));
		c = mix(c, hurt_color, clamp((edge - 0.3) * hurt, 0.0, 0.6));
	}
	c += (rand(FRAGCOORD.xy + fract(TIME) * 97.0) - 0.5) * grain;
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * (vignette + vignette_extra + pulse) * 2.0;
	const float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float t = bayer[p.y * 4 + p.x] / 16.0;
	c = floor(c * levels + t) / levels;
	COLOR = vec4(c, 1.0);
}
