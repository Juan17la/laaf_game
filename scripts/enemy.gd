class_name Enemy
extends CharacterBody3D
## Hunters and Marked Ones (RF-03): patrol → suspicious → chase → search, melee with a telegraphed
## overhead windup (dodge it with a roll), optional bow, stun (flare / fire), down (bosses kneel for
## the spare/kill choice) and death. Built in code with Enemy.spawn(); the model is any char_*.glb.
## Chapter 2 props (all off by default): lily_calls (Nora in the dark), shadow_bonus, gas_thrower +
## asthma (Julian, see GasCloud), checks_hiding (searches hiding spots it saw used), stealth takedown.
## Chapter 3: hearing + armor (Marcus), SmokeCloud blocks sight, crush() (a dropped bell), subclass spawn
## (Harvester passes its own instance to spawn()).
## Adaptive: every enemy reads and feeds one shared profile of the player's habits (habits(): dodge,
## ranged, stealth, hide, melee, stun; moving averages that keep re-learning). Rollers get delayed strikes and
## follow-ups, snipers a weaving approach and dives out of the aim, brawlers backsteps out of their swings and a
## pounce back, stunners shorter stuns and angrier enemies, sneaks guards that glance back, hiders searchers that
## check the nearest hiding spots. A habit that takes hold is told to the player (a HUD note: "THEY ADAPT").
## Combat: the player's stuns (melee, flare, fire) go through stagger(): back-to-back stuns get shorter and a
## guard window after each shrugs the next off, so nothing can be stun-locked. Rage (hurt, stunned; a boss's
## floor rises as it loses health) makes them faster, quicker to strike and frenzied. Agile ones dodge, pounce
## from a few metres into a quick strike, chain combos; packs flank. Bosses go down in varied poses (DOWN:
## HumanoidAnim.down_pose), breathing hard and watching Alex; deaths fall away from the killing blow, in varied ways.

signal died(enemy: Enemy)
signal downed(enemy: Enemy)  ## boss at 0 HP: kneels, waits for spare / kill
signal damaged(enemy: Enemy)
signal struck_player(enemy: Enemy)
signal called(enemy: Enemy)  ## lily_calls: stopped to call for Lily (glows, takes extra damage)
signal checks_spot(enemy: Enemy, pos: Vector3)  ## checks_hiding: arrived at a hiding spot it saw used

enum State { PATROL, SUSPICIOUS, CHASE, SEARCH, STUNNED, DOWN, DEAD }

@export var display_name := "Marked One"
@export var max_health := 60.0
@export var walk_speed := 1.6
@export var run_speed := 3.4
@export var melee_damage := 12.0
@export var melee_range := 1.7
@export var windup := 0.55
@export var mark_gain: float = Feel.MARK_GAIN["marked"]  ## % Mark per blow that lands (Feel.MARK_GAIN)
@export var sight_range := 20.0
@export var fov_deg := 130.0
@export var ranged := false  ## bow: keeps its distance and fires arrows
@export var bow := false  ## carries the bow (item_bow) even when not shooting it (Owen on the hunt)
@export var arrow_damage := 14.0
@export var arrow_interval := 2.2
@export var flare_stun := 2.5  ## seconds stunned by a flare hit (Owen: long, fire is his weakness)
@export var boss := false  ## at 0 HP kneels (DOWN) instead of dying
@export var invulnerable := false  ## scripted hunts: shots only stagger
@export var give_up_x := INF  ## scripted hunts: stops chasing past this world X (the town lights)
@export var lily_calls := false  ## Nora in the dark: dimmed model, stops every call_interval s to call
@export var call_interval := 7.0
@export var call_time := 1.8  ## how long each call lasts (the punish window)
@export var shadow_bonus := 1.0  ## damage multiplier while not in CHASE (hit from the shadows)
@export var gas_thrower := false  ## Julian: lobs a sedative canister (GasCloud) at the player
@export var gas_interval := 6.0
@export var asthma := false  ## stunned by any GasCloud while GasCloud.vents_reversed
@export var asthma_stun := 3.5
@export var checks_hiding := false  ## remembers hiding spots it saw used; SEARCH visits them first
@export var hearing := 1.0  ## noise radius multiplier (Marcus hears everything)
@export var armor := 1.0  ## damage multiplier while not stunned (Marcus: very tough)
@export var agile := true  ## dodges and pounces (the Harvester is too big for either)
@export var instant_notice := false  ## sight fills the awareness meter at once (the Harvester always knows)
@export var question_icon := true  ## shows "?" while noticing / searching (the Harvester only ever shows "!")

var state := State.PATROL
var awareness := 0.0  ## 0..1: how sure it is it saw Alex (Feel AWARE_*); full = CHASE. hear() doesn't touch it
var spotted_t := 99.0  ## seconds since it last went into CHASE (the "!" icon)
var health := 60.0
var patrol: Array[Vector3] = []
## The bow in the left hand (item_bow, the same grip as the player's), string drawn by the game, arms by IK.
const BOW_GRIP := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3(0, -0.06, -0.02))
var _bow_model: Node3D
var _bow_string: Array[MeshInstance3D] = []
var _bow_arrow: Node3D
var drop: Callable  ## called with the death position (loot)

var _anim: HumanoidAnim
var _model: Node3D
var _player: Node3D
var _target := Vector3.ZERO
var _patrol_i := 0
var _t_state := 0.0
var _t_sense := 0.0
var _attack := -1.0
var _cool := 0.0
var _arrow_t := 1.5
var _stun := 0.0
var _stuck := 0.0
var _strafe := 1.0
var _unseen := 0.0  ## seconds since the player was last seen
var _call_t := 0.0
var _calling := 0.0  ## > 0 while calling for Lily
var _glow: OmniLight3D
var _dim: Array = []  ## [MeshInstance3D, surface, dark material] (lily_calls)
var _gas_t := 2.5
var _throw := -1.0  ## 0..1 canister throw (windup until 0.6)
var _back := 0.0
var _asthma_cd := 0.0
var _spots: Array[Vector3] = []  ## hiding spots seen used (checks_hiding)
var _check: Array[Vector3] = []  ## spots still to check this search
var _windup_now := 0.55  ## this swing's windup (jittered; delayed against players who roll)
var _wait := 0.0  ## patrol: standing still (a pause at a waypoint or a glance back)
var _look := Vector3.ZERO  ## direction of the current glance back (ZERO: just pausing)
var _glance_t := randf_range(3.0, 8.0)
var _seen_vel := Vector3.ZERO  ## the player's velocity when last seen (where a runner went)
var _stun_tol := 0.0  ## recent stuns (decays): each new one is shorter
var _guard := 0.0  ## > 0: shrugs staggers off (just after a stun)
var _rage := 0.0  ## 0..1: faster, quicker strikes, frenzied
var _dodge := 0.0  ## > 0: seconds of dodge left
var _dodge_vel := Vector3.ZERO
var _dodge_roll := false  ## a dive roll (out of a gun's aim) rather than a backstep (out of a swing)
var _dodge_cd := randf_range(1.0, 2.5)
var _threat_was := ""
var _pounce := -1.0  ## seconds into a pounce (gather, then leap), -1 = none
var _leapt := false
var _pounce_cd := randf_range(2.0, 4.0)
var _combo := 0  ## follow-up strikes left in this flurry
var _hit_from := Vector3.ZERO  ## direction the last blow came from (a death falls away from it)
var _freeze := 0.0  ## > 0: hitstop, the whole body holds still (Feel.HITSTOP)
var _meshes: Array[MeshInstance3D] = []  ## the model's meshes (hit flash overlay)
var _flash_mat: StandardMaterial3D
var _flash_tw: Tween
var _model_scale := Vector3.ONE

const TAKEDOWN_CONE := 100.0  ## degrees behind the enemy
const SENSE_STEP := 0.2  ## s between looks (can_see_player)
const THROW_TIME := 0.9
const PACE_CAP := 5.3  ## m/s: a raging chaser stays just under Alex's sprint (escape costs stamina)
const DOWN_POSES := ["kneel", "one_knee", "hands_ground", "sit_back", "side"]
const HABIT_NOTES := {
	"dodge": "They've learned you roll on cue. They'll hold their strikes, and follow up.",
	"ranged": "They've learned you shoot from afar. They weave in and dive out of your aim.",
	"stealth": "They've learned you sneak. Patrols check behind them.",
	"hide": "They've learned you hide. They search the hiding spots first.",
	"melee": "They've learned you fight up close. They step out of your swings and pounce back.",
	"stun": "They've learned you stun them. Each stun wears off faster, and leaves them angrier.",
}
static var _local := {}  ## habits when there's no Game autoload (headless tests)
static var _noted := {}  ## habit -> told the player already (re-armed once the habit fades)

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


static func spawn(parent: Node, model_scene: String, pos: Vector3, yaw := 0.0, props := {}, e: Enemy = null) -> Enemy:
	if not e:
		e = Enemy.new()
	for k in props:
		e.set(k, props[k])
	e.collision_layer = 2
	e.collision_mask = 3
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	col.shape = cap
	col.position.y = 0.9
	e.add_child(col)
	var model: Node3D = load(model_scene).instantiate()
	model.name = "Model"
	e.add_child(model)
	var anim := HumanoidAnim.new()
	anim.name = "Anim"
	anim.model_path = ^"../Model"
	e.add_child(anim)
	e.position = pos  # parents are at the world origin; set before _ready so patrol starts here
	model.rotation.y = yaw
	parent.add_child(e)
	return e


static func habits() -> Dictionary:
	## The player's habits, 0..1, shared by every enemy. Kept in Game.run: saved with the game, kept
	## through deaths and checkpoint reloads, fresh on a new run.
	var g := G.game()
	var run: Dictionary = g.run if g else _local
	if not run.has("habits"):
		run["habits"] = {}
	for k in HABIT_NOTES:  # saves from before a habit existed get it fresh
		if not run.habits.has(k):
			run.habits[k] = 0.0
	return run.habits


static func reset_notes() -> void:
	## A new or loaded run (Game.start): every habit may be told to the player again.
	_noted.clear()


static func learn(key: String, v: float, rate := 0.25) -> void:
	## Moving average: recent behaviour counts most, so a player who changes style is re-learned. A habit
	## that takes hold (>= 0.6) is told to the player once, again only after it has faded (< 0.35).
	var h := habits()
	h[key] = lerpf(h[key], v, rate)
	if h[key] >= 0.6 and not _noted.get(key, false):
		_noted[key] = true
		var tree := Engine.get_main_loop() as SceneTree
		var p := tree.get_first_node_in_group("player") if tree else null
		if p and p.get("hud") and p.hud.has_method("note"):
			p.hud.note(HABIT_NOTES[key], "THEY ADAPT", 4.5)
	elif h[key] < 0.35:
		_noted[key] = false


func _exit_tree() -> void:
	Snd.threat(false, self)


func _ready() -> void:
	max_health *= G.settings().enemy  # difficulty
	health = max_health
	add_to_group("enemies")
	_model = $Model
	_anim = $Anim
	_player = get_tree().get_first_node_in_group("player")
	if patrol.is_empty():
		patrol = [global_position]
	_target = patrol[0]
	_call_t = call_interval
	if lily_calls:
		_dim_model()
	if ranged or bow:
		_make_bow()
	if checks_hiding and _player and _player.has_signal("hid"):
		_player.hid.connect(_on_hid)
	_model_scale = _model.scale
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mi)
	add_child(AlertIcon.new())


func _dim_model() -> void:
	## Unlit in the dark: every surface drops to near black; a call restores it for a moment.
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		for i in mi.get_surface_override_material_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m:
				var dark := m.duplicate() as BaseMaterial3D
				dark.albedo_color = m.albedo_color * Color(0.12, 0.12, 0.15)
				dark.emission_enabled = false
				_dim.append([mi, i, dark])
	_set_dim(true)
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.75, 0.85, 1.0)
	_glow.omni_range = 7.0
	_glow.light_energy = 0.0
	_glow.position.y = 1.6
	add_child(_glow)


func _set_dim(on: bool) -> void:
	for d in _dim:
		d[0].set_surface_override_material(d[1], d[2] if on else null)


func _physics_process(delta: float) -> void:
	spotted_t += delta
	if _freeze > 0.0:  # hitstop: a beat where the blow lands and everything about it holds
		_freeze -= delta
		if _freeze <= 0.0:
			_anim.set_process(true)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	_t_state += delta
	_cool = maxf(_cool - delta, 0.0)
	_asthma_cd = maxf(_asthma_cd - delta, 0.0)
	if state != State.STUNNED:  # recovers slowly, and only while free: stun after stun keeps getting shorter
		_stun_tol = maxf(_stun_tol - delta * 0.1, 0.0)
	_guard = maxf(_guard - delta, 0.0)
	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_pounce_cd = maxf(_pounce_cd - delta, 0.0)
	# rage cools off; a boss's never drops below how badly it's hurt
	_rage = maxf(_rage - delta * 0.04, (1.0 - health / max_health) * 0.8 if boss else 0.0)
	match state:
		State.DEAD:
			return
		State.DOWN:
			_stop(delta)
			_downed_idle()
		State.STUNNED:
			_stun -= delta
			_stop(delta)
			_anim.flinch = maxf(_anim.flinch, 0.6)
			if _stun <= 0.0:
				_anim.crouching = false
				_set_state(State.CHASE)
				# back up angry: shrugs off the next stagger for a while (longer against a stun-reliant player),
				# and an agile one comes straight back with a pounce
				_guard = (2.5 if boss else 1.4) * (1.0 + habits().stun)
				_cool = 0.0
				if agile:
					_pounce_cd = 0.0
		_:
			if _player and _player.get("controls_enabled") == false:
				_hold(delta)
			elif not (lily_calls and _lily(delta)):
				_think(delta)
	move_and_slide()
	_anim.speed = Vector2(velocity.x, velocity.z).length()
	_anim.vertical = velocity.y


func _hold(delta: float) -> void:
	## Player out of control (cinematic, minigame, death fade): stand still, sense nothing, drop any windup.
	_stop(delta)
	_cancel_moves()
	if _attack >= 0.0 or _throw >= 0.0:
		_attack = -1.0
		_throw = -1.0
		_anim.attack = -1.0
	if _calling > 0.0:
		_end_call()
	_anim.aim = 0.0


func _lily(delta: float) -> bool:
	## Nora: every call_interval s she freezes and calls for Lily. True while calling (skip thinking).
	if _calling > 0.0:
		_calling -= delta
		_stop(delta)
		_glow.light_energy = 2.5 * clampf(_calling / call_time * 3.0, 0.0, 1.0)
		if _calling <= 0.0:
			_end_call()
		return true
	_call_t -= delta
	if _call_t > 0.0 or _attack >= 0.0 or _throw >= 0.0:
		return false
	_call_t = call_interval
	_calling = call_time
	_anim.gesture = "hand_to_face"
	_anim.aim = 0.0
	_set_dim(false)
	called.emit(self)
	return true


func _end_call(dim := true) -> void:
	_calling = 0.0
	if lily_calls:
		_anim.gesture = ""
		_set_dim(dim)
		_glow.light_energy = 0.0


func _think(delta: float) -> void:
	_t_sense -= delta
	_unseen += delta
	if _t_sense <= 0.0:
		_t_sense = SENSE_STEP
		var seen := can_see_player()
		if seen and state != State.CHASE:  # not instant: the meter fills (near, lit, dead ahead: fast)
			awareness = minf(awareness + _notice_rate() * SENSE_STEP, 1.0)
		elif not seen and state != State.CHASE:
			awareness = maxf(awareness - Feel.AWARE_DECAY * SENSE_STEP, 0.0)
		if seen and (state == State.CHASE or awareness >= 1.0):
			_unseen = 0.0
			_target = _player.global_position
			_seen_vel = _player.velocity
			if state in [State.PATROL, State.SUSPICIOUS]:
				learn("stealth", 0.0, 0.1)  # walked into view: not sneaking this time
			if state != State.CHASE:
				_set_state(State.CHASE)
		elif seen and state == State.PATROL and awareness >= Feel.AWARE_LOOK_AT:
			_target = _player.global_position  # half sure: walks over to look (shows "?")
			_set_state(State.SUSPICIOUS)
	if state == State.CHASE and _player.global_position.x > give_up_x:
		_set_state(State.SEARCH)
		_target = patrol[0]
	if _attack >= 0.0:
		_do_attack(delta)
		return
	if _dodge > 0.0:
		_do_dodge(delta)
		return
	if _pounce >= 0.0:
		_do_pounce(delta)
		return
	if gas_thrower:
		_gas_t -= delta
		if _throw >= 0.0:
			_do_throw(delta)
			return
	match state:
		State.PATROL:
			_glance_t -= delta
			if _glance_t <= 0.0:  # against a sneaky player: stop now and then and look behind
				_glance_t = randf_range(3.0, 8.0)
				if randf() < habits().stealth:
					_wait = randf_range(1.0, 1.8)
					_look = -_model.global_basis.z
			if _wait > 0.0:
				_wait -= delta
				_stop(delta)
				if _look != Vector3.ZERO:
					_face(global_position + _look, delta, 5.0)
			elif _go(_target, walk_speed, delta) < 1.0:
				_patrol_i = (_patrol_i + 1) % patrol.size()
				_target = patrol[_patrol_i]
				if randf() < 0.35:  # not a metronome: sometimes linger at a waypoint
					_wait = randf_range(0.5, 2.0)
					_look = Vector3.ZERO
		State.SUSPICIOUS:
			if _go(_target, walk_speed * 1.3, delta) < 1.2 or _t_state > 10.0:
				_set_state(State.SEARCH)
		State.CHASE:
			var d := global_position.distance_to(_player.global_position)
			var pace := minf(run_speed * (1.15 + 0.35 * _rage), maxf(run_speed, PACE_CAP))
			_frenzy(d < 8.0 and _rage > 0.35 and not boss and not ranged and _unseen < 1.0)
			if _unseen > 5.0:  # lost them: search around the last known position
				_lost_player()
			elif agile and _try_dodge(d):
				pass
			elif gas_thrower and _gas_t <= 0.0 and _unseen < 0.5 and d < 16.0:
				_gas(d, delta)
			elif ranged and d > 4.0:
				_bow(d, delta)
			elif d < melee_range and _cool <= 0.0:
				_strike_start()
				_face(_player.global_position, delta, 30.0)
			elif agile and not ranged and _pounce_cd <= 0.0 and _unseen < 0.3 and d > 2.4 and d < 6.5 \
					and is_on_floor():
				_pounce = 0.0
				_leapt = false
			elif _unseen < 1.0:
				_go(_player.global_position + _weave(d) + _flank(d), pace, delta)
			else:
				_go(_target, pace, delta)
		State.SEARCH:
			if not _check.is_empty():
				_check_spot(delta)
			elif _go(_target, walk_speed * 1.2, delta) < 1.2:
				_target = _target + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
			if _t_state > 12.0:
				_set_state(State.PATROL)
				_target = patrol[_patrol_i]


func _notice_rate() -> float:
	## Awareness per second while Alex is in sight (Feel AWARE_*): at once up close or for instant_notice, else
	## slower with distance (against how far it can see him now: crouching / hiding shrink that) and toward the
	## edge of the view cone; faster when already alert or when the flashlight is on.
	var to: Vector3 = _player.global_position - global_position
	var d := to.length()
	if instant_notice or d <= Feel.AWARE_NEAR:
		return INF
	var reach: float = maxf(sight_range * float(_player.visibility()), Feel.AWARE_NEAR + 0.01)
	var far := clampf((d - Feel.AWARE_NEAR) / (reach - Feel.AWARE_NEAR), 0.0, 1.0)
	var rate := 1.0 / lerpf(Feel.AWARE_TIME_NEAR, Feel.AWARE_TIME_FAR, far)
	var off := clampf(rad_to_deg(_model.global_basis.z.angle_to(to)) / (fov_deg * 0.5), 0.0, 1.0)
	rate *= lerpf(1.0, Feel.AWARE_EDGE_MULT, off)
	if state in [State.SUSPICIOUS, State.SEARCH]:
		rate *= Feel.AWARE_ALERT_MULT
	var light: Node3D = _player.get("flashlight")
	if light and light.visible:
		rate *= Feel.AWARE_LIGHT_MULT
	return rate


func hitstop(t: float) -> void:
	## The blow lands: hold still for t (scaled by Feel.hitstop). Physics and the pose freeze; nothing else does.
	t *= Feel.hitstop
	if t <= 0.0 or state == State.DEAD:
		return
	_freeze = maxf(_freeze, t)
	_anim.set_process(false)


func _flash() -> void:
	## Hit feedback: a white flash over the model and a little swell, both easing off at once.
	if not _flash_mat:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if _flash_tw:
		_flash_tw.kill()
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.material_overlay = _flash_mat
	_flash_mat.albedo_color = Color(1, 1, 1, Feel.ENEMY_FLASH)
	_model.scale = _model_scale * Feel.ENEMY_POP
	_flash_tw = create_tween().set_parallel()
	_flash_tw.tween_property(_flash_mat, "albedo_color:a", 0.0, Feel.ENEMY_FLASH_TIME)
	_flash_tw.tween_property(_model, "scale", _model_scale, Feel.ENEMY_POP_TIME).set_ease(Tween.EASE_OUT)
	_flash_tw.chain().tween_callback(func() -> void:
		for mi in _meshes:
			if is_instance_valid(mi):
				mi.material_overlay = null)


func _bow(d: float, delta: float) -> void:
	# keep 8-14 m, strafe, loose arrows on a timer
	_arrow_t -= delta
	var to := (_player.global_position - global_position)
	to.y = 0.0
	to = to.normalized()
	var side := Vector3(-to.z, 0, to.x) * _strafe
	var move := side * 0.7
	if d > 14.0:
		move += to
	elif d < 8.0:
		move -= to
	if randf() < delta * 0.4:
		_strafe = -_strafe
	velocity.x = move.x * run_speed * 0.6
	velocity.z = move.z * run_speed * 0.6
	_face(_player.global_position, delta, 12.0)
	_anim.aim = 1.0
	if _arrow_t <= 0.0 and can_see_player():
		_arrow_t = arrow_interval
		_anim.recoil = 1.0
		var from := _bow_model.to_global(Vector3(0.012, 0, -0.1)) if _bow_model else global_position + Vector3.UP * 1.45 + to * 0.5
		var aim_at: Vector3 = _player.global_position + Vector3.UP * 1.1 + _player.velocity * (d / 24.0) * 0.6
		Arrow.fire(get_parent(), from, aim_at, arrow_damage, self)


func _make_bow() -> void:
	var hand := _model.find_child("HandL", true, false) as Node3D
	if not hand or not ResourceLoader.exists("res://models/item_bow.glb"):
		return
	_bow_model = Node3D.new()
	hand.add_child(_bow_model)
	_bow_model.transform = BOW_GRIP
	_bow_model.add_child((load("res://models/item_bow.glb") as PackedScene).instantiate())
	for i in 2:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.003, 0.003, 1.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.82, 0.7)
		b.material = mat
		mi.mesh = b
		_bow_model.add_child(mi)
		_bow_string.append(mi)
	if ResourceLoader.exists("res://models/item_arrow.glb"):
		_bow_arrow = (load("res://models/item_arrow.glb") as PackedScene).instantiate()
		_bow_model.add_child(_bow_arrow)


func _process(delta: float) -> void:
	_bow_arms(delta)  # in _process: cutscenes freeze the physics but still raise the bow (anim.aim)


func _bow_arms(delta: float) -> void:
	## Bow carried low in the left hand, or up at arm's length along the aim with the right hand drawing the
	## string to the cheek (same poses as the player's bow: player.gd _bow_pose). Gone once he drops it.
	if not _bow_model:
		return
	var on := (ranged or bow) and state not in [State.DEAD, State.DOWN]
	_bow_model.visible = on
	if not on:
		for k in ["L", "R"]:
			_anim.ik_w[k] = move_toward(_anim.ik_w[k], 0.0, delta * 6.0)
		_anim.stance = 0.0
		return
	var ready := clampf(_anim.aim, 0.0, 1.0) if ranged else 0.0
	var ad := Vector3(0, sin(_anim.aim_pitch), cos(_anim.aim_pitch))
	var aimed := Transform3D(Basis.looking_at(ad, Vector3.UP) * Basis(Vector3.BACK, 0.12), Vector3(0.0, 1.53, 0.12) + ad * 0.6)
	var low := Transform3D(Basis.looking_at(Vector3(0.05, -0.15, 1.0), Vector3.UP), Vector3(0.25, 0.93, 0.1))
	var w := low.interpolate_with(aimed, ready)
	var draw := ready * clampf(1.0 - _anim.recoil * 1.5, 0.0, 1.0)  # the string snaps forward on a shot
	var nock := Vector3(0, 0, 0.16 + 0.45 * draw)
	_anim.ik_pole["R"] = Vector3(-1.0, 0.3, -0.6)  # the drawing elbow out and back, not across the chest
	_anim.ik["L"] = w * BOW_GRIP.affine_inverse()
	_anim.ik_w["L"] = 1.0
	_anim.ik["R"] = w * Transform3D(Basis(), nock + Vector3(0.012, -0.015, 0)) * BOW_GRIP.affine_inverse()
	_anim.ik_w["R"] = ready
	_anim.stance = -1.2 * ready
	for i in 2:
		var tip := Vector3(0, 0.62 if i == 0 else -0.62, 0.1)
		(_bow_string[i].mesh as BoxMesh).size.z = tip.distance_to(nock)
		_bow_string[i].transform = Transform3D(Basis.looking_at(nock - tip, Vector3.RIGHT), (tip + nock) / 2.0)
	if _bow_arrow:
		_bow_arrow.visible = ready > 0.3 and _anim.recoil < 0.3
		_bow_arrow.position = nock + Vector3(0.012, 0, 0)


func _gas(d: float, delta: float) -> void:
	## Canister ready: back off to a safe distance (max 1.5 s), then a telegraphed overhead lob.
	var to := _player.global_position - global_position
	to.y = 0.0
	if d < 5.0:
		_back += delta
		if _back > 1.5:  # cornered: melee now, try the canister again shortly
			_back = 0.0
			_gas_t = 2.0
			return
		velocity.x = -to.normalized().x * run_speed * 0.8
		velocity.z = -to.normalized().z * run_speed * 0.8
		_face(_player.global_position, delta, 12.0)
		return
	_back = 0.0
	_throw = 0.0


func _do_throw(delta: float) -> void:
	_stop(delta)
	var before := _throw
	_throw += delta / THROW_TIME
	_anim.attack = _throw
	if _throw < 0.6:
		_face(_player.global_position, delta, 8.0)
	if before < 0.62 and _throw >= 0.62:
		var at: Vector3 = _player.global_position + _player.velocity * 0.5
		at.y = _player.global_position.y
		if at.distance_to(global_position) > 3.5:
			_lob(at)
	if _throw >= 1.0:
		_throw = -1.0
		_anim.attack = -1.0
		_gas_t = gas_interval


func _lob(at: Vector3) -> void:
	## A canister arcs to `at` (0.8 s) and bursts into a GasCloud.
	var can := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.06
	m.bottom_radius = 0.06
	m.height = 0.22
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.55, 0.45)
	m.material = mat
	can.mesh = m
	var parent := get_parent()
	parent.add_child(can)
	var from := global_position + Vector3.UP * 1.9
	can.global_position = from
	var tw := can.create_tween()
	tw.tween_method(func(t: float) -> void:
		can.global_position = from.lerp(at, t) + Vector3.UP * sin(t * PI) * 2.5
		can.rotation.x = t * 9.0, 0.0, 1.0, 0.8)
	tw.tween_callback(func() -> void:
		GasCloud.make(parent, at)
		can.queue_free())


func _check_spot(delta: float) -> void:
	## checks_hiding: walk to the next remembered spot; the player hiding there is pulled out.
	if _go(_check[0], walk_speed * 1.4, delta) >= 1.2:
		return
	var spot: Vector3 = _check.pop_front()
	_t_state = 0.0
	checks_spot.emit(self, spot)
	if not _player.dead and _player.global_position.distance_to(spot) < 1.6:
		_unseen = 0.0
		_target = _player.global_position
		_set_state(State.CHASE)


func _lost_player() -> void:
	## Out of sight for 5 s: guess by the player's habit (hide or run), then learn what they actually did.
	_set_state(State.SEARCH)
	if randf() < habits().hide:  # a hider: check the hiding spots nearest to where they vanished
		var near: Array = _player.hidden_spots.filter(func(p: Vector3) -> bool: return p.distance_to(_target) < 12.0)
		near.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(_target) < b.distance_to(_target))
		for p: Vector3 in near.slice(0, 2):
			if not p in _check:
				_check.append(p)
	else:  # a runner: search ahead, along the way they were running
		var v := Vector3(_seen_vel.x, 0.0, _seen_vel.z)
		_target += v.normalized() * minf(v.length() * 2.0, 10.0)
	learn("hide", 1.0 if _player.is_hidden() else 0.0, 0.3)


func _weave(d: float) -> Vector3:
	## Against a player who shoots from range: zigzag in rather than run straight down the sights.
	if d < 5.0:
		return Vector3.ZERO
	var to := (_player.global_position - global_position).normalized()
	var phase := float(get_instance_id() % 7)  # chasers in a pack don't weave in step
	return Vector3(-to.z, 0.0, to.x) * sin(_t_state * 2.2 + phase) * minf(d * 0.4, 4.0) * habits().ranged


func _on_hid(pos: Vector3) -> void:
	if state in [State.DEAD, State.DOWN] or _unseen > 1.5:
		return  # only spots it actually saw the player slip into
	for s in _spots:
		if s.distance_to(pos) < 1.5:
			return
	_spots.append(pos)


func _strike_start(wind := -1.0) -> void:
	## Begin an overhead strike. Default windup: jittered, quicker with rage, and against a player who rolls on
	## cue sometimes held late so the roll comes early. Rollers and angry enemies get follow-up strikes.
	_attack = 0.0
	_frenzy(false)
	if randf() < 0.45:
		Snd.sfx("growl", global_position)
	if wind > 0.0:
		_windup_now = wind
	else:
		_windup_now = windup * randf_range(0.85, 1.2) * (1.0 - 0.25 * _rage)
		if randf() < habits().dodge * 0.7:
			_windup_now += randf_range(0.25, 0.55)
	var chain: float = (0.45 if boss else 0.2) + 0.3 * _rage + 0.3 * float(habits().dodge)
	_combo = (1 if randf() < chain else 0) + (1 if boss and randf() < chain * 0.5 else 0)


func _do_attack(delta: float) -> void:
	var to := _player.global_position - global_position
	to.y = 0.0
	# a boss, an angry one or a roller's hunter steps in while winding up instead of swinging at air
	if _attack < 0.55 and to.length() > melee_range * 0.75 and (boss or _rage > 0.5 or habits().dodge > 0.5):
		velocity.x = to.normalized().x * 2.4
		velocity.z = to.normalized().z * 2.4
	else:
		_stop(delta)
	var before := _attack
	_attack += delta / (_windup_now / 0.6) if _attack < 0.6 else delta / 0.35
	_anim.attack = _attack
	if _attack < 0.6:
		_face(_player.global_position, delta, 6.0)
	if before < 0.62 and _attack >= 0.62:
		var fwd := _model.global_basis.z
		if to.length() < melee_range + 0.5 and fwd.dot(to.normalized()) > 0.3:
			if _player.rolling_invulnerable():
				learn("dodge", 1.0)
			elif _player.hurt(melee_damage, global_position, mark_gain):
				learn("dodge", 0.0)
				struck_player.emit(self)
	if _attack >= 1.0:
		_anim.attack = -1.0
		if _combo > 0 and not _player.dead:  # the follow-up comes fast, re-aimed at where Alex is now
			var left := _combo - 1
			_strike_start(windup * 0.5 * (1.0 - 0.2 * _rage))
			_combo = left
			return
		_attack = -1.0
		_cool = lerpf(0.6, 0.25, _rage)
		learn("stun", 0.0, 0.04)  # a whole flurry went unanswered: not leaning on stuns right now


func _threat(d: float) -> String:
	## What Alex is about to do to this enemy: "aim" (a gun on it), "swing" (a blow coming that reaches it), "".
	if d < 30.0 and _player.get("aiming"):
		var cam: Camera3D = _player.get("camera")
		var to := global_position + Vector3.UP * 1.2 - cam.global_position if cam else Vector3.ZERO
		if cam and rad_to_deg((-cam.global_basis.z).angle_to(to)) < 6.0:
			return "aim"
	var st: float = _player.get("_strike_t") if _player.get("_strike_t") != null else -1.0
	var pm: Node3D = _player.get("model")
	if st >= 0.0 and st < 0.4 and d < 2.9 and pm \
			and pm.global_basis.z.dot((global_position - _player.global_position).normalized()) > 0.4:
		return "swing"
	return ""


func _try_dodge(d: float) -> bool:
	## On a new threat, maybe dodge it: the more the player relies on that tactic, the likelier. A gun's aim gets
	## a dive roll to the side, a swing a backstep (then a pounce straight back in). True if a dodge started.
	var t := _threat(d)
	var fresh := t != "" and t != _threat_was
	_threat_was = t
	if not fresh or _dodge_cd > 0.0 or not is_on_floor():
		return false
	var chance := (0.3 if boss else 0.15) + 0.55 * float(habits().ranged if t == "aim" else habits().melee) + 0.2 * _rage
	if randf() >= chance:
		return false
	var away := global_position - _player.global_position
	away.y = 0.0
	away = away.normalized()
	_dodge_roll = t == "aim"
	if _dodge_roll:
		_dodge_vel = Vector3(-away.z, 0.0, away.x) * (1.0 if randf() < 0.5 else -1.0) * 6.5
		_dodge = 0.5
	else:
		_dodge_vel = (away + Vector3(-away.z, 0.0, away.x) * randf_range(-0.5, 0.5)).normalized() * 6.0
		_dodge = 0.3
		_pounce_cd = 0.0  # ...and straight back in
	_dodge_cd = randf_range(1.8, 3.0) if boss else randf_range(2.5, 4.0)
	return true


func _do_dodge(delta: float) -> void:
	_dodge -= delta
	velocity.x = _dodge_vel.x
	velocity.z = _dodge_vel.z
	if _dodge_roll:  # a dive roll along the dodge, then turn back to Alex
		_face(global_position + _dodge_vel, delta, 30.0)
		_anim.roll = clampf(1.0 - _dodge / 0.5, 0.0, 0.999)
	else:  # a hop back, leaning away, eyes on him
		_face(_player.global_position, delta, 20.0)
		_anim.flinch = maxf(_anim.flinch, 0.45)
	if _dodge <= 0.0:
		_dodge = 0.0
		_anim.roll = -1.0
		_stop(delta)


func _do_pounce(delta: float) -> void:
	## Gather (crouch, eyes on the prey) for a beat, leap at where Alex is going, strike quick on landing.
	_pounce += delta
	if not _leapt:
		_stop(delta)
		_anim.crouching = true
		_face(_player.global_position, delta, 14.0)
		if _pounce < 0.25:
			return
		_leapt = true
		_anim.crouching = false
		_anim.airborne = true
		var to: Vector3 = _player.global_position + _player.velocity * 0.3 - global_position
		to.y = 0.0
		var reach := clampf(to.length() - melee_range * 0.6, 0.0, 6.0)
		velocity = to.normalized() * reach / 0.6
		velocity.y = 3.0  # ~0.6 s in the air
		return
	_face(_player.global_position, delta, 10.0)
	if (is_on_floor() and _pounce > 0.45) or _pounce > 1.3:
		_anim.airborne = false
		_pounce = -1.0
		_pounce_cd = randf_range(3.5, 6.0) * (0.6 if boss else 1.0) * (1.0 - 0.4 * _rage)
		velocity.x *= 0.2
		velocity.z *= 0.2
		_strike_start(windup * 0.4)


func _cancel_moves() -> void:
	## Stunned / frozen / reset mid-dodge or mid-pounce: back on its feet, nothing in flight.
	_dodge = 0.0
	_pounce = -1.0
	_combo = 0
	_anim.roll = -1.0
	_anim.airborne = false
	if _anim.crouching and state not in [State.STUNNED, State.DOWN]:
		_anim.crouching = false
	_frenzy(false)


func _flank(d: float) -> Vector3:
	## Packs spread round the player instead of queueing up one behind the other: each chaser aims for its own
	## side (by instance), merging back onto the player in the last couple of metres.
	if boss or d < 2.0:
		return Vector3.ZERO
	var to := (_player.global_position - global_position).normalized()
	var slot := float(get_instance_id() % 5) - 2.0
	return Vector3(-to.z, 0.0, to.x) * slot * 1.2 * clampf((d - 2.0) / 4.0, 0.0, 1.0)


func _frenzy(on: bool) -> void:
	## Raging up close: stabbing, clawing, hunched (HumanoidAnim "frenzy"); never over another gesture.
	if on and _anim.gesture == "":
		_anim.gesture = "frenzy"
	elif not on and _anim.gesture == "frenzy":
		_anim.gesture = ""


func _downed_idle() -> void:
	## Kneeling boss: breathes hard (the pose does that) and watches Alex when he's near.
	if not _player:
		return
	var local := _model.global_basis.inverse() * (_player.global_position - global_position)
	var near := local.length() < 9.0
	_anim.look = _anim.look.lerp(Vector2(clampf(atan2(local.x, local.z), -1.0, 1.0), -0.25) if near else Vector2.ZERO, 0.05)


func _go(p: Vector3, speed: float, delta: float) -> float:
	var to := p - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.5:
		_stop(delta)
		return d
	var dir := to / d
	# slide around obstacles: if we're not moving, veer sideways for a moment
	if Vector2(velocity.x, velocity.z).length() < speed * 0.25:
		_stuck += delta
	else:
		_stuck = maxf(_stuck - delta, 0.0)
	if _stuck > 0.6:
		dir = (dir + Vector3(-dir.z, 0, dir.x) * _strafe * 1.5).normalized()
		if _stuck > 1.6:
			_stuck = 0.0
			_strafe = -_strafe
	velocity.x = move_toward(velocity.x, dir.x * speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 20.0 * delta)
	_face(global_position + dir, delta, 8.0)
	_anim.aim = 0.0
	return d


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)


func _face(p: Vector3, delta: float, rate: float) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(to.x, to.z), rate * delta)


func _set_state(s: State) -> void:
	var was := state
	state = s
	_t_state = 0.0
	if s == State.CHASE:
		awareness = 1.0
		if was != State.CHASE:
			spotted_t = 0.0
			if is_physics_processing():
				get_tree().call_group("screen_fx", "spike", Feel.SPIKE_CHASE)  # the Mark flares: it's on him
	if s == State.CHASE and was != State.CHASE and is_physics_processing():
		Snd.sfx("enemy_alert" if randf() < 0.5 else "growl", global_position)
	Snd.threat(s == State.CHASE and is_physics_processing(), self)
	if s == State.SEARCH and not _spots.is_empty():
		_check = _spots.duplicate()
		_check.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return a.distance_to(global_position) < b.distance_to(global_position))


func can_see_player() -> bool:
	if not _player or _player.dead:
		return false
	var eye := global_position + Vector3.UP * 1.6
	var chest: Vector3 = _player.global_position + Vector3.UP * 1.0
	var to := chest - eye
	var d := to.length()
	var vis: float = _player.visibility()
	if d > sight_range * vis:
		return false
	var close := 0.8 if _player.get("crouching") else 3.0  # sneaking up from behind (takedowns)
	if d > close and rad_to_deg(_model.global_basis.z.angle_to(to)) > fov_deg / 2.0:
		return false
	for s in get_tree().get_nodes_in_group("smoke"):
		if s.blocks(eye, chest):
			return false
	var q := PhysicsRayQueryParameters3D.create(eye, chest, 1, [get_rid(), _player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func hear(pos: Vector3, radius: float) -> void:
	if state in [State.DEAD, State.DOWN, State.STUNNED, State.CHASE]:
		return
	if pos.distance_to(global_position) < radius * hearing:
		_target = pos
		_set_state(State.SUSPICIOUS)


func hit(dmg: float, point: Vector3, flare := false) -> void:
	if not is_physics_processing():
		return  # frozen for a cutscene: fire / stray shots can't down a boss mid-scene
	if state == State.DOWN:
		kill()  # shooting a kneeling boss is the KILL choice
		return
	if state == State.DEAD:
		return
	if _player and point != global_position:  # fire / scripted hits land at the enemy's origin: not the player's aim
		learn("ranged", 1.0 if _player.global_position.distance_to(global_position) > 7.0 else 0.0, 0.15)
		var swung: bool = _player.get("_strike_t") != null and float(_player.get("_strike_t")) >= 0.0
		learn("melee", 1.0 if swung else 0.0, 0.15 if swung else 0.08)
		_hit_from = (_player.global_position - global_position).normalized()
	_rage = minf(_rage + (0.06 if boss else 0.12), 1.0)
	Snd.sfx("enemy_hit", global_position, 0.0, Feel.pitch())
	_flash()
	if point.y - global_position.y > 1.5 * _model_scale.y:
		dmg *= 2.0  # headshot
	if state == State.STUNNED or _calling > 0.0:
		dmg *= 1.5
	if state != State.CHASE:
		dmg *= shadow_bonus
	if state != State.STUNNED:
		dmg *= armor
	if flare and flare_stun > 0.0:
		stagger(flare_stun)
	_anim.flinch = 1.0
	if state != State.STUNNED:
		_target = _player.global_position
		_unseen = 0.0
		_set_state(State.CHASE)
	if invulnerable:
		stagger(0.8)
		return
	_take(dmg)


func _take(dmg: float) -> void:
	health -= dmg
	damaged.emit(self)
	if health <= 0.0:
		health = 0.0
		if boss:
			_set_state(State.DOWN)
			_attack = -1.0
			_throw = -1.0
			_cancel_moves()
			_end_call(false)  # lit for the spare / kill scene
			_anim.attack = -1.0
			_anim.down_pose = DOWN_POSES.pick_random()  # beaten, but never twice the same way for sure
			_anim.crouching = true
			_anim.aim = 0.0
			downed.emit(self)
		else:
			kill()


func can_takedown(by: Node3D) -> bool:
	## Stealth takedown: unaware (not chasing), alive, `by` close behind its back.
	if state in [State.CHASE, State.DOWN, State.DEAD]:
		return false
	var to := by.global_position - global_position
	to.y = 0.0
	if to.length() > 1.8:
		return false
	return rad_to_deg((-_model.global_basis.z).angle_to(to)) < TAKEDOWN_CONE / 2.0


func takedown() -> void:
	## Marked One: dies. Boss: 25% max health (× shadow_bonus) + 2 s stun. Invulnerable: stun only.
	learn("stealth", 1.0)
	if not (boss or invulnerable):
		kill()
		return
	_anim.flinch = 1.0
	if not invulnerable:
		_take(max_health * 0.25 * shadow_bonus)
	stun(2.0)


func crush(frac: float, stun_t: float) -> void:
	## Heavy scripted hit (a dropped bell): `frac` of max health, ignores armor, then a stun.
	if state in [State.DOWN, State.DEAD] or not is_physics_processing():
		return  # frozen by a cutscene
	_anim.flinch = 1.0
	_take(max_health * frac)
	stun(stun_t)


func asthma_attack() -> void:
	## GasCloud with vents reversed: coughing fit, then a short grace to stagger out of the gas.
	if not asthma or _asthma_cd > 0.0:
		return
	_asthma_cd = asthma_stun + 1.5
	stun(asthma_stun)


func stagger(t: float) -> bool:
	## A stun the player caused (melee blow, flare, fire): resisted, so no enemy can be stun-locked. Back-to-back
	## stuns get shorter (more so against a player who leans on them), a guard window after each stun shrugs the
	## next one off (a flinch), a boss's committed swing can't be knocked out by a light blow, and every stun
	## angers it. Scripted stuns (bells, gas, light, cutscenes) use stun() and always land. True if stunned.
	if state in [State.DEAD, State.DOWN, State.STUNNED] or not is_physics_processing():
		return false  # already reeling: a stun can't be stacked onto (or held on) a stunned enemy
	learn("stun", 1.0, 0.12)
	_rage = minf(_rage + (0.25 if boss else 0.15), 1.0)
	if _guard > 0.0 or (boss and _attack >= 0.3 and t < 1.0):
		_anim.flinch = maxf(_anim.flinch, 0.5)
		return false
	var k := 1.0 / (1.0 + _stun_tol * (1.0 + float(habits().stun)))
	_stun_tol += 1.5 if boss else 1.0
	stun(t * k)
	return true


func stun(t: float) -> void:
	if state in [State.DEAD, State.DOWN] or not is_physics_processing():
		return
	_stun = maxf(_stun, t)
	_attack = -1.0
	_throw = -1.0
	_cancel_moves()
	_end_call()
	_anim.attack = -1.0
	_anim.aim = 0.0
	_anim.crouching = t > 1.5
	_set_state(State.STUNNED)


func kill() -> void:
	if state == State.DEAD:
		return
	var was_down := state == State.DOWN
	_set_state(State.DEAD)
	Snd.sfx("enemy_death", global_position)
	_end_call(false)
	_cancel_moves()
	remove_from_group("enemies")
	collision_layer = 0
	velocity = Vector3.ZERO
	_anim.attack = -1.0
	_anim.aim = 0.0
	_anim.speed = 0.0
	_anim.look = Vector2.ZERO
	_fall(was_down)
	if drop.is_valid():
		drop.call(global_position)
	died.emit(self)
	get_tree().create_timer(30.0).timeout.connect(queue_free)


func _fall(was_down: bool) -> void:
	## The body goes down away from the killing blow (blown back, pitched forward, spun to the side) or folds
	## at the knees first, never quite the same twice. A kneeling boss topples from its kneel.
	var from := _model.global_basis.inverse() * _hit_from  # model space: +z = the blow came from in front
	var kind: String
	if was_down:
		kind = {"sit_back": "back", "hands_ground": "front"}.get(_anim.down_pose, ["back", "side", "front"].pick_random())
	else:
		var r := randf()
		kind = "crumple" if r < 0.25 else ("side" if r < 0.45 else ("back" if from.z >= 0.0 else "front"))
		_anim.crouching = false
	var side := signf(from.x) if absf(from.x) > 0.2 else (1.0 if randf() < 0.5 else -1.0)
	var tw := create_tween()
	if kind == "crumple":  # knees give first, then the rest pitches over
		_anim.down_pose = ["kneel", "hands_ground"].pick_random()
		_anim.crouching = true
		tw.tween_interval(0.45)
		kind = "front" if randf() < 0.6 else "side"
	var t := randf_range(0.45, 0.65)
	var rot := {"back": Vector3(-PI / 2.0, 0.0, 0.0), "front": Vector3(PI / 2.0, 0.0, 0.0),
		"side": Vector3(0.0, 0.0, -side * PI / 2.0)}[kind] as Vector3
	var lift := {"back": 0.13, "front": 0.15, "side": 0.18}[kind] as float
	var twist := randf_range(-0.5, 0.5) + (side * 0.8 if kind == "side" else 0.0)
	tw.tween_property(_model, "rotation", _model.rotation + rot + Vector3(0.0, twist, 0.0), t) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_model, "position:y", lift, t)
	tw.tween_property(_model, "rotation:x", _model.rotation.x + rot.x * 0.94, 0.12)  # a small bounce as it lands
	tw.tween_property(_model, "rotation:x", _model.rotation.x + rot.x, 0.1)
	tw.tween_callback(func() -> void: _anim.set_process(false))


func lose_track(p: Vector3) -> void:
	## Tension director: after a catch the hunter wanders off to search somewhere else.
	_attack = -1.0
	_anim.attack = -1.0
	_cancel_moves()
	_target = p
	_unseen = 99.0
	_set_state(State.SEARCH)
	awareness = 0.0  # it has to see Alex properly again
	_t_sense = 3.0  # blind for a moment


func reset_to(pos: Vector3) -> void:
	## Checkpoint reload: back to full health at pos, patrolling.
	global_position = pos
	health = max_health
	_stun = 0.0
	_attack = -1.0
	_throw = -1.0
	_anim.attack = -1.0
	_anim.crouching = false
	_end_call()
	_call_t = call_interval
	_gas_t = 2.5
	_wait = 0.0
	_cancel_moves()
	_rage = 0.0
	_stun_tol = 0.0
	_guard = 0.0
	awareness = 0.0
	_anim.down_pose = ""
	_anim.look = Vector2.ZERO
	_spots.clear()
	_check.clear()
	_set_state(State.PATROL)
	_target = patrol[0]
