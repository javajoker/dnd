# ⑩ 区域地图 / ⑪ 场所地图（docs/en/framework/16-map-and-exploration-spec.md §2.3/§3；04 §4 ⑩/⑪）
# 形态感知：竖屏 = 地图在上、目的地卡 + 步调 + 出发/扎营在下方拇指区；横屏 = 左侧大地图、右栏信息与操作。
# - 区域图：地点按 pos 落位、路线按危险度着色（未走过为虚线）；点地点 = 选目的地，
#   拖 ▲ 队伍标记到地点 = 选定并出发（12 §1 双通道）；行程中显示进度点。
# - 场所：区域方块（已进入实填 / 已知未进入虚框 / 当前金边），可交互物与出口为操作按钮。
# - 骰子条（骰型图标 + 值 + 明细）与托盘（事件表多面骰）消费同一事件流；事件卡为半屏弹层。
# 纯呈现：只发信号，数据来自 MapFlow 组装的视图（core 只读视图 + 选择状态）。
class_name ScreenMap
extends Control

signal location_tapped(id: String)
signal pace_changed(pace: String)
signal travel_pressed
signal camp_pressed
signal camp_action(action: String, arg: String)
signal menu_pressed
signal card_option(idx: int)
signal feature_pressed(fid: String)
signal exit_pressed(to: String)

const DANGER_COLORS := [Color(0.78, 0.70, 0.46), Color(0.92, 0.62, 0.25), Color(0.90, 0.32, 0.26), Color(0.75, 0.20, 0.45)]
const TOKEN_GRAB := 46.0
const BG_ALPHA := 0.9 # 背景插画略压暗，路线与地点按钮保持可读

var form: StringName = ShellRouter.MODE_TIME
var audio_settings_path := UiSettings.PATH

var title_label: Label
var status_label: Label
var canvas: Control
var info_label: Label
var pace_row: HBoxContainer
var actions_box: VBoxContainer
var travel_button: Button
var camp_button: Button
var menu_button: Button
var dice_glyph: DieGlyph
var dice_value: Label
var dice_detail: Label
var dice_tray: DiceTray
var card_sheet: PanelContainer
var card_title: Label
var card_text: Label
var card_options: VBoxContainer
var camp_popup: HubPopup

var _mode := "region"
var _vm: Dictionary = {}
var _loc_buttons: Dictionary = {} # id → Button（画布内落位）
var _drag_token := false
var _built := false
var _bg_tex: Texture2D = null # 当前地图 / 场所背景图（16 §6；无 = 程序化纯底）

func set_form(mode: StringName) -> void:
	form = mode
	if _built:
		for c: Node in get_children():
			remove_child(c)
			c.queue_free()
		_build()
		_render()

func _ready() -> void:
	_build()
	_built = true
	SafeArea.fit(self)

# ---------------------------------------------------------------- 搭建

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.color("bg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label = Label.new()
	status_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.6))
	menu_button = Button.new()
	menu_button.text = Texts.s(&"MENU")
	menu_button.custom_minimum_size = Vector2(44, 44)
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	canvas = Control.new()
	canvas.name = "MapCanvas"
	canvas.clip_contents = true
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.custom_minimum_size = Vector2(0, 220)
	canvas.draw.connect(_draw_canvas)
	canvas.resized.connect(_layout_canvas)
	canvas.gui_input.connect(_on_canvas_input)
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(0, 44)
	pace_row = HBoxContainer.new()
	pace_row.add_theme_constant_override("separation", 4)
	for p: String in RegionMap.PACES:
		var b := Button.new()
		b.name = "Pace_%s" % p
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 44)
		b.text = str((Texts.t(&"MAP_PACES") as Dictionary).get(p, p))
		b.tooltip_text = str((Texts.t(&"MAP_PACE_HINTS") as Dictionary).get(p, ""))
		b.pressed.connect(func() -> void: pace_changed.emit(p))
		pace_row.add_child(b)
	actions_box = VBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 6)
	travel_button = Button.new()
	travel_button.name = "Travel"
	travel_button.custom_minimum_size = Vector2(0, 52)
	travel_button.add_theme_font_size_override("font_size", 18)
	travel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	travel_button.pressed.connect(func() -> void: travel_pressed.emit())
	camp_button = Button.new()
	camp_button.text = Texts.s(&"CAMP")
	camp_button.custom_minimum_size = Vector2(0, 52)
	camp_button.pressed.connect(func() -> void: camp_pressed.emit())
	var dice_row := HBoxContainer.new()
	dice_row.add_theme_constant_override("separation", 8)
	dice_glyph = DieGlyph.new()
	dice_row.add_child(dice_glyph)
	dice_value = Label.new()
	dice_value.add_theme_font_size_override("font_size", 28)
	dice_value.custom_minimum_size = Vector2(44, 44)
	dice_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_row.add_child(dice_value)
	dice_detail = Label.new()
	dice_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dice_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dice_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_detail.add_theme_font_size_override("font_size", 13)
	dice_detail.text = Texts.s(&"DICE_STRIP_IDLE")
	dice_row.add_child(dice_detail)
	var travel_row := HBoxContainer.new()
	travel_row.add_theme_constant_override("separation", 6)
	travel_row.add_child(travel_button)
	travel_row.add_child(camp_button)
	if form == ShellRouter.MODE_SPACE:
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.add_theme_constant_override("separation", 12)
		add_child(h)
		canvas.size_flags_stretch_ratio = 2.4
		h.add_child(canvas)
		var side := VBoxContainer.new()
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side.add_theme_constant_override("separation", 8)
		h.add_child(side)
		var top := HBoxContainer.new()
		top.add_child(title_label)
		top.add_child(menu_button)
		side.add_child(top)
		side.add_child(status_label)
		side.add_child(info_label)
		side.add_child(pace_row)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(actions_box)
		side.add_child(sc)
		side.add_child(dice_row)
		side.add_child(travel_row)
	else:
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.add_theme_constant_override("separation", 6)
		add_child(v)
		var top2 := HBoxContainer.new()
		top2.add_child(title_label)
		top2.add_child(menu_button)
		v.add_child(top2)
		v.add_child(status_label)
		v.add_child(canvas)
		v.add_child(dice_row)
		v.add_child(info_label)
		v.add_child(pace_row)
		v.add_child(actions_box)
		v.add_child(travel_row)
	dice_tray = DiceTray.new() # 事件表多面骰托盘（17 §3）：叠在地图画布下段
	add_child(dice_tray)
	dice_tray.anchor_left = 0.0
	dice_tray.anchor_right = 0.62 if form == ShellRouter.MODE_SPACE else 1.0
	dice_tray.anchor_top = 0.40 if form == ShellRouter.MODE_SPACE else 0.30
	dice_tray.anchor_bottom = 0.85 if form == ShellRouter.MODE_SPACE else 0.58
	_build_card_sheet()
	camp_popup = HubPopup.new()
	camp_popup.buy_requested.connect(func(iid: String) -> void: camp_action.emit("buy", iid))
	camp_popup.short_rest_requested.connect(func(cid: String) -> void: camp_action.emit("short_rest", cid))
	camp_popup.rest_requested.connect(func() -> void: camp_action.emit("long_rest", ""))
	camp_popup.use_item_requested.connect(func(iid: String, cid: String) -> void:
		camp_action.emit("use_item", "%s:%s" % [iid, cid]))
	add_child(camp_popup)

func _build_card_sheet() -> void:
	card_sheet = PanelContainer.new()
	card_sheet.name = "EventCard"
	card_sheet.anchor_left = 0.0
	card_sheet.anchor_right = 1.0
	card_sheet.anchor_top = 0.42
	card_sheet.anchor_bottom = 1.0
	card_sheet.add_theme_stylebox_override("panel", Palette.sheet_style())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card_sheet.add_child(v)
	card_title = Label.new()
	card_title.add_theme_font_size_override("font_size", 20)
	v.add_child(card_title)
	card_text = Label.new()
	card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(card_text)
	card_options = VBoxContainer.new()
	card_options.add_theme_constant_override("separation", 6)
	v.add_child(card_options)
	card_sheet.visible = false
	add_child(card_sheet)

# ---------------------------------------------------------------- 数据

func show_region(vm: Dictionary) -> void:
	_mode = "region"
	_vm = vm
	_render()

func show_site(vm: Dictionary) -> void:
	_mode = "site"
	_vm = vm
	_render()

func show_card(card: Dictionary) -> void:
	card_title.text = str(card.get("title", ""))
	card_text.text = str(card.get("text", ""))
	for c: Node in card_options.get_children():
		card_options.remove_child(c)
		c.queue_free()
	var i := 0
	for o: Variant in card.get("options", []):
		var od: Dictionary = o
		var b := Button.new()
		b.name = "Option%d" % i
		b.custom_minimum_size = Vector2(0, 48)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = str(od.get("label", ""))
		if od.has("check"):
			b.text += " " + _check_tag(od["check"])
		var idx := i
		b.pressed.connect(func() -> void: card_option.emit(idx))
		card_options.add_child(b)
		i += 1
	card_sheet.visible = true

func hide_card() -> void:
	card_sheet.visible = false

func is_card_open() -> bool:
	return card_sheet.visible

func open_camp(data: Dictionary) -> void:
	camp_popup.usable = data.get("usable", [])
	camp_popup.open(int(data.get("gold", 0)), data.get("stock", []), data.get("party", []),
		HubPopup.MODE_CAMP, bool(data.get("rest_free", false)))

func sync_camp(data: Dictionary) -> void:
	if camp_popup.visible:
		camp_popup.usable = data.get("usable", [])
		camp_popup.bind(int(data.get("gold", 0)), data.get("stock", []), data.get("party", []))

static func _check_tag(chk: Dictionary) -> String:
	var skill := str(chk.get("skill", ""))
	var diff := str(chk.get("difficulty", "medium"))
	return Texts.s(&"MAP_CHECK_TAG") % [str(Texts.t(&"SKILL_NAMES").get(skill, skill)),
		str(Texts.t(&"DIFF_NAMES").get(diff, diff)), LightV1.dc_for(diff)]

func _render() -> void:
	if not _built:
		return
	status_label.text = Texts.s(&"MAP_STATUS") % [int(_vm.get("clock", 0)), int(_vm.get("watch", 0)),
		int(_vm.get("watches_per_segment", 4)), int(_vm.get("gold", 0))]
	for c: Node in actions_box.get_children():
		actions_box.remove_child(c)
		c.queue_free()
	if _mode == "site":
		_render_site()
	else:
		_render_region()
	_layout_canvas()
	canvas.queue_redraw()

func _render_region() -> void:
	title_label.text = str(_vm.get("name", ""))
	pace_row.visible = true
	travel_button.visible = true
	var j: Dictionary = _vm.get("journey", {})
	var locs := _locations_by_id()
	for b: Node in pace_row.get_children():
		(b as Button).button_pressed = b.name == "Pace_%s" % str(_vm.get("pace", "normal"))
		(b as Button).disabled = not j.is_empty()
	var note := str(_vm.get("note", ""))
	var lines: Array[String] = []
	if note != "":
		lines.append(note)
	var here_name := str((locs.get(str(_vm.get("here", "")), {}) as Dictionary).get("name", ""))
	if not j.is_empty():
		lines.append(Texts.s(&"MAP_JOURNEY_FMT") % [str((locs.get(str(j.get("to", "")), {}) as Dictionary).get("name", j.get("to", ""))),
			int(j.get("legs_left", 0))])
		travel_button.text = Texts.s(&"MAP_CONTINUE")
		travel_button.disabled = false
	elif str(_vm.get("selected", "")) != "":
		var r: Dictionary = _vm.get("selected_route", {})
		var dest := str((locs.get(str(_vm["selected"]), {}) as Dictionary).get("name", ""))
		if r.is_empty():
			lines.append(Texts.s(&"MAP_NO_ROUTE"))
			travel_button.disabled = true
		else:
			lines.append(Texts.s(&"MAP_DEST_FMT") % [dest, RegionMap.effective_legs(int(r.get("legs", 1)), str(_vm.get("pace", "normal"))),
				"●".repeat(int(r.get("danger", 0))) + "○".repeat(3 - clampi(int(r.get("danger", 0)), 0, 3))])
			travel_button.disabled = false
		travel_button.text = Texts.s(&"MAP_TRAVEL")
	else:
		lines.append(Texts.s(&"MAP_HERE_FMT") % here_name)
		lines.append(Texts.s(&"MAP_SELECT_HINT"))
		travel_button.text = Texts.s(&"MAP_ENTER_FMT") % here_name
		travel_button.disabled = false
	info_label.text = "\n".join(lines)
	camp_button.disabled = not j.is_empty()
	# 地点按钮（画布内落位，_layout_canvas 定位）
	for b: Node in _loc_buttons.values():
		(b as Node).queue_free()
	_loc_buttons.clear()
	for l: Variant in _vm.get("locations", []):
		var d: Dictionary = l
		var b := Button.new()
		b.name = "Loc_%s" % str(d["id"])
		b.toggle_mode = true
		b.button_pressed = str(d["id"]) == str(_vm.get("selected", ""))
		b.text = ("▲ " if bool(d.get("here", false)) else ("● " if bool(d.get("visited", false)) else "◌ ")) + str(d.get("name", ""))
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 13)
		var id := str(d["id"])
		b.pressed.connect(func() -> void: location_tapped.emit(id))
		canvas.add_child(b)
		_loc_buttons[id] = b

func _render_site() -> void:
	title_label.text = "%s · %s" % [str(_vm.get("name", "")), str(_vm.get("area_name", ""))]
	pace_row.visible = false
	travel_button.visible = false
	var lines: Array[String] = []
	if str(_vm.get("note", "")) != "":
		lines.append(str(_vm["note"]))
	lines.append(str(_vm.get("area_text", "")))
	info_label.text = "\n".join(lines)
	for b: Node in _loc_buttons.values():
		(b as Node).queue_free()
	_loc_buttons.clear()
	for f: Variant in _vm.get("features", []):
		var fd: Dictionary = f
		var b := Button.new()
		var fid := str(fd.get("id", ""))
		b.name = "Feature_%s" % fid
		b.custom_minimum_size = Vector2(0, 44)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "✦ " + str(fd.get("label", fid)) + (" " + _check_tag(fd["check"]) if fd.has("check") else "")
		b.pressed.connect(func() -> void: feature_pressed.emit(fid))
		actions_box.add_child(b)
	for e: Variant in _vm.get("exits", []):
		var ed: Dictionary = e
		var to := str(ed.get("to", ""))
		var b2 := Button.new()
		b2.name = "Exit_%s" % to.replace("@", "_")
		b2.custom_minimum_size = Vector2(0, 44)
		b2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var state := str(ed.get("state", "open"))
		var room := str(ed.get("name", to)) if str(ed.get("name", "")) != "" else Texts.s(&"SITE_UNKNOWN_ROOM")
		match state:
			"map":
				b2.text = Texts.s(&"SITE_EXIT_MAP")
			"locked":
				b2.text = Texts.s(&"SITE_DOOR_LOCKED") % room + \
					(" " + _check_tag(ed["pick"]) if not (ed.get("pick", {}) as Dictionary).is_empty() else "")
			"stuck":
				b2.text = Texts.s(&"SITE_DOOR_STUCK") % room + " " + _check_tag(
					ed["force"] if not (ed.get("force", {}) as Dictionary).is_empty() else {"skill": "athletics", "difficulty": "medium"})
			_:
				b2.text = Texts.s(&"SITE_DOOR_OPEN") % room
		b2.pressed.connect(func() -> void: exit_pressed.emit(to))
		actions_box.add_child(b2)

func _locations_by_id() -> Dictionary:
	var out := {}
	for l: Variant in _vm.get("locations", []):
		out[str((l as Dictionary)["id"])] = l
	return out

# ---------------------------------------------------------------- 画布

## 网格坐标 → 画布像素（按全部点的包围盒等比缩放，四周留边）。
func _grid_to_px(p: Variant, pts: Array) -> Vector2:
	var minv := Vector2(INF, INF)
	var maxv := Vector2(-INF, -INF)
	for q: Variant in pts:
		var v := Vector2(float(q[0]), float(q[1]))
		minv = minv.min(v)
		maxv = maxv.max(v)
	var span := (maxv - minv).max(Vector2(1, 1))
	var margin := Vector2(70, 34)
	var area := canvas.size - margin * 2.0
	var k := minf(minf(area.x / span.x, area.y / span.y), 150.0 if _mode == "site" else 190.0) # 封顶：大画布上地图收拢居中
	var used := span * k
	var origin := margin + (area - used) * 0.5
	return origin + (Vector2(float(p[0]), float(p[1])) - minv) * k

func _all_points() -> Array:
	var pts: Array = []
	var key := "areas" if _mode == "site" else "locations"
	for l: Variant in _vm.get(key, []):
		pts.append((l as Dictionary).get("pos", [0, 0]))
	return pts

func _layout_canvas() -> void:
	if canvas == null or _vm.is_empty():
		return
	var pts := _all_points()
	if pts.is_empty():
		return
	for l: Variant in _vm.get("locations", []):
		var d: Dictionary = l
		var b: Button = _loc_buttons.get(str(d["id"]))
		if b == null:
			continue
		b.reset_size()
		b.position = _grid_to_px(d.get("pos", [0, 0]), pts) - b.size * 0.5
	canvas.queue_redraw()

func _draw_canvas() -> void:
	if _vm.is_empty():
		return
	var pts := _all_points()
	if pts.is_empty():
		return
	_draw_background(pts)
	if _mode == "site":
		_draw_site(pts)
		return
	var locs := _locations_by_id()
	var j: Dictionary = _vm.get("journey", {})
	for r: Variant in _vm.get("routes", []):
		var rd: Dictionary = r
		var a: Dictionary = locs.get(str(rd["from"]), {})
		var b: Dictionary = locs.get(str(rd["to"]), {})
		if a.is_empty() or b.is_empty():
			continue
		var pa := _grid_to_px(a["pos"], pts)
		var pb := _grid_to_px(b["pos"], pts)
		var col: Color = DANGER_COLORS[clampi(int(rd.get("danger", 0)), 0, DANGER_COLORS.size() - 1)]
		if _bg_tex != null: # 插画底上路线加深色衬线，浅色道路不被纸色吞掉
			canvas.draw_line(pa, pb, Color(0.08, 0.06, 0.05, 0.55), 6.0, true)
		if bool(a.get("visited", false)) and bool(b.get("visited", false)):
			canvas.draw_line(pa, pb, col, 3.0, true)
		else:
			canvas.draw_dashed_line(pa, pb, col, 3.0, 9.0)
	if not j.is_empty():
		var fa: Dictionary = locs.get(str(j.get("from", "")), {})
		var tb: Dictionary = locs.get(str(j.get("to", "")), {})
		if not fa.is_empty() and not tb.is_empty():
			var total := maxf(float(j.get("legs_total", 1)), 1.0)
			var t := 1.0 - float(j.get("legs_left", 0)) / total
			var p := _grid_to_px(fa["pos"], pts).lerp(_grid_to_px(tb["pos"], pts), clampf(t, 0.0, 1.0))
			canvas.draw_circle(p, 9.0, Color(1.0, 0.85, 0.4))
			canvas.draw_circle(p, 5.0, Color(0.1, 0.08, 0.05))

## 背景图（16 §6）：铺在 frame 网格矩形上，与地点同一坐标变换——插画里的地标落在地点按钮之下。
func _draw_background(pts: Array) -> void:
	var r := background_rect(pts)
	if r.size == Vector2.ZERO:
		return
	canvas.draw_texture_rect(_bg_tex, r, false, Color(1, 1, 1, BG_ALPHA))

## 背景图像素矩形（无图 = 零矩形）；frame 缺省 = 全部点包围盒外扩 1 格。
func background_rect(pts: Array = []) -> Rect2:
	var bg: Dictionary = _vm.get("background", {})
	_bg_tex = ArtLoader.map_background(bg) if not bg.is_empty() else null
	if _bg_tex == null:
		return Rect2()
	if pts.is_empty():
		pts = _all_points()
	var f: Array = bg.get("frame", [])
	if f.size() != 4:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q: Variant in pts:
			lo = lo.min(Vector2(float(q[0]), float(q[1])))
			hi = hi.max(Vector2(float(q[0]), float(q[1])))
		f = [lo.x - 1.0, lo.y - 1.0, hi.x + 1.0, hi.y + 1.0]
	var p0 := _grid_to_px([f[0], f[1]], pts)
	var p1 := _grid_to_px([f[2], f[3]], pts)
	return Rect2(p0, p1 - p0)

func _draw_site(pts: Array) -> void:
	var areas := {}
	for a: Variant in _vm.get("areas", []):
		areas[str((a as Dictionary)["id"])] = a
	for l: Variant in _vm.get("links", []):
		var ld: Dictionary = l
		if areas.has(str(ld["from"])) and areas.has(str(ld["to"])):
			canvas.draw_line(_grid_to_px(areas[str(ld["from"])]["pos"], pts), _grid_to_px(areas[str(ld["to"])]["pos"], pts),
				Color(0.6, 0.55, 0.42), 3.0, true)
	var font := get_theme_default_font()
	for a2: Variant in _vm.get("areas", []):
		var d: Dictionary = a2
		if not bool(d.get("known", false)):
			continue
		var c := _grid_to_px(d["pos"], pts)
		var rect := Rect2(c - Vector2(52, 26), Vector2(104, 52))
		var entered := bool(d.get("entered", false))
		var fill_a := 0.82 if _bg_tex != null else 1.0 # 有背景图：区域框半透，透出插画
		canvas.draw_rect(rect, Color(0.16, 0.15, 0.22, fill_a) if entered else Color(0.08, 0.08, 0.10, fill_a), true)
		var border := Color(1.0, 0.82, 0.38) if bool(d.get("current", false)) else Color(0.55, 0.5, 0.4)
		if entered or bool(d.get("current", false)):
			canvas.draw_rect(rect, border, false, 2.0)
		else:
			for side: Array in [[rect.position, rect.position + Vector2(rect.size.x, 0)],
					[rect.position + Vector2(0, rect.size.y), rect.end], [rect.position, rect.position + Vector2(0, rect.size.y)],
					[rect.position + Vector2(rect.size.x, 0), rect.end]]:
				canvas.draw_dashed_line(side[0], side[1], border, 1.5, 6.0)
		var txt := str(d.get("name", "?"))
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 13)
		canvas.draw_string(font, c + Vector2(-tw.x * 0.5, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.95, 0.9, 0.8) if entered else Color(0.6, 0.6, 0.65))

## 拖 ▲ 队伍标记到地点 = 选定并出发（12 §1 双通道；点按地点 + 出发为等价路径）。
func _on_canvas_input(ev: InputEvent) -> void:
	if _mode != "region" or _vm.is_empty():
		return
	var here := str(_vm.get("here", ""))
	var hb: Button = _loc_buttons.get(here)
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed and hb != null and hb.get_rect().grow(TOKEN_GRAB * 0.5).has_point(mb.position):
			_drag_token = true
		elif not mb.pressed and _drag_token:
			_drag_token = false
			for id: Variant in _loc_buttons.keys():
				if str(id) != here and (_loc_buttons[id] as Button).get_rect().grow(8).has_point(mb.position):
					drop_token_on(str(id))
					return

## 拖放落点（测试探针同入口）：选中并出发。
func drop_token_on(id: String) -> void:
	location_tapped.emit(id)
	travel_pressed.emit()

# ---------------------------------------------------------------- 骰子（事件流）

func on_event(ev: Dictionary) -> void:
	if not _built:
		return
	if dice_tray != null:
		dice_tray.settings_path = audio_settings_path
		dice_tray.palette = Cosmetics.palette_of(null)
		dice_tray.on_event(ev)
	var p: Dictionary = ev.get("payload", {})
	match StringName(str(ev.get("type", ""))):
		EventTypes.TABLE_ROLL:
			var dice: Array = p.get("dice", [])
			dice_glyph.die = str(p.get("die", "d6")) if str(p.get("die", "")) != "d100" else "d10"
			dice_value.text = str(int(p.get("total", 0)))
			dice_detail.text = Texts.s(&"TABLE_ROLL_FMT") % [str(p.get("die", "")), int(p.get("value", 0)),
				int(p.get("mod", 0)), int(p.get("total", 0)), str(p.get("label", ""))]
			if dice.size() > 1:
				dice_value.text = str(int(p.get("value", 0)))
		EventTypes.CHECK_ROLL:
			dice_glyph.die = "d20"
			dice_value.text = str(int(p.get("keep", 0)))
			var skill := str(p.get("skill", ""))
			dice_detail.text = Texts.s(&"MAP_CHECK_LINE") % [str(Texts.t(&"SKILL_NAMES").get(skill, skill)),
				int(p.get("keep", 0)), int(p.get("mod", 0)), int(p.get("total", 0)), int(p.get("dc", 0)),
				Texts.s(&"RESULT_SUCCESS") if bool(p.get("success", false)) else Texts.s(&"RESULT_FAIL")]

## 测试探针：地点按钮。
func location_button(id: String) -> Button:
	return _loc_buttons.get(id)
