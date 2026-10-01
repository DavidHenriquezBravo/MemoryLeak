class_name OptionData
extends Resource

# Una opción A/B/C del ejercicio

@export_multiline var text: String
@export var is_correct: bool = false

@export_group("Si es incorrecta")
@export_multiline var wrong_feedback: String     # "Intentaste meter el agua en la ranura..."
@export_multiline var concept_on_error: String   # "Un puntero no guarda números..."
@export_multiline var hint: String               # PISTA 1 (la que sale tras el 1er error con esta opción)
