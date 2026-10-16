extends StaticBody2D

## Escena de la pelea (elígela en el Inspector de la Puerta)
@export_file("*.tscn") var escena_pelea: String = "pelea"

const SISTEMA := preload("res://data/npc/sistema.tres")

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
		# Con el jefe derrotado la puerta solo deja pasar: el siguiente stage está en la cueva
		if GameState.boss_defeated:
			return
		# Sin estar preparado, la primera vez solo avisa (la segunda ya te deja pasar)
		if not GameState.boss_defeated and not GameState.listo_para_jefe() and not GameState.aviso_puerta_visto:
			GameState.aviso_puerta_visto = true
			_avisar_sin_preparacion()
			return
		entrando = true
		body.set_physics_process(false)  # el jugador se queda quieto
		Transicion.ir_a_pelea(escena_pelea)


func _avisar_sin_preparacion() -> void:
	var n := GameState.misiones_completadas()
	var total := GameState.MISIONES_NIVEL_1
	var lineas: Array[String] = []
	if n >= total:
		lineas = [
			"* ADVERTENCIA: completaste todas las misiones, pero el Anciano aún no sabe que estás listo.",
			"* Habla con él antes de enfrentar a The Memory Leak. Si cruzas de nuevo, nadie te detendrá.",
		]
	elif n == 0:
		lineas = [
			"* ADVERTENCIA: integridad del jugador insuficiente.",
			"* Misiones completadas: 0/%d. Sin ellas, un solo error ante The Memory Leak puede ser fatal." % total,
			"* Habla con los aldeanos para fortalecerte. Si cruzas de nuevo, nadie te detendrá.",
		]
	else:
		lineas = [
			"* ADVERTENCIA: integridad del jugador incompleta.",
			"* Misiones completadas: %d/%d. Cada misión que falta te debilita frente a The Memory Leak." % [n, total],
			"* Termina las misiones y habla con el Anciano. Si cruzas de nuevo, nadie te detendrá.",
		]
	await Dialogue.say(SISTEMA, lineas, "MISIONES %d/%d" % [n, total])
