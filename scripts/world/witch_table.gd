extends Interactable
## La mesa de brujería: con un cuerpo, sal, brea y el Revisorio se reanima un Finao.

const COST := {"cuerpo": 1, "sal": 1, "brea": 1}


func _init() -> void:
	title = "Mesa de brujería"
	size = Vector2(112, 80)
	sprite_name = "mesa_brujeria"
	fill = Color(0.3, 0.22, 0.35)


func get_prompt() -> String:
	return "Reanimar un Finao (%s)" % GameState.costs_text(COST)


func interact(player: Node) -> void:
	if not GameState.has_all(COST):
		GameState.say("Falta material: %s." % GameState.costs_text(COST))
		return
	if player.energy < 10.0:
		GameState.say("Reanimar cansa. Abdón necesita dormir.")
		return
	GameState.spend(COST)
	player.use_energy(10.0)
	GameState.change_meter("juicio", -5.0)
	GameState.change_meter("marea", 1.0)
	Audio.play("reanimar", 0.0, 0.0)
	world.reanimate()


func _draw() -> void:
	super._draw()
	draw_circle(Vector2(0, -22), 26, Color(0.55, 0.2, 0.7, 0.15 + 0.1 * sin(Time.get_ticks_msec() / 300.0)))
