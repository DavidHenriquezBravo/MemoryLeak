extends Node

# Coordina el flujo: diálogo -> (casilla) -> ejercicio -> acierto/error -> recompensa -> diálogo final.
# No dibuja nada: las pantallas escuchan las señales de EventBus.

const LOCK_SECONDS := 5.0

# Orden en que el HUD sugiere las misiones de cada nivel
# (en el nivel 1 las 3 primeras personas se pueden hacer en cualquier orden)
const RUTAS := {
	1: [
		"res://data/missions/ej_n1_01.tres",
		"res://data/missions/ej_n1_02.tres",
		"res://data/missions/ej_n1_03.tres",
		"res://data/missions/ej_n1_07.tres",
		"res://data/missions/ej_n1_05.tres",
		"res://data/missions/ej_n1_04.tres",
		"res://data/missions/ej_n1_06.tres",
		"res://data/missions/ej_n1_08.tres",
		"res://data/missions/ej_n1_09.tres",
	],
	2: [
		"res://data/missions/ej_n2_01.tres",
		"res://data/missions/ej_n2_02.tres",
		"res://data/missions/ej_n2_05.tres",
		"res://data/missions/ej_n2_03.tres",
		"res://data/missions/ej_n2_04.tres",
		"res://data/missions/ej_n2_07.tres",
		"res://data/missions/ej_n2_09.tres",
	],
	3: [
		"res://data/missions/ej_n3_01.tres",
		"res://data/missions/ej_n3_02.tres",
		"res://data/missions/ej_n3_03.tres",
		"res://data/missions/ej_n3_04.tres",
		"res://data/missions/ej_n3_05.tres",
		"res://data/missions/ej_n3_06.tres",
		"res://data/missions/ej_n3_07.tres",
		"res://data/missions/ej_n3_08.tres",
		"res://data/missions/ej_n3_09.tres",
	],
}
const SISTEMA := preload("res://data/npc/sistema.tres")

var active: MissionData = null
var active_npc: NpcData = null
var attempts: int = 0
var _locked_until_ms: int = 0


# Lo llama el NPC al interactuar
func start(mission: MissionData, npc: NpcData) -> void:
	if GameState.is_completed(mission.id):
		if not mission.done_dialogue.is_empty():
			await Dialogue.say(npc, mission.done_dialogue)
		return

	if not GameState.requisitos_cumplidos(mission):
		if not mission.locked_dialogue.is_empty():
			await Dialogue.say(npc, mission.locked_dialogue)
		return

	if active != null and active != mission:
		# Una misión a la vez: hay que terminar la actual antes de tomar otra
		var pendiente: Array[String] = [
			"Ya tienes una misión en curso: «%s»." % active.title,
			"Termínala primero y después vuelve conmigo.",
		]
		await Dialogue.say(npc, pendiente)
		return

	# Conversación sin ejercicio (p. ej. el Anciano): se completa al terminar de hablar
	if mission.exercise == null:
		await Dialogue.say(npc, mission.intro_dialogue)
		GameState.complete_mission(mission)
		EventBus.mission_completed.emit(mission)
		await Dialogue.say(npc, mission.success_dialogue)
		return

	if active == mission:
		var lines: Array[String] = mission.reminder_dialogue
		if lines.is_empty():
			lines = mission.intro_dialogue
		await Dialogue.say(npc, lines, _registro_for(mission))
	else:
		await Dialogue.say(npc, mission.intro_dialogue, _registro_for(mission))
		active = mission
		active_npc = npc
		attempts = 0
		EventBus.mission_started.emit(mission)

	# Prueba en diálogo: el ejercicio se abre de inmediato
	if mission.cell_address == "":
		EventBus.exercise_requested.emit(mission)


# Lo llama la casilla de RAM del mapa al interactuar con ella
func open_cell(address: String) -> bool:
	if active == null:
		return false
	if casilla_objetivo() != GameState.norm(address):
		return false
	if is_locked():
		return false
	var paso := _paso_de_cadena(address)
	if paso != null:
		_seguir_placa(paso)
		return true
	EventBus.exercise_requested.emit(active)
	return true


# La casilla que el jugador tiene que abrir ahora: la primera de la cadena que falte,
# y al final la del ejercicio ("" si la prueba es en diálogo)
func casilla_objetivo() -> String:
	if active == null:
		return ""
	for c in active.cadena:
		if not GameState.is_revealed(c.address):
			return GameState.norm(c.address)
	return GameState.norm(active.cell_address)


func _paso_de_cadena(address: String) -> MemoryCellData:
	for c in active.cadena:
		if GameState.norm(c.address) == GameState.norm(address):
			return c
	return null


# Casilla intermedia: no guarda el dato, guarda otra placa. Se anota y se avisa adónde seguir.
func _seguir_placa(c: MemoryCellData) -> void:
	var mision := active
	var misma_que := ""
	for otra in mision.cadena:
		if otra != c and GameState.is_revealed(otra.address) 				and GameState.norm(otra.value) == GameState.norm(c.value):
			misma_que = GameState.norm(otra.address)
	GameState.reveal(c.address, c.value, c.label)
	EventBus.cadena_avanzo.emit(mision)
	var lineas: Array[String] = []
	if misma_que != "":
		lineas.append("`%s` (%s) guarda la placa `%s`… ¡la misma que `%s`!" % [GameState.norm(c.address), c.label, GameState.norm(c.value), misma_que])
	else:
		lineas.append("`%s` (%s) no guarda el dato: guarda otra placa, `%s`." % [GameState.norm(c.address), c.label, GameState.norm(c.value)])
	lineas.append("Anotado en el Registro. Ahora abre la casilla `%s`." % casilla_objetivo())
	await Dialogue.say(SISTEMA, lineas)


# Lo llama la pantalla del ejercicio al confirmar una opción
func answer(option: OptionData) -> void:
	if active == null:
		return
	if option.is_correct:
		GameState.complete_mission(active)      # sube stats y anota el Registro
		EventBus.exercise_passed.emit(active)
	else:
		attempts += 1
		GameState.registrar_fallo(active.id)
		_locked_until_ms = Time.get_ticks_msec() + int(LOCK_SECONDS * 1000.0)
		EventBus.exercise_failed.emit(active, option, attempts)


# Lo llama la pantalla de acierto al cerrarse: lanza el diálogo final
func finish_success() -> void:
	if active == null:
		return
	var mission := active
	var npc := active_npc
	active = null
	active_npc = null
	EventBus.mission_completed.emit(mission)
	await Dialogue.say(npc, mission.success_dialogue, _registro_for(mission))


# La siguiente misión que conviene hacer (null si hay una activa o ya no queda ninguna)
func siguiente_sugerida() -> MissionData:
	if active != null:
		return null
	for path: String in RUTAS.get(GameState.nivel_historia(), []):
		var m := load(path) as MissionData
		if m != null and not GameState.is_completed(m.id) and GameState.requisitos_cumplidos(m):
			return con_repaso(m)
	return null


# Umbral del 70 %: si la misión tiene precision_minima y el nivel no la alcanza, se da el repaso
# de la primera misión fallada (en el orden de la ruta). Si no hace falta, devuelve la misma misión.
func con_repaso(m: MissionData) -> MissionData:
	if m == null or m.precision_minima <= 0.0 or not GameState.requisitos_cumplidos(m):
		return m
	var nivel := int(String(m.id).substr(4, 1))      # "EJ-N2-09" -> 2
	if GameState.precision(nivel) >= m.precision_minima:
		return m
	for path: String in RUTAS.get(nivel, []):
		var original := load(path) as MissionData
		if original != null and GameState.fallida(original.id):
			var repaso := load(path.replace("/ej_", "/rp_")) as MissionData
			if repaso != null:
				return repaso
	return m


func is_locked() -> bool:
	return Time.get_ticks_msec() < _locked_until_ms


func lock_remaining() -> float:
	return maxf(0.0, (_locked_until_ms - Time.get_ticks_msec()) / 1000.0)


# "REGISTRO 0/1" o "REGISTRO 1/1 · OK" ("" si la misión no registra nada)
func _registro_for(mission: MissionData) -> String:
	if mission.reveals.is_empty():
		return ""
	var total := mission.reveals.size()
	var done := 0
	for cell in mission.reveals:
		if GameState.is_revealed(cell.address):
			done += 1
	var suffix := " · OK" if done == total else ""
	return "REGISTRO %d/%d%s" % [done, total, suffix]
