class_name Ch1ScenesB
extends RefCounted
## Chapter 1 story beats, part B: Grady and the guns, Moth's call, the sawmill, Owen's boss fight
## beats, the spare/kill outcome and C1.3 the blackout. Staged through the director `d`
## (scripts/chapter1.gd): see its header for the API.

const STORE_DOOR := Vector3(14, 0, -17.6)
const ALEX_AT_STORE := Vector3(14, 0, -15.8)

var d: Chapter1Director
var hud: Node


func _init(director: Chapter1Director) -> void:
	d = director
	hud = director.hud


func _talk(speaker: Node3D, listener: Node3D, who: String, text: String, side := 1.0, time := -1.0) -> void:
	## Over-the-shoulder cut on the speaker, then the line.
	d.ots(speaker, listener, side)
	await hud.subtitle(who, text, time)


func _anim(e: Node) -> HumanoidAnim:
	return e.get_node("Anim")


func _face_node(e: Node3D, p: Vector3) -> void:
	## Turns an Enemy's model toward p (Enemies are not Actors).
	var m: Node3D = e.get_node("Model")
	m.rotation.y = atan2(p.x - e.global_position.x, p.z - e.global_position.z)


func _walk_enemy(e: Node3D, p: Vector3, speed := 1.6) -> Signal:
	## A scripted walk (a tween: collisions ignored), so it stops short of any wall / prop on the way.
	p.y = e.global_position.y
	p = d.clear_walk(e.global_position, p)
	_face_node(e, p)
	var a := _anim(e)
	a.speed = speed
	var tw := e.create_tween()
	tw.tween_property(e, "global_position", p, maxf(e.global_position.distance_to(p) / speed, 0.05))
	tw.tween_callback(func() -> void: a.speed = 0.0)
	return tw.finished


func _alex_near(target: Vector3, dist: float) -> Vector3:
	## Where the Alex stand-in stands: `dist` metres from target on the player's side, clear of walls (d.near).
	return d.near(target, dist)


# ------------------------------------------------------------------ M3 the square

func grady_talk(grady: Actor) -> void:
	## Player pressed E on Grady at his store door (14, 0, -17.6). Hand over the guns with
	## d.arm_player() at the right moment. Must end with controls on and the player camera active.
	d.cinematic(true)
	var alex := d.stand_in(ALEX_AT_STORE, PI)
	grady.global_position = STORE_DOOR
	grady.model.rotation.y = 0.0
	grady.look(alex)
	alex.look(grady)
	d.key_light(Vector3(14.0, 2.4, -15.0), Color(1.0, 0.75, 0.45), 1.5, 6.5)  # the shop window's warm pool
	d.shot(Vector3(18.0, 1.7, -15.0), Vector3(14, 1.3, -16.7), Vector3(17.2, 1.6, -14.4), 4.0, 48.0)
	grady.gesture("look_around", 2.2)
	await hud.subtitle("Grady", "You. From the motel. You made it through the night.", 2.6)
	alex.gesture("give", 4.4)  # holds the burned palm out until Grady tells him to put it away
	await _talk(alex, grady, "Alex", "Barely. Someone burned this into my hand.", -1.0, 2.8)
	d.shot(Vector3(15.2, 1.5, -14.6), Vector3(14, 1.0, -15.6))
	await d.wait(0.9)
	grady.gesture("arms_crossed")
	await _talk(grady, alex, "Grady", "Put that away. They count the lit windows.", 1.0, 2.6)
	grady.gesture("look_around", 1.6)
	await _talk(grady, alex, "Grady", "Marked folk pay in tokens. Everyone else is already paid for.", 1.0, 3.4)
	await _talk(alex, grady, "Alex", "I'm not paying for anything. I'm finding my sister.", -1.0, 2.8)
	grady.gesture("")
	await _talk(grady, alex, "Grady", "Then you'll need more than a flashlight. Wait here.", 1.0, 2.6)
	# Grady ducks into the store and comes back with the guns
	grady.look(null)
	d.shot(Vector3(10.5, 1.6, -13.5), Vector3(14, 1.4, -19.0))
	await grady.walk_to(Vector3(14, 0, -20.6), 1.8)
	grady.visible = false
	alex.gesture("look_around")
	d.shot(Vector3(12.8, 1.7, -18.4), alex.global_position + Vector3.UP * 1.5)
	await d.wait(1.2)
	grady.visible = true
	alex.gesture("")
	d.shot(Vector3(10.5, 1.6, -13.5), Vector3(14, 1.4, -19.0))
	await grady.walk_to(STORE_DOOR + Vector3(0, 0, 0.8), 1.8)
	grady.look(alex)
	grady.gesture("give")
	await _talk(grady, alex, "Grady", "My brother's revolver. He won't be needing it.", 1.0, 2.8)
	alex.gesture("reach", 1.2)
	d.shot(Vector3(15.6, 1.4, -16.2), Vector3(14, 1.15, -16.4))
	await d.wait(1.0)
	d.arm_player()
	await _talk(grady, alex, "Grady", "And a flare pistol. Off a harbor boat.", 1.0, 2.4)
	grady.gesture("")
	await _talk(alex, grady, "Alex", "Flares? Against a bow?", -1.0, 2.0)
	grady.look(alex)
	d.ots(grady, alex, -1.0)
	await hud.subtitle("Grady", "Owen's scared of fire. Everybody knows it. Nobody says it.", 3.2)
	grady.gesture("nod", 1.5)
	await _talk(grady, alex, "Grady", "Practice on the stall. Then come back to me.", 1.0, 2.6)
	grady.gesture("")
	grady.global_position = STORE_DOOR
	d.release_stand_in()
	d.cinematic(false)
	hud.banner("REVOLVER + FLARE GUN", Color(0.95, 0.85, 0.6), 1.5)


func guns_tutorial() -> void:
	hud.note("RMB aim · LMB fire · R reload", "", 4.0)


func moth_sawmill_call(grady: Actor) -> void:
	## Player told Grady they're ready; Moth calls on the radio and sends them to the sawmill.
	d.cinematic(true)
	var alex := d.stand_in(ALEX_AT_STORE, PI)
	grady.look(alex)
	alex.look(grady)
	await _talk(alex, grady, "Alex", "I'm ready. Where do I find him?", -1.0, 2.2)
	grady.gesture("shrug", 1.4)
	await _talk(grady, alex, "Grady", "You don't. He finds you.", 1.0, 2.0)
	# the radio in Alex's pocket crackles
	d.shot(Vector3(12.9, 1.7, -14.6), alex.global_position + Vector3.UP * 1.55)
	alex.look(null)
	alex.face(Vector3(8, 0, -12))
	alex.gesture("hand_to_face")
	Snd.sfx("radio_tune", null, -5.0)
	await hud.subtitle("Radio", "Kshhh... channel seven...", 1.8)
	await hud.subtitle("Moth", "You found Grady. Good.", 2.0)
	await hud.subtitle("Alex", "Moth? Who is Owen?", 1.8)
	d.shot(Vector3(15.3, 1.65, -14.9), alex.global_position + Vector3.UP * 1.6)
	await hud.subtitle("Moth", "The hunter at your window. He carries a piece of the gate key.", 3.2)
	await hud.subtitle("Alex", "What key?", 1.5)
	await hud.subtitle("Moth", "The tunnel gate. Three pieces. Three hunters. It's your only way out.", 3.4)
	grady.look(null)
	await grady.face(Vector3(-20, 0, -17.6), 0.3)
	grady.gesture("point")
	d.shot(Vector3(17.5, 1.5, -13.5), Vector3(13, 1.5, -17.0))
	await hud.subtitle("Moth", "The sawmill. West road, into the forest.", 2.4)
	grady.gesture("")
	grady.face(alex.global_position)
	d.shot(Vector3(12.9, 1.7, -14.6), alex.global_position + Vector3.UP * 1.55)
	await hud.subtitle("Moth", "Gunshots carry. Be quick, or be quiet.", 2.4)
	alex.gesture("")
	alex.face(Vector3(-20, 0, -15.8))
	await hud.subtitle("Alex", "Quick it is.", 1.4)
	grady.face(Vector3(14, 0, 0))
	d.release_stand_in()
	d.cinematic(false)


# ------------------------------------------------------------------ M4 the sawmill

func sawmill_road() -> void:
	## Player starts on the west road (-34, 0, 0) heading to the sawmill. Not required to say anything.
	hud.subtitle("Alex", "Pine and smoke. Stay off the gravel.", 2.6)


func lantern_found() -> void:
	## Optional pickup (not awaited): Owen's parents' burnt festival lantern.
	hud.banner("OWEN'S PARENTS' LANTERN", Color(1.0, 0.7, 0.3), 1.2)
	hud.say([["Alex", "A festival lantern. Burnt black.", 2.2],
		["Alex", "Two names scratched in the brass. Clarke.", 2.6]])


func ledger_read() -> void:
	## Optional pickup (not awaited): evidence #1.
	hud.banner("EVIDENCE #1", Color(0.8, 0.8, 0.9), 1.0)
	hud.say([["Alex", "A hunting ledger. Names, dates...", 2.2],
		["Alex", "Last column says delivered. God.", 2.4]])


func key_found() -> void:
	## Player just pressed E on the key part at (-121, 1, -2). Quick close-up, then back to play.
	var part := d.claim_item()
	d.cinematic(true)
	var p: Vector3 = d.player.global_position
	var alex := d.stand_in(Vector3(p.x, 0, p.z), atan2(-121.0 - p.x, -2.0 - p.z))
	var fwd := Vector3(sin(alex.model.rotation.y), 0, cos(alex.model.rotation.y))
	var right := fwd.cross(Vector3.UP)
	var key := Vector3(-121, 1.0, -2)
	d.shot(p - fwd * 1.0 + right * 0.5 + Vector3.UP * 1.8, key, p - fwd * 0.6 + right * 0.4 + Vector3.UP * 1.6, 2.0)
	if part:
		await alex.take(part)
	else:
		alex.hold("key_part")
	d.scenes_a._read_shot(alex)
	hud.banner("KEY PART 1 / 3", Color(0.6, 0.9, 1.0), 1.5)
	await hud.subtitle("Alex", "One of three. Now get out.", 1.8)
	alex.let_go()
	d.release_stand_in()
	d.cinematic(false)


# ------------------------------------------------------------------ M4 boss: Owen

func boss_intro(owen: Enemy) -> void:
	## Owen (Enemy, boss) just spawned at (-130, 0, -5); the fight starts when this returns.
	owen.set_physics_process(false)
	var a := _anim(owen)
	d.cinematic(true)
	var alex := d.stand_in(Vector3(-115, 0, -3), -PI / 2.0)
	alex.look(owen)
	# the arena gets its light: a warm spot over the yard and two lanterns at its edges (they stay on for the fight)
	d.key_light(Vector3(-112.0, 7.0, -2.0), Color(1.0, 0.7, 0.4), 6.0, 25.0, Vector3(-112.0, 0.0, -2.0), 55.0)
	d.key_light(Vector3(-122.0, 2.4, -8.0), Color(1.0, 0.75, 0.45), 1.5, 8.0)
	d.key_light(Vector3(-104.0, 2.4, 4.0), Color(1.0, 0.75, 0.45), 1.5, 8.0)
	Snd.stinger("reveal", -9.0)
	# the sawmill doors: Owen steps out of the dark
	d.shot(Vector3(-119.5, 0.7, -1.0), Vector3(-127, 1.4, -5), Vector3(-119.0, 1.3, -1.8), 5.0, 50.0, 0.015)
	var out := _walk_enemy(owen, Vector3(-118.6, 0, -3.8), 2.0)
	await d.wait(1.4)
	await hud.subtitle("Owen", "That's not yours.", 1.8)
	d.track(owen, Vector3(1.6, 0.2, 2.4), Vector3(0, 1.4, 0))
	await hud.subtitle("Alex", "Owen. You marked me.", 1.8)
	await out
	_face_node(owen, alex.global_position)
	await _talk(owen, alex, "Owen", "I delivered you. There's a difference.", 1.0, 2.6)
	alex.gesture("clutch_hand", 2.4)
	await _talk(alex, owen, "Alex", "Where's my sister?", -1.0, 1.8)
	a.gesture = "shake_head"
	var face := owen.global_position
	d.shot(face + (alex.global_position - face).normalized() * 1.3 + Vector3(0.3, 1.55, 0), face + Vector3.UP * 1.5)
	await hud.subtitle("Owen", "Dad used to say the forest keeps everything.", 2.6)
	a.gesture = ""
	# the bow comes up
	var o := owen.global_position
	d.shot(o + Vector3(1.4, 1.5, 1.2), o + Vector3(0, 1.45, 0))
	var tw := owen.create_tween()
	tw.tween_property(a, "aim", 1.0, 0.5)
	await hud.subtitle("Owen", "It'll keep you too.", 1.8)
	d.ots(owen, alex, -1.0, 0.4)
	await d.wait(0.8)
	d.release_stand_in()
	d.cinematic(false)
	a.aim = 0.0
	owen.set_physics_process(true)


func boss_phase2(owen: Enemy) -> void:
	## Owen dropped under 50% HP: switches from bow to chainsaw. Not awaited — the fight goes on.
	hud.banner("PHASE 2", Color(1.0, 0.4, 0.3), 1.0)
	var a := _anim(owen)
	a.gesture = "raise_weapon"
	owen.get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if is_instance_valid(a) and a.gesture == "raise_weapon":
			a.gesture = "")
	hud.subtitle("Owen", "ENOUGH! You don't walk out of here!", 2.6)


func boss_down(owen: Enemy) -> void:
	## Owen is on his knees (Enemy.State.DOWN). The spare / kill prompt appears after this.
	var a := _anim(owen)
	d.cinematic(true)
	var o := owen.global_position
	var from := _alex_near(o, 2.6)
	_face_node(owen, from)
	d.shot(Vector3(from.x, 1.9, from.z), o + Vector3.UP * 0.8, Vector3(from.x, 1.6, from.z).lerp(o, 0.2), 3.0)
	a.gesture = "slump"
	await hud.subtitle("Owen", "Go on. Do it.", 2.0)
	a.gesture = ""
	a.look = Vector2(0, -0.3)
	await hud.subtitle("Owen", "Everyone else did.", 2.0)
	a.look = Vector2.ZERO
	d.cinematic(false)


func owen_spared(owen: Enemy, with_lantern: bool) -> void:
	var a := _anim(owen)
	var o := owen.global_position
	d.cinematic(true)
	var alex := d.stand_in(_alex_near(o, 2.4), 0.0)
	alex.face(o, 0.01)
	alex.look(owen)
	_face_node(owen, alex.global_position)
	var side := (alex.global_position - o).normalized().cross(Vector3.UP)
	if with_lantern:
		d.shot(o + side * 3.2 + Vector3.UP * 1.3, (o + alex.global_position) * 0.5 + Vector3.UP * 0.9)
		await alex.walk_to(o.lerp(alex.global_position, 0.5), 1.0)
		alex.gesture("lean")
		await d.wait(0.7)
		var lantern: Node3D = load("res://models/festival_lantern.glb").instantiate()
		d.add_child(lantern)
		lantern.global_position = o.lerp(alex.global_position, 0.5)
		lantern.scale = Vector3.ONE * 0.6
		await d.wait(0.4)
		alex.gesture("")
		await alex.walk_to(alex.global_position + (alex.global_position - o).normalized() * 0.8, 0.8)
		alex.face(o, 0.3)
		d.shot(lantern.global_position + (alex.global_position - o).normalized() * 1.4 + Vector3.UP * 0.9,
			o + Vector3.UP * 1.0)
		a.gesture = "slump"
		await hud.subtitle("Owen", "Mom's lantern.", 2.0)
		a.gesture = "hand_to_face"
		await hud.subtitle("Owen", "You found it.", 1.8)
		await _talk(alex, owen, "Alex", "It was in the loft. With their names.", -1.0, 2.4)
		a.gesture = ""
		a.look = Vector2(0, -0.2)
		await _talk(owen, alex, "Owen", "Take the key. It's yours now.", 1.0, 2.2)
		a.gesture = "slump"
		await _talk(owen, alex, "Owen", "Tell me it wasn't for nothing.", 1.0, 2.6)
		alex.gesture("nod", 1.2)
		await _talk(alex, owen, "Alex", "It won't be.", -1.0, 1.6)
	else:
		d.shot(o + side * 3.0 + Vector3.UP * 1.4, (o + alex.global_position) * 0.5 + Vector3.UP * 1.0)
		alex.gesture("shake_head", 1.2)
		await hud.subtitle("Alex", "No. Not like them.", 1.8)
		a.look = Vector2(0, -0.3)
		await _talk(owen, alex, "Owen", "Why?", 1.0, 1.4)
		await _talk(alex, owen, "Alex", "Because somebody has to stop.", -1.0, 2.2)
		a.gesture = "slump"
		await _talk(owen, alex, "Owen", "Then go. Before the lights go out.", 1.0, 2.4)
	# Owen gets up and walks back into the dark of the sawmill
	a.gesture = ""
	a.look = Vector2.ZERO
	a.crouching = false
	owen.set_physics_process(false)
	owen.collision_layer = 0
	d.shot(o + side * 2.6 + Vector3.UP * 1.2, o + Vector3.UP * 0.8)
	await d.wait(0.8)
	_walk_enemy(owen, Vector3(-131, 0, -5), 1.6)
	d.track(owen, side * 3.0 + Vector3.UP * 0.6, Vector3(0, 1.3, 0))
	await d.wait(2.2)
	alex.look(null)
	d.ots(owen, alex, 1.0)
	await d.wait(1.6)
	await hud.fade(1.0, 0.4)
	owen.visible = false
	d.release_stand_in()
	d.cinematic(false)
	hud.fade(0.0, 0.6)


func owen_killed(owen: Enemy) -> void:
	var o := owen.global_position
	d.cinematic(true)
	var alex := d.stand_in(_alex_near(o, 3.0), 0.0)
	alex.face(o, 0.01)
	alex.look(owen)
	var back := (alex.global_position - o).normalized()
	d.shot(o + back.cross(Vector3.UP) * 1.8 + Vector3.UP * 1.3, o + Vector3.UP * 0.3)
	await hud.subtitle("Owen", "M-mom...", 2.0)
	d.ots(alex, owen, 1.0)
	alex.gesture("slump")
	await d.wait(1.6)
	alex.gesture("hand_to_face")
	await hud.subtitle("Alex", "What did I just do.", 2.2)
	alex.look(null)
	alex.gesture("")
	var a_pos := alex.global_position
	d.shot(a_pos + back * 1.6 + Vector3.UP * 2.0, o, a_pos + back * 2.6 + Vector3.UP * 2.6, 3.5)
	await d.wait(1.8)
	await hud.subtitle("Alex", "The key. Just take the key.", 2.0)
	d.release_stand_in()
	d.cinematic(false)


# ------------------------------------------------------------------ C1.3 Blackout

func blackout() -> void:
	## C1.3 then the end-of-chapter card. Player is in the sawmill yard (~(-110, 0, 0)).
	await d.wait(1.0)
	d.cinematic(true)
	var p: Vector3 = d.player.global_position
	var alex := d.stand_in(Vector3(p.x, 0, p.z), PI / 2.0)
	var yard := alex.global_position
	# 03:00, the lamps go out street by street, toward the yard
	d.shot(yard + Vector3(-3.0, 1.7, 1.8), Vector3(-60, 3.0, 0.0), yard + Vector3(-2.5, 2.0, 1.2), 5.0)
	await hud.subtitle("", "03:00", 1.6)
	d.lights_out(Vector3(0, 0, 0), 30.0)
	Snd.sfx("door_slam", null, -4.0, 0.6)
	alex.look(Vector3(-60, 3, 0))
	await hud.subtitle("Alex", "The lights...", 1.6)
	d.shot(yard + Vector3(1.8, 1.55, 1.2), yard + Vector3(0, 1.55, 0))
	alex.gesture("look_around")
	await d.wait(2.0)
	alex.gesture("")
	# out of the fog on the forest road
	var harvester := d.actor("res://models/char_boss.glb", Vector3(-86, 0, -14), 0.0)
	var eyes := OmniLight3D.new()
	eyes.light_color = Color(1.0, 0.1, 0.05)
	eyes.light_energy = 2.0
	eyes.omni_range = 4.0
	harvester.model.add_child(eyes)
	eyes.position = Vector3(0, 2.6, 0.5)
	Snd.attach(harvester, "harvester", -4.0)  # the red-eyed hum
	Snd.stinger("reveal", -8.0)
	hud.mark_spike(Feel.SPIKE_SCRIPT)  # the first sight of the Harvester
	var walk := harvester.walk_to(Vector3(-86, 0, 0), 1.6)
	d.shot(Vector3(-91, 0.6, 3.0), Vector3(-86, 2.0, -8), Vector3(-91, 0.9, 2.0), 6.0)
	await d.wait(2.6)
	d.track(harvester, Vector3(2.4, 0.5, -1.8), Vector3(0, 0.4, 0))
	await d.wait(2.4)
	d.ots(harvester, alex, 1.0)
	alex.look(harvester)
	await hud.subtitle("Alex", "What is that...", 1.8)
	await walk
	# it stops, and turns its head toward Alex
	d.shot(Vector3(-88.5, 2.6, 2.2), Vector3(-86, 2.6, 0), Vector3(-88.0, 2.7, 1.6), 3.0)
	harvester.look(alex)
	await d.wait(2.2)
	d.shot(yard + Vector3(-1.4, 1.6, 0.6), yard + Vector3(0, 1.5, 0))
	alex.gesture("hand_to_face")
	await d.wait(1.0)
	alex.gesture("cower")
	await d.wait(0.9)
	d.shot(Vector3(-87.4, 2.7, 0.3), Vector3(-86, 2.65, 0))
	await d.wait(1.0)
	hud.fade(1.0, 0.05)
	await d.wait(1.2)
	harvester.queue_free()
	alex.gesture("")
	# the radio in the dark
	await hud.subtitle("Radio", "Kshhh...", 1.4)
	await hud.subtitle("Moth", "Harbor. Tomorrow. Come alone.", 2.6)
	await hud.subtitle("Alex", "Moth, what was that thing?", 2.0)
	await hud.subtitle("Radio", "Kshhh...", 1.4)
	hud.banner("I · THE MARK", Color(0.85, 0.8, 0.7), 4.0)
	await d.wait(2.5)
	var f: Dictionary = d.flags
	var owen_text: String = {"spared": "Owen: spared", "killed": "Owen: killed"}.get(f.owen, "Owen: fled")
	await hud.say([["", "End of Chapter 1.  %s · Evidence %d · Tokens %d · Key part %s" % [owen_text,
		f.evidence.size(), f.tokens, "1/3" if f.key_part else "0/3"]]])
	d.release_stand_in()
	d.cinematic(false)
	hud.fade(0.0, 1.5)


# ------------------------------------------------------------------ side mission: Tripwire (evidence #2)

func tripwire_hint() -> void:
	## Bark + tip, the first time Alex nears the forest trail's wires. Not awaited.
	hud.note("Bells on a wire across the trail. Crouch (C) to get close without ringing them; E cuts the wire.",
		"TRIPWIRE", 5.0)
	hud.subtitle("Alex", "Bells on a wire. Owen's doorbell.", 2.4)


func tripwire_rang() -> void:
	## The first bell Alex set off (whatever is in earshot is coming). Not awaited.
	hud.subtitle("Alex", "Damn it. Everyone heard that.", 2.0)


func tripwire_cut(left: int) -> void:
	## One wire cut, `left` to go. Not awaited.
	hud.banner("WIRE CUT  ·  %d LEFT" % left, Color(0.85, 0.8, 0.6), 0.9)


func tripwire_done(clean: bool, tokens: int) -> void:
	## The last wire: evidence #2 was tied under its stake. Not awaited.
	hud.banner("EVIDENCE #2" + ("  +%d TOKENS" % tokens if clean else ""), Color(0.8, 0.8, 0.9), 1.2)
	hud.say([["Alex", "Oilcloth, tied under the stake. Moth's handwriting.", 2.6],
		["Alex", "\"His wires. He marks whoever gets through.\" Photos of doors.", 3.0]])
