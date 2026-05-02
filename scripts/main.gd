extends Node2D
## 初始之地 (0,0) + 序章教學：石斧 → 營火。Tab 雙人；共用背包與主手裝備。

## 任務／提示列以下才算「世界操作區」（勿與頂部 UI 混淆）。
## 僅避開頂部任務列（操作教學已收在「?」彈層）。
const HUD_TOP_BLOCK := 88.0
## YATI 會把 .tmj 匯成 PackedScene；實際 tscn 在 .godot/imported/，執行時用此路徑 load 即可。
const TILED_MAP_PATH := "res://assets/maps/Map00.tmj"

enum BuildKind { NONE, CAMPFIRE, FLOOR, FENCE, DOOR, DISMANTLE }

@onready var bounds_root: Node2D = $Bounds
@onready var backdrop: Node2D = $Backdrop
@onready var entities: Node2D = $WorldYSort/Entities
@onready var player1: PlayerController = $WorldYSort/Player1
@onready var player2: PlayerController = $WorldYSort/Player2
@onready var camera: Camera2D = $Camera2D
@onready var quest_label: RichTextLabel = $CanvasLayer/UI/QuestPanel/MarginContainer/QuestText
@onready var inv_bar: PanelContainer = $CanvasLayer/UI/InvBar
@onready var hint_help_btn: Button = $CanvasLayer/UI/HintHelpBtn
@onready var hint_popup: PanelContainer = $CanvasLayer/UI/HintPopup
@onready var hint_label: Label = $CanvasLayer/UI/HintPopup/MarginContainer/HintText
@onready var msg_label: Label = $CanvasLayer/UI/MessageToast

var inv: GameInventory = GameInventory.new()
var quest_phase: int = 1
var two_player: bool = false
var _build_kind: BuildKind = BuildKind.NONE
var p2_mouse_right_down: bool = false

var _msg_time: float = 0.0
var _bottom_hud: BottomHudController
var _build_grid: BuildGridOverlay

var _scene_prop: PackedScene = preload("res://scenes/interactable_prop.tscn")
var _scene_loose: PackedScene = preload("res://scenes/loose_pickup.tscn")
var _campfire_script: Script = preload("res://scripts/campfire_marker.gd")

## 隨機生成樹／石／掉落物時避開：Water 任意圖塊、onGround 上 Rock Slope（含樓梯）。
var _spawn_avoid_water_layers: Array[TileMapLayer] = []
var _spawn_avoid_onground_layers: Array[TileMapLayer] = []


func _ready() -> void:
	add_to_group("game_main")
	player1.player_index = 0
	player2.player_index = 1
	player2.visible = false
	player2.process_mode = Node.PROCESS_MODE_DISABLED
	_load_tiled_map_if_present()
	_build_bounds()
	_spawn_initial_room()
	_create_build_grid_overlay()
	VisualRegistry.ensure_baked()
	_setup_bottom_hud()
	inv_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_update_quest_ui()
	_update_inv_bar()
	_show_hint()
	hint_popup.visible = false
	hint_help_btn.pressed.connect(_toggle_hint_popup)
	camera.make_current()
	camera.position = player1.global_position


func _load_tiled_map_if_present() -> void:
	_spawn_avoid_water_layers.clear()
	_spawn_avoid_onground_layers.clear()
	if not ResourceLoader.exists(TILED_MAP_PATH):
		return
	var res: Resource = load(TILED_MAP_PATH)
	if res == null or not (res is PackedScene):
		push_warning("Main: 無法載入地圖（非 PackedScene）：%s" % TILED_MAP_PATH)
		return
	var map_root: Node2D = (res as PackedScene).instantiate() as Node2D
	if map_root == null:
		return
	map_root.name = "TiledMap"
	var wys: Node2D = $WorldYSort
	wys.add_child(map_root)
	wys.move_child(map_root, 0)
	if backdrop:
		backdrop.visible = false
	_add_water_collision_from_tiled_map(map_root)
	_add_onground_rock_slope_collision_from_tiled_map(map_root)
	_collect_tilemap_layers_named(map_root, _spawn_avoid_water_layers, "water")
	_collect_tilemap_layers_named(map_root, _spawn_avoid_onground_layers, "onground")


## Tiled 的「Water」圖層通常沒有物理；為每格補 StaticBody2D（layer 1），與邊界／樹一致。
func _add_water_collision_from_tiled_map(root: Node2D) -> void:
	var layers: Array[TileMapLayer] = []
	_collect_tilemap_layers_named(root, layers, "water")
	for layer in layers:
		_fill_tile_layer_with_static_boxes(layer)


func _fill_tile_layer_with_static_boxes(layer: TileMapLayer) -> void:
	var ts := layer.tile_set
	if ts == null:
		push_warning("Main: Water 圖層沒有 TileSet，略過碰撞。")
		return
	var tile_size := Vector2(ts.tile_size)
	for cell: Vector2i in layer.get_used_cells():
		var body := StaticBody2D.new()
		body.name = "WaterBlock_%d_%d" % [cell.x, cell.y]
		body.collision_layer = 1
		body.collision_mask = 0
		var col := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = tile_size
		col.shape = sh
		body.position = layer.map_to_local(cell) + tile_size * 0.5
		body.add_child(col)
		layer.add_child(body)


## onGround 上陡坡（Rock Slope 圖集）要擋人；底列樓梯圖塊不加碰撞（與水相同：StaticBody2D layer 1）。
func _add_onground_rock_slope_collision_from_tiled_map(root: Node2D) -> void:
	var layers: Array[TileMapLayer] = []
	_collect_tilemap_layers_named(root, layers, "onground")
	for layer in layers:
		_fill_onground_rock_slope_blocking_boxes(layer)


func _collect_tilemap_layers_named(node: Node, out: Array[TileMapLayer], want_name_lower: String) -> void:
	for c in node.get_children():
		if c is TileMapLayer and String(c.name).to_lower() == want_name_lower:
			out.append(c as TileMapLayer)
		_collect_tilemap_layers_named(c, out, want_name_lower)


## Map00 底列石階對應圖集座標（Tileset_RockSlope.png）；若換圖塊請改此表。
const _ROCK_SLOPE_STAIR_ATLAS: Array[Vector2i] = [
	Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7),
]


func _fill_onground_rock_slope_blocking_boxes(layer: TileMapLayer) -> void:
	var ts := layer.tile_set
	if ts == null:
		push_warning("Main: onGround 沒有 TileSet，略過陡坡碰撞。")
		return
	var tile_size := Vector2(ts.tile_size)
	for cell: Vector2i in layer.get_used_cells():
		var sid := layer.get_cell_source_id(cell)
		if sid < 0:
			continue
		if not _tileset_source_is_rock_slope(ts, sid):
			continue
		var atlas := layer.get_cell_atlas_coords(cell)
		if atlas in _ROCK_SLOPE_STAIR_ATLAS:
			continue
		var body := StaticBody2D.new()
		body.name = "RockSlopeBlock_%d_%d" % [cell.x, cell.y]
		body.collision_layer = 1
		body.collision_mask = 0
		var col := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = tile_size
		col.shape = sh
		body.position = layer.map_to_local(cell) + tile_size * 0.5
		body.add_child(col)
		layer.add_child(body)


func _tileset_source_is_rock_slope(ts: TileSet, source_id: int) -> bool:
	var src := ts.get_source(source_id)
	if src == null or not (src is TileSetAtlasSource):
		return false
	var tex: Texture2D = (src as TileSetAtlasSource).texture
	if tex == null:
		return false
	var p := tex.resource_path.to_lower()
	return p.contains("rockslope") or p.contains("rock_slope")


func _show_hint() -> void:
	hint_label.text = "WASD 移動｜F／Space：採集、砍樹｜G：木門開關（與建造分開）｜1 製作石斧｜Q 裝備｜2 營火｜底部選建造後「左鍵」才放板／牆／門｜Tab 雙人｜2P：E 採集、G 開門、左鍵採集（非建造時）"


func _toggle_hint_popup() -> void:
	hint_popup.visible = not hint_popup.visible


func _process(delta: float) -> void:
	var mid := player1.global_position
	if two_player:
		mid = (player1.global_position + player2.global_position) * 0.5
	camera.global_position = mid

	if two_player and p2_mouse_right_down:
		if _mouse_in_world_interaction_band(get_viewport().get_mouse_position()):
			player2.set_mouse_nav_target(get_global_mouse_position(), true)

	_update_build_grid_preview()

	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			msg_label.visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_TAB:
				_toggle_two_player()
			KEY_1:
				_try_craft_axe()
			KEY_2:
				_toggle_campfire_build()
			KEY_Q:
				if inv.try_equip_axe_from_inventory():
					_show_msg("已裝備石斧。")
					_update_inv_bar()
					_update_quest_ui()
				else:
					_show_msg("沒有可裝備的石斧。")
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F or event.physical_keycode == KEY_SPACE:
			try_harvest_near(player1, 0)
		elif event.physical_keycode == KEY_G:
			try_use_near(player1, 0)
	if two_player and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			try_harvest_near(player2, 1)
		elif event.physical_keycode == KEY_G:
			try_use_near(player2, 1)

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not _mouse_in_world_interaction_band(mb.position):
			return
		if two_player:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				p2_mouse_right_down = mb.pressed
				if mb.pressed:
					player2.set_mouse_nav_target(get_global_mouse_position(), true)
			elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				if _try_handle_build_or_dismantle_click(get_global_mouse_position()):
					pass
				else:
					try_harvest_near(player2, 1)
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				if not _try_handle_build_or_dismantle_click(get_global_mouse_position()):
					pass


func _toggle_two_player() -> void:
	two_player = not two_player
	player2.visible = two_player
	player2.process_mode = Node.PROCESS_MODE_INHERIT if two_player else Node.PROCESS_MODE_DISABLED
	player2.velocity = Vector2.ZERO
	player2.use_mouse_target = false
	player2.mouse_target = Vector2.ZERO
	p2_mouse_right_down = false
	if two_player:
		player2.global_position = player1.global_position + Vector2(48, 32)
		_show_msg("雙人：1P WASD + F 採集、G 互動門；2P 方向鍵／右鍵移動，E 採集、G 互動門，左鍵採集（非建造模式時）。")
	else:
		_show_msg("單人模式。")


func _toggle_campfire_build() -> void:
	if quest_phase < 2:
		_show_msg("先完成石斧教學。")
		return
	if _build_kind == BuildKind.CAMPFIRE:
		_build_kind = BuildKind.NONE
	else:
		_build_kind = BuildKind.CAMPFIRE
	_show_msg("放置營火模式：開" if _build_kind == BuildKind.CAMPFIRE else "放置營火模式：關")
	_update_hud_build_visual()


func _try_craft_axe() -> void:
	if inv.craft_axe():
		_show_msg("製作了石斧！" + (" 已裝在主手。" if inv.equip_main == &"axe" and inv.axe_spare == 0 else " 已放入背包，按 Q 裝備。"))
		_update_inv_bar()
		_update_quest_ui()
	else:
		_show_msg("木材或石頭不足（需 3 木、2 石）。")


func _try_place_campfire_at(world: Vector2) -> void:
	if not inv.can_place_campfire():
		_show_msg("資源不足（需 5 木、3 石）。")
		return
	var snap := _grid_snap(world)
	var center := snap + Vector2.ONE * (GameConstants.GRID_SIZE * 0.5)
	if _is_protected(center) or _build_site_blocked(center):
		_show_msg("不能蓋在這裡。")
		return
	for n in entities.get_children():
		if n.is_in_group("campfire") and n.global_position.distance_to(center) < 24.0:
			_show_msg("這裡太近了。")
			return
	if not inv.spend_campfire():
		_show_msg("資源不足（需 5 木、3 石）。")
		return
	var cf := StaticBody2D.new()
	cf.set_script(_campfire_script)
	cf.global_position = center
	entities.add_child(cf)
	_build_kind = BuildKind.NONE
	_update_hud_build_visual()
	_show_msg("營火升起了！")
	_update_inv_bar()
	_advance_quest_after_campfire()


func _grid_snap(v: Vector2) -> Vector2:
	var g := float(GameConstants.GRID_SIZE)
	return Vector2(floorf(v.x / g) * g, floorf(v.y / g) * g)


func _mouse_in_world_interaction_band(screen_px: Vector2) -> bool:
	var y_top := HUD_TOP_BLOCK
	var y_bot := inv_bar.global_position.y
	if y_bot <= y_top + 8.0:
		y_bot = get_viewport().get_visible_rect().size.y - 200.0
	return screen_px.y > y_top and screen_px.y < y_bot


func _create_build_grid_overlay() -> void:
	_build_grid = BuildGridOverlay.new()
	_build_grid.z_index = 500
	_build_grid.grid_size = float(GameConstants.GRID_SIZE)
	$WorldYSort.add_child(_build_grid)


func _setup_bottom_hud() -> void:
	for c in inv_bar.get_children():
		c.queue_free()
	var bh := BottomHudController.new()
	bh.set_anchors_preset(Control.PRESET_FULL_RECT)
	bh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_bar.add_child(bh)
	_bottom_hud = bh
	bh.craft_axe_pressed.connect(_try_craft_axe)
	bh.equip_axe_pressed.connect(_on_hud_equip_axe)
	bh.unequip_axe_pressed.connect(_on_hud_unequip_axe)
	bh.toggle_campfire_pressed.connect(_on_hud_toggle_campfire)
	bh.build_floor_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.FLOOR))
	bh.build_fence_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.FENCE))
	bh.build_door_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.DOOR))
	bh.dismantle_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.DISMANTLE))


func _on_hud_equip_axe() -> void:
	if inv.try_equip_axe_from_inventory():
		_show_msg("已裝備石斧。")
		_update_inv_bar()
		_update_quest_ui()
	else:
		_show_msg("沒有可裝備的石斧。")


func _on_hud_unequip_axe() -> void:
	if inv.unequip_main_axe_to_spare():
		_show_msg("已卸下石斧。")
		_update_inv_bar()
	else:
		_show_msg("主手沒有石斧。")


func _on_hud_toggle_campfire() -> void:
	_toggle_campfire_build()


func _toggle_build_kind(k: BuildKind) -> void:
	if quest_phase < 2 and k != BuildKind.DISMANTLE:
		_show_msg("先完成石斧教學。")
		return
	var turning_off := _build_kind == k
	if turning_off:
		_build_kind = BuildKind.NONE
	else:
		_build_kind = k
	_update_hud_build_visual()
	if k == BuildKind.FLOOR:
		_show_msg("已取消木地板。" if turning_off else "木地板：左鍵對齊格線放置（1 木）。")
	elif k == BuildKind.FENCE:
		_show_msg("已取消木牆。" if turning_off else "木牆：左鍵放置（2 木）。")
	elif k == BuildKind.DOOR:
		_show_msg("已取消木門。" if turning_off else "木門：左鍵放置（3 木）。")
	elif k == BuildKind.DISMANTLE:
		_show_msg("已取消拆除。" if turning_off else "拆除：左鍵點建造物或營火以回收。")


func _update_hud_build_visual() -> void:
	if _bottom_hud == null:
		return
	_bottom_hud.set_build_mode_visual(
		_build_kind == BuildKind.CAMPFIRE,
		_build_kind == BuildKind.FLOOR,
		_build_kind == BuildKind.FENCE,
		_build_kind == BuildKind.DOOR,
		_build_kind == BuildKind.DISMANTLE
	)


func _any_build_placement_mode() -> bool:
	return _build_kind == BuildKind.CAMPFIRE or _build_kind == BuildKind.FLOOR or _build_kind == BuildKind.FENCE or _build_kind == BuildKind.DOOR


func _update_build_grid_preview() -> void:
	if _build_grid == null:
		return
	if not _any_build_placement_mode():
		_build_grid.enabled = false
		return
	_build_grid.enabled = true
	var w := get_global_mouse_position()
	var snap_c := _grid_snap(w) + Vector2.ONE * (GameConstants.GRID_SIZE * 0.5)
	_build_grid.preview_center = snap_c
	_build_grid.preview_size = Vector2(float(GameConstants.GRID_SIZE), float(GameConstants.GRID_SIZE))


func _try_handle_build_or_dismantle_click(world: Vector2) -> bool:
	match _build_kind:
		BuildKind.NONE:
			return false
		BuildKind.CAMPFIRE:
			_try_place_campfire_at(world)
			return true
		BuildKind.FLOOR:
			_try_place_world_piece(WorldBuildPiece.PieceKind.FLOOR, world)
			return true
		BuildKind.FENCE:
			_try_place_world_piece(WorldBuildPiece.PieceKind.WALL, world)
			return true
		BuildKind.DOOR:
			_try_place_world_piece(WorldBuildPiece.PieceKind.DOOR, world)
			return true
		BuildKind.DISMANTLE:
			_try_dismantle_at(world)
			return true
		_:
			return false


func _build_site_blocked(center: Vector2) -> bool:
	for c in entities.get_children():
		if c is WorldPropStatic:
			if c.global_position.distance_to(center) < 22.0:
				return true
		if c.is_in_group("build_piece") or c.is_in_group("campfire"):
			if c.global_position.distance_to(center) < GameConstants.GRID_SIZE * 0.45:
				return true
	return false


func _try_place_world_piece(kind: WorldBuildPiece.PieceKind, world: Vector2) -> void:
	var cost := GameConstants.BUILD_FLOOR_WOOD
	match kind:
		WorldBuildPiece.PieceKind.WALL:
			cost = GameConstants.BUILD_FENCE_WOOD
		WorldBuildPiece.PieceKind.DOOR:
			cost = GameConstants.BUILD_DOOR_WOOD
		_:
			pass
	if inv.wood < cost:
		_show_msg("木材不足。")
		return
	var snap := _grid_snap(world)
	var center := snap + Vector2.ONE * (GameConstants.GRID_SIZE * 0.5)
	if _is_protected(center) or _spawn_mask_blocks_global_point(center) or _build_site_blocked(center):
		_show_msg("不能蓋在這裡。")
		return
	if not inv.try_spend_wood(cost):
		_show_msg("木材不足。")
		return
	var piece := WorldBuildPiece.new()
	piece.piece_kind = kind
	piece.global_position = center
	entities.add_child(piece)
	_update_inv_bar()
	_show_msg("建造完成。")


func _try_dismantle_at(world: Vector2) -> void:
	var best: Node2D = null
	var best_d := 56.0
	for c in entities.get_children():
		if not (c is Node2D):
			continue
		if not c.is_in_group("build_piece") and not c.is_in_group("campfire"):
			continue
		var d := (c as Node2D).global_position.distance_to(world)
		if d < best_d:
			best_d = d
			best = c as Node2D
	if best == null:
		_show_msg("附近沒有可拆的目標。")
		return
	if best.is_in_group("campfire"):
		inv.add_wood(GameConstants.CAMPFIRE_WOOD)
		inv.stone += GameConstants.CAMPFIRE_STONE
		best.queue_free()
		_show_msg("已拆除營火（退回資源）。")
	elif best is WorldBuildPiece:
		var pk: WorldBuildPiece.PieceKind = (best as WorldBuildPiece).piece_kind
		inv.add_wood(WorldBuildPiece.refund_wood_for_kind(pk))
		best.queue_free()
		_show_msg("已拆除建造物（退回木材）。")
	_update_inv_bar()


func _advance_quest_after_campfire() -> void:
	if quest_phase == 2:
		quest_phase = 3
		_update_quest_ui()
		_show_msg("邊界將在後續版本開放——先到此為止的序章小成！")


func on_loose_pickup(p: LoosePickup) -> void:
	match p.pick_kind:
		LoosePickup.PickKind.WOOD:
			inv.wood += 1
		LoosePickup.PickKind.STONE:
			inv.stone += 1
		LoosePickup.PickKind.SEED:
			inv.seed += 1
	p.queue_free()
	_update_inv_bar()
	_update_quest_ui()


func try_use_near(who: PlayerController, _player_idx: int) -> void:
	## 互動鍵：木門開關（與 F 採集、左鍵建造分開）。
	var reach := GameConstants.INTERACT_REACH
	var best_door: WorldBuildPiece = null
	var best_d := reach
	for c in entities.get_children():
		if not (c is WorldBuildPiece):
			continue
		var wp := c as WorldBuildPiece
		if wp.piece_kind != WorldBuildPiece.PieceKind.DOOR:
			continue
		var dd := who.global_position.distance_to(wp.global_position)
		if dd < best_d:
			best_d = dd
			best_door = wp
	if best_door == null or best_d >= reach:
		return
	best_door.toggle_door()
	_show_msg("門已開啟，可通過。" if best_door.door_open else "門已關閉。")


func try_harvest_near(who: PlayerController, _player_idx: int) -> void:
	var reach := GameConstants.HARVEST_REACH_P1
	var best: WorldPropStatic = null
	var best_d := reach
	for c in entities.get_children():
		if c is WorldPropStatic:
			var d := who.global_position.distance_to(c.global_position)
			if d < best_d:
				best_d = d
				best = c
	if best == null:
		return
	if best.prop_kind == WorldPropStatic.PropKind.TREE and inv.equip_main != &"axe":
		_show_msg("需要裝備石斧才能砍樹。")
		return
	var res: Dictionary = best.take_hit()
	if res.get("destroyed", false):
		_on_prop_destroyed(best)


func _on_prop_destroyed(prop: WorldPropStatic) -> void:
	var p := prop.global_position
	if prop.prop_kind == WorldPropStatic.PropKind.TREE:
		var wn := randi_range(2, 3)
		var sn := randi_range(1, 2)
		for i in wn:
			_spawn_loose(LoosePickup.PickKind.WOOD, p + Vector2(randf_range(-36, 36), randf_range(-36, 36)))
		for j in sn:
			_spawn_loose(LoosePickup.PickKind.SEED, p + Vector2(randf_range(-36, 36), randf_range(-36, 36)))
		_show_msg("樹木倒下了！")
	else:
		var st := randi_range(1, 2)
		for k in st:
			_spawn_loose(LoosePickup.PickKind.STONE, p + Vector2(randf_range(-28, 28), randf_range(-28, 28)))
		_show_msg("岩石碎裂了！")
	entities.remove_child(prop)
	prop.queue_free()
	_update_inv_bar()
	_update_quest_ui()


func _spawn_loose(kind: LoosePickup.PickKind, pos: Vector2) -> void:
	var lp: LoosePickup = _scene_loose.instantiate() as LoosePickup
	lp.pick_kind = kind
	lp.global_position = pos
	if not _is_protected(pos):
		entities.add_child(lp)


func _show_msg(t: String) -> void:
	msg_label.text = t
	msg_label.visible = true
	_msg_time = 3.2


func _update_inv_bar() -> void:
	if _bottom_hud == null:
		return
	_bottom_hud.refresh(inv)
	_update_hud_build_visual()


func _update_quest_ui() -> void:
	quest_label.bbcode_enabled = true
	if quest_phase == 1 and inv.has_axe():
		quest_phase = 2
		_show_msg("太好了！接下來收集木材與石頭，蓋一座營火吧。按 2 進入放置模式，再於空地上按左鍵。")
		if inv.equip_main != &"axe":
			_show_msg("請按 Q 將石斧裝到主手才能砍樹。")
	if quest_phase == 1:
		quest_label.text = "[center]序章｜撿拾樹枝與碎石，按 [b]1[/b] 製作 [b]石斧[/b]（或主手／背包已有石斧）[/center]"
	elif quest_phase == 2:
		quest_label.text = "[center]序章｜收集資源，按 [b]2[/b] 進入放置營火，於空地 [b]左鍵[/b]（需 5 木 3 石）[/center]"
	else:
		quest_label.text = "[center]序章完成｜邊界與溪谷將在後續版本加入。[/center]"


func _build_bounds() -> void:
	var sz := get_viewport_rect().size
	var t := 32.0
	_add_wall_rect(Rect2(0, 0, sz.x, t)) # top
	_add_wall_rect(Rect2(0, sz.y - t, sz.x, t)) # bottom
	_add_wall_rect(Rect2(0, 0, t, sz.y))
	_add_wall_rect(Rect2(sz.x - t, 0, t, sz.y))


func _add_wall_rect(r: Rect2) -> void:
	var w := StaticBody2D.new()
	w.collision_layer = 1
	w.collision_mask = 0
	var col := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	col.position = r.position + r.size * 0.5
	col.shape = sh
	w.add_child(col)
	bounds_root.add_child(w)


func _spawn_initial_room() -> void:
	var sz := get_viewport_rect().size
	for i in GameConstants.INIT_TREES:
		_spawn_prop(WorldPropStatic.PropKind.TREE, sz)
	for j in GameConstants.INIT_ROCKS:
		_spawn_prop(WorldPropStatic.PropKind.ROCK, sz)
	for k in GameConstants.INIT_LOOSE_WOOD:
		_spawn_loose_at(LoosePickup.PickKind.WOOD, sz)
	for m in GameConstants.INIT_LOOSE_STONE:
		_spawn_loose_at(LoosePickup.PickKind.STONE, sz)
	player1.global_position = sz * 0.5


func _spawn_prop(kind: WorldPropStatic.PropKind, sz: Vector2) -> void:
	var pos := _random_open_pos(sz)
	if pos == Vector2.ZERO:
		return
	var node: WorldPropStatic = _scene_prop.instantiate() as WorldPropStatic
	node.prop_kind = kind
	node.global_position = pos
	entities.add_child(node)


func _spawn_loose_at(kind: LoosePickup.PickKind, sz: Vector2) -> void:
	var pos := _random_open_pos(sz)
	if pos == Vector2.ZERO:
		return
	var lp: LoosePickup = _scene_loose.instantiate() as LoosePickup
	lp.pick_kind = kind
	lp.global_position = pos
	entities.add_child(lp)


func _random_open_pos(sz: Vector2) -> Vector2:
	for attempt in 80:
		var p := Vector2(randf_range(48.0, sz.x - 48.0), randf_range(96.0, sz.y - 48.0))
		if not _is_protected(p, sz):
			return p
	return Vector2.ZERO


func _is_protected(p: Vector2, sz: Vector2 = Vector2.ZERO) -> bool:
	if sz == Vector2.ZERO:
		sz = get_viewport_rect().size
	var c := sz * 0.5
	if p.distance_to(c) < 100.0:
		return true
	if p.y < 80.0 and absf(p.x - c.x) < 80.0:
		return true
	if p.y > sz.y - 80.0 and absf(p.x - c.x) < 80.0:
		return true
	if p.x < 80.0 and absf(p.y - c.y) < 80.0:
		return true
	if p.x > sz.x - 80.0 and absf(p.y - c.y) < 80.0:
		return true
	if _spawn_mask_blocks_global_point(p):
		return true
	return false


func _spawn_mask_blocks_global_point(global_p: Vector2) -> bool:
	for layer in _spawn_avoid_water_layers:
		if _tilemap_layer_has_tile_at_global(layer, global_p):
			return true
	for layer in _spawn_avoid_onground_layers:
		if _onground_rock_slope_at_global(layer, global_p):
			return true
	return false


func _tilemap_layer_has_tile_at_global(layer: TileMapLayer, global_p: Vector2) -> bool:
	var cell := layer.local_to_map(layer.to_local(global_p))
	return layer.get_cell_tile_data(cell) != null


func _onground_rock_slope_at_global(layer: TileMapLayer, global_p: Vector2) -> bool:
	var ts := layer.tile_set
	if ts == null:
		return false
	var cell := layer.local_to_map(layer.to_local(global_p))
	if layer.get_cell_tile_data(cell) == null:
		return false
	var sid := layer.get_cell_source_id(cell)
	if sid < 0:
		return false
	return _tileset_source_is_rock_slope(ts, sid)
