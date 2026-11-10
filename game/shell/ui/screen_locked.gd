# 章节锁定页（06 §3.1 锁定态：可见但锁定 + 叙事化包装 + 半屏购买弹层；06 §7 英文市场：免费试玩 + 一次性解锁）。
# 进入带幕级门槛（tech/02 §2.2）且权利未点亮的幕时由 main 呈现；购买 / 恢复购买 / 回营地三个出口。
# 壳组件只转发意图，点亮写板由 main → Store → Entitlements 完成。
class_name ScreenLocked
extends Control

signal purchase_requested(key: String)
signal restore_requested
signal back_requested

var title_label: Label
var text_label: Label
var get_button: Button
var restore_button: Button
var back_button: Button
var shop_popup: ShopPopup
var _key := ""

func _ready() -> void:
	SafeArea.fit(self)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.custom_minimum_size = Vector2(340, 0)
	title_label.add_theme_font_size_override("font_size", UITheme.SIZE_TITLE)
	v.add_child(title_label)
	text_label = Label.new()
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(340, 0)
	text_label.add_theme_color_override("font_color", Color(0.75, 0.68, 0.5))
	v.add_child(text_label)
	get_button = _button(v, "")
	get_button.pressed.connect(func() -> void: shop_popup.open(_key, _name, _price,
		Texts.s(&"SHOP_LINE_CAMPAIGN") % [_name, _price]))
	restore_button = _button(v, Texts.s(&"STORE_RESTORE"))
	restore_button.pressed.connect(func() -> void: restore_requested.emit())
	back_button = _button(v, Texts.s(&"LOCK_BACK_HOME"))
	back_button.pressed.connect(func() -> void: back_requested.emit())
	shop_popup = ShopPopup.new()
	add_child(shop_popup)
	shop_popup.purchase_confirmed.connect(func(k: String) -> void: purchase_requested.emit(k))

var _name := ""
var _price := ""

## act_title = 被锁幕名；key = 权利键（运营配置 shop 条目）；product_name / price_text 来自运营配置（已按语言叠加）。
func bind(act_title: String, key: String, product_name: String, price_text: String, store_ok: bool) -> void:
	_key = key
	_name = product_name
	_price = price_text
	title_label.text = act_title
	text_label.text = "%s\n\n%s" % [Texts.s(&"LOCK_CHAPTER_TEXT"), Texts.s(&"LOCK_CHAPTER_DEMO")]
	get_button.text = Texts.s(&"LOCK_CHAPTER_GET") % price_text if price_text != "" else Texts.s(&"LOCK_CHAPTER_GET_NOPRICE")
	get_button.disabled = not store_ok
	restore_button.disabled = not store_ok

func _button(parent: Container, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(b)
	return b
