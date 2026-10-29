extends SceneTree
## Headless check: Alex's light is a headlamp on his head, not a lamp in his chest.
##   it's worn on the Head joint (models/item_headlamp.glb) and the SpotLight3D shines from its lens, at head height
##   F toggles it; the lens glows only while it's on
##   the beam points where the crosshair is (the camera's centre ray), round the yaw and pitch the camera can take
##   it never lights or shadows Alex himself (his meshes sit on a layer the lamp skips)
##   it stays on with every weapon drawn, carrying the battery and mid-throw (never stowed)
##   the rules tied to it hold: visibility x1.5, enemy awareness x4 (Feel.AWARE_LIGHT_MULT)
##   the Harvester rule: the lamp held on its face for DAZZLE_TIME staggers it
##   an Alex stand-in (cinematics) wears the headlamp too, unlit
## godot --headless --path . -s tests/headlamp_test.gd

var errors := 0
var world: Node
var player: CharacterBody3D


func _initialize() -> void:
	_run.call_deferred()


func _bad(msg: String) -> void:
	errors += 1
	print("!! ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _toggle() -> void:
	var ev := InputEventAction.new()
	ev.action = "flashlight"
	ev.pressed = true
	player._unhandled_input(ev)


func _look_at(p: Vector3) -> void:
	## Turns the camera rig until the crosshair (camera centre) is on p.
	for i in 6:
		var d: Vector3 = p - player.camera.global_position
		player.pivot.global_rotation.y = atan2(-d.x, -d.z)
		player.pitch.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 0.8)
		await _frames(3)


func _beam_error() -> float:
	## Degrees between the beam and the line from the lens to what the crosshair is on.
	var cam: Camera3D = player.camera
	var fwd := -cam.global_basis.z
	var from: Vector3 = cam.global_position + fwd * player.arm.spring_length
	var to: Vector3 = from + fwd * player.flashlight.spot_range
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()]))
	var target: Vector3 = hit.position if hit else to
	var fl: SpotLight3D = player.flashlight
	return rad_to_deg((-fl.global_basis.z).angle_to(target - fl.global_position))


func _run() -> void:
	world = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	player = world.get_node("Player")
	await _frames(30)
	player.respawn(Vector3(-40, 0.1, 0), PI / 2.0)  # the sawmill road: open and flat
	await _frames(10)
	var fl: SpotLight3D = player.flashlight
	var lamp: Headlamp = player.headlamp
	var head := player.model.find_child("Head", true, false) as Node3D

	# worn on the head, the light on its lens
	if not lamp or lamp.get_parent() != head:
		_bad("no headlamp on the Head joint")
	elif not lamp.is_ancestor_of(fl):
		_bad("the flashlight isn't on the headlamp (parent %s)" % fl.get_parent().get_path())
	var lens: Vector3 = head.global_transform * Headlamp.LENS
	if fl.global_position.distance_to(lens) > 0.05:
		_bad("the beam starts %.2f m from the lens" % fl.global_position.distance_to(lens))
	if fl.global_position.y - player.global_position.y < 1.6:
		_bad("the light is at %.2f m: chest height, not the head" % (fl.global_position.y - player.global_position.y))
	if not lamp or lamp.find_children("*", "MeshInstance3D", true, false).size() < 2:
		_bad("the headlamp has no model (band + lens)")

	# F toggles it, the lens glows only while it's on
	fl.visible = false
	await _frames(2)
	if lamp.lit:
		_bad("lens glowing with the light off")
	_toggle()
	await _frames(2)
	if not fl.visible or not lamp.lit or not lamp._mat.emission_enabled:
		_bad("F didn't turn the headlamp on (light %s, lens %s)" % [fl.visible, lamp.lit])
	_toggle()
	await _frames(2)
	if fl.visible or lamp.lit:
		_bad("F didn't turn it off again")
	_toggle()
	await _frames(2)

	# the beam goes where the crosshair is
	for aim in [[0.0, 0.0], [0.6, -0.25], [-0.7, 0.3], [0.3, -0.6], [1.2, 0.0]]:
		player.pivot.rotation.y = player.model.rotation.y + PI + aim[0]
		player.pitch.rotation.x = aim[1]
		await _frames(12)
		var err := _beam_error()
		if err > 2.5:
			_bad("aim yaw %.1f pitch %.1f: the beam is %.1f° off the crosshair" % [aim[0], aim[1], err])

	# Alex never lights or shadows himself
	if fl.light_cull_mask & player.BODY_LAYER:
		_bad("the headlamp lights Alex's own layer")
	for m in player.model.find_children("*", "GeometryInstance3D", true, false):
		if (m as GeometryInstance3D).layers != player.BODY_LAYER:
			_bad("%s isn't on Alex's layer: his own lamp lights it" % m.name)
			break

	# never stowed: every weapon, the battery, a throw
	for id in ["revolver", "flare", "shotgun", "bow", "axe", "bat"]:
		player.weapons.give(id, 6)
	for i in player.weapons.owned.size():
		player.weapons.swap(i)
		await _frames(3)
		if not fl.is_visible_in_tree():
			_bad("the light went out with the %s drawn" % player.weapons.gun())
	player.carry("battery")
	await _frames(3)
	if not fl.is_visible_in_tree():
		_bad("the light went out carrying the battery")
	player.drop_carry()
	player.bottles = 1
	player.throw_bottle()
	await _frames(10)
	if not fl.is_visible_in_tree():
		_bad("the light went out throwing")

	# visibility x1.5, awareness x4
	fl.visible = false
	var v_off: float = player.visibility()
	var e := Enemy.spawn(world, "res://models/char_marked_man.glb", Vector3(-52, 0, 0), PI / 2.0, {"sight_range": 20.0})
	e.patrol = [e.global_position]
	await _frames(3)
	var r_off: float = e._notice_rate()
	fl.visible = true
	if absf(player.visibility() / v_off - 1.5) > 0.01:
		_bad("light on: visibility x%.2f (want x1.5)" % (player.visibility() / v_off))
	var r_on: float = e._notice_rate()
	if r_on < r_off * Feel.AWARE_LIGHT_MULT - 0.01:
		_bad("light on: awareness x%.2f (want at least x%.1f)" % [r_on / r_off, Feel.AWARE_LIGHT_MULT])
	e.queue_free()
	await _frames(2)

	# the Harvester: the lamp on its face for DAZZLE_TIME staggers it (and only the lamp: dark, the same stare doesn't)
	var at := player.global_position + Vector3(-9, 0, 0)
	var h := Harvester.spawn_at(world, at, PI / 2.0)  # facing Alex
	await _frames(3)
	h.set_physics_process(true)
	await _look_at(at + Vector3.UP * 2.5)
	for lit in [false, true]:
		fl.visible = lit
		var stunned := false
		var on_face := false
		for i in int((Harvester.DAZZLE_TIME + 0.8) * 60.0):
			var d: Vector3 = h.global_position + Vector3.UP * 2.5 - player.camera.global_position
			player.pivot.global_rotation.y = atan2(-d.x, -d.z)
			player.pitch.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 0.8)
			player.global_position = Vector3(-40, player.global_position.y, 0)  # (holds his ground)
			await physics_frame
			var to_face: Vector3 = h.global_position + Vector3.UP * 2.5 - fl.global_position
			on_face = on_face or rad_to_deg((-fl.global_basis.z).angle_to(to_face)) < 6.0
			stunned = stunned or h.state == Enemy.State.STUNNED
			if stunned:
				break
		if lit and not on_face:
			_bad("the beam never reached the Harvester's face")
		if stunned != lit:
			_bad("light %s on the Harvester's face: staggered %s" % ["on" if lit else "off", stunned])
		h.reset_to(at)
		await _frames(2)
	h.queue_free()

	# the final boss fight: the light moves to a flashlight in his left hand, lit, the headlamp off his head; and back
	player.hold_torch(true)
	await _frames(2)
	var hand := player.model.find_child("HandL", true, false) as Node3D
	if not player.torch or player.flashlight.get_parent() != player.torch or not hand.is_ancestor_of(player.torch) \
			or not player.flashlight.visible or player.headlamp.visible or player.headlamp.lit:
		_bad("hold_torch(true): the light is not a lit flashlight in his left hand")
	player.hold_torch(false)
	await _frames(2)
	if player.flashlight.get_parent() != player.headlamp or player.torch.visible or not player.headlamp.visible:
		_bad("hold_torch(false): the light did not go back to the headlamp")

	# a cinematic stand-in wears it, unlit
	var a := Actor.make(world, "res://models/char_alex.glb", Vector3(-45, 0, 3))
	await _frames(2)
	var worn := a.model.find_child("Headlamp", true, false) as Headlamp
	if not worn or worn.lit or worn.find_children("*", "Light3D", true, false).size() > 0:
		_bad("the Alex stand-in has no (unlit) headlamp")

	if errors > 0:
		push_error("HEADLAMP FAIL: %d problems" % errors)
		quit(1)
		return
	print("HEADLAMP OK")
	quit(0)
