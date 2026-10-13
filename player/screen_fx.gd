class_name ScreenFx
extends Control
## What the Mark and pain do to the screen and the ears (values: scripts/feel.gd). Each Mark effect fades in
## smoothly around its threshold (Feel.ramp) and they stack:
##   >= 25 %  whispers now and then, behind Alex, on the Voice bus (audio/sfx_whisper_*)
##   >= 50 %  a tighter vignette that throbs with a heartbeat (its own beat, or the low-health one)
##   >= 75 %  a faint base colour split + wobble (ps2_post.gdshader)
##   >= Feel.APPARITION_AT  now and then, rarely, the Harvester standing far off in the dark (Apparition)
## Spikes (spike()): the distortion flares and fades over a couple of seconds on a hit that marks Alex, when
## something starts hunting him, and on story beats (HUD.mark_spike). Near a boss / the Harvester a faint steady
## ambience instead (boss_ambience(): no spikes, eased in and out). In a fight (aiming, or anyone hunting him) the
## base and spikes are held down to Feel.COMBAT_DISTORT at once (let go slowly after) and the total never passes
## Feel.COMBAT_MAX_*, so it never gets in the way of aiming.
## Hits: blurred red edges, stronger the less health is left; under Feel.HURT_EDGE_LOW they stay.
## Owned by the HUD (hud.gd); drives the Post ColorRect's shader uniforms. All of it is cosmetic.

const SPIKE_RISE := 0.15  ## s a spike takes to come up

var player: Node
var post: ShaderMaterial
var _pulse := 0.0
var _hurt_hit := 0.0
var _whisper_t := 0.0
var _beat_t := 0.0
var _spike_peak := 0.0  ## where the spike is heading (decays over Feel.SPIKE_FADE)
var _spike := 0.0  ## the spike on screen now (rises to the peak, then follows it down)
var _boss_amb := 0.0  ## the boss ambience on screen now (spike units, eased toward boss_ambience())
var _fight_k := 1.0  ## the fight hold on screen now: Feel.COMBAT_DISTORT in a fight, eased back to 1 after
var _fighting := false
var _appar_t := -1.0  ## s to the next sighting try (< 0: the Mark hasn't reached Feel.APPARITION_AT yet)
var _apparition: Apparition


func setup(p: Node, mat: ShaderMaterial) -> void:
	player = p
	post = mat
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("screen_fx")
	if player.has_signal("beat"):
		player.beat.connect(_on_beat)
	if player.has_signal("marked"):
		player.marked.connect(func(gain: float) -> void:
			spike(Feel.SPIKE_HIT * minf(gain / Feel.SPIKE_HIT_FULL, 1.0)))
	_whisper_t = Feel.WHISPER_EVERY.y


func strengths() -> Vector3:
	## How far into each Mark effect Alex is, 0..1: (whispers, vignette + heartbeat, base distortion).
	var m: float = player.mark
	return Vector3(Feel.ramp(m, Feel.MARK_WHISPER_AT), Feel.ramp(m, Feel.MARK_VIGNETTE_AT),
		Feel.ramp(m, Feel.MARK_DISTORT_AT))


func spike(amount: float) -> void:
	## A flare of distortion (0..1) that comes up fast and fades over Feel.SPIKE_FADE s. The strongest one wins.
	_spike_peak = maxf(_spike_peak, clampf(amount * Feel.SPIKE_SCALE, 0.0, 1.0))


func distortion() -> Vector2:
	## (colour split, wobble) going to the shader now: the Mark's base + the spike held down by the fight hold, plus
	## the boss ambience; in a fight never past Feel.COMBAT_MAX_*.
	var s := strengths()
	var ab := (s.z * Feel.MARK_ABERRATION + _spike * Feel.SPIKE_ABERRATION) * _fight_k + _boss_amb * Feel.SPIKE_ABERRATION
	var wp := (s.z * Feel.MARK_WARP + _spike * Feel.SPIKE_WARP) * _fight_k + _boss_amb * Feel.SPIKE_WARP
	if _fighting:
		ab = minf(ab, Feel.COMBAT_MAX_ABERRATION)
		wp = minf(wp, Feel.COMBAT_MAX_WARP)
	return Vector2(ab, wp) * Feel.mark_fx


func boss_ambience() -> float:
	## The steady distortion (spike units) a boss / the Harvester brings: full within Feel.SPIKE_BOSS_NEAR, thinning
	## to nothing over the next Feel.BOSS_AMBIENCE_FADE m. The strongest one wins.
	var out := 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.boss and e.state != Enemy.State.DEAD and e.is_physics_processing():
			var d: float = e.global_position.distance_to(player.global_position)
			var near := 1.0 - smoothstep(Feel.SPIKE_BOSS_NEAR, Feel.SPIKE_BOSS_NEAR + Feel.BOSS_AMBIENCE_FADE, d)
			out = maxf(out, near * (Feel.SPIKE_HARVESTER if e is Harvester else Feel.SPIKE_BOSS))
	return out * Feel.SPIKE_SCALE


func in_fight() -> bool:
	## Aiming, anything hunting Alex, or a boss close by (a boss fight is one even while it's searching / stunned).
	if player.get("aiming"):
		return true
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy and e.is_physics_processing() and e.state != Enemy.State.DEAD):
			continue
		if e.state == Enemy.State.CHASE or (e.boss and e.global_position.distance_to(player.global_position)
				< Feel.SPIKE_BOSS_NEAR):
			return true
	return false


func on_hurt() -> void:
	## A hit landed (HUD.damage_flash): edges flare, harder the less health is left.
	var frac: float = clampf(player.health / player.health_max, 0.0, 1.0)
	_hurt_hit = maxf(_hurt_hit, lerpf(1.0, Feel.HURT_EDGE, frac))


func _on_beat() -> void:
	_pulse = maxf(_pulse, Feel.MARK_PULSE * strengths().y)


func _process(delta: float) -> void:
	if not player or not post:
		return
	var s := strengths()
	var live: bool = player.controls_enabled and not player.dead
	# heartbeat (the Mark's own, unless the low-health one is already thudding)
	var low: bool = player.health / player.health_max <= 0.4
	if live and s.y > 0.0 and not low:
		_beat_t -= delta
		if _beat_t <= 0.0:
			var k := clampf((player.mark - Feel.MARK_VIGNETTE_AT) / (100.0 - Feel.MARK_VIGNETTE_AT), 0.0, 1.0)
			_beat_t = lerpf(Feel.MARK_BEAT_EVERY.x, Feel.MARK_BEAT_EVERY.y, k)
			Snd.sfx("heartbeat", null, Feel.MARK_BEAT_DB * (2.0 - s.y))
			_on_beat()
	_pulse = maxf(_pulse - Feel.PULSE_DECAY * delta, 0.0)
	# whispers
	if live and Feel.whispers and s.x > 0.0:
		_whisper_t -= delta
		if _whisper_t <= 0.0:
			_whisper_t = lerpf(Feel.WHISPER_EVERY.y, Feel.WHISPER_EVERY.x, s.x) * randf_range(0.8, 1.2)
			_whisper(s.x)
	# spikes fade; the boss ambience eases toward its level (exponentially: no corners, no flare)
	_spike_peak = maxf(_spike_peak - delta / Feel.SPIKE_FADE, 0.0)
	_spike = move_toward(_spike, _spike_peak, delta / SPIKE_RISE) if _spike < _spike_peak else _spike_peak
	var amb := boss_ambience()
	_boss_amb = lerpf(_boss_amb, amb, 1.0 - exp(-delta / Feel.BOSS_AMBIENCE_EASE))
	if absf(_boss_amb - amb) < 0.001:  # (the tail of an exponential never lands: the plain look stays exactly plain)
		_boss_amb = amb
	# the fight hold: clamps down the moment a fight starts, lets go slowly once it's over
	_fighting = in_fight()
	_fight_k = Feel.COMBAT_DISTORT if _fighting \
		else move_toward(_fight_k, 1.0, delta * (1.0 - Feel.COMBAT_DISTORT) / Feel.COMBAT_EASE)
	# hurt edges: a hit's flare fading, over what low health leaves
	_hurt_hit = maxf(_hurt_hit - delta / Feel.HURT_EDGE_TIME, 0.0)
	var frac: float = clampf(player.health / player.health_max, 0.0, 1.0)
	var stay := (1.0 - frac / Feel.HURT_EDGE_LOW) * Feel.HURT_EDGE_PERSIST if frac < Feel.HURT_EDGE_LOW else 0.0
	var dist := distortion()
	post.set_shader_parameter("vignette_extra", s.y * Feel.MARK_VIGNETTE * Feel.mark_fx)
	post.set_shader_parameter("pulse", _pulse * Feel.mark_fx)
	post.set_shader_parameter("aberration", dist.x)
	post.set_shader_parameter("warp", dist.y)
	post.set_shader_parameter("hurt", maxf(_hurt_hit, stay) * Feel.hurt_fx if not player.dead else 0.0)
	_apparitions(delta, live)


func _apparitions(delta: float, live: bool) -> void:
	## Past Feel.APPARITION_AT, once in a long while, the Harvester stands far off in the dark (scripts/apparition.gd).
	## The clock only runs while a sighting could happen: in control, not aiming, nothing hunting Alex.
	if is_instance_valid(_apparition):
		return
	if player.mark < Feel.APPARITION_AT or not Feel.hallucinations:
		return
	if _appar_t < 0.0:
		_appar_t = Feel.APPARITION_FIRST
	if not live or in_fight():
		return
	_appar_t -= delta
	if _appar_t > 0.0:
		return
	_apparition = Apparition.try_spawn(player)
	_appar_t = randf_range(Feel.APPARITION_EVERY.x, Feel.APPARITION_EVERY.y) if _apparition else Feel.APPARITION_RETRY


func _whisper(strength: float) -> void:
	## Behind Alex and to one side, close: something says something.
	var cam: Camera3D = player.get("camera")
	var at: Vector3 = player.global_position + Vector3.UP * 1.6
	if cam:
		var b := cam.global_basis
		at += (b.z * 0.7 + b.x * (1.0 if randf() < 0.5 else -1.0)).normalized() * Feel.WHISPER_DIST
	Snd.sfx("whisper", at, lerpf(Feel.WHISPER_DB.y, Feel.WHISPER_DB.x, strength), randf_range(0.85, 1.05), "Voice")
