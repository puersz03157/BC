class_name SwordThrowProjectile
extends Node2D
## 石短劍投擲飛行物；抵達時對目標造成技能傷害。

var _from: Vector2
var _to: Vector2
var _target: Node2D = null
var _t: float = 0.0
var _dur: float = 0.16
var _hit_damage: int = 2


func begin(from_world: Vector2, target: Node2D, travel_time: float = 0.16, hit_damage: int = 2) -> void:
	_from = from_world
	_target = target
	_to = target.global_position
	_dur = maxf(0.08, travel_time)
	_hit_damage = maxi(1, hit_damage)
	global_position = _from
	_t = 0.0
	z_index = 440
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / _dur, 0.0, 1.0)
	if is_instance_valid(_target):
		_to = _target.global_position
	global_position = _from.lerp(_to, k)
	queue_redraw()
	if _t >= _dur:
		if is_instance_valid(_target) and _target.has_method("take_weapon_hit"):
			var res: Variant = _target.call("take_weapon_hit", _hit_damage)
			var killed := false
			if res is Dictionary:
				killed = bool((res as Dictionary).get("destroyed", false))
			GameSfx.play_attack_chop(1.22, -1.0)
			var gm := get_tree().get_first_node_in_group("game_main")
			if gm != null:
				gm.call("_show_msg", "投擲擊敗！" if killed else "投擲命中！")
		queue_free()


func _draw() -> void:
	var blade := Color(0.82, 0.84, 0.92, 0.95)
	var hilt := Color(0.42, 0.3, 0.22, 1.0)
	var ang := 0.0
	if (global_position - _to).length_squared() > 4.0:
		ang = (_to - global_position).angle()
	draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
	draw_line(Vector2(-6, 0), Vector2(14, 0), blade, 3.5, true)
	draw_rect(Rect2(-10, -3, 6, 6), hilt)
