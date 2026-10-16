extends Node2D
## Controles táctiles: joystick virtual a la izquierda y botones de acción a la derecha.
## Solo se ven en modo táctil. Escriben directo en las acciones de entrada,
## así el resto del juego no distingue entre mando y pantalla.

const JOY_RADIUS := 130.0
const BUTTON_RADIUS := 78.0
const BUTTONS := [
	{"action": "interact", "label": "Acción", "offset": Vector2(-150, -150), "color": Color(0.3, 0.7, 0.4)},
	{"action": "attack", "label": "Arpón", "offset": Vector2(-330, -110), "color": Color(0.75, 0.35, 0.3)},
	{"action": "dodge", "label": "Esquivar", "offset": Vector2(-150, -330), "color": Color(0.35, 0.5, 0.8)},
	{"action": "spell", "label": "Revisorio", "offset": Vector2(-330, -290), "color": Color(0.6, 0.35, 0.75)},
	{"action": "squad_wheel", "label": "Cuadrilla", "offset": Vector2(-500, -130), "color": Color(0.6, 0.55, 0.35)},
	{"action": "menu", "label": "Menú", "offset": Vector2(-110, -1000), "color": Color(0.4, 0.4, 0.45)},
]

var joy_index := -1
var joy_center := Vector2.ZERO
var joy_vector := Vector2.ZERO
var buttons: Array = []


func _ready() -> void:
	for b in BUTTONS:
		var tsb := TouchScreenButton.new()
		var shape := CircleShape2D.new()
		shape.radius = BUTTON_RADIUS
		tsb.shape = shape
		tsb.action = b["action"]
		tsb.passby_press = false
		add_child(tsb)
		buttons.append(tsb)
	get_viewport().size_changed.connect(_layout)
	_layout()
	InputSetup.input_mode_changed.connect(func(_m: int) -> void: _update_visibility())
	_update_visibility()


func _update_visibility() -> void:
	visible = InputSetup.mode == InputSetup.Mode.TOUCH
	if not visible:
		_release_joystick()


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	for i in buttons.size():
		var off: Vector2 = BUTTONS[i]["offset"]
		# El botón de menú va arriba a la derecha; el resto, abajo a la derecha.
		buttons[i].position = Vector2(screen.x + off.x, screen.y + off.y if off.y > -900 else 210.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var screen := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and joy_index == -1 and event.position.x < screen.x * 0.45 and event.position.y > screen.y * 0.35:
			joy_index = event.index
			joy_center = event.position
			joy_vector = Vector2.ZERO
			queue_redraw()
		elif not event.pressed and event.index == joy_index:
			_release_joystick()
	elif event is InputEventScreenDrag and event.index == joy_index:
		joy_vector = ((event.position - joy_center) / JOY_RADIUS).limit_length(1.0)
		_apply_joystick()
		queue_redraw()


func _apply_joystick() -> void:
	_set_axis("move_right", maxf(joy_vector.x, 0.0))
	_set_axis("move_left", maxf(-joy_vector.x, 0.0))
	_set_axis("move_down", maxf(joy_vector.y, 0.0))
	_set_axis("move_up", maxf(-joy_vector.y, 0.0))


func _set_axis(action: String, strength: float) -> void:
	if strength > 0.1:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _release_joystick() -> void:
	joy_index = -1
	joy_vector = Vector2.ZERO
	_apply_joystick()
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in buttons.size():
		var b: Dictionary = BUTTONS[i]
		var p: Vector2 = buttons[i].position
		var pressed := Input.is_action_pressed(b["action"])
		var c: Color = b["color"]
		draw_circle(p, BUTTON_RADIUS, Color(c, 0.75 if pressed else 0.45))
		draw_arc(p, BUTTON_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.6), 3.0)
		var text: String = b["label"]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 26).x
		draw_string(font, p + Vector2(-w / 2.0, 9), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	if joy_index != -1:
		draw_circle(joy_center, JOY_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(joy_center, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
		draw_circle(joy_center + joy_vector * JOY_RADIUS, 55, Color(1, 1, 1, 0.45))
	else:
		var screen := get_viewport().get_visible_rect().size
		var hint := Vector2(240, screen.y - 240)
		draw_arc(hint, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.25), 3.0)
		draw_circle(hint, 55, Color(1, 1, 1, 0.15))


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()
