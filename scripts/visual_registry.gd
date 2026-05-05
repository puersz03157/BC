class_name VisualRegistry
extends RefCounted
## 集中管理遊戲內貼圖。若 `res://assets/override/` 下有同名 PNG，會優先使用（`tree.png`、`rock.png`、`berry_bush.png` 等），方便你換成 Aseprite／素材包輸出。
## 檔名請與程式一致；若從 Windows 複製出 `Tree.png` 這類大小寫差異，編輯器有時仍會載入，但 **Web／匯出後 ResourceLoader 常區分大小寫**，會變成看不到自訂圖（改顯示內建烘焙）。此處會對 override 目錄做一次不分大小寫的檔名比對。
## 否則使用內建程式烘焙（像素風暫代）。

const OVERRIDE_DIR := "res://assets/override/"
## RPG Maker MV/MZ 式 8 人行走圖（4×2 人、每人 3×4 幀、48×48）。見 `assets/characters/rm_walk_sheet.png`。
const RM_WALK_SHEET := "res://assets/characters/rm_walk_sheet.png"
const RM_FRAME_PX := 48
const RM_CHAR_HFRAMES := 3
const RM_CHAR_VFRAMES := 4
## Pixeline「Base_character_Itchio_all_*」主表（476×864）：14×24 格，單格 34×36。
## **前 6 行**為 IDLE/WALK：每行一個朝向（朝下、朝上、朝右），橫向為該向幀；無朝左圖，左走＝右行 + `flip_h`。第 7 行起為 MINING 等（勿裁進去）。
const PIXELINE_FRAME_W := 34
const PIXELINE_FRAME_H := 36
## 每行橫向可播的走路／待機幀數（素材標 6 幀；表寬 14 格，取前 6 格循環）。
const PIXELINE_ROW_ANIM_FRAMES := 6
## 站立時取橫向中間一幀，避免邊緣姿勢。
const PIXELINE_IDLE_STILL_FRAME := 2
## 外部 PNG 最長邊超過此值時，會用最近鄰縮小（與內建烘焙尺寸對齊，避免整張原畫塞滿畫面）。
const MAX_PLAYER_SIDE := 56
const MAX_TREE_SIDE := 96
const MAX_ROCK_SIDE := 72
const MAX_BERRY_BUSH_SIDE := 80
const MAX_LOOSE_SIDE := 40
const MAX_CAMPFIRE_SIDE := 56

static var _tree: Texture2D
static var _rock: Texture2D
static var _berry_bush: Texture2D
static var _player1: Texture2D
static var _player2: Texture2D
static var _loose_wood: Texture2D
static var _loose_stone: Texture2D
static var _loose_seed: Texture2D
static var _loose_slime: Texture2D
static var _loose_leather: Texture2D
static var _loose_meat: Texture2D
static var _loose_mushroom: Texture2D
static var _icon_wood: Texture2D
static var _icon_stone: Texture2D
static var _icon_seed: Texture2D
static var _icon_axe: Texture2D
static var _campfire: Texture2D
static var _baked: bool = false
static var _rm_walk_sheet: Texture2D


static func ensure_baked() -> void:
	if _baked:
		return
	_baked = true
	if ResourceLoader.exists(RM_WALK_SHEET):
		var rm: Variant = load(RM_WALK_SHEET)
		if rm is Texture2D:
			_rm_walk_sheet = rm as Texture2D
	_tree = _load_or_make("tree.png", _make_tree_texture, MAX_TREE_SIDE)
	_rock = _load_or_make("rock.png", _make_rock_texture, MAX_ROCK_SIDE)
	_berry_bush = _load_or_make("berry_bush.png", _make_berry_bush_texture, MAX_BERRY_BUSH_SIDE)
	_player1 = _load_or_make("player1.png", func() -> Texture2D: return _make_player_texture(Color("#3498db"), Color("#1a5276")), MAX_PLAYER_SIDE)
	_player2 = _load_or_make("player2.png", func() -> Texture2D: return _make_player_texture(Color("#9b59b6"), Color("#4a235a")), MAX_PLAYER_SIDE)
	_loose_wood = _load_or_make("loose_wood.png", func() -> Texture2D: return _make_loose_log(), MAX_LOOSE_SIDE)
	_loose_stone = _load_or_make("loose_stone.png", func() -> Texture2D: return _make_loose_pebble(), MAX_LOOSE_SIDE)
	_loose_seed = _load_or_make("loose_seed.png", func() -> Texture2D: return _make_seed_cluster(), MAX_LOOSE_SIDE)
	_loose_slime = _load_or_make("loose_slime.png", func() -> Texture2D: return _make_loose_slime(), MAX_LOOSE_SIDE)
	_loose_leather = _load_or_make("loose_leather.png", func() -> Texture2D: return _make_loose_leather(), MAX_LOOSE_SIDE)
	_loose_meat = _load_or_make("loose_meat.png", func() -> Texture2D: return _make_loose_meat(), MAX_LOOSE_SIDE)
	_loose_mushroom = _load_or_make(
		"wild_mushroom.png",
		func() -> Texture2D: return _make_loose_wild_mushroom(),
		MAX_LOOSE_SIDE
	)
	_icon_wood = _scale_nearest(_make_icon_branch(), 28, 28)
	_icon_stone = _scale_nearest(_make_icon_pebble(), 28, 28)
	_icon_seed = _scale_nearest(_make_icon_seed(), 28, 28)
	_icon_axe = _scale_nearest(_make_icon_axe(), 28, 28)
	_campfire = _load_or_make("campfire.png", _make_campfire_texture, MAX_CAMPFIRE_SIDE)


static func tree_tex() -> Texture2D:
	ensure_baked()
	return _tree


static func rock_tex() -> Texture2D:
	ensure_baked()
	return _rock


static func berry_bush_tex() -> Texture2D:
	ensure_baked()
	return _berry_bush


static func player_tex(idx: int) -> Texture2D:
	ensure_baked()
	return _player1 if idx == 0 else _player2


## 是否有 RM 式行走大圖（有則 PlayerController 優先用裁切動畫）。
static func rm_walk_sheet_texture() -> Texture2D:
	ensure_baked()
	return _rm_walk_sheet


## 依性別／膚色載入 Pixeline 主表；檔案不存在則 null（改走 RM／內建）。
static func pixeline_base_sheet_texture(gender_male: bool, skin_key: String) -> Texture2D:
	var path := PlayerStylingCatalog.base_body_path(gender_male, skin_key)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var t: Variant = load(path)
	return t as Texture2D if t is Texture2D else null


## RM 式朝向（0 下／1 左／2 右／3 上）→ 主表**列索引**（0-based）：待機列 0=下、1=上、2=右。
static func pixeline_idle_sheet_row(rm_face_row: int) -> int:
	match rm_face_row:
		0:
			return 0
		3:
			return 1
		1, 2:
			return 2
		_:
			return 0


## 走路列：3=下、4=上、5=右（左走與右同一列 + 鏡像）。
static func pixeline_walk_sheet_row(rm_face_row: int) -> int:
	match rm_face_row:
		0:
			return 3
		3:
			return 4
		1, 2:
			return 5
		_:
			return 3


static func pixeline_flip_h_for_rm_face(rm_face_row: int) -> bool:
	return rm_face_row == 1


## 待機「朝下」一幀裁切矩形（造型預覽用）。
static func pixeline_preview_idle_down_rect() -> Rect2:
	var col := PIXELINE_IDLE_STILL_FRAME
	var row := pixeline_idle_sheet_row(0)
	return Rect2(float(col * PIXELINE_FRAME_W), float(row * PIXELINE_FRAME_H), float(PIXELINE_FRAME_W), float(PIXELINE_FRAME_H))


## 角色格在表中的左上角（像素）。slot 0..7：左到右先上排四再下排四。
static func rm_character_origin_px(slot: int) -> Vector2i:
	var s := clampi(slot, 0, 7)
	var col := s % 4
	var row := s / 4
	var pw := RM_FRAME_PX * RM_CHAR_HFRAMES
	var ph := RM_FRAME_PX * RM_CHAR_VFRAMES
	return Vector2i(col * pw, row * ph)


static func loose_tex(kind: int) -> Texture2D:
	ensure_baked()
	match kind:
		0:
			return _loose_wood
		1:
			return _loose_stone
		2:
			return _loose_seed
		3:
			return _loose_slime
		4:
			return _loose_leather
		5:
			return _loose_meat
		6:
			return _loose_mushroom
	return _loose_wood


static func icon_wood() -> Texture2D:
	ensure_baked()
	return _icon_wood


static func icon_stone() -> Texture2D:
	ensure_baked()
	return _icon_stone


static func icon_seed() -> Texture2D:
	ensure_baked()
	return _icon_seed


static func icon_axe() -> Texture2D:
	ensure_baked()
	return _icon_axe


static func campfire_tex() -> Texture2D:
	ensure_baked()
	return _campfire


## 回傳實際可 `ResourceLoader.exists` 的 override 路徑（含大小寫容錯）。
static func _resolve_override_texture_path(file_name: String) -> String:
	var exact := OVERRIDE_DIR.path_join(file_name)
	if ResourceLoader.exists(exact):
		return exact
	var want := file_name.to_lower()
	var d := DirAccess.open(OVERRIDE_DIR.trim_suffix("/"))
	if d == null:
		return exact
	for fn in d.get_files():
		if fn.to_lower() == want:
			return OVERRIDE_DIR.path_join(fn)
	return exact


static func _load_or_make(file_name: String, maker: Callable, max_long_side: int = 0) -> Texture2D:
	var path := _resolve_override_texture_path(file_name)
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			var tex := res as Texture2D
			if max_long_side > 0:
				return _fit_long_side(tex, max_long_side, path)
			return tex
	return maker.call() as Texture2D


static func _fit_long_side(tex: Texture2D, max_side: int, path_for_log: String) -> Texture2D:
	var sz := tex.get_size()
	var mx := int(maxf(sz.x, sz.y))
	if mx <= max_side:
		return tex
	var img := tex.get_image()
	if img == null:
		push_warning("VisualRegistry: 無法讀取像素，略過自動縮放：%s" % path_for_log)
		return tex
	var scale := float(max_side) / float(mx)
	var nw := maxi(1, int(floorf(sz.x * scale)))
	var nh := maxi(1, int(floorf(sz.y * scale)))
	var dup := img.duplicate()
	dup.resize(nw, nh, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(dup)


static func _img_to_tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _scale_nearest(src: ImageTexture, w: int, h: int) -> ImageTexture:
	var img := src.get_image()
	if img == null:
		return src
	var scaled := img.duplicate()
	scaled.resize(w, h, Image.INTERPOLATE_NEAREST)
	return _img_to_tex(scaled)


static func _fill_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var r2 := r * r
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			var dx := x - cx
			var dy := y - cy
			if dx * dx + dy * dy <= r2 and x >= 0 and x < w and y >= 0 and y < h:
				img.set_pixel(x, y, col)


static func _fill_rect(img: Image, rect: Rect2i, col: Color) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
				img.set_pixel(x, y, col)


static func _make_tree_texture() -> Texture2D:
	var img := Image.create(72, 80, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, Rect2i(30, 44, 12, 28), Color("#4e342e"))
	_fill_rect(img, Rect2i(28, 42, 16, 4), Color("#3e2723"))
	_fill_circle(img, 36, 28, 22, Color("#1b5e20"))
	_fill_circle(img, 26, 34, 14, Color("#2e7d32"))
	_fill_circle(img, 46, 32, 13, Color("#388e3c"))
	_fill_circle(img, 36, 18, 10, Color("#66bb6a"))
	return _img_to_tex(img)


static func _make_rock_texture() -> Texture2D:
	var img := Image.create(56, 52, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var grays := [Color("#78909c"), Color("#90a4ae"), Color("#607d8b"), Color("#546e7a")]
	var centers := [Vector2i(26, 24), Vector2i(18, 30), Vector2i(34, 32), Vector2i(22, 18)]
	var radii := [16, 10, 9, 8]
	for i in centers.size():
		_fill_circle(img, centers[i].x, centers[i].y, radii[i], grays[i % grays.size()])
	_fill_circle(img, 26, 24, 12, Color("#b0bec5", 0.35))
	return _img_to_tex(img)


static func _make_berry_bush_texture() -> Texture2D:
	var img := Image.create(44, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, 22, 16, 16, Color("#1b5e20"))
	_fill_circle(img, 16, 18, 10, Color("#2e7d32"))
	_fill_circle(img, 28, 20, 9, Color("#388e3c"))
	_fill_circle(img, 18, 10, 3, Color("#c62828"))
	_fill_circle(img, 26, 12, 3, Color("#c62828"))
	return _img_to_tex(img)


static func _make_player_texture(shirt: Color, _outline: Color) -> Texture2D:
	var img := Image.create(40, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, 20, 12, 9, Color("#ffccbc"))
	_fill_rect(img, Rect2i(12, 20, 16, 18), shirt)
	_fill_rect(img, Rect2i(16, 36, 8, 10), Color("#37474f"))
	_fill_rect(img, Rect2i(10, 24, 6, 4), shirt.darkened(0.15))
	_fill_rect(img, Rect2i(24, 24, 6, 4), shirt.darkened(0.15))
	return _img_to_tex(img)


static func _make_loose_log() -> Texture2D:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, Rect2i(6, 10, 16, 8), Color("#8d6e63"))
	_fill_rect(img, Rect2i(8, 8, 12, 3), Color("#a1887f"))
	_fill_circle(img, 14, 12, 3, Color("#5d4037"))
	return _img_to_tex(img)


static func _make_loose_pebble() -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, 12, 12, 8, Color("#90a4ae"))
	_fill_circle(img, 10, 10, 3, Color("#eceff1"))
	return _img_to_tex(img)


static func _make_seed_cluster() -> Texture2D:
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, 8, 10, 4, Color("#2e7d32"))
	_fill_circle(img, 14, 12, 3, Color("#43a047"))
	_fill_circle(img, 11, 6, 3, Color("#1b5e20"))
	return _img_to_tex(img)


static func _make_loose_slime() -> Texture2D:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, 12, 12, 9, Color("#26a69a"))
	_fill_circle(img, 10, 10, 3, Color("#b2dfdb", 0.75))
	return _img_to_tex(img)


static func _make_loose_leather() -> Texture2D:
	var img := Image.create(26, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, Rect2i(4, 6, 18, 10), Color("#5d4037"))
	_fill_rect(img, Rect2i(6, 8, 14, 6), Color("#795548"))
	return _img_to_tex(img)


static func _make_loose_meat() -> Texture2D:
	var img := Image.create(26, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, Rect2i(5, 7, 16, 9), Color("#c62828"))
	_fill_rect(img, Rect2i(8, 9, 10, 4), Color("#ffcdd2", 0.55))
	return _img_to_tex(img)


static func _loose_tex_from_mushroom_asset(tex: Texture2D) -> Texture2D:
	## Bombschroom 主表為精靈表：不可整張縮成 loose（會糊成雜訊）；裁左上角第一格再放大。
	var tw := int(tex.get_size().x)
	var th := int(tex.get_size().y)
	if tw == 176 and th == 336:
		var img := tex.get_image()
		if img == null:
			return _fit_long_side(tex, MAX_LOOSE_SIDE, "")
		var cell := 16
		var r := Rect2i(0, 0, cell, cell)
		var piece := img.get_region(r)
		var it := ImageTexture.create_from_image(piece)
		return _scale_nearest(it, 26, 26)
	return _fit_long_side(tex, MAX_LOOSE_SIDE, "")


static func _make_loose_wild_mushroom() -> Texture2D:
	var paths: PackedStringArray = PackedStringArray([
		"res://assets/characters/Cute_Fantasy_Enemies/Bombschroom/Bombschroom.png",
		"res://assets/characters/Cute_Fantasy_Enemies/Mushroom/Mushroom.png",
		"res://assets/characters/Cute_Fantasy_Enemies/Mushrooms/Mushroom.png",
		"res://assets/characters/Cute_Fantasy_Enemies/Mushroom/Wild_Mushroom.png",
	])
	for p in paths:
		if not ResourceLoader.exists(p):
			continue
		var res: Variant = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
		if res is Texture2D:
			return _loose_tex_from_mushroom_asset(res as Texture2D)
	var img := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, 11, 9, 8, Color("#c62828"))
	_fill_circle(img, 11, 8, 5, Color("#ffcdd2", 0.7))
	_fill_rect(img, Rect2i(9, 12, 4, 8), Color("#5d4037"))
	return _img_to_tex(img)


static func _make_icon_branch() -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, Rect2i(10, 6, 4, 14), Color("#6d4c41"))
	_fill_circle(img, 12, 8, 6, Color("#2e7d32"))
	return _img_to_tex(img)


static func _make_icon_pebble() -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, 12, 12, 8, Color("#78909c"))
	return _img_to_tex(img)


static func _make_icon_seed() -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, 12, 12, 7, Color("#388e3c"))
	return _img_to_tex(img)


static func _make_icon_axe() -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_rect(img, Rect2i(10, 4, 3, 16), Color("#5d4037"))
	_fill_rect(img, Rect2i(4, 6, 10, 6), Color("#78909c"))
	_fill_rect(img, Rect2i(3, 7, 4, 4), Color("#b0bec5"))
	return _img_to_tex(img)


static func _make_campfire_texture() -> Texture2D:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_circle(img, 24, 28, 14, Color("#bf360c", 0.45))
	_fill_circle(img, 24, 26, 10, Color("#e64a19", 0.55))
	_fill_circle(img, 22, 22, 6, Color("#ff9800"))
	_fill_circle(img, 28, 20, 5, Color("#ffeb3b"))
	_fill_rect(img, Rect2i(18, 32, 4, 8), Color("#4e342e"))
	_fill_rect(img, Rect2i(26, 32, 4, 8), Color("#4e342e"))
	return _img_to_tex(img)
