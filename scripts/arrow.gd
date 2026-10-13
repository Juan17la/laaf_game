class_name Arrow
extends Node3D
## An arrow (Owen's, or Alex's from Owen's bow): fast projectile with a slight drop. Ray-steps each frame so
## it can't tunnel; a roll's i-frames make it pass through the player. The player's arrows hit enemies
## (anything with hit()) and stick where they land.

const ItemFx := preload("res://scripts/item_fx.gd")

var velocity := Vector3.ZERO
var damage := 14.0
var shooter: Node
var _life := 3.0


static func fire(parent: Node, from: Vector3, at: Vector3, dmg: float, by: Node, speed := 24.0) -> Arrow:
	var a := Arrow.new()
	a.damage = dmg
	a.shooter = by
	var path := "res://models/item_arrow.glb"
	if ResourceLoader.exists(path):
		var m: Node3D = (load(path) as PackedScene).instantiate()
		a.add_child(m)
		m.position.z = 0.36  # the model's origin is its nock: centre the shaft on the flight point
	else:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.02, 0.02, 0.7)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.25, 0.15)
		m.material = mat
		mi.mesh = m
		a.add_child(mi)
	parent.add_child(a)
	a.global_position = from
	a.velocity = (at - from).normalized() * speed
	a.look_at(at)
	return a


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	velocity.y -= 2.0 * delta
	var next := global_position + velocity * delta
	var ex: Array[RID] = []
	if is_instance_valid(shooter):
		ex.append(shooter.get_rid())
	var mine := is_instance_valid(shooter) and shooter.is_in_group("player")
	var hit := get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(global_position, next, 0b11 if mine else 1, ex))
	if not hit.is_empty():
		var body: Object = hit.collider
		if body.is_in_group("player"):
			if not body.hurt(damage, global_position, Feel.MARK_GAIN.arrow):
				global_position = next  # dodged: fly on
				return
		elif mine and body.has_method("hit"):
			body.hit(damage, hit.position)
			if body is Enemy:
				ItemFx.burst(get_parent(), hit.position, "splatter", -velocity.normalized())
				body.hitstop(Feel.HITSTOP.bow)
			if body is Node3D:  # stuck in them: it rides along until it drops out
				reparent(body)
		set_physics_process(false)
		global_position = hit.position
		get_tree().create_timer(4.0).timeout.connect(queue_free)
		return
	look_at(next + velocity)
	global_position = next
