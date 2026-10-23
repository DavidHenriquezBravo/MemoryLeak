extends Area2D

## Una parada de la historia del Anciano en la bajada. Cuando el jugador entra al área:
## el jugador se queda quieto, el Anciano camina a su lugar, lo mira y dice sus líneas.
## Opciones: temblor (la cueva tiembla antes de hablar), mirar abajo / mirar hacia / zoom (la cámara se va a
## mostrar algo: lo que hay bajo la grieta, el Distrito desde el balcón, el volcán del Stage 3...)
## y se queda (el Anciano deja de seguir al jugador).
## Cada parada se cuenta una sola vez por partida.

const ANCIANO := preload("res://scripts/data/anciano.tres")

## Lo que dice el Anciano (una línea por cuadro de diálogo). {addr:0x03F0} se ve como dirección.
@export var lineas: Array[String] = []
## Quién habla (vacío = el Anciano). Para que hable otro personaje, su .tres de NpcData.
@export var quien: NpcData = null
## Si el Anciano camina a «lugar anciano» antes de hablar (apagarlo cuando habla otro personaje)
@export var mover_anciano: bool = true
## Dónde se para el Anciano para hablar, relativo a la posición de esta parada
@export var lugar_anciano: Vector2 = Vector2(-24, 0)
## Segundos de espera antes de empezar (por ejemplo, mientras termina el fundido al entrar)
@export var espera: float = 0.0
## La cueva tiembla antes de que hable
@export var temblor: bool = false
## Cuántos píxeles baja la cámara mientras habla (0 = no se mueve)
@export var mirar_abajo: float = 0.0
## Hacia dónde se va la cámara mientras habla (se suma a «mirar abajo»): para mostrar algo lejos, como el volcán
@export var mirar_hacia: Vector2 = Vector2.ZERO
## Zoom de la cámara mientras habla (0 = el de siempre; menos de 3 = se aleja y se ve más)
@export var zoom_mirar: float = 0.0
## Segundos que tarda la cámara en ir y en volver
@export var duracion_mirar: float = 1.2
## El Anciano se queda aquí y el jugador sigue solo
@export var se_queda: bool = false
## Hacia dónde mira el Anciano cuando se queda ("frente", "izquierda", "derecha" o "espalda")
@export var mira_al_quedarse: String = "frente"

static var _vistas := {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _vistas.has(name) or GameState.en_cinematica or Dialogue.is_open:
		return
	_vistas[name] = true
	_contar(body)


func _contar(jugador: Node2D) -> void:
	GameState.en_cinematica = true
	if espera > 0.0:
		await get_tree().create_timer(espera).timeout
	var anciano := get_tree().get_first_node_in_group("anciano_guia")
	if anciano and mover_anciano:
		await anciano.ir_a(global_position + lugar_anciano)
		anciano.mirar_a(jugador.global_position)
	var cam: Camera2D = jugador.get_node_or_null("Camera2D")
	if temblor and cam:
		await _temblar(cam)
	var mira := mirar_hacia + Vector2(0, mirar_abajo)
	var zoom_antes := cam.zoom if cam else Vector2.ONE
	var mueve := cam != null and (mira != Vector2.ZERO or zoom_mirar > 0.0)
	if mueve:
		await _mover_camara(cam, mira, Vector2(zoom_mirar, zoom_mirar) if zoom_mirar > 0.0 else zoom_antes)
	await Dialogue.say(quien if quien else ANCIANO, lineas)
	if mueve:
		await _mover_camara(cam, Vector2.ZERO, zoom_antes)
	if anciano and (mover_anciano or se_queda):
		if se_queda:
			anciano.quedarse(mira_al_quedarse)
		else:
			anciano.seguir()
	GameState.en_cinematica = false


func _temblar(cam: Camera2D) -> void:
	var t := 0.0
	while t < 0.9:
		var fuerza := 3.0 * (1.0 - t / 0.9)
		cam.offset = Vector2(randf_range(-fuerza, fuerza), randf_range(-fuerza, fuerza))
		await get_tree().process_frame
		t += get_process_delta_time()
	cam.offset = Vector2.ZERO


func _mover_camara(cam: Camera2D, hasta: Vector2, zoom: Vector2) -> void:
	hasta = _dentro_de_los_limites(cam, hasta, zoom)
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "offset", hasta, duracion_mirar)
	tw.tween_property(cam, "zoom", zoom, duracion_mirar)
	await tw.finished


# El offset de la cámara se salta sus límites: si la vista (con el zoom final) se sale del nivel, se recorta
# para que no se vea el vacío ni lo que hay fuera del mapa. Ojo: con otro zoom la cámara misma se corre
# por sus límites, así que el punto de partida se calcula con el zoom final.
func _dentro_de_los_limites(cam: Camera2D, hasta: Vector2, zoom: Vector2) -> Vector2:
	var mitad := get_viewport().get_visible_rect().size / zoom / 2.0
	var lim_min := Vector2(cam.limit_left, cam.limit_top) + mitad
	var lim_max := Vector2(cam.limit_right, cam.limit_bottom) - mitad
	var base := _recortar(cam.global_position, lim_min, lim_max, cam)
	var centro := _recortar(base + hasta, lim_min, lim_max, cam)
	return centro - base


func _recortar(p: Vector2, lim_min: Vector2, lim_max: Vector2, cam: Camera2D) -> Vector2:
	var x := clampf(p.x, lim_min.x, lim_max.x) if lim_min.x <= lim_max.x else (cam.limit_left + cam.limit_right) / 2.0
	var y := clampf(p.y, lim_min.y, lim_max.y) if lim_min.y <= lim_max.y else (cam.limit_top + cam.limit_bottom) / 2.0
	return Vector2(x, y)
