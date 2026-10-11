extends RefCounted
## Item identity (preload as ItemFx): the pickup's model (res://models/item_<kind>.glb, a primitive
## stand-in until it's imported) plus a small CPUParticles3D "tell" per kind, and one-shot bursts
## (muzzle flash, casings, glass, splash). Preset keys: c / c2 colour (random between), n amount, life,
## size, v speed range, dir + spread, g gravity, r emission radius, at offset (model space), add (glow),
## fade (fraction of the life a particle shows: < 1 twinkles / blinks), burst (explosiveness),
## ring (expanding signal ring), box (mesh debris of that size instead of a sprite).

const P := {
	# idle tells
	"brass": {"c": Color(1.0, 0.8, 0.35), "n": 3, "life": 0.9, "size": 0.035, "r": 0.1, "at": Vector3(0, 0.07, 0),
		"add": true, "fade": 0.3},
	"motes": {"c": Color(1.0, 0.97, 0.92, 0.8), "c2": Color(0.9, 0.2, 0.2, 0.8), "n": 5, "life": 2.2, "size": 0.025,
		"v": Vector2(0.02, 0.06), "g": Vector3(0, 0.03, 0), "r": 0.12, "at": Vector3(0, 0.06, 0)},
	"glass": {"c": Color(0.55, 1.0, 0.65), "n": 2, "life": 1.3, "size": 0.04, "r": 0.05, "at": Vector3(0, 0.14, 0),
		"add": true, "fade": 0.25},
	"sparks": {"c": Color(1.0, 0.3, 0.1), "c2": Color(1.0, 0.8, 0.35), "n": 8, "life": 0.6, "size": 0.025,
		"v": Vector2(0.3, 0.8), "spread": 25.0, "g": Vector3(0, -1.5, 0), "r": 0.03, "at": Vector3(0, 0.06, 0), "add": true},
	"wisp": {"c": Color(0.5, 0.45, 0.45, 0.35), "n": 4, "life": 2.5, "size": 0.14, "v": Vector2(0.05, 0.15),
		"spread": 15.0, "g": Vector3(0, 0.08, 0), "at": Vector3(0, 0.1, 0)},
	"mist": {"c": Color(0.4, 0.9, 0.85, 0.25), "n": 6, "life": 2.6, "size": 0.16, "v": Vector2(0.01, 0.04),
		"g": Vector3(0, 0.02, 0), "r": 0.16, "at": Vector3(0, 0.08, 0)},
	"puffs": {"c": Color(0.6, 0.6, 0.57, 0.4), "n": 5, "life": 2.2, "size": 0.14, "v": Vector2(0.1, 0.25),
		"spread": 20.0, "g": Vector3(0, 0.05, 0), "r": 0.02, "at": Vector3(0, 0.15, 0)},
	"shimmer": {"c": Color(0.5, 0.8, 1.0), "n": 6, "life": 1.2, "size": 0.03, "v": Vector2(0.02, 0.08), "r": 0.1,
		"at": Vector3(0, 0.04, 0), "add": true, "fade": 0.6},
	"dust": {"c": Color(0.95, 0.9, 0.75, 0.6), "n": 6, "life": 3.0, "size": 0.018, "v": Vector2(0.01, 0.04),
		"g": Vector3(0, 0.01, 0), "r": 0.22, "at": Vector3(0, 0.1, 0), "add": true},
	"led": {"c": Color(1.0, 0.1, 0.05), "n": 1, "life": 1.0, "size": 0.03, "at": Vector3(0.03, 0.05, -0.02),
		"add": true, "fade": 0.45},
	"glint": {"c": Color(0.85, 0.9, 1.0), "n": 2, "life": 1.4, "size": 0.035, "r": 0.05, "at": Vector3(0, 0.02, 0),
		"add": true, "fade": 0.2},
	"battery": {"c": Color(0.7, 0.85, 1.0), "c2": Color(1.0, 1.0, 0.8), "n": 5, "life": 1.6, "size": 0.02,
		"v": Vector2(0.4, 1.0), "spread": 60.0, "g": Vector3(0, -4, 0), "at": Vector3(0.1, 0.13, 0), "add": true,
		"fade": 0.15, "burst": 1.0},
	"static": {"c": Color(0.5, 1.0, 0.6), "c2": Color(0.9, 1.0, 0.9), "n": 8, "life": 0.35, "size": 0.018,
		"v": Vector2(0.2, 0.6), "r": 0.15, "at": Vector3(0, 0.1, 0), "add": true},
	"rings": {"c": Color(0.5, 1.0, 0.6, 0.5), "n": 2, "life": 1.6, "size": 0.5, "at": Vector3(0, 0.1, 0), "add": true,
		"ring": true},
	# one-shots (burst)
	"muzzle": {"c": Color(1.0, 0.9, 0.55), "c2": Color(1.0, 0.5, 0.15), "n": 10, "life": 0.09, "size": 0.06,
		"v": Vector2(1.0, 3.0), "spread": 20.0, "add": true, "burst": 1.0},
	"muzzle_flare": {"c": Color(1.0, 0.35, 0.1), "c2": Color(1.0, 0.8, 0.3), "n": 14, "life": 0.18, "size": 0.07,
		"v": Vector2(1.0, 3.5), "spread": 25.0, "add": true, "burst": 1.0},
	"gunsmoke": {"c": Color(0.62, 0.62, 0.6, 0.35), "n": 5, "life": 0.9, "size": 0.12, "v": Vector2(0.2, 0.6),
		"spread": 30.0, "g": Vector3(0, 0.3, 0), "burst": 0.9},
	"casings": {"c": Color(0.85, 0.65, 0.25), "box": Vector3(0.012, 0.03, 0.012), "n": 6, "life": 0.55,
		"v": Vector2(0.6, 1.4), "spread": 50.0, "g": Vector3(0, -9.8, 0), "burst": 0.8},
	"flare_trail": {"c": Color(1.0, 0.35, 0.1), "c2": Color(1.0, 0.85, 0.4), "n": 30, "life": 0.45, "size": 0.035,
		"v": Vector2(0.1, 0.6), "g": Vector3(0, -2.0, 0), "add": true},
	"shards": {"c": Color(0.5, 0.8, 0.6), "box": Vector3(0.03, 0.03, 0.01), "n": 14, "life": 0.7, "v": Vector2(1.5, 3.5),
		"spread": 70.0, "g": Vector3(0, -9.8, 0), "burst": 1.0},
	"shells": {"c": Color(0.72, 0.1, 0.07), "box": Vector3(0.022, 0.022, 0.065), "n": 2, "life": 0.7,
		"v": Vector2(0.8, 1.6), "spread": 35.0, "g": Vector3(0, -9.8, 0), "burst": 1.0},
	"impact": {"c": Color(0.95, 0.9, 0.8), "c2": Color(0.55, 0.08, 0.06), "n": 10, "life": 0.3, "size": 0.05,
		"v": Vector2(1.0, 2.6), "spread": 55.0, "g": Vector3(0, -6, 0), "burst": 1.0},
	"splatter": {"c": Color(0.2, 0.02, 0.02), "c2": Color(0.06, 0.01, 0.01), "n": 12, "life": 0.5, "size": 0.05,
		"v": Vector2(1.2, 3.2), "spread": 40.0, "g": Vector3(0, -9.8, 0), "burst": 1.0},  # a hit on flesh (Feel)
	"ricochet": {"c": Color(1.0, 0.9, 0.55), "c2": Color(1.0, 0.45, 0.12), "n": 7, "life": 0.22, "size": 0.03,
		"v": Vector2(2.0, 5.0), "spread": 35.0, "g": Vector3(0, -6, 0), "add": true, "burst": 1.0},  # a round off a wall
	"thud": {"c": Color(0.6, 0.58, 0.52, 0.5), "n": 8, "life": 0.6, "size": 0.08, "v": Vector2(0.3, 1.0),
		"spread": 50.0, "g": Vector3(0, -1, 0), "burst": 1.0},
	"splash": {"c": Color(0.5, 0.36, 0.18, 0.85), "n": 16, "life": 0.6, "size": 0.045, "v": Vector2(1.0, 2.5),
		"spread": 60.0, "g": Vector3(0, -9.8, 0), "burst": 1.0},
}
const ITEMS := {  ## kind: [tells, stand-in box size (ZERO = no model, e.g. the radio already in the map), colour]
	"ammo_box": [["brass"], Vector3(0.14, 0.07, 0.09), Color(0.35, 0.3, 0.18)],
	"bandage": [["motes"], Vector3(0.08, 0.06, 0.08), Color(0.9, 0.88, 0.82)],
	"bottle": [["glass"], Vector3(0.08, 0.24, 0.08), Color(0.25, 0.5, 0.3)],
	"flares": [["sparks", "wisp"], Vector3(0.12, 0.04, 0.1), Color(0.75, 0.15, 0.08)],
	"mask_filter": [["mist"], Vector3(0.09, 0.05, 0.09), Color(0.3, 0.35, 0.3)],
	"gas_mask": [["mist"], Vector3(0.2, 0.16, 0.14), Color(0.2, 0.26, 0.2)],
	"smoke_can": [["puffs"], Vector3(0.07, 0.14, 0.07), Color(0.42, 0.42, 0.4)],
	"key_part": [["shimmer"], Vector3(0.05, 0.02, 0.1), Color(0.8, 0.65, 0.3)],
	"note": [["dust"], Vector3(0.14, 0.005, 0.1), Color(0.92, 0.88, 0.78)],
	"ledger": [["dust"], Vector3(0.2, 0.04, 0.28), Color(0.3, 0.18, 0.1)],
	"photo": [["dust"], Vector3(0.1, 0.005, 0.14), Color(0.8, 0.78, 0.7)],
	"drawing": [["dust"], Vector3(0.2, 0.005, 0.28), Color(0.95, 0.92, 0.85)],
	"recorder": [["led"], Vector3(0.12, 0.04, 0.08), Color(0.15, 0.15, 0.16)],
	"lockpick": [["glint"], Vector3(0.1, 0.01, 0.03), Color(0.6, 0.6, 0.65)],
	"car_battery": [["battery"], Vector3(0.34, 0.22, 0.2), Color(0.12, 0.12, 0.13)],
	"radio": [["static", "rings"], Vector3.ZERO, Color()],
	# weapons lying where they can be found, and their ammo
	"axe": [["glint"], Vector3(0.06, 0.04, 0.8), Color(0.6, 0.15, 0.1)],
	"bat": [["glint"], Vector3(0.06, 0.06, 0.86), Color(0.45, 0.3, 0.18)],
	"bow": [["glint"], Vector3(0.05, 1.2, 0.08), Color(0.35, 0.22, 0.12)],
	"shotgun": [["glint"], Vector3(0.05, 0.1, 1.05), Color(0.2, 0.18, 0.16)],
	"arrow": [["glint"], Vector3(0.02, 0.02, 0.74), Color(0.4, 0.3, 0.2)],
	"shells": [["brass"], Vector3(0.11, 0.06, 0.07), Color(0.6, 0.1, 0.08)],
}

static var _mats := {}
static var _ring_tex: Texture2D


static func model(kind: String) -> Node3D:
	## The item's model: origin bottom centre (car battery: centred, terminals up). Null for fx-only kinds.
	var path := "res://models/item_%s.glb" % kind
	var ps: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	if ps:
		return ps.instantiate()
	var row: Array = ITEMS.get(kind, [[], Vector3(0.08, 0.06, 0.08), Color(0.5, 0.48, 0.44)])
	var size: Vector3 = row[1]
	if size == Vector3.ZERO:
		return null
	var mesh: PrimitiveMesh
	if kind in ["bottle", "smoke_can"]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = size.x * (0.25 if kind == "bottle" else 0.5)
		cyl.bottom_radius = size.x * 0.5
		cyl.height = size.y
		mesh = cyl
	else:
		var b := BoxMesh.new()
		b.size = size
		mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = row[2]
	mat.roughness = 0.6
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = 0.0 if kind == "car_battery" else size.y / 2.0
	var root := Node3D.new()
	root.add_child(mi)
	return root


static func item(kind: String) -> Node3D:
	## Model + its tells (+ a flickering green light on a radio). Bottom centre at the origin.
	var root := Node3D.new()
	var m := model(kind)
	if m:
		root.add_child(m)
		if kind == "car_battery":
			m.position.y = 0.11
	for f in ITEMS[kind][0]:
		(m if m else root).add_child(emit(f))
	if kind == "radio":
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 1.0, 0.6)
		l.light_energy = 0.6
		l.omni_range = 2.5
		l.position.y = 0.15
		l.set_script(load("res://scripts/flicker.gd"))
		l.set("chance", 0.3)
		root.add_child(l)
	return root


static func bounds(n: Node3D, xf := Transform3D()) -> AABB:
	## Mesh bounds of an item in its own space (works out of the tree too).
	var box := AABB()
	for c in n.get_children():
		if not c is Node3D:
			continue
		var t: Transform3D = xf * (c as Node3D).transform
		var b := AABB()
		if c is MeshInstance3D and (c as MeshInstance3D).mesh:
			b = t * (c as MeshInstance3D).get_aabb()
		var sub := bounds(c, t)
		if sub.size != Vector3.ZERO:
			b = sub if b.size == Vector3.ZERO else b.merge(sub)
		if b.size != Vector3.ZERO:
			box = b if box.size == Vector3.ZERO else box.merge(b)
	return box


static func grip(item: Node3D) -> Transform3D:
	## Where an item sits in a right-hand bone (fingers -Y, thumb side +Z, palm +X), worked out from its shape so
	## any model fits: papers pinched at their near edge, face toward the thumb; long things (keys, syringes,
	## irons, rods) through the fist near their + end, business end out past the thumb; the rest in the fingers.
	var box := bounds(item)
	var s := box.size
	var face := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))  # item +Y → thumb, item -Z → fingers
	var dims := [s.x, s.y, s.z]
	var a: int = dims.find(dims.max())
	var others: Array = dims.duplicate()
	others.remove_at(a)
	if s.y < 0.03 and maxf(s.x, s.z) > 0.06:  # paper, card, photo, file
		var edge := Vector3(box.get_center().x, box.end.y, box.end.z - 0.025)
		return Transform3D(face, Vector3(0.005, -0.1, 0.03) - face * edge)
	if dims[a] > 2.2 * float(others.max()) and dims[a] > 0.08:
		var axis := Vector3.ZERO
		axis[a] = 1.0
		var b := Basis(Vector3.UP, PI) if a == 2 else Basis(Quaternion(axis, Vector3.FORWARD))
		var handle := box.get_center()
		handle[a] = box.end[a] - 0.22 * dims[a]
		return Transform3D(b, Vector3(0.015, -0.08, 0.0) - b * handle)
	return Transform3D(face, Vector3(0.02, -0.1, 0.03) - face * box.get_center())


static func emit(preset: String) -> CPUParticles3D:
	## A running emitter for `preset` (world-space particles: a moving emitter leaves a trail).
	var s: Dictionary = P[preset]
	var c: Color = s.c
	var p := CPUParticles3D.new()
	if s.has("box"):
		var b := BoxMesh.new()
		b.size = s.box
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.5
		m.roughness = 0.4
		b.material = m
		p.mesh = b
	else:
		var q := QuadMesh.new()
		q.size = Vector2.ONE * s.get("size", 0.03)
		q.material = _mat(s.get("add", false), s.get("ring", false))
		p.mesh = q
		var init := Gradient.new()
		init.set_color(0, c)
		init.set_color(1, s.get("c2", c))
		p.color_initial_ramp = init
		var fade := Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.set_color(1, Color(1, 1, 1, 0))
		var f: float = s.get("fade", 1.0)
		if f < 1.0:
			fade.add_point(f, Color(1, 1, 1, 0))
		p.color_ramp = fade
		if s.get("ring", false):
			var grow := Curve.new()
			grow.add_point(Vector2(0, 0.15))
			grow.add_point(Vector2(1, 1))
			p.scale_amount_curve = grow
	p.amount = s.get("n", 4)
	p.lifetime = s.get("life", 1.0)
	p.explosiveness = s.get("burst", 0.0)
	p.direction = s.get("dir", Vector3.UP)
	p.spread = s.get("spread", 180.0)
	var v: Vector2 = s.get("v", Vector2.ZERO)
	p.initial_velocity_min = v.x
	p.initial_velocity_max = v.y
	p.gravity = s.get("g", Vector3.ZERO)
	var r: float = s.get("r", 0.0)
	if r > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = r
	p.position = s.get("at", Vector3.ZERO)
	return p


static func burst(parent: Node, pos: Vector3, preset: String, dir := Vector3.UP, amount := 0) -> void:
	## One-shot `preset` at pos, fired along dir (world); frees itself when done.
	var p := emit(preset)
	p.one_shot = true
	p.direction = dir
	if amount > 0:
		p.amount = amount
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _mat(add: bool, ring: bool) -> StandardMaterial3D:
	var k := int(add) + 2 * int(ring)
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.albedo_texture = _ring_texture() if ring else Interactable._dot_texture()
		_mats[k] = m
	return _mats[k]


static func _ring_texture() -> Texture2D:
	if not _ring_tex:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.7, Color(1, 1, 1, 0))
		g.add_point(0.85, Color(1, 1, 1, 1))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 32
		t.height = 32
		_ring_tex = t
	return _ring_tex
