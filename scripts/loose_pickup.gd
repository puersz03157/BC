class_name LoosePickup
extends Area2D
enum PickKind { WOOD, STONE, SEED }

@export var pick_kind: PickKind = PickKind.WOOD
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = true
	var sh := CircleShape2D.new()
	sh.radius = GameConstants.LOOSE_RADIUS
	var col := CollisionShape2D.new()
	col.shape = sh
	add_child(col)
	body_entered.connect(_on_body_entered)
	VisualRegistry.ensure_baked()
	_sprite = Sprite2D.new()
	_sprite.texture = VisualRegistry.loose_tex(int(pick_kind))
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.offset = Vector2(0, -2)
	add_child(_sprite)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var main := get_tree().get_first_node_in_group("game_main")
	if main != null and main.has_method("on_loose_pickup"):
		main.on_loose_pickup(self)
