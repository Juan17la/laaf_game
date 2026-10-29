class_name HumanoidAnim
extends Node
const ItemFx := preload("res://scripts/item_fx.gd")
## Procedural animation for the shared character rig (tools/rig.py joint names).
## Set speed / crouching / roll / look from the owner each frame. A limb hanging
## down rotated by -x swings forward (+Z), +x swings back.

@export var model_path: NodePath = ^".."
@export var run_speed := 5.2
## Gallery/showcase: cycles idle → walk → run by itself.
@export var demo := false

var speed := 0.0
var crouching := false
var roll := -1.0  ## 0..1 while dodge-rolling, -1 otherwise
var look := Vector2.ZERO  ## head yaw / pitch in radians, relative to the body
var airborne := false  ## jumping / falling: legs tuck
var sliding := false  ## knee slide: hips drop, lead leg out, lean back
var aim := 0.0  ## 0..1 right arm raised along aim_pitch (gun hand), left arm supports
var aim_pitch := 0.0  ## radians, + = up: toward what's aimed at, from the chest
var aim_lean := 0.0  ## 0..1: the spine bends SPINE_AIM of aim_pitch toward it (a gun or bow aimed, not a guard)
var aim_block := 0.0  ## 0..1 wall right in front of the muzzle: gun tucks to low ready instead of poking through
var stance := 0.0  ## spine turn (radians) while aiming: long guns and the bow blade the shoulders to the target
var throw := -1.0  ## 0..1 left-hand overhand throw (windup until 0.45, release after), -1 = none
var recoil := 0.0  ## 0..1, decays by itself; set to 1 on a shot
const SPINE_AIM := 0.35  ## the share of a steep aim the spine bends (forward aiming down, back aiming up); arms the rest
var attack := -1.0  ## 0..1 overhead swing (windup until 0.6, strike after), -1 = none
var flinch := 0.0  ## 0..1, decays by itself; set to 1 when hit
var strike := -1.0  ## 0..1 a melee strike's body motion (the hands are IK'd by the player), -1 = none
var strike_style := ""  ## "jab_r" / "jab_l" (fists), "bash" (gun butt), "swing" (bat), "chop" (axe)
## Arm IK: hand bone poses in MODEL space (rig root: +Z front, +X the character's left), blended in by ik_w.
## Whoever holds something (player weapons, Actor.hold / take) sets them; solved last, over every other pose.
var ik := {}
var ik_w := {"R": 0.0, "L": 0.0}
var ik_pole := {}  ## "R" / "L" → model-space direction the elbow bends toward (default: out and down)
## Holding things (cutscenes; any character): hold() puts an item in the right hand by its shape and the arm
## IK keeps it where the pose wants it: "show" up before the eyes, "give" held out (also while the "give"
## gesture plays), "reach" the hand onto reach_to (a world pose), "" down by the side. Actor.take() stages a
## pickup with these. The arm lets go on its own once the item is freed or taken by someone else.
var held: Node3D
var hold_pose := ""
var reach_to := Transform3D()
var _holding := false  ## this anim drives ik.R for a held item (the player's weapons drive it otherwise)
## Cinematic body language (Actor.gesture): "" or one of point, wave, give, reach, hand_to_face,
## clutch_hand, arms_crossed, shrug, nod, shake_head, lean, cower, raise_weapon, window_press,
## hands_up, beckon, look_around, slump, frenzy (a charging attacker: stabbing overhead, clawing, hunched).
## Blends in/out over ~0.3 s.
var gesture := ""
## Beaten on the ground (a downed boss), shown while crouching: "kneel", "one_knee", "hands_ground", "sit_back",
## "side" ("" = the plain crouch). Standing up (crouching = false) blends out of it.
var down_pose := ""
var _g_amt := 0.0
var _g_last := ""
var _g_time := 0.0  ## seconds since the gesture started (loops like nod / shrug settle down)

## Sagittal gait curves (degrees) every 5% of a stride from this foot's heel strike, after normative gait data
## (Winter; Novacheck for running). hip: thigh forward of vertical; knee: flexion; ankle: dorsiflexion (toes up).
## Walk: toe-off at 60%, double support 0-10% and 50-60%, swing knee peaks ~60° at 72%. Run: toe-off at 40%
## (warped earlier as speed rises), flight to the other heel strike, stance knee ~40°, swing knee ~110°.
const WALK_HIP := [20, 19, 17, 13, 9, 5, 1, -3, -7, -12, -17, -19, -12, -2, 8, 15, 20, 24, 25, 23]
const WALK_KNEE := [4, 12, 17, 19, 17, 13, 9, 6, 5, 7, 12, 22, 36, 50, 59, 60, 52, 37, 18, 7]
const WALK_ANKLE := [0, -5, -3, 2, 5, 7, 8, 9, 10, 10, 8, 0, -12, -16, -10, -4, -1, 0, 1, 1]
const RUN_HIP := [28, 25, 20, 14, 7, 0, -7, -14, -19, -18, -12, -3, 8, 20, 31, 40, 45, 44, 38, 32]
const RUN_KNEE := [18, 28, 37, 42, 40, 35, 28, 22, 20, 30, 48, 70, 90, 105, 110, 102, 84, 62, 40, 24]
const RUN_ANKLE := [2, 8, 15, 20, 18, 12, 4, -8, -20, -22, -15, -8, -2, 2, 5, 6, 6, 5, 4, 3]
## How far the planted foot travels back under the hips over one stance at full stride (1.78 m rig): the stride
## is scaled so it travels about speed × stance time; the foot lock (_plant_feet) takes up the rest.
const STANCE_WALK := 0.8
const STANCE_RUN := 0.78
## Crouch (sneaking): hips low, knees bent forward over the feet, soles flat (the ankle takes up the knee's bend
## minus the hip's: CROUCH_KNEE - CROUCH_HIP). The hips drop and sit back by what the folded leg works out to on
## each rig, so the feet stay under the body. Walking crouched, the gait curves play at CROUCH_GAIT of their size
## and the total bend is capped: a swing knee never comes up to the chest.
const CROUCH_HIP := 1.3  ## rad of thigh forward of vertical
const CROUCH_KNEE := 1.85  ## rad of knee bend
const CROUCH_GAIT := 0.45
const CROUCH_HIP_MAX := 1.75  ## rad, crouched: the most a swinging thigh comes forward...
const CROUCH_KNEE_MAX := 2.2  ## ...and the most a knee folds

## Skinned models (tools/psx_chars.py): the bones each joint carries exactly; the rest follow their parents, except
## SKIN_SHARE ones, which take a share of a joint's turn about their own head (the waist bends in two places, the
## collarbones lift a little with the arms), and the fingers (a mitten's one, or four), which close by GRIP (rad per
## knuckle) on top of their relaxed bind curl whenever the hand holds something (part way running).
const SKIN := {"Hips": "m_Hips", "Spine": "m_Spine2", "Neck": "m_Neck", "Head": "m_Head",
	"UpperArmL": "m_LeftArm", "ForearmL": "m_LeftForeArm", "HandL": "m_LeftHand",
	"UpperArmR": "m_RightArm", "ForearmR": "m_RightForeArm", "HandR": "m_RightHand",
	"ThighL": "m_LeftUpLeg", "ShinL": "m_LeftLeg", "FootL": "m_LeftFoot",
	"ThighR": "m_RightUpLeg", "ShinR": "m_RightLeg", "FootR": "m_RightFoot"}
const SKIN_SHARE := {"m_Spine": ["Spine", 0.5], "m_LeftShoulder": ["UpperArmL", 0.2], "m_RightShoulder": ["UpperArmR", 0.2]}
const GRIP := [0.85, 0.82, 0.62]
var grip := {"L": 0.0, "R": 0.0}  ## 0..1 how closed each hand is, eased toward whether it holds anything

var _j := {}
var _neck: Node3D
var _skel: Skeleton3D
var _FINGER := RegEx.create_from_string("Hand(Index|Middle|Ring|Pinky)[123]$")  ## (the thumb keeps its bind pose)
var _bind := []  ## per bone: [] (follows its parent), [joint, offset], [joint, share, offset in the joint's parent], [hand, side, knuckles]
var _skirt := {}  ## optional "L" / "R" coat-tail halves on the hips (tools/rig.py), they follow the thighs
var _spd := 0.0  ## speed through a critically damped spring: gait blends stay smooth when speed jumps
var _spd_v := 0.0
var _run := 0.0  ## 0 walking .. 1 running
var _amp := 0.0  ## stride amplitude, eased
var _air := 0.0  ## 0..1 blend into the airborne pose
## Per foot while planted: on (in stance), i (the SOLE point it pivots on), at (where that point is pinned, model
## space, sliding back with the body's motion), corr (the last stance fix to the curves' foot, eased out in swing),
## last (where the ankle was put last frame).
var _lock := {"L": {"on": false, "i": 0, "at": Vector3.ZERO, "corr": Vector3.ZERO, "last": Vector3.INF},
	"R": {"on": false, "i": 0, "at": Vector3.ZERO, "corr": Vector3.ZERO, "last": Vector3.INF}}
const SOLE := [Vector3(0, -0.05, -0.07), Vector3(0, -0.05, 0.05), Vector3(0, -0.04, 0.17)]  ## heel, ball, toe
var _atk_t := 0.0  ## the overhead attack's last progress and its fade (1 → 0 once attack is cut to -1)
var _atk_fade := 0.0
var _stk_t := 0.0  ## same for strike
var _stk_fade := 0.0
var _rest := {}
var _phase := 0.0
var _time := 0.0
var _crouch := 0.0
var _air_t := 0.0  ## seconds airborne (how hard the landing is)
var _land := 0.0  ## 1 → 0 just after landing: knees and spine absorb it
## Vertical speed (m/s) while airborne: + rising (tuck), - falling (legs reach for the ground). Set by the owner.
var vertical := 0.0


func _ready() -> void:
	var model := get_node(model_path)
	for joint in ["Hips", "Spine", "Head", "UpperArmL", "ForearmL", "HandL", "UpperArmR", "ForearmR",
			"HandR", "ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR"]:
		var n := model.find_child(joint, true, false) as Node3D
		if n:
			_j[joint] = n
			_rest[joint] = n.position
	var neck := model.find_child("Neck", true, false) as Node3D  # optional (tools/rig.py split_neck)
	if neck:
		_neck = neck
	for k in ["L", "R"]:
		var sk := model.find_child("Skirt" + k, true, false) as Node3D
		if sk:
			_skirt[k] = sk
	_time = randf() * 10.0
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels:
		_skel = skels[0]
		_bind_skin()


func _process(delta: float) -> void:
	if _j.size() < 15:
		return
	_time += delta
	if demo:
		var cycle := fmod(_time, 12.0)
		speed = 0.0 if cycle < 4.0 else (1.6 if cycle < 8.0 else run_speed)
		look = Vector2(sin(_time * 0.7) * 0.6, sin(_time * 0.45) * 0.2) if cycle < 4.0 else Vector2.ZERO
	var dt := minf(delta, 0.05)
	_spd_v += (144.0 * (speed - _spd) - 24.0 * _spd_v) * dt
	_spd += _spd_v * dt
	var v := maxf(_spd, 0.0)
	# walk → run over ~1.9..2.75 m/s (2.8 is a jog), eased over ~0.2 s so even a sudden stop doesn't flick the elbows open
	_run += (smoothstep(1.9, 2.75, v) - _run) * (1.0 - exp(-dt * 6.0))
	var run := _run
	var k_scale: float = _rest["Hips"].y / 0.95  # rig scale (shorter adults)
	# cadence (steps/s) ~1.7 at a stroll, ~160/min jogging to ~182/min sprinting; the duty factor (stance share of the stride) drops from
	# 60% walking to 40% jogging and ~32% at a sprint. The stride then fits the speed (no skating); past full
	# stride the cadence rises instead.
	var duty_run := lerpf(0.4, 0.32, smoothstep(3.0, 6.0, v))
	var warp := (0.4 - duty_run) * TAU / sin(TAU * duty_run)  # run curves: stance squeezed into duty_run
	var steps := lerpf(1.0 + 0.5 * v, 2.25 + 0.14 * v, run)
	var duty := lerpf(0.6, duty_run, run)
	var reach := lerpf(STANCE_WALK, STANCE_RUN, run) * k_scale
	var a := 2.0 * duty * v / (steps * reach)  # stride amplitude, 1 = the curves as written
	var a_max := lerpf(1.35, 1.6, run)
	if a > a_max:
		steps *= a / a_max
		a = a_max
	_phase += delta * PI * steps
	_amp += (a - _amp) * (1.0 - exp(-dt * 10.0))  # the first step out of a standstill grows in, no pop
	a = _amp
	var ka := minf(a, 1.0) * (2.0 - minf(a, 1.0))  # knee / ankle excursions shrink less than the stride
	var g := minf(a, 1.0)  # gait intensity
	_crouch = move_toward(_crouch, 1.0 if crouching else 0.0, delta * 5.0)
	var breath := sin(_time * 1.8)
	var idle := 1.0 - clampf(v, 0.0, 1.0)
	if airborne:
		_air_t += delta
	elif _air_t > 0.0:  # just landed: knees take it, harder after a longer fall
		_land = clampf(_air_t * 1.6, 0.35, 1.0)
		_air_t = 0.0
	_land = move_toward(_land, 0.0, delta * 3.5)
	_air = move_toward(_air, 1.0 if airborne else 0.0, delta * 8.0)

	# pelvis (from the left heel strike): turns ±4° (±7° running) with the swinging leg's hip coming forward,
	# drops ~4° on the swing side, shifts over the stance foot; runners tip forward from the ankles
	var cyc := TAU * fposmod(_phase / TAU, 1.0)
	var yaw := -deg_to_rad(lerpf(4.0, 7.0, run)) * cos(cyc) * g
	var tilt := deg_to_rad(lerpf(4.0, 3.0, run)) * sin(cyc + TAU * 0.1) * g
	var lean := 0.1 * run
	# legs: data curves per leg (walk and run blended at the same phase); thighs cancel the pelvis turn and tilt
	# so the feet track straight; the foot is the ankle angle on top, its sole planted below
	var drive := {}  # each arm swings with the opposite thigh, a beat behind it
	var flight := 0.0
	for side in [["L", 0.0, 1.0], ["R", 0.5, -1.0]]:
		var k: String = side[0]
		var ph: float = side[2]
		var u := fposmod(_phase / TAU + side[1], 1.0)
		var ur := u + warp * sin(TAU * u) / TAU
		var gk := lerpf(1.0, CROUCH_GAIT, _crouch)  # crouched: a shuffle, not a march
		var hip := deg_to_rad(lerpf(_cyc(WALK_HIP, u), _cyc(RUN_HIP, ur), run)) * a * gk
		var knee := deg_to_rad(lerpf(_cyc(WALK_KNEE, u), _cyc(RUN_KNEE, ur), run)) * ka * gk + CROUCH_KNEE * _crouch \
				+ 1.1 * _land
		knee += idle * maxf(0.0, sin(_time * 0.35) * ph) * 0.12 * (1.0 - _crouch)  # idle: weight on one leg now and then
		knee = minf(knee, lerpf(PI, CROUCH_KNEE_MAX, _crouch))
		# in stance the ankle takes up the knee's extra share, so the foot rolls over the ground with the stride
		var on := 1.0 - smoothstep(duty - 0.04, duty + 0.08, u) * (1.0 - smoothstep(0.88, 1.0, u))
		var ankle := (deg_to_rad(lerpf(_cyc(WALK_ANKLE, u), _cyc(RUN_ANKLE, ur), run)) * lerpf(ka, a, on) \
				+ deg_to_rad(lerpf(_cyc(WALK_KNEE, u), _cyc(RUN_KNEE, ur), run)) * (ka - a) * on) * gk
		var flex := minf(hip + lean + CROUCH_HIP * _crouch, lerpf(PI, CROUCH_HIP_MAX, _crouch))
		_j["Thigh" + k].rotation = Vector3(-flex - 0.55 * _land, -yaw, (0.03 + 0.03 * idle) * ph - tilt)
		_j["Shin" + k].rotation = Vector3(knee, 0, 0)  # whole rotations: the foot lock leaves twist on these
		_j["Foot" + k].rotation = Vector3(-ankle - (CROUCH_KNEE - CROUCH_HIP) * _crouch - 0.15 * _land, 0, 0)
		var lag := u - lerpf(0.05, 0.03, run)
		drive["R" if k == "L" else "L"] = lerpf(_cyc(WALK_HIP, lag), _cyc(RUN_HIP, lag + warp * sin(TAU * lag) / TAU), run) * a
		if ur > 0.4 and ur < 0.5:
			flight = sin((ur - 0.4) / 0.1 * PI) * run

	var hips: Node3D = _j["Hips"]
	hips.position = _rest["Hips"] + Vector3((lerpf(0.025, 0.01, run) * sin(cyc) * g + idle * 0.012 * sin(_time * 0.35)) * k_scale,
			0, 0) + crouch_offset() * _crouch
	hips.rotation = Vector3(lean, yaw, tilt)
	# plant: the lowest point of either sole (heel, ball or toe) sits exactly on the ground. That gives the walk its
	# rise over the straight stance leg (lowest in double support) and the run its sink through the bent knee, and
	# keeps a foot from ever sinking into the floor. Running adds the flight between toe-off and heel strike.
	hips.position.y += (0.035 * flight * k_scale - _sole_low()) * (1.0 - _air)
	_plant_feet(delta, duty, 0.015 * (1.0 - run) * g, 1.0 - _air)

	# spine: the thorax counter-rotates against the pelvis (shoulders turn with the arms), shoulders stay level over
	# the dropping pelvis, runners lean and give a little at each footfall; crouch, landing, breathing
	var twist := deg_to_rad(lerpf(4.0, 9.0, run)) * cos(cyc) * g  # thorax turn in the world
	var give := run * maxf(0.0, sin(TAU * fposmod(_phase / TAU, 0.5) / (2.0 * duty_run)))
	var spine: Node3D = _j["Spine"]
	spine.rotation = Vector3(0.04 * g + 0.08 * run + 0.04 * give + 0.55 * _crouch + 0.3 * _land + breath * 0.015 * idle,
			twist - yaw, -0.6 * tilt)

	# arms: pendular from the shoulder opposite the legs, elbows soft walking; running they pump front-back at ~90°,
	# closing as the hand comes forward, slightly in toward the midline (not across the body)
	for side in [["L", 1.0], ["R", -1.0]]:
		var k: String = side[0]
		var ph: float = side[1]
		var d: float = drive[k]
		var sh := deg_to_rad(lerpf(-8.0, -24.0, run) * g + lerpf(0.64, 1.08, run) * d)
		var elbow := deg_to_rad(lerpf(15.0, 75.0, run) * g + lerpf(0.35, 0.55, run) * (d + 20.0 * g))
		# crouched, the arms come forward of the bent-over chest (it carries them back) and the elbows soften: the hands
		# hang by the knees, not behind the thighs
		_j["UpperArm" + k].rotation = Vector3(-sh - 0.75 * _crouch - 0.4 * _land, -0.1 * ph * maxf(0.0, sh) * run,
				ph * (0.1 + 0.08 * run + 0.25 * _land + 0.02 * breath * idle))
		# whole rotations (not just .x): the arm IK leaves twist on these that must not linger
		_j["Forearm" + k].rotation = Vector3(-0.15 * (1.0 - g) - elbow - 0.35 * _crouch, 0, 0)
		_j["Hand" + k].rotation = Vector3(-0.1 * g - 0.1 * run, 0, 0)

	# head: look target; steady in the world: undoes the thorax turn, the pelvis tilt and most of the lean
	var head: Node3D = _j["Head"]
	head.rotation = Vector3(clampf(look.y, -0.6, 0.6) - 0.8 * (lean + 0.08 * run + 0.04 * give) - 0.45 * _crouch
			- 0.2 * _land + sin(_time * 0.9) * 0.02, clampf(look.x, -1.1, 1.1) - twist, -0.4 * tilt)

	# jump / fall: rising, the lead knee drives up and the arms lift; falling, the legs reach down for the
	# ground and the arms spread for balance
	if _air > 0.0:  # blended in / out over ~0.12 s
		var fall := clampf(0.5 - vertical / 5.0, 0.0, 1.0)
		var tuck := 1.0 - fall
		_pose("ThighL", Vector3(lerpf(-1.1, -0.45, fall), 0, 0.05), _air)
		_pose("ShinL", Vector3(lerpf(1.5, 0.45, fall), 0, 0), _air)
		_pose("ThighR", Vector3(lerpf(0.25, -0.15, fall), 0, -0.05), _air)
		_pose("ShinR", Vector3(lerpf(1.1, 0.3, fall), 0, 0), _air)
		for k in ["L", "R"]:
			var ph := 1.0 if k == "L" else -1.0
			_pose("UpperArm" + k, Vector3(lerpf(-1.0 if k == "R" else -0.3, -0.35, fall), 0, ph * lerpf(0.35, 1.05, fall)), _air)
			_pose("Forearm" + k, Vector3(lerpf(-0.9, -0.3, fall), 0, 0), _air)
			_pose("Foot" + k, Vector3(lerpf(0.35, -0.1, fall), 0, 0), _air)
		spine.rotation.x = lerpf(spine.rotation.x, 0.25 * tuck, 0.7 * _air)  # curled on the way up

	# knee slide: lead (left) leg straight out, right knee folded under, lean back
	if sliding:
		hips.position.y = _rest["Hips"].y * 0.55
		spine.rotation.x = -0.5
		head.rotation.x += 0.35  # chin down: eyes stay on where he's sliding
		_j["ThighL"].rotation.x = -1.05
		_j["ShinL"].rotation.x = 0.1
		_j["ThighR"].rotation.x = -0.35
		_j["ShinR"].rotation.x = 2.2
		_j["FootL"].rotation.x = 0.3
		_j["UpperArmL"].rotation = Vector3(-0.3, 0, 0.9)

	if down_pose != "" and _crouch > 0.0:
		_down(_crouch, hips, spine, head)

	# gun arms: two-hand isosceles grip, both arms converge in front of the chest (wrists meet), the
	# right wrist turns the gun back onto the aim line; recoil kicks both hands up. Near a wall
	# (aim_block) the gun drops to low ready and pulls in instead of poking through it.
	recoil = move_toward(recoil, 0.0, delta * 6.0)
	if aim > 0.0:
		var arm_x := lerpf(-PI / 2.0 - aim_pitch * (1.0 - SPINE_AIM * aim_lean), -0.55, aim_block) - 0.3 * recoil
		var bend := -0.2 - 0.9 * aim_block - 0.25 * recoil
		_pose("UpperArmR", Vector3(arm_x, 0.4, -0.05), aim)
		_pose("ForearmR", Vector3(bend, 0, 0), aim)
		_pose("HandR", Vector3(0.2 - 0.3 * recoil, 0, -0.35), aim)
		_pose("UpperArmL", Vector3(arm_x, -0.3, 0.0), aim)
		_pose("ForearmL", Vector3(bend + 0.2, 0, 0), aim)
		_pose("HandL", Vector3(0.1, 0, 0.3), aim)
		spine.rotation.y = lerpf(spine.rotation.y, stance, aim)
		spine.rotation.x -= aim_pitch * SPINE_AIM * aim_lean * aim  # (+x bends forward: a low aim stoops, a high one arches)
		head.rotation.y -= stance * aim  # eyes stay on the target over the bladed shoulders

	# overhand throw with the free (left) hand: cock it behind the head, whip it forward, follow through
	if throw >= 0.0:
		var wind := clampf(throw / 0.45, 0.0, 1.0)
		var rel := clampf((throw - 0.45) / 0.55, 0.0, 1.0)
		var w := minf(wind * 2.0, 1.0) * (1.0 - maxf(rel - 0.7, 0.0) / 0.3)  # blend in fast, out at the end
		_pose("UpperArmL", Vector3(lerpf(-3.3, -1.1, rel), 0, lerpf(0.35, -0.2, rel)), w)
		_pose("ForearmL", Vector3(lerpf(-1.7, -0.15, rel), 0, 0), w)
		_pose("HandL", Vector3(lerpf(0.5, -0.4, rel), 0, 0), w)
		spine.rotation.y += lerpf(0.35, -0.3, rel) * w  # shoulders load, then turn through
		spine.rotation.x += lerpf(-0.1, 0.25, rel) * w

	# overhead strike, two hands (hunters, Marked Ones; the player's takedown). Wind-up (to 0.6): the arms lift
	# overhead with the elbows bent behind the head, the spine arches, weight sinks back. Strike: the trunk whips
	# forward first, the upper arms follow, the elbows snap straight last; the knees give at impact (~0.7) and
	# the hands follow through to the waist. The pose blends in from and back out to whatever the body was doing;
	# cut short (attack = -1: staggered, killed) it holds where it was and fades out over ~0.18 s.
	if attack >= 0.0:
		_atk_t = attack
		_atk_fade = 1.0
	else:
		_atk_fade = move_toward(_atk_fade, 0.0, delta / 0.18)
	if _atk_fade > 0.0:
		var t := _atk_t
		var w := smoothstep(0.0, 0.18, t) * (1.0 - smoothstep(0.82, 1.0, t)) * smoothstep(0.0, 1.0, _atk_fade)
		var sx := _keys([[0.0, 0.12], [0.6, -0.22], [0.72, 0.5], [0.86, 0.42], [1.0, 0.2]], t)
		var ua := _keys([[0.0, -0.5], [0.6, -2.85], [0.63, -2.85], [0.78, -0.55], [0.9, -0.45], [1.0, -0.5]], t)
		var fa := _keys([[0.0, -0.6], [0.6, -1.35], [0.66, -1.3], [0.79, -0.12], [1.0, -0.5]], t)
		var close := _keys([[0.55, 0.12], [0.75, -0.12]], t)  # elbows out overhead, hands together on the way down
		for k in ["L", "R"]:
			var ph := 1.0 if k == "L" else -1.0
			_pose("UpperArm" + k, Vector3(ua, 0, ph * close), w)
			_pose("Forearm" + k, Vector3(fa, 0, 0), w)
			_pose("Hand" + k, Vector3(_keys([[0.6, 0.35], [0.8, -0.3], [1.0, 0.0]], t), 0, 0), w)
		var dx := (sx - spine.rotation.x) * w
		spine.rotation.x += dx
		head.rotation.x -= 0.7 * dx  # eyes stay on the target
		_lunge(_keys([[0.0, 0.0], [0.6, 0.6], [0.7, 1.0], [0.86, 1.0], [1.0, 0.0]], t),
				_keys([[0.6, 0.0], [0.72, 0.35], [0.88, 0.25], [1.0, 0.0]], t), 0.0, w)

	# cinematic gestures, blended over whatever the body was doing
	if gesture != "":
		if gesture != _g_last or _g_amt <= 0.0:
			_g_time = 0.0
		_g_last = gesture
	_g_time += delta
	_g_amt = move_toward(_g_amt, 1.0 if gesture != "" else 0.0, delta * 3.5)
	if _g_amt > 0.0:
		_gesture(_g_last, _g_amt)

	# hit reaction: snap back
	flinch = move_toward(flinch, 0.0, delta * 4.0)
	if flinch > 0.0:
		spine.rotation.x -= 0.5 * flinch
		head.rotation.x -= 0.4 * flinch
		head.rotation.y += 0.3 * flinch  # turns the face away from the blow
		if aim <= 0.0 and throw < 0.0:  # guarding hands, unless they're holding the gun on target
			for k in ["L", "R"]:
				_j["UpperArm" + k].rotation.x -= 0.9 * flinch
				_j["Forearm" + k].rotation.x -= 1.1 * flinch

	# melee strikes (the hands ride their IK targets from player.gd), proximal to distal: the rear foot pushes,
	# the pelvis turns first, the shoulders follow, the arm last; each channel eases back to zero by t = 1.
	# Turns: + = chest toward the character's left (the right hip / shoulder forward).
	if strike >= 0.0:
		_stk_t = clampf(strike, 0.0, 1.0)
		_stk_fade = 1.0
	else:
		_stk_fade = move_toward(_stk_fade, 0.0, delta / 0.15)  # cut short: fades out from where it was
	if _stk_fade > 0.0:
		var t := _stk_t
		var fade := smoothstep(0.0, 1.0, _stk_fade)
		var w := (1.0 - _run) * fade  # running: the legs keep running, only the trunk drives
		var wt := (1.0 - _run)
		var hy := 0.0  # pelvis turn
		var sy := 0.0  # shoulders, on top of the pelvis
		var sx := 0.0  # trunk flexion
		var step := 0.0  # 0..1 into the staggered stance (left foot forward)
		var sink := 0.0  # knees give
		var push := 0.0  # rear heel up, pivoting on the ball
		match strike_style:
			"jab_r", "bash":  # cross: rear foot drives, hips then shoulders turn through, chin tucked
				hy = _keys([[0.0, 0.0], [0.24, 0.3], [0.42, 0.28], [0.8, 0.0]], t)
				sy = _keys([[0.04, 0.0], [0.32, 0.38], [0.42, 0.32], [0.85, 0.0]], t)
				sx = _keys([[0.0, 0.0], [0.32, 0.12], [0.85, 0.0]], t)
				push = _keys([[0.0, 0.0], [0.28, 1.0], [0.45, 0.9], [0.85, 0.0]], t)
				step = _keys([[0.0, 0.0], [0.3, 0.6], [0.9, 0.0]], t)
				sink = _keys([[0.0, 0.0], [0.32, 0.12], [0.9, 0.0]], t)
			"jab_l":  # jab: a short lead step, the left shoulder rolls forward, little hip
				hy = _keys([[0.0, 0.0], [0.26, -0.1], [0.75, 0.0]], t)
				sy = _keys([[0.02, 0.0], [0.32, -0.3], [0.42, -0.25], [0.8, 0.0]], t)
				sx = _keys([[0.0, 0.0], [0.32, 0.1], [0.8, 0.0]], t)
				step = _keys([[0.0, 0.0], [0.28, 1.0], [0.9, 0.0]], t)
				sink = _keys([[0.0, 0.0], [0.3, 0.15], [0.9, 0.0]], t)
			"swing":  # bat: load back on the rear leg, stride, hips fire first, shoulders lag, wrap through
				hy = _keys([[0.0, 0.0], [0.28, -0.35], [0.45, 0.3], [0.62, 0.6], [1.0, 0.0]], t)
				sy = _keys([[0.0, 0.0], [0.31, -0.5], [0.48, 0.15], [0.64, 0.45], [1.0, 0.0]], t)
				sx = _keys([[0.0, 0.0], [0.3, 0.06], [0.45, 0.15], [1.0, 0.0]], t)
				step = _keys([[0.0, 0.0], [0.33, 1.0], [0.75, 1.0], [1.0, 0.0]], t)
				sink = _keys([[0.0, 0.0], [0.3, 0.2], [0.45, 0.25], [1.0, 0.0]], t)
				push = _keys([[0.35, 0.0], [0.6, 1.0], [0.8, 0.8], [1.0, 0.0]], t)
			"chop":  # axe: arch back loading it, then the trunk folds over the blow and the knees drop
				hy = _keys([[0.0, 0.0], [0.3, -0.12], [0.48, 0.12], [1.0, 0.0]], t)
				sx = _keys([[0.0, 0.0], [0.3, -0.2], [0.48, 0.3], [0.68, 0.36], [1.0, 0.0]], t)
				step = _keys([[0.0, 0.0], [0.35, 1.0], [0.75, 1.0], [1.0, 0.0]], t)
				sink = _keys([[0.0, 0.0], [0.35, 0.1], [0.55, 0.45], [0.75, 0.35], [1.0, 0.0]], t)
		hips.rotation.y += hy * w
		hips.position.z += 0.04 * step * w * _rest["Hips"].y / 0.95  # weight onto the front foot
		spine.rotation += Vector3(sx, sy + hy * (1.0 - wt), 0) * fade
		head.rotation += Vector3(-0.6 * sx + 0.1 * absf(sy), -(hy + sy), 0) * fade  # eyes on the target, chin down
		for k in ["L", "R"]:  # the feet stay put under the turning pelvis (the rear one pivots on its ball)
			_j["Thigh" + k].rotation.y -= hy * w * (1.0 if k == "L" else 0.6)
		_lunge(step, sink, push, w)

	# dodge roll: tuck and spin around the hips
	if roll >= 0.0:
		hips.rotation.x = TAU * roll
		hips.position.y = _rest["Hips"].y * 0.55
		spine.rotation.x = 0.8
		head.rotation.x = 0.5
		for k in ["L", "R"]:
			_j["Thigh" + k].rotation.x = -1.8
			_j["Shin" + k].rotation.x = 2.2
			_j["UpperArm" + k].rotation.x = -1.2
			_j["Forearm" + k].rotation.x = -1.4

	for k in _skirt:  # coat tails follow their thigh part way (once every leg pose is final)
		var th: Node3D = _j["Thigh" + k]
		_skirt[k].rotation = Vector3(clampf(th.rotation.x * 0.6, -1.0, 0.45), 0, th.rotation.z)

	_pose_held(delta)
	if roll < 0.0:
		for k in ["R", "L"]:
			if ik_w[k] > 0.0 and ik.has(k):
				_reach(k, ik[k], smoothstep(0.0, 1.0, ik_w[k]))  # eased: hands settle onto / off their targets
	if _neck:  # the neck bends with a turn or nod: it takes 40%, the head (at the top of the neck) the rest
		var r := head.rotation
		_neck.rotation = r * 0.4
		head.rotation = r * 0.6
	if _skel:
		_skin(delta)


func _in_skel(n: Node3D) -> Transform3D:
	return _skel.global_transform.affine_inverse() * n.global_transform


func _bind_skin() -> void:
	## Ties each bone to the joints at rest (both are in the bind pose now), so _skin can carry it from them.
	for i in _skel.get_bone_count():
		var bone := _skel.get_bone_name(i)
		var rest := _skel.get_bone_global_rest(i)
		var b := []
		var joint: String = SKIN.find_key(bone) if SKIN.find_key(bone) != null else ""
		if joint != "" and _j_or_neck(joint):
			b = [joint, _in_skel(_j_or_neck(joint)).affine_inverse() * rest]
		elif SKIN_SHARE.has(bone) and _j.has(SKIN_SHARE[bone][0]):
			var j: Node3D = _j[SKIN_SHARE[bone][0]]
			b = [SKIN_SHARE[bone][0], SKIN_SHARE[bone][1], _in_skel(j.get_parent()).affine_inverse() * rest]
		elif _FINGER.search(bone):
			var k := "L" if bone.begins_with("m_Left") else "R"
			var hand: Node3D = _j["Hand" + k]
			var knuckles := []  # [rest pose in the hand, its head] from the base knuckle out to this one
			for n in int(bone.right(1)):
				knuckles.append(_in_skel(hand).affine_inverse() * _skel.get_bone_global_rest(_skel.find_bone(bone.left(-1) + str(n + 1))))
			b = ["Hand" + k, k, knuckles]
		_bind.append(b)


func _j_or_neck(joint: String) -> Node3D:
	return _neck if joint == "Neck" else _j.get(joint)


func _skin(delta: float) -> void:
	## Poses the skeleton from the joints (bones in index order: parents first).
	for k in grip:
		var hand: Node3D = _j["Hand" + k]
		var holds: bool = ik_w[k] > 0.3 or strike >= 0.0 or (k == "R" and _holding)
		for c in hand.get_children():
			holds = holds or (c is Node3D and (c as Node3D).visible)
		grip[k] = move_toward(grip[k], 1.0 if holds else 0.6 * _run, delta * 6.0)  # runners carry loose fists
	var g := []
	g.resize(_skel.get_bone_count())
	for i in g.size():
		var p := _skel.get_bone_parent(i)
		var pg: Transform3D = g[p] if p >= 0 else Transform3D()
		var b: Array = _bind[i]
		var t: Transform3D
		if b.is_empty():
			t = pg * _skel.get_bone_rest(i)
		elif b.size() == 2:
			t = _in_skel(_j_or_neck(b[0])) * b[1]
		elif b[1] is float:  # a share of the joint's turn, about this bone's own head
			var j: Node3D = _j[b[0]]
			var r := Basis(Quaternion.IDENTITY.slerp(j.quaternion, b[1]))
			var c: Vector3 = b[2].origin
			t = _in_skel(j.get_parent()) * Transform3D(r, c - r * c) * b[2]
		else:  # a finger knuckle: each one before it turns the rest about its head, around the hand's front axis
			var m := Transform3D()
			var ks: Array = b[2]
			for n in ks.size():
				var r := Basis(Vector3.BACK, (1.0 if b[1] == "R" else -1.0) * GRIP[n] * grip[b[1]])
				var c: Vector3 = ks[n].origin
				m = m * Transform3D(r, c - r * c)
			t = _in_skel(_j[b[0]]) * m * ks[-1]
		g[i] = t
		_skel.set_bone_pose(i, pg.affine_inverse() * t)


func joint(name: String) -> Node3D:
	## A rig joint (Hips, Spine, Head, UpperArmR...), null if the rig has none by that name.
	return _j.get(name)


func crouch_amount() -> float:
	return _crouch


func crouch_offset() -> Vector3:
	## Where the folded leg puts the hips (CROUCH_HIP / CROUCH_KNEE on this rig's thigh and shin): lower by what the
	## leg loses in height, and back by how far the foot ends up ahead of the hip, so the feet stay under the body.
	var thigh: float = -_rest["ShinL"].y
	var shin: float = -_rest["FootL"].y
	var lean := CROUCH_KNEE - CROUCH_HIP  # the shin's forward lean
	return Vector3(0, thigh * cos(CROUCH_HIP) + shin * cos(lean) - thigh - shin,
		-(thigh * sin(CROUCH_HIP) - shin * sin(lean)))


func _lunge(step: float, sink: float, push: float, w: float) -> void:
	## Staggered fighting stance on top of the legs (left foot forward), knees sinking, the rear heel lifting
	## (push: driving off the ball of the foot); the feet keep their pitch and the hips re-plant on the soles.
	var before := _sole_low()
	var legs := {"L": [-0.22 * step, 0.12 * step + sink, 0.0], "R": [0.16 * step - 0.12 * push, 0.06 * step + sink + 0.3 * push,
		0.45 * push]}
	for k in legs:
		var d: Array = legs[k]
		_j["Thigh" + k].rotation.x += d[0] * w
		_j["Shin" + k].rotation.x += d[1] * w
		_j["Foot" + k].rotation.x += (d[2] - d[0] - d[1]) * w
	_j["Hips"].position.y -= _sole_low() - before


func _plant_feet(delta: float, duty: float, lift: float, w: float) -> void:
	## Foot lock: through its stance (u < duty) a foot is pinned to the ground where it landed, sliding back only
	## with the body's own motion (speed along +Z), and rolls over its sole as the curves pitch it: heel strike →
	## flat → ball → toe-off, each point staying put while it carries the weight. The hips sink if a planted foot is
	## out of the leg's reach, and the leg reaches it by IK (knee forward). In swing the foot follows the curves,
	## easing out of the stance fix by mid-swing, `lift` higher at mid-swing for toe clearance, never into the
	## ground. w: 0 = the curves untouched (airborne).
	var hips: Node3D = _j["Hips"]
	var model := hips.get_parent() as Node3D
	var mb := model.global_basis.orthonormalized()
	var k_scale: float = _rest["Hips"].y / 0.95
	var plan := {}
	var drop := 0.0
	for side in [["L", 0.0], ["R", 0.5]]:
		var k: String = side[0]
		var u := fposmod(_phase / TAU + side[1], 1.0)
		var f: Node3D = _j["Foot" + k]
		var fz := mb.inverse() * f.global_basis.z
		var rot := Basis(Vector3.RIGHT, atan2(-fz.y, Vector2(fz.x, fz.z).length()))  # the curves' foot pitch, level
		var lk: Dictionary = _lock[k]
		var low := 0
		for i in 3:
			if (rot * SOLE[i]).y < (rot * SOLE[low]).y:
				low = i
		if u >= duty:
			lk.on = false
			plan[k] = [rot, u, null]
			continue
		if not lk.on:  # heel strike: pin where the swing left it (eased onto the ground below)
			lk.on = true
			lk.i = low
			var was := model.to_local(f.global_position)
			if lk.last != Vector3.INF and w > 0.99:  # walking: carry on from the swing's last (ground-clamped) step
				was = was.lerp(lk.last, 1.0 - _run)
			lk.at = was + rot * (SOLE[low] * k_scale)
			lk.at.y = maxf(lk.at.y, 0.0)
		else:
			lk.at.z -= speed * delta
			if low != lk.i:  # rolls onto the next point: it touches down where it is
				lk.at += rot * ((SOLE[low] - SOLE[lk.i]) * k_scale)
				lk.at.y = maxf(lk.at.y, 0.0)
				lk.i = low
		lk.at.y *= exp(-delta * 25.0)
		var target: Vector3 = lk.at - rot * (SOLE[lk.i] * k_scale)
		# a pin more than 18 cm off the curves' foot (a sudden start, a speed jump) drags along instead of
		# stretching the leg
		var off := target - model.to_local(f.global_position)
		var slack := Vector2(off.x, off.z).length() - 0.18 * k_scale
		if slack > 0.0:
			var pull := Vector3(off.x, 0, off.z).normalized() * slack
			lk.at -= pull
			target -= pull
		plan[k] = [rot, u, target]
		# out of reach (stance ending behind, or a stride longer than the curves'): the hips come down to it
		var h := model.to_local(_j["Thigh" + k].global_position)
		var reach := (model.to_local(_j["Shin" + k].global_position).distance_to(h)
				+ model.to_local(_j["Shin" + k].global_position).distance_to(model.to_local(f.global_position))) * 0.993
		var hz := Vector2(h.x - target.x, h.z - target.z).length()
		if hz < reach:
			drop = maxf(drop, (h.y - target.y - sqrt(reach * reach - hz * hz)) * smoothstep(0.0, 0.06, u)
					* (1.0 - smoothstep(duty - 0.08, duty, u)))
	drop = clampf(drop, 0.0, 0.08 * k_scale) * w
	hips.position.y -= drop
	for k in plan:
		var rot: Basis = plan[k][0]
		var f: Node3D = _j["Foot" + k]
		var ankle := model.to_local(f.global_position)
		var lk: Dictionary = _lock[k]
		var target := ankle
		if plan[k][2] != null:
			target = plan[k][2]
			lk.corr = target - ankle
		else:
			var p: float = (plan[k][1] - duty) / (1.0 - duty)
			# the pin's hold-down lets go at once (the toe leaves the ground), the fore-aft fix eases out by mid-swing
			var c: Vector3 = lk.corr * (1.0 - smoothstep(0.0, 0.55, p))
			c.y = lk.corr.y * (1.0 - smoothstep(0.0, 0.12, p))
			# the swing foot keeps its height while the hips sink over the other leg, touching down only at the end
			target = ankle + c + Vector3(0, (lift * smoothstep(0.0, 0.25, p) * k_scale + drop) * (1.0 - smoothstep(0.8, 1.0, p)), 0)
			# toes up as needed to clear the ground by the lift, then nothing below the floor
			var clear := lift * smoothstep(0.0, 0.25, p) * k_scale
			var toe := target.y + (rot * SOLE[2]).y * k_scale
			if toe < clear:
				rot = Basis(Vector3.RIGHT, rot.get_euler().x - (clear - toe) / (0.17 * k_scale))
			var sole := 0.0
			for pt in SOLE:
				sole = minf(sole, (rot * pt).y * k_scale)
			target.y = maxf(target.y, -sole)
		target = ankle.lerp(target, w)
		lk.last = target
		var th: Node3D = _j["Thigh" + k]
		var sh: Node3D = _j["Shin" + k]
		_limb(th, sh, f, model.to_global(target), mb.z, 1.0, deg_to_rad(165.0))
		f.quaternion = (sh.global_basis.orthonormalized().inverse() * mb * rot).get_rotation_quaternion()


func _sole_low() -> float:
	## Height of the lowest sole point (heel, ball or toe of either foot) in the model's space.
	var model := _j["Hips"].get_parent() as Node3D
	var k_scale: float = _rest["Hips"].y / 0.95
	var low := INF
	for k in ["L", "R"]:
		var f: Node3D = _j["Foot" + k]
		for pt in SOLE:
			low = minf(low, model.to_local(f.global_transform * (pt * k_scale)).y)
	return low


static func _keys(k: Array, t: float) -> float:
	## [time, value] pairs eased between (each key a still point: wind-up tops, follow-through ends); holds the
	## end values outside them.
	if t <= k[0][0]:
		return k[0][1]
	for i in range(1, k.size()):
		if t < k[i][0]:
			return lerpf(k[i - 1][1], k[i][1], smoothstep(k[i - 1][0], k[i][0], t))
	return k[-1][1]


static func _cyc(keys: Array, u: float) -> float:
	## keys spaced evenly over one cycle (u 0..1, wraps), read with a periodic Catmull-Rom spline.
	var n := keys.size()
	var x := fposmod(u, 1.0) * n
	var i := int(x)
	var t := x - i
	var p0: float = keys[(i + n - 1) % n]
	var p1: float = keys[i % n]
	var p2: float = keys[(i + 1) % n]
	var p3: float = keys[(i + 2) % n]
	return p1 + 0.5 * t * (p2 - p0 + t * (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3 + t * (3.0 * (p1 - p2) + p3 - p0)))


static func of(n: Node) -> HumanoidAnim:
	## The animator of whoever n belongs to (n: a bone, a model, an Actor, an Enemy).
	while n:
		for c in n.get_children():
			if c is HumanoidAnim:
				return c
		n = n.get_parent()
	return null


func hold(item: Node3D, pose := "show") -> Node3D:
	## Puts item in the right hand (where by its shape: ItemFx.grip) and poses the arm. Replaces what was held.
	if held and held != item and is_instance_valid(held):
		held.queue_free()
	var hand: Node3D = _j["HandR"]
	var g := ItemFx.grip(item)
	if item.is_inside_tree():
		item.reparent(hand, false)
	else:
		hand.add_child(item)
	item.transform = g
	item.set_meta("claimed", true)
	for p in item.find_children("*", "CPUParticles3D", true, false):  # its idle tell stays in the world
		p.queue_free()
	held = item
	hold_pose = pose
	return item


func let_go() -> void:
	## Drops (frees) what the right hand holds; the arm returns to the animation.
	if held and is_instance_valid(held):
		held.queue_free()
	held = null
	hold_pose = ""


func _pose_held(delta: float) -> void:
	if held and (not is_instance_valid(held) or held.get_parent() != _j["HandR"]):
		held = null  # freed, or someone took it
		if hold_pose != "reach":
			hold_pose = ""
	var pose := "give" if gesture == "give" and held else hold_pose
	if pose in ["show", "give", "talk"] and not held:
		pose = ""
	if pose == "":
		if _holding:
			ik_w.R = move_toward(ik_w.R, 0.0, delta * 4.0)
			_holding = ik_w.R > 0.0
		return
	var model := get_node(model_path) as Node3D
	var want: Transform3D
	if pose == "reach":
		want = model.global_transform.affine_inverse() * reach_to
	else:
		want = _item_pose(pose) * held.transform.affine_inverse()
	ik.R = want if not _holding else (ik.R as Transform3D).interpolate_with(want, minf(delta * 7.0, 1.0))
	ik_w.R = move_toward(ik_w.R, 1.0, delta * 3.0)
	_holding = true


func _item_pose(pose: String) -> Transform3D:
	## Where the held item goes (model space; the character faces +Z): "show" up before the eyes with its face
	## (+Y) turned to them and its top (-Z) up; "give" held out at chest height, upright, its top toward the other
	## person; "talk" at the mouth (a radio mic, a phone), top up.
	if not held.has_meta("bounds"):
		held.set_meta("bounds", ItemFx.bounds(held))
	var c: Vector3 = (held.get_meta("bounds") as AABB).get_center()
	var at: Vector3 = {"show": Vector3(-0.07, 1.28, 0.34), "give": Vector3(-0.08, 1.12, 0.5),
		"talk": Vector3(-0.07, 1.52, 0.15)}[pose]
	var b := Basis(Vector3.UP, PI)  # item -Z (its top / business end) forward, toward whoever's in front
	if pose == "talk":
		b = Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.UP, PI)  # top up, face (+Y) to the mouth
	elif pose == "show":
		var y := (Vector3(0, 1.62, 0.06) - at).normalized()
		var z := (Vector3.DOWN - y * Vector3.DOWN.dot(y)).normalized()
		b = Basis(y.cross(z), y, z)
	return Transform3D(b, at - b * c)


func _reach(k: String, target_local: Transform3D, w: float) -> void:
	## Two-bone arm IK: the wrist onto target.origin, the elbow out toward ik_pole (default out and down), the hand
	## takes target.basis. w < 1 blends in target space: from the animated wrist / elbow / hand toward the target, so
	## a fade never swings the arm through itself or bends the elbow backward.
	var model := get_node(model_path) as Node3D
	var target := model.global_transform * target_local
	var up: Node3D = _j["UpperArm" + k]
	var fo: Node3D = _j["Forearm" + k]
	var ha: Node3D = _j["Hand" + k]
	var mb := model.global_basis.orthonormalized()
	var sd := 1.0 if k == "L" else -1.0
	# elbow out and down: never in line with an arm reaching in front, overhead or down (no flip raising an axe)
	var pole: Vector3 = mb * (ik_pole[k] as Vector3 if ik_pole.has(k) else Vector3(sd, -0.6, -0.15))
	var hb := ha.global_basis.orthonormalized()
	if w < 1.0:
		var s := up.global_position
		var wr := ha.global_position
		var e := fo.global_position - s
		var line := (wr - s).normalized()
		pole = (e - line * e.dot(line)).normalized().lerp(pole.normalized(), w)  # the animated elbow's side
		target = Transform3D(hb, wr).interpolate_with(target, w)
	_limb(up, fo, ha, target.origin, pole, -1.0, deg_to_rad(150.0))
	ha.quaternion = (fo.global_basis.orthonormalized().inverse() * target.basis.orthonormalized()).get_rotation_quaternion()


func _limb(up: Node3D, lo: Node3D, tip: Node3D, at: Vector3, pole: Vector3, side: float, max_flex: float) -> void:
	## Two-bone IK (global space): up → lo → tip's pivot onto `at`, the middle joint sticking out toward `pole`.
	## Both bones get explicit bases (hanging along -Y) sharing one hinge axis, their local X: the joint only flexes
	## its natural way (side +1: knee, the lower bone swings back, +x; -1: elbow, forward, -x), never past max_flex,
	## and the twist follows the pole continuously (no shortest-arc flips pointing straight up).
	var s := up.global_position
	var l1 := s.distance_to(lo.global_position)
	var l2 := lo.global_position.distance_to(tip.global_position)
	var to := at - s
	var d := maxf(to.length(), sqrt(l1 * l1 + l2 * l2 + 2.0 * l1 * l2 * cos(max_flex)))
	var s0 := (l1 + l2) * 0.994  # past this the limb straightens softly (no knee / elbow snap at full reach)
	if d > s0:
		d = s0 + (l1 + l2 - s0) * 0.9999 * (1.0 - exp(-(d - s0) / (l1 + l2 - s0)))
	var dir := to.normalized() if to.length() > 0.0001 else -up.global_basis.y.normalized()
	var p := pole - dir * pole.dot(dir)
	if p.length() < 0.0001:
		p = up.global_basis.z * side
		p -= dir * p.dot(dir)
	p = p.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var mid := s + dir * a + p * sqrt(maxf(l1 * l1 - a * a, 0.0))
	var y1 := (s - mid).normalized()
	var z1 := (p - y1 * p.dot(y1)).normalized() * side
	var x := y1.cross(z1).normalized()
	var b1 := Basis(x, y1, z1)
	var y2 := (mid - (s + dir * d)).normalized()
	var b2 := Basis(x, y2, x.cross(y2))
	up.quaternion = ((up.get_parent() as Node3D).global_basis.orthonormalized().inverse() * b1).get_rotation_quaternion()
	var yl := b1.inverse() * y2
	lo.rotation = Vector3(atan2(yl.z, yl.y), 0, 0)  # a pure hinge, kept as an angle (past 90° too) for later poses


func _settle(after: float) -> float:
	## 1 → 0 over 0.5 s once the gesture has run `after` seconds: repeated motions (nod, wave) stop
	## instead of looping like a machine while the pose is held.
	return clampf(1.0 - (_g_time - after) / 0.5, 0.0, 1.0)


func _pose(joint: String, rot: Vector3, w: float) -> void:
	var n: Node3D = _j[joint]
	n.rotation = n.rotation.lerp(rot, w)


func _gesture(g: String, w: float) -> void:
	var t := _time
	var spine: Node3D = _j["Spine"]
	var head: Node3D = _j["Head"]
	match g:
		"point":
			_pose("UpperArmR", Vector3(-1.5, 0.2, -0.1), w)
			_pose("ForearmR", Vector3(-0.05, 0, 0), w)
		"wave":
			_pose("UpperArmR", Vector3(-2.7, 0, -0.35), w)
			_pose("ForearmR", Vector3(-0.3 - 0.35 * sin(t * 9.0) * _settle(2.0), 0, 0), w)
		"give":
			_pose("UpperArmR", Vector3(-1.0, 0.1, -0.05), w)
			_pose("ForearmR", Vector3(-0.45, 0, 0), w)
			_pose("HandR", Vector3(0.3, 0, 0), w)
		"reach":
			for k in ["L", "R"]:
				_pose("UpperArm" + k, Vector3(-1.3, 0, 0), w)
				_pose("Forearm" + k, Vector3(-0.2, 0, 0), w)
			spine.rotation.x = lerpf(spine.rotation.x, 0.2, w)
		"hand_to_face":
			_pose("UpperArmR", Vector3(-0.9, 0, 0.35), w)
			_pose("ForearmR", Vector3(-2.3, 0, 0), w)
			head.rotation.x = lerpf(head.rotation.x, 0.3, w)
		"clutch_hand":  # holding the burned right hand (the Mark) with the left
			_pose("UpperArmR", Vector3(-0.8, 0, 0.35), w)
			_pose("ForearmR", Vector3(-1.2, 0, 0), w)
			_pose("HandR", Vector3(-0.3, 0, 0), w)
			_pose("UpperArmL", Vector3(-0.7, 0, -0.45), w)
			_pose("ForearmL", Vector3(-1.4, 0, 0), w)
			spine.rotation.x = lerpf(spine.rotation.x, 0.3 + 0.04 * sin(t * 7.0), w)
			head.rotation.x = lerpf(head.rotation.x, 0.55, w)
		"arms_crossed":
			_pose("UpperArmL", Vector3(-0.35, 0, -0.3), w)
			_pose("ForearmL", Vector3(-1.9, 0, 0), w)
			_pose("UpperArmR", Vector3(-0.3, 0, 0.3), w)
			_pose("ForearmR", Vector3(-1.95, 0, 0), w)
		"shrug":  # one lift of the shoulders, then they settle
			var up := sin(clampf(_g_time / 0.9, 0.0, 1.0) * PI)
			_pose("UpperArmL", Vector3(-0.3, 0, 0.35 * up + 0.15), w)
			_pose("UpperArmR", Vector3(-0.3, 0, -0.35 * up - 0.15), w)
			_pose("ForearmL", Vector3(-1.1, 0, 0), w)
			_pose("ForearmR", Vector3(-1.1, 0, 0), w)
			head.rotation.z = lerpf(head.rotation.z, 0.15, w)
		"nod":
			head.rotation.x = lerpf(head.rotation.x, 0.1 + 0.2 * sin(t * 6.0) * _settle(1.4), w)
		"shake_head":
			head.rotation.y = lerpf(head.rotation.y, 0.35 * sin(t * 7.0) * _settle(1.5), w)
		"lean":  # bend down to pick something up / look closer
			spine.rotation.x = lerpf(spine.rotation.x, 0.75, w)
			head.rotation.x = lerpf(head.rotation.x, 0.4, w)
			_pose("UpperArmR", Vector3(-0.9, 0, 0), w)
		"cower":
			spine.rotation.x = lerpf(spine.rotation.x, 0.5, w)
			for k in ["L", "R"]:
				_pose("UpperArm" + k, Vector3(-2.0, 0, 0.3 if k == "L" else -0.3), w)
				_pose("Forearm" + k, Vector3(-1.6, 0, 0), w)
		"raise_weapon":
			for k in ["L", "R"]:
				_pose("UpperArm" + k, Vector3(-2.8, 0, 0), w)
				_pose("Forearm" + k, Vector3(-0.4, 0, 0), w)
			spine.rotation.x = lerpf(spine.rotation.x, -0.25, w)
		"window_press":
			for k in ["L", "R"]:
				_pose("UpperArm" + k, Vector3(-1.75, 0, 0.12 if k == "L" else -0.12), w)
				_pose("Forearm" + k, Vector3(-0.45, 0, 0), w)
			head.rotation.x = lerpf(head.rotation.x, -0.05, w)
		"hands_up":
			for k in ["L", "R"]:
				_pose("UpperArm" + k, Vector3(-2.2, 0, 0.5 if k == "L" else -0.5), w)
				_pose("Forearm" + k, Vector3(-1.2, 0, 0), w)
		"beckon":
			_pose("UpperArmR", Vector3(-1.2, 0.3, -0.1), w)
			_pose("ForearmR", Vector3(-0.8 - 0.7 * maxf(0.0, sin(t * 6.0)) * _settle(2.2), 0, 0), w)
		"look_around":
			head.rotation.y = lerpf(head.rotation.y, 0.9 * sin(t * 1.3), w)
			spine.rotation.y = lerpf(spine.rotation.y, 0.25 * sin(t * 1.3), w)
		"frenzy":
			var stab := sin(t * 11.0)
			_pose("UpperArmR", Vector3(-2.3 + 0.8 * stab, 0, -0.3), w)
			_pose("ForearmR", Vector3(-0.9 - 0.6 * maxf(stab, 0.0), 0, 0), w)
			_pose("UpperArmL", Vector3(-1.2 + 0.35 * sin(t * 9.0 + 1.3), 0.2, 0.45), w)
			_pose("ForearmL", Vector3(-0.5 - 0.4 * sin(t * 9.0), 0, 0), w)
			_pose("HandL", Vector3(-0.6, 0, 0), w)
			spine.rotation.x = lerpf(spine.rotation.x, 0.35 + 0.08 * sin(t * 11.0), w)
			head.rotation.x = lerpf(head.rotation.x, -0.25, w)  # eyes up on the prey over the hunch
		"slump":
			spine.rotation.x = lerpf(spine.rotation.x, 0.45, w)
			head.rotation.x = lerpf(head.rotation.x, 0.6, w)
			for k in ["L", "R"]:
				_pose("UpperArm" + k, Vector3(0.1, 0, 0.05 if k == "L" else -0.05), w)


func _down(w: float, hips: Node3D, spine: Node3D, head: Node3D) -> void:
	## down_pose, blended by the crouch amount, chest heaving for breath. Heights come from the rig (any scale):
	## thigh T, shin S; knees on the ground puts the hips S below rest, sitting puts them just off the floor.
	var shin: float = -_rest["FootL"].y
	var thigh: float = -_rest["ShinL"].y
	var heave := 0.05 * sin(_time * 3.4)  # ragged breathing
	var y := _rest["Hips"].y as float
	match down_pose:
		"kneel":  # both knees down, upright but sagging, arms hanging
			y -= shin + 0.01
			for k in ["L", "R"]:
				_pose("Thigh" + k, Vector3(-0.05, 0, 0.06 if k == "L" else -0.06), w)
				_pose("Shin" + k, Vector3(1.5, 0, 0), w)
				_pose("Foot" + k, Vector3(0.5, 0, 0), w)
				_pose("UpperArm" + k, Vector3(0.05, 0, 0.12 if k == "L" else -0.12), w)
				_pose("Forearm" + k, Vector3(-0.2, 0, 0), w)
			spine.rotation.x = lerpf(spine.rotation.x, 0.3 + heave, w)
			head.rotation.x += 0.45 * w
		"one_knee":  # right knee down, left foot planted, forearm on the left knee
			y -= thigh
			_pose("ThighR", Vector3(0.3, 0, -0.06), w)
			_pose("ShinR", Vector3(1.15, 0, 0), w)
			_pose("FootR", Vector3(0.4, 0, 0), w)
			_pose("ThighL", Vector3(-1.57, 0, 0.1), w)
			_pose("ShinL", Vector3(1.57, 0, 0), w)
			_pose("FootL", Vector3(0.0, 0, 0), w)
			_pose("UpperArmL", Vector3(-0.2, 0, 0.1), w)
			_pose("ForearmL", Vector3(-0.6, 0, 0), w)
			_pose("UpperArmR", Vector3(0.1, 0, -0.15), w)
			_pose("ForearmR", Vector3(-0.3, 0, 0), w)
			spine.rotation.x = lerpf(spine.rotation.x, 0.5 + heave, w)
			head.rotation.x += 0.3 * w
		"hands_ground":  # on knees and hands, head hanging
			y -= shin + 0.01
			for k in ["L", "R"]:
				_pose("Thigh" + k, Vector3(-0.15, 0, 0.08 if k == "L" else -0.08), w)
				_pose("Shin" + k, Vector3(1.65, 0, 0), w)
				_pose("Foot" + k, Vector3(0.5, 0, 0), w)
				_pose("UpperArm" + k, Vector3(-1.15, 0, 0.1 if k == "L" else -0.1), w)
				_pose("Forearm" + k, Vector3(-0.1, 0, 0), w)
				_pose("Hand" + k, Vector3(-0.9, 0, 0), w)
			spine.rotation.x = lerpf(spine.rotation.x, 1.15 + heave, w)
			head.rotation.x += 0.5 * w
		"sit_back":  # thrown down on its seat, knees up, leaning back on its hands
			y = 0.21 * y / 0.95
			for k in ["L", "R"]:
				_pose("Thigh" + k, Vector3(-2.0, 0, 0.15 if k == "L" else -0.15), w)
				_pose("Shin" + k, Vector3(1.2, 0, 0), w)
				_pose("Foot" + k, Vector3(0.8, 0, 0), w)
				_pose("UpperArm" + k, Vector3(0.75, 0, 0.2 if k == "L" else -0.2), w)
				_pose("Forearm" + k, Vector3(0.0, 0, 0), w)
			spine.rotation.x = lerpf(spine.rotation.x, -0.35 + heave, w)
			head.rotation.x += 0.55 * w
		"side":  # kneeling, sagging to its right on a braced arm, the other hand on its thigh
			y -= shin + 0.01
			for k in ["L", "R"]:
				_pose("Thigh" + k, Vector3(-0.05, 0, 0.06 if k == "L" else -0.06), w)
				_pose("Shin" + k, Vector3(1.5, 0, 0), w)
				_pose("Foot" + k, Vector3(0.5, 0, 0), w)
			_pose("UpperArmL", Vector3(-0.25, 0, 0.05), w)
			_pose("ForearmL", Vector3(-0.5, 0, 0), w)
			_pose("UpperArmR", Vector3(0.0, 0, -0.35), w)
			_pose("ForearmR", Vector3(0.0, 0, 0), w)
			spine.rotation = spine.rotation.lerp(Vector3(0.3 + heave, 0.1, 0.35), w)
			head.rotation.z = lerpf(head.rotation.z, 0.3, w)
			head.rotation.x += 0.35 * w
	hips.position.y = lerpf(hips.position.y, y, w)
