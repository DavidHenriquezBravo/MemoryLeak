extends CanvasLayer

signal advance_pressed

const CHARS_PER_SECOND := 40.0
const REGISTRO_OK := preload("res://Sprites/pestana_registro_ok_9slice.png")
const REGISTRO_PENDIENTE := preload("res://Sprites/pestana_registro_pendiente_9slice.png")
const COLOR_OK := Color(0.44, 0.9, 0.44)
const COLOR_PENDIENTE := Color(1.0, 0.38, 0.69)

@onready var box: Control = %Box
@onready var portrait: TextureRect = %Portrait
@onready var text_label: RichTextLabel = %Text
@onready var arrow: AnimatedSprite2D = %Arrow
@onready var name_tab: NinePatchRect = %Nombre
@onready var name_label: Label = %NameLabel
@onready var registro_box: NinePatchRect = %Registro
@onready var registro_label: Label = %RegistroLabel

var is_open := false
var _typing := false
var _tween: Tween

func _ready() -> void:
	box.visible = false
	text_label.bbcode_enabled = true
	arrow.play()

# API pública: lo único que llaman los demás
func say(npc: NpcData, lines: Array[String], registro: String = "") -> void:
	is_open = true
	_set_name(npc.display_name)
	portrait.texture = npc.portrait
	_set_registro(registro)
	box.visible = true

	for line in lines:
		await _show_line(line)

	box.visible = false
	is_open = false

# La pestaña del nombre crece con el texto (como en los bocetos)
func _set_name(text: String) -> void:
	name_label.text = text.to_upper()
	name_label.size.x = name_label.get_minimum_size().x
	name_tab.size.x = name_label.size.x + 16

# "REGISTRO 0/1" en magenta, "REGISTRO 1/1 · OK" en verde; "" = sin pestaña
func _set_registro(text: String) -> void:
	registro_box.visible = text != ""
	if text == "":
		return
	var ok := text.ends_with("OK")
	registro_label.text = text
	registro_label.add_theme_color_override("font_color", COLOR_OK if ok else COLOR_PENDIENTE)
	registro_box.texture = REGISTRO_OK if ok else REGISTRO_PENDIENTE
	registro_label.size.x = registro_label.get_minimum_size().x
	var ancho := registro_label.size.x + 16
	registro_box.size.x = ancho
	registro_box.position.x = 610 - ancho

func _show_line(line: String) -> void:
	text_label.text = AddrFormatter.format(line)
	text_label.visible_ratio = 0.0
	arrow.visible = false
	_typing = true

	var chars := text_label.get_total_character_count()
	_tween = create_tween()
	_tween.tween_property(text_label, "visible_ratio", 1.0, maxf(chars / CHARS_PER_SECOND, 0.05))
	_tween.finished.connect(func(): _typing = false)

	while _typing:
		await get_tree().process_frame

	arrow.visible = true
	await advance_pressed

func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_tween.kill()
		text_label.visible_ratio = 1.0
		_typing = false
	else:
		advance_pressed.emit()
