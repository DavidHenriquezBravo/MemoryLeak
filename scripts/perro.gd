extends Node2D

## El perro salchicha de la biblioteca: pasea de un lado a otro entre dos puntos, se para un rato
## moviendo la cola y vuelve. No choca con nada (es decoración).

## Hasta dónde camina a cada lado de donde está puesto
@export var recorrido: float = 64.0
@export var velocidad: float = 28.0
## Segundos que se queda quieto en cada punta
@export var pausa: float = 2.5

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _inicio: float
var _hacia := 1.0
var _espera := 0.0


func _ready() -> void:
	_inicio = position.x
	anim.play("quieto_derecha")


func _process(delta: float) -> void:
	if _espera > 0.0:
		_espera -= delta
		return
	position.x += _hacia * velocidad * delta
	anim.play("caminar_derecha" if _hacia > 0.0 else "caminar_izquierda")
	if absf(position.x - _inicio) >= recorrido:
		position.x = _inicio + recorrido * _hacia
		anim.play("quieto_derecha" if _hacia > 0.0 else "quieto_izquierda")
		_hacia = -_hacia
		_espera = pausa
