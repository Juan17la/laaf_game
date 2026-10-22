class_name Ch2ScenesA
extends RefCounted
## Chapter 2 story beats, part A: C2.1 Moth on the dock, M1 channel seven (lighthouse radio),
## M2 the school (PA, power cut, Lily's drawing, key part 2) and Nora's boss beats.
## Staged through the director `d` (scripts/chapter2.gd → chapter1.gd header for the API).
## Chapter 1's scene helpers (_prop, _light, _near, _hand_shot, _talk, _anim, _walk_enemy…) are
## reused through c1a / c1b instead of being copied.

const ELENA := "res://models/char_elena.glb"
const DOCK_STAND := Vector3(-6.0, 0.05, 116.0)  ## player hand-back spot after C2.1 (+0.05 on release)
const LIGHTHOUSE := Vector3(6, 0, 140)
const LIGHTHOUSE_DOOR := Vector3(6.0, 0.05, 132.0)
const ELENA_WAIT := Vector3(4.0, 0.05, 134.2)  ## by the lighthouse door, waiting for the battery
const SCHOOL := Vector3(108, 0, 0)
const PA_SPOT := Vector3(101.15, 3.1, 2.2)  ## on the inside of the school's front wall, beside the door
const MANNEQUIN := Vector3(105.95, 1.0, -7.0)  ## the child mannequin baked into school.glb
const PAPER := Color(0.92, 0.88, 0.78)
const BANDAGE := Color(0.85, 0.82, 0.75)
const BRASS := Color(0.8, 0.65, 0.3)
const COLD := Color(0.55, 0.65, 0.9)
const PA_LINES := ["Lily, sweetheart, we have a guest.", "Recess is over. Come back to class.",
	"No running in the halls, please.", "Everyone to the auditorium. Quietly.",
	"I can hear your shoes, new student.", "Lily, don't talk to strangers.",
	"Line up by the door. Hands to yourselves."]
const LILY_LINES := ["Lily?", "Lily, answer Mommy.", "It's only the dark, sweetheart.",
	"Lily? Count with me. One… two…", "Don't hide from me. Not again.", "Baby, where are you?",
	"I left the light on for you. I did."]

var d: Chapter2Director
var hud: Node
var c1a: Ch1ScenesA
var c1b: Ch1ScenesB
var _pa: Node3D  ## the PA speaker above the school door (placed on first use)


func _init(director: Chapter2Director) -> void:
	d = director
	hud = director.hud
	c1a = Ch1ScenesA.new(director)
	c1b = Ch1ScenesB.new(director)


# ------------------------------------------------------------------ helpers

func _safe(p: Vector3) -> Vector3:
	## Keeps a camera spot out of the lighthouse tower and inside the school's walls.
	var t := Vector2(p.x - LIGHTHOUSE.x, p.z - LIGHTHOUSE.z)
	if t.length() < 3.9 and t.length() > 0.01 and p.y < 17.0:
		t = t.normalized() * 3.9
		p = Vector3(LIGHTHOUSE.x + t.x, p.y, LIGHTHOUSE.z + t.y)
	if p.x > 100.6 and p.x < 115.4 and absf(p.z) < 18.4 and p.y > -0.5:
		p = Vector3(clampf(p.x, 101.5, 114.5), clampf(p.y, 0.3, 3.3), clampf(p.z, -17.5, 17.5))
	return p


func _shot(from: Vector3, look: Vector3, to := Vector3.INF, time := 6.0) -> void:
	d.shot(_safe(from), look, _safe(to) if to != Vector3.INF else to, time)


func _fwd(a: Actor) -> Vector3:
	return Vector3(sin(a.model.rotation.y), 0, cos(a.model.rotation.y))


func _face_cam(a: Actor, side := 0.3) -> void:
	## Close-up on an actor's face from the front.
	var f := _fwd(a)
	_shot(a.global_position + f * 1.0 + f.cross(Vector3.UP) * side + Vector3.UP * 1.6,
		a.global_position + Vector3.UP * 1.52)


func _find(file: String, near: Vector3, radius: float) -> Node3D:
	## Nearest instanced model (e.g. "int_radio.glb") within radius of `near`, or null.
	var best: Node3D = null
	for n in d.get_parent().find_children("*", "Node3D", true, false):
		if n.scene_file_path.ends_with(file) and n.global_position.distance_to(near) < radius:
			if not best or n.global_position.distance_to(near) < best.global_position.distance_to(near):
				best = n
	return best


func _freeze() -> Array:
	## Stops every enemy's AI while a beat runs (nobody swings at the hidden player). Undo with _thaw.
	var list := []
	for e in d.get_tree().get_nodes_in_group("enemies"):
		if e.is_physics_processing():
			e.set_physics_process(false)
			list.append(e)
	return list


func _thaw(list: Array) -> void:
	for e in list:
		if is_instance_valid(e) and e.visible:
			e.set_physics_process(true)


func _radio_prop() -> Vector3:
	## The director only marks the lighthouse radio (LH_RADIO): give it a crate and a set for the scene.
	var at := Chapter2Director.LH_RADIO
	var crate: Node3D = (load("res://models/crate.glb") as PackedScene).instantiate()
	d.add_child(crate)
	crate.global_position = Vector3(at.x, 0, at.z - 0.2)
	var radio: Node3D = (load("res://models/int_radio.glb") as PackedScene).instantiate()
	d.add_child(radio)
	radio.global_position = Vector3(at.x, 0.97, at.z - 0.2)
	return radio.global_position


func _pa_prop() -> void:
	if not is_instance_valid(_pa):
		_pa = (load("res://models/int_pa_speaker.glb") as PackedScene).instantiate()
		d.add_child(_pa)
		_pa.global_position = PA_SPOT
		_pa.rotation.y = PI / 2.0  # horn (+Z) into the room (+X)


func _stand_front(dist := 0.8, height := 1.0) -> Array:
	## Stand-in where the player is; returns [alex, point `dist` in front of them at `height`].
	var alex := c1a._begin_stand_in()
	return [alex, alex.global_position + _fwd(alex) * dist + Vector3.UP * height]


func _paper_in_hand(a: Actor, color := PAPER, kind := "map") -> Node3D:
	return c1a._prop(a.model, "HandR", Vector3(0.16, 0.01, 0.12), color, Vector3(0, -0.12, 0.04), kind)


func _add_evidence(n: int) -> void:
	if not n in d.flags.evidence:
		d.flags.evidence.append(n)


# ------------------------------------------------------------------ C2.1 Moth

func moth_intro() -> void:
	## Ends: player at DOCK_STAND (+0.05) facing +X, controls on, faded in, clock 09:00.
	d.cinematic(true)
	await hud.fade(1.0, 0.8)
	d.mood("overcast", 0.1)  # 09:00: grey daylight in the fog, not midnight
	d.player.global_position = DOCK_STAND + Vector3.UP * 0.05
	var alex := d.stand_in(Vector3(2.0, 0.05, 116.2), -PI / 2.0)
	var elena := d.actor(ELENA, Vector3(-10.5, 0.05, 116.4), -PI / 2.0)
	elena.look(Vector3(-40, 1.0, 116))  # out to sea, her back to the shore
	# fog on the harbor, the dock running out into it
	d.shot(Vector3(-19.0, 3.2, 108.5), Vector3(-6.0, 0.8, 117.0), Vector3(-17.5, 2.4, 110.2), 6.0)
	await d.wait(0.8)
	hud.fade(0.0, 1.5)
	await hud.subtitle("", "09:00. The harbor.", 2.4)
	hud.clock("09:00")
	var walk := alex.walk_to(DOCK_STAND, 1.5)
	d.track(alex, Vector3(2.4, 1.5, -1.8), Vector3(0, 1.3, 0))
	await hud.subtitle("", "A yellow rain jacket at the end of the dock.", 2.6)
	# her face; Alex coming up behind her
	d.shot(Vector3(-13.2, 1.6, 115.7), Vector3(-10.5, 1.55, 116.4))
	await hud.subtitle("Elena", "You came alone. Good.", 2.2)
	await Actor.settle(walk)  # (the walk may be over by now)
	alex.look(elena)
	d.ots(elena, alex, 1.0)
	await hud.subtitle("Alex", "Moth?", 1.4)
	# she turns: two-shot from the water, the lighthouse behind them
	elena.look(alex)
	elena.face(alex.global_position, 0.6)
	_two_shot()
	await hud.subtitle("Elena", "Elena. Moth is for the radio.", 2.4)
	await c1b._talk(alex, elena, "Alex", "You left the note. And the eye on my door?", -1.0, 2.6)
	elena.gesture("shake_head", 1.2)
	await c1b._talk(elena, alex, "Elena", "The note was me. The eye was Owen.", 1.0, 2.4)
	# the bandage comes off: the same brand
	var bandage := c1a._prop(elena.model, "HandR", Vector3(0.09, 0.05, 0.12), BANDAGE, Vector3(0, -0.08, 0.02), "bandage")
	elena.gesture("give")
	await d.wait(0.5)
	c1a._hand_shot(elena)
	await hud.subtitle("", "She unwinds the bandage.", 1.6)
	bandage.queue_free()
	var brand := c1a._light(c1a._hand(elena).global_position + Vector3(0, 0.15, 0), Color(1.0, 0.4, 0.1), 0.7, 0.7, true)
	await hud.subtitle("Alex", "The same mark.", 1.6)
	alex.gesture("clutch_hand", 2.0)
	_face_cam(elena)
	await hud.subtitle("Elena", "I'm one of them.", 1.8)
	brand.queue_free()
	elena.gesture("")
	d.ots(elena, alex, 1.0)
	await hud.subtitle("Elena", "I'm also the only one who wants them gone.", 2.6)
	await c1b._talk(alex, elena, "Alex", "Then tell me where my sister is.", -1.0, 2.2)
	elena.look(Vector3(60, 3, 60))  # inland, toward the quarry road
	_two_shot()
	await hud.subtitle("Elena", "The quarry. They took Lucía there.", 2.4)
	# a glimpse of her: the cage by the Veil's chapel altar, where Chapter 3 finds her
	await hud.fade(1.0, 0.3)
	var at := Chapter3Director.LUCIA_CAGE
	var cage: Node3D = (load("res://models/cage.glb") as PackedScene).instantiate()
	d.add_child(cage)
	cage.global_position = at
	var lucia := d.actor("res://models/char_lucia.glb", at, 0.0)
	lucia.crouch(true)
	var lamp := c1a._light(at + Vector3(0.5, 1.1, 1.3), Color(1.0, 0.55, 0.25), 2.6, 5.0, true)
	d.shot(at + Vector3(1.0, 0.95, 2.1), at + Vector3.UP * 0.8, at + Vector3(0.8, 0.9, 1.8), 3.0)
	hud.fade(0.0, 0.4)
	await d.wait(0.6)
	lucia.look(at + Vector3(0.9, 0.95, 2.0))  # up at the camera
	await hud.subtitle("Elena", "Alive.", 1.6)
	await hud.fade(1.0, 0.3)
	for n in [cage, lucia, lamp]:
		n.queue_free()
	elena.look(alex)
	_face_cam(elena, -0.3)
	hud.fade(0.0, 0.3)
	await d.wait(0.5)
	alex.gesture("hand_to_face", 1.8)
	_face_cam(alex)
	await hud.subtitle("Alex", "Alive…", 1.4)
	# the plan: the gate key, the chapel key
	elena.gesture("point", 2.0)
	d.ots(elena, alex, 1.0)
	await hud.subtitle("Elena", "One way out. The tunnel gate on the Old Pass.", 2.6)
	elena.gesture("")
	await c1b._talk(elena, alex, "Elena", "Its key comes in three parts. Owen. Nora. Julian.", 1.0, 3.0)
	var key := c1a._prop(alex.model, "HandR", Vector3(0.05, 0.02, 0.1), BRASS, Vector3(0, -0.1, 0.04), "key_part")
	alex.gesture("give")
	await d.wait(0.4)
	c1a._hand_shot(alex)
	await hud.subtitle("Alex", "Owen's is in my pocket.", 1.8)
	key.queue_free()
	alex.gesture("")
	elena.gesture("nod", 1.2)
	await c1b._talk(elena, alex, "Elena", "Then you're a third of the way out.", 1.0, 2.2)
	await c1b._talk(alex, elena, "Alex", "And Lucía?", -1.0, 1.4)
	await c1b._talk(elena, alex, "Elena", "Locked in the Veil's chapel. Marcus holds that key.", 1.0, 2.8)
	elena.gesture("arms_crossed")
	await c1b._talk(elena, alex, "Elena", "Marcus comes last. Trust me.", 1.0, 2.0)
	await c1b._talk(alex, elena, "Alex", "Why help me?", -1.0, 1.4)
	elena.gesture("shrug", 1.4)
	_face_cam(elena)
	await hud.subtitle("Elena", "You're an outsider with nothing to lose. That's useful.", 2.8)
	# the errand: battery → lighthouse radio
	elena.look(LIGHTHOUSE + Vector3.UP * 10)
	await elena.face(LIGHTHOUSE)  # turn first, then point (the arm follows her round to the boathouse)
	elena.gesture("point")
	d.shot(Vector3(-11.5, 1.2, 114.6), LIGHTHOUSE + Vector3.UP * 8.0)
	await hud.subtitle("Elena", "My radio's in the lighthouse. Dead since the blackout.", 2.8)
	elena.face(Vector3(12, 0, 108))
	elena.look(Vector3(12, 1.5, 108))
	_shot(Vector3(-3.5, 1.7, 118.0), Vector3(12, 1.5, 108))
	await hud.subtitle("Elena", "There's a car battery in the boathouse. Bring it.", 2.6)
	elena.gesture("")
	elena.face(alex.global_position)
	elena.look(alex)
	await c1b._talk(alex, elena, "Alex", "And you?", -1.0, 1.2)
	await c1b._talk(elena, alex, "Elena", "I'll be there. Don't drop it.", 1.0, 2.0)
	# she walks off the dock past Alex and up the harbor road to the lighthouse, where she said she'd be
	elena.look(null)
	var gone := elena.walk_to(Vector3(-4.0, 0.05, 117.3), 1.6)
	d.shot(Vector3(-8.5, 1.7, 115.1), Vector3(-3.0, 1.4, 117.0))
	await gone
	alex.face(Vector3(10, 0.05, 116), 0.6)
	alex.look(elena)
	await elena.walk_to(Vector3(4.0, 0.05, 117.3), 1.6)
	elena.walk_to(LIGHTHOUSE_DOOR + Vector3(0, 0, -2.0), 1.6)  # north, toward the tower
	d.shot(DOCK_STAND + Vector3(-1.2, 1.7, -0.6), LIGHTHOUSE + Vector3.UP * 6.0)
	await d.wait(2.6)
	await hud.fade(1.0, 0.5)
	# she waits by the radio room door for the battery (radio_room picks her up from there)
	elena.global_position = d.spot(ELENA_WAIT)
	elena.face(LIGHTHOUSE_DOOR + Vector3(0, 0, -12.0), 0.01)
	elena.gesture("arms_crossed")
	d.elena = elena
	alex.look(null)
	alex.model.rotation.y = PI / 2.0
	d.release_stand_in()
	d.cinematic(false)
	hud.fade(0.0, 0.8)


func _two_shot() -> void:
	## From over the water south-west of the dock: both of them, the lighthouse behind.
	d.shot(Vector3(-17.0, 1.8, 111.3), Vector3(-7.8, 1.5, 116.4))


# ------------------------------------------------------------------ M1 Channel Seven

func battery_taken() -> void:
	## Bark: the player just picked up the car battery in the boathouse.
	hud.say([["Alex", "Heavy. Walk, don't run.", 2.0], ["Alex", "Lighthouse. North, along the shore.", 2.2]])


func radio_room() -> void:
	## After the radio tuning in the lighthouse. Ends at LIGHTHOUSE_DOOR (+0.05), facing town (-Z), 15:00.
	_add_evidence(9)
	d.cinematic(true)
	var p: Vector3 = d.player.global_position
	var r := _find("int_radio.glb", p, 4.0)
	var radio: Vector3 = (r.global_position if r else _radio_prop()) + Vector3.UP * 0.15
	var alex := d.stand_in(p, atan2(radio.x - p.x, radio.z - p.z))
	var f := _fwd(alex)
	var side := f.cross(Vector3.UP)
	var elena: Actor = d.elena if is_instance_valid(d.elena) else d.actor(ELENA, p, 0.0)  # she was waiting
	elena.gesture("")
	elena.global_position = d.spot(p + side * 1.4 - f * 0.3, p)
	elena.face(radio, 0.01)
	alex.look(radio)
	elena.look(radio)
	var close := func() -> void: _shot(radio - f * 0.5 + side * 0.45 + Vector3.UP * 0.3, radio)
	close.call()
	await hud.subtitle("Radio", "Kshhh… channel seven…", 1.8)
	await hud.subtitle("", "A recording, hidden under the static.", 2.2)
	_shot(p - f * 1.6 - side * 0.8 + Vector3.UP * 1.7, radio)  # both of them, leaning in
	elena.gesture("arms_crossed")
	await hud.subtitle("Elena", "\"Night of the Lanterns. Three years on.\"", 2.4)
	close.call()
	await hud.subtitle("Elena", "\"Trucks on the quarry road. Every Tuesday, lights off.\"", 3.0)
	c1a._near(alex, f * 1.0 - side * 0.3 + Vector3.UP * 1.6, Vector3(0, 1.5, 0))
	alex.gesture("hand_to_face", 2.8)  # a reaction, not a pose to hold through the rest of the tape
	await hud.subtitle("Elena", "\"He calls the taken 'recruited'. I call them buried.\"", 3.0)
	close.call()
	await hud.subtitle("Elena", "\"If anyone hears this: he's lying to us.\"", 2.4)
	await hud.subtitle("Radio", "Kshhh…", 1.2)
	hud.banner("EVIDENCE #9", Color(0.8, 0.8, 0.9), 1.2)
	alex.gesture("")
	alex.look(elena)
	elena.gesture("")
	elena.face(alex.global_position)
	elena.look(alex)
	await c1b._talk(alex, elena, "Alex", "That's your voice.", -1.0, 1.6)
	await c1b._talk(elena, alex, "Elena", "The week I stopped believing him.", 1.0, 2.2)
	# the map: Alex hands it over, she marks two places
	await alex.face(elena.global_position, 0.3)
	var map := _paper_in_hand(alex)
	alex.gesture("give")
	await d.wait(0.5)
	c1a._hand_shot(alex)
	await hud.subtitle("Elena", "Your map.", 1.2)
	alex.gesture("")
	alex.anim.hold_pose = "give"
	await elena.take(map, "")  # out of his hand
	elena.gesture("give")  # holds the map out to show the marks (pointing would jab it at Alex)
	c1a._hand_shot(elena)
	await hud.subtitle("Elena", "The school. Nora.", 1.8)
	await hud.subtitle("Elena", "The clinic. Julian. Either order.", 2.2)
	elena.gesture("")
	_face_cam(elena)
	await hud.subtitle("Elena", "Nora keeps the lights on for a reason.", 2.4)
	await hud.subtitle("Elena", "In the dark she only looks for Lily. Use that.", 2.8)
	await c1b._talk(alex, elena, "Alex", "Lily?", -1.0, 1.2)
	elena.gesture("slump", 1.6)
	await c1b._talk(elena, alex, "Elena", "Her daughter. Six. The festival.", 1.0, 2.4)
	await c1b._talk(elena, alex, "Elena", "Julian gasses his halls. He's asthmatic.", 1.0, 2.6)
	elena.gesture("point", 1.4)
	_face_cam(elena, -0.3)
	await hud.subtitle("Elena", "The vents are on the roof.", 2.0)
	alex.anim.hold(map, "")
	await c1b._talk(alex, elena, "Alex", "You know them well.", -1.0, 1.6)
	elena.look(null)
	elena.gesture("arms_crossed")
	_face_cam(elena)
	await hud.subtitle("Elena", "Nora was my best friend.", 2.2)
	elena.look(alex)
	await c1b._talk(elena, alex, "Elena", "Go. I'll call when I have what I need.", 1.0, 2.4)
	# clock skip
	await hud.fade(1.0, 0.6)
	map.queue_free()
	elena.queue_free()
	hud.clock("15:00")
	await hud.subtitle("", "15:00.", 1.6)
	alex.look(null)
	alex.gesture("")
	alex.global_position = LIGHTHOUSE_DOOR
	alex.model.rotation.y = PI
	d.release_stand_in()
	d.cinematic(false)
	hud.fade(0.0, 0.8)


# ------------------------------------------------------------------ M2 The Teacher

func school_arrive(boxes_silenced: int) -> void:
	## Entering the school. With boxes_silenced < 3 the director spawns the PA ambush after this.
	_pa_prop()
	var alex := c1a._begin_stand_in()
	var a := alex.global_position
	var f := _fwd(alex)
	_shot(a + f * 2.6 + f.cross(Vector3.UP) * 0.8 + Vector3.UP * 1.3, a + Vector3.UP * 1.5)
	alex.gesture("look_around")
	await hud.subtitle("PA", "*ding-dong*", 1.4)
	alex.gesture("")
	alex.look(PA_SPOT)
	_shot(Vector3(103.4, 1.7, 0.9), PA_SPOT)  # up at the speaker over the door
	await hud.subtitle("Nora", "Lily, sweetheart, we have a guest.", 2.6)
	_face_cam(alex)
	await hud.subtitle("Alex", "Nora.", 1.2)
	if boxes_silenced < 3:
		_shot(Vector3(103.6, 1.2, -4.4), MANNEQUIN)  # the little mannequin in its school coat
		await hud.subtitle("Nora", "The children want to play.", 2.2)
		alex.look(MANNEQUIN)
		alex.gesture("look_around", 1.6)
		_shot(a - f * 1.8 + Vector3.UP * 1.7, a + f * 6.0 + Vector3.UP * 1.0)
		await hud.subtitle("Alex", "The music boxes. She heard me.", 2.2)
	else:
		_shot(Vector3(103.4, 1.7, 0.9), PA_SPOT)
		await hud.subtitle("Nora", "It's so quiet outside today. Did you do that?", 2.6)
		_face_cam(alex, -0.3)
		await hud.subtitle("Alex", "Guilty.", 1.2)
	await hud.subtitle("PA", "*click*", 0.8)
	alex.look(null)
	c1a._end_stand_in()


func music_box_silenced(left: int) -> void:
	## Bark: a playground music box was just silenced; `left` still playing.
	if left > 0:
		hud.subtitle("Alex", "Quiet now. %d to go." % left, 2.0)
	else:
		hud.banner("RECESS: ALL QUIET", Color(0.8, 0.8, 0.7), 1.2)
		hud.subtitle("Alex", "That's all of them. She won't hear me coming.", 2.4)


func pa_bark() -> void:
	## Bark: Nora on the PA while the power is on.
	hud.subtitle("Nora", PA_LINES[randi() % PA_LINES.size()], 2.6)


func desk_evidence(n: int) -> void:
	## Short read of a desk find (evidence #3 / #4). Not a cinematic.
	_add_evidence(n)
	hud.banner("EVIDENCE #%d" % n, Color(0.8, 0.8, 0.9), 1.0)
	if n == 3:
		hud.say([["Alex", "Attendance, the week of the festival.", 2.2],
			["Alex", "Six names crossed out in red. 'Recruited.'", 2.6]])
	else:
		hud.say([["Alex", "A letter in Nora's hand. Never sent.", 2.2],
			["Alex", "\"He says if I serve, she might come back.\"", 2.8]])


func power_cut() -> void:
	## Basement power room: the lever. The school's lights and PA die.
	var s := _stand_front(0.7, 1.3)
	var alex: Actor = s[0]
	var lever: Vector3 = s[1]
	var f := _fwd(alex)
	var side := f.cross(Vector3.UP)
	alex.gesture("reach")
	d.shot(lever - f * 0.2 + side * 0.9 + Vector3.UP * 0.1, lever)  # hands on the lever (basement: no clamp)
	await d.wait(0.9)
	var spark := c1a._light(lever + Vector3.UP * 0.2, Color(1.0, 0.85, 0.5), 2.5, 3.0, true)
	var tw := alex.create_tween()
	tw.tween_property(alex, "global_position", alex.global_position + Vector3.DOWN * 0.15, 0.2)
	tw.tween_property(alex, "global_position", alex.global_position, 0.3)
	await hud.subtitle("", "CLUNK.", 1.0)
	spark.queue_free()
	alex.gesture("")
	d.lights_out(SCHOOL, 40.0, 45.0)
	# upstairs, the hall goes dark light by light
	_shot(Vector3(102.2, 2.8, -15.5), Vector3(112, 1.0, 8.0), Vector3(102.6, 2.6, -13.5), 5.0)
	await hud.subtitle("Nora", "Lily? Lily, stay where you a—", 2.0)
	await hud.subtitle("PA", "*kzzt*", 1.0)
	c1a._near(alex, f * 1.0 + side * 0.3 + Vector3.UP * 1.6, Vector3(0, 1.5, 0))
	alex.gesture("look_around", 1.6)
	await hud.subtitle("Alex", "Lights out, Nora.", 1.6)
	await hud.subtitle("Alex", "Now you can't see me either.", 2.0)
	c1a._end_stand_in()


func drawing_found() -> void:
	## Lily's drawing (classroom 3). Hand close-up, then back to play.
	var drawing := d.claim_item()
	var alex: Actor = _stand_front()[0]
	var paper: Node3D
	if drawing:  # off the classroom desk
		paper = drawing
		await alex.take(paper)
	else:
		paper = _paper_in_hand(alex, PAPER, "drawing")
		alex.anim.hold_pose = "show"
		await d.wait(0.5)
	c1a._read_shot(alex)
	hud.banner("LILY'S DRAWING", Color(1.0, 0.85, 0.5), 1.5)
	await hud.subtitle("", "Crayon: a lighthouse, a boat, two stick figures holding hands.", 3.0)
	await hud.subtitle("", "\"ME AND MOMMY. LILY, 6.\"", 2.2)
	_face_cam(alex)
	alex.look(paper)
	await hud.subtitle("Alex", "She'll want this back.", 1.8)
	paper.queue_free()
	alex.look(null)
	alex.gesture("")
	c1a._end_stand_in()


func key_part2_found() -> void:
	## Nora's key part (classroom 3). Assumes d.flags.key_parts was already incremented.
	var part := d.claim_item()
	var s := _stand_front(0.7, 0.9)
	var alex: Actor = s[0]
	var at: Vector3 = part.global_position if part else s[1]
	var f := _fwd(alex)
	var side := f.cross(Vector3.UP)
	var p := alex.global_position
	_shot(p - f * 1.0 + side * 0.5 + Vector3.UP * 1.8, at, p - f * 0.6 + side * 0.4 + Vector3.UP * 1.6, 2.0)
	var key: Node3D
	if part:  # peeled from under the desk
		key = part
		await alex.take(key)
	else:
		key = c1a._prop(alex.model, "HandR", Vector3(0.05, 0.02, 0.1), BRASS, Vector3(0, -0.1, 0.04), "key_part")
		alex.anim.hold_pose = "show"
		await d.wait(0.5)
	c1a._read_shot(alex)
	var n: int = d.flags.get("key_parts", 2)
	hud.banner("KEY PART %d / 3" % n, Color(0.6, 0.9, 1.0), 1.5)
	await hud.subtitle("Alex", "Taped under a child's desk. Nora's piece.", 2.4)
	await hud.subtitle("Alex", "One more." if n < 3 else "All three. The tunnel gate.", 1.8)
	key.queue_free()
	alex.gesture("")
	c1a._end_stand_in()


# ------------------------------------------------------------------ M2 boss: Nora

func nora_intro(nora: Enemy) -> void:
	## The school corridor in the dark. The fight starts when this returns.
	var frozen := _freeze()
	var a := c1b._anim(nora)
	d.cinematic(true)
	var o := nora.global_position
	var dist := clampf(Vector2(d.player.global_position.x - o.x, d.player.global_position.z - o.z).length(), 3.5, 7.0)
	var alex := d.stand_in(c1b._alex_near(o, dist), 0.0)
	alex.face(o, 0.01)
	var to_alex := (alex.global_position - o).normalized()
	var side := to_alex.cross(Vector3.UP)
	c1b._face_node(nora, o - to_alex)  # her back to Alex, talking to the empty seats
	var glow := c1a._light(o + Vector3.UP * 2.2, COLD, 0.0, 5.0)
	glow.reparent(nora)
	var reveal := func(e: float) -> void:
		var t := glow.create_tween()
		t.tween_property(glow, "light_energy", e, 0.3)
		t.tween_property(glow, "light_energy", 0.15, 1.6)
	# the dark corridor, a shape at the far end
	_shot(alex.global_position - to_alex * 1.2 + side * 0.6 + Vector3.UP * 1.8, o + Vector3.UP * 1.1,
		alex.global_position - to_alex * 0.6 + side * 0.5 + Vector3.UP * 1.7, 5.0)
	await hud.subtitle("", "The corridor. Pitch dark.", 2.0)
	reveal.call(1.4)
	a.gesture = "look_around"
	await hud.subtitle("Nora", "Lily? The lights went out, baby.", 2.4)
	_shot(o - to_alex * 1.4 + side * 0.5 + Vector3.UP * 1.6, o + Vector3.UP * 1.5)  # her face, lit from above
	await hud.subtitle("Nora", "Where are you? Mommy's here.", 2.2)
	a.gesture = ""
	alex.look(nora)
	c1a._near(alex, -to_alex * 1.0 + Vector3.UP * 1.6,
		Vector3(0, 1.5, 0))
	await hud.subtitle("Alex", "Nora. Lily isn't here.", 1.8)
	# she turns toward the voice
	c1b._face_node(nora, alex.global_position)
	reveal.call(2.0)
	d.ots(nora, alex, 1.0)
	await hud.subtitle("Nora", "You. You turned off her lights.", 2.2)
	a.gesture = "hand_to_face"
	await hud.subtitle("Nora", "She hates the dark. She was so scared that night.", 2.8)
	a.gesture = ""
	await c1b._talk(alex, nora, "Alex", "I'm sorry.", -1.0, 1.4)
	# the scissors come up; she walks at Alex
	a.gesture = "raise_weapon"
	_shot(o + side * 1.6 + Vector3.UP * 1.3, o + Vector3.UP * 1.6)
	await hud.subtitle("Nora", "Then hold still, sweetheart.", 2.0)
	# she rushes him (only here: the fight's Nora stalks at her own pace), scissors stabbing, the other hand clawing
	a.gesture = "frenzy"
	var walk := c1b._walk_enemy(nora, o + to_alex * (dist - 1.5), 4.4)
	d.track(nora, side * 2.2 + to_alex * 0.8 + Vector3.UP * 1.4, Vector3(0, 1.4, 0))
	alex.gesture("hands_up", 1.2)
	await walk
	d.ots(nora, alex, -1.0)
	await hud.subtitle("Nora", "It's quicker in the dark.", 1.8)
	a.gesture = ""
	glow.queue_free()
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)
	_thaw(frozen)


func nora_calls(_nora: Enemy) -> void:
	## Bark: Nora stops and calls for Lily in the dark (fired on Enemy.called).
	hud.subtitle("Nora", LILY_LINES[randi() % LILY_LINES.size()], 2.2)


func nora_phase2(nora: Enemy) -> void:
	## Under 50% HP: she comes out of the dark and grabs Alex. QTE (E) to shove her off.
	## Safe awaited or not: Nora is frozen while the beat runs.
	if not is_instance_valid(nora) or nora.state in [Enemy.State.DOWN, Enemy.State.DEAD]:
		return
	hud.banner("PHASE 2", Color(1.0, 0.4, 0.3), 1.0)
	var frozen := _freeze()
	var a := c1b._anim(nora)
	var alex := c1a._begin_stand_in()
	var p := alex.global_position
	var o := nora.global_position
	var dir := Vector3(o.x - p.x, 0, o.z - p.z)
	dir = dir.normalized() if dir.length() > 0.3 else _fwd(alex)
	var side := dir.cross(Vector3.UP)
	alex.face(p + dir, 0.2)
	c1b._face_node(nora, p)
	a.gesture = "raise_weapon"
	_shot(p - dir * 1.2 + side * 0.6 + Vector3.UP * 1.7, o + Vector3.UP * 1.5)
	await hud.subtitle("Nora", "GIVE HER BACK!", 1.4)
	# the lunge
	var tw := nora.create_tween()
	tw.tween_property(nora, "global_position", p + dir * 0.75, 0.3).set_trans(Tween.TRANS_QUAD)
	alex.gesture("cower")
	a.gesture = "reach"
	await tw.finished
	_shot(p + side * 1.3 + Vector3.UP * 1.5, p + dir * 0.4 + Vector3.UP * 1.45)
	var ok: bool = await hud.qte("interact", 8, 2.6)
	if ok:
		alex.gesture("hands_up", 0.8)
		var back := nora.create_tween()
		back.tween_property(nora, "global_position", p + dir * 2.2, 0.35).set_trans(Tween.TRANS_QUAD)
		a.gesture = ""
		await hud.subtitle("Alex", "Get off me!", 1.2)
	else:
		d.player.health = maxf(d.player.health - 18.0, 1.0)  # scripted: hurt() is off in cinematics
		hud.damage_flash()
		_shot(p + dir * 0.4 + side * 0.7 + Vector3.UP * 1.6, p + Vector3.UP * 1.5)
		await hud.subtitle("Nora", "Shh. Shh. Sleep now.", 1.6)
		alex.gesture("clutch_hand", 1.0)
		var back := nora.create_tween()
		back.tween_property(nora, "global_position", p + dir * 2.0, 0.6)
		a.gesture = ""
		await back.finished
	alex.gesture("")
	c1a._end_stand_in()
	_thaw(frozen)
	if ok:
		nora.stun(1.5)


func nora_down(nora: Enemy) -> void:
	## Nora on her knees (DOWN). The spare / kill prompt appears after this.
	var a := c1b._anim(nora)
	d.cinematic(true)
	var frozen := _freeze()
	var o := nora.global_position
	var from := c1b._alex_near(o, 2.6)
	_shot(Vector3(from.x, 1.9, from.z), o + Vector3.UP * 0.8, Vector3(from.x, 1.6, from.z).lerp(o, 0.2), 3.0)
	a.gesture = "slump"
	await hud.subtitle("Nora", "Lily… Mommy's tired.", 2.0)
	a.gesture = "hand_to_face"
	c1b._face_node(nora, from)
	await hud.subtitle("Nora", "I only wanted to find her.", 2.2)
	a.gesture = ""
	a.look = Vector2(0, -0.3)
	await hud.subtitle("Nora", "Go on. They all think I'm mad anyway.", 2.4)
	a.look = Vector2.ZERO
	d.cinematic(false)
	_thaw(frozen)


func nora_spared(nora: Enemy, with_drawing: bool) -> void:
	var a := c1b._anim(nora)
	var o := nora.global_position
	d.cinematic(true)
	var frozen := _freeze()
	var alex := d.stand_in(c1b._alex_near(o, 2.4), 0.0)
	alex.face(o, 0.01)
	alex.look(nora)
	c1b._face_node(nora, alex.global_position)
	var side := (alex.global_position - o).normalized().cross(Vector3.UP)
	if with_drawing:
		_shot(o + side * 3.0 + Vector3.UP * 1.3, (o + alex.global_position) * 0.5 + Vector3.UP * 0.9)
		await alex.walk_to(o.lerp(alex.global_position, 0.55), 1.0)
		var paper := _paper_in_hand(alex, PAPER, "drawing")
		alex.gesture("give")
		await d.wait(0.5)
		c1a._hand_shot(alex)
		await hud.subtitle("Alex", "She drew you. You and her.", 2.0)
		a.gesture = "reach"
		await d.wait(0.5)
		a.hold(paper, "show")
		alex.gesture("")
		_shot(o + side * 1.4 + Vector3.UP * 1.0, o + Vector3.UP * 0.9)
		a.gesture = "slump"
		await hud.subtitle("Nora", "Her lighthouse. She drew it the day before.", 2.6)
		await hud.subtitle("", "The scissors slip from her fingers.", 2.0)
		a.gesture = "hand_to_face"
		await c1b._talk(nora, alex, "Nora", "She's gone. She's really gone.", 1.0, 2.4)
		alex.gesture("nod", 1.2)
		await c1b._talk(alex, nora, "Alex", "I'm sorry.", -1.0, 1.4)
		a.gesture = ""
		await c1b._talk(nora, alex, "Nora", "Tell Elena… tell her I'm sorry.", 1.0, 2.4)
	else:
		_shot(o + side * 3.0 + Vector3.UP * 1.4, (o + alex.global_position) * 0.5 + Vector3.UP * 1.0)
		alex.gesture("shake_head", 1.2)
		await hud.subtitle("Alex", "No. Not like them.", 1.8)
		a.look = Vector2(0, -0.3)
		await c1b._talk(nora, alex, "Nora", "She'd be nine now.", 1.0, 1.8)
		await c1b._talk(alex, nora, "Alex", "Then someone should remember her.", -1.0, 2.2)
		a.gesture = "slump"
		await c1b._talk(nora, alex, "Nora", "Go. Before I remember what I am.", 1.0, 2.4)
	# she gets up and walks off into the dark of the school
	a.gesture = ""
	a.look = Vector2.ZERO
	a.crouching = false
	nora.set_physics_process(false)
	nora.collision_layer = 0
	_shot(o + side * 2.6 + Vector3.UP * 1.2, o + Vector3.UP * 0.8)
	await d.wait(0.8)
	var away := o + (o - alex.global_position).normalized() * 6.0
	c1b._walk_enemy(nora, _safe(away + Vector3.UP * 0.5) - Vector3.UP * 0.5, 1.2)
	d.track(nora, side * 3.0 + Vector3.UP * 0.6, Vector3(0, 1.3, 0))
	await d.wait(2.4)
	alex.look(null)
	d.ots(nora, alex, 1.0)
	await d.wait(1.6)
	await hud.fade(1.0, 0.4)
	nora.visible = false
	d.release_stand_in()
	d.cinematic(false)
	_thaw(frozen)
	hud.fade(0.0, 0.6)


func nora_killed(nora: Enemy) -> void:
	var o := nora.global_position
	d.cinematic(true)
	var frozen := _freeze()
	var alex := d.stand_in(c1b._alex_near(o, 3.0), 0.0)
	alex.face(o, 0.01)
	alex.look(nora)
	var back := (alex.global_position - o).normalized()
	# she dies holding a child's yellow jacket
	c1a._prop(nora.get_node("Model"), "HandR", Vector3(0.3, 0.05, 0.22), Color(0.95, 0.8, 0.2), Vector3(0, -0.1, 0.05))
	_shot(o + back.cross(Vector3.UP) * 1.8 + Vector3.UP * 1.3, o + Vector3.UP * 0.3)
	await hud.subtitle("Nora", "Lily… put your jacket on…", 2.2)
	d.ots(alex, nora, 1.0)
	alex.gesture("slump")
	await d.wait(1.4)
	await hud.subtitle("", "Somewhere in the school, a music box winds down. And stops.", 3.0)
	alex.gesture("hand_to_face")
	_face_cam(alex)
	await hud.subtitle("Alex", "Two of them now." if d.flags.owen == "killed" else "What did I just do.", 1.8)
	alex.look(null)
	alex.gesture("")
	var a_pos := alex.global_position
	_shot(a_pos + back * 1.6 + Vector3.UP * 2.0, o, a_pos + back * 2.4 + Vector3.UP * 2.4, 3.5)
	await d.wait(1.6)
	d.release_stand_in()
	d.cinematic(false)
	_thaw(frozen)
