class_name BottomHudController
extends PanelContainer
## 底部四欄：裝備、背包、製作、建造。頂部可一鍵收合整條 HUD；製作／建造欄內為可折疊分類。

signal hud_minimized_changed(is_minimized: bool)
signal craft_axe_pressed
signal unequip_axe_pressed
signal unequip_main_p2_pressed
signal toggle_campfire_pressed
signal build_floor_pressed
signal build_fence_pressed
signal build_door_pressed
signal build_workbench_pressed
signal build_chest_pressed
signal build_farmland_pressed
signal plant_tree_pressed
signal plant_turnip_pressed
signal unequip_armor_pressed
## 背包格右鍵：由 Main 開選單（裝備／指派快捷鍵）。
signal backpack_slot_context_requested(slot_index: int, screen_pos: Vector2)
## 背包拖曳合併／換格後（供 Main 刷新與存檔）。
signal backpack_inventory_drag_changed
## 木箱拖曳或與背包互換後。
signal chest_inventory_changed

const COL_BG := Color(0.1725, 0.2431, 0.3137, 0.82)
const COL_PANEL := Color(0.125, 0.18, 0.24, 0.78)
const COL_BTN := Color(0.2039, 0.5961, 0.8588, 1.0)
const COL_BTN_HOVER := Color(0.26, 0.68, 0.95, 1.0)
const COL_HEADER_BLUE := Color(0.45, 0.72, 0.98, 1.0)
const COL_HEADER_YELLOW := Color(0.945, 0.768, 0.0588, 1.0)
const COL_HEADER_RED := Color(0.905, 0.298, 0.235, 1.0)
const COL_HEADER_ORANGE := Color(0.9725, 0.7059, 0.3843, 1.0)
const COL_TEXT := Color(0.93, 0.94, 0.96, 1.0)
const COL_MUTED := Color(0.62, 0.66, 0.7, 1.0)
const COL_HIGHLIGHT := Color(0.945, 0.768, 0.0588, 1.0)

var _hdr_1p_main: Label
var _lbl_main: Label
var _lbl_off: Label
var _lbl_armor: Label
var _lbl_acc: Label
var _btn_unequip: Button
## 已改為僅格狀背包，總量標籤不再建立（保留欄位避免 refresh 大改結構）。
var _lbl_wood: Label = null
var _lbl_stone: Label = null
var _lbl_dirt: Label = null
var _lbl_berries: Label = null
var _lbl_berry_jerky: Label = null
var _lbl_seed: Label = null
var _lbl_water: Label = null
var _lbl_slime: Label = null
var _lbl_leather: Label = null
var _lbl_meat_cutlet: Label = null
var _lbl_bbq_meat: Label = null
var _lbl_turnip_seeds: Label = null
var _lbl_turnip: Label = null
## 背包分格 UI（長度＝ INVENTORY_SLOT_COUNT_DEFAULT）。
var _inv_slot_icons: Array[TextureRect] = []
var _inv_slot_qty: Array[Label] = []
var _inv_slot_cells: Array[PanelContainer] = []
var _inv_slot_sb_base: Array[StyleBoxFlat] = []
var _inv_slot_sb_hover: Array[StyleBoxFlat] = []
var _inv_slot_dots: Array[Label] = []
var _inv_drag_from: int = -1
var _inv_ref: GameInventory = null
var _two_player_ref: bool = false
## 木箱 UI
var _chest_root: Control = null
var _chest_inv_ref: GameInventory = null
var _chest_drag_from: int = -1
var _chest_slot_cells: Array[PanelContainer] = []
var _chest_slot_icons: Array[TextureRect] = []
var _chest_slot_qty: Array[Label] = []
var _chest_slot_sb_base: Array[StyleBoxFlat] = []
var _chest_slot_sb_hover: Array[StyleBoxFlat] = []
var _chest_slot_dots: Array[Label] = []
var _btn_chest: Button = null
var _ico_armor: TextureRect
var _btn_unequip_armor: Button
var _btn_craft_axe: Button
var _btn_campfire: Button
var _btn_floor: Button
var _btn_fence: Button
var _btn_door: Button
var _btn_workbench: Button
var _btn_farmland: Button
var _btn_plant_tree: Button
var _btn_plant_turnip: Button
var _dismantle_glow_btn: Button

var _ico_equip_main: TextureRect
var _row_p2_equip: Control
var _ico_equip_main_p2: TextureRect
var _lbl_main_p2: Label
var _btn_unequip_p2: Button

var _btn_hud_toggle: Button
var _main_body: MarginContainer
var _hud_minimized: bool = false
var _lbl_craft_axe_state: Label

var _tab_buttons: Array[Button] = []
var _tab_panels: Array[Control] = []
var _active_tab: int = 0


func bind_dismantle_glow_button(btn: Button) -> void:
	_dismantle_glow_btn = btn


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


func _backpack_slot_stylebox(bg: Color, border_col: Color = Color.TRANSPARENT, border_w: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(7)
	s.content_margin_left = 5
	s.content_margin_right = 5
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	if border_w > 0:
		s.border_color = border_col
		s.set_border_width_all(border_w)
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


func is_hud_minimized() -> bool:
	return _hud_minimized


func _toggle_hud_minimize() -> void:
	_hud_minimized = not _hud_minimized
	_main_body.visible = not _hud_minimized
	_btn_hud_toggle.text = "▶ 展開" if _hud_minimized else "▼ 收合"
	hud_minimized_changed.emit(_hud_minimized)


## 可折疊小節：回傳內容容器，請把按鈕／網格加在內。
func _install_collapsible_section(
	parent: VBoxContainer, title_zh: String, accent: Color, start_open: bool
) -> VBoxContainer:
	var block := VBoxContainer.new()
	var hdr := Button.new()
	hdr.flat = true
	hdr.focus_mode = Control.FOCUS_NONE
	hdr.alignment = HORIZONTAL_ALIGNMENT_LEFT
	hdr.add_theme_font_size_override("font_size", 14)
	hdr.add_theme_color_override("font_color", accent)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.visible = start_open
	var open_pfx := "▼ "
	var closed_pfx := "▶ "
	hdr.text = (open_pfx if start_open else closed_pfx) + title_zh
	hdr.pressed.connect(
		func() -> void:
			body.visible = not body.visible
			hdr.text = (open_pfx if body.visible else closed_pfx) + title_zh
	)
	block.add_child(hdr)
	block.add_child(body)
	parent.add_child(block)
	return body


func _hud_icon_rect(path: String, px: Vector2 = Vector2(18, 18)) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = HudItemIcons.tex(path)
	tr.custom_minimum_size = px
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


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
	var main_v := VBoxContainer.new()
	main_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_v.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(main_v)

	var chrome := HBoxContainer.new()
	chrome.add_theme_constant_override("separation", 8)
	var title_lbl := Label.new()
	title_lbl.text = "主功能表"
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", COL_MUTED)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_child(title_lbl)
	_btn_hud_toggle = Button.new()
	_btn_hud_toggle.flat = true
	_btn_hud_toggle.focus_mode = Control.FOCUS_NONE
	_btn_hud_toggle.text = "▼ 收合"
	_btn_hud_toggle.add_theme_font_size_override("font_size", 13)
	_btn_hud_toggle.add_theme_color_override("font_color", COL_HEADER_BLUE)
	_btn_hud_toggle.pressed.connect(_toggle_hud_minimize)
	chrome.add_child(_btn_hud_toggle)
	main_v.add_child(chrome)

	_main_body = MarginContainer.new()
	_main_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_body.add_theme_constant_override("margin_left", 6)
	_main_body.add_theme_constant_override("margin_right", 6)
	_main_body.add_theme_constant_override("margin_top", 2)
	_main_body.add_theme_constant_override("margin_bottom", 6)
	_main_body.mouse_filter = Control.MOUSE_FILTER_STOP
	main_v.add_child(_main_body)

	var body_vb := VBoxContainer.new()
	body_vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vb.add_theme_constant_override("separation", 0)
	body_vb.mouse_filter = Control.MOUSE_FILTER_STOP
	_main_body.add_child(body_vb)

	# ── Tab bar ──────────────────────────────────────────
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 3)
	tab_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	body_vb.add_child(tab_bar)

	# ── Content panel ────────────────────────────────────
	var content_panel := PanelContainer.new()
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	content_panel.add_theme_stylebox_override("panel", _panel_style(COL_PANEL))
	body_vb.add_child(content_panel)

	# Stacked container — all tab panels overlap, only one visible
	var stack := Control.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_STOP
	content_panel.add_child(stack)

	# ── Build each tab ───────────────────────────────────
	var tab_labels := ["⚔ 裝備", "🎒 背包", "🔨 製作", "🏗 建造"]
	var tab_colors: Array[Color] = [COL_HEADER_BLUE, COL_HEADER_YELLOW, COL_HEADER_RED, COL_HEADER_ORANGE]
	var tab_contents: Array[Control] = [
		_build_equipment_column(),
		_build_backpack_column(),
		_build_craft_column(),
		_build_build_column(),
	]

	for i in tab_labels.size():
		var btn := Button.new()
		btn.text = tab_labels[i]
		btn.flat = false
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 13)
		tab_bar.add_child(btn)
		_tab_buttons.append(btn)

		var panel := tab_contents[i]
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.visible = (i == 0)
		stack.add_child(panel)
		_tab_panels.append(panel)

		var idx := i
		btn.pressed.connect(func() -> void: _switch_tab(idx))

	_update_tab_visuals()
	_build_chest_overlay()


func _vsep() -> Control:
	var s := ColorRect.new()
	s.custom_minimum_size = Vector2(1, 1)
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.color = Color(0.25, 0.32, 0.4, 0.9)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _switch_tab(idx: int) -> void:
	_active_tab = idx
	for i in _tab_panels.size():
		_tab_panels[i].visible = (i == idx)
	_update_tab_visuals()


func _update_tab_visuals() -> void:
	var tab_colors: Array[Color] = [COL_HEADER_BLUE, COL_HEADER_YELLOW, COL_HEADER_RED, COL_HEADER_ORANGE]
	for i in _tab_buttons.size():
		var btn := _tab_buttons[i]
		var c := tab_colors[i]
		if i == _active_tab:
			var s := StyleBoxFlat.new()
			s.bg_color = c.darkened(0.52)
			s.set_corner_radius_all(5)
			s.border_width_bottom = 2
			s.border_color = c
			s.content_margin_left = 8
			s.content_margin_right = 8
			s.content_margin_top = 5
			s.content_margin_bottom = 5
			btn.add_theme_stylebox_override("normal", s)
			btn.add_theme_stylebox_override("hover", s)
			btn.add_theme_stylebox_override("pressed", s)
			btn.add_theme_color_override("font_color", c)
		else:
			var s := StyleBoxFlat.new()
			s.bg_color = Color(0.09, 0.13, 0.18, 0.55)
			s.set_corner_radius_all(5)
			s.content_margin_left = 8
			s.content_margin_right = 8
			s.content_margin_top = 5
			s.content_margin_bottom = 5
			btn.add_theme_stylebox_override("normal", s)
			var sh := s.duplicate() as StyleBoxFlat
			sh.bg_color = Color(0.14, 0.19, 0.27, 0.8)
			btn.add_theme_stylebox_override("hover", sh)
			btn.add_theme_stylebox_override("pressed", sh)
			btn.add_theme_color_override("font_color", COL_MUTED)


func _build_equipment_column() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	var l1 := Label.new()
	l1.text = "主手"
	l1.add_theme_font_size_override("font_size", 13)
	l1.add_theme_color_override("font_color", COL_MUTED)
	_hdr_1p_main = l1
	row1.add_child(l1)
	_ico_equip_main = _hud_icon_rect(HudItemIcons.MAIN_EMPTY, Vector2(20, 20))
	row1.add_child(_ico_equip_main)
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
	var row_p2 := HBoxContainer.new()
	row_p2.add_theme_constant_override("separation", 6)
	row_p2.visible = false
	_row_p2_equip = row_p2
	var l1p := Label.new()
	l1p.text = "2P 主手"
	l1p.add_theme_font_size_override("font_size", 13)
	l1p.add_theme_color_override("font_color", COL_MUTED)
	row_p2.add_child(l1p)
	_ico_equip_main_p2 = _hud_icon_rect(HudItemIcons.MAIN_EMPTY, Vector2(20, 20))
	row_p2.add_child(_ico_equip_main_p2)
	_lbl_main_p2 = Label.new()
	_lbl_main_p2.add_theme_font_size_override("font_size", 14)
	_lbl_main_p2.add_theme_color_override("font_color", COL_HIGHLIGHT)
	_lbl_main_p2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_p2.add_child(_lbl_main_p2)
	_btn_unequip_p2 = Button.new()
	_btn_unequip_p2.text = "脫"
	_btn_unequip_p2.flat = true
	_btn_unequip_p2.add_theme_font_size_override("font_size", 12)
	_btn_unequip_p2.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	_btn_unequip_p2.custom_minimum_size = Vector2(32, 26)
	_btn_unequip_p2.pressed.connect(func() -> void: unequip_main_p2_pressed.emit())
	row_p2.add_child(_btn_unequip_p2)
	vb.add_child(row_p2)
	_lbl_off = _line_label_value("無")
	vb.add_child(_wrap_kv_icon(HudItemIcons.OFFHAND_NONE, "副手", _lbl_off))
	var row_armor := HBoxContainer.new()
	row_armor.add_theme_constant_override("separation", 6)
	var la := Label.new()
	la.text = "防具"
	la.add_theme_font_size_override("font_size", 13)
	la.add_theme_color_override("font_color", COL_MUTED)
	row_armor.add_child(la)
	_ico_armor = _hud_icon_rect(HudItemIcons.ARMOR_DEFAULT, Vector2(20, 20))
	row_armor.add_child(_ico_armor)
	_lbl_armor = Label.new()
	_lbl_armor.add_theme_font_size_override("font_size", 14)
	_lbl_armor.add_theme_color_override("font_color", COL_HIGHLIGHT)
	_lbl_armor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_armor.text = "便服"
	row_armor.add_child(_lbl_armor)
	_btn_unequip_armor = Button.new()
	_btn_unequip_armor.text = "脫"
	_btn_unequip_armor.flat = true
	_btn_unequip_armor.add_theme_font_size_override("font_size", 12)
	_btn_unequip_armor.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	_btn_unequip_armor.custom_minimum_size = Vector2(32, 26)
	_btn_unequip_armor.pressed.connect(func() -> void: unequip_armor_pressed.emit())
	row_armor.add_child(_btn_unequip_armor)
	vb.add_child(row_armor)
	_lbl_acc = _line_label_value("無")
	vb.add_child(_wrap_kv_icon(HudItemIcons.ACCESSORY_NONE, "飾品", _lbl_acc))
	return vb


func _line_label_value(val: String) -> Label:
	var lb := Label.new()
	lb.text = val
	lb.add_theme_font_size_override("font_size", 13)
	lb.add_theme_color_override("font_color", COL_TEXT)
	return lb


func _wrap_kv_icon(icon_path: String, key: String, value_label: Label) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(_hud_icon_rect(icon_path, Vector2(18, 18)))
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(36, 0)
	k.add_theme_font_size_override("font_size", 13)
	k.add_theme_color_override("font_color", COL_MUTED)
	hb.add_child(k)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(value_label)
	return hb


func _build_backpack_column() -> Control:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_STOP
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 6)
	outer.mouse_filter = Control.MOUSE_FILTER_STOP
	sc.add_child(outer)

	var slot_grid := GridContainer.new()
	slot_grid.columns = 8
	slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_grid.add_theme_constant_override("h_separation", 8)
	slot_grid.add_theme_constant_override("v_separation", 8)
	_inv_slot_icons.clear()
	_inv_slot_qty.clear()
	_inv_slot_cells.clear()
	_inv_slot_sb_base.clear()
	_inv_slot_sb_hover.clear()
	_inv_slot_dots.clear()
	## 空格：清晰可見，讓玩家能數出剩餘空間。
	var COL_SLOT_EMPTY_BG   := Color(0.08, 0.11, 0.17, 0.96)
	var COL_SLOT_EMPTY_BDR  := Color(0.38, 0.48, 0.62, 0.92)
	## 有物品：明顯亮邊框區分。
	var COL_SLOT_FULL_BG    := Color(0.14, 0.20, 0.30, 0.96)
	var COL_SLOT_FULL_BDR   := Color(0.45, 0.65, 0.90, 0.85)
	var COL_SLOT_HOVER_BDR  := Color(0.65, 0.82, 1.00, 0.95)
	for slot_idx in GameConstants.INVENTORY_SLOT_COUNT_DEFAULT:
		var cell := PanelContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.focus_mode = Control.FOCUS_NONE
		cell.custom_minimum_size = Vector2(66, 62)
		var sb_base := _backpack_slot_stylebox(COL_SLOT_EMPTY_BG, COL_SLOT_EMPTY_BDR, 2)
		var sb_hover := _backpack_slot_stylebox(
			COL_SLOT_EMPTY_BG.lightened(0.08), COL_SLOT_HOVER_BDR, 3)
		cell.add_theme_stylebox_override("panel", sb_base)
		var _si := slot_idx
		cell.gui_input.connect(func(ev: InputEvent) -> void: _on_backpack_slot_gui_input(_si, ev))
		cell.mouse_entered.connect(func() -> void: _inv_slot_set_hover_style(_si, true))
		cell.mouse_exited.connect(func() -> void: _inv_slot_set_hover_style(_si, false))
		## 以 MarginContainer 包住 inner，讓內容保持置中。
		var mc := MarginContainer.new()
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 2)
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(34, 34)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture = HudItemIcons.tex(HudItemIcons.GENERIC)
		ic.modulate = Color(1, 1, 1, 0.0)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## 空格佔位點：格子空著時顯示，讓玩家能看清每一格。
		var dot := Label.new()
		dot.text = "·"
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.add_theme_font_size_override("font_size", 22)
		dot.add_theme_color_override("font_color", Color(0.40, 0.50, 0.65, 0.55))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ql := Label.new()
		ql.visible = false
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ql.add_theme_font_size_override("font_size", 11)
		ql.add_theme_color_override("font_color", Color(0.90, 0.95, 1.00, 0.92))
		ql.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.70))
		ql.add_theme_constant_override("shadow_offset_x", 1)
		ql.add_theme_constant_override("shadow_offset_y", 1)
		ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(ic)
		inner.add_child(dot)
		inner.add_child(ql)
		_inv_slot_dots.append(dot)
		mc.add_child(inner)
		cell.add_child(mc)
		slot_grid.add_child(cell)
		_inv_slot_cells.append(cell)
		_inv_slot_icons.append(ic)
		_inv_slot_qty.append(ql)
		_inv_slot_sb_base.append(sb_base)
		_inv_slot_sb_hover.append(sb_hover)
	outer.add_child(slot_grid)

	return sc


func _build_chest_overlay() -> void:
	_chest_root = Control.new()
	_chest_root.name = "ChestOverlay"
	_chest_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chest_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_chest_root.visible = false
	_chest_root.z_index = 80
	add_child(_chest_root)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_chest_dim_gui_input)
	_chest_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chest_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 240)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(COL_PANEL))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var hdr := HBoxContainer.new()
	var ht := Label.new()
	ht.text = "木箱（12 格 · 堆疊 30）"
	ht.add_theme_font_size_override("font_size", 14)
	ht.add_theme_color_override("font_color", COL_HEADER_YELLOW)
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(ht)
	var bx := Button.new()
	bx.text = "✕"
	bx.flat = true
	bx.focus_mode = Control.FOCUS_NONE
	bx.custom_minimum_size = Vector2(36, 28)
	bx.pressed.connect(close_chest_panel)
	hdr.add_child(bx)
	vb.add_child(hdr)
	var slot_grid := GridContainer.new()
	slot_grid.columns = 6
	slot_grid.add_theme_constant_override("h_separation", 6)
	slot_grid.add_theme_constant_override("v_separation", 6)
	for slot_idx in GameConstants.CHEST_SLOT_COUNT:
		var cell := PanelContainer.new()
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.focus_mode = Control.FOCUS_NONE
		cell.custom_minimum_size = Vector2(58, 54)
		var COL_SLOT_EMPTY_BG := Color(0.08, 0.11, 0.17, 0.96)
		var COL_SLOT_EMPTY_BDR := Color(0.38, 0.48, 0.62, 0.92)
		var COL_SLOT_HOVER_BDR := Color(0.65, 0.82, 1.00, 0.95)
		var sb_base := _backpack_slot_stylebox(COL_SLOT_EMPTY_BG, COL_SLOT_EMPTY_BDR, 2)
		var sb_hover := _backpack_slot_stylebox(
			COL_SLOT_EMPTY_BG.lightened(0.08), COL_SLOT_HOVER_BDR, 3)
		cell.add_theme_stylebox_override("panel", sb_base)
		var _si := slot_idx
		cell.gui_input.connect(func(ev: InputEvent) -> void: _on_chest_slot_gui_input(_si, ev))
		cell.mouse_entered.connect(func() -> void: _chest_slot_set_hover_style(_si, true))
		cell.mouse_exited.connect(func() -> void: _chest_slot_set_hover_style(_si, false))
		var mc := MarginContainer.new()
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var inner := VBoxContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		inner.add_theme_constant_override("separation", 2)
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(30, 30)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture = HudItemIcons.tex(HudItemIcons.GENERIC)
		ic.modulate = Color(1, 1, 1, 0.0)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var dot := Label.new()
		dot.text = "·"
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.add_theme_font_size_override("font_size", 18)
		dot.add_theme_color_override("font_color", Color(0.40, 0.50, 0.65, 0.55))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ql := Label.new()
		ql.visible = false
		ql.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ql.add_theme_font_size_override("font_size", 10)
		ql.add_theme_color_override("font_color", Color(0.90, 0.95, 1.00, 0.92))
		ql.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(ic)
		inner.add_child(dot)
		inner.add_child(ql)
		_chest_slot_dots.append(dot)
		mc.add_child(inner)
		cell.add_child(mc)
		slot_grid.add_child(cell)
		_chest_slot_cells.append(cell)
		_chest_slot_icons.append(ic)
		_chest_slot_qty.append(ql)
		_chest_slot_sb_base.append(sb_base)
		_chest_slot_sb_hover.append(sb_hover)
	vb.add_child(slot_grid)


func _on_chest_dim_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			close_chest_panel()


func open_chest_panel(inv: GameInventory) -> void:
	_chest_inv_ref = inv
	if _chest_root != null:
		_chest_root.visible = true
	_refresh_chest_slots()


func close_chest_panel() -> void:
	_chest_drag_from = -1
	_chest_inv_ref = null
	if _chest_root != null:
		_chest_root.visible = false


func is_chest_panel_open() -> bool:
	return _chest_root != null and _chest_root.visible


func _refresh_chest_slots() -> void:
	if _chest_inv_ref == null:
		return
	var inv := _chest_inv_ref
	var _COL_SLOT_EMPTY_BG := Color(0.08, 0.11, 0.17, 0.96)
	var _COL_SLOT_EMPTY_BDR := Color(0.38, 0.48, 0.62, 0.92)
	var _COL_SLOT_FULL_BG := Color(0.14, 0.20, 0.30, 0.96)
	var _COL_SLOT_FULL_BDR := Color(0.45, 0.65, 0.90, 0.85)
	var _COL_SLOT_HOVER_BDR := Color(0.65, 0.82, 1.00, 0.95)
	for si in GameConstants.CHEST_SLOT_COUNT:
		if si >= _chest_slot_icons.size():
			break
		var snap := inv.get_slot_snapshot(si)
		var sid_slot: StringName = &""
		if not snap.is_empty():
			var idv: Variant = snap.get("id", &"")
			sid_slot = idv as StringName if idv is StringName else StringName(str(idv))
		var occupied := not snap.is_empty()
		var ic: TextureRect = _chest_slot_icons[si]
		var ql: Label = _chest_slot_qty[si]
		var dot: Label = _chest_slot_dots[si]
		if si < _chest_slot_cells.size():
			_chest_slot_cells[si].tooltip_text = (
				"%s ×%d" % [HudItemIcons.stackable_display_name_zh(sid_slot), int(snap.get("q", 0))]
				if occupied else "空格"
			)
		if occupied:
			ic.texture = HudItemIcons.tex(HudItemIcons.stackable_icon_path(sid_slot))
			ic.modulate = Color(1, 1, 1, 1)
			var q := int(snap.get("q", 0))
			ql.text = str(q)
			ql.visible = q > 1
			dot.visible = false
		else:
			ic.texture = HudItemIcons.tex(HudItemIcons.GENERIC)
			ic.modulate = Color(1, 1, 1, 0)
			ql.visible = false
			dot.visible = true
		if si < _chest_slot_sb_base.size():
			var sb := _chest_slot_sb_base[si]
			sb.bg_color = _COL_SLOT_FULL_BG if occupied else _COL_SLOT_EMPTY_BG
			sb.border_color = _COL_SLOT_FULL_BDR if occupied else _COL_SLOT_EMPTY_BDR
			sb.set_border_width_all(3 if occupied else 2)
		if si < _chest_slot_sb_hover.size():
			var sbh := _chest_slot_sb_hover[si]
			sbh.bg_color = (
				_COL_SLOT_FULL_BG.lightened(0.10) if occupied else _COL_SLOT_EMPTY_BG.lightened(0.08)
			)
			sbh.border_color = _COL_SLOT_HOVER_BDR
			sbh.set_border_width_all(3)


func _chest_slot_set_hover_style(slot_idx: int, hover: bool) -> void:
	if slot_idx < 0 or slot_idx >= _chest_slot_cells.size():
		return
	if slot_idx >= _chest_slot_sb_base.size() or slot_idx >= _chest_slot_sb_hover.size():
		return
	var cell: PanelContainer = _chest_slot_cells[slot_idx]
	if hover:
		cell.add_theme_stylebox_override("panel", _chest_slot_sb_hover[slot_idx])
	else:
		cell.add_theme_stylebox_override("panel", _chest_slot_sb_base[slot_idx])


func _chest_slot_index_at_global(global_pos: Vector2) -> int:
	if _chest_root == null or not _chest_root.visible or _chest_inv_ref == null:
		return -1
	for si in mini(_chest_slot_cells.size(), GameConstants.CHEST_SLOT_COUNT):
		if _chest_slot_cells[si].get_global_rect().has_point(global_pos):
			return si
	return -1


func _on_chest_slot_gui_input(slot_idx: int, ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _chest_inv_ref == null:
				return
			var snap := _chest_inv_ref.get_slot_snapshot(slot_idx)
			if snap.is_empty():
				return
			_chest_drag_from = slot_idx
			_inv_drag_from = -1


func _inv_slot_set_hover_style(slot_idx: int, hover: bool) -> void:
	if slot_idx < 0 or slot_idx >= _inv_slot_cells.size():
		return
	if slot_idx >= _inv_slot_sb_base.size() or slot_idx >= _inv_slot_sb_hover.size():
		return
	var cell: PanelContainer = _inv_slot_cells[slot_idx]
	if hover:
		cell.add_theme_stylebox_override("panel", _inv_slot_sb_hover[slot_idx])
	else:
		cell.add_theme_stylebox_override("panel", _inv_slot_sb_base[slot_idx])


func _inv_slot_index_at_global(global_pos: Vector2) -> int:
	var cap: int = GameConstants.INVENTORY_SLOT_COUNT_DEFAULT
	if _inv_ref != null:
		cap = _inv_ref.slot_count
	for si in mini(_inv_slot_cells.size(), cap):
		if _inv_slot_cells[si].get_global_rect().has_point(global_pos):
			return si
	return -1


## 由 Main._input 呼叫：滑鼠放開完成拖曳（背包／木箱互換或各自格內）。
func handle_backpack_drag_mouse_global(event: InputEvent) -> void:
	if _inv_drag_from < 0 and _chest_drag_from < 0:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
		return
	var gpos := mb.global_position
	var to_bp := _inv_slot_index_at_global(gpos)
	var to_ch := _chest_slot_index_at_global(gpos)
	var applied := false
	if _inv_drag_from >= 0 and _inv_ref != null:
		if to_ch >= 0 and _chest_inv_ref != null and is_chest_panel_open():
			applied = GameInventory.apply_slot_transfer_between(
				_inv_ref, _inv_drag_from, _chest_inv_ref, to_ch
			)
		elif to_bp >= 0:
			applied = _inv_ref.apply_backpack_slot_drag(_inv_drag_from, to_bp)
	elif _chest_drag_from >= 0 and _chest_inv_ref != null:
		if to_bp >= 0 and _inv_ref != null:
			applied = GameInventory.apply_slot_transfer_between(
				_chest_inv_ref, _chest_drag_from, _inv_ref, to_bp
			)
		elif to_ch >= 0 and is_chest_panel_open():
			applied = _chest_inv_ref.apply_backpack_slot_drag(_chest_drag_from, to_ch)
	_inv_drag_from = -1
	_chest_drag_from = -1
	if applied:
		backpack_inventory_drag_changed.emit()
		chest_inventory_changed.emit()
	elif _inv_ref != null:
		refresh(_inv_ref, _two_player_ref)
		if is_chest_panel_open():
			_refresh_chest_slots()
	get_viewport().set_input_as_handled()


func _on_backpack_slot_gui_input(slot_idx: int, ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			backpack_slot_context_requested.emit(slot_idx, mb.global_position)
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _inv_ref == null:
				return
			var snap := _inv_ref.get_slot_snapshot(slot_idx)
			if snap.is_empty():
				return
			_inv_drag_from = slot_idx
			_chest_drag_from = -1


func _resource_grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 4)
	return g


func _add_grid_resource(grid: GridContainer, icon_path: String, name_zh: String) -> Label:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_hud_icon_rect(icon_path, Vector2(15, 15)))
	var nm := Label.new()
	nm.text = name_zh
	nm.add_theme_font_size_override("font_size", 12)
	nm.add_theme_color_override("font_color", COL_TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(nm)
	var qty := Label.new()
	qty.text = "0"
	qty.add_theme_font_size_override("font_size", 12)
	qty.add_theme_color_override("font_color", COL_HIGHLIGHT)
	hb.add_child(qty)
	grid.add_child(hb)
	return qty


func _add_resource_row(parent: VBoxContainer, icon_path: String, name_zh: String) -> Label:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.add_child(_hud_icon_rect(icon_path, Vector2(18, 18)))
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
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	sc.add_child(vb)
	var tools_body := _install_collapsible_section(vb, "工具", COL_HEADER_RED, true)
	_btn_craft_axe = _craft_button(HudItemIcons.AXE, "石斧", [
		[HudItemIcons.WOOD, GameConstants.CRAFT_AXE_WOOD, "木材"],
		[HudItemIcons.STONE, GameConstants.CRAFT_AXE_STONE, "石頭"],
	])
	_lbl_craft_axe_state = _btn_craft_axe.get_meta("state_label")
	_btn_craft_axe.pressed.connect(func() -> void: craft_axe_pressed.emit())
	tools_body.add_child(_btn_craft_axe)
	return sc


## costs: [[icon_path, count, tooltip_zh], ...]
func _craft_button(icon_path: String, title: String, costs: Array) -> Button:
	var b := Button.new()
	b.flat = false
	b.add_theme_stylebox_override("normal", _btn_style(COL_BTN))
	b.add_theme_stylebox_override("hover", _btn_style(COL_BTN_HOVER))
	b.add_theme_stylebox_override("pressed", _btn_style(COL_BTN.darkened(0.08)))
	b.add_theme_stylebox_override("disabled", _btn_style(COL_BTN.darkened(0.35)))
	b.custom_minimum_size = Vector2(84, 78)
	b.clip_contents = true
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var ico := TextureRect.new()
	ico.texture = HudItemIcons.tex(icon_path)
	ico.custom_minimum_size = Vector2(28, 28)
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ico.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(ico)
	var nm := Label.new()
	nm.text = title
	nm.add_theme_font_size_override("font_size", 11)
	nm.add_theme_color_override("font_color", Color.WHITE)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nm)
	var cost_hb := HBoxContainer.new()
	cost_hb.add_theme_constant_override("separation", 2)
	cost_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c: Array in costs:
		var ci := TextureRect.new()
		ci.texture = HudItemIcons.tex(c[0])
		ci.custom_minimum_size = Vector2(13, 13)
		ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ci.mouse_filter = Control.MOUSE_FILTER_PASS
		ci.tooltip_text = c[2]
		cost_hb.add_child(ci)
		var cl := Label.new()
		cl.text = "×%d" % c[1]
		cl.add_theme_font_size_override("font_size", 10)
		cl.add_theme_color_override("font_color", COL_MUTED)
		cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cost_hb.add_child(cl)
	vb.add_child(cost_hb)
	var state_lbl := Label.new()
	state_lbl.add_theme_font_size_override("font_size", 10)
	state_lbl.add_theme_color_override("font_color", COL_HIGHLIGHT)
	state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_lbl.visible = false
	vb.add_child(state_lbl)
	b.set_meta("state_label", state_lbl)
	b.add_child(vb)
	return b


func _build_build_column() -> Control:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_STOP
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP
	sc.add_child(vb)
	var station_body := _install_collapsible_section(vb, "加工站", COL_HEADER_ORANGE, true)
	var grid_st := GridContainer.new()
	grid_st.columns = 2
	grid_st.add_theme_constant_override("h_separation", 8)
	grid_st.add_theme_constant_override("v_separation", 8)
	_btn_campfire = _craft_button(HudItemIcons.CAMPFIRE, "營火", [
		[HudItemIcons.WOOD, GameConstants.CAMPFIRE_WOOD, "木材"],
		[HudItemIcons.STONE, GameConstants.CAMPFIRE_STONE, "石頭"],
	])
	_btn_campfire.pressed.connect(func() -> void: toggle_campfire_pressed.emit())
	grid_st.add_child(_btn_campfire)
	_btn_workbench = _craft_button(HudItemIcons.WORKBENCH, "工作台", [
		[HudItemIcons.WOOD, GameConstants.BUILD_WORKBENCH_WOOD, "木材"],
		[HudItemIcons.STONE, GameConstants.BUILD_WORKBENCH_STONE, "石頭"],
	])
	_btn_workbench.pressed.connect(func() -> void: build_workbench_pressed.emit())
	grid_st.add_child(_btn_workbench)
	station_body.add_child(grid_st)
	var mat_body := _install_collapsible_section(vb, "建材", COL_HEADER_ORANGE, true)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_btn_floor = _craft_button(HudItemIcons.FLOOR, "木地板", [
		[HudItemIcons.WOOD, GameConstants.BUILD_FLOOR_WOOD, "木材"],
	])
	_btn_floor.pressed.connect(func() -> void: build_floor_pressed.emit())
	grid.add_child(_btn_floor)
	_btn_fence = _craft_button(HudItemIcons.FENCE, "木牆", [
		[HudItemIcons.WOOD, GameConstants.BUILD_FENCE_WOOD, "木材"],
	])
	_btn_fence.pressed.connect(func() -> void: build_fence_pressed.emit())
	grid.add_child(_btn_fence)
	_btn_door = _craft_button(HudItemIcons.DOOR, "木門", [
		[HudItemIcons.WOOD, GameConstants.BUILD_DOOR_WOOD, "木材"],
	])
	_btn_door.pressed.connect(func() -> void: build_door_pressed.emit())
	grid.add_child(_btn_door)
	_btn_chest = _craft_button(HudItemIcons.GENERIC, "木箱", [
		[HudItemIcons.WOOD, GameConstants.BUILD_CHEST_WOOD, "木材"],
	])
	_btn_chest.pressed.connect(func() -> void: build_chest_pressed.emit())
	grid.add_child(_btn_chest)
	_btn_farmland = _craft_button(HudItemIcons.DIRT, "耕地", [
		[HudItemIcons.DIRT, GameConstants.BUILD_FARMLAND_DIRT, "土"],
	])
	_btn_farmland.pressed.connect(func() -> void: build_farmland_pressed.emit())
	grid.add_child(_btn_farmland)
	mat_body.add_child(grid)
	var plant_body := _install_collapsible_section(vb, "種植", COL_HEADER_YELLOW, true)
	_btn_plant_tree = _craft_button(HudItemIcons.SEED, "種樹", [
		[HudItemIcons.SEED, GameConstants.PLANT_TREE_SEED_COST, "樹種"],
	])
	_btn_plant_tree.pressed.connect(func() -> void: plant_tree_pressed.emit())
	plant_body.add_child(_btn_plant_tree)
	_btn_plant_turnip = _craft_button(HudItemIcons.TURNIP_SEEDS, "種蕪菁", [
		[HudItemIcons.TURNIP_SEEDS, 1, "蕪菁種子"],
	])
	_btn_plant_turnip.pressed.connect(func() -> void: plant_turnip_pressed.emit())
	plant_body.add_child(_btn_plant_turnip)
	return sc


func _main_hand_label_text(w: StringName) -> String:
	match w:
		&"axe":
			return "石斧"
		&"wood_spear":
			return "木製長槍"
		&"iron_sword":
			return "鐵製短劍"
		_:
			return "無"


func _main_hand_icon_path(w: StringName) -> String:
	match w:
		&"axe":
			return HudItemIcons.AXE
		&"wood_spear":
			return HudItemIcons.WOOD_SPEAR
		&"iron_sword":
			return HudItemIcons.IRON_SWORD
		_:
			return HudItemIcons.MAIN_EMPTY


func refresh(inv: GameInventory, two_player: bool = false) -> void:
	if _lbl_main == null:
		return
	_inv_ref = inv
	_two_player_ref = two_player
	if _row_p2_equip != null:
		_row_p2_equip.visible = two_player
	if _hdr_1p_main != null:
		_hdr_1p_main.text = "1P 主手" if two_player else "主手"
	var main_txt := _main_hand_label_text(inv.equip_main)
	if _ico_equip_main != null:
		_ico_equip_main.texture = HudItemIcons.tex(_main_hand_icon_path(inv.equip_main))
	_lbl_main.text = main_txt
	_btn_unequip.visible = inv.equip_main != &""
	if _lbl_main_p2 != null:
		_lbl_main_p2.text = _main_hand_label_text(inv.equip_main_p2)
	if _ico_equip_main_p2 != null:
		_ico_equip_main_p2.texture = HudItemIcons.tex(_main_hand_icon_path(inv.equip_main_p2))
	if _btn_unequip_p2 != null:
		_btn_unequip_p2.visible = two_player
		_btn_unequip_p2.disabled = not two_player or inv.equip_main_p2 == &""
	_lbl_off.text = "無"
	if inv.armor_equipped == &"sticky_armor":
		_lbl_armor.text = "黏黏護甲"
		if _ico_armor != null:
			_ico_armor.texture = HudItemIcons.tex(HudItemIcons.STICKY_ARMOR)
		_btn_unequip_armor.visible = true
	else:
		_lbl_armor.text = "便服"
		if _ico_armor != null:
			_ico_armor.texture = HudItemIcons.tex(HudItemIcons.ARMOR_DEFAULT)
		_btn_unequip_armor.visible = false
	_lbl_acc.text = "無"
	var _COL_SLOT_EMPTY_BG  := Color(0.08, 0.11, 0.17, 0.96)
	var _COL_SLOT_EMPTY_BDR := Color(0.38, 0.48, 0.62, 0.92)
	var _COL_SLOT_FULL_BG   := Color(0.14, 0.20, 0.30, 0.96)
	var _COL_SLOT_FULL_BDR  := Color(0.45, 0.65, 0.90, 0.85)
	var _COL_SLOT_HOVER_BDR := Color(0.65, 0.82, 1.00, 0.95)
	for si in mini(_inv_slot_icons.size(), inv.slot_count):
		var snap := inv.get_slot_snapshot(si)
		var sid_slot: StringName = &""
		if not snap.is_empty():
			var idv: Variant = snap.get("id", &"")
			sid_slot = idv as StringName if idv is StringName else StringName(str(idv))
		var occupied := not snap.is_empty()
		if si < _inv_slot_cells.size():
			_inv_slot_cells[si].tooltip_text = (
				"%s ×%d" % [HudItemIcons.stackable_display_name_zh(sid_slot), int(snap.get("q", 0))]
				if occupied else "空格"
			)
		if si < _inv_slot_sb_base.size():
			var sb := _inv_slot_sb_base[si]
			sb.bg_color = _COL_SLOT_FULL_BG if occupied else _COL_SLOT_EMPTY_BG
			sb.border_color = _COL_SLOT_FULL_BDR if occupied else _COL_SLOT_EMPTY_BDR
			sb.set_border_width_all(3 if occupied else 2)
		if si < _inv_slot_sb_hover.size():
			var sbh := _inv_slot_sb_hover[si]
			sbh.bg_color = (_COL_SLOT_FULL_BG.lightened(0.10)
				if occupied else _COL_SLOT_EMPTY_BG.lightened(0.08))
			sbh.border_color = _COL_SLOT_HOVER_BDR
			sbh.set_border_width_all(3)
		if occupied:
			_inv_slot_icons[si].texture = HudItemIcons.tex(HudItemIcons.stackable_icon_path(sid_slot))
			_inv_slot_icons[si].modulate = Color(1, 1, 1, 1.0)
			var qty := int(snap.get("q", 0))
			_inv_slot_qty[si].visible = qty > 1
			_inv_slot_qty[si].text = str(qty)
			if si < _inv_slot_dots.size():
				_inv_slot_dots[si].visible = false
		else:
			_inv_slot_icons[si].modulate = Color(1, 1, 1, 0.0)
			_inv_slot_qty[si].visible = false
			if si < _inv_slot_dots.size():
				_inv_slot_dots[si].visible = true
	for si2 in range(inv.slot_count, _inv_slot_icons.size()):
		if si2 < _inv_slot_cells.size():
			_inv_slot_cells[si2].tooltip_text = ""
		_inv_slot_icons[si2].modulate = Color(1, 1, 1, 0.0)
		_inv_slot_qty[si2].visible = false
		if si2 < _inv_slot_dots.size():
			_inv_slot_dots[si2].visible = true
	if _lbl_wood != null:
		_lbl_wood.text = str(inv.wood)
		_lbl_stone.text = str(inv.stone)
		if _lbl_dirt != null:
			_lbl_dirt.text = str(inv.dirt)
		_lbl_berries.text = str(inv.berries)
		_lbl_berry_jerky.text = str(inv.berry_jerky)
		_lbl_seed.text = str(inv.seed)
		if _lbl_water != null:
			_lbl_water.text = "%d/%d" % [inv.water, GameConstants.WATER_CARRY_MAX]
		_lbl_slime.text = str(inv.slime_goo)
		_lbl_leather.text = str(inv.leather)
		_lbl_meat_cutlet.text = str(inv.meat_cutlet)
		_lbl_bbq_meat.text = str(inv.bbq_meat)
		if _lbl_turnip_seeds != null:
			_lbl_turnip_seeds.text = str(inv.turnip_seeds)
		if _lbl_turnip != null:
			_lbl_turnip.text = str(inv.turnip)
	var can_pay_axe := inv.wood >= GameConstants.CRAFT_AXE_WOOD and inv.stone >= GameConstants.CRAFT_AXE_STONE
	_btn_craft_axe.disabled = not can_pay_axe
	if _lbl_craft_axe_state != null:
		if inv.equip_main == &"axe":
			_lbl_craft_axe_state.text = "1P 主手✓"
			_lbl_craft_axe_state.visible = true
		elif inv.equip_main_p2 == &"axe":
			_lbl_craft_axe_state.text = "2P 主手✓"
			_lbl_craft_axe_state.visible = true
		elif inv.axe_spare > 0:
			_lbl_craft_axe_state.text = "備用×%d" % inv.axe_spare
			_lbl_craft_axe_state.visible = true
		else:
			_lbl_craft_axe_state.visible = false
	_btn_campfire.disabled = not inv.can_place_campfire()
	_btn_floor.disabled = inv.wood < GameConstants.BUILD_FLOOR_WOOD
	_btn_fence.disabled = inv.wood < GameConstants.BUILD_FENCE_WOOD
	_btn_door.disabled = inv.wood < GameConstants.BUILD_DOOR_WOOD
	if _btn_farmland != null:
		_btn_farmland.disabled = inv.dirt < GameConstants.BUILD_FARMLAND_DIRT
	_btn_plant_tree.disabled = not inv.can_plant_tree()
	if _btn_plant_turnip != null:
		_btn_plant_turnip.disabled = not inv.can_plant_turnip()
	var can_wb := (
		inv.wood >= GameConstants.BUILD_WORKBENCH_WOOD
		and inv.stone >= GameConstants.BUILD_WORKBENCH_STONE
	)
	if _btn_workbench != null:
		_btn_workbench.disabled = not can_wb
	if _btn_chest != null:
		_btn_chest.disabled = inv.wood < GameConstants.BUILD_CHEST_WOOD
	if is_chest_panel_open():
		_refresh_chest_slots()


func set_build_mode_visual(
	campfire_placing: bool,
	floor_m: bool,
	fence_m: bool,
	door_m: bool,
	dismantle_m: bool,
	plant_tree_m: bool,
	workbench_m: bool = false,
	farmland_m: bool = false,
	plant_turnip_m: bool = false,
	chest_m: bool = false
) -> void:
	_sel_glow(_btn_campfire, campfire_placing)
	_sel_glow(_btn_floor, floor_m)
	_sel_glow(_btn_fence, fence_m)
	_sel_glow(_btn_door, door_m)
	if _btn_workbench != null:
		_sel_glow(_btn_workbench, workbench_m)
	if _btn_chest != null:
		_sel_glow(_btn_chest, chest_m)
	if _btn_farmland != null:
		_sel_glow(_btn_farmland, farmland_m)
	if _dismantle_glow_btn != null:
		_sel_glow(_dismantle_glow_btn, dismantle_m)
	_sel_glow(_btn_plant_tree, plant_tree_m)
	if _btn_plant_turnip != null:
		_sel_glow(_btn_plant_turnip, plant_turnip_m)


func _sel_glow(b: Button, on: bool) -> void:
	if b == null:
		return
	b.modulate = Color(1.22, 1.12, 0.88, 1.0) if on else Color.WHITE
