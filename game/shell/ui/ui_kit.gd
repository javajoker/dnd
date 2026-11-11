# 游戏 UI 套件（docs/en/tech/05 §10；tech/07 §3 theme）：全部控件的"游戏化"外观。
# - 九宫格框体运行时按调色板令牌程序化生成（金墨双线框、角饰菱钉、渐变底、悬停外发光）——
#   换一款游戏改 theme.palette 即换色，无需重画素材；
# - 外部美术覆盖：res://assets/art/ui/ui_<name>.png（或游戏清单 theme.ui_dir 下同名文件）存在即用它，
#   边距读 MARGINS（与程序化版本同口径，见 tech/08 §3.4 提示词）；
# - 纯呈现：不读写 Board / 事件流。
class_name UiKit
extends RefCounted

const UI_DIR := "res://assets/art/ui"

## 框体规格：尺寸 / 九宫格边距 / 内容边距。
const SPECS := {
	"button": {"size": 48, "margin": 14, "content": Vector4(12, 7, 12, 7)},
	"button_hover": {"size": 48, "margin": 14, "content": Vector4(12, 7, 12, 7)},
	"button_pressed": {"size": 48, "margin": 14, "content": Vector4(12, 8, 12, 6)},
	"button_disabled": {"size": 48, "margin": 14, "content": Vector4(12, 7, 12, 7)},
	"panel": {"size": 96, "margin": 26, "content": Vector4(20, 18, 20, 18)},
	"sheet": {"size": 96, "margin": 26, "content": Vector4(20, 24, 20, 14)},
	"toast": {"size": 64, "margin": 22, "content": Vector4(30, 11, 30, 11)},
	"field": {"size": 32, "margin": 10, "content": Vector4(14, 10, 14, 10)},
	"track": {"size": 16, "margin": 7, "content": Vector4(0, 0, 0, 0)},
	"fill": {"size": 16, "margin": 7, "content": Vector4(0, 0, 0, 0)},
	"grabber": {"size": 16, "margin": 7, "content": Vector4(0, 0, 0, 0)},
	"tooltip": {"size": 32, "margin": 10, "content": Vector4(14, 10, 14, 10)},
}

## 交付框体的最小内容边距 = 九宫格角边距 × 本比例（角边距含描边与角饰，文字落在描边以内一段）。
const CONTENT_RATIO := 0.55
## 默认面板（状态带 / 操作台等）的内容边距：文字不贴框。
const SNUG_PAD := 8.0

static var _cache: Dictionary = {}
static var _external: Dictionary = {}   # name -> true（用的是美术交付文件）
static var _margins: Dictionary = {}    # ui_kit.json：外部框体的九宫格边距 {name: [l, t, r, b]}
static var _margins_loaded := false

static func reset() -> void:
	_cache.clear()
	_external.clear()
	_margins.clear()
	_margins_loaded = false

static func _ui_dir() -> String:
	return str((GameManifest.data().get("theme", {}) as Dictionary).get("ui_dir", UI_DIR))

## tools/import_ui_kit.gd 写出的边距表（外部框体专用）。
static func external_margins(name: String) -> Array:
	if not _margins_loaded:
		_margins_loaded = true
		var p := _ui_dir().path_join("ui_kit.json")
		if FileAccess.file_exists(p):
			var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
			if raw is Dictionary:
				_margins = raw
	return _margins.get(name, [])

static func is_external(name: String) -> bool:
	texture(name)
	return _external.has(name)

# ---------------------------------------------------------------- 纹理与样式

## 框体纹理：外部文件优先，否则程序化生成（按调色板）。
static func texture(name: String) -> Texture2D:
	if _cache.has(name):
		return _cache[name]
	var tex: Texture2D = null
	var path := _ui_dir().path_join("ui_%s.png" % name)
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_external[name] = true
	else:
		tex = ImageTexture.create_from_image(render(name))
	_cache[name] = tex
	return tex

## 九宫格样式盒（StyleBoxTexture）。
static func style(name: String) -> StyleBoxTexture:
	var spec: Dictionary = SPECS.get(name, SPECS["panel"])
	var sb := StyleBoxTexture.new()
	sb.texture = texture(name)
	var m := float(spec["margin"])
	var em := external_margins(name) if _external.has(name) else []
	sb.texture_margin_left = float(em[0]) if em.size() == 4 else m
	sb.texture_margin_top = float(em[1]) if em.size() == 4 else m
	sb.texture_margin_right = float(em[2]) if em.size() == 4 else m
	sb.texture_margin_bottom = float(em[3]) if em.size() == 4 else m
	var c: Vector4 = spec["content"]
	if em.size() == 4 and not ["track", "fill", "grabber"].has(name):
		# 交付框体：文字至少离开描边（≈ 九宫格角边距的 55%），不贴金线
		c = Vector4(maxf(c.x, round(float(em[0]) * CONTENT_RATIO)), maxf(c.y, round(float(em[1]) * CONTENT_RATIO)),
			maxf(c.z, round(float(em[2]) * CONTENT_RATIO)), maxf(c.w, round(float(em[3]) * CONTENT_RATIO)))
	sb.content_margin_left = c.x
	sb.content_margin_top = c.y
	sb.content_margin_right = c.z
	sb.content_margin_bottom = c.w
	if name == "button_hover" and not _external.has(name):
		sb.expand_margin_left = 3 # 外发光画在纹理留白里：外扩到控件边缘之外，内容区不缩
		sb.expand_margin_right = 3
		sb.expand_margin_top = 3
		sb.expand_margin_bottom = 3
	return sb

## 半屏弹层底板（带 ui_sheet 标记：UiFx 据此给弹层加入场动画）。
static func sheet_style() -> StyleBox:
	var sb := style("sheet")
	sb.set_meta(&"ui_sheet", true)
	return sb

# ---------------------------------------------------------------- 程序化框体（圆角矩形 SDF，自带抗锯齿）

static func _sd_round_rect(p: Vector2, c: Vector2, half: Vector2, r: float) -> float:
	var q := (p - c).abs() - (half - Vector2(r, r))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r

static func _sd_square_bottom(p: Vector2, c: Vector2, half: Vector2, r: float) -> float:
	# 上圆角、下直角（底部弹层贴屏幕下沿）
	if p.y > c.y:
		var q := (p - c).abs() - half
		return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
	return _sd_round_rect(p, c, half, r)

static func render(name: String) -> Image:
	var spec: Dictionary = SPECS.get(name, SPECS["panel"])
	var n := int(spec["size"])
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var accent := Palette.color("accent")
	var bg := Palette.color("bg")
	var panel := Palette.color("panel")
	var text := Palette.color("text")
	var muted := Palette.color("muted")
	# 每种框体的参数：pad（外发光留白）/ 圆角 / 边宽 / 底色上下 / 边色 / 内线 / 发光 / 角饰
	var pad := 3.0
	var r := 9.0
	var bw := 2.0
	var top := panel.lightened(0.12)
	var bottom := bg
	var border := Color(accent, 0.9)
	var inner := 0.0          # 内衬线距外缘距离（0 = 无）
	var glow := 0.0
	var studs := true
	var hi := 0.10            # 顶缘高光
	var square_bottom := false
	match name:
		"button_hover":
			top = panel.lightened(0.22)
			bottom = panel.lightened(0.02)
			border = accent.lightened(0.15)
			glow = 3.0
		"button_pressed":
			top = bg.darkened(0.2)
			bottom = panel.lightened(0.08)
			border = accent.lightened(0.25)
			hi = 0.0
		"button_disabled":
			top = panel.lerp(Color(0.25, 0.25, 0.27), 0.5)
			bottom = bg.lerp(Color(0.18, 0.18, 0.2), 0.5)
			border = Color(muted, 0.55)
			studs = false
		"panel":
			r = 12.0
			top = panel.lightened(0.05)
			bottom = bg.darkened(0.1)
			inner = 6.0
		"sheet":
			r = 16.0
			top = panel.lightened(0.06)
			bottom = bg
			inner = 6.0
			square_bottom = true
			pad = 0.0
		"toast":
			r = 20.0
			top = bg.darkened(0.2)
			bottom = panel
			border = accent
			inner = 4.0
		"field", "tooltip":
			r = 6.0
			top = bg.darkened(0.25)
			bottom = panel
			border = Color(accent, 0.6)
			studs = false
			hi = 0.0
		"track":
			r = 5.0
			bw = 1.0
			top = bg.darkened(0.3)
			bottom = bg
			border = Color(accent, 0.45)
			studs = false
			hi = 0.0
		"fill":
			r = 5.0
			bw = 1.0
			top = accent.lightened(0.2)
			bottom = accent.darkened(0.25)
			border = accent.lightened(0.35)
			studs = false
			hi = 0.25
		"grabber":
			r = 5.0
			bw = 1.0
			top = Color(accent, 0.7)
			bottom = Color(accent.darkened(0.2), 0.7)
			border = Color(text, 0.5)
			studs = false
	var c := Vector2(n, n) * 0.5
	var half := Vector2(n, n) * 0.5 - Vector2(pad, pad)
	for y: int in n:
		var t := float(y) / float(n - 1)
		var fill := top.lerp(bottom, t)
		for x: int in n:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := _sd_square_bottom(p, c, half, r) if square_bottom else _sd_round_rect(p, c, half, r)
			var col := Color(0, 0, 0, 0)
			if d < 0.5:
				var cover := clampf(0.5 - d, 0.0, 1.0)
				col = fill
				if hi > 0.0 and y < pad + bw + 4.0:
					col = col.lerp(Color.WHITE, hi * (1.0 - (y - pad) / (bw + 4.0)))
				var bmix := clampf(d + bw + 0.5, 0.0, 1.0) # 边带
				col = col.lerp(Color(border, 1.0), bmix * border.a)
				if inner > 0.0:
					var li := clampf(1.0 - absf(d + inner), 0.0, 1.0) # 内衬细线
					col = col.lerp(Color(accent, 1.0), li * 0.4)
				col.a = cover * fill.a if bmix < 0.5 else cover
			elif glow > 0.0 and d < glow + 0.5:
				col = Color(accent, 0.35 * (1.0 - d / (glow + 0.5)))
			img.set_pixel(x, y, col)
	if studs:
		_corner_ornaments(img, n, pad, r, accent, name == "panel" or name == "sheet" or name == "toast",
			square_bottom)
	return img

## 四角菱钉（按钮）/ 角饰（面板：菱钉 + 沿边短线）。
static func _corner_ornaments(img: Image, n: int, pad: float, r: float, accent: Color, fancy: bool,
		square_bottom: bool) -> void:
	var inset := pad + maxf(r * 0.55, 5.0)
	var s := 2.6 if not fancy else 3.6
	var corners := [Vector2(inset, inset), Vector2(n - inset, inset)]
	if not square_bottom:
		corners.append_array([Vector2(inset, n - inset), Vector2(n - inset, n - inset)])
	for cc: Vector2 in corners:
		for y: int in range(int(cc.y - s - 2), int(cc.y + s + 3)):
			for x: int in range(int(cc.x - s - 2), int(cc.x + s + 3)):
				if x < 0 or y < 0 or x >= n or y >= n:
					continue
				var d := absf(x + 0.5 - cc.x) + absf(y + 0.5 - cc.y) - s
				var a := clampf(0.5 - d, 0.0, 1.0)
				if a > 0.0:
					var base := img.get_pixel(x, y)
					img.set_pixel(x, y, Color(base.lerp(accent.lightened(0.2), a), maxf(base.a, a)))
		if fancy: # 沿边短线（金墨花角）
			var dir_x := 1.0 if cc.x < n * 0.5 else -1.0
			var dir_y := 1.0 if cc.y < n * 0.5 else -1.0
			for k: int in range(int(s) + 3, int(s) + 12):
				for pt: Vector2 in [Vector2(cc.x + dir_x * k, cc.y), Vector2(cc.x, cc.y + dir_y * k)]:
					var px := int(pt.x)
					var py := int(pt.y)
					if px >= 0 and py >= 0 and px < n and py < n:
						var fade := 1.0 - float(k - s - 3) / 9.0
						var b2 := img.get_pixel(px, py)
						img.set_pixel(px, py, Color(b2.lerp(accent, 0.75 * fade), maxf(b2.a, 0.75 * fade)))

## 滑块 / 拨杆的宝石钮（图标）。
static func gem_icon(size: int = 22) -> Texture2D:
	var key := "gem_%d" % size
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var accent := Palette.color("accent")
	var c := Vector2(size, size) * 0.5
	for y: int in size:
		for x: int in size:
			var p := Vector2(x + 0.5, y + 0.5)
			var d := absf(p.x - c.x) + absf(p.y - c.y) - size * 0.45 # 菱形
			var a := clampf(0.5 - d, 0.0, 1.0)
			var shade := accent.lightened(0.35 * (1.0 - (p.y / size))).darkened(0.25 * (p.y / size))
			if d > -2.0:
				shade = Color(0.08, 0.06, 0.04)
			img.set_pixel(x, y, Color(shade, a))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex

# ---------------------------------------------------------------- 主题

## 往主题里写入全部控件样式（UITheme.apply 调用）。
static func build(theme: Theme) -> void:
	reset()
	var accent := Palette.color("accent")
	var text := Palette.color("text")
	var muted := Palette.color("muted")
	# 按钮族（Button / OptionButton / MenuButton / 切换按钮——页签、模式开关都走 pressed 态）
	for t: StringName in [&"Button", &"OptionButton", &"MenuButton", &"CheckButton", &"CheckBox"]:
		if t == &"CheckButton" or t == &"CheckBox":
			theme.set_stylebox("normal", t, StyleBoxEmpty.new())
			theme.set_stylebox("hover", t, StyleBoxEmpty.new())
			theme.set_stylebox("pressed", t, StyleBoxEmpty.new())
			theme.set_color("font_color", t, text)
			theme.set_color("font_hover_color", t, accent)
			continue
		theme.set_stylebox("normal", t, style("button"))
		theme.set_stylebox("hover", t, style("button_hover"))
		theme.set_stylebox("pressed", t, style("button_pressed"))
		theme.set_stylebox("hover_pressed", t, style("button_pressed"))
		theme.set_stylebox("disabled", t, style("button_disabled"))
		theme.set_stylebox("focus", t, StyleBoxEmpty.new())
		theme.set_color("font_color", t, text)
		theme.set_color("font_hover_color", t, accent.lightened(0.15))
		theme.set_color("font_pressed_color", t, accent.lightened(0.25))
		theme.set_color("font_hover_pressed_color", t, accent.lightened(0.25))
		theme.set_color("font_focus_color", t, text)
		theme.set_color("font_disabled_color", t, Color(muted, 0.7))
		theme.set_color("font_outline_color", t, Color(0, 0, 0, 0.85))
		theme.set_constant("outline_size", t, 2)
		theme.set_constant("h_separation", t, 6)
	# 面板 / 弹层 / 提示
	# 默认面板：同一框体但内容边距收窄——不改变既有布局的最小尺寸（横屏战术格等按尺寸反推的布局
	# 遇到大边距会来回重排）；需要宽松留白的界面用 FramePanel 变体
	# 默认面板用简洁的 field 框（小角饰）：状态带等矮面板放得下；华丽 panel 框留给 FramePanel / 弹层
	theme.set_stylebox("panel", &"PanelContainer", _snug(style("field")))
	theme.set_stylebox("panel", &"Panel", _snug(style("field")))
	theme.set_type_variation(&"FramePanel", &"PanelContainer")
	theme.set_stylebox("panel", &"FramePanel", style("panel"))
	theme.set_stylebox("panel", &"PopupPanel", style("panel"))
	theme.set_stylebox("panel", &"PopupMenu", style("panel"))
	theme.set_stylebox("panel", &"TooltipPanel", style("tooltip"))
	theme.set_color("font_color", &"TooltipLabel", text)
	theme.set_color("font_color", &"PopupMenu", text)
	theme.set_color("font_hover_color", &"PopupMenu", accent)
	theme.set_stylebox("hover", &"PopupMenu", style("button_hover"))
	# 文字：正文淡阴影（压在插画上也可读）
	theme.set_color("font_color", &"Label", text)
	theme.set_color("font_shadow_color", &"Label", Color(0, 0, 0, 0.55))
	theme.set_constant("shadow_offset_x", &"Label", 1)
	theme.set_constant("shadow_offset_y", &"Label", 1)
	theme.set_color("default_color", &"RichTextLabel", text)
	theme.set_color("font_shadow_color", &"RichTextLabel", Color(0, 0, 0, 0.5))
	# 标题（UiFx 自动给大字号标签挂此变体）：金墨 + 描边 + 粗体
	theme.set_type_variation(&"TitleLabel", &"Label")
	theme.set_color("font_color", &"TitleLabel", accent.lightened(0.1))
	theme.set_color("font_outline_color", &"TitleLabel", Color(0.02, 0.02, 0.04, 0.95))
	theme.set_constant("outline_size", &"TitleLabel", 4)
	theme.set_color("font_shadow_color", &"TitleLabel", Color(0, 0, 0, 0.6))
	theme.set_constant("shadow_offset_y", &"TitleLabel", 2)
	var tf := UITheme.title_font()
	if tf != null:
		theme.set_font("font", &"TitleLabel", tf)
	# 横幅提示（toast / 战斗飘字条）
	theme.set_type_variation(&"ToastLabel", &"Label")
	theme.set_stylebox("normal", &"ToastLabel", style("toast"))
	theme.set_color("font_color", &"ToastLabel", accent.lightened(0.2))
	theme.set_color("font_outline_color", &"ToastLabel", Color(0, 0, 0, 0.9))
	theme.set_constant("outline_size", &"ToastLabel", 3)
	# 输入框
	for t2: StringName in [&"LineEdit", &"TextEdit"]:
		theme.set_stylebox("normal", t2, style("field"))
		theme.set_stylebox("focus", t2, style("button_hover"))
		theme.set_stylebox("read_only", t2, style("field"))
		theme.set_color("font_color", t2, text)
		theme.set_color("caret_color", t2, accent)
		theme.set_color("selection_color", t2, Color(accent, 0.35))
	# 滑条（音量等）
	for t3: StringName in [&"HSlider", &"VSlider"]:
		theme.set_stylebox("slider", t3, style("track"))
		theme.set_stylebox("grabber_area", t3, style("fill"))
		theme.set_stylebox("grabber_area_highlight", t3, style("fill"))
		theme.set_icon("grabber", t3, texture("grabber") if is_external("grabber") else gem_icon(24))
		theme.set_icon("grabber_highlight", t3, texture("grabber") if is_external("grabber") else gem_icon(26))
	# 滚动条：细金线
	for t4: StringName in [&"VScrollBar", &"HScrollBar"]:
		theme.set_stylebox("scroll", t4, _thin(Color(accent, 0.12)))
		theme.set_stylebox("grabber", t4, _thin(Color(accent, 0.55)))
		theme.set_stylebox("grabber_highlight", t4, _thin(Color(accent, 0.8)))
		theme.set_stylebox("grabber_pressed", t4, _thin(accent))
	# 进度条
	theme.set_stylebox("background", &"ProgressBar", style("track"))
	theme.set_stylebox("fill", &"ProgressBar", style("fill"))
	theme.set_color("font_color", &"ProgressBar", text)
	# 页签容器
	for t5: StringName in [&"TabContainer", &"TabBar"]:
		theme.set_stylebox("tab_selected", t5, style("button_pressed"))
		theme.set_stylebox("tab_unselected", t5, style("button"))
		theme.set_stylebox("tab_hovered", t5, style("button_hover"))
		theme.set_color("font_selected_color", t5, accent)
		theme.set_color("font_unselected_color", t5, text)
	theme.set_stylebox("panel", &"TabContainer", style("panel"))

## 细带面板（横屏上缘 / 日志带等按屏高比例冻结的条带）：同框体，只留左右内边距，放得下一行控件。
static func band_style() -> StyleBoxTexture:
	var sb := style("field")
	sb.set_content_margin(SIDE_LEFT, 8.0) # 只留左右：条带高度按屏高冻结，上下不再加
	sb.set_content_margin(SIDE_RIGHT, 8.0)
	sb.set_content_margin(SIDE_TOP, 0.0)
	sb.set_content_margin(SIDE_BOTTOM, 0.0)
	return sb

static func _snug(sb: StyleBoxTexture) -> StyleBoxTexture:
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_content_margin(side, SNUG_PAD)
	return sb

static func _thin(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	return sb
