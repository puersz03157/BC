class_name BuildGridOverlay
extends Node2D
## 建造／營火放置時在世界座標繪製對齊格線與預覽格。

@export var grid_size: float = 40.0
var enabled: bool = false
var preview_center: Vector2 = Vector2.ZERO
var preview_size: Vector2 = Vector2(40, 40)
var preview_fill: Color = Color(1, 1, 1, 0.18)
var preview_outline: Color = Color(0.95, 0.92, 0.75, 0.55)
var grid_color: Color = Color(0.88, 0.93, 1.0, 0.12)


func _process(_delta: float) -> void:
	if enabled:
		queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var half := vp / (2.0 * cam.zoom)
	var center := cam.global_position
	var tl := center - half
	var br := center + half
	var g := grid_size
	var x0 := floorf(tl.x / g) * g
	var y0 := floorf(tl.y / g) * g
	var x1 := ceilf(br.x / g) * g
	var y1 := ceilf(br.y / g) * g
	var gx := x0
	while gx <= x1 + 0.01:
		draw_line(Vector2(gx, y0), Vector2(gx, y1), grid_color, 1.0)
		gx += g
	var gy := y0
	while gy <= y1 + 0.01:
		draw_line(Vector2(x0, gy), Vector2(x1, gy), grid_color, 1.0)
		gy += g
	var half_prev := preview_size * 0.5
	## preview_size 為 (0,0) 時不畫預覽格（例如營火放置：避免與營火疊成方框）。
	if preview_size.length_squared() > 1.0:
		draw_rect(Rect2(preview_center - half_prev, preview_size), preview_fill, true)
		draw_rect(Rect2(preview_center - half_prev, preview_size), preview_outline, false, 2.0)
