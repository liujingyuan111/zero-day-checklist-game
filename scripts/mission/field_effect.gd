class_name FieldEffect
extends Node2D

var radius: float
var duration: float
var elapsed := 0.0
var tint: Color
var highlight: bool


static func spawn(parent: Node, at: Vector2, size_px: float, life: float, color: Color, marker := false) -> void:
	var fx := FieldEffect.new()
	fx.position = at
	fx.radius = size_px
	fx.duration = life
	fx.tint = color
	fx.highlight = marker
	fx.z_index = 8
	parent.add_child(fx)


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var color := Color(tint, 1.0 - t)
	if highlight:
		for i in range(4):
			var angle := i * PI / 2.0
			draw_arc(Vector2.ZERO, radius + 4.0 * t, angle + 0.12, angle + 1.1, 12, color, 3)
	else:
		draw_arc(Vector2.ZERO, maxf(1.0, radius * (1.0 - pow(1.0 - t, 2.0))), 0, TAU, 80, color, 2.5)
