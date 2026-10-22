extends SceneTree
## Headless check: every scripted interaction marker (all 3 chapters) can be used from somewhere a player can
## stand: E needs a clear line from Alex to the marker (player.gd _within_reach), so a marker buried in its
## prop's collision would be unusable.
## flatpak run org.godotengine.Godot --headless --path . -s tests/reach_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	var player: CharacterBody3D = world.get_node("Player")
	for i in 30:
		await physics_frame
	var d: Chapter1Director = world.get_node("Chapter1")
	var marks := {"door": Vector3(-97.2, 1.1, 49), "note": Vector3(-97.4, 0.25, 49.6), "radio6": Vector3(-98.5, 0.9, 50.8),
		"grady": Vector3(14, 1.2, -17.2), "key1": Vector3(-121, 1, -2), "lantern": Vector3(-117.5, 1.2, -15.5),
		"ledger": Vector3(-123.5, 1.0, 4.0), "axe": Vector3(-114, 0.4, 2.5), "battery": Vector3(15.8, 1.05, 106.8),
		"lh_radio": Vector3(6, 1.0, 144.4), "tom_note": Vector3(-22.6, 0.5, 118.6), "rod": Vector3(-23, 0.8, 114),
		"silas": Vector3(-19, 1.0, -25.9), "arcade": Vector3(-97.6, 1.3, 86.9), "desk3": Vector3(110.2, 0.9, -12.4),
		"desk4": Vector3(107.6, 0.9, -7.8), "breaker": Vector3(108, 1.3, -17.2), "key2": Vector3(107.6, 0.9, 12.2),
		"drawing": Vector3(111, 0.9, 6.6), "triage": Vector3(75, 1.0, -88), "morgue": Vector3(66, 1.0, -112.8),
		"pharmacy": Vector3(78.4, 1.2, -102), "sam": Vector3(78.2, 1.0, -113), "mask": Vector3(72, 1.0, -83.2),
		"ladder": Vector3(80.4, 1.2, -110), "hvac": Chapter2Director.HVAC, "key3": Vector3(69.2, 1.2, -103),
		"shotgun": Vector3(14.5, 0.4, 105.5), "bat": Vector3(104.5, 0.4, 4), "stash": Vector3(-100.6, 0.8, -74.0),
		"photo": Vector3(-78.0, 1.0, -103.0), "register": Vector3(-62.0, 1.0, -104.5), "recorder": Vector3(7.4, 1.0, 144.0),
		"chapel_door": Vector3(-22, 1.2, -204.2), "gate": Vector3(30, 1.2, -219.8), "cage1": Vector3(2, 1.0, -199.7),
		"cage2": Vector3(8, 1.0, -195.7), "candle1": Vector3(-75.9, 0.9, -98.8), "candle2": Vector3(-73.8, 0.9, -101.2),
		"candle3": Vector3(-69.6, 0.9, -98.8), "candle4": Vector3(-67.5, 0.9, -101.2), "candle5": Vector3(-63.3, 0.9, -98.8),
		"lucia_cage": Vector3(-24.8, 1.0, -212.3), "silas_seat": Vector3(-19, 1.0, -25.9), "grady3": Vector3(14, 1.2, -17.2),
		"room4": Chapter1Director.ROOM4_DOOR, "room4_camera": Chapter1Director.ROOM4_CAMERA,
		"wire1": Chapter1Director.TRIP_BELLS[0] + Vector3.UP * 0.2, "wire2": Chapter1Director.TRIP_BELLS[1] + Vector3.UP * 0.2,
		"wire3": Chapter1Director.TRIP_BELLS[2] + Vector3.UP * 0.2}
	var bad := 0
	for k in marks:
		var m: Vector3 = marks[k]
		var found := 0
		for r in [0.5, 0.8, 1.1, 1.4, 1.7]:
			for i in 16:
				var p := m + Vector3(r, 0, 0).rotated(Vector3.UP, TAU * i / 16.0)
				var g := d._stand(Vector3(p.x, m.y + 0.5 - 0.6, p.z))  # drops from just above the marker
				if g == Vector3.INF:
					continue
				player.global_position = g
				if m.distance_to(g + Vector3.UP * 0.9) < 2.2 and player._within_reach(m):
					found += 1
		if found == 0:
			bad += 1
		if found == 0:
			print("%s %s: unreachable" % [k, m])
	if bad > 0:
		push_error("REACH FAIL: %d markers can't be used from anywhere" % bad)
		quit(1)
		return
	print("REACH OK")
	quit(0)
