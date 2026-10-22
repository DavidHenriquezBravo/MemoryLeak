extends CharacterBody2D

## El Anciano que acompaña al jugador en la bajada: va detrás siguiendo el mismo camino que hizo
## el jugador (así nunca se mete en la roca ni en la grieta). En las paradas de la historia
## (parada_historia.gd) camina a su lugar, mira al jugador y habla; en la última se queda.

## Distancia a la que va detrás del jugador
@export var distancia: float = 22.0
## Velocidad normal (la del jugador es 150)
@export var velocidad: float = 150.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var jugador: Node2D = null
var siguiendo := true            # false mientras camina a una parada o cuando ya se quedó
var _rastro: Array[Vector2] = [] # posiciones por donde pasó el jugador
var _mira := "frente"


func _ready() -> void:
	add_to_group("anciano_guia")
	jugador = get_tree().get_first_node_in_group("player")
	if jugador:
		_rastro.append(jugador.global_position)
	anim.play("idle_frente")


func _physics_process(delta: float) -> void:
	if jugador == null or not siguiendo:
		return
	# el rastro: un punto cada vez que el jugador avanza unos píxeles
	if _rastro.is_empty() or jugador.global_position.distance_to(_rastro[-1]) > 4.0:
		_rastro.append(jugador.global_position)
	var lejos := global_position.distance_to(jugador.global_position)
	if lejos <= distancia or _rastro.is_empty():
		_quieto_mirando(jugador.global_position)
		return
	# si se quedó muy atrás, apura el paso
	var v := velocidad if lejos < 48.0 else velocidad * 1.6
	_avanzar_por_rastro(v * delta)


func _avanzar_por_rastro(paso: float) -> void:
	var antes := global_position
	while paso > 0.0 and not _rastro.is_empty():
		var meta: Vector2 = _rastro[0]
		var d := global_position.distance_to(meta)
		if d <= paso:
			global_position = meta
			paso -= d
			_rastro.pop_front()
		else:
			global_position = global_position.move_toward(meta, paso)
			paso = 0.0
	_animar(global_position - antes)


## Camina hasta un punto (para las paradas de la historia). Se usa con await.
func ir_a(punto: Vector2) -> void:
	siguiendo = false
	while global_position.distance_to(punto) > 1.0:
		var antes := global_position
		global_position = global_position.move_toward(punto, velocidad * get_physics_process_delta_time())
		_animar(global_position - antes)
		await get_tree().physics_frame
	global_position = punto
	anim.play("idle_" + _mira)


## Vuelve a seguir al jugador desde donde está (el rastro viejo se descarta)
func seguir() -> void:
	_rastro.clear()
	if jugador:
		_rastro.append(jugador.global_position)
	siguiendo = true


## Se queda en la parada final mirando hacia una dirección ("frente", "izquierda", "derecha", "espalda")
func quedarse(direccion: String = "frente") -> void:
	siguiendo = false
	_mira = direccion
	anim.play("idle_" + _mira)


func mirar_a(punto: Vector2) -> void:
	_mira = _direccion(punto - global_position)
	anim.play("idle_" + _mira)


func _quieto_mirando(punto: Vector2) -> void:
	var d := _direccion(punto - global_position)
	if d != _mira or not anim.animation.begins_with("idle"):
		_mira = d
		anim.play("idle_" + _mira)


func _animar(mov: Vector2) -> void:
	if mov.length() < 0.01:
		return
	_mira = _direccion(mov)
	if anim.animation != "caminar_" + _mira:
		anim.play("caminar_" + _mira)


func _direccion(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "derecha" if v.x > 0.0 else "izquierda"
	return "frente" if v.y > 0.0 else "espalda"
