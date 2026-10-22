extends Control

# Registro de la Daga (lo crea MissionHud; tecla R o Tab). Dos pestañas:
#   DIRECCIONES -> lo que se anotó al resolver casillas: [0x0140 | 0 maná] buzón del fondo de Sara
#   MEMORIAS    -> las memorias perdidas M1–M6; las que faltan salen como "???" con una pista del lugar
# Mientras está abierto, el juego queda en pausa. ←→ cambia de pestaña, ↑↓ desplaza, R / X cierra.
# Coordenadas en el espacio de MissionHud (640×360, escala 2).

const CAJA := preload("res://Sprites/UI/Cajas/caja_sistema_9slice.png")
const UPH := preload("res://Fuentes/upheavtt.ttf")
const TEXTO := preload("res://Fuentes/texto_dialogo.tres")
const CODIGO := preload("res://Fuentes/codigo.tres")
const C_CYAN := Color(0.239, 0.894, 0.867)
const C_GOLD := Color(0.933, 0.659, 0.251)
const C_DIM := Color(0.61, 0.61, 0.77)
const PESTANAS := ["DIRECCIONES", "MEMORIAS"]
const PASO_SCROLL := 24

var is_open := false
var _pestana := 0
var _etiquetas: Array[Label] = []
var _scroll: ScrollContainer
var _contenido: RichTextLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_crear_accion()
	_armar()


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
		x += 130.0

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

	var ayuda := Label.new()
	ayuda.text = "←→ pestaña    ↑↓ mover    R cerrar"
	ayuda.position = Vector2(96, 312)
	ayuda.add_theme_font_override("font", TEXTO)
	ayuda.add_theme_font_size_override("font_size", 10)
	ayuda.add_theme_color_override("font_color", C_DIM)
	add_child(ayuda)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed(&"registro") and _puede_abrir():
			get_viewport().set_input_as_handled()
			abrir()
		return
	if event.is_action_pressed(&"registro") or event.is_action_pressed(&"ui_cancel") \
			or (InputMap.has_action(&"cancelar") and event.is_action_pressed(&"cancelar")):
		cerrar()
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right"):
		_pestana = 1 - _pestana
		_refrescar()
	elif event.is_action_pressed(&"ui_down"):
		_scroll.scroll_vertical += PASO_SCROLL
	elif event.is_action_pressed(&"ui_up"):
		_scroll.scroll_vertical -= PASO_SCROLL
	else:
		return
	get_viewport().set_input_as_handled()


func _puede_abrir() -> bool:
	return get_parent().visible and not (Dialogue.is_open or ExercisePanel.is_open or GameState.en_cinematica)


func abrir(pestana: int = -1) -> void:
	if pestana >= 0:
		_pestana = pestana
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
			"MEMORIAS %d/%d" % [GameState.memorias.size(), Memorias.TOTAL]]
	for i in _etiquetas.size():
		_etiquetas[i].text = ("▸ " if i == _pestana else "  ") + nombres[i]
		_etiquetas[i].add_theme_color_override("font_color", C_GOLD if i == _pestana else C_DIM)
	_contenido.text = _texto_direcciones() if _pestana == 0 else _texto_memorias()
	_scroll.scroll_vertical = 0


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
