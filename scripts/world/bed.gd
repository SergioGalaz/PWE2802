extends Interactable
## La cama del palafito: recupera energía y salta la noche.

func _init() -> void:
	title = "Cama"
	size = Vector2(112, 72)
	sprite_name = "cama"
	fill = Color(0.55, 0.45, 0.4)


func get_prompt() -> String:
	if GameState.phase == GameState.Phase.DIA:
		return "Dormir (solo al atardecer o de noche)"
	return "Dormir hasta el amanecer"


func interact(_player: Node) -> void:
	if GameState.phase == GameState.Phase.DIA:
		GameState.say("Todavía es de día. Hay pega que hacer.")
		return
	world.sleep_until_morning()
