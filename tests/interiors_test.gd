extends SceneTree
## Headless check of the furnished interiors (tools/models_hd_civic.py, interior_kit.py): both staircases
## (school, clinic) are walked up to the first floor with real input, and every scripted point the
## chapter 2 missions put people or things on inside the school and the clinic is open floor (patrols, Nora's
## route, spawns, kerosene, loot, the roof hatch landing), not inside a wall or a desk.
## flatpak run org.godotengine.Godot --headless --path . -s tests/interiors_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("INTERIORS FAIL: " + msg)
	quit(1)


func _climb(player: CharacterBody3D, start: Vector3, yaw: float) -> float:
	player.respawn(start, yaw)
	player.pivot.rotation.y = yaw + PI  # camera behind: forward = the facing
	for i in 20:
		await physics_frame
	Input.action_press("move_forward")
	var top := 0.0
	for i in 60 * 5:
		await physics_frame
		top = maxf(top, player.global_position.y)
	Input.action_release("move_forward")
	return top


func _run() -> void:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	var player: CharacterBody3D = world.get_node("Player")
	for i in 30:
		await physics_frame
	var d: Chapter1Director = world.get_node("Chapter1")
	for s in [["school", Vector3(105.6, 0.1, -2.75), PI / 2.0], ["clinic", Vector3(66.2, 0.1, -102.9), PI]]:
		var top: float = await _climb(player, s[1], s[2])
		if top < 3.7:
			return _fail("the %s stairs top out at %.2f m" % [s[0], top])
	var pts := [Chapter2Director.NORA_SPAWN, Chapter2Director.HATCH, Chapter2Director.JULIAN_SPAWN,
		Vector3(103.5, 0, -14), Vector3(103.5, 0, 14), Vector3(106.5, 0, 16), Vector3(106.5, 0, 9.5),
		Vector3(106.5, 0, -12), Vector3(106.5, 0, -5.8), Vector3(104.2, 0, -5.2), Vector3(106.5, 0, -5.2),
		Vector3(104, 0, 0), Vector3(104.2, 0, 6.2), Vector3(106.5, 0, 6.2), Vector3(106.5, 0, 8.6),
		Vector3(112, 0, 8.6), Vector3(106.5, 0, 15.5), Vector3(104, 0, -15), Vector3(104, 0, 15),
		Vector3(102.5, 0, -2), Vector3(102.5, 0, 2), Vector3(103, 0, -10), Vector3(112.5, 0, 4.6), Vector3(103, 0, -16.5),
		Vector3(112, 0, 16.8), Vector3(106.4, 0, 12.2), Vector3(67.5, 0, -111.2), Vector3(67.5, 0, -88),
		Vector3(77.8, 0, -88), Vector3(77.8, 0, -96), Vector3(71, 0, -108), Vector3(66, 0, -88), Vector3(78, 0, -110)]
	for p in pts:
		if d._stand(p) == Vector3.INF:
			return _fail("%s is blocked (in a wall / furniture)" % p)
	# every doorway can be walked through: open floor a step either side (school: x = 108 - lz, z = lx;
	# clinic: x = 72 - lz, z = -100 + lx; model-space door centres from tools/models_hd_civic.py)
	var doors := []  # [label, world point either side...]
	for lx in [-15.3, -5.2, 2.2, 6.2, 15.0]:
		doors.append(["school door x%.1f" % lx, Vector3(108 - 1.7, 0.05, lx), Vector3(108 - 3.1, 0.05, lx)])
	for lx in [-8.5, 3.0, 12.5]:
		doors.append(["school upstairs x%.1f" % lx, Vector3(108 + 5.1, 3.85, lx), Vector3(108 + 3.7, 3.85, lx)])
	doors.append(["clinic morgue", Vector3(72 - 4.5, 0.05, -100 - 10.1), Vector3(72 - 4.5, 0.05, -100 - 8.7)])
	for lx in [-6.0, 0.4]:
		doors.append(["clinic back x%.1f" % lx, Vector3(72 + 1.9, 0.05, -100 + lx), Vector3(72 + 0.5, 0.05, -100 + lx)])
	for lx in [-5.7, 1.5, 9.4]:
		doors.append(["clinic upstairs N x%.1f" % lx, Vector3(72 + 1.7, 3.85, -100 + lx), Vector3(72 + 0.3, 3.85, -100 + lx)])
	for lx in [-1.6, 5.0, 11.0]:
		doors.append(["clinic upstairs S x%.1f" % lx, Vector3(72 - 0.3, 3.85, -100 + lx), Vector3(72 - 1.7, 3.85, -100 + lx)])
	doors.append(["clinic entrance", Vector3(72 - 6.1, 0.05, -100), Vector3(72 - 7.8, 0.05, -100)])
	doors.append(["school entrance", Vector3(108 - 6.1, 0.05, 0), Vector3(108 - 7.8, 0.05, 0)])
	for door in doors:
		for p in door.slice(1):
			if d._stand(p) == Vector3.INF:
				return _fail("%s: blocked at %s" % [door[0], p])
	print("INTERIORS OK")
	quit(0)
