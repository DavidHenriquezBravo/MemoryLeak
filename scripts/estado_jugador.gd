extends Control
 
# Panel de estado del jugador (arriba a la izquierda).
# No guarda nada propio: lee GameState y se refresca cuando llega stats_changed
# (recompensas de misiones, daño recibido en la pelea, etc.).
 
@onready var barra_vida: TextureProgressBar = %BarraVida
@onready var label_vida: Label = %LabelVida
@onready var label_suerte: Label = %LabelSuerte
@onready var label_dano: Label = %LabelDano
@onready var label_armadura: Label = %LabelArmadura
 
var _previo: Dictionary = {}     # último valor mostrado, para detectar subidas
var _tween_barra: Tween
 
 
func _ready() -> void:
	GameState.stats_changed.connect(refrescar)
	refrescar(false)             # primera vez: sin animación
 
 
func refrescar(animar: bool = true) -> void:
	# Vida: barra (se desliza) + número
	barra_vida.max_value = GameState.max_hp
	if animar:
		if _tween_barra:
			_tween_barra.kill()
		_tween_barra = create_tween()
		_tween_barra.tween_property(barra_vida, "value", float(GameState.hp), 0.25)
	else:
		barra_vida.value = GameState.hp
 
	_mostrar(label_vida, "vida", str(GameState.hp), GameState.hp, animar)
	_mostrar(label_suerte, "suerte", "%d%%" % roundi(GameState.luck * 100.0), GameState.luck, animar)
	_mostrar(label_dano, "dano", str(GameState.damage), GameState.damage, animar)
	_mostrar(label_armadura, "armadura", "%d%%" % roundi(GameState.armor * 100.0), GameState.armor, animar)
 
 
# Escribe el texto y, si el valor subió, destella el número en amarillo
func _mostrar(label: Label, clave: String, texto: String, valor: float, animar: bool) -> void:
	label.text = texto
	if animar and _previo.has(clave) and valor > float(_previo[clave]):
		_destello(label)
	_previo[clave] = valor
 
 
func _destello(label: Label) -> void:
	label.modulate = Color(1.0, 0.85, 0.3)
	create_tween().tween_property(label, "modulate", Color.WHITE, 0.8)
 
