extends Area2D

# Texto personalizado para este NPC en particular
@export_multiline var texto_dialogo: String = "¡Hola! Soy un NPC."

var player_in_range: bool = false

# Busca la UI global que está en la escena principal
@onready var dialogo_ui: Control = get_tree().current_scene.find_child("Control", true, false)
@onready var texto_label: Label = get_tree().current_scene.find_child("Label", true, false)

func _ready() -> void:
	if dialogo_ui:
		dialogo_ui.hide()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false
		if dialogo_ui:
			dialogo_ui.hide()

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		if dialogo_ui and texto_label:
			texto_label.text = texto_dialogo
			dialogo_ui.show()
