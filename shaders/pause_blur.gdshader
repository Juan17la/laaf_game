shader_type canvas_item;
// Behind the pause menu: the paused game, blurred and dimmed the way the fog sits behind the dossier. The blur is
// measured against the game's own 640×360 pixels, so it reads the same at any window size.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 1.4;  // mip levels past the game's own pixels
uniform float dim = 0.55;

void fragment() {
	float lod = max(log2(1.0 / (SCREEN_PIXEL_SIZE.y * 360.0)), 0.0) + blur;
	vec2 px = SCREEN_PIXEL_SIZE * exp2(lod);
	vec3 c = textureLod(screen, SCREEN_UV, lod).rgb * 0.25;
	c += (textureLod(screen, SCREEN_UV + vec2(px.x, 0.0), lod).rgb + textureLod(screen, SCREEN_UV - vec2(px.x, 0.0), lod).rgb
		+ textureLod(screen, SCREEN_UV + vec2(0.0, px.y), lod).rgb + textureLod(screen, SCREEN_UV - vec2(0.0, px.y), lod).rgb) * 0.125;
	c += (textureLod(screen, SCREEN_UV + px, lod).rgb + textureLod(screen, SCREEN_UV - px, lod).rgb
		+ textureLod(screen, SCREEN_UV + vec2(px.x, -px.y), lod).rgb + textureLod(screen, SCREEN_UV + vec2(-px.x, px.y), lod).rgb) * 0.0625;
	COLOR = vec4(c * dim, 1.0);
}
