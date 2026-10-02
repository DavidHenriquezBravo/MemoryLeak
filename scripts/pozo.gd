extends StaticBody2D

# Pozo de los Baldes (misión de Andrés). Va en el nodo "Pozo" de Stage1.
#
# 1) Orden de dibujo: Godot dibuja los nodos en el orden del árbol de escena, y
#    "Pozo" está debajo de "Player", así que el pozo tapaba al jugador incluso
#    cuando el jugador estaba delante. Aquí el pozo se mueve antes o después del
#    jugador en el árbol según quién esté más abajo en la pantalla.
# 2) Cuando el jugador obtiene la dirección 0x0004, la placa de Andrés se
#    enciende (animación "placa") y después vuelve al bucle.

## Dirección de la placa que se enciende
@export var direccion: String = "0x0004"
## Animación en bucle del pozo
@export var anim_bucle: StringName = &"default"
## Animación de la placa (sin loop)
@export var anim_placa: StringName = &"placa"
## Cuánto más arriba que el borde de abajo del dibujo está la línea del suelo del pozo
@export var margen_base: float = 16.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var jugador: Node2D = null
var alto_sprite := 48.0


func _ready() -> void:
	jugador = get_tree().get_first_node_in_group("player")
	var tex := sprite.sprite_frames.get_frame_texture(anim_bucle, 0)
	if tex:
		alto_sprite = tex.get_height() * sprite.scale.y
	GameState.address_revealed.connect(_on_direccion_revelada)
	sprite.play(anim_bucle)


func _process(_delta: float) -> void:
	if jugador == null or not is_instance_valid(jugador) or jugador.get_parent() != get_parent():
		return
	var linea_base := sprite.global_position.y + alto_sprite / 2.0 - margen_base
	var jugador_delante := jugador.global_position.y > linea_base
	var i_pozo := get_index()
	var i_jugador := jugador.get_index()
	if jugador_delante and i_pozo > i_jugador:
		get_parent().move_child(self, i_jugador)    # el pozo se dibuja antes: el jugador queda encima
	elif not jugador_delante and i_pozo < i_jugador:
		get_parent().move_child(self, i_jugador)    # el pozo se dibuja después: tapa al jugador


func _on_direccion_revelada(address: String) -> void:
	if address != GameState.norm(direccion):
		return
	# esperar a que se cierren la casilla y el diálogo, para que el jugador lo vea
	while ExercisePanel.is_open or Dialogue.is_open:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	sprite.play(anim_placa)
	await sprite.animation_finished
	sprite.play(anim_bucle)
