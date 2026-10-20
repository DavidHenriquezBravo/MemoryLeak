extends Node
## Si GameState.punto_entrada coincide con el nombre de un Marker2D hermano/hijo,
## el jugador aparece ahí en vez de en su posición fija del .tscn.

func _ready() -> void:
	if GameState.punto_entrada == &"":
		return
	var marcador := get_parent().find_child(String(GameState.punto_entrada), true, false)
	var jugador := get_tree().get_first_node_in_group("player")
	if marcador is Node2D and jugador is Node2D:
		jugador.global_position = marcador.global_position
	GameState.punto_entrada = &""
