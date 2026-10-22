class_name Chapter3Director
extends Chapter2Director
## Chapter 3 — The Veil (maps/docs/en/chapters.md §5). Dormant until Chapter 2 hands over with begin()
## after C2.2 (or a dev skip `-- --step=<ch3 step>` / `-- --chapter=3`). Steps:
##   c3_bell (C3.1) → run (M1 cemetery chase) → marcus (M2 boss, the nave bells) → static (M3 lighthouse)
##   → gate (choice: chapel or tunnel) → harvest (C3.2) → harvester (M4 final boss) → shepherd (C3.3 +
##   ending) → epilogue (C3.4 "Pop. 1413") → free.   Choosing the tunnel skips harvest + harvester (Run).
## New this chapter: smoke cans (break sight), the Mark creeps up all night (Elena's tea / jacket slow it),
## the nave bells (Bell), roaming Marked Ones, light as a weapon (Floodlight, flares, the flashlight).
## Like chapters 1-2 this is the GAMEPLAY flow; the story beats live in scripts/ch3_scenes_a.gd (bell →
## lighthouse) and scripts/ch3_scenes_b.gd (quarry → epilogue).

const C3_STEPS := ["c3_bell", "run", "marcus", "static", "gate", "harvest", "harvester", "shepherd", "epilogue", "free"]
const C3_START := {  ## dev skip: where the player stands when a run starts at that step
	"c3_bell": [Vector3(-103.5, 0.1, -78.5), PI / 2.0], "run": [Vector3(-101.3, 0.1, -76.3), PI / 2.0],
	"marcus": [Vector3(-57.5, 0.1, -100), -PI / 2.0], "static": [Vector3(-57.5, 0.1, -100), PI / 2.0],
	"gate": [Vector3(0, 0.1, -140), PI], "harvest": [Vector3(-22, 0.1, -202.5), PI],
	"harvester": [Vector3(-22, 0.1, -202.5), 0.0], "shepherd": [Vector3(-22, 0.1, -202.5), PI],
	"epilogue": [Vector3(-22, 0.1, -202.5), PI], "free": [Vector3(0, 0.1, -150), PI]}
const C3_DEFAULTS := {"marcus": "active", "clara_photo": false, "has_chapel_key": false, "broadcast_sent": false,
	"jacket": false, "cages": 0, "candles": 0, "ending": "", "tea": 0}
const MEMBERS := ["owen", "nora", "julian", "marcus"]
const ITEM := {"owen": "lantern", "nora": "drawing", "julian": "sam_file", "marcus": "clara_photo"}
const MOTH := Color(1.0, 0.85, 0.25)
# cemetery + church (nave x -84..-60, z -106..-94, door at x -60; see ch2_scenes_b.gd for the yard)
const HIDE := Vector3(-101.35, 0.05, -76.25)
const STASH := Vector3(-100.6, 0.8, -74.0)  ## moth on the mausoleum step
const MAUSOLEUM_HIDES: Array[Vector3] = [Vector3(-101.35, 0, -76.25), Vector3(-101.6, 0, -129),
	Vector3(-53.6, 0, -132), Vector3(-53.6, 0, -70)]
const CHURCH_DOOR := Vector3(-59.0, 0, -100)
const CHURCH_IN := Vector3(-61.5, 0.1, -100)
const EAST_GATE := Vector3(-47, 0, -100)
const MARCUS_SPAWN := Vector3(-80.3, 0, -100)
const BELL_X := [-65.0, -71.0, -77.0]
const PHOTO := Vector3(-78.0, 1.0, -103.0)
const REGISTER := Vector3(-62.0, 1.0, -104.5)
const CANDLES := [["Tomás", Vector3(-75.9, 0.9, -98.8)], ["Clara", Vector3(-73.8, 0.9, -101.2)],
	["the Clarkes", Vector3(-69.6, 0.9, -98.8)], ["Lily", Vector3(-67.5, 0.9, -101.2)],
	["Sam", Vector3(-63.3, 0.9, -98.8)]]
# town + lighthouse
const RECORDER := Vector3(4.3, 1.0, 135.4)  # on the step by the lighthouse door
# quarry (chapel (-22,-210) door at z -205, gate (30,-222.5), cages (2,-201) (8,-197))
const QUARRY_MOUTH := Vector3(0, 0, -150)
const QUARRY := Rect2(-50, -225, 100, 80)
const CHAPEL_DOOR := Vector3(-22, 1.2, -204.2)
const CHAPEL_OUT := Vector3(-22, 0.1, -202.5)
const GATE := Vector3(30, 1.2, -220.5)
const CAGES := [Vector3(2, 0, -201), Vector3(8, 0, -197)]
const LUCIA_CAGE := Vector3(-24.8, 0, -213.6)
const HARV_SPAWN := Vector3(-8, 0, -172)
const FLOODS := [[Vector3(-36, 0, -186), Vector3(-20, 0, -184)], [Vector3(18, 0, -204), Vector3(2, 0, -190)],
	[Vector3(-6, 0, -158), Vector3(-8, 0, -172)]]  ## [pole, lit spot]
const ALLY_SPOTS := {"owen": Vector3(-31, 0, -198), "nora": Vector3(-13, 0, -199), "julian": Vector3(-33, 0, -192),
	"marcus": Vector3(-11, 0, -193)}
const CALL_SPOTS: Array[Vector3] = [Vector3(-20, 0, -158), Vector3(12, 0, -160), Vector3(-42, 0, -176),
	Vector3(38, 0, -186)]

var scenes3a: Ch3ScenesA
var scenes3b: Ch3ScenesB
var harvester: Harvester
var lucia: Actor
var allies := {}  ## member → Actor (spared + personal item): they come to the quarry
var floods: Array[Floodlight] = []
var _bells: Array[Bell] = []
var _gate_bars: Node3D
var _bells_live := false  ## Marcus is up and fighting: a dropped bell gets his bark
var _dev := false


func owns_step(s: String) -> bool:
	return s in C3_STEPS


func begin(prev: Chapter1Director, from_step := "c3_bell") -> void:
	## Takes over from Chapter 2 (or Chapter 1 on a dev skip): same player, hud and flags.
	player = prev.player
	hud = prev.hud
	flags = prev.flags
	_checkpoint = prev._checkpoint  # (until this chapter's first: the last one, with what was carried there)
	_kit = prev._kit
	for d in [prev, get_parent().get_node_or_null("Chapter1"), get_parent().get_node_or_null("Chapter2")]:
		if d and player.died.is_connected(d._on_died):
			player.died.disconnect(d._on_died)
		if d and player.fell.is_connected(d._on_fell):
			player.fell.disconnect(d._on_fell)
	player.died.connect(_on_died)
	player.fell.connect(_on_fell)
	player.mark_cap = Feel.MARK_SOFT_CAP[3]
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 150.0
	add_child(cam)
	scenes3a = Ch3ScenesA.new(self)
	scenes3b = Ch3ScenesB.new(self)
	_grady = get_parent().get_node("Chapter1")._grady
	_dev = flags.get("chapter", 0) != 2 or G.loading()  # a dev skip or a loaded save: rebuild the earlier steps' state
	for k in Chapter2Director.FLAG_DEFAULTS.merged(C3_DEFAULTS):
		if not flags.has(k):
			flags[k] = Chapter2Director.FLAG_DEFAULTS.merged(C3_DEFAULTS)[k]
	flags.elena_alive = false
	player.teas += int(flags.tea)
	flags.tea = 0
	var boss_prop := get_parent().get_node_or_null("Props/Boss")
	if boss_prop:
		show_boss_prop(boss_prop, false)  # out collecting: it comes back at C3.2
	clear_enemies()  # Chapter 1-2 leftovers (roaming Marked Ones, hidden spared bosses)
	_on_reset = _reset_marked
	var i := maxi(C3_STEPS.find(from_step), 0)
	if _dev:  # dev skip: hand over what earlier chapters / steps give
		for m in ["owen", "nora", "julian"]:
			if flags.get(m, "active") == "active":
				flags[m] = "spared"
		flags.key_parts = 3
		player.bottles = maxi(player.bottles, 3)
		player.respawn(C3_START[C3_STEPS[i]][0], C3_START[C3_STEPS[i]][1])
		_checkpoint_at(C3_START[C3_STEPS[i]][0], C3_START[C3_STEPS[i]][1])
		if i > C3_STEPS.find("run"):
			player.smokes = maxi(player.smokes, 2)
		if i > C3_STEPS.find("marcus"):
			if flags.get("marcus", "active") == "active":  # (a loaded save keeps its own choice)
				flags.marcus = "spared"
			flags.has_chapel_key = true
		if i >= C3_STEPS.find("harvest"):
			_quarry_cast()
		if i > C3_STEPS.find("harvester"):
			harvester = Harvester.spawn_at(self, HARV_SPAWN, PI)
			harvester.phase = 3
			harvester._take(harvester.max_health)  # already kneeling
	if _dev:
		_capture_kit.call_deferred()  # (the dev skip's hand-outs: a death keeps them)
	for s in C3_STEPS.slice(i):
		if flags.ending == "run" and s in ["harvest", "harvester"]:
			continue
		step = s
		if s == "free":
			objective("")
			flags["chapter"] = 3
			G.send("at_step", [self])  # (the achievements see the finished story)
			return
		G.send("at_step", [self])
		await Callable(self, "_step_" + s).call()


# ------------------------------------------------------------------ helpers

static func show_boss_prop(prop: Node3D, on: bool) -> void:
	## The Harvester standing guard by the chapel (Props/Boss): shown / hidden, and solid only while it's there.
	prop.visible = on
	var body := prop.get_node_or_null("Body")
	if body:
		body.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


static func pick_ending(f: Dictionary) -> String:
	## progression.md §4, in priority order: run > signal > unveiled > new_eye > mixed.
	if f.get("ending", "") == "run":
		return "run"
	var st: Array = MEMBERS.map(func(m: String) -> String: return str(f.get(m, "active")))
	if f.get("broadcast_sent", false) and st.count("killed") == 0:
		return "signal"
	if st.count("spared") == 4:
		return "unveiled"
	if st.count("killed") == 4:
		return "new_eye"
	return "mixed"


func _process(delta: float) -> void:
	super(delta)
	# the Mark creeps up all night (never to 100: the Taken sequence isn't in this build)
	if player and step in ["run", "marcus", "static", "gate", "harvester"] and player.controls_enabled:
		player.mark = maxf(player.mark, minf(player.mark + Feel.MARK_CREEP * player.mark_resist * delta,
			Feel.MARK_CREEP_MAX))  # (Feel's table: the creep is the after-Elena rate)


func _fight(e: Enemy, title: String, hint: String, reset: Callable) -> void:
	## Coroutine: boss bar + checkpoint reset; phases are the caller's (connect to e first). Returns on downed.
	hud.boss_bar(title, 1.0)
	e.damaged.connect(func(en: Enemy) -> void: hud.boss_bar(title, en.health / en.max_health))
	_on_reset = func() -> void:
		reset.call()
		_clear_marked()
		hud.boss_bar(title, 1.0)
	objective(hint, e)
	await e.downed
	hud.boss_bar("", -1.0)
	_on_reset = _reset_marked


func _clear_marked() -> void:
	for e in _marked:
		if is_instance_valid(e):
			e.queue_free()
	_marked.clear()


func _drop_loot(at: Vector3) -> void:
	## Chapter 3 loot: the odd smoke can on top of Chapter 2's table.
	if randf() > 0.2:
		super(at)
		return
	Interactable.make(self, at + Vector3.UP * 0.3, "Smoke can", func(_b: Node) -> void:
		player.smokes += 1
		hud.banner("+1 SMOKE CAN", Color(0.75, 0.75, 0.7), 0.6), Color(0.7, 0.7, 0.65), true, "smoke_can")


func _allies_present() -> Array:
	return MEMBERS.filter(func(m: String) -> bool: return flags.get(m) == "spared" and flags.get(ITEM[m], false))


func _quarry_cast() -> void:
	## Lucía in her cage beside the chapel altar + the allies waiting (hidden) at the quarry.
	if is_instance_valid(lucia):
		return
	var cage: Node3D = (load("res://models/cage.glb") as PackedScene).instantiate()
	add_child(cage)
	cage.global_position = LUCIA_CAGE
	lucia = actor("res://models/char_lucia.glb", LUCIA_CAGE, 0.0)
	lucia.crouch(true)
	for m in _allies_present():
		var a := actor("res://models/char_%s.glb" % m, ALLY_SPOTS[m], PI)
		a.visible = false
		allies[m] = a


# ------------------------------------------------------------------ C3.1 The Bell

func _step_c3_bell() -> void:
	await scenes3a.the_bell()  # ends crouched at HIDE facing +X, control on, clock 19:02


# ------------------------------------------------------------------ M1 Run

func _step_run() -> void:
	hud.show_zone("Church & Cemetery")
	_checkpoint_at(HIDE + Vector3.UP * 0.05, PI / 2.0)
	for p in MAUSOLEUM_HIDES:
		player.hidden_spots.append(p)
	_bar_gate(true)
	var chasers: Array[Enemy] = [
		_marked_one(Vector3(-95, 0, -92), [Vector3(-95, 0, -92), Vector3(-88, 0, -84)], 22.0),
		_marked_one(Vector3(-91, 0, -90), [Vector3(-91, 0, -90), Vector3(-98, 0, -100)], 22.0),
		_marked_one(Vector3(-84, 0, -80), [Vector3(-84, 0, -80), Vector3(-70, 0, -72)]),
		_marked_one(Vector3(-72, 0, -88), [Vector3(-72, 0, -88), Vector3(-56, 0, -88)]),
		_marked_one(Vector3(-86, 0, -112), [Vector3(-86, 0, -112), Vector3(-66, 0, -116)]),
		_marked_one(Vector3(-54, 0, -92), [Vector3(-54, 0, -92), Vector3(-54, 0, -110)])]
	for e in chasers:
		e.hearing = 1.3
	var torch: Array[Enemy] = [chasers[0], chasers[1]]
	for e in torch:  # the two from the execution come looking
		e.hear(HIDE, 999.0)
	objective("Grab Elena's stash — the moth on the mausoleum step", STASH)
	await _use(STASH, "Open Elena's stash", MOTH, "smoke_can")
	player.smokes += 2
	player.heal(25)
	await scenes3a.stash_found()
	objective("Run for the church — smoke (T) breaks their sight, crouch (C) in a mausoleum to hide", CHURCH_DOOR)
	var bell := 3.0
	var bark := 4.0
	while Vector2(player.global_position.x - CHURCH_DOOR.x, player.global_position.z - CHURCH_DOOR.z).length() > 2.5:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		bell -= dt
		bark -= dt
		var seen := chasers.any(func(e: Enemy) -> bool:
			return is_instance_valid(e) and e.state == Enemy.State.CHASE)
		if seen and bell <= 0.0:  # every sighting rings the bell: the whole yard converges
			bell = 10.0
			scenes3a.bell_rings()
			_alert(chasers)
		elif seen and bark <= 0.0:
			bark = randf_range(5.0, 8.0)
			scenes3a.chase_bark()
	_clear_marked()


func _bar_gate(shut: bool) -> void:
	## The Marked Ones chained the east gate: the church is the only way out.
	if shut and not _gate_bars:
		_gate_bars = StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, 3.0, 10.4)
		col.shape = box
		col.position.y = 1.5
		_gate_bars.add_child(col)
		add_child(_gate_bars)
		_gate_bars.global_position = EAST_GATE
		var fence := load("res://models/fence_iron.glb") as PackedScene
		for z in [-3.0, 0.0, 3.0]:
			var f: Node3D = fence.instantiate()
			_gate_bars.add_child(f)
			f.position = Vector3(0, 0, z)
			f.rotation.y = PI / 2.0
	elif not shut and _gate_bars:
		_gate_bars.queue_free()
		_gate_bars = null


# ------------------------------------------------------------------ M2 The Bell Tower (the nave)

func _step_marcus() -> void:
	_checkpoint_at(CHURCH_IN, -PI / 2.0)
	hud.clock("19:40")
	_hang_bells()
	for x in [-63.0, -71.0, -79.0]:  # the candles on the pews, as a light the fight can be read by
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.4)
		l.light_energy = 0.9
		l.omni_range = 9.0
		l.set_script(load("res://scripts/flicker.gd"))
		add_child(l)
		l.global_position = Vector3(x, 2.6, -100)
	await scenes3a.church_enter()
	_church_side_missions()
	objective("Find Marcus — down the aisle, to the altar", MARCUS_SPAWN)
	while player.global_position.x > -78.6 or not player.controls_enabled:  # past the pews, into the chancel
		await get_tree().physics_frame
	for p in [Vector3(-62, 0.3, -96), Vector3(-62, 0.3, -104)]:
		super._drop_loot(p)
	var marcus := Enemy.spawn(self, "res://models/char_marcus.glb", MARCUS_SPAWN, PI / 2.0, {
		"display_name": "Marcus", "boss": true, "max_health": 480.0, "armor": 0.5, "hearing": 2.5,
		"run_speed": 3.3, "walk_speed": 1.5, "melee_damage": 30.0, "melee_range": 2.0, "windup": 0.8,
		"mark_gain": Feel.MARK_GAIN.marcus, "sight_range": 26.0, "fov_deg": 160.0})
	marcus.patrol = [MARCUS_SPAWN, Vector3(-66, 0, -100)]
	_hang_bells()  # any bell shot down on the walk to the altar is back for the fight (and the intro's shot)
	await scenes3a.marcus_intro(marcus, _bells)
	_bells_live = true
	var phase := [1]
	marcus.damaged.connect(func(e: Enemy) -> void:
		var n := 3 if e.health < e.max_health / 3.0 else (2 if e.health < e.max_health * 2.0 / 3.0 else 1)
		if n > phase[0] and e.state != Enemy.State.DOWN:
			phase[0] = n
			_marcus_phase(e, n))
	var reset := func() -> void:
		phase[0] = 1
		marcus.run_speed = 3.3
		marcus.windup = 0.8
		marcus.reset_to(MARCUS_SPAWN)
		_hang_bells()
	await _fight(marcus, "MARCUS HALE — THE DEACON",
		"Drop a bell on Marcus — shoot its chain or release the rope — the clang deafens him", reset)
	_bells_live = false
	_clear_marked()  # the hand bell's Marked Ones don't watch him kneel
	await scenes3a.marcus_down(marcus)
	flags.marcus = await _spare_or_kill(marcus, "Marcus")
	if flags.marcus == "spared":
		await scenes3a.marcus_spared(marcus, flags.clara_photo)
		marcus.queue_free()
	else:
		await scenes3a.marcus_killed(marcus)
	flags.has_chapel_key = true
	if 8 not in flags.evidence:
		flags.evidence.append(8)
	await scenes3a.chapel_key_found()
	_bar_gate(false)


func _hang_bells() -> void:
	for b in _bells:
		if is_instance_valid(b):
			if is_instance_valid(b.cleat):
				b.cleat.queue_free()
			b.queue_free()
	_bells.clear()
	for x in BELL_X:
		var b := Bell.make(self, Vector3(x, 0, -100), Vector3(x, 1.3, -94.95))
		b.dropped.connect(func(crushed: bool) -> void:
			if _bells_live:
				scenes3a.bell_dropped(crushed))
		_bells.append(b)


func _marcus_phase(marcus: Enemy, n: int) -> void:
	## He rings the hand bell: two Marked Ones through the door, and he stops holding back.
	marcus.run_speed = 3.3 + 0.4 * (n - 1)
	marcus.windup = 0.8 - 0.1 * (n - 1)
	var called: Array[Enemy] = []
	for z in [-98.8, -101.2]:
		called.append(_marked_one(Vector3(-61.2, 0, z), [Vector3(-61.2, 0, z)]))
	_alert(called)
	scenes3a.marcus_phase(n)


func _church_side_missions() -> void:
	_clara_photo()
	_register()
	for c in CANDLES:
		_candle(c[0], c[1])


func _clara_photo() -> void:
	await _use(PHOTO, "Take the photo from the choir pew", Color(1.0, 0.9, 0.6), "photo")
	flags.clara_photo = true
	await scenes3a.photo_found()


func _register() -> void:
	await _use(REGISTER, "Read the bell register", Color(0.7, 0.8, 1.0), "ledger")
	if 7 not in flags.evidence:
		flags.evidence.append(7)
	await scenes3a.register_found()


func _candle(who: String, at: Vector3) -> void:
	## Empty Chairs: a candle on each of the five families' pews.
	await _use(at, "Light a candle for " + who, Color(1.0, 0.75, 0.4))
	var flame := OmniLight3D.new()
	flame.light_color = Color(1.0, 0.7, 0.35)
	flame.light_energy = 0.8
	flame.omni_range = 3.0
	flame.set_script(load("res://scripts/flicker.gd"))
	add_child(flame)
	flame.global_position = at + Vector3.UP * 0.2
	flags.candles += 1
	if flags.candles == CANDLES.size():
		player.teas += 2
		player.mark = maxf(player.mark - Feel.MARK_CANDLES, 0.0)
	scenes3a.candle_lit(who, CANDLES.size() - flags.candles)


# ------------------------------------------------------------------ M3 Static

func _step_static() -> void:
	_checkpoint_at(Vector3(-57.5, 0.1, -100), PI / 2.0)
	hud.clock("20:15")
	# after Elena the group's Marked Ones walk the square at night
	for p in [[Vector3(-12, 0, 8), Vector3(12, 0, 8)], [Vector3(6, 0, -6), Vector3(6, 0, 26)],
			[Vector3(-20, 0, 40), Vector3(0, 0, 60)], [Vector3(10, 0, 80), Vector3(-10, 0, 96)]]:
		_marked_one(p[0], [p[0], p[1]])
	var talk := Interactable.make(self, GRADY_SPOT, "Talk to Grady", func(_b: Node) -> void: pass,
		Color(0.85, 0.78, 0.62))
	_ask_grady(talk)
	objective("Go to Elena's lighthouse (Grady's store is on the way)", LH_RADIO)
	await _use(LH_RADIO, "Elena's radio — still on", MOTH, "radio")
	if is_instance_valid(talk):
		talk.queue_free()  # he walks her jacket over himself: the store talk ("I heard the bell") is past
	_reset_marked()  # a quiet beat: nobody followed Alex into the radio room
	_checkpoint_at(Vector3(6, 0.1, 133.5), PI)
	await scenes3a.static_grief()  # Grady brings the jacket; clock 01:30
	flags.jacket = true
	player.mark_resist = 0.75
	_recorder()
	_transmitter()
	objective("North to the quarry — Lucía is in the Veil's Chapel (the transmitter and recorder are optional)",
		QUARRY_MOUTH)


func _ask_grady(talk: Interactable) -> void:
	await talk.used
	_reset_marked()  # the square's Marked Ones break off: nobody stands in on the talk
	await scenes3a.ask_grady(_grady)
	player.weapons.give("flare", 2)
	player.smokes += 1
	hud.banner("+2 FLARES · +1 SMOKE CAN", Color(0.9, 0.8, 0.4), 1.5)


func _recorder() -> void:
	await _use(RECORDER, "Play Elena's recorder", MOTH, "recorder")
	_reset_marked()
	await scenes3a.last_recording()
	player.weapons.give("flare", 1)
	hud.banner("+1 FLARE", Color(1.0, 0.4, 0.25), 1.0)


func _transmitter() -> void:
	while true:
		await _use(LH_RADIO, "Transmitter — channel 7, code 1413", Color(0.5, 1.0, 0.6), "radio")
		if flags.evidence.size() < 12:
			scenes3a.transmitter_locked(flags.evidence.size())
			await wait(1.0)
			continue
		_reset_marked()
		_minigame_on(true)
		var crackle := _radio_fx(LH_RADIO)
		await RadioTuning.play(hud, 0.62).done
		crackle.queue_free()
		_minigame_on(false)
		flags.broadcast_sent = true
		await scenes3a.broadcast()
		return


# ------------------------------------------------------------------ Choice point: the gate

func _step_gate() -> void:
	objective("North to the quarry — Lucía is in the Veil's Chapel", QUARRY_MOUTH)
	await _reach(QUARRY_MOUTH, 10.0)
	hud.clock("02:30")
	hud.show_zone("Quarry & Veil's Chapel")
	_checkpoint_at(QUARRY_MOUTH + Vector3(0, 0.1, -4), PI)
	_clear_marked()  # the town's Marked Ones stay in town: none follows into the quarry cinematic
	_quarry_cast()
	await scenes3b.quarry_arrive()
	for p in [[Vector3(-30, 0, -170), Vector3(-30, 0, -196)], [Vector3(20, 0, -168), Vector3(26, 0, -196)],
			[Vector3(-4, 0, -180), Vector3(14, 0, -184)]]:
		_marked_one(p[0], [p[0], p[1]], 18.0)
	var locks: Array[Interactable] = []
	for c in CAGES:
		var lock := Interactable.make(self, c + Vector3(0, 1.0, 1.3), "Pick the cage lock", func(_b: Node) -> void: pass,
			Color(0.7, 0.9, 1.0))
		lock.once = false
		locks.append(lock)
		_cage(c, lock)
	var choice := [""]
	var door := Interactable.make(self, CHAPEL_DOOR, "Unlock the Veil's Chapel", func(_b: Node) -> void:
		choice[0] = "chapel", Color(1.0, 0.3, 0.2))
	var gate := Interactable.make(self, GATE + Vector3(0, 0, 0.7), "Tunnel gate — leave now, without her?", func(_b: Node) -> void:
		if int(flags.key_parts) >= 3:
			choice[0] = "run"
		else:
			scenes3b.gate_locked(int(flags.key_parts)), Color(0.6, 0.9, 1.0))
	gate.once = false
	objective("The Veil's Chapel — or the Old Pass tunnel gate, if you're leaving", CHAPEL_DOOR)
	while choice[0] == "":
		await get_tree().physics_frame
	door.queue_free()
	gate.queue_free()
	for l in locks:  # the cages are a before-the-chapel job: no lockpicking in the middle of the boss fight
		if is_instance_valid(l):
			l.queue_free()
	_clear_marked()
	if choice[0] == "run":
		flags.ending = "run"


func _cage(at: Vector3, lock: Interactable) -> void:
	## Cages: a Marked townsperson locked up for the 03:00 collection. Freed ones prime the floodlights.
	## `lock` is the marker (the gate step frees it when the choice is made).
	var who := actor(MARKED[CAGES.find(at) % 2], at, 0.0)
	who.crouch(true)
	who.gesture("cower")
	while true:
		await lock.used
		_minigame_on(true)
		var ok: bool = await Lockpick.play(hud, 2).done
		_minigame_on(false)
		if ok:
			break
		player.noise(3.0)
		hud.banner("THE PICK SLIPPED", Color(1.0, 0.5, 0.4), 1.0)
	lock.queue_free()
	flags.cages += 1
	_reset_marked()  # the quarry's Marked Ones back on their rounds: none in the shot
	await scenes3b.cage_freed(who, flags.cages)
	who.queue_free()


# ------------------------------------------------------------------ C3.2 The Harvest

func _step_harvest() -> void:
	hud.clock("02:50")
	await scenes3b.the_harvest(allies)  # ends outside the chapel door (CHAPEL_OUT) facing the pit


# ------------------------------------------------------------------ M4 The Harvester

func _step_harvester() -> void:
	_checkpoint_at(CHAPEL_OUT, 0.0)
	floods.clear()
	for f in FLOODS:
		var fl := Floodlight.make(self, f[0], f[1], hud)
		fl.primed = flags.cages >= CAGES.size()
		fl.stunned.connect(func(_e: Node) -> void: scenes3b.flood_stun())
		floods.append(fl)
	for p in [Vector3(-26, 0.3, -196), Vector3(-16, 0.3, -196), Vector3(4, 0.3, -176)]:
		super._drop_loot(p)
	harvester = Harvester.spawn_at(self, HARV_SPAWN, PI)
	harvester.blocked.connect(scenes3b.blocked_bark)
	harvester.phase_changed.connect(_harvest_phase)
	await scenes3b.harvester_rises(harvester)
	var reset := func() -> void:
		harvester.reset_to(HARV_SPAWN)
		for f in floods:
			f.reset()
		objective("Get behind it — the skull sword blocks from the front. Light hurts it: flares, the flashlight (F)",
			harvester)
	await _fight(harvester, "THE HARVESTER",
		"Get behind it — the skull sword blocks from the front. Light hurts it: flares, the flashlight (F)", reset)
	_clear_marked()
	for f in floods:
		f.arm(false)
	await scenes3b.harvester_down(harvester)


func _harvest_phase(n: int) -> void:
	hud.mark_spike(Feel.SPIKE_SCRIPT)  # the Mark answers it changing
	if n == 2:
		await scenes3b.blackout(harvester)  # 03:00: the town goes dark, the floodlights don't
		for f in floods:
			f.arm(true)
		objective("Throw the floodlight switches — lure it into the light, then shoot", harvester)
		var n_called := 2 if "marcus" in allies else 4
		var called: Array[Enemy] = []
		for i in n_called:
			called.append(_marked_one(CALL_SPOTS[i], [CALL_SPOTS[i]], 24.0))
		for k in 3:  # never resolved: they fight for the Shepherd one last time
			var m: String = MEMBERS[k]
			if flags.get(m) in ["active", "fled"]:  # side by side, clear of the called one on CALL_SPOTS[3]
				var e := Enemy.spawn(self, "res://models/char_%s.glb" % m, CALL_SPOTS[3] - Vector3(1.6 * (k + 1), 0, 0), 0.0,
					{"display_name": m.capitalize(), "max_health": 160.0, "run_speed": 3.6, "melee_damage": 16.0,
					"mark_gain": Feel.MARK_GAIN.member})
				e.died.connect(func(_e: Enemy) -> void: flags[m] = "killed")
				_marked.append(e)
				called.append(e)
		_alert(called)
		_allies_help(called)
	else:
		scenes3b.phase3(harvester)
		objective("Roll through its sweep, then shoot the red cracks — a flare in its face opens it up", harvester)


func _allies_help(called: Array[Enemy]) -> void:
	## Each spared friend who came helps once (chapters.md §5 M4).
	for m in allies:
		await wait(2.5)
		if not is_instance_valid(harvester) or harvester.state == Enemy.State.DOWN:
			return
		match m:
			"owen":  # fire at its feet: light stuns it
				var fire := FuelBarrel.make(self, harvester.global_position + Vector3(1.5, 0, 1.5), false)
				fire.hit(0.0, fire.global_position)
				harvester.light_stun()
			"nora":  # the lanterns they carry go out: nearly blind
				for e in called:
					if is_instance_valid(e):
						e.sight_range = 7.0
			"julian":  # a canister into the crowd
				for e in called:
					if is_instance_valid(e) and e.state != Enemy.State.DEAD:
						GasCloud.make(self, e.global_position, 2.5, 6.0)
						e.stun(8.0)
			"marcus":  # already holding the road (fewer called)
				pass
		scenes3b.ally_helps(m, allies[m])


# ------------------------------------------------------------------ C3.3 The Shepherd + ending

func _step_shepherd() -> void:
	flags.ending = pick_ending(flags)
	if flags.ending == "run":
		await scenes3b.ending_run()
	else:
		await scenes3b.the_shepherd()
		await Callable(scenes3b, "ending_" + flags.ending).call()
	await scenes3b.end_card()


# ------------------------------------------------------------------ C3.4 Pop. 1413

func _step_epilogue() -> void:
	await scenes3b.pop_1413(flags.ending)
