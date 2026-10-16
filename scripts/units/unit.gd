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
## Sprite pixel art de 32 píxeles (dos cuadros: quieto y paso). Si no hay, se dibuja un círculo.
var sprite_name := ""
var frames: Array[Texture2D] = []
var sprite_scale := 2.0
var face_left := false
var walk_time := 0.0

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
		for n in [sprite_name, sprite_name + "_paso"]:
			var tex := texture(n)
			if tex != null:
				frames.append(tex)
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
	queue_free()


func stun(seconds: float) -> void:
	stun_time = maxf(stun_time, seconds)


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)


func tick_status(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	stun_time = maxf(0.0, stun_time - delta)
	if absf(velocity.x) > 5.0:
		face_left = velocity.x < 0.0
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
		var h := tex.get_height() * sprite_scale
		var bob := -sprite_scale if step == 1 else 0.0
		draw_set_transform(Vector2(0, radius - h + bob), 0.0, Vector2(-sprite_scale if face_left else sprite_scale, sprite_scale))
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
