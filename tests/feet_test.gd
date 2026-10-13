extends SceneTree
## Headless check: through a whole run cycle no character's planted foot sinks below the ground; crouched (still
## and sneaking) the hips drop, the knees bend forward over flat feet and never rise past the hips; standing back
## up returns to full height. On Alex and characters sharing the rig (enemies, actors).
## flatpak run org.godotengine.Godot --headless --path . -s tests/feet_test.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for name in ["char_alex", "char_lucia", "char_owen", "char_marcus"]:
		var model: Node3D = load("res://models/%s.glb" % name).instantiate()
		root.add_child(model)
		var anim: Node = load("res://scripts/humanoid_anim.gd").new()
		model.add_child(anim)
		anim.speed = 5.2
		var rest := INF
		for k in ["L", "R"]:
			rest = minf(rest, model.to_local((model.find_child("Foot" + k, true, false) as Node3D).global_position).y)
		var low := INF
		for i in 120:
			anim._process(1.0 / 60.0)
			for k in ["L", "R"]:
				low = minf(low, model.to_local((model.find_child("Foot" + k, true, false) as Node3D).global_position).y)
		if low < rest - 0.002:
			push_error("FEET FAIL: %s ankle dips %.3f m below rest while running" % [name, rest - low])
			quit(1)
			return
		# crouched (still, then sneaking): hips low and back, knees forward of the feet, soles on the ground,
		# and no knee ever comes up past the hips (it used to reach the chest mid-stride)
		anim.speed = 0.0
		for i in 90:  # settle standing still first
			anim._process(1.0 / 60.0)
		var hips: Node3D = model.find_child("Hips", true, false)
		var hip_rest := model.to_local(hips.global_position).y
		anim.crouching = true
		for phase in [0.0, 1.3]:
			anim.speed = phase
			for i in 150:
				anim._process(1.0 / 60.0)
				var hy := model.to_local(hips.global_position).y
				for k in ["L", "R"]:
					var knee := model.to_local((model.find_child("Shin" + k, true, false) as Node3D).global_position)
					var foot := model.to_local((model.find_child("Foot" + k, true, false) as Node3D).global_position)
					if foot.y < rest - 0.01 or knee.y > hy + 0.02 or (i > 60 and phase == 0.0
							and (knee.z < foot.z + 0.08 or foot.y > rest + 0.03 or hy > hip_rest - 0.2)):
						push_error("FEET FAIL: %s crouch%s: hips %.2f (rest %.2f) knee %s foot %s" % [name,
							" walk" if phase > 0.0 else "", hy, hip_rest, knee, foot])
						quit(1)
						return
		anim.crouching = false
		anim.speed = 0.0
		for i in 90:  # standing up: back to full height, feet still down
			anim._process(1.0 / 60.0)
		if absf(model.to_local(hips.global_position).y - hip_rest) > 0.05:
			push_error("FEET FAIL: %s didn't stand back up: hips %.2f (rest %.2f)" % [name,
				model.to_local(hips.global_position).y, hip_rest])
			quit(1)
			return
		model.queue_free()
	print("FEET OK")
	quit(0)
