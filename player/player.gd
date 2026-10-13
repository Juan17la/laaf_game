extends CharacterBody3D
## Third-person survival-horror controller (RF-01): walk, sprint, crouch, jump (coyote + buffer),
## dodge roll (i-frames), knee slide (crouch while sprinting), mantle low walls, aim + shoot
## (see weapons.gd for the swap-shot double tap), flashlight, over-the-shoulder camera.
## Emits noise to the "enemies" group; enemies call hurt() / is_hidden() / visibility().
## Chapter 2: carry (both hands, walk only), gas mask + filter, throwable bottles (G), stealth takedown (E).
## Chapter 3: smoke cans (T, SmokeCloud breaks line of sight), Elena's tea (H, Mark -15), Elena's jacket
## (mark_resist). Above 50% Mark every noise carries further (gameplay.md §8: they sense you).
## Weapons (weapons.gd): guns, Owen's bow (hold aim to draw, fire looses), the fire axe and nail bat, and the
## fists: B / middle mouse (or fire with nothing to shoot) strikes with whatever is in hand. The arms hold every weapon and
## the carried battery by IK onto its real grips (_hold → HumanoidAnim.ik).

signal died
signal interacted(target: Node)
signal hid(pos: Vector3)  ## the player just became hidden (is_hidden() went true) here
signal marked(gain: float)  ## a hit raised the Mark by `gain` % (screen spike, the Veil's Eye note)
signal beat  ## a heartbeat thudded (low health; the HUD pulses with it)
signal fell  ## dropped out of the world (below FALL_Y): the running chapter director puts Alex back at its checkpoint

@export var walk_speed := 2.8
@export var sprint_speed := 5.6
@export var crouch_speed := 1.4
@export var aim_speed := 2.0
@export var jump_velocity := 4.6
@export var air_control := 6.0
@export var roll_speed := 7.5
@export var roll_time := 0.45
@export var roll_iframes := 0.35  ## seconds of invulnerability at the start of a roll
@export var slide_speed := 8.5
@export var slide_time := 0.75
@export var stamina_max := 140.0
@export var sprint_cost := 20.0  ## per second
@export var roll_cost := 22.0
@export var jump_cost := 10.0
@export var slide_cost := 15.0
@export var stamina_regen := 24.0
@export var health_max := 200.0  ## doubled: fights are fast and enemies adapt
@export var regen_cap := 0.3  ## health regenerates on its own only up to this fraction
@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 3.0
@export var climb_max := 1.4  ## "low wall" height limit

const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.35  ## tall enough for the crouched / sliding head: it never pokes through low ceilings
const FALL_Y := -30.0  ## below this Alex has fallen out of the world
const COYOTE := 0.12
const JUMP_BUFFER := 0.12
const GAS_DPS := 6.0  ## health per second breathing gas unprotected
const FILTER_TIME := 45.0  ## seconds of gas one filter lasts
const TAKEDOWN_RANGE := 1.6
const THROW_RANGE := 22.0  ## bottles / smoke cans land on the crosshair up to this far
const ARM_REACH := 0.95  ## shoulder → muzzle when aiming: a wall closer than this tucks the gun in
const CAM_CLEAR := 0.22  ## m kept between the camera rig and any wall (a sphere, so thin posts count too)
const ASH_ROOF := 30.0  ## m: anything over Alex's head this close (a roof, a ceiling) and the falling ash fades out
const ASH_FADE := 0.6  ## s
const ItemFx := preload("res://scripts/item_fx.gd")
const WEAPON_MODELS := {"revolver": "res://models/item_revolver.glb", "flare": "res://models/item_flare_gun.glb",
	"shotgun": "res://models/item_shotgun.glb", "bow": "res://models/item_bow.glb", "axe": "res://models/item_axe.glb",
	"bat": "res://models/item_bat.glb"}
const MUZZLE := {"revolver": Vector3(0, 0.06, -0.24), "flare": Vector3(0, 0.06, -0.2),
	"shotgun": Vector3(0, 0.045, -0.74)}  ## weapon model space
## weapon model (grip at origin, business end -Z, +Y up) → hand bone (fingers -Y, thumb side +Z). Pistol grips
## (and the bow's) stand upright in the fist, barrel along the fingers; long grips (the shotgun's wrist, the axe
## and bat handles) run through the fist, thumb toward the business end.
const GRIP := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)), Vector3(0, -0.06, -0.02))
const LONG_GRIP := Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)), Vector3(0, -0.075, 0))
const SUPPORT := {"shotgun": Vector3(0, 0.0, -0.27), "axe": Vector3(0, 0, -0.4), "bat": Vector3(0, 0, -0.14)}  ## off hand
const BOW_TIPS := [Vector3(0, 0.62, 0.1), Vector3(0, -0.62, 0.1)]  ## where the string ties on (bow space)
const BOW_BRACE := 0.16  ## string at rest (bow space z); a full draw pulls the nock BOW_DRAW further back
const BOW_DRAW := 0.45
## Melee swings: weapon poses in model space (origin = right-hand grip, head direction) at strike progress t.
## The bat sweeps flat around the right side (pointing right, then at the target on contact, then left) and wraps
## over the left shoulder; the axe goes up behind the head, over the top and down through the target to the shins.
const SWINGS := {
	"swing": [[0.0, Vector3(-0.12, 1.25, 0.3), Vector3(0.1, 0.9, 0.3)], [0.3, Vector3(-0.26, 1.38, 0.14), Vector3(-0.5, 0.55, -0.67)],
		[0.39, Vector3(-0.24, 1.22, 0.3), Vector3(-0.95, 0.12, 0.25)], [0.45, Vector3(-0.02, 1.22, 0.45), Vector3(0.05, 0.08, 1.0)],
		[0.52, Vector3(0.24, 1.24, 0.38), Vector3(0.95, 0.05, 0.3)], [0.6, Vector3(0.4, 1.35, 0.3), Vector3(0.55, 0.5, -0.65)],
		[1.0, Vector3(-0.12, 1.25, 0.3), Vector3(0.1, 0.9, 0.3)]],
	"chop": [[0.0, Vector3(-0.12, 1.25, 0.3), Vector3(0.1, 0.9, 0.3)], [0.18, Vector3(-0.1, 1.68, 0.3), Vector3(0.0, 0.95, -0.25)],
		[0.35, Vector3(-0.05, 1.88, -0.14), Vector3(0.0, 0.4, -0.92)],
		[0.43, Vector3(-0.05, 1.8, 0.34), Vector3(0.0, 0.9, 0.45)], [0.5, Vector3(-0.03, 1.22, 0.58), Vector3(0.0, -0.1, 1.0)],
		[0.65, Vector3(0.0, 0.92, 0.52), Vector3(0.0, -0.85, 0.5)], [1.0, Vector3(-0.12, 1.25, 0.3), Vector3(0.1, 0.9, 0.3)]],
}
## Where each swing turns around (wind-up top, follow-through end): it eases to a stop only there, and is fastest
## midway between, on the contact key (hit_at).
const SWING_TURNS := {"swing": [0.0, 0.3, 0.6, 1.0], "chop": [0.0, 0.35, 0.65, 1.0]}

var stamina := stamina_max
var health := health_max
var mark := Feel.MARK_START  ## Mark meter 0..100 (gameplay.md §8; how it grows: Feel's MARK_* table)
var mark_cap: float = Feel.MARK_SOFT_CAP[3]  ## this chapter's soft cap (set by the director): past it hits mark less
var crouching := false
var aiming := false
var controls_enabled := true
var dead := false
var hidden_spots: Array[Vector3] = []  ## tall grass: crouching within 1.3 m hides the player
var carrying := ""  ## item held in both hands ("" = none): walk only, no guns
var gas_mask := false  ## owned
var mask_on := false
var mask_filter := 1.0  ## 0..1, drains while masked in gas
var bottles := 0
var smokes := 0
var teas := 0
var mark_resist := 1.0  ## Mark gain multiplier (Elena's rain jacket: 0.75)

var _exhausted := false
var _roll_left := 0.0
var _roll_dir := Vector3.ZERO
var _slide_left := 0.0
var _slide_dir := Vector3.ZERO
var _busy := false  # mantling
var _shoulder := 1.0
var _spawn: Vector3
var _coyote := 0.0
var _jump_buf := 0.0
var _was_air := false
var _fall_speed := 0.0
var _noise_t := 0.0
var _stride := 0.0  ## metres walked since the last footfall
var _beat_t := 0.0
var _hurt_cd := 0.0
var _aim_face := 0.0  ## keeps facing the aim briefly after a hip-fire shot
var _gun_meshes := {}
var _strike := {}  ## the melee strike being swung (a Weapons spec), empty = none
var _strike_t := -1.0  ## 0..1 through it
var _jab_left := false
var _combo := 0  ## punches that landed in a row: every third one hooks harder
var _draw := 0.0  ## bow: 0..1 drawn
var _rebound := 0.0  ## > 0: the axe / bat bounced off something it can't hurt (a wall, Owen on the hunt)
var _bow_string: Array[MeshInstance3D] = []
var _bow_arrow: Node3D
var _carry_mesh: Node3D
var _was_hidden := false
var _gas_frame := -10  ## physics frame of the last gas_exposure (several clouds count once)
var _cough_t := 0.0
var _meshes: Array[GeometryInstance3D] = []  ## Alex's body parts: shadow-only when the camera is inside him
var _cam_inside := false
var trauma := 0.0  ## 0..1 camera shake, stacks up and decays (Feel.TRAUMA_*); add_trauma()
var _shake_t := 0.0
var _hitstop := 0.0  ## > 0: a landed melee blow holds the swing still (Feel.HITSTOP)
var _cam_probe := SphereShape3D.new()
var _indoors := false  ## a roof over Alex's head: no ash falls (it used to drift through ceilings indoors)
var _ash_t := 0.0
var _ash_k := 1.0

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var shape: CapsuleShape3D = collider.shape
@onready var model: Node3D = $Model
@onready var anim: HumanoidAnim = $Anim
@onready var pivot: Node3D = $CameraPivot
@onready var pitch: Node3D = $CameraPivot/Pitch
@onready var arm: SpringArm3D = $CameraPivot/Pitch/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/Pitch/SpringArm3D/Camera3D
@onready var flashlight: SpotLight3D = $CameraPivot/Pitch/Flashlight
@onready var weapons: Weapons = $Weapons
@onready var hud: Node = $HUD
@onready var ash: GPUParticles3D = $Ash


func _ready() -> void:
	add_to_group("player")
	_spawn = global_position
	arm.add_excluded_object(get_rid())
	var probe := SphereShape3D.new()  # a sphere, not a ray: the near plane can't slice into walls at the edges
	probe.radius = 0.18
	arm.shape = probe
	_cam_probe.radius = CAM_CLEAR
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_build_guns()
	for m in model.find_children("*", "GeometryInstance3D", true, false):
		_meshes.append(m)
	weapons.changed.connect(_update_gun_meshes)
	weapons.fired.connect(_on_fired)
	weapons.reload_started.connect(_on_reload)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if controls_enabled:
			_look(event.relative * mouse_sensitivity * (0.6 if aiming else 1.0))
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	if not controls_enabled or dead:
		return
	if event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
		Snd.sfx("click", null, -8.0, 0.8)
	elif event.is_action_pressed("shoulder_swap"):
		_shoulder = -_shoulder
	elif event.is_action_pressed("mask"):
		toggle_mask()
	elif event.is_action_pressed("throw"):
		throw_bottle()
	elif event.is_action_pressed("smoke"):
		throw_smoke()
	elif event.is_action_pressed("tea"):
		drink_tea()
	elif event.is_action_pressed("crouch"):
		if _sprinting() and is_on_floor() and _slide_left <= 0.0 and stamina >= slide_cost:
			_start_slide()
		else:
			_set_crouch(not crouching)
	elif event.is_action_pressed("jump") and carrying == "":
		_jump_buf = JUMP_BUFFER
	elif event.is_action_pressed("roll"):
		_start_roll()
	elif event.is_action_pressed("fire") and carrying == "":
		if weapons.melee() or weapons.dry():
			_melee()  # nothing to shoot: swing what's in hand (fists, gun butt, axe, bat)
		elif weapons.gun() == "bow":
			_loose()
		elif weapons.request_fire():
			_fire()
		elif weapons.loaded.get(weapons.gun(), 1) <= 0 and weapons.reserve.get(weapons.gun(), 1) <= 0:
			Snd.sfx("dry")  # empty and nothing to reload with
	elif event.is_action_pressed("melee") and carrying == "":
		_melee()
	elif event.is_action_pressed("reload"):
		weapons.reload()
	elif event.is_action_pressed("swap_weapon"):
		weapons.swap()
	elif event.is_action_pressed("weapon_1"):
		weapons.swap(0)
	elif event.is_action_pressed("weapon_2"):
		weapons.swap(1)
	elif event.is_action_pressed("weapon_3"):
		weapons.swap(2)
	elif event.is_action_pressed("weapon_4"):
		weapons.swap(3)
	elif event.is_action_pressed("weapon_5"):
		weapons.swap(4)
	elif event.is_action_pressed("weapon_6"):
		weapons.swap(5)
	elif event.is_action_pressed("interact"):
		var t: Node = takedown_target()
		if t:
			_takedown(t)
			return
		t = interact_target()
		if t:
			interacted.emit(t)
			t.interact(self)


func _look(delta: Vector2) -> void:
	pivot.rotate_y(-delta.x)
	pitch.rotation.x = clampf(pitch.rotation.x - delta.y, -1.2, 0.8)


# ------------------------------------------------------------------ movement

func _sprinting() -> bool:
	return Input.is_action_pressed("sprint") and not _exhausted and not aiming and carrying == "" \
		and _move_dir().length() > 0.1


func _move_dir() -> Vector3:
	if not controls_enabled or dead:
		return Vector3.ZERO
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return pivot.global_basis * Vector3(input.x, 0.0, input.y)


func _physics_process(delta: float) -> void:
	if controls_enabled:
		_look(Input.get_vector("look_left", "look_right", "look_up", "look_down") * stick_sensitivity * delta)
	if global_position.y < FALL_Y:
		velocity = Vector3.ZERO
		if fell.get_connections().is_empty():
			global_position = _spawn  # no director (a bare player scene): back to where it started
		else:
			fell.emit()  # the director respawns Alex at its last checkpoint (Chapter1Director._on_fell)
	_hurt_cd = maxf(_hurt_cd - delta, 0.0)
	_heartbeat(delta)
	_aim_face = maxf(_aim_face - delta, 0.0)
	var h := is_hidden()
	if h and not _was_hidden:
		hid.emit(global_position)
	_was_hidden = h
	if weapons.tick(delta) and controls_enabled and carrying == "" and Weapons.GUNS[weapons.gun()].kind == "gun":
		_fire()
	if weapons.gun() == "bow" and weapons.loaded.bow <= 0:
		weapons.reload()  # nock the next arrow
	if _hitstop > 0.0:  # the blow landed: the swing (and the body's pose) hold for a beat
		_hitstop -= delta
		if _hitstop <= 0.0:
			anim.set_process(true)
	else:
		_advance_strike(delta)
	if _busy or dead:
		_animate(0.0)
		return

	aiming = controls_enabled and Input.is_action_pressed("aim") and _roll_left <= 0.0 and carrying == ""
	var dir := _move_dir()
	var sprinting := _sprinting()
	if sprinting and crouching and _slide_left <= 0.0:
		_set_crouch(false)
		sprinting = not crouching

	# jump: coyote time after leaving a ledge, buffered presses just before landing; mantle first
	var on_floor := is_on_floor()
	_coyote = COYOTE if on_floor else maxf(_coyote - delta, 0.0)
	_jump_buf = maxf(_jump_buf - delta, 0.0)
	if _jump_buf > 0.0 and _roll_left <= 0.0:
		if _try_climb():
			_jump_buf = 0.0
			return
		if _coyote > 0.0 and stamina >= jump_cost * 0.5:
			var carry := _slide_dir * slide_speed * 0.8 if _slide_left > 0.0 else Vector3.ZERO
			_end_slide()
			if crouching:
				_set_crouch(false)
			velocity.y = jump_velocity
			if carry != Vector3.ZERO:  # slide-jump keeps the momentum
				velocity.x = carry.x
				velocity.z = carry.z
			stamina = maxf(stamina - jump_cost, 0.0)
			_jump_buf = 0.0
			_coyote = 0.0
			noise(5.0)
			Snd.sfx("jump", null, -6.0)

	var speed := crouch_speed if crouching else (sprint_speed if sprinting else walk_speed)
	if aiming:
		speed = minf(speed, aim_speed)
	if _strike_t >= 0.0:
		speed *= 0.45  # a swing commits the feet
	if global_position.y < -0.35:
		speed *= 0.5  # wading in the lake
	var target := dir * speed
	var accel := 22.0 if on_floor else air_control
	if _roll_left > 0.0:
		_roll_left -= delta
		target = _roll_dir * roll_speed
		accel = 60.0
	elif _slide_left > 0.0:
		_slide_left -= delta
		var k := _slide_left / slide_time
		target = _slide_dir * slide_speed * (0.35 + 0.65 * k)
		accel = 40.0
		if _slide_left <= 0.0 or not on_floor:
			_end_slide()
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if not on_floor:
		velocity.y -= gravity * delta
		_fall_speed = -velocity.y

	if sprinting and _slide_left <= 0.0:
		stamina = maxf(stamina - sprint_cost * delta, 0.0)
		_exhausted = stamina <= 0.0
	elif _roll_left <= 0.0 and _slide_left <= 0.0 and on_floor:
		stamina = minf(stamina + stamina_regen * delta, stamina_max)
		if stamina > 30.0:
			_exhausted = false
	if health < health_max * regen_cap:
		health = minf(health + 1.5 * delta, health_max * regen_cap)

	move_and_slide()
	if is_on_floor() and _was_air and _fall_speed > 3.0:
		noise(6.0)  # landing thud
		Snd.sfx("land", global_position, minf(_fall_speed - 8.0, 0.0) * 0.5)
	_was_air = not is_on_floor()

	_update_ash(delta)
	_emit_step_noise(delta, Vector2(velocity.x, velocity.z).length(), sprinting)
	_footsteps(delta, Vector2(velocity.x, velocity.z).length(), sprinting)
	_face(delta)
	_animate(delta)
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	## Over-the-shoulder offset without seeing through walls: the spring arm only guards the space
	## behind its own origin, so the sideways shoulder offset is ray-clamped first (snaps in, eases out).
	var low := crouching or _slide_left > 0.0
	pivot.position.y = lerpf(pivot.position.y, 1.1 if low else 1.55, 8.0 * delta)
	var zoom := aiming and not weapons.melee()  # a melee "aim" is a ready stance: no zoom
	var want := (0.55 if zoom else 0.65) * _shoulder
	var side := pitch.global_basis.x * signf(want)
	want = signf(want) * absf(want) * _clear_along(pivot.global_position, side * absf(want))
	arm.position.x = want if absf(want) < absf(arm.position.x) else lerpf(arm.position.x, want, 8.0 * delta)
	arm.spring_length = lerpf(arm.spring_length, 1.25 if zoom else (1.8 if aiming else 2.2), 10.0 * delta)
	camera.fov = lerpf(camera.fov, 48.0 if zoom else 65.0, 10.0 * delta)  # (a shot's FOV punch eases back here)
	# trauma shake: frustum offset + roll, so the aim ray (camera position, -Z) never moves
	trauma = maxf(trauma - Feel.TRAUMA_DECAY * delta, 0.0)
	_shake_t += delta * Feel.SHAKE_FREQ
	var sk := trauma * trauma * Feel.shake
	camera.h_offset = Feel.SHAKE_OFFSET * sk * (sin(_shake_t * 1.0) + 0.5 * sin(_shake_t * 2.7 + 1.3))
	camera.v_offset = Feel.SHAKE_OFFSET * sk * (sin(_shake_t * 1.3 + 2.1) + 0.5 * sin(_shake_t * 3.1))
	camera.rotation.z = Feel.SHAKE_ROLL * sk * sin(_shake_t * 0.9 + 0.7)
	# camera squeezed into Alex (back to a wall): hide his body instead of rendering the inside of his head
	var inside := camera.global_position.distance_to(global_position + Vector3.UP * pivot.position.y) < 0.55
	if inside != _cam_inside:
		_cam_inside = inside
		for m in _meshes:
			if is_instance_valid(m):
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if inside \
					else GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _clear_along(from: Vector3, motion: Vector3) -> float:
	## 0..1: how far a CAM_CLEAR sphere gets from `from` along `motion` before touching world geometry (layer 1),
	## never Alex. The spring arm's own origin is moved by this, so it never starts inside a wall: a sphere, not a
	## ray, so a pole or a corner beside the shoulder can't slip between the camera and Alex either.
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _cam_probe
	q.transform = Transform3D(Basis(), from)
	q.motion = motion
	q.collision_mask = 1
	q.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(q, 1).is_empty():
		return 0.0  # the pivot itself is tight against something: the camera stays right behind the head
	return space.cast_motion(q)[0]


func _update_ash(delta: float) -> void:
	## The falling ash (the Ash particles round Alex) fades out under a roof and back in outside.
	_ash_t -= delta
	if _ash_t <= 0.0:
		_ash_t = 0.3
		var head := global_position + Vector3.UP * 1.7
		_indoors = not _ray(head, head + Vector3.UP * ASH_ROOF).is_empty()
	_ash_k = move_toward(_ash_k, 0.0 if _indoors else 1.0, delta / ASH_FADE)
	ash.amount_ratio = maxf(_ash_k, 0.001)
	var m := (ash.draw_pass_1 as PrimitiveMesh).material as StandardMaterial3D
	if m:
		m.albedo_color.a = 0.75 * _ash_k


func add_trauma(amount: float) -> void:
	## Camera shake: own shots, blows landed, hits taken (Feel.TRAUMA_*). Stacks to 1, decays by itself.
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	## World geometry only (layer 1), never Alex himself.
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()]))


func _face(delta: float) -> void:
	if aiming or _aim_face > 0.0:
		var fwd := -pivot.global_basis.z
		model.rotation.y = lerp_angle(model.rotation.y, atan2(fwd.x, fwd.z), 18.0 * delta)
		return
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length() > 0.2:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(velocity.x, velocity.z), 10.0 * delta)


func _start_roll() -> void:
	if not is_on_floor() or _roll_left > 0.0 or stamina < roll_cost or _busy or carrying != "":
		return
	var dir := _move_dir()
	_end_slide()
	_roll_left = roll_time
	_roll_dir = dir.normalized() if dir.length() > 0.1 else model.global_basis.z
	model.rotation.y = atan2(_roll_dir.x, _roll_dir.z)
	stamina -= roll_cost
	noise(6.0)
	Snd.sfx("jump", null, -2.0, 0.8)


func _start_slide() -> void:
	var dir := _move_dir()
	_slide_dir = dir.normalized() if dir.length() > 0.1 else model.global_basis.z
	_slide_left = slide_time
	stamina -= slide_cost
	crouching = true
	shape.height = CROUCH_HEIGHT
	collider.position.y = shape.height / 2.0
	noise(7.0)


func _end_slide() -> void:
	if _slide_left > 0.0 or crouching and _slide_dir != Vector3.ZERO:
		_slide_left = 0.0
		_slide_dir = Vector3.ZERO
		_set_crouch(false)  # stays crouched if a ceiling is in the way


func rolling_invulnerable() -> bool:
	return _roll_left > roll_time - roll_iframes


func _animate(delta: float) -> void:
	anim.speed = Vector2(velocity.x, velocity.z).length() if not _busy else 0.0
	anim.crouching = crouching and _slide_left <= 0.0
	anim.roll = 1.0 - _roll_left / roll_time if _roll_left > 0.0 else -1.0
	anim.airborne = not is_on_floor() and not _busy and _roll_left <= 0.0
	anim.vertical = velocity.y
	anim.sliding = _slide_left > 0.0
	anim.aim = move_toward(anim.aim, 1.0 if (aiming or _aim_face > 0.0) else 0.0, delta * 8.0)
	anim.aim_pitch = -pitch.rotation.x
	var hold: String = weapons.spec().hold
	anim.stance = {"long": -0.35, "bow": -1.2}.get(hold, 0.0) if carrying == "" else 0.0
	var block := 0.0
	if anim.aim > 0.0:
		var shoulder := global_position + Vector3.UP * (1.0 if crouching else 1.42)
		var aim_dir := -camera.global_basis.z
		var hit := _ray(shoulder, shoulder + aim_dir * ARM_REACH)
		if hit:
			block = clampf(1.0 - (shoulder.distance_to(hit.position) - 0.35) / (ARM_REACH - 0.35), 0.0, 1.0)
	anim.aim_block = move_toward(anim.aim_block, block, delta * 6.0)
	# head follows the camera unless it would have to look backwards
	var yaw := wrapf(pivot.rotation.y + PI - model.rotation.y, -PI, PI)
	anim.look = Vector2(yaw if absf(yaw) < 1.7 else 0.0, -pitch.rotation.x * 0.6)
	_hold(delta)


func _set_crouch(on: bool) -> void:
	if not on and test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT)):
		return  # ceiling in the way
	crouching = on
	shape.height = CROUCH_HEIGHT if on else STAND_HEIGHT
	collider.position.y = shape.height / 2.0


func _try_climb() -> bool:
	var fwd := model.global_basis.z
	var d := _move_dir()
	if d.length() > 0.1:
		fwd = d
	fwd.y = 0.0
	fwd = fwd.normalized()
	var space := get_world_3d().direct_space_state
	var top := global_position + fwd * 0.75 + Vector3.UP * (climb_max + 0.1)
	var ray := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (climb_max - 0.3), 1, [get_rid()])
	var hit := space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.7:
		return false
	var target: Vector3 = hit.position + Vector3.UP * 0.02
	if target.y - global_position.y < 0.5:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), target + Vector3.UP * (shape.height / 2.0 + 0.05))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	if not space.intersect_shape(q, 1).is_empty():
		return false  # no room on top
	_busy = true
	velocity = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(self, "global_position:y", target.y, 0.22)
	tw.tween_property(self, "global_position", target, 0.18)
	tw.tween_callback(func() -> void: _busy = false)
	return true


# ------------------------------------------------------------------ guns

func _fire() -> void:
	var from := camera.global_position
	var dir := -camera.global_basis.z
	# start the ray past the player so over-the-shoulder shots can't hit Alex's own back
	from += dir * (arm.spring_length * 0.9)
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5
	var spread := 1.0 if aiming else 3.0
	if moving:
		spread *= 1.6
	if not is_on_floor() or _roll_left > 0.0:
		spread *= 1.8
	var result := weapons.shoot(get_world_3d().direct_space_state, from, dir, [get_rid()], spread)
	_aim_face = 0.6
	var gun: String = result.gun
	anim.recoil = Feel.RECOIL[gun]
	add_trauma(Feel.TRAUMA_SHOT[gun])
	noise(Weapons.GUNS[gun].noise)
	Snd.sfx("gun_" + gun, global_position + Vector3.UP * 1.4, 0.0, Feel.pitch())
	_tracer(result.point, Weapons.GUNS[gun].color, gun == "flare")
	_impacts(result.impacts, dir, gun)
	if result.collider and result.collider.has_method("hit"):
		hud.hit_marker(result.double_tap)


func _impacts(impacts: Array, dir: Vector3, gun: String) -> void:
	## Where the shot landed: dark spatter and a hitstop on what bleeds, sparks and chips off the rest.
	var stopped := {}
	for im in impacts:
		var at: Vector3 = im[0]
		var normal: Vector3 = im[1]
		var body: Object = im[2]
		if body is Enemy:
			ItemFx.burst(get_parent(), at, "splatter", (normal - dir).normalized())
			if not stopped.has(body):  # one freeze per body, not per pellet
				stopped[body] = true
				body.hitstop(Feel.HITSTOP[gun])
		elif not (body and body.has_method("hit")):  # a wall, the ground: the round sparks off it
			ItemFx.burst(get_parent(), at, "ricochet", normal)
			ItemFx.burst(get_parent(), at, "thud", normal, 3)


func _on_fired(gun: String, double_tap: bool) -> void:
	if double_tap:
		hud.banner("DOUBLE TAP", Color(1.0, 0.8, 0.3), 0.7)
	pitch.rotation.x = clampf(pitch.rotation.x + Feel.KICK_PITCH[gun], -1.2, 0.8)  # muzzle climb
	camera.fov += Feel.KICK_FOV[gun]  # a punch outward; _update_camera eases it back


func _on_reload(gun: String, spent: int) -> void:
	## The revolver's cylinder swings out: the spent brass drops.
	var m: Node3D = _gun_meshes.get(gun)
	Snd.sfx("reload", global_position, -4.0)
	if gun == "revolver" and spent > 0 and m:
		ItemFx.burst(get_parent(), m.to_global(Vector3(0, 0.05, -0.05)), "casings", Vector3.DOWN, spent)
	elif gun == "shotgun" and spent > 0 and m:  # the barrels break open: the red hulls pop out
		ItemFx.burst(get_parent(), m.to_global(Vector3(0, 0.05, -0.1)), "shells", m.global_basis.z + Vector3.UP, spent)


func _muzzle() -> Vector3:
	var g := weapons.gun()
	var m: Node3D = _gun_meshes.get(g)
	return m.to_global(MUZZLE[g]) if m else global_position + Vector3.UP * 1.4


func _tracer(to: Vector3, color: Color, flare: bool) -> void:
	var from := _muzzle()
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var length := from.distance_to(to)
	mesh.size = Vector3(0.02 if not flare else 0.06, 0.02 if not flare else 0.06, length)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	line.mesh = mesh
	get_parent().add_child(line)
	line.global_position = (from + to) / 2.0
	if length > 0.01:
		line.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	var shot_dir := (to - from).normalized() if length > 0.01 else -camera.global_basis.z
	ItemFx.burst(get_parent(), from, "muzzle_flare" if flare else "muzzle", shot_dir, 22 if weapons.gun() == "shotgun" else 0)
	ItemFx.burst(get_parent(), from, "gunsmoke", shot_dir)
	if flare:  # the flare sputters sparks all the way out
		var trail := ItemFx.emit("flare_trail")
		get_parent().add_child(trail)
		trail.global_position = from
		var tt := trail.create_tween()
		tt.tween_property(trail, "global_position", to, length / 45.0)
		tt.tween_callback(func() -> void: trail.emitting = false)
		tt.tween_interval(trail.lifetime)
		tt.tween_callback(trail.queue_free)
	var flash := OmniLight3D.new()
	flash.light_color = color
	flash.light_energy = 3.0
	flash.omni_range = 5.0
	get_parent().add_child(flash)
	flash.global_position = from
	var tw := line.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25 if flare else 0.08)
	tw.tween_callback(line.queue_free)
	flash.create_tween().tween_property(flash, "light_energy", 0.0, 0.08).finished.connect(flash.queue_free)
	if flare:  # a flare keeps burning where it lands
		var ember := OmniLight3D.new()
		ember.light_color = color
		ember.light_energy = 2.5
		ember.omni_range = 7.0
		ember.set_script(load("res://scripts/flicker.gd"))
		get_parent().add_child(ember)
		ember.global_position = to + Vector3.UP * 0.2
		ember.add_child(ItemFx.emit("sparks"))
		get_tree().create_timer(6.0).timeout.connect(ember.queue_free)


func _build_guns() -> void:
	## Every weapon's model in its hand, hidden until drawn: guns, axe and bat in the right hand, the bow in the
	## left with a string the game draws (_update_bow). A plain stand-in shape until the .glb is imported.
	for id in Weapons.GUNS:
		var hand := model.find_child("HandL" if id == "bow" else "HandR", true, false) as Node3D
		if not hand:
			return
		var root := Node3D.new()
		hand.add_child(root)
		root.transform = LONG_GRIP if Weapons.GUNS[id].hold in ["long", "melee"] else GRIP
		var path: String = WEAPON_MODELS[id]
		var ps: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if ps:
			root.add_child(ps.instantiate())
		else:  # stand-in: a grip and a shaft out to the business end (model space)
			var length: float = {"shotgun": 0.75, "axe": 0.75, "bat": 0.85, "bow": 0.12}.get(id, 0.24)
			var metal := _flat_mat(Color(0.6, 0.12, 0.06) if id == "flare" else Color(0.14, 0.13, 0.12))
			for part in [[Vector3(0.035, 0.045, length), Vector3(0, 0.05, -length / 2.0)],
					[Vector3(0.035, 0.11, 0.05), Vector3(0, -0.02, 0.02)]]:
				var mi := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = part[0]
				b.material = metal
				mi.mesh = b
				mi.position = part[1]
				root.add_child(mi)
		if id == "bow":
			for i in 2:
				var mi := MeshInstance3D.new()
				var b := BoxMesh.new()
				b.size = Vector3(0.003, 0.003, 1.0)
				b.material = _flat_mat(Color(0.85, 0.82, 0.7))
				mi.mesh = b
				root.add_child(mi)
				_bow_string.append(mi)
			if ResourceLoader.exists("res://models/item_arrow.glb"):
				_bow_arrow = (load("res://models/item_arrow.glb") as PackedScene).instantiate()
				root.add_child(_bow_arrow)
		_gun_meshes[id] = root
	_update_gun_meshes()


func _update_gun_meshes() -> void:
	for id in _gun_meshes:
		_gun_meshes[id].visible = id == weapons.gun() and carrying == ""


# ------------------------------------------------------------------ handling: arms on the weapon, melee, bow

func _hold(delta: float) -> void:
	## Hands onto what they hold (IK targets in model space; the anim solves them last): the shotgun at low ready
	## or shouldered, the bow carried low or drawn to the cheek, axe / bat on the shoulder, up ready or mid-swing,
	## fists up in a guard or punching, the carried battery by its sides. Pistols keep their hand-animated aim.
	var t := {}
	anim.ik_pole.clear()  # (the bow sets the drawing elbow's)
	var c := anim.crouch_amount()
	var co := anim.crouch_offset()  # (where the crouch puts the hips: lower, and sat back over the feet)
	var drop := Vector3(0, co.y - 0.06, co.z + 0.22) * c  # crouched: everything sits lower, the arms out front
	var ad := Vector3(0, sin(anim.aim_pitch), cos(anim.aim_pitch))  # the aim, model space
	var id := weapons.gun()
	var sp := weapons.spec()
	var ready := clampf(anim.aim, 0.0, 1.0) * (1.0 - anim.aim_block)
	if carrying != "":  # palms flat on the battery's sides, fingers down
		t.R = Transform3D(Basis(), Vector3(-0.19, 1.16, 0.42) + drop)
		t.L = Transform3D(Basis(), Vector3(0.19, 1.16, 0.42) + drop)
	elif _strike_t >= 0.0 and anim.strike_style in ["swing", "chop"]:
		# eases in from wherever the weapon was held (on the shoulder, or up ready)
		var w := _melee_hold(sp.style, drop, ready).interpolate_with(_swing_pose(anim.strike_style, _strike_t, drop),
			smoothstep(0.0, 0.2, _strike_t))
		t.R = w * LONG_GRIP.affine_inverse()
		# the axe's hands slide together for the chop (the far hand couldn't reach overhead), apart again after
		var slide := 1.0 - 0.6 * smoothstep(0.0, 0.3, _strike_t) * (1.0 - smoothstep(0.65, 1.0, _strike_t)) \
			if anim.strike_style == "chop" else 1.0
		t.L = w * Transform3D(Basis(), SUPPORT.get(id, Vector3(0, 0, -0.3)) * slide) * LONG_GRIP.affine_inverse()
	elif _strike_t >= 0.0 and sp.hold == "long":  # butt-stroke: the whole gun drives forward
		var w := _long_pose(ad, drop, lerpf(ready, 1.0, smoothstep(0.0, 0.15, _strike_t)))  # up from low ready first
		w.origin += w.basis * Vector3(0, 0, -0.35) * sin(minf(_strike_t / _strike.hit_at, 1.0) * PI * 0.5) \
			* (1.0 - maxf(_strike_t - _strike.hit_at, 0.0) / (1.0 - _strike.hit_at))
		t.R = w * LONG_GRIP.affine_inverse()
		t.L = w * Transform3D(Basis(), SUPPORT.shotgun) * LONG_GRIP.affine_inverse()
	elif _strike_t >= 0.0:  # jab / gun-butt bash: the striking hand drives out along the aim and snaps back
		t = _guard(drop)
		var k := "L" if anim.strike_style == "jab_l" else "R"
		var h: float = _strike.hit_at
		# straight out from the guard, accelerating into the target, the fist turning over (palm down) as it lands;
		# the recoil snaps back quicker still
		var f := clampf(_strike_t / h, 0.0, 1.0)
		var out := f * f * (1.5 - 0.5 * f) if _strike_t < h else 1.0 - smoothstep(h, h + 0.5 * (1.0 - h), _strike_t)
		var sh := Vector3(0.2 if k == "L" else -0.2, 1.46, 0.0) + drop
		var fist := Transform3D(Basis(ad, (1.4 if k == "L" else -1.4) * out) * _fist(ad), sh + ad * 0.6 - Vector3(sh.x * 0.7, 0.06, 0))
		t[k] = (t[k] as Transform3D).interpolate_with(fist, out)
		if sp.hold == "bow":
			t.L = _bow_pose(ad, drop, 0.0) * GRIP.affine_inverse()
		elif sp.hold == "pistol" and k == "R":
			t.erase("L")
	else:
		match sp.hold:
			"long":
				var w := _long_pose(ad, drop, ready)
				t.R = w * LONG_GRIP.affine_inverse()
				t.L = w * Transform3D(Basis(), SUPPORT[id]) * LONG_GRIP.affine_inverse()
			"melee":
				var w := _melee_hold(sp.style, drop, ready)
				t.R = w * LONG_GRIP.affine_inverse()
				if ready > 0.05:
					t.L = w * Transform3D(Basis(), SUPPORT[id]) * LONG_GRIP.affine_inverse()
			"bow":
				var w := _bow_pose(ad, drop, ready)
				t.L = w * GRIP.affine_inverse()
				anim.ik_pole["R"] = Vector3(-1.0, 0.3, -0.6)  # drawing elbow out and back, level with the shoulder
				if ready > 0.05:  # the right hand hooks the string at the nock
					t.R = w * Transform3D(Basis(), Vector3(0.012, -0.015, BOW_BRACE + BOW_DRAW * _draw)) * GRIP.affine_inverse()
			"fists":
				if aiming or _aim_face > 0.0:  # (and just after a punch: the guard comes back, not the gun-aim arm)
					t = _guard(drop)
	if anim.throw >= 0.0:
		t.erase("L")  # the left hand is busy throwing
	for k in ["R", "L"]:
		if t.has(k):
			anim.ik[k] = t[k]
		anim.ik_w[k] = move_toward(anim.ik_w[k], 1.0 if t.has(k) else 0.0, delta * 10.0)
	_draw = move_toward(_draw, 1.0 if aiming and id == "bow" and weapons.loaded.bow > 0 and not weapons.busy() else 0.0,
		delta * (1.4 if aiming else 5.0))
	_update_bow()


func _toward(dir: Vector3, flip := false) -> Basis:
	## Basis with -Z along dir and +Y as close to up as it gets; flip (the axe, swung over the top): +X kept to the
	## right and +Y down when level, which stays continuous through vertical. Straight up / down only (+Y) or sideways
	## only (flip) fall back to BACK / up.
	var z := -dir.normalized()
	if flip:
		var x := Vector3.RIGHT - z * z.x
		if x.length() < 0.03:
			return Basis.looking_at(dir, Vector3.DOWN)
		x = x.normalized()
		return Basis(x, z.cross(x), z)
	return Basis.looking_at(dir, Vector3.BACK if absf(z.y) > 0.9995 else Vector3.UP)


func _fist(dir: Vector3) -> Basis:
	## A fist (hand bone) with the knuckles along dir, thumb up.
	var y := -dir.normalized()
	var z := (Vector3.UP - y * Vector3.UP.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


func _guard(drop: Vector3) -> Dictionary:
	## Both fists up by the chin.
	var up := _fist(Vector3(0, 0.55, 0.84))
	return {"R": Transform3D(up, Vector3(-0.13, 1.37, 0.27) + drop), "L": Transform3D(up, Vector3(0.12, 1.41, 0.31) + drop)}


func _long_pose(ad: Vector3, drop: Vector3, k: float) -> Transform3D:
	## The shotgun (model space): stock in the right shoulder pocket along the aim (k = 1), or at low ready with
	## the muzzle down and across the body (k = 0). Recoil shoves it back and up.
	var aim_b := _toward(ad)
	var aimed := Transform3D(aim_b, Vector3(-0.13, 1.45, 0.02) + drop - aim_b * Vector3(0, -0.035, 0.33))
	var low := Transform3D(_toward(Vector3(0.3, -0.45, 0.84)), Vector3(-0.15, 1.2, 0.22) + drop)
	var w := low.interpolate_with(aimed, k)
	w.origin += w.basis * Vector3(0, 0.03, 0.09) * anim.recoil
	return w


func _bow_pose(ad: Vector3, drop: Vector3, k: float) -> Transform3D:
	## The bow's grip (model space): at arm's length along the aim, a slight cant (k = 1), or carried low in the
	## left hand with the limbs upright (k = 0).
	# side-on: bow arm straight from the left shoulder, the arrow line down the middle to the chin
	var aimed := Transform3D(_toward(ad) * Basis(Vector3.BACK, 0.12), Vector3(0.0, 1.53, 0.12) + drop + ad * 0.6)
	var low := Transform3D(_toward(Vector3(0.05, -0.15, 1.0)), Vector3(0.25, 0.93, 0.1) + drop)
	return low.interpolate_with(aimed, k)


func _melee_hold(style: String, drop: Vector3, ready: float) -> Transform3D:
	## Axe / bat at rest on the shoulder (head up and out past it, not through it), or up ready (ready = 1).
	var rest := Transform3D(_toward(Vector3(-0.3, 0.9, -0.25).normalized(), style == "chop"), Vector3(-0.21, 1.17, 0.24) + drop)
	return rest.interpolate_with(_swing_pose(style, 0.0, drop), ready)


func _swing_pose(style: String, t: float, drop: Vector3) -> Transform3D:
	## Axe / bat at progress t: a smooth (Catmull-Rom / squad) path through its SWINGS keys, timed to ease in and out of
	## each SWING_TURNS point so the head accelerates into the contact and decelerates through the follow-through.
	var turns: Array = SWING_TURNS[style]
	var i := 0
	while i < turns.size() - 2 and t > turns[i + 1]:
		i += 1
	var s := lerpf(turns[i], turns[i + 1], smoothstep(turns[i], turns[i + 1], t))
	var keys: Array = SWINGS[style]
	var j := 0
	while j < keys.size() - 2 and s > keys[j + 1][0]:
		j += 1
	var a: Array = keys[j]
	var b: Array = keys[j + 1]
	var pa: Array = keys[j - 1] if j > 0 else [2.0 * a[0] - b[0], a[1], a[2]]
	var pb: Array = keys[j + 2] if j + 2 < keys.size() else [2.0 * b[0] - a[0], b[1], b[2]]
	var f := clampf((s - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	var bt: float = b[0] - a[0]
	var pt: float = pa[0] - a[0]
	var nt: float = pb[0] - a[0]
	var pos := (a[1] as Vector3).cubic_interpolate_in_time(b[1], pa[1], pb[1], f, bt, pt, nt)
	# orientations, not directions, are interpolated: a handle swinging past vertical keeps its twist
	var flip := style == "chop"
	var q := Quaternion(_toward(a[2], flip)).spherical_cubic_interpolate_in_time(Quaternion(_toward(b[2], flip)),
		Quaternion(_toward(pa[2], flip)), Quaternion(_toward(pb[2], flip)), f, bt, pt, nt)
	return Transform3D(Basis(q), pos + drop)


func _update_bow() -> void:
	## The string runs tip → nock → tip; the next arrow sits on it once nocked.
	if _bow_string.is_empty():
		return
	var nock := Vector3(0, 0, BOW_BRACE + BOW_DRAW * _draw)
	for i in 2:
		var tip: Vector3 = BOW_TIPS[i]
		(_bow_string[i].mesh as BoxMesh).size.z = tip.distance_to(nock)
		_bow_string[i].transform = Transform3D(Basis.looking_at(nock - tip, Vector3.RIGHT), (tip + nock) / 2.0)
	if _bow_arrow:
		_bow_arrow.visible = weapons.loaded.bow > 0 and not weapons.busy()
		_bow_arrow.position = nock + Vector3(0.012, 0, 0)


func _loose() -> void:
	## Bow: the arrow flies at the crosshair; a full draw (hold aim) flies faster and hits harder. Nearly silent.
	if not weapons.can_fire():
		return
	var k := maxf(_draw, 0.3)
	var bow: Node3D = _gun_meshes.get("bow")
	var from := bow.to_global(Vector3(0.012, 0, -0.1)) if bow else global_position + Vector3.UP * 1.45
	Arrow.fire(get_parent(), from, throw_target(Weapons.GUNS.bow.range), Weapons.GUNS.bow.damage * k, self,
		lerpf(18.0, 46.0, k))
	weapons.loose()
	anim.recoil = Feel.RECOIL.bow
	add_trauma(Feel.TRAUMA_SHOT.bow)
	Snd.sfx("bow", global_position + Vector3.UP * 1.4, 0.0, Feel.pitch())
	_draw = 0.0
	_aim_face = 0.6
	noise(Weapons.GUNS.bow.noise)


func _melee() -> void:
	## Strike with what's in hand: the axe chops, the bat swings, a gun (or an empty one) bashes with its butt,
	## bare hands jab left-right. Costs stamina; the blow lands at the spec's hit_at (_melee_hit).
	if _strike_t >= 0.0 or carrying != "" or _busy or _roll_left > 0.0 or dead or stamina < 3.0:
		return
	var sp := weapons.spec()
	if sp.kind != "melee":
		sp = Weapons.FISTS if sp.hold == "bow" else Weapons.BASH
	stamina = maxf(stamina - float(sp.stamina), 0.0)
	_strike = sp
	_strike_t = 0.0
	anim.strike = 0.0
	anim.strike_style = sp.style
	if sp.style == "jab":  # the bow hand stays on the bow
		anim.strike_style = "jab_l" if _jab_left and sp.hold == "fists" and weapons.gun() != "bow" else "jab_r"
		_jab_left = not _jab_left
	var fwd := -pivot.global_basis.z
	model.rotation.y = atan2(fwd.x, fwd.z)  # swing where the camera looks
	_aim_face = float(sp.time) + 0.2
	noise(float(sp.noise) * 0.4)
	Snd.sfx("swing", global_position, -3.0, randf_range(0.9, 1.1) * (0.85 if sp.style in ["swing", "chop"] else 1.0))


func _advance_strike(delta: float) -> void:
	if _strike_t < 0.0:
		return
	if _rebound > 0.0:  # the blow jars back up the arms toward the windup, then the strike ends
		_rebound -= delta
		_strike_t = maxf(_strike_t - delta * 2.4, 0.0)  # back through the wind-up to ready, so it ends where the hold is
		anim.strike = _strike_t
		if _rebound <= 0.0:
			_strike_t = -1.0
			anim.strike = -1.0
		return
	var before := _strike_t
	_strike_t += delta / float(_strike.time)
	anim.strike = minf(_strike_t, 1.0)
	if before < _strike.hit_at and _strike_t >= _strike.hit_at:
		_melee_hit()
	if _strike_t >= 1.0:
		_strike_t = -1.0
		anim.strike = -1.0


func _melee_hit() -> void:
	## The blow lands on everything hittable in a ball just ahead that Alex can actually reach (no hitting
	## through walls); axe and bat stagger what they hit, every third punch in a row hooks harder. A wall there
	## answers with a thud and dust.
	var sp := _strike
	var fwd := model.global_basis.z
	var chest := global_position + Vector3.UP * (0.95 if crouching else 1.3)
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.55
	q.shape = ball
	q.transform = Transform3D(Basis(), chest + fwd * (float(sp.reach) - 0.45))
	q.collision_mask = 0b11
	q.exclude = [get_rid()]
	var landed := false
	var heavy: bool = sp.style in ["swing", "chop"]
	var bounce := false
	for h in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var body: Object = h.collider
		if not (body is Node3D) or not body.has_method("hit"):
			continue
		var at: Vector3 = (body as Node3D).global_position + (Vector3.UP * 1.2 if body is CharacterBody3D else Vector3.ZERO)
		var wall := _ray(chest, at)
		if wall and wall.collider != body:
			continue
		ItemFx.burst(get_parent(), at, "impact", -fwd)
		if body is Enemy:
			ItemFx.burst(get_parent(), at, "splatter", (fwd + Vector3.UP * 0.4).normalized())
		landed = true
		if body.get("invulnerable"):
			bounce = bounce or heavy  # it can't be hurt: the axe / bat glances off
			if sp.style == "jab":
				continue  # bare fists don't stagger what bullets can't hurt
		var dmg := float(sp.damage)
		if sp.style == "jab":
			_combo += 1
			if _combo % 3 == 0:
				dmg *= 1.8
		body.hit(dmg, at)
		if body is Enemy:
			body.hitstop(Feel.HITSTOP.get(sp.style if sp.style in ["jab", "bash"] else weapons.gun(), 0.05))
		if body.get("state") == Enemy.State.DEAD:
			G.send("unlock", ["hands_on"])
		if float(sp.stun) >= 0.5 and body.has_method("stagger"):  # resisted: no stun-locking (Enemy.stagger)
			body.stagger(float(sp.stun) * (0.4 if body.get("boss") else 1.0))
	if landed:
		Snd.sfx("punch" if sp.style == "jab" else "melee_hit", chest + fwd, 0.0, Feel.pitch())
		hud.hit_marker(false)
		add_trauma(Feel.TRAUMA_MELEE.get(sp.style, 0.15))
		var hs: float = Feel.HITSTOP.get(sp.style if sp.style in ["jab", "bash"] else weapons.gun(), 0.05) * Feel.hitstop
		if hs > 0.0:  # our swing holds with the enemy it struck
			_hitstop = hs
			anim.set_process(false)
		pitch.rotation.x = clampf(pitch.rotation.x - 0.02, -1.2, 0.8)  # the jolt runs up the arms
		noise(float(sp.noise))
		if bounce:
			_bounce(chest + fwd * 0.9)
		return
	_combo = 0
	var wall := _ray(chest, chest + fwd * float(sp.reach))
	if wall:
		Snd.sfx("thud", wall.position, -4.0)
		ItemFx.burst(get_parent(), wall.position, "thud", wall.normal)
		noise(float(sp.noise) * 0.7)
		if heavy:
			_bounce(wall.position)


func _bounce(at: Vector3) -> void:
	## The axe / bat rebounds: sparks where it struck, the swing runs back, the camera jars.
	_rebound = 0.3
	ItemFx.burst(get_parent(), at, "sparks", Vector3.UP)
	pitch.rotation.x = clampf(pitch.rotation.x + 0.05, -1.2, 0.8)
	hud.banner("CLANG", Color(0.8, 0.8, 0.75), 0.4)


# ------------------------------------------------------------------ interaction, damage, noise

func interact_target() -> Node:
	## The nearest usable thing in reach that Alex can actually get his hands on: never through a wall or door.
	var best: Node = null
	var best_d := 2.2
	for n in get_tree().get_nodes_in_group("interactable"):
		if not n.is_inside_tree() or not n.get("enabled"):
			continue
		var d: float = n.global_position.distance_to(global_position + Vector3.UP * 0.9)
		if d < best_d and _within_reach(n.global_position):
			best_d = d
			best = n
	return best


func _within_reach(p: Vector3) -> bool:
	## Clear line from Alex's chest or eyes to p (anything within 0.45 m of p counts as the thing itself).
	for h in [1.2, 1.6]:
		var hit := _ray(global_position + Vector3.UP * (h * (0.75 if crouching else 1.0)), p)
		if not hit or hit.position.distance_to(p) < 0.45:
			return true
	return false


func hurt(amount: float, _from := Vector3.ZERO, mark_gain := 0.0) -> bool:
	## Returns false when the hit was dodged (roll i-frames) or ignored (cinematics / minigames never hurt).
	if dead or not controls_enabled or rolling_invulnerable() or _hurt_cd > 0.0:
		return false
	_hurt_cd = 0.25
	Snd.sfx("hurt", global_position + Vector3.UP * 1.5)
	amount *= G.settings().hurt * 0.8  # difficulty; 0.8 = global -20% balance pass
	G.send("hurt", [amount])
	health -= amount
	var was := mark
	mark = Feel.add_mark(mark, mark_gain * mark_resist, mark_cap)
	if mark > was:
		marked.emit(mark - was)
	anim.flinch = 1.0
	add_trauma(minf(amount * Feel.TRAUMA_HURT, Feel.TRAUMA_HURT_MAX))
	hud.damage_flash()
	_check_dead()
	return true


func _check_dead() -> void:
	if health <= 0.0 and not dead:
		health = 0.0
		dead = true
		died.emit()


func heal(amount: float) -> void:
	health = minf(health + amount, health_max)


func respawn(at: Vector3, yaw := 0.0) -> void:
	global_position = at
	velocity = Vector3.ZERO
	health = health_max
	stamina = stamina_max
	dead = false
	_roll_left = 0.0
	_end_slide()
	model.rotation.y = yaw
	pivot.rotation.y = yaw + PI


func is_hidden() -> bool:
	if not crouching:
		return false
	for p in hidden_spots:
		if p.distance_to(global_position) < 1.3:
			return true
	return false


func visibility() -> float:
	## 0..1.5 multiplier on how far enemies can see Alex.
	if is_hidden():
		return 0.0
	var v := 1.0
	if crouching:
		v *= 0.5
	if flashlight.visible:
		v *= 1.5
	return v


func noise(radius: float) -> void:
	radius *= 1.0 + maxf(mark - 50.0, 0.0) / 100.0  # x1.5 at 100% Mark
	get_tree().call_group("enemies", "hear", global_position, radius)


func _footsteps(delta: float, speed: float, sprinting: bool) -> void:
	## One footfall per stride walked; the surface (from the floor collider's name) picks the sound.
	if speed < 0.5 or not is_on_floor() or _slide_left > 0.0 or _roll_left > 0.0:
		_stride = 1.2  # the first footfall comes soon after setting off
		return
	_stride += speed * delta
	if _stride < (1.0 if crouching else (2.0 if sprinting else 1.55)):
		return
	_stride = 0.0
	Snd.step(self, -9.0 if crouching else (-1.0 if sprinting else -5.0))


func _heartbeat(delta: float) -> void:
	## Under 40% health a heartbeat thuds, faster the lower it gets.
	var frac := health / health_max
	if dead or frac > 0.4 or not controls_enabled:
		return
	_beat_t -= delta
	if _beat_t <= 0.0:
		_beat_t = lerpf(0.5, 1.1, frac / 0.4)
		Snd.sfx("heartbeat", null, lerpf(0.0, -8.0, frac / 0.4))
		beat.emit()


func _emit_step_noise(delta: float, speed: float, sprinting: bool) -> void:
	_noise_t -= delta
	if _noise_t > 0.0 or speed < 0.5 or not is_on_floor():
		return
	_noise_t = 0.5
	noise(12.0 if sprinting else (1.5 if crouching else 4.0))


# ------------------------------------------------------------------ chapter 2: carry, gas mask, bottles, takedown

func carry(item: String) -> void:
	## Hold `item` in both hands (a car battery): walk only, guns holstered until drop_carry().
	drop_carry()
	carrying = item
	_end_slide()
	_carry_mesh = ItemFx.model("car_battery")
	_carry_mesh.add_child(ItemFx.emit("battery"))  # the odd spark off the terminals
	model.add_child(_carry_mesh)
	_carry_mesh.position = Vector3(0, 1.08, 0.42)  # the hands grip its sides (_hold)
	_update_gun_meshes()
	hud.banner(item.to_upper(), Color(0.85, 0.82, 0.7), 0.6)


func drop_carry() -> void:
	if _carry_mesh:
		_carry_mesh.queue_free()
		_carry_mesh = null
	carrying = ""
	_update_gun_meshes()


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m


func toggle_mask() -> void:
	if not gas_mask:
		return
	mask_on = not mask_on
	Snd.sfx("item_use", null, -6.0, 0.7)
	hud.banner("MASK ON" if mask_on else "MASK OFF", Color(0.6, 0.9, 0.7), 0.4)


func refill_filter() -> void:
	mask_filter = 1.0
	hud.banner("FILTER REPLACED", Color(0.6, 0.9, 0.7), 0.8)


func in_gas() -> bool:
	return Engine.get_physics_frames() - _gas_frame < 3


func gas_exposure(delta: float) -> void:
	## Called by every GasCloud each physics frame the player is inside (overlaps count once).
	var f := Engine.get_physics_frames()
	if f == _gas_frame or dead:
		return
	_gas_frame = f
	if mask_on and mask_filter > 0.0:
		mask_filter = maxf(mask_filter - delta / FILTER_TIME, 0.0)
		if mask_filter <= 0.0:
			hud.banner("FILTER EMPTY", Color(1.0, 0.4, 0.3), 1.0)
		return
	if not controls_enabled:
		return  # cinematics never kill
	health -= GAS_DPS * delta * G.settings().hurt
	G.send("hurt", [1.0])
	_cough_t -= delta
	if _cough_t <= 0.0:  # coughing gives Alex away
		_cough_t = 1.4
		noise(10.0)
		anim.flinch = 0.6
		hud.damage_flash()
	_check_dead()


func throw_bottle() -> void:
	## Lob a bottle onto the crosshair; where it shatters every enemy within 14 m hears it.
	if bottles <= 0 or not _lob("bottle", _shatter):
		return
	bottles -= 1


func throw_smoke() -> void:
	## Lob a smoke can onto the crosshair: a SmokeCloud where it lands hides everything in and behind it.
	if smokes <= 0 or not _lob("smoke_can", func(pos: Vector3) -> void:
			SmokeCloud.make(get_parent(), pos)):
		return
	smokes -= 1
	hud.banner("SMOKE", Color(0.75, 0.75, 0.7), 0.5)


func drink_tea() -> void:
	## Elena's tea: Mark -15%.
	if teas <= 0 or mark <= 0.0:
		return
	teas -= 1
	mark = maxf(mark - Feel.MARK_TEA, 0.0)
	Snd.sfx("item_use")
	hud.banner("ELENA'S TEA  ·  MARK -15%", Color(0.8, 0.9, 0.6), 1.0)


func throw_target(reach := THROW_RANGE) -> Vector3:
	## What the crosshair is on (up to reach), else that far along the aim: where throws land, arrows fly.
	var from := camera.global_position
	var aim := -camera.global_basis.z
	from += aim * arm.spring_length  # skip the stretch between the camera and Alex
	var q := PhysicsRayQueryParameters3D.create(from, from + aim * reach, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if hit else from + aim * reach


func _lob(item: String, land: Callable) -> bool:
	## Left-hand overhand throw onto the crosshair; land(pos) runs where it hits (or after 4 s).
	## False = can't throw now (hands full, mid-mantle, or already throwing).
	if carrying != "" or _busy or anim.throw >= 0.0:
		return false
	var target := throw_target()
	var flat := target - global_position
	model.rotation.y = atan2(flat.x, flat.z)
	_aim_face = 0.7
	var tw := create_tween()
	tw.tween_property(anim, "throw", 0.45, 0.16).from(0.0)  # wind up...
	tw.tween_callback(_release.bind(target, item, land))
	tw.tween_property(anim, "throw", 1.0, 0.22)  # ...and follow through
	tw.tween_callback(func() -> void: anim.throw = -1.0)
	return true


func _release(target: Vector3, item: String, land: Callable) -> void:
	var b := RigidBody3D.new()
	b.collision_layer = 0
	b.collision_mask = 3
	b.contact_monitor = true
	b.max_contacts_reported = 1
	b.continuous_cd = true
	b.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE  # no drag: it flies the arc it was solved for
	b.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	var shape_node := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.06
	shape_node.shape = sph
	b.add_child(shape_node)
	var mi := ItemFx.model(item)
	b.add_child(mi)
	mi.position.y = -0.1  # spin about its middle, not its base
	b.add_collision_exception_with(self)
	get_parent().add_child(b)
	var hand := model.find_child("HandL", true, false) as Node3D
	var from := hand.global_position if hand else global_position + Vector3.UP * 1.6
	b.global_position = from
	# ballistic solve: reach the target in a flight time that grows with distance (flatter up close)
	var t := clampf(from.distance_to(target) / 14.0, 0.3, 1.2)
	b.linear_velocity = (target - from) / t + Vector3.UP * (0.5 * gravity * t)
	b.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-4, 4), randf_range(-8, 8))
	var smash := _land.bind(b, land)  # bound, not a lambda: b may be gone when the timer fires
	b.body_entered.connect(smash.unbind(1))
	get_tree().create_timer(4.0).timeout.connect(smash)
	noise(2.0)


func _land(b, land: Callable) -> void:  # untyped: a freed body must still bind
	if not is_instance_valid(b) or b.is_queued_for_deletion():
		return
	var pos: Vector3 = b.global_position
	b.queue_free()
	land.call(pos)


func _shatter(pos: Vector3) -> void:
	get_tree().call_group("enemies", "hear", pos, 14.0)
	Snd.sfx("glass", pos)
	ItemFx.burst(get_parent(), pos + Vector3.UP * 0.05, "shards")
	ItemFx.burst(get_parent(), pos + Vector3.UP * 0.05, "splash")


func takedown_target() -> Node:
	## Unaware enemy within TAKEDOWN_RANGE that allows a takedown from here, unless an interactable is closer.
	var best: Node = null
	var best_d := TAKEDOWN_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node3D and e.has_method("can_takedown") and e.has_method("takedown")):
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d and e.can_takedown(self):
			best_d = d
			best = e
	if best and carrying == "":
		var t := interact_target()
		if t == null or t.global_position.distance_to(global_position + Vector3.UP * 0.9) > best_d:
			return best
	return null


func _takedown(e: Node3D) -> void:
	_busy = true
	velocity = Vector3.ZERO
	var to := e.global_position - global_position
	model.rotation.y = atan2(to.x, to.z)
	interacted.emit(e)
	var tw := create_tween()
	tw.tween_property(anim, "attack", 0.6, 0.25).from(0.0)  # raise both arms...
	tw.tween_callback(func() -> void:
		e.takedown()
		hud.banner("TAKEDOWN", Color(0.9, 0.85, 0.7), 0.5))
	tw.tween_property(anim, "attack", 1.0, 0.3)  # ...and strike (as long as an enemy's, so the arms don't whip)
	tw.tween_callback(func() -> void:
		anim.attack = -1.0
		_busy = false)
