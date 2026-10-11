class_name Harvester
extends Enemy
## The Harvester (chapters.md §1): Chapter 3 final boss, three phases it switches itself (phase_changed):
##   1 GUARD  — the skull sword covers its front (GUARD_ARC): hits there do ×0.1. Circle it, shoot its back.
##   2 WARDED — below 66 %: no damage at all unless light has it stunned (floodlights, flares, fire).
##   3 SWEEP  — below 33 %: every SWEEP_EVERY s a telegraphed 360° sweep (red ring, roll through it or be
##              out of SWEEP_R); after it, it's spent: red cracks exposed (×2 from any side) for SPENT s.
## Light is the weakness (lore: C3.4): light_stun() stuns LIGHT_STUN s, then it's immune LIGHT_IMMUNE s.
## A flashlight held on its face for DAZZLE_TIME s staggers it for a second (guard down).
## A phase never skips: damage stops at the next phase line. At 0 HP it kneels (downed) — no spare/kill.

signal phase_changed(phase: int)
signal blocked  ## a hit bounced off the sword (barks)
signal swept  ## a sweep just landed

const GUARD_ARC := 75.0  ## degrees either side of its facing
const PHASE_AT := [1.0, 0.66, 0.33]  ## health fraction where phase 1 / 2 / 3 begins
const SWEEP_R := 5.5
const SWEEP_WINDUP := 1.3
const SWEEP_DAMAGE := 45.0
const SWEEP_EVERY := 8.0
const SPENT := 2.5
const LIGHT_STUN := 3.0
const LIGHT_IMMUNE := 5.0
const DAZZLE_TIME := 1.0
const DAZZLE_RANGE := 14.0

var phase := 1
var _sweep_t := 4.0
var _sweeping := -1.0  ## 0..1 through windup + strike, -1 = not sweeping
var _exposed := 0.0
var _immune := 0.0
var _dazzle := 0.0
var _dazzle_cd := 0.0
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _eyes: OmniLight3D
var _cracks: OmniLight3D


static func spawn_at(parent: Node, pos: Vector3, yaw := 0.0) -> Harvester:
	var h := Enemy.spawn(parent, "res://models/char_boss.glb", pos, yaw, {
		"display_name": "The Harvester", "boss": true, "max_health": 900.0, "walk_speed": 1.3,
		"run_speed": 2.5, "melee_damage": 38.0, "melee_range": 2.8, "windup": 1.0, "mark_gain": Feel.MARK_GAIN.harvester,
		"sight_range": 70.0, "fov_deg": 220.0, "flare_stun": 0.0, "hearing": 2.0, "agile": false,
		"instant_notice": true, "question_icon": false}, Harvester.new()) as Harvester  # it never wonders: only "!"
	var col := h.get_child(0) as CollisionShape3D
	var cap := col.shape as CapsuleShape3D
	cap.radius = 0.6
	cap.height = 2.8
	col.position.y = 1.4
	return h


func _ready() -> void:
	super()
	_eyes = _omni(Color(1.0, 0.1, 0.05), 2.0, 4.0, 2.6)
	_cracks = _omni(Color(1.0, 0.25, 0.1), 0.0, 5.0, 1.5)
	_ring = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = SWEEP_R
	disc.bottom_radius = SWEEP_R
	disc.height = 0.02
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(0.9, 0.08, 0.05, 0.0)
	disc.material = _ring_mat
	_ring.mesh = disc
	_ring.position.y = 0.05
	add_child(_ring)
	Snd.attach(self, "harvester", 2.0)


func _omni(c: Color, energy: float, r: float, y: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = r
	l.position = Vector3(0, y, 0.3)
	add_child(l)
	return l


func eyes_off(time := 2.0) -> void:
	## C3.4: the red lenses go dark.
	create_tween().tween_property(_eyes, "light_energy", 0.0, time)


func _physics_process(delta: float) -> void:
	_immune = maxf(_immune - delta, 0.0)
	_exposed = maxf(_exposed - delta, 0.0)
	_dazzle_cd = maxf(_dazzle_cd - delta, 0.0)
	_cracks.light_energy = move_toward(_cracks.light_energy, 3.0 if _exposed > 0.0 else 0.0, delta * 8.0)
	if state in [State.DOWN, State.DEAD, State.STUNNED] and _sweeping >= 0.0:
		_end_sweep()
	super(delta)


func _think(delta: float) -> void:
	if _sweeping >= 0.0:
		_do_sweep(delta)
		return
	_check_dazzle(delta)
	if phase == 3 and state == State.CHASE and _attack < 0.0:
		_sweep_t -= delta
		if _sweep_t <= 0.0 and global_position.distance_to(_player.global_position) < SWEEP_R + 3.0:
			_sweeping = 0.0
			_anim.attack = 0.0
			return
	super(delta)


func _hold(delta: float) -> void:
	if _sweeping >= 0.0:
		_end_sweep()
	super(delta)


func _do_sweep(delta: float) -> void:
	_stop(delta)
	var before := _sweeping
	_sweeping += delta / (SWEEP_WINDUP + 0.35)
	var wind := SWEEP_WINDUP / (SWEEP_WINDUP + 0.35)
	if _sweeping < wind:  # the ring fills: get out, or roll through it
		_ring_mat.albedo_color.a = 0.15 + 0.4 * _sweeping / wind
		_anim.attack = 0.6 * _sweeping / wind
		return
	if before < wind:  # the blade comes round
		_ring_mat.albedo_color.a = 0.7
		var to: Vector3 = _player.global_position - global_position
		if Vector2(to.x, to.z).length() < SWEEP_R:
			_player.hurt(SWEEP_DAMAGE, global_position, mark_gain)
		get_tree().call_group("enemies", "hear", global_position, 30.0)
		swept.emit()
	_model.rotation.y += delta * TAU / 0.35
	_anim.attack = 0.6 + 0.4 * (_sweeping - wind) / (1.0 - wind)
	if _sweeping >= 1.0:
		_end_sweep()
		_exposed = SPENT
		stun(SPENT)  # spent: kneels, cracks glowing


func _end_sweep() -> void:
	_sweeping = -1.0
	_sweep_t = SWEEP_EVERY + randf_range(-1.0, 1.0)
	_ring_mat.albedo_color.a = 0.0
	_anim.attack = -1.0


func _check_dazzle(delta: float) -> void:
	## Flashlight on its face (camera aim within ~9° of its head, facing Alex, close): stagger.
	var fl: Node3D = _player.get("flashlight")
	var cam: Camera3D = _player.get("camera")
	if _dazzle_cd > 0.0 or not fl or not fl.visible or not cam:
		_dazzle = maxf(_dazzle - delta, 0.0)
		return
	var head := global_position + Vector3.UP * 2.5
	var to_head := head - cam.global_position
	var facing := _model.global_basis.z.dot((_player.global_position - global_position).normalized()) > 0.4
	if facing and to_head.length() < DAZZLE_RANGE and rad_to_deg((-cam.global_basis.z).angle_to(to_head)) < 9.0:
		_dazzle += delta
		_eyes.light_energy = 2.0 + 2.0 * sin(_dazzle * 40.0)
		if _dazzle >= DAZZLE_TIME:
			_dazzle = 0.0
			_dazzle_cd = 6.0
			_eyes.light_energy = 2.0
			stun(1.0)
	else:
		_dazzle = maxf(_dazzle - delta, 0.0)


func light_stun() -> bool:
	## Floodlight / flare / fire. False while immune (it just shrugged off the last one).
	if _immune > 0.0 or state in [State.DOWN, State.DEAD] or not is_physics_processing():
		return false
	_immune = LIGHT_STUN + LIGHT_IMMUNE
	stun(LIGHT_STUN)
	return true


func hit(dmg: float, point: Vector3, flare := false) -> void:
	if state in [State.DOWN, State.DEAD] or not is_physics_processing():
		return  # no kill shot: C3.3 decides what happens to it
	if flare:
		light_stun()
	var open := state == State.STUNNED or _exposed > 0.0
	if _exposed > 0.0:
		dmg *= 2.0
	elif state == State.STUNNED:
		dmg *= 1.5
	elif phase == 2 or _front(point):
		dmg = 0.0 if phase == 2 else dmg * 0.1
		blocked.emit()
	_anim.flinch = 0.5 if open else 0.2
	if state != State.STUNNED:
		_target = _player.global_position
		_unseen = 0.0
		_set_state(State.CHASE)
	if dmg > 0.0:
		_take(dmg)


func _front(point: Vector3) -> bool:
	var to := point - global_position
	to.y = 0.0
	return to.length() < 0.01 or rad_to_deg(_model.global_basis.z.angle_to(to)) < GUARD_ARC


func _take(dmg: float) -> void:
	if phase < 3:  # never skip a phase: stop at the next line
		dmg = minf(dmg, health - max_health * PHASE_AT[phase] + 0.5)
	super(dmg)
	if phase < 3 and health <= max_health * PHASE_AT[phase] + 0.5 and state != State.DOWN:
		phase += 1
		phase_changed.emit(phase)


func can_takedown(_by: Node3D) -> bool:
	return false  # nobody sneaks up and chokes out a three-metre man


func reset_to(pos: Vector3) -> void:
	super(pos)
	phase = 1
	_end_sweep()
	_sweep_t = 4.0
	_exposed = 0.0
	_immune = 0.0
	_dazzle = 0.0
	_dazzle_cd = 0.0
