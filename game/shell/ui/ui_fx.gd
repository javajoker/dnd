# UI 动效（docs/en/tech/05 §10）：给全部交互组件加"游戏手感"，零侵入——
# 挂在 SceneTree.node_added 上，任何界面加入树时自动生效：
# - 按钮：按下缩 0.94、松开回弹（TRANS_BACK）；悬停微亮（桌面）；元数据 "no_ui_fx" 可豁免；
# - 大字号标签（≥20）：自动挂 TitleLabel 变体（金墨描边标题），已自定颜色的不动；
# - 弹层底板（UiKit.sheet_style 标记 ui_sheet）：显现时自下而上弹入 + 淡入；
# - toast：pop() 供壳调用（缩放弹出）。
# 纯呈现：只改 scale / modulate / theme_type_variation，不碰布局位置（不与容器排布打架）。
class_name UiFx
extends RefCounted

const PRESS_SCALE := 0.94
const PRESS_IN := 0.06
const PRESS_OUT := 0.16
const SHEET_IN := 0.22
const TITLE_MIN_SIZE := 20
const TITLE_SCALE := 0.85

static var installed := false
static var enabled := true
static var stats := {"buttons": 0, "titles": 0, "sheets": 0, "presses": 0, "sheet_ins": 0}

static func install(tree: SceneTree) -> void:
	if installed or tree == null:
		return
	installed = true
	tree.node_added.connect(_on_node_added)

static func _on_node_added(n: Node) -> void:
	if not enabled or n.has_meta(&"no_ui_fx"):
		return
	if n is BaseButton:
		_hook_button(n as BaseButton)
	elif n is Label:
		_maybe_title(n as Label)
	if n is PanelContainer or n is Panel:
		_maybe_sheet(n as Control)

# ---------------------------------------------------------------- 按钮

static func _hook_button(b: BaseButton) -> void:
	if b.has_meta(&"ui_fx_hooked"):
		return
	b.set_meta(&"ui_fx_hooked", true)
	stats["buttons"] += 1
	b.button_down.connect(func() -> void: press(b, true))
	b.button_up.connect(func() -> void: press(b, false))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.self_modulate = Color(1.12, 1.1, 1.05))
	b.mouse_exited.connect(func() -> void: b.self_modulate = Color.WHITE)

## 按压回弹（也供测试 / 键盘确认直调）。
static func press(b: Control, down: bool) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	b.pivot_offset = b.size * 0.5
	var prev: Variant = b.get_meta(&"ui_fx_tween") if b.has_meta(&"ui_fx_tween") else null
	if prev is Tween and (prev as Tween).is_valid():
		(prev as Tween).kill()
	var tw := b.create_tween()
	b.set_meta(&"ui_fx_tween", tw)
	if down:
		stats["presses"] += 1
		tw.tween_property(b, "scale", Vector2.ONE * PRESS_SCALE, PRESS_IN).set_trans(Tween.TRANS_QUAD)
	else:
		tw.tween_property(b, "scale", Vector2.ONE, PRESS_OUT).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- 标题

static func _maybe_title(l: Label) -> void:
	if l.theme_type_variation != &"" or l.has_theme_color_override("font_color"):
		return
	if not l.has_theme_font_size_override("font_size"):
		return
	if l.get_theme_font_size("font_size") < TITLE_MIN_SIZE:
		return
	l.theme_type_variation = &"TitleLabel"
	# 标题字体（如 Cinzel 全小型大写）比正文宽：字号按 TITLE_SCALE 收一档；占满整行的标题允许换行，不出屏
	var fs := l.get_theme_font_size("font_size")
	l.add_theme_font_size_override("font_size", maxi(TITLE_MIN_SIZE - 2, int(round(fs * TITLE_SCALE))))
	if l.get_parent() is VBoxContainer and l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats["titles"] += 1

# ---------------------------------------------------------------- 弹层

static func _maybe_sheet(c: Control) -> void:
	if c.has_meta(&"ui_fx_sheet"):
		return
	if not c.has_theme_stylebox_override("panel"):
		return
	var sb := c.get_theme_stylebox("panel")
	if sb == null or not sb.has_meta(&"ui_sheet"):
		return
	c.set_meta(&"ui_fx_sheet", true)
	stats["sheets"] += 1
	c.visibility_changed.connect(func() -> void:
		if c.is_visible_in_tree():
			sheet_in(c))
	if c.is_visible_in_tree():
		sheet_in.call_deferred(c)

## 弹层入场：底边为轴从 0.92 放大到 1 + 淡入（只动 scale / modulate，不碰位置）。
static func sheet_in(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	stats["sheet_ins"] += 1
	c.pivot_offset = Vector2(c.size.x * 0.5, c.size.y)
	c.scale = Vector2(1.0, 0.92)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, SHEET_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, SHEET_IN * 0.8)

# ---------------------------------------------------------------- 横幅提示

## toast 弹出（壳在显示横幅时调用）：中心缩放 0.8 → 1.05 → 1。
static func pop(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * 0.8
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * 1.05, 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(c, "scale", Vector2.ONE, 0.1)
