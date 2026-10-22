extends SceneTree
## Headless Chapter 1 playthrough, intro → blackout → Chapter 2's first step, the way a player would: every
## objective's marker is pressed for real (Interactable.interact), minigames are finished by emitting `done`, the
## boss is beaten down, the side missions (Room 4, the Tripwire) are done on the way.
##   -- --route=spare | kill   (Owen's fate; default spare)
## At every step it checks:
##   the objective is set and its target can be reached: open floor near it with a clear line (as reach_test)
##   save → load: Game.snapshot() taken at the step, loaded into a fresh world, starts that step again with the
##   same flags, inventory and weapons
## Prints the trail and "!!" for every problem; exit code = problem count (0 = clean).
##   godot --headless --path . -s tests/drivers/ch1_drive.gd [-- --route=kill]

const CH1 := ["intro", "room", "hunt", "square", "sawmill", "boss", "blackout"]

var world: Node
var ch1: Chapter1Director
var player: CharacterBody3D
var game: Node
var errors := 0
var route := "spare"
var saves := {}  ## step -> Game.snapshot() taken as the step began


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--route="):
			route = a.substr(8)
	Engine.time_scale = 4.0  # cinematics play out in real time otherwise
	_run.call_deferred()


func _bad(msg: String) -> void:
	errors += 1
	print("!! ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _until(c: Callable, timeout := 120.0) -> bool:
	var t := 0.0
	while t < timeout and not c.call():
		await physics_frame
		t += 1.0 / 60.0 * Engine.time_scale
	return c.call()


func _in_control(timeout := 120.0) -> bool:
	return await _until(func() -> bool: return player.controls_enabled and not player.dead, timeout)


func _marker(prompt: String) -> Interactable:
	for n in get_nodes_in_group("interactable"):
		if n.enabled and n.prompt.begins_with(prompt):
			return n
	return null


func _use(prompt: String, timeout := 60.0) -> bool:
	## Walks up to the marker (a standable spot within reach, as a player would), presses E.
	var found: Array = [null]  # (lambdas capture by value: an array to hand the marker out)
	await _until(func() -> bool:
		found[0] = _marker(prompt)
		return found[0] != null and player.controls_enabled, timeout)
	var m: Interactable = found[0]
	if not m:
		_bad("no '%s' marker (step %s, controls %s)" % [prompt, ch1.step, player.controls_enabled])
		return false
	var at := _reach_spot(m.global_position)
	if at == Vector3.INF:
		_bad("'%s' at %s: nowhere to stand and reach it" % [prompt, m.global_position])
		at = m.global_position + Vector3(0.6, -0.8, 0)
	player.global_position = at
	await _frames(2)
	if player.interact_target() != m:
		_bad("'%s': E from %s picks %s" % [prompt, at, player.interact_target().prompt if player.interact_target() else "nothing"])
	m.interact(player)
	print("  used '%s'" % prompt)
	return true


func _reach_spot(target: Vector3) -> Vector3:
	## Somewhere the player stands with the target in reach (player.gd interact_target / _within_reach).
	for r in [0.6, 0.9, 1.2, 1.5]:
		for i in 12:
			var p := target + Vector3(r, 0, 0).rotated(Vector3.UP, TAU * i / 12.0)
			var g := ch1._stand(Vector3(p.x, target.y - 0.1, p.z))
			if g == Vector3.INF:
				continue
			player.global_position = g
			if target.distance_to(g + Vector3.UP * 0.9) < 2.2 and player._within_reach(target):
				return g
	return Vector3.INF


func _game(cls: Variant, args: Array) -> void:
	## Finishes the minigame that just opened on the HUD.
	var found: Array = []
	await _until(func() -> bool:
		for n in player.hud.get_children():
			if is_instance_of(n, cls):
				found.append(n)
				return true
		return false, 15)
	if found.is_empty():
		_bad("no minigame %s" % cls)
		return
	var g: Node = found[0]
	g.set_process(false)
	g.set_process_input(false)
	g.callv("emit_signal", ["done"] + args)
	g.queue_free()


func _check_objective() -> void:
	## The objective is set and its target reachable: open floor near it (markers: within reach of it).
	var text: String = ch1._objective_text
	var target: Variant = ch1._objective_target
	if text == "":
		return
	var at: Vector3
	if target is Node3D:
		at = (target as Node3D).global_position + Vector3.UP * 1.0
	elif target is Vector3:
		at = target
	else:
		return
	var found := false
	for r in [0.0, 1.0, 2.0, 3.0]:
		for i in (1 if r == 0.0 else 12):
			var p: Vector3 = at + Vector3(r, 0, 0).rotated(Vector3.UP, TAU * i / 12.0)
			if ch1._stand(Vector3(p.x, at.y + 0.5, p.z)) != Vector3.INF:
				found = true
				break
		if found:
			break
	if not found:
		_bad("objective '%s': no open floor near its target %s" % [text, at])


func _step(s: String, timeout := 240.0) -> bool:
	if not await _until(func() -> bool: return ch1.step == s, timeout):
		_bad("stuck before step %s (at %s, objective '%s', controls %s)" % [s, ch1.step, ch1._objective_text,
			player.controls_enabled])
		return false
	print("STEP ", s)
	if game and game.director == ch1:
		saves[s] = game.snapshot()
	return true


func _heal_loop() -> void:
	while is_instance_valid(player):
		await physics_frame
		if is_instance_valid(player) and player.health < 80.0 and ch1.step != "hunt":
			player.health = player.health_max


func _run() -> void:
	game = G.game()
	world = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "intro"
	root.add_child(world)
	ch1 = world.get_node("Chapter1")
	player = world.get_node("Player")
	_heal_loop()

	# C1.1 + C1.2 → room 6
	await _step("intro")
	await _step("room", 300)
	await _in_control()
	await _use("Examine the door")
	await _in_control()
	_check_objective()
	await _use("Read the note")
	await _in_control()
	_check_objective()
	await _use("Use the radio")
	await _game(RadioTuning, [])

	# M2: the hunt (Owen can't kill); Room 4 on the way out (side mission #11)
	await _step("hunt", 120)
	await _in_control()
	_check_objective()
	if not ch1._owen or ch1._owen.process_mode == Node.PROCESS_MODE_DISABLED:
		_bad("hunt: Owen isn't hunting once control is back")
	await _use("Pick the lock — Room 4")
	await _game(Lockpick, [true])
	await _in_control()
	if not ch1.flags.room4_open:
		_bad("Room 4: picked lock didn't set room4_open")
	await _use("Take Lucía's camera")
	await _frames(5)
	if 11 not in ch1.flags.evidence:
		_bad("Room 4: no evidence #11")
	player.global_position = Vector3(0, 0.2, 30)  # into the square's lights

	# M3: Grady, the guns, the tin moths
	await _step("square", 60)
	await _in_control()
	await _use("Talk to Grady")
	await _in_control(120)
	if player.weapons.gun() == "":
		_bad("square: Grady handed no gun over")
	var tokens: int = ch1.flags.tokens
	for t in ch1.get_children():
		if t is Chapter1Director.Target:
			t.hit(1.0, t.global_position)
	await _frames(3)
	if ch1.flags.tokens != tokens + 25:
		_bad("tin moths: tokens %d -> %d" % [tokens, ch1.flags.tokens])
	_check_objective()
	await _use("Tell Grady you're ready")

	# M4: the sawmill, the lantern, the ledger (#1), the key part; the Tripwire on the way (#2)
	await _step("sawmill", 120)
	await _in_control()
	_check_objective()
	for i in 3:
		await _use("Cut the tripwire")
		await _frames(5)
	if 2 not in ch1.flags.evidence:
		_bad("Tripwire: three wires cut, no evidence #2")
	await _use("Take the burnt festival lantern")
	await _use("Read the ledger")
	if 1 not in ch1.flags.evidence:
		_bad("sawmill: ledger read, no evidence #1")
	player.global_position = Chapter1Director.SAWMILL_ROAD + Vector3(0, 0.2, 0)
	await _until(func() -> bool: return _marker("Take the key part") != null, 30)
	_check_objective()
	await _use("Take the key part")

	# M4 boss: Owen down, then spared or killed
	await _step("boss", 120)
	await _in_control()
	_check_objective()
	var owen: Enemy = ch1._owen
	if not owen:
		_bad("boss: no Owen")
		quit(errors)
		return
	for k in 80:
		if owen.state == Enemy.State.DOWN:
			break
		await _in_control(60)
		if k == 0:  # he goes down in a burning fuel barrel's fire (the tactic the objective names)
			var fire := FuelBarrel.make(ch1, owen.global_position + Vector3(0.6, 0, 0))
			fire.hit(1.0, fire.global_position)
		owen.stun(1.0)
		owen.hit(60.0, owen.global_position + Vector3.UP * 0.5)
		await _frames(15)
	if owen.state != Enemy.State.DOWN:
		_bad("boss: Owen never went down (hp %.0f)" % owen.health)
	await _in_control(60)
	await _frames(90)  # the fire keeps burning round him
	if owen.state != Enemy.State.DOWN:
		_bad("boss: kneeling Owen didn't wait for the choice (state %d): the fire decided it" % owen.state)
	if route == "kill":
		owen.hit(1.0, owen.global_position + Vector3.UP)
	else:
		await _use("Spare Owen")
	await _step("blackout", 120)
	if ch1.flags.owen != ("killed" if route == "kill" else "spared"):
		_bad("Owen's fate: %s (route %s)" % [ch1.flags.owen, route])
	if route == "kill" or "bow" not in player.weapons.owned:
		pass
	# C1.3 → Chapter 2 takes over
	var ch2: Chapter2Director = world.get_node("Chapter2")
	if not await _until(func() -> bool: return ch2.step != "", 200):
		_bad("Chapter 2 never started after the blackout (ch1 step %s)" % ch1.step)
	else:
		print("STEP ch2:", ch2.step, "  flags owen=%s evidence=%s tokens=%d key=%s" % [ch2.flags.get("owen"),
			ch2.flags.get("evidence"), int(ch2.flags.get("tokens", 0)), ch2.flags.get("key_part")])

	# save → load at every Chapter 1 step
	world.queue_free()
	await _frames(5)
	await _reloads()
	print("END route=%s errors=%d" % [route, errors])
	quit(errors)


func _reloads() -> void:
	if not game:
		print("(no Game autoload: save/load skipped)")
		return
	for s in CH1:
		if not saves.has(s):
			_bad("no snapshot taken at step %s" % s)
			continue
		var save: Dictionary = saves[s]
		game.pending = save.duplicate(true)
		game.loading = true
		world = load("res://maps/hollowmere.tscn").instantiate()
		root.add_child(world)
		ch1 = world.get_node("Chapter1")
		player = world.get_node("Player")
		await _frames(30)
		var ok: bool = ch1.step == s
		if not ok:
			_bad("load at %s: started at '%s'" % [s, ch1.step])
		if ch1.flags.hash() != (save.flags as Dictionary).hash():
			_bad("load at %s: flags %s, saved %s" % [s, ch1.flags, save.flags])
		var w: Weapons = player.weapons
		if w.owned != save.weapons.owned:
			_bad("load at %s: weapons %s, saved %s" % [s, w.owned, save.weapons.owned])
		for k in save.player:
			if k != "health" and str(player.get(k)) != str(save.player[k]):
				_bad("load at %s: player.%s = %s, saved %s" % [s, k, player.get(k), save.player[k]])
		print("  reload at %-8s → step %s  ok=%s" % [s, ch1.step, ok])
		world.queue_free()
		await _frames(5)
