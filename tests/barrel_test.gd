extends SceneTree
## Headless check: fuel drums (FuelBarrel) and Chapter 1's one-shot props across a checkpoint respawn.
##   a burst: the drum goes, a solid wreck and a scorch mark the size of the fire stay, the flames cover RADIUS, the
##   shock ring grows to exactly RADIUS, a body inside RADIUS burns and one just outside doesn't, the camera shakes
##   more close up than far off, the burn stops after BURN s (the wreck stays)
##   reset(): the whole drum is back where it stood, solid and shootable, nothing of the burst left; a one-off fire
##   (respawns = false) is gone instead
##   the boss fight: a run started at the boss step has the yard's drums; dying puts back every drum blown up
##   the square: tin moths knocked down before the full set hang again after a blackout; a full set stays won
## godot --headless --path . -s tests/barrel_test.gd

var errors := 0


func _initialize() -> void:
	_run.call_deferred()


func _bad(msg: String) -> void:
	errors += 1
	print("!! ", msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


class Dummy extends Node3D:
	## Something standing in the fire: counts the burns.
	var burns := 0
	var trauma := 0.0
	func hurt(_amount: float, _from := Vector3.ZERO, _mark := 0.0) -> bool:
		burns += 1
		return true
	func add_trauma(a: float) -> void:
		trauma += a


func _find(n: Node, cls: String) -> Array[Node]:
	return n.find_children("*", cls, true, false)


func _unit() -> void:
	var root3 := Node3D.new()
	root.add_child(root3)
	var near := Dummy.new()
	var far := Dummy.new()
	root3.add_child(near)
	root3.add_child(far)
	near.add_to_group("player")
	far.add_to_group("enemies")
	near.position = Vector3(FuelBarrel.RADIUS - 0.4, 0, 0)
	far.position = Vector3(0, 0, FuelBarrel.RADIUS + 0.5)
	var b := FuelBarrel.make(root3, Vector3.ZERO)
	await _frames(2)
	if not b.is_in_group(FuelBarrel.GROUP):
		_bad("a drum isn't in %s" % FuelBarrel.GROUP)
	b.hit(10.0, b.global_position)
	await _frames(2)
	if not b.burst or b.collision_layer != 0:
		_bad("a shot drum didn't burst (burst %s, layer %d)" % [b.burst, b.collision_layer])
	var wreck: Array[Node] = _find(b, "StaticBody3D")
	if wreck.size() != 1 or (wreck[0] as StaticBody3D).collision_layer != 1 or _find(wreck[0], "CollisionShape3D").is_empty():
		_bad("no solid wreck left after the burst")
	var decals := _find(b, "Decal")
	if decals.size() != 1 or not is_equal_approx((decals[0] as Decal).size.x, FuelBarrel.RADIUS * 2.0):
		_bad("the scorch mark isn't the fire's size (%s)" % [decals.map(func(d: Decal) -> Vector3: return d.size)])
	var flames := false
	for p in _find(b, "GPUParticles3D"):
		var m := (p as GPUParticles3D).process_material as ParticleProcessMaterial
		if m.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_RING:
			flames = true
			if m.emission_ring_radius > FuelBarrel.RADIUS or m.emission_ring_radius < FuelBarrel.RADIUS * 0.75:
				_bad("the fire pool's flames cover %.2f m, the fire burns %.2f m" % [m.emission_ring_radius, FuelBarrel.RADIUS])
	if not flames:
		_bad("no flames over the fire pool")
	var lights := _find(b, "OmniLight3D")
	if lights.is_empty() or (lights[0] as OmniLight3D).light_energy < 8.0:
		_bad("no bright flash when it burst")
	if near.trauma <= 0.0:
		_bad("no camera shake for the player next to it")
	var ring: MeshInstance3D = null
	for mi in _find(b, "MeshInstance3D"):
		if (mi as MeshInstance3D).mesh is PlaneMesh:
			ring = mi
	if not ring:
		_bad("no shock ring")
	await _frames(25)  # 0.42 s: the ring has finished growing
	if ring and is_instance_valid(ring) and absf(ring.scale.x * (ring.mesh as PlaneMesh).size.x / 2.0 - FuelBarrel.RADIUS) > 0.05:
		_bad("the shock ring stops at %.2f m, the fire burns %.2f m" % [ring.scale.x, FuelBarrel.RADIUS])
	await _frames(60)
	if near.burns == 0:
		_bad("standing %.1f m from the fire didn't burn" % near.position.length())
	if far.burns > 0:
		_bad("standing %.1f m from the fire (radius %.1f) burned" % [far.position.length(), FuelBarrel.RADIUS])
	var shaken := near.trauma
	var b2 := FuelBarrel.make(root3, Vector3(14, 0, 0))
	await _frames(1)
	near.trauma = 0.0
	b2.hit(1.0, b2.global_position)
	if near.trauma >= shaken or near.trauma <= 0.0:
		_bad("a drum 14 m off shook as hard as one next to Alex (%.2f vs %.2f)" % [near.trauma, shaken])
	await _frames(int(FuelBarrel.BURN * 60.0) + 10)
	if b.burning():
		_bad("still burning after %.0f s" % FuelBarrel.BURN)
	if not is_instance_valid(b) or _find(b, "StaticBody3D").is_empty():
		_bad("the wreck went with the fire")
	var burns := near.burns
	await _frames(40)
	if near.burns != burns:
		_bad("a burnt-out fire still burns")
	b.reset()
	await _frames(2)
	if b.burst or b.collision_layer != 3 or not b._drum.visible or not _find(b, "StaticBody3D").is_empty() \
			or not _find(b, "Decal").is_empty() or not _find(b, "GPUParticles3D").is_empty():
		_bad("reset() didn't put the whole drum back (burst %s, layer %d, %d bodies, %d decals)" % [b.burst,
			b.collision_layer, _find(b, "StaticBody3D").size(), _find(b, "Decal").size()])
	if b.global_position != Vector3.ZERO:
		_bad("the drum came back at %s, not where it stood" % b.global_position)
	b.hit(1.0, b.global_position)
	if not b.burst:
		_bad("a reset drum can't be blown up again")
	var once := FuelBarrel.make(root3, Vector3(30, 0, 0), false)
	once.hit(1.0, once.global_position)
	once.reset()
	await _frames(2)
	if is_instance_valid(once):
		_bad("a one-off fire came back as a drum")
	root3.queue_free()
	await _frames(2)


func _director(step: String) -> Array:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = step
	root.add_child(world)
	var player: CharacterBody3D = world.get_node("Player")
	var d: Chapter1Director = world.get_node("Chapter1")
	Engine.time_scale = 4.0
	var t := 0.0
	while t < 90.0 and not (player.controls_enabled and d.step == step):
		await physics_frame
		t += 1.0 / 60.0 * Engine.time_scale
	return [world, player, d]


func _die(player: CharacterBody3D) -> void:
	var t := 0.0
	while not player.dead and t < 10.0:  # (a hit just taken, a burn, holds the next one off a moment)
		player.hurt(10000.0)
		await physics_frame
		t += 1.0 / 60.0
	t = 0.0
	while t < 30.0 and not player.controls_enabled:
		await physics_frame
		t += 1.0 / 60.0 * Engine.time_scale


func _boss() -> void:
	var r := await _director("boss")
	var world: Node = r[0]
	var player: CharacterBody3D = r[1]
	var barrels := get_nodes_in_group(FuelBarrel.GROUP)
	if barrels.size() != Chapter1Director.YARD_BARRELS.size():
		_bad("boss fight started on its own: %d fuel drums in the yard (want %d)" % [barrels.size(),
			Chapter1Director.YARD_BARRELS.size()])
	var at := {}
	for b in barrels:
		at[b] = (b as Node3D).global_position
	for b in barrels.slice(0, 2):
		b.hit(1.0, b.global_position)
	await _frames(30)
	await _die(player)
	await _frames(5)
	for b in barrels:
		if not is_instance_valid(b) or b.burst or b.collision_layer != 3 or (b as Node3D).global_position != at[b]:
			_bad("after the blackout a fuel drum isn't back whole where it stood")
	if get_nodes_in_group(FuelBarrel.GROUP).size() != barrels.size():
		_bad("the blackout changed the number of drums (%d)" % get_nodes_in_group(FuelBarrel.GROUP).size())
	world.queue_free()
	await _frames(5)


func _square() -> void:
	var r := await _director("square")
	var world: Node = r[0]
	var player: CharacterBody3D = r[1]
	var d: Chapter1Director = r[2]
	var t := 0.0
	var moths: Array = []
	while t < 120.0 and moths.size() < Chapter1Director.MOTHS:  # Grady's talk and the gun tutorial first
		var m: Interactable = null
		for n in get_nodes_in_group("interactable"):
			if n.enabled and n.prompt == "Talk to Grady":
				m = n
		if m and player.controls_enabled:
			m.interact(player)
		await physics_frame
		t += 1.0 / 60.0 * Engine.time_scale
		moths = d.get_children().filter(func(n: Node) -> bool: return n is Chapter1Director.Target)
	if moths.size() != Chapter1Director.MOTHS:
		_bad("square: %d tin moths hung (want %d)" % [moths.size(), Chapter1Director.MOTHS])
		world.queue_free()
		return
	for m in moths:  # each on its hook under the gallery bar, not floating free
		var mi: MeshInstance3D = _find(m, "MeshInstance3D")[0]
		if not (mi.mesh is QuadMesh) or not ((mi.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture:
			_bad("a tin moth is a plain panel, not a cut-out")
		var hook := (m as Node3D).global_position
		if hook.y > 2.2 or absf(hook.x) > 5.2 or absf(hook.z - Chapter1Director.GALLERY_Z) > 0.01:
			_bad("tin moth at %s isn't hung under the gallery bar" % hook)
	await _in_control(player)
	await _frames(10)
	var tokens: int = d.flags.tokens
	moths[0].hit(1.0, Vector3.ZERO)
	moths[1].hit(1.0, Vector3.ZERO)
	await _die(player)
	await _frames(5)
	for m in moths:
		if m.collision_layer != 2 or absf(m.rotation.x) > 0.01:
			_bad("a tin moth knocked down before the blackout didn't hang again")
	for m in moths:
		m.hit(1.0, Vector3.ZERO)
	await _frames(5)
	if d.flags.tokens != tokens + 25:
		_bad("the full set paid %d tokens (want 25)" % (d.flags.tokens - tokens))
	await _die(player)
	await _frames(5)
	if moths.any(func(m: Node) -> bool: return m.collision_layer != 0):
		_bad("a won set of tin moths came back up after a blackout")
	world.queue_free()
	await _frames(5)


func _in_control(player: CharacterBody3D) -> void:
	var t := 0.0
	while t < 60.0 and not player.controls_enabled:
		await physics_frame
		t += 1.0 / 60.0 * Engine.time_scale


func _run() -> void:
	await _unit()
	await _boss()
	await _square()
	Engine.time_scale = 1.0
	if errors > 0:
		push_error("BARREL FAIL: %d problems" % errors)
		quit(1)
		return
	print("BARREL OK")
	quit(0)
