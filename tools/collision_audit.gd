extends SceneTree
## Collision audit of the generated map: walks maps/hollowmere.tscn (as the game loads it, models imported) and
## lists what the player can bump into but would walk through:
##   1. model instances with no collision at all (no CollisionObject3D anywhere under them), grouped by model
##   2. big visible parts of models that DO have collision but sit outside every collider of their instance
##      (a wall or plank panel left in a model's "detail" node, a door leaf, ...)
##   3. collision that is a single-sided sheet (a ConcavePolygonShape3D with no thickness: walkable from behind)
##   4. (with --ch1) walk-through spots: a player-sized capsule swept over every floor of the Chapter 1 zones that
##      touches no collider but does touch visible geometry (furniture built of thin parts, stacked boxes, ...)
## Skipped: things meant to be passable (PASSABLE: grass, decals, wires, ...), parts too small to matter
## (MIN_SIZE), out of reach (bottom above REACH_TOP over the ground under them) or under the ground.
## --ch1 also restricts 1-3 to the Chapter 1 zones (CH1_ZONES).
## Exit code 1 when anything is listed, so it can gate a regenerate.
##   godot --headless --path . -s tools/collision_audit.gd [-- --verbose] [--ch1]

const MAP := "res://maps/hollowmere.tscn"
## model names (substrings) the player is meant to pass through / never reach. Same rules as the generator's
## collision pass (tools/build_assets.py PASSABLE_TEX / PASSABLE_NODES): foliage and ground paving are walked through.
const PASSABLE := ["grass", "decal", "wire", "powerline_cable", "fern", "weed", "moss", "cobweb", "fog", "leaves",
	"litter", "puddle", "stain", "graffiti", "flower", "glow_fungus", "festival_lantern", "green_lantern", "paper",
	"ivy", "reeds", "mist", "candle", "terrain_detail", "blood", "bush", "slabs"]
## mesh nodes (prefixes) inside a model that are foliage: a tree's crown, a hedge's leafy top; open door leaves
const PASSABLE_PARTS := ["needles", "branches", "leaves", "ajar_leaves", "curtain_cloth"]
const MIN_SIZE := 0.35  ## m: a part whose two largest sides are both under this is ankle clutter, not a wall
const REACH_TOP := 1.85  ## m over the floor under it (Alex's height): a part starting higher is out of reach
const PART_MIN_AREA := 0.35  ## m² of vertical face (width × height) for a part of a collided model to be listed
const PROTRUDE := 0.15  ## m a part may stand proud of its model's colliders before it counts as walk-through
## Chapter 1's zones (tools/build_assets.py W.zone): x0, z0, x1, z1
const CH1_ZONES := {"Town Square": [-35, -35, 35, 35], "Lakeview Motel": [-135, 40, -75, 105],
	"Pinewood Forest & Sawmill": [-165, -70, -75, 45], "Collapsed Bridge": [-125, 128, -75, 190]}
const SWEEP_STEP := 0.3  ## m between capsule probes
const SWEEP_LAYER := 1 << 19  ## the visible-only meshes' stand-in colliders (section 4)
const SWEEP_LOW := 0.35  ## m: the probe starts this far over the floor (ankle clutter is stepped over)

var _verbose := false
var _ch1 := false
var _space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_verbose = "--verbose" in OS.get_cmdline_user_args()
	_ch1 = "--ch1" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _in_ch1(p: Vector3) -> bool:
	for z in CH1_ZONES.values():
		if p.x >= z[0] and p.x <= z[2] and p.z >= z[1] and p.z <= z[3]:
			return true
	return false


func _run() -> void:
	var world: Node3D = (load(MAP) as PackedScene).instantiate()
	for d in ["Chapter1", "Chapter2", "Chapter3"]:  # the directors stay dormant: only the static map is audited
		var n := world.get_node_or_null(d)
		if n:
			n.set_script(null)
	var p := world.get_node_or_null("Player")
	if p:
		world.remove_child(p)
		p.free()
	root.add_child(world)
	for i in 4:
		await physics_frame
	_space = world.get_world_3d().direct_space_state
	var bare := {}  ## model -> [positions]
	var parts := {}  ## model -> {part: [positions]}
	var sheets := {}  ## model -> {part: true}
	var done := {}  ## model -> [[part, local box], ...] of uncovered parts (worked out once per model)
	for n in world.find_children("*", "Node3D", true, false):
		var path := (n as Node).scene_file_path
		if not path.ends_with(".glb"):
			continue
		var model := path.get_file().get_basename()
		if _passable(model):
			continue
		var inst := n as Node3D
		if _ch1 and not _in_ch1(inst.global_position):
			continue
		if inst.find_children("*", "CollisionObject3D", true, false).is_empty():
			if _touchable(_aabb(inst), inst.global_position):
				bare.get_or_add(model, []).append(inst.global_position)
			continue
		if not done.has(model):
			done[model] = _model_parts(inst, sheets.get_or_add(model, {}))
		for pb in done[model]:
			var box: AABB = inst.global_transform * (pb[1] as AABB)
			if _touchable(box, inst.global_position):
				parts.get_or_add(model, {}).get_or_add(pb[0], []).append(inst.global_position)
	var total := 0
	print("\n== 1. touchable models with NO collision ==")
	for model in _sorted(bare):
		total += bare[model].size()
		print("  %-28s x%-3d at %s" % [model, bare[model].size(), _list(bare[model])])
	print("\n== 2. big parts outside every collider (models that have collision) ==")
	for model in _sorted(parts):
		for key in parts[model]:
			total += 1
			print("  %-28s %s  (x%d: %s)" % [model, key, parts[model][key].size(), _list(parts[model][key])])
	print("\n== 3. single-sided collision sheets (no thickness, within reach) ==")
	for model in _sorted(sheets):
		for key in sheets[model]:
			total += 1
			print("  %-28s %s" % [model, key])
	if _ch1:
		print("\n== 4. walk-through spots in the Chapter 1 zones (capsule sweep) ==")
		var spots := await _sweep(world)
		for key in _sorted(spots):
			total += 1
			print("  %-44s x%-4d at %s" % [key, spots[key].size(), _list(spots[key])])
	print("\nCOLLISION AUDIT: %d finding(s)" % total)
	quit(1 if total > 0 else 0)


func _sweep(world: Node3D) -> Dictionary:
	## "model/mesh node" -> [one position per 1 m cell]: where a standing player (a capsule from SWEEP_LOW up to head
	## height) overlaps that visible-only mesh without touching any real collider.
	for n in world.find_children("*", "Node3D", true, false):
		var path := (n as Node).scene_file_path
		if not path.ends_with(".glb") or not _in_ch1((n as Node3D).global_position):
			continue
		var model := path.get_file().get_basename()
		if _passable(model) or model == "terrain":
			continue
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			if not mi.mesh or not mi.find_children("*", "CollisionObject3D", false, false).is_empty():
				continue
			if PASSABLE_PARTS.any(func(p: String) -> bool: return str(mi.name).begins_with(p)):
				continue
			var body := StaticBody3D.new()
			body.collision_layer = SWEEP_LAYER
			body.collision_mask = 0
			body.set_meta("label", "%s/%s" % [model, mi.name])
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			shape.set_faces(mi.mesh.get_faces())
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			mi.add_child(body)
	for i in 2:
		await physics_frame
	var cap := CapsuleShape3D.new()  # the player (radius a little under his 0.3)
	cap.radius = 0.28
	cap.height = 1.75 - SWEEP_LOW
	var core := CapsuleShape3D.new()  # what visible geometry must reach into to count (PROTRUDE allowed, as in 2.)
	core.radius = cap.radius - PROTRUDE
	core.height = cap.height
	var q := PhysicsShapeQueryParameters3D.new()
	var out := {}
	var cells := {}
	for zone in CH1_ZONES.values():
		var x: float = zone[0]
		while x <= zone[2]:
			var z: float = zone[1]
			while z <= zone[3]:
				for g in _floors(x, z):
					q.transform = Transform3D(Basis(), Vector3(x, g + SWEEP_LOW + cap.height / 2.0, z))
					q.shape = cap
					q.collision_mask = 1
					if not _space.intersect_shape(q, 1).is_empty() or _in_wall(Vector3(x, g, z)):
						continue
					q.shape = core
					q.collision_mask = SWEEP_LAYER
					for h in _space.intersect_shape(q, 4):
						var body: Node3D = h.collider
						for label in _parts_at(body, Vector3(x, g, z), core):
							var cell := "%s %d %d" % [label, floori(x), floori(z)]
							if not cells.has(cell):
								cells[cell] = true
								out.get_or_add(label, []).append(Vector3(x, g, z))
				z += SWEEP_STEP
			x += SWEEP_STEP
	return out


var _part_cache := {}  ## stand-in body -> [[box in the instance's model space, label], ...]


func _parts_at(body: Node3D, floor_at: Vector3, core: CapsuleShape3D) -> Array[String]:
	## "model mesh (centre) size (size)" of the connected pieces of the body's mesh that reach into the probe (model
	## space of the instance: buildings and props only ever turn about Y, so the probe stays upright in it).
	var mi := body.get_parent() as MeshInstance3D
	var inst := mi.owner as Node3D if mi.owner else mi
	var inv := inst.global_transform.affine_inverse()
	if not _part_cache.has(body):
		var parts := []
		for c in _pieces(inv * mi.global_transform, mi.mesh.get_faces()):
			parts.append([c, "%s/%s %s" % [body.get_meta("label").get_slice("/", 0), mi.name, _box(c)]])
		_part_cache[body] = parts
	var p := inv * floor_at
	var lo := p.y + SWEEP_LOW
	var hi := lo + core.height
	var out: Array[String] = []
	for part in _part_cache[body]:
		var b: AABB = part[0]
		if b.end.y < lo or b.position.y > hi:
			continue
		var dx := maxf(maxf(b.position.x - p.x, p.x - b.end.x), 0.0)
		var dz := maxf(maxf(b.position.z - p.z, p.z - b.end.z), 0.0)
		if dx * dx + dz * dz <= core.radius * core.radius:
			out.append(part[1])
	return out


func _in_wall(p: Vector3) -> bool:
	## Collision is one-sided (rays and shapes only meet faces from the front): a capsule starting inside a wall or a
	## solid prop touches none of its faces. Over a point inside closed colliders there are more up-facing faces
	## (met by rays coming down) than down-facing ones (met by rays going up); and look in at p from just around it
	## (as Chapter1Director._stand does).
	for h in [0.5, 1.2]:
		var at: Vector3 = p + Vector3.UP * h
		if _crossings(at + Vector3.UP * 40.0, at) > _crossings(at, at + Vector3.UP * 40.0):
			return true
	for h in [0.5, 1.3]:
		for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var a: Vector3 = p + Vector3.UP * h + dir * 0.3
			if not _space.intersect_ray(PhysicsRayQueryParameters3D.create(a, p + Vector3.UP * h, 1)).is_empty():
				return true
	return false


func _crossings(from: Vector3, to: Vector3) -> int:
	## Faces (front sides) a ray from `from` to `to` meets on world collision.
	var n := 0
	var dir := (to - from).normalized()
	while n < 16:
		var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		if hit.is_empty():
			break
		n += 1
		from = (hit.position as Vector3) + dir * 0.002
	return n


func _floors(x: float, z: float) -> Array[float]:
	## Heights a player can stand at, at (x, z): the lowest walkable hit and any other within 0.45 m over it
	## (a porch deck, a raised floor), never a roof nor the top of furniture he'd have to climb (mantle: >= 0.5 m).
	var hits: Array[float] = []
	var top := 40.0
	for i in 8:
		var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, -20.0, z), 1))
		if hit.is_empty():
			break
		if hit.normal.y > 0.7:
			hits.append(hit.position.y)
		top = hit.position.y - 0.05
	if hits.is_empty():
		return hits
	var low: float = hits.min()
	return hits.filter(func(y: float) -> bool: return y <= low + 0.45)


func _passable(model: String) -> bool:
	for k in PASSABLE:
		if k in model:
			return true
	return false


func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "VisualInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func _ground(at: Vector3) -> float:
	## Height of the floor under `at` (the terrain, a floor, a stair), else `at` itself.
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 40.0)
	var hit := _space.intersect_ray(q)
	return hit.position.y if hit else at.y


func _touchable(box: AABB, origin: Vector3) -> bool:
	var s := box.size
	var dims := [s.x, s.y, s.z]
	dims.sort()
	if dims[1] < MIN_SIZE:  # a stick or a pebble
		return false
	var g := _ground(Vector3(box.get_center().x, minf(box.position.y, origin.y) + 0.05, box.get_center().z))
	return box.position.y - g < REACH_TOP and box.end.y > g + 0.15


func _big_part(box: AABB) -> bool:
	var s := box.size
	return maxf(s.x, s.z) * minf(s.y, REACH_TOP) >= PART_MIN_AREA and s.y >= 0.45


func _model_parts(inst: Node3D, sheets: Dictionary) -> Array:
	## [[label, box in the instance's space], ...]: connected pieces of visible-only geometry big enough to walk
	## into that no collider piece of the model overlaps. Flat collider pieces (sheets) go into `sheets`.
	var inv := inst.global_transform.affine_inverse()
	var cols: Array[AABB] = []
	var flat := {}  ## label -> box of every sheet-like collider piece
	for s in inst.find_children("*", "CollisionShape3D", true, false):
		var xf: Transform3D = inv * (s as Node3D).global_transform
		if s.shape is ConcavePolygonShape3D:
			for c in _pieces(xf, (s.shape as ConcavePolygonShape3D).get_faces()):
				var d := [c.size.x, c.size.y, c.size.z]
				d.sort()
				if d[0] < 0.01 and d[1] >= 0.5 and d[2] >= 0.5 and c.position.y < REACH_TOP and c.end.y > 0.15:
					flat["%s %s" % [s.get_parent().name, _box(c)]] = c
				else:
					cols.append(c)
		elif s.shape:
			cols.append(xf * s.shape.get_debug_mesh().get_aabb())
	for key in flat:  # a sheet backed by a solid collider (the generator's slab) is fine
		if not _covered(flat[key].grow(0.05), cols):
			sheets[key] = true
	cols.append_array(flat.values())
	var out := []
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if not mi.find_children("*", "CollisionObject3D", false, false).is_empty() or not mi.mesh:
			continue  # a "-col" mesh is its own collider
		if PASSABLE_PARTS.any(func(p: String) -> bool: return str(mi.name).begins_with(p)):
			continue
		for c in _pieces(inv * (mi as Node3D).global_transform, mi.mesh.get_faces()):
			if minf(c.size.x, minf(c.size.y, c.size.z)) < 0.01 and _covered(c.grow(0.12), cols):
				continue  # a decal laid on a wall (poster, graffiti): passable by design
			if _big_part(c) and not _covered(c, cols):
				out.append(["%s %s" % [mi.name, _box(c)], c])
	return out


func _pieces(xf: Transform3D, faces: PackedVector3Array) -> Array[AABB]:
	## Boxes of the connected pieces of a triangle soup (triangles sharing a corner belong together).
	var parent: Array[int] = []  # (an Array, not a packed one: _find compresses paths in place)
	parent.resize(faces.size() / 3)
	for i in parent.size():
		parent[i] = i
	var at := {}
	for i in faces.size():
		var v := faces[i]
		var key := Vector3i(roundi(v.x * 500.0), roundi(v.y * 500.0), roundi(v.z * 500.0))
		var t := i / 3
		if at.has(key):
			var a := _find(parent, t)
			var b := _find(parent, at[key])
			if a != b:
				parent[a] = b
		else:
			at[key] = t
	var boxes := {}
	for t in parent.size():
		var r := _find(parent, t)
		for k in 3:
			var v: Vector3 = xf * faces[t * 3 + k]
			if boxes.has(r):
				boxes[r] = (boxes[r] as AABB).expand(v)
			else:
				boxes[r] = AABB(v, Vector3.ZERO)
	var out: Array[AABB] = []
	for r in boxes:
		out.append(boxes[r])
	return out


func _find(parent: Array[int], i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


func _covered(c: AABB, cols: Array[AABB]) -> bool:
	## Does the piece stand clear of the colliders? Its core (PROTRUDE trimmed off each side across the ground: trim
	## and panels proud of a wall by less don't count) mostly inside collider boxes means it's covered.
	var core := c
	for ax in [0, 2]:
		var cut := minf(PROTRUDE, maxf(c.size[ax] - 0.02, 0.0) / 2.0)
		core.position[ax] += cut
		core.size[ax] -= 2.0 * cut
	core = core.grow(0.01)
	var vol := core.get_volume()
	var inside := 0.0
	for k in cols:
		var i := core.intersection(k.grow(0.05))
		if i.has_volume():
			inside += i.get_volume()
	return inside >= 0.5 * vol


func _box(b: AABB) -> String:
	return "%s size %s" % [_v(b.get_center()), _v(b.size)]


func _sorted(d: Dictionary) -> Array:
	var k := d.keys()
	k.sort()
	return k


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


func _list(ps: Array) -> String:
	var out := PackedStringArray()
	for p in ps.slice(0, 4 if not _verbose else ps.size()):
		out.append(_v(p))
	return " ".join(out) + (" …" if ps.size() > 4 and not _verbose else "")
