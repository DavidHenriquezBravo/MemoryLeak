extends Node
 
signal stats_changed
signal address_revealed(address: String)
 
# Stats de quien no ha hecho ninguna misión. Las 8 misiones del nivel 1 suman
# +40 vida, +15 daño, +20 % armadura y +10 % suerte (= 100 / 25 / 20 % / 15 %).
const BASE_MAX_HP := 60
const BASE_DAMAGE := 10
const BASE_ARMOR := 0.0
const BASE_LUCK := 0.05
const MISIONES_NIVEL_1 := 8
const MISION_ANCIANO := &"EJ-N1-09"     # "Listo para el jefe": no cuenta entre las 8
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


# Cuántas de las 8 misiones del nivel 1 lleva el jugador (el jefe se endurece si son pocas)
func misiones_completadas() -> int:
	var n := 0
	for id in completed:
		if id != MISION_ANCIANO:
			n += 1
	return mini(n, MISIONES_NIVEL_1)


# El Anciano ya sabe que estás preparado para pelear
func listo_para_jefe() -> bool:
	return is_completed(MISION_ANCIANO)


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
 
