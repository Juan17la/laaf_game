class_name Ch1ScenesA
extends RefCounted
## Chapter 1 story beats, part A: C1.1 arrival, C1.2 the window, room 6, the first hunt.
## Staged through the director `d` (scripts/chapter1.gd): see its header for the API.
## Rule: stage actions (actors move, gesture, cameras cut every 2–5 s); lines stay short.

const ROOM6 := Vector3(-100.2, 0.1, 49.6)
const OWEN_LINES := ["I can hear you breathing.", "The forest keeps everything.", "Come out, outsider.",
	"It's quicker if you don't run.", "You're not the first.", "The grass won't hide you forever.",
	"I see where you've been.", "Dad taught me to track deer.", "Your hand's burning, isn't it?",
	"Nobody's coming for you.", "Closer…", "I hear the grass move."]
const CAUGHT_LINES := ["Not yet. Run.", "I like it better when you run.", "Got you. Again.",
	"Go on. Crawl.", "Too slow, outsider."]
const CARD := Color(0.92, 0.88, 0.78)
const BRASS := Color(0.8, 0.65, 0.3)

var d: Chapter1Director
var hud: Node
var _radio: Node3D  ## room 6 has no radio model in the map: placed here on the table (RADIO_SPOT)
var _mic: Node3D  ## the radio's hand mic, lying beside it until Alex picks it up for the call
var _note: Node3D  ## Moth's note under the door, from room_door until it's picked up


func _init(director: Chapter1Director) -> void:
	d = director
	hud = director.hud


# ------------------------------------------------------------------ helpers

func _prop(parent: Node3D, bone: String, size: Vector3, color: Color, offset := Vector3.ZERO, kind := "") -> Node3D:
	## Small prop (postcard, key, bandage...): the `kind` item model if there is one, else a box. In a right
	## hand it's held properly (HumanoidAnim.hold: gripped by its shape, held out while "give" plays).
	var n: Node3D
	if kind != "" and ResourceLoader.exists("res://models/item_%s.glb" % kind):
		n = (load("res://models/item_%s.glb" % kind) as PackedScene).instantiate()
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		bm.material = mat
		mi.mesh = bm
		n = mi
	var at: Node3D = parent.find_child(bone, true, false) if bone != "" else parent
	var anim := HumanoidAnim.of(at) if bone == "HandR" and at else null
	if anim:
		return anim.hold(n, "")
	(at if at else parent).add_child(n)
	n.position = offset
	return n


func _light(pos: Vector3, color: Color, energy: float, range_m: float, flicker := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	if flicker:
		l.set_script(load("res://scripts/flicker.gd"))
		l.set("chance", 0.45)
	d.add_child(l)
	l.global_position = pos
	return l


func _near(a: Node3D, off: Vector3, look_off := Vector3(0, 1.5, 0)) -> void:
	## Cut to a close-up of an actor: camera at actor + off, looking at actor + look_off.
	d.shot(a.global_position + off, a.global_position + look_off)


func _begin_stand_in() -> Actor:
	## Staged beat on top of gameplay: Alex actor where the player stands.
	d.cinematic(true)
	return d.stand_in(d.player.global_position, d.player.model.rotation.y)


func _end_stand_in() -> void:
	## Hands control back where the stand-in ended, without the respawn refilling health/stamina.
	var hp: float = d.player.health
	var st: float = d.player.stamina
	d.release_stand_in()
	d.player.health = hp
	d.player.stamina = st
	d.cinematic(false)


# ------------------------------------------------------------------ C1.1 + C1.2

func intro() -> void:
	## C1.1 + C1.2. Must end with the player at ROOM6 facing +X, controls on, screen faded in.
	d.cinematic(true)
	hud.fade(1.0, 0.0)
	# one stand-in for the whole intro (a second stand_in() would respawn the player mid-scene);
	# the hidden player body is moved along with the scene so the zone titles stamp each place
	var alex := d.stand_in(Vector3(-100.4, 0, 146.0), PI)  # (by the driver's door, clear of the car: see _bridge)
	await _bridge(alex)
	await _store(alex)
	await _window(alex)
	d.release_stand_in()
	d.player.respawn(ROOM6, PI / 2.0)
	d.cinematic(false)
	hud.fade(0.0, 0.5)


func _settle(a: Actor) -> void:
	## Waits for a running walk_to to finish (its tween can't be cancelled) before repositioning.
	while a.anim.speed > 0.0:
		await d.get_tree().process_frame


func _room_props() -> void:
	if not is_instance_valid(_radio):
		_radio = (load("res://models/int_radio.glb") as PackedScene).instantiate()
		d.add_child(_radio)
		_radio.global_position = Vector3(-98.5, 0.78, 50.8)
		_radio.rotation.y = PI / 2.0
	if not is_instance_valid(_mic):
		_mic = (load("res://models/item_handmic.glb") as PackedScene).instantiate()
		d.add_child(_mic)
		_mic.global_position = Vector3(-98.25, 0.81, 51.2)
		_mic.rotation = Vector3(-PI / 2.0, 0.4, 0)  # lying on its back, grille up


func _hand(a: Actor) -> Node3D:
	return a.model.find_child("HandR", true, false)


func _read_shot(a: Actor) -> void:
	## Over the shoulder onto what the right hand holds up ("show"): reading it with him.
	var m := a.model
	var at := m.to_global(Vector3(-0.07, 1.28, 0.34))
	d.shot(m.to_global(Vector3(-0.32, 1.78, -0.28)), at)


func _hand_shot(a: Actor, side := 1.0) -> void:
	## Close-up on the right hand (after a "give" / "reach" pose has blended in).
	var h := _hand(a).global_position
	d.shot(h + a.model.global_basis.x * -0.5 * side + a.model.global_basis.z * 0.35 + Vector3.UP * 0.3, h)


func _bridge(alex: Actor) -> void:
	# the car rolls off the bridge, headlights on, and dies
	d.player.global_position = Vector3(-100, 0.1, 128)
	var car: Node3D = (load("res://models/car_wreck.glb") as PackedScene).instantiate()
	d.add_child(car)
	car.global_position = Vector3(-99, 0, 157)
	car.rotation.y = PI / 2.0  # the model's nose is +X; this points it down the road (-Z)
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.92, 0.7)
	beam.light_energy = 5.0
	beam.spot_range = 24.0
	beam.spot_angle = 32.0
	car.add_child(beam)
	beam.position = Vector3(2.1, 0.8, 0)
	beam.rotation = Vector3(0, -PI / 2.0, 0)
	alex.visible = false
	d.shot(Vector3(-95.2, 0.8, 136.0), Vector3(-99, 0.9, 148), Vector3(-95.5, 1.1, 141.0), 7.0, 72.0)  # wide, creeping in
	var engine := Snd.attach(car, "generator", -2.0)
	hud.fade(0.0, 1.0)
	var tw := car.create_tween()
	tw.tween_property(car, "global_position:z", 146.0, 3.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await hud.subtitle("", "Dusk. The road into Hollowmere.", 3.0)
	for i in 5:  # engine coughs: the car shudders, the lights stutter and die
		beam.visible = i % 2 == 1
		car.rotation.x = 0.025 * (1 if i % 2 else -1)
		await d.wait(0.1 + 0.05 * i)
	beam.visible = false
	car.rotation.x = 0.0
	Snd.stop(engine)
	Snd.sfx("scrape", car.global_position, -3.0, 0.6)
	# Alex gets out, walks round to the nose, leans on the hood. The car stops at (-99, 146) nose -Z: its body
	# (bumpers, mirrors) spans x -99.95..-98.05, z 143.7..148.3; Alex keeps ~0.4 m off it on the road.
	alex.visible = true
	d.shot(Vector3(-102.8, 1.4, 141.6), Vector3(-99.8, 1.0, 145.4))
	alex.walk_path([Vector3(-100.45, 0, 143.25), Vector3(-99.4, 0, 143.1)], 2.0)  # along the door, round the fender
	await hud.subtitle("Alex", "No. No, no, no—", 1.8)
	await _settle(alex)
	await alex.face(Vector3(-99.4, 0, 146))
	alex.gesture("lean")
	_near(alex, Vector3(-1.4, 1.2, -1.5), Vector3(0, 1.1, 0.4))
	await hud.subtitle("Alex", "Not here. Not now.", 1.8)
	alex.gesture("")
	# looks back at the bridge: no way back either
	alex.face(Vector3(-100, 0, 157.4))
	alex.look(Vector3(-100, 1.5, 157.4))
	d.shot(Vector3(-98.2, 1.75, 141.4), Vector3(-100, 1.4, 157.4))
	await d.wait(0.6)
	alex.gesture("shrug", 1.4)
	await hud.subtitle("Alex", "Bridge out. Great.", 1.8)
	# the postcard
	alex.look(null)
	await alex.face(Vector3(-100, 0, 130))
	var card := _prop(alex.model, "HandR", Vector3(0.14, 0.01, 0.1), CARD, Vector3(0, -0.12, 0.04), "note")
	alex.anim.hold_pose = "show"  # reads it
	await d.wait(0.6)
	_read_shot(alex)
	await hud.subtitle("", "\"Hollowmere is beautiful. Don't come.\" — L.", 3.0)
	_near(alex, alex.model.global_basis.z * 1.0 + alex.model.global_basis.x * 0.3 + Vector3.UP * 1.55,
		Vector3(0, 1.5, 0))
	await hud.subtitle("Alex", "Three weeks, Lucía. Not one call.")
	alex.look(null)
	alex.gesture("")
	card.queue_free()
	# walks into town: tracking shot, then under the town sign
	alex.walk_to(Vector3(-101.0, 0, 133.0), 1.8)  # ends before the fade (tweens can't be cancelled)
	d.shot(alex.global_position + Vector3(1.6, 1.5, -3.2), alex.global_position + Vector3(0, 1.3, 0))
	d.track(alex, Vector3(1.6, 1.5, -3.2), Vector3(0, 1.3, 0))
	await d.wait(2.2)
	d.shot(Vector3(-98.6, 0.6, 130.0), Vector3(-103.2, 2.2, 140.2), Vector3(-98.6, 0.9, 129.4), 3.4, 62.0)
	await d.wait(3.2)
	await hud.fade(1.0, 0.5)
	car.queue_free()


func _store(alex: Actor) -> void:
	# Grady's General Store: he steps out, blocks the door, hands over a key and shuts the talk down
	await _settle(alex)
	d.player.global_position = Vector3(6, 0.1, -2)
	var g: Actor = d._grady
	var home := g.global_position
	g.global_position = home + Vector3(0, 0, -1.4)
	g.model.rotation.y = 0.0
	alex.global_position = Vector3(9.0, 0, -6.0)
	alex.walk_to(Vector3(13.7, 0, -15.5), 2.0)
	d.shot(Vector3(5.5, 2.2, -4.0), Vector3(13, 1.3, -15), Vector3(7.0, 2.0, -6.5), 5.0)
	hud.fade(0.0, 0.5)
	await d.wait(2.4)
	await hud.subtitle("Alex", "Hello? Are you open?", 1.8)
	g.walk_to(home + Vector3(0, 0, 0.3), 1.6)
	d.shot(Vector3(16.2, 1.4, -13.4), Vector3(14, 1.4, -17.4))
	await d.wait(1.0)
	g.gesture("arms_crossed")
	g.look(alex)
	alex.face(g.global_position)
	alex.look(g)
	d.ots(g, alex, 1.0)
	await hud.subtitle("Grady", "Closed. Always, after dark.")
	d.ots(alex, g, -1.0)
	var card := _prop(alex.model, "HandR", Vector3(0.14, 0.01, 0.1), CARD, Vector3(0, -0.12, 0.04), "note")
	alex.gesture("give")
	await hud.subtitle("Alex", "I'm looking for my sister. Lucía.")
	_hand_shot(alex, -1.0)
	g.look(card)
	await hud.subtitle("Alex", "She sent this. From here.")
	_near(g, Vector3(0.5, 1.6, 1.0), Vector3(0, 1.6, 0))
	g.look(alex)
	g.gesture("shake_head", 1.2)
	await hud.subtitle("Grady", "Never seen her.", 1.8)
	d.ots(alex, g, -1.0)
	alex.gesture("")
	card.queue_free()
	await hud.subtitle("Alex", "You didn't even look.", 1.8)
	d.shot(Vector3(17.2, 1.5, -15.4), Vector3(13.8, 1.3, -16.6))
	g.gesture("")
	await g.face(Vector3(-100, 0, 50))
	g.gesture("point", 1.8)
	await hud.subtitle("Grady", "Motel. Lake road, west.", 1.9)
	await g.face(alex.global_position, 0.3)
	var key := _prop(g.model, "HandR", Vector3(0.05, 0.02, 0.1), BRASS, Vector3(0, -0.1, 0.04), "room_key")
	g.gesture("give")
	d.ots(g, alex, 1.0)
	await hud.subtitle("Grady", "Room six. One night.", 1.9)
	g.gesture("give")
	await alex.take(key)  # out of Grady's hand into his, and a look at the tag
	g.gesture("")
	alex.look(null)
	_near(g, Vector3(-0.4, 1.6, 1.0), Vector3(0, 1.6, 0))
	await hud.subtitle("Grady", "Then you go back the way you came.")
	d.ots(alex, g, -1.0)
	await hud.subtitle("Alex", "The bridge is out.", 1.7)
	g.look(null)
	g.walk_to(home + Vector3(0, 0, -1.4), 1.4)
	d.ots(g, alex, 1.0)
	await hud.subtitle("Grady", "Then walk.", 1.5)
	# Alex is left on the step, then heads west
	alex.look(null)
	alex.walk_to(Vector3(9.8, 0, -12.2), 1.8)
	d.shot(Vector3(14.2, 1.1, -16.4), Vector3(8, 1.2, -11), Vector3(13.8, 1.3, -15.4), 2.5)
	await d.wait(2.2)
	await hud.fade(1.0, 0.5)
	key.queue_free()
	g.global_position = home
	g.model.rotation.y = 0.0


func _window(alex: Actor) -> void:
	# 23:00, room 6: Alex asleep; Owen at the glass, at the door — the hand burns
	await _settle(alex)
	d.player.global_position = ROOM6
	_room_props()
	# on his back, head on the pillow (-X): 1.78 m from the feet here to the crown just short of the headboard
	alex.global_position = Vector3(-100.72, 0.55, 48.5)
	alex.model.rotation = Vector3(-PI / 2.0, PI / 2.0, 0)
	var owen := d.actor("res://models/char_owen.glb", Vector3(-95.3, 0, 55.5), PI)
	var back := _light(Vector3(-92.5, 2.6, 51.5), Color(0.55, 0.65, 0.9), 0.9, 7.0)
	await hud.subtitle("", "23:00. Lakeview Motel, room six.", 2.0)
	d.shot(Vector3(-98.6, 2.0, 51.4), Vector3(-102.0, 0.6, 48.5), Vector3(-99.2, 1.9, 51.0), 3.0)
	hud.fade(0.0, 0.6)
	await d.wait(2.4)
	# outside: the silhouette walks up the walkway to the window
	owen.walk_to(Vector3(-95.3, 0, 50.6), 1.3)
	d.shot(Vector3(-90.5, 1.3, 53.8), Vector3(-95.5, 1.4, 51.0))
	await d.wait(3.2)
	owen.face(Vector3(-100, 0, 50.6))
	d.shot(Vector3(-101.9, 1.05, 47.7), Vector3(-102.35, 0.7, 48.5), Vector3(-101.9, 1.0, 47.9), 3.0, 46.0, 0.006)  # asleep, breathing
	await d.wait(1.6)
	owen.gesture("window_press")
	Snd.sfx("thud", Vector3(-96.5, 1.4, 50.0), -4.0, 1.4)
	d.shot(Vector3(-93.3, 1.75, 51.9), Vector3(-101.5, 0.7, 48.6))  # over his shoulder, through the glass
	await d.wait(2.4)
	# to the door; he reaches for it
	owen.gesture("")
	await owen.walk_to(Vector3(-95.7, 0, 49.1), 1.3)
	await owen.face(Vector3(-97, 0, 49.1), 0.3)
	owen.gesture("reach")
	Snd.sfx("door_locked", Vector3(-96.5, 1.0, 49.0), -3.0)
	d.shot(Vector3(-93.4, 1.2, 47.4), Vector3(-96.0, 1.3, 49.1), Vector3(-94.6, 1.25, 48.2), 4.0, 50.0, 0.02)
	await d.wait(1.4)
	# the burn: an orange flicker on the sleeping hand
	var hand := _hand(alex)
	var burn := _light(hand.global_position + Vector3(0, 0.25, 0), Color(1.0, 0.45, 0.1), 1.2, 1.6, true)
	d.shot(hand.global_position + Vector3(0.45, 0.55, -0.35), hand.global_position)
	await hud.subtitle("", "Tsssss…", 1.3)
	# Alex jolts up, clutching the hand
	var tw := alex.create_tween().set_parallel()
	tw.tween_property(alex.model, "rotation:x", 0.0, 0.3).set_trans(Tween.TRANS_BACK)
	tw.tween_property(alex, "global_position", Vector3(-100.6, 0.1, 49.0), 0.3)  # (sits up off the bed)
	alex.gesture("clutch_hand")
	Snd.sfx("hurt", alex.global_position + Vector3.UP, -2.0)
	burn.global_position = Vector3(-100.4, 1.2, 49.3)
	d.shot(Vector3(-99.0, 1.5, 47.6), Vector3(-100.6, 1.2, 49.0))
	await hud.subtitle("Alex", "Agh—!", 1.3)
	# outside: Owen backs off the door into the dark
	owen.gesture("")
	owen.walk_to(Vector3(-93.4, 0, 49.1), 1.9)
	d.shot(Vector3(-90.8, 1.5, 46.2), Vector3(-95.0, 1.2, 49.2))
	await hud.subtitle("Alex", "Who's there?!", 1.6)
	owen.walk_to(Vector3(-89.0, 0, 42.5), 2.2)
	back.queue_free()
	await d.wait(1.2)
	# alone again, the hand still smoking
	owen.queue_free()
	alex.look(null)
	alex.walk_to(ROOM6, 1.4)
	d.shot(Vector3(-102.8, 1.6, 50.6), ROOM6 + Vector3(0, 1.1, 0))
	await d.wait(0.6)
	alex.face(ROOM6 + Vector3.RIGHT, 0.3)
	await hud.subtitle("Alex", "My hand…", 1.6)
	burn.queue_free()
	await hud.fade(1.0, 0.35)


# ------------------------------------------------------------------ M1 Room 6

func room_wake() -> void:
	_room_props()
	var alex := _begin_stand_in()
	alex.gesture("give")
	var mark := _light(Vector3.ZERO, Color(1.0, 0.4, 0.1), 0.8, 0.8, true)
	await d.wait(0.3)
	var hand := _hand(alex)
	mark.global_position = hand.global_position + Vector3(0, 0.15, 0)
	_hand_shot(alex)
	await hud.subtitle("Alex", "An eye… inside a spiral.")
	_near(alex, alex.model.global_basis.z * 0.9 + Vector3(0.2, 1.6, 0), Vector3(0, 1.5, 0))
	alex.look(hand)
	await hud.subtitle("Alex", "Burned in. What did they do to me?")
	mark.queue_free()
	alex.gesture("")
	_end_stand_in()


func room_door() -> void:
	var alex := _begin_stand_in()
	alex.face(Vector3(-96.5, 0, 49.0))
	var eye := Label3D.new()
	eye.text = "(@)"
	eye.modulate = Color(0.65, 0.05, 0.04)
	eye.font_size = 100
	eye.pixel_size = 0.004
	eye.outline_size = 0
	d.add_child(eye)
	_note = Interactable.ItemFx.item("note")  # with its dust motes: the marker's _use has no item of its own
	d.add_child(_note)
	_note.global_position = Vector3(-97.4, 0.02, 49.6)
	_note.rotation.y = 0.4
	eye.global_position = Vector3(-96.36, 1.45, 49.0)
	eye.rotation.y = PI / 2.0
	Snd.stinger("dread", -9.0)
	hud.mark_spike(Feel.SPIKE_SCRIPT)  # the same eye as the one burned into his hand
	d.shot(Vector3(-94.6, 1.5, 48.6), Vector3(-96.4, 1.4, 49.0), Vector3(-95.0, 1.5, 48.8), 4.0, 48.0)  # outside: the eye on the door
	await hud.subtitle("Alex", "The same eye. On my door.")
	d.shot(Vector3(-95.4, 1.6, 49.4), Vector3(-96.4, 1.45, 49.0))
	await hud.subtitle("Alex", "Still wet.", 1.6)
	d.shot(Vector3(-96.8, 0.5, 50.4), Vector3(-97.4, 0.05, 49.6))  # inside: something under the door
	alex.look(Vector3(-97.4, 0.2, 49.6))
	await hud.subtitle("Alex", "And a note.", 1.6)
	eye.queue_free()
	alex.look(null)
	_end_stand_in()


func room_note() -> void:
	var alex := _begin_stand_in()
	var note := Vector3(-97.4, 0, 49.6)
	d.shot(note + Vector3(-0.6, 1.1, 1.3), alex.global_position + Vector3(0, 0.6, 0))
	var card: Node3D
	if is_instance_valid(_note):  # the very note that was pushed under the door
		card = _note
		await alex.take(card)
	else:
		card = alex.hold("note")
	_note = null
	await d.wait(0.3)
	_read_shot(alex)
	await hud.subtitle("Moth", "\"Don't let them see you after dark. Radio, channel 7.\"", 3.2)
	_near(alex, alex.model.global_basis.z * 0.9 + Vector3(-0.2, 1.6, 0), Vector3(0, 1.5, 0))
	await hud.subtitle("Alex", "Channel 7…", 1.4)
	alex.look(Vector3(-98.5, 0.9, 50.8))
	await d.wait(0.6)
	card.queue_free()
	alex.gesture("")
	alex.look(null)
	_end_stand_in()


func room_radio_call() -> void:
	## Right after the radio minigame locks channel 7.
	var alex := _begin_stand_in()
	var radio := Vector3(-98.5, 0.9, 50.8)
	_room_props()
	alex.look(radio)
	if is_instance_valid(_mic):  # picks the hand mic up off the table and talks into it
		await alex.take(_mic, "talk")
	alex.face(radio)
	var close := func() -> void: d.shot(radio + Vector3(0.45, 0.3, -0.5), radio, radio + Vector3(0.25, 0.15, -0.3), 5.0, 45.0)  # the speaker crackles, slowly closer
	var face := func() -> void:
		_near(alex, alex.model.global_basis.z * 1.0 + alex.model.global_basis.x * 0.3 + Vector3.UP * 1.6,
			Vector3(0, 1.5, 0))
	var over := func() -> void:  # behind Alex's shoulder, onto the radio
		d.shot(alex.global_position - alex.model.global_basis.z * 0.8 + alex.model.global_basis.x * -0.4
			+ Vector3.UP * 1.7, radio)
	var hum := Snd.sfx("radio_static", radio, -12.0)  # the set hums under the whole call
	close.call()
	await hud.subtitle("Moth", "You're awake. Good.", 1.8)
	face.call()
	await hud.subtitle("Alex", "Who is this? Who did this to me?")
	over.call()
	alex.gesture("")
	await hud.subtitle("Moth", "No names on open air. Listen.")
	close.call()
	await hud.subtitle("Moth", "They marked you. Owen comes to collect.")
	face.call()
	await hud.subtitle("Alex", "Collect what?", 1.5)
	close.call()
	await hud.subtitle("Moth", "You. Get to the town square.")
	over.call()
	await hud.subtitle("Moth", "Stay in the tall grass. Stay low.")
	face.call()
	await hud.subtitle("Alex", "And if he sees me?", 1.6)
	close.call()
	await hud.subtitle("Moth", "Don't let him. Go. Now.", 1.8)
	alex.look(null)
	Snd.stop(hum)
	alex.let_go()  # (the mic goes back on the table)
	_room_props()
	_end_stand_in()


# ------------------------------------------------------------------ M2 First hunt

func hunt_start(owen: Enemy) -> void:
	## Owen (an Enemy, already patrolling near (-86, 0, 72)) starts hunting. Player is at the room 6 door.
	## Brief reveal: an Owen actor steps out of the dark where the Enemy stands; the Enemy is frozen and
	## hidden meanwhile, so gameplay resumes exactly where it was.
	d.cinematic(true)
	owen.process_mode = Node.PROCESS_MODE_DISABLED
	owen.visible = false
	var spot := owen.global_position
	var a := d.actor("res://models/char_owen.glb", spot + Vector3(2.0, 0, 3.5), PI)
	var rim := _light(spot + Vector3(-1.0, 2.6, -1.5), Color(0.55, 0.65, 0.9), 1.4, 6.0)
	Snd.stinger("reveal", -10.0)
	d.shot(spot + Vector3(3.0, 0.5, -4.5), spot + Vector3(0.8, 1.3, 1.2), spot + Vector3(2.6, 0.7, -3.4), 4.0, 55.0, 0.02)
	await a.walk_to(spot, 1.6)
	a.face(spot + Vector3(-8, 0, -20))  # toward the motel
	a.gesture("look_around")
	_near(a, Vector3(-1.2, 1.6, -1.8), Vector3(0, 1.6, 0))
	await hud.subtitle("Owen", "Little outsider… where'd you go?", 2.2)
	rim.queue_free()
	a.queue_free()
	owen.visible = true
	owen.process_mode = Node.PROCESS_MODE_INHERIT
	d.cinematic(false)
	hud.banner("HIDE", Color(0.8, 0.8, 0.7), 1.0)
	hud.note("C in tall grass: hidden.", "", 4.0)


func hunt_bark(_owen: Enemy) -> void:
	## Every ~10 s while Owen is within 30 m. Not awaited: keep it to one short line.
	hud.subtitle("Owen", OWEN_LINES[randi() % OWEN_LINES.size()], 2.6)


func hunt_caught(_owen: Enemy) -> void:
	## Owen just hit the player (he'll wander off to search elsewhere). Not awaited.
	hud.subtitle("Owen", CAUGHT_LINES[randi() % CAUGHT_LINES.size()], 2.4)


func hunt_end() -> void:
	## Player reached the square; Owen is gone.
	var alex := _begin_stand_in()
	var behind := alex.global_position - alex.model.global_basis.z * 20.0
	d.shot(alex.global_position + alex.model.global_basis.z * 2.6 + Vector3(0.6, 0.7, 0),
		alex.global_position + Vector3(0, 1.4, 0))
	alex.gesture("slump", 1.4)
	await d.wait(1.4)
	alex.look(behind)
	await hud.subtitle("Alex", "He stopped…", 1.6)
	d.shot(alex.global_position + alex.model.global_basis.z * 1.4 + Vector3(0, 0.4, 0),
		alex.global_position + Vector3(0, 1.9, 0))  # low, up at him and the lamps
	await hud.subtitle("Alex", "The lights. He won't come into the lights.", 2.4)
	alex.look(null)
	_end_stand_in()


# ------------------------------------------------------------------ side mission: Room 4 (evidence #11)

func room4_hint() -> void:
	## Bark, the first time Alex walks up to Lucía's old room (two doors up from room 6). Not awaited.
	hud.say([["Alex", "Room 4. Same eye on the door.", 2.2],
		["Alex", "Lucía's postcards were on this motel's paper.", 2.6]])


func room4_opened() -> void:
	## The pick set the pin (Lockpick, 1 pin). Not awaited: the camera is the next marker, on the mat.
	hud.banner("ROOM 4", Color(0.7, 0.9, 1.0), 1.0)
	hud.say([["Alex", "Chained on the inside. It gives an inch.", 2.4],
		["Alex", "Her camera's hanging off the handle.", 2.2]])


func room4_camera() -> void:
	## Evidence #11: Lucía's camera. Not awaited.
	hud.banner("EVIDENCE #11", Color(0.8, 0.8, 0.9), 1.0)
	hud.say([["Alex", "Lucía's camera. One frame left.", 2.2],
		["Alex", "Her last photo: a chapel. In a quarry.", 2.6]])
