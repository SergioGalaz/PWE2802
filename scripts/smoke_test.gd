extends Node
## Prueba automática: juega los tres días de la demo a velocidad alta y revisa
## que los sistemas principales funcionen. Se corre con:
##   godot --headless --path . -- --smoke

const TIME_SCALE := 40.0
const MAX_FRAMES := 60000

var main: Node
var frames := 0
var checks := {}
var did_reanimate := false
var did_shop := false
var did_fish := false
var did_barricades := false
var night_positioned := -1
var saw_enemy := false
var saw_horde := false
var saw_bosses := {}
var kills := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.SAVE_PATH))
	main.start_game(false)
	main.hud.auto_skip = true
	main.hud.close_modal()
	get_tree().paused = false
	GameState.set_ui_blocking(false)
	GameState.time_scale = TIME_SCALE
	main.world.player.dead = false
	print("SMOKE: partida iniciada")


func _process(_delta: float) -> void:
	frames += 1
	var w = main.world
	if w == null:
		return
	if get_tree().paused:
		main.hud.close_modal()
		get_tree().paused = false
		GameState.set_ui_blocking(false)
	if not did_reanimate and frames > 5:
		did_reanimate = true
		GameState.add("cuerpo", 3)
		GameState.add("sal", 3)
		GameState.add("brea", 3)
		var table = _find("Mesa de brujería")
		for i in 4:
			w.player.energy = 100.0
			table.interact(w.player)
		var fs: Array = w.finaos()
		check("cuatro Finaos reanimados", fs.size() == 4)
		check("el primero es Don Fermín", fs.any(func(f) -> bool: return f.display_name == "Don Fermín"))
		for f in fs:
			f.in_squad = true
		fs[1].work = "muelle"
	if not did_fish and frames > 20:
		did_fish = true
		main.hud.open_fishing()
		var fishing = main.hud.fishing
		fishing.marker = fishing.zone_center
		fishing._cast()
		main.hud.close_modal()
		check("la pesca da pescado", GameState.amount("pescado") > 0)
		var smoke = _find("Ahumadero")
		smoke.interact(w.player)
		check("el pescado entra al ahumadero", smoke.queue > 0)
	if not did_shop and frames > 40 and GameState.amount("pescado_ahumado") > 0:
		did_shop = true
		var before := GameState.amount("pesos")
		main.hud.open_shop()
		main.hud._sell("pescado_ahumado", 6)
		main.hud.close_modal()
		check("vender ahumado da pesos", GameState.amount("pesos") > before)
	if not did_barricades and GameState.day == 3:
		did_barricades = true
		GameState.add("madera", 9)
		var barricades: Array = get_tree().get_nodes_in_group("barricades")
		for b in barricades:
			b.interact(w.player)
		check("tres barricadas construidas", barricades.all(func(b) -> bool: return b.is_built()))
	if GameState.is_night() and night_positioned != GameState.day:
		night_positioned = GameState.day
		# Abdón espera a los entes con la cuadrilla, en el monte o en la playa según la noche.
		w.player.hp = w.player.max_hp
		w.player.global_position = Vector2(2250, 1300) if GameState.is_horde_night() else Vector2(1500, 650)
		w.give_order(1)
	if GameState.is_night():
		var enemies: Array = get_tree().get_nodes_in_group("enemies")
		if not enemies.is_empty():
			saw_enemy = true
			for en in enemies:
				if en.get("jefe"):
					saw_bosses[en.type] = true
			if GameState.is_horde_night():
				saw_horde = true
			# El jugador ataca solo al ente más cercano, para probar el combate.
			var e = w.nearest_enemy(w.player.global_position, 2000.0)
			if e != null and frames % 6 == 0:
				var to: Vector2 = e.global_position - w.player.global_position
				w.player.velocity = Vector2.ZERO
				if to.length() > 90.0:
					w.player.global_position += to.normalized() * 12.0
				else:
					w.player.facing = to.normalized()
					w.player.attack()
	if frames == 3000:
		check("guardar y cargar", _save_roundtrip())
	if GameState.demo_done or frames > MAX_FRAMES:
		_finish()


func _find(title: String) -> Node:
	var items: Array = get_tree().get_nodes_in_group("interactables")
	for it in items:
		if it.get("title") == title:
			return it
	return null


func _save_roundtrip() -> bool:
	GameState.save_game(main.world.serialize_finaos())
	var day := GameState.day
	var ok := GameState.has_save()
	var copy := GameState.resources.duplicate()
	var saved_flags := GameState.flags.duplicate()
	ok = ok and GameState.load_game()
	ok = ok and GameState.day == day and GameState.saved_finaos.size() == main.world.finaos().size()
	GameState.resources = copy
	GameState.flags = saved_flags
	return ok


func check(name: String, ok: bool) -> void:
	checks[name] = ok
	print("SMOKE %s: %s" % ["OK  " if ok else "FALLA", name])


func _finish() -> void:
	check("la demo llega al final del día 3", GameState.demo_done)
	check("aparecieron entes de noche", saw_enemy)
	check("hubo horda en la tercera noche", saw_horde)
	check("apareció el Chonchón", saw_bosses.has("chonchon"))
	check("apareció el Invunche", saw_bosses.has("invunche"))
	print("SMOKE resumen: día %d, finaos %d, recursos %s, marea %d, cerro %d, juicio %d, quicaví %d, frames %d" % [
		GameState.day, main.world.finaos().size(), GameState.resources, int(GameState.marea),
		int(GameState.cerro), int(GameState.juicio), int(GameState.village_hp), frames,
	])
	var failed := checks.values().count(false)
	print("SMOKE %s" % ("TODO OK" if failed == 0 else "%d FALLAS" % failed))
	Unit._texture_cache.clear()
	get_tree().quit(0 if failed == 0 else 1)
