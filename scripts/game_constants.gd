class_name GameConstants
extends RefCounted
## 與網頁版對齊的常數（grid、初始房間資源量）

## 背包：初始格數與每格堆疊上限（之後可於存檔／升級系統擴充）。
const INVENTORY_SLOT_COUNT_DEFAULT := 24
const INVENTORY_STACK_LIMIT_DEFAULT := 30

const GRID_SIZE := 40
const TREE_HP := 3
const ROCK_HP := 5
const TREE_RADIUS := 20.0
const ROCK_RADIUS := 15.0
const LOOSE_RADIUS := 8.0

const INIT_TREES := 30
const INIT_ROCKS := 15
const INIT_LOOSE_WOOD := 15
const INIT_LOOSE_STONE := 10

## 各區「首次進入」時生成的野生資源數量（樹／石／地上拾取／莓果叢）；之後固定於存檔，過圖不再重隨機。
const REGION_NORTH_TREES := 6
const REGION_NORTH_ROCKS := 38
const REGION_NORTH_LOOSE_WOOD := 6
const REGION_NORTH_LOOSE_STONE := 22
const REGION_NORTH_BERRY_BUSHES := 1

const REGION_ORCHARD_TREES := 10
const REGION_ORCHARD_ROCKS := 6
const REGION_ORCHARD_LOOSE_WOOD := 10
const REGION_ORCHARD_LOOSE_STONE := 6
const REGION_ORCHARD_BERRY_BUSHES := 7

const REGION_FOREST_TREES := 52
const REGION_FOREST_ROCKS := 6
const REGION_FOREST_LOOSE_WOOD := 18
const REGION_FOREST_LOOSE_STONE := 8
const REGION_FOREST_BERRY_BUSHES := 2

const CRAFT_AXE_WOOD := 3
const CRAFT_AXE_STONE := 2
const CAMPFIRE_WOOD := 5
const CAMPFIRE_STONE := 3
const CAMPFIRE_COLLISION_RADIUS := 14.0
## 營火快速烹飪：莓果 → 莓果干。
const CAMPFIRE_COOK_BERRY_COST := 3
## 食用莓果干：小幅飽足與生命恢復。
const JERKY_SATIETY_RESTORE := 14.0
const JERKY_HP_RESTORE := 10.0
## 營火：肉排 → 烤肉（強化食用）。
const CAMPFIRE_COOK_MEAT_COST := 1
const BBQ_MEAT_SATIETY_RESTORE := 22.0
const BBQ_MEAT_HP_RESTORE := 16.0
## 工作台：黏黏護甲（皮革×2、黏液×2）。
const CRAFT_STICKY_ARMOR_LEATHER := 2
const CRAFT_STICKY_ARMOR_SLIME := 2
## 左鍵點營火開選單時，游標與營火中心的容許距離（像素）。
const CAMPFIRE_COOK_CLICK_RADIUS := 30.0
## 左鍵點工作台開製作選單：游標與工作台中心的容許距離（像素）。
const WORKBENCH_CLICK_RADIUS := 28.0

const BUILD_FLOOR_WOOD := 1
const BUILD_FENCE_WOOD := 2
const BUILD_DOOR_WOOD := 3
const BUILD_WORKBENCH_WOOD := 8
const BUILD_WORKBENCH_STONE := 4
## 木箱：12 格、堆疊 30（與一般背包格堆疊一致時仍獨立於箱子上限）。
const CHEST_SLOT_COUNT := 12
const CHEST_STACK_LIMIT := 30
const BUILD_CHEST_WOOD := 6
## 種樹消耗樹種數。
const PLANT_TREE_SEED_COST := 1

## 工作台製作（僅在工作台 UI 使用）。
const CRAFT_SPEAR_WOOD := 10
const CRAFT_SPEAR_STONE := 2
const CRAFT_SWORD_WOOD := 3
const CRAFT_SWORD_STONE := 5
## 主手近戰：長槍較遠、較慢；短劍較近、較快（秒）。
const WEAPON_SPEAR_RANGE_MULT := 1.48
const WEAPON_SPEAR_HIT_INTERVAL := 0.58
const WEAPON_SWORD_RANGE_MULT := 0.92
const WEAPON_SWORD_HIT_INTERVAL := 0.26
## 武器技能：共用冷卻（秒）；木槍圓形 AOE／鐵劍投擲。
const WEAPON_SKILL_COOLDOWN := 1.45
## 使用技能消耗的飽足度（主手為該武器時才可施放）。
const WEAPON_SKILL_SATIETY_SPEAR := 15.0
const WEAPON_SKILL_SATIETY_IRON_SWORD := 13.0
## 鐵劍投擲鎖定最遠距離＝（木槍有效採集距離）× 此倍率。
const WEAPON_THROW_LOCK_RANGE_MULT := 1.5

## 翠幽之森（西區）野怪數量（上限）；每過一個遊戲日曆日補少量，多日離線不會超過此上限。
const REGION_FOREST_SLIMES := 5
const REGION_FOREST_BOARS := 3
## 每遊戲日曆日各補幾隻（至 REGION_* 上限為止）；離開森林時延後生成，進森林再一次落地。
const FOREST_SLIME_RESPAWN_PER_GAME_DAY := 1
const FOREST_BOAR_RESPAWN_PER_GAME_DAY := 1

const PLAYER_SPEED := 270.0
const P2_SPEED := 270.0
## 角色技能：短衝刺（E／雙人時 2P 為 K）；蓄力／鐵壁共用此冷卻。
const CHARACTER_DASH_SPEED := 520.0
const CHARACTER_DASH_DURATION_SEC := 0.11
const CHARACTER_DASH_COOLDOWN_SEC := 2.25
## 鐵壁：減傷持續秒數（共用生命條時依「受傷者」判定是否啟用）。
const CHARACTER_IRON_WALL_DURATION_SEC := 5.0
## 溪谷商人：蕪菁種子售價；單項資源每日收購上限；高價品倍率；交易幾次後每 +1 種收購（自 3 種起至 5 種）。
const MERCHANT_TURNIP_SEED_PRICE := 14
const MERCHANT_DAILY_BUY_CAP_PER_TYPE := 5
const MERCHANT_PREMIUM_PRICE_MULT := 2.0
const MERCHANT_EXTRA_TYPE_EVERY_N_TRADES := 8
## 教官技能書（買斷解鎖）。
const INSTRUCTOR_BOOK_CHARGE_PRICE := 95
const INSTRUCTOR_BOOK_IRON_WALL_PRICE := 95
const HARVEST_REACH_P1 := 70.0
const HARVEST_REACH_P2 := 70.0
const INTERACT_REACH := 80.0
## 水邊交互裝水：身上同一時間最多攜帶份數（水源不枯竭）。
const WATER_CARRY_MAX := 10
## 工作台製「土」：木＋黏液（不需特定主手）。
const CRAFT_DIRT_WOOD := 2
const CRAFT_DIRT_SLIME := 1
## 建造一格耕地消耗土堆數。
const BUILD_FARMLAND_DIRT := 2
## 耕地作物階段：1 為剛種下，達此值（含）可採收。
const FARMLAND_RIPE_STAGE := 4
## 掉落物／生成點距離畫面邊界至少此值（略大於牆厚＋採集距離），避免貼牆吸不到。
const WORLD_PLAY_MARGIN := 64.0
## 區域傳送：四向道路口附近的偵測帶（像素，相對畫面內側）。
const REGION_PORTAL_BAND := 36.0
const REGION_PORTAL_HALF_WIDTH := 88.0
const REGION_PORTAL_INSET := 48.0
## 已廢止：飽足度不再隨時間遞減（保留 0 供舊邏輯相容）。
const SATIETY_DECAY_PER_SEC := 0.0
## 飽足度：共享條，由行為消耗（移動／採集／攻擊／技能）。
## 每名玩家各自在移動時每秒額外扣（雙人同時跑則兩段各扣）。
const SATIETY_COST_MOVE_PER_SEC := 0.10
## 徒手採收類（莓果、徒手收耕作物等，成功一次）。
const SATIETY_COST_HARVEST_HAND := 1.65
## 主手敲擊（野怪／樹／石等，成功命中結算一次）。
const SATIETY_COST_WEAPON_HIT := 2.1
## 角色技能成功施放：衝刺／蓄力／鐵壁。
const SATIETY_COST_CHAR_DASH := 2.4
const SATIETY_COST_CHAR_CHARGE := 4.8
const SATIETY_COST_CHAR_IRON_WALL := 7.5
## 快捷欄生吃莓果的飽足恢復。
const RAW_BERRY_SATIETY := 6.0
## 快捷欄／營火食用生肉排（弱於烤肉）。
const RAW_MEAT_SATIETY := 10.0
const RAW_MEAT_HP := 6.0

## 日夜：phase 0=子夜、0.25=拂曉、0.5=正午、0.75=黃昏。僅在「慢相」區間內相位走得慢（白天感），其餘為夜（快）。
const DAY_CYCLE_BASE_SEC := 300.0
const DAY_SLOW_PHASE_START := 0.17
const DAY_SLOW_PHASE_END := 0.78
const DAY_PHASE_ADVANCE_MULT := 0.38
const NIGHT_PHASE_ADVANCE_MULT := 2.05
## 日照量（與 Main.day_brightness 相同）低於此值時，溪谷村落 NPC 隱藏（假裝已回屋就寢）；拂曉後再出現。
const VALLEY_NPC_HIDE_BELOW_BRIGHTNESS := 0.33
