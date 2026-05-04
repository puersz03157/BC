extends RefCounted
class_name CuteFantasyUiBars
## Cute Fantasy UI `UI_Bars.png` 裁切小圖（僅供 TextureProgressBar，避免 ProgressBar+Atlas 取樣錯誤）。

const ATLAS_PATH := "res://assets/ui/Cute_Fantasy_UI/UI/UI_Bars.png"
## 大條下方空槽（勿含 y33+ 的模組化五格小條，否則會疊在量表底下）。
const R_TRACK := Rect2i(2, 21, 92, 12)
const CACHE_VER := 2
## 中條亮紅內芯（怪物血／可選）。
const R_FILL_RED := Rect2i(214, 10, 12, 3)
## 中條青藍內芯（技能 CD）。
const R_FILL_CYAN := Rect2i(211, 14, 16, 3)

static var _cache_built_ver: int = -1
static var _tex_track: ImageTexture
static var _tex_red: ImageTexture
static var _tex_cyan: ImageTexture


static func _crop_or_null(img: Image, r: Rect2i) -> ImageTexture:
	var rr := r
	rr.size.x = mini(rr.size.x, img.get_width() - rr.position.x)
	rr.size.y = mini(rr.size.y, img.get_height() - rr.position.y)
	if rr.size.x < 1 or rr.size.y < 1:
		return null
	return ImageTexture.create_from_image(img.get_region(rr))


static func ensure_loaded() -> bool:
	if _cache_built_ver == CACHE_VER:
		return _tex_track != null
	var img: Image = null
	var tex: Texture2D = load(ATLAS_PATH) as Texture2D
	if tex != null:
		img = tex.get_image()
	if img == null or img.is_empty():
		img = Image.load_from_file(ATLAS_PATH)
	if img == null or img.is_empty():
		_cache_built_ver = CACHE_VER
		return false
	_tex_track = _crop_or_null(img, R_TRACK)
	_tex_red = _crop_or_null(img, R_FILL_RED)
	_tex_cyan = _crop_or_null(img, R_FILL_CYAN)
	_cache_built_ver = CACHE_VER
	return _tex_track != null and _tex_red != null and _tex_cyan != null


static func _apply_to(tp: TextureProgressBar, fill: ImageTexture) -> bool:
	if not ensure_loaded() or _tex_track == null or fill == null:
		return false
	tp.texture_under = _tex_track
	tp.texture_progress = fill
	tp.texture_over = null
	tp.tint_under = Color.WHITE
	tp.tint_progress = Color.WHITE
	tp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tp.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	## nine_patch_stretch：讓軌道端蓋固定、中段自由縮放，fill 也同步對齊內框；
	## 否則端蓋像素會被壓縮，fill 在 100% 時仍差一截看起來不滿。
	tp.nine_patch_stretch = true
	## 左右各留 4px 給圓角端蓋；上下留 0（軌道高度恰好等於 fill 高度）。
	tp.set_stretch_margin(SIDE_LEFT,   4)
	tp.set_stretch_margin(SIDE_RIGHT,  4)
	tp.set_stretch_margin(SIDE_TOP,    0)
	tp.set_stretch_margin(SIDE_BOTTOM, 0)
	tp.rounded = false
	tp.step = 0.001
	return true


static func setup_monster_hp_bar(tp: TextureProgressBar) -> bool:
	return _apply_to(tp, _tex_red)


static func setup_skill_cd_bar(tp: TextureProgressBar) -> bool:
	return _apply_to(tp, _tex_cyan)
