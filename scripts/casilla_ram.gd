class_name CasillaRAM
extends Area2D

# Casilla de memoria del mapa. Se coloca en el nivel y se le pone la dirección en el inspector.
# Al apretar E encima, abre el ejercicio de la misión activa (MissionManager.open_cell).
#   gris  -> no hay misión para esta casilla
#   cyan  -> es la casilla de tu misión: ¡ábrela! (en el nivel 2, también la placa intermedia que toca)
#   rojo  -> te equivocaste: espera unos segundos
#   verde -> ya resuelta (su dato quedó en el Registro)
# Modo objeto: si se le pone `objeto` (p. ej. el atril de la biblioteca), no se dibuja el cuadrito:
# la etiqueta queda sobre el objeto y es el objeto el que brilla en cyan / rojo.

const SHEET := preload("res://Sprites/Mundo/casilla_ram-Sheet.png")
const C_CYAN := Color(0.239, 0.894, 0.867)
const C_GREEN := Color(0.439, 0.902, 0.439)
const C_RED := Color(1.0, 0.353, 0.353)
const C_DIM := Color(0.61, 0.61, 0.77)

@export var address: String = "0x0000"   # NO cambiar aquí: se pone en el Inspector de cada casilla
@export var objeto: NodePath                # opcional: el mueble que hace de casilla
@export var zona_objeto := Vector2(56, 44)  # zona para interactuar en modo objeto (los muebles son más grandes)
@export var alto_etiqueta := 40.0           # cuánto sobre la casilla va la etiqueta en modo objeto

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var etiqueta: Label = $Etiqueta

var _jugador_cerca := false
var _estado := ""
var _dibujo_objeto: CanvasItem = null       # el Sprite2D del mueble (modo objeto)
var _pulso: Tween

static var _frames_casilla: SpriteFrames


func _ready() -> void:
	address = GameState.norm(address)
	etiqueta.text = address
	sprite.sprite_frames = _frames()
	if not objeto.is_empty():
		_preparar_objeto()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_actualizar()


func _process(_delta: float) -> void:
	_actualizar()


func _actualizar() -> void:
	var nuevo := "inactiva"
	if GameState.is_revealed(address):
		nuevo = "resuelta"
	elif MissionManager.casilla_objetivo() == address:
		nuevo = "bloqueada" if MissionManager.is_locked() else "activa"
	if nuevo == _estado:
		return
	_estado = nuevo
	sprite.play(nuevo)
	var col := C_DIM
	match nuevo:
		"activa":
			col = C_CYAN
		"bloqueada":
			col = C_RED
		"resuelta":
			col = C_GREEN
	etiqueta.add_theme_color_override("font_color", col)
	if _dibujo_objeto != null:
		_brillo_objeto(nuevo)


func _preparar_objeto() -> void:
	var nodo := get_node_or_null(objeto)
	if nodo == null:
		return
	_dibujo_objeto = nodo.get_node_or_null("Sprite2D") as CanvasItem
	if _dibujo_objeto == null and nodo is CanvasItem:
		_dibujo_objeto = nodo
	sprite.visible = false
	z_index = 2                               # la etiqueta no queda tapada por los estantes
	var forma := $CollisionShape2D as CollisionShape2D
	var rect := RectangleShape2D.new()
	rect.size = zona_objeto
	forma.shape = rect
	etiqueta.position.y = -alto_etiqueta


# El mueble late en cyan cuando toca abrirlo y se tiñe de rojo durante la espera tras un error
func _brillo_objeto(estado: String) -> void:
	if _pulso:
		_pulso.kill()
		_pulso = null
	match estado:
		"activa":
			_pulso = create_tween().set_loops()
			_pulso.tween_property(_dibujo_objeto, "modulate", Color(0.75, 1.35, 1.35), 0.6)
			_pulso.tween_property(_dibujo_objeto, "modulate", Color.WHITE, 0.6)
		"bloqueada":
			_dibujo_objeto.modulate = Color(1.3, 0.7, 0.7)
		_:
			_dibujo_objeto.modulate = Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if not _jugador_cerca or Dialogue.is_open or ExercisePanel.is_open:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if not MissionManager.open_cell(address):
			_sacudir()


# Pequeño temblor cuando la casilla no se puede abrir (sin misión, bloqueada o ya resuelta)
func _sacudir() -> void:
	var t := create_tween()
	var quien: CanvasItem = sprite if _dibujo_objeto == null else etiqueta
	var x0: float = quien.position.x
	for dx in [2.0, -2.0, 1.0, 0.0]:
		t.tween_property(quien, "position:x", x0 + dx, 0.04)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jugador_cerca = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_jugador_cerca = false


static func _frames() -> SpriteFrames:
	if _frames_casilla != null:
		return _frames_casilla
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var anims := {"inactiva": [0], "activa": [1, 2], "bloqueada": [3], "resuelta": [4]}
	for anim_name: String in anims:
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, 3.0)
		sf.set_animation_loop(anim_name, true)
		for i: int in anims[anim_name]:
			var frame := AtlasTexture.new()
			frame.atlas = SHEET
			frame.region = Rect2(i * 16, 0, 16, 16)
			sf.add_frame(anim_name, frame)
	_frames_casilla = sf
	return sf
