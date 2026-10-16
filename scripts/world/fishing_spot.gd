extends Interactable
## El muelle: Abdón pesca con un minijuego y un Finao arponero puede pescar solo.

const WORK_INTERVAL := 30.0

var work_progress := 0.0


func _init() -> void:
	title = "Muelle"
	prompt = "Pescar"
	size = Vector2(90, 200)
	fill = Color(0.5, 0.38, 0.25)


func can_interact(_player: Node) -> bool:
	return not GameState.is_night()


func interact(player: Node) -> void:
	if player.energy < 5.0:
		GameState.say("Abdón está muy cansado para pescar.")
		return
	player.use_energy(5.0)
	world.hud.open_fishing()


func _process(delta: float) -> void:
	super._process(delta)
	if GameState.is_night():
		return
	var workers: int = world.workers_at("muelle", true)
	if workers == 0:
		return
	work_progress += delta * GameState.time_scale * workers
	if work_progress >= WORK_INTERVAL:
		work_progress = 0.0
		GameState.add("pescado", 1)


func _draw() -> void:
	super._draw()
	for i in 5:
		draw_line(Vector2(-45, -80 + i * 40), Vector2(45, -80 + i * 40), Color(0.3, 0.2, 0.12), 3.0)
