class_name ExerciseData
extends Resource

@export var title: String = "PRUEBA"
@export_multiline var code: String
@export_multiline var question: String
@export var memory_cells: Array[MemoryCellData] = []
@export var options: Array[OptionData] = []

@export_group("Pistas y ejemplo resuelto")
@export_multiline var conceptual_hint: String    # PISTA 2 (segundo error)
@export_multiline var example_code: String       # 3er error: ejemplo con otra variable
@export var example_cells: Array[MemoryCellData] = []
@export_multiline var example_text: String
@export_multiline var example_followup: String   # "Mismo concepto, otra variable. Ahora vuelve a..."

@export_group("Acierto")
@export var success_title: String = "¡CORRECTO!"
@export_multiline var success_text: String
@export_multiline var concept_text: String       # lo que va junto a "CONCEPTO"
@export var reward: RewardData
