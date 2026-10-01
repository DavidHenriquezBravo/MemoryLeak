class_name MissionData
extends Resource

@export var id: StringName
@export var oa_code: String = ""                 # "OA2.1"
@export var title: String = ""                   # "La Daga que forjó Juan"
@export var objective: String = ""               # "→ Abre la casilla `0x0020`"
@export var requires_mission: StringName         # id de otra misión que debe estar completa antes
@export var cell_address: String = ""            # "" = prueba en diálogo (sin casilla en el mapa)

@export_group("Diálogos")
@export var intro_dialogue: Array[String] = []
@export var reminder_dialogue: Array[String] = []   # si vuelve a hablar con la misión ya aceptada
@export var success_dialogue: Array[String] = []
@export var done_dialogue: Array[String] = []       # si vuelve a hablar con la misión ya terminada

@export_group("Ejercicio y resultado")
@export var exercise: ExerciseData
@export var reveals: Array[MemoryCellData] = []     # lo que se anota en el Registro al resolver
