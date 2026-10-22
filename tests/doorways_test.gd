extends SceneTree
## Headless check: Alex walks (real move input, move_and_slide) through every doorway Chapter 1's story takes him
## through, in and back out: Room 6 from the spawn out to the motel walkway, the diner, Grady's store, the bar, the
## sawmill shed and a forest cabin. A generated collider plugging a doorway (a door casing boxed shut, a leaf or
## a threshold made solid) leaves him stuck: the test names the collider he is pushing against.
## godot --headless --path . -s tests/doorways_test.gd

const MAX_TIME := 10.0  ## s of walking per leg before it counts as stuck

## name: [building origin (x, z), yaw (deg), door centre along the facade (model x), facade (model z), inside point
## (world) or null = 1.8 m in through the door]
const DOORS := {
	"motel room 6": [Vector2(-100, 62), 90.0, 13.0, 3.5, Chapter1Director.ROOM6],
	"diner": [Vector2(-100, 92), 90.0, -4.5, 4.5, null],
	"grady's store": [Vector2(14, -24), 0.0, 0.0, 5.0, null],
	"bar": [Vector2(-15, -24), 0.0, -3.0, 5.0, null],
	"sawmill": [Vector2(-132, -5), 90.0, -7.5, 6.0, null],
	"cabin": [Vector2(-105, -28), 0.0, -1.5, 2.5, null],
}

var world: Node
var player: CharacterBody3D
var director: Chapter1Director


func _initialize() -> void:
	_run.call_deferred()


func _world(origin: Vector2, yaw: float, px: float, pz: float) -> Vector3:
	## A point in a building's model space (x along the facade, z out of it) to the world (W.inst's placement).
	var c := cos(deg_to_rad(yaw))
	var s := sin(deg_to_rad(yaw))
	return Vector3(origin.x + c * px + s * pz, 0.1, origin.y - s * px + c * pz)


func _walk(path: Array[Vector3]) -> String:
	## Walks the path with the forward key, the camera turned toward each point. "" when it gets there, else what
	## stopped it.
	var blocker := ""
	for to in path:
		var t := 0.0
		while true:
			var d := to - player.global_position
			d.y = 0.0
			if d.length() < 0.25:
				break
			if t > MAX_TIME:
				Input.action_release("move_forward")
				return "stuck at %s short of %s (against %s)" % [player.global_position, to, blocker]
			player.pivot.global_rotation.y = atan2(-d.x, -d.z)
			Input.action_press("move_forward")
			await physics_frame
			t += 1.0 / 60.0
			for i in player.get_slide_collision_count():
				var c := player.get_slide_collision(i)
				if absf(c.get_normal().y) < 0.7 and c.get_collider() is Node:
					blocker = "%s at %s" % [(c.get_collider() as Node).get_path(), c.get_position()]
	Input.action_release("move_forward")
	return ""


func _run() -> void:
	world = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	player = world.get_node("Player")
	director = world.get_node("Chapter1")
	for i in 30:
		await physics_frame
	var bad := 0
	for door in DOORS:
		var d: Array = DOORS[door]
		var outside := _world(d[0], d[1], d[2], d[3] + 1.6)
		var front := _world(d[0], d[1], d[2], d[3] + 0.5)
		var back := _world(d[0], d[1], d[2], d[3] - 0.6)
		var inside: Vector3 = d[4] if d[4] != null else _world(d[0], d[1], d[2], d[3] - 1.8)
		player.respawn(inside, 0.0)
		for i in 5:
			await physics_frame
		var out := await _walk([back, front, outside])
		if out != "":
			bad += 1
			print("%s: can't get out: %s" % [door, out])
			continue
		var back_in := await _walk([front, back, inside])
		if back_in != "":
			bad += 1
			print("%s: can't get back in: %s" % [door, back_in])
			continue
		print("%s: through and back" % door)
	if bad > 0:
		push_error("DOORWAYS FAIL: %d doorways blocked" % bad)
		quit(1)
		return
	print("DOORWAYS OK")
	quit(0)
