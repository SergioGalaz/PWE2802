extends Unit
## Abdón Cárcamo: se mueve, pesca, pelea con el arpón y usa el Revisorio.

const SPEED := 340.0
const DASH_SPEED := 1050.0
const ATTACK_RANGE := 105.0
const ATTACK_DAMAGE := 22.0
const SPELL_COST := 15.0
const SPELL_RADIUS := 170.0
const SPELL_DAMAGE := 45.0

var energy := 100.0
var facing := Vector2.DOWN
var attack_cd := 0.0
var dash_time := 0.0
var dash_cd := 0.0
var swing := 0.0
var nearest: Object = null
var camera: Camera2D
var lantern: PointLight2D


func _ready() -> void:
	display_name = "Abdón"
	sprite_name = "abdon"
	color = Color(0.25, 0.5, 0.95)
	radius = 24.0
	setup_body(LAYER_PLAYER, LAYER_TERRAIN | LAYER_BARRICADE)
	add_to_group("player")
	camera = Camera2D.new()
	camera.zoom = Vector2(1.15, 1.15)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()
	lantern = PointLight2D.new()
	lantern.texture = radial_texture()
	lantern.texture_scale = 3.2
	lantern.color = Color(1.0, 0.85, 0.55)
	lantern.energy = 0.0
	add_child(lantern)


static func radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _physics_process(delta: float) -> void:
	tick_status(delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	swing = maxf(0.0, swing - delta)
	lantern.energy = GameState.darkness() * 1.1
	if dead:
		return
	var accepts_input := not GameState.ui_blocking and GameState.ui_cooldown <= 0.0
	var input := InputSetup.move_vector() if not GameState.ui_blocking else Vector2.ZERO
	if dash_time > 0.0:
		dash_time -= delta
		velocity = facing * DASH_SPEED
	else:
		var speed := SPEED * (0.6 if energy <= 0.0 else 1.0)
		velocity = input * speed
		if input.length() > 0.15:
			facing = input.normalized()
	var aim := InputSetup.aim_vector()
	if aim.length() > 0.35 and not GameState.ui_blocking:
		facing = aim.normalized()
	move_and_slide()
	look = facing
	_update_nearest()
	if accepts_input:
		if Input.is_action_just_pressed("attack"):
			attack()
		if Input.is_action_just_pressed("dodge"):
			dodge()
		if Input.is_action_just_pressed("spell"):
			cast_spell()
		if Input.is_action_just_pressed("interact") and nearest != null:
			nearest.interact(self)


func _update_nearest() -> void:
	var best: Object = null
	var best_d := INF
	var items: Array = get_tree().get_nodes_in_group("interactables")
	for it in items:
		if it == self or not it.can_interact(self):
			continue
		var d: float = global_position.distance_to(it.global_position)
		if d < float(it.interact_radius) and d < best_d:
			best = it
			best_d = d
	nearest = best


func use_energy(amount: float) -> void:
	energy = maxf(0.0, energy - amount)
	if energy <= 0.0:
		GameState.say("Abdón está agotado. Duerme para recuperar energía.")


func attack() -> void:
	if attack_cd > 0.0:
		return
	attack_cd = 0.4
	swing = 0.18
	show_attack()
	Audio.play("arpon")
	use_energy(0.5)
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		var to: Vector2 = e.global_position - global_position
		var reach: float = ATTACK_RANGE + e.radius
		if to.length() < reach and (to.length() < 30.0 or to.normalized().dot(facing) > 0.2):
			e.take_damage(ATTACK_DAMAGE, self)


func dodge() -> void:
	if dash_cd > 0.0 or energy < 2.0:
		return
	dash_time = 0.16
	dash_cd = 0.8
	use_energy(2.0)


func cast_spell() -> void:
	if GameState.juicio < SPELL_COST:
		GameState.say("No te queda Juicio para leer el Revisorio.")
		return
	GameState.change_meter("juicio", -SPELL_COST)
	GameState.change_meter("marea", 3.0)
	Audio.play("revisorio")
	var center := global_position + facing * 150.0
	world.spawn_burst(center, SPELL_RADIUS, Color(0.6, 0.3, 0.9, 0.5))
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e.global_position.distance_to(center) < SPELL_RADIUS:
			e.take_damage(SPELL_DAMAGE, self)
	GameState.story("primer_hechizo", [
		["Don Fermín", "Ojo con ese libro, patrón. Cada hechizo es un favor que le debe al mar."],
		["Don Fermín", "La Marea sube y el Juicio baja. Yo lo anoto todo, por si acaso."],
	])


func take_damage(amount: float, source: Node = null) -> void:
	if dash_time > 0.0:
		return
	super.take_damage(amount, source)


func _on_death(_source: Node) -> void:
	world.player_down()


func revive(at: Vector2) -> void:
	dead = false
	hp = max_hp * 0.5
	global_position = at


func _draw() -> void:
	super._draw()
	# Marca de hacia dónde apunta el arpón.
	var tip := facing * (radius + 30)
	var side := facing.orthogonal() * 7
	draw_colored_polygon(PackedVector2Array([tip, facing * (radius + 16) + side, facing * (radius + 16) - side]), Color(0.95, 0.95, 1.0, 0.8))
	if swing > 0.0:
		var a := facing.angle()
		draw_arc(Vector2.ZERO, ATTACK_RANGE * 0.8, a - 0.9, a + 0.9, 16, Color(1, 1, 1, swing * 4.0), 6.0)
