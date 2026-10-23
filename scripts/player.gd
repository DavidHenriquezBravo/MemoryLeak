extends CharacterBody2D

@export var speed: float = 150.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Trajes por nivel (GameState.traje()): 0 el de la escena (venda), 1 chaqueta, 2 túnica
const TRAJES := [null, preload("res://scenes/actors/trajes/traje_1.tres"), preload("res://scenes/actors/trajes/traje_2.tres")]

# Guarda la última dirección en la que miró el personaje
var last_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	var n := GameState.traje()
	if TRAJES[n]:
		animated_sprite.sprite_frames = TRAJES[n]
	if n > GameState.traje_visto:
		GameState.traje_visto = n
		_estrenar_traje.call_deferred()

# La primera vez que aparece con un traje nuevo: destella y suelta chispas cyan
func _estrenar_traje() -> void:
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	var t := create_tween()
	for i in 3:
		t.tween_property(animated_sprite, "modulate", Color(2.6, 2.6, 2.6), 0.12)
		t.tween_property(animated_sprite, "modulate", Color.WHITE, 0.2)
	var chispas := CPUParticles2D.new()
	chispas.one_shot = true
	chispas.amount = 26
	chispas.lifetime = 1.0
	chispas.explosiveness = 0.85
	chispas.spread = 180.0
	chispas.gravity = Vector2(0, -30)
	chispas.initial_velocity_min = 25.0
	chispas.initial_velocity_max = 55.0
	chispas.scale_amount_min = 1.0
	chispas.scale_amount_max = 2.0
	chispas.color = Color("3de4dd")
	chispas.z_index = 5
	add_child(chispas)
	chispas.emitting = true
	get_tree().create_timer(1.6).timeout.connect(chispas.queue_free)

func _physics_process(_delta: float) -> void:
	# Quieto mientras hay un diálogo o una casilla de RAM abierta
	if Dialogue.is_open or ExercisePanel.is_open or GameState.en_cinematica:
		velocity = Vector2.ZERO
		update_animation(Vector2.ZERO)
		return
	# 1. Obtener dirección del movimiento
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# 2. Aplicar velocidad
	velocity = input_direction * speed
	move_and_slide()
	
	# 3. Actualizar la animación
	update_animation(input_direction)

func update_animation(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		# Guardamos la última dirección en la que caminó
		last_direction = direction
		
		# Priorizar la animación según el eje de movimiento principal
		if abs(direction.x) > abs(direction.y):
			if direction.x > 0:
				animated_sprite.play("walk_right")
			else:
				animated_sprite.play("walk_left")
		else:
			if direction.y > 0:
				animated_sprite.play("walk_down")
			else:
				animated_sprite.play("walk_up")
	else:
		# Si está quieto, reproducir la animación idle según hacia dónde miraba
		if abs(last_direction.x) > abs(last_direction.y):
			if last_direction.x > 0:
				animated_sprite.play("idle_right")
			else:
				animated_sprite.play("idle_left")
		else:
			if last_direction.y > 0:
				animated_sprite.play("idle_down")
			else:
				animated_sprite.play("idle_up")
