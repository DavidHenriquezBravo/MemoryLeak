extends Node

# Coordina el flujo: diálogo -> (casilla) -> ejercicio -> acierto/error -> recompensa -> diálogo final.
# No dibuja nada: las pantallas escuchan las señales de EventBus.

const LOCK_SECONDS := 5.0

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

	if mission.requires_mission != &"" and not GameState.is_completed(mission.requires_mission):
		print("Misión bloqueada: requiere ", mission.requires_mission)
		return

	if active != null and active != mission:
		await Dialogue.say(npc, ["Termina primero lo que tienes pendiente."])
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
	if GameState.norm(active.cell_address) != GameState.norm(address):
		return false
	if is_locked():
		return false
	EventBus.exercise_requested.emit(active)
	return true


# Lo llama la pantalla del ejercicio al confirmar una opción
func answer(option: OptionData) -> void:
	if active == null:
		return
	if option.is_correct:
		GameState.complete_mission(active)      # sube stats y anota el Registro
		EventBus.exercise_passed.emit(active)
	else:
		attempts += 1
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
