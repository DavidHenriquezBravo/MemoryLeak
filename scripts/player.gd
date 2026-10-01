extends CharacterBody2D

@export var speed: float = 150.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

# Guarda la última dirección en la que miró el personaje
var last_direction: Vector2 = Vector2.DOWN

func _physics_process(_delta: float) -> void:
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
