class_name NPC
extends CharacterBody2D

# Un solo script para Andrés, Juan, Rivera, Vicente y el Anciano.
# Lo que cambia entre ellos se rellena en el inspector de cada escena.

@export var npc_data: NpcData                     # nombre + retrato (el .tres del personaje)
@export var lines: Array[String] = ["..."]        # frases del diálogo
@export var registro_text: String = ""            # ej. "REGISTRO 0/1" ("" = sin pestaña)
@export var default_anim: StringName = &"idle_down"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var player_near: Node2D = null


func _ready() -> void:
	_play(default_anim)


func _unhandled_input(event: InputEvent) -> void:
	if player_near == null or Dialogue.is_open:
		return
	if event.is_action_pressed("interact"):
		# Importante: marcar el evento como usado, si no el cuadro de diálogo
		# recibe esa misma pulsación de E y salta la primera frase.
		get_viewport().set_input_as_handled()
		_face(player_near.global_position)
		await Dialogue.say(npc_data, lines, registro_text)
		_play(default_anim)


func _face(target: Vector2) -> void:
	var d := target - global_position
	var target_anim: StringName
	if absf(d.x) > absf(d.y):
		target_anim = &"idle_left" if d.x < 0.0 else &"idle_right"
	else:
		target_anim = &"idle_down"
	_play(target_anim)


# Solo reproduce si la animación existe (Juan no tiene idle_right, por ejemplo)
func _play(anim_name: StringName) -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation(anim_name):
		anim.play(anim_name)


# Estas dos funciones ya están conectadas en tus escenas (señales del Area2D).
func _on_area_2d_body_entered(body: Node2D) -> void:
	print("entró: ", body.name, " | en grupo player: ", body.is_in_group("player"))
	if body.is_in_group("player"):
		player_near = body


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body == player_near:
		player_near = null
