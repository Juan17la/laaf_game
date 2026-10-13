extends SceneTree
## Headless check of Chapter 1's optional evidence (chapters.md §3) and the 12/12 payoff:
##   Room 4 — pick the lock (Lockpick), take Lucía's camera → evidence #11
##   Tripwire — three bells (MusicBox); a ring costs the 10 tokens; cutting the last wire → evidence #2
##   a loaded save rebuilds them from the flags (lock open, wires cut, finished ones gone, also in Chapter 2)
##   with 12/12 (and nobody killed) the Chapter 3 transmitter broadcasts → the Signal ending; 11/12 refuses;
##   12/12 unlocks "Paper Trail" (achievements file backed up and restored: the player's real unlocks stay as they were)
## godot --headless --path . -s tests/evidence_test.gd


var g: Node


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("EVIDENCE FAIL: " + msg)
	Engine.time_scale = 1.0
	quit(1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _world(step: String, save := {}) -> Node:
	if not save.is_empty():
		g.pending = save.duplicate(true)
		g.loading = true
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = step
	root.add_child(world)
	return world


func _marks(prompt: String) -> Array:
	return get_nodes_in_group("interactable").filter(func(n: Node) -> bool:
		return n.prompt == prompt and n.enabled and not n.is_queued_for_deletion())


func _bells(d: Node) -> Array:
	return d.get_children().filter(func(n: Node) -> bool: return n is MusicBox and n.playing)


func _find(n: Node, script_class: Script) -> Node:
	for c in n.find_children("*", "Control", true, false):
		if c.get_script() == script_class:
			return c
	return null


func _until(c: Callable, frames := 6000) -> bool:
	for i in frames:
		if c.call():
			return true
		await physics_frame
	return c.call()


func _save(step: String, flags: Dictionary) -> Dictionary:
	return {"version": 1, "time": 0.0, "step": step, "difficulty": 1, "run": {"damaged": false, "time": 0.0},
		"flags": flags}


func _run() -> void:
	g = G.game()  # the autoload is there (only its global name isn't, under -s)
	if not g:
		g = load("res://scripts/game.gd").new()
		g.name = "Game"
		root.add_child(g)

	# --- a fresh run: both missions are there
	var world := _world("free")
	await _frames(60)
	var d: Chapter1Director = world.get_node("Chapter1")
	var player: CharacterBody3D = world.get_node("Player")
	if _marks("Pick the lock — Room 4").size() != 1 or _bells(d).size() != 3:
		return _fail("fresh run: room 4 lock %d, bells %d" % [_marks("Pick the lock — Room 4").size(), _bells(d).size()])
	# Room 4: lock → camera → #11
	_marks("Pick the lock — Room 4")[0].interact(player)
	await _frames(2)
	var lp: Lockpick = _find(player.hud, Lockpick)
	if not lp or player.controls_enabled:
		return _fail("room 4: no lockpick minigame (controls %s)" % player.controls_enabled)
	lp.done.emit(true)
	lp.queue_free()
	await _frames(2)
	if not d.flags.room4_open or not player.controls_enabled or _marks("Take Lucía's camera").size() != 1:
		return _fail("room 4 after the lock: open %s controls %s" % [d.flags.room4_open, player.controls_enabled])
	_marks("Take Lucía's camera")[0].interact(player)
	await _frames(15)  # (the camera flies to Alex's hands first: don't free the world under it)
	if 11 not in d.flags.evidence:
		return _fail("room 4: no evidence #11 (%s)" % [d.flags.evidence])
	# Tripwire: one bell rings (no tokens), then every wire is cut → #2
	var tokens: int = d.flags.tokens
	var bells := _bells(d)
	bells[1].chime()
	if not d.flags.trip_rang:
		return _fail("tripwire: a ring wasn't recorded")
	for b in bells:
		b.interactable.interact(player)
		await _frames(1)
	if 2 not in d.flags.evidence or d.flags.tokens != tokens or d.flags.trip_cut.size() != 3:
		return _fail("tripwire done: evidence %s tokens %d→%d cut %s" % [d.flags.evidence, tokens, d.flags.tokens,
			d.flags.trip_cut])
	world.queue_free()
	await _frames(5)

	# --- a loaded save mid-mission: the lock stays open (straight to the camera), cut wires stay cut
	world = _world("intro", _save("free", {"owen": "active", "evidence": [1], "tokens": 5, "key_part": false,
		"lantern": false, "room4_open": true, "trip_cut": [0], "trip_rang": false}))
	await _frames(60)
	d = world.get_node("Chapter1")
	player = world.get_node("Player")
	if not _marks("Pick the lock — Room 4").is_empty() or _marks("Take Lucía's camera").size() != 1:
		return _fail("loaded: room 4 lock %d camera %d" % [_marks("Pick the lock — Room 4").size(),
			_marks("Take Lucía's camera").size()])
	bells = _bells(d)
	if bells.size() != 2:
		return _fail("loaded: %d bells (one was cut)" % bells.size())
	var b0: MusicBox = bells[0]  # crouched past it: silent; upright: rings
	player.global_position = b0.global_position + Vector3(1.5, 0.05, 0)
	player._set_crouch(true)
	player.velocity = Vector3(1, 0, 0)
	b0._physics_process(0.016)
	if d.flags.trip_rang:
		return _fail("a crouched walker rang the bell")
	for b in bells:
		b.interactable.interact(player)
		await _frames(1)
	_marks("Take Lucía's camera")[0].interact(player)
	await _frames(15)  # (the camera flies to Alex's hands first: don't free the world under it)
	if d.flags.evidence != [1, 2, 11] or d.flags.tokens != 5 + Chapter1Director.TRIP_TOKENS:
		return _fail("loaded run finished: evidence %s tokens %d" % [d.flags.evidence, d.flags.tokens])
	world.queue_free()
	await _frames(5)

	# --- a loaded Chapter 2 save that already has both: nothing of them comes back; one without: they're there
	world = _world("intro", _save("zones", {"owen": "spared", "evidence": [1, 2, 11], "tokens": 0, "key_part": true,
		"lantern": true, "room4_open": true, "trip_cut": [0, 1, 2], "trip_rang": false}))
	await _frames(60)
	d = world.get_node("Chapter1")
	if world.get_node("Chapter2").step != "zones" or not _bells(d).is_empty() \
			or not _marks("Take Lucía's camera").is_empty() or not _marks("Pick the lock — Room 4").is_empty():
		return _fail("ch2 load (done): step %s bells %d" % [world.get_node("Chapter2").step, _bells(d).size()])
	world.queue_free()
	await _frames(5)
	world = _world("intro", _save("zones", {"owen": "spared", "evidence": [1], "tokens": 0, "key_part": true,
		"lantern": true}))  # a save from before these missions existed
	await _frames(60)
	d = world.get_node("Chapter1")
	if _bells(d).size() != 3 or _marks("Pick the lock — Room 4").size() != 1:
		return _fail("ch2 load (old save): bells %d room 4 %d" % [_bells(d).size(), _marks("Pick the lock — Room 4").size()])
	world.queue_free()
	await _frames(5)

	# --- Chapter 3: the transmitter refuses 11/12, broadcasts 12/12 → Signal; 12/12 → Paper Trail
	var all := range(1, 13)
	var eleven := all.filter(func(n: int) -> bool: return n != 2)
	world = _world("intro", _save("static", {"owen": "spared", "nora": "spared", "julian": "spared",
		"marcus": "spared", "evidence": eleven, "tokens": 0, "key_part": true, "lantern": true, "key_parts": 3,
		"room4_open": true, "trip_cut": [], "trip_rang": false, "chapter": 2}))
	Engine.time_scale = 8.0
	var ch3: Chapter3Director
	if not await _until(func() -> bool: return _marks("Elena's radio — still on").size() == 1 \
			and world.get_node("Player").controls_enabled):
		return _fail("static: Elena's radio never came up")
	ch3 = world.get_node("Chapter3")
	player = world.get_node("Player")
	_marks("Elena's radio — still on")[0].interact(player)
	var tx := "Transmitter — channel 7, code 1413"
	if not await _until(func() -> bool: return _marks(tx).size() == 1 and player.controls_enabled):
		return _fail("static: no transmitter after the grief scene (step %s)" % ch3.step)
	_marks(tx)[0].interact(player)
	await _frames(5)
	if ch3.flags.broadcast_sent or _find(player.hud, RadioTuning):
		return _fail("the transmitter broadcast with 11/12")
	ch3.flags.evidence.append(2)  # the Tripwire, collected
	if not await _until(func() -> bool: return _marks(tx).size() == 1 and player.controls_enabled):
		return _fail("transmitter didn't come back after the refusal")
	_marks(tx)[0].interact(player)
	await _frames(3)
	var radio: RadioTuning = _find(player.hud, RadioTuning)
	if not radio:
		return _fail("12/12: no radio tuning")
	radio.done.emit()
	radio.queue_free()
	if not await _until(func() -> bool: return ch3.flags.broadcast_sent):
		return _fail("12/12: broadcast not sent")
	Engine.time_scale = 1.0
	if Chapter3Director.pick_ending(ch3.flags) != "signal":
		return _fail("12/12 + broadcast + nobody killed: ending %s" % Chapter3Director.pick_ending(ch3.flags))
	# Paper Trail: Game's achievement check, as a story run, with the real file put back afterwards
	var had := FileAccess.file_exists(_ach_file())
	var bytes := FileAccess.get_file_as_bytes(_ach_file()) if had else PackedByteArray()
	var before: Dictionary = g._unlocked.duplicate()
	var got := [false]
	g.achievement_unlocked.connect(func(id: String) -> void: if id == "evidence": got[0] = true)
	g.director = ch3
	g.mode = "story"
	g._check_t = 0.0
	g._process(0.0)
	g.mode = ""
	var ok: bool = g.unlocked("evidence") and (got[0] or before.has("evidence"))
	g._unlocked = before
	if had:
		var f := FileAccess.open(_ach_file(), FileAccess.WRITE)
		f.store_buffer(bytes)
		f.close()
	else:
		DirAccess.remove_absolute(_ach_file())
	if not ok:
		return _fail("12/12 didn't unlock Paper Trail")
	print("EVIDENCE OK")
	quit(0)


func _ach_file() -> String:
	return g.ACH_FILE
