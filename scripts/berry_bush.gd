extends StaticBody2D
## 莓果叢：F／Space 徒手採集，每次 2～3 個莓果；採光後須經 2 個完整日夜相位週期才結果。非樹木，石斧無法砍伐。
## 外觀：`res://assets/override/berry_bush.png`（無則程式簡圖）。

var _has_berries: bool = true
var _depleted_at_phase: float = 0.0
var _waiting_regrow: bool = false

var _ripe_vis: Sprite2D
var _bare_vis: Sprite2D


func _ready() -> void:
	add_to_group("berry_bush")
	collision_layer = 1
	collision_mask = 0
	## 略高於地面預設，避免被草地／底圖完全遮住。
	z_index = 2
	var sh := CircleShape2D.new()
	sh.radius = 20.0
	var col := CollisionShape2D.new()
	col.shape = sh
	add_child(col)
	VisualRegistry.ensure_baked()
	var tex := VisualRegistry.berry_bush_tex()
	_ripe_vis = Sprite2D.new()
	_ripe_vis.texture = tex
	_ripe_vis.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ripe_vis.centered = true
	_ripe_vis.offset = Vector2(0, -8)
	_bare_vis = Sprite2D.new()
	_bare_vis.texture = tex
	_bare_vis.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bare_vis.centered = true
	_bare_vis.offset = Vector2(0, -8)
	_bare_vis.modulate = Color(0.55, 0.52, 0.48, 1.0)
	_bare_vis.visible = false
	add_child(_ripe_vis)
	add_child(_bare_vis)


static func _phase_elapsed(from_ph: float, to_ph: float) -> float:
	if to_ph >= from_ph:
		return to_ph - from_ph
	return (1.0 - from_ph) + to_ph


func is_ripe_for_harvest() -> bool:
	return _has_berries


func try_harvest_hand() -> bool:
	if not _has_berries:
		return false
	var n := randi_range(2, 3)
	var main := get_tree().get_first_node_in_group("game_main")
	if main != null and main.has_method("add_berries"):
		main.call("add_berries", n)
	_has_berries = false
	_waiting_regrow = true
	if main != null and main.has_method("get_cycle_phase"):
		_depleted_at_phase = float(main.call("get_cycle_phase"))
	_sync_visuals()
	return true


func _process(_delta: float) -> void:
	if not _waiting_regrow:
		return
	var main := get_tree().get_first_node_in_group("game_main")
	if main == null or not main.has_method("get_cycle_phase"):
		return
	var now := float(main.call("get_cycle_phase"))
	if _phase_elapsed(_depleted_at_phase, now) >= 2.0:
		_has_berries = true
		_waiting_regrow = false
		_sync_visuals()


func _sync_visuals() -> void:
	if _ripe_vis:
		_ripe_vis.visible = _has_berries
	if _bare_vis:
		_bare_vis.visible = not _has_berries


func get_save_ripe() -> bool:
	return _has_berries


func get_save_depleted_phase() -> float:
	return _depleted_at_phase if _waiting_regrow else -1.0


func apply_save_state(ripe: bool, dep_phase: float) -> void:
	_has_berries = ripe
	_waiting_regrow = not ripe
	if _waiting_regrow:
		_depleted_at_phase = dep_phase
	_sync_visuals()
