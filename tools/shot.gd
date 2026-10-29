extends SceneTree
## Renders one model (or the map) to a PNG so asset changes can be checked by eye.
##   flatpak run org.godotengine.Godot --path . --resolution 900x700 -s tools/shot.gd -- <model.glb|res://maps/x.tscn> <out.png> [cam_x cam_y cam_z look_x look_y look_z]
## A .glb is read straight from disk (absolute path, no import step needed). Models get a neutral key
## light; with no camera args the camera frames the model from the front-left. The map needs its models
## imported first: flatpak run org.godotengine.Godot --headless --path . --import
## Icon mode: the inventory's item icons (scripts/inventory.gd ICONS), each item_*.glb rendered small on a clear
## background in the PS2 look (no smoothing, a short palette, a dark rim), into ui/icons/<name>.png:
##   godot --path . --resolution 256x256 -s tools/shot.gd -- --icons

const ICON_PX := 64  ## the icons' size (the inventory scales them down for its rows)
const ICON_RENDER := 160  ## px rendered before the nearest-neighbour cut down to ICON_PX
const ICON_DIR := "res://ui/icons"
## icon name -> [model, yaw°, pitch°, roll°]: how the item lies for its portrait (long ones tilted across the square)
const ICONS := {
	"revolver": ["item_revolver", 90, 10, 0], "flare": ["item_flare_gun", 90, 10, 0],
	"shotgun": ["item_shotgun", 90, 8, 35], "bow": ["item_bow", 90, 5, 30], "axe": ["item_axe", 90, 5, 35],
	"bat": ["item_bat", 90, 5, 35], "arrow": ["item_arrow", 90, 10, 35],
	"bottle": ["item_bottle", 30, 15, 0], "smoke": ["item_smoke_can", 30, 20, 0], "tea": ["item_tea_tin", 30, 25, 0],
	"mask": ["item_gas_mask", 0, 65, 0], "filter": ["item_mask_filter", 30, 25, 0],
	"headlamp": ["item_headlamp", 30, 30, 0], "key_part": ["item_key_part", 0, 70, 0],
	"chapel_key": ["item_chapel_key", 0, 70, 0], "drawing": ["item_drawing", 0, 75, 0], "file": ["item_file", 0, 70, 0],
	"photo": ["item_photo", 15, 8, 0], "lantern": ["festival_lantern", 30, 12, 0], "ledger": ["item_ledger", 15, 60, 0],
	"note": ["item_note", 0, 75, 0], "toe_tag": ["item_toe_tag", 0, 75, 0], "map": ["item_map", 0, 70, 0],
	"recorder": ["item_recorder", 30, 30, 0], "tin_box": ["item_tin_box", 30, 30, 0], "ammo": ["item_ammo_box", 30, 25, 0],
	"shells": ["item_shells", 30, 30, 0], "flares": ["item_flares", 30, 30, 0],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0] == "--icons":
		await _icons()
		quit(0)
		return
	var is_model := args[0].ends_with(".glb")
	var scene: Node
	if is_model:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(args[0], state) != OK:
			push_error("cannot read " + args[0])
			quit(1)
			return
		scene = doc.generate_scene(state)
	else:
		scene = load(args[0]).instantiate()
	root.add_child(scene)
	var aabb := AABB()
	if is_model:
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mi.global_transform * mi.get_aabb()
			aabb = box if aabb.size == Vector3.ZERO else aabb.merge(box)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.18, 0.18, 0.2)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
		root.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, -30, 0)
		sun.light_energy = 1.4
		root.add_child(sun)
	for p in scene.find_children("Player", "", true, false):
		p.process_mode = Node.PROCESS_MODE_DISABLED
		for c in p.find_children("*", "Camera3D", true, false):
			c.current = false
	var cam := Camera3D.new()
	root.add_child(cam)
	if args.size() >= 8:
		cam.position = Vector3(float(args[2]), float(args[3]), float(args[4]))
		cam.look_at(Vector3(float(args[5]), float(args[6]), float(args[7])))
	else:
		var c := aabb.get_center()
		var r := aabb.size.length() * 0.9
		cam.position = c + Vector3(-0.45, 0.25, 1.0).normalized() * r
		cam.look_at(c)
	cam.current = true
	for i in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(args[1])
	quit(0)


# ------------------------------------------------------------------ icon mode

func _icons() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICON_DIR))
	var vp := SubViewport.new()
	vp.size = Vector2i(ICON_RENDER, ICON_RENDER)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.48, 0.45)
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_energy = 1.5
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10, 140, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.7, 0.75, 0.9)
	vp.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.current = true
	for name: String in ICONS:
		var spec: Array = ICONS[name]
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var path := ProjectSettings.globalize_path("res://models/%s.glb" % spec[0])
		if doc.append_from_file(path, state) != OK:
			push_error("cannot read " + path)
			continue
		var model: Node3D = doc.generate_scene(state)
		var pivot := Node3D.new()
		vp.add_child(pivot)
		pivot.add_child(model)
		for n in model.find_children("*", "", true, false):  # (collision-only parts would show as boxes)
			if n.name.ends_with("-colonly") or n is CollisionShape3D:
				n.queue_free()
		pivot.rotation_degrees = Vector3(spec[2], spec[1], 0)
		var roll := Node3D.new()  # (the tilt across the frame, after the item is turned)
		vp.add_child(roll)
		pivot.reparent(roll)
		roll.rotation_degrees.z = spec[3]
		await process_frame
		var box := AABB()
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mi.global_transform * mi.get_aabb()
			box = b if box.size == Vector3.ZERO else box.merge(b)
		var c := box.get_center()
		var r := box.size.length() * 0.5
		cam.position = c + Vector3(0, 0, r / tan(deg_to_rad(cam.fov * 0.5)) * 1.02)
		cam.look_at(c)
		for i in 4:
			await process_frame
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(ICON_PX, ICON_PX, Image.INTERPOLATE_NEAREST)
		_ps2(img)
		img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [ICON_DIR, name]))
		print("icon ", name)
		roll.queue_free()
		await process_frame


static func _ps2(img: Image) -> void:
	## Hard alpha, colours cut to 5 bits a channel with a 2x2 ordered dither, and a one-pixel dark rim round the
	## shape so it reads on the dossier.
	var bayer := [0.0, 0.5, 0.75, 0.25]
	var w := img.get_width()
	var h := img.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			var p := img.get_pixel(x, y)
			solid[y * w + x] = 1 if p.a > 0.5 else 0
			if p.a <= 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var d: float = (bayer[(y % 2) * 2 + x % 2] - 0.375) / 31.0
			img.set_pixel(x, y, Color(snappedf(clampf(p.r + d, 0, 1), 1.0 / 31.0),
				snappedf(clampf(p.g + d, 0, 1), 1.0 / 31.0), snappedf(clampf(p.b + d, 0, 1), 1.0 / 31.0), 1.0))
	for y in h:
		for x in w:
			if solid[y * w + x]:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and solid[q.y * w + q.x]:
					img.set_pixel(x, y, Color(0.04, 0.03, 0.025, 1.0))
					break
