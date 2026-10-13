extends SceneTree
## Headless check of what the player can't walk through (tools/build_assets.py auto_collision, the map's bodies):
##   props that had no collision now block (an eye door, an IV stand, trash bags, a broken bench), and so do the
##   lighthouse tower and the boathouse walls by the harbor
##   rolling and knee-sliding at full speed into walls (thick, thin, curved) never ends up on the other side
##   the camera never sits behind / inside a wall with Alex's back to it (it comes in closer instead)
##   the Harvester statue by the chapel blocks while it's there and not once it's away; the floodlight pole blocks
##   layers: Alex on 1 (mask 1 + 2), enemies on 2, the camera's spring arm only sees the world and never Alex
## godot --headless --path . -s tests/collision_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("COLLISION FAIL: " + msg)
	quit(1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> bool:
	## A 10 cm ball swept from `from` to `to` (world, layer 1) touches something on the way.
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.1
	q.shape = ball
	q.transform = Transform3D(Basis(), from)
	q.motion = to - from
	q.collision_mask = 1
	q.exclude = exclude
	return space.cast_motion(q)[0] < 1.0


func _centre(n: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "VisualInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_center()


func _instance(world: Node, model: String, near: Vector3) -> Node3D:
	var best: Node3D = null
	for n in world.find_children("*", "Node3D", true, false):
		if n.scene_file_path.ends_with("/%s.glb" % model) and (not best
				or n.global_position.distance_to(near) < best.global_position.distance_to(near)):
			best = n
	return best


func _ram(player: CharacterBody3D, start: Vector3, dir: Vector3, wall: Vector3, normal: Vector3, what: String) -> String:
	## Rolls, then knee-slides, at full speed from `start` along `dir` into a wall; "" if Alex stayed on his side.
	for move in ["roll", "roll", "slide", "slide"]:
		player.respawn(start, atan2(dir.x, dir.z))
		player.model.rotation.y = atan2(dir.x, dir.z)
		await _frames(8)
		player.stamina = player.stamina_max
		if move == "roll":
			player._start_roll()
		else:
			player.velocity = dir * player.sprint_speed
			player._start_slide()
		for i in 50:
			await physics_frame
			if (player.global_position - wall).dot(normal) < 0.0:
				return "%s: a %s went through (%s, wall at %s)" % [what, move, player.global_position, wall]
	return ""


func _run() -> void:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	await _frames(60)
	var player: CharacterBody3D = world.get_node("Player")
	var space := player.get_world_3d().direct_space_state

	# --- layers
	if player.collision_layer != 1 or player.collision_mask != 3:
		return _fail("player layer %d mask %d" % [player.collision_layer, player.collision_mask])
	var arm: SpringArm3D = player.arm
	if arm.collision_mask != 1:
		return _fail("spring arm mask %d (only the world)" % arm.collision_mask)
	var e := Enemy.spawn(world, "res://models/char_marked_man.glb", Vector3(-40, 0, 40), 0.0)
	await _frames(2)
	if e.collision_layer != 2 or e.collision_mask != 3:
		return _fail("enemy layer %d mask %d" % [e.collision_layer, e.collision_mask])
	e.queue_free()

	# --- props that used to have no collision
	for spec in [["int_eye_door", Vector3(105, 0.1, -17.8)], ["int_iv_stand", Vector3(75.4, 0.1, -95.4)],
			["town_trash_bags", Vector3(24.8, 0, -5.4)], ["park_bench_broken", Vector3(-4.4, 0, 18.4)]]:
		var n := _instance(world, spec[0], spec[1])
		if not n:
			return _fail("no %s near %s in the map" % spec)
		var c := _centre(n)
		var hit := false
		for side in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD]:
			var y := clampf(c.y, n.global_position.y + 0.25, n.global_position.y + 1.2)
			hit = hit or _blocked(space, Vector3(c.x, y, c.z) + side * 1.5, Vector3(c.x, y, c.z))
		if not hit:
			return _fail("%s at %s still lets things through" % spec)

	# --- full-speed rolls and slides into walls: the boathouse's plank back wall (0.2 m), the lighthouse tower
	# (round), a school partition (0.15 m)
	var bh := _instance(world, "boathouse", Vector3(12, 0, 108))
	var back := bh.global_transform * Vector3(0, 1.0, -5.0)  # its back wall, outside face (model z = -d / 2)
	var out_n := (bh.global_basis * Vector3(0, 0, -1)).normalized()
	var err: String = await _ram(player, back + out_n * 3.0 - Vector3.UP * 0.9, -out_n, back, out_n, "boathouse")
	if err != "":
		return _fail(err)
	var tower := Vector3(6, 0.1, 140)
	var tn := Vector3(1, 0, -1).normalized()
	err = await _ram(player, tower + tn * 7.0, -tn, tower + tn * 3.2, tn, "lighthouse")
	if err != "":
		return _fail(err)
	var corridor := Vector3(103.4, 1.0, -6.0)
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(corridor, corridor + Vector3.LEFT * 6.0, 1,
		[player.get_rid()]))
	if wall.is_empty():
		return _fail("school: no wall west of the corridor")
	err = await _ram(player, wall.position + wall.normal * 2.5 + Vector3.DOWN * 0.9, -wall.normal, wall.position,
		wall.normal, "school partition")
	if err != "":
		return _fail(err)
	print("rams: nobody through")

	# --- the camera with Alex's back to a wall: it comes in, it never goes behind / into the wall
	for shoulder in [1.0, -1.0]:
		player.respawn(back + out_n * 0.45 - Vector3.UP * 0.9, atan2(out_n.x, out_n.z))
		player._shoulder = shoulder
		player.pivot.rotation.y = atan2(out_n.x, out_n.z) + PI  # (the camera looks the way Alex faces: away)
		player.pitch.rotation.x = -0.2
		await _frames(40)
		var cam: Vector3 = player.camera.global_position
		if (cam - back).dot(out_n) < 0.05:
			return _fail("camera behind the wall (shoulder %d): %s" % [shoulder, cam])
		var head: Vector3 = player.global_position + Vector3.UP * player.pivot.position.y
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(head, cam, 1, [player.get_rid()])).is_empty():
			return _fail("a wall between Alex's head and the camera (shoulder %d)" % shoulder)
		if player.arm.get_hit_length() > player.arm.spring_length - 0.05:
			return _fail("the spring arm didn't come in against the wall")
	print("camera: stays out of the wall")

	# --- the statue by the chapel, the floodlight pole
	var boss := world.get_node("Props/Boss") as Node3D
	var at := boss.global_position + Vector3.UP * 1.2
	if not _blocked(space, at + Vector3.RIGHT * 2.0, at):
		return _fail("the Harvester statue doesn't block")
	Chapter3Director.show_boss_prop(boss, false)
	await _frames(3)
	if _blocked(space, at + Vector3.RIGHT * 2.0, at) or boss.visible:
		return _fail("the statue still blocks while it's away")
	Chapter3Director.show_boss_prop(boss, true)
	await _frames(3)
	if not _blocked(space, at + Vector3.RIGHT * 2.0, at):
		return _fail("the statue doesn't block once it's back")
	var flood := Floodlight.make(world, Vector3(-40, 0, -40), Vector3(-40, 0, -30), player.hud)
	await _frames(3)
	if not _blocked(space, Vector3(-41.5, 1.0, -40), Vector3(-38.5, 1.0, -40)):
		return _fail("the floodlight pole doesn't block")
	flood.queue_free()
	print("COLLISION OK")
	quit(0)
