extends Interactable
## El almacén de Lucio: se vende lo que se produce y se compra lo que falta.

func _init() -> void:
	title = "Almacén de Lucio"
	prompt = "Comprar y vender"
	size = Vector2(160, 150)
	sprite_name = "almacen"
	sprite_scale = 2.5
	fill = Color(0.55, 0.3, 0.25)


func can_interact(_player: Node) -> bool:
	return not GameState.is_night()


func interact(_player: Node) -> void:
	world.hud.open_shop()
