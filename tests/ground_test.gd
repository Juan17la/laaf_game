extends SceneTree
## Headless check: shoes rest on the paving, not in it. The town's roads, lots and raised sidewalks stand a few cm
## proud of the terrain; each must be walked on (it has a collider), and Alex's real soles (the skinned mesh's lowest
## vertex) must sit on it standing, walking, running and crouched, on flat paving and astride a curb. Same for an
## enemy and a cinematic actor (the shared rig).
## godot --headless --path . -s tests/ground_test.gd

const SINK := 0.02  ## m a sole may dip into the floor under it (a heel rolling, the shoe's rounded edge)
const FLOAT := 0.035  ## m it may hover standing still (a foot raised over a curb's edge, the other one down)

## name: [point (x, z), what the floor under it must be]
const SPOTS := {
	"sidewalk": [Vector2(5.2, -45.0), "streets"],
	"road": [Vector2(1.0, -45.0), "roads"],
	"town square paving": [Vector2(0.0, -20.0), "roads"],
	"curb (on the road side)": [Vector2(3.88, -45.0), "roads"],
	"curb (on the sidewalk side)": [Vector2(4.1, -45.0), "streets"],
}

var world: Node
var player: CharacterBody3D
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _floor(p: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, p.y + 0.5, p.z), Vector3(p.x, p.y - 0.6, p.z), 1)
	q.exclude = exclude
	return root.get_world_3d().direct_space_state.intersect_ray(q)


static func soles(model: Node3D, below := 0.2) -> Array:
	## World positions of the skinned mesh's vertices low enough to be the shoes (bind pose: the bottom 20 cm), or
	## of all of them (below = INF): CPU skinning, as the GPU does.
	var out := []
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not mi.skin:
			continue
		var skin := mi.skin
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var pos: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bo: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var we: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bo.size() / pos.size()
			for vi in pos.size():
				if pos[vi].y > below:
					continue
				var acc := Vector3.ZERO
				for j in per:
					var w := we[vi * per + j]
					if w > 0.0:
						var bi := bo[vi * per + j]
						var bone := skin.get_bind_bone(bi)
						if bone < 0:
							bone = skel.find_bone(skin.get_bind_name(bi))
						acc += w * (skel.get_bone_global_pose(bone) * skin.get_bind_pose(bi) * pos[vi])
				out.append(skel.global_transform * acc)
	return out


func _check(who: String, body: Node3D, model: Node3D, frames: int, still: bool, exclude: Array[RID]) -> void:
	## Over `frames` frames: every shoe vertex at most SINK under the floor right under it; standing still, the
	## lowest one of each shoe at most FLOAT over it.
	var worst_sink := 0.0
	var worst_float := 0.0
	var at := ""
	for f in frames:
		await process_frame
		if f % 6 != 0:
			continue
		var low := {}  # side of the body → [height over its floor]
		for v: Vector3 in soles(model):
			var hit := _floor(v, exclude)
			if not hit:
				continue
			var over: float = v.y - hit.position.y
			if over < -worst_sink:
				worst_sink = -over
				at = "%s over %s" % [v, (hit.collider as Node).name]
			var side := signf((v - body.global_position).dot(model.global_basis.x))
			low[side] = minf(low.get(side, INF), over)
		if still and f > frames / 2:
			for side in low:
				worst_float = maxf(worst_float, low[side])
	if worst_sink > SINK or worst_float > FLOAT:
		fails += 1
		print("FAIL %s: soles sink %.3f m (at %s), float %.3f m" % [who, worst_sink, at, worst_float])
	else:
		print("%s: sink %.3f float %.3f" % [who, worst_sink, worst_float])


func _run() -> void:
	world = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	player = world.get_node("Player")
	var director: Chapter1Director = world.get_node("Chapter1")
	for i in 30:
		await physics_frame
	var me: Array[RID] = [player.get_rid()]
	for spot in SPOTS:
		var xz: Vector2 = SPOTS[spot][0]
		var hit := _floor(Vector3(xz.x, 0.3, xz.y), me)
		var name := "%s %s" % [hit.collider.get_parent().name, hit.collider.name] if hit else "nothing"
		if not name.contains(SPOTS[spot][1]):
			fails += 1
			print("FAIL %s: the floor there is %s, not the paving (%s)" % [spot, name, SPOTS[spot][1]])
			continue
		player.respawn(Vector3(xz.x, 0.3, xz.y), 0.0)
		for i in 20:
			await physics_frame
		await _check("Alex standing on the %s" % spot, player, player.model, 60, true, me)
		player.crouching = true
		await _check("Alex crouched on the %s" % spot, player, player.model, 60, true, me)
		player.crouching = false
	# walking and running along the sidewalk and the road (and over the curb between them)
	for run in [false, true]:
		for path in [[Vector3(5.2, 0.1, -40), Vector3(5.2, 0.1, -52)], [Vector3(1, 0.1, -40), Vector3(1, 0.1, -52)],
				[Vector3(1, 0.1, -60), Vector3(5.5, 0.1, -66)]]:
			player.respawn(path[0], 0.0)
			for i in 10:
				await physics_frame
			var to: Vector3 = path[1]
			var d := to - player.global_position
			player.pivot.global_rotation.y = atan2(-d.x, -d.z)
			Input.action_press("move_forward")
			if run:
				Input.action_press("sprint")
			await _check("Alex %s %s→%s" % ["running" if run else "walking", path[0], path[1]], player, player.model,
					90, false, me)
			Input.action_release("move_forward")
			Input.action_release("sprint")
	# an enemy and a cinematic actor on the same rig, standing on the sidewalk
	player.respawn(Vector3(20, 0.1, -40), 0.0)
	var e := Enemy.spawn(director, "res://models/char_marked_man.glb", Vector3(5.2, 0.3, -46), 0.0)
	e.set_physics_process(false)
	e.set_process(false)
	for i in 20:
		e.velocity = Vector3.DOWN
		e.move_and_slide()
		await physics_frame
	await _check("Marked One on the sidewalk", e, e.get_node("Model"), 60, true, [e.get_rid()])
	e.queue_free()
	var a := Actor.make(director, "res://models/char_grady.glb", Vector3(5.2, 0.0, -48), 0.0)
	await _check("Grady (actor) on the sidewalk", a, a.model, 60, true, [])
	a.walk_to(Vector3(2.0, 0, -48), 1.4)
	await _check("Grady (actor) stepping off the curb", a, a.model, 80, false, [])
	a.queue_free()
	if fails > 0:
		push_error("GROUND FAIL: %d checks" % fails)
		quit(1)
		return
	print("GROUND OK")
	quit(0)
