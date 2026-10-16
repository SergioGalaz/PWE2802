extends Control
## Rueda de órdenes a la cuadrilla.
## Con mando o teclado: mantener LT (o Q), elegir con un stick y soltar.
## En táctil: tocar "Cuadrilla" abre la rueda y se toca la orden.

signal order_chosen(order: int)

const FinaoScript := preload("res://scripts/units/finao.gd")
## Orden por dirección: arriba, derecha, abajo, izquierda.
const LAYOUT := [
	{"order": FinaoScript.Order.FOLLOW, "offset": Vector2(0, -170)},
	{"order": FinaoScript.Order.ATTACK, "offset": Vector2(220, 0)},
	{"order": FinaoScript.Order.DEFEND, "offset": Vector2(0, 170)},
	{"order": FinaoScript.Order.RETREAT, "offset": Vector2(-220, 0)},
]
const LABELS := {
	FinaoScript.Order.FOLLOW: "Seguir",
	FinaoScript.Order.ATTACK: "Atacar",
	FinaoScript.Order.DEFEND: "Defender aquí",
	FinaoScript.Order.RETREAT: "Retirarse",
}

var buttons: Array = []
var highlighted := -1
var held := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in LAYOUT.size():
		var b := Button.new()
		b.text = LABELS[LAYOUT[i]["order"]]
		b.custom_minimum_size = Vector2(260, 90)
		b.focus_mode = Control.FOCUS_NONE
		var order: int = LAYOUT[i]["order"]
		b.pressed.connect(func() -> void: _choose(order))
		add_child(b)
		buttons.append(b)
	hide()


func _layout() -> void:
	var center := get_viewport().get_visible_rect().size / 2.0
	for i in buttons.size():
		var b: Button = buttons[i]
		b.position = center + LAYOUT[i]["offset"] - b.custom_minimum_size / 2.0


func _process(_delta: float) -> void:
	var touch := InputSetup.mode == InputSetup.Mode.TOUCH
	if touch:
		if Input.is_action_just_pressed("squad_wheel") and not get_tree().paused:
			if visible:
				hide()
			else:
				_open()
		return
	var pressed := Input.is_action_pressed("squad_wheel") and not get_tree().paused
	if pressed and not held and not GameState.ui_blocking:
		held = true
		GameState.ui_blocking = true
		_open()
	if not held:
		return
	if pressed:
		_track_direction()
	else:
		held = false
		GameState.set_ui_blocking(false)
		hide()
		if highlighted != -1:
			order_chosen.emit(LAYOUT[highlighted]["order"])


func _open() -> void:
	highlighted = -1
	_layout()
	_refresh()
	show()


func _track_direction() -> void:
	var v := InputSetup.aim_vector()
	if v.length() < 0.4:
		v = InputSetup.move_vector()
	if v.length() < 0.4:
		return
	if absf(v.x) > absf(v.y):
		highlighted = 1 if v.x > 0.0 else 3
	else:
		highlighted = 2 if v.y > 0.0 else 0
	_refresh()


func _refresh() -> void:
	for i in buttons.size():
		buttons[i].modulate = Color(1.3, 1.2, 0.7) if i == highlighted else Color(1, 1, 1, 0.85)


func _choose(order: int) -> void:
	hide()
	order_chosen.emit(order)
