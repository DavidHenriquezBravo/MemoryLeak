extends Node

# Registro local de la partida para analíticas (autoload "Analitica").
# Guarda un CSV con una fila por evento: apertura y cierre del juego, cada respuesta
# (correcta o no, con su tiempo) y lo que tardó cada nivel. El correo identifica al jugador.
#
# Separador ";", UTF-8 con BOM y tiempos en milisegundos enteros: así Excel en español
# abre las columnas bien. En Python: pandas.read_csv(ruta, sep=";", encoding="utf-8-sig").
#
# Sin correo no se escribe nada: las pruebas del editor que entran directo a un stage no ensucian el log.

const CARPETA := "registros"
const ARCHIVO := "registro_partidas.csv"
const SEPARADOR := ";"
const COLUMNAS: PackedStringArray = [
	"fecha_hora", "sesion", "correo", "evento", "nivel", "origen", "id_pregunta", "intento",
	"respuesta", "correcta", "tiempo_respuesta_ms", "duracion_ms", "detalle",
]
const SIN_RESPUESTA := "(sin responder)"
# Entrar por primera vez a una de estas escenas empieza el nivel; vencer a su jefe lo termina
const ESCENAS_NIVEL := {"stage_1": 1, "stage_2": 2, "stage_3": 3}

var correo := ""

var _ruta := ""
var _sesion := ""
var _fecha_apertura := ""
var _apertura_ms := 0
var _inicio_nivel_ms := {}      # nivel -> ticks al empezarlo
var _niveles_terminados := {}
var _intentos := {}             # id de la pregunta o "JEFE-n" -> veces respondida o peleada en esta partida
var _pelea_inicio_ms := -1      # -1 = no hay una pelea en curso
var _ultimo_nivel := 0
var _formato_correo := RegEx.create_from_string("^[a-z0-9][a-z0-9._%+-]*@[a-z0-9-]+(\\.[a-z0-9-]+)*\\.[a-z]{2,}$")
var _marca_addr := RegEx.create_from_string("\\{addr:([^}]*)\\}")


func _ready() -> void:
	_apertura_ms = Time.get_ticks_msec()
	_fecha_apertura = _ahora()
	_sesion = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "-")
	_ruta = _elegir_carpeta().path_join(ARCHIVO)
	get_tree().scene_changed.connect(_on_escena_cambiada)


# Corre tanto al cerrar la ventana como con el botón Salir
func _exit_tree() -> void:
	_escribir("cierre_juego", {
		"nivel": _ultimo_nivel if _ultimo_nivel > 0 else "",
		"duracion_ms": Time.get_ticks_msec() - _apertura_ms,
	})


# Lo llama la pantalla inicial. Devuelve false si el correo no es válido.
func identificar(texto: String) -> bool:
	var limpio := texto.strip_edges().to_lower()
	if _formato_correo.search(limpio) == null:
		return false
	correo = limpio
	_escribir("inicio_juego", {"fecha_hora": _fecha_apertura})
	return true


func evento_partida(evento: String, slot: int, nivel := 0) -> void:
	_escribir(evento, {"nivel": nivel if nivel > 0 else "", "detalle": "save %d" % slot})


# Lo que va dentro de un save: el tiempo jugado de cada nivel sigue contando entre sesiones
func exportar_partida() -> Dictionary:
	var transcurrido := {}
	for nivel: int in _inicio_nivel_ms:
		transcurrido[nivel] = Time.get_ticks_msec() - int(_inicio_nivel_ms[nivel])
	return {
		"transcurrido": transcurrido,
		"terminados": _niveles_terminados.duplicate(),
		"intentos": _intentos.duplicate(),
		"ultimo_nivel": _ultimo_nivel,
	}


# Con un diccionario vacío empieza de cero (partida nueva). No toca el archivo del log.
func importar_partida(datos: Dictionary) -> void:
	_inicio_nivel_ms.clear()
	var transcurrido: Dictionary = datos.get("transcurrido", {})
	for nivel: int in transcurrido:
		_inicio_nivel_ms[nivel] = Time.get_ticks_msec() - int(transcurrido[nivel])
	_niveles_terminados = datos.get("terminados", {}).duplicate()
	_intentos = datos.get("intentos", {}).duplicate()
	_ultimo_nivel = int(datos.get("ultimo_nivel", 0))


func respuesta_mision(mision: MissionData, opcion: OptionData, tiempo_ms: int) -> void:
	var nivel := int(String(mision.id).substr(4, 1))      # "EJ-N2-09" -> 2
	_escribir_respuesta("mision", nivel, mision.id, opcion.text, opcion.is_correct, tiempo_ms, "")


func respuesta_jefe(nivel: int, id: String, texto: String, correcta: bool, tiempo_ms: int, accion: String) -> void:
	_escribir_respuesta("jefe", nivel, id, texto, correcta, tiempo_ms, accion)


# Cada entrada a la pelea es un intento, también al reintentar desde el game over
func inicio_pelea(nivel: int) -> void:
	var clave := "JEFE-%d" % nivel
	_intentos[clave] = int(_intentos.get(clave, 0)) + 1
	_pelea_inicio_ms = Time.get_ticks_msec()
	_escribir("jefe_intento", {
		"nivel": nivel,
		"origen": "jefe",
		"intento": _intentos[clave],
		"detalle": GameState.NOMBRES_JEFE.get(nivel, ""),
	})


# resultado: "victoria" o "derrota"
func fin_pelea(nivel: int, resultado: String) -> void:
	if _pelea_inicio_ms < 0:
		return
	_escribir("jefe_fin", {
		"nivel": nivel,
		"origen": "jefe",
		"intento": _intentos.get("JEFE-%d" % nivel, ""),
		"duracion_ms": Time.get_ticks_msec() - _pelea_inicio_ms,
		"detalle": resultado,
	})
	_pelea_inicio_ms = -1


func fin_nivel(nivel: int) -> void:
	if _niveles_terminados.has(nivel):
		return
	_niveles_terminados[nivel] = true
	var datos := {"nivel": nivel}
	if _inicio_nivel_ms.has(nivel):
		datos["duracion_ms"] = Time.get_ticks_msec() - int(_inicio_nivel_ms[nivel])
	_escribir("nivel_fin", datos)


func _escribir_respuesta(origen: String, nivel: int, id: String, texto: String, correcta: bool, tiempo_ms: int, detalle: String) -> void:
	_intentos[id] = int(_intentos.get(id, 0)) + 1
	_escribir("respuesta", {
		"nivel": nivel,
		"origen": origen,
		"id_pregunta": id,
		"intento": _intentos[id],
		"respuesta": _texto_plano(texto),
		"correcta": 1 if correcta else 0,
		"tiempo_respuesta_ms": tiempo_ms,
		"detalle": detalle,
	})


func _on_escena_cambiada() -> void:
	var escena := get_tree().current_scene
	if escena == null:
		return
	for clave: String in ESCENAS_NIVEL:
		if escena.scene_file_path.contains(clave):
			_empezar_nivel(ESCENAS_NIVEL[clave])
			return


func _empezar_nivel(nivel: int) -> void:
	if _inicio_nivel_ms.has(nivel):
		return                                  # volver al mapa no reinicia el cronómetro
	_inicio_nivel_ms[nivel] = Time.get_ticks_msec()
	_ultimo_nivel = nivel
	_escribir("nivel_inicio", {"nivel": nivel})


func _escribir(evento: String, datos: Dictionary) -> void:
	if correo == "":
		return
	var valores := PackedStringArray()
	for columna in COLUMNAS:
		valores.append(str(datos.get(columna, "")))
	valores[COLUMNAS.find("fecha_hora")] = str(datos.get("fecha_hora", _ahora()))
	valores[COLUMNAS.find("sesion")] = _sesion
	valores[COLUMNAS.find("correo")] = correo
	valores[COLUMNAS.find("evento")] = evento
	var archivo := _abrir_archivo()
	if archivo != null:
		archivo.store_csv_line(valores, SEPARADOR)
		archivo.close()                         # cerrar en cada fila: si el juego se cae, no se pierde nada


func _abrir_archivo() -> FileAccess:
	var existia := FileAccess.file_exists(_ruta)
	var archivo := FileAccess.open(_ruta, FileAccess.READ_WRITE if existia else FileAccess.WRITE)
	if archivo == null:
		push_warning("Analitica: no se pudo abrir %s (error %d)" % [_ruta, FileAccess.get_open_error()])
		return null
	archivo.seek_end()
	if not existia:
		archivo.store_buffer(PackedByteArray([0xEF, 0xBB, 0xBF]))
		archivo.store_csv_line(COLUMNAS, SEPARADOR)
	return archivo


# En el juego exportado, carpeta "registros" junto al .exe para que sea fácil recoger el archivo.
# Desde el editor, o si esa carpeta no se puede escribir (Archivos de programa), en user://.
func _elegir_carpeta() -> String:
	if not OS.has_feature("editor"):
		var junto_al_exe := OS.get_executable_path().get_base_dir().path_join(CARPETA)
		if DirAccess.make_dir_recursive_absolute(junto_al_exe) == OK:
			return junto_al_exe
	var en_usuario := "user://".path_join(CARPETA)
	DirAccess.make_dir_recursive_absolute(en_usuario)
	return en_usuario


func _ahora() -> String:
	return Time.get_datetime_string_from_system(false, true)


# Quita las marcas que usa AddrFormatter (`código` y {addr:0x0020})
func _texto_plano(texto: String) -> String:
	return _marca_addr.sub(texto, "$1", true).replace("`", "").replace("\n", " ").strip_edges()
