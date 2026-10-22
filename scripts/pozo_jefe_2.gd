extends Area2D

## El pozo abandonado del Stage 2: por aquí se baja con el Anciano al jefe 2 (scenes/cinematicas/bajada_jefe_2.tscn).
## - Al terminar la misión del Anciano «Listo para The Dangling Pointer» (EJ-N2-09) la bajada empieza sola.
## - Con [E] junto al pozo también se baja. Sin estar listo se puede bajar igual: la primera vez el Anciano
##   avisa que todavía no estás al nivel; si vuelves a asomarte, bajan juntos.

const ANCIANO := preload("res://scripts/data/anciano.tres")
const BAJADA := "res://scenes/cinematicas/bajada_jefe_2.tscn"
const MISION_ANCIANO := &"EJ-N2-09"
const C_CYAN := Color("3de4dd")

## El Anciano ya avisó una vez en esta partida (la segunda vez deja bajar)
static var aviso_visto := false

var _cerca := false
var _ocupado := false
var _aviso: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	EventBus.mission_completed.connect(_on_mision_completada)

	_aviso = Label.new()
	_aviso.text = "[E] BAJAR AL POZO"
	_aviso.z_index = 10
	_aviso.position = Vector2(-50, -40)
	_aviso.size = Vector2(100, 12)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_color_override("font_color", C_CYAN)
	_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso.add_theme_constant_override("outline_size", 3)
	_aviso.add_theme_font_size_override("font_size", 8)
	_aviso.visible = false
	add_child(_aviso)


func _process(_delta: float) -> void:
	_aviso.visible = _cerca and not _ocupado and not _hay_algo_abierto()


func _unhandled_input(event: InputEvent) -> void:
	if not _cerca or _ocupado or _hay_algo_abierto():
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_asomarse()


func _hay_algo_abierto() -> bool:
	return Dialogue.is_open or ExercisePanel.is_open or GameState.en_cinematica


func _asomarse() -> void:
	if GameState.listo_para_jefe(2) or aviso_visto:
		_bajar()
		return
	# Todavía no está al nivel: el Anciano avisa, pero no lo impide
	aviso_visto = true
	_ocupado = true
	var faltan: int = GameState.MISIONES_POR_NIVEL.get(2, 0) - GameState.misiones_completadas(2)
	var lineas: Array[String] = ["Espera, viajero. Todavía no estás al nivel de lo que hay ahí abajo."]
	if faltan > 0:
		lineas.append("Aún te faltan %d %s en el distrito. Cada persona que ayudas te hace más fuerte." % [faltan, "misión" if faltan == 1 else "misiones"])
	else:
		lineas.append("Ya ayudaste a todos, pero antes quiero hablar contigo. Estoy aquí al lado.")
	lineas.append("Si de verdad quieres bajar ahora, asómate otra vez al pozo. Yo iré contigo igual.")
	await Dialogue.say(ANCIANO, lineas)
	_ocupado = false


func _on_mision_completada(m: MissionData) -> void:
	if m.id != MISION_ANCIANO:
		return
	# Justo después de esta señal el Anciano dice su despedida: se espera a que termine
	await get_tree().process_frame
	while Dialogue.is_open:
		await get_tree().process_frame
	_bajar()


func _bajar() -> void:
	if _ocupado and GameState.en_cinematica:
		return
	_ocupado = true
	GameState.en_cinematica = true
	Transicion.ir_a(BAJADA)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_cerca = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_cerca = false
