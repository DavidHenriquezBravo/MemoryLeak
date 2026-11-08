extends Control

const ESCENA_JUEGO_PATH: String = "res://scenes/levels/inicio.tscn"

# Referencias a los nodos de la interfaz
@onready var boton_jugar: Button = $VBoxContainer/Jugar
@onready var boton_opciones: OptionButton = $VBoxContainer/Opciones # Ahora es OptionButton
@onready var boton_salir: Button = $VBoxContainer/Salir

# Pantalla del correo: se muestra antes del menú, una sola vez por cada vez que se abre el juego
@onready var menu: VBoxContainer = $VBoxContainer
@onready var panel_correo: PanelContainer = $PanelCorreo
@onready var campo_correo: LineEdit = $PanelCorreo/Contenido/Campo
@onready var error_correo: Label = $PanelCorreo/Contenido/Error
@onready var boton_continuar: Button = $PanelCorreo/Contenido/Continuar

# Pantalla de partidas: se abre con Jugar. Las filas (una por save) se arman por código.
const FUENTE_PARTIDAS := preload("res://Fuentes/upheavtt.ttf")
@onready var panel_partidas: PanelContainer = $PanelPartidas
@onready var filas_partidas: VBoxContainer = $PanelPartidas/Contenido/Filas
@onready var aviso_partidas: Label = $PanelPartidas/Contenido/Aviso
@onready var fila_confirmar: HBoxContainer = $PanelPartidas/Contenido/Confirmar
@onready var boton_borrar_si: Button = $PanelPartidas/Contenido/Confirmar/Si
@onready var boton_borrar_no: Button = $PanelPartidas/Contenido/Confirmar/No
@onready var boton_volver: Button = $PanelPartidas/Contenido/Volver

var _slot_a_borrar := 0

func _ready() -> void:
	boton_borrar_si.pressed.connect(_borrar_confirmado)
	boton_borrar_no.pressed.connect(_armar_partidas)
	boton_volver.pressed.connect(_volver_al_menu)
	campo_correo.text_submitted.connect(_confirmar_correo)
	boton_continuar.pressed.connect(_confirmar_correo.bind(""))
	var falta_correo := Analitica.correo == ""
	panel_correo.visible = falta_correo
	menu.visible = not falta_correo
	if falta_correo:
		campo_correo.grab_focus()


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

func _confirmar_correo(_texto: String) -> void:
	if Analitica.identificar(campo_correo.text):
		panel_correo.hide()
		menu.show()
	else:
		error_correo.text = "CORREO NO VÁLIDO"
		campo_correo.grab_focus()

func _on_boton_jugar_pressed() -> void:
	menu.hide()
	panel_partidas.show()
	_armar_partidas()

func _volver_al_menu() -> void:
	panel_partidas.hide()
	menu.show()

func _armar_partidas() -> void:
	aviso_partidas.text = ""
	fila_confirmar.hide()
	for fila in filas_partidas.get_children():
		filas_partidas.remove_child(fila)
		fila.queue_free()
	for slot in range(1, Guardado.SLOTS + 1):
		var resumen := Guardado.resumen(slot)
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		var texto: String = "NUEVA PARTIDA" if resumen.is_empty() else Guardado.descripcion(resumen).to_upper()
		var elegir := _boton_partida("SAVE %d  -  %s" % [slot, texto])
		elegir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		elegir.alignment = HORIZONTAL_ALIGNMENT_LEFT
		elegir.disabled = resumen.get("danado", false)
		elegir.pressed.connect(_elegir_partida.bind(slot, resumen.is_empty()))
		fila.add_child(elegir)
		if not resumen.is_empty():
			var borrar := _boton_partida("BORRAR")
			borrar.pressed.connect(_pedir_borrado.bind(slot))
			fila.add_child(borrar)
		filas_partidas.add_child(fila)
	(filas_partidas.get_child(0).get_child(0) as Button).grab_focus()

func _boton_partida(texto: String) -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.add_theme_font_override("font", FUENTE_PARTIDAS)
	boton.add_theme_font_size_override("font_size", 28)
	return boton

func _elegir_partida(slot: int, vacia: bool) -> void:
	if vacia:
		Guardado.nueva_partida(slot)
		get_tree().change_scene_to_file(ESCENA_JUEGO_PATH)
	elif Guardado.cargar(slot):
		panel_partidas.hide()
	else:
		aviso_partidas.text = "NO SE PUDO CARGAR ESTE SAVE"

func _pedir_borrado(slot: int) -> void:
	_slot_a_borrar = slot
	aviso_partidas.text = "¿BORRAR SAVE %d? NO SE PUEDE DESHACER" % slot
	fila_confirmar.show()
	boton_borrar_no.grab_focus()

func _borrar_confirmado() -> void:
	Guardado.borrar(_slot_a_borrar)
	_armar_partidas()

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
