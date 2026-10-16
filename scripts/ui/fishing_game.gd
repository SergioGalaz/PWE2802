extends PanelContainer
## Minijuego de pesca: una marca va y viene por la barra y hay que tirar la red
## cuando pasa por la zona buena. Tres intentos por salida.

signal finished

const CASTS := 3

var marker := 0.0
var direction := 1.0
var speed := 0.9
var zone_center := 0.5
var zone_width := 0.2
var casts_left := CASTS
var caught := 0
var bar: Control
var info: Label
var cast_button: Button
var close_button: Button


func _ready() -> void:
	custom_minimum_size = Vector2(900, 420)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	add_child(box)
	var title := Label.new()
	title.text = "Pesca en el muelle"
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)
	info = Label.new()
	box.add_child(info)
	bar = Control.new()
	bar.custom_minimum_size = Vector2(840, 70)
	bar.draw.connect(_draw_bar)
	box.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	cast_button = Button.new()
	cast_button.text = "¡Tirar la red!"
	cast_button.custom_minimum_size = Vector2(420, 90)
	cast_button.pressed.connect(_cast)
	row.add_child(cast_button)
	close_button = Button.new()
	close_button.text = "Volver"
	close_button.custom_minimum_size = Vector2(300, 90)
	close_button.pressed.connect(func() -> void: finished.emit())
	row.add_child(close_button)


func start() -> void:
	casts_left = CASTS
	caught = 0
	# En bajamar la zona buena es más chica, pero salen mariscos además del pescado.
	zone_width = 0.15 if GameState.is_low_tide() else 0.22
	speed = randf_range(0.8, 1.1)
	_new_zone()
	_update_info("Tira la red cuando la marca pase por la zona verde.")
	cast_button.disabled = false
	cast_button.grab_focus()


func _new_zone() -> void:
	zone_center = randf_range(0.2, 0.8)
	marker = 0.0
	direction = 1.0


func _process(delta: float) -> void:
	if not visible or casts_left == 0:
		return
	marker += direction * speed * delta
	if marker > 1.0 or marker < 0.0:
		direction *= -1.0
		marker = clampf(marker, 0.0, 1.0)
	bar.queue_redraw()


func _cast() -> void:
	if casts_left == 0:
		return
	casts_left -= 1
	Audio.play("chapuzon")
	var msg := ""
	if absf(marker - zone_center) <= zone_width / 2.0:
		var n := randi_range(1, 3) + (1 if GameState.is_low_tide() else 0)
		caught += n
		GameState.add("pescado", n)
		msg = "¡Salieron %d!" % n
		Audio.play("pesca", 0.0, 0.0)
		GameState.story("primera_pesca", [
			["Don Fermín", "Buena. Ese pescado llévelo al ahumadero; fresco se pudre, ahumado se vende."],
		])
	else:
		msg = "Nada. Solo algas y una bota."
	if casts_left == 0:
		cast_button.disabled = true
		close_button.grab_focus()
		_update_info("%s Total de la salida: %d pescados." % [msg, caught])
	else:
		_new_zone()
		_update_info(msg)


func _update_info(msg: String) -> void:
	info.text = "%s  Intentos: %d. Marea: %s." % [msg, casts_left, GameState.tide_name()]


func _draw_bar() -> void:
	var w := bar.size.x
	var h := bar.size.y
	bar.draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.2, 0.3))
	bar.draw_rect(Rect2((zone_center - zone_width / 2.0) * w, 0, zone_width * w, h), Color(0.3, 0.75, 0.35))
	bar.draw_rect(Rect2(marker * w - 6, -8, 12, h + 16), Color(1, 1, 1))
