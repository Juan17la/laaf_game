class_name Headlamp
extends Node3D
## Alex's headlamp (models/item_headlamp.glb, built in his Head joint's space by tools/models_items.py m_headlamp):
## worn on the Head joint, so it turns, nods and ducks with every animation. The player hangs his flashlight
## SpotLight3D on it at LENS and aims it (player.gd _aim_lamp); `lit` makes the lens glow while that light is on.
## Cinematic stand-ins (Actor.make with char_alex) wear one too, unlit.
##   var lamp := Headlamp.wear(model)   # null if the model has no Head joint

const SCENE := "res://models/item_headlamp.glb"
const LENS := Vector3(0.0, 0.176, 0.19)  ## lens face centre, Head space (models_items.py HEADLAMP_LENS)
const GLOW := Color(1.0, 0.94, 0.8)

var lit := false:
	set = set_lit
var _lens: MeshInstance3D
var _mat: StandardMaterial3D


static func wear(model: Node3D) -> Headlamp:
	var head := model.find_child("Head", true, false) as Node3D
	if not head:
		return null
	var had := head.get_node_or_null("Headlamp") as Headlamp
	if had:
		return had
	var h := Headlamp.new()
	h.name = "Headlamp"
	if ResourceLoader.exists(SCENE):
		h.add_child((load(SCENE) as PackedScene).instantiate())
	head.add_child(h)
	h._lens = h.find_child("lens", true, false) as MeshInstance3D
	h._mat = StandardMaterial3D.new()
	h._mat.roughness = 0.1
	h._mat.emission = GLOW
	if h._lens:
		h._lens.material_override = h._mat
	h.set_lit(false)
	return h


func set_lit(on: bool) -> void:
	lit = on
	if not _mat:
		return
	_mat.emission_enabled = on
	_mat.emission_energy_multiplier = 3.0 if on else 0.0
	_mat.albedo_color = GLOW if on else Color(0.55, 0.57, 0.52)
