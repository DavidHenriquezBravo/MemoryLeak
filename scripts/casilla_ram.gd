class_name CasillaRAM
extends Area2D

# Casilla de memoria del mapa. Se coloca en el nivel y se le pone la dirección en el inspector.
# Al apretar E encima, abre el ejercicio de la misión activa (MissionManager.open_cell).
#   gris  -> no hay misión para esta casilla
#   cyan  -> es la casilla de tu misión: ¡ábrela!
#   rojo  -> te equivocaste: espera unos segundos
#   verde -> ya resuelta (su dato quedó en el Registro)

const SHEET := preload("res://Sprites/casilla_ram-Sheet.png")
const C_CYAN := Color(0.239, 0.894, 0.867)
const C_GREEN := Color(0.439, 0.902, 0.439)
const C_RED := Color(1.0, 0.353, 0.353)
const C_DIM := Color(0.61, 0.61, 0.77)

@export var address: String = "0x0000"   # NO cambiar aquí: se pone en el Inspector de cada casilla

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var etiqueta: Label = $Etiqueta

var _jugador_cerca := false
var _estado := ""

static var _frames_casilla: SpriteFrames


func _ready() -> void:
	address = GameState.norm(address)
	etiqueta.text = address
	sprite.sprite_frames = _frames()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_actualizar()


func _process(_delta: float) -> void:
	_actualizar()


func _actualizar() -> void:
	var nuevo := "inactiva"
	if GameState.is_revealed(address):
		nuevo = "resuelta"
	elif MissionManager.active != null and GameState.norm(MissionManager.active.cell_address) == address:
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
	for dx in [2.0, -2.0, 1.0, 0.0]:
		t.tween_property(sprite, "position:x", dx, 0.04)


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
