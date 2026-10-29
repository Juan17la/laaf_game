extends SceneTree
## Headless check of the cars and the fists slot:
##   cars (tools/models_hd_street.py body_col): Alex walking at a car from the front, back and both sides stops
##   outside its body (bumpers, hood, doors), for a parked car and for the intro's bridge car
##   a cinematic actor walking past a car stays on the road (Actor._ground: no climbing onto the hood)
##   fists: key 0 holsters, Q / the mouse wheel cycle fists → each weapon → fists, holding the gamepad's Y opens the
##   slowed wheel (its pick drawn on release) and tapping it swaps, holding Tab opens it at once with the items too
##   (letting go draws a weapon or uses an item), the double tap still works across a swap,
##   a snapshot keeps fists in hand
## godot --headless --path . -s tests/cars_fists_test.gd

var player: CharacterBody3D
var world: Node


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("CARS/FISTS FAIL: " + msg)
	quit(1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _press(action: String, pressed := true) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _pad_y(pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_Y
	e.pressed = pressed
	Input.parse_input_event(e)


func _walk_into(car: Node3D, side: Vector3) -> String:
	## Puts Alex 3 m off the car along `side` (car space), walks him at its centre for 2 s; "" if he stayed out.
	var out := car.global_transform * (side * 3.0)
	player.global_position = Vector3(out.x, car.global_position.y + 0.1, out.z)
	player.velocity = Vector3.ZERO
	await _frames(3)
	var to := (car.global_position - player.global_position)
	to.y = 0.0
	player.pivot.rotation.y = atan2(-to.x, -to.z)  # (the camera pivot looks down -Z: forward is toward the car)
	_press("move_forward")
	await _frames(120)
	_press("move_forward", false)
	await _frames(2)
	var lp := car.to_local(player.global_position)
	# body (with bumpers): local x ±2.3, z ±0.93; Alex's capsule is ~0.3 m round: his centre must stay outside
	if absf(lp.x) < 2.3 + 0.2 and absf(lp.z) < 0.93 + 0.2:
		return "walked into the car from %s: car-space %s" % [side, lp]
	return ""


func _run() -> void:
	world = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	player = world.get_node("Player")
	await _frames(30)

	# a parked car in the map (the one by the motel lot), and the intro's bridge car where the intro leaves it
	var parked: Node3D = null
	for n in world.find_children("*", "Node3D", true, false):
		if n.scene_file_path.ends_with("car_wreck.glb") and n.global_position.distance_to(Vector3(-86, 0, 52)) < 1.0:
			parked = n
	if not parked:
		return _fail("no parked car at (-86, 52)")
	var bridge: Node3D = (load("res://models/car_wreck.glb") as PackedScene).instantiate()
	world.add_child(bridge)
	bridge.global_position = Vector3(-99, 0, 146)
	bridge.rotation.y = PI / 2.0
	await _frames(5)
	for car in [parked, bridge]:
		for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(0.7, 0, 0.7)]:
			var bad: String = await _walk_into(car, side)
			if bad != "":
				return _fail(bad)

	# a stand-in walking right past the bridge car's fender stays on the road
	var a := Actor.make(world, "res://models/char_alex.glb", Vector3(-100.0, 0, 147.0), PI)
	await _frames(3)
	var top := 0.0
	a.walk_to(Vector3(-99.3, 0, 142.6), 1.8)  # (cuts the fender corner on purpose)
	while a.anim.speed > 0.0:  # (walk_to's tween zeroes the speed as it ends: no await on its signal, which may be gone)
		await physics_frame
		top = maxf(top, a.global_position.y)
	if top > 0.2:
		return _fail("the actor climbed onto the car: feet at %.2f m" % top)
	a.queue_free()
	player.global_position = Vector3(-86, 0.2, 60)
	await _frames(10)

	# fists
	var w: Weapons = player.weapons
	w.give("revolver", 24)
	w.give("flare", 4)
	w.swap(0)
	await _frames(30)
	_press("weapon_0")
	await _frames(2)
	_press("weapon_0", false)
	if w.gun() != "" or not w.holstered() or w.spec() != Weapons.FISTS:
		return _fail("key 0 did not put the weapons away: %s" % w.gun())
	var cycle: Array[String] = []
	for i in 3:
		_press("swap_weapon")
		await _frames(1)
		_press("swap_weapon", false)
		await _frames(1)
		cycle.append(w.gun())
	if cycle != ["revolver", "flare", ""]:
		return _fail("Q cycle should go fists → revolver → flare → fists, got %s" % [cycle])
	_pad_y(true)  # tap: a swap, on release
	await _frames(3)
	if w.gun() != "":
		return _fail("the pad's Y swapped on press, before its release")
	_pad_y(false)
	await _frames(2)
	if w.gun() != "revolver":
		return _fail("tapping Y did not swap (holding %s)" % w.gun())
	_pad_y(true)  # hold: the weapon wheel, the game slowed; pointing up picks the fists, letting go draws them
	await _frames(int(60 * (player.WHEEL_HOLD + 0.15)))
	if not player.wheel.visible or Engine.time_scale != WeaponWheel.SLOW:
		return _fail("holding Y did not open the slowed-down weapon wheel")
	if w.gun() != "revolver":
		return _fail("opening the wheel swapped (holding %s)" % w.gun())
	player.wheel.mouse(Vector2(0, -60))
	_pad_y(false)
	await _frames(2)
	if player.wheel.visible or Engine.time_scale != 1.0:
		return _fail("letting go of Y left the wheel up or the game slowed")
	if w.gun() != "":
		return _fail("the wheel's pick (fists, at the top) was not drawn (holding %s)" % w.gun())
	_press("wheel")  # hold Tab: the wheel at once, weapons then items; the revolver (slot 1, right of the top)
	await _frames(2)
	if not player.wheel.visible or Engine.time_scale != WeaponWheel.SLOW:
		return _fail("holding Tab did not open the slowed-down wheel")
	if not player.wheel.slots().any(func(s: Dictionary) -> bool: return s.item and s.id == "headlamp"):
		return _fail("the wheel lists no items (no headlamp)")
	player.wheel.sel = 1
	_press("wheel", false)
	await _frames(2)
	if player.wheel.visible or Engine.time_scale != 1.0 or w.gun() != "revolver":
		return _fail("letting go of Tab: wheel %s, scale %.2f, holding %s" % [player.wheel.visible, Engine.time_scale, w.gun()])
	var lit: bool = player.flashlight.visible
	_press("wheel")
	await _frames(2)
	player.wheel.sel = player.wheel._slots.size() - 1  # the headlamp, last
	_press("wheel", false)
	await _frames(2)
	if player.flashlight.visible == lit:
		return _fail("picking the headlamp on the wheel didn't switch it")
	_press("wheel")  # a right click cancels: nothing picked, the game back to speed
	await _frames(2)
	player.wheel.sel = 0
	var rc := InputEventMouseButton.new()
	rc.button_index = MOUSE_BUTTON_RIGHT
	rc.pressed = true
	Input.parse_input_event(rc)
	await _frames(2)
	_press("wheel", false)
	await _frames(2)
	if player.wheel.visible or Engine.time_scale != 1.0 or w.gun() != "revolver":
		return _fail("a right click didn't cancel the wheel (holding %s)" % w.gun())
	w.holster()
	await _frames(2)
	# with fists out the HUD's ammo counter hides
	await process_frame
	if player.hud._ammo.visible:
		return _fail("the ammo counter shows with fists in hand")
	# fists → a gun right after a shot is still a double tap (and a gun → fists → gun cycle too)
	w.swap(0)
	await _frames(40)
	var space := player.get_world_3d().direct_space_state
	w.shoot(space, player.global_position + Vector3.UP * 50, Vector3.UP, [])
	w.swap(1)
	if not w.can_fire() or not w.shoot(space, player.global_position + Vector3.UP * 50, Vector3.UP, []).double_tap:
		return _fail("the swap-shot double tap broke")
	# a checkpoint restore keeps what's in hand, fists included; a snapshot taken with fists out says so
	var snap := w.snapshot()  # (the flare gun in hand)
	w.holster()
	w.restore(snap)
	if w.gun() != "":
		return _fail("restore() lost the fists in hand (holding %s)" % w.gun())
	if int(w.snapshot().current) != Weapons.HOLSTERED:
		return _fail("a snapshot with fists out doesn't say current %d" % Weapons.HOLSTERED)
	var fresh := Weapons.new()  # a save's current -1 (fists) loads as fists
	fresh.restore(w.snapshot())
	if fresh.gun() != "":
		return _fail("a save with fists out loaded with %s in hand" % fresh.gun())
	fresh.free()
	# an empty gun still strikes: fire with nothing to shoot swings
	w.swap(1)
	w.loaded.flare = 0
	w.reserve.flare = 0
	if not w.dry():
		return _fail("an empty flare gun isn't dry")
	print("CARS/FISTS OK")
	quit(0)
