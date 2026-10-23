extends CanvasLayer

# HUD de misión (autoload "MissionHud"):
#   - arriba a la derecha, la misión activa con su objetivo (caja dorada del boceto)
#   - si no hay misión activa, la caja sugiere la siguiente: "→ Habla con Juan"
#   - al empezar una misión: aviso "¡NUEVA MISIÓN!" unos segundos
#   - al terminarla: aviso "¡SUBISTE AL NIVEL N!" con la misión y la recompensa
#   - en el nivel 2, al abrir una placa intermedia el objetivo pasa a la casilla siguiente
#   - al recoger una memoria perdida: aviso "¡MEMORIA RECUPERADA N/6!"
#   - el Registro de la Daga (tecla R) vive aquí como hijo: scenes/ui/registro.gd
# No se muestra en el menú, en la pelea ni en el game over.

const CAJA_MISION := preload("res://Sprites/UI/Cajas/caja_mision_9slice.png")
const CAJA_ACIERTO := preload("res://Sprites/UI/Cajas/caja_acierto_9slice.png")
const C_GOLD := Color(0.933, 0.659, 0.251)
const C_GREEN := Color(0.439, 0.902, 0.439)
const SEGUNDOS_AVISO := 2.5
const ESCENAS_SIN_HUD := ["menu", "pelea", "game_over", "cinematicas", "nucleo_final", "levels/inicio"]
const REGISTRO := preload("res://scenes/ui/registro.gd")

# Cuándo empezó la última misión (lo usa ExercisePanel para no tapar el aviso)
var ultimo_inicio_ms: int = -100000

@onready var caja: NinePatchRect = %Caja
@onready var aviso: NinePatchRect = %Aviso

var _tween: Tween
var registro: Control
var _ruta_escena := ""   # para notar el cambio de escena (el nivel de la sugerencia depende de dónde estás)


func _ready() -> void:
	caja.visible = false
	aviso.visible = false
	EventBus.mission_started.connect(_on_started)
	EventBus.mission_completed.connect(_on_completed)
	EventBus.cadena_avanzo.connect(_on_cadena)
	GameState.memoria_recuperada.connect(_on_memoria)
	registro = REGISTRO.new()
	registro.name = "Registro"
	add_child(registro)
	GameState.stats_changed.connect(_actualizar_sugerencia)
	_actualizar_sugerencia.call_deferred()


func _process(_delta: float) -> void:
	var escena := get_tree().current_scene
	var ruta := escena.scene_file_path if escena != null else ""
	var oculto := false
	for clave: String in ESCENAS_SIN_HUD:
		if ruta.contains(clave):
			oculto = true
	visible = not oculto
	if ruta != _ruta_escena:
		_ruta_escena = ruta
		_actualizar_sugerencia()


func _on_started(m: MissionData) -> void:
	ultimo_inicio_ms = Time.get_ticks_msec()
	%Etiqueta.text = "MISIÓN"
	%Titulo.text = m.title
	%Objetivo.text = AddrFormatter.format(m.objective)
	caja.visible = true
	await get_tree().process_frame
	caja.size.y = %Contenido.get_combined_minimum_size().y + 10
	_mostrar_aviso("¡NUEVA MISIÓN!", m.title, false)


# Placa intermedia resuelta: el objetivo ahora es la casilla a la que apuntaba
func _on_cadena(m: MissionData) -> void:
	if MissionManager.active != m:
		return
	var siguiente := MissionManager.casilla_objetivo()
	%Objetivo.text = AddrFormatter.format("→ Abre la casilla `%s`" % siguiente)
	await get_tree().process_frame
	caja.size.y = %Contenido.get_combined_minimum_size().y + 10


# Memoria perdida: se avisa cuando termina de contarse el recuerdo
func _on_memoria(id: StringName) -> void:
	await get_tree().process_frame
	while Dialogue.is_open:
		await get_tree().process_frame
	var datos := Memorias.buscar(id)
	_mostrar_aviso("¡MEMORIA RECUPERADA %d/%d!" % [GameState.memorias.size(), Memorias.TOTAL],
			str(datos.get("lugar", "")), true)


func _on_completed(m: MissionData) -> void:
	caja.visible = false
	# Se avisa cuando el NPC termina su diálogo final, para no tapar el banner verde
	await get_tree().process_frame
	while Dialogue.is_open:
		await get_tree().process_frame
	var texto := m.title
	if m.exercise and m.exercise.reward:
		texto += "   " + m.exercise.reward.label()
		# Cada misión con premio es un nivel más (las del Anciano no suben)
		_mostrar_aviso("¡SUBISTE AL NIVEL %d!" % GameState.nivel_jugador, texto, true)
	elif m.variante_de != &"":
		_mostrar_aviso("¡REPASO SUPERADO!", m.title, true)
	else:
		_mostrar_aviso("¡MISIÓN COMPLETA!", texto, true)
	_actualizar_sugerencia()


# Sin misión activa, la caja dice qué hacer ahora (la ruta guiada de MissionManager)
func _actualizar_sugerencia() -> void:
	if MissionManager.active != null:
		return
	var nivel := GameState.nivel_historia()
	if not GameState.NOMBRES_JEFE.has(nivel):
		caja.visible = false
		return
	var m := MissionManager.siguiente_sugerida()
	%Etiqueta.text = "SIGUIENTE"
	if m != null:
		%Titulo.text = m.title
		%Objetivo.text = AddrFormatter.format("→ Habla con %s" % m.giver_name)
	elif GameState.listo_para_jefe(nivel):
		%Titulo.text = GameState.NOMBRES_JEFE[nivel]
		%Objetivo.text = ["→ Cruza la puerta del norte", "→ Baja por el pozo con el Anciano",
				"→ Entra al Núcleo del volcán"][nivel - 1]
	else:
		caja.visible = false
		return
	caja.visible = true
	await get_tree().process_frame
	caja.size.y = %Contenido.get_combined_minimum_size().y + 10


func _mostrar_aviso(titulo: String, texto: String, completa: bool) -> void:
	%AvisoTitulo.text = titulo
	%AvisoTitulo.add_theme_color_override("font_color", C_GREEN if completa else C_GOLD)
	%AvisoTexto.text = texto
	aviso.texture = CAJA_ACIERTO if completa else CAJA_MISION
	aviso.visible = true
	aviso.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(aviso, "modulate:a", 1.0, 0.2)
	_tween.tween_interval(SEGUNDOS_AVISO)
	_tween.tween_property(aviso, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(aviso.hide)
