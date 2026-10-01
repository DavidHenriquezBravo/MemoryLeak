class_name AddrFormatter
extends RefCounted

# Convierte marcas del texto en BBCode:
#   {addr:0x0020}  -> magenta "[0x0020]" si no está resuelta; cyan con su valor si ya se reveló
#   `int *ptr;`    -> amarillo (código)
# El código y las direcciones van en [code] para que usen la fuente monoespaciada
# (theme_override_fonts/mono_font del RichTextLabel).

static func format(text: String) -> String:
	var rx := RegEx.create_from_string("\\{addr:(0x[0-9A-Fa-f]+)\\}")
	for m in rx.search_all(text):
		var a := m.get_string(1)
		var repl: String
		if GameState.is_revealed(a):
			repl = "[color=#4fe0e0]%s[/color]" % GameState.revealed_value(a)
		else:
			repl = "[bgcolor=#3a1a30][color=#ff4fb0][code][lb]%s[rb][/code][/color][/bgcolor]" % a
		text = text.replace(m.get_string(), repl)

	var rc := RegEx.create_from_string("`([^`]+)`")
	for m in rc.search_all(text):
		var code := m.get_string(1).replace("[", "[lb]")
		text = text.replace(m.get_string(), "[bgcolor=#2a2616][color=#ffd84f][code]%s[/code][/color][/bgcolor]" % code)
	return text
