extends SceneTree
## Headless check of dying and coming back (Chapter1Director._on_died / restore_kit):
##   reaching a checkpoint stores what Alex carries; dying puts it back: rounds loaded and in reserve, bottles,
##   smoke cans, tea, the gas mask filter and the Mark. A weapon picked up after the checkpoint stays, with the
##   rounds it came with. Falling out of the world only moves him: the inventory stays as it is.
##   In a boss fight a respawn always has rounds (Chapter1Director.BOSS_MIN_AMMO), even from a dry checkpoint.
##   After Chapter 2 takes over, its own deaths restore its checkpoint's kit too.
## godot --headless --path . -s tests/respawn_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("RESPAWN FAIL: " + msg)
	quit(1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _world(step: String) -> Node:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = step
	root.add_child(world)
	return world


func _die(player: CharacterBody3D) -> bool:
	## Kills Alex and waits until the director has him back in control. False if it never did.
	player.health = 1.0
	player.hurt(9999.0)
	await _frames(5)
	if not player.dead and player.controls_enabled:
		return false
	for i in 600:
		await physics_frame
		if not player.dead and player.controls_enabled:
			return true
	return false


func _total(w: Weapons, id: String) -> int:
	return int(w.loaded[id]) + int(w.reserve[id])


func _run() -> void:
	var world := _world("free")
	await _frames(60)
	var d: Chapter1Director = world.get_node("Chapter1")
	var player: CharacterBody3D = world.get_node("Player")
	var w: Weapons = player.weapons
	var cp := Vector3(0, 0.1, 30)  # the square
	w.give("revolver", 24)
	w.give("flare", 4)
	player.bottles = 2
	player.smokes = 1
	player.teas = 1
	player.gas_mask = true
	player.mask_filter = 0.8
	player.mark = 20.0
	d._checkpoint_at(cp, PI)
	await _frames(2)
	var rev := _total(w, "revolver")
	var flare := _total(w, "flare")
	# spend it all, pick up a new gun and spend that too
	w.loaded.revolver = 0
	w.reserve.revolver = 0
	w.loaded.flare = 0
	player.bottles = 0
	player.smokes = 0
	player.teas = 0
	player.mask_filter = 0.1
	player.mark = 35.0
	w.give("shotgun", 8)
	w.loaded.shotgun = 0
	w.reserve.shotgun = 0
	if not await _die(player):
		return _fail("never came back after dying")
	if w.loaded.revolver != 6 or _total(w, "revolver") != rev or _total(w, "flare") != flare:
		return _fail("rounds not restored: revolver %d/%d flare %d" % [w.loaded.revolver, w.reserve.revolver,
			_total(w, "flare")])
	if player.bottles != 2 or player.smokes != 1 or player.teas != 1:
		return _fail("throwables / tea not restored: %d %d %d" % [player.bottles, player.smokes, player.teas])
	if not player.gas_mask or absf(player.mask_filter - 0.8) > 0.001 or absf(player.mark - 20.0) > 0.001:
		return _fail("mask %s filter %.2f mark %.1f" % [player.gas_mask, player.mask_filter, player.mark])
	if "shotgun" not in w.owned or _total(w, "shotgun") != 8:
		return _fail("the shotgun picked up after the checkpoint: owned %s rounds %d" % [w.owned, _total(w, "shotgun")])
	if Vector2(player.global_position.x - cp.x, player.global_position.z - cp.z).length() > 2.5:
		return _fail("respawned at %s, checkpoint %s" % [player.global_position, cp])
	print("death: kit restored")

	# falling out of the world: back at the checkpoint, nothing restored
	w.loaded.revolver = 1
	w.reserve.revolver = 0
	player.bottles = 0
	player.mark = 40.0
	player.global_position = Vector3(player.global_position.x, -40.0, player.global_position.z)
	await _frames(5)
	if Vector2(player.global_position.x - cp.x, player.global_position.z - cp.z).length() > 2.5:
		return _fail("fell: not back at the checkpoint (%s)" % player.global_position)
	if _total(w, "revolver") != 1 or player.bottles != 0 or absf(player.mark - 40.0) > 0.001:
		return _fail("a fall touched the inventory: revolver %d bottles %d mark %.1f" % [_total(w, "revolver"),
			player.bottles, player.mark])
	print("fall: inventory untouched")

	# a boss fight from a dry checkpoint: the respawn still has rounds for every gun
	w.loaded.revolver = 0
	w.reserve.revolver = 0
	w.loaded.flare = 0
	w.reserve.flare = 0
	w.loaded.shotgun = 0
	w.reserve.shotgun = 0
	d._checkpoint_at(cp, PI)
	await _frames(2)
	player.hud.boss_bar("TEST BOSS", 1.0)
	if not await _die(player):
		return _fail("boss: never came back")
	for id in Chapter1Director.BOSS_MIN_AMMO:
		if id in w.owned and (_total(w, id) < Chapter1Director.BOSS_MIN_AMMO[id] or w.loaded[id] <= 0):
			return _fail("boss: %s respawned with %d/%d" % [id, w.loaded[id], w.reserve[id]])
	player.hud.boss_bar("", -1.0)
	print("boss: never dry")
	world.queue_free()
	await _frames(5)

	# Chapter 2 took over: its own checkpoint's kit
	world = _world("zones")
	await _frames(90)
	var ch2: Chapter2Director = world.get_node("Chapter2")
	player = world.get_node("Player")
	w = player.weapons
	ch2._checkpoint_at(Vector3(6, 0.1, 132), PI)
	await _frames(2)
	var rounds := _total(w, "revolver")
	var bottles: int = player.bottles
	w.loaded.revolver = 0
	w.reserve.revolver = 0
	player.bottles = 0
	if not await _die(player):
		return _fail("ch2: never came back")
	if _total(w, "revolver") != rounds or player.bottles != bottles:
		return _fail("ch2: revolver %d (had %d) bottles %d (had %d)" % [_total(w, "revolver"), rounds,
			player.bottles, bottles])
	print("RESPAWN OK")
	quit(0)
