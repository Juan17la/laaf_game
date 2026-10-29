extends SceneTree
## Headless check of the aim pose (player.gd _hold: the arms aim at aim_at, the point under the crosshair):
##   revolver, flare gun, shotgun and bow, at camera pitch -80°, 0° and +80°, over either shoulder, standing,
##   crouched and walking: the weapon's barrel (its model's -Z) points within MAX_OFF of the line from the muzzle (the
##   bow: the arrow's rest) to the crosshair point, and a low aim bends the spine forward, a high one back
##   the shot's tracer starts at the muzzle and runs to the crosshair point; the arrow leaves the bow toward it
##   throws land on the crosshair aiming down, and aiming at the sky land out along the aim on the ground
## godot --headless --path . -s tests/aim_test.gd

const MAX_OFF := 6.0  ## degrees
const PITCHES := [-80.0, 0.0, 80.0]
const SPOT := Vector3(-80, 0.2, 75)  ## the lake road by the motel, looking north: 80 m clear ahead, open sky

var player: CharacterBody3D
var world: Node
var _bad := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_bad += 1
		push_error("AIM FAIL: " + msg)


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


func _barrel(id: String) -> Array:
	## [muzzle (world), barrel direction (world)] of the weapon in hand.
	var m: Node3D = player._gun_meshes[id]
	var fwd := (-m.global_basis.z).normalized()
	var at: Vector3 = m.to_global(player.MUZZLE[id]) if player.MUZZLE.has(id) else m.to_global(Vector3(0.012, 0, -0.1))
	return [at, fwd]


func _off(id: String) -> float:
	var b := _barrel(id)
	return rad_to_deg((b[1] as Vector3).angle_to(player.aim_at - (b[0] as Vector3)))


func _run() -> void:
	world = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	player = world.get_node("Player")
	await _frames(30)
	player.global_position = SPOT
	player.pivot.rotation.y = 0.0
	await _frames(20)
	var w: Weapons = player.weapons
	w.give("revolver", 30)
	w.give("flare", 6)
	w.give("shotgun", 10)
	w.give("bow", 10)
	_press("aim")
	for id in ["revolver", "flare", "shotgun", "bow"]:
		w.swap(w.owned.find(id))
		await _frames(30)
		for shoulder in [1.0, -1.0]:
			player._shoulder = shoulder
			for state in ["stand", "crouch", "walk"]:
				player.global_position = SPOT
				player.pivot.rotation.y = 0.0
				player._set_crouch(state == "crouch")
				if state == "walk":
					_press("move_forward")
				for deg: float in PITCHES:
					player.pitch.rotation.x = deg_to_rad(deg)
					await _frames(25)
					var off := _off(id)
					var near: float = player.aim_at.distance_to(player.global_position + Vector3.UP * (1.0 if state == "crouch" else 1.42))
					if player.anim.aim_block > 0.05:  # tucked to low ready: only the shotgun, at a floor nearer than its barrels
						_check(id == "shotgun" and near < player.LONG_REACH + 0.1, "%s %s at %+d°: tucked in (target %.2f m away)" % [
							id, state, deg, near])
						print("  %s %s shoulder %+d at %+d°: low ready (the floor %.2f m off, nearer than the barrels)" % [
							id, state, shoulder, deg, near])
						continue
					_check(off < MAX_OFF, "%s %s shoulder %+d at %+d°: barrel %.1f° off the crosshair point" % [
						id, state, shoulder, deg, off])
				if state == "walk":
					_press("move_forward", false)
					await _frames(10)
		player._set_crouch(false)
	# the spine takes part of a steep aim (forward down, back up)
	w.swap(w.owned.find("revolver"))
	player._shoulder = 1.0
	var spine: Node3D = player.anim.joint("Spine")
	var bends := []
	for deg in [-80.0, 80.0]:
		player.pitch.rotation.x = deg_to_rad(deg)
		await _frames(25)
		bends.append(spine.rotation.x)
	_check(bends[0] > bends[1] + 0.4, "the spine doesn't bend with a steep aim: down %.2f, up %.2f" % bends)

	# a shot: the tracer leaves the muzzle for the crosshair point
	player.global_position = SPOT
	await _frames(5)
	player.pitch.rotation.x = deg_to_rad(-30.0)
	await _frames(25)
	var muzzle: Vector3 = _barrel("revolver")[0]
	var before := world.get_child_count()
	player._fire()
	var tracer: MeshInstance3D = null
	for i in range(before, world.get_child_count()):
		var n := world.get_child(i)
		if n is MeshInstance3D and n.mesh is BoxMesh:
			tracer = n
	_check(tracer != null, "no tracer")
	if tracer:
		var half := (tracer.mesh as BoxMesh).size.z / 2.0
		var start := tracer.global_position + tracer.global_basis.z.normalized() * half
		_check(start.distance_to(muzzle) < 0.12, "the tracer starts %.2f m from the muzzle" % start.distance_to(muzzle))
	# an arrow leaves the bow toward the crosshair point
	w.swap(w.owned.find("bow"))
	await _frames(60)
	player.pitch.rotation.x = deg_to_rad(10.0)
	await _frames(25)
	var bow_at: Vector3 = _barrel("bow")[0]
	var aim: Vector3 = player.aim_at
	before = world.get_child_count()
	player._loose()
	var arrow: Node3D = null
	for i in range(before, world.get_child_count()):
		if world.get_child(i) is Arrow:
			arrow = world.get_child(i)
	await _frames(2)
	_check(arrow != null, "no arrow")
	if arrow:
		var flew := (arrow.global_position - bow_at).normalized()
		_check(rad_to_deg(flew.angle_to(aim - bow_at)) < 8.0, "the arrow left %.1f° off the crosshair point" % rad_to_deg(flew.angle_to(aim - bow_at)))
	_press("aim", false)
	await _frames(20)

	# throws: aiming down they land on the crosshair point; at the sky, out along the aim on the ground
	player.global_position = SPOT
	player.pivot.rotation.y = 0.0
	await _frames(5)
	for deg: float in [-60.0, 60.0]:
		player.pitch.rotation.x = deg_to_rad(deg)
		await _frames(10)
		var want: Vector3 = player.throw_target()
		var sky: bool = deg > 0.0
		var landed := [Vector3.INF]
		player._lob("bottle", func(pos: Vector3) -> void: landed[0] = pos)
		await _frames(200)
		var p: Vector3 = landed[0]
		_check(p != Vector3.INF, "the throw at %+d° never landed" % deg)
		if p == Vector3.INF:
			continue
		if sky:
			var flat := Vector2(want.x - player.global_position.x, want.z - player.global_position.z)
			var went := Vector2(p.x - player.global_position.x, p.z - player.global_position.z)
			_check(p.y < player.global_position.y + 3.0 and went.length() > Player_THROW_MIN and went.normalized().dot(flat.normalized()) > 0.95,
				"a throw at the sky landed at %s (aim heading %s)" % [p, flat])
		else:
			_check(p.distance_to(want) < 1.5, "a throw at %+d° landed %.2f m off the crosshair point" % [deg, p.distance_to(want)])
	if _bad == 0:
		print("AIM OK")
	quit(1 if _bad else 0)


const Player_THROW_MIN := 5.0  ## m out: a sky throw goes far along the aim, not up and back down at Alex's feet
