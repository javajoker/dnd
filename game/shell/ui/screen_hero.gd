# 建角屏（docs/en/framework/11 §1.1；04 §② 之后、序章之前）：选职业 + 出身。
# - 职业卡：名字 + 一句话定位 + 属性 / 生命骰 / 技能；出身卡：名字 + 背景故事；选中即显示完整故事；
# - "启程"上报选择（写板由引导层经 HeroBuild.choose 完成）；纯呈现。
class_name ScreenHero
extends Control

signal confirmed(class_id: String, background_id: String)
signal back_requested

var title: Label
var class_box: VBoxContainer
var bg_box: HFlowContainer
var story_label: Label
var confirm_button: Button
var back_button: Button

var _classes: Array = []
var _backgrounds: Array = []
var _skill_names := {}
var class_id := ""
var background_id := ""

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.color("bg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	var top := HBoxContainer.new()
	title = Label.new()
	title.text = Texts.s(&"HERO_TITLE")
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	back_button = Button.new()
	back_button.text = Texts.s(&"COMMON_BACK")
	back_button.custom_minimum_size = Vector2(0, 44)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back_button)
	v.add_child(top)
	var ch := Label.new()
	ch.text = Texts.s(&"HERO_CLASS_HEAD")
	ch.add_theme_color_override("font_color", Palette.color("accent"))
	v.add_child(ch)
	class_box = VBoxContainer.new()
	class_box.add_theme_constant_override("separation", 6)
	v.add_child(class_box)
	var bh := Label.new()
	bh.text = Texts.s(&"HERO_BG_HEAD")
	bh.add_theme_color_override("font_color", Palette.color("accent"))
	v.add_child(bh)
	bg_box = HFlowContainer.new()
	bg_box.add_theme_constant_override("h_separation", 6)
	bg_box.add_theme_constant_override("v_separation", 6)
	v.add_child(bg_box)
	story_label = Label.new()
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.custom_minimum_size = Vector2(0, 90)
	story_label.add_theme_color_override("font_color", Palette.color("muted"))
	v.add_child(story_label)
	confirm_button = Button.new()
	confirm_button.text = Texts.s(&"HERO_BEGIN")
	confirm_button.custom_minimum_size = Vector2(0, 56)
	confirm_button.add_theme_font_size_override("font_size", 20)
	confirm_button.pressed.connect(func() -> void:
		if class_id != "" and background_id != "":
			confirmed.emit(class_id, background_id))
	v.add_child(confirm_button)
	SafeArea.fit(self)

## data = {classes:[{id,name,desc,story,attrs,hit_die,skills[]}], backgrounds:[{id,name,story}], skill_names:{id:name}}
func bind(data: Dictionary) -> void:
	_classes = data.get("classes", [])
	_backgrounds = data.get("backgrounds", [])
	_skill_names = data.get("skill_names", {})
	if class_id == "" and not _classes.is_empty():
		class_id = str((_classes[0] as Dictionary)["id"])
	if background_id == "" and not _backgrounds.is_empty():
		background_id = str((_backgrounds[0] as Dictionary)["id"])
	_render()

func select_class(cid: String) -> void:
	class_id = cid
	_render()

func select_background(bid: String) -> void:
	background_id = bid
	_render()

func _render() -> void:
	for c: Node in class_box.get_children():
		class_box.remove_child(c)
		c.queue_free()
	for c2: Node in bg_box.get_children():
		bg_box.remove_child(c2)
		c2.queue_free()
	var attr_names: Dictionary = Texts.t(&"ATTR_SHORT")
	var story := ""
	for cl: Variant in _classes:
		var d: Dictionary = cl
		var cid := str(d["id"])
		var a: Dictionary = d.get("attrs", {})
		var skills: Array[String] = []
		for sid: Variant in d.get("skills", []):
			skills.append(str(_skill_names.get(str(sid), sid)))
		var b := Button.new()
		b.name = "Class_%s" % cid
		b.toggle_mode = true
		b.button_pressed = cid == class_id
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(0, 64)
		b.text = "%s — %s\n%s %+d  %s %+d  %s %+d · %s · %s" % [str(d.get("name", cid)), str(d.get("desc", "")),
			str(attr_names["might"]), int(a.get("might", 0)), str(attr_names["finesse"]), int(a.get("finesse", 0)),
			str(attr_names["wits"]), int(a.get("wits", 0)), Texts.s(&"HERO_HIT_DIE") % str(d.get("hit_die", "d8")),
			Texts.s(&"LIST_SEP").join(skills)]
		b.pressed.connect(func() -> void: select_class(cid))
		class_box.add_child(b)
		if cid == class_id:
			story = str(d.get("story", ""))
	for bgd: Variant in _backgrounds:
		var e: Dictionary = bgd
		var bid := str(e["id"])
		var bb := Button.new()
		bb.name = "Background_%s" % bid
		bb.toggle_mode = true
		bb.button_pressed = bid == background_id
		bb.custom_minimum_size = Vector2(0, 44)
		bb.text = str(e.get("name", bid))
		bb.pressed.connect(func() -> void: select_background(bid))
		bg_box.add_child(bb)
		if bid == background_id:
			story += "\n\n" + str(e.get("story", ""))
	story_label.text = story.strip_edges()
	confirm_button.disabled = class_id == "" or background_id == ""
