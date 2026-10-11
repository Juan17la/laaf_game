class_name Floodlight
extends Node3D
## Chapter 3 finale: an old quarry floodlight on its own generator (the 03:00 blackout doesn't reach it).
## Throw the switch at the generator (E): a crank QTE first unless `primed` (the freed cage prisoners
## got the generators ready). The beam burns ON_TIME s on a ground spot; anything with light_stun()
## within REACH of that spot is stunned (the Harvester has its own immunity window). Then the bulb pops
## and the rig needs COOL s. `armed` = false keeps the switch dead (phase 1).
## Placeholder meshes: see maps/docs/en/ch3_objects_to_generate.md (prop_floodlight_rig).

signal lit
signal stunned(e: Node)

const ON_TIME := 8.0
const COOL := 10.0
const REACH := 6.5

var primed := false
var armed := false
var spot := Vector3.ZERO
var switch: Interactable
var _hud: Node
var _beam: SpotLight3D
var _lens: StandardMaterial3D
var _on := 0.0
var _cool := 0.0
var _tick := 0.0
var _busy := false
var _gen_snd: Node


static func make(parent: Node, pos: Vector3, aim: Vector3, hud: Node) -> Floodlight:
	var f := Floodlight.new()
	f._hud = hud
	f.spot = aim
	f.position = pos  # parents sit at the world origin
	parent.add_child(f)
	return f


func _ready() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.3, 0.3, 0.32)
	steel.metallic = 0.6
	_box(Vector3(0.18, 5.0, 0.18), Vector3(0, 2.5, 0), steel)  # pole
	var body := StaticBody3D.new()  # the pole stops Alex (and the camera) like any post
	var col := CollisionShape3D.new()
	var pole := BoxShape3D.new()
	pole.size = Vector3(0.18, 5.0, 0.18)
	col.shape = pole
	col.position.y = 2.5
	body.add_child(col)
	add_child(body)
	var head := Node3D.new()
	add_child(head)
	head.position.y = 5.1
	head.look_at(spot + Vector3.UP * 0.5, Vector3.UP)
	var h := _box(Vector3(1.0, 0.7, 0.45), Vector3.ZERO, steel)
	h.reparent(head, false)
	_lens = StandardMaterial3D.new()
	_lens.albedo_color = Color(0.5, 0.5, 0.45)
	_lens.emission_enabled = true
	_lens.emission = Color(1.0, 0.95, 0.8)
	_lens.emission_energy_multiplier = 0.0
	var lens := _box(Vector3(0.85, 0.55, 0.05), Vector3.ZERO, _lens)
	lens.reparent(head, false)
	lens.position = Vector3(0, 0, -0.25)
	_beam = SpotLight3D.new()
	_beam.light_color = Color(1.0, 0.96, 0.85)
	_beam.light_energy = 0.0
	_beam.light_volumetric_fog_energy = 4.0
	_beam.spot_range = position.distance_to(spot) + 8.0
	_beam.spot_angle = rad_to_deg(atan2(REACH, position.distance_to(spot)))
	_beam.shadow_enabled = true
	head.add_child(_beam)
	_beam.position.z = -0.3
	var gen: Node3D = (load("res://models/ext_generator.glb") as PackedScene).instantiate()
	add_child(gen)
	var side := (spot - position).cross(Vector3.UP).normalized()
	gen.position = side * 1.4
	switch = Interactable.make(self, global_position + side * 1.4 + Vector3.UP * 1.0, "Throw the floodlight switch",
		_throw, Color(1.0, 0.95, 0.7))
	switch.once = false
	switch.enabled = false


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	add_child(mi)
	mi.position = at
	return mi


func arm(on: bool) -> void:
	armed = on
	_refresh()


func is_on() -> bool:
	return _on > 0.0


func reset() -> void:
	## Checkpoint reload: dark, cold, disarmed.
	_on = 0.0
	_cool = 0.0
	_busy = false
	_beam.light_energy = 0.0
	_lens.emission_energy_multiplier = 0.0
	arm(false)


func _refresh() -> void:
	if is_instance_valid(switch):
		switch.enabled = armed and not _busy and _on <= 0.0 and _cool <= 0.0
		switch.prompt = "Throw the floodlight switch" if primed else "Crank the generator"


func _throw(by: Node) -> void:
	if _busy or _on > 0.0 or _cool > 0.0:
		return
	_busy = true
	_refresh()
	var ok := true
	if not primed:
		by.set("controls_enabled", false)
		ok = await _hud.qte("interact", 8, 3.0)
		by.set("controls_enabled", true)
		by.noise(12.0)
	_busy = false
	if ok:
		_on = ON_TIME
		_tick = 0.0
		_gen_snd = Snd.attach(self, "generator", 3.0)
		lit.emit()
	_refresh()


func _physics_process(delta: float) -> void:
	if _cool > 0.0:
		_cool -= delta
		if _cool <= 0.0:
			_refresh()
	if _on <= 0.0:
		return
	_on -= delta
	_beam.light_energy = 14.0 * clampf(_on * 3.0, 0.0, 1.0)
	_lens.emission_energy_multiplier = 3.0 * clampf(_on * 3.0, 0.0, 1.0)
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.2
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.has_method("light_stun") and Vector2(e.global_position.x - spot.x, e.global_position.z - spot.z).length() < REACH:
				if e.light_stun():
					stunned.emit(e)
	if _on <= 0.0:  # the bulb pops
		Snd.stop(_gen_snd)
		Snd.sfx("glass", global_position, -4.0)
		_cool = COOL
		_beam.light_energy = 0.0
		_lens.emission_energy_multiplier = 0.0
		_refresh()
