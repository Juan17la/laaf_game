class_name Ch2ScenesB
extends RefCounted
## Chapter 2 story beats, part B: the side missions (Old Tom, Silas, triage, pharmacy, morgue), the
## clinic (M3 "The Medic", Julian's fight beats and spare / kill) and C2.2 "The Traitor" with the
## chapter card. Staged through the director `d` (scripts/chapter2.gd, API in scripts/chapter1.gd).
## Rule: stage actions (actors move, gesture, cameras cut every 2–5 s); lines stay short.
## Pickup beats stage around wherever the player stands (like ch1 key_found); barks never take the camera.

const CARD := Color(0.92, 0.88, 0.78)
const MANILA := Color(0.82, 0.72, 0.45)
const WARM := Color(1.0, 0.72, 0.38)
const TOM_SPOT := Vector3(-22.6, 0.05, 118.6)  ## dock T-head: Tom's rod, bucket and note
const SILAS_ACROSS := 3.0  ## Alex across Silas' 1.4 m card table (its far edge is 2.1 m from Silas)
const TRIAGE_BED := Vector3(75.4, 0.0, -88.0)  ## the strapped patient's bay (director: _triage)
const TRIAGE_ALEX := Vector3(74.4, 0.0, -88.9)  ## the aisle between the beds and the bay curtains
const MORGUE := Vector3(66.0, 1.0, -112.8)
# C2.2 — cemetery north of the church (church (-72,0,-100) yaw 90: nave x -84..-60, bell tower
# at (-81,-91.5), tower door (-81,-89) facing +Z). Mausoleum (-104,-74): plinth x -106.1..-100.9, z -75.8..-72.2.
const HIDE := Vector3(-101.35, 0.0, -76.25)  ## Alex crouched at the mausoleum's SE corner, behind the bush
const LOCK_CAM := Vector3(-101.2, 1.6, -75.6)  ## the locked hiding view over Alex (checked: clear to ELENA_SPOT)
const ELENA_SPOT := Vector3(-94.0, 0.0, -91.0)  ## open ground between the north graves and the tower
const BELL := Vector3(-81.0, 13.2, -91.5)
const TOWER_DOOR := Vector3(-81.0, 0.0, -88.4)
const TRAITOR_END := Vector3(-103.5, 0.0, -78.5)  ## between grave rows (-104,-80 is on a mound)
const JULIAN_LINES := ["Hold still. This is easier if you don't fight it.", "I lost her on this table.",
	"Breathe in. Deeper.", "You're bleeding on my floor.", "Triage, outsider. Somebody always loses.",
	"Every room in here is mine.", "I can hear you wheezing."]
const FISH_LINES := ["Not Old Tom. Still counts.", "Dinner, at least.", "Something's still down there. Bigger."]

var d: Chapter2Director
var hud: Node
var _tom_props: Node3D  ## rod + bucket on the dock, placed on first read of the note


func _init(director: Chapter2Director) -> void:
	d = director
	hud = director.hud


# ------------------------------------------------------------------ helpers

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


func _box(parent: Node, size: Vector3, color: Color, offset := Vector3.ZERO, glow := 0.0) -> MeshInstance3D:
	## Small box prop (note, file, syringe, map...). parent may be a bone ("HandR" found by the caller).
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	bm.material = mat
	mi.mesh = bm
	parent.add_child(mi)
	mi.position = offset
	return mi


func _prop(parent: Node, item: String, size: Vector3, color: Color, offset := Vector3.ZERO, glow := 0.0) -> Node3D:
	## models/item_<item>.glb once imported, else the _box stand-in. In a right hand it's held properly
	## (HumanoidAnim.hold: gripped by its shape, held out while "give" plays).
	var path := "res://models/item_%s.glb" % item
	var anim := HumanoidAnim.of(parent) if parent.name == "HandR" else null
	var m: Node3D
	if not ResourceLoader.exists(path):
		m = _box(d if anim else parent, size, color, offset, glow)
	else:
		m = (load(path) as PackedScene).instantiate()
		if not anim:
			parent.add_child(m)
			m.position = offset
	return anim.hold(m, "") if anim else m


func _hand(a: Node3D, side := "R") -> Node3D:
	var m: Node3D = a.get("model") if a is Actor else a.get_node("Model")
	var h: Node3D = m.find_child("Hand" + side, true, false)
	return h if h else m


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


func _lantern(a: Actor) -> void:
	## A festival lantern in the left hand, with its warm light.
	var h := _hand(a, "L")
	var lan: Node3D = load("res://models/festival_lantern.glb").instantiate()
	h.add_child(lan)
	lan.position = Vector3(0, -0.3, 0.05)
	lan.scale = Vector3.ONE * 0.35
	var l := OmniLight3D.new()
	l.light_color = WARM
	l.light_energy = 1.6
	l.omni_range = 5.0
	l.set_script(load("res://scripts/flicker.gd"))
	h.add_child(l)
	l.position = Vector3(0, -0.35, 0.1)


func _here(face_at := Vector3.INF) -> Array:
	## Stand-in on the player's spot, facing the player's way or `face_at`: [alex, fwd, right]. Caller did
	## d.cinematic(true).
	var p: Vector3 = d.player.global_position
	var yaw: float = d.player.model.rotation.y
	if face_at != Vector3.INF and Vector2(face_at.x - p.x, face_at.z - p.z).length() > 0.2:
		yaw = atan2(face_at.x - p.x, face_at.z - p.z)
	var alex := d.stand_in(p, yaw)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	return [alex, fwd, fwd.cross(Vector3.UP)]


func _pickup(size: Vector3, color: Color, banner: String, lines: Array, gesture := "lean", item := "") -> void:
	## Close-up on whatever the player just took: Alex reaches for the very thing where it lies (the model the
	## marker showed, d.claim_item) and holds it up to look at, banner, a few lines cutting between reading it
	## over his shoulder and his face, then control back where he stands. With nothing lying there (no model)
	## he brings it out of the drawer / cabinet: the `item` model if given, else a box.
	var thing := d.claim_item()
	d.cinematic(true)
	var h := _here(thing.global_position if thing else Vector3.INF)
	var alex: Actor = h[0]
	var fwd: Vector3 = h[1]
	var right: Vector3 = h[2]
	var p := alex.global_position
	var look: Vector3 = thing.global_position if thing else p + fwd * 0.55 + Vector3.UP * 0.95
	d.shot(p - fwd * 0.3 + right * 0.6 + Vector3.UP * 1.6, look, p - fwd * 0.1 + right * 0.45 + Vector3.UP * 1.45, 2.4)
	if thing:
		await alex.take(thing)
	else:
		alex.gesture(gesture)
		await d.wait(0.7)
		alex.gesture("")
		alex.hold(Interactable.ItemFx.model(item) if item != "" else _box(d, size, color))
		await d.wait(0.4)
	hud.banner(banner, Color(0.8, 0.85, 0.95), 1.6)
	for i in lines.size():
		if i % 2 == 0:  # over his shoulder, onto what he holds
			_read_shot(alex)
		else:  # his face, looking at it
			d.shot(p + fwd * 1.0 - right * 0.35 + Vector3.UP * 1.55, p + Vector3.UP * 1.45)
		await hud.subtitle(lines[i][0], lines[i][1], lines[i][2] if lines[i].size() > 2 else -1.0)
	alex.let_go()
	d.release_stand_in()
	d.cinematic(false)


func _read_shot(a: Actor) -> void:
	## Over the shoulder onto what the right hand holds up (same framing as Ch1ScenesA._read_shot).
	d.shot(a.model.to_global(Vector3(-0.32, 1.78, -0.28)), a.model.to_global(Vector3(-0.07, 1.28, 0.34)))


# ------------------------------------------------------------------ side missions

func old_tom_note() -> void:
	## Harbor dock: Tom isn't here. His rod, bucket and a note at TOM_SPOT (the note interactable goes there).
	var paper := d.claim_item()
	if not _tom_props:
		_tom_props = Node3D.new()
		d.add_child(_tom_props)
		_tom_props.global_position = TOM_SPOT
		_prop(_tom_props, "bucket", Vector3(0.3, 0.32, 0.3), Color(0.35, 0.38, 0.4), Vector3(0.3, 0.0, 0.2))
		var rod := _prop(_tom_props, "fishing_rod", Vector3(0.03, 0.03, 2.4), Color(0.3, 0.22, 0.14), Vector3(-0.2, 0.25, -0.3))
		rod.rotation = Vector3(-0.2, 1.1, 0)
	d.cinematic(true)
	var alex := d.stand_in(_alex_near(TOM_SPOT, 1.1), 0.0)
	alex.face(TOM_SPOT, 0.01)
	var s := TOM_SPOT
	# the empty T-head in the fog: a rod, a bucket, nobody
	d.shot(s + Vector3(4.0, 1.4, -3.0), s + Vector3(0, 0.3, 0), s + Vector3(3.2, 1.2, -2.2), 4.0)
	await hud.subtitle("Alex", "Somebody's rod. Still baited.", 2.2)
	d.shot(s + Vector3(0.9, 0.7, 0.8), s + Vector3(0.3, 0.2, 0.2))
	var note: Node3D
	if paper:  # the note that was lying on the boards
		note = paper
		await alex.take(note)
	else:
		note = alex.hold("note")
		await d.wait(0.5)
	_read_shot(alex)
	await hud.subtitle("Tom", "\"Gone to the meeting. Rod's yours if you can hold it.\"", 2.8)
	await hud.subtitle("Tom", "\"Old Tom's still under the dock. The Ruiz boy named him.\"", 3.0)
	d.shot(alex.global_position + Vector3(1.2, 1.5, 0.9), alex.global_position + Vector3.UP * 1.5)
	alex.anim.hold_pose = ""  # lowers it
	alex.look(s + Vector3(-3, 0, 0))
	await hud.subtitle("Tom", "\"Tomás fed him every morning. Nobody's fed him since.\"", 3.0)
	await hud.subtitle("Alex", "Tomás. Elena's brother.", 2.0)
	alex.let_go()
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)


func fish_caught(legendary: bool) -> void:
	## After a catch. Normal fish: a bark. The legendary catfish: close-up + the sunken box (evidence #10).
	if not legendary:
		hud.subtitle("Alex", FISH_LINES[randi() % FISH_LINES.size()], 2.0)
		return
	d.cinematic(true)
	var h := _here()
	var alex: Actor = h[0]
	var fwd: Vector3 = h[1]
	var right: Vector3 = h[2]
	var p := alex.global_position
	alex.gesture("reach")
	var fish := _box(_hand(alex), Vector3(0.18, 0.9, 0.22), Color(0.22, 0.24, 0.18), Vector3(0, -0.4, 0.1))
	d.shot(p + fwd * 1.6 + right * 0.8 + Vector3.UP * 1.1, p + Vector3.UP * 1.2, p + fwd * 1.3 + right * 0.6 + Vector3.UP * 1.2, 3.0)
	hud.banner("OLD TOM", Color(0.6, 0.8, 1.0), 1.6)
	await hud.subtitle("Alex", "Old Tom himself. Look at you.", 2.2)
	d.shot(p + fwd * 0.6 - right * 0.5 + Vector3.UP * 1.3, p + fwd * 0.3 + Vector3.UP * 0.9)
	await hud.subtitle("Alex", "Something's snagged on his jaw. A box.", 2.4)
	# let him go, keep the box
	alex.gesture("lean")
	var tw := fish.create_tween()
	tw.tween_property(fish, "global_position", fish.global_position + fwd * 1.2 + Vector3.DOWN * 1.5, 0.8)
	d.shot(p + right * 1.4 + Vector3.UP * 0.8, p + fwd * 1.2 + Vector3.DOWN * 0.3)
	await hud.subtitle("Alex", "Go on, old man. Back under.", 2.0)
	fish.queue_free()
	var tin := _prop(_hand(alex), "tin_box", Vector3(0.22, 0.08, 0.16), Color(0.4, 0.3, 0.2), Vector3(0, -0.12, 0.05))
	alex.anim.hold_pose = "show"
	await d.wait(0.4)
	_read_shot(alex)
	hud.banner("EVIDENCE #10", Color(0.8, 0.8, 0.9), 1.2)
	await hud.subtitle("Alex", "Photos. Sealed in wax. The festival night...", 2.6)
	await hud.subtitle("Alex", "Every boat in the harbor chained. Nobody was meant to leave.", 3.0)
	tin.queue_free()
	alex.gesture("")
	d.release_stand_in()
	d.cinematic(false)


func silas_intro(silas: Actor) -> void:
	## The Drowned Lantern: Silas at his table invites Alex to Lantern Hi-Lo. The minigame starts after.
	d.cinematic(true)
	var alex := d.stand_in(_alex_near(silas.global_position, SILAS_ACROSS), 0.0)
	alex.face(silas.global_position, 0.01)
	silas.face(alex.global_position, 0.01)
	silas.look(alex)
	alex.look(silas)
	var s := silas.global_position
	var side := (alex.global_position - s).normalized().cross(Vector3.UP)
	d.shot(s + side * 2.2 + Vector3.UP * 1.4, (s + alex.global_position) * 0.5 + Vector3.UP * 1.2,
		s + side * 1.8 + Vector3.UP * 1.5, 4.0)
	silas.gesture("beckon", 2.0)
	await hud.subtitle("Silas", "Sit. Sit! Nobody sits with Silas anymore.", 2.6)
	await _talk(alex, silas, "Alex", "What are we playing?", -1.0, 1.8)
	silas.gesture("give", 2.0)
	d.shot(s + (alex.global_position - s) * 0.5 + side * 0.5 + Vector3.UP * 1.0, s + Vector3.UP * 1.0)
	await hud.subtitle("Silas", "Lantern Hi-Lo. Higher or lower. Like the lanterns that night.", 3.2)
	silas.gesture("slump")
	await _talk(silas, alex, "Silas", "My boy always bet high.", 1.0, 2.2)
	silas.gesture("")
	silas.look(alex)
	await _talk(silas, alex, "Silas", "Beat me three hands and I'll tell you something worth more than tokens.", 1.0, 3.4)
	alex.gesture("nod", 1.0)
	await _talk(alex, silas, "Alex", "Deal.", -1.0, 1.2)
	silas.look(null)
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)


func silas_result(silas: Actor, won: bool) -> void:
	## After the Hi-Lo: won → the Shepherd's letter (evidence #12) + the rumor about Julian's patrol.
	d.cinematic(true)
	var alex := d.stand_in(_alex_near(silas.global_position, SILAS_ACROSS), 0.0)
	alex.face(silas.global_position, 0.01)
	silas.face(alex.global_position, 0.01)
	silas.look(alex)
	alex.look(silas)
	var s := silas.global_position
	if not won:
		silas.gesture("shrug", 2.0)
		await _talk(silas, alex, "Silas", "Ha! The lanterns like me tonight.", 1.0, 2.2)
		await _talk(silas, alex, "Silas", "Come back when your luck sobers up.", 1.0, 2.2)
	else:
		silas.gesture("slump", 1.6)
		await _talk(silas, alex, "Silas", "Three hands. Nobody's done that since my boy.", 1.0, 2.6)
		silas.gesture("give")
		var letter := _prop(_hand(silas), "note", Vector3(0.16, 0.01, 0.11), CARD, Vector3(0, -0.12, 0.04))
		d.shot(s.lerp(alex.global_position, 0.5) + Vector3(0.6, 1.5, 0.6), s.lerp(alex.global_position, 0.4) + Vector3.UP * 1.1)
		await hud.subtitle("Silas", "Took this off the Shepherd's man. Never had the nerve to read it twice.", 3.4)
		letter.queue_free()
		silas.gesture("")
		alex.gesture("give")
		letter = _prop(_hand(alex), "note", Vector3(0.16, 0.01, 0.11), CARD, Vector3(0, -0.12, 0.04))
		hud.banner("EVIDENCE #12", Color(0.8, 0.8, 0.9), 1.2)
		d.shot(alex.global_position + Vector3(-0.4, 1.7, -0.4) + (alex.global_position - s).normalized() * 0.3,
			_hand(alex).global_position)
		await hud.subtitle("Alex", "\"The harvest keeps the valley. Deliver the outsiders.\"", 3.0)
		await hud.subtitle("Alex", "Signed... the Shepherd.", 1.8)
		letter.queue_free()
		alex.gesture("")
		silas.gesture("point", 1.8)
		await _talk(silas, alex, "Silas", "And the medic. The lot, the back wall, the ambulance bay. Same loop, every time.", 1.0, 3.4)
		silas.gesture("nod", 1.2)
		await _talk(silas, alex, "Silas", "He never checks the same room twice in a row.", 1.0, 2.6)
	silas.look(null)
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)


func triage_patient() -> void:
	## Clinic ward: the strapped Marked patient was just freed (the director removes its strapped patient,
	## if any). Its own patient sits up in her bay at TRIAGE_BED, Alex in the aisle; hints at evidence #6.
	d.cinematic(true)
	var alex := d.stand_in(TRIAGE_ALEX, 0.0)
	var fwd := (TRIAGE_BED - TRIAGE_ALEX).normalized()
	var right := fwd.cross(Vector3.UP)
	var p := alex.global_position
	alex.face(TRIAGE_BED, 0.01)
	var pat := d.actor("res://models/char_marked_woman.glb", TRIAGE_BED, atan2(-fwd.x, -fwd.z))
	pat.crouch(true)
	pat.gesture("cower")
	pat.look(alex)
	alex.look(pat)
	d.shot(p + right * 1.8 + fwd * 0.6 + Vector3.UP * 1.2, pat.global_position + Vector3.UP * 0.9,
		p + right * 1.5 + fwd * 0.7 + Vector3.UP * 1.1, 3.0)
	await hud.subtitle("Patient", "You... you're not him.", 2.0)
	alex.gesture("hands_up", 1.4)
	await _talk(alex, pat, "Alex", "Easy. The straps are off.", -1.0, 2.0)
	pat.gesture("")
	pat.crouch(false)
	await d.wait(0.4)
	pat.gesture("clutch_hand", 2.4)
	await _talk(pat, alex, "Patient", "He keeps things cold downstairs. In the morgue.", 1.0, 2.6)
	await pat.face(MORGUE, 0.3)  # turn to the morgue before pointing at it (eyes stay on Alex)
	pat.gesture("point", 2.0)
	await _talk(pat, alex, "Patient", "Third drawer. Something he doesn't want found.", 1.0, 2.6)
	pat.face(alex.global_position, 0.3)
	await _talk(alex, pat, "Alex", "Get out of here. Stay off the halls.", -1.0, 2.0)
	pat.look(null)
	d.shot(p - fwd * 0.8 + right * 0.5 + Vector3.UP * 1.7, pat.global_position + Vector3.UP * 1.2)
	# out of her bay past the curtain ends, along the east wall (not through beds, curtains or Alex)
	await pat.walk_to(Vector3(78.3, 0.0, -89.2), 1.8)
	pat.walk_to(Vector3(78.3, 0.0, -97.0), 1.8)
	await d.wait(1.0)
	pat.queue_free()
	alex.look(null)
	d.release_stand_in()
	d.cinematic(false)


func pharmacy_opened() -> void:
	## The lockpicked pharmacy cabinet: Elena's tea ×2 + evidence #5.
	await _pickup(Vector3(0.12, 0.16, 0.12), Color(0.55, 0.4, 0.25), "ELENA'S TEA ×2 · EVIDENCE #5", [
		["Alex", "Elena's tea. Two tins, her name on the lids.", 2.4],
		["Alex", "And a delivery list. Sedatives, signed J.P.", 2.4],
		["Alex", "Destination: the quarry.", 2.0]], "reach")


func morgue_evidence() -> void:
	## Morgue freezer, third drawer: evidence #6. Cold light from the open drawer.
	var cold := _light(d.player.global_position + Vector3.UP * 1.0, Color(0.6, 0.8, 1.0), 1.2, 4.0)
	await _pickup(Vector3(0.1, 0.01, 0.06), CARD, "EVIDENCE #6", [
		["Alex", "An empty body bag. Just a toe tag.", 2.2],
		["Alex", "\"Tomás R. Transferred. Quarry.\"", 2.4],
		["Alex", "Transferred. Not dead.", 2.0]])
	cold.queue_free()


# ------------------------------------------------------------------ M3 the clinic

func clinic_arrive() -> void:
	## Arriving at St. Agnes (72,0,-100) yaw -90: entrance faces -X at (65,-100), ambulance at (55,-92).
	d.cinematic(true)
	var p: Vector3 = d.player.global_position
	var alex := d.stand_in(p, atan2(65.0 - p.x, -100.0 - p.z))
	var flick := _light(Vector3(62.5, 3.0, -100), Color(0.7, 1.0, 0.75), 1.0, 8.0, true)
	d.shot(Vector3(50.0, 1.6, -109.0), Vector3(65, 4.5, -100), Vector3(51.5, 2.4, -107.0), 4.5)
	await hud.subtitle("Alex", "St. Agnes Clinic.", 1.8)
	d.shot(Vector3(58.5, 1.2, -96.5), Vector3(55, 1.2, -92), Vector3(58.0, 1.4, -97.5), 3.0)
	await hud.subtitle("Julian", "Visiting hours are over.", 2.2)
	alex.gesture("look_around")
	d.shot(alex.global_position + Vector3(1.0, 1.6, 0.9), alex.global_position + Vector3.UP * 1.55)
	await hud.subtitle("Alex", "Intercom. He knows I'm here.", 2.2)
	alex.gesture("")
	alex.look(Vector3(72, 8, -100))
	d.shot(Vector3(56.0, 0.6, -104.0), Vector3(72, 8.5, -100))
	await hud.subtitle("Alex", "Gas mask first. Then the vents on the roof.", 2.6)
	alex.look(null)
	flick.queue_free()
	d.release_stand_in()
	d.cinematic(false)


func gas_mask_found() -> void:
	await _pickup(Vector3(0.2, 0.18, 0.14), Color(0.2, 0.26, 0.2), "GAS MASK", [
		["Alex", "Old filters. They'll hold. For a while.", 2.4]], "reach", "gas_mask")


func vents_reversed() -> void:
	## Roof HVAC room: the big valve turns, the fans shudder and run backwards.
	d.cinematic(true)
	var h := _here()
	var alex: Actor = h[0]
	var fwd: Vector3 = h[1]
	var right: Vector3 = h[2]
	var p := alex.global_position
	alex.gesture("reach")
	d.shot(p - fwd * 0.4 + right * 0.7 + Vector3.UP * 1.5, p + fwd * 0.6 + Vector3.UP * 1.2)
	await hud.subtitle("", "The valve grinds...", 1.6)
	d.shot(p + right * 1.2 + fwd * 0.5 + Vector3.UP * 1.3, p + Vector3.UP * 1.4)
	alex.gesture("raise_weapon", 1.0)
	await d.wait(1.2)
	# the clinic roof from above: the ducts cough and draw the other way
	d.shot(Vector3(58.0, 15.0, -116.0), Vector3(72, 7.5, -100), Vector3(60.0, 16.5, -113.0), 4.0)
	hud.banner("VENTS REVERSED", Color(0.6, 1.0, 0.7), 1.6)
	await hud.subtitle("", "The fans shudder, and run backwards.", 2.4)
	alex.gesture("")
	d.shot(p + fwd * 1.2 - right * 0.4 + Vector3.UP * 1.6, p + Vector3.UP * 1.5)
	await hud.subtitle("Alex", "Your gas, your lungs, Julian.", 2.2)
	d.release_stand_in()
	d.cinematic(false)


func julian_bark() -> void:
	hud.subtitle("Julian", JULIAN_LINES[randi() % JULIAN_LINES.size()], 2.6)


func julian_checks_spot() -> void:
	hud.subtitle("Julian", "I saw you go in there.", 2.2)


func julian_retreats() -> void:
	## Bark: the stalking Julian, hurt, breaks a canister at his feet and backs off (director: _stalk).
	hud.subtitle("Julian", "Not here. You'll come to my table, outsider.", 2.4)
	hud.banner("JULIAN FALLS BACK", Color(0.6, 0.9, 0.7), 1.2)


func sam_file_found() -> void:
	await _pickup(Vector3(0.24, 0.02, 0.32), MANILA, "SAM'S FILE", [
		["Alex", "\"Samantha Kim. Admitted 22:10, Night of Lanterns.\"", 2.8],
		["Alex", "\"Released to the Shepherd. Alive.\"", 2.4],
		["Alex", "She didn't die on his table. They took her.", 2.6]])


func key_part3_found() -> void:
	var n: int = maxi(int(d.flags.get("key_parts", 0)), 1)
	await _pickup(Vector3(0.05, 0.02, 0.1), Color(0.8, 0.65, 0.3), "KEY PART %d / 3" % n, [
		["Alex", "Julian's piece. Cold, like everything in here.", 2.4]], "lean", "key_part")


func _lunge(julian: Enemy, alex: Actor) -> void:
	## Julian drives a syringe at Alex: mash E to shove him off; fail = a dose (damage), never death.
	var a := _anim(julian)
	var syr := _prop(_hand(julian), "syringe", Vector3(0.02, 0.16, 0.02), Color(0.7, 1.0, 0.75), Vector3(0, -0.12, 0.03), 1.5)
	var from := julian.global_position
	var to := alex.global_position + (from - alex.global_position).normalized() * 0.9
	d.shot(alex.global_position + (alex.global_position - from).normalized() * 1.0 + Vector3(0.4, 1.7, 0),
		from + Vector3.UP * 1.4)
	var tw := julian.create_tween()
	tw.tween_property(a, "attack", 0.6, 0.35)
	await _walk_enemy(julian, to, 5.0)
	d.shot(to.lerp(alex.global_position, 0.5) + (to - alex.global_position).normalized().cross(Vector3.UP) * 1.3
		+ Vector3.UP * 1.4, to.lerp(alex.global_position, 0.5) + Vector3.UP * 1.3)
	alex.gesture("hands_up")
	var ok: bool = await hud.qte("interact", 7, 2.2)
	a.attack = -1.0
	if ok:
		a.flinch = 1.0
		alex.gesture("reach", 0.6)
		await _walk_enemy(julian, to + (to - alex.global_position).normalized() * 1.6, 3.0)
		await hud.subtitle("Alex", "Get off me!", 1.2)
	else:
		a.attack = 0.8
		var hp: float = d.player.health
		d.player.health = maxf(hp - 18.0, 10.0)
		hud.damage_flash()
		alex.gesture("clutch_hand", 1.6)
		await hud.subtitle("Julian", "There. Now you'll slow down.", 2.0)
		a.attack = -1.0
		await _walk_enemy(julian, to + (to - alex.global_position).normalized() * 1.6, 2.0)
	alex.gesture("")
	syr.queue_free()


func julian_intro(julian: Enemy) -> void:
	## The glass surgery hall: Julian waits by the table; the fight starts when this returns.
	julian.set_physics_process(false)
	d.cinematic(true)
	var j := julian.global_position
	var alex := d.stand_in(_alex_near(j, 6.0), 0.0)
	alex.face(j, 0.01)
	alex.look(julian)
	_face_node(julian, alex.global_position)
	var a := _anim(julian)
	var side := (alex.global_position - j).normalized().cross(Vector3.UP)
	# behind the glass: Julian washing up, back turned
	var m: Node3D = julian.get_node("Model")
	m.rotation.y += PI
	d.shot(j + side * 3.0 + Vector3.UP * 1.3, j + Vector3.UP * 1.3, j + side * 2.4 + Vector3.UP * 1.5, 4.0)
	a.gesture = "lean"
	await hud.subtitle("Julian", "I lost her on this table.", 2.2)
	a.gesture = ""
	_face_node(julian, alex.global_position)
	d.track(julian, side * 1.4 + (alex.global_position - j).normalized() * 0.8 + Vector3.UP * 1.4, Vector3(0, 1.5, 0))
	await hud.subtitle("Julian", "Every night since, I scrub. It never comes off.", 2.8)
	if d.flags.get("sam_file", false):
		alex.gesture("give")
		var file := _prop(_hand(alex), "file", Vector3(0.24, 0.02, 0.32), MANILA, Vector3(0, -0.14, 0.05))
		await _talk(alex, julian, "Alex", "I read Sam's file, Julian.", -1.0, 2.0)
		file.queue_free()
		alex.gesture("")
		a.gesture = "shake_head"
		await _talk(julian, alex, "Julian", "You don't get to say her name.", 1.0, 2.2)
	else:
		alex.gesture("point", 1.6)
		await _talk(alex, julian, "Alex", "You gassed a whole building for one outsider?", -1.0, 2.4)
		a.gesture = "arms_crossed"
		await _talk(julian, alex, "Julian", "Triage. Some are lost so the rest survive.", 1.0, 2.6)
	a.gesture = ""
	d.shot(j + (alex.global_position - j).normalized() * 1.2 + side * 0.3 + Vector3.UP * 1.55, j + Vector3.UP * 1.5)
	await hud.subtitle("Julian", "Hold still. This is easier if you don't fight it.", 2.6)
	await _lunge(julian, alex)
	d.ots(julian, alex, 1.0)
	await d.wait(0.6)
	d.release_stand_in()
	d.cinematic(false)
	julian.set_physics_process(true)


func julian_phase2(julian: Enemy) -> void:
	## Julian under 50%: a short beat with a second syringe lunge. Safe awaited or not.
	julian.set_physics_process(false)
	hud.banner("PHASE 2", Color(1.0, 0.4, 0.3), 1.0)
	d.cinematic(true)
	var j := julian.global_position
	var alex := d.stand_in(_alex_near(j, 4.0), 0.0)
	alex.face(j, 0.01)
	alex.look(julian)
	_face_node(julian, alex.global_position)
	var a := _anim(julian)
	a.gesture = "hand_to_face"
	d.shot(j + (alex.global_position - j).normalized() * 1.4 + Vector3(0.3, 1.5, 0), j + Vector3.UP * 1.5)
	await hud.subtitle("Julian", "Not again. I won't lose on this table again!", 2.4)
	a.gesture = ""
	await _lunge(julian, alex)
	d.release_stand_in()
	d.cinematic(false)
	julian.set_physics_process(true)


func julian_down(julian: Enemy) -> void:
	## Julian on his knees, wheezing. The spare / kill prompt appears after this.
	var a := _anim(julian)
	d.cinematic(true)
	var o := julian.global_position
	var from := _alex_near(o, 2.6)
	d.shot(Vector3(from.x, o.y + 1.9, from.z), o + Vector3.UP * 0.8, Vector3(from.x, o.y + 1.6, from.z).lerp(o, 0.2), 3.0)
	a.gesture = "hand_to_face"
	await hud.subtitle("", "He wheezes. Every breath a whistle.", 2.0)
	a.gesture = "slump"
	await hud.subtitle("Julian", "Go on. It's only triage.", 2.0)
	_face_node(julian, from)
	a.look = Vector2(0, -0.3)
	await hud.subtitle("Julian", "One for the rest.", 1.8)
	a.gesture = ""
	a.look = Vector2.ZERO
	d.cinematic(false)


func julian_spared(julian: Enemy, with_file: bool) -> void:
	var a := _anim(julian)
	var o := julian.global_position
	d.cinematic(true)
	var alex := d.stand_in(_alex_near(o, 2.2), 0.0)
	alex.face(o, 0.01)
	alex.look(julian)
	_face_node(julian, alex.global_position)
	var side := (alex.global_position - o).normalized().cross(Vector3.UP)
	if with_file:
		d.shot(o + side * 3.0 + Vector3.UP * 1.3, (o + alex.global_position) * 0.5 + Vector3.UP * 0.9)
		await alex.walk_to(o.lerp(alex.global_position, 0.55), 1.0)
		alex.gesture("give")
		var file := _prop(_hand(alex), "file", Vector3(0.24, 0.02, 0.32), MANILA, Vector3(0, -0.14, 0.05))
		await _talk(alex, julian, "Alex", "Read it. Released to the Shepherd. Alive.", -1.0, 2.6)
		alex.gesture("")
		file.queue_free()
		file = _prop(_hand(julian), "file", Vector3(0.24, 0.02, 0.32), MANILA, Vector3(0, -0.14, 0.05))
		a.gesture = "give"
		d.shot(o + (alex.global_position - o).normalized() * 0.9 + side * 0.5 + Vector3.UP * 1.3, o + Vector3.UP * 0.9)
		await hud.subtitle("Julian", "They told me she bled out. Here. On this table.", 2.8)
		a.gesture = "hand_to_face"
		await hud.subtitle("Julian", "She was alive when they took her.", 2.4)
		file.queue_free()
		a.gesture = "give"
		var key := _prop(_hand(julian), "key_part", Vector3(0.05, 0.02, 0.1), Color(0.8, 0.65, 0.3), Vector3(0, -0.1, 0.04))
		await _talk(julian, alex, "Julian", "Take the key. And my keys. Every door in here.", 1.0, 2.8)
		key.queue_free()
		a.gesture = ""
		alex.gesture("nod", 1.2)
		await _talk(alex, julian, "Alex", "Find out where they took her.", -1.0, 2.0)
		a.look = Vector2(0, -0.2)
		await _talk(julian, alex, "Julian", "The quarry. It's always the quarry.", 1.0, 2.4)
	else:
		d.shot(o + side * 3.0 + Vector3.UP * 1.4, (o + alex.global_position) * 0.5 + Vector3.UP * 1.0)
		alex.gesture("shake_head", 1.2)
		await hud.subtitle("Alex", "No. I'm not doing your triage for you.", 2.2)
		a.look = Vector2(0, -0.3)
		await _talk(julian, alex, "Julian", "Mercy. How unclinical.", 1.0, 2.0)
		a.gesture = "slump"
		await _talk(julian, alex, "Julian", "Go. Before I change my mind.", 1.0, 2.2)
	# Julian gets up and walks off, coughing, into the dark of the clinic
	a.gesture = ""
	a.look = Vector2.ZERO
	a.crouching = false
	julian.set_physics_process(false)
	julian.collision_layer = 0
	d.shot(o + side * 2.6 + Vector3.UP * 1.2, o + Vector3.UP * 0.8)
	await d.wait(0.8)
	_walk_enemy(julian, o - (alex.global_position - o).normalized() * 7.0, 1.4)
	d.track(julian, side * 3.0 + Vector3.UP * 0.6, Vector3(0, 1.3, 0))
	await d.wait(2.2)
	alex.look(null)
	d.ots(julian, alex, 1.0)
	await d.wait(1.4)
	await hud.fade(1.0, 0.4)
	julian.visible = false
	d.release_stand_in()
	d.cinematic(false)
	hud.fade(0.0, 0.6)


func julian_killed(julian: Enemy) -> void:
	var o := julian.global_position
	d.cinematic(true)
	var alex := d.stand_in(_alex_near(o, 3.0), 0.0)
	alex.face(o, 0.01)
	alex.look(julian)
	var back := (alex.global_position - o).normalized()
	d.shot(o + back.cross(Vector3.UP) * 1.8 + Vector3.UP * 1.3, o + Vector3.UP * 0.3)
	await hud.subtitle("Julian", "S-Sam...", 2.0)
	d.ots(alex, julian, 1.0)
	alex.gesture("slump")
	await d.wait(1.6)
	alex.gesture("hand_to_face")
	await hud.subtitle("Alex", "Another one. God.", 2.0)
	alex.look(null)
	alex.gesture("")
	var a_pos := alex.global_position
	d.shot(a_pos + back * 1.6 + Vector3.UP * 2.0, o, a_pos + back * 2.6 + Vector3.UP * 2.6, 3.5)
	await d.wait(1.8)
	await hud.subtitle("Alex", "The key. Take the key and go.", 2.0)
	d.release_stand_in()
	d.cinematic(false)


# ------------------------------------------------------------------ C2.2 The Traitor

func _lock(look: Vector3, fov := 60.0) -> void:
	## The hiding view: always from behind the mausoleum; "cuts" are the lens punching in.
	d.shot(LOCK_CAM, look)
	d.cam.fov = fov


func traitor() -> void:
	## C2.2 then the chapter card. Ends: player at TRAITOR_END (-103.5, 0.05, -78.5), control on, faded in.
	d.cinematic(true)
	await hud.fade(1.0, 0.8)
	var f: Dictionary = d.flags
	var alex := d.stand_in(Vector3(-100.5, 0, -66.5), PI)
	var elena := d.actor("res://models/char_elena.glb", ELENA_SPOT, -PI / 2.0)
	var map := _prop(_hand(elena), "map", Vector3(0.3, 0.01, 0.22), CARD, Vector3(0, -0.13, 0.05))
	var old: Variant = d.get("elena")
	if old is Node and is_instance_valid(old):
		old.visible = false
	var cast: Array[Node] = [elena]
	var lamp := _light(ELENA_SPOT + Vector3(0.6, 1.2, 0.4), WARM, 1.0, 4.5, true)  # her lantern on a grave
	cast.append(lamp)
	await hud.subtitle("", "19:00", 1.6)
	hud.clock("19:00")
	hud.fade(0.0, 1.0)
	# late: over the north fence, through the graves
	alex.walk_to(Vector3(-99.9, 0, -78.6), 1.7)
	d.track(alex, Vector3(-0.7, 1.4, 2.4), Vector3(0, 1.3, -4.0))
	await hud.subtitle("Alex", "Seven, she said. I'm late.", 2.2)
	await d.wait(1.4)
	# Elena among the graves, the map in her hand
	d.shot(ELENA_SPOT + Vector3(-2.6, 1.5, 2.2), ELENA_SPOT + Vector3.UP * 1.3, ELENA_SPOT + Vector3(-2.1, 1.4, 1.7), 3.0)
	elena.gesture("look_around")
	await d.wait(1.6)
	elena.gesture("give")
	await d.wait(0.5)  # let the arm come up before framing the hand
	var hand := _hand(elena).global_position
	d.shot(hand + Vector3(-0.8, 0.45, 0.75), hand, hand + Vector3(-0.6, 0.35, 0.55), 2.6)
	await hud.subtitle("", "The quarry map. Stolen from the Shepherd's own ledger room.", 2.6)
	elena.gesture("")
	elena.face(alex.global_position)
	elena.look(alex)
	d.ots(elena, alex, 1.0)
	await hud.subtitle("Elena", "Alex. I've got it. The whole quarry—", 2.2)
	# she hears something in the fog; her face changes
	elena.look(Vector3(-100, 1.5, -108))
	d.shot(ELENA_SPOT + Vector3(1.0, 1.6, 1.4), ELENA_SPOT + Vector3.UP * 1.55)
	await d.wait(1.0)
	elena.look(alex)
	elena.gesture("shake_head", 1.2)
	await hud.subtitle("Elena", "Don't. Hide.", 1.4)
	elena.gesture("point", 1.2)
	alex.run_to(HIDE)
	d.shot(Vector3(-98.0, 0.9, -80.5), HIDE + Vector3.UP * 0.8)
	await d.wait(1.3)
	alex.face(ELENA_SPOT, 0.2)
	alex.crouch(true)
	alex.look(elena)
	# ---- locked to the mausoleum from here on
	_lock(ELENA_SPOT + Vector3.UP * 1.2, 55.0)
	await d.wait(1.6)
	_lock(BELL, 20.0)
	await hud.subtitle("", "BONG.", 1.2)
	_lock(ELENA_SPOT + Vector3.UP * 1.3, 32.0)
	elena.face(TOWER_DOOR)
	await hud.subtitle("", "The bell. Once.", 1.4)
	# Marcus out of the tower door, a lantern in his fist
	var marcus := d.actor("res://models/char_marcus.glb", TOWER_DOOR, 0.0)
	_lantern(marcus)
	cast.append(marcus)
	var mw := marcus.walk_to(ELENA_SPOT + Vector3(2.6, 0, 0.6), 1.3)
	_lock(TOWER_DOOR + Vector3(-1.0, 1.4, 0.6), 34.0)  # half behind the angels: his light moving
	await d.wait(1.3)
	_lock(marcus.global_position + Vector3.UP * 1.3, 28.0)
	await d.wait(1.3)
	# the others step out of the fog, lanterns first
	var members: Array[Actor] = []
	var said: Array = []
	var roster := [["owen", "Owen", "You sent him to my sawmill.", Vector3(-108.0, 0, -106.0), Vector3(-96.8, 0, -93.2)],
		["nora", "Nora", "Elena... why?", Vector3(-99.0, 0, -112.0), Vector3(-94.2, 0, -94.4)],
		["julian", "Julian", "Triage. One for the rest.", Vector3(-88.0, 0, -111.0), Vector3(-91.6, 0, -93.6)]]
	for r in roster:
		if str(f.get(r[0], "active")) in ["spared", "killed"]:
			continue  # spared or dead: missing from the circle
		var mem := d.actor("res://models/char_%s.glb" % r[0], r[3], 0.0)
		_lantern(mem)
		mem.walk_to(r[4], 1.5)
		members.append(mem)
		said.append(r)
		cast.append(mem)
	_lock(Vector3(-97, 1.0, -100), 50.0)
	await hud.subtitle("", "Lanterns in the fog.", 1.8)
	alex.gesture("clutch_hand")
	_lock(HIDE + Vector3(0.1, 0.6, -0.3), 45.0)  # his hand on the cold marble
	await d.wait(1.4)
	alex.gesture("")
	await mw
	marcus.face(elena.global_position)
	marcus.look(elena)
	elena.face(marcus.global_position)
	elena.look(marcus)
	_lock(marcus.global_position + Vector3.UP * 1.55, 18.0)
	await hud.subtitle("Marcus", "Three years, Elena.", 2.2)
	_lock(ELENA_SPOT + Vector3.UP * 1.5, 20.0)
	await hud.subtitle("Elena", "Three years, Marcus. Tomás was fourteen.", 2.6)
	for mem in members:
		mem.face(elena.global_position)
		mem.look(elena)
	for i in mini(members.size(), 2):  # the first two still standing say their piece
		_lock(members[i].global_position + Vector3.UP * 1.45, 22.0)
		members[i].gesture("shake_head", 1.4)
		await hud.subtitle(said[i][1], said[i][2], 2.2)
	marcus.gesture("give")
	_lock(ELENA_SPOT.lerp(marcus.global_position, 0.5) + Vector3.UP * 1.1, 24.0)
	await hud.subtitle("Marcus", "The map.", 1.4)
	# she lets it fall instead
	map.reparent(d)
	var drop := map.create_tween()
	drop.tween_property(map, "global_position", Vector3(map.global_position.x, 0.03, map.global_position.z), 0.5)
	drop.parallel().tween_property(map, "rotation", Vector3(0, 0.6, 0), 0.5)
	cast.append(map)
	await d.wait(0.8)
	marcus.gesture("")
	_lock(marcus.global_position + Vector3.UP * 1.55, 18.0)
	await hud.subtitle("Marcus", "I kept them alive. All of them. Until you.", 2.6)
	# Marcus listens. Alex holds his breath.
	marcus.look(alex)
	marcus.gesture("look_around")
	_lock(HIDE + Vector3(0.25, 1.2, -0.2), 40.0)
	alex.gesture("hand_to_face")
	await hud.subtitle("", "Don't breathe.", 1.0)
	var still: bool = await hud.qte("interact", 6, 2.4)
	alex.gesture("")
	if not still:
		marcus.face(HIDE, 0.6)
		_lock(marcus.global_position + Vector3.UP * 1.55, 16.0)
		await hud.subtitle("Marcus", "...Who else is here?", 1.8)
		elena.gesture("beckon", 1.4)
		_lock(ELENA_SPOT + Vector3.UP * 1.5, 22.0)
		await hud.subtitle("Elena", "Look at me, Marcus. Not the dead.", 2.2)
	marcus.gesture("")
	marcus.face(elena.global_position, 0.6)
	marcus.look(elena)
	# her last words, to the mausoleum, not to them
	elena.look(alex)
	_lock(ELENA_SPOT + Vector3.UP * 1.55, 14.0)
	await hud.subtitle("Elena", "Channel seven… one-four-one-three.", 2.6)
	_lock(HIDE + Vector3(0.3, 1.0, -0.6), 30.0)
	alex.gesture("clutch_hand")
	await d.wait(1.2)
	_lock(ELENA_SPOT + Vector3.UP * 1.55, 12.0)
	await hud.subtitle("Elena", "Tell them his name was Tomás.", 2.4)
	# the circle closes
	for mem in members:
		mem.walk_to(mem.global_position.lerp(ELENA_SPOT, 0.35), 1.0)
	marcus.walk_to(marcus.global_position.lerp(ELENA_SPOT, 0.4), 0.9)
	_lock(ELENA_SPOT + Vector3.UP * 1.0, 40.0)
	await d.wait(1.8)
	marcus.gesture("raise_weapon")
	_lock(ELENA_SPOT + Vector3.UP * 1.3, 28.0)
	await d.wait(0.9)
	# the blow comes down; cut to black on the bell
	var ma := marcus.anim
	ma.create_tween().tween_property(ma, "attack", 1.0, 0.35).from(0.6)
	await d.wait(0.2)
	hud.mark_spike(Feel.SPIKE_SCRIPT)  # the bell: Elena
	hud.fade(1.0, 0.05)
	await hud.subtitle("", "BONG.", 1.2)
	ma.attack = -1.0
	marcus.gesture("")
	# ---- the aftermath, still from behind the marble: she lies among the graves in the yellow coat
	elena.gesture("")
	elena.look(null)
	elena.grounded = false
	elena.model.rotation = Vector3(-PI / 2.0, 0.5, 0)  # on her back
	elena.global_position = ELENA_SPOT + Vector3(0, 0.12, 0)
	lamp.set_script(null)  # her lantern, knocked into the grass beside her, still burning
	lamp.light_energy = 0.8
	lamp.global_position = ELENA_SPOT + Vector3(0.8, 0.2, -0.5)
	for mem in members:
		mem.look(null)
		mem.gesture("")
	_lock(ELENA_SPOT + Vector3.UP * 0.4, 30.0)
	await hud.fade(0.0, 1.8)
	await hud.subtitle("", "Nobody says anything.", 2.2)
	# they turn away one by one, lanterns low
	for mem in members:
		mem.walk_to(mem.global_position + (mem.global_position - ELENA_SPOT).normalized() * 9.0, 1.0)
		await d.wait(0.9)
	# Marcus kneels by her, closes her eyes, takes the map out of the grass
	await marcus.walk_to(ELENA_SPOT + (marcus.global_position - ELENA_SPOT).normalized() * 0.9, 0.8)
	marcus.face(ELENA_SPOT, 0.4)
	marcus.crouch(true)
	marcus.gesture("reach", 1.4)
	_lock(ELENA_SPOT + Vector3.UP * 0.5, 16.0)
	await hud.subtitle("Marcus", "Go to sleep, Elena.", 2.4)
	if is_instance_valid(map):
		await marcus.take(map, "")
	marcus.crouch(false)
	_lock(marcus.global_position + Vector3.UP * 1.5, 20.0)
	await hud.subtitle("Marcus", "Ring it again. So the town knows who it lost.", 2.6)
	marcus.walk_to(TOWER_DOOR, 1.1)
	await d.wait(1.8)
	_lock(BELL, 20.0)
	await hud.subtitle("", "BONG.", 1.4)
	# the lantern burns down beside her
	_lock(ELENA_SPOT + Vector3.UP * 0.3, 22.0)
	lamp.create_tween().tween_property(lamp, "light_energy", 0.0, 3.2)
	await hud.subtitle("", "Her lantern gutters out on the grave. The yellow coat is the last thing the fog takes.", 3.4)
	_lock(HIDE + Vector3(0.25, 1.1, -0.3), 40.0)
	alex.gesture("hand_to_face")
	await hud.subtitle("Alex", "...Tomás. His name was Tomás.", 2.6)
	await hud.fade(1.0, 1.4)
	f["elena_alive"] = false
	for n in cast:
		if is_instance_valid(n):
			n.queue_free()
	if old is Node and is_instance_valid(old):
		old.queue_free()
		d.set("elena", null)
	alex.crouch(false)
	alex.gesture("")
	alex.look(null)
	alex.global_position = TRAITOR_END
	alex.model.rotation.y = PI / 2.0
	d.cam.fov = 60.0
	await d.wait(1.5)
	hud.banner("II · MOTH", Color(0.85, 0.8, 0.7), 4.0)
	await d.wait(4.5)
	var nora_text: String = {"spared": "spared", "killed": "killed"}.get(f.get("nora", "active"), "fled")
	var julian_text: String = {"spared": "spared", "killed": "killed"}.get(f.get("julian", "active"), "fled")
	await hud.say([["", "End of Chapter 2.  Nora: %s · Julian: %s · Evidence %d · Tokens %d · Key parts %d/3" % [
		nora_text, julian_text, f.evidence.size(), f.tokens, int(f.get("key_parts", 0))]]])
	d.release_stand_in()
	d.cinematic(false)
	hud.fade(0.0, 1.5)
