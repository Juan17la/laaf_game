class_name Ch3ScenesB
extends RefCounted
## Chapter 3 story beats, part B: the quarry (arrival, cages, the gate), C3.2 "The Harvest", the final
## fight's beats (the 03:00 blackout, allies, barks, the fall), C3.3 "The Shepherd", the five endings,
## the end card and C3.4 "Pop. 1413" — the post-end cinematic: Lucía tells what the Veil really was
## and how it ended. Staged through the director `d` (scripts/chapter3.gd; API in scripts/chapter1.gd).
## Lore (chapters.md §5, C3.4): the Shepherd is Elias Morrow, the old quarry chaplain. Thirty-one years
## ago the pit fell in on nine men, his son Caleb among them; the town sealed it to keep the pass open.
## Caleb dug out on the ninth day, blind to light. Elias made grief a religion and his son its
## executioner: the Harvester. The 03:00 blackout was always for Caleb's eyes.

const SHEPHERD := "res://models/char_shepherd.glb"
const MARKED := ["res://models/char_marked_man.glb", "res://models/char_marked_woman.glb"]
const BOSS := "res://models/char_boss.glb"
const CHAPEL := Vector3(-22, 0, -210)
const AISLE := Vector3(-22, 0, -208.0)  ## Alex, inside the chapel door
const AT_CAGE := Vector3(-23.6, 0, -211.9)  ## between the back bench and Lucía's cage
const AISLE_END := Vector3(-22.0, 0, -211.9)  ## foot of the aisle: the way round the back bench to AT_CAGE
const LUCIA_BARS := Vector3(-24.8, 0, -212.7)  ## inside her cage (LUCIA_CAGE, door on +Z), at the front bars
const LUCIA_OUT := Vector3(-25.0, 0, -211.8)  ## just out of the cage door, 1.4 m from Alex at AT_CAGE
const SHEP_SPOT := Vector3(-19.6, 0, -213.4)  ## in the dark beside the altar
const ALTAR_TOP := Vector3(-21.6, 1.02, -213.6)
const GATE_IN := Vector3(30, 0, -221.2)
const RED := Color(1.0, 0.15, 0.08)
const BONE := Color(0.82, 0.78, 0.68)
const IRON := Color(0.18, 0.17, 0.16)
const BLOCK_LINES := ["The sword takes it — get behind it!", "It blocks from the front.", "Its back. Hit its back.",
	"Not the sword. Around it."]
const ALLY_LINES := {"owen": "It's only fire. I'm not scared of it anymore!",
	"nora": "Lanterns out, children. Everyone in the dark.", "julian": "Breathe in. Deeper.",
	"marcus": "I've got the road! Nobody else comes down!"}
const ALLY_ARRIVE := {"owen": "You said tell me it wasn't for nothing. Let's make it something.",
	"nora": "Nobody else goes in a cage. Not one more.", "julian": "Triage. Tonight it's him.",
	"marcus": "Elena drew that map for you. We'll follow it."}
const FATES := {  ## Mixed ending cards: [spared, killed, still out there]
	"owen": ["Owen keeps a fire going at the sawmill. Nobody is afraid of it.", "Owen is buried by the harbor wall, next to Elena.",
		"Owen still walks the forest at night, whistling."],
	"nora": ["Nora opened the school again. The lights stay on.", "Nora is buried by the harbor wall, a yellow jacket folded on the stone.",
		"Nora still talks to Lily on the school PA."],
	"julian": ["Julian runs the clinic. He signs every file with both names.", "Julian is buried by the harbor wall. No one wrote the time.",
		"Julian still keeps the clinic sealed."],
	"marcus": ["Marcus rings the bell at dawn now. It calls no one.", "Marcus lies under the bell he rang for three years.",
		"Marcus still holds the chapel key."]}

var d: Chapter3Director
var hud: Node
var a3: Ch3ScenesA
var c1a: Ch1ScenesA
var c1b: Ch1ScenesB
var c2a: Ch2ScenesA
var c2b: Ch2ScenesB
var _shep: Actor
var _iron: Node3D
var _last_bark := -99999


func _init(director: Chapter3Director) -> void:
	d = director
	hud = director.hud
	a3 = director.scenes3a if director.scenes3a else Ch3ScenesA.new(director)
	c1a = a3.c1a
	c1b = a3.c1b
	c2a = a3.c2a
	c2b = a3.c2b


# ------------------------------------------------------------------ helpers

func _shot(from: Vector3, look: Vector3, to := Vector3.INF, time := 6.0) -> void:
	a3._shot(from, look, to, time)


func _bark(who: String, text: String, every := 7.0) -> void:
	## Throttled bark for the fight (not awaited).
	if Time.get_ticks_msec() - _last_bark < every * 1000.0:
		return
	_last_bark = Time.get_ticks_msec()
	hud.subtitle(who, text, 2.0)


func _harv_actor(pos: Vector3, yaw: float) -> Actor:
	## The Harvester as a cinematic actor, red eyes lit.
	var h := d.actor(BOSS, pos, yaw)
	var eyes := OmniLight3D.new()
	eyes.light_color = RED
	eyes.light_energy = 2.0
	eyes.omni_range = 4.0
	h.model.add_child(eyes)
	eyes.position = Vector3(0, 2.6, 0.5)
	return h


func _drag(harv: Actor, body: Actor) -> void:
	## The Harvester hauls a body by the ankle: its left hand reaches down and back (arm IK), the feet ride in
	## that hand and the rest trails face up along the ground behind, arms over the head, jolting with each
	## step. Runs until the body gets the "dropped" meta.
	body.grounded = false
	body.gesture("hands_up")  # the arms trail past the head
	harv.anim.ik["L"] = Transform3D(Basis(), Vector3(0.45, 0.75, -0.45))
	harv.anim.ik_w["L"] = 1.0
	var hand: Node3D = harv.model.find_child("HandL", true, false)
	var t := 0.0
	while is_instance_valid(body) and is_instance_valid(harv) and not body.has_meta("dropped"):
		t += harv.get_process_delta_time()
		var feet: Vector3 = hand.global_position if hand else harv.global_position + Vector3.UP * 0.8
		var back := -harv.model.global_basis.z
		back.y = 0.0
		back = back.normalized()
		var tilt := asin(clampf((feet.y - 0.15) / 1.7, 0.0, 0.9))  # feet up in the hand, head on the ground
		var y := (back * cos(tilt) + Vector3.DOWN * sin(tilt)).normalized()  # feet → head
		var z := (Vector3.UP - y * Vector3.UP.dot(y)).normalized()  # on its back: the front faces up
		var b := Basis(y.cross(z), y, z).rotated(y, 0.12 * sin(t * 7.0))  # rolls with the steps
		body.global_transform = Transform3D(b, feet)
		await harv.get_tree().process_frame


func _lie(a: Node3D) -> void:
	## Flat on the ground (a body, a spent man).
	var m: Node3D = a.model if a is Actor else a.get_node("Model")
	var tw := m.create_tween()
	tw.tween_property(m, "rotation:x", -PI / 2.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "position:y", 0.25, 0.6)


func dawn(time := 6.0) -> void:
	## Night → pale dawn: sky, ambient, fog and the moon warm up (not awaited).
	var env: Environment = d.get_parent().get_node("WorldEnvironment").environment
	var moon: DirectionalLight3D = d.get_parent().get_node("Moon")
	var tw := d.create_tween().set_parallel()
	tw.tween_property(env, "background_color", Color(0.46, 0.42, 0.44), time)
	tw.tween_property(env, "ambient_light_color", Color(0.85, 0.74, 0.66), time)
	tw.tween_property(env, "ambient_light_energy", 0.9, time)
	tw.tween_property(env, "fog_light_color", Color(0.62, 0.52, 0.48), time)
	tw.tween_property(env, "fog_density", 0.012, time)
	tw.tween_property(env, "volumetric_fog_density", 0.01, time)
	tw.tween_property(moon, "light_color", Color(1.0, 0.78, 0.58), time)
	tw.tween_property(moon, "light_energy", 0.7, time)


func _members(state: String) -> Array:
	return Chapter3Director.MEMBERS.filter(func(m: String) -> bool: return d.flags.get(m) == state)


# ------------------------------------------------------------------ the quarry

func quarry_arrive() -> void:
	## The pit from the mouth of the quarry road: the chapel, the cages, the gate. Then the choice.
	d.cinematic(true)
	var alex := d.stand_in(d.player.global_position, PI)
	var p := alex.global_position
	_shot(p + Vector3(3.0, 6.0, -1.0), Vector3(-22, 2.0, -208), p + Vector3(1.0, 5.0, -4.0), 6.0)
	await hud.subtitle("", "The quarry. Festival lanterns strung over the pit like trophies.", 3.0)
	await hud.subtitle("", "The Veil's Chapel, cut into the rock. Somewhere in there: Lucía.", 3.0)
	_shot(Vector3(18, 3.0, -200), Vector3(30, 3.5, -222.5))
	await hud.subtitle("", "And the Old Pass gate. Three slots.", 2.2)
	alex.gesture("clutch_hand", 2.0)
	_shot(p + Vector3(0.9, 1.6, -1.0), p + Vector3.UP * 1.5)
	await hud.subtitle("Alex", "Three parts in my pocket. I could just go.", 2.6)
	alex.look(Vector3(-22, 1.5, -208))
	await hud.subtitle("Alex", "…No. I came for her.", 2.0)
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)


func gate_locked(have: int) -> void:
	hud.subtitle("Alex", "%d of 3 key parts. It won't turn." % have, 2.2)


func cage_freed(who: Actor, n: int) -> void:
	## A freed Marked townsperson: they'll ready the floodlight generators.
	d.cinematic(true)
	var alex := d.stand_in(c1b._alex_near(who.global_position, 1.5), 0.0)
	alex.face(who.global_position, 0.01)
	who.crouch(false)
	who.gesture("")
	who.face(alex.global_position, 0.2)
	who.look(alex)
	d.ots(who, alex, 1.0)
	await hud.subtitle("Marked One", "You opened it. Nobody opens them.", 2.2)
	await who.face(Chapter3Director.FLOODS[1][0], 0.3)  # the rig by the cages: points at it, not at Alex
	who.gesture("point", 1.8)
	await hud.subtitle("Marked One", "The floodlights. The old generators. We'll get them turning over.", 3.0)
	if n >= Chapter3Director.CAGES.size():
		hud.banner("FLOODLIGHTS PRIMED — NO CRANKING", Color(1.0, 0.95, 0.7), 2.0)
	await c1b._talk(alex, who, "Alex", "Then stay in the dark till it's over.", -1.0, 2.0)
	who.walk_to(who.global_position + Vector3(-6, 0, 10), 2.4)
	await d.wait(1.0)
	d.release_stand_in()
	d.cinematic(false)


# ------------------------------------------------------------------ C3.2 The Harvest

func the_harvest(allies: Dictionary) -> void:
	## Inside the chapel: Lucía, the Shepherd's radio; the Harvester comes home; the allies arrive.
	## Ends: player at CHAPEL_OUT facing +Z (the pit), control on, the allies at their ALLY_SPOTS.
	d.cinematic(true)
	await hud.fade(1.0, 0.6)
	var lucia: Actor = d.lucia
	lucia.global_position = Chapter3Director.LUCIA_CAGE
	lucia.crouch(true)
	lucia.model.rotation.y = 0.0
	var radio: Node3D = (load("res://models/int_radio.glb") as PackedScene).instantiate()
	d.add_child(radio)
	radio.global_position = ALTAR_TOP
	radio.rotation.y = PI
	var alex := d.stand_in(AISLE, PI)
	var glow := c2b._light(CHAPEL + Vector3(0, 3.8, -1.0), Color(1.0, 0.45, 0.25), 1.6, 8.0, true)
	_shot(Vector3(-19.0, 1.8, -205.8), Vector3(-22, 1.5, -212), Vector3(-19.4, 2.2, -207.0), 5.0)
	hud.fade(0.0, 0.8)
	await hud.subtitle("", "Candles. Festival lanterns. An eye as tall as a man on the far wall.", 3.0)
	_shot(Vector3(-21.2, 1.0, -209.6), lucia.global_position + Vector3.UP * 0.7)
	await hud.subtitle("Lucía", "…Alex?", 1.4)
	alex.look(lucia)
	await alex.walk_to(AISLE_END, 2.6)  # down the aisle, not through the back bench
	await alex.walk_to(AT_CAGE, 2.6)
	alex.face(LUCIA_BARS, 0.2)
	lucia.crouch(false)
	lucia.global_position = LUCIA_BARS
	lucia.face(alex.global_position, 0.2)
	lucia.look(alex)
	d.ots(lucia, alex, 1.0)
	await hud.subtitle("Alex", "Lucía.", 1.2)
	await hud.subtitle("Lucía", "You came. You idiot. I told you not to come.", 2.6)
	await c1b._talk(alex, lucia, "Alex", "You told me it was beautiful.", -1.0, 2.0)
	lucia.gesture("reach")
	await d.wait(0.5)
	c1a._hand_shot(lucia)
	var brand := c1a._light(c1a._hand(lucia).global_position + Vector3.UP * 0.12, Color(1.0, 0.4, 0.1), 0.6, 0.7, true)
	await hud.subtitle("", "Her hand through the bars. The same eye.", 2.2)
	brand.queue_free()
	lucia.gesture("")
	# the radio on the altar
	_shot(ALTAR_TOP + Vector3(0.8, 0.4, 1.0), ALTAR_TOP)
	await hud.subtitle("Radio", "Kshhh…", 1.2)
	await hud.subtitle("Shepherd", "You came for her.", 1.8)
	await hud.subtitle("Shepherd", "They all come for someone.", 2.2)
	alex.look(ALTAR_TOP)
	a3._face(alex)
	await hud.subtitle("Alex", "Where are you?", 1.4)
	_shot(ALTAR_TOP + Vector3(-0.7, 0.3, 0.9), ALTAR_TOP)
	await hud.subtitle("Shepherd", "Close. I'm always close.", 2.0)
	alex.gesture("reach", 1.0)
	d.ots(lucia, alex, -1.0)
	await hud.subtitle("", "The padlock has no keyhole. Just an eye.", 2.2)
	await hud.subtitle("Shepherd", "Only my boy opens the cages. It's nearly three.", 2.6)
	# the floor shakes: it's coming home down the quarry road, dragging a Taken by the ankle
	var harv := _harv_actor(Vector3(2, 0, -152), PI)
	var pit := Chapter3Director.HARV_SPAWN  # the pit gets a key light and two lanterns (they stay on for the fight)
	d.key_light(pit + Vector3(0, 7.0, 0), Color(1.0, 0.7, 0.4), 6.0, 28.0, pit, 55.0)
	d.key_light(pit + Vector3(-9, 2.4, 4), Color(1.0, 0.75, 0.45), 1.5, 8.0)
	d.key_light(pit + Vector3(9, 2.4, -4), Color(1.0, 0.75, 0.45), 1.5, 8.0)
	Snd.stinger("reveal", -8.0)
	hud.mark_spike(Feel.SPIKE_SCRIPT)  # it comes home
	Snd.attach(harv, "harvester", -2.0)
	var taken := d.actor(MARKED[0], Vector3(2, 0, -150), 0.0)
	_drag(harv, taken)
	var steps := harv.walk_to(Chapter3Director.HARV_SPAWN, 1.8)
	_shot(Vector3(-12.0, 1.0, -160.0), Vector3(1, 1.2, -154))
	await hud.subtitle("", "Footsteps, and something heavy scraping along behind them.", 2.6)
	_shot(Vector3(-6.0, 0.7, -156.0), Vector3(1.5, 0.4, -152))
	await hud.subtitle("", "It drags a Taken by the ankle. Face up, arms trailing through the dirt.", 3.0)
	lucia.gesture("cower")
	_shot(Vector3(-24.6, 1.4, -210.2), lucia.global_position + Vector3.UP * 1.3)
	await hud.subtitle("Lucía", "Alex, don't go out there. It's not what you think it is.", 2.8)
	lucia.gesture("")
	d.track(harv, Vector3(-4.0, 1.4, -3.0), Vector3(0, 1.8, 0))
	await steps
	taken.set_meta("dropped", true)  # it lets go of the ankle: the body stays where it fell
	harv.anim.ik_w["L"] = 0.0
	taken.global_transform = Transform3D(Basis(), Chapter3Director.HARV_SPAWN + Vector3(1.2, 0, 0.8))
	taken.gesture("")
	_lie(taken)
	harv.face(Chapter3Director.CHAPEL_OUT, 0.8)
	# Alex at the chapel door
	alex.look(null)
	alex.global_position = Chapter3Director.CHAPEL_OUT - Vector3.UP * 0.1
	alex.model.rotation.y = 0.0
	alex.look(harv)
	d.ots(harv, alex, 1.0)
	await hud.subtitle("", "It drops the body like a sack of feed. And looks at you.", 2.8)
	var to_alex := (Chapter3Director.CHAPEL_OUT - harv.global_position).normalized()
	_shot(harv.global_position + to_alex * 2.4 + to_alex.cross(Vector3.UP) * 0.6 + Vector3.UP * 2.5,
		harv.global_position + Vector3.UP * 2.6)
	await d.wait(1.6)
	# whoever Alex spared, and gave back what they'd lost, comes down the rock paths
	for m in allies:
		var a: Actor = allies[m]
		a.visible = true
		a.global_position = a.global_position + Vector3(-14, 0, 6)
		c2b._lantern(a)
		a.walk_to(Chapter3Director.ALLY_SPOTS[m], 3.0)
	if not allies.is_empty():
		_shot(Chapter3Director.CHAPEL_OUT + Vector3(-3.0, 1.6, 4.0), Chapter3Director.CHAPEL_OUT + Vector3(-9, 1.3, 2))
		await hud.subtitle("", "Lanterns on the rock path. Not the group's. Not anymore.", 2.6)
		for m in allies:
			var a: Actor = allies[m]
			await c1a._settle(a)  # arrives first: no turning to face it mid-stride
			a.face(harv.global_position, 0.4)
			a.look(harv)
			_shot(a.global_position + Vector3(1.4, 1.6, 2.0), a.global_position + Vector3.UP * 1.5)
			await hud.subtitle(m.capitalize(), ALLY_ARRIVE[m], 2.8)
	harv.gesture("raise_weapon")
	_shot(Chapter3Director.CHAPEL_OUT + Vector3(0.8, 1.7, -1.2), harv.global_position + Vector3.UP * 2.0)
	await hud.subtitle("", "The skull sword comes up.", 1.8)
	await hud.fade(1.0, 0.3)
	harv.queue_free()
	glow.queue_free()
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)
	hud.fade(0.0, 0.4)


# ------------------------------------------------------------------ M4 the fight

func harvester_rises(h: Harvester) -> void:
	## Two seconds: the enemy the player fights now stands where the actor stood.
	var frozen := c2a._freeze()
	d.cinematic(true)
	var a := c1b._anim(h)
	c1b._face_node(h, Chapter3Director.CHAPEL_OUT)
	a.gesture = "raise_weapon"
	_shot(h.global_position + Vector3(4.0, 1.0, -3.0), h.global_position + Vector3.UP * 2.2)
	hud.banner("THE HARVESTER", Color(0.9, 0.2, 0.15), 2.0)
	await d.wait(1.6)
	a.gesture = ""
	d.cinematic(false)
	c2a._thaw(frozen)


func blocked_bark() -> void:
	_bark("Alex", BLOCK_LINES[randi() % BLOCK_LINES.size()], 9.0)


func flood_stun() -> void:
	hud.banner("LIGHT", Color(1.0, 0.95, 0.75), 0.8)
	_bark("Alex", ["It can't stand the light!", "Now — while it's blind!", "Hit it! Hit it now!"][randi() % 3], 6.0)


func blackout(h: Harvester) -> void:
	## Phase 2 at 03:00: every light in the valley dies but the floodlights' own generators.
	var frozen := c2a._freeze()
	d.cinematic(true)
	var a := c1b._anim(h)
	hud.banner("PHASE 2", Color(1.0, 0.4, 0.3), 1.0)
	hud.clock("03:00")
	_shot(Vector3(-2, 9.0, -160), h.global_position + Vector3.UP * 1.5)
	await hud.subtitle("", "03:00", 1.2)
	d.lights_out(h.global_position, 40.0)
	await hud.subtitle("Shepherd", "Three o'clock. Lights out, children.", 2.4)
	a.gesture = "raise_weapon"
	_shot(h.global_position + Vector3(3.0, 1.2, 3.0), h.global_position + Vector3.UP * 2.2)
	await hud.subtitle("", "It plants the sword in the stone. Up on the rim, lanterns answer.", 2.8)
	_shot(Vector3(-30, 2.0, -178), Vector3(-36, 4.5, -186))
	await hud.subtitle("", "Only the old floodlights have their own generators.", 2.6)
	a.gesture = ""
	d.cinematic(false)
	c2a._thaw(frozen)


func phase3(_h: Harvester) -> void:
	hud.banner("PHASE 3", Color(1.0, 0.4, 0.3), 1.0)
	hud.say([["Shepherd", "Leave him be! He only does what I ask!", 2.4],
		["", "Its guard breaks into a wild sweep. Roll through it.", 2.4]])


func ally_helps(m: String, a: Actor) -> void:
	await a.face(d.harvester.global_position if is_instance_valid(d.harvester) else a.global_position, 0.3)
	a.gesture("point" if m in ["nora", "marcus"] else "raise_weapon", 1.6)
	hud.subtitle(m.capitalize(), ALLY_LINES[m], 2.4)


func harvester_down(h: Harvester) -> void:
	var frozen := c2a._freeze()
	d.cinematic(true)
	var a := c1b._anim(h)
	var o := h.global_position
	var from := c1b._alex_near(o, 4.0)
	_shot(Vector3(from.x, 1.2, from.z), o + Vector3.UP * 1.6, Vector3(from.x, 1.0, from.z).lerp(o, 0.2), 3.0)
	a.gesture = "slump"
	await hud.subtitle("", "It kneels. The sword slides out of its hands.", 2.4)
	var sword := c2b._box(d, Vector3(0.3, 0.2, 2.0), BONE, Vector3.ZERO)
	sword.global_position = o + Vector3(1.0, 0.1, 0.8)
	sword.rotation.y = 0.7
	await hud.subtitle("", "The skulls scatter over the stone.", 2.0)
	_shot(o + Vector3(0.6, 1.0, 2.6), o + Vector3.UP * 1.4)
	await hud.subtitle("Radio", "Kshhh— no. No, no, no—", 1.8)
	await hud.subtitle("Shepherd", "Caleb—", 1.4)
	_lie(h)
	await d.wait(0.8)
	var alex := d.stand_in(from, 0.0)
	alex.face(o, 0.01)
	alex.look(h)
	a3._face(alex)
	await hud.subtitle("Alex", "…Caleb?", 1.4)
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)
	c2a._thaw(frozen)
	h.set_physics_process(false)  # stays where it fell (C3.4 comes back to it)


# ------------------------------------------------------------------ C3.3 The Shepherd

func the_shepherd() -> void:
	## Behind the altar: a tired old man with a radio. Ends inside the chapel, cinematic still on,
	## _shep / _iron / Lucía staged for the ending_* that follows.
	d.cinematic(true)
	await hud.fade(1.0, 0.5)
	var lucia: Actor = d.lucia
	lucia.global_position = Chapter3Director.LUCIA_CAGE
	lucia.crouch(true)
	lucia.look(null)
	var alex := d.stand_in(AISLE, PI)
	_shep = d.actor(SHEPHERD, SHEP_SPOT, atan2(AISLE.x - SHEP_SPOT.x, AISLE.z - SHEP_SPOT.z))  # facing the door
	_shep.crouch(true)
	_iron = c2b._prop(d, "brand_iron", Vector3(0.05, 0.05, 0.7), IRON, Vector3.ZERO, 0.0)
	_iron.global_position = ALTAR_TOP + Vector3(-0.9, 0.03, 0.1)
	_iron.rotation.y = 0.4
	if _iron is MeshInstance3D:  # stand-in: the model has its own glowing Brand head
		c2b._box(_iron, Vector3(0.14, 0.03, 0.14), RED, Vector3(0, 0, -0.38), 3.0).name = "Brand"
	var lamp := c2b._light(SHEP_SPOT + Vector3(0.3, 1.4, 0.6), Color(1.0, 0.6, 0.3), 0.7, 3.5, true)
	lamp.name = "ShepLamp"
	_shot(Vector3(-18.8, 1.4, -206.4), SHEP_SPOT + Vector3.UP * 0.9)
	hud.fade(0.0, 0.6)
	await hud.subtitle("", "He'd been sitting there the whole time. Three metres from the cage.", 3.0)
	_shep.look(alex)
	_shot(SHEP_SPOT + Vector3(-0.6, 1.2, 1.4), SHEP_SPOT + Vector3.UP * 0.95)
	await hud.subtitle("", "An old man. A radio. A brand iron on the altar, still warm.", 2.8)
	await hud.subtitle("Shepherd", "I never took anyone.", 1.8)
	await hud.subtitle("Shepherd", "They brought them to me.", 2.2)
	alex.look(_shep)
	await alex.walk_to(AISLE + Vector3(0.4, 0, -1.4), 1.2)
	d.ots(alex, _shep, -1.0)
	await hud.subtitle("Alex", "Open the cage.", 1.4)
	_shep.gesture("give")
	var keys := c2b._prop(c2b._hand(_shep), "keyring", Vector3(0.06, 0.02, 0.1), Color(0.7, 0.6, 0.3), Vector3(0, -0.1, 0.04))
	d.ots(_shep, alex, 1.0)
	await hud.subtitle("Shepherd", "Take them. I'm finished with keys.", 2.2)
	keys.queue_free()
	_shep.gesture("")
	alex.gesture("reach", 0.8)
	await d.wait(0.5)
	# the cage opens; Lucía gets up
	await alex.walk_to(AISLE_END, 1.4)
	await alex.walk_to(AT_CAGE, 1.4)
	alex.face(LUCIA_OUT, 0.3)
	lucia.crouch(false)
	lucia.global_position = LUCIA_BARS
	lucia.walk_to(LUCIA_OUT, 0.8)
	lucia.look(alex)
	_shot(Vector3(-20.6, 1.5, -209.6), LUCIA_OUT + Vector3.UP * 1.3)
	await hud.subtitle("", "The cage swings open.", 1.6)
	await c1a._settle(lucia)
	lucia.face(alex.global_position, 0.3)  # out of the door, she turns to him (the endings talk face to face)
	_shep.look(Vector3(-22, 1.5, -200))  # out the door, toward the pit
	_shot(SHEP_SPOT + Vector3(-0.5, 1.1, 1.3), SHEP_SPOT + Vector3.UP * 0.95)
	await hud.subtitle("Shepherd", "Is he breathing? My boy. Is he breathing?", 2.6)
	await c1b._talk(alex, _shep, "Alex", "Your boy.", -1.0, 1.4)
	_shep.gesture("slump")
	await hud.subtitle("Shepherd", "He only ever did what I asked. He always did what I asked.", 3.0)
	_shep.gesture("")


func ending_signal() -> void:
	var lucia: Actor = d.lucia
	_shot(ALTAR_TOP + Vector3(0.8, 0.4, 1.0), ALTAR_TOP)
	await hud.subtitle("Radio", "Kshhh…", 1.2)
	await hud.subtitle("Dispatch", "…Hollowmere, this is county dispatch. We hear you.", 2.8)
	await hud.subtitle("Dispatch", "We heard all of it. Units are on the Old Pass.", 2.8)
	_shot(SHEP_SPOT + Vector3(-0.5, 1.1, 1.3), SHEP_SPOT + Vector3.UP * 0.95)
	_shep.gesture("slump")
	await hud.subtitle("Shepherd", "They'll come now. Let them.", 2.2)
	await hud.fade(1.0, 0.6)
	# 03:41 — lights over the lake, the lower cells emptying
	dawn(12.0)
	var alex := d.stand_in(Chapter3Director.CHAPEL_OUT + Vector3(2.0, -0.1, 3.0), 0.0)
	lucia.global_position = alex.global_position + Vector3(1.0, 0, 0.3)
	lucia.model.rotation.y = 0.0
	var beams: Array[SpotLight3D] = []
	for i in 2:
		var s := SpotLight3D.new()
		s.light_color = Color(0.9, 0.95, 1.0)
		s.light_energy = 14.0
		s.light_volumetric_fog_energy = 5.0
		s.spot_range = 70.0
		s.spot_angle = 9.0
		d.add_child(s)
		s.global_position = Vector3(-10 + 24 * i, 45, -165 - 10 * i)
		s.look_at(Vector3(-6 + 6 * i, 0, -190), Vector3.FORWARD)
		var tw := s.create_tween().set_loops()
		tw.tween_property(s, "rotation:y", s.rotation.y + 0.3, 2.5 + i)
		tw.tween_property(s, "rotation:y", s.rotation.y - 0.3, 2.5 + i)
		beams.append(s)
	var freed: Array[Actor] = []
	for i in 3:
		var t := d.actor(MARKED[i % 2], Vector3(8 + i * 1.5, 0, -214 + i), PI * 0.1)
		freed.append(t)
		if i > 0:  # Tomás (0) makes straight for Alex below: one walk each, a walk_to tween can't be cancelled
			t.walk_to(Vector3(-6 + i * 3.0, 0, -160), 1.2)
	var tomas := freed[0]
	tomas.walk_to(alex.global_position + Vector3(0.8, 0, 1.6), 3.0)
	_shot(Vector3(-2, 2.0, -196), Vector3(10, 1.5, -208))
	hud.fade(0.0, 0.8)
	await hud.subtitle("", "03:41. Lights over the lake.", 2.2)
	await hud.subtitle("", "They come up out of the lower cells, blinking at the searchlights.", 3.0)
	d.track(tomas, Vector3(2.0, 1.4, 2.0), Vector3(0, 1.4, 0))
	await hud.subtitle("Lucía", "That one. He kept asking about his sister.", 2.6)
	await c1a._settle(tomas)  # he talks from arm's length, not from across the pit
	tomas.face(alex.global_position, 0.3)
	tomas.look(alex)
	alex.look(tomas)
	d.ots(tomas, alex, 1.0)
	await hud.subtitle("Tomás", "Is Elena with you?", 1.8)
	await d.wait(1.2)
	alex.gesture("clutch_hand")
	d.ots(alex, tomas, -1.0)
	await hud.subtitle("Alex", "She sent me.", 1.8)
	tomas.gesture("hand_to_face")
	await d.wait(1.6)
	await hud.fade(1.0, 1.0)
	for n in freed + beams:
		n.queue_free()
	await hud.subtitle("", "ELENA RUIZ", 3.0)
	d.release_stand_in()


func ending_unveiled() -> void:
	var lucia: Actor = d.lucia
	var cast: Array[Actor] = []
	for i in Chapter3Director.MEMBERS.size():  # every spared friend comes to the chapel door
		var m: String = Chapter3Director.MEMBERS[i]
		var a: Actor = d.allies.get(m)
		if not a:
			a = d.actor("res://models/char_%s.glb" % m, Vector3(-22 + i * 0.9, 0, -203.5), PI)
		a.visible = true
		a.global_position = Vector3(-23.4 + i * 0.95, 0, -205.8 - (i % 2) * 0.6)
		a.model.rotation.y = PI
		cast.append(a)
	var marcus := cast[3]
	_shot(Vector3(-19.2, 1.7, -208.8), Vector3(-22, 1.5, -205.6))
	await hud.subtitle("", "Footsteps at the door. Four of them.", 2.2)
	marcus.look(_shep)
	d.ots(marcus, _shep, 1.0)
	await hud.subtitle("Marcus", "It's over, Elias.", 1.8)
	_shot(SHEP_SPOT + Vector3(-0.5, 1.1, 1.3), SHEP_SPOT + Vector3.UP * 0.95)
	await hud.subtitle("Shepherd", "Is it? You'll see him in every dark room for the rest of your lives.", 3.2)
	cast[0].look(_shep)
	d.ots(cast[0], _shep, -1.0)
	await hud.subtitle("Owen", "Then we'll leave the lights on.", 2.0)
	await hud.fade(1.0, 0.6)
	# dawn: the broken sword carried out of the pit
	dawn(8.0)
	var alex := d.stand_in(Vector3(-16, 0, -196), -PI / 2.0)
	lucia.global_position = alex.global_position + Vector3(0.9, 0, 0.4)
	lucia.model.rotation.y = -PI / 2.0
	var sword := c2b._box(d, Vector3(0.3, 0.2, 2.0), Color(0.82, 0.78, 0.68), Vector3.ZERO)
	cast[0].global_position = Vector3(-22, 0, -201)
	cast[1].global_position = Vector3(-22, 0, -203)
	for k in 2:
		cast[k].model.rotation.y = 0.0
		cast[k].gesture("reach")
	sword.global_position = Vector3(-22, 1.0, -202)
	sword.reparent(cast[0])
	for k in 2:
		cast[k].walk_to(cast[k].global_position + Vector3(0, 0, 30), 1.0)
	_shot(Vector3(-12, 1.4, -190), Vector3(-22, 1.2, -200), Vector3(-13, 1.6, -188), 6.0)
	hud.fade(0.0, 1.0)
	await hud.subtitle("", "Dawn. They carry its sword out of the pit between them.", 3.0)
	# Marcus scrapes the eye off the chapel door
	marcus.global_position = Vector3(-22, 0, -203.4)
	marcus.model.rotation.y = PI
	marcus.gesture("reach")
	_shot(Vector3(-19.5, 2.2, -199.5), Vector3(-22, 4.2, -204.8))
	await hud.subtitle("", "At dawn they scrape the eyes off the doors. Every door in the valley.", 3.0)
	# Alex and Lucía, the tunnel
	alex.walk_to(Chapter3Director.GATE - Vector3(1.0, 1.2, -1.2), 1.4)
	lucia.walk_to(Chapter3Director.GATE - Vector3(0.0, 1.2, -1.0), 1.4)
	_shot(Vector3(10, 2.2, -196), GATE_IN + Vector3.UP * 1.5)
	await hud.subtitle("Lucía", "Can we go home now?", 1.8)
	await hud.subtitle("Alex", "Yeah. We can go home.", 1.8)
	await d.wait(2.0)
	await hud.fade(1.0, 1.0)
	sword.queue_free()
	for a in cast:  # they stay in the quarry: not frozen reaching for the rest of the game
		a.gesture("")
	d.release_stand_in()


func ending_new_eye() -> void:
	var lucia: Actor = d.lucia
	var alex: Actor = d._stand_in
	_shep.crouch(false)
	_shep.look(alex)
	_shot(SHEP_SPOT + Vector3(-0.5, 1.4, 1.3), SHEP_SPOT + Vector3.UP * 1.5)
	await hud.subtitle("", "He looks at the blood on you. Then he smiles.", 2.6)
	_shep.anim.hold(_iron, "")
	_shep.gesture("give")
	await hud.subtitle("Shepherd", "Four of them. I never had one who could do that.", 2.8)
	d.ots(_shep, alex, 1.0)
	await hud.subtitle("Shepherd", "You did their work better than they did.", 2.6)
	alex.face(_shep.global_position, 0.3)
	await alex.take(_iron, "")
	_shep.gesture("")
	c1a._hand_shot(alex)
	await d.wait(1.2)
	lucia.look(alex)
	lucia.gesture("hand_to_face")  # shock where she stands: a step back would cross Alex or the bench
	_shot(Vector3(-24.8, 1.5, -207.2), lucia.global_position + Vector3.UP * 1.4)
	await hud.subtitle("Lucía", "Alex…?", 1.8)
	await hud.fade(1.0, 1.0)
	lucia.gesture("")
	# weeks later: the motel. Room 6 is ready.
	var p := Vector3(-95.6, 0.05, 49.0)
	var room := d.actor("res://models/char_alex.glb", p, -PI / 2.0)
	var iron := c2b._prop(c2b._hand(room), "brand_iron", Vector3(0.05, 0.05, 0.7), IRON, Vector3(0, -0.12, 0.2))
	if iron is MeshInstance3D:
		c2b._box(iron, Vector3(0.14, 0.03, 0.14), RED, Vector3(0, 0, -0.38), 3.0)
	var burn := c1a._light(Vector3(-96.4, 1.3, 49.0), Color(1.0, 0.3, 0.1), 1.2, 2.5, true)
	room.gesture("reach")
	d.release_stand_in()
	_shot(Vector3(-94.6, 1.5, 48.6), Vector3(-96.4, 1.4, 49.0))
	hud.fade(0.0, 1.0)
	await hud.subtitle("", "A car stalls at the bridge.", 2.2)
	await hud.subtitle("", "Room 6 is ready.", 2.2)
	await hud.fade(1.0, 1.0)
	room.queue_free()
	burn.queue_free()


func ending_mixed() -> void:
	var lucia: Actor = d.lucia
	var alex: Actor = d._stand_in
	lucia.gesture("slump")
	d.ots(lucia, alex, 1.0)
	await hud.subtitle("Lucía", "I can't feel my legs. Three weeks in that box.", 2.6)
	await c1b._talk(alex, lucia, "Alex", "Then I'll carry you. Like when you were six.", -1.0, 2.6)
	await hud.fade(1.0, 0.6)
	alex.global_position = Chapter3Director.CHAPEL_OUT + Vector3(3, -0.1, 3)
	lucia.global_position = alex.global_position + Vector3(0.45, 0, 0.1)
	for a in [alex, lucia]:
		a.gesture("lean")
		a.walk_to(Chapter3Director.GATE - Vector3(0.5, 1.2, -1.0), 0.9)
	d.track(alex, Vector3(-2.2, 1.6, 3.0), Vector3(0, 1.2, 0))
	hud.fade(0.0, 0.8)
	await hud.subtitle("", "She can barely stand. Alex carries her most of the way.", 3.0)
	await d.wait(1.6)
	await hud.fade(1.0, 0.8)
	var cards := []
	for m in Chapter3Director.MEMBERS:
		var st: String = d.flags.get(m, "active")
		cards.append(["", FATES[m][0 if st == "spared" else (1 if st == "killed" else 2)], 3.0])
	await hud.say(cards)
	lucia.gesture("")
	alex.gesture("")
	d.release_stand_in()


func ending_run() -> void:
	## Chosen at the gate: no chapel, no Lucía.
	d.cinematic(true)
	var alex := d.stand_in(d.player.global_position, PI)
	alex.look(Vector3(-22, 1.5, -208))
	_shot(alex.global_position + Vector3(1.4, 1.6, 1.8), alex.global_position + Vector3.UP * 1.5)
	await hud.subtitle("Alex", "I'm sorry, Lucía.", 1.8)
	alex.look(null)
	_shot(Vector3(24, 1.2, -212), GATE_IN + Vector3.UP * 3.0)
	await hud.subtitle("", "Three parts turn in three slots. The gate grinds open.", 3.0)
	alex.walk_to(GATE_IN, 1.4)
	d.track(alex, Vector3(-1.8, 1.6, 3.2), Vector3(0, 1.3, -2.0))
	await d.wait(2.6)
	await hud.fade(1.0, 1.0)
	await hud.subtitle("", "The Old Pass. Three kilometres of dark.", 2.6)
	await hud.subtitle("", "The mark on the back of the hand itches all the way.", 2.8)
	await hud.subtitle("Radio", "Kshhh… channel seven…", 2.2)
	await hud.subtitle("", "Lucía is not found.", 2.4)
	d.release_stand_in()


func end_card() -> void:
	## The chapter card + ending stats on black. The next step (C3.4) fades back in.
	d.cinematic(true)
	await hud.fade(1.0, 0.3)
	if is_instance_valid(_shep):
		_shep.queue_free()
		if is_instance_valid(_iron):  # New Eye: it went with Alex's stand-in
			_iron.queue_free()
		var lamp := d.get_node_or_null("ShepLamp")
		if lamp:
			lamp.queue_free()
	hud.banner("III · THE VEIL", Color(0.85, 0.8, 0.7), 4.0)
	await d.wait(4.5)
	var f: Dictionary = d.flags
	var st: Array = Chapter3Director.MEMBERS.map(func(m: String) -> String: return str(f.get(m, "active")))
	await hud.say([["", "Ending: %s.  Spared %d · Killed %d · Evidence %d/12 · Tokens %d" % [
		{"run": "RUN", "signal": "SIGNAL", "unveiled": "UNVEILED", "new_eye": "THE NEW EYE", "mixed": "MIXED"}[f.ending],
		st.count("spared"), st.count("killed"), f.evidence.size(), f.tokens], 5.0]])


# ------------------------------------------------------------------ C3.4 Pop. 1413 (post-end)

func pop_1413(ending: String) -> void:
	## Lucía tells what the Veil really was, then how it ended. Starts on black; ends in free roam.
	d.cinematic(true)
	var run := ending == "run"
	if not run:
		dawn(0.5)
	# the town sign
	_shot(Vector3(-98.2, 2.0, 141.8), Vector3(-104.5, 2.2, 140), Vector3(-99.4, 2.1, 141.0), 8.0)
	hud.fade(0.0, 1.5)
	await hud.subtitle("", "HOLLOWMERE  ·  POP. 1413", 2.6)
	if run:
		await hud.subtitle("Lucía", "Alex. I heard the gate. I hope it was you.", 3.0)
		await hud.subtitle("Lucía", "I'll tell you anyway. Somebody should know.", 2.6)
	else:
		await hud.subtitle("Lucía", "Twenty-two days in that cage. He talked to me every night.", 3.0)
		await hud.subtitle("Lucía", "I think I was the first one who ever listened.", 2.6)
	# the pit
	_shot(Vector3(6, 16, -150), Vector3(-10, 0, -195), Vector3(-2, 15, -152), 10.0)
	await hud.subtitle("Lucía", "His name is Elias Morrow. He was the quarry's chaplain.", 3.0)
	await hud.subtitle("Lucía", "Thirty-one years ago the pit fell in. Nine men under the rock.", 3.0)
	await hud.subtitle("Lucía", "His son Caleb was one of them.", 2.4)
	_shot(Vector3(20, 2.0, -206), Vector3(30, 3.5, -222.5))
	await hud.subtitle("Lucía", "The town voted to seal it. Save the pass. Save the rest.", 3.0)
	# Caleb
	var h: Node3D = d.harvester if is_instance_valid(d.harvester) else null
	if run or not h:
		var prop := d.get_parent().get_node_or_null("Props/Boss") as Node3D
		if prop:
			Chapter3Director.show_boss_prop(prop, true)
			h = prop
	if h:
		_shot(h.global_position + Vector3(1.6, 1.8, 2.8), h.global_position + Vector3.UP * (0.6 if h is Enemy else 2.2))
	await hud.subtitle("Lucía", "On the ninth day Caleb dug himself out. Blind to any light. No words left.", 3.4)
	if h is Harvester:
		(h as Harvester).eyes_off(2.5)
	await hud.subtitle("Lucía", "The red eyes were a lamp's lenses. The tar was pitch from the pit.", 3.2)
	await hud.subtitle("Lucía", "The sword was the nine he couldn't dig out. And everyone since.", 3.2)
	# the blackout, explained
	_shot(Vector3(0, 3.0, 34), Vector3(0, 1.5, 0), Vector3(0, 3.6, 30), 8.0)
	await hud.subtitle("Lucía", "Elias told the valley the pit had kept his boy. That it keeps everyone — if you feed it.", 3.8)
	await hud.subtitle("Lucía", "Light hurt Caleb. So every night at three, the town turned its lights off for him.", 3.6)
	await hud.subtitle("Lucía", "That's all the Veil ever was. A father who couldn't let go. A town that owed him.", 3.6)
	await hud.subtitle("Lucía", "The ones who broke went out in the Tuesday trucks. The rest stayed in the pit.", 3.4)
	# the lighthouse: Elena's number
	_shot(Vector3(-10, 5.0, 124), Vector3(6, 11, 140))
	await hud.subtitle("Lucía", "The sign still says 1413. That's how many lived here the year the pit fell.", 3.4)
	await hud.subtitle("Lucía", "Elena made it her code. The one number he couldn't make smaller.", 3.2)
	await Callable(self, "_after_" + ending).call()
	await hud.fade(1.0, 1.2)
	hud.banner("LAAF", Color(0.85, 0.8, 0.7), 3.5)
	await d.wait(3.8)
	await hud.subtitle("", "Thank you for playing.", 2.6)
	d.player.respawn(Vector3(0, 0.1, -150), PI)
	d.cinematic(false)
	hud.fade(0.0, 1.5)


func _after_signal() -> void:
	await hud.subtitle("Lucía", "The broadcast reached a county trucker at 03:14. By noon, forty cars on the Old Pass.", 3.6)
	await hud.subtitle("Lucía", "Eleven alive in the lower cells. Tomás Ruiz asked for his sister first.", 3.4)
	_shot(Vector3(-4, 1.6, 128), Vector3(6, 2.0, 136))
	await hud.subtitle("Lucía", "Grady painted a moth on the lighthouse door. Nobody has painted over it.", 3.4)


func _after_unveiled() -> void:
	await hud.subtitle("Lucía", "Owen, Nora, Julian and Marcus stayed. Every eye was off every door by the first frost.", 3.8)
	await hud.subtitle("Lucía", "Elias sat with Caleb in the pit until they both went quiet. Nobody stopped him.", 3.6)
	_shot(Vector3(-66, 2.0, -86), Vector3(-81, 14, -91.5))
	hud.banner("BONG", Color(0.9, 0.85, 0.7), 1.2)
	await hud.subtitle("Lucía", "Marcus rings the bell at dawn now. It doesn't call anyone.", 3.2)


func _after_new_eye() -> void:
	await hud.subtitle("Lucía", "Alex stayed. I left alone.", 2.4)
	await hud.subtitle("Lucía", "Sometimes a car stalls at the bridge, and a new eye turns up on a door at the motel.", 3.6)
	_shot(Vector3(-94.6, 1.5, 48.6), Vector3(-96.4, 1.4, 49.0))
	await hud.subtitle("Lucía", "I don't read the news from Hollowmere anymore.", 2.8)


func _after_mixed() -> void:
	var spared := _members("spared").size()
	await hud.subtitle("Lucía", "Some of them came back to themselves. Some are under the harbor wall. We don't talk about which.", 3.8)
	await hud.subtitle("Lucía", "Elias is still up there with his boy." if spared < 4 else "Elias went down into the pit.", 3.0)
	_shot(Vector3(0, 3.0, 34), Vector3(0, 1.5, 0))
	await hud.subtitle("Lucía", "The lights in Hollowmere still go out at three. Just not all of them.", 3.4)


func _after_run() -> void:
	var cage := Chapter3Director.LUCIA_CAGE
	var lan := c1a._light(cage + Vector3(1.4, 1.2, 1.0), Color(1.0, 0.6, 0.3), 1.2, 5.0, true)
	_shot(cage + Vector3(2.6, 1.5, 3.4), cage + Vector3.UP * 0.8)
	await hud.subtitle("Lucía", "I hope you made it through. I hope you don't come back.", 3.2)
	await hud.subtitle("Radio", "Kshhh… channel seven…", 2.2)
	var tw := lan.create_tween()
	tw.tween_property(lan, "light_energy", 0.0, 2.0)
	await hud.subtitle("", "The lantern gutters out.", 2.4)
