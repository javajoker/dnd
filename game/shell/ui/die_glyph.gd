# 骰型图标（docs/en/framework/17-polyhedral-dice-spec.md §3/§6：骰子条显示正确骰型）
# 程序绘制轮廓（无字体/贴图依赖）：d4 三角 / d6 方 / d8 菱 / d10 风筝 / d12 五边 / d20 六边，中间写数值。
# 纯呈现：只接收壳层给的骰型与值。
class_name DieGlyph
extends Control

var die := "d20":
	set(v):
		die = v
		queue_redraw()
var value_text := "":
	set(v):
		value_text = v
		queue_redraw()
var face_color := Color(0.93, 0.80, 0.45)
var edge_color := Color(0.55, 0.42, 0.18)

func _init() -> void:
	custom_minimum_size = Vector2(52, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## 轮廓顶点（单位圆内，y 向下）。
static func outline(kind: String) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match kind:
		"d4":
			for k: int in 3:
				var a := deg_to_rad(-90.0 + 120.0 * k)
				pts.append(Vector2(cos(a), sin(a)))
		"d6":
			pts = PackedVector2Array([Vector2(-0.78, -0.78), Vector2(0.78, -0.78), Vector2(0.78, 0.78), Vector2(-0.78, 0.78)])
		"d8":
			pts = PackedVector2Array([Vector2(0, -1), Vector2(0.82, 0), Vector2(0, 1), Vector2(-0.82, 0)])
		"d10":
			pts = PackedVector2Array([Vector2(0, -1), Vector2(0.9, -0.15), Vector2(0, 1), Vector2(-0.9, -0.15)])
		"d12":
			for k: int in 5:
				var a2 := deg_to_rad(-90.0 + 72.0 * k)
				pts.append(Vector2(cos(a2), sin(a2)))
		_:
			for k: int in 6:
				var a3 := deg_to_rad(-90.0 + 60.0 * k)
				pts.append(Vector2(cos(a3), sin(a3)))
	return pts

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46
	var poly := PackedVector2Array()
	for p: Vector2 in outline(die):
		poly.append(c + p * r)
	draw_colored_polygon(poly, Color(face_color.r, face_color.g, face_color.b, 0.12))
	var loop := poly.duplicate()
	loop.append(poly[0])
	draw_polyline(loop, edge_color, 2.0, true)
	var font := get_theme_default_font()
	var text := value_text if value_text != "" else die
	var fs := 20 if text.length() <= 2 else 14
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string(font, c + Vector2(-tw.x * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, face_color)
