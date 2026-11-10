# 队伍分合界面组件（docs/en/framework/15-party-split-and-perspective-spec.md §4/§5/§3.3）——双壳共用：
# - PartySplitUi（本节点）= 组条：小组标签（点按切焦点）、⧉ 分屏开关、✉ 联络按钮、"与此同时"一行；
# - 分屏窗格（split_pane）：另一组的节点标题与摘要（暗显、只读），点按 = 切焦点；
# - 联络弹层（link_sheet）：求援 / 送物 / 换人（数据来自 StoryVM 的 vm.split.link）；
# - 分装弹层（divide_sheet）：道具逐件分给各组，点按交给下一组，拖到组头 = 交给该组（12 §1 双通道）。
# 纯呈现：一切动作经信号交给引导层（CampaignFlow._on_hub_action），写板在 core。
class_name PartySplitUi
extends VBoxContainer

signal focus_requested(gid: String)
signal link_requested(action: String) ## "help:<gid>" / "send:<iid>:<gid>" / "move:<cid>:<gid>"
signal divided(assign: Dictionary)
signal assigned(assignment: Dictionary) ## 自选分组完成（15 §2.1 assign: "player"）
signal pane_changed(shown: bool) ## 分屏窗格显隐（横屏据此把焦点故事区收窄到左侧）

var tabs_row: HBoxContainer
var meanwhile: Label
var split_button: Button
var link_button: Button
var split_pane: PanelContainer
var pane_title: Label
var pane_text: Label
var link_sheet: PanelContainer
var link_box: VBoxContainer
var divide_sheet: PanelContainer
var divide_box: VBoxContainer
var split_view := false
var _split: Dictionary = {}
var _divide: Dictionary = {}
var _assign: Dictionary = {} # {groups:[{id,label,min,max,requires}], roster:[{id,name}], assign:{gid:[cid]}} # {groups:[{id,label}], items:[{id,name,count}], assign:{gid:{iid:n}}}
var _pane_gid := ""

static func _sheet_style() -> StyleBox:
	return Palette.sheet_style()

func _init() -> void:
	name = "PartySplitUi"
	visible = false
	add_theme_constant_override("separation", 2)
	tabs_row = HBoxContainer.new()
	tabs_row.add_theme_constant_override("separation", 4)
	add_child(tabs_row)
	meanwhile = Label.new()
	meanwhile.add_theme_font_size_override("font_size", 12)
	meanwhile.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	meanwhile.clip_text = true
	meanwhile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(meanwhile)
	split_button = Button.new()
	split_button.text = Texts.s(&"PARTY_SPLIT_VIEW")
	split_button.toggle_mode = true
	split_button.custom_minimum_size = Vector2(44, 40)
	split_button.toggled.connect(func(on: bool) -> void:
		split_view = on
		_render_pane())
	link_button = Button.new()
	link_button.custom_minimum_size = Vector2(0, 40)
	link_button.pressed.connect(_open_link_sheet)
	# 分屏窗格 / 联络 / 分装：由壳挂到合适的父节点（mount）
	split_pane = PanelContainer.new()
	split_pane.name = "SplitPane"
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.10, 0.14, 0.92)
	ps.border_width_left = 2
	ps.border_color = Color(0.55, 0.5, 0.4)
	ps.set_content_margin_all(10)
	split_pane.add_theme_stylebox_override("panel", ps)
	split_pane.modulate = Color(1, 1, 1, 0.85) # 暗显：只读的另一视角
	var pv := VBoxContainer.new()
	split_pane.add_child(pv)
	pane_title = Label.new()
	pane_title.add_theme_font_size_override("font_size", 16)
	pv.add_child(pane_title)
	pane_text = Label.new()
	pane_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pane_text.add_theme_font_size_override("font_size", 13)
	pv.add_child(pane_text)
	var hint := Label.new()
	hint.text = Texts.s(&"PARTY_TAP_SWITCH")
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Palette.color("accent"))
	pv.add_child(hint)
	split_pane.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and _pane_gid != "":
			focus_requested.emit(_pane_gid))
	split_pane.visible = false
	link_sheet = PanelContainer.new()
	link_sheet.name = "LinkSheet"
	link_sheet.add_theme_stylebox_override("panel", _sheet_style())
	link_box = VBoxContainer.new()
	link_box.add_theme_constant_override("separation", 6)
	link_sheet.add_child(link_box)
	link_sheet.visible = false
	divide_sheet = PanelContainer.new()
	divide_sheet.name = "DivideSheet"
	divide_sheet.add_theme_stylebox_override("panel", _sheet_style())
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	divide_box = VBoxContainer.new()
	divide_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divide_box.add_theme_constant_override("separation", 6)
	sc.add_child(divide_box)
	divide_sheet.add_child(sc)
	divide_sheet.visible = false

## 壳挂载：窗格放主视野内（rect 由壳给锚点），两个弹层占下半屏。
func mount(host: Control, pane_anchors: Rect2) -> void:
	host.add_child(split_pane)
	split_pane.anchor_left = pane_anchors.position.x
	split_pane.anchor_top = pane_anchors.position.y
	split_pane.anchor_right = pane_anchors.end.x
	split_pane.anchor_bottom = pane_anchors.end.y
	for sheet: PanelContainer in [link_sheet, divide_sheet]:
		host.add_child(sheet)
		sheet.anchor_left = 0.0
		sheet.anchor_right = 1.0
		sheet.anchor_top = 0.45
		sheet.anchor_bottom = 1.0

## 每次故事态刷新调用：split = vm.split（空 = 未分队，整条隐藏）。
func refresh(split: Dictionary) -> void:
	_split = split
	visible = not split.is_empty()
	for c: Node in tabs_row.get_children():
		tabs_row.remove_child(c)
		if c != split_button and c != link_button:
			c.queue_free()
	if split.is_empty():
		split_pane.visible = false
		link_sheet.visible = false
		return
	var lines: Array[String] = []
	for g: Variant in split.get("groups", []):
		var gd: Dictionary = g
		var gid := str(gd["id"])
		var b := Button.new()
		b.name = "Group_%s" % gid
		b.toggle_mode = true
		b.button_pressed = bool(gd.get("focused", false))
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var status := str((Texts.t(&"PARTY_STATUS") as Dictionary).get(str(gd.get("status", "")), ""))
		b.text = str(gd.get("label", gid)) + ((" · " + status) if status != "" else "")
		b.disabled = str(gd.get("status", "")) == "waiting"
		b.pressed.connect(func() -> void:
			if not bool(gd.get("focused", false)):
				focus_requested.emit(gid))
		tabs_row.add_child(b)
		if not bool(gd.get("focused", false)):
			lines.append(Texts.s(&"PARTY_MEANWHILE") % [str(gd.get("label", gid)), str(gd.get("node_title", ""))
				+ ((" (" + status + ")") if status != "" else "")])
	tabs_row.add_child(split_button)
	var link: Dictionary = split.get("link", {})
	link_button.text = Texts.s(&"PARTY_LINK") % int(link.get("charges", 0))
	tabs_row.add_child(link_button)
	meanwhile.text = "  ".join(lines)
	_render_pane()
	if link_sheet.visible:
		_open_link_sheet()

func _render_pane() -> void:
	_pane_gid = ""
	for g: Variant in _split.get("groups", []):
		var gd: Dictionary = g
		if not bool(gd.get("focused", false)) and str(gd.get("status", "")) != "waiting":
			_pane_gid = str(gd["id"])
			pane_title.text = "%s — %s" % [str(gd.get("label", "")), str(gd.get("node_title", ""))]
			pane_text.text = str(gd.get("node_text", ""))
			break
	var shown := split_view and _pane_gid != "" and not _split.is_empty()
	if shown != split_pane.visible:
		split_pane.visible = shown
		pane_changed.emit(shown)

# ---------------------------------------------------------------- 联络弹层

func _clear(box: Node) -> void:
	for c: Node in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _sheet_button(text: String, action: String, enabled: bool = true) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.disabled = not enabled
	b.name = "Link_%s" % action.replace(":", "_")
	b.pressed.connect(func() -> void: link_requested.emit(action))
	return b

func _open_link_sheet() -> void:
	_clear(link_box)
	var link: Dictionary = _split.get("link", {})
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.text = Texts.s(&"LINK_TITLE") % int(link.get("charges", 0))
	link_box.add_child(title)
	if not bool(link.get("enabled", false)):
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.text = Texts.s(&"LINK_LOCKED")
		link_box.add_child(l)
	else:
		var ch := int(link.get("charges", 0))
		for o: Variant in link.get("others", []):
			var od: Dictionary = o
			link_box.add_child(_sheet_button(Texts.s(&"LINK_HELP") % str(od["label"]), "help:%s" % str(od["id"]), ch >= 1))
			for it: Variant in link.get("items", []):
				var itd: Dictionary = it
				link_box.add_child(_sheet_button(Texts.s(&"LINK_SEND") % [str(itd["name"]), str(od["label"])],
					"send:%s:%s" % [str(itd["id"]), str(od["id"])], ch >= 1))
			if bool(od.get("anchor_ok", false)):
				for mm: Variant in link.get("members", []):
					var md: Dictionary = mm
					link_box.add_child(_sheet_button(Texts.s(&"LINK_MOVE") % [str(md["name"]), str(od["label"])],
						"move:%s:%s" % [str(md["id"]), str(od["id"])], ch >= 2))
		if bool(link.get("recall", false)):
			link_box.add_child(_sheet_button(Texts.s(&"LINK_RECALL"), "recall", int(link.get("charges", 0)) >= 2))
		if link_box.get_child_count() == 1:
			var l2 := Label.new()
			l2.text = Texts.s(&"LINK_NONE")
			link_box.add_child(l2)
	var close := Button.new()
	close.text = Texts.s(&"HUB_CLOSE")
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func() -> void: link_sheet.visible = false)
	link_box.add_child(close)
	link_sheet.visible = true

# ---------------------------------------------------------------- 分装弹层（15 §3.3）

## data = {groups:[{id,label}], items:[{id,name,count}], assign:{gid:{iid:n}}}（assign 缺省 = 默认分配）。
func open_divide(data: Dictionary) -> void:
	_divide = data.duplicate(true)
	_render_divide()
	divide_sheet.visible = true

func is_dividing() -> bool:
	return divide_sheet.visible

func _assigned(gid: String, iid: String) -> int:
	return int(((_divide.get("assign", {}) as Dictionary).get(gid, {}) as Dictionary).get(iid, 0))

## 把 iid 的一份交给 gid（从当前持有最多的另一组拿）。
func give_one(iid: String, gid: String) -> void:
	var assign: Dictionary = _divide.get("assign", {})
	var donor := ""
	for g: Variant in _divide.get("groups", []):
		var other := str((g as Dictionary)["id"])
		if other != gid and _assigned(other, iid) > 0 and (donor == "" or _assigned(other, iid) > _assigned(donor, iid)):
			donor = other
	if donor == "":
		return
	(assign[donor] as Dictionary)[iid] = _assigned(donor, iid) - 1
	if not assign.has(gid):
		assign[gid] = {}
	(assign[gid] as Dictionary)[iid] = _assigned(gid, iid) + 1
	_render_divide()

## 点按道具：交给"下一组"（按组序轮转，从持有它的组之后开始）。
func cycle_item(iid: String) -> void:
	var gs: Array = _divide.get("groups", [])
	for i: int in gs.size():
		if _assigned(str((gs[i] as Dictionary)["id"]), iid) > 0:
			give_one(iid, str((gs[(i + 1) % gs.size()] as Dictionary)["id"]))
			return

func _render_divide() -> void:
	_clear(divide_box)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.text = Texts.s(&"DIVIDE_TITLE")
	divide_box.add_child(title)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.text = Texts.s(&"DIVIDE_HINT")
	divide_box.add_child(hint)
	var names := {}
	for it: Variant in _divide.get("items", []):
		names[str((it as Dictionary)["id"])] = str((it as Dictionary).get("name", ""))
	for g: Variant in _divide.get("groups", []):
		var gid := str((g as Dictionary)["id"])
		var parts: Array[String] = []
		for iid: Variant in ((_divide.get("assign", {}) as Dictionary).get(gid, {}) as Dictionary).keys():
			var n := _assigned(gid, str(iid))
			if n > 0:
				parts.append("%s ×%d" % [str(names.get(str(iid), iid)), n])
		var head := Button.new()
		head.name = "DivideGroup_%s" % gid
		head.custom_minimum_size = Vector2(0, 48)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.text = Texts.s(&"DIVIDE_GROUP_FMT") % [str((g as Dictionary).get("label", gid)),
			", ".join(parts) if not parts.is_empty() else Texts.s(&"DIVIDE_EMPTY")]
		head.set_drag_forwarding(Callable(), func(_p: Vector2, d: Variant) -> bool: return d is Dictionary and (d as Dictionary).has("divide_item"),
			func(_p: Vector2, d: Variant) -> void: give_one(str((d as Dictionary)["divide_item"]), gid))
		divide_box.add_child(head)
	for it2: Variant in _divide.get("items", []):
		var itd: Dictionary = it2
		var iid2 := str(itd["id"])
		var row := Button.new()
		row.name = "DivideItem_%s" % iid2
		row.custom_minimum_size = Vector2(0, 44)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = "◆ %s ×%d" % [str(itd.get("name", iid2)), int(itd.get("count", 0))]
		row.pressed.connect(func() -> void: cycle_item(iid2))
		row.set_drag_forwarding(func(_p: Vector2) -> Variant:
			var pv := Label.new()
			pv.text = str(itd.get("name", iid2))
			row.set_drag_preview(pv)
			return {"divide_item": iid2}, Callable(), Callable())
		divide_box.add_child(row)
	var btns := HBoxContainer.new()
	var dflt := Button.new()
	dflt.text = Texts.s(&"DIVIDE_DEFAULT")
	dflt.custom_minimum_size = Vector2(0, 48)
	dflt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dflt.pressed.connect(func() -> void:
		_divide["assign"] = (_divide.get("default", {}) as Dictionary).duplicate(true)
		_render_divide())
	btns.add_child(dflt)
	var done := Button.new()
	done.name = "DivideDone"
	done.text = Texts.s(&"DIVIDE_DONE")
	done.custom_minimum_size = Vector2(0, 48)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(func() -> void:
		divide_sheet.visible = false
		divided.emit((_divide.get("assign", {}) as Dictionary).duplicate(true)))
	btns.add_child(done)
	divide_box.add_child(btns)

## 测试探针：当前分装。
func divide_assign() -> Dictionary:
	return (_divide.get("assign", {}) as Dictionary).duplicate(true)

# ---------------------------------------------------------------- 自选分组（15 §2.1）

## data = {groups:[{id,label,min,max,requires}], roster:[{id,name}], assign:{gid:[cid]}}（assign = 默认建议）。
func open_assign(data: Dictionary) -> void:
	_assign = data.duplicate(true)
	_render_assign()
	divide_sheet.visible = true

func is_assigning() -> bool:
	return divide_sheet.visible and not _assign.is_empty()

func _group_of(cid: String) -> String:
	for gid: Variant in (_assign.get("assign", {}) as Dictionary).keys():
		if ((_assign["assign"] as Dictionary)[gid] as Array).has(cid):
			return str(gid)
	return ""

## 把 cid 换到 gid（拖放落点）。
func move_to(cid: String, gid: String) -> void:
	var a: Dictionary = _assign.get("assign", {})
	for g: Variant in a.keys():
		(a[g] as Array).erase(cid)
	if not a.has(gid):
		a[gid] = []
	(a[gid] as Array).append(cid)
	_render_assign()

## 点按：换到下一组。
func cycle_member(cid: String) -> void:
	var gs: Array = _assign.get("groups", [])
	var cur := _group_of(cid)
	for i: int in gs.size():
		if str((gs[i] as Dictionary)["id"]) == cur:
			move_to(cid, str((gs[(i + 1) % gs.size()] as Dictionary)["id"]))
			return

## 前端预校验（core 再校验一次）：人数与必需成员。
func assignment_valid() -> bool:
	for g: Variant in _assign.get("groups", []):
		var gd: Dictionary = g
		var ms: Array = (_assign.get("assign", {}) as Dictionary).get(str(gd["id"]), [])
		if ms.size() < int(gd.get("min", 1)) or ms.size() > int(gd.get("max", 99)):
			return false
		for r: Variant in gd.get("requires", []):
			if not ms.has(str(r)):
				return false
	return true

func _render_assign() -> void:
	_clear(divide_box)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 18)
	title.text = Texts.s(&"PARTY_ASSIGN_TITLE")
	divide_box.add_child(title)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.text = Texts.s(&"PARTY_ASSIGN_HINT")
	divide_box.add_child(hint)
	var names := {}
	for r: Variant in _assign.get("roster", []):
		names[str((r as Dictionary)["id"])] = str((r as Dictionary).get("name", ""))
	for g: Variant in _assign.get("groups", []):
		var gd: Dictionary = g
		var gid := str(gd["id"])
		var head := Button.new()
		head.name = "AssignGroup_%s" % gid
		head.custom_minimum_size = Vector2(0, 40)
		head.text = Texts.s(&"PARTY_ASSIGN_RULE") % [str(gd.get("label", gid)), int(gd.get("min", 1)), int(gd.get("max", 99))]
		head.set_drag_forwarding(Callable(), func(_p: Vector2, d: Variant) -> bool: return d is Dictionary and (d as Dictionary).has("assign_member"),
			func(_p: Vector2, d: Variant) -> void: move_to(str((d as Dictionary)["assign_member"]), gid))
		divide_box.add_child(head)
		var row := HFlowContainer.new()
		for cid: Variant in (_assign.get("assign", {}) as Dictionary).get(gid, []):
			var c := str(cid)
			var b := Button.new()
			b.name = "Member_%s" % c
			b.custom_minimum_size = Vector2(0, 44)
			var required := (gd.get("requires", []) as Array).has(c)
			b.text = ("🔒 " if required else "") + str(names.get(c, c))
			b.disabled = required
			b.pressed.connect(func() -> void: cycle_member(c))
			b.set_drag_forwarding(func(_p: Vector2) -> Variant:
				var pv := Label.new()
				pv.text = str(names.get(c, c))
				b.set_drag_preview(pv)
				return {"assign_member": c}, Callable(), Callable())
			row.add_child(b)
		divide_box.add_child(row)
	var ok := assignment_valid()
	if not ok:
		var warn := Label.new()
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.add_theme_color_override("font_color", Palette.color("danger"))
		warn.text = Texts.s(&"PARTY_ASSIGN_INVALID")
		divide_box.add_child(warn)
	var done := Button.new()
	done.name = "AssignDone"
	done.text = Texts.s(&"PARTY_ASSIGN_DONE")
	done.custom_minimum_size = Vector2(0, 48)
	done.disabled = not ok
	done.pressed.connect(func() -> void:
		divide_sheet.visible = false
		var out := (_assign.get("assign", {}) as Dictionary).duplicate(true)
		_assign = {}
		assigned.emit(out))
	divide_box.add_child(done)
