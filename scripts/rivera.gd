extends CharacterBody2D

# Texto de prueba que aparecerá en pantalla y en consola
@export_multiline var texto_dialogo: String = "¡Hola! Soy Andrés, el tutor de punteros (0x00FF)."

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# Referencias a la UI
@onready var cuadro_dialogo: Control = get_tree().current_scene.find_child("CuadroDialogo", true, false)
@onready var label_texto: Label = get_tree().current_scene.find_child("LabelDialogo", true, false)

var jugador_cerca: CharacterBody2D = null
var dialogo_activo: bool = false

func _ready() -> void:
	anim.play("idle_right")
	if cuadro_dialogo:
		cuadro_dialogo.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		print("--- Tecla 'interactuar' (E) presionada ---")
		if jugador_cerca:
			if not dialogo_activo:
				mostrar_dialogo()
			else:
				ocultar_dialogo()
		else:
			print("Intento de interacción fallido: El jugador NO está dentro del Area2D")

func mostrar_dialogo() -> void:
	dialogo_activo = true
	
	# 1. Orientación hacia el jugador
	orientar_hacia_jugador(jugador_cerca.global_position)
	
	# 2. Imprimir diálogo en consola para probar si no hay UI configurada aún
	print("NPC DICE: ", texto_dialogo)
	
	# 3. Mostrar en la UI si existe
	if cuadro_dialogo and label_texto:
		label_texto.text = texto_dialogo
		cuadro_dialogo.show()

func ocultar_dialogo() -> void:
	dialogo_activo = false
	print("Diálogo cerrado.")
	if cuadro_dialogo:
		cuadro_dialogo.hide()

func orientar_hacia_jugador(pos_jugador: Vector2) -> void:
	# Vector de dirección desde Andrés hacia el jugador
	var diff: Vector2 = pos_jugador - global_position
	print("Diferencia de posición con el jugador: X=", diff.x, " | Y=", diff.y)
	
	# Si la distancia en X es mayor que en Y, está a los lados
	if abs(diff.x) > abs(diff.y):
		if diff.x < 0:
			print("Cambiando animación a: idle_left")
			anim.play("idle_left")
		else:
			print("Cambiando animación a: idle_right")
			anim.play("idle_right")
	else:
		print("Cambiando animación a: idle_down")
		anim.play("idle_down")

# Conectar desde la pestaña Nodo > Señales del Area2D
func _on_area_2d_body_entered(body: Node2D) -> void:
	print("Objeto entró al Area2D: ", body.name)
	# Si tu jugador no está en el grupo "jugador", aceptamos cualquier CharacterBody2D para probar
	if body is CharacterBody2D and body != self:
		jugador_cerca = body
		print("-> Jugador detectado exitosamente!")

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == jugador_cerca:
		print("-> Jugador salió del área de Andrés")
		jugador_cerca = null
		ocultar_dialogo()
		anim.play("idle_right")
