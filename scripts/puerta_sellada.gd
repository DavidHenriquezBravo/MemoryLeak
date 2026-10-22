extends StaticBody2D

## La puerta sellada del costado de la arena del jefe 2. Cerrada: el sello rosa y las cadenas no dejan pasar.
## Al abrirse (cuando el jefe ya fue vencido) el sello se purifica, caen las cadenas, el portón sube y el «Paso al
## camino» (Area2D hijo, con puerta_escena.gd) lleva al Camino al Núcleo.

## Para probar el recorrido sin pelear: la puerta arranca abierta.
@export var abierta_al_inicio: bool = false
## Si esta variable de GameState es true, la puerta arranca abierta. La primera vez que se vuelve de la pelea
## ganada, arena_jefe_2.gd la cierra con cerrar_al_instante() y la abre con abrir() en la cinemática.
@export var variable_abierta: StringName = &"boss2_defeated"

@onready var anim: AnimatedSprite2D = $Puerta
@onready var bloqueo: CollisionShape2D = $CollisionShape2D
@onready var paso: Area2D = $"Paso al camino"


func _ready() -> void:
	var vencido: bool = variable_abierta in GameState and bool(GameState.get(variable_abierta))
	if abierta_al_inicio or vencido:
		_quedar_abierta()
	else:
		anim.stop()
		anim.frame = 0
		paso.monitoring = false


func abrir() -> void:
	anim.play("abrir")
	await anim.animation_finished
	_quedar_abierta()


func cerrar_al_instante() -> void:
	anim.animation = &"abrir"
	anim.stop()
	anim.frame = 0
	bloqueo.set_deferred("disabled", false)
	paso.set_deferred("monitoring", false)


func _quedar_abierta() -> void:
	anim.animation = &"abrir"
	anim.stop()                                       # stop() vuelve al cuadro 0: el último se pone después
	anim.frame = anim.sprite_frames.get_frame_count(&"abrir") - 1
	bloqueo.set_deferred("disabled", true)
	paso.set_deferred("monitoring", true)
