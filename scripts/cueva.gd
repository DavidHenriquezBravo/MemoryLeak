extends Area2D

## La cueva del macizo: con el jefe derrotado y la corrupción limpia, la roca de la entrada
## se abre sola. Entonces el jugador se acerca a la boca y pulsa la acción (E o Z) para
## entrar y pasar al siguiente stage.

## A dónde lleva la cueva
@export_file("*.tscn") var escena_stage_2: String = "res://scenes/levels/bajada.tscn"
@onready var aviso: Label = $Aviso
## La roca que tapa la boca (AnimatedSprite2D con las animaciones cerrada / abrir / reposo)
@onready var tapon: AnimatedSprite2D = get_node_or_null("../Entrada cueva/AnimatedSprite2D")
## Colisión que bloquea la boca mientras la roca está cerrada
@onready var bloqueo: CollisionShape2D = get_node_or_null("../Entrada cueva/Tapon")

var jugador: Node2D = null
var entrando := false
var abierta := true       # sin roca en la escena, la cueva queda siempre abierta
var abriendo := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	aviso.visible = false
	if tapon == null:
		return
	# Si el final ya se vio, la cueva vuelve abierta; si no, cerrada y corrupta hasta la limpieza
	if GameState.boss_defeated and GameState.final_visto:
		_fijar_abierta()
	else:
		_fijar_cerrada()


func _process(_delta: float) -> void:
	aviso.visible = _puede_entrar()
	# Cuando termina la cinemática de limpieza, la roca se abre
	if tapon != null and not abierta and not abriendo and GameState.boss_defeated \
			and GameState.final_visto and not GameState.en_cinematica:
		_abrir_con_animacion()


func _unhandled_input(event: InputEvent) -> void:
	if not _puede_entrar() or not event.is_action_pressed("interact"):
		return
	# Marcar el evento como usado, igual que los NPC, para que nadie más reaccione a esta E
	get_viewport().set_input_as_handled()
	_entrar()


func _puede_entrar() -> bool:
	return jugador != null and not entrando and abierta \
			and GameState.boss_defeated and not GameState.en_cinematica \
			and not Dialogue.is_open and not ExercisePanel.is_open


func _fijar_cerrada() -> void:
	abierta = false
	tapon.play("cerrada")
	if bloqueo:
		bloqueo.set_deferred("disabled", false)


func _fijar_abierta() -> void:
	abierta = true
	tapon.play("reposo")
	if bloqueo:
		bloqueo.set_deferred("disabled", true)


func _abrir_con_animacion() -> void:
	abriendo = true
	tapon.play("abrir")
	await tapon.animation_finished
	abriendo = false
	_fijar_abierta()


func _entrar() -> void:
	entrando = true
	jugador.set_physics_process(false)
	GameState.punto_entrada = &"DesdeStage1"
	Transicion.ir_a(escena_stage_2)


func _es_jugador(body: Node2D) -> bool:
	return body.is_in_group("jugador") or body.name == "Player"


func _on_body_entered(body: Node2D) -> void:
	if _es_jugador(body):
		jugador = body


func _on_body_exited(body: Node2D) -> void:
	if body == jugador:
		jugador = null
