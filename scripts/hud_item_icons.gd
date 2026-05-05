class_name HudItemIcons
extends RefCounted
## 底部 HUD 道具圖示路徑集中於此。補圖時可覆寫同路徑檔案，或改常數指向新檔（建議仍放 `assets/ui/hud_icons/`）。
## 技能 PNG：`skill_character_dash.png`（E 角色技）、`skill_weapon_spear_whirl.png`（木槍 Q）、`skill_weapon_daggers_strip.png`（直向三格：上＝石短劍 Q、中＝預設、下＝石斧 Q）。
## 目前檔名：wood.svg, stone.svg, seed.svg, water.svg, dirt.svg, turnip*.png, main_empty.svg, axe.svg, wood_spear.svg, iron_sword.svg,
## offhand_none.svg, armor_default.svg, accessory_none.svg, campfire.svg, workbench.svg, floor.svg,
## fence.svg, door.svg, dismantle.svg, _generic.svg（可當未分類道具預設圖）。

const DIR := "res://assets/ui/hud_icons/"

## 主手：空手／石斧（refresh 時切換）
const MAIN_EMPTY := DIR + "main_empty.svg"
const AXE := DIR + "axe.svg"
const OFFHAND_NONE := DIR + "offhand_none.svg"
const ARMOR_DEFAULT := DIR + "armor_default.svg"
const ACCESSORY_NONE := DIR + "accessory_none.svg"
const WOOD := DIR + "wood.svg"
const STONE := DIR + "stone.svg"
const SEED := DIR + "seed.svg"
const BERRY := DIR + "berry.svg"
const BERRY_JERKY := DIR + "berry_jerky.svg"
const WATER := DIR + "water.svg"
const DIRT := DIR + "dirt.svg"
const TURNIP := DIR + "turnip.png"
const TURNIP_SEEDS := DIR + "turnip_seeds.png"
## 耕地作物階段美術（預留）。
const TURNIP_SPROUT := DIR + "turnip_sprout.png"
const CAMPFIRE := DIR + "campfire.svg"
const WORKBENCH := DIR + "workbench.svg"
const FLOOR := DIR + "floor.svg"
const FENCE := DIR + "fence.svg"
const DOOR := DIR + "door.svg"
const DISMANTLE := DIR + "dismantle.svg"
## 未指定專用圖時的通用佔位（可換成自訂 PNG／SVG）
const GENERIC := DIR + "_generic.svg"
## 左上角生命／飽食／地名／金錢列小圖示。
const VITALS_HEART := DIR + "vitals_heart.svg"
const VITALS_MAP := DIR + "vitals_map.svg"
const VITALS_LIGHTNING := DIR + "vitals_lightning.svg"
const VITALS_COIN := DIR + "vitals_coin.svg"
## 武器圖示：預設為專案內簡圖；要換美術請覆寫同路徑或改下列常數為新檔名。
const WOOD_SPEAR := DIR + "wood_spear.svg"
const IRON_SWORD := DIR + "iron_sword.svg"
## 快捷列旁「Q 武器技能」預設圖（無長條圖或主手非槍／劍時）。
const WEAPON_SKILL_Q := DIR + "iron_sword.svg"
## 角色技能（短衝刺）PNG。
const CHARACTER_DASH := DIR + "skill_character_dash.png"
## 蓄力／鐵壁角色技能圖（可覆寫同檔名替換美術）。
const CHARACTER_CHARGE := DIR + "skill_charge.png"
const CHARACTER_IRON_WALL := DIR + "skill_iron_wall.png"
## 木槍武器技（迴旋）PNG。
const SKILL_SPEAR_WHIRL := DIR + "skill_weapon_spear_whirl.png"
## 直向三格匕首條：石短劍技用上格、預設／石斧用下格、中格備用。
const SKILL_DAGGERS_STRIP := DIR + "skill_weapon_daggers_strip.png"

static var _dagger_strip_slices: Array[Texture2D] = []
## 森林掉落與食物／防具。
const SLIME := DIR + "slime.svg"
const WILD_MUSHROOM := DIR + "mushroom.svg"
const LEATHER := DIR + "leather.svg"
const MEAT_CUTLET := DIR + "meat_cutlet.svg"
const BBQ_MEAT := DIR + "bbq_meat.svg"
const STICKY_ARMOR := DIR + "_generic.svg"

static var _fallback: ImageTexture


static func tex(path: String) -> Texture2D:
	if path.is_empty():
		return _missing_texture()
	if ResourceLoader.exists(path):
		var res: Variant = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if res is Texture2D:
			return res as Texture2D
	return _missing_texture()


## 快捷列「Q」武器技能圖：依 1P 主手切換美術圖。
static func weapon_skill_icon_for_main(main_weapon: StringName) -> Texture2D:
	match main_weapon:
		&"wood_spear":
			return tex(SKILL_SPEAR_WHIRL)
		&"iron_sword":
			return _dagger_strip_frame(0)
		&"axe":
			return _dagger_strip_frame(2)
		_:
			return _dagger_strip_frame(1)


static func character_skill_tex(skill: StringName) -> Texture2D:
	match skill:
		&"dash":
			return tex(CHARACTER_DASH)
		&"charge":
			return tex(CHARACTER_CHARGE)
		&"iron_wall":
			return tex(CHARACTER_IRON_WALL)
		_:
			return tex(CHARACTER_DASH)


static func _dagger_strip_frame(row_index: int) -> Texture2D:
	_ensure_dagger_strip_slices()
	if _dagger_strip_slices.is_empty():
		return tex(WEAPON_SKILL_Q)
	var i := clampi(row_index, 0, _dagger_strip_slices.size() - 1)
	return _dagger_strip_slices[i]


static func _ensure_dagger_strip_slices() -> void:
	if not _dagger_strip_slices.is_empty():
		return
	if not ResourceLoader.exists(SKILL_DAGGERS_STRIP):
		return
	var src: Variant = ResourceLoader.load(SKILL_DAGGERS_STRIP, "", ResourceLoader.CACHE_MODE_REUSE)
	if not (src is Texture2D):
		return
	var full := src as Texture2D
	var sz := full.get_size()
	if sz.y < 6.0:
		return
	var w := int(sz.x)
	var h := int(roundf(sz.y / 3.0))
	for row in 3:
		var at := AtlasTexture.new()
		at.atlas = full
		at.region = Rect2i(0, row * h, w, h)
		_dagger_strip_slices.append(at)


static func stackable_icon_path(id: StringName) -> String:
	match id:
		&"wood":
			return WOOD
		&"stone":
			return STONE
		&"berries":
			return BERRY
		&"berry_jerky":
			return BERRY_JERKY
		&"seed":
			return SEED
		&"water":
			return WATER
		&"dirt":
			return DIRT
		&"turnip_seeds":
			return TURNIP_SEEDS
		&"turnip":
			return TURNIP
		&"slime_goo":
			return SLIME
		&"wild_mushroom":
			return WILD_MUSHROOM
		&"leather":
			return LEATHER
		&"meat_cutlet":
			return MEAT_CUTLET
		&"bbq_meat":
			return BBQ_MEAT
		&"axe_spare":
			return AXE
		&"spear_spare":
			return WOOD_SPEAR
		&"sword_spare":
			return IRON_SWORD
		&"sticky_armor_spare":
			return STICKY_ARMOR
		_:
			return GENERIC


## 背包格懸浮提示用中文名（與 stackable_icon_path 的 id 對齊）。
static func stackable_display_name_zh(id: StringName) -> String:
	match id:
		&"wood":
			return "木材"
		&"stone":
			return "石材"
		&"berries":
			return "莓果"
		&"berry_jerky":
			return "莓果干"
		&"seed":
			return "樹種"
		&"water":
			return "水"
		&"dirt":
			return "黏土"
		&"turnip_seeds":
			return "蕪菁種子"
		&"turnip":
			return "蕪菁"
		&"slime_goo":
			return "史萊姆黏液"
		&"wild_mushroom":
			return "野菇"
		&"leather":
			return "皮革"
		&"meat_cutlet":
			return "生肉排"
		&"bbq_meat":
			return "烤肉"
		&"axe_spare":
			return "石斧（備用）"
		&"spear_spare":
			return "木製長槍（備用）"
		&"sword_spare":
			return "石製短劍（備用）"
		&"sticky_armor_spare":
			return "黏黏護甲（備用）"
		_:
			return "道具"


static func _missing_texture() -> Texture2D:
	if _fallback != null:
		return _fallback
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.24, 0.3, 1.0))
	for i in range(24):
		img.set_pixel(i, i, Color(0.82, 0.84, 0.88, 1.0))
		img.set_pixel(23 - i, i, Color(0.82, 0.84, 0.88, 1.0))
	_fallback = ImageTexture.create_from_image(img)
	return _fallback
