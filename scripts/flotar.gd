extends Node2D

## Decoración que flota: sube y baja despacio y gira un poco (rocas, trozos de casas, placas, fragmentos).

@export var amplitud: float = 4.0
@export var periodo: float = 3.0
@export var giro: float = 4.0        # grados de vaivén

var _t := 0.0
var _y0: float


func _ready() -> void:
	_y0 = position.y
	_t = randf() * periodo


func _process(delta: float) -> void:
	_t += delta
	var f := sin(_t / periodo * TAU)
	position.y = _y0 + f * amplitud
	rotation_degrees = cos(_t / periodo * TAU) * giro
