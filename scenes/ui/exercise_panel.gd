extends CanvasLayer

# Pantalla de la casilla de RAM (o prueba del NPC), como en los bocetos:
#   PREGUNTA -> código + memoria + 3 opciones (↑↓ y E)
#   ERROR    -> lo que pasó en el mundo + concepto + pista; espera 5 s
#   EJEMPLO  -> desde el 3er error: ejemplo resuelto con otra variable
#   ACIERTO  -> banner verde con el concepto y la recompensa; luego el diálogo final
# Es un autoload ("ExercisePanel"): escucha EventBus y responde a MissionManager.

enum Estado { CERRADO, PREGUNTA, ERROR, EJEMPLO, ACIERTO }

const LETRAS := ["A", "B", "C", "D"]
const ICONOS := {
	RewardData.Stat.DAMAGE: preload("res://Sprites/espada.png"),
	RewardData.Stat.ARMOR: preload("res://Sprites/escudo.png"),
	RewardData.Stat.LUCK: preload("res://Sprites/Trebol.png"),
	RewardData.Stat.MAX_HP: preload("res://Sprites/Corazon.png"),
}
const C_DIM := Color(0.61, 0.61, 0.77)
const C_GOLD := Color(0.933, 0.659, 0.251)
const C_CYAN := Color(0.239, 0.894, 0.867)
const SEGUNDOS_TRAS_AVISO := 1.6   # deja ver "¡NUEVA MISIÓN!" antes de abrir la prueba

var is_open := false
var estado := Estado.CERRADO

var _mision: MissionData
var _sel := 0
var _filas: Array[Control] = []

@onready var oscuro: ColorRect = %Oscuro
@onready var pregunta: Control = %Pregunta
@onready var error: Control = %Error
@onready var ejemplo: Control = %Ejemplo
@onready var acierto: Control = %Acierto


func _ready() -> void:
	_ocultar_todo()
	# La primera fila de opción está en la escena; las demás se copian de ella
	var plantilla: Control = %Opcion0
	_filas.append(plantilla)
	for i in 2:
		var fila := plantilla.duplicate() as Control
		fila.unique_name_in_owner = false
		fila.name = "Opcion%d" % (i + 1)
		%Opciones.add_child(fila)
		_filas.append(fila)
	EventBus.exercise_requested.connect(_abrir)
	EventBus.exercise_failed.connect(_on_fallo)
	EventBus.exercise_passed.connect(_on_acierto)


func _process(_delta: float) -> void:
	if estado == Estado.ERROR:
		_actualizar_espera()


# ------------------------------------------------------------------ entrada
func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	var aceptar := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	match estado:
		Estado.PREGUNTA:
			if event.is_action_pressed("ui_up"):
				_mover(-1)
			elif event.is_action_pressed("ui_down"):
				_mover(1)
			elif aceptar:
				_confirmar()
			elif event.is_action_pressed("ui_cancel") or (InputMap.has_action("cancelar") and event.is_action_pressed("cancelar")):
				_cerrar()
			else:
				return
		Estado.ERROR:
			if not aceptar:
				return
			if MissionManager.lock_remaining() <= 0.0:
				if MissionManager.attempts >= 3:
					_mostrar_ejemplo()
				else:
					_mostrar_pregunta()
		Estado.EJEMPLO:
			if not aceptar:
				return
			_mostrar_pregunta()
		Estado.ACIERTO:
			if not aceptar:
				return
			_continuar_acierto()
		_:
			return
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ PREGUNTA
func _abrir(mision: MissionData) -> void:
	if mision == null or mision.exercise == null:
		return
	_mision = mision
	_sel = 0
	is_open = true            # el jugador ya queda quieto
	estado = Estado.CERRADO
	# Prueba en diálogo: se abre justo al aceptar la misión, así que espera al aviso
	var espera := SEGUNDOS_TRAS_AVISO - (Time.get_ticks_msec() - MissionHud.ultimo_inicio_ms) / 1000.0
	if mision.cell_address == "" and espera > 0.0:
		await get_tree().create_timer(espera).timeout
		if _mision != mision or not is_open:
			return
	_mostrar_pregunta()


func _mostrar_pregunta() -> void:
	var e := _mision.exercise
	_ocultar_todo()
	oscuro.visible = true
	pregunta.visible = true
	estado = Estado.PREGUNTA

	%Titulo.text = e.title
	%Titulo.size.x = %Titulo.get_minimum_size().x
	%Direccion.text = GameState.norm(_mision.cell_address) if _mision.cell_address != "" else ""
	%Direccion.position.x = %Titulo.position.x + %Titulo.size.x + 8
	%IdOa.text = "%s · %s" % [_mision.id, _mision.oa_code]
	%Codigo.text = e.code
	%Enunciado.text = AddrFormatter.format(e.question)
	%Memoria.set_cells(e.memory_cells, _mision.cell_address)

	for i in _filas.size():
		var fila := _filas[i]
		fila.visible = i < e.options.size()
		if fila.visible:
			(fila.get_node("Letra") as Label).text = LETRAS[i] + ")"
			(fila.get_node("Texto") as RichTextLabel).text = AddrFormatter.format(e.options[i].text)
	_sel = clampi(_sel, 0, e.options.size() - 1)
	_marcar()
	%Intento.text = "Intento %d" % (MissionManager.attempts + 1)


func _mover(paso: int) -> void:
	var n := _mision.exercise.options.size()
	_sel = wrapi(_sel + paso, 0, n)
	_marcar()


func _marcar() -> void:
	for i in _filas.size():
		var activa := i == _sel
		var fila := _filas[i]
		(fila.get_node("Fondo") as CanvasItem).visible = activa
		(fila.get_node("Cursor") as CanvasItem).visible = activa
		(fila.get_node("Letra") as Label).add_theme_color_override("font_color", C_GOLD if activa else C_DIM)


func _confirmar() -> void:
	MissionManager.answer(_mision.exercise.options[_sel])   # emite exercise_failed o exercise_passed


func _cerrar() -> void:
	# La misión sigue activa: se puede volver a la casilla (o hablar con el NPC) para reintentar
	_ocultar_todo()
	estado = Estado.CERRADO
	is_open = false


# ------------------------------------------------------------------ ERROR
func _on_fallo(_m: MissionData, opcion: OptionData, intento: int) -> void:
	if not is_open:
		return
	_ocultar_todo()
	oscuro.visible = true
	error.visible = true
	estado = Estado.ERROR

	%ErrorTitulo.text = "RESPUESTA %s" % LETRAS[_sel]
	%Elegiste.text = "Elegiste: " + AddrFormatter.format(opcion.text)
	%Retro.text = AddrFormatter.format(opcion.wrong_feedback)
	%ConceptoError.text = AddrFormatter.format(opcion.concept_on_error)

	# Pista escalonada: 1 narrativa, 2 conceptual, 3 ejemplo resuelto
	var etiqueta := "PISTA 1"
	var pista := opcion.hint
	if intento == 2:
		etiqueta = "PISTA 2"
		pista = _mision.exercise.conceptual_hint
	elif intento >= 3:
		etiqueta = "PISTA 3"
		pista = "Al continuar verás un ejemplo resuelto con otra variable."
	%PistaEtiqueta.text = etiqueta
	%PistaTexto.text = AddrFormatter.format(pista)
	%FilaPista.visible = pista != ""
	_actualizar_espera()
	# La caja crece o se achica según el texto, centrada en la pantalla
	# (se mide dónde terminó el pie una vez que Godot acomodó los textos)
	%ContenidoError.position.y = 54.0
	%ContenidoError.size.y = 254.0
	await get_tree().process_frame
	await get_tree().process_frame
	if estado != Estado.ERROR:
		return
	var alto: float = %Pie.position.y + %Pie.size.y
	var marco_alto := alto + 30.0
	var arriba := roundf((360.0 - marco_alto) / 2.0)
	%MarcoError.position.y = arriba
	%MarcoError.size.y = marco_alto
	%ContenidoError.position.y = arriba + 14.0
	%ContenidoError.size.y = alto + 2.0


func _actualizar_espera() -> void:
	var falta := MissionManager.lock_remaining()
	var que := "La casilla se reabre" if _mision.cell_address != "" else "Puedes reintentar"
	if falta > 0.0:
		%Espera.text = "%s en %d s" % [que, ceili(falta)]
		%Boton.modulate = Color(1, 1, 1, 0.35)
	else:
		%Espera.text = "E: volver a intentar"
		%Boton.modulate = Color.WHITE


# ------------------------------------------------------------------ EJEMPLO (3er error)
func _mostrar_ejemplo() -> void:
	var e := _mision.exercise
	_ocultar_todo()
	oscuro.visible = true
	ejemplo.visible = true
	estado = Estado.EJEMPLO
	%EjemploCodigo.text = e.example_code
	%EjemploMemoria.set_cells(e.example_cells)
	%EjemploTexto.text = AddrFormatter.format(e.example_text)
	%EjemploSigue.text = AddrFormatter.format(e.example_followup)
	# La explicación va justo debajo del código o de la memoria (lo que termine más abajo)
	await get_tree().process_frame
	var fondo_codigo: float = %EjemploCodigoFondo.position.y + %EjemploCodigoFondo.get_combined_minimum_size().y
	var fondo_memoria: float = %EjemploMemoria.position.y + e.example_cells.size() * MemoryView.ROW_H
	%EjemploTextos.position.y = maxf(fondo_codigo, fondo_memoria) + 18.0


# ------------------------------------------------------------------ ACIERTO
func _on_acierto(m: MissionData) -> void:
	if not is_open:
		return
	var e := m.exercise
	_ocultar_todo()
	acierto.visible = true
	estado = Estado.ACIERTO
	%AciertoTitulo.text = e.success_title
	%AciertoTexto.text = AddrFormatter.format(e.success_text)
	%ConceptoOk.text = AddrFormatter.format(e.concept_text)
	var hay_premio := e.reward != null
	%PremioIcono.visible = hay_premio
	%Premio.visible = hay_premio
	%LineaV.visible = hay_premio
	if hay_premio:
		%PremioIcono.texture = ICONOS.get(e.reward.stat)
		%Premio.text = e.reward.label()
	%Continuar.visible = true
	# El marco crece con el texto
	await get_tree().process_frame
	await get_tree().process_frame
	var alto: float = %FilaConceptoOk.position.y + %FilaConceptoOk.size.y
	%Marco.size.y = maxf(64.0, alto + 18.0)
	%LineaV.size.y = %Marco.size.y - 12.0


func _continuar_acierto() -> void:
	# El banner queda arriba mientras el NPC dice su diálogo final (como en el boceto)
	estado = Estado.CERRADO
	is_open = false
	%Continuar.visible = false
	await MissionManager.finish_success()
	if estado == Estado.CERRADO:
		_ocultar_todo()


func _ocultar_todo() -> void:
	oscuro.visible = false
	pregunta.visible = false
	error.visible = false
	ejemplo.visible = false
	acierto.visible = false
