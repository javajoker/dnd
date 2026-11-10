# 补给与休息半屏弹层（04 §3.3；战役书 §4 N1-1；11 §7.2 短休/长休）。双壳与结算屏共用同一组件：
# - hub 模式（旅店）：商店 + 旅店长休（免费）；
# - camp 模式（野外营地，战斗之间）：补给（同货单）+ 逐人短休（花费生命骰）+ 长休（时间钟 +1）。
# 壳只负责弹出与本组件的信号转发；购买/休息的写板全部在 core（StoryGraph.hub_buy/short_rest/long_rest）。
class_name HubPopup
extends Control

const MODE_HUB := &"hub"
const MODE_CAMP := &"camp"

signal buy_requested(item_id: String)
signal rest_requested ## hub = 旅店长休；camp = 野外长休（耗时钟）
signal short_rest_requested(char_id: String)
signal use_item_requested(item_id: String, char_id: String) ## 战斗外用治疗道具（11 §8.2；营地 / 旅店 / 整备前）

var mode: StringName = MODE_HUB
var rest_free := false ## 营地模式下长休免费（rest 安全落脚节点，StoryGraph.rest_is_free）
var title_label: Label
var gold_label: Label
var party_box: VBoxContainer ## 队伍 HP / 生命骰（两种模式都显示：休息前先看清伤势）
var stock_box: VBoxContainer
var use_box: VBoxContainer ## 「使用道具」：每件治疗道具一行 + 每名伤员一个「给 X」按钮
## 可用道具 [{id, name, heal, count}]（StoryGraph.camp_usable_items）；调用方在 open / bind 前赋值。
var usable: Array = []
var hint_label: Label
var rest_button: Button
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
	# 弹层：下 75%（04 §3.3；营地有队伍 / 用道具 / 补给三段，竖屏半屏放不下）
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.25
	panel.anchor_bottom = 1.0
	panel.add_theme_stylebox_override("panel", Palette.sheet_style()) # 不透明底板（调色板令牌 sheet / accent）
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	title_label = Label.new()
	title_label.text = Texts.s(&"HUB_SHOP")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	v.add_child(title_label)
	gold_label = Label.new()
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(gold_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	party_box = VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 4)
	body.add_child(party_box)
	use_box = VBoxContainer.new()
	use_box.name = "UseItems"
	use_box.add_theme_constant_override("separation", 4)
	body.add_child(use_box)
	stock_box = VBoxContainer.new()
	stock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_box.add_theme_constant_override("separation", 4)
	body.add_child(stock_box)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	hint_label.add_theme_font_size_override("font_size", 13)
	v.add_child(hint_label)
	rest_button = Button.new()
	rest_button.custom_minimum_size = Vector2(0, 44)
	rest_button.pressed.connect(func() -> void: rest_requested.emit())
	v.add_child(rest_button)
	close_button = Button.new()
	close_button.text = Texts.s(&"HUB_CLOSE")
	close_button.custom_minimum_size = Vector2(0, 44)
	close_button.pressed.connect(hide)
	v.add_child(close_button)
	hide()

## 填充货单 / 金币 / 队伍（数据来自 StoryVM.build 的 vm.gold / vm.stock / vm.party）。
## p_mode 缺省沿用上次模式（购买/休息后刷新不切换模式）。
func bind(gold: int, stock: Array, party: Array = [], p_mode: StringName = &"") -> void:
	if p_mode != &"":
		mode = p_mode
	var camp := mode == MODE_CAMP
	title_label.text = Texts.s(&"CAMP_TITLE") if camp else Texts.s(&"HUB_SHOP")
	gold_label.text = Texts.s(&"HUB_GOLD") % gold
	hint_label.text = Texts.s(&"CAMP_HINT") if camp else Texts.s(&"HUB_REST_HINT")
	rest_button.text = Texts.s(&"CAMP_LONG_REST") % StoryGraph.CAMP_LONG_REST_CLOCK if camp and not rest_free \
		else Texts.s(&"HUB_INN_REST")
	for child: Node in party_box.get_children():
		party_box.remove_child(child) # 先摘再释放：新行同名（Party_<id>）不被自动改名
		child.queue_free()
	for p: Variant in party:
		party_box.add_child(_party_row(p as Dictionary, camp))
	_render_use(party)
	for child: Node in stock_box.get_children():
		stock_box.remove_child(child)
		child.queue_free()
	if camp and not stock.is_empty():
		var sup := Label.new()
		sup.text = Texts.s(&"CAMP_SUPPLIES")
		sup.add_theme_color_override("font_color", Palette.color("accent"))
		stock_box.add_child(sup)
	for item: Variant in stock:
		var it: Dictionary = item
		var b := Button.new()
		b.text = Texts.s(&"HUB_SHOP_LINE") % [str(it.get("name", "")), int(it.get("price", 0)),
			Texts.s(&"HUB_OWNED_TAG") % int(it["owned"]) if int(it.get("owned", 0)) > 0 else ""]
		b.disabled = not bool(it.get("affordable", false))
		if b.disabled:
			b.text += Texts.s(&"PAREN_FMT") % Texts.s(&"HUB_NO_GOLD").trim_suffix("。").trim_suffix(".")
		b.custom_minimum_size = Vector2(0, 40)
		var iid := str(it.get("id", ""))
		ArtLoader.decorate_item_button(b, iid, it)
		b.pressed.connect(func() -> void: buy_requested.emit(iid))
		stock_box.add_child(b)

## 「使用道具」段：持有的治疗道具 × 伤员（满血队员不出按钮；全员满血给一行说明）。
func _render_use(party: Array) -> void:
	for child: Node in use_box.get_children():
		use_box.remove_child(child)
		child.queue_free()
	if usable.is_empty() or party.is_empty():
		return
	var head := Label.new()
	head.text = Texts.s(&"CAMP_USE_HEAD")
	head.add_theme_color_override("font_color", Palette.color("accent"))
	use_box.add_child(head)
	var wounded: Array = party.filter(func(p: Variant) -> bool:
		return int((p as Dictionary).get("hp", 0)) < int((p as Dictionary).get("max_hp", 0)))
	for u: Variant in usable:
		var it: Dictionary = u
		var iid := str(it.get("id", ""))
		var row := HFlowContainer.new()
		row.name = "Use_%s" % iid
		row.add_theme_constant_override("h_separation", 6)
		var lbl := Button.new() # 扁平按钮当标签用：可挂图标，点了无动作
		lbl.flat = true
		lbl.focus_mode = Control.FOCUS_NONE
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.text = Texts.s(&"CAMP_USE_LINE") % [str(it.get("name", iid)), int(it.get("count", 0)), str(it.get("heal", ""))]
		ArtLoader.decorate_item_button(lbl, iid, it)
		row.add_child(lbl)
		for p2: Variant in wounded:
			var cid := str((p2 as Dictionary).get("id", ""))
			var b := Button.new()
			b.name = "Give_%s" % cid
			b.custom_minimum_size = Vector2(0, 40)
			b.text = Texts.s(&"CAMP_USE_ON") % str((p2 as Dictionary).get("name", cid))
			b.pressed.connect(func() -> void: use_item_requested.emit(iid, cid))
			row.add_child(b)
		use_box.add_child(row)
	if wounded.is_empty():
		var none := Label.new()
		none.text = Texts.s(&"CAMP_USE_NONE")
		none.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
		use_box.add_child(none)

## 队伍行：名字 + HP + 生命骰；营地模式附「短休」按钮（满血 / 无骰时禁用并说明原因）。
func _party_row(p: Dictionary, camp: bool) -> Control:
	var row := HBoxContainer.new()
	row.name = "Party_%s" % str(p.get("id", ""))
	row.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.text = Texts.s(&"CAMP_PARTY_LINE") % [str(p.get("name", "")), int(p.get("hp", 0)), int(p.get("max_hp", 0)),
		int(p.get("hd_left", 0)), int(p.get("hd_max", 0)), str(p.get("hit_die", "d8"))]
	row.add_child(lbl)
	if camp:
		var b := Button.new()
		b.name = "ShortRest"
		b.custom_minimum_size = Vector2(0, 40)
		var full := int(p.get("hp", 0)) >= int(p.get("max_hp", 0))
		var no_dice := int(p.get("hd_left", 0)) <= 0
		b.disabled = full or no_dice
		b.text = Texts.s(&"CAMP_FULL") if full else (Texts.s(&"CAMP_NO_DICE") if no_dice else Texts.s(&"CAMP_SHORT_REST"))
		var cid := str(p.get("id", ""))
		b.pressed.connect(func() -> void: short_rest_requested.emit(cid))
		row.add_child(b)
	return row

func open(gold: int, stock: Array, party: Array = [], p_mode: StringName = MODE_HUB,
		p_rest_free: bool = false) -> void:
	rest_free = p_rest_free or p_mode == MODE_HUB
	bind(gold, stock, party, p_mode)
	visible = true
