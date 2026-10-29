shader_type spatial;
render_mode cull_disabled;
// The trees' bark and needles bending in the wind (scripts/weather.gd swaps it onto their materials and drives
// `wind`). The bend grows with height above the trunk's base, so roots stay planted; each tree has its own phase
// from its position, and the needles flutter on top. The look is the original material's: texture × colour,
// alpha-scissored.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float scissor = 0.5;
uniform float wind = 0.3;  // 0 still air .. 1 a storm
uniform float flutter = 0.0;  // the needles' shiver (0 on bark)
uniform vec2 gust_dir = vec2(0.85, 0.5);

void vertex() {
	vec3 o = NODE_POSITION_WORLD;
	float ph = o.x * 0.37 + o.z * 0.53;
	float h = max(VERTEX.y, 0.0) / 8.0;
	float bend = h * h;
	float t = TIME;
	float gust = 0.6 + 0.4 * sin(t * 0.35 + ph * 0.2);
	vec2 sway = gust_dir * (0.35 + 0.2 * sin(t * 1.1 + ph)) * gust
		+ vec2(sin(t * 1.7 + ph * 1.3), cos(t * 1.3 + ph)) * 0.12;
	vec3 off = vec3(sway.x, 0.0, sway.y) * bend * wind * 0.9;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
	VERTEX += NORMAL * sin(t * 7.0 + dot(VERTEX, vec3(3.1, 2.3, 2.7)) + ph) * 0.03 * flutter * wind * h;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo;
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = scissor;
	ROUGHNESS = 1.0;
	SPECULAR = 0.2;
}
