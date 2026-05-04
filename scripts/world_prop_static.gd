class_name WorldPropStatic
extends StaticBody2D
enum PropKind { TREE, ROCK }

@export var prop_kind: PropKind = PropKind.TREE
var hit_points: int = 1
## 讀檔還原用：在加入場景樹前設為 >=0 則覆寫預設血量。
var _restore_hit_points: int = -1
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	if _restore_hit_points >= 0:
		hit_points = _restore_hit_points
		_restore_hit_points = -1
	elif prop_kind == PropKind.TREE:
		hit_points = GameConstants.TREE_HP
	else:
		hit_points = GameConstants.ROCK_HP
	var sh := CircleShape2D.new()
	sh.radius = GameConstants.TREE_RADIUS if prop_kind == PropKind.TREE else GameConstants.ROCK_RADIUS
	var col := CollisionShape2D.new()
	col.shape = sh
	add_child(col)
	VisualRegistry.ensure_baked()
	_sprite = Sprite2D.new()
	_sprite.texture = VisualRegistry.tree_tex() if prop_kind == PropKind.TREE else VisualRegistry.rock_tex()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.offset = Vector2(0, -6) if prop_kind == PropKind.TREE else Vector2(0, -2)
	add_child(_sprite)


func apply_hit_shake() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector2(randf_range(-3, 3), randf_range(-3, 3)), 0.04)
	tw.tween_property(self, "position", position, 0.04)


func take_hit() -> Dictionary:
	## 回傳 { "destroyed": bool, "kind": PropKind }
	hit_points -= 1
	apply_hit_shake()
	if _sprite:
		_sprite.modulate = Color(1.2, 1.2, 1.2, 1.0)
		var tw2 := create_tween()
		tw2.tween_property(_sprite, "modulate", Color.WHITE, 0.12)
	if hit_points <= 0:
		return { "destroyed": true, "kind": prop_kind }
	return { "destroyed": false, "kind": prop_kind }
