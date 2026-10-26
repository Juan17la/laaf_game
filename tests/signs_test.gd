extends SceneTree
## Headless check of every world sign (the Label3Ds under maps/hollowmere.tscn "Signs", tools/build_assets.py
## W.label): each one's text has to sit on a board and read cleanly, measured against the real meshes around it
## (trimesh stand-ins built for the check):
##   on a board: straight behind the text, within BOARD_GAP, a surface facing the same way (not text in the air, not
##   z-fighting: never closer than MIN_GAP)
##   fits: the text's box inside that board with MARGIN to spare all round (the board is measured by rays)
##   not clipped: nothing in front of the text within CLEAR (an awning, a header, the roof)
##   faces out: single-sided, its front toward open air
##   readable at 640x360: capitals at least MIN_CAP tall, glyphs rasterised no coarser than MAX_TEXEL per texel
## In every language (LANGUAGES): the notices that translate (scripts/sign_label.gd) are measured as they read in
## English and in Spanish, the town's own names (auto_translate off) are the same in both.
## Prints each sign's board and text box.  godot --headless --path . -s tests/signs_test.gd [-- --verbose]

const BOARD_GAP := 0.08  ## m: the board is at most this far behind the text...
const MIN_GAP := 0.004  ## ...and at least this far (closer z-fights)
const MARGIN := [0.02, 0.12, 0.065]  ## board left round the text: 12% of its height, 2-6.5 cm (build_assets
## LABEL_MARGIN keeps more; a plate flush with the wall measures as tall as the wall, hence the cap)
const CLEAR := 0.4  ## m in front of the text that must be open
const MIN_CAP := 0.05  ## m: smallest capitals (a plaque read up close)
const MAX_TEXEL := 0.02  ## m per font texel: coarser and the letters break up into blocks
const CAP := 0.72  ## the default font's capital height, in ems
const STAND_IN := 1 << 18  ## collision layer of the meshes' stand-in shapes
const LANGUAGES := ["en", "es"]

var _space: PhysicsDirectSpaceState3D
var _verbose := false


func _initialize() -> void:
	_verbose = "--verbose" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, STAND_IN)
	q.hit_back_faces = false
	return _space.intersect_ray(q)


func _depth(l: Label3D, x: float, y: float) -> float:
	## How far behind the label plane the first surface facing the reader is at local (x, y); INF = none.
	var front := l.global_basis.z.normalized()
	var p := l.global_transform * Vector3(x, y, 0)
	var hit := _ray(p + front * 0.02, p - front * BOARD_GAP * 2.0)
	if hit.is_empty() or (hit.normal as Vector3).dot(front) < 0.7:
		return INF
	return (p - (hit.position as Vector3)).dot(front)


func _extent(l: Label3D, d0: float, axis: Vector2, start: float) -> float:
	## How far the board runs from the text centre along axis (label space), stepping until it ends or steps away.
	var s := start
	var miss := 0
	while s < 8.0:
		var d := _depth(l, axis.x * (s + 0.01), axis.y * (s + 0.01))
		miss = miss + 1 if d == INF or absf(d - d0) > 0.03 else 0
		if miss == 2:  # (one ray alone can slip through a seam between two triangles)
			return s - 0.01
		s += 0.01
	return s


func _run() -> void:
	var world: Node = load("res://maps/hollowmere.tscn").instantiate()
	for d in ["Chapter1", "Chapter2", "Chapter3"]:
		world.get_node(d).set_script(null)
	var p := world.get_node("Player")
	world.remove_child(p)
	p.free()
	root.add_child(world)
	var labels: Array[Label3D] = []
	for n in world.get_node("Signs").get_children():
		if n is Label3D:
			labels.append(n)
	# stand-in collision for every mesh near a sign
	var meshes := world.find_children("*", "MeshInstance3D", true, false)
	var done := {}
	for l in labels:
		for m in meshes:
			var mi := m as MeshInstance3D
			if done.has(mi) or not mi.mesh:
				continue
			var box := mi.global_transform * mi.get_aabb()
			if box.grow(1.0).has_point(l.global_position):
				done[mi] = true
				var body := StaticBody3D.new()
				body.collision_layer = STAND_IN
				body.collision_mask = 0
				var cs := CollisionShape3D.new()
				cs.shape = mi.mesh.create_trimesh_shape()
				body.add_child(cs)
				mi.add_child(body)
	for i in 4:
		await physics_frame
	_space = world.get_world_3d().direct_space_state
	var bad := 0
	var boot := TranslationServer.get_locale()
	for lang in LANGUAGES:
		TranslationServer.set_locale(lang)  # (Label3D re-shapes its text, sign_label.gd its size, on the next frame)
		for i in 2:
			await process_frame
		print("-- %s" % lang)
		bad += _check_signs(labels)
	TranslationServer.set_locale(boot)
	if bad > 0:
		push_error("SIGNS FAIL: %d sign checks (of %d signs, %d languages)" % [bad, labels.size(), LANGUAGES.size()])
		quit(1)
		return
	print("SIGNS OK (%d, in %s)" % [labels.size(), ", ".join(LANGUAGES)])
	quit(0)


func _check_signs(labels: Array[Label3D]) -> int:
	## Every sign as it reads in the current language; returns how many have a problem.
	var bad := 0
	for l in labels:
		var problems: Array[String] = []
		var text := l.get_aabb()  # (local: x along the text, y up, centred on the origin)
		var px := l.pixel_size
		var cap := CAP * l.font_size * px
		if cap < MIN_CAP:
			problems.append("capitals %.3f m tall (min %.2f)" % [cap, MIN_CAP])
		if px > MAX_TEXEL:
			problems.append("%.3f m per font texel (max %.2f)" % [px, MAX_TEXEL])
		if l.double_sided:
			problems.append("double-sided (mirror-writing from behind)")
		var d0 := _depth(l, 0, 0)
		if d0 == INF and "--probe" in OS.get_cmdline_user_args():
			var fr := l.global_basis.z.normalized()
			for dy in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				for back in [1.0, -1.0]:
					var o := l.global_transform * Vector3(0, dy, 0)
					var h := _ray(o + fr * 0.02 * back, o - fr * 3.0 * back)
					if not h.is_empty():
						print("    probe dy %.1f %s: hit %.2f m, normal.front %.2f" % [dy, "behind" if back > 0 else "in front",
							o.distance_to(h.position), (h.normal as Vector3).dot(fr)])
		if d0 == INF:
			problems.append("no board behind the text (floating)")
		else:
			if d0 > BOARD_GAP:
				problems.append("board %.3f m behind the text (floats off it)" % d0)
			if d0 < MIN_GAP:
				problems.append("board %.3f m behind the text (z-fights)" % d0)
			var left := _extent(l, d0, Vector2(-1, 0), 0.0)
			var right := _extent(l, d0, Vector2(1, 0), 0.0)
			var down := _extent(l, d0, Vector2(0, -1), 0.0)
			var up := _extent(l, d0, Vector2(0, 1), 0.0)
			var margin := clampf(MARGIN[1] * minf(up + down, 1.0), MARGIN[0], MARGIN[2])
			var short := minf(minf(left + text.position.x, right - text.end.x), minf(down + text.position.y, up - text.end.y))
			if short < margin - 0.005:
				problems.append("text %.2f x %.2f overruns its board %.2f x %.2f (margin %.3f, want %.2f)" %
					[text.size.x, text.size.y, left + right, up + down, short, margin])
			if _verbose:
				print("  %s: board x %.2f..%.2f y %.2f..%.2f at %.3f; text %s" % [l.tr(l.text).replace("\n", " / "),
					-left, right, -down, up, d0, text])
		# nothing in front of the text: corners and middle
		var front := l.global_basis.z.normalized()
		for c in [Vector2(0, 0), Vector2(text.position.x, text.position.y), Vector2(text.end.x, text.position.y),
				Vector2(text.position.x, text.end.y), Vector2(text.end.x, text.end.y)]:
			var at := l.global_transform * Vector3(c.x * 0.95, c.y * 0.9, 0)
			var hit := _ray(at + front * 0.003, at + front * CLEAR)
			if not hit.is_empty():
				problems.append("clipped: geometry %.2f m in front of the text" % (at.distance_to(hit.position)))
				break
		var shown := l.tr(l.text) if l.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else l.text
		if problems.is_empty():
			print("ok  %s" % shown.replace("\n", " / "))
		else:
			bad += 1
			print("BAD %s at %s: %s" % [shown.replace("\n", " / "), l.global_position, "; ".join(problems)])
	return bad
