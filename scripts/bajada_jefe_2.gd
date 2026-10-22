extends Control

## Cinemática de la bajada al jefe 2, con el Anciano: del pozo abandonado del Stage 2 a la arena.
##   1. Bajan por el pozo en la plataforma colgada (loop de 48 cuadros mientras el Anciano habla).
##   2. Cruzan la caverna de los rieles colgantes en la tirolesa (un recorrido; el Anciano habla en el camino).
##   3. Llegan al poste de la isla: pasa a arena_jefe_2.tscn (punto de entrada «DesdeTirolesa»).
## Los cuadros son de 320x180 (Sprites/Cinematicas/*-Sheet.png) y se ven a pantalla completa.

const ANCIANO := preload("res://scripts/data/anciano.tres")
const HOJA_POZO := preload("res://Sprites/Cinematicas/Bajada pozo-Sheet.png")
const HOJA_TIROLESA := preload("res://Sprites/Cinematicas/Bajada tirolesa-Sheet.png")
const ARENA := "res://scenes/levels/arena_jefe_2.tscn"
const FPS := 10.0

const LINEAS_POZO: Array[String] = [
	"Cada placa apuntaba a una casa del Distrito. Las casas se borraron... pero las placas siguen flotando, apuntando a la nada.",
	"Agárrate fuerte. Abajo nos espera una tirolesa.",
]
const LINEAS_TIROLESA: Array[String] = [
	"¡No mires abajo! Esos rieles terminan en el aire: no apuntan a ningún lado.",
	"Así son los punteros colgantes. Y su dueño nos espera en la isla.",
]
## Cuadro de la tirolesa en que el Anciano empieza a hablar
const HABLA_EN := 14

@onready var cuadro: TextureRect = $Cuadro
@onready var velo: ColorRect = $Velo

var _pozo: Array[AtlasTexture] = []
var _tirolesa: Array[AtlasTexture] = []
var _hablando := false


func _ready() -> void:
	GameState.en_cinematica = true
	_pozo = _cortar(HOJA_POZO, 48, 8)
	_tirolesa = _cortar(HOJA_TIROLESA, 100, 10)
	_reproducir()


func _cortar(hoja: Texture2D, cantidad: int, columnas: int) -> Array[AtlasTexture]:
	var lista: Array[AtlasTexture] = []
	for i in cantidad:
		var at := AtlasTexture.new()
		at.atlas = hoja
		at.region = Rect2((i % columnas) * 320, (i / columnas) * 180, 320, 180)
		lista.append(at)
	return lista


func _reproducir() -> void:
	# 1. El pozo: la plataforma baja mientras el Anciano habla (el loop sigue hasta que termina)
	_hablando = true
	_charla_pozo()
	var i := 0
	while _hablando or i < 15:
		cuadro.texture = _pozo[i % _pozo.size()]
		i += 1
		await get_tree().create_timer(1.0 / FPS).timeout
	await _fundido(1.0, 0.35)

	# 2. La tirolesa: el recorrido no se detiene; el Anciano habla en el camino
	cuadro.texture = _tirolesa[0]
	await _fundido(0.0, 0.35)
	var en_tirolesa := false
	for k in _tirolesa.size():
		cuadro.texture = _tirolesa[k]
		if k == HABLA_EN:
			en_tirolesa = true
			Dialogue.say(ANCIANO, LINEAS_TIROLESA)
		await get_tree().create_timer(1.0 / FPS).timeout
	while en_tirolesa and Dialogue.is_open:
		await get_tree().process_frame

	# 3. A la arena: llegan por el poste de la tirolesa
	GameState.punto_entrada = &"DesdeTirolesa"
	GameState.en_cinematica = false
	Transicion.ir_a(ARENA)


func _charla_pozo() -> void:
	await get_tree().create_timer(1.2).timeout
	await Dialogue.say(ANCIANO, LINEAS_POZO)
	_hablando = false


func _fundido(hasta: float, segundos: float) -> void:
	var t := create_tween()
	t.tween_property(velo, "color:a", hasta, segundos)
	await t.finished
