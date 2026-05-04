class_name RadialPointLightTex
extends RefCounted
## 共用：PointLight2D 圓形柔邊貼圖（營火、玩家攜帶光等）。
## inner_dim：小於 1 時壓低圓心附近 alpha（減輪心過亮）；inner_blend 為從圓心到「恢復滿強度」的歸一距離。


static func create_texture(
	size: int = 256, inner_dim: float = 1.0, inner_blend: float = 0.42
) -> ImageTexture:
	var cx := (size - 1) * 0.5
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(float(x), float(y)).distance_to(Vector2(cx, cx))
			var t: float = clampf(d / cx, 0.0, 1.0)
			var a: float = 1.0 - smoothstep(0.08, 1.0, pow(t, 1.05))
			if inner_dim < 0.999:
				var w: float = lerpf(inner_dim, 1.0, smoothstep(0.0, inner_blend, t))
				a *= w
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
