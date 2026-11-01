shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_disabled;
// The Veil's Eye branded into the back of Alex's hand (scripts/brand_mark.gd): an almond eye with its pupil,
// ringed by a spiral, drawn on a small quad. Pixelated on a 24-cell grid like the PS2-era textures.
//   heat 1 = the iron just lifted (white-orange, glowing, the skin around it angry red)
//   heat 0 = a healed scar, dark and raised, only lit by the scene
// Also painted on doors (BrandMark.paint): heat 0, and `reveal` draws it round from the left corner as a thumb goes.

uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float time_offset = 0.0;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;

float eye_mask(vec2 p) {
	float lid = 0.34 * (1.0 - (p.x * p.x) / (0.6 * 0.6));
	float lids = (lid > 0.0) ? step(abs(abs(p.y) - lid), 0.085) : 0.0;
	float pupil = step(length(p), 0.15);
	return max(lids, pupil);
}

float spiral_mask(vec2 p) {
	// one stroke winding out round the eye, a little over a turn: from just past the eye's corner to the rim
	float r = length(p);
	float a = fract(atan(p.y, p.x) / 6.28318 + 0.5);  // 0..1 round from the eye's left corner
	float best = 9.0;
	for (int k = 0; k < 2; k++) {  // the turn it's on (the stroke overlaps itself for the last bit)
		float along = a + float(k);
		if (along <= 1.25) {
			best = min(best, abs(r - (0.66 + 0.24 * along)));
		}
	}
	return step(best, 0.075) * step(0.6, r);
}

void fragment() {
	vec2 uv = (floor(UV * 24.0) + 0.5) / 24.0;
	vec2 p = (uv - 0.5) * 2.0;
	float ink = max(eye_mask(p), spiral_mask(p));
	ink *= step(fract(atan(p.y, p.x) / 6.28318 + 0.5), reveal + 0.001);
	float r = length(p);
	float halo = (1.0 - smoothstep(0.55, 1.0, r)) * heat;  // inflamed skin round a fresh burn
	float flick = 0.88 + 0.12 * sin(TIME * 13.0 + time_offset) * sin(TIME * 7.3 + time_offset * 2.0);
	vec3 scar = vec3(0.26, 0.06, 0.045);
	vec3 hot = mix(vec3(0.9, 0.2, 0.03), vec3(1.0, 0.78, 0.38), heat * heat);
	vec3 col = mix(scar, hot, heat * flick);
	ALBEDO = mix(vec3(0.55, 0.12, 0.08), col, ink);
	EMISSION = ink * hot * heat * heat * 3.0 * flick + (1.0 - ink) * vec3(0.6, 0.08, 0.02) * halo * 0.6;
	ROUGHNESS = 0.9;
	ALPHA = max(ink * 0.92, halo * 0.45);
}
