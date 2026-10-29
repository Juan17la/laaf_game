shader_type fog;
// Rolling ground fog: banks of 3D noise drifting on the wind, thick at the feet and thinning with height.
// Lives on the FogVolume that scripts/weather.gd keeps centred on the camera. The noise is sampled in world space,
// so the banks stay put in the town while the volume follows the camera; they fade at the volume's sides.

uniform sampler3D noise : repeat_enable;
uniform float density = 0.09;
uniform float floor_y = 0.0;  // the ground under the camera (m): the fog is thickest here
uniform float falloff = 0.55;  // how fast it thins with height (per m)
uniform vec3 drift = vec3(0.9, 0.05, 0.4);  // m/s, the wind pushing the banks
uniform vec3 albedo : source_color = vec3(0.74, 0.77, 0.74);

void fog() {
	vec3 p = WORLD_POSITION + drift * TIME;
	float n = texture(noise, p * 0.035).r * 0.65 + texture(noise, p * 0.11 + vec3(0.37)).r * 0.35;
	float banks = smoothstep(0.38, 0.72, n);
	float h = exp(-max(WORLD_POSITION.y - floor_y, 0.0) * falloff);
	vec2 e = abs(UVW.xz - 0.5) * 2.0;
	float sides = 1.0 - smoothstep(0.6, 1.0, max(e.x, e.y));
	DENSITY = density * (0.25 + banks) * h * sides;
	ALBEDO = albedo;
}
