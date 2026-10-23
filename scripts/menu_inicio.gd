extends Control

const ESCENA_JUEGO_PATH: String = "res://scenes/levels/inicio.tscn"

# Referencias a los nodos de la interfaz
@onready var boton_jugar: Button = $VBoxContainer/Jugar
@onready var boton_opciones: OptionButton = $VBoxContainer/Opciones # Ahora es OptionButton
@onready var boton_salir: Button = $VBoxContainer/Salir

func _ready() -> void:
	if not boton_jugar.pressed.is_connected(_on_boton_jugar_pressed):
		boton_jugar.pressed.connect(_on_boton_jugar_pressed)
		
	if not boton_salir.pressed.is_connected(_on_boton_salir_pressed):
		boton_salir.pressed.connect(_on_boton_salir_pressed)
		
	if boton_opciones:
		boton_opciones.clear() 
		boton_opciones.add_item("Resolución: 1280x720", 0)
		boton_opciones.add_item("Resolución: 1920x1080", 1)
		
		# --- NUEVO: Forzar la resolución inicial ---
		boton_opciones.select(0) # Hace que el texto del botón diga 1280x720
		_on_opciones_item_selected(0) # Ejecuta el código para poner la ventana en 1280x720
		
		# Conectar la señal
		if not boton_opciones.item_selected.is_connected(_on_opciones_item_selected):
			boton_opciones.item_selected.connect(_on_opciones_item_selected)

func _on_boton_jugar_pressed() -> void:
	var error = get_tree().change_scene_to_file(ESCENA_JUEGO_PATH)
	if error != OK:
		print("Error al cargar la escena: ", error)

# Esta función se ejecuta al elegir una opción del menú desplegable
func _on_opciones_item_selected(index: int) -> void:
	var nueva_resolucion: Vector2i
	
	match index:
		0:
			nueva_resolucion = Vector2i(1280, 720)
		1:
			nueva_resolucion = Vector2i(1920, 1080)
			
	print("Cambiando resolución a: ", nueva_resolucion)
	if Engine.is_embedded_in_editor():
		print("(el juego está dentro del editor: la ventana no se puede cambiar; en el .exe sí)")
		return
	
	# Cambiar el tamaño de la ventana
	DisplayServer.window_set_size(nueva_resolucion)
	
	# Centrar la ventana en la pantalla actual
	var tamano_pantalla = DisplayServer.screen_get_size()
	var posicion_centrada = (tamano_pantalla / 2) - (nueva_resolucion / 2)
	
	# Mover la ventana solo si el sistema lo permite
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_position(posicion_centrada)

func _on_boton_salir_pressed() -> void:
	get_tree().quit()
