extends Node2D

## Arena de The Dangling Pointer.
## Antes de la pelea: al acercarse al centro de la isla, el vagón sube colgando desde el vacío, habla y empieza
## la pelea (scenes/boss/pelea_jefe_2.tscn). Al volver ganando: dice su última frase, se deshace en píxeles,
## la corrupción del piso se apaga y la puerta sellada se abre hacia el Camino al Núcleo.

const PELEA := "res://scenes/boss/pelea_jefe_2.tscn"
const DATOS_JEFE := preload("res://scripts/data/dangling_pointer.tres")
const ANCIANO := preload("res://scripts/data/anciano.tres")
const ANCIANO_GUIA := preload("res://scenes/actors/anciano_guia.tscn")

const LINEAS_ENTRADA: Array[String] = [
	"Vaya, vaya... una placa nueva bajando por mi pozo.",
	"Cada balde de esta mina tenía su dirección. Los baldes se fueron. Las placas... me las quedé yo.",
	"Te doy la dirección de la casa de tu infancia. Entra. ¿Qué pasa? ¿No hay nadie?",
	"Pregúntale a tu viejo acompañante de quién es la memoria que buscas.",
	"Ven. Veamos cuánto aguanta tu referencia.",
]
const LINEA_SIN_MISIONES := "Y encima bajas sin haber ayudado a nadie allá arriba. Hueles a memoria vacía."
const LINEAS_DERROTA: Array[String] = [
	"Suéltame si quieres... Las placas que guardaba ya no apuntan a nada.",
	"Pero la tuya, la de tu memoria... esa no la tengo yo. Alguien más la guarda.",
]

const LINEAS_LLEGADA: Array[String] = [
	"Llegamos. Esta isla es lo último que queda de la vieja mina.",
	"Quédate cerca del farol... y si algo te ofrece una dirección, no la tomes sin mirar.",
]

## Dónde queda el jugador al volver de la pelea ganada (frente al jefe)
const LUGAR_VICTORIA := Vector2(372, 352)
## Lo que sube el vagón desde el vacío en la entrada
const SUBIDA := 150.0

## Ya se vio el final de la pelea en esta partida: el jefe no vuelve y la puerta queda abierta
static var final_visto := false

@onready var jefe: AnimatedSprite2D = $"Objetos/The Dangling Pointer"
@onready var puerta = $"Objetos/Puerta sellada al stage final"      # puerta_sellada.gd
@onready var corrupcion: TileMapLayer = $"Corrupcion piso"
@onready var jugador = $Objetos/Player                                  # player.gd
@onready var memoria_m6: Node2D = get_node_or_null("Objetos/Memoria M6")

var _lugar_jefe := Vector2.ZERO
var _empezo := false


func _ready() -> void:
	_lugar_jefe = jefe.position
	var llega_en_tirolesa := GameState.punto_entrada == &"DesdeTirolesa"
	if llega_en_tirolesa:
		GameState.punto_entrada = &""
	if not GameState.boss2_defeated:
		# El jefe espera escondido en el vacío hasta que el jugador se acerca al centro
		jefe.visible = false
		_crear_zona_entrada()
		_poner_anciano()
		if llega_en_tirolesa:
			_llegada.call_deferred()
	elif not final_visto:
		puerta.cerrar_al_instante()
		jugador.position = LUGAR_VICTORIA
		jugador.last_direction = Vector2.RIGHT
		_poner_anciano()
		GameState.en_cinematica = true
		_esconder_memoria(true)
		_final.call_deferred()
	else:
		jefe.queue_free()
		corrupcion.modulate.a = 0.0
		_poner_anciano()


## El Anciano baja con el jugador y lo sigue por la isla (anciano_guia.gd)
func _poner_anciano() -> void:
	if get_tree().get_first_node_in_group("anciano_guia") != null:
		return
	var anciano: Node2D = ANCIANO_GUIA.instantiate()
	anciano.position = jugador.position + Vector2(-20, 0)
	$Objetos.add_child(anciano)


func _llegada() -> void:
	GameState.en_cinematica = true
	jugador.last_direction = Vector2.RIGHT
	await get_tree().create_timer(1.4).timeout      # deja terminar el goteo de la transición
	await Dialogue.say(ANCIANO, LINEAS_LLEGADA)
	GameState.en_cinematica = false


# ------------------------------------------------------------------ entrada del jefe

func _crear_zona_entrada() -> void:
	var zona := Area2D.new()
	zona.name = "Zona del jefe"
	zona.position = Vector2(_lugar_jefe.x - 120.0, _lugar_jefe.y)
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 200)
	forma.shape = rect
	zona.add_child(forma)
	add_child(zona)
	zona.body_entered.connect(_on_zona_body_entered)


func _on_zona_body_entered(body: Node2D) -> void:
	if _empezo or not body.is_in_group("player") or GameState.en_cinematica:
		return
	_empezo = true
	_entrada()


func _entrada() -> void:
	GameState.en_cinematica = true
	jugador.last_direction = Vector2.RIGHT
	var cam := _camara_cinematica()
	await _mover_camara(cam, (jugador.global_position + to_global(_lugar_jefe)) / 2.0, 0.8)

	# El vagón sube colgando desde el vacío mientras todo tiembla
	jefe.position = _lugar_jefe + Vector2(0, SUBIDA)
	jefe.modulate.a = 0.0
	jefe.visible = true
	jefe.play(&"reposo")
	_temblar(cam, 1.6, 3.0)
	var t := create_tween().set_parallel()
	t.tween_property(jefe, "position", _lugar_jefe, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(jefe, "modulate:a", 1.0, 0.6)
	await t.finished
	jefe.play(&"ataque")             # el balanceo del péndulo al llegar arriba
	await jefe.animation_finished
	jefe.play(&"reposo")
	await get_tree().create_timer(0.4).timeout

	var lineas := LINEAS_ENTRADA.duplicate()
	if GameState.misiones_completadas(2) == 0:
		lineas.insert(1, LINEA_SIN_MISIONES)
	await Dialogue.say(DATOS_JEFE, lineas)

	_temblar(cam, 0.5, 4.0)
	await get_tree().create_timer(0.3).timeout
	GameState.en_cinematica = false
	Transicion.ir_a_pelea(PELEA)


# ------------------------------------------------------------------ final: vuelve ganando

func _final() -> void:
	final_visto = true
	await get_tree().create_timer(0.8).timeout
	var cam := _camara_cinematica()
	await _mover_camara(cam, (jugador.global_position + to_global(_lugar_jefe)) / 2.0, 0.6)
	jefe.play(&"recibe dano")
	await jefe.animation_finished
	jefe.play(&"reposo")
	await Dialogue.say(DATOS_JEFE, LINEAS_DERROTA)

	# Se deshace en píxeles y la corrupción del piso se apaga con él
	_temblar(cam, 0.8, 2.0)
	jefe.play(&"derrota")
	create_tween().tween_property(corrupcion, "modulate:a", 0.0, 1.8)
	await jefe.animation_finished
	jefe.visible = false
	# Al deshacerse suelta la memoria que guardaba (M6)
	_esconder_memoria(false)
	await get_tree().create_timer(0.8).timeout

	# La puerta sellada se abre: el camino al Núcleo queda libre
	await _mover_camara(cam, puerta.global_position + Vector2(0, -24), 1.2)
	await get_tree().create_timer(0.3).timeout
	await puerta.abrir()
	await get_tree().create_timer(0.8).timeout
	await _mover_camara(cam, jugador.global_position, 1.0)
	_devolver_camara(cam)
	GameState.en_cinematica = false


## memoria_perdida.gd se muestra sola apenas cae el jefe; aquí espera a que el vagón se deshaga
func _esconder_memoria(esconder: bool) -> void:
	if memoria_m6 == null:
		return
	memoria_m6.visible = not esconder
	memoria_m6.process_mode = Node.PROCESS_MODE_DISABLED if esconder else Node.PROCESS_MODE_INHERIT


# ------------------------------------------------------------------ cámara

## Una cámara propia que parte donde está la del jugador (así el paneo no salta)
func _camara_cinematica() -> Camera2D:
	var del_jugador: Camera2D = jugador.get_node("Camera2D")
	var cam := Camera2D.new()
	cam.zoom = del_jugador.zoom
	cam.limit_left = del_jugador.limit_left
	cam.limit_top = del_jugador.limit_top
	cam.limit_right = del_jugador.limit_right
	cam.limit_bottom = del_jugador.limit_bottom
	add_child(cam)
	cam.global_position = del_jugador.get_screen_center_position()
	cam.make_current()
	return cam


func _devolver_camara(cam: Camera2D) -> void:
	(jugador.get_node("Camera2D") as Camera2D).make_current()
	cam.queue_free()


func _mover_camara(cam: Camera2D, hasta: Vector2, segundos: float) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(cam, "global_position", hasta, segundos)
	await t.finished


func _temblar(cam: Camera2D, segundos: float, fuerza: float) -> void:
	var t := create_tween()
	for i in int(segundos / 0.05):
		var f := fuerza * (1.0 - float(i) / (segundos / 0.05))
		t.tween_property(cam, "offset", Vector2(randf_range(-f, f), randf_range(-f, f)), 0.05)
	t.tween_property(cam, "offset", Vector2.ZERO, 0.05)
