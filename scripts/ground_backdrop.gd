extends Node2D
## 大範圍草地噪聲底圖；之後可換成 TileMap 或整張手繪背景圖（Sprite2D.texture）。


func _ready() -> void:
	z_index = -80
	var ntex := NoiseTexture2D.new()
	ntex.width = 640
	ntex.height = 360
	ntex.seamless = true
	var noise := FastNoiseLite.new()
	noise.seed = 42
	noise.frequency = 0.032
	noise.fractal_octaves = 4
	ntex.noise = noise
	var g := Gradient.new()
	g.add_point(0.0, Color("#142018"))
	g.add_point(0.32, Color("#1c2e22"))
	g.add_point(0.62, Color("#2a4534"))
	g.add_point(1.0, Color("#3a5c44"))
	# NoiseTexture2D.color_ramp 在 Godot 4 為 Gradient，不是 GradientTexture1D
	ntex.color_ramp = g
	var sprite := Sprite2D.new()
	sprite.name = "GroundSprite"
	sprite.texture = ntex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = true
	sprite.position = Vector2(640, 360)
	sprite.scale = Vector2(2.65, 2.65)
	sprite.modulate = Color(0.94, 0.97, 0.92, 1.0)
	add_child(sprite)
