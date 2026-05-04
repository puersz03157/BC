extends StaticBody2D
## 標記、繪製與碰撞（layer 1，與樹石一致）。PointLight2D：圓形柔光，僅夜間啟用。

var _sprite: Sprite2D
var _light: PointLight2D
## 深夜滿強度時的基準（與 campfire_light_strength 相乘；ADD 混合已偏亮，不宜過高）。
const _NIGHT_ENERGY_PEAK := 1.12
## 光暈半徑主要由 texture_scale 決定（先前約 2.8 在 720p 下過大）。
const _TEXTURE_SCALE_BASE := 1.42


func _ready() -> void:
	add_to_group("campfire")
	collision_layer = 1
	collision_mask = 0
	z_index = 1
	var sh := CircleShape2D.new()
	sh.radius = GameConstants.CAMPFIRE_COLLISION_RADIUS
	var col := CollisionShape2D.new()
	col.shape = sh
	## 關閉子節點顯示（除錯「可視碰撞」開啟時較不刺眼；不影響碰撞）。
	col.visible = false
	add_child(col)
	VisualRegistry.ensure_baked()
	_sprite = Sprite2D.new()
	_sprite.texture = VisualRegistry.campfire_tex()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	add_child(_sprite)
	_light = PointLight2D.new()
	## 圓心略壓暗，避免 ADD 混合時中心一團過亮。
	_light.texture = RadialPointLightTex.create_texture(256, 0.5, 0.44)

	_light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_light.color = Color(1.0, 0.74, 0.48, 1.0)
	_light.energy = 0.0
	## ADD：CanvasModulate 夜間壓暗時，MIX 易在光心出現異常暗斑；ADD 為正常疊光。
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	_light.shadow_enabled = false
	_light.texture_scale = _TEXTURE_SCALE_BASE
	_light.position = Vector2.ZERO
	add_child(_light)


func _process(_delta: float) -> void:
	if _sprite:
		var pulse := 0.92 + 0.08 * sin(Time.get_ticks_msec() * 0.012)
		_sprite.modulate = Color(pulse, pulse * 0.95, 0.88, 1.0)
	if _light:
		var flicker := 0.96 + 0.04 * sin(Time.get_ticks_msec() * 0.016)
		var str := 0.0
		var rad_scale := 1.0
		var main := get_tree().get_first_node_in_group("game_main")
		if main:
			if main.has_method("campfire_light_strength"):
				str = main.campfire_light_strength()
			if main.has_method("campfire_light_radius_scale"):
				rad_scale = main.campfire_light_radius_scale()
		_light.enabled = str > 0.02
		if not _light.enabled:
			_light.energy = 0.0
			return
		_light.texture_scale = _TEXTURE_SCALE_BASE * rad_scale
		_light.energy = _NIGHT_ENERGY_PEAK * flicker * str
