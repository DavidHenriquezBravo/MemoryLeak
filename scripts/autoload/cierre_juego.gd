extends CanvasLayer

# Mantener Esc durante 3 segundos cierra el juego desde cualquier pantalla (autoload "CierreJuego").
# Mientras se mantiene aparece una barra; al soltar se cancela. Un toque corto de Esc sigue
# funcionando como siempre (cerrar el Registro o la casilla, etc.).
# Cierra con get_tree().quit(), así que Analitica alcanza a escribir cierre_juego.

const SEGUNDOS_PARA_CERRAR := 3.0
const SEGUNDOS_ANTES_DE_MOSTRAR := 0.25      # un toque corto no hace parpadear la barra
const FUENTE := preload("res://Fuentes/upheavtt.ttf")
const C_CYAN := Color(0.239, 0.894, 0.867)

var _tiempo := 0.0
var _panel: PanelContainer
var _barra: ProgressBar


func _ready() -> void:
	layer = 110                                  # por encima de la transición (100)
	process_mode = Node.PROCESS_MODE_ALWAYS      # también funciona con el juego en pausa
	_armar()


func _process(delta: float) -> void:
	if not Input.is_physical_key_pressed(KEY_ESCAPE):
		_tiempo = 0.0
		_panel.visible = false
		return
	_tiempo += delta
	_panel.visible = _tiempo >= SEGUNDOS_ANTES_DE_MOSTRAR
	_barra.value = _tiempo / SEGUNDOS_PARA_CERRAR
	if _tiempo >= SEGUNDOS_PARA_CERRAR:
		set_process(false)
		get_tree().quit()


func _armar() -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.055, 0.055, 0.11, 0.96)
	estilo.set_border_width_all(3)
	estilo.border_color = C_CYAN
	estilo.set_content_margin_all(14)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", estilo)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(620, 0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 24)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.visible = false
	add_child(_panel)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 8)
	_panel.add_child(columna)
	columna.add_child(_etiqueta("CERRANDO EL JUEGO", 34))

	var relleno := StyleBoxFlat.new()
	relleno.bg_color = C_CYAN
	_barra = ProgressBar.new()
	_barra.max_value = 1.0
	_barra.step = 0.0
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(0, 16)
	_barra.add_theme_stylebox_override("fill", relleno)
	columna.add_child(_barra)
	columna.add_child(_etiqueta("LO NO GUARDADO SE PIERDE. SUELTA ESC PARA CANCELAR", 18))


func _etiqueta(texto: String, tamano: int) -> Label:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta.add_theme_font_override("font", FUENTE)
	etiqueta.add_theme_font_size_override("font_size", tamano)
	return etiqueta
