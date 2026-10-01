extends Node

signal stats_changed
signal address_revealed(address: String)

const BASE_MAX_HP := 100
const BASE_DAMAGE := 25
const BASE_ARMOR := 0.20
const BASE_LUCK := 0.15
const ARMOR_CAP := 0.75
const LUCK_CAP := 0.60

var hp: int = BASE_MAX_HP
var bonus: Dictionary = {"max_hp": 0, "damage": 0, "armor": 0.0, "luck": 0.0}
var completed: Array[StringName] = []
var revealed: Dictionary = {}     # "0x0020" -> {"value": "0", "label": "cerradura de Juan"}

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
