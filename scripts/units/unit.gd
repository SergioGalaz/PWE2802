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


func setup_body(layer: int, mask: int) -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = layer
	collision_mask = mask
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.8
	shape.shape = circle
	add_child(shape)
	label = Label.new()
	label.text = display_name
	label.size = Vector2(240, 30)
	label.position = Vector2(-120, -radius - 44)
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
	queue_redraw()


func _draw() -> void:
	var body_color := Color.WHITE if flash > 0.0 else color
	draw_circle(Vector2(0, radius * 0.7), radius * 0.9, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0, 0, 0, 0.7), 3.0)
	if hp < max_hp:
		var w := radius * 2.4
		draw_rect(Rect2(-w / 2.0, -radius - 12, w, 6), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w / 2.0, -radius - 12, w * hp / max_hp, 6), Color(0.85, 0.2, 0.2))
	if stun_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 6, 0.0, TAU, 24, Color(1, 0.9, 0.2), 3.0)
