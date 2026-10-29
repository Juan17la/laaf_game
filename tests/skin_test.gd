extends SceneTree
## Headless check of the skinned characters (tools/psx_chars.py, humanoid_anim.gd _skin): through a run, a crouch and
## an aim every bone a joint carries stays on that joint (same place, same turn from rest), and a hand closes once it
## holds something (its fingertips come in toward the palm) and opens again when it lets go.
## flatpak run org.godotengine.Godot --headless --path . -s tests/skin_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	push_error("SKIN FAIL: " + msg)
	quit(1)


func _run() -> void:
	for name in ["char_alex", "char_owen"]:  # a mitten hand and a five-finger one (both empty-handed)
		var model: Node3D = load("res://models/%s.glb" % name).instantiate()
		root.add_child(model)
		var anim: HumanoidAnim = load("res://scripts/humanoid_anim.gd").new()
		model.add_child(anim)
		var skel := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var rest := {}  # joint → [joint pose, bone pose] at rest, both in the model
		for j: String in HumanoidAnim.SKIN:
			var n := anim.joint(j) if j != "Neck" else model.find_child("Neck", true, false) as Node3D
			var b := skel.find_bone(HumanoidAnim.SKIN[j])
			if n and b >= 0:
				rest[j] = [n.global_transform, skel.global_transform * skel.get_bone_global_pose(b)]
		if rest.size() < 15:
			_fail("%s: only %d joints carry bones" % [name, rest.size()])
			return
		for state in ["run", "crouch", "aim"]:
			anim.speed = 5.2 if state == "run" else 0.0
			anim.crouching = state == "crouch"
			anim.aim = 1.0 if state == "aim" else 0.0
			for i in 50:
				anim._process(1.0 / 60.0)
			for j: String in rest:
				var n := anim.joint(j) if j != "Neck" else model.find_child("Neck", true, false) as Node3D
				var bone := skel.global_transform * skel.get_bone_global_pose(skel.find_bone(HumanoidAnim.SKIN[j]))
				# the bone moved exactly as its joint did since rest
				var want: Transform3D = n.global_transform * rest[j][0].affine_inverse() * rest[j][1]
				var turn := bone.basis.get_rotation_quaternion().angle_to(want.basis.get_rotation_quaternion())
				if bone.origin.distance_to(want.origin) > 0.002 or turn > 0.01:
					_fail("%s %s: bone %s is %.3f m, %.3f rad off its joint" % [name, state, j,
						bone.origin.distance_to(want.origin), turn])
					return
		anim.aim = 0.0
		var tip := skel.find_bone("m_RightHandIndex3")
		var palm := skel.find_bone("m_RightHand")
		var gap := func() -> float:
			return skel.get_bone_global_pose(tip).origin.distance_to(skel.get_bone_global_pose(palm).origin)
		for i in 60:
			anim._process(1.0 / 60.0)
		var open: float = gap.call()
		var held := Node3D.new()
		anim.joint("HandR").add_child(held)
		for i in 30:
			anim._process(1.0 / 60.0)
		if anim.grip.R < 0.99 or gap.call() > open - 0.005:
			_fail("%s: the right hand doesn't close on what it holds (grip %.2f, fingertip %.3f → %.3f)" % [
				name, anim.grip.R, open, gap.call()])
			return
		held.free()
		for i in 30:
			anim._process(1.0 / 60.0)
		if anim.grip.R > 0.01:
			_fail("%s: the right hand stays closed after letting go" % name)
			return
		model.free()
	print("SKIN OK")
	quit(0)
