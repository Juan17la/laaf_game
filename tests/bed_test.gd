extends SceneTree
## Headless check: Alex asleep in room 6's bed (C1.2, ch1_scenes_a.gd _window) fits it: his skinned mesh stays
## between the headboard and the footboard, his back lies on the mattress (not sunk through it) and his head rests on
## the pillow, the face clear of it. Bed numbers: tools/build_assets.py bed() in the motel (room 6).
## godot --headless --path . -s tests/bed_test.gd

const HEADBOARD := -102.745  ## world x of the headboard slats' face (the bed's head end, -Z in the motel model)
const FOOTBOARD := -100.655  ## ...and of the footboard panel's inner face
const MATTRESS := 0.43  ## top of the mattress
const PILLOW := [-102.69, -102.35, 48.22, 48.78, 0.495]  ## x0, x1, z0, z1, top
const GIVE := 0.03  ## m a body may press into the bedding
const Ground := preload("res://tests/ground_test.gd")  ## (its CPU skinning)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	var d: Chapter1Director = world.get_node("Chapter1")
	for i in 10:
		await physics_frame
	var scenes := preload("res://scripts/ch1_scenes_a.gd")
	var alex := Actor.make(d, "res://models/char_alex.glb", scenes.BED_LIE, 0.0)
	alex.model.rotation = scenes.BED_TURN
	alex.gesture("asleep")
	for i in 90:
		await process_frame
	var fails := 0
	var lo_x := INF
	var hi_x := -INF
	var sunk := 0.0
	var on_pillow := INF
	var in_pillow := 0.0
	for v: Vector3 in Ground.soles(alex.model, INF):
		lo_x = minf(lo_x, v.x)
		hi_x = maxf(hi_x, v.x)
		if v.x > PILLOW[1] and v.x < FOOTBOARD:
			sunk = maxf(sunk, MATTRESS - v.y)
		elif v.x > PILLOW[0] and v.x < PILLOW[1] and v.z > PILLOW[2] and v.z < PILLOW[3]:
			in_pillow = maxf(in_pillow, PILLOW[4] - v.y)
			on_pillow = minf(on_pillow, v.y)
	print("bed: crown at x %.3f (headboard %.3f), shoes at %.3f (footboard %.3f), back %.3f into the mattress, head %.3f into the pillow"
			% [lo_x, HEADBOARD, hi_x, FOOTBOARD, sunk, in_pillow])
	if lo_x < HEADBOARD + 0.01:
		fails += 1
		print("FAIL: the head goes through the headboard")
	if hi_x > FOOTBOARD - 0.02:
		fails += 1
		print("FAIL: the shoes go through the footboard")
	if sunk > GIVE:
		fails += 1
		print("FAIL: the body sinks through the mattress")
	if on_pillow == INF:
		fails += 1
		print("FAIL: the head isn't over the pillow")
	elif in_pillow > GIVE:
		fails += 1
		print("FAIL: the head is buried in the pillow")
	if fails > 0:
		push_error("BED FAIL: %d checks" % fails)
		quit(1)
		return
	print("BED OK")
	quit(0)
