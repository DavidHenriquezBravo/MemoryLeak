extends Node2D

@export var npc: NpcData   # arrastra andres.tres aquí en el inspector

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_T and not Dialogue.is_open:
		Dialogue.say(npc, ["Hola, soy una prueba.", "Mira {addr:0x0004}."], "REGISTRO 0/1")
