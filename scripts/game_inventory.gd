class_name GameInventory
extends RefCounted
## 固定格數 + 堆疊上限的背包；裝備欄（主手／防具）仍獨立於格位。之後可改 slot_count、stack_limit 擴充。

var slot_count: int = GameConstants.INVENTORY_SLOT_COUNT_DEFAULT
var stack_limit: int = GameConstants.INVENTORY_STACK_LIMIT_DEFAULT
## 每格：null 或 { "id": StringName, "q": int }
var slots: Array = []

## 1P 主手武器。
var equip_main: StringName = &""
## 2P 主手武器（雙人模式；與 1P 共用背包格）。
var equip_main_p2: StringName = &""
## 防具：空＝便服；黏黏護甲。
var armor_equipped: StringName = &""
## 由 Main 同步雙人模式。為 false 時，工作台／序章製作武器只會裝到 1P 主手或備用格，不會寫入 equip_main_p2（否則單人時材料消失但看不到槍／劍）。
var dual_main_weapon_slots_enabled: bool = false


func _init() -> void:
	_ensure_slot_array()


func _ensure_slot_array() -> void:
	slot_count = maxi(1, slot_count)
	stack_limit = maxi(1, stack_limit)
	while slots.size() < slot_count:
		slots.append(null)
	while slots.size() > slot_count:
		slots.pop_back()


func set_slot_count_for_upgrade(new_count: int) -> void:
	slot_count = clampi(new_count, 1, GameConstants.INVENTORY_SLOT_COUNT_DEFAULT)
	_ensure_slot_array()


func set_stack_limit_for_upgrade(new_limit: int) -> void:
	stack_limit = clampi(new_limit, 1, 9999)


func _item_count(id: StringName) -> int:
	var n := 0
	for s in slots:
		if s == null:
			continue
		if not s is Dictionary:
			continue
		var d := s as Dictionary
		if StringName(d.get("id", &"")) == id:
			n += int(d.get("q", 0))
	return n


func get_slot_snapshot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slots.size():
		return {}
	var s: Variant = slots[slot_index]
	if s == null or not s is Dictionary:
		return {}
	var d := s as Dictionary
	var idv: Variant = d.get("id", &"")
	var id: StringName
	if idv is StringName:
		id = idv
	else:
		id = StringName(str(idv))
	var q := maxi(0, int(d.get("q", 0)))
	if id == &"" or q <= 0:
		return {}
	return {"id": id, "q": q}


## 從指定格扣減數量（僅該格）；回傳實際扣下的數量。
func remove_quantity_from_slot(slot_index: int, quantity: int) -> int:
	if slot_index < 0 or slot_index >= slots.size() or quantity <= 0:
		return 0
	var s: Variant = slots[slot_index]
	if s == null or not s is Dictionary:
		return 0
	var d := s as Dictionary
	var fid: StringName = StringName(d.get("id", &""))
	var fq := int(d.get("q", 0))
	if fid == &"" or fq <= 0:
		return 0
	var rm := mini(quantity, fq)
	fq -= rm
	if fq <= 0:
		slots[slot_index] = null
	else:
		d["q"] = fq
		slots[slot_index] = d
	return rm


func item_count(id: StringName) -> int:
	return _item_count(id)


## 多個倉儲加總某材料數量（[玩家背包, 地上箱子, …]）。
static func count_in_pools(pools: Array[GameInventory], id: StringName) -> int:
	var n := 0
	for p in pools:
		if p != null:
			n += p._item_count(id)
	return n


## 依序從多個倉儲扣材料（先扣第一個，再扣第二個…）。
static func remove_from_pools_ordered(pools: Array[GameInventory], id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	var need := amount
	for p in pools:
		if p == null or need <= 0:
			break
		var have := p._item_count(id)
		var take := mini(have, need)
		if take > 0:
			if not p.try_remove_item(id, take):
				return false
			need -= take
	return need <= 0


static func refund_to_inventory(inv: GameInventory, id: StringName, amount: int) -> void:
	if inv == null or amount <= 0:
		return
	inv.try_add_item(id, amount)


## 建造用：營火材料是否足夠（背包＋本區所有箱子格位加總）。
static func pools_can_spend_campfire(pools: Array[GameInventory]) -> bool:
	return (
		count_in_pools(pools, &"wood") >= GameConstants.CAMPFIRE_WOOD
		and count_in_pools(pools, &"stone") >= GameConstants.CAMPFIRE_STONE
	)


## 建造用：從 pools 依序扣營火材料；失敗時已扣的木頭會退回 `pools[0]`（玩家背包）。
static func pools_try_spend_campfire(pools: Array[GameInventory]) -> bool:
	if not pools_can_spend_campfire(pools):
		return false
	if not remove_from_pools_ordered(pools, &"wood", GameConstants.CAMPFIRE_WOOD):
		return false
	if not remove_from_pools_ordered(pools, &"stone", GameConstants.CAMPFIRE_STONE):
		if pools.size() > 0 and pools[0] != null:
			refund_to_inventory(pools[0], &"wood", GameConstants.CAMPFIRE_WOOD)
		return false
	return true


## 建造用：扣木材／石頭；石頭扣失敗時退回已扣木材至 `pools[0]`。
static func pools_try_spend_build_wood_stone(
	pools: Array[GameInventory], cost_w: int, cost_s: int
) -> bool:
	if cost_w < 0 or cost_s < 0:
		return false
	if cost_w > 0 and not remove_from_pools_ordered(pools, &"wood", cost_w):
		return false
	if cost_s > 0 and not remove_from_pools_ordered(pools, &"stone", cost_s):
		if cost_w > 0 and pools.size() > 0 and pools[0] != null:
			refund_to_inventory(pools[0], &"wood", cost_w)
		return false
	return true


## 非玩家背包的儲物：只存格位（存檔用，不含裝備欄位）。
func storage_serialize() -> Dictionary:
	return {"slots": _serialize_slots()}


func storage_deserialize(d: Dictionary) -> void:
	slot_count = GameConstants.CHEST_SLOT_COUNT
	stack_limit = GameConstants.CHEST_STACK_LIMIT
	slots.clear()
	_ensure_slot_array()
	if d.has("slots") and d.get("slots") is Array:
		_deserialize_slots(d.get("slots"))
	_ensure_slot_array()


## 兩倉儲之間單格移動／合併／交換；合併以上限較大者依「目標格所屬倉儲」的 stack_limit 為準。
static func apply_slot_transfer_between(
	from_inv: GameInventory, from_idx: int, to_inv: GameInventory, to_idx: int
) -> bool:
	if from_idx < 0 or to_idx < 0:
		return false
	if from_idx >= from_inv.slot_count or to_idx >= to_inv.slot_count:
		return false
	if from_inv == to_inv:
		return from_inv.apply_backpack_slot_drag(from_idx, to_idx)
	var src: Variant = from_inv.slots[from_idx]
	if src == null or not src is Dictionary:
		return false
	var fd := src as Dictionary
	var fid: StringName = StringName(fd.get("id", &""))
	var fq := int(fd.get("q", 0))
	if fid == &"" or fq <= 0:
		return false
	var tgt: Variant = to_inv.slots[to_idx]
	if tgt == null:
		var move: Dictionary = (fd as Dictionary).duplicate()
		to_inv.slots[to_idx] = move
		from_inv.slots[from_idx] = null
		return true
	if not tgt is Dictionary:
		return false
	var td := tgt as Dictionary
	var tid: StringName = StringName(td.get("id", &""))
	var tq := int(td.get("q", 0))
	if tid == &"" or tq <= 0:
		var move2: Dictionary = (fd as Dictionary).duplicate()
		to_inv.slots[to_idx] = move2
		from_inv.slots[from_idx] = null
		return true
	var to_limit := to_inv.stack_limit
	if fid == tid:
		if tq >= to_limit:
			var tmp: Variant = from_inv.slots[from_idx]
			from_inv.slots[from_idx] = to_inv.slots[to_idx]
			to_inv.slots[to_idx] = tmp
			return true
		var room: int = to_limit - tq
		var mv: int = mini(room, fq)
		if mv <= 0:
			var tmp2: Variant = from_inv.slots[from_idx]
			from_inv.slots[from_idx] = to_inv.slots[to_idx]
			to_inv.slots[to_idx] = tmp2
			return true
		td["q"] = tq + mv
		fq -= mv
		to_inv.slots[to_idx] = td
		if fq <= 0:
			from_inv.slots[from_idx] = null
		else:
			fd["q"] = fq
			from_inv.slots[from_idx] = fd
		return true
	var tmp3: Variant = from_inv.slots[from_idx]
	from_inv.slots[from_idx] = to_inv.slots[to_idx]
	to_inv.slots[to_idx] = tmp3
	return true


func _pools_with(extra_storages: Array[GameInventory]) -> Array[GameInventory]:
	var a: Array[GameInventory] = [self]
	for e in extra_storages:
		if e != null:
			a.append(e)
	return a


## 回傳未能入格的數量（0 表示全數入包）。
func try_add_item(id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	if id == &"":
		return amount
	var left := amount
	while left > 0:
		var placed := false
		for i in slots.size():
			var s: Variant = slots[i]
			if s == null or not s is Dictionary:
				continue
			var d := s as Dictionary
			if StringName(d.get("id", &"")) != id:
				continue
			var q := int(d.get("q", 0))
			if q >= stack_limit:
				continue
			var room := stack_limit - q
			var take := mini(room, left)
			d["q"] = q + take
			slots[i] = d
			left -= take
			placed = true
			if left <= 0:
				return 0
		var empty_i := _first_empty_slot_index()
		if empty_i < 0:
			return left
		var take2 := mini(stack_limit, left)
		slots[empty_i] = {"id": id, "q": take2}
		left -= take2
		placed = true
		if not placed:
			return left
	return left


func _first_empty_slot_index() -> int:
	for i in slots.size():
		if slots[i] == null:
			return i
	return -1


## 背包拖曳：空格＝移動；同 id 且未滿則合併；目標格滿且同 id 則兩堆互換；不同 id 則互換。
func apply_backpack_slot_drag(from_idx: int, to_idx: int) -> bool:
	if from_idx == to_idx:
		return false
	if from_idx < 0 or to_idx < 0 or from_idx >= slot_count or to_idx >= slot_count:
		return false
	var src: Variant = slots[from_idx]
	if src == null or not src is Dictionary:
		return false
	var fd := src as Dictionary
	var fid: StringName = StringName(fd.get("id", &""))
	var fq := int(fd.get("q", 0))
	if fid == &"" or fq <= 0:
		return false
	var tgt: Variant = slots[to_idx]
	if tgt == null:
		slots[to_idx] = fd
		slots[from_idx] = null
		return true
	if not tgt is Dictionary:
		return false
	var td := tgt as Dictionary
	var tid: StringName = StringName(td.get("id", &""))
	var tq := int(td.get("q", 0))
	if tid == &"" or tq <= 0:
		slots[to_idx] = fd
		slots[from_idx] = null
		return true
	if fid == tid:
		if tq >= stack_limit:
			var tmp: Variant = slots[from_idx]
			slots[from_idx] = slots[to_idx]
			slots[to_idx] = tmp
			return true
		var room: int = stack_limit - tq
		var mv: int = mini(room, fq)
		if mv <= 0:
			var tmp2: Variant = slots[from_idx]
			slots[from_idx] = slots[to_idx]
			slots[to_idx] = tmp2
			return true
		td["q"] = tq + mv
		fq -= mv
		slots[to_idx] = td
		if fq <= 0:
			slots[from_idx] = null
		else:
			fd["q"] = fq
			slots[from_idx] = fd
		return true
	var tmp3: Variant = slots[from_idx]
	slots[from_idx] = slots[to_idx]
	slots[to_idx] = tmp3
	return true


func try_remove_item(id: StringName, amount: int) -> bool:
	if amount <= 0:
		return true
	if _item_count(id) < amount:
		return false
	var need := amount
	for i in slots.size():
		if need <= 0:
			break
		var s: Variant = slots[i]
		if s == null or not s is Dictionary:
			continue
		var d := s as Dictionary
		if StringName(d.get("id", &"")) != id:
			continue
		var q := int(d.get("q", 0))
		var t := mini(q, need)
		q -= t
		need -= t
		if q <= 0:
			slots[i] = null
		else:
			d["q"] = q
			slots[i] = d
	return need <= 0


func can_remove(id: StringName, amount: int) -> bool:
	return _item_count(id) >= amount


## 讀取專用：木材總量（跨格加總）。
var wood: int:
	get:
		return _item_count(&"wood")


var stone: int:
	get:
		return _item_count(&"stone")


var berries: int:
	get:
		return _item_count(&"berries")


var berry_jerky: int:
	get:
		return _item_count(&"berry_jerky")


var seed: int:
	get:
		return _item_count(&"seed")


var axe_spare: int:
	get:
		return _item_count(&"axe_spare")


var spear_spare: int:
	get:
		return _item_count(&"spear_spare")


var sword_spare: int:
	get:
		return _item_count(&"sword_spare")


var slime_goo: int:
	get:
		return _item_count(&"slime_goo")


var leather: int:
	get:
		return _item_count(&"leather")


var meat_cutlet: int:
	get:
		return _item_count(&"meat_cutlet")


var wild_mushroom: int:
	get:
		return _item_count(&"wild_mushroom")


var bbq_meat: int:
	get:
		return _item_count(&"bbq_meat")


var water: int:
	get:
		return _item_count(&"water")


var dirt: int:
	get:
		return _item_count(&"dirt")


var turnip_seeds: int:
	get:
		return _item_count(&"turnip_seeds")


var turnip: int:
	get:
		return _item_count(&"turnip")


var sticky_armor_spare: int:
	get:
		return _item_count(&"sticky_armor_spare")


func equip_main_for(player_idx: int) -> StringName:
	return equip_main if player_idx == 0 else equip_main_p2


func has_axe() -> bool:
	return equip_main == &"axe" or equip_main_p2 == &"axe" or axe_spare > 0


func equip_main_can_chop_tree() -> bool:
	return equip_main_can_chop_tree_for(0) or equip_main_can_chop_tree_for(1)


func equip_main_can_chop_tree_for(player_idx: int) -> bool:
	var w := equip_main_for(player_idx)
	return w == &"axe" or w == &"wood_spear" or w == &"iron_sword"


func craft_axe() -> bool:
	if wood < GameConstants.CRAFT_AXE_WOOD or stone < GameConstants.CRAFT_AXE_STONE:
		return false
	if not try_remove_item(&"wood", GameConstants.CRAFT_AXE_WOOD):
		return false
	if not try_remove_item(&"stone", GameConstants.CRAFT_AXE_STONE):
		## 不應發生
		try_add_item(&"wood", GameConstants.CRAFT_AXE_WOOD)
		return false
	if equip_main == &"":
		equip_main = &"axe"
	elif dual_main_weapon_slots_enabled and equip_main_p2 == &"":
		equip_main_p2 = &"axe"
	else:
		var ov := try_add_item(&"axe_spare", 1)
		if ov > 0:
			## 無格位放備用則退回材料（極罕見）
			try_add_item(&"wood", GameConstants.CRAFT_AXE_WOOD)
			try_add_item(&"stone", GameConstants.CRAFT_AXE_STONE)
			return false
	return true


func _stash_main_to_spare_for(player_idx: int) -> bool:
	var w := equip_main_for(player_idx)
	if w == &"":
		return true
	match w:
		&"axe":
			if try_add_item(&"axe_spare", 1) > 0:
				return false
		&"wood_spear":
			if try_add_item(&"spear_spare", 1) > 0:
				return false
		&"iron_sword":
			if try_add_item(&"sword_spare", 1) > 0:
				return false
		_:
			pass
	if player_idx == 0:
		equip_main = &""
	else:
		equip_main_p2 = &""
	return true


func _stash_current_main_to_spare_if_any() -> bool:
	return _stash_main_to_spare_for(0)


func try_equip_axe_from_inventory_for(player_idx: int) -> bool:
	if equip_main_for(player_idx) == &"axe":
		return false
	if axe_spare < 1:
		return false
	if not _stash_main_to_spare_for(player_idx):
		return false
	if not try_remove_item(&"axe_spare", 1):
		return false
	if player_idx == 0:
		equip_main = &"axe"
	else:
		equip_main_p2 = &"axe"
	return true


func try_equip_axe_from_inventory() -> bool:
	return try_equip_axe_from_inventory_for(0)


func try_equip_spear_from_inventory_for(player_idx: int) -> bool:
	if equip_main_for(player_idx) == &"wood_spear":
		return false
	if spear_spare < 1:
		return false
	if not _stash_main_to_spare_for(player_idx):
		return false
	if not try_remove_item(&"spear_spare", 1):
		return false
	if player_idx == 0:
		equip_main = &"wood_spear"
	else:
		equip_main_p2 = &"wood_spear"
	return true


func try_equip_spear_from_inventory() -> bool:
	return try_equip_spear_from_inventory_for(0)


func try_equip_sword_from_inventory_for(player_idx: int) -> bool:
	if equip_main_for(player_idx) == &"iron_sword":
		return false
	if sword_spare < 1:
		return false
	if not _stash_main_to_spare_for(player_idx):
		return false
	if not try_remove_item(&"sword_spare", 1):
		return false
	if player_idx == 0:
		equip_main = &"iron_sword"
	else:
		equip_main_p2 = &"iron_sword"
	return true


func try_equip_sword_from_inventory() -> bool:
	return try_equip_sword_from_inventory_for(0)


func can_place_campfire() -> bool:
	return wood >= GameConstants.CAMPFIRE_WOOD and stone >= GameConstants.CAMPFIRE_STONE


func can_plant_tree() -> bool:
	return seed >= GameConstants.PLANT_TREE_SEED_COST


func can_plant_turnip() -> bool:
	return turnip_seeds >= 1


func try_consume_one_turnip_seed() -> bool:
	return try_remove_item(&"turnip_seeds", 1)


func try_spend_seed_for_tree() -> bool:
	return try_remove_item(&"seed", GameConstants.PLANT_TREE_SEED_COST)


func spend_campfire() -> bool:
	if not can_place_campfire():
		return false
	if not try_remove_item(&"wood", GameConstants.CAMPFIRE_WOOD):
		return false
	if not try_remove_item(&"stone", GameConstants.CAMPFIRE_STONE):
		try_add_item(&"wood", GameConstants.CAMPFIRE_WOOD)
		return false
	return true


func unequip_main_weapon_to_spare_for(player_idx: int) -> bool:
	var w := equip_main_for(player_idx)
	match w:
		&"axe":
			if try_add_item(&"axe_spare", 1) > 0:
				return false
			if player_idx == 0:
				equip_main = &""
			else:
				equip_main_p2 = &""
			return true
		&"wood_spear":
			if try_add_item(&"spear_spare", 1) > 0:
				return false
			if player_idx == 0:
				equip_main = &""
			else:
				equip_main_p2 = &""
			return true
		&"iron_sword":
			if try_add_item(&"sword_spare", 1) > 0:
				return false
			if player_idx == 0:
				equip_main = &""
			else:
				equip_main_p2 = &""
			return true
		_:
			return false


func unequip_main_weapon_to_spare() -> bool:
	return unequip_main_weapon_to_spare_for(0)


func can_craft_berry_jerky() -> bool:
	return berries >= GameConstants.CAMPFIRE_COOK_BERRY_COST


func try_craft_berry_jerky() -> bool:
	if not can_craft_berry_jerky():
		return false
	if not try_remove_item(&"berries", GameConstants.CAMPFIRE_COOK_BERRY_COST):
		return false
	if try_add_item(&"berry_jerky", 1) > 0:
		try_add_item(&"berries", GameConstants.CAMPFIRE_COOK_BERRY_COST)
		return false
	return true


func try_consume_berry_jerky() -> bool:
	return try_remove_item(&"berry_jerky", 1)


func can_craft_bbq_meat() -> bool:
	return meat_cutlet >= GameConstants.CAMPFIRE_COOK_MEAT_COST


func try_craft_bbq_meat_at_campfire() -> bool:
	if not can_craft_bbq_meat():
		return false
	if not try_remove_item(&"meat_cutlet", GameConstants.CAMPFIRE_COOK_MEAT_COST):
		return false
	if try_add_item(&"bbq_meat", 1) > 0:
		try_add_item(&"meat_cutlet", GameConstants.CAMPFIRE_COOK_MEAT_COST)
		return false
	return true


func try_consume_bbq_meat() -> bool:
	return try_remove_item(&"bbq_meat", 1)


func try_add_one_water() -> bool:
	if water >= GameConstants.WATER_CARRY_MAX:
		return false
	if try_add_item(&"water", 1) > 0:
		return false
	return true


func try_consume_one_water() -> bool:
	return try_remove_item(&"water", 1)


func can_craft_dirt(extra_storages: Array[GameInventory] = []) -> bool:
	var pools := _pools_with(extra_storages)
	return (
		GameInventory.count_in_pools(pools, &"wood") >= GameConstants.CRAFT_DIRT_WOOD
		and GameInventory.count_in_pools(pools, &"slime_goo") >= GameConstants.CRAFT_DIRT_SLIME
	)


func try_craft_dirt_at_bench(extra_storages: Array[GameInventory] = []) -> bool:
	if not can_craft_dirt(extra_storages):
		return false
	var pools := _pools_with(extra_storages)
	if not GameInventory.remove_from_pools_ordered(pools, &"wood", GameConstants.CRAFT_DIRT_WOOD):
		return false
	if not GameInventory.remove_from_pools_ordered(pools, &"slime_goo", GameConstants.CRAFT_DIRT_SLIME):
		GameInventory.refund_to_inventory(self, &"wood", GameConstants.CRAFT_DIRT_WOOD)
		return false
	if try_add_item(&"dirt", 1) > 0:
		try_add_item(&"wood", GameConstants.CRAFT_DIRT_WOOD)
		try_add_item(&"slime_goo", GameConstants.CRAFT_DIRT_SLIME)
		return false
	return true


func try_spend_dirt(amount: int) -> bool:
	return try_remove_item(&"dirt", amount)


func can_craft_sticky_armor(extra_storages: Array[GameInventory] = []) -> bool:
	var pools := _pools_with(extra_storages)
	return (
		GameInventory.count_in_pools(pools, &"leather") >= GameConstants.CRAFT_STICKY_ARMOR_LEATHER
		and GameInventory.count_in_pools(pools, &"slime_goo") >= GameConstants.CRAFT_STICKY_ARMOR_SLIME
	)


func try_craft_sticky_armor_at_bench(extra_storages: Array[GameInventory] = []) -> bool:
	if not can_craft_sticky_armor(extra_storages):
		return false
	var pools := _pools_with(extra_storages)
	if not GameInventory.remove_from_pools_ordered(pools, &"leather", GameConstants.CRAFT_STICKY_ARMOR_LEATHER):
		return false
	if not GameInventory.remove_from_pools_ordered(pools, &"slime_goo", GameConstants.CRAFT_STICKY_ARMOR_SLIME):
		GameInventory.refund_to_inventory(self, &"leather", GameConstants.CRAFT_STICKY_ARMOR_LEATHER)
		return false
	if armor_equipped == &"":
		armor_equipped = &"sticky_armor"
	else:
		if try_add_item(&"sticky_armor_spare", 1) > 0:
			try_add_item(&"leather", GameConstants.CRAFT_STICKY_ARMOR_LEATHER)
			try_add_item(&"slime_goo", GameConstants.CRAFT_STICKY_ARMOR_SLIME)
			return false
	return true


func _stash_armor_to_spare_if_any() -> bool:
	if armor_equipped != &"sticky_armor":
		return true
	if try_add_item(&"sticky_armor_spare", 1) > 0:
		return false
	armor_equipped = &""
	return true


func try_equip_sticky_armor_from_inventory() -> bool:
	if armor_equipped == &"sticky_armor":
		return false
	if sticky_armor_spare < 1:
		return false
	if not _stash_armor_to_spare_if_any():
		return false
	if not try_remove_item(&"sticky_armor_spare", 1):
		return false
	armor_equipped = &"sticky_armor"
	return true


func unequip_armor_to_spare() -> bool:
	if armor_equipped != &"sticky_armor":
		return false
	armor_equipped = &""
	if try_add_item(&"sticky_armor_spare", 1) > 0:
		armor_equipped = &"sticky_armor"
		return false
	return true


func try_consume_one_berry() -> bool:
	return try_remove_item(&"berries", 1)


func try_consume_meat_cutlet() -> bool:
	return try_remove_item(&"meat_cutlet", 1)


func try_spend_wood(amount: int) -> bool:
	return try_remove_item(&"wood", amount)


func try_spend_stone(amount: int) -> bool:
	return try_remove_item(&"stone", amount)


## 回傳未能入格的數量。
func add_wood(amount: int) -> int:
	return try_add_item(&"wood", amount)


func try_craft_wood_spear_at_bench(extra_storages: Array[GameInventory] = []) -> bool:
	var pools := _pools_with(extra_storages)
	if (
		GameInventory.count_in_pools(pools, &"wood") < GameConstants.CRAFT_SPEAR_WOOD
		or GameInventory.count_in_pools(pools, &"stone") < GameConstants.CRAFT_SPEAR_STONE
	):
		return false
	if not GameInventory.remove_from_pools_ordered(pools, &"wood", GameConstants.CRAFT_SPEAR_WOOD):
		return false
	if not GameInventory.remove_from_pools_ordered(pools, &"stone", GameConstants.CRAFT_SPEAR_STONE):
		GameInventory.refund_to_inventory(self, &"wood", GameConstants.CRAFT_SPEAR_WOOD)
		return false
	if equip_main == &"":
		equip_main = &"wood_spear"
	elif dual_main_weapon_slots_enabled and equip_main_p2 == &"":
		equip_main_p2 = &"wood_spear"
	else:
		if try_add_item(&"spear_spare", 1) > 0:
			try_add_item(&"wood", GameConstants.CRAFT_SPEAR_WOOD)
			try_add_item(&"stone", GameConstants.CRAFT_SPEAR_STONE)
			return false
	return true


func try_craft_iron_sword_at_bench(extra_storages: Array[GameInventory] = []) -> bool:
	var pools := _pools_with(extra_storages)
	if (
		GameInventory.count_in_pools(pools, &"wood") < GameConstants.CRAFT_SWORD_WOOD
		or GameInventory.count_in_pools(pools, &"stone") < GameConstants.CRAFT_SWORD_STONE
	):
		return false
	if not GameInventory.remove_from_pools_ordered(pools, &"wood", GameConstants.CRAFT_SWORD_WOOD):
		return false
	if not GameInventory.remove_from_pools_ordered(pools, &"stone", GameConstants.CRAFT_SWORD_STONE):
		GameInventory.refund_to_inventory(self, &"wood", GameConstants.CRAFT_SWORD_WOOD)
		return false
	if equip_main == &"":
		equip_main = &"iron_sword"
	elif dual_main_weapon_slots_enabled and equip_main_p2 == &"":
		equip_main_p2 = &"iron_sword"
	else:
		if try_add_item(&"sword_spare", 1) > 0:
			try_add_item(&"wood", GameConstants.CRAFT_SWORD_WOOD)
			try_add_item(&"stone", GameConstants.CRAFT_SWORD_STONE)
			return false
	return true


func _serialize_slots() -> Array:
	var out: Array = []
	for s in slots:
		if s == null:
			out.append(null)
		elif s is Dictionary:
			var d := (s as Dictionary).duplicate()
			d["id"] = String(d.get("id", ""))
			out.append(d)
		else:
			out.append(null)
	return out


func _deserialize_slots(arr: Variant) -> void:
	slots.clear()
	if not (arr is Array):
		_ensure_slot_array()
		return
	for item in arr as Array:
		if slots.size() >= slot_count:
			break
		if item == null:
			slots.append(null)
		elif item is Dictionary:
			var d := (item as Dictionary).duplicate()
			d["id"] = StringName(str(d.get("id", "")))
			d["q"] = maxi(0, int(d.get("q", 0)))
			if d["id"] == &"" or int(d["q"]) <= 0:
				slots.append(null)
			else:
				slots.append(d)
		else:
			slots.append(null)
	_ensure_slot_array()


func to_save_dict() -> Dictionary:
	return {
		"slot_count": slot_count,
		"stack_limit": stack_limit,
		"slots": _serialize_slots(),
		"armor_equipped": String(armor_equipped),
		"equip_main": String(equip_main),
		"equip_main_p2": String(equip_main_p2),
	}


func apply_save_dict(d: Dictionary) -> void:
	## 格數上限與底部 HUD 格位一致；之後擴充時請同步加大常數與 UI 格數。
	slot_count = clampi(
		int(d.get("slot_count", GameConstants.INVENTORY_SLOT_COUNT_DEFAULT)),
		1,
		GameConstants.INVENTORY_SLOT_COUNT_DEFAULT
	)
	stack_limit = clampi(int(d.get("stack_limit", GameConstants.INVENTORY_STACK_LIMIT_DEFAULT)), 1, 9999)
	slots.clear()
	_ensure_slot_array()
	if d.has("slots") and d.get("slots") is Array:
		_deserialize_slots(d.get("slots"))
		_ensure_slot_array()
	else:
		_import_legacy_flat_dict(d)
	armor_equipped = StringName(str(d.get("armor_equipped", "")))
	equip_main = StringName(str(d.get("equip_main", "")))
	if equip_main == &"stone_sword":
		equip_main = &"iron_sword"
	equip_main_p2 = StringName(str(d.get("equip_main_p2", "")))
	if equip_main_p2 == &"stone_sword":
		equip_main_p2 = &"iron_sword"


func _import_legacy_flat_dict(d: Dictionary) -> void:
	var legacy: Array = [
		[&"wood", int(d.get("wood", 0))],
		[&"stone", int(d.get("stone", 0))],
		[&"berries", int(d.get("berries", 0))],
		[&"berry_jerky", int(d.get("berry_jerky", 0))],
		[&"seed", int(d.get("seed", 0))],
		[&"axe_spare", int(d.get("axe_spare", 0))],
		[&"spear_spare", int(d.get("spear_spare", 0))],
		[&"sword_spare", int(d.get("sword_spare", 0))],
		[&"slime_goo", int(d.get("slime_goo", 0))],
		[&"leather", int(d.get("leather", 0))],
		[&"meat_cutlet", int(d.get("meat_cutlet", 0))],
		[&"wild_mushroom", int(d.get("wild_mushroom", 0))],
		[&"bbq_meat", int(d.get("bbq_meat", 0))],
		[&"water", clampi(int(d.get("water", 0)), 0, GameConstants.WATER_CARRY_MAX)],
		[&"dirt", maxi(0, int(d.get("dirt", 0)))],
		[&"turnip_seeds", maxi(0, int(d.get("turnip_seeds", 0)))],
		[&"turnip", maxi(0, int(d.get("turnip", 0)))],
		[&"sticky_armor_spare", int(d.get("sticky_armor_spare", 0))],
	]
	for pair in legacy:
		var id: StringName = pair[0]
		var q: int = pair[1]
		if q > 0:
			var ov := try_add_item(id, q)
			if ov > 0:
				push_warning("GameInventory: 舊存檔匯入時格位不足，%s 損失 %d" % [String(id), ov])
