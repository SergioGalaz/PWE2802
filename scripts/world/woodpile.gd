extends Interactable
## Leña del monte: madera para barricadas, solo de día y unas pocas veces por día.

const USES_PER_DAY := 4

var uses_left := USES_PER_DAY


func _init() -> void:
	title = "Leña del monte"
	size = Vector2(120, 60)
	fill = Color(0.42, 0.3, 0.18)


func _ready() -> void:
	super._ready()
	GameState.day_started.connect(_on_day_started)


func _on_day_started(_day: int) -> void:
	uses_left = USES_PER_DAY


func can_interact(_player: Node) -> bool:
	return not GameState.is_night() and uses_left > 0


func get_prompt() -> String:
	return "Cortar leña (+2 madera, quedan %d hoy)" % uses_left


func interact(player: Node) -> void:
	if player.energy < 8.0:
		GameState.say("Abdón no tiene fuerzas para el hacha.")
		return
	player.use_energy(8.0)
	uses_left -= 1
	GameState.add("madera", 2)
