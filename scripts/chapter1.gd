class_name Chapter1Director
extends Node3D
## Chapter 1 — The Mark (maps/docs/en/chapters.md §3). Runs the steps in order:
##   intro (C1.1 + C1.2) → room (M1) → hunt (M2) → square (M3) → sawmill + boss (M4) → blackout (C1.3)
## This file is the GAMEPLAY flow (objectives, spawns, checkpoints). Every story beat — cinematics,
## conversations, radio calls, barks — lives in scripts/ch1_scenes_a.gd (intro → hunt) and
## scripts/ch1_scenes_b.gd (square → blackout), which stage them with the API below:
##   player, hud, cam, flags, cinematic(on), shot(from, look, to, time), track(node, offset, look_offset),
##   ots(speaker, listener, side), wait(sec), actor(scene, pos, yaw), stand_in(pos, yaw), release_stand_in()
## stand_in() reuses/replaces the current stand-in (release first moves the player to it). Staging is kept
## physical: close shots swing round walls instead of filming through them (shot / track), the stand-in and
## the player it hands back to only ever stand on open ground on the right side of a wall (spot, near), and
## a pickup's real model is handed to the scene that stages it (claim_item → Actor.take).
## Every line is a subtitle (babbled by Audio.voice), skippable with Enter / E while in a cinematic.
## Dev: start mid-chapter with `-- --step=hunt` (any step name) or set start_step; "free" = no script.
## After the blackout the sibling Chapter2 node takes over (Chapter2Director.begin); a Chapter 2 step
## name (`-- --step=zones`) or `-- --chapter=2` jumps straight there (armed, key part 1); Chapter 3 the
## same way (`-- --step=harvester`, `-- --chapter=3`), Chapter 2 hands over to it after the traitor.

@export var start_step := "intro"

const STEPS := ["intro", "room", "hunt", "square", "sawmill", "boss", "blackout", "free"]
const MARKED := ["res://models/char_marked_man.glb", "res://models/char_marked_woman.glb"]
const ROOM6 := Vector3(-100.2, 0.1, 49.6)
const ROOM6_DOOR := Vector3(-96.5, 0.1, 49.0)
const SAWMILL_YARD := Vector3(-112.0, 0.0, -2.0)
const CLOSE_SHOT := 5.0  ## a shot closer than this to what it frames is kept out of walls (_frame)
const STEP_START := {  ## where the player stands when a run starts at that step (dev skip)
	"hunt": [Vector3(-94.0, 0.1, 49.5), PI / 2.0], "square": [Vector3(0.0, 0.1, 30.0), PI],
	"sawmill": [Vector3(-34.0, 0.1, 0.0), -PI / 2.0], "boss": [Vector3(-104.0, 0.1, -2.0), -PI / 2.0],
	"blackout": [Vector3(-110.0, 0.1, 0.0), -PI / 2.0]}
## Dying in a boss fight never comes back without a way to hurt it: at least these rounds (loaded + reserve) for
## every gun carried, the magazine full. (The checkpoint's own kit is restored first; this only tops up.)
const BOSS_MIN_AMMO := {"revolver": 12, "flare": 3, "shotgun": 6, "bow": 6}
const OWEN_LINES := ["I can hear you breathing.", "Dad used to say the forest keeps everything.",
	"Come out. It's quicker if you don't run.", "You're not the first outsider. You won't be the last.",
	"The grass won't hide you forever."]

var player: CharacterBody3D
var hud: Node
var cam: Camera3D
var step := ""
var flags := {"owen": "active", "evidence": [], "tokens": 0, "key_part": false, "lantern": false,
	"room4_open": false, "trip_cut": [], "trip_rang": false}
var _checkpoint := {"pos": ROOM6, "yaw": PI / 2.0}
var _kit := {}  ## what Alex carried when he reached the checkpoint (kit()): dying puts it back (_on_died)
var _on_reset := Callable()
var _owen: Enemy
var _grady: Actor
var scenes_a: Ch1ScenesA
var scenes_b: Ch1ScenesB
var _track: Node3D
var _sway := 0.0  ## handheld amplitude (m) of the current shot; 0 = locked off
var _sway_t := randf() * 10.0
var _cin_music := false  ## a cinematic's music is pushed (Snd.push_music)
var _track_offset := Vector3.ZERO
var _track_look := Vector3.ZERO
var _stand_in: Actor
var _save := {}  ## a save being loaded (Game.pending): its flags and inventory are restored at the start
var _stand_from := Vector3.INF  ## where the player stood when the stand-in took over
var _taken: Node3D  ## model of what the player just picked up (Interactable.taken), until claim_item()
var _all_evidence := false  ## dev: start holding all 12 pieces of evidence (`-- --evidence=all`, Dev Mode toggle)
var _start_mark := -1.0  ## dev: start with the Mark here (`-- --mark=N`, Dev Mode); < 0 = as the story has it


class Target extends StaticBody3D:
	## Tin moth on the festival stall: knocked down by any shot.
	signal down
	func hit(_d: float, _p: Vector3, _f := false) -> void:
		if collision_layer == 0:
			return
		collision_layer = 0
		create_tween().tween_property(self, "rotation:x", -PI / 2.0, 0.15)
		down.emit()


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--step="):
			start_step = a.substr(7)
		elif a == "--chapter=2":
			start_step = "c2_intro"
		elif a == "--chapter=3":
			start_step = "c3_bell"
		elif a == "--evidence=all":
			_all_evidence = true
		elif a.begins_with("--mark="):  # dev: start with the Mark at N % (0-100)
			_start_mark = clampf(float(a.substr(7)), 0.0, 100.0)
	var p := G.take_pending()  # from the main menu: a step, or a whole save
	if p.has("step") and str(p.step) != "":
		start_step = p.step
	if p.has("flags"):
		_save = p
	var g := G.game()
	if g and g.get("dev_evidence"):  # Dev Mode's ALL 12 EVIDENCE toggle
		_all_evidence = true
	if g and float(g.get("dev_mark")) >= 0.0:  # Dev Mode's START MARK row
		_start_mark = float(g.get("dev_mark"))
	_start.call_deferred()


func _start() -> void:
	player = get_tree().get_first_node_in_group("player")
	hud = player.hud
	player.died.connect(_on_died)
	player.fell.connect(_on_fell)
	player.mark_cap = Feel.MARK_SOFT_CAP[1]
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 150.0
	add_child(cam)
	scenes_a = Ch1ScenesA.new(self)
	scenes_b = Ch1ScenesB.new(self)
	_setup_world()
	if not _save.is_empty():
		flags = (_save.flags as Dictionary).duplicate(true)
	if _all_evidence:  # dev: the transmitter and the Signal ending (`-- --evidence=all --step=static`)
		flags.evidence = range(1, 13)
	var ch2 := get_parent().get_node_or_null("Chapter2")
	var ch3 := get_parent().get_node_or_null("Chapter3")
	var i := STEPS.find(start_step)
	if i < 0 and ch3 and ch3.owns_step(start_step):  # dev skip into Chapter 3
		arm_player()
		for w in [["axe", 0], ["bow", 10], ["bat", 0], ["shotgun", 8]]:
			player.weapons.give(w[0], w[1])
		flags.key_part = true
		_restore_save()
		side_missions()
		ch3.begin(self, start_step)
		return
	if i < 0 and ch2 and ch2.owns_step(start_step):  # dev skip into Chapter 2
		arm_player()
		player.weapons.give("axe")
		player.weapons.give("bow", 10)
		flags.key_part = true
		_restore_save()
		side_missions()
		ch2.begin(self, start_step)
		return
	if i < 0:
		i = 0
	if i >= STEPS.find("square"):  # skipping ahead: hand over what earlier steps give
		arm_player()
	_restore_save()
	_capture_kit.call_deferred()  # (until the first checkpoint: dying puts back what the run started with)
	if STEPS[i] in STEP_START:
		player.respawn.call_deferred(STEP_START[STEPS[i]][0], STEP_START[STEPS[i]][1])
	for s in STEPS.slice(i):
		step = s
		if STEPS.find(s) > STEPS.find("room"):  # out of room 6: Room 4 and the Tripwire are open
			side_missions()
		if s == "free":
			objective("")
			if STEPS[i] != "free" and ch2:  # played through the blackout: on to Chapter 2
				ch2.begin(self)
			return
		G.send("at_step", [self])
		await Callable(self, "_step_" + s).call()


# ------------------------------------------------------------------ helpers

func _setup_world() -> void:
	# hiding spots: every tall-grass clump in the map + extra clumps along the hunt route
	var grass := load("res://models/ext_tall_grass.glb") as PackedScene
	var extra: Array[Vector3] = []
	for x in range(-82, -24, 5):
		extra.append(Vector3(x + randf_range(-1, 1), 0, 67.5 + randf_range(-0.8, 0.8)))
		extra.append(Vector3(x + 2.5 + randf_range(-1, 1), 0, 52.5 + randf_range(-0.8, 0.8)))
	for z in range(64, 85, 5):
		extra.append(Vector3(-76.5, 0, z))
	for p in extra:
		var g: Node3D = grass.instantiate()
		add_child(g)
		g.global_position = p
		g.rotation.y = randf() * TAU
	for n in get_parent().find_children("*", "Node3D", true, false):
		if n.scene_file_path.ends_with("ext_tall_grass.glb"):
			player.hidden_spots.append(n.global_position)
	# a failing sodium lamp over room 6's door: warm against the cold night, and a reason to be afraid of the dark
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.7, 0.35)
	lamp.light_energy = 1.6
	lamp.omni_range = 8.0
	lamp.set_script(load("res://scripts/flicker.gd"))
	lamp.set("chance", 0.12)
	add_child(lamp)
	lamp.global_position = Vector3(-94.8, 2.6, 49.0)
	# Grady waits at his store door (square)
	_grady = actor("res://models/char_grady.glb", Vector3(14, 0, -17.6), 0.0)


func weapon_pickup(pos: Vector3, id: String, rounds := 0, yaw := 0.0) -> Interactable:
	## A weapon lying at pos: E takes it into the slots and draws it.
	var take := func(_b: Node) -> void:
		var w: Weapons = player.weapons
		w.give(id, rounds)
		w.swap(w.owned.find(id))
		hud.banner(Weapons.GUNS[id].name.to_upper(), Weapons.GUNS[id].color, 1.2)
		hud.note({"axe": "Fire swings.", "bat": "Fire swings.", "bow": "Hold aim to draw.",
			"shotgun": "Close range."}.get(id, ""), "", 3.0)
	return Interactable.make(self, pos, "Take the " + Weapons.GUNS[id].name.to_lower(), take,
		Weapons.GUNS[id].color, false, id).lay(yaw)


func _restore_save() -> void:
	## A loaded save: its inventory and weapons (after the skip's hand-outs, which it replaces).
	if not _save.is_empty():
		G.send("restore_player", [player, _save])
	if _start_mark >= 0.0:  # (after a save's own Mark: the dev override wins)
		player.mark = _start_mark


func arm_player() -> void:
	if player.weapons.gun() == "":
		player.weapons.give("revolver", 24)
		player.weapons.give("flare", 4)
		player.weapons.current = 0


func _checkpoint_at(pos: Vector3, yaw: float) -> void:
	_checkpoint = {"pos": pos, "yaw": yaw}
	_capture_kit.call_deferred()  # (end of the frame: what the step hands out as it reaches the spot counts too)


func _capture_kit() -> void:
	_kit = kit()


func kit() -> Dictionary:
	## Alex's inventory as it stands: weapons and rounds, throwables, tea, the gas mask and its filter, the Mark.
	return {"weapons": player.weapons.snapshot(), "bottles": player.bottles, "smokes": player.smokes,
		"teas": player.teas, "gas_mask": player.gas_mask, "mask_filter": player.mask_filter, "mark": player.mark}


func restore_kit(k: Dictionary) -> void:
	## Back to a kit(): spent rounds, throwables, tea and filter come back, gains since are undone. What can't be
	## found again stays: a weapon picked up since (Weapons.restore) and the gas mask.
	if k.is_empty():
		return
	player.weapons.restore(k.weapons)
	player.bottles = int(k.bottles)
	player.smokes = int(k.smokes)
	player.teas = int(k.teas)
	if k.gas_mask:
		player.mask_filter = float(k.mask_filter)
	player.gas_mask = player.gas_mask or bool(k.gas_mask)
	player.mark = float(k.mark)


func _boss_floor() -> void:
	## A boss-fight respawn: every gun carried gets at least BOSS_MIN_AMMO, and with no gun at all, the revolver.
	var w: Weapons = player.weapons
	if not w.owned.any(func(id: String) -> bool: return Weapons.GUNS[id].kind != "melee"):
		w.give("revolver")
	for id in w.owned:
		if BOSS_MIN_AMMO.has(id):
			w.top_up(id, BOSS_MIN_AMMO[id])


func _on_died() -> void:
	## Blackout: back at the last checkpoint with what Alex carried when he reached it (kit), healed; the step's
	## reset puts the fight back. In a boss fight he always has rounds to fight with (_boss_floor).
	player.controls_enabled = false
	await hud.fade(1.0, 0.8)
	await hud.subtitle("", "You black out…", 1.5)
	var boss: bool = hud.boss_active()
	player.respawn(spot(_checkpoint.pos) + Vector3.UP * 0.05, _checkpoint.yaw)  # on open floor, never in a prop
	restore_kit(_kit)
	if _on_reset.is_valid():
		_on_reset.call()
	if boss or hud.boss_active():
		_boss_floor()
	await hud.fade(0.0, 0.8)
	player.controls_enabled = true


func _on_fell() -> void:
	## Out of the world (player.gd FALL_Y): back on the last checkpoint's open floor, like after a blackout, but
	## mid-play: no heal, no reset of the fight, the inventory untouched (no kit restore), just a cut from black.
	var hp: float = player.health
	var st: float = player.stamina
	player.respawn(spot(_checkpoint.pos) + Vector3.UP * 0.05, _checkpoint.yaw)
	player.health = hp
	player.stamina = st
	await hud.fade(1.0, 0.0)
	hud.fade(0.0, 0.6)


func _use(pos: Vector3, prompt: String, glow := Color(1.0, 0.85, 0.4), item := "") -> void:
	## Coroutine: waits until the player presses E on a marker at pos (showing `item`, an ItemFx kind).
	var it := Interactable.make(self, pos, prompt, func(_by: Node) -> void: pass, glow, false, item)
	await it.used
	_taken = it.taken


func claim_item() -> Node3D:
	## The model of what the player just picked up, still lying where it was, for the scene to take (Actor.take).
	## Unclaimed, it flies to the player's hands by itself (Interactable._collect).
	var t := _taken
	_taken = null
	if t and is_instance_valid(t) and not t.is_queued_for_deletion() and not t.has_meta("claimed"):
		t.set_meta("claimed", true)
		return t
	return null


func _radio_fx(pos: Vector3) -> Node3D:
	## Static crackle + flicker on a radio while it's being tuned; free it after.
	var fx := Interactable.ItemFx.item("radio")
	add_child(fx)
	fx.global_position = pos
	return fx


func _reach(p: Vector3, radius: float) -> void:
	## Coroutine: waits until the player is within radius of p (XZ).
	while Vector2(player.global_position.x - p.x, player.global_position.z - p.z).length() > radius:
		await get_tree().physics_frame


var _objective_text := ""
var _objective_target: Variant = null
var _cam_tw: Tween


func cinematic(on: bool) -> void:
	## Takes the camera and the controls away from the player (and gives them back).
	player.controls_enabled = not on
	_track = null
	_sway = 0.0
	cam.fov = 60.0  # a telephoto / wide shot never leaks into the next scene
	cam.h_offset = 0.0
	cam.v_offset = 0.0
	hud.letterbox(on)
	if on != _cin_music:  # the score follows the camera: a melancholy theme under every cinematic
		_cin_music = on
		if on:
			Snd.push_music("melancholy", 2.0)
		else:
			Snd.pop_music(2.5)
	if on:
		player.velocity = Vector3.ZERO
		cam.current = true
		hud.objective("")
	else:
		if _cam_tw:
			_cam_tw.kill()
		player.camera.current = true
		hud.objective(_objective_text, _objective_target)


func objective(text: String, target: Variant = null) -> void:
	## Objective line + where the guide (minimap / compass / marker) points: Vector3, Node3D or null.
	_objective_text = text
	_objective_target = target
	hud.objective(text, target)


func shot(from: Vector3, look: Vector3, to := Vector3.INF, time := 6.0, fov := 0.0, sway := 0.012) -> void:
	## Cuts the cinematic camera to `from` looking at `look`; optionally dollies to `to` over `time`
	## seconds (eased in and out, not awaited). `fov` > 0 sets the lens (a close-up ~40, an establishing wide ~72;
	## cinematic() puts it back to 60), `sway` is the handheld wobble in metres (0 = locked off, 0.03 = tension).
	## Cancels any previous move or track. Close shots are staged around wherever the
	## player happens to stand, so if a wall, door or shelf gets between the lens and the subject the camera
	## swings round the subject to the nearest clear angle (_frame).
	_track = null
	_sway = sway
	if _cam_tw:
		_cam_tw.kill()
	if fov > 0.0:
		cam.fov = fov
	var swing := _frame(from, look)
	from = _swung(from, look, swing)
	if to != Vector3.INF:
		to = _swung(to, look, swing)
		if not _lens_clear(look, to):
			to = Vector3.INF
	cam.global_position = from
	cam.look_at(look)
	if to != Vector3.INF:
		_cam_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_cam_tw.tween_method(func(t: float) -> void:
			cam.global_position = from.lerp(to, t)
			cam.look_at(look), 0.0, 1.0, time)


func track(node: Node3D, offset: Vector3, look_offset := Vector3(0, 1.5, 0)) -> void:
	## Camera follows `node` from node.position + offset (world axes), looking at node + look_offset.
	if _cam_tw:
		_cam_tw.kill()
	_track = node
	_track_offset = offset
	_track_look = look_offset


func ots(speaker: Node3D, listener: Node3D, side := 1.0, push := 0.3) -> void:
	## Over-the-shoulder cut for dialogue: camera behind and above `listener`'s shoulder, framing `speaker`
	## through a 42 degree lens (so the foreground head stays a sliver, not half the frame). `push` (metres, default a slow 0.3) is the
	## creep toward the speaker over the line; 0 holds still.
	var a := listener.global_position + Vector3.UP * 1.6
	var b := speaker.global_position + Vector3.UP * 1.55
	var back := (a - b).normalized()
	var right := back.cross(Vector3.UP).normalized()
	var from := a + back * 1.4 + right * 0.55 * side + Vector3.UP * 0.25
	shot(from, b, from - back * push if push > 0.0 else Vector3.INF, 4.0, 42.0)


func wait(sec: float) -> Signal:
	return get_tree().create_timer(sec).timeout


func actor(scene: String, pos: Vector3, yaw := 0.0) -> Actor:
	return Actor.make(self, scene, pos, yaw)


func stand_in(pos: Vector3, yaw: float) -> Actor:
	## Hides the player and puts an Alex actor at pos for staging. release_stand_in() hands control
	## back with the player standing where the stand-in ended.
	release_stand_in()
	_stand_from = player.global_position
	player.model.visible = false
	var from := _stand_from if pos.distance_to(_stand_from) < 12.0 else Vector3.INF
	_stand_in = actor("res://models/char_alex.glb", spot(pos, from), yaw)
	return _stand_in


func release_stand_in() -> void:
	if not _stand_in:
		return
	var hp: float = player.health
	var st: float = player.stamina
	var end := _stand_in.global_position
	var at := spot(end, _stand_from if _stand_from.distance_to(end) < 12.0 else Vector3.INF)  # never inside a wall
	player.respawn(at + Vector3.UP * 0.05, _stand_in.model.rotation.y)
	player.health = hp  # a cutscene isn't a free heal
	player.stamina = st
	player.model.visible = true
	_stand_in.queue_free()
	_stand_in = null


func _process(delta: float) -> void:
	if cam and cam.current and _sway > 0.0:  # handheld: slow two-frequency drift of the frustum, never touches the aim
		_sway_t += delta
		cam.h_offset = _sway * (sin(_sway_t * 1.3) + 0.5 * sin(_sway_t * 3.1 + 1.0))
		cam.v_offset = _sway * 0.7 * (sin(_sway_t * 1.7 + 2.0) + 0.5 * sin(_sway_t * 2.3))
	if _track and is_instance_valid(_track):
		var look := _track.global_position + _track_look
		var goal := _track.global_position + _track_offset
		if not _lens_clear(look, goal):
			goal = _swung(goal, look, INF)
		cam.global_position = cam.global_position.lerp(goal, 0.08)
		cam.look_at(look)


# ------------------------------------------------------------------ mood + lighting

const MOODS := {  ## Environment + moon look per scene; "night" is whatever hollowmere.tscn authored (captured once)
	"overcast": {"background_color": Color(0.46, 0.5, 0.54), "ambient_light_color": Color(0.6, 0.66, 0.72),
		"ambient_light_energy": 1.0, "fog_light_color": Color(0.5, 0.56, 0.6), "fog_density": 0.014,
		"volumetric_fog_density": 0.01, "moon_color": Color(0.9, 0.9, 0.85), "moon_energy": 0.5},
	"interior": {"ambient_light_energy": 0.45, "fog_density": 0.008, "volumetric_fog_density": 0.006},
	"dim": {"ambient_light_energy": 0.3, "moon_energy": 0.08},
}
var _night := {}


func mood(name: String, time := 2.0) -> void:
	## Tweens the world's look: "night" (default), "overcast" (the day scenes: 09:00 / 15:00 must not look like
	## midnight), "interior", "dim" (a blackout). Not awaited.
	var env: Environment = get_parent().get_node("WorldEnvironment").environment
	var moon: DirectionalLight3D = get_parent().get_node("Moon")
	if _night.is_empty():
		for k in ["background_color", "ambient_light_color", "ambient_light_energy", "fog_light_color", "fog_density",
				"volumetric_fog_density"]:
			_night[k] = env.get(k)
		_night["moon_color"] = moon.light_color
		_night["moon_energy"] = moon.light_energy
	var look: Dictionary = _night.duplicate()
	look.merge(MOODS.get(name, {}), true)
	var tw := create_tween().set_parallel()
	for k in look:
		if k.begins_with("moon"):
			tw.tween_property(moon, "light_" + k.trim_prefix("moon_"), look[k], time)
		else:
			tw.tween_property(env, k, look[k], time)


func key_light(pos: Vector3, color: Color, energy: float, range_m: float, look := Vector3.INF, angle := 55.0, fade := 1.5) -> Light3D:
	## A set light that fades in (a SpotLight3D aimed at `look`, or an OmniLight3D without it). It stays: arenas
	## stay lit through the fight.
	var l: Light3D
	if look != Vector3.INF:
		var sp := SpotLight3D.new()
		sp.spot_range = range_m
		sp.spot_angle = angle
		l = sp
	else:
		var om := OmniLight3D.new()
		om.omni_range = range_m
		l = om
	l.light_color = color
	l.light_energy = 0.0
	add_child(l)
	l.global_position = pos
	if look != Vector3.INF:
		l.look_at(look, Vector3.RIGHT if absf((look - pos).normalized().y) > 0.99 else Vector3.UP)  # straight down is fine too
	create_tween().tween_property(l, "light_energy", energy, fade)
	return l


# ------------------------------------------------------------------ staging kept physical

func _solid(a: Vector3, b: Vector3) -> Dictionary:
	## First world (layer 1) hit from a to b; the player doesn't count.
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, 1, [player.get_rid()]))


func _lens_clear(look: Vector3, p: Vector3) -> bool:
	## Nothing solid between a subject and a lens at p, nor just behind the lens (the near plane).
	var d := p - look
	if d.length() < 0.05:
		return true
	var n := d.normalized()
	return _solid(look + n * minf(0.15, d.length() * 0.5), p + n * 0.2).is_empty()


func _frame(from: Vector3, look: Vector3) -> float:
	## Yaw to swing a close shot round its subject so nothing blocks it: 0 = as authored, INF = no clear angle
	## (pull the lens in instead). Wide establishing shots are authored clear and left alone.
	if from.distance_to(look) > CLOSE_SHOT:
		return 0.0
	for a in [0.0, 0.5, -0.5, 1.0, -1.0, 1.6, -1.6, 2.3, -2.3, PI]:
		if _lens_clear(look, look + (from - look).rotated(Vector3.UP, a)):
			return a
	return INF


func _swung(p: Vector3, look: Vector3, a: float) -> Vector3:
	if a != INF:
		return look + (p - look).rotated(Vector3.UP, a)
	var hit := _solid(look, p)
	return look.lerp(hit.position, 0.8) if hit else p


func _stand(p: Vector3) -> Vector3:
	## p dropped onto the ground under it if a standing person fits there (no wall, prop or ceiling), else INF.
	var down := _solid(p + Vector3.UP * 0.6, p + Vector3.DOWN * 1.5)
	var g: Vector3 = down.position if down else p
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.6
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), g + Vector3.UP * 0.92)
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	if not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
		return Vector3.INF
	# walls are one-sided: from just behind one the capsule doesn't touch it, so look in at p from around it
	for h in [0.4, 1.3]:
		for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			if _solid(g + Vector3.UP * h + dir * 0.3, g + Vector3.UP * h):
				return Vector3.INF
	return g


func spot(want: Vector3, from := Vector3.INF) -> Vector3:
	## Somewhere a person can stand at `want`, or the nearest such place within ~2 m that can see `from` (the
	## player's side of any wall). Falls back to `from`, else `want`.
	var g := _stand(want)
	if g != Vector3.INF:
		return g
	for r in [0.35, 0.7, 1.1, 1.6, 2.2]:
		for i in 10:
			g = _stand(want + Vector3(r, 0, 0).rotated(Vector3.UP, TAU * i / 10.0))
			if g != Vector3.INF and (from == Vector3.INF or _solid(from + Vector3.UP * 1.2, g + Vector3.UP * 1.2).is_empty()):
				return g
	return from if from != Vector3.INF else want


func clear_walk(from: Vector3, to: Vector3) -> Vector3:
	## `to`, or where a straight walk from `from` would first meet a wall or prop (stopping just short of it):
	## scripted walks are tweens that ignore collisions.
	var best := to
	for h in [0.4, 1.2]:
		var hit := _solid(from + Vector3.UP * h, Vector3(to.x, from.y + h, to.z))
		if hit:
			var p: Vector3 = hit.position - (Vector3(to.x, from.y, to.z) - from).normalized() * 0.45
			p.y = to.y
			if from.distance_to(p) < from.distance_to(best):
				best = p
	return best


func near(target: Vector3, dist: float) -> Vector3:
	## Where Alex stands to face something `dist` away: on the player's side of it, on open ground, with a clear
	## line to it and to where the player is (never through a wall). Falls back to the player's own spot.
	var p := player.global_position
	var flat := Vector2(p.x - target.x, p.z - target.z)
	var base := atan2(flat.x, flat.y) if flat.length() > 0.3 else 0.0
	for a in [0.0, 0.4, -0.4, 0.8, -0.8, 1.3, -1.3, 1.9, -1.9, 2.6, -2.6, PI]:
		var g := _stand(Vector3(target.x + sin(base + a) * dist, p.y, target.z + cos(base + a) * dist))
		if g == Vector3.INF:
			continue
		var eye := g + Vector3.UP * 1.3
		if _solid(eye, Vector3(target.x, eye.y, target.z)).is_empty() and _solid(p + Vector3.UP * 1.3, eye).is_empty():
			return g
	return p


func _spawn_marked(pos: Vector3, i: int, patrol: Array[Vector3] = []) -> Enemy:
	var e := Enemy.spawn(self, MARKED[i % 2], pos, randf() * TAU,
			{"display_name": "Marked One", "max_health": 60.0, "run_speed": 3.3, "melee_damage": 12.0})
	if patrol.size() > 0:
		e.patrol = patrol
	e.drop = _drop_loot
	return e


func clear_enemies() -> void:
	## Frees every living enemy: a finished mission's leftovers must not hunt the player into the next one.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()


func _drop_loot(at: Vector3) -> void:
	var roll := randf()
	var owned: Array[String] = player.weapons.owned
	if roll < 0.4 and roll >= 0.25 and ("bow" in owned or "shotgun" in owned):  # the others need feeding too
		var id := "shotgun" if "shotgun" in owned and (not "bow" in owned or randf() < 0.5) else "bow"
		var n := maxi(int(round((6 if id == "shotgun" else 5) * G.settings().ammo)), 2)
		Interactable.make(self, at + Vector3.UP * 0.3, "Shells" if id == "shotgun" else "Arrows", func(_b: Node) -> void:
			player.weapons.give(id, n)
			hud.banner("+%d %s" % [n, "SHELLS" if id == "shotgun" else "ARROWS"], Weapons.GUNS[id].color, 0.6),
			Weapons.GUNS[id].color, true, "shells" if id == "shotgun" else "arrow")
		return
	if roll < 0.25 and "flare" in player.weapons.owned:  # the second gun needs its own rounds too
		Interactable.make(self, at + Vector3.UP * 0.3, "Flares", func(_b: Node) -> void:
			player.weapons.give("flare", 3)
			hud.banner("+3 FLARES", Color(1.0, 0.45, 0.3), 0.6), Color(1.0, 0.35, 0.2), true, "flares")
		return
	var ammo := roll < 0.65
	var rounds := maxi(int(round(12 * G.settings().ammo)), 4)
	var take := func(_b: Node) -> void:
		if ammo:
			player.weapons.give("revolver", rounds)
			hud.banner("+%d ROUNDS" % rounds, Color(0.9, 0.85, 0.6), 0.6)
		else:
			player.heal(25)
			hud.banner("+25 HEALTH", Color(0.8, 0.3, 0.3), 0.6)
	Interactable.make(self, at + Vector3.UP * 0.3, "Ammo" if ammo else "Bandage", take,
		Color(0.9, 0.8, 0.4) if ammo else Color(0.9, 0.3, 0.3), true, "ammo_box" if ammo else "bandage")


# ------------------------------------------------------------------ C1.1 + C1.2

func _step_intro() -> void:
	await scenes_a.intro()  # ends with the player in room 6 (ROOM6, facing the door) in control


# ------------------------------------------------------------------ M1 Room 6

const DOOR_SPOT := Vector3(-97.2, 1.1, 49.0)
const NOTE_SPOT := Vector3(-97.4, 0.25, 49.6)
const RADIO_SPOT := Vector3(-98.5, 0.9, 50.8)


func _step_room() -> void:
	_checkpoint_at(ROOM6, PI / 2.0)
	hud.show_zone("Lakeview Motel — Room 6")
	await scenes_a.room_wake()
	objective("Check the door", DOOR_SPOT)
	await _use(DOOR_SPOT, "Examine the door")
	await scenes_a.room_door()
	objective("Read the note", NOTE_SPOT)
	await _use(NOTE_SPOT, "Read the note", Color(1.0, 0.9, 0.5))
	await scenes_a.room_note()
	objective("Tune the radio to channel 7", RADIO_SPOT)
	await _use(RADIO_SPOT, "Use the radio", Color(0.5, 1.0, 0.6), "radio")
	player.controls_enabled = false
	var crackle := _radio_fx(RADIO_SPOT)
	var radio := RadioTuning.play(hud, 0.62)
	await radio.done
	crackle.queue_free()
	player.controls_enabled = true
	await scenes_a.room_radio_call()


# ------------------------------------------------------------------ M2 First hunt

const SQUARE := Vector3(0, 0, 24)


func _step_hunt() -> void:
	_checkpoint_at(ROOM6_DOOR + Vector3(2.5, 0, 0.5), PI / 2.0)
	var home := Vector3(-86, 0, 72)
	_owen = Enemy.spawn(self, "res://models/char_owen.glb", home, PI, {
		"display_name": "Owen", "invulnerable": true, "bow": true, "give_up_x": -28.0, "run_speed": 4.4,
		"walk_speed": 1.8, "melee_damage": 20.0, "mark_gain": Feel.MARK_GAIN.owen_hunt, "sight_range": 24.0, "windup": 0.6})
	_owen.patrol = [Vector3(-86, 0, 70), Vector3(-86, 0, 52), Vector3(-70, 0, 60), Vector3(-50, 0, 60),
		Vector3(-70, 0, 60)]
	_owen.struck_player.connect(func(_e: Enemy) -> void:
		scenes_a.hunt_caught(_owen)
		_owen.lose_track(player.global_position + Vector3(randf_range(-18, 18), 0, randf_range(12, 18))))
	_on_reset = func() -> void: _owen.reset_to(home)
	await scenes_a.hunt_start(_owen)
	objective("Reach the town square — crouch (C) in tall grass to hide", SQUARE)
	var t := 6.0
	while Vector2(player.global_position.x, player.global_position.z).length() > 38.0:
		await get_tree().physics_frame
		player.health = maxf(player.health, _owen.melee_damage + 1.0)  # being caught never kills (M2)
		t -= get_physics_process_delta_time()
		if t <= 0.0 and _owen.global_position.distance_to(player.global_position) < 30.0:
			t = randf_range(9.0, 14.0)
			scenes_a.hunt_bark(_owen)
	_owen.queue_free()
	_owen = null
	_on_reset = Callable()
	await scenes_a.hunt_end()


# ------------------------------------------------------------------ M3 The square

const GRADY_SPOT := Vector3(14, 1.2, -17.2)


func _step_square() -> void:
	_checkpoint_at(Vector3(0, 0.1, 30), PI)
	hud.show_zone("Town Square")
	objective("Talk to Grady at the General Store", _grady)
	await _use(GRADY_SPOT, "Talk to Grady")
	await scenes_b.grady_talk(_grady)  # hands over the guns (calls arm_player) and returns control
	arm_player()
	await scenes_b.guns_tutorial()
	# optional practice: tin moths on a festival stall
	objective("Optional: knock down the 5 tin moths · Talk to Grady when ready", _grady)
	var left := [5]
	for i in 5:
		var tgt := Target.new()
		tgt.collision_layer = 2
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.35, 0.35, 0.08)
		col.shape = box
		tgt.add_child(col)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = box.size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.68, 0.6)
		mat.metallic = 0.6
		bm.material = mat
		mi.mesh = bm
		tgt.add_child(mi)
		add_child(tgt)
		tgt.global_position = Vector3(-4.0 + i * 2.0, 1.4 + 0.3 * (i % 2), -10.0)
		tgt.down.connect(func() -> void:
			left[0] -= 1
			if left[0] == 0:
				flags.tokens += 25
				hud.banner("+25 TOKENS", Color(0.9, 0.8, 0.4), 1.0))
	await _use(GRADY_SPOT, "Tell Grady you're ready")
	await scenes_b.moth_sawmill_call(_grady)


# ------------------------------------------------------------------ M4 The Woodsman (part 1)

const SAWMILL_ROAD := Vector3(-100, 0, 0)
const KEY_SPOT := Vector3(-121.0, 1.0, -2.0)


func _step_sawmill() -> void:
	_checkpoint_at(Vector3(-34, 0.1, 0), -PI / 2.0)
	objective("Go west to the sawmill and find Owen's key part", SAWMILL_ROAD)
	var spots: Array[Vector3] = [Vector3(-55, 0, 4), Vector3(-66, 0, -5), Vector3(-82, 0, 3),
		Vector3(-96, 0, -6), Vector3(-106, 0, 5), Vector3(-108, 0, -10)]
	var marked: Array[Enemy] = []
	for i in spots.size():
		var p := spots[i]
		marked.append(_spawn_marked(p, i, [p, p + Vector3(randf_range(-6, 6), 0, randf_range(-5, 5))]))
	for p in [Vector3(-112, 0, -9), Vector3(-110, 0, 6), Vector3(-117, 0, 9), Vector3(-104, 0, -2)]:
		FuelBarrel.make(self, p)
	# optional: the parents' lantern (spare condition) and evidence #1
	var lantern := func(_b: Node) -> void:
		flags.lantern = true
		scenes_b.lantern_found()
	Interactable.make(self, Vector3(-117.5, 1.2, -15.5), "Take the burnt festival lantern", lantern, Color(1.0, 0.6, 0.2))
	if "axe" not in player.weapons.owned:  # optional: a fire axe left in the yard
		weapon_pickup(Vector3(-114, 0.4, 2.5), "axe", 0, 0.6)
	var ledger := func(_b: Node) -> void:
		if 1 not in flags.evidence:  # a reload replays the step: never count it twice
			flags.evidence.append(1)
		scenes_b.ledger_read()
	Interactable.make(self, Vector3(-123.5, 1.0, 4.0), "Read the ledger", ledger, Color(0.7, 0.8, 1.0), false,
		"ledger")
	_on_reset = func() -> void:
		for e in marked:
			if is_instance_valid(e) and e.state != Enemy.State.DEAD:
				e.reset_to(e.patrol[0])
	await scenes_b.sawmill_road()
	await _reach(SAWMILL_ROAD, 12.0)
	hud.show_zone("Pinewood Forest & Sawmill")
	_checkpoint_at(Vector3(-100, 0.1, 0), -PI / 2.0)
	objective("Find the key part in the sawmill yard", KEY_SPOT)
	await _use(KEY_SPOT, "Take the key part", Color(0.6, 0.9, 1.0), "key_part")
	flags.key_part = true
	clear_enemies()  # the yard's Marked Ones: not in the key close-up, not in the boss fight
	await scenes_b.key_found()


# ------------------------------------------------------------------ M4 boss: Owen

func _step_boss() -> void:
	arm_player()
	clear_enemies()  # the sawmill's Marked Ones: Owen fights alone (boss_intro cuts away this frame)
	_checkpoint_at(Vector3(-104, 0.1, -2), -PI / 2.0)
	var spawn := Vector3(-130, 0, -5)
	_owen = Enemy.spawn(self, "res://models/char_owen.glb", spawn, PI / 2.0, {
		"display_name": "Owen", "boss": true, "max_health": 420.0, "ranged": true, "run_speed": 4.0,
		"walk_speed": 2.0, "melee_damage": 26.0, "mark_gain": Feel.MARK_GAIN.owen, "sight_range": 45.0, "fov_deg": 300.0,
		"flare_stun": 6.0, "arrow_interval": 2.4, "arrow_damage": 11.0, "windup": 0.6})
	_owen.patrol = [SAWMILL_YARD]
	for p in [Vector3(-106, 0.3, 5), Vector3(-107, 0.3, -9)]:
		_drop_loot(p)
	await scenes_b.boss_intro(_owen)
	var title := "OWEN CLARKE — THE WOODSMAN"
	hud.boss_bar(title, 1.0)
	var phase := [1]
	_owen.damaged.connect(func(e: Enemy) -> void:
		hud.boss_bar(title, e.health / e.max_health)
		if phase[0] == 1 and e.health < e.max_health * 0.5:
			phase[0] = 2
			e.ranged = false
			e.run_speed = 4.7
			e.windup = 0.5
			scenes_b.boss_phase2(e))
	_on_reset = func() -> void:
		phase[0] = 1
		_owen.ranged = true
		_owen.run_speed = 4.0
		_owen.windup = 0.6
		_owen.reset_to(spawn)
		hud.boss_bar(title, 1.0)
	objective("Survive Owen — flares and burning barrels freeze him (fire)", _owen)
	await _owen.downed
	hud.boss_bar("", -1.0)
	_on_reset = Callable()
	await scenes_b.boss_down(_owen)
	objective("SPARE him (E) — or shoot to KILL", _owen)
	var choice := [""]
	var spare := Interactable.make(self, _owen.global_position + Vector3.UP * 1.0, "Spare Owen",
		func(_b: Node) -> void: choice[0] = "spared")
	_owen.died.connect(func(_e: Enemy) -> void: choice[0] = "killed")
	while choice[0] == "":
		await get_tree().physics_frame
	spare.queue_free()
	flags.owen = choice[0]
	objective("")
	var bow_at := _owen.global_position + Vector3(1.2, 0.4, 0.4)
	if choice[0] == "spared":
		await scenes_b.owen_spared(_owen, flags.lantern)
		_owen.queue_free()  # he walked off into the sawmill: no hidden, frozen boss left in "enemies"
		_owen = null
	else:
		await scenes_b.owen_killed(_owen)
	if "bow" not in player.weapons.owned:  # his bow stays in the yard
		weapon_pickup(spot(bow_at, player.global_position) + Vector3.UP * 0.4, "bow", 10, 1.2)


# ------------------------------------------------------------------ side missions: Room 4 (#11), Tripwire (#2)

const ROOM4_DOOR := Vector3(-96.4, 1.1, 59.0)  ## Lucía's old room, two doors up from room 6 (the Veil's eye on it)
const ROOM4_CAMERA := Vector3(-96.0, 0.3, 59.0)  ## her camera, hung on the inside handle: it lands on the mat
## Owen's early warning on the forest trail south of the sawmill road, toward the cabins (chapters.md §3)
const TRIP_BELLS: Array[Vector3] = [Vector3(-87, 0, -12), Vector3(-91, 0, -22), Vector3(-93, 0, -31)]
const TRIP_REACH := 3.0  ## walking upright this close to a wire rings its bell (crouched never does)
const TRIP_TOKENS := 10
var _side_ready := false


func side_missions() -> void:
	## Chapter 1's optional missions, started once the player is out of room 6 and on any later start (a dev skip,
	## a loaded save) so 12/12 evidence stays reachable in Chapters 2-3. They rebuild from the flags: a finished
	## one doesn't come back, a picked lock stays open, cut wires stay cut, a rung bell stays rung.
	if _side_ready:
		return
	_side_ready = true
	if not flags.has("room4_open"):  # (saves from before these missions existed)
		flags["room4_open"] = false
	if not flags.has("trip_cut"):
		flags["trip_cut"] = []
	if not flags.has("trip_rang"):
		flags["trip_rang"] = false
	if 11 not in flags.evidence:
		_room4()
	if 2 not in flags.evidence:
		_tripwire()


func _room4() -> void:
	## Room 4: pick the lock (1 pin), then take Lucía's camera (evidence #11).
	if not flags.room4_open:
		_hint_near(ROOM4_DOOR, 4.0, scenes_a.room4_hint)
		while true:
			await _use(ROOM4_DOOR, "Pick the lock — Room 4", Color(0.7, 0.9, 1.0))
			player.controls_enabled = false
			var ok: bool = await Lockpick.play(hud, 1).done
			player.controls_enabled = true
			if ok:
				break
			player.noise(3.0)
			hud.banner("THE PICK SLIPPED", Color(1.0, 0.5, 0.4), 1.0)
		flags.room4_open = true
		scenes_a.room4_opened()
	await _use(ROOM4_CAMERA, "Take Lucía's camera", Color(0.95, 0.85, 0.6), "photo")
	if 11 not in flags.evidence:
		flags.evidence.append(11)
	scenes_a.room4_camera()


func _tripwire() -> void:
	## Tripwire: three bells strung across the trail (MusicBox noise traps). Cut every wire (E); walking past one
	## upright rings it and calls whatever is in earshot. Evidence #2 lies under the last one; the 10 tokens only
	## if none of them rang.
	var dir := (TRIP_BELLS[-1] - TRIP_BELLS[0]).normalized()
	for i in TRIP_BELLS.size():
		if i in flags.trip_cut:
			continue
		var bell := MusicBox.make(self, TRIP_BELLS[i], _trip_bell(atan2(dir.x, dir.z)), "Cut the tripwire")
		bell.reach = TRIP_REACH
		bell.sound = "bell"
		bell.pitch = 2.2  # a hand bell on a wire, not the church
		bell.chimed.connect(func() -> void:
			if not flags.trip_rang:
				flags.trip_rang = true
				scenes_b.tripwire_rang())
		bell.silenced.connect(_trip_cut.bind(i))
	if flags.trip_cut.is_empty():
		_hint_near(TRIP_BELLS[0], 14.0, scenes_b.tripwire_hint)


func _trip_cut(i: int) -> void:
	if i not in flags.trip_cut:
		flags.trip_cut.append(i)
	var left: int = TRIP_BELLS.size() - flags.trip_cut.size()
	if left > 0:
		scenes_b.tripwire_cut(left)
		return
	if 2 not in flags.evidence:
		flags.evidence.append(2)
	var clean: bool = not flags.trip_rang
	if clean:
		flags.tokens += TRIP_TOKENS
	scenes_b.tripwire_done(clean, TRIP_TOKENS)


func _trip_bell(yaw: float) -> Node3D:
	## Placeholder look (no model yet): a wire between two stakes across the trail, a small brass bell hanging
	## from its middle (the MusicBox origin: where it rings from and where E cuts it).
	var root := Node3D.new()
	root.rotation.y = yaw  # local +Z along the trail, so the wire (local X) runs across it
	var brass := _flat(Color(0.75, 0.6, 0.25), 0.7)
	var wood := _flat(Color(0.3, 0.22, 0.14))
	var wire := _flat(Color(0.55, 0.55, 0.5), 0.8)
	for side in [-1.6, 1.6]:
		_mesh(root, BoxMesh.new(), Vector3(0.04, 0.45, 0.04), Vector3(side, 0.22, 0), wood)
	_mesh(root, BoxMesh.new(), Vector3(3.2, 0.008, 0.008), Vector3(0, 0.32, 0), wire)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.025
	cone.bottom_radius = 0.06
	cone.height = 0.09
	cone.radial_segments = 8
	_mesh(root, cone, Vector3.ONE, Vector3(0, 0.25, 0), brass)
	return root


func _flat(c: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	return m


func _mesh(parent: Node3D, mesh: PrimitiveMesh, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		mesh.size = size
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	parent.add_child(mi)
	return mi


func _hint_near(p: Vector3, radius: float, say: Callable) -> void:
	## Fire-and-forget: the first time the player walks up to p in control, one bark.
	await _reach(p, radius)
	while not player.controls_enabled:
		await get_tree().physics_frame
	say.call()


# ------------------------------------------------------------------ C1.3 Blackout

func _step_blackout() -> void:
	await scenes_b.blackout()


func lights_out(from := Vector3.ZERO, speed := 45.0, radius := INF) -> void:
	## Every light within `radius` (XZ) of `from` dies, spreading outward at `speed` m/s (not awaited).
	for l in get_parent().find_children("*", "OmniLight3D", true, false):
		if l.get_parent() is Enemy:
			continue  # eyes / glows on enemies aren't on the town grid
		var dist := Vector2(l.global_position.x - from.x, l.global_position.z - from.z).length()
		if dist > radius:
			continue
		var delay := dist / speed
		var tw := l.create_tween()
		tw.tween_interval(delay)
		tw.tween_callback(func() -> void: l.set_script(null))  # stop flicker.gd driving the energy
		tw.tween_property(l, "light_energy", 0.0, 0.15)
