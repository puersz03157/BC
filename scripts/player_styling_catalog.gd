class_name PlayerStylingCatalog
extends RefCounted
## Pixeline 造型目錄：膚色、髮型／頭飾、上衣、下裝（由資料夾掃描 .png）。

const PIXELINE_DIR := "res://assets/characters/pixeline/"

## 依檔名主鍵對應繁中顯示名（未列者退回英文詞轉空格）。
const _BASENAME_ZH: Dictionary = {
	"Base_character_Female_Beige_Shirt_Adventurer": "米色冒險者襯衫",
	"Base_character_Female_Black_Cape": "黑色披風",
	"Base_character_Female_Crown": "皇冠",
	"Base_character_Female_Dress_Royal_Blue": "皇家藍禮服",
	"Base_character_Female_Fur_Armor_Chest": "毛皮護胸",
	"Base_character_Female_Fur_Armor_Pants": "毛皮護腿褲",
	"Base_character_Female_Gold_Pants": "金色褲／裙",
	"Base_character_Female_Green_Ranger_Cape": "綠遊俠披風",
	"Base_character_Female_Hair_Bun_Peasant_Brown": "農婦棕髮包頭",
	"Base_character_Female_Hair_Gray_Bun": "灰髮髮髻",
	"Base_character_Female_Hair_Long_Blond_Glossy": "長金亮髮",
	"Base_character_Female_Hair_Long_Purple_witchy": "長紫女巫髮",
	"Base_character_Female_Hair_Long_Unisex_Black": "長黑髮（通用）",
	"Base_character_Female_Hair_Queen_Crown_Bun": "女王冠髮髻",
	"Base_character_Female_Hair_Short_Pixie": "精靈短髮",
	"Base_character_Female_Hat_Adventurer": "冒險者帽",
	"Base_character_Female_Hat_Light_Brown_Turqoiuse": "淺棕綠松石帽",
	"Base_character_Female_Hat_White_red": "白紅配色帽",
	"Base_character_Female_Hat_Witch": "女巫帽",
	"Base_character_Female_Pants_Peasant": "農夫褲",
	"Base_character_Female_Pants_Villager": "村民褲",
	"Base_character_Female_Peasant_Red_Shirt": "紅色農夫襯衫",
	"Base_character_Female_Peasant_Skirt_with_Apron": "圍裙短裙",
	"Base_character_Female_Peasant_White_Shirt": "白農夫襯衫",
	"Base_character_Female_Purple_Witch_Dress": "紫色女巫裙",
	"Base_character_Female_Spooky_Pumpkin": "南瓜頭（女）",
	"Base_character_Female_Villager_Pink_Skirt": "村民粉紅裙襬",
	"Base_character_Male_Cape_Black": "黑色披風",
	"Base_character_Male_Cape_Green_Ranger": "綠遊俠披風",
	"Base_character_Male_Fur_Armor": "毛皮護甲（上身）",
	"Base_character_Male_Hair_Blonde_with_beard": "金髮蓄鬍",
	"Base_character_Male_Hat_Adventurer": "冒險者帽",
	"Base_character_Male_Hat_Wizard": "巫師帽",
	"Base_character_Male_Helmet_Knight_Closed": "騎士全罩頭盔",
	"Base_character_Male_King_Cloak": "君王斗篷",
	"Base_character_Male_King_Crown": "王者皇冠",
	"Base_character_Male_Knight_Cape": "騎士披風",
	"Base_character_Male_Long_Hair_Black_Unisex": "長黑髮（通用）",
	"Base_character_Male_Old_Man_Hair_Elegant": "優雅長者髮型",
	"Base_character_Male_Pants_Fur_Pants": "毛皮褲",
	"Base_character_Male_Pants_Noble_Gold": "貴族金褲",
	"Base_character_Male_Pants_Peasant": "農夫褲",
	"Base_character_Male_Pants_Villager": "村民褲",
	"Base_character_Male_Pants_Villager_red": "村民紅褲",
	"Base_character_Male_Shirt_beige": "米色襯衫",
	"Base_character_Male_Shirt_Royal_Blue": "皇家藍襯衫",
	"Base_character_Male_Shirt_Royal_Red": "皇家紅襯衫",
	"Base_character_Male_Shirt_with_Vest_brown": "棕背心襯衫",
	"Base_character_Male_Shirt_with_Vest_RED_Elegant": "紅色優雅背心襯衫",
	"Base_character_Male_Short_Brown": "短棕髮",
	"Base_character_Male_Short_Dark_Blonde": "短深金髮",
	"Base_character_Male_Spooky_Pumpkin": "南瓜頭（男）",
	"Base_character_Male_Steel_Armor_Chest": "鋼鐵胸甲",
	"Base_character_Male_Steel_Armor_Legs": "鋼鐵護腿",
}


static func skin_keys() -> Array[String]:
	return ["medium", "pale", "tanned", "dark", "pinkish"]


static func skin_label_zh(key: String) -> String:
	match key:
		"medium":
			return "中等膚色"
		"pale":
			return "白皙"
		"tanned":
			return "褐色／曬色"
		"dark":
			return "深色"
		"pinkish":
			return "偏粉"
		_:
			return key


static func base_body_path(gender_male: bool, skin_key: String) -> String:
	var fn := ""
	if gender_male:
		match skin_key:
			"medium":
				fn = "Base_character_Itchio_all_Male_medium.png"
			"pale":
				fn = "Base_character_Itchio_all_Male_Pale.png"
			"tanned":
				fn = "Base_character_Itchio_all_Male_tanned.png"
			"dark":
				fn = "Base_character_Itchio_all_Male_dark.png"
			"pinkish":
				fn = "Base_character_Itchio_all_Male_Pinkish.png"
	else:
		match skin_key:
			"medium":
				fn = "Base_character_Itchio_all_Female_Medium.png"
			"pale":
				fn = "Base_character_Itchio_all_Female_Pale.png"
			"tanned":
				fn = "Base_character_Itchio_all_Female_Tanned.png"
			"dark":
				fn = "Base_character_Itchio_all_Female_Dark.png"
			"pinkish":
				fn = "Base_character_Itchio_all_Female_Pinkish.png"
	if fn.is_empty():
		return ""
	return PIXELINE_DIR + fn


## 開局免費解鎖（其餘須購買／劇情解鎖）；路徑須與掃描結果一致。
static func starter_unlock_paths() -> PackedStringArray:
	return PackedStringArray([
		PIXELINE_DIR + "Hair Male/Base_character_Male_Short_Brown.png",
		PIXELINE_DIR + "Hair Male/Base_character_Male_Short_Dark_Blonde.png",
		PIXELINE_DIR + "Hair Male/Base_character_Male_Long_Hair_Black_Unisex.png",
		PIXELINE_DIR + "Hair Female/Base_character_Female_Hair_Short_Pixie.png",
		PIXELINE_DIR + "Hair Female/Base_character_Female_Hair_Bun_Peasant_Brown.png",
		PIXELINE_DIR + "Hair Female/Base_character_Female_Hair_Long_Blond_Glossy.png",
		PIXELINE_DIR + "Clothes Male/Chest/Base_character_Male_Shirt_beige.png",
		PIXELINE_DIR + "Clothes Male/Chest/Base_character_Male_Shirt_with_Vest_brown.png",
		PIXELINE_DIR + "Clothes Male/Chest/Base_character_Male_Cape_Green_Ranger.png",
		PIXELINE_DIR + "Clothes Female/Chest/Base_character_Female_Peasant_White_Shirt.png",
		PIXELINE_DIR + "Clothes Female/Chest/Base_character_Female_Beige_Shirt_Adventurer.png",
		PIXELINE_DIR + "Clothes Female/Chest/Base_character_Female_Green_Ranger_Cape.png",
		PIXELINE_DIR + "Clothes Male/Pants/Base_character_Male_Pants_Villager.png",
		PIXELINE_DIR + "Clothes Male/Pants/Base_character_Male_Pants_Peasant.png",
		PIXELINE_DIR + "Clothes Male/Pants/Base_character_Male_Pants_Villager_red.png",
		PIXELINE_DIR + "Clothes Female/Legs/Base_character_Female_Pants_Villager.png",
		PIXELINE_DIR + "Clothes Female/Legs/Base_character_Female_Peasant_Skirt_with_Apron.png",
		PIXELINE_DIR + "Clothes Female/Legs/Base_character_Female_Fur_Armor_Pants.png",
	])


static func _collect_png_sorted(dir_res: String) -> Array[String]:
	var out: Array[String] = []
	var base := dir_res.rstrip("/")
	var da := DirAccess.open(base)
	if da == null:
		return out
	var err := da.list_dir_begin()
	if err != OK:
		return out
	while true:
		var fn := da.get_next()
		if fn == "":
			break
		if da.current_is_dir():
			continue
		if not fn.ends_with(".png"):
			continue
		out.append(base.path_join(fn))
	da.list_dir_end()
	out.sort()
	return out


static func _pretty_label_from_path(path: String) -> String:
	var stem := path.get_file().get_basename()
	for prefix in ["Base_character_Male_", "Base_character_Female_"]:
		if stem.begins_with(prefix):
			stem = stem.substr(prefix.length())
			break
	return stem.replace("_", " ")


## 下拉選單顯示用繁中名；path 空為「（無）」；Head 資料夾圖會加【頭飾】前綴。
static func display_label_zh(path: String) -> String:
	if path.is_empty():
		return "（無）"
	var key := path.get_file().get_basename()
	var zh: Variant = _BASENAME_ZH.get(key, "")
	var base_zh: String = str(zh) if str(zh) != "" else _pretty_label_from_path(path)
	if path.contains("/Head/"):
		return "【頭飾】" + base_zh
	return base_zh


## { "label": String, "path": String }；path 空＝無。含髮型資料夾 + 頭飾（Head）圖，頭飾仍畫在髮層。
static func hair_rows(gender_male: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"label": "（無）", "path": ""}]
	var hair_sub := "Hair Male/" if gender_male else "Hair Female/"
	var head_sub := "Clothes Male/Head/" if gender_male else "Clothes Female/Head/"
	for p in _collect_png_sorted(PIXELINE_DIR + hair_sub):
		rows.append({"label": _pretty_label_from_path(p), "path": p})
	for p in _collect_png_sorted(PIXELINE_DIR + head_sub):
		rows.append({"label": _pretty_label_from_path(p), "path": p})
	return rows


static func outfit_rows(gender_male: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"label": "（無）", "path": ""}]
	var chest_sub := "Clothes Male/Chest/" if gender_male else "Clothes Female/Chest/"
	for p in _collect_png_sorted(PIXELINE_DIR + chest_sub):
		rows.append({"label": _pretty_label_from_path(p), "path": p})
	return rows


## 下半身（男＝ Pants、女＝ Legs）；與主表同格裁切。
static func pants_rows(gender_male: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = [{"label": "（無）", "path": ""}]
	var legs_sub := "Clothes Male/Pants/" if gender_male else "Clothes Female/Legs/"
	for p in _collect_png_sorted(PIXELINE_DIR + legs_sub):
		rows.append({"label": _pretty_label_from_path(p), "path": p})
	return rows


## 溪谷村落 NPC：Pixeline 字典（gender_male, skin, hair, outfit, pants）。供 Main／RmStationaryNpc 使用。
static func valley_npc_preset_instructor() -> Dictionary:
	return {
		"gender_male": true,
		"skin": "medium",
		"hair": PIXELINE_DIR + "Hair Male/Base_character_Male_Short_Brown.png",
		"outfit": PIXELINE_DIR + "Clothes Male/Chest/Base_character_Male_Shirt_beige.png",
		"pants": PIXELINE_DIR + "Clothes Male/Pants/Base_character_Male_Pants_Villager.png",
	}


static func valley_npc_preset_merchant() -> Dictionary:
	return {
		"gender_male": false,
		"skin": "medium",
		"hair": PIXELINE_DIR + "Hair Female/Base_character_Female_Hair_Short_Pixie.png",
		"outfit": PIXELINE_DIR + "Clothes Female/Chest/Base_character_Female_Beige_Shirt_Adventurer.png",
		"pants": PIXELINE_DIR + "Clothes Female/Legs/Base_character_Female_Pants_Villager.png",
	}


static func valley_npc_preset_steward() -> Dictionary:
	return {
		"gender_male": true,
		"skin": "pale",
		"hair": PIXELINE_DIR + "Hair Male/Base_character_Male_Old_Man_Hair_Elegant.png",
		"outfit": PIXELINE_DIR + "Clothes Male/Chest/Base_character_Male_Shirt_Royal_Red.png",
		"pants": PIXELINE_DIR + "Clothes Male/Pants/Base_character_Male_Pants_Noble_Gold.png",
	}


static func valley_npc_preset_village_chief() -> Dictionary:
	return {
		"gender_male": false,
		"skin": "medium",
		"hair": PIXELINE_DIR + "Hair Female/Base_character_Female_Hair_Bun_Peasant_Brown.png",
		"outfit": PIXELINE_DIR + "Clothes Female/Chest/Base_character_Female_Peasant_White_Shirt.png",
		"pants": PIXELINE_DIR + "Clothes Female/Legs/Base_character_Female_Peasant_Skirt_with_Apron.png",
	}
