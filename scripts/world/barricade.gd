extends Interactable
## Barricada de la playa. Se construye con madera y frena a los ahogados de la horda.

const BUILD_COST := {"madera": 3}
const REPAIR_COST := {"madera": 1}
const MAX_HP := 150.0

var hp := 0.0
var body: StaticBody2D


func _init() -> void:
	title = "Barricada"
	size = Vector2(184, 48)
	sprite_name = "barricada"
	fill = Color(0.5, 0.35, 0.2)
	interact_radius = 130.0


func _ready() -> void:
	super._ready()
	add_to_group("barricades")
	body = StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)
	_update_body()


func is_built() -> bool:
	return hp > 0.0


func can_interact(_player: Node) -> bool:
	return not is_built() or hp < MAX_HP


func get_prompt() -> String:
	if not is_built():
		return "Construir barricada (%s)" % GameState.costs_text(BUILD_COST)
	return "Reparar barricada (%s)" % GameState.costs_text(REPAIR_COST)


func interact(_player: Node) -> void:
	var building := not is_built()
	if not GameState.spend(BUILD_COST if building else REPAIR_COST):
		GameState.say("Falta madera. Hay leña en el monte.")
		return
	hp = MAX_HP if building else minf(MAX_HP, hp + 60.0)
	_update_body()


func take_damage(amount: float) -> void:
	if not is_built():
		return
	hp = maxf(0.0, hp - amount)
	if hp == 0.0:
		GameState.say("¡Cayó una barricada!")
		_update_body()


func _update_body() -> void:
	body.collision_layer = Unit.LAYER_BARRICADE if is_built() else 0
	title_label.text = title if is_built() else "Barricada (sin construir)"


func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	if not is_built():
		draw_rect(r, Color(1, 1, 1, 0.25), false, 3.0)
		return
	super._draw()
	draw_rect(Rect2(-90, 30, 180, 6), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-90, 30, 180 * hp / MAX_HP, 6), Color(0.9, 0.7, 0.2))
