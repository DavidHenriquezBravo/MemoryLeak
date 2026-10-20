extends Area2D

## Final de la bajada: cuando el jugador entra a la boca de mina del balcón, pasa al Stage 2.
## Llega por el pasillo de rieles del oeste del Distrito (ver "posicion_llegada" en stage_2).

@export_file("*.tscn") var escena_siguiente: String = "res://scenes/levels/stage_2.tscn"

var usado := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if usado or not (body.is_in_group("player") or body.name == "Player"):
		return
	usado = true
	Transicion.ir_a(escena_siguiente)
