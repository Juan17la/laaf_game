extends SceneTree
## Headless check: the town's weather (scripts/weather.gd).
##   the world has it; every kind eases in (rain, wind, wet as KINDS has them) and an unknown one falls back to fog
##   rain makes the ground glossy and turns the env's SSR on; dry ground is back as authored
##   the trees wear the wind shader, and only the trees
##   mission steps pick their weather (Game.STEP_WEATHER) and a restored save gets it at once
## godot --headless --path . -s tests/weather_test.gd

var errors := 0


func _initialize() -> void:
	_run.call_deferred()


func _bad(msg: String) -> void:
	errors += 1
	print("!! ", msg)


func _run() -> void:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	for n in ["Chapter1", "Chapter2", "Chapter3"]:
		world.get_node(n).free()
	root.add_child(world)
	await process_frame
	var w := world.get_node_or_null("Weather") as Weather
	if w == null:
		_bad("no Weather node in hollowmere.tscn")
		quit(1)
		return
	if w._foliage.is_empty():
		_bad("no tree material got the wind shader")
	if w._ground.is_empty():
		_bad("no ground material to wet")
	for m: StandardMaterial3D in w._ground:
		if m.albedo_texture.resource_path.get_file().begins_with("pine_tree"):
			_bad("a tree material is in the ground set")
	var env: Environment = world.get_node("WorldEnvironment").environment
	var rough: float = w._ground.keys()[0].roughness
	for k in Weather.KINDS:
		w.set_weather(k, 0.05)
		for i in 10:
			await process_frame
		var want: Dictionary = Weather.KINDS[k]
		if absf(w.rain - want.rain) > 0.01 or absf(w.wet - want.wet) > 0.01 or absf(w.wind - want.wind) > 0.01:
			_bad("%s: rain %.2f wet %.2f wind %.2f" % [k, w.rain, w.wet, w.wind])
		if w._rain.emitting != (want.rain > 0.0):
			_bad("%s: rain emitting %s" % [k, w._rain.emitting])
		if env.ssr_enabled != (want.wet > 0.05):
			_bad("%s: ssr %s" % [k, env.ssr_enabled])
	if w._ground.keys()[0].roughness >= rough:
		_bad("storm: the ground isn't glossier when wet")
	w.set_weather("nonsense", 0.05)
	for i in 10:
		await process_frame
	if w.kind != "fog" or w.rain > 0.01 or absf(w._ground.keys()[0].roughness - rough) > 0.001:
		_bad("an unknown kind should be dry fog, ground as authored")
	for s in Game.STEP_WEATHER:
		if not Game.STEP_WEATHER[s] in Weather.KINDS:
			_bad("step %s: no weather kind %s" % [s, Game.STEP_WEATHER[s]])
	w._strike()  # a lightning flash must not error
	for i in 30:
		await process_frame
	print("weather_test: ", "OK" if errors == 0 else "%d FAILED" % errors)
	quit(1 if errors else 0)
