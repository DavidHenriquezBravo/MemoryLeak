extends CharacterBody2D

# Texto configurable desde el Inspector de Godot para este NPC
@export_multiline var texto_dialogo: String = "¡Hola! Soy Andrés, el tutor de punteros."

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Referencias directas a la UI (Ajusta las rutas a tu CanvasLayer / HUD si difieren)
# Asumimos que la UI está en la escena como UI_Juego/CuadroDialogo
@onready var cuadro_dialogo: Control = get_tree().current_scene.find_child("CuadroDialogo", true, false)
@onready var label_texto: Label = get_tree().current_scene.find_child("LabelDialogo", true, false)

var jugador_cerca: CharacterBody2D = null
var dialogo_activo: bool = false

func _ready() -> void:
	anim.play("idle_down")
	if cuadro_dialogo:
		cuadro_dialogo.hide()

func _unhandled_input(event: InputEvent) -> void:
	# Se activa con la tecla 'E' (acción "interactuar")
	if jugador_cerca and event.is_action_pressed("interactuar"):
		if not dialogo_activo:
			mostrar_dialogo()
		else:
			ocultar_dialogo()

func mostrar_dialogo() -> void:
	dialogo_activo = true
	# 1. Orienta a Andrés hacia el jugador antes de hablar
	orientar_hacia_jugador(jugador_cerca.global_position)
	
	# 2. Muestra el texto en la UI
	if cuadro_dialogo and label_texto:
		label_texto.text = texto_dialogo
		cuadro_dialogo.show()

func ocultar_dialogo() -> void:
	dialogo_activo = false
	if cuadro_dialogo:
		cuadro_dialogo.hide()

func orientar_hacia_jugador(pos_jugador: Vector2) -> void:
	var direccion: Vector2 = (pos_jugador - global_position).normalized()
	
	# Si la diferencia es mayor en X, mira a la izquierda o derecha
	if abs(direccion.x) > abs(direccion.y):
		if direccion.x < 0:
			anim.play("idle_left")   # Jugador a la izquierda
		else:
			anim.play("idle_right")  # Jugador a la derecha
	else:
		anim.play("idle_down")

# Conectados desde las señales del Area2D de Andrés
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("jugador") or body.name == "Player":
		jugador_cerca = body

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == jugador_cerca:
		jugador_cerca = null
		ocultar_dialogo()
		anim.play("idle_down")
