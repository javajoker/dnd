# 通用半屏信息弹层（04 §3.3：半屏弹层不打断当前情境）——时间边预告（04 §3.1 点时间钟）等只读列表。
# 双壳共用同一组件，呈现数据由调用方以纯字符串列表传入。
class_name InfoPopup
extends Control

var title_label: Label
var icon_rect: TextureRect # 可选大图标（道具详情，tech/05 §7.2）；无图隐藏
var body_label: RichTextLabel
var close_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			hide())
	add_child(dim)
	var panel := PanelContainer.new()
	# 半屏弹层：下 50%（04 §3.3）
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.55
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", Palette.sheet_style()) # 不透明半屏底板（与分队 / 地图卡同一底板）
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	v.add_child(title_label)
	icon_rect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(72, 72)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.visible = false
	v.add_child(icon_rect)
	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = false
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.scroll_following = false
	v.add_child(body_label)
	close_button = Button.new()
	close_button.text = Texts.s(&"HUB_CLOSE")
	close_button.pressed.connect(hide)
	v.add_child(close_button)
	hide()

## 弹出并填充只读内容（icon 可选：道具详情大图标）。
func show_info(title: String, lines: Array, icon: Texture2D = null) -> void:
	title_label.text = title
	icon_rect.texture = icon
	icon_rect.visible = icon != null
	body_label.text = "\n".join(lines)
	popup()

func popup() -> void:
	visible = true
