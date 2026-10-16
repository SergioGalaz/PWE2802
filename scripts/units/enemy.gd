extends Unit
## Un ente de la noche. Los del monte rondan el bosque; los ahogados de Cai Cai
## suben del mar en noches de Marea Bruja y van hacia la iglesia.

const TYPES := {
	"trauco": {"name": "Trauco", "hp": 60.0, "dmg": 9.0, "speed": 130.0, "radius": 20.0, "color": Color(0.55, 0.35, 0.15), "kind": "monte"},
	"fiura": {"name": "Fiura", "hp": 45.0, "dmg": 6.0, "speed": 115.0, "radius": 18.0, "color": Color(0.5, 0.75, 0.25), "kind": "monte"},
	"ahogado": {"name": "Ahogado", "hp": 40.0, "dmg": 8.0, "speed": 95.0, "radius": 21.0, "color": Color(0.3, 0.5, 0.6), "kind": "mar"},
}
const AGGRO := 380.0
const HORDE_AGGRO := 170.0

var type := "trauco"
var kind := "monte"
var horde := false
var home := Vector2.ZERO
var ability_cd := 4.0
var attack_cd := 0.0
var wander_target := Vector2.ZERO
var pulse := 0.0
var pulse_color := Color.WHITE
var pulse_radius := 0.0


func setup(enemy_type: String, is_horde: bool) -> void:
	type = enemy_type
	horde = is_horde
	var t: Dictionary = TYPES[type]
	display_name = t["name"]
	max_hp = t["hp"]
	hp = max_hp
	radius = t["radius"]
	color = t["color"]
	kind = t["kind"]
	sprite_name = type


func _ready() -> void:
	setup_body(LAYER_ENEMY, LAYER_BARRICADE)
	# Las hordas son muchas: sin nombre encima, para no tapar la pelea.
	label.visible = not horde
	add_to_group("enemies")
	home = global_position
	wander_target = home


func _physics_process(delta: float) -> void:
	tick_status(delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	ability_cd -= delta
	pulse = maxf(0.0, pulse - delta)
	if dead:
		return
	if stun_time > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var t: Dictionary = TYPES[type]
	if ability_cd <= 0.0:
		_use_ability()
	var target = world.nearest_ally(global_position, HORDE_AGGRO if horde else AGGRO)
	var dest := global_position
	if target != null:
		dest = target.global_position
		if global_position.distance_to(target.global_position) < radius + target.radius + 22.0:
			dest = global_position
			if attack_cd <= 0.0:
				attack_cd = 1.0
				target.take_damage(t["dmg"], self)
	elif horde:
		var barricade = world.blocking_barricade(global_position)
		if barricade != null:
			dest = global_position
			if attack_cd <= 0.0:
				attack_cd = 1.0
				barricade.take_damage(t["dmg"])
		elif global_position.distance_to(world.church_pos) < 70.0:
			world.enemy_reached_church(self)
			return
		else:
			dest = world.church_pos
	else:
		if global_position.distance_to(wander_target) < 20.0:
			wander_target = home + Vector2(randf_range(-260, 260), randf_range(-160, 160))
		dest = wander_target
	var to := dest - global_position
	var speed: float = t["speed"] * (0.55 if target == null and not horde else 1.0)
	velocity = to.normalized() * speed if to.length() > 6.0 else Vector2.ZERO
	move_and_slide()


func _use_ability() -> void:
	match type:
		"trauco":
			# Su mirada paraliza a los Finaos cercanos. A los vivos no les hace nada.
			ability_cd = 6.0
			var hit := false
			var finaos: Array = get_tree().get_nodes_in_group("finaos")
			for f in finaos:
				if f.global_position.distance_to(global_position) < 210.0:
					f.stun(2.0)
					hit = true
			if hit:
				_pulse(210.0, Color(1.0, 0.85, 0.2, 0.35))
		"fiura":
			# Su aliento pudre a los Finaos y enferma a Abdón.
			ability_cd = 5.0
			var hit := false
			var allies: Array = world.allies()
			for a in allies:
				if a.global_position.distance_to(global_position) < 150.0:
					a.take_damage(6.0, self)
					if a.get("frescura") != null:
						a.frescura = maxf(0.0, a.frescura - 4.0)
					hit = true
			if hit:
				_pulse(150.0, Color(0.5, 0.9, 0.2, 0.35))
		_:
			ability_cd = 99.0


func _pulse(r: float, c: Color) -> void:
	pulse = 0.4
	pulse_radius = r
	pulse_color = c


func _on_death(source: Node) -> void:
	world.enemy_killed(self, source)
	queue_free()


func _draw() -> void:
	if pulse > 0.0:
		draw_circle(Vector2.ZERO, pulse_radius * (1.0 - pulse), pulse_color)
	super._draw()
