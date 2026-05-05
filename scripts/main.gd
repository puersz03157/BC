extends Node2D
## 初始之地 (0,0) + 序章教學：石斧 → 營火 → 木箱 → 工作台 → 探索。Tab 雙人；共用背包，雙人時 1P／2P 主手裝備分開。

## 「?」鈕一列以下、且不在右上狀態／任務欄內，才算「世界操作區」。
const HUD_TOP_HINT_ROW := 48.0
## YATI 會把 .tmj 匯成 PackedScene；各區獨立 .tmj（初版可與 Map00 同內容，之後再換美術）。
const WILD_REGION_SPAWN_GROUP := "wild_region_spawn"
## 翠幽之森（西）：史萊姆／野菇每日補生與讀檔追趕日數用。
const FOREST_WORLD_REGION := Vector2i(-1, 0)
## Web 無系統中文字型；用 Noto CJK 當 ThemeDB fallback，避免 UI 變方塊。
const UI_CJK_FONT := "res://assets/fonts/NotoSansCJKtc-Regular.otf"
const BGM_PATH := "res://assets/audio/music/Drafting_Tomorrow.mp3"
const USER_SAVE_PATH := "user://wilderness_home_save.json"
const SETTINGS_PATH := "user://wilderness_settings.cfg"
const SAVE_FORMAT_VERSION := 21
## 存檔版本 ≥ 此值時：各區野生資源僅在首次進入時隨機生成，之後過圖／讀檔皆還原同一布局（砍完即沒，樹苗／交易等另行取得）。
const SAVE_REGION_WILD_LAYOUT_VERSION := 17
## 存檔版本低於此值時：將讀檔時角色已穿上的 Pixeline 路徑一併視為已解鎖（舊檔無 styling_unlocks）。
const SAVE_STYLING_UNLOCK_VERSION := 19
## 造型選單：未解鎖項目在名稱後顯示的鎖頭符號（UTF-8）。
const _STYLING_LOCK := "🔒"

enum BuildKind {
	NONE,
	CAMPFIRE,
	FLOOR,
	FENCE,
	DOOR,
	DISMANTLE,
	PLANT_TREE,
	WORKBENCH,
	FARMLAND,
	PLANT_TURNIP,
	CHEST,
}

@onready var world_modulate: CanvasModulate = $DayNightModulate
@onready var bounds_root: Node2D = $DayNightModulate/Bounds
@onready var backdrop: Node2D = $DayNightModulate/Backdrop
@onready var entities: Node2D = $DayNightModulate/WorldYSort/Entities
@onready var player1: PlayerController = $DayNightModulate/WorldYSort/Player1
@onready var player2: PlayerController = $DayNightModulate/WorldYSort/Player2
@onready var camera: Camera2D = $Camera2D
@onready var left_vitals_panel: Control = $CanvasLayer/UI/LeftVitalsPanel
@onready var right_hud_column: Control = $CanvasLayer/UI/RightHudColumn
@onready var quest_label: RichTextLabel = $CanvasLayer/UI/RightHudColumn/QuestPanel/MarginContainer/QuestText
@onready var region_info_label: Label = $CanvasLayer/UI/LeftVitalsPanel/MarginContainer/VitalsMainHBox/BarsVBox/RegionInfoLabel
@onready var hp_bar: ProgressBar = $CanvasLayer/UI/LeftVitalsPanel/MarginContainer/VitalsMainHBox/BarsVBox/HpRow/HpBar
@onready var hunger_bar: ProgressBar = $CanvasLayer/UI/LeftVitalsPanel/MarginContainer/VitalsMainHBox/BarsVBox/HungerRow/HungerBar
@onready var game_date_label: Label = $CanvasLayer/UI/LeftVitalsPanel/MarginContainer/VitalsMainHBox/DateTimeVBox/GameDateLabel
@onready var real_time_label: Label = $CanvasLayer/UI/LeftVitalsPanel/MarginContainer/VitalsMainHBox/DateTimeVBox/RealTimeLabel
@onready var inv_bar: PanelContainer = $CanvasLayer/UI/InvBar
@onready var top_right_stack: Control = $CanvasLayer/UI/TopRightStack
@onready var settings_btn: Button = $CanvasLayer/UI/TopRightStack/SettingsBtn
@onready var styling_btn: Button = $CanvasLayer/UI/TopRightStack/StylingBtn
@onready var hint_help_btn: Button = $CanvasLayer/UI/TopRightStack/HintHelpBtn
@onready var dismantle_btn: Button = $CanvasLayer/UI/TopRightStack/DismantleBtn
@onready var settings_popup: PanelContainer = $CanvasLayer/UI/SettingsPopup
@onready var settings_btn_save: Button = $CanvasLayer/UI/SettingsPopup/MarginContainer/SettingsVBox/BtnManualSave
@onready var settings_btn_reset: Button = $CanvasLayer/UI/SettingsPopup/MarginContainer/SettingsVBox/BtnReset
@onready var settings_btn_close: Button = $CanvasLayer/UI/SettingsPopup/MarginContainer/SettingsVBox/BtnClose
@onready var hint_popup: PanelContainer = $CanvasLayer/UI/HintPopup
@onready var hint_label: Label = $CanvasLayer/UI/HintPopup/MarginContainer/HintText
@onready var quest_log_btn: Button = $CanvasLayer/UI/TopRightStack/QuestLogBtn
@onready var quest_log_popup: PanelContainer = $CanvasLayer/UI/QuestLogPopup
@onready var quest_log_text: RichTextLabel = $CanvasLayer/UI/QuestLogPopup/MarginContainer/VBox/QuestLogText
@onready var quest_log_close_btn: Button = $CanvasLayer/UI/QuestLogPopup/MarginContainer/VBox/BtnQuestLogClose
@onready var msg_label: Label = $CanvasLayer/UI/MessageToast

var inv: GameInventory = GameInventory.new()
## 預留欄位，與存檔一併序列化。
var money: int = 0
var quest_phase: int = 1
var two_player: bool = false
var _build_kind: BuildKind = BuildKind.NONE
## 左鍵長按放開後，成功建造則保持模式連放，直到失敗或 Esc。
var _build_use_continuous: bool = false
## 建造／拆除模式下左鍵已按下，等待放開以區分短按／長按。
var _build_lmb_armed: bool = false
var _build_lmb_down_ms: int = -1
const BUILD_LONG_PRESS_MS := 320
var p2_mouse_right_down: bool = false

var _msg_time: float = 0.0
var _bottom_hud: BottomHudController
var _hud_expand_btn: Button = null
var _build_grid: BuildGridOverlay
## 開啟工作台製作 UI 時，用於判定鄰近「帶倉儲的箱子」是否併入材料池。
var _workbench_popup_anchor: WorldBuildPiece = null

var _scene_prop: PackedScene = preload("res://scenes/interactable_prop.tscn")
var _scene_loose: PackedScene = preload("res://scenes/loose_pickup.tscn")
var _campfire_script: Script = preload("res://scripts/campfire_marker.gd")
var _sapling_script: Script = preload("res://scripts/planted_sapling.gd")
var _berry_bush_script: Script = preload("res://scripts/berry_bush.gd")
var _farmland_script: Script = preload("res://scripts/farmland_tile.gd")
var _rm_npc_script: Script = preload("res://scripts/rm_stationary_npc.gd")

## 隨機生成樹／石／掉落物時避開：Water 任意圖塊、onGround 上 Rock Slope（含樓梯）。
var _spawn_avoid_water_layers: Array[TileMapLayer] = []
var _spawn_avoid_onground_layers: Array[TileMapLayer] = []
## 單人觸控導航：對應的觸控點 index（-1 表示無）。
var _p1_touch_idx: int = -1
var _mobile_touch_bar: Control = null
## 設定：是否顯示手機／網頁用觸控快捷列（右下角）。
var _mobile_touch_bar_user_enabled: bool = true
var _settings_mobile_touch_check: CheckButton = null
var _campfire_cook_popup: PanelContainer
var _btn_campfire_craft_jerky: Button
var _btn_campfire_eat_jerky: Button
var _btn_campfire_craft_bbq: Button
var _btn_campfire_eat_bbq: Button
var _workbench_craft_popup: PanelContainer
var _btn_workbench_craft_spear: Button
var _btn_workbench_craft_sword: Button
var _btn_workbench_craft_sticky_armor: Button
var _btn_workbench_craft_dirt: Button
var _lbl_wb_cost_spear: Label
var _lbl_wb_cost_sword: Label
var _lbl_wb_cost_armor: Label
var _lbl_wb_cost_dirt: Label
var _p1_weapon_cd: float = 0.0
var _p2_weapon_cd: float = 0.0
var _p1_weapon_skill_cd: float = 0.0
var _p2_weapon_skill_cd: float = 0.0
var _auto_save_timer: Timer
var _reset_confirm: ConfirmationDialog
var _styling_popup: PanelContainer
var _styling_opt_target: OptionButton
var _styling_opt_gender: OptionButton
var _styling_opt_skin: OptionButton
var _styling_opt_hair: OptionButton
var _styling_opt_outfit: OptionButton
var _styling_opt_pants: OptionButton
var _styling_btn_apply: Button
var _styling_btn_close: Button
var _styling_skin_keys: Array[String] = []
var _styling_hair_paths: Array[String] = []
var _styling_outfit_paths: Array[String] = []
var _styling_pants_paths: Array[String] = []
## 已解鎖的 Pixeline 服飾／髮型／頭飾 res:// 路徑（鍵存在即解鎖）。
var _styling_unlock_set: Dictionary = {}
var _styling_preview_vp: SubViewport
var _styling_preview_root: Node2D
var _styling_pv_body: Sprite2D
var _styling_pv_pants: Sprite2D
var _styling_pv_chest: Sprite2D
var _styling_pv_hair: Sprite2D
var _styling_title_label: Label
var _styling_hint_label: Label
## 新遊戲／進度初始化後：先只顯示造型視窗；全螢幕遮罩阻擋操作直到關閉或成功套用。
var _boot_styling_active: bool = false
var _boot_styling_blocker: ColorRect
var _boot_saved_left_vitals_visible: bool = true
var _loading_save: bool = false
var _game_boot_complete: bool = false
var _sfx_volume: float = 1.0
var _sfx_muted: bool = false
var _bgm_volume: float = 1.0
var _bgm_muted: bool = false
var _p1_name: String = ""
var _p2_name: String = ""
var _settings_sfx_check: CheckButton
var _settings_sfx_slider: HSlider
var _settings_bgm_check: CheckButton
var _settings_bgm_slider: HSlider
var _settings_p1_name: LineEdit
var _settings_p2_name: LineEdit
var _settings_two_player_check: CheckButton
## 0..1，0=子夜、0.5=正午；供營火燈等讀取。
var day_brightness: float = 0.5
var _cycle_phase: float = 0.42
## 遊戲內曆：1=1/1 … 365=12/31；每完成一次日夜相位循環 +1 天。
var game_calendar_doy: int = 1
## 世界區域格座標：(0,0)=初始之地；北(0,1)、東(1,0)、西(-1,0)、南(0,-1)。
var world_region: Vector2i = Vector2i.ZERO
## 區域傳送：進入邊緣傳送帶時提示地名，按互動鍵才傳送（不重複提示同一組合）。
var _portal_prompt_last_key: String = ""
## 各區獨立實體：鍵 "x,y" → 與存檔相同的 Dictionary 陣列（含樹／石／野生掉落／莓果叢／森林怪等）。
var _region_entity_store: Dictionary = {}
## 鍵 "x,y" → 該區是否已完成「首次野生布局」（未完成時進圖會先生成野生再疊上存檔建築等）。
var _region_wild_init: Dictionary = {}
## 上次已結算「遊戲日曆日」野生怪補生的日序（1..365）；與 game_calendar_doy 同步推進。
var _mob_respawn_last_calendar_doy: int = 1
## 翠幽之森：離開該區時累積、進區再落地的補生數（避免在無地圖遮罩時寫入錯誤座標）。
var _forest_mob_bank_slimes: int = 0
var _forest_mob_bank_boars: int = 0

## 1P 狀態條（生命、飽食度）。
var vitals_hp: float = 100.0
var vitals_hp_max: float = 100.0
## 飽食度 UI：數值為「飽足度」（高＝不餓，0＝極餓）；由移動／採集／攻擊／技能消耗，不再隨時間遞減。
var vitals_satiety: float = 100.0
var vitals_satiety_max: float = 100.0
## 快捷欄 9 格：武器／莓果／莓果干／肉排／烤肉等（右鍵編排）。
var _hotbar_items: Array[StringName] = []
var _hotbar_ctrl: HotbarController = null
var _backpack_ctx_menu: PopupMenu = null
var _backpack_ctx_slot: int = -1
var _ctx_hotbar_map_id: StringName = &""
var _chest_take_dialog: AcceptDialog = null
var _chest_take_spin: SpinBox = null
var _chest_take_hint: Label = null
var _chest_take_slot_idx: int = -1
var _bgm_player: AudioStreamPlayer
## 角色技能：&"dash" 短衝刺、&"charge" 蓄力、&"iron_wall" 鐵壁（教官處裝備與技能書解鎖）。
var _p1_character_skill: StringName = &"dash"
var _p2_character_skill: StringName = &"dash"
var _skill_unlock_charge: bool = false
var _skill_unlock_iron_wall: bool = false
## 蓄力：下一次武器技能（木槍迴旋／石短劍投擲）傷害加倍。
var _p1_next_weapon_skill_double: bool = false
var _p2_next_weapon_skill_double: bool = false
## 鐵壁：秒；受敵方接觸傷害時若該玩家啟用中則減半（共用生命條依受擊者槽位判定）。
var _p1_iron_wall_timer: float = 0.0
var _p2_iron_wall_timer: float = 0.0
## 商人：累計「賣出」次數（用於每日收購種類上限）；當日收購清單與配額。
var merchant_trade_total: int = 0
var _merchant_offer_doy: int = -1
var _merchant_buy_types: Array[StringName] = []
var _merchant_premium_index: int = 0
var _merchant_sold_today: Dictionary = {}
var _merchant_popup: PanelContainer
var _merchant_lbl_offers: Label
var _merchant_sells_vbox: VBoxContainer
var _merchant_btn_seed: Button
var _instructor_popup: PanelContainer
var _instructor_lbl_money: Label
var _btn_instructor_buy_charge: Button
var _btn_instructor_buy_iron: Button
var _instructor_opt_p1: OptionButton
var _instructor_opt_p2: OptionButton
var _instructor_lbl_p2: Label
var _instructor_syncing_options: bool = false
## 左上角日期／時間下方：目前滑鼠對應的世界座標。
var _mouse_world_coord_label: Label
## 左上角地名列下方：1P 角色世界座標。
var _p1_world_coord_label: Label
var _left_money_label: Label = null
var _vitals_hunger_icon: TextureRect = null

const _MERCHANT_RESOURCE_POOL: Array[StringName] = [
	&"wood",
	&"stone",
	&"berries",
	&"berry_jerky",
	&"seed",
	&"slime_goo",
	&"leather",
	&"meat_cutlet",
	&"bbq_meat",
	&"dirt",
	&"turnip",
]


func _ready() -> void:
	_apply_ui_cjk_font()
	add_to_group("game_main")
	player1.player_index = 0
	player2.player_index = 1
	player2.visible = false
	player2.process_mode = Node.PROCESS_MODE_DISABLED
	player2.set_carry_light_suppressed(true)
	if backdrop:
		backdrop.visible = true
	_build_bounds()
	_create_build_grid_overlay()
	VisualRegistry.ensure_baked()
	_setup_hud_expand_btn()
	_setup_bottom_hud()
	_ensure_hotbar_items_size()
	_setup_hotbar()
	_bottom_hud.bind_dismantle_glow_button(dismantle_btn)
	inv_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	right_hud_column.visible = false
	hint_popup.visible = false
	quest_log_popup.visible = false
	settings_popup.visible = false
	hint_help_btn.pressed.connect(_toggle_hint_popup)
	quest_log_btn.pressed.connect(_toggle_quest_log_popup)
	quest_log_close_btn.pressed.connect(_close_quest_log_popup)
	dismantle_btn.pressed.connect(func() -> void: _toggle_build_kind(BuildKind.DISMANTLE))
	settings_btn.pressed.connect(_toggle_settings_popup)
	styling_btn.pressed.connect(_toggle_styling_popup)
	settings_btn_save.pressed.connect(_on_settings_manual_save)
	settings_btn_reset.pressed.connect(_on_settings_reset_pressed)
	settings_btn_close.pressed.connect(_on_settings_close)
	_setup_campfire_cook_popup()
	_setup_workbench_craft_popup()
	_setup_merchant_popup()
	_setup_instructor_popup()
	_setup_save_confirm_dialog()
	_setup_styling_popup()
	_setup_auto_save_timer()
	var _new_game_boot_styling := false
	if not _try_load_save_on_startup():
		_new_game_boot_styling = true
		_styling_init_unlock_defaults()
		_reload_tiled_map_for_current_region()
		_spawn_initial_room()
		_region_wild_init[_region_store_key(Vector2i.ZERO)] = true
		_merchant_ensure_offers_for_calendar()
		_update_quest_ui()
	_update_inv_bar()
	_show_hint()
	_apply_vitals_bars_theme()
	_setup_left_vitals_panel_icons()
	_apply_top_right_style()
	_load_settings()
	_setup_mobile_touch_bar()
	_setup_settings_controls()
	_apply_audio_settings()
	_apply_player_names()
	_setup_p1_world_coord_label()
	_setup_mouse_world_coord_label()
	_update_vitals_bars_ui()
	camera.make_current()
	camera.position = player1.global_position
	var _cam_sz := get_viewport_rect().size
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(_cam_sz.x)
	camera.limit_bottom = int(_cam_sz.y)
	_update_day_night_modulate()
	_setup_bgm()
	_game_boot_complete = true
	if _new_game_boot_styling:
		call_deferred("_open_boot_styling_wizard")


func _setup_bgm() -> void:
	if not ResourceLoader.exists(BGM_PATH):
		push_warning("Main: 找不到背景音樂（請確認路徑）：%s" % BGM_PATH)
		return
	var st: AudioStream = load(BGM_PATH) as AudioStream
	if st == null:
		push_warning("Main: 背景音樂載入失敗：%s" % BGM_PATH)
		return
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmDraftingTomorrow"
	_bgm_player.stream = st
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = -10.0
	add_child(_bgm_player)
	_bgm_player.play()


func campfire_light_strength() -> float:
	## 0＝大白天（營火燈關閉），1＝深夜（燈全開）；平滑過渡。
	var s := day_brightness
	return 1.0 - smoothstep(0.12, 0.46, s)


func campfire_light_radius_scale() -> float:
	## 深夜略放大半徑；上限勿太大以免光暈蓋滿畫面。
	var w := campfire_light_strength()
	return lerpf(1.0, 1.08, w)


func player_carry_light_strength() -> float:
	## 與營火同一「是否入夜」曲線；火把／提燈可再乘在 PlayerController 的 export 上。
	return campfire_light_strength()


func player_carry_light_radius_scale() -> float:
	var w := player_carry_light_strength()
	return lerpf(1.0, 1.18, w)


## PlayerController 從這裡查詢對應玩家的武器技能剩餘 CD（秒）。
func player_weapon_cd(player_idx: int) -> float:
	return _p1_weapon_cd if player_idx == 0 else _p2_weapon_cd


func _apply_ui_cjk_font() -> void:
	if not ResourceLoader.exists(UI_CJK_FONT):
		push_warning("Main: 缺少中文字型：%s" % UI_CJK_FONT)
		return
	var ff := FontFile.new()
	var err := ff.load_dynamic_font(UI_CJK_FONT)
	if err != OK:
		push_warning("Main: 字型載入失敗：%s" % error_string(err))
		return
	ThemeDB.fallback_font = ff


func _mobile_touch_platform() -> bool:
	return OS.has_feature("web") or DisplayServer.is_touchscreen_available()


func _mobile_touch_bar_bottom_clearance() -> float:
	## 與底部主功能表（展開時）及收合條錯開；收合時略抬高即可。
	if _bottom_hud != null and not _bottom_hud.is_hud_minimized():
		return 288.0
	return 96.0


func _layout_mobile_touch_bar() -> void:
	if _mobile_touch_bar == null:
		return
	var bar := _mobile_touch_bar as HBoxContainer
	var side := 10.0
	var btn_h := 44.0
	var sep := 6.0
	var nbtn := float(bar.get_child_count())
	var btn_w := 56.0
	var w := nbtn * btn_w + maxf(0.0, nbtn - 1.0) * sep
	var y_clear := _mobile_touch_bar_bottom_clearance()
	bar.anchor_left = 1.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_right = -side
	bar.offset_left = -side - w
	bar.offset_bottom = -y_clear
	bar.offset_top = bar.offset_bottom - btn_h
	bar.z_index = 24


func _apply_mobile_touch_bar_visibility() -> void:
	if _mobile_touch_bar == null:
		return
	var want := _mobile_touch_platform() and _mobile_touch_bar_user_enabled and not two_player
	_mobile_touch_bar.visible = want
	if want:
		_layout_mobile_touch_bar()


func _setup_mobile_touch_bar() -> void:
	if not _mobile_touch_platform():
		return
	var ui := $CanvasLayer/UI as Control
	var bar := HBoxContainer.new()
	bar.name = "MobileTouchBar"
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.add_theme_constant_override("separation", 6)
	ui.add_child(bar)
	bar.add_child(_mk_mobile_btn("採集", _mobile_btn_harvest))
	bar.add_child(_mk_mobile_btn("交互", _mobile_btn_interact_p1))
	bar.add_child(_mk_mobile_btn("技能", _mobile_btn_character_skill_p1))
	bar.add_child(_mk_mobile_btn("武技", _mobile_btn_weapon_skill_p1))
	_mobile_touch_bar = bar
	if not get_viewport().size_changed.is_connected(_layout_mobile_touch_bar):
		get_viewport().size_changed.connect(_layout_mobile_touch_bar)
	_apply_mobile_touch_bar_visibility()


func _mk_mobile_btn(txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.custom_minimum_size = Vector2(56, 40)
	b.pressed.connect(cb)
	return b


func _mobile_btn_harvest() -> void:
	try_harvest_near(player1, 0)


func _mobile_btn_interact_p1() -> void:
	## 與鍵盤 G 相同邏輯：依距離開營火烹飪／工作台／門（最近一項）。
	try_use_near(player1, 0)


func _mobile_btn_character_skill_p1() -> void:
	_try_use_character_skill(0)


func _mobile_btn_weapon_skill_p1() -> void:
	try_weapon_skill_near(player1, 0)


func _unload_tiled_map() -> void:
	var dm: Node = $DayNightModulate
	var old: Node = dm.get_node_or_null("TiledMap")
	if old != null:
		dm.remove_child(old)
		old.free()
	_spawn_avoid_water_layers.clear()
	_spawn_avoid_onground_layers.clear()


func _load_tiled_map_from_path(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("Main: 地圖檔不存在：%s" % path)
		return false
	var res: Resource = load(path)
	if res == null or not (res is PackedScene):
		push_warning("Main: 地圖載入失敗（非 PackedScene）：%s" % path)
		return false
	var map_root: Node2D = (res as PackedScene).instantiate() as Node2D
	if map_root == null:
		return false
	map_root.name = "TiledMap"
	## 不可掛在 WorldYSort 底下：該節點啟用 Y Sort，整張 TileMap 會與玩家依 Y 競爭排序，玩家在畫面上方時會被整張地圖蓋住。改掛在 DayNightModulate，並插在 WorldYSort 之前，地圖永遠當背景。
	var dm: Node = $DayNightModulate
	var wys: Node2D = $DayNightModulate/WorldYSort
	dm.add_child(map_root)
	dm.move_child(map_root, wys.get_index())
	if backdrop:
		backdrop.visible = false
	_apply_tiled_map_layer_z_order(map_root)
	## YATI 對動畫磚的處理：地圖存的是「動畫幀 atlas 座標」（如 (7,0)），
	## 但 Godot TileSetAtlasSource 只認識「基底 atlas 座標」（如 (1,0)）。
	## 幀座標 set_cell 後 Godot 找不到對應 tile → 磁磚不顯示。
	## 此函式把所有幀座標修正為基底座標，讓動畫磚（水域等）正確渲染。
	_fix_animated_tile_atlas_coords(map_root)
	## TileSet 的 physics_layer_0（來自 TSX objectgroup，如 TallGrass、Sand）預設 collision_layer=1 會擋玩家。
	## 水域 / 陡坡碰撞已由 StaticBody2D 程式生成，所有 TileMapLayer 本身的碰撞都要清除。
	_disable_tilemap_layer_physics(map_root)
	_add_water_collision_from_tiled_map(map_root)
	_add_onground_rock_slope_collision_from_tiled_map(map_root)
	_collect_tilemap_layers_named(map_root, _spawn_avoid_water_layers, "water")
	_collect_tilemap_layers_named(map_root, _spawn_avoid_onground_layers, "onground")
	## YATI 會把多邊形／矩形物件建成 StaticBody2D，預設 collision_layer=1 會擋玩家；這些層只用來標區域，不應有實體碰撞。
	_disable_physics_for_tiled_design_overlays(map_root)
	## 下一幀再跑一次，避免插件／場景在 `add_child` 當幀才掛上碰撞體時漏關。
	call_deferred("_disable_physics_for_tiled_design_overlays", map_root)
	return true


## 將整張 Tiled 地圖所有 TileMapLayer 的磁磚碰撞關閉。
## TallGrass / Sand / Water 等 TSX 帶 objectgroup → TileSet physics → 會擋玩家。
## Godot 4.6 的 TileMapLayer 不可寫 collision_layer／collision_mask；改用 collision_enabled。
## 水域與陡坡由 StaticBody2D 程式碼另行生成。
func _disable_tilemap_layer_physics(node: Node) -> void:
	if node is TileMapLayer:
		(node as TileMapLayer).collision_enabled = false
	for ch in node.get_children():
		_disable_tilemap_layer_physics(ch)


## 關閉僅供邏輯使用的物件層碰撞（仍保留子節點形狀供傳送／資源區取點）。
func _collision_object_disable_physics(co: CollisionObject2D) -> void:
	co.collision_layer = 0
	co.collision_mask = 0


## 祖先有 `resourcezone`／`teleport` 物件層（不分大小寫）的碰撞體：僅標記用，不可擋人。
func _collision_body_is_under_tiled_design_layer(co: CollisionObject2D) -> bool:
	var p: Node = co.get_parent()
	while p != null:
		if p is Node:
			var nm := String(p.name).to_lower()
			if nm == "resourcezone" or nm == "teleport":
				return true
		p = p.get_parent()
	return false


func _disable_physics_for_tiled_design_overlays(map_root: Node2D) -> void:
	if map_root == null or not is_instance_valid(map_root):
		return
	_disable_physics_for_tiled_design_overlays_r(map_root)


func _disable_physics_for_tiled_design_overlays_r(node: Node) -> void:
	## Godot 4.6 的 TileMapLayer 可能符合 CollisionObject2D，但不可任意寫 collision_layer；只處理實體／區域。
	if (
		node is StaticBody2D
		or node is AnimatableBody2D
		or node is RigidBody2D
		or node is CharacterBody2D
		or node is Area2D
	):
		var co := node as CollisionObject2D
		if _collision_body_is_under_tiled_design_layer(co):
			_collision_object_disable_physics(co)
	for ch in node.get_children():
		_disable_physics_for_tiled_design_overlays_r(ch)


func _reload_tiled_map_for_current_region() -> void:
	_unload_tiled_map()
	if world_region == Vector2i.ZERO:
		if not _load_tiled_map_from_path("res://assets/maps/Map00.tmj"):
			if backdrop:
				backdrop.visible = true
	elif world_region == Vector2i(0, 1):
		if not _load_tiled_map_from_path("res://assets/maps/Map01.tmj"):
			push_warning("Main: 北方山麓 Map01 載入失敗，改用空地。")
			_load_empty_region_root()
	elif world_region == Vector2i(0, -1):
		if not _load_tiled_map_from_path("res://assets/maps/Map0-1.tmj"):
			push_warning("Main: 溪谷村落 Map0-1 載入失敗，改用空地。")
			_load_empty_region_root()
	else:
		_load_empty_region_root()


## 無專用 tmj 的區域：空 Node2D 佔位 + Backdrop 草地（無水／無 TileMap 遮罩）。
func _load_empty_region_root() -> void:
	var root := Node2D.new()
	root.name = "TiledMap"
	var dm: Node = $DayNightModulate
	var wys: Node2D = $DayNightModulate/WorldYSort as Node2D
	dm.add_child(root)
	dm.move_child(root, wys.get_index())
	if backdrop:
		backdrop.visible = true
	_spawn_avoid_water_layers.clear()
	_spawn_avoid_onground_layers.clear()


func _region_store_key(r: Vector2i) -> String:
	return "%d,%d" % [r.x, r.y]


func _calendar_forward_days(from_doy: int, to_doy: int) -> int:
	var a: int = clampi(from_doy, 1, 365)
	var b: int = clampi(to_doy, 1, 365)
	if b >= a:
		return b - a
	return (365 - a) + b


func _forest_mob_placed_counts() -> Vector2i:
	var slime_n := 0
	var boar_n := 0
	if world_region == FOREST_WORLD_REGION:
		for c in entities.get_children():
			if c is ForestSlime:
				slime_n += 1
			elif c is ForestMushroom:
				boar_n += 1
		return Vector2i(slime_n, boar_n)
	var fk := _region_store_key(FOREST_WORLD_REGION)
	if not _region_entity_store.has(fk):
		return Vector2i.ZERO
	for item_v in _region_entity_store[fk]:
		if not item_v is Dictionary:
			continue
		var item := item_v as Dictionary
		match str(item.get("t", "")):
			"forest_slime":
				slime_n += 1
			"forest_mushroom", "forest_boar":
				boar_n += 1
			_:
				pass
	return Vector2i(slime_n, boar_n)


func _forest_mob_effective_counts() -> Vector2i:
	var placed := _forest_mob_placed_counts()
	return Vector2i(placed.x + _forest_mob_bank_slimes, placed.y + _forest_mob_bank_boars)


func _forest_mob_respawn_region_ready() -> bool:
	var fk := _region_store_key(FOREST_WORLD_REGION)
	return bool(_region_wild_init.get(fk, false)) and _region_entity_store.has(fk)


func _apply_forest_mob_respawn_for_passed_days(days: int) -> void:
	if days <= 0:
		return
	if not _forest_mob_respawn_region_ready():
		return
	var eff := _forest_mob_effective_counts()
	var cap_s: int = GameConstants.REGION_FOREST_SLIMES
	var cap_b: int = GameConstants.REGION_FOREST_BOARS
	var want_s: int = mini(cap_s, eff.x + days * GameConstants.FOREST_SLIME_RESPAWN_PER_GAME_DAY)
	var want_b: int = mini(cap_b, eff.y + days * GameConstants.FOREST_BOAR_RESPAWN_PER_GAME_DAY)
	var add_s: int = want_s - eff.x
	var add_b: int = want_b - eff.y
	if add_s <= 0 and add_b <= 0:
		return
	if world_region == FOREST_WORLD_REGION:
		var sz := get_viewport_rect().size
		for _i in add_s:
			_spawn_forest_slime(sz, true)
		for _j in add_b:
			_spawn_forest_mushroom(sz, true)
	else:
		_forest_mob_bank_slimes += add_s
		_forest_mob_bank_boars += add_b


func _flush_forest_mob_bank() -> void:
	if world_region != FOREST_WORLD_REGION:
		return
	if _forest_mob_bank_slimes <= 0 and _forest_mob_bank_boars <= 0:
		return
	var sz := get_viewport_rect().size
	for _i in _forest_mob_bank_slimes:
		_spawn_forest_slime(sz, true)
	for _j in _forest_mob_bank_boars:
		_spawn_forest_mushroom(sz, true)
	_forest_mob_bank_slimes = 0
	_forest_mob_bank_boars = 0


func _sync_mob_respawn_state_from_save_dict(d: Dictionary, loaded_save_ver: int) -> void:
	_forest_mob_bank_slimes = 0
	_forest_mob_bank_boars = 0
	var fmb: Variant = d.get("forest_mob_bank", null)
	if fmb is Dictionary:
		_forest_mob_bank_slimes = maxi(0, int((fmb as Dictionary).get("s", 0)))
		_forest_mob_bank_boars = maxi(0, int((fmb as Dictionary).get("b", 0)))
	var saved_last := int(d.get("mob_respawn_last_doy", -1))
	if saved_last < 1 or loaded_save_ver < 18:
		_mob_respawn_last_calendar_doy = game_calendar_doy
		return
	var gap := _calendar_forward_days(saved_last, game_calendar_doy)
	if gap > 0:
		_apply_forest_mob_respawn_for_passed_days(gap)
	_mob_respawn_last_calendar_doy = game_calendar_doy


func _persist_entities_for_region(r: Vector2i) -> void:
	var list: Array = []
	for c in entities.get_children():
		var se := _serialize_entity_node(c)
		if str(se.get("t", "")).is_empty():
			continue
		list.append(se)
	_region_entity_store[_region_store_key(r)] = list


func _restore_entities_for_region(r: Vector2i) -> void:
	var key := _region_store_key(r)
	if not _region_entity_store.has(key):
		return
	var list: Variant = _region_entity_store[key]
	if not (list is Array):
		return
	for item in list as Array:
		if item is Dictionary:
			_spawn_entity_from_save(item as Dictionary)


## 舊存檔沒有 pstyle 時：依名稱／ValleyNpc_ 編號補上與新遊戲相同的 Pixeline 預設。
func _valley_npc_default_pixeline_styling(display_nm: String, node_name: String) -> Dictionary:
	var nm := display_nm.strip_edges()
	match nm:
		"教官":
			return PlayerStylingCatalog.valley_npc_preset_instructor().duplicate(true)
		"商人":
			return PlayerStylingCatalog.valley_npc_preset_merchant().duplicate(true)
		"總管":
			return PlayerStylingCatalog.valley_npc_preset_steward().duplicate(true)
		"村長":
			return PlayerStylingCatalog.valley_npc_preset_village_chief().duplicate(true)
		_:
			pass
	if node_name.begins_with("ValleyNpc_"):
		var rest := node_name.substr("ValleyNpc_".length())
		if rest.is_valid_int():
			var idx: int = int(rest) - 1
			var fb: Array[Dictionary] = [
				PlayerStylingCatalog.valley_npc_preset_instructor(),
				PlayerStylingCatalog.valley_npc_preset_merchant(),
				PlayerStylingCatalog.valley_npc_preset_steward(),
				PlayerStylingCatalog.valley_npc_preset_village_chief(),
			]
			if idx >= 0 and idx < fb.size():
				return fb[idx].duplicate(true)
	return {}


func _spawn_valley_village_npcs() -> void:
	## 溪谷村落 Map0-1：四個站立 NPC（Pixeline 預設造型；讀檔無 pstyle 時仍可用 rm slot）。教官(1176,105)、商人(1081,119)、總管(1112,308)、村長(808,156)。
	VisualRegistry.ensure_baked()
	var presets: Array[Dictionary] = [
		PlayerStylingCatalog.valley_npc_preset_instructor(),
		PlayerStylingCatalog.valley_npc_preset_merchant(),
		PlayerStylingCatalog.valley_npc_preset_steward(),
		PlayerStylingCatalog.valley_npc_preset_village_chief(),
	]
	var any_pixeline := false
	for pd in presets:
		var gm := bool(pd.get("gender_male", true))
		var sk := str(pd.get("skin", "medium"))
		var bp := PlayerStylingCatalog.base_body_path(gm, sk)
		if not bp.is_empty() and ResourceLoader.exists(bp):
			any_pixeline = true
			break
	if not any_pixeline and VisualRegistry.rm_walk_sheet_texture() == null:
		return
	const SLOTS: Array[int] = [1, 2, 3, 4]
	const POS: Array[Vector2] = [
		Vector2(1176, 105),
		Vector2(1081, 119),
		Vector2(1112, 308),
		Vector2(808, 156),
	]
	## 與 ValleyNpc_1～4、POS 順序對應：教官、商人、總管、村長。
	const NPC_NAMES: Array[String] = ["教官", "商人", "總管", "村長"]
	for i in POS.size():
		var npc := Node2D.new()
		npc.name = "ValleyNpc_%d" % (i + 1)
		npc.set_script(_rm_npc_script)
		npc.global_position = POS[i]
		npc.set("rm_sheet_slot", SLOTS[i])
		npc.set("npc_display_name", NPC_NAMES[i])
		if any_pixeline:
			npc.set("pixeline_styling", (presets[i] as Dictionary).duplicate(true))
		entities.add_child(npc)
		npc.add_to_group("valley_village_npc")


func _spawn_wild_props_for_region(c: Vector2i, sz: Vector2) -> void:
	if not _world_region_is_known(c):
		return
	match c:
		Vector2i.ZERO:
			for i in GameConstants.INIT_TREES:
				_spawn_prop(WorldPropStatic.PropKind.TREE, sz, true)
			for j in GameConstants.INIT_ROCKS:
				_spawn_prop(WorldPropStatic.PropKind.ROCK, sz, true)
			for k in GameConstants.INIT_LOOSE_WOOD:
				_spawn_loose_at(LoosePickup.PickKind.WOOD, sz, true)
			for m in GameConstants.INIT_LOOSE_STONE:
				_spawn_loose_at(LoosePickup.PickKind.STONE, sz, true)
			_spawn_one_berry_bush(sz, true)
		Vector2i(0, 1):
			for i in GameConstants.REGION_NORTH_TREES:
				_spawn_prop(WorldPropStatic.PropKind.TREE, sz, true)
			for j in GameConstants.REGION_NORTH_ROCKS:
				_spawn_prop(WorldPropStatic.PropKind.ROCK, sz, true)
			for k in GameConstants.REGION_NORTH_LOOSE_WOOD:
				_spawn_loose_at(LoosePickup.PickKind.WOOD, sz, true)
			for m in GameConstants.REGION_NORTH_LOOSE_STONE:
				_spawn_loose_at(LoosePickup.PickKind.STONE, sz, true)
			for _i in range(GameConstants.REGION_NORTH_BERRY_BUSHES):
				_spawn_one_berry_bush(sz, true)
		Vector2i(1, 0):
			for i in GameConstants.REGION_ORCHARD_TREES:
				_spawn_prop(WorldPropStatic.PropKind.TREE, sz, true)
			for j in GameConstants.REGION_ORCHARD_ROCKS:
				_spawn_prop(WorldPropStatic.PropKind.ROCK, sz, true)
			for k in GameConstants.REGION_ORCHARD_LOOSE_WOOD:
				_spawn_loose_at(LoosePickup.PickKind.WOOD, sz, true)
			for m in GameConstants.REGION_ORCHARD_LOOSE_STONE:
				_spawn_loose_at(LoosePickup.PickKind.STONE, sz, true)
			for _i in range(GameConstants.REGION_ORCHARD_BERRY_BUSHES):
				_spawn_one_berry_bush(sz, true)
		Vector2i(-1, 0):
			for i in GameConstants.REGION_FOREST_TREES:
				_spawn_prop(WorldPropStatic.PropKind.TREE, sz, true)
			for j in GameConstants.REGION_FOREST_ROCKS:
				_spawn_prop(WorldPropStatic.PropKind.ROCK, sz, true)
			for k in GameConstants.REGION_FOREST_LOOSE_WOOD:
				_spawn_loose_at(LoosePickup.PickKind.WOOD, sz, true)
			for m in GameConstants.REGION_FOREST_LOOSE_STONE:
				_spawn_loose_at(LoosePickup.PickKind.STONE, sz, true)
			for _i in range(GameConstants.REGION_FOREST_BERRY_BUSHES):
				_spawn_one_berry_bush(sz, true)
			for _fs in range(GameConstants.REGION_FOREST_SLIMES):
				_spawn_forest_slime(sz, true)
			for _fb in range(GameConstants.REGION_FOREST_BOARS):
				_spawn_forest_mushroom(sz, true)
		Vector2i(0, -1):
			_spawn_valley_village_npcs()
		_:
			pass


## Tiled 層序：全部層都要在玩家（z=0）之下，用負值確保不蓋角色。
## 層間視覺順序靠節點順序維持（ground → 2f → onground → water 由先到後）。
## 注意：z_as_relative=true 時，有效 z = 父節點有效 z + 自身 z_index。
## map_root 在 DayNightModulate 內，WorldYSort 之前；
## 若用正 z_index，會蓋過 WorldYSort 內玩家（z=0），故全部設負值。
func _apply_tiled_map_layer_z_order(root: Node) -> void:
	var order: Dictionary = {"ground": -4, "2f": -3, "onground": -2, "water": -1}
	for c in root.get_children():
		if c is TileMapLayer:
			var nm := String(c.name).to_lower()
			if nm in order:
				var layer := c as TileMapLayer
				layer.z_index = int(order[nm])
				layer.z_as_relative = true
		elif c.get_child_count() > 0:
			_apply_tiled_map_layer_z_order(c)


## YATI 動畫磚 atlas 座標修正。
## 問題：Tileset_Water.tsx 的水域磁磚都是動畫磚（4 幀，水平排列）。
##       Tiled 把第 N 幀的 local ID 存進地圖資料，YATI 直接轉換成對應的 atlas 座標
##       （例如 local_id=7 → atlas(7,0)）。但 Godot 的 TileSetAtlasSource 只有
##       「基底磁磚」的記錄（如 atlas(1,0)）；幀位置不是獨立的 base tile，
##       set_cell 以幀座標存入後，TileMapLayer 找不到對應磁磚 → 透明不顯示。
## 修正：遍歷所有 TileMapLayer，對每個格子檢查其 atlas_coords 是否為合法基底磚
##       （has_tile()）；若否，呼叫 get_tile_at_coords() 取得擁有該位置的基底磚座標，
##       再以基底座標重新 set_cell。Godot 將自動播放動畫。
func _fix_animated_tile_atlas_coords(root: Node) -> void:
	for c in root.get_children():
		if c is TileMapLayer:
			var layer := c as TileMapLayer
			var ts := layer.tile_set
			if ts == null:
				continue
			var remapped := 0
			for cell: Vector2i in layer.get_used_cells():
				var src_id := layer.get_cell_source_id(cell)
				if src_id < 0:
					continue
				if not ts.has_source(src_id):
					continue
				var src := ts.get_source(src_id)
				if not src is TileSetAtlasSource:
					continue
				var atlas_src := src as TileSetAtlasSource
				var coords := layer.get_cell_atlas_coords(cell)
				## 如果這個座標已是合法基底磚，不需要修正
				if atlas_src.has_tile(coords):
					continue
				## 找出擁有此位置的基底磚（通常是動畫幀所屬的基底 tile）
				var base := atlas_src.get_tile_at_coords(coords)
				if base == Vector2i(-1, -1):
					continue
				var alt := layer.get_cell_alternative_tile(cell)
				layer.set_cell(cell, src_id, base, alt)
				remapped += 1
			if remapped > 0:
				print("Main: [%s] 修正 %d 格動畫磚幀座標 → 基底座標" % [c.name, remapped])
		elif c.get_child_count() > 0:
			_fix_animated_tile_atlas_coords(c)


## Tiled 的「Water」圖層通常沒有物理；為每格補 StaticBody2D（layer 1），與邊界／樹一致。
func _add_water_collision_from_tiled_map(root: Node2D) -> void:
	var layers: Array[TileMapLayer] = []
	_collect_tilemap_layers_named(root, layers, "water")
	if layers.is_empty():
		return
	var holder := _ensure_map_collision_holder(root, "GeneratedWaterCollision")
	for layer in layers:
		_fill_tile_layer_with_static_boxes(layer, holder)


func _ensure_map_collision_holder(root: Node2D, holder_name: String) -> Node2D:
	var ex := root.get_node_or_null(holder_name)
	if ex is Node2D:
		return ex as Node2D
	var h := Node2D.new()
	h.name = holder_name
	root.add_child(h)
	return h


func _fill_tile_layer_with_static_boxes(layer: TileMapLayer, holder: Node2D) -> void:
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
		body.add_child(col)
		holder.add_child(body)
		body.global_position = layer.to_global(layer.map_to_local(cell))


## onGround 上陡坡（Rock Slope 圖集）要擋人；底列樓梯圖塊不加碰撞（與水相同：StaticBody2D layer 1）。
func _add_onground_rock_slope_collision_from_tiled_map(root: Node2D) -> void:
	var layers: Array[TileMapLayer] = []
	_collect_tilemap_layers_named(root, layers, "onground")
	if layers.is_empty():
		return
	var holder := _ensure_map_collision_holder(root, "GeneratedRockSlopeCollision")
	for layer in layers:
		_fill_onground_rock_slope_blocking_boxes(layer, holder)


func _collect_tilemap_layers_named(node: Node, out: Array[TileMapLayer], want_name_lower: String) -> void:
	for c in node.get_children():
		if c is TileMapLayer and String(c.name).to_lower() == want_name_lower:
			out.append(c as TileMapLayer)
		_collect_tilemap_layers_named(c, out, want_name_lower)


## Map00 底列石階對應圖集座標（Tileset_RockSlope.png）；若換圖塊請改此表。
const _ROCK_SLOPE_STAIR_ATLAS: Array[Vector2i] = [
	Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7),
]


func _fill_onground_rock_slope_blocking_boxes(layer: TileMapLayer, holder: Node2D) -> void:
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
		body.add_child(col)
		holder.add_child(body)
		body.global_position = layer.to_global(layer.map_to_local(cell))


func _tileset_source_is_rock_slope(ts: TileSet, source_id: int) -> bool:
	var src := ts.get_source(source_id)
	if src == null or not (src is TileSetAtlasSource):
		return false
	var tex: Texture2D = (src as TileSetAtlasSource).texture
	if tex == null:
		return false
	var p := tex.resource_path.to_lower()
	return p.contains("rockslope") or p.contains("rock_slope")


func _close_quest_log_popup() -> void:
	quest_log_popup.visible = false


## Esc／手把 B：依序關閉最上層彈窗或建造模式。
func _try_close_modal_ui_stack() -> bool:
	if _styling_popup != null and _styling_popup.visible:
		_close_styling_popup()
		return true
	if _campfire_cook_popup != null and _campfire_cook_popup.visible:
		_close_campfire_cook_popup()
		return true
	if _bottom_hud != null and _bottom_hud.is_chest_panel_open():
		_bottom_hud.close_chest_panel()
		return true
	if _workbench_craft_popup != null and _workbench_craft_popup.visible:
		_close_workbench_craft_popup()
		return true
	if _merchant_popup != null and _merchant_popup.visible:
		_close_merchant_popup()
		return true
	if _instructor_popup != null and _instructor_popup.visible:
		_close_instructor_popup()
		return true
	if quest_log_popup.visible:
		_close_quest_log_popup()
		return true
	if hint_popup.visible:
		hint_popup.visible = false
		return true
	if settings_popup.visible:
		_on_settings_close()
		return true
	if _reset_confirm != null and _reset_confirm.visible:
		_reset_confirm.hide()
		return true
	if _build_kind != BuildKind.NONE or _build_use_continuous or _build_lmb_armed:
		_clear_build_session()
		return true
	return false


func _toggle_quest_log_popup() -> void:
	quest_log_popup.visible = not quest_log_popup.visible
	if quest_log_popup.visible:
		_refresh_quest_log_popup()
		_close_styling_popup()
		settings_popup.visible = false
		hint_popup.visible = false
		_close_campfire_cook_popup()
		_close_workbench_craft_popup()
		_close_merchant_popup()
		_close_instructor_popup()


func _refresh_quest_log_popup() -> void:
	if quest_log_text == null:
		return
	# 改標題
	var title_lbl := quest_log_popup.get_node_or_null("MarginContainer/VBox/Title") as Label
	if title_lbl != null:
		title_lbl.text = "任務日誌"
	# 目前任務區塊
	var body := "[b][color=#aad4ff]── 目前任務 ──[/color][/b]\n" + _quest_current_bbcode()
	# 已完成區塊（有才顯示）
	var done := _quest_completed_bbcode()
	if done.length() > 0:
		body += "\n\n[b][color=#88e498]── 已完成任務 ──[/color][/b]\n" + done
	quest_log_text.text = body


func _quest_completed_bbcode() -> String:
	var lines: Array[String] = []
	if quest_phase >= 2:
		lines.append("[color=#88e498]✓[/color] 製作石斧  （底部製作 · 木 3 · 石 2）")
	if quest_phase >= 3:
		lines.append("[color=#88e498]✓[/color] 放置營火  （加工站 · 木 5 · 石 3）")
	if quest_phase >= 4:
		lines.append("[color=#88e498]✓[/color] 放置木箱  （底部建造 · 木 6）")
	if quest_phase >= 5:
		lines.append(
			"[color=#88e498]✓[/color] 放置工作台  （底部建造 · 木 %d · 石 %d）"
			% [GameConstants.BUILD_WORKBENCH_WOOD, GameConstants.BUILD_WORKBENCH_STONE]
		)
		lines.append("[color=#88e498]✓[/color] 序章進度  （土路傳送探索鄰近區域）")
	if lines.is_empty():
		return (
			"[color=#9aa8ba]尚無已完成的主線紀錄。[/color]\n\n"
			+ "進行中的目標請看右側任務面板。"
		)
	return "\n\n".join(lines)


func _show_hint() -> void:
	var t := (
		"移動 WASD  ·  採集/砍樹 F  ·  互動/傳送 G  ·  快捷欄 1~9  ·  角色技 E（衝刺）  ·  武器技 Q  ·  拆除 右上按鈕\n"
		+ "建造/製作 底部面板  ·  存檔/重置 右上⚙  ·  近 NPC 左鍵對話\n"
		+ "飽足度：移動／採集／攻擊／技能會消耗（不隨時間下降）；吃莓果與料理可恢復。\n"
		+ "雙人 Tab 切換：2P 方向鍵／左搖桿移動（僅一支手把時給 2P；兩支時用第二支）或右鍵拖移  ·  K／A 互動  ·  L／LB 角色技  ·  P／RB 武器技  ·  X 採集  ·  任意手把 B 關閉視窗（同 Esc）"
	)
	if OS.has_feature("web") or DisplayServer.is_touchscreen_available():
		t += "\n手機/網頁：右下角快捷列（可在⚙設定關閉）· 長按快捷欄右鍵編排"
	hint_label.text = t


func _toggle_hint_popup() -> void:
	hint_popup.visible = not hint_popup.visible
	if hint_popup.visible:
		_close_styling_popup()
		settings_popup.visible = false
		quest_log_popup.visible = false
		_close_campfire_cook_popup()
		_close_workbench_craft_popup()
		_close_merchant_popup()
		_close_instructor_popup()


func _process(delta: float) -> void:
	_advance_day_night(delta)
	_update_day_night_modulate()
	_update_valley_village_npc_sleep_visibility()
	if _boot_styling_active:
		return

	var mid := player1.global_position
	if two_player:
		mid = (player1.global_position + player2.global_position) * 0.5
	camera.global_position = mid

	if two_player and p2_mouse_right_down:
		if (
			not player2.is_p2_gamepad_moving()
			and _mouse_in_world_interaction_band(get_viewport().get_mouse_position())
		):
			player2.set_mouse_nav_target(get_global_mouse_position(), true)

	_update_build_grid_preview()

	var mov := GameConstants.SATIETY_COST_MOVE_PER_SEC * delta
	if player1.velocity.length_squared() > 900.0:
		vitals_satiety = maxf(0.0, vitals_satiety - mov)
	if two_player and player2.velocity.length_squared() > 900.0:
		vitals_satiety = maxf(0.0, vitals_satiety - mov)

	_p1_iron_wall_timer = maxf(0.0, _p1_iron_wall_timer - delta)
	_p2_iron_wall_timer = maxf(0.0, _p2_iron_wall_timer - delta)

	if _msg_time > 0.0:
		_msg_time -= delta
		if _msg_time <= 0.0:
			msg_label.visible = false
	_p1_weapon_cd = maxf(0.0, _p1_weapon_cd - delta)
	_p2_weapon_cd = maxf(0.0, _p2_weapon_cd - delta)
	_p1_weapon_skill_cd = maxf(0.0, _p1_weapon_skill_cd - delta)
	_p2_weapon_skill_cd = maxf(0.0, _p2_weapon_skill_cd - delta)
	_update_vitals_bars_ui()
	_portal_tick(delta)
	if _hotbar_ctrl != null and _hotbar_ctrl.visible:
		if (
			_p1_weapon_skill_cd > 0.0
			or (two_player and _p2_weapon_skill_cd > 0.0)
			or player1.character_dash_cooldown_remaining() > 0.0
			or (two_player and player2.character_dash_cooldown_remaining() > 0.0)
			or _p1_iron_wall_timer > 0.001
			or _p2_iron_wall_timer > 0.001
			or _p1_next_weapon_skill_double
			or _p2_next_weapon_skill_double
		):
			_refresh_hotbar_ui()


func _advance_day_night(delta: float) -> void:
	var slow := _cycle_phase >= GameConstants.DAY_SLOW_PHASE_START and _cycle_phase <= GameConstants.DAY_SLOW_PHASE_END
	var mult := GameConstants.DAY_PHASE_ADVANCE_MULT if slow else GameConstants.NIGHT_PHASE_ADVANCE_MULT
	var step := delta * mult / GameConstants.DAY_CYCLE_BASE_SEC
	var acc := _cycle_phase + step
	while acc >= 1.0:
		acc -= 1.0
		_bump_game_calendar_day()
	_cycle_phase = acc
	## 與相位對齊的「日照量」：0=子夜、1=正午。
	day_brightness = clampf(0.5 - 0.5 * cos(_cycle_phase * TAU), 0.0, 1.0)


func _bump_game_calendar_day() -> void:
	game_calendar_doy += 1
	if game_calendar_doy > 365:
		game_calendar_doy = 1
	get_tree().call_group("farmland", "on_game_new_day")
	_merchant_ensure_offers_for_calendar()
	var gap := _calendar_forward_days(_mob_respawn_last_calendar_doy, game_calendar_doy)
	if gap > 0:
		_apply_forest_mob_respawn_for_passed_days(gap)
		_mob_respawn_last_calendar_doy = game_calendar_doy


func _game_doy_to_md_string(doy: int) -> String:
	var d: int = clampi(doy, 1, 365)
	var lens: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	for mi in lens.size():
		var ln: int = lens[mi]
		if d <= ln:
			return "%d/%d" % [mi + 1, d]
		d -= ln
	return "12/31"


func _format_game_clock_hm() -> String:
	var p: float = fposmod(_cycle_phase, 1.0)
	var total_min: int = int(floor(p * 24.0 * 60.0))
	total_min = mini(total_min, 24 * 60 - 1)
	var h: int = total_min / 60
	var m: int = total_min % 60
	return "%02d:%02d" % [h, m]


func _world_region_is_known(c: Vector2i) -> bool:
	return (
		c == Vector2i.ZERO
		or c == Vector2i(0, 1)
		or c == Vector2i(1, 0)
		or c == Vector2i(-1, 0)
		or c == Vector2i(0, -1)
	)


func _world_region_display_name(c: Vector2i) -> String:
	match c:
		Vector2i.ZERO:
			return "初始之地"
		Vector2i(0, 1):
			return "北方山麓"
		Vector2i(1, 0):
			return "甜甜果園"
		Vector2i(-1, 0):
			return "翠幽之森"
		Vector2i(0, -1):
			return "溪谷村落"
		_:
			return "未知區域"


func _portal_rects(vp: Vector2) -> Dictionary:
	var cx := vp.x * 0.5
	var cy := vp.y * 0.5
	var hw := GameConstants.REGION_PORTAL_HALF_WIDTH
	var band := GameConstants.REGION_PORTAL_BAND
	var ins := GameConstants.REGION_PORTAL_INSET
	return {
		&"north": Rect2(cx - hw, ins, hw * 2.0, band),
		&"south": Rect2(cx - hw, vp.y - ins - band, hw * 2.0, band),
		&"west": Rect2(ins, cy - hw, band, hw * 2.0),
		&"east": Rect2(vp.x - ins - band, cy - hw, band, hw * 2.0),
	}


## Tiled 物件層 `teleport` 內矩形（YATI → StaticBody2D + RectangleShape2D）在場景中的 AABB。
func _collision_shape_global_rect2(cs: CollisionShape2D) -> Rect2:
	var s := cs.shape
	if s == null or not (s is RectangleShape2D):
		return Rect2()
	var half: Vector2 = (s as RectangleShape2D).size * 0.5
	var xf: Transform2D = cs.global_transform
	var mn: Vector2 = xf * Vector2(-half.x, -half.y)
	var mx := mn
	for corner in [Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		var p: Vector2 = xf * corner
		mn = mn.min(p)
		mx = mx.max(p)
	return Rect2(mn, mx - mn)


func _teleport_collect_global_rects_from_node(node: Node, out: Array) -> void:
	if node is CollisionShape2D:
		var r := _collision_shape_global_rect2(node as CollisionShape2D)
		if r.size.x > 1.5 and r.size.y > 1.5:
			out.append(r)
	for ch in node.get_children():
		_teleport_collect_global_rects_from_node(ch, out)


## 依矩形中心離畫面四邊的距離，對應 north / south / west / east（與 `_portal_rects` 語意一致）。
func _classify_rect_to_portal_edge(rect: Rect2, vp: Vector2) -> StringName:
	var c := rect.get_center()
	var d_n := c.y
	var d_s := vp.y - c.y
	var d_w := c.x
	var d_e := vp.x - c.x
	var m := minf(minf(d_n, d_s), minf(d_w, d_e))
	if m == d_n:
		return &"north"
	if m == d_s:
		return &"south"
	if m == d_w:
		return &"west"
	return &"east"


func _tiled_teleport_rects_by_edge(map_root: Node2D, vp: Vector2) -> Dictionary:
	var layer := _find_tiled_object_layer_ci(map_root, "teleport")
	if layer == null:
		return {}
	var raw: Array = []
	for ch in layer.get_children():
		_teleport_collect_global_rects_from_node(ch, raw)
	if raw.is_empty():
		return {}
	var by_edge: Dictionary = {}
	for item in raw:
		var r := item as Rect2
		var e := _classify_rect_to_portal_edge(r, vp)
		if by_edge.has(e):
			by_edge[e] = (by_edge[e] as Rect2).merge(r)
		else:
			by_edge[e] = r
	return by_edge


## 預設邊緣傳送帶與 Tiled `teleport` 矩形 **合併**（玩家走邊緣或走地圖上標記區都能觸發）。
func _effective_portal_rects(vp: Vector2) -> Dictionary:
	var pr := _portal_rects(vp)
	var tmap := get_node_or_null("DayNightModulate/TiledMap")
	if tmap is Node2D:
		var te := _tiled_teleport_rects_by_edge(tmap as Node2D, vp)
		for k in te:
			pr[k] = (pr[k] as Rect2).merge(te[k] as Rect2)
	return pr


## 傳送後落點在傳送帶內側、離開邊緣 portal 矩形，避免一落地又觸發提示。
func _point_past_portal_toward_center(pr: Dictionary, edge: StringName) -> Vector2:
	var r: Rect2 = pr[edge]
	var c := r.get_center()
	var push := GameConstants.REGION_PORTAL_BAND * 0.5 + 36.0
	match edge:
		&"north", &"south":
			push = maxf(push, r.size.y * 0.5 + 28.0)
		&"west", &"east":
			push = maxf(push, r.size.x * 0.5 + 28.0)
		_:
			pass
	match edge:
		&"north":
			return Vector2(c.x, c.y + push)
		&"south":
			return Vector2(c.x, c.y - push)
		&"west":
			return Vector2(c.x + push, c.y)
		&"east":
			return Vector2(c.x - push, c.y)
		_:
			return c


func _any_player_in_rect(r: Rect2) -> bool:
	if r.has_point(player1.global_position):
		return true
	if two_player and r.has_point(player2.global_position):
		return true
	return false


func _clamp_party_spawn(p1_spot: Vector2) -> void:
	var vp := get_viewport_rect().size
	var m := GameConstants.WORLD_PLAY_MARGIN
	var lo := Vector2(m + 10.0, m + 10.0)
	var hi := Vector2(vp.x - m - 10.0, vp.y - m - 10.0)
	var p2_off := Vector2(28.0, 0.0)
	if two_player:
		p2_off = player2.global_position - player1.global_position
		if p2_off.length_squared() < 16.0:
			p2_off = Vector2(28.0, 0.0)
	player1.global_position = p1_spot.clamp(lo, hi)
	if two_player:
		player2.global_position = (player1.global_position + p2_off).clamp(lo, hi)


func _teleport_world_region(dest: Vector2i, spawn_edge: StringName) -> void:
	if not _world_region_is_known(dest):
		return
	var from_r := world_region
	if from_r == FOREST_WORLD_REGION:
		_flush_forest_mob_bank()
	_persist_entities_for_region(from_r)
	world_region = dest
	_reload_tiled_map_for_current_region()
	_clear_spawned_entities()
	var sz := get_viewport_rect().size
	var rk := _region_store_key(world_region)
	if not bool(_region_wild_init.get(rk, false)):
		_spawn_wild_props_for_region(world_region, sz)
		_region_wild_init[rk] = true
	_restore_entities_for_region(world_region)
	if world_region == FOREST_WORLD_REGION:
		_flush_forest_mob_bank()
	var pr_dest := _effective_portal_rects(sz)
	_clamp_party_spawn(_point_past_portal_toward_center(pr_dest, spawn_edge))
	_portal_prompt_last_key = ""
	_show_msg("已抵達「%s」" % _world_region_display_name(dest))
	_update_vitals_bars_ui()


func _portal_compute_offer() -> Dictionary:
	var vp := get_viewport_rect().size
	var pr := _effective_portal_rects(vp)
	var north: Rect2 = pr[&"north"]
	var south: Rect2 = pr[&"south"]
	var west: Rect2 = pr[&"west"]
	var east: Rect2 = pr[&"east"]
	match world_region:
		Vector2i.ZERO:
			if _any_player_in_rect(north):
				return {
					"dest": Vector2i(0, 1),
					"spawn_edge": &"south",
					"portal_edge": &"north",
				}
			if _any_player_in_rect(south):
				return {
					"dest": Vector2i(0, -1),
					"spawn_edge": &"north",
					"portal_edge": &"south",
				}
			if _any_player_in_rect(west):
				return {
					"dest": Vector2i(-1, 0),
					"spawn_edge": &"east",
					"portal_edge": &"west",
				}
			if _any_player_in_rect(east):
				return {
					"dest": Vector2i(1, 0),
					"spawn_edge": &"west",
					"portal_edge": &"east",
				}
		Vector2i(0, 1):
			if _any_player_in_rect(south):
				return {
					"dest": Vector2i.ZERO,
					"spawn_edge": &"north",
					"portal_edge": &"south",
				}
		Vector2i(0, -1):
			if _any_player_in_rect(north):
				return {
					"dest": Vector2i.ZERO,
					"spawn_edge": &"south",
					"portal_edge": &"north",
				}
		Vector2i(-1, 0):
			if _any_player_in_rect(east):
				return {
					"dest": Vector2i.ZERO,
					"spawn_edge": &"west",
					"portal_edge": &"east",
				}
		Vector2i(1, 0):
			if _any_player_in_rect(west):
				return {
					"dest": Vector2i.ZERO,
					"spawn_edge": &"east",
					"portal_edge": &"west",
				}
		_:
			pass
	return {}


func _portal_tick(_delta: float) -> void:
	if not _game_boot_complete or _loading_save or _boot_styling_active:
		return
	var offer := _portal_compute_offer()
	if offer.is_empty():
		_portal_prompt_last_key = ""
		return
	var dest: Vector2i = offer["dest"] as Vector2i
	var portal_e: StringName = offer["portal_edge"] as StringName
	var key := "%d,%d|%s" % [dest.x, dest.y, String(portal_e)]
	if key != _portal_prompt_last_key:
		_portal_prompt_last_key = key
		_show_msg(
			"前往「%s」— 按 G 傳送（雙人時 2P 為 K）。"
			% _world_region_display_name(dest)
		)


func _try_portal_interact_with(who: PlayerController) -> bool:
	var offer := _portal_compute_offer()
	if offer.is_empty():
		return false
	var pr := _effective_portal_rects(get_viewport_rect().size)
	var portal_e: StringName = offer["portal_edge"] as StringName
	var r: Rect2 = pr[portal_e]
	if not r.has_point(who.global_position):
		return false
	var dest: Vector2i = offer["dest"] as Vector2i
	var spawn_e: StringName = offer["spawn_edge"] as StringName
	_teleport_world_region(dest, spawn_e)
	GameSfx.play_interact(-3.0)
	return true


func _apply_saved_world_region(raw: Variant) -> void:
	world_region = Vector2i.ZERO
	if raw is Array:
		var a := raw as Array
		if a.size() >= 2:
			var c := Vector2i(int(a[0]), int(a[1]))
			if _world_region_is_known(c):
				world_region = c


func _update_day_night_modulate() -> void:
	if world_modulate == null:
		return
	var s := day_brightness
	## 子夜稍再暗一點，營火照明才顯得有必要。
	var c_night := Color(0.2, 0.22, 0.34, 1.0)
	var c_midnight := Color(0.14, 0.15, 0.24, 1.0)
	var c_day := Color(1.02, 0.99, 0.93, 1.0)
	var t := smoothstep(0.0, 1.0, s)
	var c := c_night.lerp(c_day, t)
	if s < 0.22:
		var midnight_mix := 1.0 - smoothstep(0.0, 0.22, s)
		c = c.lerp(c_midnight, midnight_mix)
	## 黃昏略暖
	if s > 0.15 and s < 0.55:
		var dusk := 1.0 - absf(s - 0.35) / 0.2
		c = c.lerp(Color(1.06, 0.92, 0.78, 1.0), clampf(dusk, 0.0, 1.0) * 0.22)
	world_modulate.color = c


func _update_valley_village_npc_sleep_visibility() -> void:
	var hide := day_brightness < GameConstants.VALLEY_NPC_HIDE_BELOW_BRIGHTNESS
	for c in entities.get_children():
		if not (c is Node2D):
			continue
		if not c.is_in_group("valley_village_npc"):
			continue
		if (c as Node).has_method("set_valley_npc_night_hidden"):
			(c as Node).call("set_valley_npc_night_hidden", hide)
		else:
			(c as Node2D).visible = not hide


func _user_save_exists() -> bool:
	return FileAccess.file_exists(USER_SAVE_PATH)


func _user_save_delete() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		dir.remove("wilderness_home_save.json")


func _user_save_write(data: Dictionary) -> Error:
	data["version"] = SAVE_FORMAT_VERSION
	var json := JSON.stringify(data)
	var f := FileAccess.open(USER_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(json)
	f.close()
	return OK


func _user_save_read() -> Dictionary:
	if not FileAccess.file_exists(USER_SAVE_PATH):
		return {}
	var f := FileAccess.open(USER_SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	if txt.is_empty():
		return {}
	var v: Variant = JSON.parse_string(txt)
	if v is Dictionary:
		return v as Dictionary
	return {}


func _user_save_is_supported(d: Dictionary) -> bool:
	var ver := int(d.get("version", 0))
	return ver >= 1 and ver <= SAVE_FORMAT_VERSION


func _notification(what: int) -> void:
	if not _game_boot_complete:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree():
			_autosave_if_ready()


func _autosave_if_ready() -> void:
	if not _game_boot_complete or not is_inside_tree():
		return
	var err: Error = _user_save_write(serialize_game_state())
	if err != OK:
		push_warning("Main: 自動存檔失敗：%s" % error_string(err))


func _on_auto_save_timeout() -> void:
	_autosave_if_ready()


func _setup_auto_save_timer() -> void:
	_auto_save_timer = Timer.new()
	_auto_save_timer.wait_time = 45.0
	_auto_save_timer.autostart = true
	_auto_save_timer.timeout.connect(_on_auto_save_timeout)
	add_child(_auto_save_timer)


func _setup_save_confirm_dialog() -> void:
	var ui := $CanvasLayer/UI as Control
	_reset_confirm = ConfirmationDialog.new()
	_reset_confirm.dialog_text = "確定要清除所有存檔資料並回到序章初始狀態？此動作無法復原。"
	_reset_confirm.confirmed.connect(_perform_progress_reset)
	ui.add_child(_reset_confirm)


func _close_styling_popup() -> void:
	var was_boot := _boot_styling_active
	if _styling_popup != null:
		_styling_popup.visible = false
	if was_boot:
		_end_boot_styling()


func _ensure_boot_styling_blocker() -> void:
	if _boot_styling_blocker != null:
		return
	var ui := $CanvasLayer/UI as Control
	var cr := ColorRect.new()
	cr.name = "BootStylingBlocker"
	cr.color = Color(0.04, 0.06, 0.09, 0.82)
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_STOP
	cr.visible = false
	## 低於造型視窗；並置於 UI 子節點最前（繪製在後），避免擋住點擊。
	cr.z_index = 10
	cr.z_as_relative = false
	ui.add_child(cr)
	ui.move_child(cr, 0)
	_boot_styling_blocker = cr


func _open_boot_styling_wizard() -> void:
	if _styling_popup == null:
		return
	_ensure_boot_styling_blocker()
	_boot_styling_active = true
	_boot_styling_blocker.visible = true
	_boot_saved_left_vitals_visible = left_vitals_panel.visible
	left_vitals_panel.visible = false
	if _mobile_touch_bar != null:
		_mobile_touch_bar.visible = false
	player1.process_mode = Node.PROCESS_MODE_DISABLED
	player2.process_mode = Node.PROCESS_MODE_DISABLED
	var ui := $CanvasLayer/UI as Control
	if _styling_popup.get_parent() == ui:
		ui.move_child(_styling_popup, -1)
	_styling_popup.z_as_relative = false
	_styling_popup.z_index = 100
	if _styling_title_label != null:
		_styling_title_label.text = "角色造型（Pixeline）\n選好外觀後按「套用」或按「關閉」以開始遊戲。"
	if _styling_hint_label != null:
		_styling_hint_label.text = "開局僅解鎖部分服飾；未解鎖可先預覽。與主表同格裁切；之後可從右上角「造型」再改。"
	settings_popup.visible = false
	hint_popup.visible = false
	quest_log_popup.visible = false
	_close_campfire_cook_popup()
	_close_workbench_craft_popup()
	_close_merchant_popup()
	_close_instructor_popup()
	_styling_popup.visible = true
	_styling_refresh_target_options()
	if not two_player:
		_styling_opt_target.select(0)
	var who := player1 if _styling_opt_target.selected == 0 else player2
	_styling_load_from_player(who)
	call_deferred("_boot_styling_ensure_popup_on_top")


func _boot_styling_ensure_popup_on_top() -> void:
	if not _boot_styling_active or _styling_popup == null:
		return
	var ui := $CanvasLayer/UI as Control
	if _styling_popup.get_parent() == ui:
		ui.move_child(_styling_popup, -1)
	if _boot_styling_blocker != null and _boot_styling_blocker.get_parent() == ui:
		ui.move_child(_boot_styling_blocker, 0)
	_styling_popup.z_as_relative = false
	_styling_popup.z_index = 100


func _end_boot_styling() -> void:
	if not _boot_styling_active:
		return
	_boot_styling_active = false
	if _boot_styling_blocker != null:
		_boot_styling_blocker.visible = false
	if _styling_popup != null:
		_styling_popup.z_index = 25
		_styling_popup.z_as_relative = true
	if _styling_title_label != null:
		_styling_title_label.text = "角色造型（Pixeline）"
	if _styling_hint_label != null:
		_styling_hint_label.text = "與主表同格裁切；無獨立左向圖時會自動鏡像。變更後請手動存檔以保留。"
	left_vitals_panel.visible = _boot_saved_left_vitals_visible
	_apply_mobile_touch_bar_visibility()
	player1.process_mode = Node.PROCESS_MODE_INHERIT
	if two_player:
		player2.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		player2.process_mode = Node.PROCESS_MODE_DISABLED


func _setup_styling_popup() -> void:
	var ui := $CanvasLayer/UI as Control
	_styling_popup = PanelContainer.new()
	_styling_popup.name = "StylingPopup"
	_styling_popup.visible = false
	_styling_popup.z_index = 25
	_styling_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var pan := StyleBoxFlat.new()
	pan.bg_color = Color(0.11, 0.15, 0.2, 0.95)
	pan.set_border_width_all(2)
	pan.border_color = Color(0.38, 0.55, 0.72, 1.0)
	pan.set_corner_radius_all(8)
	pan.content_margin_left = 12
	pan.content_margin_top = 10
	pan.content_margin_right = 12
	pan.content_margin_bottom = 10
	_styling_popup.add_theme_stylebox_override("panel", pan)
	_styling_popup.set_anchors_preset(Control.PRESET_CENTER)
	_styling_popup.offset_left = -280.0
	_styling_popup.offset_top = -340.0
	_styling_popup.offset_right = 280.0
	_styling_popup.offset_bottom = 340.0
	ui.add_child(_styling_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	_styling_popup.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	var title := Label.new()
	_styling_title_label = title
	title.text = "角色造型（Pixeline）"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	_styling_opt_target = OptionButton.new()
	_styling_opt_target.focus_mode = Control.FOCUS_NONE
	vbox.add_child(_styling_make_labeled_row("對象", _styling_opt_target))
	_styling_opt_gender = OptionButton.new()
	_styling_opt_gender.focus_mode = Control.FOCUS_NONE
	_styling_opt_gender.add_item("男")
	_styling_opt_gender.add_item("女")
	vbox.add_child(_styling_make_labeled_row("性別", _styling_opt_gender))
	_styling_opt_skin = OptionButton.new()
	_styling_opt_skin.focus_mode = Control.FOCUS_NONE
	vbox.add_child(_styling_make_labeled_row("膚色", _styling_opt_skin))
	_styling_opt_hair = OptionButton.new()
	_styling_opt_hair.focus_mode = Control.FOCUS_NONE
	vbox.add_child(_styling_make_labeled_row("髮型", _styling_opt_hair))
	_styling_opt_outfit = OptionButton.new()
	_styling_opt_outfit.focus_mode = Control.FOCUS_NONE
	vbox.add_child(_styling_make_labeled_row("上衣／外套", _styling_opt_outfit))
	_styling_opt_pants = OptionButton.new()
	_styling_opt_pants.focus_mode = Control.FOCUS_NONE
	vbox.add_child(_styling_make_labeled_row("下裝（褲／裙）", _styling_opt_pants))
	var hint := Label.new()
	_styling_hint_label = hint
	hint.text = "與主表同格裁切；無獨立左向圖時會自動鏡像。變更後請手動存檔以保留。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	vbox.add_child(hint)
	var pv_title := Label.new()
	pv_title.text = "預覽（朝下待機 · 放大）"
	pv_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(pv_title)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(300, 220)
	svc.stretch = true
	_styling_preview_vp = SubViewport.new()
	_styling_preview_vp.disable_3d = true
	_styling_preview_vp.transparent_bg = true
	_styling_preview_vp.size = Vector2i(140, 120)
	_styling_preview_vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	svc.add_child(_styling_preview_vp)
	vbox.add_child(svc)
	_styling_preview_root = Node2D.new()
	_styling_preview_root.position = Vector2(70, 102)
	_styling_preview_vp.add_child(_styling_preview_root)
	var pv_scale := Vector2(2.85, 2.85)
	for z in range(4):
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		spr.scale = pv_scale
		spr.z_index = z
		_styling_preview_root.add_child(spr)
		match z:
			0:
				_styling_pv_body = spr
			1:
				_styling_pv_pants = spr
			2:
				_styling_pv_chest = spr
			_:
				_styling_pv_hair = spr
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_styling_btn_apply = Button.new()
	_styling_btn_apply.text = "套用"
	_styling_btn_apply.focus_mode = Control.FOCUS_NONE
	row.add_child(_styling_btn_apply)
	_styling_btn_close = Button.new()
	_styling_btn_close.text = "關閉"
	_styling_btn_close.focus_mode = Control.FOCUS_NONE
	row.add_child(_styling_btn_close)
	vbox.add_child(row)
	_styling_opt_target.item_selected.connect(_styling_on_target_changed)
	_styling_opt_gender.item_selected.connect(_styling_on_gender_changed)
	_styling_opt_skin.item_selected.connect(_styling_queue_refresh_preview)
	_styling_opt_hair.item_selected.connect(_styling_queue_refresh_preview)
	_styling_opt_outfit.item_selected.connect(_styling_queue_refresh_preview)
	_styling_opt_pants.item_selected.connect(_styling_queue_refresh_preview)
	_styling_btn_apply.pressed.connect(_styling_on_apply_pressed)
	_styling_btn_close.pressed.connect(_close_styling_popup)
	_styling_fill_skin_options()


func _styling_make_labeled_row(label_text: String, ctrl: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var lb := Label.new()
	lb.text = label_text
	lb.custom_minimum_size = Vector2(92, 0)
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(lb)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctrl)
	return h


func _styling_fill_skin_options() -> void:
	_styling_opt_skin.clear()
	_styling_skin_keys.clear()
	for sk in PlayerStylingCatalog.skin_keys():
		_styling_opt_skin.add_item(PlayerStylingCatalog.skin_label_zh(sk))
		_styling_skin_keys.append(sk)


func _styling_init_unlock_defaults() -> void:
	_styling_unlock_set.clear()
	for p in PlayerStylingCatalog.starter_unlock_paths():
		_styling_unlock_set[p] = true


func _styling_merge_unlocks_array(raw: Variant) -> void:
	if raw is Array:
		for x in raw as Array:
			if x is String:
				var s: String = x
				if s.begins_with("res://"):
					_styling_unlock_set[s] = true


func _styling_unlock_migrate_worn_from_old_save(ps1: Variant, ps2: Variant) -> void:
	for v in [ps1, ps2]:
		if v is Dictionary:
			var d := v as Dictionary
			for k in ["hair", "outfit", "pants"]:
				var s := str(d.get(k, ""))
				if not s.is_empty() and s.begins_with("res://"):
					_styling_unlock_set[s] = true


func _styling_path_unlocked(path: String) -> bool:
	if path.is_empty():
		return true
	return _styling_unlock_set.has(path)


func _styling_serialize_unlock_paths() -> Array:
	var arr: Array = _styling_unlock_set.keys()
	arr.sort()
	return arr


## 之後服裝商人購買時呼叫：解鎖指定造型圖 res:// 路徑。
func unlock_styling_item(res_path: String) -> void:
	if res_path.is_empty() or not res_path.begins_with("res://"):
		return
	_styling_unlock_set[res_path] = true
	if _styling_popup != null and _styling_popup.visible:
		_styling_refill_hair_and_outfit()
		var who := player1 if _styling_opt_target.selected == 0 else player2
		_styling_load_from_player(who)


func _styling_refresh_target_options() -> void:
	if _styling_opt_target == null:
		return
	_styling_opt_target.clear()
	_styling_opt_target.add_item("玩家一（1P）")
	_styling_opt_target.add_item("玩家二（2P）")
	_styling_opt_target.set_item_disabled(1, not two_player)


func _styling_rows_unlocked_first(rows: Array[Dictionary]) -> Array[Dictionary]:
	if rows.size() <= 1:
		return rows.duplicate()
	var out: Array[Dictionary] = []
	out.append(rows[0])
	var unlocked: Array[Dictionary] = []
	var locked: Array[Dictionary] = []
	for i in range(1, rows.size()):
		var row := rows[i]
		var p := str(row.get("path", ""))
		if _styling_path_unlocked(p):
			unlocked.append(row)
		else:
			locked.append(row)
	unlocked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return PlayerStylingCatalog.display_label_zh(str(a.get("path", ""))).naturalnocasecmp_to(PlayerStylingCatalog.display_label_zh(str(b.get("path", "")))) < 0
	)
	locked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return PlayerStylingCatalog.display_label_zh(str(a.get("path", ""))).naturalnocasecmp_to(PlayerStylingCatalog.display_label_zh(str(b.get("path", "")))) < 0
	)
	out.append_array(unlocked)
	out.append_array(locked)
	return out


func _styling_refill_hair_and_outfit() -> void:
	var male := _styling_opt_gender.selected == 0
	_styling_opt_hair.clear()
	_styling_hair_paths.clear()
	for row in _styling_rows_unlocked_first(PlayerStylingCatalog.hair_rows(male)):
		var hp := str(row.get("path", ""))
		var lab := PlayerStylingCatalog.display_label_zh(hp)
		if not _styling_path_unlocked(hp):
			lab += " " + _STYLING_LOCK
		_styling_opt_hair.add_item(lab)
		_styling_hair_paths.append(hp)
	_styling_opt_hair.select(0)
	_styling_opt_outfit.clear()
	_styling_outfit_paths.clear()
	for row in _styling_rows_unlocked_first(PlayerStylingCatalog.outfit_rows(male)):
		var op := str(row.get("path", ""))
		var olab := PlayerStylingCatalog.display_label_zh(op)
		if not _styling_path_unlocked(op):
			olab += " " + _STYLING_LOCK
		_styling_opt_outfit.add_item(olab)
		_styling_outfit_paths.append(op)
	_styling_opt_outfit.select(0)
	_styling_opt_pants.clear()
	_styling_pants_paths.clear()
	for row in _styling_rows_unlocked_first(PlayerStylingCatalog.pants_rows(male)):
		var pp := str(row.get("path", ""))
		var plab := PlayerStylingCatalog.display_label_zh(pp)
		if not _styling_path_unlocked(pp):
			plab += " " + _STYLING_LOCK
		_styling_opt_pants.add_item(plab)
		_styling_pants_paths.append(pp)
	_styling_opt_pants.select(0)
	_styling_queue_refresh_preview()


func _styling_load_from_player(who: PlayerController) -> void:
	var d := who.get_pixeline_styling_save_dict()
	_styling_opt_gender.set_block_signals(true)
	_styling_opt_gender.select(0 if bool(d.get("gender_male", true)) else 1)
	_styling_opt_gender.set_block_signals(false)
	_styling_refill_hair_and_outfit()
	var sk := str(d.get("skin", "medium"))
	var si := _styling_skin_keys.find(sk)
	_styling_opt_skin.select(si if si >= 0 else 0)
	var hp := str(d.get("hair", ""))
	var hi := _styling_hair_paths.find(hp)
	_styling_opt_hair.select(hi if hi >= 0 else 0)
	var op := str(d.get("outfit", ""))
	var oi := _styling_outfit_paths.find(op)
	_styling_opt_outfit.select(oi if oi >= 0 else 0)
	var pp := str(d.get("pants", ""))
	var pi := _styling_pants_paths.find(pp)
	_styling_opt_pants.select(pi if pi >= 0 else 0)
	_styling_queue_refresh_preview()


func _styling_queue_refresh_preview(_i: int = 0) -> void:
	call_deferred("_styling_refresh_preview")


func _styling_preview_set_layer(spr: Sprite2D, path: String, r: Rect2) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		spr.visible = false
		return
	var t: Texture2D = load(path) as Texture2D
	if t == null:
		spr.visible = false
		return
	spr.texture = t
	spr.region_enabled = true
	spr.region_rect = r
	spr.flip_h = false
	spr.visible = true


func _styling_refresh_preview() -> void:
	if _styling_preview_vp == null or _styling_pv_body == null:
		return
	VisualRegistry.ensure_baked()
	var male := _styling_opt_gender.selected == 0
	var skin := _styling_skin_keys[_styling_opt_skin.selected] if _styling_skin_keys.size() > 0 else "medium"
	var body_path := PlayerStylingCatalog.base_body_path(male, skin)
	var r := VisualRegistry.pixeline_preview_idle_down_rect()
	if body_path.is_empty() or not ResourceLoader.exists(body_path):
		_styling_pv_body.visible = false
		_styling_pv_pants.visible = false
		_styling_pv_chest.visible = false
		_styling_pv_hair.visible = false
		return
	_styling_preview_set_layer(_styling_pv_body, body_path, r)
	var pants := _styling_pants_paths[_styling_opt_pants.selected] if _styling_pants_paths.size() > 0 else ""
	var chest := _styling_outfit_paths[_styling_opt_outfit.selected] if _styling_outfit_paths.size() > 0 else ""
	var hair := _styling_hair_paths[_styling_opt_hair.selected] if _styling_hair_paths.size() > 0 else ""
	_styling_preview_set_layer(_styling_pv_pants, pants, r)
	_styling_preview_set_layer(_styling_pv_chest, chest, r)
	_styling_preview_set_layer(_styling_pv_hair, hair, r)


func _styling_on_target_changed(_i: int) -> void:
	var who := player1 if _styling_opt_target.selected == 0 else player2
	_styling_load_from_player(who)


func _styling_on_gender_changed(_i: int) -> void:
	_styling_refill_hair_and_outfit()


func _styling_on_apply_pressed() -> void:
	var who := player1 if _styling_opt_target.selected == 0 else player2
	var skin := _styling_skin_keys[_styling_opt_skin.selected] if _styling_skin_keys.size() > 0 else "medium"
	var hair_p := _styling_hair_paths[_styling_opt_hair.selected] if _styling_hair_paths.size() > 0 else ""
	var out_p := _styling_outfit_paths[_styling_opt_outfit.selected] if _styling_outfit_paths.size() > 0 else ""
	var pants_p := _styling_pants_paths[_styling_opt_pants.selected] if _styling_pants_paths.size() > 0 else ""
	if not _styling_path_unlocked(hair_p) or not _styling_path_unlocked(out_p) or not _styling_path_unlocked(pants_p):
		_show_msg("選取含 " + _STYLING_LOCK + " 鎖定項目，預覽可查看；解鎖後才能套用。")
		return
	var ok := who.apply_pixeline_customization(
		_styling_opt_gender.selected == 0,
		skin,
		hair_p,
		out_p,
		pants_p
	)
	if ok:
		_show_msg("已套用造型。")
		if _boot_styling_active:
			_close_styling_popup()
	else:
		_show_msg("無法載入 Pixeline 主圖（請確認 assets/characters/pixeline）。")


func _toggle_styling_popup() -> void:
	if _styling_popup == null:
		return
	_styling_popup.visible = not _styling_popup.visible
	if _styling_popup.visible:
		settings_popup.visible = false
		hint_popup.visible = false
		quest_log_popup.visible = false
		_close_campfire_cook_popup()
		_close_workbench_craft_popup()
		_close_merchant_popup()
		_close_instructor_popup()
		_styling_refresh_target_options()
		if not two_player:
			_styling_opt_target.select(0)
		var who := player1 if _styling_opt_target.selected == 0 else player2
		_styling_load_from_player(who)
	else:
		if _boot_styling_active:
			_end_boot_styling()


func _toggle_settings_popup() -> void:
	settings_popup.visible = not settings_popup.visible
	if settings_popup.visible:
		if _settings_mobile_touch_check != null:
			_settings_mobile_touch_check.button_pressed = _mobile_touch_bar_user_enabled
		_close_styling_popup()
		hint_popup.visible = false
		quest_log_popup.visible = false
		_close_campfire_cook_popup()
		_close_workbench_craft_popup()
		_close_merchant_popup()
		_close_instructor_popup()


func _on_settings_close() -> void:
	settings_popup.visible = false


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_sfx_volume = clampf(cfg.get_value("audio", "sfx_volume", 1.0), 0.0, 1.0)
	_sfx_muted = cfg.get_value("audio", "sfx_muted", false)
	_bgm_volume = clampf(cfg.get_value("audio", "bgm_volume", 1.0), 0.0, 1.0)
	_bgm_muted = cfg.get_value("audio", "bgm_muted", false)
	_p1_name = cfg.get_value("players", "p1_name", "")
	_p2_name = cfg.get_value("players", "p2_name", "")
	if _mobile_touch_platform():
		_mobile_touch_bar_user_enabled = bool(cfg.get_value("ui", "touch_action_bar_enabled", true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_volume", _sfx_volume)
	cfg.set_value("audio", "sfx_muted", _sfx_muted)
	cfg.set_value("audio", "bgm_volume", _bgm_volume)
	cfg.set_value("audio", "bgm_muted", _bgm_muted)
	cfg.set_value("players", "p1_name", _p1_name)
	cfg.set_value("players", "p2_name", _p2_name)
	if _mobile_touch_platform():
		cfg.set_value("ui", "touch_action_bar_enabled", _mobile_touch_bar_user_enabled)
	cfg.save(SETTINGS_PATH)


func _apply_audio_settings() -> void:
	GameSfx.muted = _sfx_muted
	GameSfx.volume_scale = 0.0 if _sfx_muted else _sfx_volume
	if _bgm_player != null:
		_bgm_player.volume_db = -80.0 if _bgm_muted else lerp(-40.0, 0.0, _bgm_volume)


func _apply_player_names() -> void:
	if player1 != null:
		player1.set_player_name(_p1_name)
	if player2 != null:
		player2.set_player_name(_p2_name)


func _setup_settings_controls() -> void:
	var vbox := settings_btn_save.get_parent() as VBoxContainer
	var insert_idx := settings_btn_save.get_index()

	var _mk_sep := func() -> HSeparator:
		var s := HSeparator.new()
		s.add_theme_constant_override("separation", 4)
		return s

	var _mk_section_lbl := func(t: String) -> Label:
		var l := Label.new()
		l.text = t
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.55, 0.78, 1.0))
		return l

	# ── 音訊 ────────────────────────────────────────────────
	var audio_sep: HSeparator = _mk_sep.call()
	vbox.add_child(audio_sep)
	vbox.move_child(audio_sep, insert_idx)
	insert_idx += 1
	var audio_lbl: Label = _mk_section_lbl.call("音訊")
	vbox.add_child(audio_lbl)
	vbox.move_child(audio_lbl, insert_idx)
	insert_idx += 1

	var _mk_vol_row := func(label: String, init_on: bool, init_vol: float,
			on_toggle: Callable, on_vol: Callable) -> Array:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var chk := CheckButton.new()
		chk.text = label
		chk.button_pressed = init_on
		chk.focus_mode = Control.FOCUS_NONE
		chk.toggled.connect(on_toggle)
		chk.custom_minimum_size = Vector2(70, 0)
		row.add_child(chk)
		var sld := HSlider.new()
		sld.min_value = 0
		sld.max_value = 100
		sld.step = 1
		sld.value = init_vol * 100.0
		sld.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sld.focus_mode = Control.FOCUS_NONE
		sld.value_changed.connect(on_vol)
		row.add_child(sld)
		var val_lbl := Label.new()
		val_lbl.text = "%d" % int(init_vol * 100.0)
		val_lbl.custom_minimum_size = Vector2(28, 0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_font_size_override("font_size", 12)
		sld.value_changed.connect(func(v: float) -> void: val_lbl.text = "%d" % int(v))
		row.add_child(val_lbl)
		return [row, chk, sld]

	var sfx_res: Array = _mk_vol_row.call(
		"音效", not _sfx_muted, _sfx_volume,
		func(on: bool) -> void:
			_sfx_muted = not on
			_apply_audio_settings()
			_save_settings(),
		func(v: float) -> void:
			_sfx_volume = v / 100.0
			_apply_audio_settings()
			_save_settings()
	)
	_settings_sfx_check = sfx_res[1]
	_settings_sfx_slider = sfx_res[2]
	vbox.add_child(sfx_res[0])
	vbox.move_child(sfx_res[0], insert_idx)
	insert_idx += 1

	var bgm_res: Array = _mk_vol_row.call(
		"音樂", not _bgm_muted, _bgm_volume,
		func(on: bool) -> void:
			_bgm_muted = not on
			_apply_audio_settings()
			_save_settings(),
		func(v: float) -> void:
			_bgm_volume = v / 100.0
			_apply_audio_settings()
			_save_settings()
	)
	_settings_bgm_check = bgm_res[1]
	_settings_bgm_slider = bgm_res[2]
	vbox.add_child(bgm_res[0])
	vbox.move_child(bgm_res[0], insert_idx)
	insert_idx += 1

	if _mobile_touch_platform():
		var touch_sep: HSeparator = _mk_sep.call()
		vbox.add_child(touch_sep)
		vbox.move_child(touch_sep, insert_idx)
		insert_idx += 1
		var touch_lbl: Label = _mk_section_lbl.call("觸控（手機／網頁）")
		vbox.add_child(touch_lbl)
		vbox.move_child(touch_lbl, insert_idx)
		insert_idx += 1
		_settings_mobile_touch_check = CheckButton.new()
		_settings_mobile_touch_check.text = "顯示右下角快捷鍵列"
		_settings_mobile_touch_check.button_pressed = _mobile_touch_bar_user_enabled
		_settings_mobile_touch_check.focus_mode = Control.FOCUS_NONE
		_settings_mobile_touch_check.toggled.connect(func(on: bool) -> void:
			_mobile_touch_bar_user_enabled = on
			_apply_mobile_touch_bar_visibility()
			_layout_mobile_touch_bar()
			_save_settings()
		)
		vbox.add_child(_settings_mobile_touch_check)
		vbox.move_child(_settings_mobile_touch_check, insert_idx)
		insert_idx += 1
		var touch_hint := Label.new()
		touch_hint.text = "採集／互動／角色技／武器技；展開主功能表時列位置上移以免擋住。"
		touch_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		touch_hint.add_theme_font_size_override("font_size", 11)
		touch_hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
		vbox.add_child(touch_hint)
		vbox.move_child(touch_hint, insert_idx)
		insert_idx += 1

	# ── 雙人模式 ─────────────────────────────────────────────
	var two_p_sep: HSeparator = _mk_sep.call()
	vbox.add_child(two_p_sep)
	vbox.move_child(two_p_sep, insert_idx)
	insert_idx += 1
	var two_p_lbl: Label = _mk_section_lbl.call("遊戲模式")
	vbox.add_child(two_p_lbl)
	vbox.move_child(two_p_lbl, insert_idx)
	insert_idx += 1
	var two_p_row := HBoxContainer.new()
	two_p_row.add_theme_constant_override("separation", 8)
	_settings_two_player_check = CheckButton.new()
	_settings_two_player_check.text = "雙人模式"
	_settings_two_player_check.button_pressed = two_player
	_settings_two_player_check.focus_mode = Control.FOCUS_NONE
	_settings_two_player_check.toggled.connect(func(on: bool) -> void: _set_two_player(on))
	two_p_row.add_child(_settings_two_player_check)
	var two_p_hint := Label.new()
	two_p_hint.text = "開啟後 2P 出現，Tab 鍵快速切換展開 HUD"
	two_p_hint.add_theme_font_size_override("font_size", 11)
	two_p_hint.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
	two_p_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	two_p_row.add_child(two_p_hint)
	vbox.add_child(two_p_row)
	vbox.move_child(two_p_row, insert_idx)
	insert_idx += 1

	# ── 玩家名稱 ─────────────────────────────────────────────
	var name_sep: HSeparator = _mk_sep.call()
	vbox.add_child(name_sep)
	vbox.move_child(name_sep, insert_idx)
	insert_idx += 1
	var name_lbl: Label = _mk_section_lbl.call("玩家名稱（顯示於頭上）")
	vbox.add_child(name_lbl)
	vbox.move_child(name_lbl, insert_idx)
	insert_idx += 1

	var _mk_name_row := func(tag: String, init: String, placeholder: String,
			on_change: Callable) -> LineEdit:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var lbl := Label.new()
		lbl.text = tag
		lbl.custom_minimum_size = Vector2(24, 0)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
		row.add_child(lbl)
		var edit := LineEdit.new()
		edit.text = init
		edit.placeholder_text = placeholder
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.max_length = 12
		edit.text_changed.connect(on_change)
		row.add_child(edit)
		return edit

	_settings_p1_name = _mk_name_row.call(
		"1P", _p1_name, "玩家 1",
		func(t: String) -> void:
			_p1_name = t
			_apply_player_names()
			_save_settings()
	) as LineEdit
	var p1_row: Control = _settings_p1_name.get_parent()
	vbox.add_child(p1_row)
	vbox.move_child(p1_row, insert_idx)
	insert_idx += 1

	_settings_p2_name = _mk_name_row.call(
		"2P", _p2_name, "玩家 2",
		func(t: String) -> void:
			_p2_name = t
			_apply_player_names()
			_save_settings()
	) as LineEdit
	var p2_row: Control = _settings_p2_name.get_parent()
	vbox.add_child(p2_row)
	vbox.move_child(p2_row, insert_idx)
	insert_idx += 1

	var final_sep: HSeparator = _mk_sep.call()
	vbox.add_child(final_sep)
	vbox.move_child(final_sep, insert_idx)


func _setup_campfire_cook_popup() -> void:
	var ui := $CanvasLayer/UI as Control
	_campfire_cook_popup = PanelContainer.new()
	_campfire_cook_popup.name = "CampfireCookPopup"
	_campfire_cook_popup.visible = false
	_campfire_cook_popup.z_index = 22
	_campfire_cook_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var pan := StyleBoxFlat.new()
	pan.bg_color = Color(0.12, 0.14, 0.2, 0.98)
	pan.set_corner_radius_all(8)
	pan.content_margin_left = 14
	pan.content_margin_top = 12
	pan.content_margin_right = 14
	pan.content_margin_bottom = 12
	_campfire_cook_popup.add_theme_stylebox_override("panel", pan)
	_campfire_cook_popup.set_anchors_preset(Control.PRESET_CENTER)
	_campfire_cook_popup.offset_left = -220.0
	_campfire_cook_popup.offset_top = -210.0
	_campfire_cook_popup.offset_right = 220.0
	_campfire_cook_popup.offset_bottom = 210.0
	ui.add_child(_campfire_cook_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 2)
	_campfire_cook_popup.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "營火｜快速烹飪"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86, 1.0))
	vbox.add_child(title)
	var desc := Label.new()
	desc.text = "消耗莓果烘焙莓果干；肉排可烤成烤肉（效果較佳）。兩者皆可恢復飽足與生命。"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	vbox.add_child(desc)
	_btn_campfire_craft_jerky = Button.new()
	_btn_campfire_craft_jerky.focus_mode = Control.FOCUS_NONE
	_btn_campfire_craft_jerky.add_theme_font_size_override("font_size", 14)
	_btn_campfire_craft_jerky.pressed.connect(_on_campfire_craft_jerky_pressed)
	vbox.add_child(_btn_campfire_craft_jerky)
	_btn_campfire_eat_jerky = Button.new()
	_btn_campfire_eat_jerky.focus_mode = Control.FOCUS_NONE
	_btn_campfire_eat_jerky.add_theme_font_size_override("font_size", 14)
	_btn_campfire_eat_jerky.pressed.connect(_on_campfire_eat_jerky_pressed)
	vbox.add_child(_btn_campfire_eat_jerky)
	_btn_campfire_craft_bbq = Button.new()
	_btn_campfire_craft_bbq.focus_mode = Control.FOCUS_NONE
	_btn_campfire_craft_bbq.add_theme_font_size_override("font_size", 14)
	_btn_campfire_craft_bbq.pressed.connect(_on_campfire_craft_bbq_pressed)
	vbox.add_child(_btn_campfire_craft_bbq)
	_btn_campfire_eat_bbq = Button.new()
	_btn_campfire_eat_bbq.focus_mode = Control.FOCUS_NONE
	_btn_campfire_eat_bbq.add_theme_font_size_override("font_size", 14)
	_btn_campfire_eat_bbq.pressed.connect(_on_campfire_eat_bbq_pressed)
	vbox.add_child(_btn_campfire_eat_bbq)
	var btn_close := Button.new()
	btn_close.text = "關閉"
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.pressed.connect(_close_campfire_cook_popup)
	vbox.add_child(btn_close)
	_refresh_campfire_cook_popup()


func _refresh_campfire_cook_popup() -> void:
	if _btn_campfire_craft_jerky == null:
		return
	var cost := GameConstants.CAMPFIRE_COOK_BERRY_COST
	_btn_campfire_craft_jerky.text = "烘焙莓果干（需 %d 莓果）" % cost
	_btn_campfire_craft_jerky.disabled = not inv.can_craft_berry_jerky()
	var sj := int(roundf(GameConstants.JERKY_SATIETY_RESTORE))
	var hj := int(roundf(GameConstants.JERKY_HP_RESTORE))
	_btn_campfire_eat_jerky.text = "食用莓果干（+%d 飽足、+%d 生命）" % [sj, hj]
	_btn_campfire_eat_jerky.disabled = inv.berry_jerky < 1
	var mc := GameConstants.CAMPFIRE_COOK_MEAT_COST
	_btn_campfire_craft_bbq.text = "烤製烤肉（需 %d 肉排）" % mc
	_btn_campfire_craft_bbq.disabled = not inv.can_craft_bbq_meat()
	var sb := int(roundf(GameConstants.BBQ_MEAT_SATIETY_RESTORE))
	var hb := int(roundf(GameConstants.BBQ_MEAT_HP_RESTORE))
	_btn_campfire_eat_bbq.text = "食用烤肉（+%d 飽足、+%d 生命）" % [sb, hb]
	_btn_campfire_eat_bbq.disabled = inv.bbq_meat < 1


func _open_campfire_cook_popup() -> void:
	if _campfire_cook_popup == null:
		return
	GameSfx.play_interact(-3.0)
	_refresh_campfire_cook_popup()
	_campfire_cook_popup.visible = true


func _close_campfire_cook_popup() -> void:
	if _campfire_cook_popup == null:
		return
	_campfire_cook_popup.visible = false


func _setup_workbench_craft_popup() -> void:
	var ui := $CanvasLayer/UI as Control
	_workbench_craft_popup = PanelContainer.new()
	_workbench_craft_popup.name = "WorkbenchCraftPopup"
	_workbench_craft_popup.visible = false
	_workbench_craft_popup.z_index = 22
	_workbench_craft_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var pan := StyleBoxFlat.new()
	pan.bg_color = Color(0.10, 0.13, 0.17, 0.98)
	pan.set_corner_radius_all(10)
	pan.border_width_top = 1
	pan.border_color = Color(0.28, 0.36, 0.48, 0.7)
	pan.content_margin_left = 16
	pan.content_margin_top = 14
	pan.content_margin_right = 16
	pan.content_margin_bottom = 14
	_workbench_craft_popup.add_theme_stylebox_override("panel", pan)
	_workbench_craft_popup.set_anchors_preset(Control.PRESET_CENTER)
	_workbench_craft_popup.offset_left = -264.0
	_workbench_craft_popup.offset_top = -196.0
	_workbench_craft_popup.offset_right = 264.0
	_workbench_craft_popup.offset_bottom = 196.0
	ui.add_child(_workbench_craft_popup)

	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 12)
	_workbench_craft_popup.add_child(root_vb)

	# ── 標題列 ──────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 0)
	var title_lbl := Label.new()
	title_lbl.text = "🔨 工作台"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78, 1.0))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)
	var btn_x := Button.new()
	btn_x.text = "✕"
	btn_x.flat = true
	btn_x.focus_mode = Control.FOCUS_NONE
	btn_x.add_theme_font_size_override("font_size", 14)
	btn_x.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
	btn_x.pressed.connect(_close_workbench_craft_popup)
	title_row.add_child(btn_x)
	root_vb.add_child(title_row)

	# ── 2×2 卡片格 ──────────────────────────────────────────
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	root_vb.add_child(grid)

	var cards: Array[Array] = [
		[
			HudItemIcons.WOOD_SPEAR, "木製長槍", "遠距攻擊・技能掃地形",
			[[HudItemIcons.WOOD, GameConstants.CRAFT_SPEAR_WOOD],
			 [HudItemIcons.STONE, GameConstants.CRAFT_SPEAR_STONE]],
			Color(0.45, 0.82, 0.98),
		],
		[
			HudItemIcons.IRON_SWORD, "石製短劍", "近距快攻・技能投擲",
			[[HudItemIcons.WOOD, GameConstants.CRAFT_SWORD_WOOD],
			 [HudItemIcons.STONE, GameConstants.CRAFT_SWORD_STONE]],
			Color(0.98, 0.80, 0.35),
		],
		[
			HudItemIcons.STICKY_ARMOR, "黏黏護甲", "受傷減半的輕型護甲",
			[[HudItemIcons.LEATHER, GameConstants.CRAFT_STICKY_ARMOR_LEATHER],
			 [HudItemIcons.SLIME, GameConstants.CRAFT_STICKY_ARMOR_SLIME]],
			Color(0.62, 0.92, 0.58),
		],
		[
			HudItemIcons.DIRT, "土", "用於建造耕地",
			[[HudItemIcons.WOOD, GameConstants.CRAFT_DIRT_WOOD],
			 [HudItemIcons.SLIME, GameConstants.CRAFT_DIRT_SLIME]],
			Color(0.85, 0.68, 0.45),
		],
	]
	var cost_lbls: Array[Label] = []
	var craft_btns: Array[Button] = []

	for card_data in cards:
		var icon_path: String = card_data[0]
		var name_zh: String = card_data[1]
		var desc_zh: String = card_data[2]
		var costs: Array = card_data[3]
		var accent: Color = card_data[4]

		# 卡片底色
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.14, 0.18, 0.24, 1.0)
		card_style.set_corner_radius_all(7)
		card_style.border_width_left = 2
		card_style.border_color = accent.darkened(0.25)
		card_style.content_margin_left = 10
		card_style.content_margin_top = 10
		card_style.content_margin_right = 10
		card_style.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", card_style)
		grid.add_child(card)

		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 10)
		card.add_child(inner)

		# 圖示
		var icon_rect := TextureRect.new()
		icon_rect.texture = HudItemIcons.tex(icon_path)
		icon_rect.custom_minimum_size = Vector2(48, 48)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(icon_rect)

		var info_vb := VBoxContainer.new()
		info_vb.add_theme_constant_override("separation", 4)
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(info_vb)

		# 名稱
		var name_lbl := Label.new()
		name_lbl.text = name_zh
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", accent)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vb.add_child(name_lbl)

		# 描述
		var desc_lbl := Label.new()
		desc_lbl.text = desc_zh
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info_vb.add_child(desc_lbl)

		# 費用列
		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 6)
		cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cost_lbl := Label.new()
		var cost_parts: Array[String] = []
		for cost_pair in costs:
			cost_parts.append("×%d" % cost_pair[1])
		# 費用圖示 + 數字
		var cost_hb := HBoxContainer.new()
		cost_hb.add_theme_constant_override("separation", 3)
		cost_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for cost_pair in costs:
			var cico := TextureRect.new()
			cico.texture = HudItemIcons.tex(cost_pair[0])
			cico.custom_minimum_size = Vector2(14, 14)
			cico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cico.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost_hb.add_child(cico)
			var cnum := Label.new()
			cnum.text = "×%d  " % cost_pair[1]
			cnum.add_theme_font_size_override("font_size", 12)
			cnum.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
			cnum.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost_hb.add_child(cnum)
		cost_lbl = cost_hb.get_child(1) as Label
		cost_lbls.append(cost_lbl)
		info_vb.add_child(cost_hb)

		# 製作按鈕
		var craft_btn := Button.new()
		craft_btn.text = "製作"
		craft_btn.focus_mode = Control.FOCUS_NONE
		craft_btn.add_theme_font_size_override("font_size", 13)
		var btn_s := StyleBoxFlat.new()
		btn_s.bg_color = accent.darkened(0.45)
		btn_s.set_corner_radius_all(5)
		btn_s.content_margin_left = 10
		btn_s.content_margin_right = 10
		btn_s.content_margin_top = 5
		btn_s.content_margin_bottom = 5
		btn_s.border_width_bottom = 1
		btn_s.border_color = accent.darkened(0.2)
		var btn_h := btn_s.duplicate() as StyleBoxFlat
		btn_h.bg_color = accent.darkened(0.3)
		var btn_d := btn_s.duplicate() as StyleBoxFlat
		btn_d.bg_color = Color(0.18, 0.22, 0.28, 1.0)
		craft_btn.add_theme_stylebox_override("normal", btn_s)
		craft_btn.add_theme_stylebox_override("hover", btn_h)
		craft_btn.add_theme_stylebox_override("pressed", btn_d)
		craft_btn.add_theme_stylebox_override("disabled", btn_d)
		craft_btn.add_theme_color_override("font_color", Color.WHITE)
		craft_btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.48, 0.52))
		info_vb.add_child(craft_btn)
		craft_btns.append(craft_btn)

	_btn_workbench_craft_spear = craft_btns[0]
	_btn_workbench_craft_sword = craft_btns[1]
	_btn_workbench_craft_sticky_armor = craft_btns[2]
	_btn_workbench_craft_dirt = craft_btns[3]
	_lbl_wb_cost_spear = cost_lbls[0]
	_lbl_wb_cost_sword = cost_lbls[1]
	_lbl_wb_cost_armor = cost_lbls[2]
	_lbl_wb_cost_dirt = cost_lbls[3]

	_btn_workbench_craft_spear.pressed.connect(_on_workbench_craft_spear_pressed)
	_btn_workbench_craft_sword.pressed.connect(_on_workbench_craft_sword_pressed)
	_btn_workbench_craft_sticky_armor.pressed.connect(_on_workbench_craft_sticky_armor_pressed)
	_btn_workbench_craft_dirt.pressed.connect(_on_workbench_craft_dirt_pressed)
	_refresh_workbench_craft_popup()


func _refresh_workbench_craft_popup() -> void:
	if _btn_workbench_craft_spear == null:
		return
	var extras := _workbench_adjacent_storage_inventories(_workbench_popup_anchor)
	var pool: Array[GameInventory] = [inv]
	pool.append_array(extras)
	var can_spear := (
		GameInventory.count_in_pools(pool, &"wood") >= GameConstants.CRAFT_SPEAR_WOOD
		and GameInventory.count_in_pools(pool, &"stone") >= GameConstants.CRAFT_SPEAR_STONE
	)
	var can_sword := (
		GameInventory.count_in_pools(pool, &"wood") >= GameConstants.CRAFT_SWORD_WOOD
		and GameInventory.count_in_pools(pool, &"stone") >= GameConstants.CRAFT_SWORD_STONE
	)
	_btn_workbench_craft_spear.disabled = not can_spear
	_btn_workbench_craft_sword.disabled = not can_sword
	_btn_workbench_craft_sticky_armor.disabled = not inv.can_craft_sticky_armor(extras)
	if _btn_workbench_craft_dirt != null:
		_btn_workbench_craft_dirt.disabled = not inv.can_craft_dirt(extras)
	var dim := Color(0.42, 0.45, 0.5)
	var bright := Color(0.85, 0.88, 0.92)
	if _lbl_wb_cost_spear != null:
		_lbl_wb_cost_spear.add_theme_color_override("font_color", bright if can_spear else dim)
	if _lbl_wb_cost_sword != null:
		_lbl_wb_cost_sword.add_theme_color_override("font_color", bright if can_sword else dim)
	if _lbl_wb_cost_armor != null:
		_lbl_wb_cost_armor.add_theme_color_override(
			"font_color", bright if inv.can_craft_sticky_armor(extras) else dim
		)
	if _lbl_wb_cost_dirt != null:
		_lbl_wb_cost_dirt.add_theme_color_override(
			"font_color", bright if inv.can_craft_dirt(extras) else dim
		)


func _open_workbench_craft_popup(anchor: WorldBuildPiece = null) -> void:
	if _workbench_craft_popup == null:
		return
	if anchor != null and is_instance_valid(anchor) and anchor.piece_kind == WorldBuildPiece.PieceKind.WORKBENCH:
		_workbench_popup_anchor = anchor
	else:
		_workbench_popup_anchor = _nearest_workbench_piece_to_player1()
	GameSfx.play_interact(-3.0)
	_refresh_workbench_craft_popup()
	_workbench_craft_popup.visible = true


func _close_workbench_craft_popup() -> void:
	if _workbench_craft_popup == null:
		return
	_workbench_craft_popup.visible = false
	_workbench_popup_anchor = null


func _close_merchant_popup() -> void:
	if _merchant_popup == null:
		return
	_merchant_popup.visible = false


func _close_instructor_popup() -> void:
	if _instructor_popup == null:
		return
	_instructor_popup.visible = false


func _merchant_types_to_string_array() -> Array:
	var arr: Array = []
	for ty in _merchant_buy_types:
		arr.append(String(ty))
	return arr


func _apply_merchant_from_save_dict(md: Dictionary) -> void:
	_merchant_offer_doy = int(md.get("offer_doy", -1))
	_merchant_buy_types.clear()
	var raw_t: Variant = md.get("types", [])
	if raw_t is Array:
		for el in raw_t as Array:
			_merchant_buy_types.append(StringName(str(el)))
	_merchant_premium_index = 0
	if _merchant_buy_types.size() > 0:
		_merchant_premium_index = clampi(
			int(md.get("premium_i", 0)), 0, _merchant_buy_types.size() - 1
		)
	_merchant_sold_today.clear()
	var sd: Variant = md.get("sold", {})
	if sd is Dictionary:
		for k in sd as Dictionary:
			_merchant_sold_today[str(k)] = int((sd as Dictionary)[k])


func _merchant_ensure_offers_for_calendar() -> void:
	if _merchant_offer_doy != game_calendar_doy or _merchant_buy_types.is_empty():
		_merchant_roll_new_offers()


func _merchant_roll_new_offers() -> void:
	var n_slots := mini(
		5, 3 + merchant_trade_total / GameConstants.MERCHANT_EXTRA_TYPE_EVERY_N_TRADES
	)
	n_slots = maxi(3, n_slots)
	var pool := _MERCHANT_RESOURCE_POOL.duplicate()
	pool.shuffle()
	_merchant_buy_types.clear()
	for j in n_slots:
		if j < pool.size():
			_merchant_buy_types.append(pool[j])
	_merchant_premium_index = 0
	if _merchant_buy_types.size() > 0:
		_merchant_premium_index = randi() % _merchant_buy_types.size()
	_merchant_sold_today.clear()
	for ty in _merchant_buy_types:
		_merchant_sold_today[str(ty)] = 0
	_merchant_offer_doy = game_calendar_doy


func _merchant_type_label(ty: StringName) -> String:
	match ty:
		&"wood":
			return "木頭"
		&"stone":
			return "石頭"
		&"berries":
			return "莓果"
		&"berry_jerky":
			return "莓果干"
		&"seed":
			return "樹種"
		&"slime_goo":
			return "黏液"
		&"leather":
			return "皮革"
		&"meat_cutlet":
			return "肉排"
		&"bbq_meat":
			return "烤肉"
		&"dirt":
			return "土"
		&"turnip":
			return "蕪菁"
		_:
			return str(ty)


func _merchant_base_unit_price(ty: StringName) -> int:
	match ty:
		&"wood":
			return 2
		&"stone":
			return 2
		&"berries":
			return 3
		&"berry_jerky":
			return 5
		&"seed":
			return 4
		&"slime_goo":
			return 4
		&"leather":
			return 7
		&"meat_cutlet":
			return 5
		&"bbq_meat":
			return 8
		&"dirt":
			return 3
		&"turnip":
			return 9
		_:
			return 2


func _merchant_unit_sell_price(ty: StringName) -> int:
	var p := _merchant_base_unit_price(ty)
	var i := _merchant_buy_types.find(ty)
	if i == _merchant_premium_index:
		p = int(roundf(float(p) * GameConstants.MERCHANT_PREMIUM_PRICE_MULT))
	return maxi(1, p)


func _inv_resource_count(ty: StringName) -> int:
	match ty:
		&"wood":
			return inv.wood
		&"stone":
			return inv.stone
		&"berries":
			return inv.berries
		&"berry_jerky":
			return inv.berry_jerky
		&"seed":
			return inv.seed
		&"slime_goo":
			return inv.slime_goo
		&"leather":
			return inv.leather
		&"meat_cutlet":
			return inv.meat_cutlet
		&"bbq_meat":
			return inv.bbq_meat
		&"dirt":
			return inv.dirt
		&"turnip":
			return inv.turnip
		_:
			return 0


func _inv_take_resource(ty: StringName, qty: int) -> void:
	if qty <= 0:
		return
	inv.try_remove_item(ty, qty)


func _merchant_remaining_quota(ty: StringName) -> int:
	var k := str(ty)
	var sold := int(_merchant_sold_today.get(k, 0))
	return maxi(0, GameConstants.MERCHANT_DAILY_BUY_CAP_PER_TYPE - sold)


func _on_merchant_sell_pressed(ty: StringName) -> void:
	var have := _inv_resource_count(ty)
	var cap := _merchant_remaining_quota(ty)
	var qty := mini(have, cap)
	if qty <= 0:
		_show_msg("沒有可賣的份量或今日配額已滿。")
		return
	var unit := _merchant_unit_sell_price(ty)
	money += qty * unit
	_inv_take_resource(ty, qty)
	var k := str(ty)
	_merchant_sold_today[k] = int(_merchant_sold_today.get(k, 0)) + qty
	merchant_trade_total += 1
	GameSfx.play_pickup()
	_update_inv_bar()
	_refresh_merchant_popup()
	_show_msg("賣出 %s×%d，獲得 %d 金。" % [_merchant_type_label(ty), qty, qty * unit])


func _on_merchant_buy_seed_pressed() -> void:
	var price := GameConstants.MERCHANT_TURNIP_SEED_PRICE
	if money < price:
		_show_msg("金錢不足（需 %d）。" % price)
		return
	money -= price
	if inv.try_add_item(&"turnip_seeds", 1) > 0:
		money += price
		_show_msg("背包已滿，無法購入種子。")
		_refresh_merchant_popup()
		return
	GameSfx.play_pickup()
	_update_inv_bar()
	_refresh_merchant_popup()
	_show_msg("購入蕪菁種子×1。")


func _refresh_merchant_popup() -> void:
	if _merchant_lbl_offers == null or _merchant_sells_vbox == null:
		return
	var lines: PackedStringArray = []
	lines.append("今日收購種類：%d（隨累計賣出次數最高至 5 種）。" % _merchant_buy_types.size())
	lines.append("每種每日最多收 %d 份；標★為高價品。" % GameConstants.MERCHANT_DAILY_BUY_CAP_PER_TYPE)
	for j in _merchant_buy_types.size():
		var ty := _merchant_buy_types[j]
		var tag := "★" if j == _merchant_premium_index else ""
		var unit := _merchant_unit_sell_price(ty)
		var rem := _merchant_remaining_quota(ty)
		var hv := _inv_resource_count(ty)
		lines.append(
			(
				"%s%s：單價 %d／個｜身上 %d｜今日尚可賣 %d"
				% [tag, _merchant_type_label(ty), unit, hv, rem]
			)
		)
	_merchant_lbl_offers.text = "\n".join(lines)
	if _merchant_btn_seed != null:
		_merchant_btn_seed.text = "購買蕪菁種子（%d 金／份）｜持有金：%d" % [
			GameConstants.MERCHANT_TURNIP_SEED_PRICE,
			money,
		]
		_merchant_btn_seed.disabled = money < GameConstants.MERCHANT_TURNIP_SEED_PRICE
	for c in _merchant_sells_vbox.get_children():
		c.queue_free()
	for ty in _merchant_buy_types:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		var rem2 := _merchant_remaining_quota(ty)
		var hv2 := _inv_resource_count(ty)
		b.text = "賣出「%s」（可一次賣出至今日上限）" % _merchant_type_label(ty)
		b.disabled = rem2 <= 0 or hv2 <= 0
		var ty_c := ty
		b.pressed.connect(func() -> void: _on_merchant_sell_pressed(ty_c))
		_merchant_sells_vbox.add_child(b)


func _setup_merchant_popup() -> void:
	var ui := $CanvasLayer/UI as Control
	_merchant_popup = PanelContainer.new()
	_merchant_popup.name = "MerchantPopup"
	_merchant_popup.visible = false
	_merchant_popup.z_index = 23
	_merchant_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var pan := StyleBoxFlat.new()
	pan.bg_color = Color(0.14, 0.12, 0.18, 0.98)
	pan.set_corner_radius_all(8)
	pan.content_margin_left = 14
	pan.content_margin_top = 12
	pan.content_margin_right = 14
	pan.content_margin_bottom = 12
	_merchant_popup.add_theme_stylebox_override("panel", pan)
	_merchant_popup.set_anchors_preset(Control.PRESET_CENTER)
	_merchant_popup.offset_left = -260.0
	_merchant_popup.offset_top = -240.0
	_merchant_popup.offset_right = 260.0
	_merchant_popup.offset_bottom = 240.0
	ui.add_child(_merchant_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 2)
	_merchant_popup.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "商人｜收購與種子"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86, 1.0))
	vbox.add_child(title)
	_merchant_lbl_offers = Label.new()
	_merchant_lbl_offers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_merchant_lbl_offers.add_theme_font_size_override("font_size", 12)
	_merchant_lbl_offers.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	vbox.add_child(_merchant_lbl_offers)
	_merchant_btn_seed = Button.new()
	_merchant_btn_seed.focus_mode = Control.FOCUS_NONE
	_merchant_btn_seed.add_theme_font_size_override("font_size", 14)
	_merchant_btn_seed.pressed.connect(_on_merchant_buy_seed_pressed)
	vbox.add_child(_merchant_btn_seed)
	var sell_title := Label.new()
	sell_title.text = "賣出資源（不收購水）"
	sell_title.add_theme_font_size_override("font_size", 13)
	sell_title.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7, 1.0))
	vbox.add_child(sell_title)
	_merchant_sells_vbox = VBoxContainer.new()
	_merchant_sells_vbox.add_theme_constant_override("separation", 6)
	vbox.add_child(_merchant_sells_vbox)
	var btn_close := Button.new()
	btn_close.text = "關閉"
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.pressed.connect(_close_merchant_popup)
	vbox.add_child(btn_close)
	_refresh_merchant_popup()


func _open_merchant_popup() -> void:
	if _merchant_popup == null:
		return
	_merchant_ensure_offers_for_calendar()
	GameSfx.play_interact(-3.0)
	_refresh_merchant_popup()
	_close_instructor_popup()
	_merchant_popup.visible = true


func _populate_instructor_skill_options(opt: OptionButton, for_p1: bool) -> void:
	opt.clear()
	var cur := _p1_character_skill if for_p1 else _p2_character_skill
	opt.add_item("短衝刺")
	var ids: Array[StringName] = [&"dash"]
	if _skill_unlock_charge:
		opt.add_item("蓄力")
		ids.append(&"charge")
	if _skill_unlock_iron_wall:
		opt.add_item("鐵壁")
		ids.append(&"iron_wall")
	var pick := 0
	for i in ids.size():
		if ids[i] == cur:
			pick = i
			break
	_instructor_syncing_options = true
	opt.select(pick)
	_instructor_syncing_options = false


func _on_instructor_p1_skill_selected(idx: int) -> void:
	if _instructor_syncing_options:
		return
	var ids: Array[StringName] = [&"dash"]
	if _skill_unlock_charge:
		ids.append(&"charge")
	if _skill_unlock_iron_wall:
		ids.append(&"iron_wall")
	if idx < 0 or idx >= ids.size():
		return
	_p1_character_skill = ids[idx]
	_refresh_hotbar_ui()
	_user_save_write(serialize_game_state())


func _on_instructor_p2_skill_selected(idx: int) -> void:
	if _instructor_syncing_options:
		return
	var ids: Array[StringName] = [&"dash"]
	if _skill_unlock_charge:
		ids.append(&"charge")
	if _skill_unlock_iron_wall:
		ids.append(&"iron_wall")
	if idx < 0 or idx >= ids.size():
		return
	_p2_character_skill = ids[idx]
	_refresh_hotbar_ui()
	_user_save_write(serialize_game_state())


func _refresh_instructor_popup() -> void:
	if _instructor_lbl_money == null:
		return
	_instructor_lbl_money.text = "持有金：%d" % money
	if _btn_instructor_buy_charge != null:
		_btn_instructor_buy_charge.text = (
			"購買《蓄力要訣》（%d 金）%s"
			% [
				GameConstants.INSTRUCTOR_BOOK_CHARGE_PRICE,
				"（已解鎖）" if _skill_unlock_charge else "",
			]
		)
		_btn_instructor_buy_charge.disabled = (
			_skill_unlock_charge or money < GameConstants.INSTRUCTOR_BOOK_CHARGE_PRICE
		)
	if _btn_instructor_buy_iron != null:
		_btn_instructor_buy_iron.text = (
			"購買《鐵壁心得》（%d 金）%s"
			% [
				GameConstants.INSTRUCTOR_BOOK_IRON_WALL_PRICE,
				"（已解鎖）" if _skill_unlock_iron_wall else "",
			]
		)
		_btn_instructor_buy_iron.disabled = (
			_skill_unlock_iron_wall or money < GameConstants.INSTRUCTOR_BOOK_IRON_WALL_PRICE
		)
	if _instructor_opt_p1 != null:
		_populate_instructor_skill_options(_instructor_opt_p1, true)
	if _instructor_opt_p2 != null:
		_instructor_lbl_p2.visible = two_player
		_instructor_opt_p2.visible = two_player
		if two_player:
			_populate_instructor_skill_options(_instructor_opt_p2, false)


func _on_instructor_buy_charge_pressed() -> void:
	if _skill_unlock_charge:
		return
	var p := GameConstants.INSTRUCTOR_BOOK_CHARGE_PRICE
	if money < p:
		_show_msg("金錢不足。")
		return
	money -= p
	_skill_unlock_charge = true
	GameSfx.play_pickup()
	_refresh_instructor_popup()
	_show_msg("已習得蓄力！可在上方選單設為角色技能。")


func _on_instructor_buy_iron_pressed() -> void:
	if _skill_unlock_iron_wall:
		return
	var p := GameConstants.INSTRUCTOR_BOOK_IRON_WALL_PRICE
	if money < p:
		_show_msg("金錢不足。")
		return
	money -= p
	_skill_unlock_iron_wall = true
	GameSfx.play_pickup()
	_refresh_instructor_popup()
	_show_msg("已習得鐵壁！")


func _setup_instructor_popup() -> void:
	var ui := $CanvasLayer/UI as Control
	_instructor_popup = PanelContainer.new()
	_instructor_popup.name = "InstructorPopup"
	_instructor_popup.visible = false
	_instructor_popup.z_index = 23
	_instructor_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var pan := StyleBoxFlat.new()
	pan.bg_color = Color(0.12, 0.16, 0.2, 0.98)
	pan.set_corner_radius_all(8)
	pan.content_margin_left = 14
	pan.content_margin_top = 12
	pan.content_margin_right = 14
	pan.content_margin_bottom = 12
	_instructor_popup.add_theme_stylebox_override("panel", pan)
	_instructor_popup.set_anchors_preset(Control.PRESET_CENTER)
	_instructor_popup.offset_left = -268.0
	_instructor_popup.offset_top = -248.0
	_instructor_popup.offset_right = 268.0
	_instructor_popup.offset_bottom = 248.0
	ui.add_child(_instructor_popup)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 2)
	_instructor_popup.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "教官｜技能書與裝備"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.94, 0.92, 0.86, 1.0))
	vbox.add_child(title)
	var desc := Label.new()
	desc.text = "購買技能書後永久解鎖；在此選擇要裝備的角色技能（取代快捷列旁的短衝刺說明與按鍵效果）。"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	vbox.add_child(desc)
	_instructor_lbl_money = Label.new()
	_instructor_lbl_money.add_theme_font_size_override("font_size", 13)
	_instructor_lbl_money.add_theme_color_override("font_color", Color(0.88, 0.86, 0.55, 1.0))
	vbox.add_child(_instructor_lbl_money)
	_btn_instructor_buy_charge = Button.new()
	_btn_instructor_buy_charge.focus_mode = Control.FOCUS_NONE
	_btn_instructor_buy_charge.add_theme_font_size_override("font_size", 14)
	_btn_instructor_buy_charge.pressed.connect(_on_instructor_buy_charge_pressed)
	vbox.add_child(_btn_instructor_buy_charge)
	_btn_instructor_buy_iron = Button.new()
	_btn_instructor_buy_iron.focus_mode = Control.FOCUS_NONE
	_btn_instructor_buy_iron.add_theme_font_size_override("font_size", 14)
	_btn_instructor_buy_iron.pressed.connect(_on_instructor_buy_iron_pressed)
	vbox.add_child(_btn_instructor_buy_iron)
	var lbl1 := Label.new()
	lbl1.text = "1P 角色技能"
	lbl1.add_theme_font_size_override("font_size", 13)
	vbox.add_child(lbl1)
	_instructor_opt_p1 = OptionButton.new()
	_instructor_opt_p1.focus_mode = Control.FOCUS_NONE
	_instructor_opt_p1.item_selected.connect(_on_instructor_p1_skill_selected)
	vbox.add_child(_instructor_opt_p1)
	_instructor_lbl_p2 = Label.new()
	_instructor_lbl_p2.text = "2P 角色技能"
	_instructor_lbl_p2.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_instructor_lbl_p2)
	_instructor_opt_p2 = OptionButton.new()
	_instructor_opt_p2.focus_mode = Control.FOCUS_NONE
	_instructor_opt_p2.item_selected.connect(_on_instructor_p2_skill_selected)
	vbox.add_child(_instructor_opt_p2)
	var btn_close := Button.new()
	btn_close.text = "關閉"
	btn_close.focus_mode = Control.FOCUS_NONE
	btn_close.pressed.connect(_close_instructor_popup)
	vbox.add_child(btn_close)
	_refresh_instructor_popup()


func _open_instructor_popup() -> void:
	if _instructor_popup == null:
		return
	GameSfx.play_interact(-3.0)
	_refresh_instructor_popup()
	_close_merchant_popup()
	_instructor_popup.visible = true


func _skill_clamp_equipped_after_load() -> void:
	if _p1_character_skill == &"charge" and not _skill_unlock_charge:
		_p1_character_skill = &"dash"
	if _p1_character_skill == &"iron_wall" and not _skill_unlock_iron_wall:
		_p1_character_skill = &"dash"
	if _p2_character_skill == &"charge" and not _skill_unlock_charge:
		_p2_character_skill = &"dash"
	if _p2_character_skill == &"iron_wall" and not _skill_unlock_iron_wall:
		_p2_character_skill = &"dash"


func apply_enemy_contact_damage(raw_amount: float, damaged_player_slot: int) -> void:
	var m := 1.0
	if damaged_player_slot == 0 and _p1_iron_wall_timer > 0.001:
		m *= 0.5
	elif damaged_player_slot == 1 and _p2_iron_wall_timer > 0.001:
		m *= 0.5
	vitals_hp = maxf(0.0, vitals_hp - raw_amount * m)
	_update_vitals_bars_ui()


func _weapon_skill_damage_multiplier(player_idx: int) -> int:
	if player_idx == 0:
		if _p1_next_weapon_skill_double:
			_p1_next_weapon_skill_double = false
			return 2
	else:
		if _p2_next_weapon_skill_double:
			_p2_next_weapon_skill_double = false
			return 2
	return 1


func _on_workbench_craft_spear_pressed() -> void:
	var extras := _workbench_adjacent_storage_inventories(_workbench_popup_anchor)
	if inv.try_craft_wood_spear_at_bench(extras):
		GameSfx.play_craft()
		_update_inv_bar()
		_refresh_workbench_craft_popup()
		var ws_p1 := inv.equip_main == &"wood_spear"
		var ws_p2 := inv.equip_main_p2 == &"wood_spear"
		var ws_msg := " 已放入背包備用。"
		if ws_p1 and not ws_p2:
			ws_msg = " 已裝在 1P 主手。"
		elif ws_p2:
			ws_msg = " 已裝在 2P 主手。"
		_show_msg("製作了木製長槍！" + ws_msg)
	else:
		_show_msg("木材或石頭不足。")


func _on_workbench_craft_sword_pressed() -> void:
	var extras := _workbench_adjacent_storage_inventories(_workbench_popup_anchor)
	if inv.try_craft_iron_sword_at_bench(extras):
		GameSfx.play_craft()
		_update_inv_bar()
		_refresh_workbench_craft_popup()
		var sw_p1 := inv.equip_main == &"iron_sword"
		var sw_p2 := inv.equip_main_p2 == &"iron_sword"
		var sw_msg := " 已放入背包備用。"
		if sw_p1 and not sw_p2:
			sw_msg = " 已裝在 1P 主手。"
		elif sw_p2:
			sw_msg = " 已裝在 2P 主手。"
		_show_msg("製作了石製短劍！" + sw_msg)
	else:
		_show_msg("木材或石頭不足。")


func _on_workbench_craft_sticky_armor_pressed() -> void:
	var extras := _workbench_adjacent_storage_inventories(_workbench_popup_anchor)
	if inv.try_craft_sticky_armor_at_bench(extras):
		GameSfx.play_craft()
		_update_inv_bar()
		_refresh_workbench_craft_popup()
		_show_msg(
			"製作了黏黏護甲！"
			+ (" 已穿在身上。" if inv.armor_equipped == &"sticky_armor" else " 已放入背包備用。")
		)
	else:
		_show_msg("皮革或黏液不足（各需 %d）。" % GameConstants.CRAFT_STICKY_ARMOR_LEATHER)


func _on_workbench_craft_dirt_pressed() -> void:
	var extras := _workbench_adjacent_storage_inventories(_workbench_popup_anchor)
	if inv.try_craft_dirt_at_bench(extras):
		GameSfx.play_craft()
		_update_inv_bar()
		_refresh_workbench_craft_popup()
		_show_msg("已製作土。")
	else:
		_show_msg("木材或黏液不足。")


func _on_campfire_craft_jerky_pressed() -> void:
	if inv.try_craft_berry_jerky():
		GameSfx.play_cook()
		_update_inv_bar()
		_refresh_campfire_cook_popup()
		_show_msg("烤好了莓果干！")
	else:
		_show_msg("莓果不足（需 %d 個）。" % GameConstants.CAMPFIRE_COOK_BERRY_COST)


func _on_campfire_eat_jerky_pressed() -> void:
	if _try_eat_jerky_quick():
		_refresh_campfire_cook_popup()
	else:
		_refresh_campfire_cook_popup()


func _on_campfire_craft_bbq_pressed() -> void:
	if inv.try_craft_bbq_meat_at_campfire():
		GameSfx.play_cook()
		_update_inv_bar()
		_refresh_campfire_cook_popup()
		_show_msg("烤好了烤肉！")
	else:
		_show_msg("肉排不足（需 %d 份）。" % GameConstants.CAMPFIRE_COOK_MEAT_COST)


func _on_campfire_eat_bbq_pressed() -> void:
	if _try_eat_bbq_meat_quick():
		_refresh_campfire_cook_popup()
	else:
		_refresh_campfire_cook_popup()


func _try_eat_jerky_quick() -> bool:
	if not inv.try_consume_berry_jerky():
		_show_msg("沒有可食用的莓果干。")
		return false
	GameSfx.play_eat()
	vitals_satiety = clampf(
		vitals_satiety + GameConstants.JERKY_SATIETY_RESTORE, 0.0, vitals_satiety_max
	)
	vitals_hp = clampf(vitals_hp + GameConstants.JERKY_HP_RESTORE, 0.0, vitals_hp_max)
	_update_inv_bar()
	_update_vitals_bars_ui()
	_show_msg("已食用莓果干，飽足與生命恢復了。")
	return true


func _try_eat_bbq_meat_quick() -> bool:
	if not inv.try_consume_bbq_meat():
		_show_msg("沒有可食用的烤肉。")
		return false
	GameSfx.play_eat()
	vitals_satiety = clampf(
		vitals_satiety + GameConstants.BBQ_MEAT_SATIETY_RESTORE, 0.0, vitals_satiety_max
	)
	vitals_hp = clampf(vitals_hp + GameConstants.BBQ_MEAT_HP_RESTORE, 0.0, vitals_hp_max)
	_update_inv_bar()
	_update_vitals_bars_ui()
	_show_msg("已食用烤肉，飽足與生命明顯恢復。")
	return true


func _try_eat_meat_cutlet_quick() -> bool:
	if not inv.try_consume_meat_cutlet():
		_show_msg("沒有肉排。")
		return false
	GameSfx.play_eat()
	vitals_satiety = clampf(
		vitals_satiety + GameConstants.RAW_MEAT_SATIETY, 0.0, vitals_satiety_max
	)
	vitals_hp = clampf(vitals_hp + GameConstants.RAW_MEAT_HP, 0.0, vitals_hp_max)
	_update_inv_bar()
	_update_vitals_bars_ui()
	_show_msg("吃了生肉排，止餓了一些。")
	return true


func _try_eat_raw_berry() -> void:
	if not inv.try_consume_one_berry():
		_show_msg("沒有莓果。")
		return
	GameSfx.play_eat(-6.0)
	vitals_satiety = clampf(
		vitals_satiety + GameConstants.RAW_BERRY_SATIETY, 0.0, vitals_satiety_max
	)
	_update_inv_bar()
	_update_vitals_bars_ui()
	_show_msg("吃了莓果，稍微止餓。")


func _parse_character_skill_id(raw: Variant) -> StringName:
	var s := StringName(str(raw))
	if s == &"dash" or s == &"charge" or s == &"iron_wall":
		return s
	return &"dash"


func _satiety_drain_from_action(amount: float) -> void:
	if amount <= 0.0:
		return
	vitals_satiety = maxf(0.0, vitals_satiety - amount)
	_update_vitals_bars_ui()


func _try_use_character_skill(player_slot: int) -> void:
	var who := player1 if player_slot == 0 else player2
	var sk := _p1_character_skill if player_slot == 0 else _p2_character_skill
	if who.process_mode == Node.PROCESS_MODE_DISABLED or not who.visible:
		return
	match sk:
		&"dash":
			var dc := GameConstants.SATIETY_COST_CHAR_DASH
			if vitals_satiety < dc - 0.001:
				_show_msg("飽足不足，無法衝刺。")
				return
			if who.try_begin_dash():
				_satiety_drain_from_action(dc)
				GameSfx.play_skill_whoosh(1.28, -9.0)
		&"charge":
			if not _skill_unlock_charge:
				return
			if who.character_dash_cooldown_remaining() > 0.001:
				_show_msg("角色技能冷卻中。")
				return
			var chc := GameConstants.SATIETY_COST_CHAR_CHARGE
			if vitals_satiety < chc - 0.001:
				_show_msg("飽足不足，無法蓄力。")
				return
			who.begin_character_skill_cooldown()
			_satiety_drain_from_action(chc)
			if player_slot == 0:
				_p1_next_weapon_skill_double = true
			else:
				_p2_next_weapon_skill_double = true
			GameSfx.play_skill_whoosh(1.05, -8.0)
			_show_msg("蓄力：下次武器技能傷害加倍。")
		&"iron_wall":
			if not _skill_unlock_iron_wall:
				return
			if who.character_dash_cooldown_remaining() > 0.001:
				_show_msg("角色技能冷卻中。")
				return
			var iwc := GameConstants.SATIETY_COST_CHAR_IRON_WALL
			if vitals_satiety < iwc - 0.001:
				_show_msg("飽足不足，無法施展鐵壁。")
				return
			who.begin_character_skill_cooldown()
			_satiety_drain_from_action(iwc)
			if player_slot == 0:
				_p1_iron_wall_timer = GameConstants.CHARACTER_IRON_WALL_DURATION_SEC
			else:
				_p2_iron_wall_timer = GameConstants.CHARACTER_IRON_WALL_DURATION_SEC
			GameSfx.play_skill_whoosh(0.88, -7.0)
			_show_msg("鐵壁：%.0f 秒內受傷減半。" % GameConstants.CHARACTER_IRON_WALL_DURATION_SEC)
		_:
			pass


func _try_use_hotbar_slot(idx: int) -> void:
	if idx < 0 or idx >= _hotbar_items.size():
		return
	var id: StringName = _hotbar_items[idx]
	match id:
		&"axe":
			if inv.try_equip_axe_from_inventory():
				_show_msg("已裝備石斧（1P）。")
				_update_inv_bar()
				_update_quest_ui()
			elif two_player and inv.try_equip_axe_from_inventory_for(1):
				_show_msg("已裝備石斧（2P）。")
				_update_inv_bar()
				_update_quest_ui()
			else:
				_show_msg("沒有可裝備的石斧。")
		&"wood_spear":
			if inv.try_equip_spear_from_inventory():
				_show_msg("已裝備木製長槍（1P）。")
				_update_inv_bar()
			elif two_player and inv.try_equip_spear_from_inventory_for(1):
				_show_msg("已裝備木製長槍（2P）。")
				_update_inv_bar()
			else:
				_show_msg("沒有可裝備的木製長槍。")
		&"iron_sword":
			if inv.try_equip_sword_from_inventory():
				_show_msg("已裝備石製短劍（1P）。")
				_update_inv_bar()
			elif two_player and inv.try_equip_sword_from_inventory_for(1):
				_show_msg("已裝備石製短劍（2P）。")
				_update_inv_bar()
			else:
				_show_msg("沒有可裝備的石製短劍。")
		&"berries":
			_try_eat_raw_berry()
		&"jerky":
			_try_eat_jerky_quick()
		&"meat_cutlet":
			_try_eat_meat_cutlet_quick()
		&"bbq_meat":
			_try_eat_bbq_meat_quick()
		&"water":
			_try_use_water_on_farmland(player1)
		_:
			pass


func _ensure_hotbar_items_size() -> void:
	while _hotbar_items.size() < 9:
		_hotbar_items.append(&"")


func _setup_hotbar() -> void:
	_ensure_hotbar_items_size()
	var hb := HotbarController.new()
	hb.name = "HotbarRow"
	var ui := $CanvasLayer/UI as Control
	ui.add_child(hb)
	_hotbar_ctrl = hb
	hb.assign_chosen.connect(_on_hotbar_assign_chosen)
	_sync_hotbar_visibility()
	_relayout_hotbar()
	_refresh_hotbar_ui()


func _on_hotbar_assign_chosen(slot: int, item_id: StringName) -> void:
	if slot < 0 or slot >= _hotbar_items.size():
		return
	_hotbar_items[slot] = item_id
	_refresh_hotbar_ui()


func _ensure_backpack_ctx_menu() -> void:
	if _backpack_ctx_menu != null:
		return
	var ui := $CanvasLayer/UI as Control
	var m := PopupMenu.new()
	m.name = "BackpackSlotContextMenu"
	m.id_pressed.connect(_on_backpack_ctx_menu_id)
	ui.add_child(m)
	_backpack_ctx_menu = m


func _ensure_chest_take_dialog() -> void:
	if _chest_take_dialog != null:
		return
	var ui := $CanvasLayer/UI as Control
	var dlg := AcceptDialog.new()
	dlg.name = "ChestTakeAmountDialog"
	dlg.title = "從箱子取出"
	dlg.ok_button_text = "取出"
	dlg.min_size = Vector2i(320, 168)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_chest_take_hint = Label.new()
	_chest_take_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(_chest_take_hint)
	var spin := SpinBox.new()
	spin.min_value = 1.0
	spin.max_value = 1.0
	spin.step = 1.0
	spin.rounded = true
	spin.alignment = HORIZONTAL_ALIGNMENT_LEFT
	spin.custom_minimum_size = Vector2(120, 0)
	_chest_take_spin = spin
	vb.add_child(spin)
	dlg.add_child(vb)
	dlg.confirmed.connect(_on_chest_take_confirmed)
	dlg.canceled.connect(_on_chest_take_canceled)
	ui.add_child(dlg)
	_chest_take_dialog = dlg


func _on_chest_take_canceled() -> void:
	_chest_take_slot_idx = -1


func _on_chest_take_confirmed() -> void:
	var slot := _chest_take_slot_idx
	_chest_take_slot_idx = -1
	if slot < 0 or _chest_take_spin == null:
		return
	if _bottom_hud == null or not _bottom_hud.is_chest_panel_open():
		return
	var want := int(_chest_take_spin.value)
	if want <= 0:
		return
	_take_from_open_chest_slot_to_backpack(slot, want)


func _open_chest_take_amount_dialog(slot_idx: int) -> void:
	_ensure_chest_take_dialog()
	if _bottom_hud == null or not _bottom_hud.is_chest_panel_open():
		return
	var cst := _bottom_hud.get_open_chest_inventory()
	if cst == null:
		return
	var snap := cst.get_slot_snapshot(slot_idx)
	if snap.is_empty():
		return
	var q := int(snap.get("q", 0))
	if q <= 1:
		return
	var idv: Variant = snap.get("id", &"")
	var sid: StringName = idv as StringName if idv is StringName else StringName(str(idv))
	var nm := HudItemIcons.stackable_display_name_zh(sid)
	_chest_take_slot_idx = slot_idx
	if _chest_take_hint != null:
		_chest_take_hint.text = "%s · 箱內共 %d 個" % [nm, q]
	if _chest_take_spin != null:
		_chest_take_spin.max_value = float(q)
		_chest_take_spin.min_value = 1.0
		_chest_take_spin.value = float(q)
	if _chest_take_dialog != null:
		_chest_take_dialog.popup_centered()


func _take_from_open_chest_slot_to_backpack(slot_idx: int, amount: int) -> void:
	if _bottom_hud == null or not _bottom_hud.is_chest_panel_open():
		return
	var cst := _bottom_hud.get_open_chest_inventory()
	if cst == null or amount <= 0:
		return
	var snap := cst.get_slot_snapshot(slot_idx)
	if snap.is_empty():
		return
	var idv: Variant = snap.get("id", &"")
	var sid: StringName = idv as StringName if idv is StringName else StringName(str(idv))
	var q := int(snap.get("q", 0))
	if sid == &"" or q <= 0:
		return
	var take := mini(amount, q)
	if take <= 0:
		return
	var removed: int = cst.remove_quantity_from_slot(slot_idx, take)
	if removed <= 0:
		return
	var overflow := inv.try_add_item(sid, removed)
	if overflow > 0:
		var back: int = cst.try_add_item(sid, overflow)
		if back > 0:
			var re_ov := inv.try_add_item(sid, back)
			if re_ov > 0:
				push_error("Main: chest withdraw lost stack id=%s n=%d" % [str(sid), re_ov])
	var placed := removed - overflow
	var nm := HudItemIcons.stackable_display_name_zh(sid)
	if overflow == 0:
		_show_msg("已將 %d 個%s 取回背包。" % [placed, nm])
	elif placed <= 0:
		_show_msg("背包已滿，無法取回%s。" % nm)
	else:
		_show_msg("背包空間不足，僅取回 %d 個%s（%d 個留在箱子）。" % [placed, nm, overflow])
	_update_inv_bar()
	_autosave_if_ready()


func _on_chest_slot_withdraw_requested(slot_idx: int, _screen_pos: Vector2) -> void:
	if _bottom_hud == null or not _bottom_hud.is_chest_panel_open():
		return
	var cst := _bottom_hud.get_open_chest_inventory()
	if cst == null:
		return
	var snap := cst.get_slot_snapshot(slot_idx)
	if snap.is_empty():
		return
	var q := int(snap.get("q", 0))
	if q <= 1:
		_take_from_open_chest_slot_to_backpack(slot_idx, 1)
	else:
		_open_chest_take_amount_dialog(slot_idx)


func _inv_stack_id_to_hotbar_item_id(stack_id: StringName) -> StringName:
	match stack_id:
		&"axe_spare":
			return &"axe"
		&"spear_spare":
			return &"wood_spear"
		&"sword_spare":
			return &"iron_sword"
		&"berries":
			return &"berries"
		&"berry_jerky":
			return &"jerky"
		&"meat_cutlet":
			return &"meat_cutlet"
		&"bbq_meat":
			return &"bbq_meat"
		&"water":
			return &"water"
		_:
			return &""


func _on_backpack_slot_context_requested(slot_idx: int, screen_pos: Vector2) -> void:
	_ensure_backpack_ctx_menu()
	var snap := inv.get_slot_snapshot(slot_idx)
	if snap.is_empty():
		_show_msg("此格為空。")
		return
	var sid: StringName = StringName(str(snap.get("id", &"")))
	_backpack_ctx_slot = slot_idx
	var m := _backpack_ctx_menu
	m.clear()
	if sid == &"axe_spare":
		m.add_item("裝備石斧（1P）", 100)
		if two_player:
			m.add_item("裝備石斧（2P）", 101)
	elif sid == &"spear_spare":
		m.add_item("裝備木製長槍（1P）", 110)
		if two_player:
			m.add_item("裝備木製長槍（2P）", 111)
	elif sid == &"sword_spare":
		m.add_item("裝備石製短劍（1P）", 120)
		if two_player:
			m.add_item("裝備石製短劍（2P）", 121)
	elif sid == &"sticky_armor_spare":
		m.add_item("穿上黏黏護甲", 130)
	_ctx_hotbar_map_id = _inv_stack_id_to_hotbar_item_id(sid)
	if _ctx_hotbar_map_id != &"":
		if m.item_count > 0:
			m.add_separator()
		for hi in 9:
			m.add_item("設為快捷鍵 %d" % (hi + 1), 300 + hi)
	if m.item_count == 0:
		_show_msg("此格道具無法裝備或設快捷鍵。")
		_backpack_ctx_slot = -1
		return
	m.popup(Rect2(screen_pos, Vector2.ZERO))


func _try_transfer_backpack_slot_to_chest(slot_idx: int) -> bool:
	if _bottom_hud == null or not _bottom_hud.is_chest_panel_open():
		return false
	var cst := _bottom_hud.get_open_chest_inventory()
	if cst == null:
		return false
	var snap := inv.get_slot_snapshot(slot_idx)
	if snap.is_empty():
		return false
	var idv: Variant = snap.get("id", &"")
	var sid: StringName = idv as StringName if idv is StringName else StringName(str(idv))
	var q := int(snap.get("q", 0))
	if sid == &"" or q <= 0:
		return false
	for ti in cst.slot_count:
		var tsp := cst.get_slot_snapshot(ti)
		if tsp.is_empty():
			continue
		var tidv: Variant = tsp.get("id", &"")
		var tid: StringName = tidv as StringName if tidv is StringName else StringName(str(tidv))
		if tid == sid:
			var tq := int(tsp.get("q", 0))
			if tq < cst.stack_limit:
				if GameInventory.apply_slot_transfer_between(inv, slot_idx, cst, ti):
					return true
	for ti in cst.slot_count:
		var tsp2 := cst.get_slot_snapshot(ti)
		if tsp2.is_empty():
			if GameInventory.apply_slot_transfer_between(inv, slot_idx, cst, ti):
				return true
	return false


func _chest_has_non_empty_slot_with_id(cst: GameInventory, sid: StringName) -> bool:
	for ti in cst.slot_count:
		var tsp := cst.get_slot_snapshot(ti)
		if tsp.is_empty():
			continue
		var tidv: Variant = tsp.get("id", &"")
		var tid: StringName = tidv as StringName if tidv is StringName else StringName(str(tidv))
		if tid == sid:
			return true
	return false


## 一鍵入箱：僅處理「目前開啟的箱子裡至少已有一格同 id」的物品；可併未滿疊，或移入箱內空格（不引入箱內從未出現過的種類）。
func _try_transfer_backpack_slot_to_chest_quick_stash(slot_idx: int) -> bool:
	if _bottom_hud == null or not _bottom_hud.is_chest_panel_open():
		return false
	var cst := _bottom_hud.get_open_chest_inventory()
	if cst == null:
		return false
	var snap := inv.get_slot_snapshot(slot_idx)
	if snap.is_empty():
		return false
	var idv: Variant = snap.get("id", &"")
	var sid: StringName = idv as StringName if idv is StringName else StringName(str(idv))
	var q := int(snap.get("q", 0))
	if sid == &"" or q <= 0:
		return false
	if not _chest_has_non_empty_slot_with_id(cst, sid):
		return false
	return _try_transfer_backpack_slot_to_chest(slot_idx)


func _on_backpack_quick_send_to_chest(slot_idx: int) -> void:
	if _try_transfer_backpack_slot_to_chest(slot_idx):
		_show_msg("已放入箱子。")
		_update_inv_bar()
		_autosave_if_ready()
	else:
		_show_msg("無法放入箱子（沒有空格或同物品已滿疊）。")


func _try_stash_all_backpack_to_open_chest() -> bool:
	if _bottom_hud == null or not _bottom_hud.is_chest_panel_open():
		return false
	if _bottom_hud.get_open_chest_inventory() == null:
		return false
	var any := false
	var safety := 0
	while safety < 300:
		safety += 1
		var progressed := false
		for i in inv.slot_count:
			if _try_transfer_backpack_slot_to_chest_quick_stash(i):
				progressed = true
				any = true
		if not progressed:
			break
	return any


func _on_chest_quick_stash_requested() -> void:
	if _try_stash_all_backpack_to_open_chest():
		_show_msg("已將背包中可集中的物品放入箱子（僅箱內已有種類）。")
		_update_inv_bar()
		_autosave_if_ready()
	else:
		_show_msg("沒有可放入的物品（箱子須已有該種類，且須有未滿疊或空格）。")


func _on_backpack_ctx_menu_id(id: int) -> void:
	var slot := _backpack_ctx_slot
	_backpack_ctx_slot = -1
	if slot < 0:
		return
	var snap := inv.get_slot_snapshot(slot)
	if snap.is_empty():
		return
	var sid: StringName = StringName(str(snap.get("id", &"")))
	if id >= 300 and id < 309:
		var hi := id - 300
		var hb := _ctx_hotbar_map_id
		if hb != &"" and hi >= 0 and hi < _hotbar_items.size():
			_hotbar_items[hi] = hb
			_show_msg("已設到快捷鍵 %d。" % (hi + 1))
			_refresh_hotbar_ui()
		return
	match id:
		100:
			if sid == &"axe_spare":
				_on_hud_equip_axe()
		101:
			if sid == &"axe_spare":
				_on_hud_equip_axe_p2()
		110:
			if sid == &"spear_spare":
				_on_hud_equip_spear()
		111:
			if sid == &"spear_spare":
				_on_hud_equip_spear_p2()
		120:
			if sid == &"sword_spare":
				_on_hud_equip_sword()
		121:
			if sid == &"sword_spare":
				_on_hud_equip_sword_p2()
		130:
			if sid == &"sticky_armor_spare":
				_on_hud_equip_sticky_armor()
		_:
			pass
	_refresh_hotbar_ui()


func _sync_hotbar_visibility() -> void:
	if _hotbar_ctrl == null or _bottom_hud == null:
		return
	## 底部大面板展開時隱藏快捷列，避免蓋住背包／建造；收合成一條時再顯示。
	_hotbar_ctrl.visible = _bottom_hud.is_hud_minimized()


func _relayout_hotbar() -> void:
	if _hotbar_ctrl == null:
		return
	_hotbar_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hotbar_ctrl.anchor_left = 0.0
	_hotbar_ctrl.anchor_right = 1.0
	_hotbar_ctrl.anchor_top = 1.0
	_hotbar_ctrl.anchor_bottom = 1.0
	_hotbar_ctrl.z_index = 6
	if _bottom_hud != null and _bottom_hud.is_hud_minimized():
		# 收合：貼底；右側預留給「展開」鈕（約 160px 寬 + 邊距），避免快捷列與技能說明與按鈕重疊。
		const HOTBAR_RIGHT_RESERVE := 172.0
		_hotbar_ctrl.offset_left = 8.0
		_hotbar_ctrl.offset_right = -HOTBAR_RIGHT_RESERVE
		_hotbar_ctrl.offset_top = -108.0
		_hotbar_ctrl.offset_bottom = -44.0
	else:
		# 展開：緊貼 inv_bar 上方
		var h := 70.0
		var gap := 4.0
		_hotbar_ctrl.offset_left = 72.0
		_hotbar_ctrl.offset_right = -72.0
		_hotbar_ctrl.offset_top = -300.0 - gap - h
		_hotbar_ctrl.offset_bottom = -300.0 - gap


func _refresh_hotbar_ui() -> void:
	if _hotbar_ctrl == null:
		return
	_hotbar_ctrl.refresh(
		_hotbar_items,
		inv,
		_p1_weapon_skill_cd,
		two_player,
		_p2_weapon_skill_cd,
		player1.character_dash_cooldown_remaining(),
		player2.character_dash_cooldown_remaining(),
		_p1_character_skill,
		_p2_character_skill,
		_p1_next_weapon_skill_double,
		_p2_next_weapon_skill_double,
		_p1_iron_wall_timer,
		_p2_iron_wall_timer
	)


func _hotbar_to_save_array() -> Array:
	var arr: Array = []
	for s: StringName in _hotbar_items:
		arr.append(String(s))
	return arr


func _apply_hotbar_from_save(raw: Variant) -> void:
	_hotbar_items.clear()
	_ensure_hotbar_items_size()
	if raw is Array:
		var a := raw as Array
		for i in mini(9, a.size()):
			var hid := StringName(str(a[i]))
			if hid == &"stone_sword":
				hid = &"iron_sword"
			_hotbar_items[i] = hid
	if _hotbar_ctrl != null:
		_refresh_hotbar_ui()


func _workbench_under_world_click(world: Vector2) -> WorldBuildPiece:
	var pick := GameConstants.WORKBENCH_CLICK_RADIUS
	var best: WorldBuildPiece = null
	var best_d := pick + 1.0
	for c in entities.get_children():
		if not (c is WorldBuildPiece):
			continue
		var wp := c as WorldBuildPiece
		if wp.piece_kind != WorldBuildPiece.PieceKind.WORKBENCH:
			continue
		var d := world.distance_to(wp.global_position)
		if d <= pick and d < best_d:
			best_d = d
			best = wp
	return best


func _can_open_workbench_at_click(world_click: Vector2, who: PlayerController) -> bool:
	var wb := _workbench_under_world_click(world_click)
	if wb == null:
		return false
	return who.global_position.distance_to(wb.global_position) < GameConstants.INTERACT_REACH


## 左鍵點營火或工作台（同一格附近重疊時，以游標距離較近者為準）。
func _try_open_interactive_station_from_world_click(world_click: Vector2, who: PlayerController) -> bool:
	if _campfire_cook_popup != null and _campfire_cook_popup.visible:
		return false
	if _workbench_craft_popup != null and _workbench_craft_popup.visible:
		return false
	if _merchant_popup != null and _merchant_popup.visible:
		return false
	if _instructor_popup != null and _instructor_popup.visible:
		return false
	var can_cf := _can_open_campfire_cook_at_click(world_click, who)
	var can_wb := _can_open_workbench_at_click(world_click, who)
	if not can_cf and not can_wb:
		return false
	if can_cf and not can_wb:
		_open_campfire_cook_popup()
		return true
	if can_wb and not can_cf:
		_open_workbench_craft_popup(_workbench_under_world_click(world_click))
		return true
	var cf_n := _campfire_under_world_click(world_click)
	var wb_n := _workbench_under_world_click(world_click)
	if cf_n == null:
		_open_workbench_craft_popup(wb_n)
		return true
	if wb_n == null:
		_open_campfire_cook_popup()
		return true
	var d_cf := world_click.distance_to(cf_n.global_position)
	var d_wb := world_click.distance_to(wb_n.global_position)
	if d_cf <= d_wb:
		_open_campfire_cook_popup()
	else:
		_open_workbench_craft_popup(wb_n)
	return true


func _campfire_under_world_click(world: Vector2) -> Node2D:
	var pick := GameConstants.CAMPFIRE_COOK_CLICK_RADIUS
	var best: Node2D = null
	var best_d := pick + 1.0
	for c in entities.get_children():
		if not (c is Node2D):
			continue
		if not c.is_in_group("campfire"):
			continue
		var n2 := c as Node2D
		var d := world.distance_to(n2.global_position)
		if d <= pick and d < best_d:
			best_d = d
			best = n2
	return best


func _can_open_campfire_cook_at_click(world_click: Vector2, who: PlayerController) -> bool:
	var cf := _campfire_under_world_click(world_click)
	if cf == null:
		return false
	return who.global_position.distance_to(cf.global_position) < GameConstants.INTERACT_REACH


func _on_settings_manual_save() -> void:
	var err: Error = _user_save_write(serialize_game_state())
	if err == OK:
		_show_msg("已手動存檔。")
	else:
		_show_msg("存檔失敗：%s" % error_string(err))


func _on_settings_reset_pressed() -> void:
	_reset_confirm.popup_centered()


func _perform_progress_reset() -> void:
	settings_popup.visible = false
	quest_log_popup.visible = false
	_close_styling_popup()
	_close_campfire_cook_popup()
	_close_workbench_craft_popup()
	_close_merchant_popup()
	_close_instructor_popup()
	_user_save_delete()
	reset_game_to_initial_state()
	_show_msg("進度已初始化，已開始新遊戲。")
	call_deferred("_open_boot_styling_wizard")


func serialize_game_state() -> Dictionary:
	_persist_entities_for_region(world_region)
	var bk := int(_build_kind)
	return {
		"version": SAVE_FORMAT_VERSION,
		"inv": inv.to_save_dict(),
		"money": money,
		"quest_phase": quest_phase,
		"two_player": two_player,
		"build_kind": bk,
		"vitals": {
			"hp": vitals_hp,
			"hp_max": vitals_hp_max,
			"satiety": vitals_satiety,
			"satiety_max": vitals_satiety_max,
		},
		"cycle_phase": _cycle_phase,
		"p1_pos": [player1.global_position.x, player1.global_position.y],
		"p2_pos": [player2.global_position.x, player2.global_position.y],
		"cam_pos": [camera.global_position.x, camera.global_position.y],
		"entities_by_region": _region_entity_store.duplicate(true),
		"hotbar": _hotbar_to_save_array(),
		"p1_character_skill": String(_p1_character_skill),
		"p2_character_skill": String(_p2_character_skill),
		"merchant_trade_total": merchant_trade_total,
		"skill_unlock_charge": _skill_unlock_charge,
		"skill_unlock_iron_wall": _skill_unlock_iron_wall,
		"merchant": {
			"offer_doy": _merchant_offer_doy,
			"types": _merchant_types_to_string_array(),
			"premium_i": _merchant_premium_index,
			"sold": _merchant_sold_today.duplicate(),
		},
		"calendar_doy": game_calendar_doy,
		"world_region": [world_region.x, world_region.y],
		"region_wild_init": _region_wild_init.duplicate(true),
		"mob_respawn_last_doy": _mob_respawn_last_calendar_doy,
		"forest_mob_bank": {"s": _forest_mob_bank_slimes, "b": _forest_mob_bank_boars},
		"p1_style": player1.get_pixeline_styling_save_dict(),
		"p2_style": player2.get_pixeline_styling_save_dict(),
		"styling_unlocks": _styling_serialize_unlock_paths(),
	}


func _serialize_entity_node(c: Node) -> Dictionary:
	if c is WorldPropStatic:
		var p := c as WorldPropStatic
		return {"t": "prop", "k": int(p.prop_kind), "x": p.global_position.x, "y": p.global_position.y, "hp": p.hit_points}
	if c is LoosePickup:
		var lp := c as LoosePickup
		return {"t": "loose", "k": int(lp.pick_kind), "x": lp.global_position.x, "y": lp.global_position.y}
	if c is WorldBuildPiece:
		var w := c as WorldBuildPiece
		var pd := {
			"t": "piece",
			"k": int(w.piece_kind),
			"x": w.global_position.x,
			"y": w.global_position.y,
			"door": w.door_open,
		}
		if WorldBuildPiece.piece_kind_has_storage_inventory(w.piece_kind) and w.chest_storage != null:
			pd["storage"] = w.chest_storage.storage_serialize()
		return pd
	if c is Node2D and c.is_in_group("berry_bush"):
		var ripe: bool = bool((c as Node2D).call("get_save_ripe"))
		var dep_ph: float = float((c as Node2D).call("get_save_depleted_phase"))
		return {"t": "berry_bush", "x": c.global_position.x, "y": c.global_position.y, "ripe": ripe, "dep": dep_ph}
	if c is Node2D and c.is_in_group("sapling"):
		var ph: float = 0.0
		if (c as Node2D).has_method("get_save_phase"):
			ph = float((c as Node2D).call("get_save_phase"))
		return {"t": "sapling", "x": c.global_position.x, "y": c.global_position.y, "p": ph}
	if c is Node2D and c.is_in_group("farmland"):
		var fn := c as Node2D
		return {
			"t": "farmland",
			"x": fn.global_position.x,
			"y": fn.global_position.y,
			"w": bool(fn.call("get_save_watered")),
			"cs": int(fn.call("get_save_crop_stage")),
			"pd": int(fn.call("get_save_planted_doy")),
			"ck": String(fn.call("get_save_crop_kind")),
		}
	if c is Node2D and c.is_in_group("campfire"):
		var cf := c as Node2D
		return {"t": "campfire", "x": cf.global_position.x, "y": cf.global_position.y}
	if c is ForestSlime:
		var sl := c as ForestSlime
		return {"t": "forest_slime", "x": sl.global_position.x, "y": sl.global_position.y, "hp": sl.hit_points}
	if c is ForestMushroom:
		var mu := c as ForestMushroom
		return {"t": "forest_mushroom", "x": mu.global_position.x, "y": mu.global_position.y, "hp": mu.hit_points}
	if c is Node2D and c.is_in_group("valley_village_npc"):
		var vn := c as Node2D
		var d: Dictionary = {
			"t": "valley_npc",
			"x": vn.global_position.x,
			"y": vn.global_position.y,
			"slot": int(vn.get("rm_sheet_slot")),
			"nm": str(vn.get("npc_display_name")),
			"nn": String(vn.name),
		}
		var ps: Variant = vn.get("pixeline_styling")
		if ps is Dictionary and (ps as Dictionary).size() > 0:
			d["pstyle"] = (ps as Dictionary).duplicate(true)
		return d
	return {}


func _try_load_save_on_startup() -> bool:
	if not _user_save_exists():
		return false
	var d: Dictionary = _user_save_read()
	if not _user_save_is_supported(d):
		push_warning("Main: 存檔版本不符或損毀，將重新開局。")
		return false
	apply_game_state(d)
	return true


func apply_game_state(d: Dictionary) -> void:
	_close_campfire_cook_popup()
	_close_workbench_craft_popup()
	_close_merchant_popup()
	_close_instructor_popup()
	_loading_save = true
	var loaded_save_ver := int(d.get("version", 0))
	_apply_saved_world_region(d.get("world_region", null))
	_region_entity_store.clear()
	_region_wild_init.clear()
	var ebr: Variant = d.get("entities_by_region", null)
	if ebr is Dictionary and (ebr as Dictionary).size() > 0:
		for k in (ebr as Dictionary):
			var arr: Variant = (ebr as Dictionary)[k]
			if arr is Array:
				_region_entity_store[str(k)] = (arr as Array).duplicate()
	else:
		var el: Variant = d.get("entities", [])
		if el is Array and (el as Array).size() > 0:
			_region_entity_store[_region_store_key(world_region)] = (el as Array).duplicate()
	var rwi: Variant = d.get("region_wild_init", null)
	if rwi is Dictionary:
		for kw in rwi as Dictionary:
			_region_wild_init[str(kw)] = bool((rwi as Dictionary)[kw])
	if loaded_save_ver >= SAVE_REGION_WILD_LAYOUT_VERSION and _region_wild_init.is_empty() and _region_entity_store.size() > 0:
		for rk in _region_entity_store.keys():
			_region_wild_init[str(rk)] = true
	_clear_spawned_entities()
	money = int(d.get("money", 0))
	var raw_quest_ph := int(d.get("quest_phase", 1))
	quest_phase = raw_quest_ph
	if loaded_save_ver < 21 and quest_phase == 4:
		## v20：phase 4＝探索；v21：phase 4＝工作台、phase 5＝探索。
		quest_phase = 5
	if loaded_save_ver < 20 and raw_quest_ph >= 3:
		## 更舊：phase 3＝序章已結束；新版最末為探索 phase 5。
		quest_phase = 5
	var bk_raw := int(d.get("build_kind", int(BuildKind.NONE)))
	if bk_raw < 0 or bk_raw > int(BuildKind.CHEST):
		bk_raw = int(BuildKind.NONE)
	_build_kind = bk_raw as BuildKind
	_build_use_continuous = false
	_build_lmb_armed = false
	_build_lmb_down_ms = -1
	inv.apply_save_dict(d.get("inv", {}) as Dictionary)
	_apply_hotbar_from_save(d.get("hotbar", []))
	var vit: Variant = d.get("vitals", {})
	if vit is Dictionary:
		var vd := vit as Dictionary
		vitals_hp = float(vd.get("hp", 100.0))
		vitals_hp_max = float(vd.get("hp_max", 100.0))
		vitals_satiety = float(vd.get("satiety", 100.0))
		vitals_satiety_max = float(vd.get("satiety_max", 100.0))
	_cycle_phase = clampf(float(d.get("cycle_phase", 0.42)), 0.0, 1.0)
	game_calendar_doy = clampi(int(d.get("calendar_doy", 1)), 1, 365)
	_reload_tiled_map_for_current_region()
	var sz := get_viewport_rect().size
	var rk := _region_store_key(world_region)
	if loaded_save_ver >= SAVE_REGION_WILD_LAYOUT_VERSION:
		if not bool(_region_wild_init.get(rk, false)):
			_spawn_wild_props_for_region(world_region, sz)
			_region_wild_init[rk] = true
		_restore_entities_for_region(world_region)
	else:
		_spawn_wild_props_for_region(world_region, sz)
		_restore_entities_for_region(world_region)
		_persist_entities_for_region(world_region)
		_region_wild_init[rk] = true
	if world_region == FOREST_WORLD_REGION:
		_flush_forest_mob_bank()
	_sync_mob_respawn_state_from_save_dict(d, loaded_save_ver)
	var p1: Variant = d.get("p1_pos", null)
	if p1 is Array and (p1 as Array).size() >= 2:
		var a1 := p1 as Array
		player1.global_position = Vector2(float(a1[0]), float(a1[1]))
	var p2: Variant = d.get("p2_pos", null)
	if p2 is Array and (p2 as Array).size() >= 2:
		var a2 := p2 as Array
		player2.global_position = Vector2(float(a2[0]), float(a2[1]))
	var cmp: Variant = d.get("cam_pos", null)
	if cmp is Array and (cmp as Array).size() >= 2:
		var ac := cmp as Array
		camera.global_position = Vector2(float(ac[0]), float(ac[1]))
	_set_two_player(bool(d.get("two_player", false)), true)
	merchant_trade_total = int(d.get("merchant_trade_total", 0))
	_skill_unlock_charge = bool(d.get("skill_unlock_charge", false))
	_skill_unlock_iron_wall = bool(d.get("skill_unlock_iron_wall", false))
	var mg: Variant = d.get("merchant", null)
	if mg is Dictionary:
		_apply_merchant_from_save_dict(mg as Dictionary)
	else:
		_merchant_offer_doy = -1
		_merchant_buy_types.clear()
		_merchant_sold_today.clear()
	_p1_character_skill = _parse_character_skill_id(d.get("p1_character_skill", "dash"))
	_p2_character_skill = _parse_character_skill_id(d.get("p2_character_skill", "dash"))
	_skill_clamp_equipped_after_load()
	_p1_next_weapon_skill_double = false
	_p2_next_weapon_skill_double = false
	_p1_iron_wall_timer = 0.0
	_p2_iron_wall_timer = 0.0
	_merchant_ensure_offers_for_calendar()
	_styling_init_unlock_defaults()
	_styling_merge_unlocks_array(d.get("styling_unlocks", []))
	if loaded_save_ver < SAVE_STYLING_UNLOCK_VERSION:
		_styling_unlock_migrate_worn_from_old_save(d.get("p1_style", null), d.get("p2_style", null))
	var ps1: Variant = d.get("p1_style", null)
	if ps1 is Dictionary:
		player1.apply_pixeline_styling_from_save(ps1 as Dictionary)
	var ps2: Variant = d.get("p2_style", null)
	if ps2 is Dictionary:
		player2.apply_pixeline_styling_from_save(ps2 as Dictionary)
	_loading_save = false
	day_brightness = clampf(0.5 - 0.5 * cos(_cycle_phase * TAU), 0.0, 1.0)
	_update_day_night_modulate()
	_update_vitals_bars_ui()
	_update_inv_bar()
	_update_quest_ui()
	_update_hud_build_visual()


func reset_game_to_initial_state() -> void:
	_close_campfire_cook_popup()
	_close_workbench_craft_popup()
	_close_merchant_popup()
	_close_instructor_popup()
	_close_styling_popup()
	_loading_save = true
	_clear_spawned_entities()
	_p1_touch_idx = -1
	p2_mouse_right_down = false
	money = 0
	quest_phase = 1
	_build_kind = BuildKind.NONE
	_build_use_continuous = false
	_build_lmb_armed = false
	_build_lmb_down_ms = -1
	inv = GameInventory.new()
	vitals_hp = vitals_hp_max
	vitals_satiety = vitals_satiety_max
	_hotbar_items.clear()
	_ensure_hotbar_items_size()
	_p1_character_skill = &"dash"
	_p2_character_skill = &"dash"
	_skill_unlock_charge = false
	_skill_unlock_iron_wall = false
	merchant_trade_total = 0
	_merchant_offer_doy = -1
	_merchant_buy_types.clear()
	_merchant_sold_today.clear()
	_p1_next_weapon_skill_double = false
	_p2_next_weapon_skill_double = false
	_p1_iron_wall_timer = 0.0
	_p2_iron_wall_timer = 0.0
	_refresh_hotbar_ui()
	_cycle_phase = 0.42
	game_calendar_doy = 1
	world_region = Vector2i.ZERO
	_region_entity_store.clear()
	_region_wild_init.clear()
	_mob_respawn_last_calendar_doy = 1
	_forest_mob_bank_slimes = 0
	_forest_mob_bank_boars = 0
	_reload_tiled_map_for_current_region()
	_spawn_initial_room()
	_region_wild_init[_region_store_key(Vector2i.ZERO)] = true
	_set_two_player(false, true)
	_merchant_ensure_offers_for_calendar()
	_styling_init_unlock_defaults()
	player1.apply_pixeline_customization(true, "medium", "", "", "")
	player2.apply_pixeline_customization(true, "medium", "", "", "")
	_loading_save = false
	day_brightness = clampf(0.5 - 0.5 * cos(_cycle_phase * TAU), 0.0, 1.0)
	_update_day_night_modulate()
	_update_vitals_bars_ui()
	_update_inv_bar()
	_update_quest_ui()
	_update_hud_build_visual()
	_refresh_merchant_popup()
	_refresh_instructor_popup()
	camera.position = player1.global_position


func _clear_spawned_entities() -> void:
	var to_free: Array[Node] = []
	for c in entities.get_children():
		to_free.append(c)
	for n in to_free:
		n.free()


func _spawn_entity_from_save(ed: Dictionary) -> void:
	var t := str(ed.get("t", ""))
	match t:
		"prop":
			var kind := int(ed.get("k", 0)) as WorldPropStatic.PropKind
			var hp := int(ed.get("hp", -1))
			var node: WorldPropStatic = _scene_prop.instantiate() as WorldPropStatic
			node.prop_kind = kind
			if hp >= 0:
				node._restore_hit_points = hp
			node.global_position = Vector2(float(ed.get("x", 0.0)), float(ed.get("y", 0.0)))
			entities.add_child(node)
		"loose":
			var lk_raw := int(ed.get("k", 0))
			var lk := clampi(lk_raw, 0, int(LoosePickup.PickKind.MUSHROOM)) as LoosePickup.PickKind
			var lp: LoosePickup = _scene_loose.instantiate() as LoosePickup
			lp.pick_kind = lk
			lp.global_position = Vector2(float(ed.get("x", 0.0)), float(ed.get("y", 0.0)))
			entities.add_child(lp)
		"piece":
			var pk_raw := int(ed.get("k", 0))
			## 與 `WorldBuildPiece.PieceKind` 最大項對齊；若新增建築種類請一併提高上限。
			var pk_max := int(WorldBuildPiece.PieceKind.CHEST)
			var pk := clampi(pk_raw, 0, pk_max) as WorldBuildPiece.PieceKind
			var piece := WorldBuildPiece.new()
			piece.piece_kind = pk
			piece.door_open = bool(ed.get("door", false))
			piece.global_position = Vector2(float(ed.get("x", 0.0)), float(ed.get("y", 0.0)))
			entities.add_child(piece)
			if WorldBuildPiece.piece_kind_has_storage_inventory(pk):
				var st: Variant = ed.get("storage", null)
				if st == null or not st is Dictionary:
					st = ed.get("chest", {})
				if st is Dictionary and piece.chest_storage != null:
					piece.chest_storage.storage_deserialize(st as Dictionary)
		"campfire":
			var cf := StaticBody2D.new()
			cf.set_script(_campfire_script)
			cf.global_position = Vector2(float(ed.get("x", 0.0)), float(ed.get("y", 0.0)))
			entities.add_child(cf)
		"sapling":
			var sap := Node2D.new()
			sap.set_script(_sapling_script)
			sap.global_position = Vector2(float(ed.get("x", 0.0)), float(ed.get("y", 0.0)))
			sap.call("set_planted_phase", float(ed.get("p", 0.0)))
			entities.add_child(sap)
		"farmland":
			var land := Node2D.new()
			land.set_script(_farmland_script)
			land.global_position = Vector2(float(ed.get("x", 0.0)), float(ed.get("y", 0.0)))
			entities.add_child(land)
			var ck_raw := str(ed.get("ck", "tree"))
			var ck := StringName(ck_raw)
			if ck != &"turnip" and ck != &"tree":
				ck = &"tree"
			land.call(
				"apply_farmland_save",
				bool(ed.get("w", false)),
				int(ed.get("cs", 0)),
				int(ed.get("pd", 1)),
				ck
			)
		"berry_bush":
			var bb := StaticBody2D.new()
			bb.set_script(_berry_bush_script)
			bb.global_position = Vector2(float(ed.get("x", 0.0)), float(ed.get("y", 0.0)))
			entities.add_child(bb)
			bb.call(
				"apply_save_state",
				bool(ed.get("ripe", true)),
				float(ed.get("dep", -1.0))
			)
		"forest_slime":
			var s := ForestSlime.new()
			s.global_position = Vector2(float(ed.get("x", 0.0)), float(ed.get("y", 0.0)))
			var shp := int(ed.get("hp", ForestSlime.HIT_POINTS_MAX))
			s.hit_points = clampi(shp, 1, ForestSlime.HIT_POINTS_MAX)
			entities.add_child(s)
		"forest_mushroom", "forest_boar":
			var mu := ForestMushroom.new()
			mu.global_position = Vector2(float(ed.get("x", 0.0)), float(ed.get("y", 0.0)))
			var mhp := int(ed.get("hp", ForestMushroom.HIT_POINTS_MAX))
			mu.hit_points = clampi(mhp, 1, ForestMushroom.HIT_POINTS_MAX)
			entities.add_child(mu)
		"valley_npc":
			var npc := Node2D.new()
			var nn := str(ed.get("nn", ""))
			if not nn.is_empty():
				npc.name = nn
			npc.set_script(_rm_npc_script)
			npc.global_position = Vector2(float(ed.get("x", 0.0)), float(ed.get("y", 0.0)))
			npc.set("rm_sheet_slot", int(ed.get("slot", 1)))
			npc.set("npc_display_name", str(ed.get("nm", "")))
			var pst: Variant = ed.get("pstyle", null)
			if pst is Dictionary and (pst as Dictionary).size() > 0:
				npc.set("pixeline_styling", (pst as Dictionary).duplicate(true))
			else:
				npc.set(
					"pixeline_styling",
					_valley_npc_default_pixeline_styling(str(ed.get("nm", "")), nn)
				)
			entities.add_child(npc)
			npc.add_to_group("valley_village_npc")
		_:
			pass


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if _try_close_modal_ui_stack():
				get_viewport().set_input_as_handled()
				return
	if event is InputEventJoypadButton:
		var jb_b := event as InputEventJoypadButton
		if jb_b.button_index == JOY_BUTTON_B and jb_b.pressed and not event.is_echo():
			if _try_close_modal_ui_stack():
				get_viewport().set_input_as_handled()
				return
	if _boot_styling_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			if _bottom_hud != null:
				_bottom_hud._toggle_hud_minimize()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var pk: int = int((event as InputEventKey).physical_keycode)
		if pk >= KEY_1 and pk <= KEY_9:
			_try_use_hotbar_slot(pk - KEY_1)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			_try_use_character_skill(0)
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F or event.physical_keycode == KEY_SPACE:
			try_harvest_near(player1, 0)
		elif event.physical_keycode == KEY_G:
			try_use_near(player1, 0)
		elif event.physical_keycode == KEY_Q:
			try_weapon_skill_near(player1, 0)
			get_viewport().set_input_as_handled()
	if two_player and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_L:
			_try_use_character_skill(1)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_K:
			try_use_near(player2, 1)
		elif event.physical_keycode == KEY_P:
			try_weapon_skill_near(player2, 1)
			get_viewport().set_input_as_handled()
	if two_player and event is InputEventJoypadButton:
		var jb := event as InputEventJoypadButton
		if (
			jb.device == PlayerController.p2_gamepad_device_id()
			and jb.pressed
			and not event.is_echo()
		):
			match jb.button_index:
				JOY_BUTTON_LEFT_SHOULDER:
					_try_use_character_skill(1)
					get_viewport().set_input_as_handled()
				JOY_BUTTON_A:
					try_use_near(player2, 1)
					get_viewport().set_input_as_handled()
				JOY_BUTTON_RIGHT_SHOULDER:
					try_weapon_skill_near(player2, 1)
					get_viewport().set_input_as_handled()
				JOY_BUTTON_X:
					try_harvest_near(player2, 1)
					get_viewport().set_input_as_handled()
				_:
					pass


func _unhandled_input(event: InputEvent) -> void:
	## 滑鼠／觸控先給 UI（按鈕），未消化才處理世界區（避免 Web 上按不到底部面板）。
	if _boot_styling_active:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if _unhandled_build_mouse_button(mb):
			return
		if not _mouse_in_world_interaction_band(mb.position):
			return
		if two_player:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				p2_mouse_right_down = mb.pressed
				if mb.pressed:
					player2.set_mouse_nav_target(get_global_mouse_position(), true)
			elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var w2 := get_global_mouse_position()
				if _try_talk_npc_at_world_click(w2, player2):
					get_viewport().set_input_as_handled()
				elif not _try_open_interactive_station_from_world_click(w2, player2):
					try_harvest_near(player2, 1)
		else:
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var w1 := get_global_mouse_position()
				if _try_talk_npc_at_world_click(w1, player1):
					get_viewport().set_input_as_handled()
				elif not _try_open_interactive_station_from_world_click(w1, player1):
					pass
	elif not two_player:
		_handle_p1_touch_navigation(event)


func _screen_px_to_world_2d(screen_px: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_px


func _handle_p1_touch_navigation(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if not _mouse_in_world_interaction_band(st.position):
				return
			_p1_touch_idx = st.index
			player1.set_touch_navigation(true, _screen_px_to_world_2d(st.position))
		else:
			if st.index == _p1_touch_idx:
				_p1_touch_idx = -1
				player1.set_touch_navigation(false)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _p1_touch_idx and _p1_touch_idx != -1:
			player1.set_touch_navigation(true, _screen_px_to_world_2d(sd.position))


func _toggle_two_player() -> void:
	_clear_build_session()
	_set_two_player(not two_player)


func _set_two_player(on: bool, silent: bool = false) -> void:
	if two_player == on:
		inv.dual_main_weapon_slots_enabled = on
		return
	two_player = on
	inv.dual_main_weapon_slots_enabled = two_player
	_p1_touch_idx = -1
	player1.set_touch_navigation(false)
	player2.visible = two_player
	player2.process_mode = Node.PROCESS_MODE_INHERIT if two_player else Node.PROCESS_MODE_DISABLED
	player2.set_carry_light_suppressed(not two_player)
	player2.velocity = Vector2.ZERO
	player2.use_mouse_target = false
	player2.mouse_target = Vector2.ZERO
	p2_mouse_right_down = false
	if two_player:
		if not silent:
			player2.global_position = player1.global_position + Vector2(48, 32)
		_apply_mobile_touch_bar_visibility()
		if not silent:
			_show_msg("雙人：1P WASD、F／Space 採集、Q 武器技、E 衝刺、G 互動；2P 方向鍵／右鍵移動、左鍵採集與點營火／工作台（非建造模式）、P 武器技、L 衝刺、K 互動。兩人主手裝備獨立，請在底面板以「裝1P／裝2P」分配石斧／長槍／石製短劍。")
	else:
		_apply_mobile_touch_bar_visibility()
		if not silent:
			_show_msg("單人模式。")
	if _settings_two_player_check != null and _settings_two_player_check.button_pressed != two_player:
		_settings_two_player_check.button_pressed = two_player
	_refresh_hotbar_ui()
	if _instructor_popup != null and _instructor_popup.visible:
		_refresh_instructor_popup()
	if _styling_opt_target != null:
		_styling_refresh_target_options()


func _try_craft_axe() -> void:
	var em1 := inv.equip_main
	var em2 := inv.equip_main_p2
	var sp := inv.axe_spare
	if inv.craft_axe():
		GameSfx.play_craft()
		var tail := " 已放入背包備用。"
		if inv.equip_main == &"axe" and em1 == &"":
			tail = " 已裝在 1P 主手。"
		elif inv.equip_main_p2 == &"axe" and em2 == &"":
			tail = " 已裝在 2P 主手。"
		elif inv.axe_spare > sp:
			tail = " 已放入背包備用。"
		_show_msg("製作了石斧！" + tail)
		_update_inv_bar()
		_update_quest_ui()
	else:
		_show_msg("木材或石頭不足（需 3 木、2 石）。")


func _try_place_campfire_at(world: Vector2) -> bool:
	var pools_cf := _build_material_pools()
	if not GameInventory.pools_can_spend_campfire(pools_cf):
		_show_msg("資源不足（需 5 木、3 石）。")
		return false
	var snap := _grid_snap(world)
	var center := snap + Vector2.ONE * (GameConstants.GRID_SIZE * 0.5)
	if _is_protected(center) or _build_site_blocked(center, true):
		_show_msg("不能蓋在這裡。")
		return false
	for n in entities.get_children():
		if n.is_in_group("campfire") and n.global_position.distance_to(center) < 24.0:
			_show_msg("這裡太近了。")
			return false
	if not GameInventory.pools_try_spend_campfire(pools_cf):
		_show_msg("資源不足（需 5 木、3 石）。")
		return false
	var cf := StaticBody2D.new()
	cf.set_script(_campfire_script)
	cf.global_position = center
	entities.add_child(cf)
	GameSfx.play_place()
	_show_msg("營火升起了！")
	_update_inv_bar()
	_advance_quest_after_campfire()
	return true


func _grid_snap(v: Vector2) -> Vector2:
	var g := float(GameConstants.GRID_SIZE)
	return Vector2(floorf(v.x / g) * g, floorf(v.y / g) * g)


func _grid_top_left_for_center(center: Vector2) -> Vector2:
	var g := float(GameConstants.GRID_SIZE)
	return _grid_snap(center - Vector2(g * 0.5, g * 0.5))


func _pieces_adjacent_on_grid(center_a: Vector2, center_b: Vector2) -> bool:
	var g := float(GameConstants.GRID_SIZE)
	var tla := _grid_top_left_for_center(center_a)
	var tlb := _grid_top_left_for_center(center_b)
	var dx := int(round((tlb.x - tla.x) / g))
	var dy := int(round((tlb.y - tla.y) / g))
	return abs(dx) + abs(dy) == 1


## 建造扣資源用：玩家背包＋目前區域內所有帶倉儲的箱子（不含製作／工作台鄰接邏輯）。
func _build_material_pools() -> Array[GameInventory]:
	var pools: Array[GameInventory] = [inv]
	for c in entities.get_children():
		if not (c is WorldBuildPiece):
			continue
		var wp := c as WorldBuildPiece
		if not WorldBuildPiece.piece_kind_has_storage_inventory(wp.piece_kind):
			continue
		if wp.chest_storage == null:
			continue
		pools.append(wp.chest_storage)
	return pools


func _workbench_adjacent_storage_inventories(wb: WorldBuildPiece) -> Array[GameInventory]:
	var out: Array[GameInventory] = []
	if wb == null or not is_instance_valid(wb):
		return out
	if wb.piece_kind != WorldBuildPiece.PieceKind.WORKBENCH:
		return out
	for c in entities.get_children():
		if not (c is WorldBuildPiece):
			continue
		var wp := c as WorldBuildPiece
		if not WorldBuildPiece.piece_kind_has_storage_inventory(wp.piece_kind):
			continue
		if wp.chest_storage == null:
			continue
		if _pieces_adjacent_on_grid(wb.global_position, wp.global_position):
			out.append(wp.chest_storage)
	return out


func _nearest_workbench_piece_to_player1() -> WorldBuildPiece:
	var best: WorldBuildPiece = null
	var best_d := 9999999.0
	for c in entities.get_children():
		if not (c is WorldBuildPiece):
			continue
		var wp := c as WorldBuildPiece
		if wp.piece_kind != WorldBuildPiece.PieceKind.WORKBENCH:
			continue
		var d := player1.global_position.distance_to(wp.global_position)
		if d < best_d:
			best_d = d
			best = wp
	return best


func _mouse_in_world_interaction_band(screen_px: Vector2) -> bool:
	var vr := get_viewport().get_visible_rect()
	var y_top := HUD_TOP_HINT_ROW
	var y_bot := inv_bar.global_position.y
	if _hotbar_ctrl != null and is_instance_valid(_hotbar_ctrl) and _hotbar_ctrl.visible:
		y_bot = minf(y_bot, _hotbar_ctrl.global_position.y)
	if y_bot <= y_top + 8.0:
		y_bot = vr.size.y - 200.0
	if _hotbar_ctrl != null and is_instance_valid(_hotbar_ctrl) and _hotbar_ctrl.visible:
		if _hotbar_ctrl.get_global_rect().has_point(screen_px):
			return false
	if hint_help_btn.get_global_rect().has_point(screen_px):
		return false
	if hint_popup.visible and hint_popup.get_global_rect().has_point(screen_px):
		return false
	if settings_popup.visible and settings_popup.get_global_rect().has_point(screen_px):
		return false
	if _styling_popup != null and _styling_popup.visible and _styling_popup.get_global_rect().has_point(screen_px):
		return false
	if quest_log_popup.visible and quest_log_popup.get_global_rect().has_point(screen_px):
		return false
	if _campfire_cook_popup != null and _campfire_cook_popup.visible:
		if _campfire_cook_popup.get_global_rect().has_point(screen_px):
			return false
	if _workbench_craft_popup != null and _workbench_craft_popup.visible:
		if _workbench_craft_popup.get_global_rect().has_point(screen_px):
			return false
	if _merchant_popup != null and _merchant_popup.visible:
		if _merchant_popup.get_global_rect().has_point(screen_px):
			return false
	if _instructor_popup != null and _instructor_popup.visible:
		if _instructor_popup.get_global_rect().has_point(screen_px):
			return false
	if top_right_stack.get_global_rect().has_point(screen_px):
		return false
	if _mobile_touch_bar != null and _mobile_touch_bar.visible:
		if _mobile_touch_bar.get_global_rect().has_point(screen_px):
			return false
	if left_vitals_panel != null and left_vitals_panel.visible:
		if left_vitals_panel.get_global_rect().has_point(screen_px):
			return false
	if right_hud_column != null and right_hud_column.visible:
		if right_hud_column.get_global_rect().has_point(screen_px):
			return false
	return screen_px.y > y_top and screen_px.y < y_bot


func _apply_top_right_style() -> void:
	## 右上角按鈕組、任務面板、設定彈窗、提示彈窗的視覺美化。
	if settings_btn == null or styling_btn == null:
		return

	# ── 共用圓角暗色按鈕樣式工廠 ─────────────────────────────────────────
	var mk := func(bg: Color, border: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg
		s.border_color = border
		s.set_border_width_all(1)
		s.set_corner_radius_all(10)
		s.set_content_margin_all(4.0)
		return s

	# ── ⚙ 設定 & ? 說明按鈕 ──────────────────────────────────────────────
	var btn_n: StyleBoxFlat = mk.call(Color(0.08, 0.10, 0.15, 0.84), Color(0.30, 0.42, 0.62, 0.55))
	var btn_h: StyleBoxFlat = mk.call(Color(0.16, 0.22, 0.34, 0.94), Color(0.52, 0.68, 0.90, 0.80))
	var btn_p: StyleBoxFlat = mk.call(Color(0.04, 0.06, 0.10, 0.97), Color(0.45, 0.60, 0.85, 1.00))
	for b: Button in [settings_btn, styling_btn, hint_help_btn, quest_log_btn]:
		b.flat = false
		b.add_theme_stylebox_override("normal",  btn_n.duplicate())
		b.add_theme_stylebox_override("hover",   btn_h.duplicate())
		b.add_theme_stylebox_override("pressed", btn_p.duplicate())
		b.add_theme_color_override("font_color",         Color(0.90, 0.92, 0.97, 1.0))
		b.add_theme_color_override("font_hover_color",   Color(1.00, 1.00, 1.00, 1.0))
		b.add_theme_color_override("font_pressed_color", Color(0.75, 0.85, 1.00, 1.0))

	# ── 🗑 拆除按鈕（紅色調，視覺區隔） ──────────────────────────────────
	var dis_n: StyleBoxFlat = mk.call(Color(0.20, 0.07, 0.07, 0.88), Color(0.68, 0.28, 0.22, 0.60))
	var dis_h: StyleBoxFlat = mk.call(Color(0.32, 0.10, 0.08, 0.96), Color(0.88, 0.42, 0.30, 0.88))
	var dis_p: StyleBoxFlat = mk.call(Color(0.10, 0.04, 0.04, 0.98), Color(1.00, 0.52, 0.38, 1.00))
	dismantle_btn.flat = false
	dismantle_btn.text = "拆除"
	dismantle_btn.add_theme_font_size_override("font_size", 13)
	dismantle_btn.custom_minimum_size = Vector2(48, 36)
	dismantle_btn.add_theme_stylebox_override("normal",  dis_n)
	dismantle_btn.add_theme_stylebox_override("hover",   dis_h)
	dismantle_btn.add_theme_stylebox_override("pressed", dis_p)
	dismantle_btn.add_theme_color_override("font_color",         Color(1.00, 0.72, 0.65, 1.0))
	dismantle_btn.add_theme_color_override("font_hover_color",   Color(1.00, 0.88, 0.82, 1.0))
	dismantle_btn.add_theme_color_override("font_pressed_color", Color(1.00, 0.55, 0.45, 1.0))

	# ── 任務面板（左側綠色邊框強調） ──────────────────────────────────────
	var qp := quest_label.get_parent().get_parent() as PanelContainer
	if qp != null:
		var qs := StyleBoxFlat.new()
		qs.bg_color = Color(0.06, 0.09, 0.13, 0.92)
		qs.border_color = Color(0.42, 0.72, 0.38, 0.72)
		qs.set_border_width_all(1)
		qs.border_width_left = 3
		qs.set_corner_radius_all(8)
		qp.add_theme_stylebox_override("panel", qs)

	# ── 左側狀態列面板 ────────────────────────────────────────────────────
	var vp := StyleBoxFlat.new()
	vp.bg_color = Color(0.06, 0.08, 0.13, 0.88)
	vp.border_color = Color(0.28, 0.38, 0.56, 0.42)
	vp.set_border_width_all(1)
	vp.set_corner_radius_all(8)
	left_vitals_panel.add_theme_stylebox_override("panel", vp)

	# ── 設定彈窗背景 ──────────────────────────────────────────────────────
	var sps := StyleBoxFlat.new()
	sps.bg_color = Color(0.07, 0.09, 0.14, 0.97)
	sps.border_color = Color(0.32, 0.44, 0.64, 0.68)
	sps.set_border_width_all(1)
	sps.set_corner_radius_all(12)
	settings_popup.add_theme_stylebox_override("panel", sps)

	# 存檔（綠）
	var sv_n: StyleBoxFlat = mk.call(Color(0.10, 0.22, 0.16, 0.95), Color(0.32, 0.72, 0.42, 0.65))
	var sv_h: StyleBoxFlat = mk.call(Color(0.16, 0.34, 0.22, 0.98), Color(0.42, 0.88, 0.54, 0.90))
	settings_btn_save.add_theme_stylebox_override("normal", sv_n)
	settings_btn_save.add_theme_stylebox_override("hover",  sv_h)
	settings_btn_save.add_theme_color_override("font_color",       Color(0.62, 0.96, 0.70, 1.0))
	settings_btn_save.add_theme_color_override("font_hover_color", Color(0.80, 1.00, 0.86, 1.0))

	# 初始化（紅）
	var rs_n: StyleBoxFlat = mk.call(Color(0.22, 0.08, 0.07, 0.95), Color(0.75, 0.28, 0.22, 0.65))
	var rs_h: StyleBoxFlat = mk.call(Color(0.34, 0.10, 0.08, 0.98), Color(0.92, 0.38, 0.28, 0.90))
	settings_btn_reset.add_theme_stylebox_override("normal", rs_n)
	settings_btn_reset.add_theme_stylebox_override("hover",  rs_h)
	settings_btn_reset.add_theme_color_override("font_color",       Color(1.00, 0.65, 0.58, 1.0))
	settings_btn_reset.add_theme_color_override("font_hover_color", Color(1.00, 0.80, 0.72, 1.0))

	# 關閉（灰）
	var cl_n: StyleBoxFlat = mk.call(Color(0.12, 0.14, 0.20, 0.95), Color(0.40, 0.46, 0.58, 0.50))
	var cl_h: StyleBoxFlat = mk.call(Color(0.20, 0.24, 0.32, 0.98), Color(0.58, 0.65, 0.80, 0.75))
	settings_btn_close.add_theme_stylebox_override("normal", cl_n)
	settings_btn_close.add_theme_stylebox_override("hover",  cl_h)
	settings_btn_close.add_theme_color_override("font_color",       Color(0.78, 0.82, 0.90, 1.0))
	settings_btn_close.add_theme_color_override("font_hover_color", Color(0.92, 0.95, 1.00, 1.0))

	# ── 提示彈窗背景 ──────────────────────────────────────────────────────
	var hps := StyleBoxFlat.new()
	hps.bg_color = Color(0.06, 0.08, 0.13, 0.94)
	hps.border_color = Color(0.45, 0.60, 0.82, 0.42)
	hps.set_border_width_all(1)
	hps.set_corner_radius_all(8)
	hint_popup.add_theme_stylebox_override("panel", hps)

	var qlps := StyleBoxFlat.new()
	qlps.bg_color = Color(0.06, 0.08, 0.13, 0.96)
	qlps.border_color = Color(0.48, 0.62, 0.36, 0.55)
	qlps.set_border_width_all(1)
	qlps.set_corner_radius_all(10)
	quest_log_popup.add_theme_stylebox_override("panel", qlps)
	quest_log_close_btn.add_theme_stylebox_override("normal", cl_n.duplicate())
	quest_log_close_btn.add_theme_stylebox_override("hover", cl_h.duplicate())
	quest_log_close_btn.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90, 1.0))
	quest_log_close_btn.add_theme_color_override("font_hover_color", Color(0.92, 0.95, 1.00, 1.0))

	# ── 按鈕間距微調 ──────────────────────────────────────────────────────
	top_right_stack.add_theme_constant_override("separation", 6)


func _mk_vitals_row_icon(px: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(px, px)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _setup_left_vitals_panel_icons() -> void:
	if region_info_label == null or hp_bar == null or hunger_bar == null:
		return
	var bars := region_info_label.get_parent() as VBoxContainer
	if bars == null:
		return
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 6)
	var coin_ic := _mk_vitals_row_icon(14.0)
	coin_ic.texture = HudItemIcons.tex(HudItemIcons.VITALS_COIN)
	_left_money_label = Label.new()
	_left_money_label.add_theme_font_size_override("font_size", 12)
	_left_money_label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.58, 1.0))
	_left_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_row.add_child(coin_ic)
	money_row.add_child(_left_money_label)
	bars.add_child(money_row)
	bars.move_child(money_row, 0)
	bars.remove_child(region_info_label)
	var region_row := HBoxContainer.new()
	region_row.add_theme_constant_override("separation", 6)
	var map_ic := _mk_vitals_row_icon(14.0)
	map_ic.texture = HudItemIcons.tex(HudItemIcons.VITALS_MAP)
	region_row.add_child(map_ic)
	region_row.add_child(region_info_label)
	region_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_child(region_row)
	bars.move_child(region_row, 1)
	var hp_row := hp_bar.get_parent() as HBoxContainer
	if hp_row != null:
		var heart := _mk_vitals_row_icon(14.0)
		heart.texture = HudItemIcons.tex(HudItemIcons.VITALS_HEART)
		hp_row.add_child(heart)
		hp_row.move_child(heart, 0)
	var hun_row := hunger_bar.get_parent() as HBoxContainer
	if hun_row != null:
		_vitals_hunger_icon = _mk_vitals_row_icon(14.0)
		_vitals_hunger_icon.texture = HudItemIcons.tex(HudItemIcons.MEAT_CUTLET)
		hun_row.add_child(_vitals_hunger_icon)
		hun_row.move_child(_vitals_hunger_icon, 0)


func _apply_vitals_bars_theme() -> void:
	if hp_bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.11, 0.13, 0.17, 0.95)
	bg.set_corner_radius_all(4)
	var fill_hp := StyleBoxFlat.new()
	fill_hp.bg_color = Color(0.78, 0.22, 0.26, 1.0)
	fill_hp.set_corner_radius_all(4)
	var fill_sat := StyleBoxFlat.new()
	fill_sat.bg_color = Color(0.9, 0.62, 0.18, 1.0)
	fill_sat.set_corner_radius_all(4)
	for b: ProgressBar in [hp_bar, hunger_bar]:
		b.add_theme_stylebox_override("background", bg.duplicate() as StyleBoxFlat)
	hp_bar.add_theme_stylebox_override("fill", fill_hp)
	hunger_bar.add_theme_stylebox_override("fill", fill_sat)


func _setup_p1_world_coord_label() -> void:
	if region_info_label == null:
		return
	var bars := region_info_label.get_parent() as VBoxContainer
	if bars == null:
		return
	_p1_world_coord_label = Label.new()
	_p1_world_coord_label.name = "P1WorldCoordLabel"
	_p1_world_coord_label.text = "1P 座標 —"
	_p1_world_coord_label.add_theme_font_size_override("font_size", 11)
	_p1_world_coord_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.82, 1.0))
	_p1_world_coord_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bars.add_child(_p1_world_coord_label)
	bars.move_child(_p1_world_coord_label, 2)


func _setup_mouse_world_coord_label() -> void:
	if real_time_label == null:
		return
	var col := real_time_label.get_parent() as VBoxContainer
	if col == null:
		return
	_mouse_world_coord_label = Label.new()
	_mouse_world_coord_label.name = "MouseWorldCoordLabel"
	_mouse_world_coord_label.text = "游標 —"
	_mouse_world_coord_label.add_theme_font_size_override("font_size", 11)
	_mouse_world_coord_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78, 1.0))
	_mouse_world_coord_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_mouse_world_coord_label)


func _update_vitals_bars_ui() -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = maxf(1.0, vitals_hp_max)
	hp_bar.value = clampf(vitals_hp, 0.0, vitals_hp_max)
	hunger_bar.max_value = maxf(1.0, vitals_satiety_max)
	hunger_bar.value = clampf(vitals_satiety, 0.0, vitals_satiety_max)
	if _left_money_label != null:
		_left_money_label.text = str(money)
	if _vitals_hunger_icon != null:
		var ratio := vitals_satiety / maxf(1.0, vitals_satiety_max)
		_vitals_hunger_icon.texture = HudItemIcons.tex(
			HudItemIcons.VITALS_LIGHTNING if ratio < 0.28 else HudItemIcons.MEAT_CUTLET
		)
	if game_date_label != null:
		game_date_label.text = _game_doy_to_md_string(game_calendar_doy)
	if real_time_label != null:
		real_time_label.text = _format_game_clock_hm()
	if _mouse_world_coord_label != null:
		var w := get_global_mouse_position()
		_mouse_world_coord_label.text = "游標 (%.0f , %.0f)" % [w.x, w.y]
	if _p1_world_coord_label != null and player1 != null:
		var p1p := player1.global_position
		_p1_world_coord_label.text = "1P 座標 (%.0f , %.0f)" % [p1p.x, p1p.y]
	if region_info_label != null:
		region_info_label.text = "%s  (%d,%d)" % [
			_world_region_display_name(world_region),
			world_region.x,
			world_region.y,
		]


func _create_build_grid_overlay() -> void:
	_build_grid = BuildGridOverlay.new()
	_build_grid.z_index = 500
	_build_grid.grid_size = float(GameConstants.GRID_SIZE)
	$DayNightModulate/WorldYSort.add_child(_build_grid)


func _setup_hud_expand_btn() -> void:
	var ui := $CanvasLayer/UI as Control
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = false
	btn.text = "▶ 展開  [Tab]"
	btn.add_theme_font_size_override("font_size", 12)
	btn.anchor_left = 1.0
	btn.anchor_top = 1.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = -160.0
	btn.offset_top = -40.0
	btn.offset_right = -8.0
	btn.offset_bottom = -8.0
	btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	btn.z_index = 10
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.10, 0.14, 0.20, 0.88)
	sn.set_corner_radius_all(8)
	sn.border_color = Color(0.35, 0.52, 0.78, 0.65)
	sn.set_border_width_all(1)
	sn.content_margin_left = 10
	sn.content_margin_right = 10
	btn.add_theme_stylebox_override("normal", sn)
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.18, 0.26, 0.40, 0.96)
	sh.border_color = Color(0.52, 0.72, 1.0, 0.90)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	btn.visible = false
	btn.pressed.connect(func() -> void:
		if _bottom_hud != null:
			_bottom_hud._toggle_hud_minimize()
	)
	ui.add_child(btn)
	_hud_expand_btn = btn


func _setup_bottom_hud() -> void:
	for c in inv_bar.get_children():
		c.queue_free()
	var bh := BottomHudController.new()
	bh.set_anchors_preset(Control.PRESET_FULL_RECT)
	bh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inv_bar.add_child(bh)
	_bottom_hud = bh
	var ui_host := inv_bar.get_parent() as Control
	if ui_host != null:
		bh.configure_chest_overlay_host(ui_host)
	bh.hud_minimized_changed.connect(_on_bottom_hud_minimized)
	bh.craft_axe_pressed.connect(_try_craft_axe)
	bh.unequip_axe_pressed.connect(_on_hud_unequip_axe)
	bh.unequip_main_p2_pressed.connect(_on_hud_unequip_main_p2)
	bh.toggle_campfire_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.CAMPFIRE))
	bh.build_floor_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.FLOOR))
	bh.build_fence_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.FENCE))
	bh.build_door_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.DOOR))
	bh.build_workbench_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.WORKBENCH))
	bh.build_farmland_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.FARMLAND))
	bh.plant_tree_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.PLANT_TREE))
	bh.plant_turnip_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.PLANT_TURNIP))
	bh.build_chest_pressed.connect(func() -> void: _toggle_build_kind(BuildKind.CHEST))
	bh.unequip_armor_pressed.connect(_on_hud_unequip_armor)
	bh.backpack_slot_context_requested.connect(_on_backpack_slot_context_requested)
	bh.backpack_quick_send_to_chest_requested.connect(_on_backpack_quick_send_to_chest)
	bh.chest_quick_stash_requested.connect(_on_chest_quick_stash_requested)
	bh.chest_slot_withdraw_requested.connect(_on_chest_slot_withdraw_requested)
	bh.backpack_inventory_drag_changed.connect(func() -> void:
		_update_inv_bar()
		_autosave_if_ready()
	)
	bh.chest_inventory_changed.connect(func() -> void:
		_update_inv_bar()
		_autosave_if_ready()
	)
	bh._toggle_hud_minimize()


func _on_bottom_hud_minimized(minimized: bool) -> void:
	inv_bar.visible = not minimized
	if _hud_expand_btn != null:
		_hud_expand_btn.visible = minimized
	_sync_hotbar_visibility()
	_relayout_hotbar()
	_layout_mobile_touch_bar()


func _on_hud_equip_axe() -> void:
	if inv.try_equip_axe_from_inventory():
		_show_msg("已裝備石斧（1P）。" if two_player else "已裝備石斧。")
		_update_inv_bar()
		_update_quest_ui()
	else:
		_show_msg("沒有可裝備的石斧。")


func _on_hud_equip_axe_p2() -> void:
	if inv.try_equip_axe_from_inventory_for(1):
		_show_msg("已裝備石斧（2P）。")
		_update_inv_bar()
		_update_quest_ui()
	else:
		_show_msg("沒有可裝備的石斧。")


func _on_hud_unequip_axe() -> void:
	if inv.unequip_main_weapon_to_spare_for(0):
		_show_msg("已卸下 1P 主手裝備。" if two_player else "已卸下主手裝備。")
		_update_inv_bar()
	else:
		_show_msg("1P 主手沒有可卸下的裝備。" if two_player else "主手沒有可卸下的裝備。")


func _on_hud_unequip_main_p2() -> void:
	if inv.unequip_main_weapon_to_spare_for(1):
		_show_msg("已卸下 2P 主手裝備。")
		_update_inv_bar()
	else:
		_show_msg("2P 主手沒有可卸下的裝備。")


func _on_hud_equip_spear() -> void:
	if inv.try_equip_spear_from_inventory():
		_show_msg("已裝備木製長槍（1P）。" if two_player else "已裝備木製長槍。")
		_update_inv_bar()
	else:
		_show_msg("沒有可裝備的木製長槍。")


func _on_hud_equip_spear_p2() -> void:
	if inv.try_equip_spear_from_inventory_for(1):
		_show_msg("已裝備木製長槍（2P）。")
		_update_inv_bar()
	else:
		_show_msg("沒有可裝備的木製長槍。")


func _on_hud_equip_sword() -> void:
	if inv.try_equip_sword_from_inventory():
		_show_msg("已裝備石製短劍（1P）。" if two_player else "已裝備石製短劍。")
		_update_inv_bar()
	else:
		_show_msg("沒有可裝備的石製短劍。")


func _on_hud_equip_sword_p2() -> void:
	if inv.try_equip_sword_from_inventory_for(1):
		_show_msg("已裝備石製短劍（2P）。")
		_update_inv_bar()
	else:
		_show_msg("沒有可裝備的石製短劍。")


func _on_hud_equip_sticky_armor() -> void:
	if inv.try_equip_sticky_armor_from_inventory():
		_show_msg("已穿上黏黏護甲。")
		_update_inv_bar()
	else:
		_show_msg("沒有可裝備的黏黏護甲備件。")


func _on_hud_unequip_armor() -> void:
	if inv.unequip_armor_to_spare():
		_show_msg("已卸下黏黏護甲。")
		_update_inv_bar()
	else:
		_show_msg("目前沒有穿上的黏黏護甲。")


func _toggle_build_kind(k: BuildKind) -> void:
	if quest_phase < 2 and k != BuildKind.DISMANTLE:
		_show_msg("先完成石斧教學。")
		return
	var turning_off := _build_kind == k
	if turning_off:
		_build_kind = BuildKind.NONE
	else:
		_build_kind = k
	_build_use_continuous = false
	_build_lmb_armed = false
	_build_lmb_down_ms = -1
	_update_hud_build_visual()
	_update_build_grid_preview()
	if k == BuildKind.FLOOR:
		_show_msg(
			"已取消木地板。" if turning_off else "木地板：短按左鍵放開蓋一格並結束模式；長按放開可連蓋至失敗或 Esc。"
		)
	elif k == BuildKind.FENCE:
		_show_msg(
			"已取消木牆。" if turning_off else "木牆：短按左鍵放開蓋一段並結束；長按放開可連蓋至失敗或 Esc。"
		)
	elif k == BuildKind.DOOR:
		_show_msg(
			"已取消木門。" if turning_off else "木門：短按左鍵放開蓋一扇並結束；長按放開可連蓋至失敗或 Esc。"
		)
	elif k == BuildKind.DISMANTLE:
		_show_msg(
			"已取消拆除。" if turning_off else "拆除：短按左鍵放開拆一個並結束；長按放開可連拆至失敗或 Esc。"
		)
	elif k == BuildKind.CAMPFIRE:
		_show_msg("已關閉放置營火。" if turning_off else "放置營火：左鍵按下後放開於空地（5木3石）；短按放開結束模式。")
	elif k == BuildKind.PLANT_TREE:
		_show_msg(
			"已取消種樹。" if turning_off else "種樹：短按左鍵放開種一棵並結束；長按放開可連種至失敗或 Esc。"
		)
	elif k == BuildKind.PLANT_TURNIP:
		_show_msg(
			"已取消種蕪菁。" if turning_off else "種蕪菁：僅能種在耕地上，消耗 1 份蕪菁種子；短按左鍵放開種一塊並結束；長按可連種至失敗或 Esc。"
		)
	elif k == BuildKind.WORKBENCH:
		_show_msg(
			"已取消放置工作台。" if turning_off else "工作台：短按左鍵放開蓋一座並結束；長按放開可連蓋（%d 木、%d 石）至失敗或 Esc。"
			% [GameConstants.BUILD_WORKBENCH_WOOD, GameConstants.BUILD_WORKBENCH_STONE]
		)
	elif k == BuildKind.FARMLAND:
		_show_msg(
			"已取消耕地。" if turning_off else "耕地：短按左鍵放開蓋一格並結束；長按放開可連蓋（%d 土）至失敗或 Esc。"
			% GameConstants.BUILD_FARMLAND_DIRT
		)
	elif k == BuildKind.CHEST:
		_show_msg(
			"已取消木箱。" if turning_off else "木箱：短按左鍵放開放一座（%d 木）並結束；長按可連放至失敗或 Esc。"
			% GameConstants.BUILD_CHEST_WOOD
		)


func _update_hud_build_visual() -> void:
	if _bottom_hud == null:
		return
	_bottom_hud.set_build_mode_visual(
		_build_kind == BuildKind.CAMPFIRE,
		_build_kind == BuildKind.FLOOR,
		_build_kind == BuildKind.FENCE,
		_build_kind == BuildKind.DOOR,
		_build_kind == BuildKind.DISMANTLE,
		_build_kind == BuildKind.PLANT_TREE,
		_build_kind == BuildKind.WORKBENCH,
		_build_kind == BuildKind.FARMLAND,
		_build_kind == BuildKind.PLANT_TURNIP,
		_build_kind == BuildKind.CHEST
	)


func _any_build_placement_mode() -> bool:
	return (
		_build_kind == BuildKind.CAMPFIRE
		or _build_kind == BuildKind.FLOOR
		or _build_kind == BuildKind.FENCE
		or _build_kind == BuildKind.DOOR
		or _build_kind == BuildKind.PLANT_TREE
		or _build_kind == BuildKind.WORKBENCH
		or _build_kind == BuildKind.FARMLAND
		or _build_kind == BuildKind.PLANT_TURNIP
		or _build_kind == BuildKind.CHEST
	)


func get_cycle_phase() -> float:
	return _cycle_phase


func replace_sapling_with_tree(sap: Node2D) -> void:
	if sap == null or not sap.is_inside_tree():
		return
	var pos := sap.global_position
	entities.remove_child(sap)
	sap.free()
	var node: WorldPropStatic = _scene_prop.instantiate() as WorldPropStatic
	node.prop_kind = WorldPropStatic.PropKind.TREE
	node.global_position = pos
	entities.add_child(node)
	_update_inv_bar()


func _update_build_grid_preview() -> void:
	if _build_grid == null:
		return
	if not _any_build_placement_mode():
		if _build_grid.enabled or _build_grid.visible:
			_build_grid.enabled = false
			_build_grid.visible = false
			_build_grid.queue_redraw()
		return
	_build_grid.visible = true
	_build_grid.enabled = true
	var w := get_global_mouse_position()
	var snap_c := _grid_snap(w) + Vector2.ONE * (GameConstants.GRID_SIZE * 0.5)
	_build_grid.preview_center = snap_c
	## 營火模式不畫 40×40 預覽框（易與營火疊看起來像異常方框）。
	if _build_kind == BuildKind.CAMPFIRE:
		_build_grid.preview_size = Vector2.ZERO
	else:
		_build_grid.preview_size = Vector2(float(GameConstants.GRID_SIZE), float(GameConstants.GRID_SIZE))


func _clear_build_session() -> void:
	_build_kind = BuildKind.NONE
	_build_use_continuous = false
	_build_lmb_armed = false
	_build_lmb_down_ms = -1
	_update_hud_build_visual()
	_update_build_grid_preview()


func _try_build_or_dismantle_place(world: Vector2) -> bool:
	match _build_kind:
		BuildKind.NONE:
			return false
		BuildKind.CAMPFIRE:
			return _try_place_campfire_at(world)
		BuildKind.FLOOR:
			return _try_place_world_piece(WorldBuildPiece.PieceKind.FLOOR, world)
		BuildKind.FENCE:
			return _try_place_world_piece(WorldBuildPiece.PieceKind.WALL, world)
		BuildKind.DOOR:
			return _try_place_world_piece(WorldBuildPiece.PieceKind.DOOR, world)
		BuildKind.DISMANTLE:
			return _try_dismantle_at(world)
		BuildKind.PLANT_TREE:
			return _try_place_sapling(world)
		BuildKind.PLANT_TURNIP:
			return _try_place_turnip_on_farmland(world)
		BuildKind.WORKBENCH:
			return _try_place_world_piece(WorldBuildPiece.PieceKind.WORKBENCH, world)
		BuildKind.FARMLAND:
			return _try_place_farmland(world)
		BuildKind.CHEST:
			return _try_place_world_piece(WorldBuildPiece.PieceKind.CHEST, world)
		_:
			return false


func _unhandled_build_mouse_button(mb: InputEventMouseButton) -> bool:
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return false
	if _build_kind == BuildKind.NONE and not _build_use_continuous:
		return false
	var world := get_global_mouse_position()
	if mb.pressed:
		if _build_use_continuous:
			var ok_c := _try_build_or_dismantle_place(world)
			if not ok_c:
				_clear_build_session()
			get_viewport().set_input_as_handled()
			return true
		if _build_kind != BuildKind.NONE:
			_build_lmb_down_ms = Time.get_ticks_msec()
			_build_lmb_armed = true
			get_viewport().set_input_as_handled()
			return true
		return false
	if _build_lmb_armed:
		_build_lmb_armed = false
		var held := Time.get_ticks_msec() - _build_lmb_down_ms
		_build_lmb_down_ms = -1
		var is_long := held >= BUILD_LONG_PRESS_MS
		var ok := _try_build_or_dismantle_place(world)
		if is_long and ok:
			_build_use_continuous = true
		elif (not is_long) and ok:
			_clear_build_session()
		get_viewport().set_input_as_handled()
		return true
	return false


## 同格已有建造時通常不可再蓋。`allow_build_on_floor` 為 true 時，同格僅有木地板可忽略（可再疊牆／門／工作台等）。
func _build_site_blocked(center: Vector2, allow_build_on_floor: bool = false) -> bool:
	for c in entities.get_children():
		if c is WorldPropStatic:
			if c.global_position.distance_to(center) < 22.0:
				return true
		if c.is_in_group("berry_bush"):
			if c.global_position.distance_to(center) < 22.0:
				return true
		if c.is_in_group("build_piece") or c.is_in_group("campfire"):
			if allow_build_on_floor and c is WorldBuildPiece:
				var wp := c as WorldBuildPiece
				if wp.piece_kind == WorldBuildPiece.PieceKind.FLOOR:
					continue
			if c.global_position.distance_to(center) < GameConstants.GRID_SIZE * 0.45:
				return true
	return false


func _try_place_world_piece(kind: WorldBuildPiece.PieceKind, world: Vector2) -> bool:
	var cost_w := GameConstants.BUILD_FLOOR_WOOD
	var cost_s := 0
	match kind:
		WorldBuildPiece.PieceKind.WALL:
			cost_w = GameConstants.BUILD_FENCE_WOOD
		WorldBuildPiece.PieceKind.DOOR:
			cost_w = GameConstants.BUILD_DOOR_WOOD
		WorldBuildPiece.PieceKind.WORKBENCH:
			cost_w = GameConstants.BUILD_WORKBENCH_WOOD
			cost_s = GameConstants.BUILD_WORKBENCH_STONE
		WorldBuildPiece.PieceKind.CHEST:
			cost_w = GameConstants.BUILD_CHEST_WOOD
		_:
			pass
	var pools_bp := _build_material_pools()
	if GameInventory.count_in_pools(pools_bp, &"wood") < cost_w:
		_show_msg("木材不足。")
		return false
	if GameInventory.count_in_pools(pools_bp, &"stone") < cost_s:
		_show_msg("石頭不足。")
		return false
	var snap := _grid_snap(world)
	var center := snap + Vector2.ONE * (GameConstants.GRID_SIZE * 0.5)
	if (
		_is_protected(center)
		or _spawn_mask_blocks_global_point(center)
		or _build_site_blocked(center, kind != WorldBuildPiece.PieceKind.FLOOR)
	):
		_show_msg("不能蓋在這裡。")
		return false
	if not GameInventory.pools_try_spend_build_wood_stone(pools_bp, cost_w, cost_s):
		_show_msg("木材或石頭不足。")
		return false
	var piece := WorldBuildPiece.new()
	piece.piece_kind = kind
	piece.global_position = center
	entities.add_child(piece)
	GameSfx.play_place()
	_update_inv_bar()
	_show_msg("建造完成。")
	return true


func _try_place_farmland(world: Vector2) -> bool:
	var pools_fm := _build_material_pools()
	if GameInventory.count_in_pools(pools_fm, &"dirt") < GameConstants.BUILD_FARMLAND_DIRT:
		_show_msg("土不足。")
		return false
	var snap := _grid_snap(world)
	var center := snap + Vector2.ONE * (GameConstants.GRID_SIZE * 0.5)
	if (
		_is_protected(center)
		or _spawn_mask_blocks_global_point(center)
		or _build_site_blocked(center, true)
	):
		_show_msg("不能蓋在這裡。")
		return false
	if not GameInventory.remove_from_pools_ordered(
		pools_fm, &"dirt", GameConstants.BUILD_FARMLAND_DIRT
	):
		_show_msg("土不足。")
		return false
	var fm := Node2D.new()
	fm.set_script(_farmland_script)
	fm.global_position = center
	entities.add_child(fm)
	GameSfx.play_place()
	_update_inv_bar()
	_show_msg("已蓋好耕地。")
	return true


func _farmland_at_cell(center: Vector2) -> Node2D:
	for c in entities.get_children():
		if c is Node2D and c.is_in_group("farmland"):
			var n := c as Node2D
			if n.global_position.distance_to(center) < 12.0:
				return n
	return null


func _nearest_farmland_for_water(from: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist + 1.0
	for c in entities.get_children():
		if c is Node2D and c.is_in_group("farmland"):
			var n := c as Node2D
			var d := n.global_position.distance_to(from)
			if d <= max_dist and d < best_d:
				best_d = d
				best = n
	return best


func _try_use_water_on_farmland(who: PlayerController) -> void:
	if inv.water < 1:
		_show_msg("沒有水。")
		return
	var fm := _nearest_farmland_for_water(who.global_position, GameConstants.INTERACT_REACH)
	if fm == null:
		_show_msg("附近沒有耕地。")
		return
	if bool(fm.call("is_already_watered")):
		_show_msg("這塊耕地已經澆過水了。")
		return
	if not inv.try_consume_one_water():
		return
	fm.call("apply_water_after_consume")
	GameSfx.play_pickup(-2.0)
	_show_msg("已澆水。")
	_update_inv_bar()


func _try_place_sapling(world: Vector2) -> bool:
	var pools_tr := _build_material_pools()
	if GameInventory.count_in_pools(pools_tr, &"seed") < GameConstants.PLANT_TREE_SEED_COST:
		_show_msg("樹種不足。")
		return false
	var snap := _grid_snap(world)
	var center := snap + Vector2.ONE * (GameConstants.GRID_SIZE * 0.5)
	var on_farmland := _farmland_at_cell(center)
	if on_farmland != null:
		if bool(on_farmland.call("has_crop")):
			_show_msg("這塊耕地已有作物。")
			return false
		if _is_protected(center) or _spawn_mask_blocks_global_point(center):
			_show_msg("不能種在這裡。")
			return false
		if not GameInventory.remove_from_pools_ordered(
			pools_tr, &"seed", GameConstants.PLANT_TREE_SEED_COST
		):
			_show_msg("樹種不足。")
			return false
		if not bool(on_farmland.call("try_plant_crop", game_calendar_doy, &"tree")):
			var ov_rs := inv.try_add_item(&"seed", GameConstants.PLANT_TREE_SEED_COST)
			if ov_rs > 0:
				_show_msg("無法種在這裡；背包已滿，樹種無法退回。")
			else:
				_show_msg("無法種在這裡。")
			return false
		GameSfx.play_place(-3.0)
		_show_msg("在耕地上種了作物；每日澆水可長一階，長滿後按 F 採收。")
		_update_inv_bar()
		return true
	if (
		_is_protected(center)
		or _spawn_mask_blocks_global_point(center)
		or _build_site_blocked(center, true)
	):
		_show_msg("不能種在這裡。")
		return false
	if not GameInventory.remove_from_pools_ordered(
		pools_tr, &"seed", GameConstants.PLANT_TREE_SEED_COST
	):
		_show_msg("樹種不足。")
		return false
	var sap := Node2D.new()
	sap.set_script(_sapling_script)
	sap.global_position = center
	sap.call("set_planted_phase", _cycle_phase)
	entities.add_child(sap)
	GameSfx.play_place(-3.0)
	_show_msg("已種下樹苗，約經過遊戲內一整天會長成大樹。")
	_update_inv_bar()
	return true


func _try_place_turnip_on_farmland(world: Vector2) -> bool:
	var pools_tp := _build_material_pools()
	if GameInventory.count_in_pools(pools_tp, &"turnip_seeds") < 1:
		_show_msg("沒有蕪菁種子。")
		return false
	var snap := _grid_snap(world)
	var center := snap + Vector2.ONE * (GameConstants.GRID_SIZE * 0.5)
	var on_farmland := _farmland_at_cell(center)
	if on_farmland == null:
		_show_msg("請點在耕地上種蕪菁。")
		return false
	if bool(on_farmland.call("has_crop")):
		_show_msg("這塊耕地已有作物。")
		return false
	if _is_protected(center) or _spawn_mask_blocks_global_point(center):
		_show_msg("不能種在這裡。")
		return false
	if not GameInventory.remove_from_pools_ordered(pools_tp, &"turnip_seeds", 1):
		_show_msg("沒有蕪菁種子。")
		return false
	if not bool(on_farmland.call("try_plant_crop", game_calendar_doy, &"turnip")):
		if inv.try_add_item(&"turnip_seeds", 1) > 0:
			_show_msg("無法種在這裡；背包已滿，種子無法退回。")
		else:
			_show_msg("無法種在這裡。")
		return false
	GameSfx.play_place(-3.0)
	_show_msg("已種下蕪菁；每日澆水可長一階，長滿後按 F 採收。")
	_update_inv_bar()
	return true


func _dismantle_target_is_wood_floor(n: Node2D) -> bool:
	if not (n is WorldBuildPiece):
		return false
	return (n as WorldBuildPiece).piece_kind == WorldBuildPiece.PieceKind.FLOOR


## 拆除範圍內多個目標時：優先非木地板建造物／營火，其次才木地板；同優先級取較近者。
func _pick_dismantle_target_near(candidates: Array[Node2D], world: Vector2) -> Node2D:
	var arr: Array[Node2D] = candidates.duplicate()
	arr.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		var af := _dismantle_target_is_wood_floor(a)
		var bf := _dismantle_target_is_wood_floor(b)
		if af != bf:
			if af and not bf:
				return false
			if not af and bf:
				return true
		var da := a.global_position.distance_to(world)
		var db := b.global_position.distance_to(world)
		if da != db:
			return da < db
		return a.get_instance_id() < b.get_instance_id()
	)
	return arr[0]


func _try_dismantle_at(world: Vector2) -> bool:
	var reach := 56.0
	var candidates: Array[Node2D] = []
	for c in entities.get_children():
		if not (c is Node2D):
			continue
		if not c.is_in_group("build_piece") and not c.is_in_group("campfire"):
			continue
		var n2 := c as Node2D
		if n2.global_position.distance_to(world) < reach:
			candidates.append(n2)
	if candidates.is_empty():
		_show_msg("附近沒有可拆的目標。")
		return false
	var best := _pick_dismantle_target_near(candidates, world)
	if best.is_in_group("campfire"):
		var ovw := inv.try_add_item(&"wood", GameConstants.CAMPFIRE_WOOD)
		var ovs := inv.try_add_item(&"stone", GameConstants.CAMPFIRE_STONE)
		if ovw > 0 or ovs > 0:
			_show_msg("背包空間不足，部分營火退回資源無法入包。")
		best.queue_free()
		GameSfx.play_place(-8.0)
		_show_msg("已拆除營火（退回資源）。")
	elif best.is_in_group("sapling"):
		if inv.try_add_item(&"seed", GameConstants.PLANT_TREE_SEED_COST) > 0:
			_show_msg("背包已滿，樹種無法取回。")
		best.queue_free()
		GameSfx.play_place(-8.0)
		_show_msg("已移除樹苗（退回樹種）。")
	elif best.is_in_group("farmland"):
		if inv.try_add_item(&"dirt", GameConstants.BUILD_FARMLAND_DIRT) > 0:
			_show_msg("背包已滿，土無法取回。")
		best.queue_free()
		GameSfx.play_place(-8.0)
		_show_msg("已拆除耕地（退回土）。")
	elif best is WorldBuildPiece:
		var wpb := best as WorldBuildPiece
		var pk: WorldBuildPiece.PieceKind = wpb.piece_kind
		if WorldBuildPiece.piece_kind_has_storage_inventory(pk) and wpb.chest_storage != null:
			if _bottom_hud != null:
				_bottom_hud.close_chest_panel()
			var spilled := false
			for si in wpb.chest_storage.slot_count:
				var sn := wpb.chest_storage.get_slot_snapshot(si)
				if sn.is_empty():
					continue
				var idv: Variant = sn.get("id", &"")
				var sid: StringName = idv as StringName if idv is StringName else StringName(str(idv))
				var q := int(sn.get("q", 0))
				if sid == &"" or q <= 0:
					continue
				var ov_sp := inv.try_add_item(sid, q)
				if ov_sp > 0:
					spilled = true
			if spilled:
				_show_msg("背包空間不足，箱子內部分物品未能取回。")
		var rw := WorldBuildPiece.refund_wood_for_kind(pk)
		var rs := WorldBuildPiece.refund_stone_for_kind(pk)
		var owr := inv.try_add_item(&"wood", rw)
		var osr := inv.try_add_item(&"stone", rs)
		if owr > 0 or osr > 0:
			_show_msg("背包空間不足，部分退回資源無法入包。")
		best.queue_free()
		GameSfx.play_place(-8.0)
		_show_msg("已拆除建造物（退回資源）。")
	_update_inv_bar()
	return true


func _advance_quest_after_campfire() -> void:
	if quest_phase == 2:
		quest_phase = 3
		_update_quest_ui()
		_show_msg(
			"營火完成了！接下來用「木箱」集中木材與石頭：底部「建造」→ 木箱，於空地左鍵放置（木 6）。"
			+ "任務欄會說明箱子的拖放、一鍵入箱與右鍵取出等用法。"
		)


func on_loose_pickup(p: LoosePickup) -> void:
	GameSfx.play_pickup()
	var id := _loose_pick_kind_to_stackable_id(p.pick_kind)
	var ov := inv.try_add_item(id, 1) if id != &"" else 1
	p.queue_free()
	if ov > 0:
		_show_msg("背包已滿，無法拾起。")
	else:
		match p.pick_kind:
			LoosePickup.PickKind.SLIME:
				_show_msg("撿到黏液。")
			LoosePickup.PickKind.LEATHER:
				_show_msg("撿到皮革。")
			LoosePickup.PickKind.MEAT_CUTLET:
				_show_msg("撿到肉排。")
			LoosePickup.PickKind.MUSHROOM:
				_show_msg("撿到野菇。")
			_:
				pass
	_update_inv_bar()
	_update_quest_ui()


func _loose_pick_kind_to_stackable_id(k: LoosePickup.PickKind) -> StringName:
	match k:
		LoosePickup.PickKind.WOOD:
			return &"wood"
		LoosePickup.PickKind.STONE:
			return &"stone"
		LoosePickup.PickKind.SEED:
			return &"seed"
		LoosePickup.PickKind.SLIME:
			return &"slime_goo"
		LoosePickup.PickKind.LEATHER:
			return &"leather"
		LoosePickup.PickKind.MEAT_CUTLET:
			return &"meat_cutlet"
		LoosePickup.PickKind.MUSHROOM:
			return &"wild_mushroom"
		_:
			return &""


## 回傳角色與最近一格「Water」圖塊中心的距離；若互動範圍內無水格則為 INF。
func _nearest_water_tile_interact_distance(who: Node2D) -> float:
	var gp := who.global_position
	var reach := GameConstants.INTERACT_REACH
	var best := INF
	for layer in _spawn_avoid_water_layers:
		var ts := layer.tile_set
		if ts == null:
			continue
		var tsz := Vector2(ts.tile_size)
		var cell_w := maxf(minf(tsz.x, tsz.y), 1.0)
		var r := int(ceili(reach / cell_w)) + 1
		var center_cell := layer.local_to_map(layer.to_local(gp))
		for ox in range(-r, r + 1):
			for oy in range(-r, r + 1):
				var nc := center_cell + Vector2i(ox, oy)
				if layer.get_cell_tile_data(nc) == null:
					continue
				var top_left := layer.map_to_local(nc)
				var tile_center := layer.to_global(top_left + tsz * 0.5)
				var d := gp.distance_to(tile_center)
				if d <= reach and d < best:
					best = d
	return best


func _try_talk_npc_at_world_click(world_click: Vector2, who: PlayerController) -> bool:
	var reach := GameConstants.INTERACT_REACH
	const CLICK_R := 40.0
	var best: Node2D = null
	var best_d := CLICK_R + 1.0
	for c in entities.get_children():
		if not (c is Node2D):
			continue
		if not c.is_in_group("talkable_npc"):
			continue
		var n2 := c as Node2D
		if not n2.visible:
			continue
		if who.global_position.distance_to(n2.global_position) > reach:
			continue
		var d := world_click.distance_to(n2.global_position)
		if d <= CLICK_R and d < best_d:
			best_d = d
			best = n2
	if best == null:
		return false
	var nm := str(best.get("npc_display_name"))
	if nm.is_empty():
		return false
	if _try_open_npc_shop_by_name(nm):
		return true
	_show_msg("「你好，我是%s。」" % nm)
	GameSfx.play_interact(-1.5)
	return true


func _try_open_npc_shop_by_name(nm: String) -> bool:
	if nm == "商人":
		_open_merchant_popup()
		return true
	if nm == "教官":
		_open_instructor_popup()
		return true
	return false


func try_use_near(who: PlayerController, _player_idx: int) -> void:
	## 互動鍵：營火快速烹飪、工作台製作、木門開關、水邊裝水、NPC 對話（與 F 採集、左鍵建造分開）。
	if _try_portal_interact_with(who):
		return
	var reach := GameConstants.INTERACT_REACH
	var best_door: WorldBuildPiece = null
	var best_d_door := reach
	var best_cf: Node2D = null
	var best_d_cf := reach
	var best_wb: WorldBuildPiece = null
	var best_d_wb := reach
	var best_ch: WorldBuildPiece = null
	var best_d_ch := reach
	var best_talk: Node2D = null
	var best_d_talk := reach + 1.0
	for c in entities.get_children():
		if c is WorldBuildPiece:
			var wp := c as WorldBuildPiece
			if wp.piece_kind == WorldBuildPiece.PieceKind.DOOR:
				var dd := who.global_position.distance_to(wp.global_position)
				if dd < best_d_door:
					best_d_door = dd
					best_door = wp
			elif wp.piece_kind == WorldBuildPiece.PieceKind.WORKBENCH:
				var dwb := who.global_position.distance_to(wp.global_position)
				if dwb < best_d_wb:
					best_d_wb = dwb
					best_wb = wp
			elif WorldBuildPiece.piece_kind_has_storage_inventory(wp.piece_kind):
				var dch := who.global_position.distance_to(wp.global_position)
				if dch < best_d_ch:
					best_d_ch = dch
					best_ch = wp
		if c is Node2D and c.is_in_group("campfire"):
			var n2 := c as Node2D
			var dc := who.global_position.distance_to(n2.global_position)
			if dc < best_d_cf:
				best_d_cf = dc
				best_cf = n2
		if c is Node2D and c.is_in_group("talkable_npc"):
			var nt := c as Node2D
			if not nt.visible:
				continue
			var dt := who.global_position.distance_to(nt.global_position)
			if dt < reach and dt < best_d_talk:
				best_d_talk = dt
				best_talk = nt
	var use := &""
	var use_d := reach + 1.0
	if best_cf != null and best_d_cf < reach and best_d_cf < use_d:
		use = &"cf"
		use_d = best_d_cf
	if best_wb != null and best_d_wb < reach and best_d_wb < use_d:
		use = &"wb"
		use_d = best_d_wb
	if best_ch != null and best_d_ch < reach and best_d_ch < use_d:
		use = &"chest"
		use_d = best_d_ch
	if best_door != null and best_d_door < reach and best_d_door < use_d:
		use = &"door"
		use_d = best_d_door
	var water_d := _nearest_water_tile_interact_distance(who)
	if water_d < reach and water_d < use_d:
		use = &"water"
		use_d = water_d
	if best_talk != null and best_d_talk < reach and best_d_talk < use_d:
		use = &"npc"
		use_d = best_d_talk
	match use:
		&"cf":
			_open_campfire_cook_popup()
		&"wb":
			_open_workbench_craft_popup(best_wb)
		&"chest":
			if best_ch != null and best_ch.chest_storage != null and _bottom_hud != null:
				_bottom_hud.open_chest_panel(best_ch.chest_storage)
				GameSfx.play_interact(-3.0)
		&"door":
			best_door.toggle_door()
			GameSfx.play_interact(-2.0)
			_show_msg("門已開啟，可通過。" if best_door.door_open else "門已關閉。")
		&"water":
			if inv.try_add_one_water():
				GameSfx.play_pickup()
				_show_msg("裝了 1 份水。")
				_update_inv_bar()
			else:
				_show_msg("水已滿（最多 %d 份）。" % GameConstants.WATER_CARRY_MAX)
		&"npc":
			if best_talk != null:
				var nm2 := str(best_talk.get("npc_display_name"))
				if not nm2.is_empty():
					if not _try_open_npc_shop_by_name(nm2):
						_show_msg("「你好，我是%s。」" % nm2)
						GameSfx.play_interact(-1.5)
		_:
			pass


func add_berries(amount: int) -> void:
	var n := maxi(0, amount)
	if n <= 0:
		return
	var ov := inv.try_add_item(&"berries", n)
	if ov > 0:
		_show_msg("背包已滿，%d 個莓果未能入包。" % ov)
	_update_inv_bar()


func _weapon_range_mult(main: StringName) -> float:
	match main:
		&"wood_spear":
			return GameConstants.WEAPON_SPEAR_RANGE_MULT
		&"iron_sword":
			return GameConstants.WEAPON_SWORD_RANGE_MULT
		_:
			return 1.0


func _weapon_hit_interval(main: StringName) -> float:
	match main:
		&"wood_spear":
			return GameConstants.WEAPON_SPEAR_HIT_INTERVAL
		&"iron_sword":
			return GameConstants.WEAPON_SWORD_HIT_INTERVAL
		&"axe":
			return 0.38
		_:
			return 0.0


func _spawn_weapon_attack_vfx(
	from: Vector2, toward: Vector2, reach: float, weapon: StringName, on_cooldown: bool
) -> void:
	var v := WeaponAttackVfx.new()
	entities.add_child(v)
	v.begin(from, toward, reach, weapon, on_cooldown)


## 與木製長槍採集距離相同：基礎採集距離 × 長槍倍率（技能／投擲鎖定皆用此當「木槍攻擊距離」參考）。
func _spear_effective_reach(player_idx: int) -> float:
	var base := (
		GameConstants.HARVEST_REACH_P1
		if player_idx == 0
		else GameConstants.HARVEST_REACH_P2
	)
	return base * GameConstants.WEAPON_SPEAR_RANGE_MULT


func _weapon_skill_cd_remaining(player_idx: int) -> float:
	return _p1_weapon_skill_cd if player_idx == 0 else _p2_weapon_skill_cd


func _set_weapon_skill_cd(player_idx: int) -> void:
	if player_idx == 0:
		_p1_weapon_skill_cd = GameConstants.WEAPON_SKILL_COOLDOWN
	else:
		_p2_weapon_skill_cd = GameConstants.WEAPON_SKILL_COOLDOWN


func try_weapon_skill_near(who: PlayerController, player_idx: int) -> void:
	var wm := inv.equip_main_for(player_idx)
	match wm:
		&"wood_spear":
			_try_wood_spear_whirl_skill(who, player_idx)
		&"iron_sword":
			_try_iron_sword_throw_skill(who, player_idx)
		_:
			_show_msg("武器技能：請裝備木製長槍或石製短劍。")


func _try_wood_spear_whirl_skill(who: PlayerController, player_idx: int) -> void:
	if _weapon_skill_cd_remaining(player_idx) > 0.0:
		_show_msg("武器技能冷卻中。")
		return
	var cost := GameConstants.WEAPON_SKILL_SATIETY_SPEAR
	if vitals_satiety < cost:
		_show_msg("飽足不足，無法施展長槍迴旋（需至少 %.0f）。" % cost)
		return
	var radius := _spear_effective_reach(player_idx)
	vitals_satiety = maxf(0.0, vitals_satiety - cost)
	_update_vitals_bars_ui()
	var whirl := SpearWhirlVfx.new()
	entities.add_child(whirl)
	whirl.begin(who.global_position, radius)
	GameSfx.play_skill_whoosh(0.95, -2.5)
	var props: Array[WorldPropStatic] = []
	for c in entities.get_children():
		if c is WorldPropStatic:
			var p := c as WorldPropStatic
			if who.global_position.distance_to(p.global_position) <= radius:
				props.append(p)
	for p in props:
		var res: Dictionary = p.take_hit()
		if res.get("destroyed", false):
			_on_prop_destroyed(p)
	var mobs: Array[Node2D] = []
	for c in entities.get_children():
		if not (c is Node2D):
			continue
		if not c.is_in_group("melee_monster"):
			continue
		if not c.has_method("take_weapon_hit"):
			continue
		var m := c as Node2D
		if who.global_position.distance_to(m.global_position) <= radius:
			mobs.append(m)
	var spear_dmg := _weapon_skill_damage_multiplier(player_idx)
	for m in mobs:
		m.call("take_weapon_hit", spear_dmg)
	_set_weapon_skill_cd(player_idx)
	_update_inv_bar()
	_show_msg("長槍迴旋！")


func _nearest_melee_monster_in_range(from: Vector2, max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist + 1.0
	for c in entities.get_children():
		if not (c is Node2D):
			continue
		if not c.is_in_group("melee_monster"):
			continue
		if not c.has_method("take_weapon_hit"):
			continue
		var n := c as Node2D
		var d := from.distance_to(n.global_position)
		if d <= max_dist and d < best_d:
			best_d = d
			best = n
	return best


func _try_iron_sword_throw_skill(who: PlayerController, player_idx: int) -> void:
	if _weapon_skill_cd_remaining(player_idx) > 0.0:
		_show_msg("武器技能冷卻中。")
		return
	var max_r := _spear_effective_reach(player_idx) * GameConstants.WEAPON_THROW_LOCK_RANGE_MULT
	var tgt := _nearest_melee_monster_in_range(who.global_position, max_r)
	if tgt == null:
		_show_msg("範圍內沒有可鎖定的野怪（最遠約為木槍攻擊距離的 %.1f 倍）。" % GameConstants.WEAPON_THROW_LOCK_RANGE_MULT)
		return
	var cost := GameConstants.WEAPON_SKILL_SATIETY_IRON_SWORD
	if vitals_satiety < cost:
		_show_msg("飽足不足，無法投擲（需至少 %.0f）。" % cost)
		return
	vitals_satiety = maxf(0.0, vitals_satiety - cost)
	_update_vitals_bars_ui()
	var mult := _weapon_skill_damage_multiplier(player_idx)
	var proj := SwordThrowProjectile.new()
	entities.add_child(proj)
	var dist := who.global_position.distance_to(tgt.global_position)
	var travel := clampf(0.09 + dist / 920.0, 0.11, 0.28)
	proj.begin(who.global_position, tgt, travel, 2 * mult)
	GameSfx.play_skill_whoosh(1.12, -2.5)
	_set_weapon_skill_cd(player_idx)


func try_harvest_near(who: PlayerController, player_idx: int) -> void:
	var reach := (
		GameConstants.HARVEST_REACH_P1
		if player_idx == 0
		else GameConstants.HARVEST_REACH_P2
	)
	var my_weapon := inv.equip_main_for(player_idx)
	reach *= _weapon_range_mult(my_weapon)
	var best_mob: Node2D = null
	var best_d_mob := reach + 1.0
	for c in entities.get_children():
		if not (c is Node2D):
			continue
		if not c.is_in_group("melee_monster"):
			continue
		if not c.has_method("take_weapon_hit"):
			continue
		var mob := c as Node2D
		var dm := who.global_position.distance_to(mob.global_position)
		if dm <= reach and dm < best_d_mob:
			best_d_mob = dm
			best_mob = mob
	var best_prop: WorldPropStatic = null
	var best_berry: StaticBody2D = null
	var best_fm: Node2D = null
	var best_d_prop := reach
	var best_d_berry := reach
	var best_d_fm := reach + 1.0
	for c in entities.get_children():
		if c is WorldPropStatic:
			var wp := c as WorldPropStatic
			var d0 := who.global_position.distance_to(wp.global_position)
			if d0 < best_d_prop:
				best_d_prop = d0
				best_prop = wp
		if c is StaticBody2D and c.is_in_group("berry_bush"):
			var bb := c as StaticBody2D
			if not bool(bb.call("is_ripe_for_harvest")):
				continue
			var d1 := who.global_position.distance_to(bb.global_position)
			if d1 < best_d_berry:
				best_d_berry = d1
				best_berry = bb
		if c is Node2D and c.is_in_group("farmland"):
			var fm := c as Node2D
			if not bool(fm.call("is_ripe_for_hand_harvest")):
				continue
			var df := who.global_position.distance_to(fm.global_position)
			if df < best_d_fm:
				best_d_fm = df
				best_fm = fm
	if best_mob == null and best_prop == null and best_berry == null and best_fm == null:
		return
	if best_mob != null:
		if not inv.equip_main_can_chop_tree_for(player_idx):
			_show_msg("需要裝備石斧、木製長槍或石製短劍才能攻擊野怪。")
			return
		var ivm := _weapon_hit_interval(my_weapon)
		if ivm > 0.0:
			var cdm := _p1_weapon_cd if player_idx == 0 else _p2_weapon_cd
			if cdm > 0.0:
				_spawn_weapon_attack_vfx(
					who.global_position, best_mob.global_position, reach, my_weapon, true
				)
				return
		_spawn_weapon_attack_vfx(
			who.global_position, best_mob.global_position, reach, my_weapon, false
		)
		GameSfx.play_attack_chop(1.0, -1.5)
		best_mob.call("take_weapon_hit", 1)
		_satiety_drain_from_action(GameConstants.SATIETY_COST_WEAPON_HIT)
		if ivm > 0.0:
			if player_idx == 0:
				_p1_weapon_cd = ivm
			else:
				_p2_weapon_cd = ivm
		_update_inv_bar()
		return
	if (
		best_fm != null
		and best_d_fm <= reach
		and (best_berry == null or best_d_fm < best_d_berry)
		and (best_prop == null or best_d_fm < best_d_prop)
	):
		var hk: Variant = best_fm.call("try_harvest_crop_hand")
		if hk is StringName and (hk as StringName) != &"":
			_satiety_drain_from_action(GameConstants.SATIETY_COST_HARVEST_HAND)
			var rk: StringName = hk as StringName
			if rk == &"turnip":
				if inv.try_add_item(&"turnip", 1) > 0:
					_show_msg("背包已滿，蕪菁未能入包。")
				else:
					GameSfx.play_pickup(-4.0)
					_show_msg("採收了蕪菁！")
			elif rk == &"tree":
				if inv.try_add_item(&"seed", GameConstants.PLANT_TREE_SEED_COST) > 0:
					_show_msg("背包已滿，樹種未能入包。")
				else:
					GameSfx.play_pickup(-4.0)
					_show_msg("採收了田間樹木作物（退回樹種）。")
			_update_inv_bar()
		return
	if (
		best_berry != null
		and (best_prop == null or best_d_berry <= best_d_prop)
		and (best_fm == null or best_d_berry <= best_d_fm)
	):
		if bool(best_berry.call("try_harvest_hand")):
			_satiety_drain_from_action(GameConstants.SATIETY_COST_HARVEST_HAND)
			GameSfx.play_pickup(-4.0)
			_show_msg("採到了莓果！")
		return
	var best := best_prop
	if best == null:
		return
	if not inv.equip_main_can_chop_tree_for(player_idx):
		if best.prop_kind == WorldPropStatic.PropKind.TREE:
			_show_msg("需要裝備石斧、木製長槍或石製短劍才能砍樹。")
		else:
			_show_msg("需要裝備石斧、木製長槍或石製短劍才能敲碎岩石。")
		return
	var iv := _weapon_hit_interval(my_weapon)
	if iv > 0.0:
		var cd := _p1_weapon_cd if player_idx == 0 else _p2_weapon_cd
		if cd > 0.0:
			_spawn_weapon_attack_vfx(
				who.global_position, best.global_position, reach, my_weapon, true
			)
			return
	_spawn_weapon_attack_vfx(who.global_position, best.global_position, reach, my_weapon, false)
	var pit := 0.9 if best.prop_kind == WorldPropStatic.PropKind.TREE else 1.14
	GameSfx.play_attack_chop(pit, -2.0)
	var res: Dictionary = best.take_hit()
	_satiety_drain_from_action(GameConstants.SATIETY_COST_WEAPON_HIT)
	if iv > 0.0:
		if player_idx == 0:
			_p1_weapon_cd = iv
		else:
			_p2_weapon_cd = iv
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


func _spawn_loose(kind: LoosePickup.PickKind, pos: Vector2, mark_wild: bool = false) -> void:
	var p := _clamp_loose_pickup_pos(pos)
	if _is_protected(p):
		return
	var lp: LoosePickup = _scene_loose.instantiate() as LoosePickup
	lp.pick_kind = kind
	lp.global_position = p
	entities.add_child(lp)
	if mark_wild:
		lp.add_to_group(WILD_REGION_SPAWN_GROUP)


func _show_msg(t: String) -> void:
	msg_label.text = t
	msg_label.visible = true
	_msg_time = 3.2


func _update_inv_bar() -> void:
	if _bottom_hud == null:
		return
	_bottom_hud.refresh(inv, two_player, _build_material_pools())
	_refresh_hotbar_ui()
	_update_hud_build_visual()
	if _campfire_cook_popup != null and _campfire_cook_popup.visible:
		_refresh_campfire_cook_popup()
	if _workbench_craft_popup != null and _workbench_craft_popup.visible:
		_refresh_workbench_craft_popup()
	if _merchant_popup != null and _merchant_popup.visible:
		_refresh_merchant_popup()
	if _instructor_popup != null and _instructor_popup.visible:
		_refresh_instructor_popup()
	_update_vitals_bars_ui()


func _world_has_storage_chest_in_entities() -> bool:
	for c in entities.get_children():
		if c is WorldBuildPiece:
			var wp := c as WorldBuildPiece
			if WorldBuildPiece.piece_kind_has_storage_inventory(wp.piece_kind):
				return true
	return false


func _world_has_workbench_in_entities() -> bool:
	for c in entities.get_children():
		if c is WorldBuildPiece:
			var wp := c as WorldBuildPiece
			if wp.piece_kind == WorldBuildPiece.PieceKind.WORKBENCH:
				return true
	return false


func _quest_current_bbcode() -> String:
	if quest_phase == 1:
		return (
			"[color=#f4c84a]◎ 目標：製作石斧[/color]\n"
			+ "[b]石斧[/b]：初階複合工具，用來砍樹、敲碎岩石採石；之後也能改裝長槍／石製短劍作主手。\n"
			+ "撿拾木材與石頭 → 底部 [b]製作[/b] → 石斧（木 3 · 石 2）"
		)
	elif quest_phase == 2:
		return (
			"[color=#f4c84a]◎ 目標：放置營火[/color]\n"
			+ "[b]營火[/b]：夜晚提供光源與週邊照明；並可在此烹飪（例如莓果乾、烤肉）。\n"
			+ "底部 [b]加工站[/b] → 點「營火」→ 空地 [b]左鍵[/b] 放置（木 5 · 石 3；本區箱子內材料也可一併扣除）"
		)
	elif quest_phase == 3:
		return (
			"[color=#f4c84a]◎ 目標：放置木箱[/color]\n"
			+ "[b]箱子[/b]：把資源集中成堆疊好整理。[b]開箱[/b]時主功能表會自動展開並切到背包，方便拖曳互換。\n"
			+ "[b]一鍵入箱[/b]：把背包裡「箱內已出現過的種類」併入未滿疊或空格（不會把全新種類硬塞進空位）。\n"
			+ "[b]箱格右鍵[/b]：堆疊品可選取出數量，單件則直接取回背包。\n"
			+ "[b]工作台旁[/b]的箱子裡，木材／石頭等也會算進「製作」材料（本階段只要先蓋好一箱即可）。\n"
			+ "底部 [b]建造[/b] → 木箱 → 空地左鍵（木 6；本區箱子內材料也可一併扣除）"
		)
	elif quest_phase == 4:
		return (
			"[color=#f4c84a]◎ 目標：放置工作台[/color]\n"
			+ "[b]工作台[/b]：用來製作各種進階材料與裝備的站台（例如木製長槍、石製短劍）；配方會消耗背包與鄰近一格內箱子裡的材料。\n"
			+ "靠近工作台按互動鍵開啟製作介面；本區木箱內的木材／石頭也會一併計入花費。\n"
			+ "底部 [b]建造[/b] → 工作台 → 空地左鍵（木 %d · 石 %d）"
			% [GameConstants.BUILD_WORKBENCH_WOOD, GameConstants.BUILD_WORKBENCH_STONE]
		)
	else:
		return (
			"[color=#70dd60]✓ 序章進度：探索鄰近區域[/color]\n"
			+ "走進土路傳送帶 → 按 [b]G[/b] 確認（雙人 2P 按 K）\n"
			+ "北 [color=#aad4ff]山麓[/color]  南 [color=#aad4ff]溪谷[/color]  東 [color=#aad4ff]果園[/color]  西 [color=#aad4ff]森林[/color]"
		)


func _update_quest_ui() -> void:
	quest_label.bbcode_enabled = true
	if not _loading_save and quest_phase == 1 and inv.has_axe():
		quest_phase = 2
		_show_msg("太好了！接下來收集木材與石頭，蓋一座營火吧。請用底部面板「加工站」開啟放置營火，再於空地上按左鍵。")
		if not inv.equip_main_can_chop_tree_for(0):
			_show_msg("請用底部面板「裝」將石斧裝到主手（或工作台製作的長槍／石製短劍）才能砍樹與採石。")
	if not _loading_save and quest_phase == 3 and _world_has_storage_chest_in_entities():
		quest_phase = 4
		_show_msg(
			(
				"木箱已就位！接下來請用底部「建造」放置工作台（木 %d、石 %d）："
				+ "可在此合成進階裝備與材料，鄰近箱子裡的資源也會算進配方。"
			)
			% [GameConstants.BUILD_WORKBENCH_WOOD, GameConstants.BUILD_WORKBENCH_STONE]
		)
	if not _loading_save and quest_phase == 4 and _world_has_workbench_in_entities():
		quest_phase = 5
		_show_msg(
			"工作台已就緒！之後可在此製作長槍、石製短劍等。"
			+ " 接著從土路傳送帶探索周邊區域吧。"
		)
	quest_label.text = _quest_current_bbcode()
	if quest_log_popup.visible:
		_refresh_quest_log_popup()


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


## Tiled 物件層名 `spawnpoint`（不分大小寫）內，YATI 會把 point 物件建成 **Marker2D** 子節點。
func _find_tiled_object_layer_ci(root: Node, layer_name_lower: String) -> Node2D:
	if root == null:
		return null
	if root is Node2D and String(root.name).to_lower() == layer_name_lower:
		return root as Node2D
	for c in root.get_children():
		var r := _find_tiled_object_layer_ci(c, layer_name_lower)
		if r != null:
			return r
	return null


## 回傳第一個 Marker2D 的 `global_position`；沒有則 `null`（新地圖可沒設出生點）。
func _tiled_spawn_marker_global(map_root: Node2D) -> Variant:
	if map_root == null:
		return null
	var layer := _find_tiled_object_layer_ci(map_root, "spawnpoint")
	if layer == null:
		return null
	for ch in layer.get_children():
		if ch is Marker2D:
			return (ch as Marker2D).global_position
	return null


func _spawn_initial_room() -> void:
	var sz := get_viewport_rect().size
	_spawn_wild_props_for_region(Vector2i.ZERO, sz)
	var tmap_n := get_node_or_null("DayNightModulate/TiledMap")
	var spot: Variant = null
	if tmap_n is Node2D:
		spot = _tiled_spawn_marker_global(tmap_n as Node2D)
	if spot is Vector2:
		_clamp_party_spawn(spot as Vector2)
	else:
		_clamp_party_spawn(sz * 0.5)


## Tiled 物件層 `resourcezone`：多邊形（YATI → StaticBody2D + CollisionPolygon2D）+ `Resource_Type`（圖層或單物件 meta，可多行／逗號分隔）。
func _parse_resource_type_tags(raw: Variant) -> Array[String]:
	var s := str(raw).strip_edges()
	var out: Array[String] = []
	if s.is_empty():
		return out
	for token in s.replace(",", "\n").split("\n", false):
		var p := token.strip_edges().to_lower()
		if not p.is_empty():
			out.append(p)
	return out


func _resource_zone_tag_aliases(tag: StringName) -> Array[String]:
	var t := String(tag).to_lower()
	match t:
		"wood_chop":
			return ["wood_chop", "tree"]
		"stone_mine":
			return ["stone_mine", "rock"]
		"wood_pickup":
			return ["wood_pickup", "loose_wood"]
		"stone_pickup":
			return ["stone_pickup", "loose_stone"]
		"berry_bush":
			return ["berry_bush", "berry", "berries"]
		_:
			return [t]


func _resource_zone_tags_match_entry(entry_tags: Array[String], tag: StringName) -> bool:
	for a in _resource_zone_tag_aliases(tag):
		if a in entry_tags:
			return true
	return false


func _collision_polygon_global_packed(co: CollisionObject2D) -> PackedVector2Array:
	for child in co.get_children():
		if child is CollisionPolygon2D:
			var cp := child as CollisionPolygon2D
			var xf: Transform2D = cp.global_transform
			var local := cp.polygon
			var out := PackedVector2Array()
			out.resize(local.size())
			for i in local.size():
				out[i] = xf * local[i]
			return out
	return PackedVector2Array()


func _collect_resource_zone_entries(map_root: Node2D) -> Array:
	var out: Array = []
	if map_root == null:
		return out
	var layer := _find_tiled_object_layer_ci(map_root, "resourcezone")
	if layer == null:
		return out
	var layer_tags := _parse_resource_type_tags(layer.get_meta("Resource_Type", ""))
	for ch in layer.get_children():
		if not (ch is CollisionObject2D):
			continue
		var co := ch as CollisionObject2D
		var poly := _collision_polygon_global_packed(co)
		if poly.size() < 3:
			continue
		var tags := layer_tags
		if co.has_meta("Resource_Type"):
			tags = _parse_resource_type_tags(co.get_meta("Resource_Type"))
		if tags.is_empty():
			continue
		out.append({"tags": tags, "poly": poly})
	return out


func _random_point_in_resource_polygon(poly: PackedVector2Array, sz: Vector2) -> Vector2:
	if poly.size() < 3:
		return Vector2.ZERO
	var mn := poly[0]
	var mx := poly[0]
	for i in range(1, poly.size()):
		mn = mn.min(poly[i])
		mx = mx.max(poly[i])
	var bounds := Rect2(mn, mx - mn)
	if bounds.size.x < 2.0 or bounds.size.y < 2.0:
		return Vector2.ZERO
	for _i in 56:
		var p := Vector2(
			randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		)
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		if _is_protected(p, sz):
			continue
		if _spawn_mask_blocks_global_point(p):
			continue
		return p
	return Vector2.ZERO


func _random_point_in_resource_zones(tag: StringName, sz: Vector2) -> Vector2:
	var tmap := get_node_or_null("DayNightModulate/TiledMap")
	if not (tmap is Node2D):
		return Vector2.ZERO
	var entries := _collect_resource_zone_entries(tmap as Node2D)
	var polys: Array[PackedVector2Array] = []
	for e in entries:
		var raw_tags: Variant = e.get("tags", [])
		if not (raw_tags is Array):
			continue
		var entry_tags: Array[String] = []
		for t in raw_tags as Array:
			entry_tags.append(str(t).to_lower())
		if _resource_zone_tags_match_entry(entry_tags, tag):
			polys.append(e["poly"] as PackedVector2Array)
	if polys.is_empty():
		return Vector2.ZERO
	for _attempt in 72:
		var poly: PackedVector2Array = polys[randi() % polys.size()]
		var p := _random_point_in_resource_polygon(poly, sz)
		if p != Vector2.ZERO:
			return p
	return Vector2.ZERO


## 供日後「區內補生／重生」呼叫：有 `resourcezone` 且含 `tag`（或別名）則回傳區內一點，否則回 `Vector2.ZERO`。
func random_point_for_resource_zone_tag(tag: String, sz: Vector2 = Vector2.ZERO) -> Vector2:
	if sz == Vector2.ZERO:
		sz = get_viewport_rect().size
	return _random_point_in_resource_zones(StringName(tag.to_lower()), sz)


func _spawn_one_berry_bush(sz: Vector2, mark_wild: bool = false) -> void:
	var pos := _random_point_in_resource_zones(&"berry_bush", sz)
	if pos == Vector2.ZERO:
		pos = _random_open_pos(sz)
	if pos == Vector2.ZERO:
		pos = _find_berry_bush_spawn_fallback(sz)
	if pos == Vector2.ZERO:
		push_warning("Main: 無法為莓果叢找到可生成位置（地圖遮罩可能過大）。")
		return
	pos = _clamp_loose_pickup_pos(pos)
	var b := StaticBody2D.new()
	b.set_script(_berry_bush_script)
	entities.add_child(b)
	b.global_position = pos
	if mark_wild:
		b.add_to_group(WILD_REGION_SPAWN_GROUP)


func _find_berry_bush_spawn_fallback(sz: Vector2) -> Vector2:
	var center := sz * 0.5
	var m := GameConstants.WORLD_PLAY_MARGIN
	var y_min := maxf(96.0, m)
	for ring in [108.0, 124.0, 142.0, 168.0, 196.0]:
		var steps := maxi(16, int(ring * 0.18))
		for i in steps:
			var ang := TAU * float(i) / float(steps)
			var p: Vector2 = center + Vector2(cos(ang), sin(ang)) * ring
			if p.x < m or p.x > sz.x - m or p.y < y_min or p.y > sz.y - m:
				continue
			if _is_protected(p, sz):
				continue
			if _spawn_mask_blocks_global_point(p):
				continue
			return p
	return Vector2.ZERO


func _spawn_prop(kind: WorldPropStatic.PropKind, sz: Vector2, mark_wild: bool = false) -> void:
	var tag := &"wood_chop" if kind == WorldPropStatic.PropKind.TREE else &"stone_mine"
	var pos := _random_point_in_resource_zones(tag, sz)
	if pos == Vector2.ZERO:
		pos = _random_open_pos(sz)
	if pos == Vector2.ZERO:
		return
	var node: WorldPropStatic = _scene_prop.instantiate() as WorldPropStatic
	node.prop_kind = kind
	node.global_position = pos
	entities.add_child(node)
	if mark_wild:
		node.add_to_group(WILD_REGION_SPAWN_GROUP)


func _spawn_loose_at(kind: LoosePickup.PickKind, sz: Vector2, mark_wild: bool = false) -> void:
	var pos: Vector2
	if kind == LoosePickup.PickKind.WOOD:
		pos = _random_point_in_resource_zones(&"wood_pickup", sz)
	elif kind == LoosePickup.PickKind.STONE:
		pos = _random_point_in_resource_zones(&"stone_pickup", sz)
	else:
		pos = Vector2.ZERO
	if pos == Vector2.ZERO:
		pos = _random_open_pos(sz)
	if pos == Vector2.ZERO:
		return
	pos = _clamp_loose_pickup_pos(pos)
	_spawn_loose(kind, pos, mark_wild)


func _spawn_forest_slime(sz: Vector2, mark_wild: bool = false) -> void:
	var pos := _random_open_pos(sz)
	if pos == Vector2.ZERO:
		return
	pos = _clamp_loose_pickup_pos(pos)
	if _is_protected(pos, sz):
		return
	if _spawn_mask_blocks_global_point(pos):
		return
	var s := ForestSlime.new()
	s.global_position = pos
	entities.add_child(s)
	if mark_wild:
		s.add_to_group(WILD_REGION_SPAWN_GROUP)


func _spawn_forest_mushroom(sz: Vector2, mark_wild: bool = false) -> void:
	var pos := _random_open_pos(sz)
	if pos == Vector2.ZERO:
		return
	pos = _clamp_loose_pickup_pos(pos)
	if _is_protected(pos, sz):
		return
	if _spawn_mask_blocks_global_point(pos):
		return
	var m := ForestMushroom.new()
	m.global_position = pos
	entities.add_child(m)
	if mark_wild:
		m.add_to_group(WILD_REGION_SPAWN_GROUP)


func _clamp_loose_pickup_pos(p: Vector2) -> Vector2:
	var sz := get_viewport_rect().size
	var m := GameConstants.WORLD_PLAY_MARGIN
	var y_min := maxf(96.0, m)
	return Vector2(clampf(p.x, m, sz.x - m), clampf(p.y, y_min, sz.y - m))


func _random_open_pos(sz: Vector2) -> Vector2:
	var m := GameConstants.WORLD_PLAY_MARGIN
	var y_min := maxf(96.0, m)
	for attempt in 200:
		var p := Vector2(randf_range(m, sz.x - m), randf_range(y_min, sz.y - m))
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
