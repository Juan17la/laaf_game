extends SceneTree
## Collision audit of the generated map: walks maps/hollowmere.tscn (as the game loads it, models imported) and
## lists what the player can bump into but would walk through:
##   1. model instances with no collision at all (no CollisionObject3D anywhere under them), grouped by model
##   2. big visible parts of models that DO have collision but sit outside every collider of their instance
##      (a wall or plank panel left in a model's "detail" node, a door leaf, ...)
##   3. collision that is a single-sided sheet (a ConcavePolygonShape3D with no thickness: walkable from behind)
## Skipped: things meant to be passable (PASSABLE: grass, decals, wires, ...), parts too small to matter
## (MIN_SIZE), out of reach (bottom above REACH_TOP over the ground under them) or under the ground.
## Exit code 1 when anything is listed, so it can gate a regenerate.
##   godot --headless --path . -s tools/collision_audit.gd [-- --verbose]

const MAP := "res://maps/hollowmere.tscn"
## model names (substrings) the player is meant to pass through / never reach. Same rules as the generator's
## collision pass (tools/build_assets.py PASSABLE_TEX / PASSABLE_NODES): foliage and ground paving are walked through.
const PASSABLE := ["grass", "decal", "wire", "powerline_cable", "fern", "weed", "moss", "cobweb", "fog", "leaves",
	"litter", "puddle", "stain", "graffiti", "flower", "glow_fungus", "festival_lantern", "green_lantern", "paper",
	"ivy", "reeds", "mist", "candle", "terrain_detail", "blood", "bush", "slabs"]
## mesh nodes (prefixes) inside a model that are foliage: a tree's crown, a hedge's leafy top
const PASSABLE_PARTS := ["needles", "branches", "leaves"]
const MIN_SIZE := 0.35  ## m: a part whose two largest sides are both under this is ankle clutter, not a wall
const REACH_TOP := 1.85  ## m over the floor under it (Alex's height): a part starting higher is out of reach
const PART_MIN_AREA := 0.35  ## m² of vertical face (width × height) for a part of a collided model to be listed
const PROTRUDE := 0.15  ## m a part may stand proud of its model's colliders before it counts as walk-through

var _verbose := false
var _space: PhysicsDirectSpaceState3D


func _initialize() -> void:
	_verbose = "--verbose" in OS.get_cmdline_user_args()
	_run.call_deferred()


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
	print("\nCOLLISION AUDIT: %d finding(s)" % total)
	quit(1 if total > 0 else 0)


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
