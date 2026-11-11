extends Node

# Envía las filas del registro a la planilla de Google (ver analitica_google/LEEME.md).
# Lo crea Analitica como hijo; no es un autoload aparte.
#
# Cada fila entra primero a una cola guardada en disco (pendientes_envio.json, junto al CSV) y sale de
# ahí solo cuando Google confirma que la recibió. Sin internet se reintenta sola, cada vez más espaciado,
# y también la próxima vez que se abra el juego. Si una fila llega dos veces, el script de Google la
# ignora por su id_evento.

## URL de la aplicación web de Apps Script (termina en /exec). Vacía = no se envía nada.
const URL := "https://script.google.com/macros/s/AKfycbxP4cFL1tj9_DfCDp6OpA2-Oq-G1r5pNhXXAtqbg-FPoYS2CgsiomjT8MvSAY4fTu-5/exec"
## La CLAVE_JUEGO que muestra configurar() en Apps Script. La CLAVE_LECTURA nunca va aquí.
const CLAVE := "ff9b3f5a6a5342b69c7b60de89fa7c34"

const MAX_POR_ENVIO := 50
const MAX_EN_COLA := 20000                     # si se pasa, se descartan las más antiguas (siguen en el CSV)
const ESPERAS_REINTENTO := [5.0, 15.0, 30.0, 60.0, 120.0, 300.0]
const ARCHIVO_COLA := "pendientes_envio.json"

## Lo fija Analitica antes de agregarlo al árbol
var carpeta := ""

var _ruta_cola := ""
var _cola: Array = []
var _lote: Array = []                          # lo que va en el envío en curso
var _ocupado := false
var _fallos := 0
var _http: HTTPRequest
var _reintento: Timer
var _crypto := Crypto.new()


func activo() -> bool:
	return URL != "" and CLAVE != ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS    # sigue enviando aunque el juego esté en pausa
	if not activo():
		return
	_ruta_cola = carpeta.path_join(ARCHIVO_COLA)
	_http = HTTPRequest.new()
	_http.timeout = 30.0
	_http.request_completed.connect(_on_respuesta)
	add_child(_http)
	_reintento = Timer.new()
	_reintento.one_shot = true
	_reintento.timeout.connect(_enviar)
	add_child(_reintento)
	_cargar_cola()
	_enviar()                                  # lo que quedó pendiente de la última vez


## Una fila del registro (columna -> valor). Se le agrega un id_evento único.
func encolar(fila: Dictionary) -> void:
	if not activo():
		return
	var evento := fila.duplicate()
	evento["id_evento"] = _crypto.generate_random_bytes(8).hex_encode()
	_cola.append(evento)
	if _cola.size() > MAX_EN_COLA:
		_cola = _cola.slice(_cola.size() - MAX_EN_COLA)
	_guardar_cola()
	_enviar()


func pendientes() -> int:
	return _cola.size()


func _enviar() -> void:
	if _ocupado or _cola.is_empty():
		return
	_ocupado = true
	_lote = _cola.slice(0, MAX_POR_ENVIO)
	var cuerpo := JSON.stringify({"clave": CLAVE, "eventos": _lote})
	# Apps Script responde al POST con una redirección; se sigue a mano con un GET (ver _on_respuesta)
	_http.max_redirects = 0
	if _http.request(URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, cuerpo) != OK:
		_fallo("no se pudo iniciar el envío")


func _on_respuesta(resultado: int, codigo: int, encabezados: PackedStringArray, cuerpo: PackedByteArray) -> void:
	# Google ya guardó los datos y redirige a otra dirección donde está la respuesta
	if resultado == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED and codigo in [301, 302, 303, 307, 308]:
		var destino := _encabezado(encabezados, "location")
		if destino == "":
			_fallo("redirección sin destino")
			return
		_http.max_redirects = 8
		if _http.request(destino) != OK:
			_fallo("no se pudo leer la respuesta")
		return
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		_fallo("sin conexión o error del servidor (resultado %d, código %d)" % [resultado, codigo])
		return
	var respuesta = JSON.parse_string(cuerpo.get_string_from_utf8())
	if not (respuesta is Dictionary and respuesta.get("ok", false)):
		_fallo("la planilla rechazó el envío: %s" % cuerpo.get_string_from_utf8().left(200))
		return
	var enviados := {}
	for evento in _lote:
		enviados[evento["id_evento"]] = true
	_cola = _cola.filter(func(ev): return not enviados.has(ev["id_evento"]))
	_guardar_cola()
	_lote = []
	_fallos = 0
	_ocupado = false
	_enviar()                                  # si quedan más, el siguiente lote


func _fallo(motivo: String) -> void:
	if _fallos == 0:
		push_warning("EnvioRegistros: %s. Se reintentará; las filas siguen en %s" % [motivo, _ruta_cola])
	_ocupado = false
	_reintento.start(ESPERAS_REINTENTO[mini(_fallos, ESPERAS_REINTENTO.size() - 1)])
	_fallos += 1


func _encabezado(encabezados: PackedStringArray, nombre: String) -> String:
	for linea in encabezados:
		var i := linea.find(":")
		if i > 0 and linea.left(i).strip_edges().to_lower() == nombre:
			return linea.substr(i + 1).strip_edges()
	return ""


func _cargar_cola() -> void:
	if not FileAccess.file_exists(_ruta_cola):
		return
	var datos = JSON.parse_string(FileAccess.get_file_as_string(_ruta_cola))
	if datos is Array:
		_cola = datos.filter(func(ev): return ev is Dictionary and ev.has("id_evento"))


# Se escribe a un archivo temporal y se renombra, así un cierre a mitad de escritura no corrompe la cola
func _guardar_cola() -> void:
	var temporal := _ruta_cola + ".tmp"
	var archivo := FileAccess.open(temporal, FileAccess.WRITE)
	if archivo == null:
		return
	archivo.store_string(JSON.stringify(_cola))
	archivo.close()
	DirAccess.rename_absolute(temporal, _ruta_cola)
