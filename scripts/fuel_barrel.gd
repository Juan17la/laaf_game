class_name FuelBarrel
extends StaticBody3D
## Red fuel drum: shoot it (or hit it with a flare) and it bursts into a fire pool for a few
## seconds. Fire hurts everyone inside and stuns anything with flare_stun (Owen fears fire).

const RADIUS := 3.2
const BURN := 7.0

var _fire := 0.0
var _light: OmniLight3D
var _tick := 0.0


static func make(parent: Node, pos: Vector3) -> FuelBarrel:
	var b := FuelBarrel.new()
	b.collision_layer = 3
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.35
	cyl.height = 0.95
	col.shape = cyl
	col.position.y = 0.475
	b.add_child(col)
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.33
	m.bottom_radius = 0.33
	m.height = 0.95
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.06, 0.04)
	mat.roughness = 0.6
	m.material = mat
	mi.mesh = m
	mi.position.y = 0.475
	b.add_child(mi)
	parent.add_child(b)
	b.global_position = pos
	return b


func hit(_dmg: float, _point: Vector3, _flare := false) -> void:
	if _fire > 0.0:
		return
	_fire = BURN
	get_child(1).visible = false
	collision_layer = 0
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.15)
	_light.light_energy = 4.0
	_light.omni_range = 9.0
	_light.set_script(load("res://scripts/flicker.gd"))
	add_child(_light)
	_light.position.y = 1.0
	var flames := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.2
	m.bottom_radius = RADIUS * 0.8
	m.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	flames.mesh = m
	flames.position.y = 0.8
	add_child(flames)
	get_tree().call_group("enemies", "hear", global_position, 25.0)
	Snd.sfx("gun_flare", global_position, -4.0)
	Snd.attach(self, "hiss", -2.0)


func _physics_process(delta: float) -> void:
	if _fire <= 0.0:
		return
	_fire -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.5
		for n in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("player"):
			if n is Enemy and (n as Enemy).state == Enemy.State.DOWN:
				continue  # a kneeling boss waits for spare / kill: the fire never decides it (a hit would kill)
			if n.global_position.distance_to(global_position) < RADIUS:
				if n.has_method("stagger") and n.flare_stun > 0.0:
					n.stagger(n.flare_stun)
				if n.has_method("hurt"):
					n.hurt(8.0, global_position)
				elif n.has_method("hit"):
					n.hit(10.0, n.global_position, false)
	if _fire <= 0.0:
		queue_free()
