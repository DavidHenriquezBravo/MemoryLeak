extends Control

# Ruta a la escena principal de tu juego (Gameplay/Mundo)
# Asegúrate de cambiar esta ruta por la de tu archivo .tscn real
const ESCENA_JUEGO_PATH: String = "res://scenes/levels/stage_1.tscn"

# Referencias a los nodos de la interfaz
@onready var boton_jugar: Button = $VBoxContainer/Jugar
@onready var boton_opciones: Button = $VBoxContainer/Opciones
@onready var boton_salir: Button = $VBoxContainer/Salir

func _ready() -> void:
	# Conectar las señales de los botones por código (si no las conectaste en el editor)
	if not boton_jugar.pressed.is_connected(_on_boton_jugar_pressed):
		boton_jugar.pressed.connect(_on_boton_jugar_pressed)
		
	if not boton_salir.pressed.is_connected(_on_boton_salir_pressed):
		boton_salir.pressed.connect(_on_boton_salir_pressed)
	
	# Desactivar temporalmente el botón de Opciones
	if boton_opciones:
		boton_opciones.disabled = true
		boton_opciones.tooltip_text = "Próximamente" # Mensaje flotante opcional

func _on_boton_jugar_pressed() -> void:
	# Cambia a la escena principal del juego
	var error = get_tree().change_scene_to_file(ESCENA_JUEGO_PATH)
	
	if error != OK:
		print("Error al intentar cargar la escena del juego: ", error)

func _on_boton_salir_pressed() -> void:
	# Cierra el juego
	get_tree().quit()
