extends Area2D

## Puerta a otra escena (entrar a la biblioteca, salir al Distrito...). Al entrar el jugador al área,
## pasa a «escena» con fundido y aparece en el Marker2D llamado «punto_llegada» de esa escena
## (lo resuelve punto_llegada.gd, igual que la cueva y la bajada).

@export_file("*.tscn") var escena: String = ""
## Nombre del Marker2D donde aparece el jugador en la otra escena
@export var punto_llegada: StringName = &""

var _usada := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _usada or escena == "" or not body.is_in_group("player"):
		return
	_usada = true
	GameState.punto_entrada = punto_llegada
	Transicion.ir_a(escena)
