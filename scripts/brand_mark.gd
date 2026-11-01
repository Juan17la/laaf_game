class_name BrandMark
extends MeshInstance3D
## The Veil's Eye branded on the back of Alex's right hand (shaders/brand_mark.gdshader), worn on the HandR joint so
## it moves with every pose. Owen burns it in on the first night (Ch1ScenesA._window); before that it's hidden.
##   var m := BrandMark.wear(model)   # null if the model has no HandR joint; the same one again on a second call
##   m.burn()                         # white-hot, then it cools by itself to a scar over COOL seconds
## The player's own copy follows his Mark meter (`source`): it smoulders brighter as the Mark climbs and flares on
## every hit that marks.

const COOL := 40.0  ## s from white-hot to the scar's resting glow
## The back of the hand in HandR's space (the PSX pack rig, tools/psx_chars.py): just off the skin, facing out.
const FIT_AT := Vector3(-0.037, -0.066, 0.012)
const FIT_TURN := Vector3(0.0, -PI / 2.0, 0.0)  ## euler: the quad's face onto the back of the hand
const SIZE := 0.05  ## m across

var heat := 0.0  ## 0..1 now (the shader's)
var source: Node  ## optional: the player, read for `mark` (0..100)
var _floor := 0.0
var _last_mark := -1.0
var _mat: ShaderMaterial


static func wear(model: Node3D) -> BrandMark:
	var hand := model.find_child("HandR", true, false) as Node3D
	if not hand:
		return null
	var had := hand.get_node_or_null("BrandMark") as BrandMark
	if had:
		return had
	var m := BrandMark.new()
	m.name = "BrandMark"
	var q := QuadMesh.new()
	q.size = Vector2(SIZE, SIZE)
	m.mesh = q
	m._mat = ShaderMaterial.new()
	m._mat.shader = load("res://shaders/brand_mark.gdshader")
	m._mat.set_shader_parameter("time_offset", randf() * 10.0)
	m.material_override = m._mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = FIT_AT
	m.rotation = FIT_TURN
	hand.add_child(m)
	return m


static func of(model: Node3D) -> BrandMark:
	var hand := model.find_child("HandR", true, false) as Node3D if model else null
	return hand.get_node_or_null("BrandMark") as BrandMark if hand else null


static func paint(parent: Node, size: float) -> MeshInstance3D:
	## The same eye daubed on a door or a wall (no glow): a quad facing +Z. Draw it in with set_reveal().
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/brand_mark.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func set_reveal(painted: MeshInstance3D, k: float) -> void:
	(painted.material_override as ShaderMaterial).set_shader_parameter("reveal", k)


func burn() -> void:
	visible = true
	heat = 1.0


func _process(delta: float) -> void:
	if source and is_instance_valid(source):
		var mk := float(source.get("mark"))
		_floor = 0.04 + 0.22 * mk / 100.0  # the deeper the Mark, the more it smoulders
		if _last_mark >= 0.0 and mk > _last_mark:
			heat = minf(heat + (mk - _last_mark) * 0.08, 0.9)  # a hit that marks: it flares
		_last_mark = mk
	heat = maxf(heat - delta / COOL * (1.0 + heat * 2.0), _floor)  # fast off white-hot, slow near the scar
	_mat.set_shader_parameter("heat", heat)
