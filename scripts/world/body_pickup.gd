extends Interactable
## Un ahogado en la playa. Se recoge para reanimarlo en la mesa de brujería.

func _init() -> void:
	title = "Ahogado"
	prompt = "Recoger el cuerpo"
	size = Vector2(64, 20)
	sprite_name = "cuerpo"
	fill = Color(0.35, 0.5, 0.55)
	interact_radius = 90.0


func interact(_player: Node) -> void:
	GameState.add("cuerpo", 1)
	GameState.say("Recogiste un cuerpo. Huele a mar y a mala suerte.")
	queue_free()
