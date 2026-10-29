class_name Weather
extends Node3D
## The town's weather and the life in its air (a child of maps/hollowmere.tscn, so the menu's town has it too):
##  · rolling ground fog: a FogVolume of drifting noise banks (shaders/rolling_fog.gdshader) kept on the camera.
##    It thins with the mood's own volumetric fog (an interior mood all but clears it)
##  · rain: streaks round the camera that stop on whatever is above the ground (roofs, awnings: a height field
##    follows the camera) and splash where they land, with a rain hiss on the SFX bus
##  · wet ground: in rain the terrain, roads and streets darken and turn glossy (the env's SSR shows the lamps in them)
##  · wind: the trees bend and their needles shiver (shaders/foliage_wind.gdshader), harder in a storm
##  · a storm: lightning now and then (a flash through the fog, the thunder after it)
## set_weather(kind) per mission step comes from Game.at_step (STEP_WEATHER); every change eases in. Cosmetic.

const KINDS := {  ## rain 0..1, wind 0..1, wet 0..1, lightning, extra ground fog
	"fog": {"rain": 0.0, "wind": 0.25, "wet": 0.0, "storm": false, "fog": 1.0},
	"drizzle": {"rain": 0.22, "wind": 0.35, "wet": 0.55, "storm": false, "fog": 1.1},
	"rain": {"rain": 0.65, "wind": 0.6, "wet": 1.0, "storm": false, "fog": 0.9},
	"storm": {"rain": 1.0, "wind": 1.0, "wet": 1.0, "storm": true, "fog": 0.8},
}
const DROPS := 12000  ## rain particles at full strength
const AREA := 24.0  ## m: half the width of the rain round the camera
const FLASH_EVERY := Vector2(9.0, 22.0)  ## s between lightning strikes in a storm
const WET_ROUGHNESS := 0.22
const WET_DARKEN := 0.72

var kind := "fog"
var rain := 0.0  ## the strengths on screen now (eased toward KINDS[kind] by set_weather)
var wind := 0.25
var wet := 0.0
var fog := 1.0
var _storm := false
var _flash_t := 0.0
var _we: WorldEnvironment  ## (its environment is read each frame: the menu swaps in its own)
var _vol_base := 0.0  ## the scene's own volumetric fog density: the ground fog scales with the mood's
var _fog_vol: FogVolume
var _fog_mat: ShaderMaterial
var _rain: GPUParticles3D
var _rain_mat: ParticleProcessMaterial
var _field: GPUParticlesCollisionHeightField3D
var _hiss: AudioStreamPlayer
var _thunder: AudioStreamPlayer
var _bolt: DirectionalLight3D
var _foliage: Array[ShaderMaterial] = []
var _ground := {}  ## StandardMaterial3D (our copy) -> [roughness, albedo_color, specular] as authored


func _ready() -> void:
	_we = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	_vol_base = maxf(_we.environment.volumetric_fog_density, 0.001) if _we else 0.02
	_build_fog()
	_build_rain()
	_build_sound()
	_bolt = DirectionalLight3D.new()
	_bolt.light_color = Color(0.78, 0.84, 1.0)
	_bolt.light_energy = 0.0
	_bolt.light_volumetric_fog_energy = 2.5
	_bolt.rotation = Vector3(-1.1, 0.6, 0.0)
	_bolt.visible = false
	add_child(_bolt)
	_dress(get_parent())
	_flash_t = randf_range(FLASH_EVERY.x, FLASH_EVERY.y)


func set_weather(k: String, time := 4.0) -> void:
	## Eases the weather to `k` (a KINDS key; unknown = "fog") over `time` s.
	kind = k if k in KINDS else "fog"
	var w: Dictionary = KINDS[kind]
	_storm = w.storm
	var tw := create_tween().set_parallel()
	for p in ["rain", "wind", "wet", "fog"]:
		tw.tween_property(self, p, float(w[p]), maxf(time, 0.01))


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var c := cam.global_position
		_fog_vol.global_position = Vector3(c.x, c.y - 1.0, c.z)
		_rain.global_position = c + Vector3(-_rain_mat.direction.x, 0.0, -_rain_mat.direction.z) * 6.0 + Vector3.UP * 14.0
		_fog_mat.set_shader_parameter("floor_y", c.y - 2.2)
	var env: Environment = _we.environment if _we else null
	var mood := clampf(env.volumetric_fog_density / _vol_base, 0.0, 2.0) if env else 1.0
	_fog_mat.set_shader_parameter("density", 0.075 * fog * mood * mood)
	_fog_mat.set_shader_parameter("drift", Vector3(0.9, 0.05, 0.4) * (0.6 + wind * 1.6))
	_rain.emitting = rain > 0.01
	_rain.amount_ratio = rain
	_rain_mat.direction = Vector3(0.18 * wind, -1.0, 0.1 * wind)
	_hiss.volume_db = linear_to_db(maxf(rain * 0.55, 0.0001))
	if rain > 0.01 and not _hiss.playing:
		_hiss.play()
	elif rain <= 0.01 and _hiss.playing:
		_hiss.stop()
	for m in _foliage:
		m.set_shader_parameter("wind", wind)
	for m: StandardMaterial3D in _ground:
		var a: Array = _ground[m]
		m.roughness = lerpf(a[0], WET_ROUGHNESS, wet)
		m.albedo_color = (a[1] as Color).darkened(1.0 - lerpf(1.0, WET_DARKEN, wet))
		m.metallic_specular = lerpf(a[2], 0.75, wet)
	if env:
		env.ssr_enabled = wet > 0.05
	if _storm:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash_t = randf_range(FLASH_EVERY.x, FLASH_EVERY.y)
			_strike()


func _strike() -> void:
	## A flicker of lightning through the fog, the thunder 0.6-2.5 s after (nearer = sooner and louder).
	var far := randf()
	_bolt.visible = true
	_bolt.rotation.y = randf() * TAU
	var tw := create_tween()
	for e in [2.4, 0.3, 1.6, 0.0]:
		tw.tween_property(_bolt, "light_energy", e * (1.2 - far * 0.6), 0.06 if e > 0.0 else 0.35)
	tw.tween_callback(func() -> void: _bolt.visible = false)
	get_tree().create_timer(0.6 + far * 1.9).timeout.connect(func() -> void:
		_thunder.pitch_scale = randf_range(0.75, 1.05)
		_thunder.volume_db = lerpf(-2.0, -12.0, far)
		_thunder.play())


# ------------------------------------------------------------------ building

func _build_fog() -> void:
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.06
	nz.fractal_octaves = 3
	var tex := NoiseTexture3D.new()
	tex.width = 64
	tex.height = 32
	tex.depth = 64
	tex.seamless = true
	tex.noise = nz
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = load("res://shaders/rolling_fog.gdshader")
	_fog_mat.set_shader_parameter("noise", tex)
	_fog_vol = FogVolume.new()
	_fog_vol.size = Vector3(110.0, 9.0, 110.0)
	_fog_vol.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_fog_vol.material = _fog_mat
	add_child(_fog_vol)


func _build_rain() -> void:
	var look := StandardMaterial3D.new()  # lit, so the drops glint in the lamps and vanish in the dark between them
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(0.72, 0.78, 0.84, 0.2)
	look.emission_enabled = true
	look.emission = Color(0.5, 0.56, 0.6)
	look.emission_energy_multiplier = 0.12
	look.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	look.billboard_keep_scale = true
	look.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	look.cull_mode = BaseMaterial3D.CULL_DISABLED
	var streak := QuadMesh.new()
	streak.size = Vector2(0.01, 0.42)
	streak.material = look
	var splash_mesh := QuadMesh.new()
	splash_mesh.size = Vector2(0.07, 0.05)
	splash_mesh.material = look

	var splash_mat := ParticleProcessMaterial.new()
	splash_mat.direction = Vector3.UP
	splash_mat.spread = 70.0
	splash_mat.initial_velocity_min = 0.6
	splash_mat.initial_velocity_max = 1.5
	splash_mat.gravity = Vector3(0, -9.8, 0)
	splash_mat.scale_min = 0.6
	splash_mat.scale_max = 1.3
	var splash := GPUParticles3D.new()
	splash.name = "Splash"
	splash.amount = 900
	splash.lifetime = 0.28
	splash.emitting = false
	splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splash.process_material = splash_mat
	splash.draw_pass_1 = splash_mesh
	splash.visibility_aabb = AABB(Vector3(-AREA, -40, -AREA), Vector3(AREA * 2.0, 60, AREA * 2.0))
	add_child(splash)

	_rain_mat = ParticleProcessMaterial.new()
	_rain_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_mat.emission_box_extents = Vector3(AREA, 0.5, AREA)
	_rain_mat.direction = Vector3(0, -1, 0)
	_rain_mat.spread = 2.0
	_rain_mat.initial_velocity_min = 17.0
	_rain_mat.initial_velocity_max = 21.0
	_rain_mat.gravity = Vector3(0, -9.8, 0)
	_rain_mat.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_rain_mat.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION
	_rain_mat.sub_emitter_amount_at_collision = 2
	_rain = GPUParticles3D.new()
	_rain.amount = DROPS
	_rain.lifetime = 1.1
	_rain.emitting = false
	_rain.local_coords = false
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.process_material = _rain_mat
	_rain.draw_pass_1 = streak
	_rain.visibility_aabb = AABB(Vector3(-AREA - 8, -40, -AREA - 8), Vector3(AREA * 2.0 + 16, 44, AREA * 2.0 + 16))
	add_child(_rain)
	_rain.sub_emitter = _rain.get_path_to(splash)

	_field = GPUParticlesCollisionHeightField3D.new()  # what the drops land on: re-baked as the camera moves
	_field.size = Vector3(AREA * 2.0 + 8.0, 60.0, AREA * 2.0 + 8.0)
	_field.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	_field.follow_camera_enabled = true
	_field.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	add_child(_field)


func _build_sound() -> void:
	## Rain and thunder are made here, not files: filtered noise.
	_hiss = AudioStreamPlayer.new()
	_hiss.bus = "SFX"
	_hiss.stream = _noise(3.0, 0.35, 0.02, func(_t: float) -> float: return 1.0)
	add_child(_hiss)
	_thunder = AudioStreamPlayer.new()
	_thunder.bus = "SFX"
	_thunder.stream = _noise(4.5, 0.012, 0.0, func(t: float) -> float:
		return minf(t / 0.08, 1.0) * exp(-t * 1.1) * (0.7 + 0.3 * sin(t * 9.0) * exp(-t * 2.0)))
	add_child(_thunder)


static func _noise(secs: float, smooth: float, ticks: float, env: Callable) -> AudioStreamWAV:
	## Mono 16-bit noise through a one-pole low-pass (`smooth`: 1 = white, small = a rumble), with `ticks` a
	## chance per sample of a brighter drop, shaped by env(t). Loops when env is flat.
	const RATE := 22050
	var n := int(secs * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var y := 0.0
	var peak := 0.0
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		y += (randf_range(-1.0, 1.0) - y) * smooth
		var s := y
		if ticks > 0.0 and randf() < ticks:
			s += randf_range(-0.6, 0.6)
		buf[i] = s * env.call(float(i) / RATE)
		peak = maxf(peak, absf(buf[i]))
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i] / maxf(peak, 0.0001) * 0.8, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if ticks > 0.0:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = n
	return w


func _dress(root: Node) -> void:
	## The town's trees get the wind shader; its ground gets its own copies of the materials to wet.
	var swapped := {}
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as StandardMaterial3D
			if m == null or m.albedo_texture == null:
				continue
			var path := m.albedo_texture.resource_path.get_file()
			if path.begins_with("pine_tree") or path.begins_with("dead_tree"):
				if not swapped.has(m):
					var s := ShaderMaterial.new()
					s.shader = load("res://shaders/foliage_wind.gdshader")
					s.set_shader_parameter("albedo_tex", m.albedo_texture)
					s.set_shader_parameter("albedo", m.albedo_color)
					s.set_shader_parameter("scissor", m.alpha_scissor_threshold if m.transparency != 0 else 0.0)
					s.set_shader_parameter("flutter", 1.0 if "needles" in path else 0.0)
					swapped[m] = s
					_foliage.append(s)
				mi.set_surface_override_material(i, swapped[m])
			elif path.begins_with("terrain_") and path != "terrain_water.png":
				if not swapped.has(m):
					var c := m.duplicate() as StandardMaterial3D
					swapped[m] = c
					_ground[c] = [c.roughness, c.albedo_color, c.metallic_specular]
				mi.set_surface_override_material(i, swapped[m])
