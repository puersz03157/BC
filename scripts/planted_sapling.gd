extends Node2D
## 種下的樹苗：日夜相位走完一圈（遊戲內約「一天」）後長成樹。

var planted_phase: float = 0.0
var _growing: bool = true


func _ready() -> void:
	add_to_group("sapling")
	add_to_group("build_piece")
	z_index = 0
	var stem := Polygon2D.new()
	stem.polygon = PackedVector2Array([Vector2(-3, 8), Vector2(3, 8), Vector2(3, -2), Vector2(-3, -2)])
	stem.color = Color(0.42, 0.3, 0.2, 1.0)
	add_child(stem)
	var leaf := Polygon2D.new()
	leaf.polygon = PackedVector2Array([Vector2(-8, -4), Vector2(8, -4), Vector2(0, -14)])
	leaf.color = Color(0.32, 0.68, 0.32, 1.0)
	add_child(leaf)


func set_planted_phase(phase_at_plant: float) -> void:
	planted_phase = phase_at_plant


func get_save_phase() -> float:
	return planted_phase


static func phase_elapsed_since(from_ph: float, to_ph: float) -> float:
	if to_ph >= from_ph:
		return to_ph - from_ph
	return (1.0 - from_ph) + to_ph


func _process(_delta: float) -> void:
	if not _growing:
		return
	var main := get_tree().get_first_node_in_group("game_main")
	if main == null or not main.has_method("get_cycle_phase"):
		return
	var now: float = float(main.call("get_cycle_phase"))
	if phase_elapsed_since(planted_phase, now) >= 1.0:
		_growing = false
		set_process(false)
		if main.has_method("replace_sapling_with_tree"):
			main.call_deferred("replace_sapling_with_tree", self)
