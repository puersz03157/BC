extends StaticBody2D
## 標記、繪製與碰撞（layer 1，與樹石一致）。

var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("campfire")
	collision_layer = 1
	collision_mask = 0
	z_index = 1
	var sh := CircleShape2D.new()
	sh.radius = GameConstants.CAMPFIRE_COLLISION_RADIUS
	var col := CollisionShape2D.new()
	col.shape = sh
	add_child(col)
	VisualRegistry.ensure_baked()
	_sprite = Sprite2D.new()
	_sprite.texture = VisualRegistry.campfire_tex()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	add_child(_sprite)


func _process(_delta: float) -> void:
	if _sprite:
		var pulse := 0.92 + 0.08 * sin(Time.get_ticks_msec() * 0.012)
		_sprite.modulate = Color(pulse, pulse * 0.95, 0.88, 1.0)
