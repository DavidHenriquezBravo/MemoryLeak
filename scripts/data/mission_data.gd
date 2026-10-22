class_name MissionData
extends Resource

@export var id: StringName
@export var oa_code: String = ""                 # "OA2.1"
@export var title: String = ""                   # "La Daga que forjó Juan"
@export var objective: String = ""               # "→ Abre la casilla `0x0020`"
@export var requires_mission: StringName         # id de otra misión que debe estar completa antes
@export var requires_all: Array[StringName] = [] # ids de TODAS las misiones que deben estar completas antes
@export var giver_name: String = ""              # quién la da ("Juan"): lo usa la sugerencia del HUD
@export var cell_address: String = ""            # "" = prueba en diálogo (sin casilla en el mapa)
# Nivel 2 (indirección): casillas que hay que abrir ANTES de cell_address, en orden.
# Cada una guarda en `value` la dirección de la siguiente; al abrirla se anota en el Registro.
@export var cadena: Array[MemoryCellData] = []
# Umbral del nivel (la misión del Anciano): si la precisión del nivel está por debajo,
# en vez de esta misión se da el repaso de una misión fallada. 0 = sin umbral.
@export var precision_minima: float = 0.0
# Misión de repaso (id "RP-N2-01"): id de la misión original que recupera ("EJ-N2-01")
@export var variante_de: StringName

@export_group("Diálogos")
@export var intro_dialogue: Array[String] = []
@export var reminder_dialogue: Array[String] = []   # si vuelve a hablar con la misión ya aceptada
@export var success_dialogue: Array[String] = []
@export var done_dialogue: Array[String] = []       # si vuelve a hablar con la misión ya terminada
@export var locked_dialogue: Array[String] = []     # si le habla antes de cumplir los requisitos

@export_group("Ejercicio y resultado")
@export var exercise: ExerciseData
@export var reveals: Array[MemoryCellData] = []     # lo que se anota en el Registro al resolver
