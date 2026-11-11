extends Control

# Registro de la Daga (lo crea MissionHud; tecla R o Tab). Tres pestañas:
#   DIRECCIONES -> lo que se anotó al resolver casillas: [0x0140 | 0 maná] buzón del fondo de Sara
#   MEMORIAS    -> las memorias perdidas M1–M6; las que faltan salen como "???" con una pista del lugar
#   GUARDAR     -> los saves de la partida (autoload Guardado); ↑↓ elige, E guarda, X cancela
#   CONFIGURACIÓN -> volumen del juego (bus Master); ↑↓ sube/baja, E silencia. Se guarda en user://ajustes.cfg
# Mientras está abierto, el juego queda en pausa. ←→ cambia de pestaña, ↑↓ desplaza, R / X cierra.
# Coordenadas en el espacio de MissionHud (640×360, escala 2).

const CAJA := preload("res://Sprites/UI/Cajas/caja_sistema_9slice.png")
const UPH := preload("res://Fuentes/upheavtt.ttf")
const TEXTO := preload("res://Fuentes/texto_dialogo.tres")
const CODIGO := preload("res://Fuentes/codigo.tres")
const C_CYAN := Color(0.239, 0.894, 0.867)
const C_GOLD := Color(0.933, 0.659, 0.251)
const C_DIM := Color(0.61, 0.61, 0.77)
const PESTANAS := ["DIRECCIONES", "MEMORIAS", "GUARDAR", "CONFIGURACIÓN"]
const PESTANA_GUARDAR := 2
const PESTANA_CONFIG := 3
const PASO_SCROLL := 24

const ARCHIVO_AJUSTES := "user://ajustes.cfg"
const VOLUMEN_INICIAL := 0.7       # un poco más bajo que el volumen original de cada pista
const PASO_VOLUMEN := 0.1

var is_open := false
var _pestana := 0
var _etiquetas: Array[Label] = []
var _scroll: ScrollContainer
var _contenido: RichTextLabel
var _ayuda: Label
var _slot_elegido := 1
var _confirmando := false     # el save elegido tiene datos: falta confirmar que se sobrescribe
var _mensaje := ""
var volumen := VOLUMEN_INICIAL      # 0..1
var silencio := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_crear_accion()
	_armar()
	_cargar_ajustes()                 # el Registro se crea al abrir el juego: el volumen se aplica desde el menú


# La acción "registro" (R y Tab) se crea aquí para no tener que tocar project.godot
func _crear_accion() -> void:
	if InputMap.has_action(&"registro"):
		return
	InputMap.add_action(&"registro")
	for tecla in [KEY_R, KEY_TAB]:
		var ev := InputEventKey.new()
		ev.physical_keycode = tecla
		InputMap.action_add_event(&"registro", ev)


func _armar() -> void:
	var oscuro := ColorRect.new()
	oscuro.color = Color(0, 0, 0, 0.6)
	oscuro.position = Vector2.ZERO
	oscuro.size = Vector2(640, 360)
	add_child(oscuro)

	var marco := NinePatchRect.new()
	marco.texture = CAJA
	marco.patch_margin_left = 4
	marco.patch_margin_top = 4
	marco.patch_margin_right = 4
	marco.patch_margin_bottom = 4
	marco.position = Vector2(80, 26)
	marco.size = Vector2(480, 308)
	add_child(marco)

	var titulo := Label.new()
	titulo.text = "REGISTRO DE LA DAGA"
	titulo.position = Vector2(96, 34)
	titulo.add_theme_font_override("font", UPH)
	titulo.add_theme_font_size_override("font_size", 20)
	titulo.add_theme_color_override("font_color", C_CYAN)
	add_child(titulo)

	var x := 96.0
	for i in PESTANAS.size():
		var et := Label.new()
		et.position = Vector2(x, 62)
		et.add_theme_font_override("font", TEXTO)
		et.add_theme_font_size_override("font_size", 11)
		add_child(et)
		_etiquetas.append(et)
		x += 112.0

	var linea := ColorRect.new()
	linea.color = Color(0.306, 0.306, 0.69)
	linea.position = Vector2(96, 80)
	linea.size = Vector2(448, 1)
	add_child(linea)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(96, 86)
	_scroll.size = Vector2(448, 220)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_contenido = RichTextLabel.new()
	_contenido.bbcode_enabled = true
	_contenido.fit_content = true
	_contenido.scroll_active = false
	_contenido.custom_minimum_size = Vector2(440, 0)
	_contenido.add_theme_font_override("normal_font", TEXTO)
	_contenido.add_theme_font_override("mono_font", CODIGO)
	_contenido.add_theme_font_size_override("normal_font_size", 11)
	_contenido.add_theme_font_size_override("mono_font_size", 10)
	_contenido.add_theme_color_override("default_color", Color(0.933, 0.933, 0.965))
	_scroll.add_child(_contenido)

	_ayuda = Label.new()
	_ayuda.position = Vector2(96, 312)
	_ayuda.add_theme_font_override("font", TEXTO)
	_ayuda.add_theme_font_size_override("font_size", 10)
	_ayuda.add_theme_color_override("font_color", C_DIM)
	add_child(_ayuda)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed(&"registro") and _puede_abrir():
			get_viewport().set_input_as_handled()
			abrir()
		return
	var en_guardar := _pestana == PESTANA_GUARDAR
	var en_config := _pestana == PESTANA_CONFIG
	if event.is_action_pressed(&"registro"):
		cerrar()
	elif event.is_action_pressed(&"ui_cancel") or (InputMap.has_action(&"cancelar") and event.is_action_pressed(&"cancelar")):
		if _confirmando:
			_confirmando = false
			_refrescar()
		else:
			cerrar()
	elif event.is_action_pressed(&"ui_left"):
		_cambiar_pestana(-1)
	elif event.is_action_pressed(&"ui_right"):
		_cambiar_pestana(1)
	elif event.is_action_pressed(&"ui_down"):
		if en_guardar:
			_mover_slot(1)
		elif en_config:
			_cambiar_volumen(-PASO_VOLUMEN)
		else:
			_scroll.scroll_vertical += PASO_SCROLL
	elif event.is_action_pressed(&"ui_up"):
		if en_guardar:
			_mover_slot(-1)
		elif en_config:
			_cambiar_volumen(PASO_VOLUMEN)
		else:
			_scroll.scroll_vertical -= PASO_SCROLL
	elif en_guardar and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		_guardar()
	elif en_config and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		silencio = not silencio
		_aplicar_ajustes(true)
	else:
		return
	get_viewport().set_input_as_handled()


func _cambiar_pestana(paso: int) -> void:
	_pestana = wrapi(_pestana + paso, 0, PESTANAS.size())
	_confirmando = false
	_mensaje = ""
	_refrescar()


func _mover_slot(paso: int) -> void:
	_slot_elegido = wrapi(_slot_elegido + paso, 1, Guardado.SLOTS + 1)
	_confirmando = false
	_mensaje = ""
	_refrescar()


func _guardar() -> void:
	if not _confirmando and not Guardado.resumen(_slot_elegido).is_empty():
		_confirmando = true
		_mensaje = ""
	else:
		_confirmando = false
		if Guardado.guardar(_slot_elegido):
			_mensaje = "[color=#70e670]Partida guardada en SAVE %d.[/color]" % _slot_elegido
		else:
			_mensaje = "[color=#e0679d]No se pudo guardar.[/color]"
	_refrescar()


# --- Volumen ---
func _cambiar_volumen(paso: float) -> void:
	volumen = clampf(snappedf(volumen + paso, PASO_VOLUMEN), 0.0, 1.0)
	silencio = false
	_aplicar_ajustes(true)


func _aplicar_ajustes(guardar: bool) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(volumen))
	AudioServer.set_bus_mute(0, silencio or volumen <= 0.0)
	if guardar:
		var cfg := ConfigFile.new()
		cfg.set_value("audio", "volumen", volumen)
		cfg.set_value("audio", "silencio", silencio)
		cfg.save(ARCHIVO_AJUSTES)
		if is_open:
			_refrescar()


func _cargar_ajustes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO_AJUSTES) == OK:
		volumen = clampf(float(cfg.get_value("audio", "volumen", VOLUMEN_INICIAL)), 0.0, 1.0)
		silencio = bool(cfg.get_value("audio", "silencio", false))
	_aplicar_ajustes(false)


func _texto_config() -> String:
	var llenas := roundi(volumen * 10)
	var barra := "[color=#3de4dd]%s[/color][color=#4e4eb0]%s[/color]" % ["■".repeat(llenas), "■".repeat(10 - llenas)]
	var estado := "[color=#e0679d]SILENCIADO[/color]" if silencio or volumen <= 0.0 else "%d %%" % roundi(volumen * 100)
	return ("[color=#eea840]▸ VOLUMEN[/color]\n\n%s   %s\n\n" % [barra, estado]
		+ "[color=#9c9cc4]↑ subir    ↓ bajar    E silenciar / activar\nSe guarda en este computador para las próximas partidas.[/color]")


func _puede_abrir() -> bool:
	return get_parent().visible and not (Dialogue.is_open or ExercisePanel.is_open or GameState.en_cinematica)


func abrir(pestana: int = -1) -> void:
	if pestana >= 0:
		_pestana = pestana
	_slot_elegido = maxi(Guardado.slot_actual, 1)
	_confirmando = false
	_mensaje = ""
	is_open = true
	visible = true
	# La pausa también detendría la música del nivel: los reproductores siguen sonando
	for musica in get_tree().current_scene.find_children("*", "AudioStreamPlayer", true, false) 			+ get_tree().current_scene.find_children("*", "AudioStreamPlayer2D", true, false):
		musica.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_refrescar()


func cerrar() -> void:
	is_open = false
	visible = false
	get_tree().paused = false


func _refrescar() -> void:
	var nombres := ["DIRECCIONES %d" % GameState.revealed.size(),
			"MEMORIAS %d/%d" % [GameState.memorias.size(), Memorias.TOTAL], "GUARDAR", "CONFIGURACIÓN"]
	for i in _etiquetas.size():
		_etiquetas[i].text = ("▸ " if i == _pestana else "  ") + nombres[i]
		_etiquetas[i].add_theme_color_override("font_color", C_GOLD if i == _pestana else C_DIM)
	match _pestana:
		0:
			_contenido.text = _texto_direcciones()
		1:
			_contenido.text = _texto_memorias()
		PESTANA_CONFIG:
			_contenido.text = _texto_config()
		_:
			_contenido.text = _texto_guardar()
	match _pestana:
		PESTANA_GUARDAR:
			_ayuda.text = "←→ pestaña    ↑↓ elegir    E guardar    R cerrar"
		PESTANA_CONFIG:
			_ayuda.text = "←→ pestaña    ↑↓ volumen    E silenciar    R cerrar"
		_:
			_ayuda.text = "←→ pestaña    ↑↓ mover    R cerrar"
	_scroll.scroll_vertical = 0


func _texto_guardar() -> String:
	var t := ""
	for slot in range(1, Guardado.SLOTS + 1):
		var elegido := slot == _slot_elegido
		t += "[color=%s]%sSAVE %d[/color]   %s\n\n" % ["#eea840" if elegido else "#9c9cc4", "▸ " if elegido else "   ", slot,
				Guardado.descripcion(Guardado.resumen(slot))]
	if _confirmando:
		t += "[color=#eea840]SAVE %d ya tiene una partida. E: sobrescribir    X: cancelar[/color]" % _slot_elegido
	return t + _mensaje


func _texto_direcciones() -> String:
	if GameState.revealed.is_empty():
		return "[color=#9c9cc4]Todavía no hay direcciones anotadas. Resuelve casillas para llenarlo.[/color]"
	var direcciones: Array = GameState.revealed.keys()
	direcciones.sort()
	var t := ""
	for d: String in direcciones:
		var r: Dictionary = GameState.revealed[d]
		t += "[color=#3de4dd][code]%s[/code][/color]   [color=#eea840]%s[/color]   %s\n" % [d, _bb(str(r["value"])), _bb(str(r["label"]))]
	return t


func _texto_memorias() -> String:
	var t := ""
	for m: Dictionary in Memorias.LISTA:
		if GameState.memorias.has(m["id"]):
			t += "[color=#eea840]%s · %s[/color]\n%s\n\n" % [m["id"], m["lugar"], AddrFormatter.format(m["texto"])]
		else:
			t += "[color=#9c9cc4]%s · ???\nPista: %s[/color]\n\n" % [m["id"], _pista(m["lugar"])]
	return t


# Escapa los corchetes de un texto suelto para que no se lean como BBCode
func _bb(s: String) -> String:
	return s.replace("[", "[lb]")


# "Junto a la casa" -> "junto a la casa" (solo la primera letra: "Laguna de los Espejos" queda igual)
func _pista(lugar: String) -> String:
	return lugar.left(1).to_lower() + lugar.substr(1)
