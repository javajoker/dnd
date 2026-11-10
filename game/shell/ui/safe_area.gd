# 安全区（tech/01 §10.1 移动平台层）：刘海 / 圆角 / Home 指示条避让。
# - 真机：DisplayServer.get_display_safe_area()（屏幕像素）换算到视口坐标（stretch canvas_items）；
# - 桌面：默认无内缩；`-- --safe-area=上,右,下,左` 或 override 注入模拟值（截图走查 / 测试）；
# - 各界面根节点与双壳在 _ready 里调用 fit / apply_offsets——内容落在安全区内，
#   全屏背景类覆盖层（转场幕布、关键判定演出）仍可铺满整屏。
class_name SafeArea
extends RefCounted

## 模拟内缩（视口单位）：{top, right, bottom, left}；为空 = 按平台计算。
static var override_insets: Dictionary = {}

## 当前内缩（视口单位）。
static func insets(vp: Viewport) -> Dictionary:
	if not override_insets.is_empty():
		return override_insets
	var zero := {"top": 0.0, "right": 0.0, "bottom": 0.0, "left": 0.0}
	if vp == null or not OS.has_feature("mobile"):
		return zero
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	var vp_size := vp.get_visible_rect().size
	if safe.size.x <= 0 or screen.x <= 0:
		return zero
	var sx := vp_size.x / float(screen.x)
	var sy := vp_size.y / float(screen.y)
	return {"top": safe.position.y * sy, "left": safe.position.x * sx,
		"bottom": (screen.y - safe.end.y) * sy, "right": (screen.x - safe.end.x) * sx}

## 视口内的安全矩形。
static func rect(vp: Viewport) -> Rect2:
	var full := vp.get_visible_rect()
	var i := insets(vp)
	return Rect2(full.position + Vector2(i["left"], i["top"]),
		full.size - Vector2(i["left"] + i["right"], i["top"] + i["bottom"]))

## 以位置 + 尺寸落位（父节点非 Control 的界面根）。
static func fit(c: Control) -> void:
	var r := rect(c.get_viewport())
	c.position = r.position
	c.size = r.size

## 以锚点全屏 + 偏移内缩落位（双壳根节点）。
static func apply_offsets(c: Control) -> void:
	var i := insets(c.get_viewport())
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.offset_left = i["left"]
	c.offset_top = i["top"]
	c.offset_right = -i["right"]
	c.offset_bottom = -i["bottom"]

## 解析 `--safe-area=上,右,下,左`（命令行模拟）。
static func parse_arg(arg: String) -> Dictionary:
	var parts := arg.trim_prefix("--safe-area=").split(",")
	if parts.size() != 4:
		return {}
	return {"top": float(parts[0]), "right": float(parts[1]), "bottom": float(parts[2]), "left": float(parts[3])}
