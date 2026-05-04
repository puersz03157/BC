class_name RmStationaryNpc
extends Node2D
## 站立 NPC：預設裁切 `rm_walk_sheet` 一格（朝下 idle）；若設 `pixeline_styling` 則改為 Pixeline 與玩家相同主表／層級（僅待機朝下）。

@export_range(0, 7) var rm_sheet_slot: int = 1
## 非空且含有效膚色／性別時：使用 Pixeline（鍵與存檔 p1_style 相同：gender_male, skin, hair, outfit, pants）。
@export var pixeline_styling: Dictionary = {}
## 非空時可 G／「交互」／左鍵（近距）對話，並加入群組 `talkable_npc`。
@export var npc_display_name: String = ""
## 與玩家相同的顯示縮放（Pixeline／RM 皆適用）。
@export_range(0.5, 4.0, 0.05) var display_scale: float = 1.5

var _body_collider: StaticBody2D
var _rm_sprite: Sprite2D
var _pixeline_mode: bool = false
var _px_body: Sprite2D
var _px_pants: Sprite2D
var _px_outfit: Sprite2D
var _px_hair: Sprite2D


func _ready() -> void:
	VisualRegistry.ensure_baked()
	if _pixeline_styling_valid():
		_pixeline_mode = true
		_build_pixeline_visual()
	else:
		_build_rm_visual()
	_body_collider = _make_collider()
	add_child(_body_collider)
	if not npc_display_name.is_empty():
		add_to_group("talkable_npc")


func _pixeline_styling_valid() -> bool:
	if pixeline_styling.is_empty():
		return false
	var gm := bool(pixeline_styling.get("gender_male", true))
	var sk := str(pixeline_styling.get("skin", "medium"))
	var path := PlayerStylingCatalog.base_body_path(gm, sk)
	return not path.is_empty() and ResourceLoader.exists(path)


func _build_rm_visual() -> void:
	var rm_tex := VisualRegistry.rm_walk_sheet_texture()
	if rm_tex == null:
		return
	_rm_sprite = Sprite2D.new()
	_rm_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rm_sprite.centered = true
	var org := VisualRegistry.rm_character_origin_px(rm_sheet_slot)
	var pw := VisualRegistry.RM_FRAME_PX * VisualRegistry.RM_CHAR_HFRAMES
	var ph := VisualRegistry.RM_FRAME_PX * VisualRegistry.RM_CHAR_VFRAMES
	_rm_sprite.texture = rm_tex
	_rm_sprite.region_enabled = true
	_rm_sprite.region_rect = Rect2(org.x, org.y, pw, ph)
	_rm_sprite.hframes = VisualRegistry.RM_CHAR_HFRAMES
	_rm_sprite.vframes = VisualRegistry.RM_CHAR_VFRAMES
	_rm_sprite.frame = 1
	_apply_scale_offset(_rm_sprite)
	add_child(_rm_sprite)


func _build_pixeline_visual() -> void:
	var gm := bool(pixeline_styling.get("gender_male", true))
	var sk := str(pixeline_styling.get("skin", "medium"))
	var hair := str(pixeline_styling.get("hair", ""))
	var outfit := str(pixeline_styling.get("outfit", ""))
	var pants := str(pixeline_styling.get("pants", ""))
	var body_path := PlayerStylingCatalog.base_body_path(gm, sk)
	var tex: Texture2D = load(body_path) as Texture2D
	if tex == null:
		push_warning("RmStationaryNpc: Pixeline 主表載入失敗，改 RM：%s" % body_path)
		pixeline_styling.clear()
		_pixeline_mode = false
		_build_rm_visual()
		return
	_px_body = Sprite2D.new()
	_px_body.name = "PixelineBody"
	_px_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_px_body.centered = true
	_px_body.texture = tex
	_px_body.hframes = 1
	_px_body.vframes = 1
	_px_body.region_enabled = true
	_px_body.z_index = 0
	_apply_scale_offset(_px_body)
	add_child(_px_body)
	_px_pants = _add_pixeline_layer(pants, "PixelinePants", 1)
	_px_outfit = _add_pixeline_layer(outfit, "PixelineOutfit", 2)
	_px_hair = _add_pixeline_layer(hair, "PixelineHair", 3)
	_refresh_pixeline_idle_down()


func _add_pixeline_layer(path: String, node_name: String, z: int) -> Sprite2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var ltex: Texture2D = load(path) as Texture2D
	if ltex == null:
		return null
	var spr := Sprite2D.new()
	spr.name = node_name
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = true
	spr.texture = ltex
	spr.hframes = 1
	spr.vframes = 1
	spr.region_enabled = true
	spr.z_index = z
	_apply_scale_offset(spr)
	add_child(spr)
	return spr


func _refresh_pixeline_idle_down() -> void:
	if not _pixeline_mode or _px_body == null:
		return
	var row := VisualRegistry.pixeline_idle_sheet_row(0)
	var col := clampi(VisualRegistry.PIXELINE_IDLE_STILL_FRAME, 0, VisualRegistry.PIXELINE_ROW_ANIM_FRAMES - 1)
	var fw := VisualRegistry.PIXELINE_FRAME_W
	var fh := VisualRegistry.PIXELINE_FRAME_H
	var r := Rect2(float(col * fw), float(row * fh), float(fw), float(fh))
	_px_body.region_rect = r
	_px_body.flip_h = false
	for layer in [_px_pants, _px_outfit, _px_hair]:
		if layer != null:
			layer.region_rect = r
			layer.flip_h = false


func _apply_scale_offset(spr: Sprite2D) -> void:
	var s := display_scale
	spr.scale = Vector2(s, s)
	spr.offset = Vector2(0, -12.0 * s)


func _make_collider() -> StaticBody2D:
	var hit := StaticBody2D.new()
	hit.name = "NpcStaticBody"
	hit.collision_layer = 1
	hit.collision_mask = 0
	var cs := CollisionShape2D.new()
	var circ := CircleShape2D.new()
	circ.radius = 11.0
	cs.shape = circ
	cs.position = Vector2(0, -6.0)
	hit.add_child(cs)
	return hit


## 溪谷村落：入夜隱藏時一併關閉碰撞，天亮再恢復（避免透明牆擋路）。
func set_valley_npc_night_hidden(hide_at_night: bool) -> void:
	visible = not hide_at_night
	if _body_collider != null:
		_body_collider.collision_layer = 0 if hide_at_night else 1
