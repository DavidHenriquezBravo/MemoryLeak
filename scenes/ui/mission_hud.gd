extends CanvasLayer

# HUD de misión (autoload "MissionHud"):
#   - arriba a la derecha, la misión activa con su objetivo (caja dorada del boceto)
#   - al empezar una misión: aviso "¡NUEVA MISIÓN!" unos segundos
#   - al terminarla: aviso "¡MISIÓN COMPLETA!" con la recompensa

const CAJA_MISION := preload("res://Sprites/caja_mision_9slice.png")
const CAJA_ACIERTO := preload("res://Sprites/caja_acierto_9slice.png")
const C_GOLD := Color(0.933, 0.659, 0.251)
const C_GREEN := Color(0.439, 0.902, 0.439)
const SEGUNDOS_AVISO := 2.5

# Cuándo empezó la última misión (lo usa ExercisePanel para no tapar el aviso)
var ultimo_inicio_ms: int = -100000

@onready var caja: NinePatchRect = %Caja
@onready var aviso: NinePatchRect = %Aviso

var _tween: Tween


func _ready() -> void:
	caja.visible = false
	aviso.visible = false
	EventBus.mission_started.connect(_on_started)
	EventBus.mission_completed.connect(_on_completed)


func _on_started(m: MissionData) -> void:
	ultimo_inicio_ms = Time.get_ticks_msec()
	%Titulo.text = m.title
	%Objetivo.text = AddrFormatter.format(m.objective)
	caja.visible = true
	await get_tree().process_frame
	caja.size.y = %Contenido.get_combined_minimum_size().y + 10
	_mostrar_aviso("¡NUEVA MISIÓN!", m.title, false)


func _on_completed(m: MissionData) -> void:
	caja.visible = false
	# Se avisa cuando el NPC termina su diálogo final, para no tapar el banner verde
	await get_tree().process_frame
	while Dialogue.is_open:
		await get_tree().process_frame
	var texto := m.title
	if m.exercise and m.exercise.reward:
		texto += "   " + m.exercise.reward.label()
	_mostrar_aviso("¡MISIÓN COMPLETA!", texto, true)


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
