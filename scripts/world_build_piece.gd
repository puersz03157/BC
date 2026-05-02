class_name WorldBuildPiece
extends Node2D
## 木地板（無碰撞，可行走）、木牆（實心方格）、木門（關閉擋人；F 互動開啟可通過）。

enum PieceKind { FLOOR, WALL, DOOR }

const HALF := GameConstants.GRID_SIZE * 0.5

@export var piece_kind: PieceKind = PieceKind.FLOOR

var door_open: bool = false

var _solid: StaticBody2D
var _collision: CollisionShape2D
var _door_visual: Node2D


func _ready() -> void:
	add_to_group("build_piece")
	match piece_kind:
		PieceKind.FLOOR:
			z_index = 0
			_build_floor_art()
		PieceKind.WALL:
			z_index = 0
			_build_wall_art()
			_add_solid_collision(GameConstants.GRID_SIZE, GameConstants.GRID_SIZE)
		PieceKind.DOOR:
			z_index = 1
			add_to_group("interactive_door")
			_build_door_art()
			_add_solid_collision(GameConstants.GRID_SIZE, GameConstants.GRID_SIZE)


func _add_solid_collision(w: float, h: float) -> void:
	_solid = StaticBody2D.new()
	_solid.collision_layer = 1
	_solid.collision_mask = 0
	_collision = CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(w, h)
	_collision.shape = sh
	_solid.add_child(_collision)
	add_child(_solid)


func _rect_poly(w2: float, h2: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-w2, -h2), Vector2(w2, -h2), Vector2(w2, h2), Vector2(-w2, h2),
	])


func _build_floor_art() -> void:
	var base := Polygon2D.new()
	base.polygon = _rect_poly(HALF, HALF)
	base.color = Color(0.58, 0.42, 0.28, 0.92)
	add_child(base)
	var inner := Polygon2D.new()
	inner.polygon = _rect_poly(HALF - 3.0, HALF - 3.0)
	inner.color = Color(0.68, 0.52, 0.36, 0.55)
	add_child(inner)
	# 輕微木板紋
	for i in range(-1, 2):
		var ln := Line2D.new()
		ln.width = 1.0
		ln.default_color = Color(0.45, 0.32, 0.2, 0.35)
		var x := float(i) * 11.0
		ln.points = PackedVector2Array([Vector2(x, -HALF + 4), Vector2(x, HALF - 4)])
		add_child(ln)


func _build_wall_art() -> void:
	var shell := Polygon2D.new()
	shell.polygon = _rect_poly(HALF, HALF)
	shell.color = Color(0.38, 0.26, 0.16, 1.0)
	add_child(shell)
	var inset := Polygon2D.new()
	inset.polygon = _rect_poly(HALF - 2.5, HALF - 2.5)
	inset.color = Color(0.48, 0.34, 0.22, 1.0)
	add_child(inset)
	# 直向木板條
	for i in range(3):
		var plank := Polygon2D.new()
		var x0 := -HALF + 6.0 + float(i) * 12.0
		plank.polygon = PackedVector2Array([
			Vector2(x0, -HALF + 5), Vector2(x0 + 8, -HALF + 5),
			Vector2(x0 + 8, HALF - 5), Vector2(x0, HALF - 5),
		])
		plank.color = Color(0.55, 0.38, 0.24, 1.0)
		add_child(plank)
	var cap := Line2D.new()
	cap.width = 2.0
	cap.default_color = Color(0.28, 0.18, 0.1, 1.0)
	cap.points = PackedVector2Array([Vector2(-HALF, -HALF), Vector2(HALF, -HALF)])
	add_child(cap)
	var cap2 := Line2D.new()
	cap2.width = 2.0
	cap2.default_color = Color(0.28, 0.18, 0.1, 1.0)
	cap2.points = PackedVector2Array([Vector2(-HALF, HALF), Vector2(HALF, HALF)])
	add_child(cap2)


func _build_door_art() -> void:
	_door_visual = Node2D.new()
	_door_visual.position = Vector2(-HALF, 0.0)
	add_child(_door_visual)
	var slab := Polygon2D.new()
	var dh := 17.0
	slab.polygon = PackedVector2Array([
		Vector2(0, -dh), Vector2(GameConstants.GRID_SIZE, -dh),
		Vector2(GameConstants.GRID_SIZE, dh), Vector2(0, dh),
	])
	slab.color = Color(0.5, 0.34, 0.22, 1.0)
	_door_visual.add_child(slab)
	var inset := Polygon2D.new()
	inset.polygon = PackedVector2Array([
		Vector2(3, -dh + 3), Vector2(GameConstants.GRID_SIZE - 3, -dh + 3),
		Vector2(GameConstants.GRID_SIZE - 3, dh - 3), Vector2(3, dh - 3),
	])
	inset.color = Color(0.58, 0.4, 0.26, 1.0)
	_door_visual.add_child(inset)
	# 拉把（右側小圓形用多邊形近似）
	var handle := Polygon2D.new()
	var hx := GameConstants.GRID_SIZE - 11.0
	var hy := 2.0
	var hr := 3.5
	handle.polygon = _circle_poly(Vector2(hx, hy), hr, 10)
	handle.color = Color(0.85, 0.72, 0.35, 1.0)
	_door_visual.add_child(handle)
	var ring := Line2D.new()
	ring.width = 1.5
	ring.default_color = Color(0.35, 0.28, 0.15, 1.0)
	ring.points = _circle_points(Vector2(hx, hy), hr + 0.8, 12)
	_door_visual.add_child(ring)


func _circle_poly(center: Vector2, r: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


func _circle_points(center: Vector2, r: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments + 1):
		var a := TAU * float(i) / float(segments)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	return pts


func toggle_door() -> void:
	if piece_kind != PieceKind.DOOR:
		return
	door_open = not door_open
	if _collision:
		_collision.set_deferred(&"disabled", door_open)
	if _door_visual:
		_door_visual.rotation_degrees = -88.0 if door_open else 0.0
		_door_visual.modulate = Color(1.0, 1.0, 1.0, 0.42) if door_open else Color.WHITE


static func refund_wood_for_kind(k: PieceKind) -> int:
	match k:
		PieceKind.FLOOR:
			return GameConstants.BUILD_FLOOR_WOOD
		PieceKind.WALL:
			return GameConstants.BUILD_FENCE_WOOD
		PieceKind.DOOR:
			return GameConstants.BUILD_DOOR_WOOD
		_:
			return 0
