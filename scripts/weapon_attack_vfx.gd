class_name WeaponAttackVfx
extends Node2D
## 主手採集（F／Space）時短暫顯示的攻擊範圍／軌跡；置於 entities 下與世界座標對齊。

var _elapsed: float = 0.0
var _duration: float = 0.22
var _reach: float = 64.0
var _weapon: StringName = &""
var _muted: bool = false


func begin(origin: Vector2, toward_world: Vector2, reach_px: float, weapon: StringName, on_cooldown: bool) -> void:
	global_position = origin
	var d := toward_world - origin
	if d.length_squared() < 4.0:
		d = Vector2.RIGHT * 8.0
	rotation = d.angle()
	_reach = maxf(24.0, reach_px)
	_weapon = weapon
	_muted = on_cooldown
	_duration = 0.14 if on_cooldown else 0.24
	_elapsed = 0.0
	z_index = 420
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _duration:
		queue_free()


func _alpha_base() -> float:
	var t := clampf(1.0 - _elapsed / _duration, 0.0, 1.0)
	var a := t * t
	return a * (0.32 if _muted else 0.78)


func _draw() -> void:
	var ab := _alpha_base()
	match _weapon:
		&"wood_spear":
			_draw_spear(ab)
		&"iron_sword":
			_draw_sword_swing(ab)
		_:
			_draw_axe_swing(ab)


func _draw_spear(ab: float) -> void:
	## 狹長戳刺帶：沿面朝方向，長度＝有效採集距離（與邏輯 reach 一致）。
	var L := _reach
	var hw := 5.0
	var c := Color(0.92, 0.72, 0.38, ab)
	var edge := Color(1.0, 0.95, 0.82, ab * 0.95)
	var poly := PackedVector2Array([
		Vector2(6, -hw), Vector2(L, -hw * 0.35), Vector2(L, hw * 0.35), Vector2(6, hw),
	])
	draw_colored_polygon(poly, c)
	draw_polyline(poly + PackedVector2Array([poly[0]]), edge, 1.6, true)
	## 槍尖端點標示最遠可判定距離
	draw_line(Vector2(L - 10.0, 0.0), Vector2(L + 3.0, 0.0), Color(1.0, 0.88, 0.45, ab * 0.85), 2.4, true)


func _draw_sword_swing(ab: float) -> void:
	## 較寬的扇形揮擊，半徑略小於有效距離以表現「近距快攻」。
	var r := _reach * 0.96
	var spread := 0.95
	var segs := 14
	var poly := PackedVector2Array([Vector2.ZERO])
	for i in segs + 1:
		var u := lerpf(-spread, spread, float(i) / float(segs))
		poly.append(Vector2(cos(u), sin(u)) * r)
	draw_colored_polygon(poly, Color(0.75, 0.78, 0.92, ab * 0.55))
	draw_polyline(poly + PackedVector2Array([Vector2.ZERO]), Color(0.95, 0.96, 1.0, ab), 2.2, true)


func _draw_axe_swing(ab: float) -> void:
	var r := _reach * 0.94
	var spread := 0.62
	var segs := 12
	var poly := PackedVector2Array([Vector2.ZERO])
	for i in segs + 1:
		var u := lerpf(-spread, spread, float(i) / float(segs))
		poly.append(Vector2(cos(u), sin(u)) * r)
	draw_colored_polygon(poly, Color(0.88, 0.62, 0.38, ab * 0.5))
	draw_polyline(poly + PackedVector2Array([Vector2.ZERO]), Color(1.0, 0.9, 0.7, ab * 0.9), 2.0, true)
