extends Area2D

# Usa la ruta exacta hacia tu CanvasLayer y sus hijos
@onready var dialogo_ui: Control = get_node("/root/Stage1/CanvasLayer/Control") 
@onready var texto_label: Label = get_node("/root/Stage1/CanvasLayer/Control/Label")

var player_in_range: bool = false

func _ready() -> void:
	if dialogo_ui:
		dialogo_ui.visible = false

func _on_body_entered(body: Node2D) -> void:
	# Verifica si el nodo que entra es el jugador
	if body.name == "Player":
		player_in_range = true
		print("Jugador dentro del rango del NPC")

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false
		if dialogo_ui:
			dialogo_ui.visible = false
		print("Jugador fuera del rango")

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and event.is_action_pressed("interact"):
		print("¡Tecla E presionada dentro del rango!")
		if dialogo_ui and texto_label:
			texto_label.text = "¡Hola! Bienvenido al juego."
			dialogo_ui.visible = true
