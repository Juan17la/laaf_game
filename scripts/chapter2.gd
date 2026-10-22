class_name Chapter2Director
extends Chapter1Director
## Chapter 2 — Moth (maps/docs/en/chapters.md §4). Dormant until Chapter 1 hands over with begin()
## (after the blackout, or a dev skip `-- --step=<ch2 step>` / `-- --chapter=2`). Steps:
##   c2_intro (C2.1) → channel7 (M1) → zones (M2 school + M3 clinic, either order) → traitor (C2.2) → free
## Like chapter1.gd this is the GAMEPLAY flow; every story beat lives in scripts/ch2_scenes_a.gd
## (Elena, school, Nora) and scripts/ch2_scenes_b.gd (side missions, clinic, Julian, traitor), staged
## through the inherited API. Side missions are fire-and-forget coroutines waiting on their marker.

const C2_STEPS := ["c2_intro", "channel7", "zones", "traitor", "free"]
const C2_START := {  ## dev skip: where the player stands when a run starts at that step
	"c2_intro": [Vector3(-6, 0.1, 116), PI / 2.0], "channel7": [Vector3(-6, 0.1, 116), PI / 2.0],
	"zones": [Vector3(6, 0.1, 132), PI], "traitor": [Vector3(-36, 0.1, -100), -PI / 2.0],
	"free": [Vector3(-103.5, 0.1, -78.5), 0.0]}
const FLAG_DEFAULTS := {"nora": "active", "julian": "active", "key_parts": 0, "drawing": false,
	"sam_file": false, "music_boxes": 0, "silas_rumor": false, "elena_alive": true}
const DOCK := Vector3(-6, 0.1, 116)
const BATTERY := Vector3(15.8, 1.05, 106.8)  # boathouse workbench
const LH_RADIO := Vector3(7.7, 1.0, 135.3)  # the radio set beside the lighthouse door (the door faces the road)
const CHURCH_GATE := Vector3(-47, 0, -100)
# school (interior x 101..115, z -18..18, door at x 101): corridor along the door wall (x 101..105.6), behind it
# the utility room (breaker, z < -13.8), classroom 1 (z -13.8..-4), the stair hall, the office, classroom 3
# (z 4..18); stairs up to the library / staff / music rooms. See tools/models_hd_civic.py _school_structure.
const SCHOOL := Rect2(78, -35, 57, 80)
const SCHOOL_DOOR := Vector3(102.5, 0, 0)
const BREAKER := Vector3(108, 1.3, -17.2)
const DRAWING := Vector3(111, 0.9, 6.6)  # on the art table
const KEY2 := Vector3(107.6, 0.9, 12.2)  # the front-row desk with the music box
const NORA_SPAWN := Vector3(103.5, 0, -13)  # the dark corridor's west end: her charge runs down open floor
# clinic (interior x 65..79, z -114..-86, door at x 65, ambulance bay at z -83): the hall along the door wall,
# morgue & records (z < -109.4), exam room, pharmacy, the open ward (z > -96.8); stairs up by the door to the
# patient rooms / archive / staff room / theatre. See tools/models_hd_civic.py _clinic_structure.
const CLINIC := Rect2(44, -130, 66, 60)
const CLINIC_DOOR := Vector3(64, 0, -100)
const MASK := Vector3(72, 1.0, -83.2)
const LADDER := Vector3(80.4, 1.2, -110)
const ROOF := Vector3(77.5, 7.75, -110)
const HATCH_LADDER := Vector3(78.4, 4.9, -110)  ## the ladder up to the roof hatch, on the upstairs landing
const HATCH := Vector3(77, 3.9, -110)  ## under the roof hatch: the clinic's upstairs landing, the way back in
const HVAC := Vector3(75.3, 8.3, -100)  ## on the side of the middle roof unit (it's solid: not its middle)
const KEY3 := Vector3(69.2, 1.2, -103)
const SAM_FILE := Vector3(78.2, 1.0, -113)
const JULIAN_SPAWN := Vector3(71, 0, -92)

var scenes2a: Ch2ScenesA
var scenes2b: Ch2ScenesB
var elena: Actor
var power_on := true  ## school power (PA barks, remote locks); power_cut() kills it
var _marked: Array[Enemy] = []
var _town_ready := false


func _ready() -> void:
	pass  # dormant: Chapter 1 calls begin()


func owns_step(s: String) -> bool:
	return s in C2_STEPS


func begin(ch1: Chapter1Director, from_step := "c2_intro") -> void:
	## Takes over from Chapter 1 (same player, hud and flags) and runs the steps from `from_step`.
	player = ch1.player
	hud = ch1.hud
	flags = ch1.flags
	_checkpoint = ch1._checkpoint  # (until this chapter's first: the last one, with what was carried there)
	_kit = ch1._kit
	if player.died.is_connected(ch1._on_died):
		player.died.disconnect(ch1._on_died)
	player.died.connect(_on_died)
	player.mark_cap = Feel.MARK_SOFT_CAP[2]
	if player.fell.is_connected(ch1._on_fell):
		player.fell.disconnect(ch1._on_fell)
	player.fell.connect(_on_fell)
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 150.0
	add_child(cam)
	scenes2a = Ch2ScenesA.new(self)
	scenes2b = Ch2ScenesB.new(self)
	for k in FLAG_DEFAULTS:
		if not flags.has(k):
			flags[k] = FLAG_DEFAULTS[k]
	flags.key_parts = maxi(flags.key_parts, 1 if flags.key_part else 0)
	GasCloud.vents_reversed = false
	_on_reset = _reset_marked
	var i := maxi(C2_STEPS.find(from_step), 0)
	if i > 0:  # dev skip: hand over what earlier steps give
		player.respawn(C2_START[C2_STEPS[i]][0], C2_START[C2_STEPS[i]][1])
		_checkpoint_at(C2_START[C2_STEPS[i]][0], C2_START[C2_STEPS[i]][1])
		player.bottles = maxi(player.bottles, 3)
	if i > 0:
		_capture_kit.call_deferred()  # (the dev skip's hand-outs: a death keeps them)
	if i > C2_STEPS.find("zones"):
		_town_side_missions()
	for s in C2_STEPS.slice(i):
		step = s
		if s == "free":
			objective("")
			flags["chapter"] = 2
			var ch3 := get_parent().get_node_or_null("Chapter3")
			if ch3:  # played through the traitor: on to Chapter 3
				ch3.begin(self)
			return
		G.send("at_step", [self])
		await Callable(self, "_step_" + s).call()


# ------------------------------------------------------------------ helpers

func _drop_loot(at: Vector3) -> void:
	## Chapter 2 loot adds throwable bottles to the ammo / bandage table.
	if randf() > 0.3:
		super(at)
		return
	var take := func(_b: Node) -> void:
		player.bottles += 1
		hud.banner("+1 BOTTLE", Color(0.6, 0.85, 0.65), 0.6)
	Interactable.make(self, at + Vector3.UP * 0.3, "Bottle", take, Color(0.5, 0.9, 0.6), true, "bottle")


func _marked_one(pos: Vector3, patrol: Array[Vector3], sight := 20.0) -> Enemy:
	var e := _spawn_marked(pos, _marked.size(), patrol)
	e.sight_range = sight
	_marked.append(e)
	return e


func _reset_marked() -> void:
	for e in _marked:
		if is_instance_valid(e) and e.state != Enemy.State.DEAD:
			e.reset_to(e.patrol[0])


func _free_marked(area := Rect2()) -> void:
	## A mission's Marked Ones end with it: frees those whose post (patrol[0]) is in `area` (default: all).
	for e in _marked.duplicate():
		if is_instance_valid(e) and area.has_area() and not area.has_point(Vector2(e.patrol[0].x, e.patrol[0].z)):
			continue
		_marked.erase(e)
		if is_instance_valid(e):
			e.queue_free()


func _leash() -> void:
	## School / clinic Marked Ones never chase Alex out of their lot: past it they give up and head
	## home (keeps them out of town, the side missions and the other mission).
	while step == "zones":
		await wait(0.5)
		for e in _marked:
			if not is_instance_valid(e) or e.state != Enemy.State.CHASE:
				continue
			for r in [SCHOOL, CLINIC]:
				if r.has_point(Vector2(e.patrol[0].x, e.patrol[0].z)) and not _in(r):
					e.lose_track(e.patrol[0])


func _alert(group: Array[Enemy]) -> void:
	for e in group:
		if is_instance_valid(e):  # a kill is freed 30 s later; its group can still be alerted
			e.hear(player.global_position, 999.0)


func _stare(a: Actor, away: Vector3) -> void:
	## A Marked One who won't attack: idles, and once Alex comes close turns and stares at him, then walks away
	## into the fog with his head still turned toward him, and is gone.
	a.gesture("slump")
	while is_instance_valid(a) and a.global_position.distance_to(player.global_position) > 11.0:
		await wait(0.3)
	if not is_instance_valid(a):
		return
	a.gesture("")
	a.look(player)
	await a.face(player.global_position, 0.6)
	await wait(2.2)
	if not is_instance_valid(a):
		return
	a.walk_to(away, 0.9)
	await wait(a.global_position.distance_to(away) / 0.9 + 0.2)
	if is_instance_valid(a):
		a.queue_free()


func _in(r: Rect2) -> bool:
	return r.has_point(Vector2(player.global_position.x, player.global_position.z))


func _minigame_on(on: bool) -> void:
	player.controls_enabled = not on


func _boss_fight(e: Enemy, title: String, spawn: Vector3, hint: String, phase2: Callable, phase1: Callable) -> void:
	## Coroutine: boss bar + 2 phases (below 50 %) + checkpoint resets; returns when the boss kneels.
	hud.boss_bar(title, 1.0)
	var phase := [1]
	e.damaged.connect(func(en: Enemy) -> void:
		hud.boss_bar(title, en.health / en.max_health)
		if phase[0] == 1 and en.health < en.max_health * 0.5:
			phase[0] = 2
			phase2.call(en))
	_on_reset = func() -> void:
		phase[0] = 1
		phase1.call(e)
		e.reset_to(spawn)
		_reset_marked()
		hud.boss_bar(title, 1.0)
	objective(hint, e)
	await e.downed
	hud.boss_bar("", -1.0)
	_on_reset = _reset_marked


func _spare_or_kill(e: Enemy, who: String) -> String:
	## Coroutine: E on the kneeling boss spares, a shot kills. Returns "spared" / "killed".
	objective("SPARE %s (E) — or shoot to KILL" % who, e)
	var choice := [""]
	var spare := Interactable.make(self, e.global_position + Vector3.UP, "Spare " + who,
		func(_b: Node) -> void: choice[0] = "spared")
	e.died.connect(func(_e: Enemy) -> void: choice[0] = "killed")
	while choice[0] == "":
		await get_tree().physics_frame
	spare.queue_free()
	objective("")
	return choice[0]


# ------------------------------------------------------------------ C2.1 Moth

func _step_c2_intro() -> void:
	await scenes2a.moth_intro()  # ends on the dock (DOCK, facing +X), in control, clock 09:00
	player.bottles += 3
	hud.note("G throws a bottle.", "+3 bottles", 3.5)


# ------------------------------------------------------------------ M1 Channel Seven

func _step_channel7() -> void:
	_checkpoint_at(DOCK, PI / 2.0)
	if "shotgun" not in player.weapons.owned:  # optional: Tom's old double-barrel by the boathouse bench
		weapon_pickup(Vector3(14.5, 0.4, 105.5), "shotgun", 6, -0.4)
	objective("Get the car battery from the boathouse", BATTERY)
	await _use(BATTERY, "Take the car battery", Color(0.9, 0.8, 0.4), "car_battery")
	player.carry("battery")
	_checkpoint_at(Vector3(6, 0.1, 108), -PI / 2.0)
	_on_reset = func() -> void:
		_reset_marked()
		player.carry("battery")
	await scenes2a.battery_taken()
	# two Marked Ones on the harbor road: they don't attack a man carrying a battery (hands full, no gun).
	# They stop, stare at him as he passes, and walk off into the fog still watching him.
	var watchers: Array[Actor] = []
	for w in [[Vector3(-2, 0, 126), Vector3(-16, 0, 132), 0], [Vector3(12, 0, 138), Vector3(24, 0, 150), 1]]:
		var a := actor(MARKED[w[2]], w[0], PI / 2.0)
		watchers.append(a)
		_stare(a, w[1])
	objective("Carry the battery to the lighthouse radio room", LH_RADIO)
	await _use(LH_RADIO, "Wire the battery to the radio", Color(0.5, 1.0, 0.6), "radio")
	player.drop_carry()
	for a in watchers:
		if is_instance_valid(a):
			a.queue_free()
	_free_marked()  # the harbor clears out: nobody follows into the radio room
	_on_reset = _reset_marked
	_checkpoint_at(Vector3(6, 0.1, 133.5), PI)
	objective("Tune the radio to channel 7")
	_minigame_on(true)
	var crackle := _radio_fx(LH_RADIO)
	await RadioTuning.play(hud).done
	crackle.queue_free()
	_minigame_on(false)
	if 9 not in flags.evidence:
		flags.evidence.append(9)
	await scenes2a.radio_room()  # evidence #9, map marks, clock 15:00; ends at the lighthouse


# ------------------------------------------------------------------ M2 + M3 (either order)

func _step_zones() -> void:
	hud.clock("15:00")
	_checkpoint_at(Vector3(6, 0.1, 132), PI)
	_town_side_missions()
	_school_setup()
	_clinic_setup()
	_leash()
	var left := ["school", "clinic"]
	while not left.is_empty():
		var p := player.global_position
		var near: String = left[0]
		if left.size() == 2 and p.distance_to(CLINIC_DOOR) < p.distance_to(SCHOOL_DOOR):
			near = "clinic"
		var target: Vector3 = SCHOOL_DOOR if near == "school" else CLINIC_DOOR
		if left.size() == 2:
			objective("Get the key parts: Nora at the school — or Julian at the clinic", target)
		else:
			objective("Go to the %s — %s has the last key part" % [near, "Nora" if near == "school" else "Julian"], target)
		var which := ""
		while which == "":
			await get_tree().physics_frame
			if "school" in left and _in(SCHOOL):
				which = "school"
			elif "clinic" in left and _in(CLINIC):
				which = "clinic"
		if which == "school":
			await _school()
		else:
			await _clinic()
		left.erase(which)


# ------------------------------------------------------------------ town side missions (Old Tom, Silas, Moth Run)

func _town_side_missions() -> void:
	if _town_ready:
		return
	_town_ready = true
	_old_tom()
	_silas()
	_arcade()


func _old_tom() -> void:
	await _use(Vector3(-22.6, 0.5, 118.6), "Read the note by the fishing rod", Color(1.0, 0.9, 0.5), "note")
	await scenes2b.old_tom_note()
	while true:
		var legendary: bool = not flags.get("catfish", false)
		await _use(Vector3(-23, 0.8, 114), "Fish (Old Tom's rod)", Color(0.5, 0.8, 1.0))
		_minigame_on(true)
		var r: Array = await Fishing.play(hud, legendary).done
		_minigame_on(false)
		var fish: String = r[0]
		if fish == "":
			hud.banner("IT GOT AWAY", Color(0.8, 0.8, 0.8), 1.0)
			continue
		flags.tokens += r[1]
		hud.banner("%s  +%d TOKENS" % [fish.to_upper(), r[1]], Color(0.9, 0.8, 0.4), 1.2)
		if fish != "Old Tom":
			scenes2b.fish_caught(false)  # bark
		else:
			flags["catfish"] = true
			if 10 not in flags.evidence:
				flags.evidence.append(10)
			await scenes2b.fish_caught(true)


func _silas() -> void:
	var silas := actor("res://models/char_silas.glb", Vector3(-19, 0, -28.4), 0.0)
	var met := false
	while true:
		await _use(Vector3(-19, 1.0, -25.9), "Sit at Silas' table", Color(1.0, 0.7, 0.3))
		if not met:
			met = true
			await scenes2b.silas_intro(silas)
		_minigame_on(true)
		var r: Array = await HiLo.play(hud, 3, flags.tokens).done
		_minigame_on(false)
		flags.tokens = maxi(flags.tokens + r[1], 0)
		var won: bool = r[0]
		if won and 12 in flags.evidence:  # the letter scene plays once
			hud.banner("SILAS PAYS UP", Color(1.0, 0.8, 0.5), 1.2)
			continue
		await scenes2b.silas_result(silas, won)
		if won and 12 not in flags.evidence:
			flags.evidence.append(12)
			flags.silas_rumor = true


func _arcade() -> void:
	while true:
		await _use(Vector3(-97.6, 1.3, 86.9), "Play Moth Run (1 token)", Color(0.8, 0.5, 1.0))
		if flags.tokens < 1:
			hud.banner("NEED 1 TOKEN", Color(1.0, 0.5, 0.4), 1.0)
			await wait(1.0)
			continue
		flags.tokens -= 1
		_minigame_on(true)
		var score: int = await MothRun.play(hud, not flags.elena_alive).done
		_minigame_on(false)
		var pay := mini(score / 100, 60)
		flags.tokens += pay
		hud.banner("SCORE %d  +%d TOKENS" % [score, pay], Color(0.9, 0.8, 0.4), 1.5)


# ------------------------------------------------------------------ M2 The Teacher (school)

var _school_in: Array[Enemy] = []  ## hall patrols (darkness blinds them after the power cut)


func _school_setup() -> void:
	if "bat" not in player.weapons.owned:  # optional: a nail bat just inside the school doors
		weapon_pickup(Vector3(104.5, 0.4, 4.0), "bat", 0, 1.3)
	# Recess: 3 music boxes on the playground
	for p in [Vector3(88.5, 0, 24.5), Vector3(97, 0, 31), Vector3(85, 0, 37)]:
		var box := MusicBox.make(self, p)
		box.silenced.connect(func() -> void:
			flags.music_boxes += 1
			scenes2a.music_box_silenced(3 - flags.music_boxes))
	# yard patrols (backs to the fence: takedown bait) + hall patrols
	_marked_one(Vector3(90, 0, 20), [Vector3(90, 0, 20), Vector3(100, 0, 20)])
	_marked_one(Vector3(86, 0, 32), [Vector3(86, 0, 32), Vector3(98, 0, 38)])
	_marked_one(Vector3(95, 0, -14), [Vector3(95, 0, -14), Vector3(95, 0, -2), Vector3(88, 0, -2)])
	_school_in = [  # the corridor, and the door-side aisles of classrooms 3 and 1
		_marked_one(Vector3(103.5, 0, -14), [Vector3(103.5, 0, -14), Vector3(103.5, 0, 14)]),
		_marked_one(Vector3(106.5, 0, 16), [Vector3(106.5, 0, 16), Vector3(106.5, 0, 9.5)]),
		_marked_one(Vector3(106.5, 0, -12), [Vector3(106.5, 0, -12), Vector3(106.5, 0, -5.8)])]
	# Hidden in class: evidence #3 / #4 in the desks
	for n in [3, 4]:
		_desk(n, Vector3(110.2, 0.9, -12.4) if n == 3 else Vector3(107.6, 0.9, -7.8))  # teacher's / a pupil's
	_pa_loop()


func _desk(n: int, pos: Vector3) -> void:
	await _use(pos, "Search the desk", Color(0.7, 0.8, 1.0))
	if n not in flags.evidence:
		flags.evidence.append(n)
	await scenes2a.desk_evidence(n)


func _pa_loop() -> void:
	## Nora on the PA every 12-20 s while the school has power and Alex is on the grounds.
	while power_on:
		await wait(randf_range(12.0, 20.0))
		if power_on and _in(SCHOOL) and player.controls_enabled:
			scenes2a.pa_bark()


func _school() -> void:
	_checkpoint_at(Vector3(92, 0.1, 0), PI / 2.0)
	objective("Get inside the school", SCHOOL_DOOR)
	await _reach(SCHOOL_DOOR, 2.0)
	_checkpoint_at(SCHOOL_DOOR, PI / 2.0)
	await scenes2a.school_arrive(flags.music_boxes)
	if flags.music_boxes < 3:  # PA ambush: "The children want to play."
		var ambush: Array[Enemy] = []
		for p in [Vector3(96, 0, -7), Vector3(96, 0, 7), Vector3(104, 0, -15), Vector3(104, 0, 15)]:
			ambush.append(_marked_one(p, [p]))
		_alert(ambush)
	objective("Find the basement power room and cut the power", BREAKER)
	await _use(BREAKER, "Pull the basement breaker", Color(1.0, 0.5, 0.3))
	power_on = false
	await scenes2a.power_cut()  # lights_out on the school
	for e in _school_in:  # the hall is dark now: easy to slip behind them
		if is_instance_valid(e):
			e.sight_range = 11.0
	_drawing()
	objective("Find key part 2 (Lily's drawing is in classroom 3)", KEY2)
	await _use(KEY2, "Take the key part", Color(0.6, 0.9, 1.0), "key_part")
	flags.key_parts += 1
	await scenes2a.key_part2_found()
	await _nora()
	_free_marked(SCHOOL)


func _drawing() -> void:
	await _use(DRAWING, "Take Lily's drawing", Color(1.0, 0.9, 0.6), "drawing")
	flags.drawing = true
	await scenes2a.drawing_found()


func _nora() -> void:
	_checkpoint_at(KEY2 + Vector3(-1.2, -0.8, 0), PI)
	for p in [Vector3(103, 0.3, -16.5), Vector3(112, 0.3, 16.8)]:
		super._drop_loot(p)
	for p in [Vector3(103, 0, -10), Vector3(112.5, 0, 4.6)]:  # janitor's kerosene
		FuelBarrel.make(self, p)
	_free_marked(SCHOOL)  # the halls clear: Nora hunts alone (her phase-2 kids are the only adds)
	var nora := Enemy.spawn(self, "res://models/char_nora.glb", NORA_SPAWN, 0.0, {
		"display_name": "Nora", "boss": true, "lily_calls": true, "call_interval": 7.0, "shadow_bonus": 2.0,
		"max_health": 360.0, "run_speed": 3.6, "walk_speed": 1.8, "melee_damage": 22.0, "mark_gain": Feel.MARK_GAIN.nora,
		"sight_range": 18.0, "fov_deg": 140.0, "windup": 0.55})
	# through the doorways (she steers straight): classroom 1 → corridor → lobby → classroom 3 and back
	var route: Array[Vector3] = [Vector3(104.2, 0, -5.2), Vector3(106.5, 0, -5.2), Vector3(106.5, 0, -12),
		Vector3(106.5, 0, -5.2), Vector3(104.2, 0, -5.2), Vector3(104, 0, 0), Vector3(104.2, 0, 6.2),
		Vector3(106.5, 0, 6.2), Vector3(106.5, 0, 8.6), Vector3(112, 0, 8.6), Vector3(106.5, 0, 8.6), Vector3(106.5, 0, 15.5)]
	var back := route.duplicate()
	back.reverse()
	var loop: Array[Vector3] = [NORA_SPAWN]
	loop.append_array(route)
	loop.append_array(back.slice(1))
	nora.patrol = loop
	nora.called.connect(scenes2a.nora_calls)
	await scenes2a.nora_intro(nora)
	var kids: Array[Enemy] = []
	var phase2 := func(e: Enemy) -> void:
		e.run_speed = 4.3
		e.windup = 0.45
		e.call_interval = 4.5  # frantic: calls for Lily more often, and every call is an opening
		await scenes2a.nora_phase2(e)  # the grab first: the kids come running once it's over
		if e.state in [Enemy.State.DOWN, Enemy.State.DEAD]:
			return
		for p in [Vector3(102.5, 0, -2), Vector3(102.5, 0, 2)]:
			kids.append(_marked_one(p, [p]))
		_alert(kids)
	var phase1 := func(e: Enemy) -> void:  # also the checkpoint reset: a retry doesn't stack more kids
		e.run_speed = 3.6
		e.windup = 0.55
		e.call_interval = 7.0
		for k in kids:
			_marked.erase(k)
			if is_instance_valid(k):
				k.queue_free()
		kids.clear()
	await _boss_fight(nora, "NORA VANCE — THE TEACHER", NORA_SPAWN,
		"Nora hunts in the dark — hit her when she calls for Lily", phase2, phase1)
	await scenes2a.nora_down(nora)
	flags.nora = await _spare_or_kill(nora, "Nora")
	if flags.nora == "spared":
		await scenes2a.nora_spared(nora, flags.drawing)
		nora.queue_free()  # she walked off into the dark (the scene hid her)
	else:
		await scenes2a.nora_killed(nora)


# ------------------------------------------------------------------ M3 The Medic (clinic)

func _clinic_setup() -> void:
	# corridor gas before the mask (permanent until the clinic is done)
	for p in [Vector3(67.5, 0, -100), Vector3(72, 0, -109), Vector3(72, 0, -92), Vector3(62, 0, -100)]:
		GasCloud.make(self, p, 3.0, 0.0)
	_marked_one(Vector3(67.5, 0, -111.2), [Vector3(67.5, 0, -111.2), Vector3(67.5, 0, -88)])  # (short of the open drawer)
	_marked_one(Vector3(77.8, 0, -88), [Vector3(77.8, 0, -88), Vector3(77.8, 0, -96)])  # behind the ward beds
	_marked_one(Vector3(50, 0, -120), [Vector3(50, 0, -120), Vector3(62, 0, -120)])
	_marked_one(Vector3(84, 0, -118), [Vector3(84, 0, -118), Vector3(84, 0, -84)])
	# hiding: tall grass round the lot + crouching beside the ward beds
	var grass := load("res://models/ext_tall_grass.glb") as PackedScene
	for p in [Vector3(50, 0, -106), Vector3(48, 0, -95), Vector3(60, 0, -122), Vector3(86, 0, -121),
			Vector3(86, 0, -96), Vector3(58, 0, -80)]:
		var g: Node3D = grass.instantiate()
		add_child(g)
		g.global_position = p
		g.rotation.y = randf() * TAU
		player.hidden_spots.append(p)
	for z in [-97.0, -94.0, -91.0, -88.0]:
		player.hidden_spots.append(Vector3(75.3, 0, z))
	# spare filters
	for p in [Vector3(57, 0.3, -88), Vector3(78, 0.3, -86.8)]:
		Interactable.make(self, p, "Mask filter", func(_b: Node) -> void: player.refill_filter(),
			Color(0.6, 0.9, 0.7), true, "mask_filter")
	_triage()
	_pharmacy()
	_sam_file()


func _triage() -> void:
	var patient := actor(MARKED[1], Vector3(75.4, 0, -88), -PI / 2.0)
	patient.crouch(true)
	while true:
		await _use(Vector3(75, 1.0, -88), "Free the strapped patient", Color(0.9, 0.4, 0.4))
		_minigame_on(true)
		var ok: bool = await hud.qte("interact", 10, 3.5)
		_minigame_on(false)
		if ok:
			break
		player.noise(18.0)  # the straps rattle, she screams
		hud.banner("THE STRAPS HOLD", Color(1.0, 0.5, 0.4), 1.0)
	patient.queue_free()  # triage_patient() stages its own, sitting up
	player.heal(50)
	hud.banner("+MEDKIT", Color(0.8, 0.3, 0.3), 1.0)
	await scenes2b.triage_patient()
	await _use(Vector3(66, 1.0, -112.8), "Open the morgue freezer", Color(0.6, 0.8, 1.0))
	if 6 not in flags.evidence:
		flags.evidence.append(6)
	await scenes2b.morgue_evidence()


func _pharmacy() -> void:
	while true:
		await _use(Vector3(78.4, 1.2, -102), "Pick the pharmacy cabinet lock", Color(0.7, 0.9, 1.0))
		_minigame_on(true)
		var ok: bool = await Lockpick.play(hud, 3).done
		_minigame_on(false)
		if ok:
			break
		player.noise(3.0)
		hud.banner("THE PICK SLIPPED", Color(1.0, 0.5, 0.4), 1.0)
	flags["tea"] = flags.get("tea", 0) + 2
	if 5 not in flags.evidence:
		flags.evidence.append(5)
	hud.banner("+2 ELENA'S TEA", Color(0.8, 0.9, 0.6), 1.0)
	await scenes2b.pharmacy_opened()


func _sam_file() -> void:
	await _use(SAM_FILE, "Search the records cabinet", Color(0.7, 0.8, 1.0))
	flags.sam_file = true
	await scenes2b.sam_file_found()


func _julian_loop(j: Enemy) -> void:
	## Julian's voice down the corridors while he stalks the clinic.
	while is_instance_valid(j):
		await wait(randf_range(9.0, 14.0))
		if is_instance_valid(j) and j.visible and j.global_position.distance_to(player.global_position) < 30.0 \
				and player.controls_enabled:
			scenes2b.julian_bark()


var _hunt_on := false  ## M3: Julian stalks the clinic (off while Alex is up on the roof)


func _stalker() -> Enemy:
	## Julian hunting the clinic lot before his fight: gas, and he checks the spots he saw you hide in.
	## He can't be put down yet: hurt to half health (~3 rounds) he backs off for a while (_stalk).
	## Joins _marked, so the leash, checkpoint resets and the clinic's _free_marked cover him too.
	var home := Vector3(71, 0, -92)  # the hall: he only ever walks the building
	var j := Enemy.spawn(self, "res://models/char_julian.glb", home, PI, {
		"display_name": "Julian", "boss": true, "max_health": 200.0, "gas_thrower": true, "gas_interval": 9.0,
		"checks_hiding": true, "run_speed": 3.9, "walk_speed": 1.7, "melee_damage": 18.0, "mark_gain": Feel.MARK_GAIN.julian_hunt,
		"sight_range": 20.0})
	j.patrol = [home, Vector3(67.5, 0, -90), Vector3(67.5, 0, -111.2), Vector3(71, 0, -106)]
	_marked.append(j)
	j.checks_spot.connect(func(_e: Enemy, _p: Vector3) -> void: scenes2b.julian_checks_spot())
	j.struck_player.connect(func(_e: Enemy) -> void:
		j.lose_track(player.global_position + Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))))
	_julian_loop(j)
	_stalk(j)
	return j


func _stalk(j: Enemy) -> void:
	## Julian is out only while _hunt_on. Hurt to half health he staggers, smashes a canister at his feet
	## and slips away in the gas; 25 s later he's back, healed, from the far end of his loop.
	var rest := 0.0
	while is_instance_valid(j):
		if j.visible and j.health <= j.max_health * 0.5:
			j.collision_layer = 0  # he's going: no more hits (a boss at 0 HP would kneel, then die)
			j.stun(1.2)
			GasCloud.make(self, j.global_position, 2.5, 6.0)
			scenes2b.julian_retreats()
			await wait(1.2)
			if not is_instance_valid(j):
				return
			rest = 25.0
		var out := _hunt_on and rest <= 0.0 and _in_clinic()  # only while Alex is inside: he never follows him out
		if out != j.visible:
			_stalker_out(j, out)
		rest -= get_physics_process_delta_time()
		await get_tree().physics_frame


func _in_clinic() -> bool:
	var p := player.global_position
	return p.x > 64.8 and p.x < 79.2 and p.z > -114.2 and p.z < -85.8


func _stalker_out(j: Enemy, out: bool) -> void:
	## Hidden = frozen, no collision, out of the enemies group (no takedown, noise or gas).
	j.visible = out
	j.set_physics_process(out)
	j.collision_layer = 2 if out else 0
	if not out:
		j.remove_from_group("enemies")
		return
	j.add_to_group("enemies")
	var far := j.patrol[0]
	for p in j.patrol:
		if p.distance_to(player.global_position) > far.distance_to(player.global_position):
			far = p
	j.reset_to(far)


func _clinic() -> void:
	_checkpoint_at(Vector3(48, 0.1, -100), PI / 2.0)
	await scenes2b.clinic_arrive()
	_hunt_on = true
	_stalker()
	var vents := [false]
	_on_reset = func() -> void:
		_reset_marked()
		GasCloud.vents_reversed = vents[0]
	if flags.silas_rumor:
		hud.banner("Silas: he walks the lot, the back wall, then the bay", Color(1.0, 0.8, 0.5), 3.0)
	# 1. gas mask
	objective("Get a gas mask from the ambulance bay", MASK)
	await _use(MASK, "Take the gas mask", Color(0.6, 0.9, 0.7), "gas_mask")
	player.gas_mask = true
	player.refill_filter()
	await scenes2b.gas_mask_found()
	hud.note("X: mask on / off.", "", 3.5)
	_checkpoint_at(Vector3(68, 0.1, -99), PI / 2.0)  # back inside, in the hall
	# 2. roof vents (the ladder stays usable: falling off the roof never soft-locks). Julian keeps to the
	# ground: once Alex climbs he's gone until Alex is back down.
	objective("Reverse the vents on the roof — upstairs, up the ladder to the roof hatch", HATCH_LADDER)
	var up := func(_b: Node) -> void:
		_hunt_on = false
		_climb(ROOF, -PI / 2.0)
	var ladder := Interactable.make(self, HATCH_LADDER, "Climb up through the roof hatch", up, Color(0.9, 0.8, 0.5))
	ladder.once = false
	var fire := Interactable.make(self, LADDER, "Climb the fire ladder", up, Color(0.9, 0.8, 0.5))  # from outside too
	fire.once = false
	await _use(HVAC, "Reverse the vents", Color(0.6, 1.0, 0.6))
	ladder.queue_free()
	fire.queue_free()
	vents[0] = true
	GasCloud.vents_reversed = true
	await scenes2b.vents_reversed()
	await _climb(HATCH, PI)  # down the roof hatch into the clinic, not back outside by the ladder
	_checkpoint_at(HATCH, PI)
	_hunt_on = true
	# 3. key part 3 (Sam's file is in the records cabinet: optional, the spare condition)
	objective("Find key part 3 in the clinic (Sam's file is in the records cabinet)", KEY3)
	await _use(KEY3, "Take the key part", Color(0.6, 0.9, 1.0), "key_part")
	flags.key_parts += 1
	await scenes2b.key_part3_found()
	_hunt_on = false
	_on_reset = _reset_marked
	await _julian()
	get_tree().call_group("gas_clouds", "clear")
	GasCloud.vents_reversed = false


func _climb(to: Vector3, yaw: float) -> void:
	player.controls_enabled = false
	await hud.fade(1.0, 0.4)
	var hp: float = player.health  # a ladder isn't a free heal
	player.respawn(to, yaw)
	player.health = hp
	await wait(0.3)
	await hud.fade(0.0, 0.4)
	player.controls_enabled = true


func _julian() -> void:
	_free_marked(CLINIC)  # the stalker and the clinic's Marked Ones: Julian fights alone in the surgery hall
	_checkpoint_at(KEY3 + Vector3(-1.4, -1.1, 0), PI / 2.0)
	for p in [Vector3(66, 0.3, -88), Vector3(78, 0.3, -110)]:
		super._drop_loot(p)
	var julian := Enemy.spawn(self, "res://models/char_julian.glb", JULIAN_SPAWN, -PI / 2.0, {
		"display_name": "Julian", "boss": true, "gas_thrower": true, "gas_interval": 6.0, "asthma": true,
		"asthma_stun": 3.5, "checks_hiding": true, "max_health": 380.0, "run_speed": 3.8, "walk_speed": 1.8,
		"melee_damage": 20.0, "mark_gain": Feel.MARK_GAIN.julian, "sight_range": 26.0, "fov_deg": 180.0, "windup": 0.55})
	julian.patrol = [JULIAN_SPAWN, Vector3(71, 0, -108)]
	julian.checks_spot.connect(func(_e: Enemy, _p: Vector3) -> void: scenes2b.julian_checks_spot())
	await scenes2b.julian_intro(julian)
	var phase2 := func(e: Enemy) -> void:
		e.gas_interval = 4.0
		e.run_speed = 4.4
		e.windup = 0.45
		scenes2b.julian_phase2(e)
	var phase1 := func(e: Enemy) -> void:
		e.gas_interval = 6.0
		e.run_speed = 3.8
		e.windup = 0.55
	await _boss_fight(julian, "JULIAN MARSH — THE MEDIC", JULIAN_SPAWN,
		"Survive Julian — the reversed vents choke him in his own gas (mask on: X)", phase2, phase1)
	await scenes2b.julian_down(julian)
	flags.julian = await _spare_or_kill(julian, "Julian")
	if flags.julian == "spared":
		await scenes2b.julian_spared(julian, flags.sam_file)
		julian.queue_free()
	else:
		await scenes2b.julian_killed(julian)


# ------------------------------------------------------------------ C2.2 The Traitor

func _step_traitor() -> void:
	_free_marked()  # both missions are done: no Marked One walks into the church scene
	_checkpoint_at(Vector3(-36, 0.1, -100), -PI / 2.0)
	objective("Meet Elena at the church at 19:00", CHURCH_GATE)
	await _reach(CHURCH_GATE, 8.0)
	objective("")
	await scenes2b.traitor()  # ends by the mausoleum, control on, elena_alive = false
	flags.elena_alive = false
	_checkpoint_at(Vector3(-103.5, 0.1, -78.5), 0.0)
