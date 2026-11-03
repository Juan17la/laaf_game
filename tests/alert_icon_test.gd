extends SceneTree
## Headless check of the enemy "?" / "!" icon (scripts/alert_icon.gd): it rides over the enemy's head, and it isn't
## drawn through the world: a suspicious Marked One in the school's corridor shows no icon to an Alex outside the
## front wall (it used to float over the brickwork, and in a crowd looked detached from the visible bodies), and
## shows it once he's inside with a clear view.
## godot --headless --path . -s tests/alert_icon_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("ALERT ICON FAIL: " + msg)
	quit(1)


func _icon(e: Enemy) -> AlertIcon:
	for c in e.get_children():
		if c is AlertIcon:
			return c
	return null


func _look(player: CharacterBody3D, at: Vector3) -> void:
	var d := at - player.global_position
	player.pivot.global_rotation.y = atan2(-d.x, -d.z)


func _run() -> void:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	var player: CharacterBody3D = world.get_node("Player")
	var d: Chapter1Director = world.get_node("Chapter1")
	for i in 30:
		await physics_frame
	# behind the school's front wall (corridor), Alex outside it, the wall square between them
	var spot := Vector3(103.5, 0.05, -7.0)
	var e := Enemy.spawn(d, "res://models/char_marked_man.glb", spot, PI / 2.0)
	for i in 10:
		await physics_frame
	e.sight_range = 0.0  # (it mustn't see him and charge: only its icon is under test)
	player.respawn(Vector3(97.0, 0.1, -7.0), PI / 2.0)
	for i in 20:
		await physics_frame
	e.hear(spot + Vector3(-1, 0, 0), 999.0)  # a sound outside: suspicious, "?"
	_look(player, spot)
	for i in 20:
		await physics_frame
	var icon := _icon(e)
	if not icon or icon._shown != "?":
		return _fail("no \"?\" on a suspicious enemy (state %s)" % Enemy.State.keys()[e.state])
	var head := (e.get_node("Model") as Node3D).find_child("Head", true, false) as Node3D
	var over := icon.global_position - head.global_position
	if Vector2(over.x, over.z).length() > 0.05 or over.y < 0.1 or over.y > 1.0:
		return _fail("the icon isn't over the head: %s from it" % over)
	if icon.visible:
		return _fail("the \"?\" shows through the school's front wall")
	# inside, up the corridor from it: in plain view
	player.respawn(Vector3(103.2, 0.1, 1.5), PI)
	for i in 10:
		e.hear(e.global_position + Vector3(0, 0, 1), 999.0)  # (keeps it suspicious, on the spot)
		_look(player, e.global_position)
		await physics_frame
	if not icon.visible:
		return _fail("the \"?\" is hidden with the enemy in plain view")
	print("ALERT ICON OK")
	quit(0)
