extends SceneTree
## Headless check of the game-feel pass (scripts/feel.gd):
##   detection: far away the awareness meter fills over time ("?"), up close or with the flashlight almost at once,
##   full → CHASE and a "!" that goes away after ICON_ALERT_HOLD; hear() still only makes it suspicious;
##   the Harvester knows at once and never shows "?"
##   hitstop freezes an enemy's pose and lets go; Feel.hitstop = 0 turns it off
##   camera trauma shakes the frustum (never the aim) and dies out; Feel.shake = 0 turns it off
##   the Mark: the Post shader's effect uniforms are all 0 at 0 % (the plain look), the vignette at 50 %; at 100 %
##   only a faint base split / wobble (<= 25 % of the first pass); spikes flare and fade, held down in a fight;
##   near a boss a faint steady ambience (eased, thinning out past the near ring), a fight never past COMBAT_MAX_*;
##   whispers past 25 %; a hit reddens the edges, then they fade
##   apparitions: the Harvester 20-40 m off, no collision, gone when looked at or after a moment; off with the switch
##   the Mark's growth: the soft cap (Feel.add_mark), Player.marked; the HUD's "MARK +N%" notice (merging, fading,
##   the creep gathered), no Veil's Eye; the exact Mark in the pause menu
##   Dev: Game.dev_evidence starts a run with all 12 pieces, Game.dev_mark with the Mark set (`-- --mark=N`)
## godot --headless --path . -s tests/feel_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("FEEL FAIL: " + msg)
	quit(1)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _secs(t: float) -> void:
	await _frames(int(t * 60.0))


func _icon(e: Enemy) -> AlertIcon:
	for c in e.get_children():
		if c is AlertIcon:
			return c
	return null


func _param(mat: ShaderMaterial, n: String) -> float:
	var v: Variant = mat.get_shader_parameter(n)
	return float(v) if v != null else 0.0


func _run() -> void:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	world.get_node("Chapter1").start_step = "free"
	root.add_child(world)
	await _frames(60)
	var player: CharacterBody3D = world.get_node("Player")
	var post: ShaderMaterial = player.hud.get_node("Post").material
	# the sawmill road: open, flat, nothing between x -60 and -40
	var spot := Vector3(-40, 0.1, 0)
	player.global_position = spot
	player.flashlight.visible = false
	await _frames(10)

	# --- far: the meter fills over time, "?" while it does, then CHASE and "!"
	var at := Vector3(-55, 0, 0)
	var e := Enemy.spawn(world, "res://models/char_marked_man.glb", at, PI / 2.0, {"sight_range": 20.0})
	e.patrol = [at]
	await _frames(3)
	if not e.can_see_player():
		return _fail("setup: the enemy can't see down the road")
	await _secs(0.5)
	if e.state == Enemy.State.CHASE or e.awareness <= 0.0 or e.awareness >= 1.0:
		return _fail("far: noticed at once (state %d, awareness %.2f)" % [e.state, e.awareness])
	if _icon(e)._shown != "?":
		return _fail("far: icon '%s' while noticing" % _icon(e)._shown)
	var t := 0.5
	while e.state != Enemy.State.CHASE and t < Feel.AWARE_TIME_FAR + 2.0:
		await physics_frame
		t += 1.0 / 60.0
	if e.state != Enemy.State.CHASE:
		return _fail("far: never spotted (awareness %.2f)" % e.awareness)
	await _frames(2)
	if _icon(e)._shown != "!":
		return _fail("spotted: icon '%s'" % _icon(e)._shown)
	print("far: spotted after %.2f s" % t)
	# the flashlight: almost at once from the same distance
	e.reset_to(at)
	player.global_position = spot
	player.flashlight.visible = true
	t = 0.0
	while e.state != Enemy.State.CHASE and t < 2.0:
		await physics_frame
		t += 1.0 / 60.0
	player.flashlight.visible = false
	if t >= 1.2:
		return _fail("flashlight: took %.2f s" % t)
	print("flashlight: spotted after %.2f s" % t)
	e.reset_to(at)
	await _frames(2)
	# hear(): suspicious, the meter untouched
	player.global_position = at + Vector3(0, 0.1, 30)  # out of its sight
	await _frames(15)
	e.awareness = 0.0
	e.hear(at + Vector3(2, 0, 0), 10.0)
	if e.state != Enemy.State.SUSPICIOUS or e.awareness != 0.0:
		return _fail("hear: state %d awareness %.2f" % [e.state, e.awareness])
	await _frames(3)
	if _icon(e)._shown != "?":
		return _fail("hear: icon '%s'" % _icon(e)._shown)
	e.queue_free()
	await _frames(2)

	# --- near: at once
	player.global_position = spot
	var n := Enemy.spawn(world, "res://models/char_marked_woman.glb", spot + Vector3(-2.5, -0.1, 0), PI / 2.0)
	n.patrol = [n.position]
	t = 0.0
	while n.state != Enemy.State.CHASE and t < 1.0:
		await physics_frame
		t += 1.0 / 60.0
	if t > Enemy.SENSE_STEP + 0.1:
		return _fail("near: took %.2f s" % t)
	# the "!" stays a while, then goes
	await _secs(Feel.ICON_ALERT_HOLD + 0.3)
	if _icon(n)._shown != "":
		return _fail("'!' still up after the hold: '%s'" % _icon(n)._shown)

	# --- hitstop: the pose freezes, then lets go; off when Feel.hitstop = 0
	n.hitstop(0.08)
	if n._anim.is_processing() or n._freeze <= 0.0:
		return _fail("hitstop didn't freeze")
	await _secs(0.2)
	if not n._anim.is_processing() or n._freeze > 0.0:
		return _fail("hitstop didn't let go")
	Feel.hitstop = 0.0
	n.hitstop(0.08)
	Feel.hitstop = 1.0
	if n._freeze > 0.0:
		return _fail("hitstop with Feel.hitstop = 0")
	n.queue_free()
	await _frames(2)

	# --- the Harvester: knows at once, never "?"
	var h := Harvester.spawn_at(world, Vector3(-58, 0, 0), PI / 2.0)
	h.patrol = [h.position]
	t = 0.0
	var asked := false
	while h.state != Enemy.State.CHASE and t < 1.0:
		await physics_frame
		t += 1.0 / 60.0
		asked = asked or _icon(h)._shown == "?"
	if t > Enemy.SENSE_STEP + 0.1 or asked:
		return _fail("harvester: %.2f s to notice, showed '?' %s" % [t, asked])
	h.queue_free()
	await _frames(2)

	# --- trauma: the frustum shakes (the camera itself doesn't move), then settles; off at Feel.shake = 0
	var cam_at: Vector3 = player.camera.global_position
	player.add_trauma(0.8)
	await _frames(3)
	if absf(player.camera.h_offset) + absf(player.camera.v_offset) < 0.001:
		return _fail("trauma: no shake")
	await _secs(1.0)
	if player.trauma > 0.0 or absf(player.camera.h_offset) > 0.0001:
		return _fail("trauma didn't die out: %.2f" % player.trauma)
	Feel.shake = 0.0
	player.add_trauma(0.8)
	await _frames(3)
	Feel.shake = 1.0
	if absf(player.camera.h_offset) > 0.0001:
		return _fail("shake with Feel.shake = 0")
	player.trauma = 0.0
	if player.camera.global_position.distance_to(cam_at) > 0.5:
		return _fail("the shake moved the camera (the aim)")

	# --- the Mark on the screen: plain at 0, vignette at 50, split + warp at 90
	var fx: ScreenFx = null
	for c in player.hud.find_children("*", "Control", true, false):
		if c is ScreenFx:
			fx = c
	player.mark = 0.0
	await _secs(Feel.COMBAT_EASE + 0.2)  # (the fights above: the hold lets go first)
	for p in ["vignette_extra", "pulse", "aberration", "warp", "hurt"]:
		if _param(post, p) != 0.0:
			return _fail("mark 0: %s = %f (the plain look must be untouched)" % [p, _param(post, p)])
	player.mark = 50.0
	await _frames(3)
	if _param(post, "vignette_extra") <= 0.0 or _param(post, "aberration") != 0.0:
		return _fail("mark 50: vignette %f aberration %f" % [_param(post, "vignette_extra"), _param(post, "aberration")])
	# the base split / wobble at 100 %: there, but at most a quarter of the first pass (0.006 / 0.0035)
	player.mark = 100.0
	await _frames(3)
	var base_ab := _param(post, "aberration")
	var base_wp := _param(post, "warp")
	if base_ab <= 0.0 or base_ab > 0.006 * 0.25 + 1e-6 or base_wp > 0.0035 * 0.25 + 1e-6:
		return _fail("mark 100 base distortion: aberration %f warp %f" % [base_ab, base_wp])
	# a spike flares over the base, then fades back to it within SPIKE_FADE
	fx.spike(1.0)
	await _frames(15)
	if _param(post, "aberration") < base_ab + Feel.SPIKE_ABERRATION * 0.5:
		return _fail("spike: aberration only %f" % _param(post, "aberration"))
	await _secs(Feel.SPIKE_FADE + 0.4)
	if absf(_param(post, "aberration") - base_ab) > 1e-5:
		return _fail("spike didn't fade (%f vs base %f)" % [_param(post, "aberration"), base_ab])
	# in a fight it's all held down
	var foe := Enemy.spawn(world, "res://models/char_marked_man.glb", spot + Vector3(-30, -0.1, 0), PI / 2.0)
	foe.patrol = [foe.position]
	await _frames(2)
	foe._set_state(Enemy.State.CHASE)  # (spikes too: something started hunting Alex)
	fx.spike(1.0)
	await _frames(15)
	var cap := (base_ab + Feel.SPIKE_ABERRATION) * Feel.COMBAT_DISTORT + 1e-6
	if not fx.in_fight() or _param(post, "aberration") > cap:
		return _fail("fight: aberration %f over %f" % [_param(post, "aberration"), cap])
	foe.queue_free()
	await _secs(Feel.SPIKE_FADE + 0.3)
	# near a boss: a faint steady ambience, eased in (no step, no flare), always under the fight ceiling
	player.mark = 0.0
	await _secs(Feel.COMBAT_EASE + 0.2)
	var boss := Enemy.spawn(world, "res://models/char_owen.glb", spot + Vector3(-10, -0.1, 0), PI / 2.0,
		{"boss": true, "walk_speed": 0.0, "run_speed": 0.0, "ranged": false, "sight_range": 0.5})
	boss.patrol = [boss.position]
	var last := _param(post, "aberration")
	var jump := 0.0
	# every frame for 4 s, each change per 1/60 s of the delta it was eased by (read one frame late: process_frame
	# comes before the frame's _process): a hitch (the boss model loading) is one long frame through which the ease
	# takes one long step; a real step (a snap to the level) is just as big at any frame rate
	var dt := 1.0 / 60.0
	var watched := 0.0
	while watched < 4.0:
		await process_frame
		var ab := _param(post, "aberration")
		jump = maxf(jump, absf(ab - last) / maxf(dt * 60.0, 1.0))
		last = ab
		dt = root.get_process_delta_time()
		watched += dt
	var amb := Feel.SPIKE_BOSS * Feel.SPIKE_ABERRATION * Feel.mark_fx
	if last < amb * 0.8 or last > amb * 1.05 or _param(post, "warp") > Feel.COMBAT_MAX_WARP:
		return _fail("boss ambience: aberration %f (level %f) warp %f" % [last, amb, _param(post, "warp")])
	if jump > amb * 0.05:
		return _fail("boss ambience isn't smooth: a %f step" % jump)
	boss.global_position = spot + Vector3(-14.0 - Feel.BOSS_AMBIENCE_FADE * 0.5, -0.1, 0)  # thinning out, not gone
	await _secs(Feel.BOSS_AMBIENCE_EASE * 4.0)
	var mid := _param(post, "aberration")
	if mid <= amb * 0.1 or mid >= amb * 0.9:
		return _fail("boss ambience past the near ring: %f (full %f)" % [mid, amb])
	boss.global_position = spot + Vector3(-6, -0.1, 0)
	boss._set_state(Enemy.State.CHASE)  # a fight: a scripted beat + a hit on top stay under the ceiling
	player.mark = 100.0
	fx.spike(Feel.SPIKE_SCRIPT)
	for i in 30:
		await physics_frame
		if _param(post, "aberration") > Feel.COMBAT_MAX_ABERRATION + 1e-6 or _param(post, "warp") > Feel.COMBAT_MAX_WARP + 1e-6:
			return _fail("boss fight: aberration %f warp %f over the ceiling" % [_param(post, "aberration"), _param(post, "warp")])
	boss.queue_free()
	player.mark = 100.0
	await _secs(Feel.SPIKE_FADE + 0.3)
	# whispers past 25 %
	fx._whisper_t = 0.0
	await _frames(2)
	if Snd._a() and Snd._a().last_sfx != "whisper" and Snd._a().last_sfx != "heartbeat":
		return _fail("no whisper at 100 %% (last sfx %s)" % Snd._a().last_sfx)

	# --- apparitions: the Harvester, far off in the dark, gone when looked at / by itself; off with the switch
	player.mark = 95.0
	player.pitch.rotation.x = 0.0
	var ap: Apparition = null
	for i in 16:
		ap = Apparition.try_spawn(player)
		if ap:
			break
		player.pivot.rotation.y += 0.4  # look around for a dark corner
		await _frames(2)
	if not ap:
		return _fail("apparition: no dark spot anywhere around the sawmill road")
	var ad := ap.global_position.distance_to(player.global_position)
	if ad < Feel.APPARITION_DIST.x - 0.5 or ad > Feel.APPARITION_DIST.y + 0.5:
		return _fail("apparition at %.1f m" % ad)
	if not ap.find_children("*", "CollisionObject3D", true, false).is_empty() or ap.is_in_group("enemies"):
		return _fail("apparition has collision / is an enemy")
	var to: Vector3 = ap.global_position - player.camera.global_position
	player.pivot.rotation.y = atan2(-to.x, -to.z)  # look right at it
	await _frames(4)
	if is_instance_valid(ap):
		return _fail("apparition still there when looked at")
	player.pivot.rotation.y += PI * 0.5
	await _frames(2)
	for i in 16:
		ap = Apparition.try_spawn(player)
		if ap:
			break
		player.pivot.rotation.y += 0.4
		await _frames(2)
	if ap:  # left alone it goes by itself
		var look: float = player.pivot.rotation.y
		await _secs(Feel.APPARITION_TIME.y + 0.3)
		if is_instance_valid(ap) and player.pivot.rotation.y == look:
			return _fail("apparition outlived APPARITION_TIME")
	Feel.hallucinations = false
	fx._appar_t = 0.0
	await _frames(5)
	Feel.hallucinations = true
	if is_instance_valid(fx._apparition):
		return _fail("apparition with Feel.hallucinations off")

	# --- the Mark's growth: the chapter's soft cap, the marked signal
	if absf(Feel.add_mark(25.0, 10.0, 30.0) - 31.25) > 0.001 or Feel.add_mark(10.0, 4.0, 30.0) != 14.0:
		return _fail("add_mark: %f / %f" % [Feel.add_mark(25.0, 10.0, 30.0), Feel.add_mark(10.0, 4.0, 30.0)])
	player.mark = 20.0
	player.mark_cap = Feel.MARK_SOFT_CAP[1]
	player.health = player.health_max
	var got := [0.0]
	player.marked.connect(func(gain: float) -> void: got[0] = gain)
	await _frames(20)
	player.hurt(5.0, Vector3.ZERO, Feel.MARK_GAIN.owen_hunt)
	if absf(player.mark - 24.0) > 0.001 or absf(got[0] - 4.0) > 0.001:
		return _fail("hurt + mark: %.2f (signal %.2f)" % [player.mark, got[0]])
	# the HUD's "MARK +N%": flashes on a rise, rises while it's up merge into it, then it fades; the slow creep is
	# gathered into one notice per Feel.MARK_NOTICE_CREEP %; the Veil's Eye (gauge + note) is gone
	var hud: Node = player.hud
	if hud.find_children("*", "Control", true, false).any(func(c: Node) -> bool: return c is HudEyes) == false:
		return _fail("the visibility eye is gone from the HUD")
	if "_veil" in hud._eyes:
		return _fail("the Veil's Eye is still on the HUD")
	await _secs(Feel.MARK_NOTICE_HOLD + Feel.MARK_NOTICE_FADE + 0.5)  # (the hit above told its own +4 %)
	if hud._mark_note.modulate.a > 0.01:
		return _fail("mark notice didn't fade: alpha %.2f" % hud._mark_note.modulate.a)
	await _frames(20)
	player.hurt(5.0, Vector3.ZERO, 2.0)
	await _frames(3)
	if hud._mark_note.modulate.a < 0.9 or hud._mark_note.text != "MARK +2%":
		return _fail("mark notice: '%s' alpha %.2f" % [hud._mark_note.text, hud._mark_note.modulate.a])
	await _frames(20)
	player.hurt(5.0, Vector3.ZERO, 1.5)
	await _frames(3)
	if hud._mark_note.text != "MARK +3.5%":
		return _fail("rapid rises didn't merge: '%s'" % hud._mark_note.text)
	await _secs(Feel.MARK_NOTICE_HOLD + Feel.MARK_NOTICE_FADE + 0.5)
	if hud._mark_note.modulate.a > 0.01:
		return _fail("merged notice didn't fade")
	for i in 30:  # creep: 0.1 % a frame, 3 % in all → one notice of 2 %, the rest waiting
		player.mark += 0.1
		await process_frame
	if hud._mark_note.modulate.a < 0.5 or not hud._mark_note.text.begins_with("MARK +2"):
		return _fail("creep notice: '%s' alpha %.2f" % [hud._mark_note.text, hud._mark_note.modulate.a])
	var before: String = hud._mark_note.text
	player.mark += 20.0  # a jump that's no rise (a save / dev start, a checkpoint restore): no notice
	await _frames(3)
	if hud._mark_note.text != before:
		return _fail("a non-rise jump made a notice: '%s'" % hud._mark_note.text)
	# the pause menu shows the exact value
	var gg := G.game()
	if gg and gg.director:
		player.mark = 37.4
		gg._open_pause()
		var shown: Array = gg._pause.find_children("Mark", "Label", true, false)
		var txt: String = shown[0].text if not shown.is_empty() else ""
		gg.resume()
		if txt != "MARK  37.4%":
			return _fail("pause menu mark: '%s'" % txt)
	player.mark = 0.0
	# a hit: red edges that fade
	player.health = player.health_max
	player.hurt(30.0)
	await _frames(2)
	if _param(post, "hurt") <= 0.0:
		return _fail("hurt: no edges")
	await _secs(Feel.HURT_EDGE_TIME + 0.3)
	if _param(post, "hurt") > 0.0:
		return _fail("hurt edges didn't fade (%f)" % _param(post, "hurt"))
	world.queue_free()
	await _frames(5)

	# --- Dev: all 12 pieces of evidence
	var g := G.game()
	if g:
		g.dev_evidence = true
		world = load("res://maps/hollowmere.tscn").instantiate()
		world.get_node("Chapter1").start_step = "free"
		root.add_child(world)
		await _frames(30)
		g.dev_evidence = false
		var ev: Array = world.get_node("Chapter1").flags.evidence
		if ev.size() != 12:
			return _fail("dev evidence: %s" % [ev])
		world.queue_free()
		await _frames(5)
		g.dev_mark = 60.0  # Dev Mode START MARK (as `-- --mark=60`)
		world = load("res://maps/hollowmere.tscn").instantiate()
		world.get_node("Chapter1").start_step = "free"
		root.add_child(world)
		await _frames(30)
		g.dev_mark = -1.0
		if absf(world.get_node("Player").mark - 60.0) > 0.001:
			return _fail("dev mark: %.1f" % world.get_node("Player").mark)
	print("FEEL OK")
	quit(0)
