class_name Unit
extends CharacterBody2D
## Base común de Abdón, los Finaos y los entes: vida, aturdimiento y dibujo provisorio.

signal died(unit: Unit)

## Capas de colisión (valores de bit).
const LAYER_TERRAIN := 1
const LAYER_PLAYER := 2
const LAYER_FINAO := 4
const LAYER_ENEMY := 8
const LAYER_BARRICADE := 16

var max_hp := 100.0
var hp := 100.0
var radius := 22.0
var color := Color.WHITE
var display_name := ""
var stun_time := 0.0
var flash := 0.0
var dead := false
var world: Node
var label: Label
## Sprite pixel art en tres vistas (frente, espalda y lado), con dos cuadros cada una:
## quieto y paso. El lado mira a la derecha y se voltea. Si no hay sprite, se dibuja un círculo.
const VIEWS := ["frente", "espalda", "lado"]
var sprite_name := ""
var frames: Array[Texture2D] = []
var views := {}
var attack_views := {}
var view := "frente"
## Tiempo que queda mostrando el cuadro de ataque, y hacia dónde.
var attack_pose := 0.0
var attack_dir := Vector2.ZERO
var sprite_scale := 1.5
var face_left := false
var walk_time := 0.0
## Hacia dónde mira; si queda en cero se usa la velocidad.
var look := Vector2.ZERO
## Altura a la que flota sobre su sombra (el Chonchón).
var float_height := 0.0
var float_time := 0.0

static var _texture_cache := {}


static func texture(sprite: String) -> Texture2D:
	if not _texture_cache.has(sprite):
		var path := "res://assets/sprites/%s.png" % sprite
		_texture_cache[sprite] = load(path) if ResourceLoader.exists(path) else null
	return _texture_cache[sprite]


func setup_body(layer: int, mask: int) -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = layer
	collision_mask = mask
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.8
	shape.shape = circle
	add_child(shape)
	if sprite_name != "":
		for v in VIEWS:
			var pair: Array[Texture2D] = []
			for n in ["%s_%s" % [sprite_name, v], "%s_%s_paso" % [sprite_name, v]]:
				var tex := texture(n)
				if tex != null:
					pair.append(tex)
			if not pair.is_empty():
				views[v] = pair
			var atk := texture("%s_%s_ataque" % [sprite_name, v])
			if atk != null:
				attack_views[v] = atk
		if views.has("frente"):
			frames = views["frente"]
	label = Label.new()
	label.text = display_name
	label.size = Vector2(240, 30)
	label.position = Vector2(-120, -radius - 44 if frames.is_empty() else radius - frames[0].get_height() * sprite_scale - 34.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)


func take_damage(amount: float, source: Node = null) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.12
	Audio.play("golpe", -8.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		died.emit(self)
		_on_death(source)


func _on_death(_source: Node) -> void:
	fall()


## Muestra el cuadro de ataque un momento, mirando hacia `dir` si se da.
func show_attack(dir := Vector2.ZERO) -> void:
	attack_pose = 0.22
	attack_dir = dir


## La caída al morir: se ladea, se apaga y desaparece. Deja de contar para todo
## (grupos y choques) desde el primer momento.
func fall() -> void:
	dead = true
	for g in get_groups():
		if not str(g).begins_with("_"):
			remove_from_group(g)
	collision_layer = 0
	collision_mask = 0
	if label != null:
		label.visible = false
	var side := -1.0 if face_left else 1.0
	var tween := create_tween()
	tween.tween_property(self, "rotation", side * PI / 2.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)


func stun(seconds: float) -> void:
	stun_time = maxf(stun_time, seconds)


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func tick_status(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	stun_time = maxf(0.0, stun_time - delta)
	attack_pose = maxf(0.0, attack_pose - delta)
	float_time += delta
	var dir := look if look.length() > 0.1 else velocity
	if attack_pose > 0.0 and attack_dir.length() > 0.1:
		dir = attack_dir
	if dir.length() > 5.0 or look.length() > 0.1:
		if absf(dir.y) > absf(dir.x) * 1.15:
			view = "espalda" if dir.y < 0.0 else "frente"
		else:
			view = "lado"
			face_left = dir.x < 0.0
		if views.has(view):
			frames = views[view]
		elif views.has("frente"):
			frames = views["frente"]
	walk_time = walk_time + delta if velocity.length() > 10.0 else 0.0
	queue_redraw()


func _draw() -> void:
	var top := -radius
	if frames.is_empty():
		var body_color := Color.WHITE if flash > 0.0 else color
		draw_circle(Vector2(0, radius * 0.7), radius * 0.9, Color(0, 0, 0, 0.25))
		draw_circle(Vector2.ZERO, radius, body_color)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.7), 3.0)
	else:
		# Sombra en elipse y el sprite con los pies en el borde inferior del cuerpo.
		draw_set_transform(Vector2(0, radius - 2.0), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, radius * 1.1, Color(0, 0, 0, 0.3))
		var step := int(walk_time * 7.0) % 2
		var tex: Texture2D = frames[mini(step, frames.size() - 1)]
		if attack_pose > 0.0 and attack_views.has(view):
			tex = attack_views[view]
			step = 0
		var h := tex.get_height() * sprite_scale
		var bob := -sprite_scale if step == 1 else 0.0
		if float_height > 0.0:
			bob = -float_height + sin(float_time * 4.0) * 4.0
		var flip := face_left and view == "lado"
		draw_set_transform(Vector2(0, radius - h + bob), 0.0, Vector2(-sprite_scale if flip else sprite_scale, sprite_scale))
		var tint := Color(2.5, 2.5, 2.5) if flash > 0.0 else Color.WHITE
		draw_texture(tex, Vector2(-tex.get_width() / 2.0, 0.0), tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		top = radius - h
	if hp < max_hp:
		var w := radius * 2.4
		draw_rect(Rect2(-w / 2.0, top - 12, w, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w / 2.0, top - 12, w * hp / max_hp, 6), Color(0.85, 0.2, 0.2))
	if stun_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 6, 0.0, TAU, 24, Color(1, 0.9, 0.2), 3.0)
