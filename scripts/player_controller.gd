class_name PlayerController
extends CharacterBody2D
## 1P：WASD。2P：雙人時滑鼠右鍵拖曳更新移動目標，否則方向鍵。

@export var player_index: int = 0
var mouse_target: Vector2 = Vector2.ZERO
var use_mouse_target: bool = false
## 單人 Web／手機：指尖導航目標（鍵盤 WASD 會取消）。
var touch_nav_active: bool = false
var touch_nav_target: Vector2 = Vector2.ZERO
var _sprite: Sprite2D


func _ready() -> void:
	add_to_group("player")
	set_meta("player_index", player_index)
	collision_layer = 2
	collision_mask = 1
	VisualRegistry.ensure_baked()
	_sprite = Sprite2D.new()
	_sprite.texture = VisualRegistry.player_tex(player_index)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.offset = Vector2(0, -12)
	add_child(_sprite)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	if player_index == 0:
		dir.x = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
		dir.y = float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
		if dir.length_squared() > 0.0001:
			touch_nav_active = false
		elif touch_nav_active:
			var to_t := touch_nav_target - global_position
			if to_t.length() > 14.0:
				dir = to_t.normalized()
	else:
		if use_mouse_target and mouse_target != Vector2.ZERO:
			var to_tgt := mouse_target - global_position
			if to_tgt.length() > 8.0:
				dir = to_tgt.normalized()
		if dir == Vector2.ZERO:
			dir.x = float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
			dir.y = float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))
	if dir.length_squared() > 0.0001:
		velocity = dir.normalized() * GameConstants.PLAYER_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func set_mouse_nav_target(world: Vector2, active: bool) -> void:
	mouse_target = world
	use_mouse_target = active


func set_touch_navigation(active: bool, world_pos: Vector2 = Vector2.ZERO) -> void:
	touch_nav_active = active
	if active:
		touch_nav_target = world_pos


func _draw() -> void:
	# 腳下小陰影，增加落地感
	draw_circle(Vector2(0, 12), 11.0, Color(0, 0, 0, 0.24))
