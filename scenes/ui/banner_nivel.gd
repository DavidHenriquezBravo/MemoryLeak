extends CanvasLayer

# Cartel de fin de nivel (mismo estilo que el panel de acierto).
# Uso:  var b = load("res://scenes/ui/banner_nivel.tscn").instantiate()
#       add_child(b)
#       await b.mostrar("¡NIVEL 1 SUPERADO!", "Derrotaste al jefe.", "Detalle opcional")
#       b.queue_free()

signal cerrado

@onready var oscuro: ColorRect = %Oscuro
@onready var panel: Control = %Panel
@onready var titulo: Label = %Titulo
@onready var texto: Label = %Texto
@onready var detalle: Label = %Detalle
@onready var continuar: Label = %Continuar

var _esperando: bool = false


func _ready() -> void:
	panel.modulate.a = 0.0
	oscuro.color.a = 0.0
	continuar.visible = false


func mostrar(t: String, linea: String, extra: String = "") -> void:
	titulo.text = t
	texto.text = linea
	detalle.text = extra
	titulo.visible_ratio = 0.0

	var entrada := create_tween().set_parallel()
	entrada.tween_property(oscuro, "color:a", 0.62, 0.5)
	entrada.tween_property(panel, "modulate:a", 1.0, 0.5)
	entrada.tween_property(panel, "position:y", 0.0, 0.5).from(14.0)
	await entrada.finished

	var escribir := create_tween()
	escribir.tween_property(titulo, "visible_ratio", 1.0, 0.9)
	await escribir.finished

	continuar.visible = true
	var parpadeo := create_tween().set_loops()
	parpadeo.tween_property(continuar, "modulate:a", 0.3, 0.6)
	parpadeo.tween_property(continuar, "modulate:a", 1.0, 0.6)

	_esperando = true
	await cerrado
	parpadeo.kill()

	var salida := create_tween().set_parallel()
	salida.tween_property(panel, "modulate:a", 0.0, 0.3)
	salida.tween_property(oscuro, "color:a", 0.0, 0.3)
	await salida.finished


func _input(event: InputEvent) -> void:
	if _esperando and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_esperando = false
		cerrado.emit()
