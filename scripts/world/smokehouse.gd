extends Interactable
## El ahumadero: convierte pescado fresco en ahumado, que se vende mejor.
## Los Finaos asignados lo hacen funcionar más rápido.

const SMOKE_TIME := 15.0

var queue := 0
var progress := 0.0


func _init() -> void:
	title = "Ahumadero"
	size = Vector2(130, 110)
	fill = Color(0.35, 0.25, 0.2)


func get_prompt() -> String:
	if GameState.amount("pescado") > 0:
		return "Ahumar %d pescado" % GameState.amount("pescado")
	return "Ahumadero: %d en el humo" % queue


func interact(_player: Node) -> void:
	var n := GameState.amount("pescado")
	if n == 0:
		GameState.say("No hay pescado fresco. Ve a pescar al muelle.")
		return
	GameState.spend({"pescado": n})
	queue += n
	GameState.say("%d pescado al humo." % n)


func _process(delta: float) -> void:
	super._process(delta)
	if queue == 0:
		progress = 0.0
		return
	var workers: int = world.workers_at("ahumadero", true)
	progress += delta * GameState.time_scale * (1.0 + workers)
	if progress >= SMOKE_TIME:
		progress = 0.0
		queue -= 1
		GameState.add("pescado_ahumado", 1)
		GameState.story("primer_ahumado", [
			["Don Fermín", "Pescado ahumado: dura más y Lucio lo paga mejor. El humo es lo único en esta isla que no viene del mar."],
		])


func _draw() -> void:
	super._draw()
	if queue > 0:
		draw_rect(Rect2(-55, 40, 110 * progress / SMOKE_TIME, 10), Color(0.95, 0.6, 0.2))
		for i in 3:
			draw_circle(Vector2(-20 + i * 20, -70 - fmod(Time.get_ticks_msec() / 20.0 + i * 30.0, 60.0)), 10, Color(0.8, 0.8, 0.8, 0.4))
