class_name Interactable
extends Node2D
## Algo con lo que Abdón puede interactuar. El jugador elige el más cercano dentro de su radio.

var prompt := "Interactuar"
var interact_radius := 120.0
var world: Node
## Tamaño del dibujo provisorio.
var size := Vector2(120, 90)
var fill := Color(0.45, 0.32, 0.22)
var title := ""
var title_label: Label
## Sprite pixel art. Si no hay, se dibuja un rectángulo del color `fill`.
var sprite_name := ""
var sprite_scale := 1.5


func _ready() -> void:
	add_to_group("interactables")
	title_label = Label.new()
	title_label.size = Vector2(320, 30)
	title_label.position = Vector2(-160, -size.y / 2.0 - 40)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 6)
	add_child(title_label)
	title_label.text = title


func can_interact(_player: Node) -> bool:
	return true


func get_prompt() -> String:
	return prompt


func interact(_player: Node) -> void:
	pass


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var tex := Unit.texture(sprite_name) if sprite_name != "" else null
	if tex != null:
		var s := Vector2(tex.get_size()) * sprite_scale
		draw_set_transform(Vector2(0, s.y / 2.0 - 4.0), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, s.x * 0.45, Color(0, 0, 0, 0.25))
		draw_set_transform(-s / 2.0, 0.0, Vector2(sprite_scale, sprite_scale))
		draw_texture(tex, Vector2.ZERO)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var r := Rect2(-size / 2.0, size)
	draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.25))
	draw_rect(r, fill)
	draw_rect(r, Color(0, 0, 0, 0.7), false, 3.0)
