extends CanvasLayer
## Interfaz de la partida: barra superior, avisos, diálogos, menús y controles táctiles.
## Todo se puede usar con mando (foco y cruceta), teclado o tocando la pantalla.

signal quit_to_title

const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const FishingGame := preload("res://scripts/ui/fishing_game.gd")
const SquadWheel := preload("res://scripts/ui/squad_wheel.gd")
const FinaoScript := preload("res://scripts/units/finao.gd")
const SELL_PRICES := {"pescado_ahumado": 5, "pescado": 2, "trofeo": 12}
const BUY_PRICES := {"sal": 4, "brea": 5, "chicha": 6}

var world: Node
## En la prueba automática los diálogos se saltan solos.
var auto_skip := false

var root: Control
var top_label: Label
var res_label: Label
var hp_bar: ProgressBar
var energy_bar: ProgressBar
var meter_bars := {}
var prompt_label: Label
var notes_box: VBoxContainer
var dialogue_panel: PanelContainer
var dialogue_speaker: Label
var dialogue_text: Label
var dialogue_queue: Array = []
var modal: Control = null
var fishing: PanelContainer
var shop_panel: PanelContainer
var shop_box: VBoxContainer
var finao_panel: PanelContainer
var finao_box: VBoxContainer
var current_finao = null
var menu_panel: PanelContainer
var end_panel: PanelContainer
var end_label: Label
var wheel: Control
var touch: Node2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = make_theme()
	add_child(root)
	_build_top_bar()
	_build_prompt_and_notes()
	touch = TouchControls.new()
	add_child(touch)
	wheel = SquadWheel.new()
	wheel.set_anchors_preset(Control.PRESET_FULL_RECT)
	wheel.order_chosen.connect(func(order: int) -> void: world.give_order(order))
	root.add_child(wheel)
	_build_dialogue()
	fishing = FishingGame.new()
	fishing.finished.connect(close_modal)
	_add_modal(fishing)
	shop_panel = _make_panel("Almacén de Lucio")
	shop_box = shop_panel.get_child(0) as VBoxContainer
	finao_panel = _make_panel("Finao")
	finao_box = finao_panel.get_child(0) as VBoxContainer
	_build_menu()
	_build_end_panel()
	root.move_child(dialogue_panel, -1)
	GameState.notify.connect(add_note)
	GameState.dialogue_requested.connect(show_dialogue)
	GameState.demo_finished.connect(show_demo_end)


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.1, 0.14, 0.92)
	panel.border_color = Color(0.55, 0.45, 0.3)
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(14)
	panel.set_content_margin_all(28)
	t.set_stylebox("panel", "PanelContainer", panel)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.2, 0.18)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(14)
	var focus := normal.duplicate()
	focus.bg_color = Color(0.45, 0.35, 0.2)
	focus.border_color = Color(1, 0.85, 0.5)
	focus.set_border_width_all(4)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", focus)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("pressed", "Button", focus)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.15, 0.15, 0.15)
	t.set_stylebox("disabled", "Button", disabled)
	return t


# --- Barra superior ---

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 120
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	bar.add_child(row)
	var left := VBoxContainer.new()
	row.add_child(left)
	top_label = Label.new()
	top_label.add_theme_font_size_override("font_size", 28)
	left.add_child(top_label)
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 12)
	left.add_child(bars)
	hp_bar = _small_bar(bars, "Vida", Color(0.85, 0.25, 0.25))
	energy_bar = _small_bar(bars, "Energía", Color(0.9, 0.75, 0.25))
	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 12)
	row.add_child(meters)
	meter_bars["marea"] = _small_bar(meters, "Marea", Color(0.25, 0.55, 0.85))
	meter_bars["cerro"] = _small_bar(meters, "Cerro", Color(0.45, 0.7, 0.35))
	meter_bars["juicio"] = _small_bar(meters, "Juicio", Color(0.75, 0.6, 0.9))
	meter_bars["aldea"] = _small_bar(meters, "Quicaví", Color(0.85, 0.7, 0.45))
	res_label = Label.new()
	res_label.add_theme_font_size_override("font_size", 24)
	res_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	res_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(res_label)


func _small_bar(parent: Control, text: String, c: Color) -> ProgressBar:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	box.add_child(l)
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(150, 22)
	pb.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = c
	pb.add_theme_stylebox_override("fill", fill)
	box.add_child(pb)
	return pb


func _build_prompt_and_notes() -> void:
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_top = -170
	prompt_label.offset_bottom = -110
	prompt_label.offset_left = -500
	prompt_label.offset_right = 500
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 32)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 8)
	root.add_child(prompt_label)
	notes_box = VBoxContainer.new()
	notes_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	notes_box.position = Vector2(24, 150)
	notes_box.custom_minimum_size = Vector2(900, 0)
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes_box)


func add_note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(900, 0)
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	notes_box.add_child(l)
	while notes_box.get_child_count() > 4:
		notes_box.get_child(0).free()
	var tween := l.create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(l, "modulate:a", 0.0, 1.0)
	tween.tween_callback(l.queue_free)


func _process(_delta: float) -> void:
	if world == null:
		return
	var p = world.player
	var phase_name := "" if GameState.phase == GameState.Phase.DIA else " (%s)" % GameState.PHASE_NAMES[GameState.phase]
	top_label.text = "Día %d · %s%s · %s%s" % [
		GameState.day, GameState.clock_text(), phase_name, GameState.tide_name(),
		" · Noche de Marea Bruja" if GameState.is_horde_night() else "",
	]
	hp_bar.value = p.hp
	energy_bar.value = p.energy
	meter_bars["marea"].value = GameState.marea
	meter_bars["cerro"].value = GameState.cerro
	meter_bars["juicio"].value = GameState.juicio
	meter_bars["aldea"].value = GameState.village_hp
	var parts: PackedStringArray = []
	for res in GameState.RESOURCE_NAMES:
		parts.append("%s %d" % [GameState.RESOURCE_NAMES[res], GameState.amount(res)])
	parts.append("Finaos %d" % world.finaos().size())
	res_label.text = "  ".join(parts)
	if p.nearest != null and modal == null and not dialogue_panel.visible:
		var g := InputSetup.glyph("interact")
		var key := "Acción" if InputSetup.mode == InputSetup.Mode.TOUCH else g
		prompt_label.text = "[%s] %s" % [key, p.nearest.get_prompt()]
	else:
		prompt_label.text = ""
	if Input.is_action_just_pressed("menu") and modal == null and not dialogue_panel.visible:
		open_modal(menu_panel)


# --- Diálogos ---

func _build_dialogue() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_panel.offset_top = -300
	dialogue_panel.offset_left = 120
	dialogue_panel.offset_right = -120
	dialogue_panel.offset_bottom = -40
	root.add_child(dialogue_panel)
	var box := VBoxContainer.new()
	dialogue_panel.add_child(box)
	dialogue_speaker = Label.new()
	dialogue_speaker.add_theme_font_size_override("font_size", 32)
	dialogue_speaker.add_theme_color_override("font_color", Color(1, 0.8, 0.45))
	box.add_child(dialogue_speaker)
	dialogue_text = Label.new()
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	dialogue_text.add_theme_font_size_override("font_size", 32)
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(dialogue_text)
	var hint := Label.new()
	hint.text = "Toca o pulsa Acción para seguir"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)
	dialogue_panel.hide()


## Cada línea es [quién habla, texto]. Pausa el juego hasta terminar.
func show_dialogue(lines: Array) -> void:
	dialogue_queue.append_array(lines)
	if auto_skip:
		dialogue_queue.clear()
		return
	if not dialogue_panel.visible:
		get_tree().paused = true
		GameState.set_ui_blocking(true)
		dialogue_panel.show()
		_next_line()


func _next_line() -> void:
	if dialogue_queue.is_empty():
		dialogue_panel.hide()
		if modal == null:
			get_tree().paused = false
			GameState.set_ui_blocking(false)
		return
	var line: Array = dialogue_queue.pop_front()
	dialogue_speaker.text = line[0]
	dialogue_speaker.visible = line[0] != ""
	dialogue_text.text = line[1]


func _input(event: InputEvent) -> void:
	if not dialogue_panel.visible:
		return
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	if event is InputEventScreenTouch and event.pressed:
		advance = true
	if event is InputEventMouseButton and event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
		advance = true
	if advance:
		get_viewport().set_input_as_handled()
		_next_line()


func _unhandled_input(event: InputEvent) -> void:
	if modal != null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_modal()


# --- Ventanas ---

func _make_panel(title: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 38)
	box.add_child(l)
	_add_modal(panel)
	return panel


func _add_modal(panel: Control) -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	center.hide()
	root.add_child(center)


func open_modal(panel: Control) -> void:
	if modal != null:
		close_modal()
	modal = panel
	panel.get_parent().show()
	get_tree().paused = true
	GameState.set_ui_blocking(true)
	_focus_first(panel)


func close_modal() -> void:
	if modal == null:
		return
	modal.get_parent().hide()
	modal = null
	current_finao = null
	if not dialogue_panel.visible:
		get_tree().paused = false
		GameState.set_ui_blocking(false)


func _focus_first(node: Node) -> void:
	var buttons: Array = node.find_children("*", "Button", true, false)
	for c in buttons:
		if not c.disabled:
			c.grab_focus()
			return


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(760, 84)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _clear_box(box: VBoxContainer) -> void:
	# El primer hijo es el título.
	for i in range(box.get_child_count() - 1, 0, -1):
		box.get_child(i).free()


func open_fishing() -> void:
	open_modal(fishing)
	fishing.start()


# --- Almacén ---

func sell_bonus() -> float:
	return 1.2 if world.has_finao_role("contador") else 1.0


func open_shop() -> void:
	_fill_shop(0)
	open_modal(shop_panel)


func _fill_shop(focus_index: int) -> void:
	_clear_box(shop_box)
	var info := Label.new()
	info.text = "Tienes %d pesos.%s" % [GameState.amount("pesos"), " Don Fermín regatea un 20 por ciento más." if sell_bonus() > 1.0 else ""]
	shop_box.add_child(info)
	var buttons: Array = []
	for res in SELL_PRICES:
		var price := int(round(SELL_PRICES[res] * sell_bonus()))
		var n := GameState.amount(res)
		var b := _button(shop_box, "Vender %s a %d c/u" % [GameState.quantity(res, n), price], _sell.bind(res, price))
		b.disabled = n == 0
		buttons.append(b)
	for res in BUY_PRICES:
		var b := _button(shop_box, "Comprar %s por %d pesos" % [GameState.quantity(res, 1), BUY_PRICES[res]], _buy.bind(res, BUY_PRICES[res]))
		b.disabled = GameState.amount("pesos") < BUY_PRICES[res]
		buttons.append(b)
	buttons.append(_button(shop_box, "Volver", close_modal))
	var target: Button = buttons[clampi(focus_index, 0, buttons.size() - 1)]
	if target.disabled:
		_focus_first(shop_box)
	else:
		target.grab_focus()


func _sell(res: String, price: int) -> void:
	var n := GameState.amount(res)
	GameState.spend({res: n})
	GameState.add("pesos", n * price)
	_fill_shop(_focused_index(shop_box))


func _buy(res: String, price: int) -> void:
	if GameState.spend({"pesos": price}):
		GameState.add(res, 1)
	_fill_shop(_focused_index(shop_box))


func _focused_index(box: VBoxContainer) -> int:
	var buttons: Array = box.find_children("*", "Button", true, false)
	for i in buttons.size():
		if buttons[i].has_focus():
			return i
	return 0


# --- Panel de un Finao ---

func open_finao_panel(f: Node) -> void:
	current_finao = f
	_fill_finao(0)
	open_modal(finao_panel)


func _fill_finao(focus_index: int) -> void:
	var f = current_finao
	_clear_box(finao_box)
	var info := Label.new()
	info.text = f.summary()
	finao_box.add_child(info)
	var buttons: Array = []
	buttons.append(_button(finao_box, "Trabajo de día: %s (cambiar)" % FinaoScript.WORK_NAMES[f.work], _cycle_work))
	buttons.append(_button(finao_box, "Sale de noche en la cuadrilla: %s" % ("Sí" if f.in_squad else "No"), _toggle_squad))
	var chicha := _button(finao_box, "Darle chicha (+30 moral, quedan %d)" % GameState.amount("chicha"), _give_chicha)
	chicha.disabled = GameState.amount("chicha") == 0
	buttons.append(chicha)
	buttons.append(_button(finao_box, "Volver", close_modal))
	var target: Button = buttons[clampi(focus_index, 0, buttons.size() - 1)]
	if target.disabled:
		_focus_first(finao_box)
	else:
		target.grab_focus()


func _cycle_work() -> void:
	var order := ["ahumadero", "muelle", "descanso"]
	current_finao.work = order[(order.find(current_finao.work) + 1) % order.size()]
	_fill_finao(0)


func _toggle_squad() -> void:
	current_finao.in_squad = not current_finao.in_squad
	_fill_finao(1)


func _give_chicha() -> void:
	if GameState.spend({"chicha": 1}):
		current_finao.moral = minf(100.0, current_finao.moral + 30.0)
		GameState.say("%s se toma la chicha y se le ve más contento. Dentro de lo posible." % current_finao.display_name)
	_fill_finao(2)


# --- Menú de pausa y fin de la demo ---

func _build_menu() -> void:
	menu_panel = _make_panel("Pausa")
	var box := menu_panel.get_child(0) as VBoxContainer
	_button(box, "Seguir jugando", close_modal)
	_button(box, "Guardar partida", func() -> void:
		GameState.save_game(world.serialize_finaos())
		GameState.say("Partida guardada.")
		close_modal())
	var controls := Label.new()
	controls.text = "Mando: stick para moverse, A acción, X arpón, B esquivar, Y Revisorio, LT + stick para órdenes.\nTeclado: WASD, E, J, K, L y Q."
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD
	controls.custom_minimum_size = Vector2(760, 0)
	controls.add_theme_font_size_override("font_size", 22)
	box.add_child(controls)
	_button(box, "Salir al inicio", func() -> void:
		close_modal()
		quit_to_title.emit())


func _build_end_panel() -> void:
	end_panel = _make_panel("Fin de la demo")
	var box := end_panel.get_child(0) as VBoxContainer
	end_label = Label.new()
	end_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	end_label.custom_minimum_size = Vector2(760, 0)
	box.add_child(end_label)
	_button(box, "Seguir jugando", close_modal)
	_button(box, "Volver al inicio", func() -> void:
		close_modal()
		quit_to_title.emit())


func show_demo_end() -> void:
	end_label.text = "Abdón sobrevivió tres días en Quicaví.\n\nFinaos: %d. Pesos: %d. Trofeos: %d.\nMarea %d, Cerro %d, Juicio %d, Quicaví %d.\n\nEn el juego completo, la Marea Bruja recién empieza." % [
		world.finaos().size(), GameState.amount("pesos"), GameState.amount("trofeo"),
		int(GameState.marea), int(GameState.cerro), int(GameState.juicio), int(GameState.village_hp),
	]
	if auto_skip:
		return
	open_modal(end_panel)
