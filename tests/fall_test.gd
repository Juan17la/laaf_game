extends SceneTree
## Headless check of falling out of the world (player.gd FALL_Y): the running chapter director puts Alex back on
## its last checkpoint (not the scene's spawn), keeping health and stamina; after Chapter 2 takes over only its
## own checkpoint counts (Chapter 1's handler is disconnected); with no director listening, back to the spawn.
## godot --headless --path . -s tests/fall_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("FALL FAIL: " + msg)
	quit(1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _world(step: String) -> Node:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = step
	root.add_child(world)
	return world


func _drop(player: CharacterBody3D) -> void:
	player.global_position = Vector3(player.global_position.x, -40.0, player.global_position.z)
	await _frames(3)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	# Chapter 1: a checkpoint far from the spawn (the square), health stays what it was
	var world := _world("free")
	await _frames(60)
	var d: Chapter1Director = world.get_node("Chapter1")
	var player: CharacterBody3D = world.get_node("Player")
	var spawn: Vector3 = player._spawn
	var cp := Vector3(0, 0.1, 30)
	d._checkpoint_at(cp, PI)
	player.health = 55.0
	await _drop(player)
	if _flat(player.global_position, cp) > 2.5 or player.global_position.y < -1.0:
		return _fail("ch1: respawned at %s, checkpoint %s (spawn %s)" % [player.global_position, cp, spawn])
	if absf(player.health - 55.0) > 1.0:
		return _fail("ch1: a fall healed / hurt Alex: %.1f" % player.health)
	await _frames(30)
	if not player.is_on_floor() or _flat(player.global_position, cp) > 2.5:
		return _fail("ch1: not standing at the checkpoint after the fall: %s" % player.global_position)

	# no director listening: back to the scene's spawn, as before
	for c in player.fell.get_connections():
		player.fell.disconnect(c.callable)
	await _drop(player)
	if _flat(player.global_position, spawn) > 0.5:
		return _fail("no director: respawned at %s, spawn %s" % [player.global_position, spawn])
	world.queue_free()
	await _frames(5)

	# Chapter 2 took over: its checkpoint, and only one handler
	world = _world("zones")
	await _frames(90)
	var ch2: Chapter2Director = world.get_node("Chapter2")
	player = world.get_node("Player")
	if player.fell.get_connections().size() != 1 or not player.fell.is_connected(ch2._on_fell):
		return _fail("ch2: fell handlers %s" % [player.fell.get_connections()])
	var cp2 := Vector3(-6, 0.1, 116)  # the harbor dock
	ch2._checkpoint_at(cp2, PI / 2.0)
	await _drop(player)
	if _flat(player.global_position, cp2) > 2.5:
		return _fail("ch2: respawned at %s, checkpoint %s" % [player.global_position, cp2])
	print("FALL OK")
	quit(0)
