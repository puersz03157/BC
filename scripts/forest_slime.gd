class_name ForestSlime
extends CharacterBody2D
## 翠幽之森 Lv1 主動怪：追最近可見玩家；死亡掉落黏液拾取物。

const CHASE_SPEED := 95.0
const HIT_POINTS_MAX := 3
const COLLIDE_R := 11.0

const TEX_CANDIDATES: Array[String] = [
	"res://assets/characters/Cute_Fantasy_Enemies/Slime/Slime_Small/Slime_Small_Green.png",
	"res://assets/characters/Cute_Fantasy_Enemies/Slimes/Slime.png",
	"res://assets/characters/Cute_Fantasy_Enemies/Slime/Slime.png",
	"res://assets/characters/Cute_Fantasy_Enemies/Green_Slime.png",
	"res://assets/characters/Cute_Fantasy_Enemies/slime.png",
]

var hit_points: int = HIT_POINTS_MAX
## 用於受擊閃爍：Sprite2D 或 Polygon2D（程式史萊姆）。
var _vis_hit: CanvasItem = null
var _hp_bar: TextureProgressBar = null
var _player_hurt_tick: float = 0.0
var _anim_t: float = 0.0


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
			if _try_setup_slime_sheet(tex):
				break
			var sp := Sprite2D.new()
			sp.texture = tex
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sp.centered = true
			var sz := sp.texture.get_size() as Vector2
			var mx := maxf(sz.x, sz.y)
			if mx > 0.001:
				sp.scale = Vector2.ONE * (22.0 / mx)
			add_child(sp)
			_vis_hit = sp
			break
	if _vis_hit == null:
		var blob := Polygon2D.new()
		blob.polygon = _circle_poly(10, 14)
		blob.color = Color(0.35, 0.82, 0.42, 0.95)
		add_child(blob)
		_vis_hit = blob
		var eye := Polygon2D.new()
		eye.polygon = PackedVector2Array([Vector2(-4, -3), Vector2(-1, -3), Vector2(-2, -1)])
		eye.color = Color(0.08, 0.12, 0.1, 1.0)
		add_child(eye)
		var eye2 := Polygon2D.new()
		eye2.polygon = PackedVector2Array([Vector2(1, -3), Vector2(4, -3), Vector2(2, -1)])
		eye2.color = Color(0.08, 0.12, 0.1, 1.0)
		add_child(eye2)
	var col := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = COLLIDE_R
	col.shape = sh
	add_child(col)
	_hp_bar = TextureProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(40, 10)
	_hp_bar.size = Vector2(40, 10)
	_hp_bar.position = Vector2(-20, -28)
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


func _try_setup_slime_sheet(tex: Texture2D) -> bool:
	var szf := tex.get_size() as Vector2
	var tw := int(szf.x)
	var th := int(szf.y)
	var hf := 0
	var vf := 0
	if tw == 128 and th == 64:
		hf = 8
		vf = 4
	elif tw == 256 and th == 128:
		hf = 8
		vf = 4
	else:
		return false
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	sp.hframes = hf
	sp.vframes = vf
	sp.frame = 0
	var cell := float(tw) / float(hf)
	var target := 22.0
	sp.scale = Vector2.ONE * (target / cell)
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


func _circle_poly(r: float, segs: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segs + 1:
		var a := TAU * float(i) / float(segs)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _sync_slime_sheet_frame() -> void:
	if _vis_hit == null or not (_vis_hit is Sprite2D):
		return
	var sp := _vis_hit as Sprite2D
	if sp.hframes <= 1 or sp.vframes <= 1:
		return
	var hf := sp.hframes
	var moving := velocity.length_squared() > 25.0
	if moving:
		var i := int(_anim_t * 9.0) % 7
		sp.frame = hf * 1 + i
	else:
		var j := int(_anim_t * 7.0) % 4
		sp.frame = j


func _physics_process(delta: float) -> void:
	_anim_t += delta
	var tgt := _nearest_visible_player_pos()
	var to_v := tgt - global_position
	if to_v.length_squared() > 12.0:
		velocity = to_v.normalized() * CHASE_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_sync_slime_sheet_frame()
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


func _nearest_visible_player_pos() -> Vector2:
	var best: Vector2 = global_position + Vector2.RIGHT * 80.0
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
	return best


func _flash_hit() -> void:
	if _vis_hit == null:
		return
	_vis_hit.modulate = Color(1.35, 1.35, 1.35, 1.0)
	var tw := create_tween()
	tw.tween_property(_vis_hit, "modulate", Color.WHITE, 0.1)


func take_weapon_hit(amount: int) -> Dictionary:
	hit_points -= amount
	_sync_mob_hp_bar()
	_flash_hit()
	if hit_points <= 0:
		_spawn_slime_drops()
		queue_free()
		return { "destroyed": true }
	return { "destroyed": false }


func _spawn_slime_drops() -> void:
	var main := get_tree().get_first_node_in_group("game_main")
	if main == null or not main.has_method("_spawn_loose"):
		return
	var n := randi_range(1, 2)
	for i in n:
		var off := Vector2(randf_range(-14.0, 14.0), randf_range(-14.0, 14.0))
		main.call("_spawn_loose", LoosePickup.PickKind.SLIME, global_position + off, false)
