extends SceneTree
## Headless check of carrying (player.gd carry(): both hands, walk only) against furniture and walls:
##   walking into a table, a counter, a shelf and a wall with the battery, Alex stops at it and neither he nor
##   the load he holds out in front ends up inside it; turning on the spot to face a wall pushes him back off it
##   the load's shape goes away with drop_carry()
##   empty-handed, the Chapter 1 interiors' furniture blocks (motel, diner, Grady's store, bar), the props that used
##   to be walked through included (vending machine, stools, feed sacks, a stack of stock boxes)
## godot --headless --path . -s tests/carry_test.gd

## [model, target (model space), start (model space), label]: walked from start straight at target
const INTO := [
	["motel", Vector3(11.2, 0, 1.5), Vector3(12.8, 0, 1.5), "motel room 6 table"],
	["motel", Vector3(10.4, 0, -1.1), Vector3(12.2, 0, -1.1), "motel room 6 dresser"],
	["diner", Vector3(1.5, 0, -2.2), Vector3(1.5, 0, 0.2), "diner counter"],
	["grady_store", Vector3(1.5, 0, -1.5), Vector3(2.75, 0, -1.5), "store shelf"],
	["bar", Vector3(1, 0, -3), Vector3(1, 0, -0.5), "bar counter"],
	["motel", Vector3(14.8, 0, 0.0), Vector3(13.2, 0, 0.0), "motel room 6 wall"],
]
const FURNITURE := [
	["motel", Vector3(-19.2, 0, 2.9), Vector3(-19.2, 0, 4.6), "motel vending machine"],
	["diner", Vector3(1.1, 0, -1.5), Vector3(1.1, 0, 0.3), "diner stool"],
	["bar", Vector3(0.9, 0, -2.1), Vector3(0.9, 0, -0.4), "bar stool"],
	["grady_store", Vector3(-5.1, 0, 4.3), Vector3(-5.1, 0, 2.6), "store feed sacks"],
	["grady_store", Vector3(4.8, 0, -4.6), Vector3(4.8, 0, -2.9), "store stock boxes"],
]

var player: CharacterBody3D
var world: Node


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("CARRY FAIL: " + msg)
	quit(1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _find(model: String) -> Node3D:
	for n in world.find_children("*", "Node3D", true, false):
		if n.scene_file_path.ends_with("/%s.glb" % model):
			return n
	return null


func _load_inside() -> String:
	## What the battery in Alex's hands (its visible box, a little smaller: touching is fine) overlaps in the world,
	## "" if nothing.
	var held: Node3D = player._carry_mesh
	var inv := held.global_transform.affine_inverse()
	var bounds := AABB()
	for mi in held.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = inv * (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		bounds = b if bounds.size == Vector3.ZERO else bounds.merge(b)
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = bounds.size - Vector3.ONE * 0.04
	q.shape = box
	q.transform = held.global_transform.orthonormalized() * Transform3D(Basis(), bounds.get_center())
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var hits := player.get_world_3d().direct_space_state.intersect_shape(q, 1)
	return "" if hits.is_empty() else str((hits[0].collider as Node).get_path())


func _walk(spec: Array, item: String) -> Array:
	## Walks from spec's start at its target for 3 s; [how far the body centre got along the way (m from the
	## start), whether the load ever ended up inside something ("" or what)].
	var b := _find(spec[0])
	var t: Vector3 = b.global_transform * spec[1]
	var s: Vector3 = b.global_transform * spec[2]
	s.y = b.global_position.y
	var dir := ((t - s) * Vector3(1, 0, 1)).normalized()
	player.drop_carry()
	player.respawn(s + Vector3.UP * 0.1, atan2(dir.x, dir.z))
	if item != "":
		player.carry(item)
	player.pivot.rotation.y = atan2(dir.x, dir.z) + PI
	await _frames(10)
	Input.action_press("move_forward")
	var inside := ""
	for i in 180:
		await physics_frame
		player.pivot.rotation.y = atan2(dir.x, dir.z) + PI
		if item != "" and inside == "":
			inside = _load_inside()
	Input.action_release("move_forward")
	await _frames(5)
	return [(player.global_position - s).dot(dir), inside]


func _run() -> void:
	world = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	player = world.get_node("Player")
	await _frames(60)

	for spec in INTO:
		var free: Array = await _walk(spec, "")
		var held: Array = await _walk(spec, "battery")
		var full: float = (spec[1] - spec[2]).length()  # walking all the way would reach the target's centre
		if free[0] > full - 0.3:
			return _fail("%s: empty-handed Alex walked into it (%.2f of %.2f m)" % [spec[3], free[0], full])
		if held[0] > full - 0.3 or held[0] > free[0] + 0.02:
			return _fail("%s: carrying, Alex got %.2f m in (%.2f empty-handed, %.2f to its centre)"
				% [spec[3], held[0], free[0], full])
		if held[1] != "":
			return _fail("%s: the carried battery went into %s" % [spec[3], held[1]])
		print("%-22s stopped: empty %.2f m, carrying %.2f m (of %.2f)" % [spec[3], free[0], held[0], full])

	# turning on the spot to face a wall (the room 6 back wall, Alex side-on to it) never leaves the load inside it
	var motel := _find("motel")
	var by_wall: Vector3 = motel.global_transform * Vector3(14.45, 0.1, 0.0)  # 0.35 m off the wall: room to turn
	var wall_dir: Vector3 = (motel.global_basis * Vector3(1, 0, 0)).normalized()
	player.drop_carry()
	player.respawn(by_wall, atan2(wall_dir.z, -wall_dir.x))  # side-on
	player.carry("battery")
	await _frames(5)
	var tw := create_tween()
	tw.tween_property(player.model, "rotation:y", atan2(wall_dir.x, wall_dir.z), 0.4)
	var into := ""
	for i in 60:
		await physics_frame
		if i > 30 and into == "":  # (the turn itself may graze it for a frame before he's pushed back)
			into = _load_inside()
	if into != "":
		return _fail("turned to face a wall, the battery stayed inside %s" % into)
	print("turned into a wall: pushed back off it")

	# drop_carry: the shape goes with the battery
	player.drop_carry()
	await _frames(2)
	var shapes := 0
	for c in player.get_children():
		if c is CollisionShape3D and not c.is_queued_for_deletion():
			shapes += 1
	if shapes != 1:
		return _fail("drop_carry left the load's shape on Alex (%d shapes)" % shapes)

	for spec in FURNITURE:
		var r: Array = await _walk(spec, "")
		var full: float = (spec[1] - spec[2]).length()
		if r[0] > full - 0.3:
			return _fail("%s: walked into it (%.2f of %.2f m)" % [spec[3], r[0], full])
		print("%-22s blocks: stopped %.2f m short of its centre" % [spec[3], full - r[0]])
	print("CARRY OK")
	quit(0)
