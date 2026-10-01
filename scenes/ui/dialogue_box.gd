extends CanvasLayer

signal advance_pressed

const CHARS_PER_SECOND := 40.0

@onready var box: Control = %Box
@onready var portrait: TextureRect = %Portrait
@onready var text_label: RichTextLabel = %Text
@onready var arrow: AnimatedSprite2D = %Arrow
@onready var name_label: Label = %NameLabel
@onready var registro_box: Control = %Registro
@onready var registro_label: Label = %RegistroLabel

var is_open := false
var _typing := false
var _tween: Tween

func _ready() -> void:
	box.visible = false
	text_label.bbcode_enabled = true
	arrow.play()   # si tu animación tiene otro nombre: arrow.play("nombre")

# API pública: lo único que llaman los demás
func say(npc: NpcData, lines: Array[String], registro: String = "") -> void:
	is_open = true
	name_label.text = npc.display_name
	portrait.texture = npc.portrait
	registro_box.visible = registro != ""
	registro_label.text = registro
	box.visible = true

	for line in lines:
		await _show_line(line)

	box.visible = false
	is_open = false

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
