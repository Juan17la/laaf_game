extends SceneTree
## Headless check: Alex walks (real move input, move_and_slide) every way Chapter 2 sends him in, with that step's
## enemies up: the school (front doors, the corridor, the utility room's breaker, classroom 3's key part) with the
## PA ambush spawned, the clinic (front doors, hall, morgue and records, pharmacy, the stairs up to the roof hatch,
## the roof to the vents, round the outside to the ambulance bay and the fire ladder) with Julian stalking, the
## boathouse, the lighthouse radio and the church doors. The enemies keep their posts and patrols (bodies in the
## way count) but are kept from noticing him. Stuck legs name the collider he is pushing against.
## godot --headless --path . -s tests/doorways_ch2_test.gd

const MAX_TIME := 12.0  ## s of walking per leg before it counts as stuck

## route: [start, yaw, [waypoints...]] (world; y is ignored while walking, the start is dropped onto the floor)
const SCHOOL := {
	"school: in through the front doors to the breaker": [Vector3(96, 0.3, 0), PI / 2.0, [Vector3(100, 0, 0),
		Vector3(102.2, 0, 0), Vector3(104.3, 0, 0), Vector3(104.3, 0, -15.3), Vector3(106.6, 0, -15.3),
		Vector3(107.2, 0, -16.4)]],
	"school: the breaker to classroom 3's key part": [null, 0.0, [Vector3(106.6, 0, -15.3), Vector3(103.8, 0, -15.3),
		Vector3(104.3, 0, 6.2), Vector3(106.4, 0, 6.2), Vector3(106.4, 0, 11.6)]],
	"school: back out of the front doors": [null, 0.0, [Vector3(106.4, 0, 6.2), Vector3(104.3, 0, 6.2),
		Vector3(104.3, 0, 0), Vector3(102.2, 0, 0), Vector3(97, 0, 0)]],
}
const CLINIC := {
	"clinic: in through the front doors to the nurses' station": [Vector3(58, 0.3, -100), PI / 2.0, [
		Vector3(63, 0, -100), Vector3(66, 0, -100), Vector3(68, 0, -101.5)]],
	"clinic: the hall to the morgue and records": [null, 0.0, [Vector3(67.5, 0, -107.5), Vector3(67.5, 0, -111.2),
		Vector3(76.5, 0, -112.4)]],
	"clinic: records back to the pharmacy": [null, 0.0, [Vector3(76.5, 0, -110.5), Vector3(67.5, 0, -110.5),
		Vector3(67.5, 0, -101.5), Vector3(72, 0, -99.6), Vector3(74.6, 0, -99.6), Vector3(74.6, 0, -101.8),
		Vector3(77.8, 0, -101.8)]],  # (along the cabinets, round the fallen trolley)
	"clinic: up the stairs to the roof hatch": [null, 0.0, [Vector3(74.6, 0, -101.8), Vector3(74.6, 0, -99.6),
		Vector3(72, 0, -99.6),
		Vector3(66.8, 0, -101.5), Vector3(66.8, 0, -103.0), Vector3(66.7, 0, -109.6), Vector3(66.7, 0, -110.8),
		Vector3(77.0, 0, -110.8)]],
	"clinic: across the roof to the vents": [Chapter2Director.ROOF, -PI / 2.0, [Vector3(76.6, 0, -105),
		Vector3(76.4, 0, -100.4)]],
	"clinic: round the outside to the ambulance bay": [Vector3(58, 0.3, -100), 0.0, [Vector3(58, 0, -85.2),
		Vector3(66.5, 0, -85.2), Vector3(71.6, 0, -84.4)]],
	"clinic: round the back to the fire ladder": [Vector3(58, 0.3, -100), 0.0, [Vector3(58, 0, -118.5),
		Vector3(81.4, 0, -118.5), Vector3(81.4, 0, -110.6)]],
	"boathouse: in to the battery on the workbench": [Vector3(2, 0.3, 108), PI / 2.0, [Vector3(8.6, 0, 108),
		Vector3(14.4, 0, 106.9)]],
	"lighthouse: up to the radio by the door": [Vector3(6, 0.3, 127), PI, [Vector3(7.3, 0, 133.9)]],
	"church: in through the doors": [Vector3(-55, 0.3, -100), -PI / 2.0, [Vector3(-61.5, 0, -100),
		Vector3(-66, 0, -100)]],
}

var world: Node
var player: CharacterBody3D
var bad := 0


func _initialize() -> void:
	_run.call_deferred()


func _hush() -> void:
	## The enemies stay where the story put them (bodies and patrols in the way count) but never notice Alex,
	## and nothing he walks through hurts him.
	for e in get_nodes_in_group("enemies"):
		var en := e as Enemy
		en.sight_range = 0.0
		en.hearing = 0.0
		en.awareness = 0.0
	player.health = player.health_max


func _frame() -> void:
	_hush()
	await physics_frame


func _enemy_near() -> bool:
	for e in get_nodes_in_group("enemies"):
		if (e as Node3D).global_position.distance_to(player.global_position) < 2.5:
			return true
	return false


func _walk(path: Array) -> String:
	## Walks the path with the forward key, the camera turned toward each point; a cinematic on the way is
	## waited out. "" when it gets there, else what stopped it.
	var blocker := ""
	for to: Vector3 in path:
		var t := 0.0
		while true:
			if not player.controls_enabled:  # a cinematic (the school's PA, the clinic's arrival...)
				Input.action_release("move_forward")
				var w := 0.0
				while not player.controls_enabled and w < 60.0:
					await _frame()
					w += 1.0 / 60.0
				t = 0.0
			var d := to - player.global_position
			d.y = 0.0
			if d.length() < 0.3:
				break
			if t > MAX_TIME and _enemy_near() and t < MAX_TIME * 3.0:
				pass  # a patrol in a narrow lane (the corridor past the overturned table): it moves on, wait for it
			elif t > MAX_TIME:
				Input.action_release("move_forward")
				return "stuck at %s short of %s (against %s)" % [player.global_position.snapped(Vector3.ONE * 0.01), to,
					blocker]
			player.pivot.global_rotation.y = atan2(-d.x, -d.z)
			Input.action_press("move_forward")
			await _frame()
			t += 1.0 / 60.0
			for i in player.get_slide_collision_count():
				var c := player.get_slide_collision(i)
				if absf(c.get_normal().y) < 0.7 and c.get_collider() is Node:
					blocker = "%s at %s" % [(c.get_collider() as Node).get_path(), c.get_position().snapped(Vector3.ONE * 0.01)]
	Input.action_release("move_forward")
	return ""


func _routes(routes: Dictionary) -> void:
	for r in routes:
		var leg: Array = routes[r]
		if leg[0] != null:
			player.respawn(leg[0], leg[1])
			for i in 10:
				await _frame()
		var out := await _walk(leg[2])
		if out != "":
			bad += 1
			print("%s: %s" % [r, out])
		else:
			print("%s: ok" % r)


func _world() -> void:
	if world:
		world.queue_free()
		await process_frame
	world = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "zones"
	root.add_child(world)
	player = world.get_node("Player")
	for i in 60:
		await _frame()


func _run() -> void:
	# the school route: Nora's music boxes still playing, so the PA ambush spawns as he walks in
	await _world()
	await _routes(SCHOOL)
	var ambush := 0
	for e in get_nodes_in_group("enemies"):
		if (e as Enemy).patrol.size() == 1:
			ambush += 1
	print("(%d enemies up, %d of them the PA ambush)" % [get_nodes_in_group("enemies").size(), ambush])
	if ambush == 0:
		bad += 1
		print("school: the PA ambush never spawned (the route didn't play the way the game does)")
	# the clinic route (Julian stalks it once Alex has arrived), then the other buildings Chapter 2 sends him to
	await _world()
	await _routes(CLINIC)
	if bad > 0:
		push_error("DOORWAYS CH2 FAIL: %d routes blocked" % bad)
		quit(1)
		return
	print("DOORWAYS CH2 OK")
	quit(0)
