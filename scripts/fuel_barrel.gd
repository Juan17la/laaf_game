class_name FuelBarrel
extends StaticBody3D
## Red fuel drum: shoot it (or hit it with a flare) and it bursts: a flash, a fireball and a shock ring out to RADIUS
## (exactly the reach of the fire), smoke and torn metal, then a fire pool that burns BURN s round the charred
## wreck it leaves (solid, on a scorch mark). The fire hurts everyone inside and stuns anything with flare_stun
## (Owen fears fire). A checkpoint respawn (Chapter1Director._on_died) calls reset() on every barrel in GROUP:
## the wreck and the scorch go, the drum stands there again, whole. One-off fires (respawns = false: Owen's help in
## Chapter 3) free themselves once burnt out instead.

const GROUP := "fuel_barrels"
const RADIUS := 3.2
const BURN := 7.0
const FLASH := 0.35  ## s the burst's flash takes to fade
const SHAKE := 0.75  ## camera trauma at point blank...
const SHAKE_RANGE := 22.0  ## ...fading to nothing this far out
const DRUM := Vector2(0.33, 0.95)  ## radius, height
const WRECK_H := 0.55

var respawns := true
var burst := false  ## blown (until reset)
var _fire := 0.0
var _tick := 0.0
var _col: CollisionShape3D
var _drum: Node3D
var _fx: Node3D  ## everything the burst made: wreck, scorch, fire, light (freed by reset)
var _flames: GPUParticles3D
var _smoke: GPUParticles3D
var _light: OmniLight3D
var _hiss: Node

static var _blob_tex: Texture2D
static var _ring_tex: Texture2D
static var _scorch_tex: Texture2D


static func make(parent: Node, pos: Vector3, respawn := true) -> FuelBarrel:
	var b := FuelBarrel.new()
	b.respawns = respawn
	b.collision_layer = 3
	b._col = CollisionShape3D.new()
	b.add_child(b._col)
	b._drum = _drum_mesh()
	b.add_child(b._drum)
	b._whole()
	parent.add_child(b)
	b.global_position = pos
	return b


func _ready() -> void:
	add_to_group(GROUP)


func _whole() -> void:
	## The standing drum and its collision.
	var cyl := CylinderShape3D.new()
	cyl.radius = DRUM.x + 0.02
	cyl.height = DRUM.y
	_col.shape = cyl
	_col.position.y = DRUM.y / 2.0
	_drum.visible = true
	collision_layer = 3


func hit(_dmg: float, _point: Vector3, _flare := false) -> void:
	if burst:
		return
	burst = true
	_fire = BURN
	_tick = 0.0
	_drum.visible = false
	collision_layer = 0
	_fx = Node3D.new()
	add_child(_fx)
	_fx.add_child(_wreck())
	_fx.add_child(_scorch())
	_explode()
	_flames = _burn_flames()
	_fx.add_child(_flames)
	_smoke = _burn_smoke()
	_fx.add_child(_smoke)
	get_tree().call_group("enemies", "hear", global_position, 25.0)
	Snd.sfx("explosion", global_position, 2.0)
	_hiss = Snd.attach(self, "hiss", -2.0)
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p and p.has_method("add_trauma"):
		var k := clampf(1.0 - p.global_position.distance_to(global_position) / SHAKE_RANGE, 0.0, 1.0)
		p.add_trauma(SHAKE * k * k * Feel.shake)


func reset() -> void:
	## Back to an unexploded drum where it stood (a checkpoint respawn). A one-off fire just goes.
	if not respawns:
		queue_free()
		return
	if not burst:
		return
	burst = false
	_fire = 0.0
	Snd.stop(_hiss)
	_hiss = null
	if is_instance_valid(_fx):
		_fx.queue_free()
	_fx = null
	_flames = null
	_smoke = null
	_light = null
	_whole()


func burning() -> bool:
	return _fire > 0.0


func _physics_process(delta: float) -> void:
	if _fire <= 0.0:
		return
	_fire -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for n in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("player"):
			if n is Enemy and (n as Enemy).state == Enemy.State.DOWN:
				continue  # a kneeling boss waits for spare / kill: the fire never decides it (a hit would kill)
			if n.global_position.distance_to(global_position) < RADIUS:
				if n.has_method("stagger") and n.flare_stun > 0.0:
					n.stagger(n.flare_stun)
				if n.has_method("hurt"):
					n.hurt(8.0, global_position)
				elif n.has_method("hit"):
					n.hit(10.0, n.global_position, false)
	if _fire <= 0.0:
		_burnt_out()


func _burnt_out() -> void:
	## The pool dies down: flames and smoke stop, the light fades; the wreck and the scorch stay (until reset).
	Snd.stop(_hiss)
	_hiss = null
	if not respawns:
		queue_free()
		return
	if _flames:
		_flames.emitting = false
	if _smoke:
		_smoke.emitting = false
	if _light:
		_light.set_script(null)  # (flicker.gd drives the energy)
		create_tween().tween_property(_light, "light_energy", 0.0, 1.5)


# ------------------------------------------------------------------ the burst

func _explode() -> void:
	# flash: a hard white-orange light that fades in FLASH s into the fire's own flicker
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.light_energy = 14.0
	_light.omni_range = RADIUS * 3.5
	_light.shadow_enabled = false
	_light.position.y = 1.0
	_fx.add_child(_light)
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 4.0, FLASH).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(_light, "omni_range", 9.0, 0.2)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_light) and _fire > 0.0:
			_light.set_script(load("res://scripts/flicker.gd")))
	# fireball: chunky billboards thrown out to the fire's reach, white-hot to orange to soot
	_fx.add_child(_particles({"n": 26, "life": 0.7, "one_shot": true, "size": Vector2(0.9, 1.5), "r": 0.45,
		"at": Vector3(0, 0.7, 0), "v": Vector2(4.5, 6.0), "damp": 9.0, "g": Vector3(0, 1.5, 0),
		"ramp": [[0.0, Color(1.0, 0.92, 0.6, 1.0)], [0.2, Color(1.0, 0.55, 0.1, 1.0)], [0.55, Color(0.7, 0.18, 0.04, 0.9)],
			[1.0, Color(0.1, 0.06, 0.05, 0.0)]], "grow": [0.5, 1.0, 0.6]}))
	# smoke burst: a dark column rolling up out of it
	_fx.add_child(_particles({"n": 14, "life": 2.4, "one_shot": true, "size": Vector2(1.2, 2.0), "r": 0.8,
		"at": Vector3(0, 1.0, 0), "v": Vector2(0.8, 2.0), "spread": 40.0, "damp": 0.6, "g": Vector3(0, 1.2, 0),
		"explode": 0.7, "ramp": [[0.0, Color(0.16, 0.13, 0.11, 0.0)], [0.15, Color(0.16, 0.13, 0.11, 0.75)],
			[1.0, Color(0.3, 0.29, 0.28, 0.0)]], "grow": [0.6, 1.0, 1.5]}))
	# sparks
	_fx.add_child(_particles({"n": 18, "life": 0.9, "one_shot": true, "size": Vector2(0.06, 0.1), "r": 0.3,
		"at": Vector3(0, 0.6, 0), "v": Vector2(5.0, 9.0), "spread": 70.0, "g": Vector3(0, -9.8, 0), "add": true,
		"ramp": [[0.0, Color(1.0, 0.9, 0.5, 1.0)], [1.0, Color(1.0, 0.3, 0.05, 0.0)]]}))
	# shock ring on the ground: grows to exactly RADIUS, so the player sees how far the fire reaches
	var ring := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.0, 2.0)
	ring.mesh = pm
	var rm := _sprite_mat(_ring(), true)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	rm.albedo_color = Color(1.0, 0.7, 0.35, 0.9)
	ring.material_override = rm
	ring.position.y = 0.06
	ring.scale = Vector3.ONE * 0.3
	_fx.add_child(ring)
	var rt := create_tween().set_parallel()
	rt.tween_property(ring, "scale", Vector3(RADIUS, 1.0, RADIUS), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	rt.tween_property(rm, "albedo_color:a", 0.0, 0.5).set_delay(0.1)
	rt.chain().tween_callback(ring.queue_free)
	# torn metal: a few chunks of the drum thrown clear, gone once they've settled
	for i in 6:
		_chunk(i)


func _chunk(i: int) -> void:
	var c := RigidBody3D.new()
	c.collision_layer = 0
	c.collision_mask = 1
	c.mass = 0.4
	var size := Vector3(randf_range(0.12, 0.26), 0.03, randf_range(0.1, 0.22))
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	c.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = _flat(Color(0.5, 0.08, 0.05) if i % 2 else Color(0.12, 0.1, 0.09), 0.5)
	mi.mesh = bm
	c.add_child(mi)
	_fx.add_child(c)
	var a := TAU * (i + randf() * 0.6) / 6.0
	c.global_position = global_position + Vector3(cos(a) * 0.3, 0.5 + randf() * 0.4, sin(a) * 0.3)
	c.linear_velocity = Vector3(cos(a), 0.0, sin(a)) * randf_range(3.0, 5.5) + Vector3.UP * randf_range(4.0, 7.0)
	c.angular_velocity = Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
	var tw := c.create_tween()
	tw.tween_interval(4.0 + randf())
	tw.tween_property(c, "scale", Vector3.ONE * 0.01, 0.6)
	tw.tween_callback(c.queue_free)


func _burn_flames() -> GPUParticles3D:
	## The fire pool: flames licking up all over the RADIUS disc, taller in the middle where the drum burst.
	var f := _particles({"n": 64, "life": 0.85, "size": Vector2(0.45, 0.9), "r": RADIUS * 0.9, "disc": true,
		"at": Vector3(0, 0.15, 0), "v": Vector2(0.8, 1.8), "spread": 12.0, "g": Vector3(0, 1.0, 0),
		"ramp": [[0.0, Color(1.0, 0.75, 0.3, 0.0)], [0.12, Color(1.0, 0.55, 0.12, 0.85)], [0.55, Color(0.85, 0.22, 0.04, 0.65)],
			[1.0, Color(0.3, 0.05, 0.02, 0.0)]], "grow": [0.7, 1.0, 0.2]})
	var core := _particles({"n": 18, "life": 1.0, "size": Vector2(0.7, 1.2), "r": 0.35, "at": Vector3(0, 0.5, 0),
		"v": Vector2(1.5, 2.6), "spread": 10.0, "g": Vector3(0, 1.2, 0),
		"ramp": [[0.0, Color(1.0, 0.85, 0.45, 0.0)], [0.1, Color(1.0, 0.62, 0.18, 0.95)], [0.6, Color(0.9, 0.28, 0.05, 0.7)],
			[1.0, Color(0.3, 0.05, 0.02, 0.0)]], "grow": [0.8, 1.0, 0.3]})
	f.add_child(core)
	f.emitting = true
	return f


func _burn_smoke() -> GPUParticles3D:
	return _particles({"n": 12, "life": 3.2, "size": Vector2(1.0, 1.8), "r": 1.2, "at": Vector3(0, 1.6, 0),
		"v": Vector2(0.6, 1.2), "spread": 15.0, "damp": 0.2, "g": Vector3(0, 0.6, 0),
		"ramp": [[0.0, Color(0.12, 0.1, 0.09, 0.0)], [0.2, Color(0.12, 0.1, 0.09, 0.5)], [1.0, Color(0.25, 0.24, 0.23, 0.0)]],
		"grow": [0.5, 1.0, 1.6]})


# ------------------------------------------------------------------ building blocks (PS2: flat, chunky, low-res)

func _particles(s: Dictionary) -> GPUParticles3D:
	## A billboard emitter. s: n, life, size (min, max), r (emission radius; "disc": flat on the ground), at, v (speed
	## range), spread (deg off straight up; default all round), damp, g, add (additive), ramp [[t, colour], ...],
	## grow [start, mid, end] scale over life, one_shot, explode (explosiveness of a one-shot).
	var p := GPUParticles3D.new()
	p.amount = s.n
	p.lifetime = s.life
	p.one_shot = s.get("one_shot", false)
	p.explosiveness = s.get("explode", 1.0) if p.one_shot else 0.0
	p.position = s.get("at", Vector3.ZERO)
	p.visibility_aabb = AABB(Vector3(-RADIUS - 2, -1, -RADIUS - 2), Vector3(RADIUS * 2 + 4, 9, RADIUS * 2 + 4))
	var m := ParticleProcessMaterial.new()
	if s.get("disc", false):
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		m.emission_ring_axis = Vector3.UP
		m.emission_ring_radius = s.r
		m.emission_ring_inner_radius = 0.0
		m.emission_ring_height = 0.05
	else:
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = s.r
	m.direction = Vector3.UP
	m.spread = s.get("spread", 180.0)
	m.initial_velocity_min = s.v.x if s.has("v") else 0.0
	m.initial_velocity_max = s.v.y if s.has("v") else 0.0
	m.gravity = s.get("g", Vector3.ZERO)
	m.damping_min = s.get("damp", 0.0)
	m.damping_max = s.get("damp", 0.0)
	m.scale_min = s.size.x
	m.scale_max = s.size.y
	m.angle_min = -180.0
	m.angle_max = 180.0
	if s.has("ramp"):
		var g := Gradient.new()
		var ts := PackedFloat32Array()
		var cs := PackedColorArray()
		for k in s.ramp:
			ts.append(k[0])
			cs.append(k[1])
		g.offsets = ts
		g.colors = cs
		var gt := GradientTexture1D.new()
		gt.gradient = g
		gt.width = 32
		m.color_ramp = gt
	if s.has("grow"):
		var c := Curve.new()
		c.add_point(Vector2(0.0, s.grow[0]))
		c.add_point(Vector2(0.4, s.grow[1]))
		c.add_point(Vector2(1.0, s.grow[2]))
		var ct := CurveTexture.new()
		ct.curve = c
		m.scale_curve = ct
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	q.material = _sprite_mat(_blob(), s.get("add", false))
	p.draw_pass_1 = q
	p.emitting = true
	if p.one_shot:
		p.finished.connect(p.queue_free)
	return p


static func _sprite_mat(tex: Texture2D, add: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.disable_receive_shadows = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _flat(c: Color, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.3
	return m


static func _blob() -> Texture2D:
	## 12x12 lumpy puff: hard-edged, a few holes, the PS2's chunky fire / smoke sprite.
	if not _blob_tex:
		var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for y in 12:
			for x in 12:
				var d := Vector2(x - 5.5, y - 5.5).length() / 6.0 + rng.randf_range(-0.12, 0.12)
				var a := clampf((1.0 - d) * 2.2, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, snappedf(a, 0.25)))
		_blob_tex = ImageTexture.create_from_image(img)
	return _blob_tex


static func _ring() -> Texture2D:
	if not _ring_tex:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				var a := clampf(1.0 - absf(d - 0.88) / 0.1, 0.0, 1.0) if d <= 1.0 else 0.0
				img.set_pixel(x, y, Color(1, 1, 1, snappedf(a, 0.25)))
		_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


static func _scorch_texture() -> Texture2D:
	## Soot splash: black in the middle, ragged spokes out to the edge of the fire's reach.
	if not _scorch_tex:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		var spokes: Array[float] = []
		for i in 12:
			spokes.append(rng.randf_range(0.7, 1.0))
		for y in 32:
			for x in 32:
				var v := Vector2(x - 15.5, y - 15.5)
				var d := v.length() / 16.0
				var reach: float = spokes[int((v.angle() + PI) / TAU * 12.0) % 12]
				var a := clampf((reach - d) * 3.0, 0.0, 0.92) * (0.75 + 0.25 * rng.randf())
				img.set_pixel(x, y, Color(0.04, 0.03, 0.025, snappedf(a, 0.125)))
		_scorch_tex = ImageTexture.create_from_image(img)
	return _scorch_tex


func _scorch() -> Decal:
	var d := Decal.new()
	d.texture_albedo = _scorch_texture()
	d.size = Vector3(RADIUS * 2.0, 1.2, RADIUS * 2.0)
	d.position.y = 0.2
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.cull_mask = 1  # the ground and the props (not Alex: his meshes are on Player.BODY_LAYER)
	return d


static func _drum_mesh() -> Node3D:
	## The standing drum: red body, two rolling hoops, a darker lid.
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = DRUM.x
	cm.bottom_radius = DRUM.x
	cm.height = DRUM.y
	cm.radial_segments = 10
	cm.rings = 1
	cm.material = _flat(Color(0.45, 0.06, 0.04), 0.6)
	body.mesh = cm
	body.position.y = DRUM.y / 2.0
	root.add_child(body)
	for y in [DRUM.y * 0.33, DRUM.y * 0.67]:
		var hoop := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = DRUM.x + 0.015
		hm.bottom_radius = DRUM.x + 0.015
		hm.height = 0.035
		hm.radial_segments = 10
		hm.rings = 1
		hm.material = _flat(Color(0.3, 0.05, 0.03), 0.5)
		hoop.mesh = hm
		hoop.position.y = y
		root.add_child(hoop)
	var lid := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = DRUM.x - 0.02
	lm.bottom_radius = DRUM.x - 0.02
	lm.height = 0.02
	lm.radial_segments = 10
	lm.rings = 1
	lm.material = _flat(Color(0.2, 0.04, 0.03), 0.5)
	lid.mesh = lm
	lid.position.y = DRUM.y + 0.005
	root.add_child(lid)
	return root


func _wreck() -> Node3D:
	## What's left: the charred bottom of the drum, its top torn open into petals of metal, the lid blown off beside it.
	## Solid (a plain body on the world layer: shots spark off it, it's no target any more).
	var root := StaticBody3D.new()
	root.collision_layer = 1
	root.collision_mask = 0
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = DRUM.x + 0.03
	cyl.height = WRECK_H
	col.shape = cyl
	col.position.y = WRECK_H / 2.0
	root.add_child(col)
	var char_mat := _flat(Color(0.09, 0.07, 0.06), 0.9)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = DRUM.x + 0.02
	cm.bottom_radius = DRUM.x
	cm.height = WRECK_H - 0.12
	cm.radial_segments = 10
	cm.rings = 1
	cm.cap_top = false
	cm.material = char_mat
	body.mesh = cm
	body.position.y = (WRECK_H - 0.12) / 2.0
	root.add_child(body)
	var red := _flat(Color(0.28, 0.05, 0.03), 0.8)
	for i in 7:
		var a := TAU * (i + 0.2 * sin(i * 3.1)) / 7.0
		var petal := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.22, 0.3 + 0.08 * sin(i * 1.7), 0.02)
		pb.material = red if i % 3 == 0 else char_mat
		petal.mesh = pb
		var out := Vector3(cos(a), 0.0, sin(a))
		var at := out * DRUM.x + Vector3.UP * (WRECK_H - 0.12)
		var lean := 0.6 + 0.35 * sin(i * 2.3)  # torn outward: the petal's top tips away from the middle
		var b := Basis(Vector3.UP.cross(out), lean) * Basis.looking_at(out, Vector3.UP)
		petal.transform = Transform3D(b, at) * Transform3D(Basis(), Vector3(0, pb.size.y / 2.0, 0))
		root.add_child(petal)
	var lid := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = DRUM.x - 0.02
	lm.bottom_radius = DRUM.x - 0.02
	lm.height = 0.02
	lm.radial_segments = 10
	lm.rings = 1
	lm.material = char_mat
	lid.mesh = lm
	lid.position = Vector3(0.9, 0.04, -0.5)
	lid.rotation = Vector3(0.15, 0.0, -0.2)
	root.add_child(lid)
	return root
