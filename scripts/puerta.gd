extends StaticBody2D

## Escena de la pelea (elígela en el Inspector de la Puerta)
@export_file("*.tscn") var escena_pelea: String = "pelea"
## A dónde lleva la puerta cuando el jefe ya fue derrotado
@export_file("*.tscn") var escena_stage_2: String = "res://scenes/levels/stage_2.tscn"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var pared: CollisionShape2D = $CollisionShape2D
@onready var zona: Area2D = $ZonaInteraccion
@onready var entrada: Area2D = $Entrada

var jugador_cerca := false
var abierta := false
var animando := false
var entrando := false

func _ready() -> void:
	sprite.animation = "abrir"
	sprite.frame = 0
	zona.body_entered.connect(_on_body_entered)
	zona.body_exited.connect(_on_body_exited)
	entrada.body_entered.connect(_on_entrada_body_entered)

func _unhandled_input(event: InputEvent) -> void:
	if jugador_cerca and not animando and event.is_action_pressed("interact"):
		if abierta:
			cerrar()
		else:
			abrir()

func abrir() -> void:
	animando = true
	sprite.play("abrir")
	await sprite.animation_finished
	pared.set_deferred("disabled", true)
	abierta = true
	animando = false

func cerrar() -> void:
	animando = true
	pared.set_deferred("disabled", false)
	sprite.play_backwards("abrir")
	await sprite.animation_finished
	abierta = false
	animando = false

func _es_jugador(body: Node2D) -> bool:
	return body.is_in_group("jugador") or body.name == "Player"

func _on_body_entered(body: Node2D) -> void:
	if _es_jugador(body):
		jugador_cerca = true

func _on_body_exited(body: Node2D) -> void:
	if _es_jugador(body):
		jugador_cerca = false

func _on_entrada_body_entered(body: Node2D) -> void:
	if abierta and not entrando and _es_jugador(body):
		entrando = true
		body.set_physics_process(false)  # el jugador se queda quieto
		if GameState.boss_defeated:
			# El jefe ya cayó: la puerta ahora lleva al siguiente stage
			Transicion.ir_a(escena_stage_2)
		else:
			Transicion.ir_a_pelea(escena_pelea)
