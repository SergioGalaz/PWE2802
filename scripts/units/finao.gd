extends Unit
## Un Finao: ahogado reanimado que trabaja de día y pelea de noche.
## Su oficio en vida define su rol.

enum Order { FOLLOW, ATTACK, DEFEND, RETREAT }

const ROLES := {
	"muralla": {"name": "Muralla", "hp": 130.0, "dmg": 8.0, "range": 50.0, "speed": 150.0, "cd": 0.9, "color": Color(0.45, 0.6, 0.4)},
	"arponero": {"name": "Arponero", "hp": 70.0, "dmg": 11.0, "range": 230.0, "speed": 170.0, "cd": 1.1, "color": Color(0.35, 0.65, 0.6)},
	"rezador": {"name": "Rezador", "hp": 70.0, "dmg": 4.0, "range": 50.0, "speed": 160.0, "cd": 1.0, "color": Color(0.7, 0.7, 0.5)},
	"saqueador": {"name": "Saqueador", "hp": 80.0, "dmg": 9.0, "range": 50.0, "speed": 220.0, "cd": 0.7, "color": Color(0.6, 0.5, 0.35)},
	"contador": {"name": "Contador", "hp": 55.0, "dmg": 3.0, "range": 50.0, "speed": 150.0, "cd": 1.2, "color": Color(0.55, 0.55, 0.65)},
}
const OFICIOS := {
	"muralla": ["carpintero", "leñador", "herrero"],
	"arponero": ["pescador", "lobero"],
	"rezador": ["sacristán", "beata", "profesora"],
	"saqueador": ["contrabandista", "comerciante"],
	"contador": ["contador"],
}
const NAMES := [
	"Don Lautaro", "Doña Elcira", "El Chumbeque", "Doña Rosalba", "Don Eleuterio", "La Meche",
	"Don Abelino", "Doña Filomena", "El Guatón Ruiz", "Don Belarmino", "Doña Ercilia", "El Tito",
]
const WORK_NAMES := {"ahumadero": "Ahumadero", "muelle": "Muelle", "descanso": "Descanso"}
const ORDER_NAMES := {Order.FOLLOW: "Seguir", Order.ATTACK: "Atacar", Order.DEFEND: "Defender", Order.RETREAT: "Retirarse"}

var role := "muralla"
var oficio := "carpintero"
var frescura := 100.0
var moral := 80.0
var work := "descanso"
var in_squad := true
var order: int = Order.FOLLOW
var defend_point := Vector2.ZERO
var attack_cd := 0.0
var target = null
var interact_radius := 80.0
var offset := Vector2.ZERO
var fought_tonight := false


func _ready() -> void:
	var stats: Dictionary = ROLES[role]
	max_hp = stats["hp"]
	hp = minf(hp, max_hp) if hp > 0.0 else max_hp
	color = stats["color"]
	radius = 20.0
	setup_body(LAYER_FINAO, LAYER_TERRAIN)
	add_to_group("finaos")
	add_to_group("interactables")
	offset = Vector2(randf_range(-70, 70), randf_range(-70, 70))


## Crea un Finao nuevo con oficio al azar, o con los datos dados.
func setup(data: Dictionary) -> void:
	display_name = data.get("name", NAMES.pick_random())
	role = data.get("role", ROLES.keys().pick_random())
	var oficios: Array = OFICIOS[role]
	oficio = data.get("oficio", oficios.pick_random())
	frescura = float(data.get("frescura", 100.0))
	moral = float(data.get("moral", 80.0))
	work = data.get("work", "descanso")
	in_squad = bool(data.get("in_squad", true))
	hp = float(data.get("hp", 0.0))


func to_dict() -> Dictionary:
	return {
		"name": display_name, "role": role, "oficio": oficio, "frescura": frescura,
		"moral": moral, "work": work, "in_squad": in_squad, "hp": hp,
	}


func role_name() -> String:
	return ROLES[role]["name"]


func summary() -> String:
	return "%s. En vida fue %s; en la cuadrilla es %s. Frescura %d, moral %d." % [display_name, oficio, role_name().to_lower(), int(frescura), int(moral)]


# --- Interacción (abre su panel) ---

func can_interact(_player: Node) -> bool:
	return not dead


func get_prompt() -> String:
	return "Hablar con %s" % display_name


func interact(_player: Node) -> void:
	world.hud.open_finao_panel(self)


# --- Órdenes ---

## Devuelve falso si el Finao se niega por tener la moral baja.
func give_order(new_order: int, point: Vector2) -> bool:
	if moral < 30.0 and randf() < 0.4:
		return false
	order = new_order
	defend_point = point
	return true


func _physics_process(delta: float) -> void:
	tick_status(delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	if dead:
		return
	if stun_time > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var stats: Dictionary = ROLES[role]
	if role == "rezador":
		_heal_allies(delta)
	var dest := global_position
	var player: Node2D = world.player
	target = null
	if GameState.is_night() and in_squad:
		fought_tonight = true
		match order:
			Order.FOLLOW:
				target = world.nearest_enemy(player.global_position, 340.0)
				dest = player.global_position + offset
			Order.ATTACK:
				target = world.nearest_enemy(global_position, 1400.0)
				dest = player.global_position + offset
			Order.DEFEND:
				target = world.nearest_enemy(defend_point, 300.0)
				dest = defend_point + offset
			Order.RETREAT:
				dest = world.work_position("descanso") + offset
	else:
		var place := "descanso" if GameState.is_night() else work
		dest = world.work_position(place) + offset * 0.6
		# Si un ente se acerca demasiado, se defiende igual.
		target = world.nearest_enemy(global_position, 140.0)
	if target != null:
		var reach: float = stats["range"] + target.radius
		if global_position.distance_to(target.global_position) > reach:
			dest = target.global_position
		else:
			dest = global_position
			if attack_cd <= 0.0:
				_attack(stats)
	var to := dest - global_position
	var speed: float = stats["speed"] * (0.7 if moral < 30.0 else 1.0)
	velocity = to.normalized() * speed if to.length() > 14.0 else Vector2.ZERO
	move_and_slide()


func _attack(stats: Dictionary) -> void:
	attack_cd = stats["cd"]
	var dmg: float = stats["dmg"]
	if role == "arponero":
		world.spawn_shot(global_position, target.global_position)
		if target.get("kind") == "mar":
			dmg *= 1.5
	target.take_damage(dmg, self)


func _heal_allies(delta: float) -> void:
	var allies: Array = get_tree().get_nodes_in_group("finaos")
	for f in allies:
		if f != self and f.global_position.distance_to(global_position) < 200.0:
			f.heal(4.0 * delta)


func _on_death(_source: Node) -> void:
	world.finao_fell(self)


## Paso del tiempo al amanecer. Devuelve falso si el Finao se desarmó.
func new_day() -> bool:
	if GameState.spend({"sal": 1}):
		frescura -= 4.0
	else:
		frescura -= 15.0
	if fought_tonight:
		moral = maxf(0.0, moral - 10.0)
	fought_tonight = false
	hp = max_hp
	return frescura > 0.0


func _draw() -> void:
	super._draw()
	# Ojos de ahogado, para que se note que no están del todo vivos.
	draw_circle(Vector2(-7, -4), 3.5, Color(0.9, 0.95, 0.8))
	draw_circle(Vector2(7, -4), 3.5, Color(0.9, 0.95, 0.8))
	if frescura < 40.0:
		draw_arc(Vector2.ZERO, radius + 3, 0.0, TAU * frescura / 100.0, 16, Color(0.6, 0.8, 0.3), 2.0)
