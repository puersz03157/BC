class_name GameInventory
extends RefCounted
## 與網頁版一致：共用背包；主手裝備影響兩人採集判定（harvestKurt 使用 player.equip.main）

var wood: int = 0
var stone: int = 0
var seed: int = 0
var axe_spare: int = 0
var equip_main: StringName = &""


func has_axe() -> bool:
	return equip_main == &"axe" or axe_spare > 0


func craft_axe() -> bool:
	if wood < GameConstants.CRAFT_AXE_WOOD or stone < GameConstants.CRAFT_AXE_STONE:
		return false
	wood -= GameConstants.CRAFT_AXE_WOOD
	stone -= GameConstants.CRAFT_AXE_STONE
	if equip_main == &"":
		equip_main = &"axe"
	else:
		axe_spare += 1
	return true


func try_equip_axe_from_inventory() -> bool:
	if equip_main == &"axe":
		return false
	if axe_spare < 1:
		return false
	axe_spare -= 1
	equip_main = &"axe"
	return true


func can_place_campfire() -> bool:
	return wood >= GameConstants.CAMPFIRE_WOOD and stone >= GameConstants.CAMPFIRE_STONE


func spend_campfire() -> bool:
	if not can_place_campfire():
		return false
	wood -= GameConstants.CAMPFIRE_WOOD
	stone -= GameConstants.CAMPFIRE_STONE
	return true


func unequip_main_axe_to_spare() -> bool:
	if equip_main != &"axe":
		return false
	equip_main = &""
	axe_spare += 1
	return true


func try_spend_wood(amount: int) -> bool:
	if wood < amount:
		return false
	wood -= amount
	return true


func add_wood(amount: int) -> void:
	wood += amount
