shader_type canvas_item;
// Behind the selection wheel (player/weapon_wheel.gd): the slowed game, blurred a little, greyed and darkened.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec3 c = textureLod(screen, SCREEN_UV, 1.5).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	vec2 d = SCREEN_UV - 0.5;
	COLOR = vec4(mix(c, vec3(l), 0.8) * (0.55 - dot(d, d) * 0.9), 1.0);
}
