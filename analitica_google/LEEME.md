# Registro de partidas en Google Sheets

El juego envía cada fila del registro a una planilla de Google y desde Excel se leen esos datos. El CSV local (`registros/registro_partidas.csv`, junto al `.exe`) se sigue escribiendo como respaldo.

## Qué queda en la planilla

- **Jugadores:** una fila por persona, identificada por su correo, con un ID único (`J0001`, `J0002`…) que no cambia. Si la persona vuelve a jugar, se actualiza su misma fila.
  - **Datos generales:** `primera_vez`, `ultima_vez` y `sesiones`.
  - **Respuestas:** `preguntas_respondidas`, `correctas`, `errores`, `porcentaje_acierto` y `tiempo_promedio_respuesta_s`.
  - **Jefes y niveles:** por cada jefe, `intentos`, `derrotas` y `vencido`; por cada nivel, `duracion_min` de la primera vez que lo pasó. Al final va `juego_terminado`.
- **Detalle:** una fila por evento, con el `id_jugador`:
  - Cada respuesta a un NPC o a un jefe, si fue correcta y cuánto tardó.
  - Cada pelea contra un jefe que termina en victoria o derrota.
  - Cada nivel terminado.

## 1. Crear la planilla y el script (una sola vez)

1. Crea una planilla nueva en Google Sheets. Si la cuenta de la universidad no deja publicar para "cualquier usuario", usa una cuenta personal.
2. Ve a **Extensiones → Apps Script**. Borra lo que aparece y pega todo el contenido de `Code.gs`. Guarda con el ícono de disquete.
3. En la barra de arriba, elige la función **`configurar`** y aprieta **Ejecutar**.
   - Google pedirá permisos. Si aparece "Google no verificó esta app", entra a **Configuración avanzada → Ir a … (no seguro)**. Es normal en scripts propios.
   - En el **Registro de ejecución** de abajo aparecen dos claves. Cópialas:
     - `CLAVE_JUEGO`: va dentro del juego y solo permite agregar filas.
     - `CLAVE_LECTURA`: va solo en el Excel y permite leer los datos, incluidos los correos. **No la pongas en el juego.**
   - Si las pierdes, ejecuta **`verClaves`**.
4. Aprieta **Implementar → Nueva implementación**. En el engranaje elige **Aplicación web** y configura:
   - **Ejecutar como:** yo
   - **Quién tiene acceso:** cualquier usuario
5. Aprieta **Implementar** y copia la **URL de la aplicación web**, que termina en `/exec`.

> **Si después cambias `Code.gs`**, no hagas una implementación nueva, porque cambiaría la URL y el juego dejaría de enviar. Ve a **Implementar → Administrar implementaciones**, aprieta el lápiz, elige **Versión: nueva versión** y luego **Implementar**. Así se mantiene la misma URL.

## 2. Conectar el juego

En `scripts/autoload/envio_registros.gd` completa las dos constantes y vuelve a exportar el juego:

```gdscript
const URL := "https://script.google.com/macros/s/…/exec"
const CLAVE := "la CLAVE_JUEGO"
```

Si `URL` o `CLAVE` quedan vacías, el juego no envía nada y solo escribe el CSV.

**Sin internet:** las filas quedan en `registros/pendientes_envio.json`, junto al CSV. El juego las reintenta solo y también la próxima vez que se abra. Si una fila llega dos veces, la planilla la ignora.

## 3. Ver los datos en Excel

Haz una consulta para cada hoja:

1. En Excel ve a **Datos → Obtener datos → De otras fuentes → Consulta en blanco**.
2. En el Editor de Power Query aprieta **Editor avanzado**, borra lo que hay y pega el código de abajo con tu URL y tu `CLAVE_LECTURA`.
3. Aprieta **Listo**. Si pregunta por el acceso al contenido web, elige **Anónimo → Conectar**.
4. Cambia el nombre de la consulta a `Jugadores` (panel derecho) y aprieta **Cerrar y cargar**.
5. Repite con el segundo código para `Detalle`. Quedan en dos hojas del mismo archivo.

**Jugadores:**

```
let
    Url = "PEGA_AQUI_LA_URL_QUE_TERMINA_EN_/exec",
    Clave = "PEGA_AQUI_LA_CLAVE_LECTURA",
    Respuesta = Json.Document(Web.Contents(Url, [Query = [hoja = "jugadores", clave = Clave]])),
    Tabla = if Respuesta[ok] = true
        then Table.FromRows(Respuesta[filas], Respuesta[columnas])
        else error Respuesta[error]
in
    Tabla
```

**Detalle:** es el mismo código con `hoja = "detalle"`:

```
let
    Url = "PEGA_AQUI_LA_URL_QUE_TERMINA_EN_/exec",
    Clave = "PEGA_AQUI_LA_CLAVE_LECTURA",
    Respuesta = Json.Document(Web.Contents(Url, [Query = [hoja = "detalle", clave = Clave]])),
    Tabla = if Respuesta[ok] = true
        then Table.FromRows(Respuesta[filas], Respuesta[columnas])
        else error Respuesta[error]
in
    Tabla
```

**Para ver datos nuevos:**
- Aprieta **Datos → Actualizar todo**.
- Para que se actualice solo, ve a **Datos → Consultas y conexiones**, haz clic derecho en la consulta y entra a **Propiedades**. Ahí marca "Actualizar al abrir el archivo" o "Actualizar cada N minutos".

Los números llegan como números, sin problemas de coma decimal. Las fechas llegan como texto con formato `2026-11-10 14:05:00`, que se ordena bien. Si las necesitas como fecha, cambia el tipo de la columna en Power Query.

## Seguridad

- La URL y la `CLAVE_JUEGO` van dentro del juego. Alguien que las saque del `.exe` podría agregar filas falsas, pero no leer los datos.
- Para leer hace falta la `CLAVE_LECTURA`, que solo está en tu Excel y en el script.
- Los correos de los jugadores quedan guardados en esta planilla de Google, además de los computadores donde se juegue.
