extends Node
## Registra las acciones de entrada y detecta con qué se está jugando:
## pantalla táctil, mando o teclado. La interfaz cambia sola según el último uso.

signal input_mode_changed(mode: int)

enum Mode { TOUCH, GAMEPAD, KEYBOARD }

const DEADZONE := 0.25

var mode: int = Mode.KEYBOARD
## Verdadero si el mando conectado es de PlayStation (cambia los íconos de botones).
var playstation_layout := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0, [KEY_A, KEY_LEFT])
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0, [KEY_D, KEY_RIGHT])
	_add_axis("move_up", JOY_AXIS_LEFT_Y, -1.0, [KEY_W, KEY_UP])
	_add_axis("move_down", JOY_AXIS_LEFT_Y, 1.0, [KEY_S, KEY_DOWN])
	_add_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0, [])
	_add_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0, [])
	_add_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0, [])
	_add_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0, [])
	_add_button("interact", JOY_BUTTON_A, [KEY_E, KEY_SPACE])
	_add_button("attack", JOY_BUTTON_X, [KEY_J])
	_add_button("dodge", JOY_BUTTON_B, [KEY_K])
	_add_button("spell", JOY_BUTTON_Y, [KEY_L])
	_add_axis("squad_wheel", JOY_AXIS_TRIGGER_LEFT, 1.0, [KEY_Q])
	_add_button("menu", JOY_BUTTON_START, [KEY_ESCAPE])

	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if not Input.get_connected_joypads().is_empty():
		_detect_layout(Input.get_connected_joypads()[0])
		mode = Mode.GAMEPAD
	elif DisplayServer.is_touchscreen_available():
		mode = Mode.TOUCH


func _add_button(action: StringName, joy_button: JoyButton, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)
	var ev := InputEventJoypadButton.new()
	ev.button_index = joy_button
	InputMap.action_add_event(action, ev)
	_add_keys(action, keys)


func _add_axis(action: StringName, axis: JoyAxis, value: float, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
	_add_keys(action, keys)


func _add_keys(action: StringName, keys: Array) -> void:
	for k in keys:
		var kev := InputEventKey.new()
		kev.physical_keycode = k
		InputMap.action_add_event(action, kev)


func _input(event: InputEvent) -> void:
	var new_mode := mode
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		new_mode = Mode.TOUCH
	elif event is InputEventJoypadButton:
		new_mode = Mode.GAMEPAD
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		new_mode = Mode.GAMEPAD
	elif event is InputEventKey and event.pressed:
		new_mode = Mode.KEYBOARD
	set_mode(new_mode)


func set_mode(new_mode: int) -> void:
	if new_mode != mode:
		mode = new_mode
		input_mode_changed.emit(mode)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_detect_layout(device)
		set_mode(Mode.GAMEPAD)


func _detect_layout(device: int) -> void:
	var joy_name := Input.get_joy_name(device).to_lower()
	playstation_layout = joy_name.contains("ps") or joy_name.contains("sony") \
		or joy_name.contains("dualsense") or joy_name.contains("dualshock")


## Texto corto del botón asociado a una acción, según el esquema activo.
func glyph(action: String) -> String:
	if mode == Mode.TOUCH:
		return "Toca"
	if mode == Mode.KEYBOARD:
		var keys := {"interact": "E", "attack": "J", "dodge": "K", "spell": "L", "squad_wheel": "Q", "menu": "Esc"}
		return keys.get(action, "?")
	var xbox := {"interact": "A", "attack": "X", "dodge": "B", "spell": "Y", "squad_wheel": "LT", "menu": "Menú"}
	var ps := {"interact": "✕", "attack": "□", "dodge": "○", "spell": "△", "squad_wheel": "L2", "menu": "Options"}
	return (ps if playstation_layout else xbox).get(action, "?")


## Vector de movimiento combinado (stick, teclado o joystick táctil).
func move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Vector de apuntado del stick derecho. Vacío si no se usa.
func aim_vector() -> Vector2:
	return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
