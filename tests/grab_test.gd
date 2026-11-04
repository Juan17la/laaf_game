extends SceneTree
## Headless check: Alex's hand goes to what he uses.
##   E on a pickup: he turns to it, the free hand (right, empty-handed) reaches it and the item ends up in that hand
##   the radio minigame keeps the hand on the set's dial, turning it with the dial; it lets go when the minigame ends
## flatpak run org.godotengine.Godot --headless --path . -s tests/grab_test.gd

var errors := 0


func _initialize() -> void:
	_run.call_deferred()


func _bad(msg: String) -> void:
	errors += 1
	print("!! ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _run() -> void:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	var player: CharacterBody3D = world.get_node("Player")
	await _frames(30)
	player.respawn(Vector3(-40, 0.1, 0), 0.0)  # the sawmill road: open and flat
	player.weapons.holster()
	await _frames(10)
	var hand: Node3D = player.free_hand()
	if not hand or hand.name != "HandR":
		_bad("empty-handed, the free hand isn't the right (%s)" % hand)

	# a pickup in arm's reach off to his right, waist high
	var at: Vector3 = player.global_position + Vector3(0.45, 1.0, 0.25)
	var it := Interactable.make(world, at, "Take", func(_by: Node) -> void: pass, Color(), false, "bandage")
	await _frames(3)
	var yaw0: float = player.model.rotation.y
	var item := it._item as Node3D
	it.interact(player)
	player.reach(item.global_position)
	var closest := 9.0
	var rode := false
	for i in 30:
		await physics_frame
		closest = minf(closest, hand.global_position.distance_to(at))
		if is_instance_valid(item) and item.global_position.distance_to(hand.global_position) < 0.05:
			rode = true
	if closest > 0.25:
		_bad("the hand never got to the pickup (closest %.2f m)" % closest)
	if not rode:
		_bad("the item never ended up in the hand")
	if absf(angle_difference(yaw0, player.model.rotation.y)) < 0.3:
		_bad("he didn't turn to the pickup")
	await _frames(40)

	# the radio, 1.5 m off: he steps up to it, the hand on the dial while tuning, turned with it, let go after
	var set_at: Vector3 = player.global_position + player.model.global_basis.z * 1.5 + Vector3.UP * 1.0
	var radio := RadioTuning.play(world.get_node("HUD") if world.has_node("HUD") else player.hud, 0.62, set_at)
	radio.dial = 0.1
	await _frames(90)
	var d := hand.global_position.distance_to(set_at)
	if d > 0.2:
		_bad("tuning, the hand isn't on the set (%.2f m off)" % d)
	var b0: Basis = hand.global_basis
	radio.dial = 0.9
	await _frames(30)
	if rad_to_deg(b0.get_rotation_quaternion().angle_to(hand.global_basis.get_rotation_quaternion())) < 30.0:
		_bad("the hand didn't turn with the dial")
	radio.free()
	if player._reach_point() != Vector3.INF:
		_bad("the hand stayed on the set after the minigame")
	if errors:
		push_error("GRAB FAIL: %d" % errors)
		quit(1)
		return
	print("GRAB OK")
	quit(0)
