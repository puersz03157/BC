class_name PlayerController
extends CharacterBody2D
## 1P：WASD。2P：雙人時左搖桿（第二支手把優先，僅一支則用該支）／方向鍵／滑鼠右鍵拖曳移動。
## 攜帶光：夜間微弱圓光；之後火把／提燈可調 carry_light_*_mult（或由主流程寫入）。

@export var player_index: int = 0
## 之後裝備火把／提燈時改為 >1 即可加亮、加半徑（或由存檔／背包驅動）。
@export_range(0.15, 4.0, 0.05) var carry_light_energy_mult: float = 1.0
@export_range(0.35, 3.0, 0.05) var carry_light_radius_mult: float = 1.0
## 角色貼圖等比縮放（不影響碰撞）；配合 TEXTURE_FILTER_NEAREST 維持像素邊緣。
@export_range(0.5, 4.0, 0.05) var display_scale: float = 1.5
var mouse_target: Vector2 = Vector2.ZERO
var use_mouse_target: bool = false
## 單人 Web／手機：指尖導航目標（鍵盤 WASD 會取消）。
var touch_nav_active: bool = false
var touch_nav_target: Vector2 = Vector2.ZERO
var _sprite: Sprite2D
var _carry_light: PointLight2D
## 2P 關閉時不更新也不顯示攜帶光（本節點 process 可能仍為 INHERIT，由主場景呼叫壓制）。
var _carry_suppressed: bool = false
var _name_label: Label
## 使用 `rm_walk_sheet.png` 時為 true（1P=第1格、2P=第8格）。
var _rm_sheet_mode: bool = false
## 使用 Pixeline 主表（`assets/characters/pixeline/Base_character_*`）時為 true；優先於 RM。
var _pixeline_mode: bool = false
## Pixeline 造型（由「造型」面板或存檔寫入）。
var _pixeline_gender_male: bool = true
var _pixeline_skin: String = "medium"
var _pixeline_hair_path: String = ""
var _pixeline_outfit_path: String = ""
var _pixeline_pants_path: String = ""
var _sprite_hair: Sprite2D
var _sprite_outfit: Sprite2D
var _sprite_pants: Sprite2D
var _rm_anim_t: float = 0.0
var _rm_face_row: int = 0
## 角色技能：短衝刺（由 Main 呼叫 try_begin_dash）。
var _dash_remain: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.DOWN
## 腳下 CD 量條（角色技能 E、武器技能 Q）。
var _char_cd_bar: TextureProgressBar = null
var _weapon_cd_bar: TextureProgressBar = null
var _char_cd_lbl: Label = null
var _weapon_cd_lbl: Label = null
var _last_facing_dir: Vector2 = Vector2.DOWN
## 深夜滿強度時基準（ADD 混合比 MIX 亮，略降以免過曝）。
const _CARRY_PEAK_ENERGY := 0.38
const _CARRY_TEX_SCALE_BASE := 1.18
const _RM_WALK_FPS := 7.5
## 2P 左搖桿／十字鍵：死區（過小視為無輸入）。
const _P2_JOY_DEADZONE := 0.22
## 名牌／腳下陰影（皆再乘 `display_scale`）。Y 愈小愈靠畫面上方。
const _NAME_LABEL_Y_OFFSET_BASE := -46.0
const _FEET_SHADOW_CENTER_Y_BASE := 3.0
## 腳下陰影：橫向半徑、縱向半徑（拉扁橢圓），再乘 `display_scale`。
const _FEET_SHADOW_RX_BASE := 9.0
const _FEET_SHADOW_RY_BASE := 2.75
const _FEET_SHADOW_ELLIPSE_SEGMENTS := 28


func _ready() -> void:
	add_to_group("player")
	set_meta("player_index", player_index)
	collision_layer = 2
	collision_mask = 1
	VisualRegistry.ensure_baked()
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	var px_tex := VisualRegistry.pixeline_base_sheet_texture(_pixeline_gender_male, _pixeline_skin)
	if px_tex != null:
		_pixeline_mode = true
		_rm_sheet_mode = false
		_sprite.texture = px_tex
		_sprite.region_enabled = true
		_sprite.hframes = 1
		_sprite.vframes = 1
		_rm_face_row = 0
		_pixeline_update_sprite_frame(0.0)
	else:
		var rm_tex := VisualRegistry.rm_walk_sheet_texture()
		if rm_tex != null:
			_rm_sheet_mode = true
			var slot := 0 if player_index == 0 else 7
			var org := VisualRegistry.rm_character_origin_px(slot)
			var pw := VisualRegistry.RM_FRAME_PX * VisualRegistry.RM_CHAR_HFRAMES
			var ph := VisualRegistry.RM_FRAME_PX * VisualRegistry.RM_CHAR_VFRAMES
			_sprite.texture = rm_tex
			_sprite.region_enabled = true
			_sprite.region_rect = Rect2(org.x, org.y, pw, ph)
			_sprite.hframes = VisualRegistry.RM_CHAR_HFRAMES
			_sprite.vframes = VisualRegistry.RM_CHAR_VFRAMES
			_sprite.frame = 1
			## hframes×vframes 時實際只顯示 48×48 一幀，勿用整塊 192 當顯示高度，否則 offset 過大會「飄空」。
		else:
			_sprite.texture = VisualRegistry.player_tex(player_index)
	add_child(_sprite)
	_carry_light = PointLight2D.new()
	_carry_light.texture = RadialPointLightTex.create_texture(256)
	_carry_light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_carry_light.color = Color(0.96, 0.94, 1.0, 1.0)
	_carry_light.energy = 0.0
	## ADD：與父層 CanvasModulate 壓暗並用時，MIX 會在光斑中心算出異常暗區（像黑色光球）。
	_carry_light.blend_mode = Light2D.BLEND_MODE_ADD
	_carry_light.shadow_enabled = false
	_carry_light.texture_scale = _CARRY_TEX_SCALE_BASE * carry_light_radius_mult
	add_child(_carry_light)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 11)
	_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_name_label.add_theme_constant_override("outline_size", 3)
	_name_label.visible = false
	add_child(_name_label)
	if _pixeline_mode:
		_refresh_pixeline_overlay_textures()
	else:
		_apply_display_scale()
	_setup_cd_bars()
	set_process(true)
	queue_redraw()


func set_player_name(display_name: String) -> void:
	if _name_label == null:
		return
	_name_label.text = display_name
	_name_label.visible = display_name.length() > 0
	_name_label.position = Vector2(-(_name_label.size.x * 0.5), _NAME_LABEL_Y_OFFSET_BASE * display_scale)


func _setup_cd_bars() -> void:
	## 量條寬度隨 display_scale 縮放，置於腳下陰影正下方。
	var s := display_scale
	var bar_w := roundf(28.0 * s)
	var bar_h := maxf(4.0, roundf(5.0 * s))
	var row_gap := maxf(3.0, roundf(4.0 * s))
	var base_y := (_FEET_SHADOW_CENTER_Y_BASE + _FEET_SHADOW_RY_BASE + 2.5) * s
	var lbl_x := -bar_w * 0.5 - roundf(8.0 * s)
	var bar_x := -bar_w * 0.5
	## 角色技能（E／衝刺）──藍色量條。
	_char_cd_lbl = Label.new()
	_char_cd_lbl.text = "E"
	_char_cd_lbl.position = Vector2(lbl_x, base_y - 1.0)
	_char_cd_lbl.add_theme_font_size_override("font_size", maxi(8, int(9.0 * s)))
	_char_cd_lbl.add_theme_color_override("font_color", Color(0.52, 0.88, 1.00, 0.92))
	_char_cd_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.80))
	_char_cd_lbl.add_theme_constant_override("outline_size", 2)
	_char_cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_char_cd_lbl.visible = false
	add_child(_char_cd_lbl)
	_char_cd_bar = TextureProgressBar.new()
	_char_cd_bar.position = Vector2(bar_x, base_y)
	_char_cd_bar.custom_minimum_size = Vector2(bar_w, bar_h)
	_char_cd_bar.size = Vector2(bar_w, bar_h)
	_char_cd_bar.min_value = 0.0
	_char_cd_bar.max_value = GameConstants.CHARACTER_DASH_COOLDOWN_SEC
	_char_cd_bar.value = 0.0
	_char_cd_bar.rounded = false
	_char_cd_bar.step = 0.01
	_char_cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_char_cd_bar.visible = false
	if CuteFantasyUiBars.setup_skill_cd_bar(_char_cd_bar):
		_char_cd_bar.tint_progress = Color(0.48, 0.82, 1.00)
		add_child(_char_cd_bar)
	else:
		_char_cd_bar.queue_free()
		_char_cd_bar = null
	## 武器技能（Q）──綠色量條。
	var y2 := base_y + bar_h + row_gap
	_weapon_cd_lbl = Label.new()
	_weapon_cd_lbl.text = "Q"
	_weapon_cd_lbl.position = Vector2(lbl_x, y2 - 1.0)
	_weapon_cd_lbl.add_theme_font_size_override("font_size", maxi(8, int(9.0 * s)))
	_weapon_cd_lbl.add_theme_color_override("font_color", Color(0.58, 1.00, 0.58, 0.92))
	_weapon_cd_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.80))
	_weapon_cd_lbl.add_theme_constant_override("outline_size", 2)
	_weapon_cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_cd_lbl.visible = false
	add_child(_weapon_cd_lbl)
	_weapon_cd_bar = TextureProgressBar.new()
	_weapon_cd_bar.position = Vector2(bar_x, y2)
	_weapon_cd_bar.custom_minimum_size = Vector2(bar_w, bar_h)
	_weapon_cd_bar.size = Vector2(bar_w, bar_h)
	_weapon_cd_bar.min_value = 0.0
	_weapon_cd_bar.max_value = GameConstants.WEAPON_SKILL_COOLDOWN
	_weapon_cd_bar.value = 0.0
	_weapon_cd_bar.rounded = false
	_weapon_cd_bar.step = 0.01
	_weapon_cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_cd_bar.visible = false
	if CuteFantasyUiBars.setup_skill_cd_bar(_weapon_cd_bar):
		_weapon_cd_bar.tint_progress = Color(0.52, 1.00, 0.52)
		add_child(_weapon_cd_bar)
	else:
		_weapon_cd_bar.queue_free()
		_weapon_cd_bar = null


func _update_cd_bars() -> void:
	## 衝刺 CD（角色技能 E）：有 CD 才顯示，從滿格倒數至空格。
	var dash_rem := _dash_cd
	var dash_on := dash_rem > 0.001
	if _char_cd_lbl != null:
		_char_cd_lbl.visible = dash_on
	if _char_cd_bar != null:
		_char_cd_bar.visible = dash_on
		if dash_on:
			_char_cd_bar.value = dash_rem
	## 武器技能 CD（Q）：向 Main 查詢此玩家的剩餘冷卻。
	var wcd := 0.0
	var main := get_tree().get_first_node_in_group("game_main")
	if main and main.has_method("player_weapon_cd"):
		wcd = main.player_weapon_cd(player_index)
	var weapon_on := wcd > 0.001
	if _weapon_cd_lbl != null:
		_weapon_cd_lbl.visible = weapon_on
	if _weapon_cd_bar != null:
		_weapon_cd_bar.visible = weapon_on
		if weapon_on:
			_weapon_cd_bar.value = wcd


func set_carry_light_suppressed(suppressed: bool) -> void:
	_carry_suppressed = suppressed
	if suppressed and _carry_light:
		_carry_light.enabled = false
		_carry_light.energy = 0.0


func _process(_delta: float) -> void:
	if _carry_light == null:
		return
	if _carry_suppressed:
		_carry_light.enabled = false
		_carry_light.energy = 0.0
		return
	var str := 0.0
	var rad_scale := 1.0
	var main := get_tree().get_first_node_in_group("game_main")
	if main:
		if main.has_method("player_carry_light_strength"):
			str = main.player_carry_light_strength()
		if main.has_method("player_carry_light_radius_scale"):
			rad_scale = main.player_carry_light_radius_scale()
	_carry_light.enabled = str > 0.02
	if not _carry_light.enabled:
		_carry_light.energy = 0.0
		return
	_carry_light.texture_scale = _CARRY_TEX_SCALE_BASE * carry_light_radius_mult * rad_scale * display_scale
	_carry_light.energy = _CARRY_PEAK_ENERGY * carry_light_energy_mult * str
	_update_cd_bars()


func try_begin_dash() -> bool:
	if _dash_cd > 0.001 or _dash_remain > 0.001:
		return false
	var d := _read_move_input_dir()
	if d.length_squared() < 0.0001:
		d = _last_facing_dir
	if d.length_squared() < 0.0001:
		d = Vector2(0, 1)
	_dash_dir = d.normalized()
	_dash_remain = GameConstants.CHARACTER_DASH_DURATION_SEC
	return true


## 蓄力／鐵壁等非位移技能：僅進入與短衝刺相同的冷卻，不觸發位移。
func begin_character_skill_cooldown() -> void:
	if _dash_remain > 0.001:
		return
	_dash_cd = maxf(_dash_cd, GameConstants.CHARACTER_DASH_COOLDOWN_SEC)


func character_dash_cooldown_remaining() -> float:
	return _dash_cd


## 雙人 2P 使用的手把裝置 id：已連接 ≥2 支時用第二支，否則用僅存的那一支。
static func p2_gamepad_device_id() -> int:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return -1
	if pads.size() >= 2:
		return pads[1]
	return pads[0]


func is_p2_gamepad_moving() -> bool:
	if player_index != 1:
		return false
	return _p2_joy_combined_axes().length_squared() > _P2_JOY_DEADZONE * _P2_JOY_DEADZONE


func _p2_joy_combined_axes() -> Vector2:
	var jid := p2_gamepad_device_id()
	if jid < 0:
		return Vector2.ZERO
	var sx := Input.get_joy_axis(jid, JOY_AXIS_LEFT_X)
	var sy := Input.get_joy_axis(jid, JOY_AXIS_LEFT_Y)
	var v := Vector2(sx, sy)
	## 多數手把十字鍵為 HAT 軸（SDL 常見為軸 6／7；與左搖桿併用）。
	const hat_x := 6
	const hat_y := 7
	var hx := Input.get_joy_axis(jid, hat_x)
	var hy := Input.get_joy_axis(jid, hat_y)
	var hat := Vector2(hx, hy)
	if hat.length_squared() > 0.04:
		if v.length_squared() < 0.04:
			v = hat
		else:
			v = (v + hat).limit_length(1.0)
	return v


func _p2_read_joy_move_dir() -> Vector2:
	if player_index != 1:
		return Vector2.ZERO
	var v := _p2_joy_combined_axes()
	if v.length_squared() < _P2_JOY_DEADZONE * _P2_JOY_DEADZONE:
		return Vector2.ZERO
	return v.normalized()


func _read_move_input_dir() -> Vector2:
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
		var jdir := _p2_read_joy_move_dir()
		if jdir.length_squared() > 0.0001:
			dir = jdir
			if use_mouse_target:
				use_mouse_target = false
		elif use_mouse_target and mouse_target != Vector2.ZERO:
			var to_tgt := mouse_target - global_position
			if to_tgt.length() > 8.0:
				dir = to_tgt.normalized()
		if dir == Vector2.ZERO:
			dir.x = float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
			dir.y = float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))
	return dir


func _physics_process(delta: float) -> void:
	if _dash_cd > 0.0:
		_dash_cd = maxf(0.0, _dash_cd - delta)
	if _dash_remain > 0.001:
		var prev_remain := _dash_remain
		_dash_remain = maxf(0.0, _dash_remain - delta)
		if prev_remain > 0.001 and _dash_remain <= 0.001:
			_dash_cd = GameConstants.CHARACTER_DASH_COOLDOWN_SEC
		velocity = _dash_dir * GameConstants.CHARACTER_DASH_SPEED
		move_and_slide()
		if _pixeline_mode and _sprite != null:
			_pixeline_update_sprite_frame(delta)
		elif _rm_sheet_mode and _sprite != null:
			_rm_update_sprite_frame(delta)
		return
	var dir := _read_move_input_dir()
	if dir.length_squared() > 0.0001:
		_last_facing_dir = dir.normalized()
	if dir.length_squared() > 0.0001:
		velocity = dir.normalized() * GameConstants.PLAYER_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if _pixeline_mode and _sprite != null:
		_pixeline_update_sprite_frame(delta)
	elif _rm_sheet_mode and _sprite != null:
		_rm_update_sprite_frame(delta)


func set_mouse_nav_target(world: Vector2, active: bool) -> void:
	mouse_target = world
	use_mouse_target = active


func set_touch_navigation(active: bool, world_pos: Vector2 = Vector2.ZERO) -> void:
	touch_nav_active = active
	if active:
		touch_nav_target = world_pos


func _rm_pick_face_row_from_velocity(v: Vector2) -> int:
	var ax := absf(v.x)
	var ay := absf(v.y)
	if ax < 8.0 and ay < 8.0:
		return _rm_face_row
	if ax >= ay:
		return 2 if v.x > 0.0 else 1
	return 0 if v.y > 0.0 else 3


func _rm_update_sprite_frame(delta: float) -> void:
	var moving := velocity.length_squared() > 400.0
	if moving:
		_rm_face_row = _rm_pick_face_row_from_velocity(velocity)
		_rm_anim_t += delta * _RM_WALK_FPS
	var col := 1
	if moving:
		col = int(_rm_anim_t) % 3
	_sprite.frame = _rm_face_row * VisualRegistry.RM_CHAR_HFRAMES + col


func _pixeline_update_sprite_frame(delta: float) -> void:
	var moving := velocity.length_squared() > 400.0
	if moving:
		_rm_face_row = _rm_pick_face_row_from_velocity(velocity)
		_rm_anim_t += delta * _RM_WALK_FPS
	var sheet_row: int
	var col_off: int
	var nframes := VisualRegistry.PIXELINE_ROW_ANIM_FRAMES
	if moving:
		sheet_row = VisualRegistry.pixeline_walk_sheet_row(_rm_face_row)
		col_off = int(_rm_anim_t) % nframes
	else:
		sheet_row = VisualRegistry.pixeline_idle_sheet_row(_rm_face_row)
		col_off = clampi(VisualRegistry.PIXELINE_IDLE_STILL_FRAME, 0, nframes - 1)
	var fw := VisualRegistry.PIXELINE_FRAME_W
	var fh := VisualRegistry.PIXELINE_FRAME_H
	var gx := col_off * fw
	var gy := sheet_row * fh
	_sprite.region_rect = Rect2(gx, gy, fw, fh)
	_sprite.flip_h = VisualRegistry.pixeline_flip_h_for_rm_face(_rm_face_row)
	_sync_pixeline_overlay_frames()


func _sync_pixeline_overlay_frames() -> void:
	if not _pixeline_mode:
		return
	var r := _sprite.region_rect
	var fh := _sprite.flip_h
	for layer in [_sprite_pants, _sprite_outfit, _sprite_hair]:
		if layer == null:
			continue
		layer.region_enabled = true
		layer.region_rect = r
		layer.flip_h = fh


func _pixeline_free_layer_sprite(layer: Sprite2D) -> void:
	if layer != null and is_instance_valid(layer):
		layer.queue_free()


func _insert_sprite_before_carry(spr: Node) -> void:
	if spr.get_parent() != self:
		var ins := get_child_count()
		if _carry_light != null and is_instance_valid(_carry_light):
			ins = _carry_light.get_index()
		add_child(spr)
		move_child(spr, ins)
	elif _carry_light != null and is_instance_valid(_carry_light):
		var ci := _carry_light.get_index()
		if spr.get_index() > ci:
			move_child(spr, ci)


func _ensure_pixeline_layer(path: String, existing: Sprite2D, node_name: String, z_index_layer: int) -> Sprite2D:
	if path.is_empty():
		_pixeline_free_layer_sprite(existing)
		return null
	if not ResourceLoader.exists(path):
		push_warning("PlayerController: 找不到造型層：%s" % path)
		_pixeline_free_layer_sprite(existing)
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		_pixeline_free_layer_sprite(existing)
		return null
	var spr := existing
	if spr == null or not is_instance_valid(spr):
		spr = Sprite2D.new()
		spr.name = node_name
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		_insert_sprite_before_carry(spr)
	spr.texture = tex
	spr.hframes = 1
	spr.vframes = 1
	spr.region_enabled = true
	spr.z_index = z_index_layer
	return spr


func _refresh_pixeline_overlay_textures() -> void:
	if not _pixeline_mode:
		return
	_sprite_pants = _ensure_pixeline_layer(_pixeline_pants_path, _sprite_pants, "PixelinePants", 1)
	_sprite_outfit = _ensure_pixeline_layer(_pixeline_outfit_path, _sprite_outfit, "PixelineOutfit", 2)
	_sprite_hair = _ensure_pixeline_layer(_pixeline_hair_path, _sprite_hair, "PixelineHair", 3)
	_sprite.z_index = 0
	_sync_pixeline_overlay_frames()
	_apply_display_scale()


## 套用 Pixeline 身體膚色／性別與可選髮型、上衣、下半身；成功回 true。
func apply_pixeline_customization(gender_male: bool, skin_key: String, hair_res: String, outfit_res: String, pants_res: String = "") -> bool:
	var path := PlayerStylingCatalog.base_body_path(gender_male, skin_key)
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return false
	_pixeline_gender_male = gender_male
	_pixeline_skin = skin_key
	_pixeline_hair_path = hair_res
	_pixeline_outfit_path = outfit_res
	_pixeline_pants_path = pants_res
	_pixeline_mode = true
	_rm_sheet_mode = false
	_sprite.texture = tex
	_sprite.region_enabled = true
	_sprite.hframes = 1
	_sprite.vframes = 1
	_rm_face_row = 0
	_pixeline_update_sprite_frame(0.0)
	_refresh_pixeline_overlay_textures()
	return true


func get_pixeline_styling_save_dict() -> Dictionary:
	return {
		"gender_male": _pixeline_gender_male,
		"skin": _pixeline_skin,
		"hair": _pixeline_hair_path,
		"outfit": _pixeline_outfit_path,
		"pants": _pixeline_pants_path,
	}


func apply_pixeline_styling_from_save(d: Dictionary) -> void:
	if d.is_empty():
		return
	var gm := bool(d.get("gender_male", true))
	var sk := str(d.get("skin", "medium"))
	var hr := str(d.get("hair", ""))
	var ot := str(d.get("outfit", ""))
	var pn := str(d.get("pants", ""))
	apply_pixeline_customization(gm, sk, hr, ot, pn)


func _apply_display_scale() -> void:
	var s := display_scale
	if _sprite:
		_sprite.scale = Vector2(s, s)
		_sprite.offset = Vector2(0, -12.0 * s)
	for layer in [_sprite_pants, _sprite_outfit, _sprite_hair]:
		if layer != null and is_instance_valid(layer):
			layer.scale = Vector2(s, s)
			layer.offset = Vector2(0, -12.0 * s)
	if _carry_light:
		_carry_light.position = Vector2(0, -10.0 * s)
		_carry_light.texture_scale = _CARRY_TEX_SCALE_BASE * carry_light_radius_mult * s
	if _name_label:
		_name_label.add_theme_font_size_override("font_size", maxi(8, int(round(11.0 * s))))
		_name_label.position = Vector2(-(_name_label.size.x * 0.5), _NAME_LABEL_Y_OFFSET_BASE * s)
	queue_redraw()


func _draw() -> void:
	var s := display_scale
	var center := Vector2(0.0, _FEET_SHADOW_CENTER_Y_BASE * s)
	var rx := _FEET_SHADOW_RX_BASE * s
	var ry := _FEET_SHADOW_RY_BASE * s
	var n := _FEET_SHADOW_ELLIPSE_SEGMENTS
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in range(n):
		var t := TAU * float(i) / float(n)
		pts[i] = center + Vector2(cos(t) * rx, sin(t) * ry)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.24))
