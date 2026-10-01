extends Node2D

# Script TEMPORAL para probar la lógica de misiones sin interfaz.
# Adjúntalo al nodo raíz de stage_1 (quita antes debug_dialogo.gd).
# En el inspector: Npc = juan.tres | Missions = [ej_n1_02.tres, ej_n1_05.tres]
#
# Teclas:  Y = misión 1 (daga)   U = misión 2 (cerradura)   C = pisar la casilla 0x0020
#          1 / 2 / 3 = responder A / B / C     F = cerrar el panel de acierto
#          P = ver stats       (E avanza los diálogos)

@export var npc: NpcData
@export var missions: Array[MissionData]


func _ready() -> void:
	EventBus.mission_started.connect(func(m): print("MISIÓN INICIADA: ", m.title))
	EventBus.exercise_requested.connect(func(m): print("EJERCICIO PEDIDO: ", m.exercise.question))
	EventBus.exercise_failed.connect(func(_m, o, n): print("FALLO #", n, " | ", o.wrong_feedback, " | PISTA: ", o.hint))
	EventBus.exercise_passed.connect(func(m): print("ACIERTO: ", m.exercise.success_title, " ", m.exercise.reward.label()))
	EventBus.mission_completed.connect(func(m): print("MISIÓN COMPLETA: ", m.title))
	GameState.stats_changed.connect(_print_stats)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed) or Dialogue.is_open:
		return
	match event.keycode:
		KEY_Y:
			MissionManager.start(missions[0], npc)
		KEY_U:
			MissionManager.start(missions[1], npc)
		KEY_C:
			print("casilla abierta: ", MissionManager.open_cell(missions[1].cell_address))
		KEY_1, KEY_2, KEY_3:
			_answer(event.keycode - KEY_1)
		KEY_F:
			MissionManager.finish_success()
		KEY_P:
			_print_stats()


func _answer(i: int) -> void:
	var m := MissionManager.active
	if m == null or i >= m.exercise.options.size():
		print("No hay ejercicio activo")
		return
	MissionManager.answer(m.exercise.options[i])


func _print_stats() -> void:
	print("STATS -> daño ", GameState.damage, " | armadura ", GameState.armor, " | suerte ", GameState.luck)
