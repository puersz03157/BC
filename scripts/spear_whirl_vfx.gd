class_name SpearWhirlVfx
extends Node2D
## 木槍圓形 AOE 範圍提示（半徑＝技能判定半徑）。

var _radius: float = 80.0
var _t: float = 0.0
var _dur: float = 0.32


func begin(center: Vector2, radius_px: float) -> void:
	global_position = center
	_radius = maxf(8.0, radius_px)
	_t = 0.0
	z_index = 430
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= _dur:
		queue_free()


func _draw() -> void:
	var u := clampf(_t / _dur, 0.0, 1.0)
	var a := (1.0 - u) * (1.0 - u)
	var fill := Color(0.95, 0.78, 0.35, a * 0.22)
	var ring := Color(1.0, 0.92, 0.55, a * 0.75)
	draw_circle(Vector2.ZERO, _radius * (0.82 + 0.18 * u), fill)
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, ring, 3.2, true)
