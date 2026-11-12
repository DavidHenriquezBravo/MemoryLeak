extends Node

# Partidas guardadas (autoload "Guardado"): un archivo por save en user://saves.
# Se guarda desde el Registro (R o Tab, pestaña GUARDAR) y se carga o borra desde "Jugar" en el menú.
# Borrar un save solo elimina su archivo: el registro de analíticas (Analitica) es otro archivo y no se toca.

const SLOTS := 3
const CARPETA := "user://saves"

var slot_actual := 0      # el save en que se está jugando (0 = ninguno, p. ej. con F6 en el editor)


# Autoguardado en el save en que se está jugando, para no perder la partida si el juego se cierra
# o se queda pegado: al terminar cada misión, al llegar a otra escena del mapa y al cerrar el juego
# (manteniendo Esc o con la X de la ventana).
func _ready() -> void:
	EventBus.mission_completed.connect(func(_m: MissionData): autoguardar.call_deferred())
	get_tree().scene_changed.connect(_on_escena_cambiada)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		autoguardar()


func _on_escena_cambiada() -> void:
	# Dos cuadros: primero se coloca al jugador (punto_llegada o el save recién cargado)
	await get_tree().process_frame
	await get_tree().process_frame
	autoguardar()


## Guarda en slot_actual solo donde también se podría guardar a mano: en el mapa, con el jugador
## presente (no en peleas, menús, cinemáticas ni el inicio). Devuelve true si guardó.
func autoguardar() -> bool:
	if slot_actual <= 0 or not _se_puede_autoguardar():
		return false
	return guardar(slot_actual)


func _se_puede_autoguardar() -> bool:
	# En plena animación no se guarda: queda el último autoguardado, que es de justo antes
	# (p. ej. al terminar la misión del Anciano, antes de la bajada al pozo).
	if GameState.en_cinematica:
		return false
	var escena := get_tree().current_scene
	if escena == null or get_tree().get_first_node_in_group("player") == null:
		return false
	for clave: String in MissionHud.ESCENAS_SIN_HUD:
		if escena.scene_file_path.contains(clave):
			return false
	return true


# {} si está vacío, {"danado": true} si no se pudo leer, o {"fecha", "nivel", "nv"}
func resumen(slot: int) -> Dictionary:
	if not FileAccess.file_exists(_ruta(slot)):
		return {}
	var archivo := ConfigFile.new()
	if archivo.load(_ruta(slot)) != OK or not archivo.has_section_key("partida", "fecha"):
		return {"danado": true}
	return {
		"fecha": archivo.get_value("partida", "fecha"),
		"nivel": archivo.get_value("partida", "nivel", 1),
		"nv": archivo.get_value("partida", "nv", 1),
	}


# "Nivel 2 - NV 9 - 08/11 14:32"
func descripcion(datos: Dictionary) -> String:
	if datos.is_empty():
		return "Vacío"
	if datos.get("danado", false):
		return "Dañado"
	var f: String = datos["fecha"]        # "2026-11-08 14:32:05"
	return "Nivel %d - NV %d - %s/%s %s" % [datos["nivel"], datos["nv"], f.substr(8, 2), f.substr(5, 2), f.substr(11, 5)]


func nueva_partida(slot: int) -> void:
	slot_actual = slot
	GameState.importar_partida({})
	MissionManager.importar_partida({})
	Analitica.importar_partida({})
	Analitica.evento_partida("partida_nueva", slot)


func guardar(slot: int) -> bool:
	var escena := get_tree().current_scene
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if escena == null or jugador == null:
		return false
	var nivel := GameState.nivel_historia()
	var archivo := ConfigFile.new()
	archivo.set_value("partida", "fecha", Time.get_datetime_string_from_system(false, true))
	archivo.set_value("partida", "nivel", nivel)
	archivo.set_value("partida", "nv", GameState.nivel_jugador)
	archivo.set_value("partida", "escena", escena.scene_file_path)
	archivo.set_value("partida", "posicion", jugador.global_position)
	archivo.set_value("datos", "estado", GameState.exportar_partida())
	archivo.set_value("datos", "mision", MissionManager.exportar_partida())
	archivo.set_value("datos", "analitica", Analitica.exportar_partida())
	DirAccess.make_dir_recursive_absolute(CARPETA)
	if archivo.save(_ruta(slot)) != OK:
		return false
	slot_actual = slot
	Analitica.evento_partida("partida_guardada", slot, nivel)
	return true


func cargar(slot: int) -> bool:
	var archivo := ConfigFile.new()
	if archivo.load(_ruta(slot)) != OK:
		return false
	var escena: String = archivo.get_value("partida", "escena", "")
	if not ResourceLoader.exists(escena):
		return false
	slot_actual = slot
	GameState.importar_partida(archivo.get_value("datos", "estado", {}))
	MissionManager.importar_partida(archivo.get_value("datos", "mision", {}))
	Analitica.importar_partida(archivo.get_value("datos", "analitica", {}))
	Analitica.evento_partida("partida_cargada", slot, archivo.get_value("partida", "nivel", 1))
	var posicion: Vector2 = archivo.get_value("partida", "posicion", Vector2.ZERO)
	get_tree().scene_changed.connect(_colocar_jugador.bind(posicion), CONNECT_ONE_SHOT)
	Transicion.ir_a(escena)
	return true


func borrar(slot: int) -> void:
	DirAccess.remove_absolute(_ruta(slot))
	if slot_actual == slot:
		slot_actual = 0
	Analitica.evento_partida("partida_borrada", slot)


func _colocar_jugador(posicion: Vector2) -> void:
	var jugador := get_tree().get_first_node_in_group("player") as Node2D
	if jugador == null:
		return
	jugador.global_position = posicion
	var camara := jugador.get_node_or_null("Camera2D") as Camera2D
	if camara != null:
		camara.reset_smoothing()
	var anciano := get_tree().get_first_node_in_group("anciano_guia")
	if anciano != null and anciano.siguiendo:
		anciano.global_position = posicion + Vector2(-20, 0)
		anciano.seguir()


func _ruta(slot: int) -> String:
	return CARPETA.path_join("save_%d.cfg" % slot)
