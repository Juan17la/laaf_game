class_name Snd
extends RefCounted
## Safe access to the "Audio" autoload (scripts/audio.gd) from gameplay code, like G does for Game: the headless
## `-s` test scripts run without autoloads, and there every call is a silent no-op.


static func _a() -> Node:
	var t := Engine.get_main_loop() as SceneTree
	return t.root.get_node_or_null("Audio") if t and t.root else null


static func music(name: String, fade := 1.5) -> void:
	var a := _a()
	if a:
		a.music(name, fade)


static func push_music(name: String, fade := 1.5) -> void:
	var a := _a()
	if a:
		a.push_music(name, fade)


static func pop_music(fade := 2.0) -> void:
	var a := _a()
	if a:
		a.pop_music(fade)


static func stop_music(fade := 1.5) -> void:
	var a := _a()
	if a:
		a.stop_music(fade)


static func threat(on: bool, source: Object) -> void:
	var a := _a()
	if a:
		a.threat(on, source)


static func sfx(name: String, at: Variant = null, volume_db := 0.0, pitch := 1.0, bus := "SFX") -> Node:
	var a := _a()
	return a.sfx(name, at, volume_db, pitch, bus) if a else null


static func attach(parent: Node3D, name: String, volume_db := 0.0) -> Node:
	var a := _a()
	return a.attach(parent, name, volume_db) if a else null


static func stop(player: Node) -> void:
	var a := _a()
	if a:
		a.stop(player)


static func stinger(name: String, duck_db := -10.0) -> void:
	var a := _a()
	if a:
		a.stinger(name, duck_db)


static func duck(db: float, hold := 2.0) -> void:
	var a := _a()
	if a:
		a.duck(db, hold)


static func voice(who: String, text: String, time := -1.0) -> void:
	var a := _a()
	if a:
		a.voice(who, text, time)


static func stop_voice() -> void:
	var a := _a()
	if a:
		a.stop_voice()


static func caption(text: String) -> void:
	var a := _a()
	if a:
		a.caption(text)


const SURFACES := [["grass", "grass"], ["lawn", "grass"], ["park", "grass"], ["forest", "grass"], ["wood", "wood"],
	["floor", "wood"], ["plank", "wood"], ["deck", "wood"], ["pier", "wood"], ["metal", "metal"], ["grate", "metal"],
	["stair", "metal"], ["gravel", "gravel"], ["dirt", "gravel"], ["sand", "gravel"], ["path", "gravel"]]


static func step(node: Node3D, volume_db := -5.0) -> void:
	## A footfall under `node`: the floor collider's name (and its parent's) picks the surface sound.
	var surface := "concrete"
	var from := node.global_position + Vector3.UP * 0.3
	var hit := node.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.0, 1))
	if node.global_position.y < -0.35:
		surface = "gravel"  # wading
	elif hit and hit.collider:
		var key := ("%s %s" % [hit.collider.name, hit.collider.get_parent().name]).to_lower()
		for k in SURFACES:
			if key.contains(k[0]):
				surface = k[1]
				break
	sfx("step_" + surface, node.global_position, volume_db, randf_range(0.93, 1.07))
