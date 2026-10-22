extends Node
 
signal stats_changed
signal address_revealed(address: String)
signal memoria_recuperada(id: StringName)

# Stats de quien no ha hecho ninguna misión. Las 8 misiones del nivel 1 suman
# +40 vida, +15 daño, +20 % armadura y +10 % suerte (= 100 / 25 / 20 % / 15 %).
const BASE_MAX_HP := 60
const BASE_DAMAGE := 1000
const BASE_ARMOR := 0.0
const BASE_LUCK := 0.05
const MISIONES_NIVEL_1 := 8
const MISION_ANCIANO := &"EJ-N1-09"     # "Listo para el jefe": no cuenta entre las 8
# Por nivel: cuántas misiones de NPC tiene y cuál es la del Anciano (no cuenta entre ellas).
# Las 6 del nivel 2 suman +40 vida, +15 daño, +15 % armadura y +10 % suerte (= 140 / 40 / 35 % / 25 %).
const MISIONES_POR_NIVEL := {1: 8, 2: 6}
const MISIONES_ANCIANO := {1: &"EJ-N1-09", 2: &"EJ-N2-09"}
const NOMBRES_JEFE := {1: "The Memory Leak", 2: "The Dangling Pointer"}
const ARMOR_CAP := 0.75
const LUCK_CAP := 0.60

var punto_entrada: StringName = &""
var hp: int = BASE_MAX_HP
var bonus: Dictionary = {"max_hp": 0, "damage": 0, "armor": 0.0, "luck": 0.0}
var completed: Array[StringName] = []
var revealed: Dictionary = {}     # "0x0020" -> {"value": "0", "label": "cerradura de Juan"}
 
# Progreso del final del nivel 1
var boss_defeated: bool = false     # el jefe ya murió
var final_visto: bool = false       # ya se vio la animación de la corrupción desapareciendo
var en_cinematica: bool = false     # congela al jugador durante animaciones
var aviso_puerta_visto: bool = false  # ya se mostró la advertencia de la puerta (solo avisa una vez)
var preguntas_jefe_resueltas: Array[String] = []   # ids del banco del jefe ya respondidos bien (no se repiten)
var boss2_defeated: bool = false    # The Dangling Pointer ya cayó
var fallos: Dictionary = {}         # "EJ-N2-01" -> respuestas equivocadas antes de acertar (para el 70 %)
var memorias: Array[StringName] = []   # memorias perdidas recogidas ("M1".."M6"), en el orden en que se encontraron

# NV del jugador: cada misión de NPC y cada jefe derrotado suben un nivel (sin barra de experiencia).
# Los repasos ("RP-...") y las misiones del Anciano no suben.
var nivel_jugador: int:
	get:
		var n := 1
		for id in completed:
			if String(id).begins_with("EJ-") and not id in MISIONES_ANCIANO.values():
				n += 1
		if boss_defeated:
			n += 1
		if boss2_defeated:
			n += 1
		return n

var max_hp: int:
	get:
		return BASE_MAX_HP + int(bonus["max_hp"])
 
var damage: int:
	get:
		return BASE_DAMAGE + int(bonus["damage"])
 
var armor: float:
	get:
		return minf(BASE_ARMOR + float(bonus["armor"]), ARMOR_CAP)
 
var luck: float:
	get:
		return minf(BASE_LUCK + float(bonus["luck"]), LUCK_CAP)
 
 
func norm(address: String) -> String:
	var s := address.strip_edges()
	if s.to_lower().begins_with("0x"):
		return "0x" + s.substr(2).to_upper()
	return s
 
 
func is_completed(mission_id: StringName) -> bool:
	return mission_id in completed


# En qué nivel de la historia va el jugador: el jefe 1 abre el nivel 2, el jefe 2 abre el 3
func nivel_historia() -> int:
	var n := 1
	if boss2_defeated:
		n = 3
	elif boss_defeated:
		n = 2
	return maxi(n, _nivel_de_escena())


# El nivel al que pertenece la escena actual (para cuando se entra directo a un stage, sin pasar por los jefes)
func _nivel_de_escena() -> int:
	var esc := get_tree().current_scene if is_inside_tree() else null
	var ruta := esc.scene_file_path if esc else ""
	for clave in ["stage_3", "camino_nucleo"]:
		if ruta.contains(clave):
			return 3
	for clave in ["stage_2", "biblioteca", "arena_jefe_2", "bajada_jefe_2"]:
		if ruta.contains(clave):
			return 2
	return 1


# Cuántas misiones de NPC de ese nivel lleva el jugador (el jefe se endurece si son pocas)
func misiones_completadas(nivel: int = 1) -> int:
	var n := 0
	for id in completed:
		if _es_del_nivel(id, nivel) and id != MISIONES_ANCIANO.get(nivel):
			n += 1
	return mini(n, MISIONES_POR_NIVEL.get(nivel, 0))


# El Anciano ya sabe que estás preparado para pelear contra el jefe de ese nivel
func listo_para_jefe(nivel: int = 1) -> bool:
	return is_completed(MISIONES_ANCIANO.get(nivel, &""))


func registrar_fallo(mission_id: StringName) -> void:
	fallos[mission_id] = int(fallos.get(mission_id, 0)) + 1


# Fracción de misiones del nivel resueltas al primer intento (1.0 si todavía no hay ninguna).
# Una misión fallada vuelve a contar como acierto si se hizo su repaso (PDF: "reponer con
# ejercicios equivalentes del mismo subobjetivo fallado").
func precision(nivel: int) -> float:
	var hechas := 0
	var limpias := 0
	for id in completed:
		if not _es_del_nivel(id, nivel) or id == MISIONES_ANCIANO.get(nivel):
			continue
		hechas += 1
		if not fallida(id):
			limpias += 1
	return 1.0 if hechas == 0 else float(limpias) / hechas


# Se equivocó al menos una vez y todavía no hizo el repaso ("EJ-N2-03" -> "RP-N2-03")
func fallida(mission_id: StringName) -> bool:
	return int(fallos.get(mission_id, 0)) > 0 			and not is_completed(StringName(String(mission_id).replace("EJ-", "RP-")))


# "EJ-N2-05" es del nivel 2
func _es_del_nivel(id: StringName, nivel: int) -> bool:
	return String(id).begins_with("EJ-N%d-" % nivel)


# ¿Ya hizo lo que pide esta misión? (requires_mission y requires_all)
func requisitos_cumplidos(m: MissionData) -> bool:
	if m.requires_mission != &"" and not is_completed(m.requires_mission):
		return false
	for id in m.requires_all:
		if not is_completed(id):
			return false
	return true
 
 
func is_revealed(address: String) -> bool:
	return revealed.has(norm(address))
 
 
func revealed_value(address: String) -> String:
	return str(revealed[norm(address)]["value"])
 
 
func reveal(address: String, value: String, label: String) -> void:
	var key := norm(address)
	if revealed.has(key):
		return
	revealed[key] = {"value": value, "label": label}
	address_revealed.emit(key)


# Memoria perdida recogida (false si ya estaba)
func recoger_memoria(id: StringName) -> bool:
	if id in memorias:
		return false
	memorias.append(id)
	memoria_recuperada.emit(id)
	return true

 
# Única puerta para dar recompensa y registrar direcciones
func complete_mission(mission: MissionData) -> void:
	if mission.id in completed:
		return                                  # nunca se premia dos veces
	completed.append(mission.id)
	if mission.exercise and mission.exercise.reward:
		_apply_reward(mission.exercise.reward)
	for cell in mission.reveals:
		reveal(cell.address, cell.value, cell.label)
	stats_changed.emit()
 
 
func _apply_reward(r: RewardData) -> void:
	match r.stat:
		RewardData.Stat.DAMAGE:
			bonus["damage"] = int(bonus["damage"]) + int(r.amount)
		RewardData.Stat.ARMOR:
			bonus["armor"] = float(bonus["armor"]) + r.amount
		RewardData.Stat.LUCK:
			bonus["luck"] = float(bonus["luck"]) + r.amount
		RewardData.Stat.MAX_HP:
			bonus["max_hp"] = int(bonus["max_hp"]) + int(r.amount)
			hp += int(r.amount)
 
