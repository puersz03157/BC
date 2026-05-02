class_name VisualRegistry
extends RefCounted
## 集中管理遊戲內貼圖。若 `res://assets/override/` 下有同名 PNG，會優先使用，方便你換成 Aseprite／素材包輸出。
## 否則使用內建程式烘焙（像素風暫代）。

const OVERRIDE_DIR := "res://assets/override/"
## 外部 PNG 最長邊超過此值時，會用最近鄰縮小（與內建烘焙尺寸對齊，避免整張原畫塞滿畫面）。
const MAX_PLAYER_SIDE := 56
const MAX_TREE_SIDE := 96
const MAX_ROCK_SIDE := 72
const MAX_LOOSE_SIDE := 40
const MAX_CAMPFIRE_SIDE := 56

static var _tree: Texture2D
static var _rock: Texture2D
static var _player1: Texture2D
static var _player2: Texture2D
static var _loose_wood: Texture2D
static var _loose_stone: Texture2D
static var _loose_seed: Texture2D
static var _icon_wood: Texture2D
static var _icon_stone: Texture2D
static var _icon_seed: Texture2D
static var _icon_axe: Texture2D
static var _campfire: Texture2D
static var _baked: bool = false


static func ensure_baked() -> void:
	if _baked:
		return
	_baked = true
	_tree = _load_or_make("tree.png", _make_tree_texture, MAX_TREE_SIDE)
	_rock = _load_or_make("rock.png", _make_rock_texture, MAX_ROCK_SIDE)
	_player1 = _load_or_make("player1.png", func() -> Texture2D: return _make_player_texture(Color("#3498db"), Color("#1a5276")), MAX_PLAYER_SIDE)
	_player2 = _load_or_make("player2.png", func() -> Texture2D: return _make_player_texture(Color("#9b59b6"), Color("#4a235a")), MAX_PLAYER_SIDE)
	_loose_wood = _load_or_make("loose_wood.png", func() -> Texture2D: return _make_loose_log(), MAX_LOOSE_SIDE)
	_loose_stone = _load_or_make("loose_stone.png", func() -> Texture2D: return _make_loose_pebble(), MAX_LOOSE_SIDE)
	_loose_seed = _load_or_make("loose_seed.png", func() -> Texture2D: return _make_seed_cluster(), MAX_LOOSE_SIDE)
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


static func player_tex(idx: int) -> Texture2D:
	ensure_baked()
	return _player1 if idx == 0 else _player2


static func loose_tex(kind: int) -> Texture2D:
	ensure_baked()
	match kind:
		0:
			return _loose_wood
		1:
			return _loose_stone
		2:
			return _loose_seed
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


static func _load_or_make(file_name: String, maker: Callable, max_long_side: int = 0) -> Texture2D:
	var path := OVERRIDE_DIR.path_join(file_name)
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
