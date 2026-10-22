extends Node2D

## Capa de fondo para escenas de lado: se mueve más lento (factor < 1) o más rápido (factor > 1) que el mundo.
## 0 = queda fija en la pantalla; 1 = se mueve con el mundo. Si «ancho_repeticion» > 0, la imagen se repite.
## Sus Sprite2D hijos se ponen con su posición en la pantalla (la pantalla mide 320 x 180 con zoom 4).

@export var factor: float = 0.5
@export var ancho_repeticion: float = 0.0

var _bases: Array[float] = []


func _ready() -> void:
	for h in get_children():
		if h is Node2D:
			_bases.append(h.position.x)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var izq := cam.get_screen_center_position().x - 160.0
	var corrido := izq * factor
	if ancho_repeticion > 0.0:
		corrido = fposmod(corrido, ancho_repeticion)
	position.x = izq - corrido
