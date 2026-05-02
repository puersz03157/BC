class_name BottomHudController
extends PanelContainer
## 底部四欄：裝備、背包、製作、建造（外觀參考使用者提供的示意圖）。

signal craft_axe_pressed
signal equip_axe_pressed
signal unequip_axe_pressed
signal toggle_campfire_pressed
signal build_floor_pressed
signal build_fence_pressed
signal build_door_pressed
signal dismantle_pressed

const COL_BG := Color(0.1725, 0.2431, 0.3137, 1.0)
const COL_PANEL := Color(0.125, 0.18, 0.24, 1.0)
const COL_BTN := Color(0.2039, 0.5961, 0.8588, 1.0)
const COL_BTN_HOVER := Color(0.26, 0.68, 0.95, 1.0)
const COL_HEADER_BLUE := Color(0.45, 0.72, 0.98, 1.0)
const COL_HEADER_YELLOW := Color(0.945, 0.768, 0.0588, 1.0)
const COL_HEADER_RED := Color(0.905, 0.298, 0.235, 1.0)
const COL_HEADER_ORANGE := Color(0.9725, 0.7059, 0.3843, 1.0)
const COL_TEXT := Color(0.93, 0.94, 0.96, 1.0)
const COL_MUTED := Color(0.62, 0.66, 0.7, 1.0)
const COL_HIGHLIGHT := Color(0.945, 0.768, 0.0588, 1.0)

var _lbl_main: Label
var _lbl_off: Label
var _lbl_armor: Label
var _lbl_acc: Label
var _btn_unequip: Button
var _lbl_wood: Label
var _lbl_stone: Label
var _lbl_seed: Label
var _btn_craft_axe: Button
var _btn_campfire: Button
var _btn_floor: Button
var _btn_fence: Button
var _btn_door: Button
var _btn_dismantle: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style(COL_BG))
	_build()


func _panel_style(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(6)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _btn_style(filled: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = filled
	s.set_corner_radius_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _make_header(text: String, color: Color) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.color = color
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(dot)
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", color)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(t)
	return hb


func _build() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 10)
	root.add_theme_constant_override("margin_right", 10)
	root.add_theme_constant_override("margin_top", 8)
	root.add_theme_constant_override("margin_bottom", 8)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var outer := PanelContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_STOP
	outer.add_theme_stylebox_override("panel", _panel_style(COL_PANEL))
	root.add_child(outer)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	outer.add_child(h)
	h.add_child(_build_equipment_column())
	h.add_child(_vsep())
	h.add_child(_build_backpack_column())
	h.add_child(_vsep())
	h.add_child(_build_craft_column())
	h.add_child(_vsep())
	h.add_child(_build_build_column())


func _vsep() -> Control:
	var s := ColorRect.new()
	s.custom_minimum_size = Vector2(1, 1)
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.color = Color(0.25, 0.32, 0.4, 0.9)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _build_equipment_column() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.custom_minimum_size = Vector2(200, 0)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.add_child(_make_header("裝備", COL_HEADER_BLUE))
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	var l1 := Label.new()
	l1.text = "主手"
	l1.add_theme_font_size_override("font_size", 13)
	l1.add_theme_color_override("font_color", COL_MUTED)
	row1.add_child(l1)
	_lbl_main = Label.new()
	_lbl_main.add_theme_font_size_override("font_size", 14)
	_lbl_main.add_theme_color_override("font_color", COL_HIGHLIGHT)
	_lbl_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(_lbl_main)
	_btn_unequip = Button.new()
	_btn_unequip.text = "脫"
	_btn_unequip.flat = true
	_btn_unequip.add_theme_font_size_override("font_size", 12)
	_btn_unequip.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	_btn_unequip.custom_minimum_size = Vector2(32, 26)
	_btn_unequip.pressed.connect(func() -> void: unequip_axe_pressed.emit())
	row1.add_child(_btn_unequip)
	vb.add_child(row1)
	_lbl_off = _line_label_value("無")
	vb.add_child(_wrap_kv("副手", _lbl_off))
	_lbl_armor = _line_label_value("便服")
	vb.add_child(_wrap_kv("防具", _lbl_armor))
	_lbl_acc = _line_label_value("無")
	vb.add_child(_wrap_kv("飾品", _lbl_acc))
	return vb


func _line_label_value(val: String) -> Label:
	var lb := Label.new()
	lb.text = val
	lb.add_theme_font_size_override("font_size", 13)
	lb.add_theme_color_override("font_color", COL_TEXT)
	return lb


func _wrap_kv(key: String, value_label: Label) -> HBoxContainer:
	var hb := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(40, 0)
	k.add_theme_font_size_override("font_size", 13)
	k.add_theme_color_override("font_color", COL_MUTED)
	hb.add_child(k)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(value_label)
	return hb


func _build_backpack_column() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.custom_minimum_size = Vector2(220, 0)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.add_child(_make_header("背包與技能", COL_HEADER_YELLOW))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 120)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_STOP
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 4)
	sc.add_child(inner)
	_lbl_wood = _add_resource_row(inner, "木材")
	_lbl_stone = _add_resource_row(inner, "石頭")
	_lbl_seed = _add_resource_row(inner, "樹種")
	var row_axe := HBoxContainer.new()
	row_axe.add_theme_constant_override("separation", 6)
	var ax := Label.new()
	ax.text = "石斧（備用）"
	ax.add_theme_font_size_override("font_size", 13)
	ax.add_theme_color_override("font_color", COL_TEXT)
	ax.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_axe.add_child(ax)
	var b_eq := Button.new()
	b_eq.text = "裝"
	b_eq.flat = true
	b_eq.add_theme_font_size_override("font_size", 12)
	b_eq.add_theme_color_override("font_color", COL_HEADER_BLUE)
	b_eq.custom_minimum_size = Vector2(36, 26)
	b_eq.pressed.connect(func() -> void: equip_axe_pressed.emit())
	row_axe.add_child(b_eq)
	inner.add_child(row_axe)
	vb.add_child(sc)
	return vb


func _add_resource_row(parent: VBoxContainer, name_zh: String) -> Label:
	var hb := HBoxContainer.new()
	var nm := Label.new()
	nm.text = name_zh
	nm.add_theme_font_size_override("font_size", 13)
	nm.add_theme_color_override("font_color", COL_TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(nm)
	var qty := Label.new()
	qty.text = "0"
	qty.add_theme_font_size_override("font_size", 13)
	qty.add_theme_color_override("font_color", COL_HIGHLIGHT)
	hb.add_child(qty)
	parent.add_child(hb)
	return qty


func _build_craft_column() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.custom_minimum_size = Vector2(200, 0)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.add_child(_make_header("製作工具", COL_HEADER_RED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_btn_craft_axe = _craft_button("石斧", "%d木,%d石" % [GameConstants.CRAFT_AXE_WOOD, GameConstants.CRAFT_AXE_STONE])
	_btn_craft_axe.pressed.connect(func() -> void: craft_axe_pressed.emit())
	grid.add_child(_btn_craft_axe)
	_btn_campfire = _craft_button("營火", "%d木,%d石" % [GameConstants.CAMPFIRE_WOOD, GameConstants.CAMPFIRE_STONE])
	_btn_campfire.pressed.connect(func() -> void: toggle_campfire_pressed.emit())
	grid.add_child(_btn_campfire)
	var wb := _craft_button("工作台", "未開放")
	wb.disabled = true
	grid.add_child(wb)
	vb.add_child(grid)
	return vb


func _craft_button(title: String, cost: String) -> Button:
	var b := Button.new()
	b.flat = false
	b.add_theme_stylebox_override("normal", _btn_style(COL_BTN))
	b.add_theme_stylebox_override("hover", _btn_style(COL_BTN_HOVER))
	b.add_theme_stylebox_override("pressed", _btn_style(COL_BTN.darkened(0.08)))
	b.add_theme_stylebox_override("disabled", _btn_style(COL_BTN.darkened(0.35)))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_font_size_override("font_size", 13)
	b.text = "%s\n(%s)" % [title, cost]
	b.custom_minimum_size = Vector2(92, 56)
	return b


func _build_build_column() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.custom_minimum_size = Vector2(200, 0)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.add_child(_make_header("建築工事", COL_HEADER_ORANGE))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_btn_floor = _craft_button("木地板", "%d木" % GameConstants.BUILD_FLOOR_WOOD)
	_btn_floor.pressed.connect(func() -> void: build_floor_pressed.emit())
	grid.add_child(_btn_floor)
	_btn_fence = _craft_button("木牆", "%d木" % GameConstants.BUILD_FENCE_WOOD)
	_btn_fence.pressed.connect(func() -> void: build_fence_pressed.emit())
	grid.add_child(_btn_fence)
	_btn_door = _craft_button("木門", "%d木" % GameConstants.BUILD_DOOR_WOOD)
	_btn_door.pressed.connect(func() -> void: build_door_pressed.emit())
	grid.add_child(_btn_door)
	vb.add_child(grid)
	_btn_dismantle = Button.new()
	_btn_dismantle.text = "拆除（回收）"
	_btn_dismantle.add_theme_stylebox_override("normal", _btn_style(Color(0.7529, 0.2235, 0.1686, 1.0)))
	_btn_dismantle.add_theme_stylebox_override("hover", _btn_style(Color(0.85, 0.3, 0.22, 1.0)))
	_btn_dismantle.add_theme_color_override("font_color", Color.WHITE)
	_btn_dismantle.add_theme_font_size_override("font_size", 14)
	_btn_dismantle.pressed.connect(func() -> void: dismantle_pressed.emit())
	vb.add_child(_btn_dismantle)
	return vb


func refresh(inv: GameInventory) -> void:
	if _lbl_main == null:
		return
	var main_txt := "無"
	if inv.equip_main == &"axe":
		main_txt = "石斧"
	_lbl_main.text = main_txt
	_btn_unequip.visible = inv.equip_main == &"axe"
	_lbl_off.text = "無"
	_lbl_armor.text = "便服"
	_lbl_acc.text = "無"
	_lbl_wood.text = str(inv.wood)
	_lbl_stone.text = str(inv.stone)
	_lbl_seed.text = str(inv.seed)
	var can_pay_axe := inv.wood >= GameConstants.CRAFT_AXE_WOOD and inv.stone >= GameConstants.CRAFT_AXE_STONE
	_btn_craft_axe.disabled = not can_pay_axe
	if inv.has_axe() and inv.equip_main == &"axe":
		_btn_craft_axe.text = "石斧\n(主手✓)"
	elif inv.axe_spare > 0:
		_btn_craft_axe.text = "石斧\n(備用×%d)" % inv.axe_spare
	else:
		_btn_craft_axe.text = "石斧\n(%d木,%d石)" % [GameConstants.CRAFT_AXE_WOOD, GameConstants.CRAFT_AXE_STONE]
	_btn_campfire.disabled = not inv.can_place_campfire()
	_btn_floor.disabled = inv.wood < GameConstants.BUILD_FLOOR_WOOD
	_btn_fence.disabled = inv.wood < GameConstants.BUILD_FENCE_WOOD
	_btn_door.disabled = inv.wood < GameConstants.BUILD_DOOR_WOOD


func set_build_mode_visual(campfire_placing: bool, floor_m: bool, fence_m: bool, door_m: bool, dismantle_m: bool) -> void:
	_sel_glow(_btn_campfire, campfire_placing)
	_sel_glow(_btn_floor, floor_m)
	_sel_glow(_btn_fence, fence_m)
	_sel_glow(_btn_door, door_m)
	_sel_glow(_btn_dismantle, dismantle_m)


func _sel_glow(b: Button, on: bool) -> void:
	if b == null:
		return
	b.modulate = Color(1.22, 1.12, 0.88, 1.0) if on else Color.WHITE
