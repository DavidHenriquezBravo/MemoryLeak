extends Node

# Final del stage: si el jefe ya fue derrotado, la cámara se abre para mostrar toda la aldea,
# desaparece la corrupción (charcos, partículas, árboles...) y termina el nivel.
# Se añade como nodo hijo de Stage1 (Nodo "Node" + este script).
#
# Qué desaparece: los nodos de "nombres_por_defecto", los de la lista "nodos_corrupcion"
# y TODO nodo que esté en el grupo "corrupcion" (Nodo > Grupos).
#
# Animación: si el nodo (o un AnimatedSprite2D dentro) tiene una animación "desaparecer"
# SIN loop, se reproduce. Si no, el nodo se desvanece con un fundido.

@export_group("Corrupción")
@export var nodos_corrupcion: Array[NodePath] = []
@export var nombres_por_defecto: PackedStringArray = ["charco_memoria", "Memoria caida", "Particulas", "Arbol1", "Arbol2", "Arbol3", "Arbol4"]
@export var grupo_corrupcion: StringName = &"corrupcion"
@export var anim_desaparecer: StringName = &"desaparecer"
@export var duracion_respaldo: float = 2.5
## El jefe del mapa: ya fue derrotado, así que se quita de inmediato.
@export var nombre_jefe: String = "Boss Stage1"

@export_group("Cámara")
@export var camara_panoramica: bool = true
## Zona de la aldea a mostrar. Si queda en cero se calcula sola con la capa "Fondo".
@export var rect_aldea: Rect2 = Rect2()
@export var capa_fondo: String = "Fondo"
## 1.0 = la aldea ocupa justo toda la pantalla; menos de 1 deja un borde.
@export_range(0.5, 1.0, 0.01) var margen_camara: float = 0.92
@export var duracion_camara: float = 2.0

@export_group("Secuencia")
@export var pausa_inicial: float = 1.0
@export var mostrar_cartel_final: bool = true
## Escena a la que se pasa al terminar (ej. el menú o el nivel 2). Vacío = se queda en el mapa.
@export_file("*.tscn") var escena_siguiente: String = ""

signal _listos

var _pendientes: int = 0
var _cam: Camera2D = null
var _cam_pos: Vector2
var _cam_zoom: Vector2
var _cam_limites: Array = []


func _ready() -> void:
	if not GameState.boss_defeated:
		return
	var jefe := get_parent().find_child(nombre_jefe, true, false)
	if jefe:
		jefe.queue_free()
	if GameState.final_visto:
		for n in _resolver():
			n.queue_free()          # el final ya se vio: el mapa vuelve limpio
		return
	_reproducir.call_deferred()


func _reproducir() -> void:
	GameState.final_visto = true
	GameState.en_cinematica = true
	var nodos := _resolver()

	await get_tree().create_timer(pausa_inicial).timeout

	if camara_panoramica:
		await _camara_abrir()
		await get_tree().create_timer(0.5).timeout

	_pendientes = nodos.size()
	for n in nodos:
		_desaparecer(n)
	if _pendientes > 0:
		await _listos
	await get_tree().create_timer(1.0).timeout

	if mostrar_cartel_final:
		var banner = load("res://scenes/ui/banner_nivel.tscn").instantiate()
		add_child(banner)
		await banner.mostrar("¡LA CORRUPCIÓN DESAPARECIÓ!", "El pueblo vuelve a respirar. La memoria está en orden.", "FIN DEL NIVEL 1")
		banner.queue_free()

	if escena_siguiente != "":
		await _fundido_a_negro(0.8)
		GameState.en_cinematica = false
		get_tree().change_scene_to_file(escena_siguiente)
	else:
		if camara_panoramica:
			await _camara_volver()
		GameState.en_cinematica = false   # sin escena siguiente: el jugador recupera el control


# ---------------------------------------------------------------- desaparición
func _desaparecer(nodo: Node) -> void:
	var sprite := _buscar_anim(nodo)
	if sprite != null:
		sprite.play(anim_desaparecer)
		await sprite.animation_finished
	elif nodo is CanvasItem:
		var t := create_tween()
		t.tween_property(nodo, "modulate:a", 0.0, duracion_respaldo)
		await t.finished
	if is_instance_valid(nodo):
		nodo.queue_free()
	_pendientes -= 1
	if _pendientes <= 0:
		_listos.emit()


# Primer AnimatedSprite2D (el propio nodo o un hijo) que tenga la animación de desaparecer
func _buscar_anim(nodo: Node) -> AnimatedSprite2D:
	if nodo is AnimatedSprite2D and nodo.sprite_frames and nodo.sprite_frames.has_animation(anim_desaparecer):
		return nodo
	for hijo in nodo.get_children():
		var s := _buscar_anim(hijo)
		if s != null:
			return s
	return null


# Une nombres + lista + grupo, sin repetidos y sin nodos que cuelguen de otro ya incluido
func _resolver() -> Array[Node]:
	var todos: Array[Node] = []
	for nombre in nombres_por_defecto:
		var n := get_parent().find_child(nombre, true, false)
		if n and not todos.has(n):
			todos.append(n)
	for ruta in nodos_corrupcion:
		var n := get_node_or_null(ruta)
		if n and not todos.has(n):
			todos.append(n)
	for n in get_tree().get_nodes_in_group(grupo_corrupcion):
		if not todos.has(n):
			todos.append(n)

	var lista: Array[Node] = []
	for n in todos:
		var es_hijo := false
		for otro in todos:
			if otro != n and otro.is_ancestor_of(n):
				es_hijo = true
				break
		if not es_hijo:
			lista.append(n)
	return lista


# ---------------------------------------------------------------- cámara
func _camara_abrir() -> void:
	_cam = get_viewport().get_camera_2d()
	if _cam == null:
		return
	_cam_pos = _cam.position
	_cam_zoom = _cam.zoom
	_cam_limites = [_cam.limit_left, _cam.limit_top, _cam.limit_right, _cam.limit_bottom]
	# sin límites mientras dura el plano general, si no la cámara se queda "pegada" al borde
	_cam.limit_left = -10000000
	_cam.limit_top = -10000000
	_cam.limit_right = 10000000
	_cam.limit_bottom = 10000000

	var r := _rect_de_la_aldea()
	var pantalla := get_viewport().get_visible_rect().size
	var z := minf(pantalla.x / r.size.x, pantalla.y / r.size.y) * margen_camara
	z = minf(z, _cam_zoom.x)        # nunca más cerca que antes
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "global_position", r.get_center(), duracion_camara)
	t.tween_property(_cam, "zoom", Vector2(z, z), duracion_camara)
	await t.finished


func _camara_volver() -> void:
	if _cam == null:
		return
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_cam, "position", _cam_pos, duracion_camara)
	t.tween_property(_cam, "zoom", _cam_zoom, duracion_camara)
	await t.finished
	_cam.limit_left = _cam_limites[0]
	_cam.limit_top = _cam_limites[1]
	_cam.limit_right = _cam_limites[2]
	_cam.limit_bottom = _cam_limites[3]


func _rect_de_la_aldea() -> Rect2:
	if rect_aldea.size != Vector2.ZERO:
		return rect_aldea
	var capa := get_parent().find_child(capa_fondo, true, false)
	if capa is TileMapLayer and capa.tile_set != null:
		var usado: Rect2i = capa.get_used_rect()
		if usado.size != Vector2i.ZERO:
			var ts := Vector2(capa.tile_set.tile_size)
			var origen: Vector2 = capa.to_global(Vector2(usado.position) * ts)
			return Rect2(origen, Vector2(usado.size) * ts)
	return Rect2(-317, -320, 700, 560)   # respaldo aproximado


func _fundido_a_negro(segundos: float) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 50
	var velo := ColorRect.new()
	velo.color = Color(0, 0, 0, 0)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(velo)
	add_child(capa)
	var t := create_tween()
	t.tween_property(velo, "color:a", 1.0, segundos)
	await t.finished
