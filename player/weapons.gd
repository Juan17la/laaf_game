class_name Weapons
extends Node
## What the player carries: guns (revolver, flare gun, shotgun), Owen's bow, melee weapons (fire axe, bat) and
## always the fists (FISTS: what an empty hand or an empty gun hits with; current == HOLSTERED puts every weapon
## away, the always-there first slot of the cycle: key 0, Q / mouse wheel past the last weapon, the weapon wheel's top slot). Guns are hitscan
## from the camera (the shotgun casts `pellets` rays); the bow fires a real Arrow; melee is a timed strike the
## player swings (see player.gd _strike). "kind" picks the logic, "hold" the arms (player.gd _hold).
## SWAP-SHOT: fire, then swap within SWAP_WINDOW → the swap is instant and the first shot of the
## other gun ignores its cooldown and deals DOUBLE_TAP_MULT damage ("DOUBLE TAP"). Pressing fire a
## moment before the swap lands is buffered, so click → swap+click reads as one move.

signal fired(gun: String, double_tap: bool)
signal changed
signal reload_started(gun: String, spent: int)  ## spent: empty chambers being cleared

const SWAP_WINDOW := 0.45  ## after a shot, a swap in this window is instant
const DOUBLE_TAP_MULT := 1.5
const SWAP_TIME := 0.35  ## normal holster/draw time
const FIRE_BUFFER := 0.15
const HOLSTERED := -1  ## `current` with bare fists in hand (the weapons stay carried)

const GUNS := {  # gun damage: +15% over the first balance pass (34 / 20 / 11)
	"revolver": {"name": "Revolver", "kind": "gun", "hold": "pistol", "damage": 39.1, "cooldown": 0.32, "mag": 6,
			"reload": 1.5, "spread": 0.012, "noise": 40.0, "range": 90.0, "flare": false, "color": Color(1.0, 0.85, 0.5)},
	"flare": {"name": "Flare gun", "kind": "gun", "hold": "pistol", "damage": 23.0, "cooldown": 0.6, "mag": 1,
			"reload": 1.1, "spread": 0.004, "noise": 18.0, "range": 60.0, "flare": true, "color": Color(1.0, 0.25, 0.1)},
	"shotgun": {"name": "Shotgun", "kind": "gun", "hold": "long", "damage": 12.65, "pellets": 7, "cooldown": 0.45,
			"mag": 2, "reload": 2.2, "spread": 0.07, "noise": 55.0, "range": 32.0, "flare": false,
			"color": Color(1.0, 0.7, 0.4)},
	"bow": {"name": "Hunting bow", "kind": "bow", "hold": "bow", "damage": 70.0, "cooldown": 0.3, "mag": 1,
			"reload": 0.75, "spread": 0.0, "noise": 3.0, "range": 60.0, "flare": false, "color": Color(0.8, 0.9, 0.6)},
	"axe": {"name": "Fire axe", "kind": "melee", "hold": "melee", "style": "chop", "damage": 58.0, "time": 0.8,
			"hit_at": 0.5, "reach": 1.7, "stamina": 20.0, "stun": 0.6, "noise": 10.0, "color": Color(1.0, 0.35, 0.3)},
	"bat": {"name": "Nail bat", "kind": "melee", "hold": "melee", "style": "swing", "damage": 40.0, "time": 0.62,
			"hit_at": 0.45, "reach": 1.8, "stamina": 15.0, "stun": 1.1, "noise": 9.0, "color": Color(0.9, 0.75, 0.55)},
}
## Bare hands (and the butt of a gun: "bash") when there's nothing to shoot. Punches alternate hands.
const FISTS := {"name": "Fists", "kind": "melee", "hold": "fists", "style": "jab", "damage": 13.0, "time": 0.36,
		"hit_at": 0.32, "reach": 1.25, "stamina": 6.0, "stun": 0.25, "noise": 5.0, "color": Color(0.9, 0.85, 0.75)}
const BASH := {"name": "Bash", "kind": "melee", "hold": "pistol", "style": "bash", "damage": 20.0, "time": 0.45,
		"hit_at": 0.35, "reach": 1.35, "stamina": 8.0, "stun": 0.7, "noise": 6.0, "color": Color(0.9, 0.85, 0.75)}

var owned: Array[String] = []
var current := 0
var picked := {}  ## id -> [loaded, reserve] just after it was first given (a checkpoint restore gives it back so)
var loaded := {"revolver": 0, "flare": 0, "shotgun": 0, "bow": 0, "axe": 0, "bat": 0}
var reserve := {"revolver": 0, "flare": 0, "shotgun": 0, "bow": 0, "axe": 0, "bat": 0}

var _cool := 0.0
var _reload := 0.0
var _swap := 0.0
var _since_shot := 99.0
var _double := 0.0  ## > 0: next shot is a double tap
var _buffer := 0.0


func gun() -> String:
	return owned[current] if current >= 0 and current < owned.size() else ""


func holstered() -> bool:
	## Fists in hand by choice (or nothing carried yet).
	return gun() == ""


func spec() -> Dictionary:
	## What's in hand: the current weapon, or FISTS.
	return GUNS[gun()] if gun() != "" else FISTS


func melee() -> bool:
	return spec().kind == "melee"


func dry() -> bool:
	## A gun / bow with nothing left to load: fire swings the hands (FISTS / BASH) instead.
	var g := gun()
	return g != "" and GUNS[g].kind != "melee" and loaded[g] <= 0 and reserve[g] <= 0 and _reload <= 0.0


func give(id: String, rounds := 0) -> void:
	var first := id not in owned
	if first:
		owned.append(id)
		loaded[id] = mini(rounds, GUNS[id].get("mag", 0))
		rounds -= loaded[id]
	reserve[id] += rounds
	if first:
		picked[id] = [loaded[id], reserve[id]]
	changed.emit()


func snapshot() -> Dictionary:
	## What's carried right now: weapons, rounds in them and in reserve, the one in hand.
	return {"owned": owned.duplicate(), "loaded": loaded.duplicate(), "reserve": reserve.duplicate(),
		"current": current}


func restore(snap: Dictionary) -> void:
	## Back to a snapshot(). A weapon picked up since stays (its pickup is gone from the world) with the rounds it
	## came with; the one in hand stays in hand if it's still carried. Reloads / swaps in progress are dropped.
	var held := gun()
	var fists := held == "" and not owned.is_empty()  # put away on purpose: fists stay in hand
	var since := owned.filter(func(id: String) -> bool: return id not in snap.owned)
	owned.assign(snap.owned)
	loaded = (snap.loaded as Dictionary).duplicate()
	reserve = (snap.reserve as Dictionary).duplicate()
	for id in since:
		owned.append(id)
		loaded[id] = picked.get(id, [0, 0])[0]
		reserve[id] = picked.get(id, [0, 0])[1]
	if fists or (int(snap.current) == HOLSTERED and held not in owned):
		current = HOLSTERED
	else:
		current = owned.find(held) if held in owned else clampi(int(snap.current), 0, maxi(owned.size() - 1, 0))
	_reload = 0.0
	_swap = 0.0
	_buffer = 0.0
	_double = 0.0
	_cool = 0.0
	changed.emit()


func top_up(id: String, rounds: int) -> void:
	## At least `rounds` in all for a carried gun (loaded + reserve), the magazine filled from them.
	if id not in owned or GUNS[id].kind == "melee":
		return
	reserve[id] += maxi(rounds - loaded[id] - reserve[id], 0)
	var n := mini(GUNS[id].mag - loaded[id], reserve[id])
	loaded[id] += n
	reserve[id] -= n
	changed.emit()


func busy() -> bool:
	return _reload > 0.0 or _swap > 0.0


func reloading() -> bool:
	return _reload > 0.0


func tick(delta: float) -> bool:
	## Advance timers. Returns true when a buffered shot should fire now.
	_cool = maxf(_cool - delta, 0.0)
	_since_shot += delta
	_double = maxf(_double - delta, 0.0)
	_buffer = maxf(_buffer - delta, 0.0)
	if _swap > 0.0:
		_swap = maxf(_swap - delta, 0.0)
	if _reload > 0.0:
		_reload -= delta
		if _reload <= 0.0:
			var g := gun()
			var n := mini(GUNS[g].mag - loaded[g], reserve[g])
			loaded[g] += n
			reserve[g] -= n
			changed.emit()
	return _buffer > 0.0 and can_fire()


func can_fire() -> bool:
	var g := gun()
	return g != "" and GUNS[g].kind != "melee" and not busy() and loaded[g] > 0 and (_cool <= 0.0 or _double > 0.0)


func swap(to := -1) -> void:
	## to < 0: the next one round the cycle (fists, then each weapon carried, then fists again); else that slot.
	var next := to
	if to < 0:
		if owned.is_empty():
			return
		next = 0 if holstered() else (HOLSTERED if current + 1 >= owned.size() else current + 1)
	elif to >= owned.size():
		return
	_draw(next)


func holster() -> void:
	## Every weapon away: bare fists (key 0, the weapon wheel's top slot).
	_draw(HOLSTERED)


func _draw(next: int) -> void:
	if next == current or (next == HOLSTERED and holstered()):
		return
	current = next
	_reload = 0.0
	if _since_shot < SWAP_WINDOW:
		_swap = 0.0
		_double = SWAP_WINDOW
		_cool = 0.0
	else:
		_swap = SWAP_TIME
	changed.emit()


func reload() -> void:
	var g := gun()
	if g != "" and GUNS[g].kind != "melee" and _reload <= 0.0 and loaded[g] < GUNS[g].mag and reserve[g] > 0:
		_reload = GUNS[g].reload
		reload_started.emit(g, GUNS[g].mag - loaded[g])
		changed.emit()


func request_fire() -> bool:
	## Called on a fire press. Returns true if the shot happens now; otherwise it may be buffered.
	var g := gun()
	if g == "" or GUNS[g].kind == "melee":
		return false
	if loaded[g] <= 0 and not busy():
		reload()
		return false
	if can_fire():
		return true
	_buffer = FIRE_BUFFER
	return false


func loose() -> void:
	## The bow: the nocked arrow leaves (player.gd flies it as a real Arrow).
	var g := gun()
	loaded[g] -= 1
	_cool = GUNS[g].cooldown
	_double = 0.0
	_buffer = 0.0
	_since_shot = 0.0
	fired.emit(g, false)
	changed.emit()


func shoot(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, exclude: Array[RID],
		spread_mult := 1.0) -> Dictionary:
	## Consume a round and cast the shot. Returns {hit, point, collider, double_tap, gun, impacts}; impacts: one
	## [point, normal, collider] per pellet that struck something (the player puts sparks / blood there).
	var g := gun()
	var spec: Dictionary = GUNS[g]
	var dt := _double > 0.0
	loaded[g] -= 1
	_cool = spec.cooldown
	_double = 0.0
	_buffer = 0.0
	_since_shot = 0.0
	var s: float = spec.spread * spread_mult
	var aim := dir
	var out := {}
	var hits := {}  ## collider → pellets that hit it (one hit() call each: a flinch per shot, not per pellet)
	var impacts := []
	for i in spec.get("pellets", 1):
		dir = (aim + Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))).normalized()
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * spec.range, 0b11, exclude)
		var hit := space.intersect_ray(q)
		var o := {"hit": not hit.is_empty(), "point": hit.get("position", from + dir * spec.range),
				"collider": hit.get("collider"), "double_tap": dt, "gun": g}
		if out.is_empty() or (o.collider and not out.collider):
			out = o
		if o.hit:
			impacts.append([o.point, hit.get("normal", -dir), o.collider])
		var body: Object = o.collider
		if body and body.has_method("hit"):
			hits[body] = [hits.get(body, [0])[0] + 1, o.point]
	for body in hits:
		var dmg: float = spec.damage * hits[body][0] * (DOUBLE_TAP_MULT if dt else 1.0)
		body.hit(dmg, hits[body][1], spec.flare)
	out["pellets"] = spec.get("pellets", 1)
	out["impacts"] = impacts
	fired.emit(g, dt)
	changed.emit()
	return out
