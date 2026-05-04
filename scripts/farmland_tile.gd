extends Node2D
## 耕地：消耗「土」建造；快捷欄用水可澆濕；種樹種後，每個遊戲日曆日若已澆水則作物長一階，滿階可徒手採收。

const FARMLAND_TEX := "res://assets/farming/farmland.png"

var watered: bool = false
## 0＝無作物；1～3 生長中；4＝可採收。
var crop_stage: int = 0
var planted_at_doy: int = 1
## 耕地作物：&"tree"＝樹種長出、&"turnip"＝蕪菁種子。
var crop_kind: StringName = &""

var _ground: Sprite2D
var _crop: Polygon2D


func _ready() -> void:
	add_to_group("build_piece")
	add_to_group("farmland")
	z_index = 0
	_ground = Sprite2D.new()
	_ground.centered = true
	var tex := _load_or_make_texture()
	_ground.texture = tex
	if tex != null:
		var g := float(GameConstants.GRID_SIZE)
		_ground.scale = Vector2(g / tex.get_width(), g / tex.get_height())
	add_child(_ground)
	_crop = Polygon2D.new()
	_crop.z_index = 1
	add_child(_crop)
	_apply_water_visual()
	_refresh_crop_visual()


func _load_or_make_texture() -> Texture2D:
	if ResourceLoader.exists(FARMLAND_TEX):
		var r: Variant = ResourceLoader.load(FARMLAND_TEX, "", ResourceLoader.CACHE_MODE_REUSE)
		if r is Texture2D:
			return r as Texture2D
	return _make_placeholder_farmland_texture()


func _make_placeholder_farmland_texture() -> Texture2D:
	var g := 32
	var img := Image.create(g, g, false, Image.FORMAT_RGBA8)
	for y in g:
		for x in g:
			var col := int(x * 4 / g)
			var stripe := (x + col * 2) % 7 == 0
			var c := Color(0.26, 0.14, 0.09) if stripe else Color(0.48, 0.3, 0.18)
			c = c.lerp(Color(0.36, 0.22, 0.14), float(y) / float(g) * 0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func on_game_new_day() -> void:
	if crop_stage >= 1 and crop_stage < GameConstants.FARMLAND_RIPE_STAGE and watered:
		crop_stage += 1
	watered = false
	_apply_water_visual()
	_refresh_crop_visual()


func is_already_watered() -> bool:
	return watered


func apply_water_after_consume() -> void:
	watered = true
	_apply_water_visual()


func _apply_water_visual() -> void:
	if _ground == null:
		return
	_ground.modulate = Color(0.68, 0.86, 1.05, 1.0) if watered else Color.WHITE


func has_crop() -> bool:
	return crop_stage > 0


func try_plant_crop(calendar_doy: int, kind: StringName = &"tree") -> bool:
	if crop_stage > 0:
		return false
	crop_kind = kind
	crop_stage = 1
	planted_at_doy = calendar_doy
	_refresh_crop_visual()
	return true


func is_ripe_for_hand_harvest() -> bool:
	return crop_stage >= GameConstants.FARMLAND_RIPE_STAGE


## 成功時回傳作物種類；失敗回傳空字串。
func try_harvest_crop_hand() -> StringName:
	if crop_stage < GameConstants.FARMLAND_RIPE_STAGE:
		return &""
	var k := crop_kind
	crop_kind = &""
	crop_stage = 0
	watered = false
	_apply_water_visual()
	_refresh_crop_visual()
	return k


func _refresh_crop_visual() -> void:
	if _crop == null:
		return
	match crop_stage:
		0:
			_crop.visible = false
		1:
			_crop.visible = true
			_crop.polygon = PackedVector2Array([Vector2(-2, 10), Vector2(2, 10), Vector2(3, 2), Vector2(-3, 2)])
			_crop.color = Color(0.32, 0.62, 0.34, 1.0)
		2:
			_crop.visible = true
			_crop.polygon = PackedVector2Array([
				Vector2(-8, 8), Vector2(8, 8), Vector2(6, -2), Vector2(0, -10), Vector2(-6, -2),
			])
			_crop.color = Color(0.28, 0.68, 0.36, 1.0)
		3:
			_crop.visible = true
			_crop.polygon = PackedVector2Array([
				Vector2(-12, 6), Vector2(-4, -12), Vector2(4, -14), Vector2(12, 6), Vector2(0, 4),
			])
			_crop.color = Color(0.24, 0.58, 0.3, 1.0)
		_:
			_crop.visible = true
			_crop.polygon = PackedVector2Array([
				Vector2(-14, 4), Vector2(-8, -8), Vector2(0, -16), Vector2(8, -8), Vector2(14, 4), Vector2(0, 10),
			])
			if crop_kind == &"turnip":
				_crop.color = Color(0.92, 0.82, 0.38, 1.0)
			else:
				_crop.color = Color(0.45, 0.78, 0.38, 1.0)


func get_save_watered() -> bool:
	return watered


func get_save_crop_stage() -> int:
	return crop_stage


func get_save_planted_doy() -> int:
	return planted_at_doy


func get_save_crop_kind() -> StringName:
	return crop_kind


func apply_farmland_save(w: bool, cs: int, pd: int, kind: StringName = &"tree") -> void:
	watered = w
	crop_stage = clampi(cs, 0, GameConstants.FARMLAND_RIPE_STAGE)
	planted_at_doy = clampi(pd, 1, 365)
	if crop_stage > 0:
		crop_kind = kind
	else:
		crop_kind = &""
	_apply_water_visual()
	_refresh_crop_visual()
