extends SceneTree
## Headless check of the final report: Game.tally / the zone tracking feed it, an enemy's dive off a shot's line counts
## as a dodged shot, the columns read the numbers right, the closing line falls back with no Groq and a bad Groq answer
## is thrown away, and the screen waits for the player.
## flatpak run org.godotengine.Godot --headless --path . -s tests/run_report_test.gd

var _bad := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_bad += 1
		push_error("REPORT FAIL: " + msg)


func _value(cols: Array, label: String) -> String:
	for c: Array in cols:
		for row: Array in c[1]:
			if row[0] == label:
				return row[1]
	return "?"


func _run() -> void:
	var run := {"shots": 10, "shots_hit": 4, "shots_dodged": 2, "kills": 7, "explore": 125.0, "distance": 1500.0,
		"damaged": true, "zones": {"Town Square": [30.0, 5], "Lakeview Motel": [90.0, 1]}}
	var flags := {"owen": "spared", "nora": "killed", "ending": "mixed", "evidence": [1, 2]}
	var cols := RunReport.sections(run, flags)
	_check(_value(cols, "Accuracy") == "40%", "accuracy: " + _value(cols, "Accuracy"))
	_check(_value(cols, "Time exploring") == "2:05", "time: " + _value(cols, "Time exploring"))
	_check(_value(cols, "Distance on foot") == "1.5 km", "distance")
	_check(_value(cols, "Lakeview Motel") == "1:30 · 1×", "zone row: " + _value(cols, "Lakeview Motel"))
	_check(_value(cols, "Town Square") == "0:30 · 5×", "zone visits")
	_check(cols[0][1][3][0] == "Lakeview Motel", "the longest stay isn't listed first")
	_check(_value(cols, "Shots they dodged") == "2", "dodges")
	_check(_value(cols, "Hunters spared") == "1" and _value(cols, "Hunters killed") == "1", "fates")
	_check(_value(RunReport.sections({}, {}), "Accuracy") == "—", "an empty run must still draw")

	_check(RunReport.local_verdict({}, {}).begins_with("Not a scratch"), "untouched line")
	_check(RunReport.local_verdict({"damaged": true, "shots_dodged": 9, "shots_hit": 1}, {"ending": "mixed"}).begins_with("They learned"),
		"dodged line")
	_check(RunReport.local_verdict({"damaged": true}, {"ending": "run"}).begins_with("You left"), "run line")

	_check(Groq.answer('{"choices":[{"message":{"content":"Hi"}}]}') == "Hi", "a good answer")
	for bad: String in ["", "null", "{}", '{"choices":[]}', '{"choices":[1]}', '{"choices":[{"message":{"content":null}}]}']:
		_check(Groq.answer(bad) == "", "a bad answer got through: " + bad)
	_check(Groq.clean("<think>hm</think>\n\"One.\n\nTwo.\"") == "One. Two.", "clean: " + Groq.clean("<think>hm</think>\n\"One.\n\nTwo.\""))
	_check(Groq.answer('{"choices":[{"finish_reason":"length","message":{"content":"Cut of"}}]}') == "", "a cut-off answer got through")
	var told := RunReport.facts({"habits": {"hide": 0.72}, "rolls": 9, "zones": run.zones}, flags)
	_check(told.habits_enemies_learned.hiding == "strong" and told.habits_enemies_learned.sneaking == "faint" and told.rolls == 9, "habits not told: %s" % str(told))
	_check(told.places_most_visited[0].place == "Lakeview Motel" and told.places_most_visited[1].visits == 5, "places not told")
	_check(Groq.clean("x".repeat(Groq.MAX_LEN + 1)) == "", "too long kept")
	_check(Groq.clean("One. " + "x".repeat(Groq.MAX_LEN)) == "One.", "an overrun isn't cut back to whole sentences")

	for i in 200:  # the DEV tab's random runs: never impossible numbers
		var made := RunReport.random_run()
		var m: Dictionary = made.run
		_check(m.shots_hit <= m.shots and m.headshots <= m.shots_hit and m.shots_dodged <= m.shots - m.shots_hit, "random shots: %s" % str(m))
		_check(m.shots_dodged <= m.aim_dodges, "random: more shots dodged than dives")
		_check(m.deaths == 0 or m.damaged, "random: died without being hurt")
		_check(m.zones.values().all(func(z: Array) -> bool: return z[0] <= m.explore), "random: a place longer than the whole run")
		_check(made.flags.ending in RunReport.ENDINGS, "random ending: %s" % made.flags.ending)
		_check(RunReport.sections(m, made.flags).size() == 3, "random run doesn't draw")

	var g: Node = G.game()
	if not g:
		g = load("res://scripts/game.gd").new()
		g.name = "Game"
		root.add_child(g)
	g.run = {"damaged": false, "time": 0.0}
	g.tally("kills")
	g.tally("kills")
	g.hurt(2.5)
	_check(g.run.kills == 2 and is_equal_approx(g.run.damage, 2.5), "tally")

	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	for i in 30:
		await physics_frame
	var ch1: Node = world.get_node("Chapter1")
	var player: CharacterBody3D = world.get_node("Player")
	g.director = ch1
	player.global_position = Vector3(-30, 0.1, 0)  # just inside the square
	for i in 3:
		await process_frame
	player.global_position = Vector3(-80, 0.1, -140)  # out on the road between zones
	for i in 3:
		await process_frame
	player.global_position = Vector3(-30, 0.1, 0)
	for i in 3:
		await process_frame
	g.director = null
	_check(g.run.has("zones") and g.run.zones["Town Square"][1] == 2, "walking back in should be a second visit: %s" % str(g.run.get("zones")))
	_check(float(g.run.get("explore", 0.0)) > 0.0, "time in control not counted")

	var e := Enemy.spawn(world, "res://models/char_marked_man.glb", Vector3(0, 0.1, 20), 0.0, {"walk_speed": 0.0})
	await physics_frame
	e._dodge = 5.0
	e._dodge_roll = true
	_check(Enemy.diving_off(self, Vector3(0, 1, 0), Vector3(0, 0, 1)), "a dive on the shot's line wasn't seen")
	_check(not Enemy.diving_off(self, Vector3(0, 1, 0), Vector3(1, 0, 0)), "a shot the other way isn't dodged")
	e._dodge_roll = false
	_check(not Enemy.diving_off(self, Vector3(0, 1, 0), Vector3(0, 0, 1)), "a backstep isn't a dive")

	var layer := CanvasLayer.new()
	root.add_child(layer)
	var r := RunReport.new()
	r.ask_groq = false
	r.run = run
	r.flags = flags
	layer.add_child(r)
	await process_frame
	_check(r.verdict == r.tr(RunReport.local_verdict(run, flags)), "no local line with Groq off")
	_check(not r.verdict_ai, "a built-in line must not be labelled as AI")
	var shut := [false]
	r.closed.connect(func() -> void: shut[0] = true)
	var enter := InputEventAction.new()
	enter.action = "ui_accept"
	enter.pressed = true
	r._unhandled_input(enter)
	_check(not shut[0], "the key that ended the credits skipped the report")
	r._age = RunReport.GUARD
	r._unhandled_input(enter)
	_check(shut[0], "Enter didn't move on")
	var done := [false]
	var wait := func() -> void:
		await RunReport.present(world, flags)
		done[0] = true
	wait.call()
	await process_frame
	var shown: RunReport = world.find_children("*", "RunReport", true, false)[0]
	_check(not done[0], "present() didn't wait for the player")
	shown._age = RunReport.GUARD
	shown._unhandled_input(enter)
	await process_frame
	_check(done[0], "present() didn't return once the player moved on")
	if _bad == 0:
		print("REPORT OK")
	quit(1 if _bad > 0 else 0)
