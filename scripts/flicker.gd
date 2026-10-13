extends Light3D
## Random flicker for unstable lamps: now and then the lamp dips to 0-30 % for a beat and comes back.
## `chance` is per sixtieth of a second (as it was tuned at 60 fps), so a lamp flickers the same at any frame rate,
## and a dip holds DIP_TIME: a stutter, never a per-frame strobe (that made walls and fog crawl indoors).
## Drives only its own light, from the energy it had on entering the tree: code that fades a lamp removes the
## script first (Chapter1Director.lights_out).

const DIP_TIME := Vector2(0.05, 0.14)  ## s a dip lasts

@export var chance := 0.08

@onready var _base := light_energy
var _dip := 0.0
var _level := 1.0


func _process(delta: float) -> void:
	if _dip > 0.0:
		_dip -= delta
		if _dip <= 0.0:
			_level = 1.0
	elif randf() < 1.0 - pow(1.0 - chance, delta * 60.0):
		_dip = randf_range(DIP_TIME.x, DIP_TIME.y)
		_level = randf_range(0.0, 0.3)
	light_energy = _base * _level
