/**
 * MemoryLeak · registro de partidas en Google Sheets
 *
 * El juego envía cada fila del registro (respuestas, fin de pelea, fin de nivel) a esta aplicación web.
 * Se guardan en dos hojas:
 *   - Jugadores: una fila por persona (identificada por su correo) con un ID único y su resumen.
 *   - Detalle:   una fila por evento, con el ID del jugador. Aquí está cada respuesta, si fue correcta y su tiempo.
 *
 * Instalación: ver LEEME.md en esta misma carpeta.
 *   1. Pegar este archivo en Extensiones > Apps Script de la planilla.
 *   2. Ejecutar configurar() una vez: crea las hojas y muestra las dos claves en el registro de ejecución.
 *   3. Implementar > Nueva implementación > Aplicación web (Ejecutar como: yo, Acceso: cualquier usuario).
 *
 * Claves:
 *   - CLAVE_JUEGO:   va dentro del juego y solo permite AGREGAR filas.
 *   - CLAVE_LECTURA: va solo en el Excel y permite LEER los datos (con correos). No la pongas en el juego.
 */

const HOJA_JUGADORES = 'Jugadores';
const HOJA_DETALLE = 'Detalle';
const NIVELES = [1, 2, 3];

const COLUMNAS_DETALLE = [
  'id_evento', 'id_jugador', 'correo', 'fecha_hora', 'sesion', 'evento', 'nivel', 'origen', 'id_pregunta',
  'intento', 'respuesta', 'correcta', 'tiempo_respuesta_ms', 'duracion_ms', 'detalle',
];
// Columnas que se guardan como número (el resto como texto, tal como llega)
const NUMERICAS_DETALLE = ['nivel', 'intento', 'correcta', 'tiempo_respuesta_ms', 'duracion_ms'];

const COLUMNAS_JUGADORES = [
  'id_jugador', 'correo', 'primera_vez', 'ultima_vez', 'sesiones',
  'preguntas_respondidas', 'correctas', 'errores', 'porcentaje_acierto', 'tiempo_promedio_respuesta_s',
].concat(
  ...NIVELES.map((n) => [`jefe${n}_intentos`, `jefe${n}_derrotas`, `jefe${n}_vencido`]),
  NIVELES.map((n) => `nivel${n}_duracion_min`),
  ['juego_terminado'],
);

const MAX_EVENTOS_POR_ENVIO = 500;


// ------------------------------------------------------------------ instalación

/** Ejecutar una vez desde el editor. Se puede repetir: no borra datos ni cambia claves ya creadas. */
function configurar() {
  const libro = SpreadsheetApp.getActiveSpreadsheet();
  hoja_(libro, HOJA_JUGADORES, COLUMNAS_JUGADORES);
  hoja_(libro, HOJA_DETALLE, COLUMNAS_DETALLE);
  // Quita la hoja vacía que trae una planilla nueva ("Hoja 1")
  for (const h of libro.getSheets()) {
    if (![HOJA_JUGADORES, HOJA_DETALLE].includes(h.getName()) && h.getLastRow() === 0) {
      libro.deleteSheet(h);
    }
  }
  const props = PropertiesService.getScriptProperties();
  for (const nombre of ['CLAVE_JUEGO', 'CLAVE_LECTURA']) {
    if (!props.getProperty(nombre)) {
      props.setProperty(nombre, Utilities.getUuid().replace(/-/g, ''));
    }
  }
  verClaves();
}

/** Muestra las claves en el registro de ejecución. */
function verClaves() {
  const props = PropertiesService.getScriptProperties();
  console.log('CLAVE_JUEGO (va en el juego):     ' + props.getProperty('CLAVE_JUEGO'));
  console.log('CLAVE_LECTURA (va solo en Excel): ' + props.getProperty('CLAVE_LECTURA'));
}


// ------------------------------------------------------------------ el juego escribe

/**
 * Cuerpo esperado (JSON):
 *   { "clave": "...", "eventos": [ { "id_evento": "...", "correo": "...", "fecha_hora": "...", ... }, ... ] }
 * Responde { ok, recibidos, nuevos }. Un id_evento repetido se ignora, así el juego puede reenviar sin duplicar.
 */
function doPost(e) {
  let datos;
  try {
    datos = JSON.parse(e.postData.contents);
  } catch (err) {
    return json_({ ok: false, error: 'el cuerpo no es JSON' });
  }
  if (!claveValida_(datos.clave, 'CLAVE_JUEGO')) {
    return json_({ ok: false, error: 'clave incorrecta' });
  }
  const eventos = Array.isArray(datos.eventos) ? datos.eventos.slice(0, MAX_EVENTOS_POR_ENVIO) : [];

  const candado = LockService.getScriptLock();
  candado.waitLock(30000);                 // dos jugadores a la vez no se pisan las filas
  try {
    const nuevos = guardarEventos_(eventos);
    return json_({ ok: true, recibidos: eventos.length, nuevos: nuevos });
  } finally {
    candado.releaseLock();
  }
}

function guardarEventos_(eventos) {
  const libro = SpreadsheetApp.getActiveSpreadsheet();
  const hojaDetalle = hoja_(libro, HOJA_DETALLE, COLUMNAS_DETALLE);
  const hojaJugadores = hoja_(libro, HOJA_JUGADORES, COLUMNAS_JUGADORES);

  const detalle = leer_(hojaDetalle, COLUMNAS_DETALLE);
  const yaGuardados = new Set(detalle.map((ev) => String(ev.id_evento)));
  const jugadores = leer_(hojaJugadores, COLUMNAS_JUGADORES);
  const porCorreo = new Map();
  jugadores.forEach((j, i) => porCorreo.set(String(j.correo).toLowerCase(), { id: j.id_jugador, fila: i + 2 }));
  let siguiente = jugadores.reduce((max, j) => Math.max(max, Number(String(j.id_jugador).slice(1)) || 0), 0) + 1;

  const nuevos = [];
  const afectados = new Set();
  for (const original of eventos) {
    const id = texto_(original && original.id_evento);
    const correo = texto_(original && original.correo).toLowerCase();
    if (!id || !correo || yaGuardados.has(id)) continue;
    yaGuardados.add(id);
    let jugador = porCorreo.get(correo);
    if (!jugador) {
      jugador = { id: 'J' + String(siguiente++).padStart(4, '0'), fila: 0 };
      porCorreo.set(correo, jugador);
    }
    const ev = {};
    for (const col of COLUMNAS_DETALLE) {
      ev[col] = NUMERICAS_DETALLE.includes(col) ? numero_(original[col]) : texto_(original[col]);
    }
    ev.id_evento = id;
    ev.id_jugador = jugador.id;
    ev.correo = correo;
    nuevos.push(ev);
    afectados.add(correo);
  }
  if (nuevos.length === 0) return 0;

  hojaDetalle.getRange(hojaDetalle.getLastRow() + 1, 1, nuevos.length, COLUMNAS_DETALLE.length)
    .setValues(nuevos.map((ev) => COLUMNAS_DETALLE.map((col) => celda_(ev[col]))));

  // Recalcula el resumen de cada jugador que recibió eventos, desde todo su detalle
  const todos = detalle.concat(nuevos);
  for (const correo of afectados) {
    const jugador = porCorreo.get(correo);
    const suyos = todos.filter((ev) => String(ev.correo).toLowerCase() === correo);
    const fila = COLUMNAS_JUGADORES.map((col) => celda_(resumen_(jugador.id, correo, suyos)[col]));
    if (!jugador.fila) {
      jugador.fila = hojaJugadores.getLastRow() + 1;
    }
    hojaJugadores.getRange(jugador.fila, 1, 1, COLUMNAS_JUGADORES.length).setValues([fila]);
  }
  return nuevos.length;
}

function resumen_(id, correo, eventos) {
  const fechas = eventos.map((ev) => String(ev.fecha_hora)).filter(Boolean).sort();
  const respuestas = eventos.filter((ev) => ev.evento === 'respuesta');
  const correctas = respuestas.filter((ev) => Number(ev.correcta) === 1).length;
  const tiempos = respuestas.map((ev) => ev.tiempo_respuesta_ms).filter((t) => t !== '' && !isNaN(Number(t)));
  const r = {
    id_jugador: id,
    correo: correo,
    primera_vez: fechas[0] || '',
    ultima_vez: fechas[fechas.length - 1] || '',
    sesiones: new Set(eventos.map((ev) => String(ev.sesion))).size,
    preguntas_respondidas: respuestas.length,
    correctas: correctas,
    errores: respuestas.length - correctas,
    porcentaje_acierto: respuestas.length ? redondear_(100 * correctas / respuestas.length, 1) : '',
    tiempo_promedio_respuesta_s: tiempos.length
      ? redondear_(tiempos.reduce((a, t) => a + Number(t), 0) / tiempos.length / 1000, 1) : '',
  };
  for (const n of NIVELES) {
    const peleas = eventos.filter((ev) => ev.evento === 'jefe_fin' && Number(ev.nivel) === n);
    const vencido = peleas.some((ev) => ev.detalle === 'victoria');
    r[`jefe${n}_intentos`] = peleas.length;
    r[`jefe${n}_derrotas`] = peleas.filter((ev) => ev.detalle === 'derrota').length;
    r[`jefe${n}_vencido`] = vencido ? 'sí' : 'no';
    // Si pasó el nivel más de una vez (partida nueva), cuenta la primera
    const fin = eventos
      .filter((ev) => ev.evento === 'nivel_fin' && Number(ev.nivel) === n && ev.duracion_ms !== '')
      .sort((a, b) => String(a.fecha_hora).localeCompare(String(b.fecha_hora)))[0];
    r[`nivel${n}_duracion_min`] = fin ? redondear_(Number(fin.duracion_ms) / 60000, 1) : '';
  }
  const ultimo = NIVELES[NIVELES.length - 1];
  r.juego_terminado = r[`jefe${ultimo}_vencido`] === 'sí' ||
    eventos.some((ev) => ev.evento === 'nivel_fin' && Number(ev.nivel) === ultimo) ? 'sí' : 'no';
  return r;
}


// ------------------------------------------------------------------ Excel lee

/**
 * GET ?hoja=jugadores|detalle&clave=CLAVE_LECTURA
 * Responde { columnas: [...], filas: [[...], ...] }, que Power Query convierte en tabla.
 */
function doGet(e) {
  const p = (e && e.parameter) || {};
  if (!claveValida_(p.clave, 'CLAVE_LECTURA')) {
    return json_({ ok: false, error: 'clave incorrecta' });
  }
  const nombre = String(p.hoja || 'jugadores').toLowerCase() === 'detalle' ? HOJA_DETALLE : HOJA_JUGADORES;
  const columnas = nombre === HOJA_DETALLE ? COLUMNAS_DETALLE : COLUMNAS_JUGADORES;
  const hoja = hoja_(SpreadsheetApp.getActiveSpreadsheet(), nombre, columnas);
  const filas = leer_(hoja, columnas).map((obj) => columnas.map((col) => salida_(obj[col])));
  return json_({ ok: true, hoja: nombre, columnas: columnas, filas: filas });
}


// ------------------------------------------------------------------ ayudas

function claveValida_(recibida, propiedad) {
  const esperada = PropertiesService.getScriptProperties().getProperty(propiedad);
  return Boolean(esperada) && String(recibida || '') === esperada;
}

/** Devuelve la hoja; si no existe la crea con sus encabezados. */
function hoja_(libro, nombre, columnas) {
  let hoja = libro.getSheetByName(nombre);
  if (!hoja) {
    hoja = libro.insertSheet(nombre);
  }
  if (hoja.getLastRow() === 0) {
    hoja.getRange(1, 1, 1, columnas.length).setValues([columnas]).setFontWeight('bold');
    hoja.setFrozenRows(1);
  }
  return hoja;
}

/** Filas de la hoja (sin encabezado) como objetos {columna: valor}. */
function leer_(hoja, columnas) {
  const n = hoja.getLastRow() - 1;
  if (n <= 0) return [];
  return hoja.getRange(2, 1, n, columnas.length).getValues().map((fila) => {
    const obj = {};
    columnas.forEach((col, i) => { obj[col] = fila[i]; });
    return obj;
  });
}

function texto_(v) {
  return v === undefined || v === null ? '' : String(v).trim();
}

function numero_(v) {
  if (v === undefined || v === null || String(v).trim() === '') return '';
  const n = Number(v);
  return isNaN(n) ? '' : n;
}

function redondear_(n, decimales) {
  const f = Math.pow(10, decimales);
  return Math.round(n * f) / f;
}

/**
 * Lo que se escribe en una celda. Los textos van con apóstrofo para que Sheets no los convierta:
 * así una respuesta como "= NULL" no se vuelve fórmula y "2026-11-10 12:00:00" queda tal cual.
 */
function celda_(v) {
  return typeof v === 'string' && v !== '' ? "'" + v : v;
}

/** Valor para el JSON de lectura (por si alguien escribió una fecha a mano en la hoja). */
function salida_(v) {
  if (v instanceof Date) {
    return Utilities.formatDate(v, Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm:ss');
  }
  return v;
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
