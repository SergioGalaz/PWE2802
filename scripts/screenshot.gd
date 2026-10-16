extends Node
## Saca capturas de la demo para revisar cómo se ve. Se corre con:
##   godot --path . -- --screenshot=res://captura.png [--night] [--touch]

var main: Node
var path := "user://captura.png"
var night := false
var touch := false
var frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			path = arg.trim_prefix("--screenshot=")
	night = "--night" in OS.get_cmdline_user_args()
	touch = "--touch" in OS.get_cmdline_user_args()
	main.start_game(false)
	main.hud.auto_skip = true
	main.hud.dialogue_queue.clear()
	main.hud._next_line()
	var w = main.world
	GameState.add("cuerpo", 2)
	GameState.add("brea", 2)
	var table := _find("Mesa de brujería")
	for i in 3:
		w.player.energy = 100.0
		table.interact(w.player)
	if night:
		GameState.day = 3
		GameState.phase = GameState.Phase.NOCHE
		GameState.phase_time = 40.0
		GameState.add("madera", 9)
		var barricades: Array = get_tree().get_nodes_in_group("barricades")
		for b in barricades:
			b.interact(w.player)
		w.player.global_position = Vector2(2250, 1300)
		for i in 6:
			w.spawn_enemy("ahogado", Vector2(2000 + i * 90, 1560 + (i % 2) * 60), true)
		for f in w.finaos():
			f.global_position = Vector2(2150 + randf_range(-80, 80), 1330)
	else:
		w.player.global_position = Vector2(960, 1150)
		GameState.phase_time = 200.0
	if touch:
		InputSetup.set_mode(InputSetup.Mode.TOUCH)
	if "--shop" in OS.get_cmdline_user_args():
		GameState.add("pescado_ahumado", 4)
		main.hud.open_shop()
	if "--finao" in OS.get_cmdline_user_args():
		main.hud.open_finao_panel(w.finaos()[0])
	GameState.say("Día %d. La marea dejó ahogados en la playa." % GameState.day)


func _find(title: String) -> Node:
	var items: Array = get_tree().get_nodes_in_group("interactables")
	for it in items:
		if it.get("title") == title:
			return it
	return null


func _process(_delta: float) -> void:
	frames += 1
	if frames == 90:
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path)
		print("Captura guardada en ", path)
		Unit._texture_cache.clear()
		get_tree().quit()
