extends Node2D
## El mundo de la demo: el palafito de Abdón, Quicaví, el monte y la playa.
## También dirige la noche: la caza en el monte y las hordas de Cai Cai.

const MAP_SIZE := Vector2(3200, 2000)
const FOREST_BOTTOM := 700.0
const BEACH_TOP := 1360.0
const SEA_TOP := 1520.0
const WAVE_INTERVAL := 60.0
const HUNT_INTERVAL := 45.0
const MAX_HUNT := 6

const PlayerScript := preload("res://scripts/units/player.gd")
const FinaoScript := preload("res://scripts/units/finao.gd")
const EnemyScript := preload("res://scripts/units/enemy.gd")
const FishingSpot := preload("res://scripts/world/fishing_spot.gd")
const Smokehouse := preload("res://scripts/world/smokehouse.gd")
const WitchTable := preload("res://scripts/world/witch_table.gd")
const Bed := preload("res://scripts/world/bed.gd")
const Shop := preload("res://scripts/world/shop.gd")
const Woodpile := preload("res://scripts/world/woodpile.gd")
const BodyPickup := preload("res://scripts/world/body_pickup.gd")
const Barricade := preload("res://scripts/world/barricade.gd")

var player
var hud: Node
var church_pos := Vector2(2250, 980)
var bed_pos := Vector2(1170, 1090)
var work_spots := {
	"ahumadero": Vector2(760, 1160),
	"muelle": Vector2(1000, 1420),
	"descanso": Vector2(870, 1250),
}
var night_timer := 0.0
var waves_sent := 0
var hunt_spawned := 0
var shade: CanvasModulate
var trees: Array = []


func _ready() -> void:
	y_sort_enabled = true
	_build_collision()
	_plant_trees()
	shade = CanvasModulate.new()
	add_child(shade)
	_place(FishingSpot.new(), Vector2(1000, 1500))
	_place(Smokehouse.new(), Vector2(760, 1060))
	_place(WitchTable.new(), Vector2(980, 1050))
	_place(Bed.new(), bed_pos)
	_place(Shop.new(), Vector2(1950, 1160))
	_place(Woodpile.new(), Vector2(520, 760))
	for x in [1900.0, 2250.0, 2600.0]:
		_place(Barricade.new(), Vector2(x, 1410))
	_add_zone_label("Monte de Tepual", Vector2(1500, 80))
	_add_zone_label("Quicaví", Vector2(2250, 740))
	_add_zone_label("Palafito de Abdón", Vector2(950, 930))
	_add_zone_label("Golfo de Ancud", Vector2(1500, 1880))

	player = PlayerScript.new()
	player.world = self
	player.position = Vector2(1050, 1200)
	add_child(player)
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = int(MAP_SIZE.x)
	player.camera.limit_bottom = int(MAP_SIZE.y)

	for data in GameState.saved_finaos:
		spawn_finao(data)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.day_started.connect(_on_day_started)


func _place(node: Interactable, pos: Vector2) -> void:
	node.world = self
	node.position = pos
	add_child(node)


func _add_zone_label(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.size = Vector2(600, 50)
	l.position = pos - Vector2(300, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	add_child(l)


func _build_collision() -> void:
	var walls := StaticBody2D.new()
	walls.collision_layer = Unit.LAYER_TERRAIN
	# El mar y los bordes del mapa. Los entes no chocan con esto: suben del agua.
	_add_rect(walls, Rect2(0, SEA_TOP, MAP_SIZE.x, MAP_SIZE.y - SEA_TOP + 100))
	_add_rect(walls, Rect2(-100, -100, 100, MAP_SIZE.y + 200))
	_add_rect(walls, Rect2(MAP_SIZE.x, -100, 100, MAP_SIZE.y + 200))
	_add_rect(walls, Rect2(0, -100, MAP_SIZE.x, 100))
	add_child(walls)


func _add_rect(body: StaticBody2D, r: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.position + r.size / 2.0
	body.add_child(shape)


func _plant_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1960
	for i in 140:
		trees.append(Vector2(rng.randf_range(40, MAP_SIZE.x - 40), rng.randf_range(20, FOREST_BOTTOM - 30)))


func _process(_delta: float) -> void:
	var d := GameState.darkness()
	var c := Color.WHITE.lerp(Color(0.22, 0.25, 0.42), d)
	if GameState.phase == GameState.Phase.ATARDECER:
		c = c.lerp(Color(1.0, 0.65, 0.45), 0.35 * (1.0 - absf(d - 0.5) * 2.0))
	shade.color = c


func _physics_process(delta: float) -> void:
	if not GameState.is_night():
		return
	night_timer += delta * GameState.time_scale
	if GameState.is_horde_night():
		if waves_sent < 3 and night_timer >= waves_sent * WAVE_INTERVAL:
			_send_wave(4 + 2 * waves_sent)
			waves_sent += 1
	elif hunt_spawned < MAX_HUNT and night_timer >= hunt_spawned * HUNT_INTERVAL:
		var enemies: Array = get_tree().get_nodes_in_group("enemies")
		if enemies.size() < 5:
			spawn_enemy("trauco" if randf() < 0.55 else "fiura", _forest_point(), false)
		hunt_spawned += 1


func _send_wave(count: int) -> void:
	GameState.say("¡Suben ahogados del mar! Ola %d de 3." % (waves_sent + 1))
	for i in count:
		spawn_enemy("ahogado", Vector2(randf_range(1800, 2700), randf_range(1700, 1900)), true)


func _forest_point() -> Vector2:
	return Vector2(randf_range(250, MAP_SIZE.x - 250), randf_range(150, FOREST_BOTTOM - 80))


func spawn_enemy(type: String, pos: Vector2, horde: bool) -> Unit:
	var e = EnemyScript.new()
	e.setup(type, horde)
	e.world = self
	e.position = pos
	add_child(e)
	return e


func spawn_finao(data: Dictionary) -> Unit:
	var f = FinaoScript.new()
	if not data.has("name"):
		var used := finaos().map(func(x) -> String: return x.display_name)
		var free: Array = FinaoScript.NAMES.filter(func(n: String) -> bool: return not used.has(n))
		data = data.duplicate()
		data["name"] = free.pick_random() if not free.is_empty() else FinaoScript.NAMES.pick_random()
	f.setup(data)
	f.world = self
	f.position = work_spots["descanso"] + Vector2(randf_range(-60, 60), randf_range(-30, 30))
	add_child(f)
	return f


func finaos() -> Array:
	return get_tree().get_nodes_in_group("finaos").filter(func(f) -> bool: return not f.dead)


func serialize_finaos() -> Array:
	return finaos().map(func(f) -> Dictionary: return f.to_dict())


# --- Consultas para la IA ---

func nearest_enemy(pos: Vector2, max_dist: float) -> Variant:
	var best: Variant = null
	var best_d := max_dist
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.dead:
			continue
		var d: float = pos.distance_to(e.global_position)
		if d < best_d:
			best = e
			best_d = d
	return best


func allies() -> Array:
	var list := finaos()
	if not player.dead:
		list.append(player)
	return list


func nearest_ally(pos: Vector2, max_dist: float) -> Variant:
	var best: Variant = null
	var best_d := max_dist
	for a in allies():
		var d: float = pos.distance_to(a.global_position)
		if d < best_d:
			best = a
			best_d = d
	return best


func blocking_barricade(pos: Vector2) -> Variant:
	var barricades: Array = get_tree().get_nodes_in_group("barricades")
	for b in barricades:
		if b.is_built() and absf(b.global_position.x - pos.x) < 110.0 and absf(b.global_position.y - pos.y) < 50.0:
			return b
	return null


func work_position(place: String) -> Vector2:
	return work_spots.get(place, work_spots["descanso"])


## Cuántos Finaos trabajan en un lugar. Con `present`, solo cuenta a los que ya llegaron.
func workers_at(place: String, present: bool) -> int:
	var n := 0
	for f in finaos():
		if f.work != place or (GameState.is_night() and f.in_squad):
			continue
		if present and f.global_position.distance_to(work_position(place)) > 160.0:
			continue
		n += 1
	return n


func has_finao_role(role: String) -> bool:
	return finaos().any(func(f) -> bool: return f.role == role)


# --- Eventos ---

func reanimate() -> void:
	if not GameState.flags.get("fermin", false):
		GameState.flags["fermin"] = true
		spawn_finao({"name": "Don Fermín", "role": "contador", "oficio": "contador", "work": "ahumadero", "in_squad": false})
		GameState.dialogue_requested.emit([
			["Don Fermín", "¿Ya? ¿Y el cigarro que le pedí?"],
			["Don Fermín", "Fermín Oyarzo, contador en Puerto Montt por treinta años. Ahogado hace tres días. Muerto, pero no tonto."],
			["Abdón", "¿Y ahora qué hago con usted?"],
			["Don Fermín", "Póngame en el ahumadero. Y vaya a pescar al muelle, que con pescado ahumado se paga la sal y la brea."],
			["Don Fermín", "En la playa siempre aparecen más ahogados. Tráigalos, que de noche nos va a hacer falta gente."],
		])
		return
	var f = spawn_finao({})
	GameState.say("%s volvió a abrir los ojos. Era %s en vida: %s." % [f.display_name, f.oficio, f.role_name()])
	GameState.story("segundo_finao", [
		["Don Fermín", "Cada finao sirve para algo según su oficio. Los carpinteros aguantan, los pescadores tiran arpón y las beatas rezan."],
		["Don Fermín", "Háblele para mandarlo a trabajar o sacarlo de la cuadrilla de la noche."],
	])


func _on_phase_changed(phase: int) -> void:
	if phase == GameState.Phase.ATARDECER:
		if GameState.is_horde_night():
			GameState.say("Atardece. Esta noche es de Marea Bruja: construye barricadas en la playa.")
		else:
			GameState.say("Atardece. Elige quién sale de noche en la cuadrilla.")
	elif phase == GameState.Phase.NOCHE:
		night_timer = 0.0
		waves_sent = 0
		hunt_spawned = 0
		for f in finaos():
			f.order = FinaoScript.Order.FOLLOW
		if GameState.is_horde_night():
			GameState.dialogue_requested.emit([
				["Don Fermín", "Patrón, el mar está raro. Los ahogados de Cai Cai van a subir a la iglesia."],
				["Don Fermín", "Si entran, el pueblo lo paga. Ponga a la cuadrilla a defender las barricadas."],
			])
		else:
			GameState.story("primera_noche", [
				["Don Fermín", "De noche bajan cosas del monte. Traucos y Fiuras, por lo menos."],
				["Don Fermín", "El Trauco paraliza a los finaos con la mirada. A usted no, porque está vivo. Por ahora."],
				["Don Fermín", "La Fiura tiene un aliento que pudre. Pelee lejos de ella si puede."],
				["Don Fermín", "Cace lo que pueda: los trofeos se venden bien donde Lucio."],
			])


func _on_day_started(_day: int) -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		e.queue_free()
	var lost: Array = []
	for f in finaos():
		if not f.new_day():
			lost.append(f.display_name)
			f.queue_free()
	if not lost.is_empty():
		GameState.say("Se desarmó: %s. Hacía falta más sal." % ", ".join(lost))
	if GameState.village_hp <= 0.0:
		GameState.say("Los ahogados entraron a la iglesia. Quicaví amaneció de luto y la Marea subió.")
		GameState.change_meter("marea", 10.0)
		GameState.change_meter("aldea", 60.0)
	for i in randi_range(1, 2):
		_drop_body(Vector2(randf_range(300, 1700), randf_range(1420, 1480)))
	GameState.save_game(serialize_finaos())
	if GameState.is_horde_night():
		GameState.say("Día %d. Los viejos dicen que esta noche viene la Marea Bruja." % GameState.day)
	else:
		GameState.say("Día %d. La marea dejó ahogados en la playa." % GameState.day)


func _drop_body(pos: Vector2) -> void:
	var b := BodyPickup.new()
	_place(b, Vector2(pos.x, minf(pos.y, SEA_TOP - 50.0)))


func enemy_killed(e, source: Node) -> void:
	if e.kind == "mar":
		GameState.change_meter("cerro", 1.0)
		if randf() < 0.5:
			_drop_body(e.global_position)
	else:
		var n := 1
		if source != null and source.get("role") == "saqueador":
			n += 1
		GameState.add("trofeo", n)
		GameState.story("primer_trofeo", [
			["Don Fermín", "Eso es un trofeo. Lucio los compra y no pregunta. El gringo del hotel pagaría más, pero ese es otro cuento."],
		])


func enemy_reached_church(e: Unit) -> void:
	e.remove_from_group("enemies")
	e.queue_free()
	GameState.change_meter("aldea", -10.0)
	GameState.change_meter("marea", 2.0)
	GameState.say("¡Un ahogado llegó a la iglesia!")


func finao_fell(f: Unit) -> void:
	GameState.say("A %s se le cayó la cabeza en la pelea. El cuerpo quedó tirado." % f.display_name)
	_drop_body(f.global_position)
	f.queue_free()


func player_down() -> void:
	var lost := GameState.amount("pescado") / 2
	GameState.spend({"pescado": lost})
	GameState.change_meter("juicio", -10.0)
	player.revive(bed_pos + Vector2(0, 60))
	GameState.say("Abdón despertó en su cama sin saber cómo llegó. Le faltan pescados y algo de Juicio.")


func give_order(order: int) -> void:
	var refused: Array = []
	var squad := finaos().filter(func(f) -> bool: return f.in_squad)
	if squad.is_empty():
		GameState.say("No hay Finaos en la cuadrilla.")
		return
	for f in squad:
		if not f.give_order(order, player.global_position):
			refused.append(f.display_name)
	var text := "Orden: %s." % FinaoScript.ORDER_NAMES[order]
	if not refused.is_empty():
		text += " No obedecen por moral baja: %s." % ", ".join(refused)
	GameState.say(text)


func sleep_until_morning() -> void:
	player.energy = 100.0
	GameState.change_meter("juicio", 15.0)
	if GameState.phase == GameState.Phase.ATARDECER:
		GameState.advance_phase()
	if GameState.is_horde_night() and waves_sent < 3:
		GameState.change_meter("aldea", -40.0)
		GameState.change_meter("marea", 5.0)
		GameState.say("Mientras Abdón dormía, la horda golpeó Quicaví.")
	GameState.advance_phase()


func spawn_shot(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from, to])
	line.width = 4.0
	line.default_color = Color(0.95, 0.95, 0.85)
	line.z_index = 5
	add_child(line)
	get_tree().create_timer(0.12).timeout.connect(line.queue_free)


func spawn_burst(center: Vector2, r: float, c: Color) -> void:
	var burst := Burst.new()
	burst.radius = r
	burst.color = c
	burst.position = center
	burst.z_index = 5
	add_child(burst)


class Burst:
	extends Node2D
	var radius := 100.0
	var color := Color.WHITE
	var life := 0.35

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius * (1.2 - life), Color(color, color.a * life / 0.35))


func _draw() -> void:
	# Monte, pradera, playa y mar.
	draw_rect(Rect2(0, 0, MAP_SIZE.x, FOREST_BOTTOM), Color(0.13, 0.27, 0.16))
	draw_rect(Rect2(0, FOREST_BOTTOM, MAP_SIZE.x, BEACH_TOP - FOREST_BOTTOM), Color(0.33, 0.45, 0.25))
	draw_rect(Rect2(0, BEACH_TOP, MAP_SIZE.x, SEA_TOP - BEACH_TOP), Color(0.72, 0.66, 0.5))
	draw_rect(Rect2(0, SEA_TOP, MAP_SIZE.x, MAP_SIZE.y - SEA_TOP), Color(0.12, 0.27, 0.4))
	for i in 12:
		var y := SEA_TOP + 40.0 + i * 38.0
		draw_line(Vector2(0, y), Vector2(MAP_SIZE.x, y + 8.0), Color(1, 1, 1, 0.06), 3.0)
	for t in trees:
		draw_circle(t + Vector2(6, 10), 34, Color(0, 0, 0, 0.2))
		draw_circle(t, 34, Color(0.08, 0.2, 0.11))
		draw_circle(t + Vector2(-8, -8), 18, Color(0.16, 0.33, 0.18))
	# El palafito de Abdón, con sus pilotes hacia la playa.
	draw_rect(Rect2(650, 980, 620, 330), Color(0.4, 0.3, 0.22, 0.55))
	draw_rect(Rect2(650, 980, 620, 330), Color(0.2, 0.14, 0.1), false, 4.0)
	for x in range(680, 1260, 80):
		draw_line(Vector2(x, 1310), Vector2(x, 1380), Color(0.25, 0.18, 0.12), 8.0)
	draw_rect(Rect2(780, 1215, 180, 70), Color(0.3, 0.22, 0.16, 0.6))
	# Quicaví: casas, la iglesia de madera y el camino.
	draw_line(Vector2(1270, 1150), Vector2(2900, 1150), Color(0.55, 0.48, 0.35), 50.0)
	for h in [Vector2(1750, 920), Vector2(2600, 930), Vector2(2800, 1060), Vector2(1700, 1260), Vector2(2550, 1260)]:
		draw_rect(Rect2(h, Vector2(150, 110)), Color(0.6, 0.45, 0.3))
		draw_colored_polygon(PackedVector2Array([h, h + Vector2(75, -50), h + Vector2(150, 0)]), Color(0.45, 0.25, 0.2))
	var c := church_pos
	draw_rect(Rect2(c + Vector2(-110, -60), Vector2(220, 170)), Color(0.85, 0.75, 0.45))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-120, -60), c + Vector2(0, -130), c + Vector2(120, -60)]), Color(0.5, 0.3, 0.25))
	draw_rect(Rect2(c + Vector2(-25, -220), Vector2(50, 100)), Color(0.85, 0.75, 0.45))
	draw_line(c + Vector2(0, -260), c + Vector2(0, -225), Color(0.2, 0.15, 0.1), 6.0)
	draw_line(c + Vector2(-14, -248), c + Vector2(14, -248), Color(0.2, 0.15, 0.1), 6.0)
	draw_rect(Rect2(c + Vector2(-25, 50), Vector2(50, 60)), Color(0.3, 0.2, 0.15))
