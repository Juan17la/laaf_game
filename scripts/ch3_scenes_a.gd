class_name Ch3ScenesA
extends RefCounted
## Chapter 3 story beats, part A: C3.1 "The Bell", the cemetery chase barks, the church (Marcus, the
## bells, Clara's photo, the bell register, Empty Chairs) and M3 "Static" (Grady, the grief scene at
## Elena's radio, her last recording, the broadcast). Staged through the director `d`
## (scripts/chapter3.gd → chapter1.gd header for the API). Earlier chapters' scene helpers are reused
## through c1a / c1b / c2a / c2b instead of being copied.
## Rule: stage actions (actors move, gesture, cameras cut every 2–5 s); lines stay short.

const MARCUS := "res://models/char_marcus.glb"
const GRADY := "res://models/char_grady.glb"
const YELLOW := Color(0.95, 0.78, 0.15)
const BRASS := Color(0.8, 0.65, 0.3)
const IRON := Color(0.18, 0.17, 0.16)
const CARD := Color(0.92, 0.88, 0.78)
const WARM := Color(1.0, 0.72, 0.38)
const NAVE := Rect2(-84, -106, 24, 12)  ## church interior (x, z), 8 m high
const CHASE_LINES := ["There! By the graves!", "The Deacon wants them breathing!", "Don't let them reach the road!",
	"I hear them! Left!", "Lanterns up! Look under the angels!", "You can't hide from the bell."]
const MARCUS_LINES := ["Clara sang in this choir.", "I kept them alive. All of them.", "Hold still. It's a church.",
	"I hear your heart, outsider.", "Every bell in here has a name.", "She'd have liked you. That's the worst of it."]

var d: Chapter3Director
var hud: Node
var c1a: Ch1ScenesA
var c1b: Ch1ScenesB
var c2a: Ch2ScenesA
var c2b: Ch2ScenesB


func _init(director: Chapter3Director) -> void:
	d = director
	hud = director.hud
	c1a = Ch1ScenesA.new(director)
	c1b = Ch1ScenesB.new(director)
	c2a = Ch2ScenesA.new(director)
	c2b = Ch2ScenesB.new(director)


# ------------------------------------------------------------------ helpers

func _shot(from: Vector3, look: Vector3, to := Vector3.INF, time := 6.0) -> void:
	## Camera cut with every Chapter 3 interior kept honest (church nave, chapel, lighthouse, school).
	d.shot(safe(from), look, safe(to) if to != Vector3.INF else to, time)


static func safe(p: Vector3) -> Vector3:
	if p == Vector3.INF:
		return p
	if NAVE.has_point(Vector2(p.x, p.z)) and p.y < 8.0:
		return Vector3(clampf(p.x, -83.5, -60.6), clampf(p.y, 0.3, 7.4), clampf(p.z, -105.4, -94.8))
	if p.x > -26 and p.x < -18 and p.z > -215 and p.z < -205 and p.y < 5.0:  # the Veil's Chapel
		return Vector3(clampf(p.x, -25.6, -18.4), clampf(p.y, 0.3, 4.5), clampf(p.z, -214.6, -205.4))
	var t := Vector2(p.x - 6.0, p.z - 140.0)  # lighthouse tower
	if t.length() < 3.9 and t.length() > 0.01 and p.y < 17.0:
		t = t.normalized() * 3.9
		p = Vector3(6.0 + t.x, p.y, 140.0 + t.y)
	return p


func _face(a: Node3D, side := 0.3) -> void:
	## Close-up on an actor's face from the front.
	var m: Node3D = a.model if a is Actor else a.get_node("Model")
	var f := Vector3(sin(m.rotation.y), 0, cos(m.rotation.y))
	_shot(a.global_position + f * 1.0 + f.cross(Vector3.UP) * side + Vector3.UP * 1.6,
		a.global_position + Vector3.UP * 1.52)


func _enemy_face(e: Enemy, from: Vector3, side := 0.4) -> void:
	var to := (from - e.global_position)
	to.y = 0.0
	to = to.normalized()
	_shot(e.global_position + to * 1.3 + to.cross(Vector3.UP) * side + Vector3.UP * 1.65, e.global_position + Vector3.UP * 1.5)


# ------------------------------------------------------------------ C3.1 The Bell

func the_bell() -> void:
	## Straight on from C2.2. Ends: player crouched at HIDE facing +X, control on, clock 19:02.
	d.cinematic(true)
	hud.fade(1.0, 0.0)
	var spot := Ch2ScenesB.ELENA_SPOT
	var alex := d.stand_in(Chapter3Director.HIDE, PI / 2.0)
	alex.crouch(true)
	alex.face(spot, 0.01)
	var jacket := c2b._box(d, Vector3(0.55, 0.05, 0.75), YELLOW, Vector3.ZERO)  # all that's left in the mud
	jacket.global_position = spot + Vector3(0, 0.03, 0)
	jacket.rotation.y = 0.5
	var marcus := d.actor(MARCUS, spot + Vector3(1.4, 0, 0.6), -PI / 2.0)
	c2b._lantern(marcus)
	var men: Array[Actor] = []
	for i in 2:
		var m := d.actor(Chapter1Director.MARKED[i], spot + [Vector3(-1.8, 0, 2.0), Vector3(0.8, 0, -2.2)][i], 0.0)
		c2b._lantern(m)
		m.face(spot, 0.01)
		men.append(m)
	var cast: Array[Node] = [jacket, marcus, men[0], men[1]]
	hud.clock("19:02")
	d.shot(Ch2ScenesB.LOCK_CAM, spot + Vector3.UP * 0.6)
	d.cam.fov = 32.0
	hud.fade(0.0, 1.2)
	await hud.subtitle("", "The last note of the bell dies in the rain.", 2.6)
	marcus.crouch(true)
	marcus.gesture("slump")
	marcus.look(jacket)
	d.cam.fov = 18.0
	d.shot(Ch2ScenesB.LOCK_CAM, marcus.global_position + Vector3.UP * 1.0)
	await hud.subtitle("Marcus", "Go on ahead, Elena. Tell Clara I tried.", 2.8)
	# one lantern swings toward the mausoleum: he turns, then points (just the once)
	men[0].look(alex)
	d.cam.fov = 26.0
	d.shot(Ch2ScenesB.LOCK_CAM, men[0].global_position + Vector3.UP * 1.4)
	await men[0].face(Chapter3Director.HIDE)
	men[0].gesture("point", 1.8)
	await hud.subtitle("Marked One", "Deacon. The angels. Something moved.", 2.4)
	d.cam.fov = 45.0
	d.shot(Ch2ScenesB.LOCK_CAM + Vector3(0.05, -0.5, 0.2), Chapter3Director.HIDE + Vector3.UP * 0.7)
	alex.gesture("hand_to_face")
	await d.wait(1.2)
	marcus.crouch(false)
	marcus.gesture("")
	marcus.face(Chapter3Director.HIDE, 0.6)
	marcus.look(alex)
	d.cam.fov = 18.0
	d.shot(Ch2ScenesB.LOCK_CAM, marcus.global_position + Vector3.UP * 1.55)
	await hud.subtitle("Marcus", "Channel seven. She wasn't talking to us.", 2.6)
	marcus.gesture("point", 1.4)
	await hud.subtitle("Marcus", "The outsider. Bring them.", 2.0)
	# he walks back to the tower; the lanterns come for the mausoleum
	marcus.walk_to(Ch2ScenesB.TOWER_DOOR, 1.5)
	for m in men:
		m.gesture("")
		m.walk_to(m.global_position.lerp(Chapter3Director.HIDE, 0.3), 1.2)
	d.cam.fov = 40.0
	d.shot(Ch2ScenesB.LOCK_CAM, spot + Vector3.UP * 1.2)
	await d.wait(1.4)
	d.cam.fov = 60.0
	alex.gesture("clutch_hand")
	d.shot(Ch2ScenesB.LOCK_CAM, Chapter3Director.HIDE + Vector3.UP * 0.7)  # from behind the angels (clear of the bush)
	d.cam.fov = 45.0
	await hud.subtitle("Alex", "Elena…", 1.4)
	await hud.subtitle("Alex", "Not here. Not yet.", 1.6)
	alex.gesture("")
	alex.look(null)
	d.cam.fov = 60.0
	for n in cast:
		n.queue_free()
	alex.crouch(false)
	alex.model.rotation.y = PI / 2.0
	d.release_stand_in()
	d.cinematic(false)
	d.player._set_crouch(true)


func stash_found() -> void:
	var frozen := c2a._freeze()  # the lanterns are already coming
	await c2b._pickup(Vector3(0.2, 0.1, 0.14), Color(0.45, 0.42, 0.35), "+2 SMOKE CANS · BANDAGE", [
		["", "A moth scratched into the marble. Under the step, Elena's tin.", 2.8],
		["Alex", "Smoke cans. She thought of everything.", 2.2]], "lean", "smoke_can")
	hud.note("T throws smoke.", "", 3.5)
	c2a._thaw(frozen)


func bell_rings() -> void:
	## Bark: a chaser saw Alex — the bell rings and the whole yard converges. Not awaited.
	hud.banner("BONG", Color(0.9, 0.8, 0.6), 0.8)
	hud.subtitle("", "The bell. They all heard it.", 1.8)


func chase_bark() -> void:
	hud.subtitle("Marked One", CHASE_LINES[randi() % CHASE_LINES.size()], 2.0)


# ------------------------------------------------------------------ M2 The church

func church_enter() -> void:
	## Just inside the church door: the bells hung low over the aisle, Marcus's voice from the dark.
	var alex := c1a._begin_stand_in()
	var p := alex.global_position
	alex.face(Vector3(-80, 0, -100), 0.3)
	_shot(p + Vector3(0.6, 1.7, 1.2), Vector3(-80, 1.8, -100), p + Vector3(-1.2, 1.9, 0.9), 5.0)
	await hud.subtitle("", "The nave. Candles on every pew.", 2.2)
	_shot(Vector3(-67.5, 1.6, -96.0), Vector3(-71, 5.5, -100))
	await hud.subtitle("", "Three bells hang over the aisle on chains, brought down from the tower.", 3.0)
	_shot(Vector3(-66.0, 1.2, -95.2), Vector3(-65, 1.3, -94.95))
	await hud.subtitle("", "Their ropes are tied off at the wall.", 2.2)
	_shot(Vector3(-70.0, 2.0, -99.5), Vector3(-82, 1.5, -100))
	await hud.subtitle("Marcus", "Clara sang in this choir.", 2.4)
	await hud.subtitle("Marcus", "Every Sunday. Third row. Off-key, and loud.", 2.8)
	alex.look(Vector3(-80, 1.6, -100))
	_face(alex)
	await hud.subtitle("Alex", "Marcus.", 1.2)
	alex.look(null)
	c1a._end_stand_in()


func marcus_intro(marcus: Enemy, bells: Array[Bell]) -> void:
	## The altar. The fight starts when this returns.
	var frozen := c2a._freeze()
	var a := c1b._anim(marcus)
	d.cinematic(true)
	var o := marcus.global_position
	var alex := d.stand_in(safe(c1b._alex_near(o, 6.0)), 0.0)
	alex.face(o, 0.01)
	alex.look(marcus)
	c1b._face_node(marcus, o + Vector3(-3, 0, 0))  # his back to Alex, at the candles
	a.gesture = "reach"
	_shot(alex.global_position + Vector3(0.8, 1.8, 1.0), o + Vector3.UP * 1.2, alex.global_position + Vector3(0.2, 1.7, 0.9), 4.0)
	await hud.subtitle("", "He's lighting candles. One for every bell rung since the festival.", 3.0)
	a.gesture = ""
	c1b._face_node(marcus, alex.global_position)
	_enemy_face(marcus, alex.global_position)
	await hud.subtitle("Marcus", "She was my sister in everything but blood.", 2.6)
	a.gesture = "hand_to_face"
	await hud.subtitle("Marcus", "I held the hammer. Do you understand? Me.", 2.8)
	a.gesture = ""
	await c1b._talk(alex, marcus, "Alex", "Then put it down.", -1.0, 1.6)
	await c1b._talk(marcus, alex, "Marcus", "He said if we served, they'd come back. Clara. Tomás. Lily.", 1.0, 3.2)
	_shot(o + Vector3(1.8, 1.0, 2.0), o + Vector3.UP * 1.7)
	await hud.subtitle("Marcus", "Three years I rang that bell for him.", 2.4)
	a.gesture = "raise_weapon"  # on the threat, not the memory
	await hud.subtitle("Marcus", "Tonight I ring it for you.", 2.0)
	# Elena's last clue, remembered: the bells
	var b: Bell = bells[1]
	_shot(Vector3(b.global_position.x + 2.5, 1.6, -97.0), b.global_position + Vector3.UP * 0.6)
	await hud.subtitle("Elena", "(memory) Marcus hears everything. Make the bells scream.", 3.0)
	a.gesture = ""
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)
	c2a._thaw(frozen)


func bell_dropped(crushed: bool) -> void:
	## Bark: a bell came down. Not awaited.
	if crushed:
		hud.banner("BELL", Color(0.95, 0.75, 0.35), 1.0)
		hud.subtitle("Marcus", ["AAGH—!", "Clara— no—", "You'd bring the church down on me?"][randi() % 3], 1.8)
	else:
		hud.banner("CLANG", Color(0.8, 0.8, 0.75), 0.8)
		hud.subtitle("Marcus", "My ears— where are you—", 1.8)


func marcus_phase(n: int) -> void:
	hud.banner(tr("PHASE %d") % n, Color(1.0, 0.4, 0.3), 1.0)
	hud.say([["", "He rings the hand bell. The doors bang open behind you.", 2.4],
		["Marcus", "Into the house of God! All of you!" if n == 2 else "Nobody leaves! Nobody ever leaves!", 2.2]])


func marcus_down(marcus: Enemy) -> void:
	## Marcus on his knees in the aisle. The spare / kill prompt appears after this.
	var a := c1b._anim(marcus)
	d.cinematic(true)
	var frozen := c2a._freeze()
	var o := marcus.global_position
	var from := safe(c1b._alex_near(o, 2.6))
	_shot(Vector3(from.x, 1.9, from.z), o + Vector3.UP * 0.8, Vector3(from.x, 1.6, from.z).lerp(o, 0.2), 3.0)
	a.gesture = "slump"
	await hud.subtitle("Marcus", "Clara… I'm so tired.", 2.0)
	c1b._face_node(marcus, from)
	a.gesture = "hand_to_face"
	await hud.subtitle("Marcus", "Go on. I did it to Elena. I've earned it.", 2.6)
	a.gesture = ""
	a.look = Vector2(0, -0.3)
	await d.wait(0.6)
	a.look = Vector2.ZERO
	d.cinematic(false)
	c2a._thaw(frozen)


func marcus_spared(marcus: Enemy, with_photo: bool) -> void:
	var a := c1b._anim(marcus)
	var o := marcus.global_position
	d.cinematic(true)
	var frozen := c2a._freeze()
	var alex := d.stand_in(safe(c1b._alex_near(o, 2.4)), 0.0)
	alex.face(o, 0.01)
	alex.look(marcus)
	c1b._face_node(marcus, alex.global_position)
	var side := (alex.global_position - o).normalized().cross(Vector3.UP)
	if with_photo:
		_shot(o + side * 2.6 + Vector3.UP * 1.3, (o + alex.global_position) * 0.5 + Vector3.UP * 0.9)
		await alex.walk_to(o.lerp(alex.global_position, 0.55), 1.0)
		var photo := c2b._prop(c2b._hand(alex), "photo", Vector3(0.1, 0.01, 0.14), CARD, Vector3(0, -0.12, 0.04))
		alex.gesture("give")
		await d.wait(0.5)
		c1a._hand_shot(alex)
		await hud.subtitle("Alex", "It was on the choir pew. Third row.", 2.2)
		a.gesture = "reach"
		await d.wait(0.5)
		a.hold(photo, "show")
		alex.gesture("")
		_shot(o + side * 1.3 + Vector3.UP * 1.0, o + Vector3.UP * 0.9)
		a.gesture = "slump"
		await hud.subtitle("Marcus", "Her Sunday dress. She hated this picture.", 2.6)
		await hud.subtitle("", "The sledgehammer rolls out of his hand.", 2.0)
		a.gesture = "hand_to_face"
		await c1b._talk(marcus, alex, "Marcus", "Elena was right. She was always right.", 1.0, 2.6)
		a.gesture = ""
		await c1b._talk(marcus, alex, "Marcus", "The quarry. I'll be there. Whatever's left of me.", 1.0, 2.8)
	else:
		_shot(o + side * 2.8 + Vector3.UP * 1.4, (o + alex.global_position) * 0.5 + Vector3.UP * 1.0)
		alex.gesture("shake_head", 1.2)
		await hud.subtitle("Alex", "No. She wouldn't have. So I won't.", 2.2)
		a.look = Vector2(0, -0.3)
		await c1b._talk(marcus, alex, "Marcus", "Mercy. From you. In here.", 1.0, 2.2)
		a.gesture = "slump"
		await c1b._talk(marcus, alex, "Marcus", "Take the key. I don't want to hold anything anymore.", 1.0, 2.8)
	# he gets up and walks to the altar candles, away from Alex
	a.gesture = ""
	a.look = Vector2.ZERO
	a.crouching = false
	marcus.set_physics_process(false)
	marcus.collision_layer = 0
	_shot(o + side * 2.4 + Vector3.UP * 1.3, o + Vector3.UP * 0.9)
	await d.wait(0.8)
	c1b._walk_enemy(marcus, Vector3(-80.6, 0, -99.2), 1.0)
	d.track(marcus, side * 2.6 + Vector3.UP * 0.8, Vector3(0, 1.3, 0))
	await d.wait(2.4)
	alex.look(null)
	await hud.fade(1.0, 0.4)
	marcus.visible = false
	d.release_stand_in()
	d.cinematic(false)
	c2a._thaw(frozen)
	hud.fade(0.0, 0.6)


func marcus_killed(marcus: Enemy) -> void:
	var o := marcus.global_position
	d.cinematic(true)
	var frozen := c2a._freeze()
	var alex := d.stand_in(safe(c1b._alex_near(o, 3.0)), 0.0)
	alex.face(o, 0.01)
	alex.look(marcus)
	var back := (alex.global_position - o).normalized()
	_shot(o + back.cross(Vector3.UP) * 1.8 + Vector3.UP * 1.3, o + Vector3.UP * 0.3)
	await hud.subtitle("Marcus", "Clara… sing it for me…", 2.2)
	_shot(o + back * 1.0 + Vector3.UP * 5.0, o + Vector3(0, 7.5, 0))  # up the chains, into the dark
	await d.wait(1.0)
	hud.banner("BONG", Color(0.9, 0.8, 0.6), 1.0)
	await hud.subtitle("", "Somewhere above, a bell rings once more. Nobody is pulling it.", 3.0)
	alex.gesture("hand_to_face")
	_face(alex)
	await hud.subtitle("Alex", "I'm sorry, Elena. I couldn't.", 2.0)
	alex.gesture("")
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)
	c2a._thaw(frozen)


func chapel_key_found() -> void:
	await c2b._pickup(Vector3(0.08, 0.02, 0.22), IRON, "CHAPEL KEY · EVIDENCE #8", [
		["Alex", "Iron. Heavy. An eye cast into the bow.", 2.4],
		["Alex", "And Elena's map. He couldn't burn it.", 2.2],
		["", "The quarry, every cell and cage. One circled in red: \"L.M. — chapel, beside the altar.\"", 3.4]])


func photo_found() -> void:
	var frozen := c2a._freeze()  # may be picked up mid-fight
	await c2b._pickup(Vector3(0.1, 0.01, 0.14), CARD, "CLARA'S PHOTO", [
		["", "A woman in a choir robe, laughing at whoever held the camera.", 2.8],
		["", "On the back: \"Marcus — sing with me. C.\"", 2.4]], "lean", "photo")
	c2a._thaw(frozen)


func register_found() -> void:
	var frozen := c2a._freeze()
	await c2b._pickup(Vector3(0.22, 0.04, 0.3), Color(0.35, 0.2, 0.12), "EVIDENCE #7", [
		["Alex", "The bell register. Every blackout rung since the festival.", 2.8],
		["Alex", "A date, and a count. Hundreds of lines.", 2.4],
		["Alex", "The last one is tonight. \"One. Elena.\"", 2.4]], "reach", "ledger")
	c2a._thaw(frozen)


func candle_lit(who: String, left: int) -> void:
	## Bark (Empty Chairs). Not awaited.
	if left > 0:
		hud.subtitle("Alex", "For %s.", 1.6, [tr(who)])
		return
	hud.banner("MARK -20%  ·  +2 ELENA'S TEA", Color(0.8, 0.9, 0.6), 1.6)
	hud.say([["Alex", "For %s.", 1.4, [tr(who)]], ["Alex", "Five chairs. Five candles. It's all I've got.", 2.4]])


# ------------------------------------------------------------------ M3 Static

func ask_grady(grady: Actor) -> void:
	## Grady's store after the execution: flares and a smoke can, free. The director hands them over.
	d.cinematic(true)
	var alex := d.stand_in(c1b._alex_near(grady.global_position, 1.6), 0.0)
	alex.face(grady.global_position, 0.01)
	grady.face(alex.global_position, 0.01)
	grady.look(alex)
	alex.look(grady)
	d.ots(grady, alex, 1.0)
	await hud.subtitle("Grady", "You're alive. I heard the bell. Everyone heard.", 2.6)
	await c1b._talk(alex, grady, "Alex", "They killed her, Grady.", -1.0, 1.8)
	grady.gesture("slump", 2.0)
	_face(grady)
	await hud.subtitle("Grady", "Three years I sold that girl her tea. Asked her nothing.", 2.8)
	grady.gesture("give")
	var box := c2b._prop(c2b._hand(grady), "supply_box", Vector3(0.3, 0.12, 0.2), Color(0.55, 0.12, 0.08), Vector3(0, -0.12, 0.05))
	await d.wait(0.4)
	c1a._hand_shot(grady)
	await hud.subtitle("Grady", "Flares. A smoke can. Don't pay.", 2.2)
	box.queue_free()
	grady.gesture("")
	await c1b._talk(grady, alex, "Grady", "Just end it.", 1.0, 1.6)
	await c1b._talk(alex, grady, "Alex", "You said you don't pick sides.", -1.0, 2.0)
	grady.gesture("arms_crossed", 2.0)
	await c1b._talk(grady, alex, "Grady", "I pick prices. Tonight the price went up.", 1.0, 2.6)
	grady.look(null)
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)


func static_grief() -> void:
	## M3: Elena's radio, still on. Grady brings her jacket. Ends in the radio room, control on, clock 01:30.
	d.cinematic(true)
	var p: Vector3 = d.player.global_position
	var r := c2a._find("int_radio.glb", p, 4.0)
	var radio: Vector3 = (r.global_position if r else c2a._radio_prop()) + Vector3.UP * 0.15
	var alex := d.stand_in(p, atan2(radio.x - p.x, radio.z - p.z))
	var f := c2a._fwd(alex)
	var side := f.cross(Vector3.UP)
	var close := func() -> void: _shot(radio - f * 0.5 + side * 0.45 + Vector3.UP * 0.3, radio)
	var hum := c1a._light(radio + Vector3.UP * 0.2, Color(0.5, 1.0, 0.6), 0.6, 2.5, true)
	hud.clock("22:50")
	close.call()
	await hud.subtitle("Radio", "Kshhh…", 1.6)
	await hud.subtitle("", "Still on channel seven. Still waiting for her.", 2.6)
	# her thermos, her pencil marks on the dial
	alex.look(radio)
	_shot(p - f * 1.4 + side * 0.9 + Vector3.UP * 1.6, radio)
	alex.gesture("lean")
	await hud.subtitle("", "A thermos, half full. Pencil ticks on the dial: 7, 7, 7.", 2.8)
	c1a._near(alex, f * 1.0 - side * 0.3 + Vector3.UP * 1.5, Vector3(0, 1.4, 0))
	alex.gesture("slump")
	await hud.subtitle("Alex", "You said you'd call when you had what you needed.", 2.8)
	await d.wait(1.0)
	# Grady, out of breath, the yellow jacket over his arm
	var grady := d.actor(GRADY, p - f * 5.0 + side * 1.0, 0.0)
	var jacket := c2b._box(c2b._hand(grady), Vector3(0.4, 0.6, 0.12), YELLOW, Vector3(0, -0.3, 0.06))
	grady.walk_to(p - f * 1.4 + side * 1.0, 1.2)
	_shot(p + f * 0.8 + side * 1.2 + Vector3.UP * 1.6, p - f * 2.0 + Vector3.UP * 1.3)
	await hud.subtitle("Grady", "They left it in the mud.", 2.2)
	await d.wait(1.6)
	alex.gesture("")
	alex.face(grady.global_position, 0.6)
	alex.look(grady)
	grady.face(alex.global_position, 0.3)
	grady.look(alex)
	await c1b._talk(grady, alex, "Grady", "I buried her by the harbor wall. Where the boats can see.", 1.0, 3.0)
	grady.gesture("give")
	await d.wait(0.5)
	c1a._hand_shot(grady)
	await hud.subtitle("Grady", "She'd want it worn.", 2.0)
	await alex.take(jacket, "show")  # out of Grady's hands
	grady.gesture("")
	_face(alex, -0.3)
	await hud.subtitle("Alex", "It still smells like the sea.", 2.0)
	jacket.queue_free()
	hud.banner("ELENA'S JACKET · MARK SLOWER", YELLOW, 2.0)
	await c1b._talk(grady, alex, "Grady", "Her transmitter's there. Channel seven. The code she gave you.", 1.0, 3.0)
	await grady.face(grady.global_position + Vector3.FORWARD * 10.0, 0.4)  # north: points the way, not at Alex
	grady.gesture("point", 1.6)
	await c1b._talk(grady, alex, "Grady", "And the quarry's north. Whatever you decide, decide it before three.", 1.0, 3.0)
	await c1b._talk(alex, grady, "Alex", "Before three.", -1.0, 1.4)
	await hud.fade(1.0, 0.6)
	grady.queue_free()
	hum.queue_free()
	hud.clock("01:30")
	await hud.subtitle("", "01:30.", 1.4)
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)
	hud.fade(0.0, 0.8)


func last_recording() -> void:
	## Elena's recorder: her last message (and the fight's hint: light).
	var found := d.claim_item()
	var alex := c1a._begin_stand_in()
	var p := alex.global_position
	var f := c2a._fwd(alex)
	var rec: Node3D
	if found:  # off the shelf where she left it
		rec = found
		await alex.take(rec)
		f = c2a._fwd(alex)
		p = alex.global_position
	else:
		rec = c2b._prop(c2b._hand(alex), "recorder", Vector3(0.1, 0.03, 0.16), Color(0.2, 0.2, 0.22), Vector3(0, -0.1, 0.04))
		alex.anim.hold_pose = "show"
		await d.wait(0.4)
	c1a._read_shot(alex)
	await hud.subtitle("", "Click.", 0.8)
	await hud.subtitle("Elena", "Test. Test. If you're hearing this, I didn't come back.", 3.0)
	c1a._near(alex, f * 1.0 + Vector3.UP * 1.55, Vector3(0, 1.45, 0))
	await hud.subtitle("Elena", "Alex. It's you, isn't it. Stubborn.", 2.4)
	_shot(p + f.cross(Vector3.UP) * 1.6 - f * 0.4 + Vector3.UP * 1.3, p + Vector3.UP * 1.3)
	await hud.subtitle("Elena", "The thing at the quarry flinches from the lighthouse beam. Every night.", 3.2)
	await hud.subtitle("Elena", "That's why they cut the power at three. Light hurts it.", 3.0)
	c1a._hand_shot(alex)
	await hud.subtitle("Elena", "Tell Tomás… no. Just find him.", 2.4)
	await hud.subtitle("", "Click.", 0.8)
	rec.queue_free()
	alex.gesture("")
	c1a._end_stand_in()


func transmitter_locked(have: int) -> void:
	## Bark: not enough evidence for the broadcast (needs all 12).
	hud.say([["Alex", "%d of 12. She said all of it or nothing.", 2.4, [have]],
		["Alex", "One gap and they call it a hoax.", 2.0]])


func broadcast() -> void:
	## After the tuning: Alex reads it all into Elena's microphone (sets up the Signal ending).
	var alex := c1a._begin_stand_in()
	var p := alex.global_position
	var f := c2a._fwd(alex)
	alex.gesture("lean")
	_shot(p + f.cross(Vector3.UP) * 1.4 - f * 0.3 + Vector3.UP * 1.4, p + Vector3.UP * 1.3)
	await hud.subtitle("Alex", "This is Hollowmere. Population thirty-one. It used to be fourteen thirteen.", 3.4)
	_shot(p - f.cross(Vector3.UP) * 1.2 + f * 0.3 + Vector3.UP * 1.55, p + Vector3.UP * 1.45)
	await hud.subtitle("Alex", "Ledgers. Photos. A bell register. Everything is on this channel.", 3.2)
	await hud.subtitle("Alex", "Her name was Elena Ruiz. Her brother's name is Tomás.", 3.0)
	await hud.subtitle("Alex", "Somebody out there. Please.", 2.0)
	hud.banner("BROADCAST SENT", Color(0.6, 1.0, 0.6), 2.0)
	await hud.subtitle("Radio", "Kshhh…", 1.6)
	alex.gesture("")
	c1a._end_stand_in()
