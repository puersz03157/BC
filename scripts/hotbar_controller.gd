class_name HotbarController
extends PanelContainer
## 底部面板上方的 9 格快捷欄 + E 角色技 + Q 武器技能說明；由 Main 處理數字鍵 1～9、E／L（2P 衝刺）等。雙人時武器說明依 1P／2P 主手。

signal assign_chosen(slot_index: int, item_id: StringName)

var _outer: HBoxContainer
var _slot_root: HBoxContainer
var _panels: Array[Panel] = []
var _slot_styles: Array[StyleBoxFlat] = []
var _icons: Array[TextureRect] = []
var _nums: Array[Label] = []
var _menu: PopupMenu
var _menu_slot: int = -1
var _last_inv: GameInventory = null
var _last_two_p: bool = false
var _dash_icon: TextureRect
var _dash_hint: Label
var _char_cd_bar: TextureProgressBar = null
var _skill_icon: TextureRect
var _skill_hint: Label
var _weapon_cd_bar: TextureProgressBar = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.content_margin_left = 6
	flat.content_margin_right = 6
	flat.content_margin_top = 2
	flat.content_margin_bottom = 2
	add_theme_stylebox_override("panel", flat)
	_outer = HBoxContainer.new()
	_outer.add_theme_constant_override("separation", 8)
	_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_outer)
	_slot_root = HBoxContainer.new()
	_slot_root.add_theme_constant_override("separation", 5)
	_slot_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dash_col := VBoxContainer.new()
	dash_col.add_theme_constant_override("separation", 2)
	dash_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row_e := HBoxContainer.new()
	row_e.add_theme_constant_override("separation", 4)
	var e_tag := Label.new()
	e_tag.text = "E"
	e_tag.add_theme_font_size_override("font_size", 12)
	e_tag.add_theme_color_override("font_color", Color(0.55, 0.88, 0.72, 1.0))
	row_e.add_child(e_tag)
	_dash_icon = TextureRect.new()
	_dash_icon.texture = HudItemIcons.character_skill_tex(&"dash")
	_dash_icon.custom_minimum_size = Vector2(24, 24)
	_dash_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dash_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dash_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_e.add_child(_dash_icon)
	dash_col.add_child(row_e)
	_char_cd_bar = TextureProgressBar.new()
	_char_cd_bar.custom_minimum_size = Vector2(158, 10)
	_char_cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_char_cd_bar.min_value = 0.0
	_char_cd_bar.max_value = GameConstants.CHARACTER_DASH_COOLDOWN_SEC
	_char_cd_bar.value = 0.0
	_char_cd_bar.visible = false
	if CuteFantasyUiBars.setup_skill_cd_bar(_char_cd_bar):
		dash_col.add_child(_char_cd_bar)
	else:
		_char_cd_bar.queue_free()
		_char_cd_bar = null
	_dash_hint = Label.new()
	_dash_hint.add_theme_font_size_override("font_size", 10)
	_dash_hint.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 1.0))
	_dash_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dash_hint.custom_minimum_size = Vector2(158, 0)
	_dash_hint.text = "角色技能"
	_dash_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash_col.add_child(_dash_hint)
	_outer.add_child(_skill_panel_wrap(dash_col))
	var weapon_col := VBoxContainer.new()
	weapon_col.add_theme_constant_override("separation", 2)
	weapon_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var row_q := HBoxContainer.new()
	row_q.add_theme_constant_override("separation", 4)
	var q_tag := Label.new()
	q_tag.text = "Q"
	q_tag.add_theme_font_size_override("font_size", 12)
	q_tag.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1.0))
	row_q.add_child(q_tag)
	_skill_icon = TextureRect.new()
	_skill_icon.texture = HudItemIcons.weapon_skill_icon_for_main(&"")
	_skill_icon.custom_minimum_size = Vector2(24, 24)
	_skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_q.add_child(_skill_icon)
	weapon_col.add_child(row_q)
	_weapon_cd_bar = TextureProgressBar.new()
	_weapon_cd_bar.custom_minimum_size = Vector2(158, 10)
	_weapon_cd_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_cd_bar.min_value = 0.0
	_weapon_cd_bar.max_value = GameConstants.WEAPON_SKILL_COOLDOWN
	_weapon_cd_bar.value = 0.0
	_weapon_cd_bar.visible = false
	if CuteFantasyUiBars.setup_skill_cd_bar(_weapon_cd_bar):
		weapon_col.add_child(_weapon_cd_bar)
	else:
		_weapon_cd_bar.queue_free()
		_weapon_cd_bar = null
	_skill_hint = Label.new()
	_skill_hint.add_theme_font_size_override("font_size", 10)
	_skill_hint.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 1.0))
	_skill_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_hint.custom_minimum_size = Vector2(158, 0)
	_skill_hint.text = "武器技能"
	_skill_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_col.add_child(_skill_hint)
	_outer.add_child(_skill_panel_wrap(weapon_col))
	_outer.add_child(_slot_root)
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu_id_pressed)
	add_child(_menu)
	for i in 9:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(40, 40)
		p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		var flat_p := StyleBoxFlat.new()
		flat_p.bg_color = Color(0.14, 0.18, 0.24, 0.96)
		flat_p.set_corner_radius_all(6)
		flat_p.border_width_left = 1
		flat_p.border_width_top = 1
		flat_p.border_width_right = 1
		flat_p.border_width_bottom = 1
		flat_p.border_color = Color(0.32, 0.40, 0.52, 0.85)
		p.add_theme_stylebox_override("panel", flat_p)
		_slot_styles.append(flat_p)
		# 圖示填滿格子（留 4px 邊距）
		var ic := TextureRect.new()
		ic.anchor_left = 0.0
		ic.anchor_top = 0.0
		ic.anchor_right = 1.0
		ic.anchor_bottom = 1.0
		ic.offset_left = 4
		ic.offset_top = 4
		ic.offset_right = -4
		ic.offset_bottom = -4
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(ic)
		# 數字疊在左下角
		var nb := Label.new()
		nb.text = str(i + 1)
		nb.add_theme_font_size_override("font_size", 9)
		nb.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78, 0.85))
		nb.anchor_left = 0.0
		nb.anchor_top = 1.0
		nb.anchor_right = 0.0
		nb.anchor_bottom = 1.0
		nb.offset_left = 3
		nb.offset_top = -14
		nb.offset_right = 14
		nb.offset_bottom = -2
		nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(nb)
		var idx := i
		p.gui_input.connect(func(ev: InputEvent) -> void: _on_slot_gui_input(idx, ev))
		_slot_root.add_child(p)
		_panels.append(p)
		_icons.append(ic)
		_nums.append(nb)


func _on_slot_gui_input(slot: int, ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_open_assign_menu(slot, mb.global_position)


func _open_assign_menu(slot: int, screen_pos: Vector2) -> void:
	_menu_slot = slot
	_menu.clear()
	_menu.add_item("清除", 0)
	var inv := _last_inv
	if inv == null:
		_menu.popup(Rect2(screen_pos, Vector2.ZERO))
		return
	var two_p := _last_two_p
	var candidates: Array[Array] = [
		[1, "石斧", inv.has_axe()],
		[4, "木製長槍", inv.spear_spare > 0 or inv.equip_main == &"wood_spear" or (two_p and inv.equip_main_p2 == &"wood_spear")],
		[5, "石製短劍", inv.sword_spare > 0 or inv.equip_main == &"iron_sword" or (two_p and inv.equip_main_p2 == &"iron_sword")],
		[2, "莓果", inv.berries > 0],
		[3, "莓果干", inv.berry_jerky > 0],
		[6, "肉排", inv.meat_cutlet > 0],
		[7, "烤肉", inv.bbq_meat > 0],
		[8, "水", inv.water > 0],
	]
	for c in candidates:
		if c[2]:
			_menu.add_item(c[1], c[0])
	if _menu.item_count == 1:
		_menu.add_separator()
		_menu.add_item("（目前沒有可指派的物品）", 99)
		_menu.set_item_disabled(_menu.item_count - 1, true)
	_menu.popup(Rect2(screen_pos, Vector2.ZERO))


func _on_menu_id_pressed(id: int) -> void:
	var sn: StringName = &""
	match id:
		0:
			sn = &""
		1:
			sn = &"axe"
		2:
			sn = &"berries"
		3:
			sn = &"jerky"
		4:
			sn = &"wood_spear"
		5:
			sn = &"iron_sword"
		6:
			sn = &"meat_cutlet"
		7:
			sn = &"bbq_meat"
		8:
			sn = &"water"
		_:
			pass
	assign_chosen.emit(_menu_slot, sn)


func _char_skill_hint_one(skill: StringName, charge_ready: bool, iron_rem: float) -> String:
	match skill:
		&"dash":
			return "短衝刺（朝移動方向位移）"
		&"charge":
			var t := "蓄力（下次木槍迴旋／石短劍投擲傷害加倍）"
			if charge_ready:
				t += "·已蓄力"
			return t
		&"iron_wall":
			var iw := "鐵壁（%.0f 秒內受傷減半）" % GameConstants.CHARACTER_IRON_WALL_DURATION_SEC
			if iron_rem > 0.05:
				iw += "·剩%.1fs" % iron_rem
			return iw
		_:
			return "角色技能"


func _dash_hint_text(
	p1_skill: StringName,
	p2_skill: StringName,
	two_p: bool,
	p1_charge_ready: bool,
	p2_charge_ready: bool,
	p1_iron: float,
	p2_iron: float
) -> String:
	if not two_p:
		return _char_skill_hint_one(p1_skill, p1_charge_ready, p1_iron) + "。按 E。"
	return (
		"1P："
		+ _char_skill_hint_one(p1_skill, p1_charge_ready, p1_iron)
		+ " 2P："
		+ _char_skill_hint_one(p2_skill, p2_charge_ready, p2_iron)
		+ "（1P＝E，2P＝L）。"
	)


func _weapon_skill_desc_line(w: StringName) -> String:
	match w:
		&"wood_spear":
			return "木槍：周身迴旋，掃樹／石／野怪；消耗飽足度。"
		&"iron_sword":
			return "石短劍：投擲鎖定最近野怪（較遠）；消耗飽足度。"
		_:
			return "裝備木槍或石短劍後可施放；有共用冷卻。"


func _weapon_skill_short(w: StringName) -> String:
	match w:
		&"wood_spear":
			return "木槍"
		&"iron_sword":
			return "石短劍"
		&"axe":
			return "石斧"
		_:
			return "無"


func _skill_hint_text(inv: GameInventory, two_p: bool) -> String:
	if not two_p:
		return _weapon_skill_desc_line(inv.equip_main)
	var w1 := inv.equip_main
	var w2 := inv.equip_main_p2
	if w1 == w2:
		return _weapon_skill_desc_line(w1) + " 雙人：1P＝Q，2P＝P。"
	return (
		"雙人：武器技依各自主手（1P＝Q，2P＝P）。1P："
		+ _weapon_skill_short(w1)
		+ " 2P："
		+ _weapon_skill_short(w2)
		+ "。"
	)


func refresh(
	slot_ids: Array[StringName],
	inv: GameInventory,
	p1_skill_cd: float = 0.0,
	two_p: bool = false,
	p2_skill_cd: float = 0.0,
	p1_dash_cd: float = 0.0,
	p2_dash_cd: float = 0.0,
	p1_char_skill: StringName = &"dash",
	p2_char_skill: StringName = &"dash",
	p1_charge_ready: bool = false,
	p2_charge_ready: bool = false,
	p1_iron_wall_rem: float = 0.0,
	p2_iron_wall_rem: float = 0.0
) -> void:
	_last_inv = inv
	_last_two_p = two_p
	for i in mini(9, _icons.size()):
		var sn: StringName = &"" if i >= slot_ids.size() else slot_ids[i]
		var tr := _icons[i]
		match sn:
			&"axe":
				tr.texture = HudItemIcons.tex(HudItemIcons.AXE)
				tr.modulate = Color.WHITE if inv.has_axe() else Color(0.45, 0.45, 0.5, 1.0)
			&"wood_spear":
				tr.texture = HudItemIcons.tex(HudItemIcons.WOOD_SPEAR)
				var has_spear := (
					inv.spear_spare > 0
					or inv.equip_main == &"wood_spear"
					or (two_p and inv.equip_main_p2 == &"wood_spear")
				)
				tr.modulate = Color.WHITE if has_spear else Color(0.45, 0.45, 0.5, 1.0)
			&"iron_sword":
				tr.texture = HudItemIcons.tex(HudItemIcons.IRON_SWORD)
				var has_sword := (
					inv.sword_spare > 0
					or inv.equip_main == &"iron_sword"
					or (two_p and inv.equip_main_p2 == &"iron_sword")
				)
				tr.modulate = Color.WHITE if has_sword else Color(0.45, 0.45, 0.5, 1.0)
			&"berries":
				tr.texture = HudItemIcons.tex(HudItemIcons.BERRY)
				tr.modulate = Color.WHITE if inv.berries > 0 else Color(0.45, 0.45, 0.5, 1.0)
			&"jerky":
				tr.texture = HudItemIcons.tex(HudItemIcons.BERRY_JERKY)
				tr.modulate = Color.WHITE if inv.berry_jerky > 0 else Color(0.45, 0.45, 0.5, 1.0)
			&"meat_cutlet":
				tr.texture = HudItemIcons.tex(HudItemIcons.MEAT_CUTLET)
				tr.modulate = Color.WHITE if inv.meat_cutlet > 0 else Color(0.45, 0.45, 0.5, 1.0)
			&"bbq_meat":
				tr.texture = HudItemIcons.tex(HudItemIcons.BBQ_MEAT)
				tr.modulate = Color.WHITE if inv.bbq_meat > 0 else Color(0.45, 0.45, 0.5, 1.0)
			&"water":
				tr.texture = HudItemIcons.tex(HudItemIcons.WATER)
				tr.modulate = Color.WHITE if inv.water > 0 else Color(0.45, 0.45, 0.5, 1.0)
			_:
				tr.texture = null
				tr.modulate = Color.WHITE
		# 空槽隱藏暗底，有物品才顯示格子背景
		# 空槽仍顯示格子背景（讓玩家知道有快捷鍵位），有物品時邊框加亮
		if i < _slot_styles.size():
			var st := _slot_styles[i]
			if sn == &"":
				st.bg_color = Color(0.10, 0.13, 0.18, 0.72)
				st.border_color = Color(0.22, 0.28, 0.38, 0.55)
			else:
				st.bg_color = Color(0.14, 0.18, 0.24, 0.96)
				st.border_color = Color(0.32, 0.40, 0.52, 0.85)
			_nums[i].visible = true
	if _dash_hint != null:
		var dt := _dash_hint_text(
			p1_char_skill,
			p2_char_skill,
			two_p,
			p1_charge_ready,
			p2_charge_ready,
			p1_iron_wall_rem,
			p2_iron_wall_rem
		)
		if p1_dash_cd > 0.001:
			dt += "（1P 冷卻 %.1fs）" % p1_dash_cd
		if two_p and p2_dash_cd > 0.001:
			dt += "（2P 冷卻 %.1fs）" % p2_dash_cd
		_dash_hint.text = dt
	if _dash_icon != null:
		_dash_icon.texture = HudItemIcons.character_skill_tex(p1_char_skill)
		var dash_dim := p1_dash_cd > 0.001 or (two_p and p2_dash_cd > 0.001)
		_dash_icon.modulate = Color(0.55, 0.58, 0.62, 1.0) if dash_dim else Color.WHITE
	if _skill_hint != null:
		var t := _skill_hint_text(inv, two_p)
		if p1_skill_cd > 0.0:
			t += "（1P 冷卻 %.1fs）" % p1_skill_cd
		if two_p and p2_skill_cd > 0.0:
			t += "（2P 冷卻 %.1fs）" % p2_skill_cd
		_skill_hint.text = t
	if _skill_icon != null:
		_skill_icon.texture = HudItemIcons.weapon_skill_icon_for_main(inv.equip_main)
		var on_cd := p1_skill_cd > 0.001 or (two_p and p2_skill_cd > 0.001)
		_skill_icon.modulate = Color(0.55, 0.58, 0.62, 1.0) if on_cd else Color.WHITE
	if _char_cd_bar != null:
		var drem := p1_dash_cd if not two_p else maxf(p1_dash_cd, p2_dash_cd)
		_char_cd_bar.visible = drem > 0.001
		_char_cd_bar.max_value = GameConstants.CHARACTER_DASH_COOLDOWN_SEC
		_char_cd_bar.value = drem
	if _weapon_cd_bar != null:
		var wrem := p1_skill_cd if not two_p else maxf(p1_skill_cd, p2_skill_cd)
		_weapon_cd_bar.visible = wrem > 0.001
		_weapon_cd_bar.max_value = GameConstants.WEAPON_SKILL_COOLDOWN
		_weapon_cd_bar.value = wrem


func _skill_panel_wrap(col: VBoxContainer) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.13, 0.18, 0.82)
	s.set_corner_radius_all(6)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", s)
	pc.add_child(col)
	return pc
