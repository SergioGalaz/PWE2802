extends Node
## Punto de entrada: pantalla de inicio, creación de la partida y prueba automática.

const World := preload("res://scripts/world/world.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const SmokeTest := preload("res://scripts/smoke_test.gd")
const Screenshot := preload("res://scripts/screenshot.gd")

var world: Node2D
var hud: CanvasLayer
var title: CanvasLayer


func _ready() -> void:
	if "--smoke" in OS.get_cmdline_user_args():
		var smoke := SmokeTest.new()
		smoke.main = self
		add_child(smoke)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot"):
			var shot := Screenshot.new()
			shot.main = self
			add_child(shot)
			return
	show_title()


func show_title() -> void:
	_clear_game()
	title = CanvasLayer.new()
	add_child(title)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.theme = Hud.make_theme()
	title.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)
	var name_label := Label.new()
	name_label.text = "MAREA BRUJA"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 96)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.55))
	box.add_child(name_label)
	var sub := Label.new()
	sub.text = "Quicaví, Chiloé. Otoño de 1960. Demo del acto I."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var new_game := Button.new()
	new_game.text = "Nueva partida"
	new_game.custom_minimum_size = Vector2(520, 96)
	new_game.pressed.connect(start_game.bind(false))
	box.add_child(new_game)
	if GameState.has_save():
		var cont := Button.new()
		cont.text = "Continuar"
		cont.custom_minimum_size = Vector2(520, 96)
		cont.pressed.connect(start_game.bind(true))
		box.add_child(cont)
		cont.grab_focus()
	else:
		new_game.grab_focus()
	var hint := Label.new()
	hint.text = "Se juega con la pantalla táctil, con un mando o con el teclado."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	box.add_child(hint)


func start_game(load_save: bool) -> void:
	if title != null:
		title.queue_free()
		title = null
	if not (load_save and GameState.load_game()):
		GameState.reset()
	world = World.new()
	hud = Hud.new()
	world.hud = hud
	hud.world = world
	hud.quit_to_title.connect(show_title)
	add_child(world)
	add_child(hud)
	GameState.running = true
	if not load_save:
		GameState.dialogue_requested.emit([
			["", "Quicaví, Chiloé. Marzo de 1960."],
			["Abdón", "Anoche la red trajo un ahogado. Abrió los ojos y me pidió un cigarro."],
			["Abdón", "Venía con un libro envuelto en hule. Un Revisorio, con el nombre de mi papá en la primera página."],
			["Abdón", "El libro dice que con sal y brea, en la mesa de brujería, los muertos se levantan a trabajar."],
			["", "Ve a la mesa de brujería del palafito y reanima al ahogado."],
		])


func _clear_game() -> void:
	GameState.running = false
	get_tree().paused = false
	GameState.set_ui_blocking(false)
	if world != null:
		world.queue_free()
		world = null
	if hud != null:
		hud.queue_free()
		hud = null
