class_name ForestMushroom
extends CharacterBody2D
## 翠幽之森主動怪：僅在較短距離內鎖敵並追擊；死亡掉落野菇。

const CHASE_SPEED := 78.0
## 進入／離開追擊的平方距離（離開要大於進入，避免邊界抖動）。
const AGGRO_ENTER_SQ := 76.0 * 76.0
const AGGRO_EXIT_SQ := 104.0 * 104.0
const HIT_POINTS_MAX := 5
const COLLIDE_R := 12.0

const TEX_CANDIDATES: Array[String] = [
	"res://assets/characters/Cute_Fantasy_Enemies/Bombschroom/Bombschroom.png",
	"res://assets/characters/Cute_Fantasy_Enemies/Mushroom/Mushroom.png",
	"res://assets/characters/Cute_Fantasy_Enemies/Mushrooms/Mushroom.png",
	"res://assets/characters/Cute_Fantasy_Enemies/Mushroom/Wild_Mushroom.png",
	"res://assets/characters/Cute_Fantasy_Enemies/mushroom.png",
]

var hit_points: int = HIT_POINTS_MAX
var _vis_hit: CanvasItem = null
var _hp_bar: TextureProgressBar = null
var _player_hurt_tick: float = 0.0
var _aggro_active: bool = false
var _hit_flash_tween: Tween = null


func _ready() -> void:
	add_to_group("melee_monster")
	collision_layer = 2
	collision_mask = 1
	z_index = 2
	for p in TEX_CANDIDATES:
		if not ResourceLoader.exists(p):
			continue
		var res: Variant = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
		if res is Texture2D:
			var tex := res as Texture2D
			if _try_setup_mushroom_sheet(tex):
				break
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.centered = true
			var sz := sp.texture.get_size() as Vector2
			var mx := maxf(sz.x, sz.y)
			if mx > 0.001:
				sp.scale = Vector2.ONE * (26.0 / mx)
			add_child(sp)
			_vis_hit = sp
			break
	if _vis_hit == null:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(-10, 4), Vector2(-6, -8), Vector2(6, -10), Vector2(12, 0),
			Vector2(8, 10), Vector2(-4, 10),
		])
		poly.color = Color(0.55, 0.38, 0.28, 1.0)
		add_child(poly)
		_vis_hit = poly
	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = COLLIDE_R
	col.shape = sh
	add_child(col)
	_hp_bar = TextureProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(44, 10)
	_hp_bar.size = Vector2(44, 10)
	_hp_bar.position = Vector2(-22, -34)
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = float(HIT_POINTS_MAX)
	_hp_bar.value = float(hit_points)
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if CuteFantasyUiBars.setup_monster_hp_bar(_hp_bar):
		add_child(_hp_bar)
		_sync_mob_hp_bar()
		_ensure_hp_bar_sync_after_ready.call_deferred()
	else:
		_hp_bar.queue_free()
		_hp_bar = null


func _try_setup_mushroom_sheet(tex: Texture2D) -> bool:
	## Bombschroom 主表多數格子會輪播到全透明幀 → 看起來「一下有圖一下沒圖」。
	## 改裁固定一格成獨立 Texture2D，不再用 hframes 切幀。
	var szf := tex.get_size() as Vector2
	var tw := int(szf.x)
	var th := int(szf.y)
	if tw != 176 or th != 336:
		return false
	var img := tex.get_image()
	if img == null:
		return false
	var cell := 16
	var r := Rect2i(0, 0, cell, cell)
	var piece := img.get_region(r)
	var sub := ImageTexture.create_from_image(piece)
	var sp := Sprite2D.new()
	sp.texture = sub
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	var target := 26.0
	sp.scale = Vector2.ONE * (target / float(cell))
	add_child(sp)
	_vis_hit = sp
	return true


func _ensure_hp_bar_sync_after_ready() -> void:
	if not is_inside_tree() or _hp_bar == null:
		return
	_sync_mob_hp_bar()


func _sync_mob_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 100.0
	_hp_bar.rounded = false
	_hp_bar.step = 0.01
	var hp := clampi(hit_points, 0, HIT_POINTS_MAX)
	_hp_bar.value = 100.0 * float(hp) / float(HIT_POINTS_MAX)


func _chase_target_pos() -> Vector2:
	var best: Vector2 = global_position
	var best_d := 1.0e12
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node2D):
			continue
		if not p.visible:
			continue
		var n := p as Node2D
		var d := global_position.distance_squared_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n.global_position
	if best_d > 1.0e11:
		_aggro_active = false
		return global_position
	if _aggro_active:
		if best_d > AGGRO_EXIT_SQ:
			_aggro_active = false
	else:
		if best_d <= AGGRO_ENTER_SQ:
			_aggro_active = true
	if _aggro_active:
		return best
	return global_position


func _physics_process(delta: float) -> void:
	var tgt := _chase_target_pos()
	var to_v := tgt - global_position
	if to_v.length_squared() > 12.0:
		velocity = to_v.normalized() * CHASE_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_player_hurt_tick = maxf(0.0, _player_hurt_tick - delta)
	var best_d := 1.0e12
	var best_slot := 0
	for p in get_tree().get_nodes_in_group("player"):
		if not (p is Node2D):
			continue
		if not (p as Node2D).visible:
			continue
		var n2 := p as Node2D
		var d := global_position.distance_squared_to(n2.global_position)
		if d < best_d:
			best_d = d
			best_slot = int(n2.get_meta("player_index", 0))
	if best_d < 18.0 * 18.0 and _player_hurt_tick <= 0.0:
		var main := get_tree().get_first_node_in_group("game_main")
		if main != null and main.has_method("apply_enemy_contact_damage"):
			main.call("apply_enemy_contact_damage", 6.0, best_slot)
			_player_hurt_tick = 1.05


func _flash_hit() -> void:
	if _vis_hit == null:
		return
	if is_instance_valid(_hit_flash_tween):
		_hit_flash_tween.kill()
	_hit_flash_tween = null
	_vis_hit.modulate = Color(1.22, 1.12, 1.08, 1.0)
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(_vis_hit, "modulate", Color.WHITE, 0.1)


func take_weapon_hit(amount: int) -> Dictionary:
	hit_points -= amount
	_sync_mob_hp_bar()
	_flash_hit()
	if hit_points <= 0:
		_spawn_mushroom_drops()
		queue_free()
		return { "destroyed": true }
	return { "destroyed": false }


func _spawn_mushroom_drops() -> void:
	var main := get_tree().get_first_node_in_group("game_main")
	if main == null or not main.has_method("_spawn_loose"):
		return
	var n := randi_range(1, 2)
	for i in n:
		var off := Vector2(randf_range(-12.0, 12.0), randf_range(-12.0, 12.0))
		main.call("_spawn_loose", LoosePickup.PickKind.MUSHROOM, global_position + off, false)
