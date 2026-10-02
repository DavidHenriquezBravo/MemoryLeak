extends CanvasLayer
## Pantalla de GAME OVER. La pelea la pone encima cuando la vida del jugador llega a 0.
## Se elige con las flechas y Z; quien la crea decide qué hacer con cada opción.

signal reintentar
signal salir

const TEX_PUNTERO := preload("res://Sprites/Pelea/puntero.png")

@onready var fondo: ColorRect = $Fondo
@onready var contenido: Control = $Contenido
@onready var titulo: Label = $Contenido/Titulo
@onready var botones: Array = [$Contenido/Opciones/Reintentar, $Contenido/Opciones/Salir]

var indice := 0
var activo := false
var icono_puntero: AtlasTexture
var espera_glitch := 1.5

func _ready() -> void:
	# El puntero de la hoja está en la esquina; se centra en 16x16 como en la pelea
	icono_puntero = AtlasTexture.new()
	icono_puntero.atlas = TEX_PUNTERO
	icono_puntero.region = Rect2(0, 0, 9, 13)
	icono_puntero.margin = Rect2(3, 1, 7, 3)
	_actualizar_botones()

	fondo.modulate.a = 0.0
	contenido.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(fondo, "modulate:a", 1.0, 0.8)
	t.tween_property(contenido, "modulate:a", 1.0, 0.6)
	await t.finished
	activo = true

# El título tiembla de vez en cuando, como un error de memoria
func _process(delta: float) -> void:
	if not activo:
		return
	espera_glitch -= delta
	if espera_glitch <= 0.0:
		espera_glitch = randf_range(1.2, 2.6)
		var t := create_tween()
		for i in 4:
			t.tween_property(titulo, "position:x", randf_range(-6.0, 6.0), 0.03).as_relative()
		t.tween_callback(func(): titulo.position.x = 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if not activo:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		indice = wrapi(indice - 1, 0, botones.size())
		_actualizar_botones()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		indice = wrapi(indice + 1, 0, botones.size())
		_actualizar_botones()
	elif event.is_action_pressed("interact"):
		_elegir()
	else:
		return
	get_viewport().set_input_as_handled()

func _actualizar_botones() -> void:
	for i in botones.size():
		botones[i].icon = icono_puntero if i == indice else null
		botones[i].modulate.a = 1.0 if i == indice else 0.55

func _elegir() -> void:
	activo = false
	if indice == 0:
		reintentar.emit()
	else:
		salir.emit()
