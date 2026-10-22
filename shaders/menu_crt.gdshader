shader_type canvas_item;
// Menu screen pass: soft CRT scanlines, a slow rolling band, film grain, vignette, a hint of colour fringing.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float scan = 0.16;
uniform float grain = 0.05;

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float fringe = 0.0006;
	vec3 c = vec3(texture(screen, uv + vec2(fringe, 0.0)).r, texture(screen, uv).g, texture(screen, uv - vec2(fringe, 0.0)).b);
	c *= 1.0 - scan * step(0.5, fract(FRAGCOORD.y * 0.5));
	c *= 1.0 + 0.05 * sin((uv.y + TIME * 0.08) * 6.2832 * 1.5);
	c += (rand(FRAGCOORD.xy + fract(TIME) * 61.0) - 0.5) * grain;
	vec2 d = uv - 0.5;
	c *= 1.0 - dot(d, d) * 1.1;
	COLOR = vec4(c, 1.0);
}
