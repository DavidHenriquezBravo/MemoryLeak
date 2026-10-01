class_name MemoryView
extends Control

# Dibuja el diagrama de memoria del ejercicio:   [0x0020 | 1 ] cerradura
# Si una casilla es puntero (points_to), dibuja una flecha hasta la casilla apuntada;
# si apunta a NULL, una X roja.

const ROW_H := 24          # alto de cada fila
const BOX_H := 18          # alto de la caja
const X0 := 14             # margen izquierdo (espacio para las flechas)
const W_ADDR := 54         # ancho de la parte de la dirección
const W_VAL := 58          # ancho de la parte del valor

const C_FONDO := Color(0.055, 0.07, 0.14)
const C_BORDE := Color(0.306, 0.306, 0.69)
const C_CYAN := Color(0.239, 0.894, 0.867)
const C_DIM := Color(0.61, 0.61, 0.77)
const C_TXT := Color(0.93, 0.93, 0.96)
const C_GOLD := Color(0.93, 0.66, 0.25)
const C_MASK := Color(1.0, 0.38, 0.69)
const C_RED := Color(1.0, 0.35, 0.35)

@export var font: Font
@export var font_size := 11

var cells: Array[MemoryCellData] = []
var highlight := ""


func set_cells(new_cells: Array[MemoryCellData], highlight_address: String = "") -> void:
	cells = new_cells
	highlight = highlight_address
	custom_minimum_size.y = cells.size() * ROW_H
	queue_redraw()


func _draw() -> void:
	var f := font if font != null else get_theme_default_font()
	var filas := {}
	for i in cells.size():
		var c := cells[i]
		var y := float(i * ROW_H)
		var es_destacada := highlight != "" and GameState.norm(c.address) == GameState.norm(highlight)
		var borde := C_CYAN if es_destacada else C_BORDE
		var caja := Rect2(X0, y, W_ADDR + W_VAL, BOX_H)
		draw_rect(caja, C_FONDO)
		draw_rect(caja, borde, false, 1.0)
		draw_line(Vector2(X0 + W_ADDR, y + 1), Vector2(X0 + W_ADDR, y + BOX_H - 1), borde, 1.0)

		var sin_dir := c.address.begins_with("-")
		_centrado(f, c.address, Rect2(X0, y, W_ADDR, BOX_H), C_DIM if sin_dir else C_CYAN)
		var valor := "?" if c.masked and c.value != "???" else c.value
		var col_valor := C_TXT
		if c.masked:
			col_valor = C_MASK
		elif valor.begins_with("0x"):
			col_valor = C_GOLD
		_centrado(f, valor, Rect2(X0 + W_ADDR, y, W_VAL, BOX_H), col_valor)
		var base := y + (BOX_H + f.get_ascent(font_size) - f.get_descent(font_size)) / 2.0
		draw_string(f, Vector2(X0 + W_ADDR + W_VAL + 6, base), c.label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, C_DIM)
		filas[GameState.norm(c.address)] = y

	# Flechas de los punteros
	for c in cells:
		if c.points_to == "":
			continue
		var ys: float = filas[GameState.norm(c.address)] + BOX_H / 2.0
		if c.points_to.to_upper() == "NULL":
			draw_line(Vector2(X0 - 1, ys), Vector2(5, ys), C_RED, 1.0)
			draw_line(Vector2(1, ys - 3), Vector2(7, ys + 3), C_RED, 1.0)
			draw_line(Vector2(1, ys + 3), Vector2(7, ys - 3), C_RED, 1.0)
			continue
		var destino := GameState.norm(c.points_to)
		if not filas.has(destino):
			continue
		var yd: float = filas[destino] + BOX_H / 2.0
		var xa := 4.0
		draw_polyline(PackedVector2Array([
			Vector2(X0 - 1, ys), Vector2(xa, ys), Vector2(xa, yd), Vector2(X0 - 4, yd)]), C_GOLD, 1.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(X0 - 1, yd), Vector2(X0 - 5, yd - 3), Vector2(X0 - 5, yd + 3)]), C_GOLD)


func _centrado(f: Font, texto: String, r: Rect2, col: Color) -> void:
	var base := r.position.y + (r.size.y + f.get_ascent(font_size) - f.get_descent(font_size)) / 2.0
	draw_string(f, Vector2(r.position.x, base), texto, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, font_size, col)
