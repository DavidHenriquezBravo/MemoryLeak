extends Node2D

## Escena «Camino al Núcleo» (del jefe 2 al Stage 3): se camina de lado, en silueta, hacia el volcán.
## Pone a los personajes a contraluz, baja la velocidad para que sea un paseo y al llegar al final del camino
## muestra el título del nivel y pasa al Stage 3.

const SILUETA := preload("res://shaders/silueta.gdshader")

## La escena del Stage 3 y el punto donde aparece el jugador
@export_file("*.tscn") var escena_stage_3: String = "res://scenes/levels/stage_3_referencia.tscn"
@export var punto_llegada: StringName = &"DesdeArena"
## Velocidad del jugador en este camino (en el resto del juego es 150)
@export var velocidad_jugador: float = 55.0

var _terminado := false


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SILUETA
	for n in get_tree().get_nodes_in_group("silueta"):
		n.material = mat
	var jugador := get_tree().get_first_node_in_group("player")
	if jugador:
		jugador.get_node("AnimatedSprite2D").material = mat
		jugador.set("speed", velocidad_jugador)
	var anciano := get_tree().get_first_node_in_group("anciano_guia")
	if anciano:
		anciano.get_node("AnimatedSprite2D").material = mat
		anciano.set("velocidad", velocidad_jugador + 4.0)
	$"Fin del camino".body_entered.connect(_al_final)


func _al_final(body: Node2D) -> void:
	if _terminado or not body.is_in_group("player"):
		return
	_terminado = true
	GameState.en_cinematica = true
	# fundido a negro y el título del nivel, como en la entrada del Stage 2
	var capa := CanvasLayer.new()
	capa.layer = 60
	add_child(capa)
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0)
	velo.size = Vector2(1280, 720)
	capa.add_child(velo)
	var titulo := _texto(capa, "NIVEL 3", 64, Color(0.94, 0.66, 0.25), 280)
	var nombre := _texto(capa, "EL NÚCLEO FRAGMENTADO", 52, Color(1.0, 0.48, 0.18), 360)
	var tw := create_tween()
	tw.tween_property(velo, "color:a", 1.0, 1.2)
	tw.tween_property(titulo, "modulate:a", 1.0, 0.8)
	tw.parallel().tween_property(nombre, "modulate:a", 1.0, 0.8)
	tw.tween_interval(2.5)
	tw.tween_property(titulo, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(nombre, "modulate:a", 0.0, 0.6)
	await tw.finished
	GameState.en_cinematica = false
	GameState.punto_entrada = punto_llegada
	Transicion.ir_a(escena_stage_3)


func _texto(capa: CanvasLayer, t: String, tam: int, col: Color, y: float) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", load("res://Fuentes/upheavtt.ttf"))
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(1280, 80)
	l.position = Vector2(0, y)
	l.modulate.a = 0.0
	capa.add_child(l)
	return l
