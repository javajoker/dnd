# 整备界面 v2（docs/framework/09-遭遇与双模式交互规范.md §9.1；tech/02 §2.4 loadout 配置；11 §8.1/§8.2）
# 逐角色整备：为技能 / 道具 / 装备都可能很多的队伍而设计——
# - 队伍卡（置顶）：每名队员一张卡（HP / AC），点选 = 打开其角色表；同时是拖放目标；
# - 角色表：四个装备槽（武器 / 护甲 / 盾牌 / 饰物）+ 备战技能槽（玩家按配置槽位；同伴恒带招牌技能）；
# - 快取袋（全队共享）：战斗中附赠动作取用；未放进快取袋的道具仍在背包，战斗中取用耗 1 动作；
# - 资源库：技能 / 道具 / 装备三个页签的可滚动列表，每条一句话说明与归属；
#   **点按 = 交给当前角色**，**拖到任一队伍卡 / 槽位 / 快取袋 = 指定交付**（12 §1 双通道铁律）；
#   点按已备条目 = 取下。只有一件的装备拖给别人 = 直接转手。
# - 槽位限制读配置（manifest `loadout`，遭遇级可覆盖）——框架只执行，不硬编码；
# - 确认经 Loadout.confirm 写 `loadout.confirm` 事件；装备变更由引导层写板（Equipment，世界状态）。
# - 形态感知双布局（04 §④.8）：竖屏纵列（拇指区放开战）；横屏三段横列——左角色表 / 中资源库 + 快取袋 /
#   右预设与开战，队伍卡置顶。两形态同数据同操作路径。
class_name ScreenLoadout
extends Control

signal confirmed(selection: Dictionary)
signal back_requested
signal camp_pressed ## 开战前扎营 / 补给 / 用药（11 §7.2 / §8.2）：引导层回填营地数据 → open_camp
signal camp_action(action: String, arg: String) ## 营地弹层动作（buy / short_rest / long_rest / use_item）

const LIB_SKILLS := &"skills"
const LIB_ITEMS := &"items"
const LIB_GEAR := &"gear"

var form: StringName = ShellRouter.MODE_TIME # 战役形态（09 §8；04 §④.8）：time=竖屏纵列，space=横屏三段

var party_bar: HBoxContainer    # 队伍卡（两形态都有；拖放目标）
var sheet_title: Label
var equip_grid: GridContainer   # 四装备槽（拖放目标）
var skill_box: VBoxContainer    # 当前角色备战技能
var item_box: VBoxContainer     # 快取袋（拖放目标）
var lib_tabs: HBoxContainer
var lib_list: VBoxContainer     # 资源库条目（可拖动）
var lib_hint: Label
var attr_label: Label
var attr_box: HBoxContainer
var hint_label: Label
var confirm_button: Button
var back_button: Button
var camp_button: Button         # 扎营：开战前回血 / 补给 / 用道具
var camp_popup: HubPopup        # 与结算屏 / 地图同一弹层组件（04 §3.3）

# 横屏专版容器（04 §④.8；竖屏形态恒为 null，作布局形态探针）
var cols: HBoxContainer
var col_skills: VBoxContainer   # 左：角色表
var col_items: VBoxContainer    # 中：资源库 + 快取袋 + 属性点
var col_right: VBoxContainer    # 右：预设与开战
var preset_label: Label         # 预设卡（当前选择摘要）
var preset_box: BoxContainer    # 系统预设按钮（09 §9.3）

var _config: Dictionary = {}
var _skills: Array = []          # 玩家技能池 [{id,name,kind,damage,uses,…}]（兼容旧候选结构）
var _items: Array = []           # 可放进快取袋的道具 [{id,name,count,use?}]
var _party: Array = []           # 队伍 [{id,name,kind?,hp,max_hp,ac?,learned?,skill_slots?,equipment?}]
var _gear: Array = []            # 装备库 [{id,name,count,equip}]
var _basic_attacks: Array = []   # 角色普攻（恒定携带、不占槽位，tech/04 §2 basic_attack）
var _player_id := ""             # 玩家模板队员 id（无队伍数据时为空串 = 只整备玩家）
var _sel := ""                   # 当前角色表的队员 id
var _lib_tab: StringName = LIB_SKILLS
var _picked_skills: Array[String] = []   # 玩家备战技能（兼容探针 picked_skills）
var _picked_by_char: Dictionary = {}     # 同伴备战技能 {cid: Array}
var _picked_items: Array[String] = []    # 快取袋
var _equip: Dictionary = {}              # 装备工作副本 {cid: {slot: iid}}（确认时写板）
var _attr_points := 0
var _attr_alloc := {"might": 0, "finesse": 0, "wits": 0}
var _attrs_base := {"might": 0, "finesse": 0, "wits": 0} # 板上已分配值（封顶判定，11 §6）
var _built := false

## 设定呈现形态（main 依战役形态注入，09 §8）；已建布局则重建并刷新（同数据重排）。
func set_form(mode: StringName) -> void:
	form = mode
	if _built:
		_rebuild()

func _ready() -> void:
	_build()
	_built = true
	SafeArea.fit(self) # 根 Control 父级为纯 Node：显式落位到视口安全区（tech/01 §10.1）

func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	cols = null
	col_skills = null
	col_items = null
	col_right = null
	preset_label = null
	_build()
	_refresh()

func _build() -> void:
	_make_widgets()
	if form == ShellRouter.MODE_SPACE:
		_build_landscape()
	else:
		_build_portrait()
	camp_popup = HubPopup.new() # 最后加入：盖在布局之上
	camp_popup.buy_requested.connect(func(iid: String) -> void: camp_action.emit("buy", iid))
	camp_popup.short_rest_requested.connect(func(cid: String) -> void: camp_action.emit("short_rest", cid))
	camp_popup.rest_requested.connect(func() -> void: camp_action.emit("long_rest", ""))
	camp_popup.use_item_requested.connect(func(iid: String, cid: String) -> void:
		camp_action.emit("use_item", "%s:%s" % [iid, cid]))
	add_child(camp_popup)

func _make_widgets() -> void:
	party_bar = HBoxContainer.new()
	party_bar.name = "PartyBar"
	party_bar.add_theme_constant_override("separation", 6)
	sheet_title = Label.new()
	sheet_title.add_theme_font_size_override("font_size", 18)
	equip_grid = GridContainer.new()
	equip_grid.columns = 2
	equip_grid.add_theme_constant_override("h_separation", 6)
	equip_grid.add_theme_constant_override("v_separation", 6)
	skill_box = VBoxContainer.new()
	skill_box.add_theme_constant_override("separation", 4)
	item_box = VBoxContainer.new()
	item_box.name = "Pouch"
	item_box.add_theme_constant_override("separation", 4)
	item_box.set_drag_forwarding(Callable(), _can_drop_any, func(_p: Vector2, data: Variant) -> void:
		drop_on_pouch(data as Dictionary))
	lib_tabs = HBoxContainer.new()
	lib_tabs.add_theme_constant_override("separation", 4)
	for tab: StringName in [LIB_SKILLS, LIB_ITEMS, LIB_GEAR]:
		var b := Button.new()
		b.name = "Tab_%s" % tab
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		b.text = Texts.s({LIB_SKILLS: &"LOADOUT_TAB_SKILLS", LIB_ITEMS: &"LOADOUT_TAB_ITEMS",
			LIB_GEAR: &"LOADOUT_TAB_GEAR"}[tab])
		b.pressed.connect(func() -> void: set_library_tab(tab))
		lib_tabs.add_child(b)
	lib_list = VBoxContainer.new()
	lib_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lib_list.add_theme_constant_override("separation", 4)
	lib_hint = Label.new()
	lib_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lib_hint.add_theme_font_size_override("font_size", 12)
	lib_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	attr_label = Label.new()
	attr_box = HBoxContainer.new()
	attr_box.add_theme_constant_override("separation", 6)
	hint_label = Label.new()
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	confirm_button = Button.new()
	confirm_button.text = Texts.s(&"LOADOUT_CONFIRM")
	confirm_button.custom_minimum_size = Vector2(0, 56)
	confirm_button.add_theme_font_size_override("font_size", 20)
	confirm_button.pressed.connect(_on_confirm)
	back_button = Button.new()
	back_button.text = Texts.s(&"COMMON_BACK")
	back_button.custom_minimum_size = Vector2(0, 44)
	back_button.pressed.connect(func() -> void: back_requested.emit())
	camp_button = Button.new()
	camp_button.name = "CampButton"
	camp_button.text = Texts.s(&"LOADOUT_CAMP")
	camp_button.custom_minimum_size = Vector2(0, 44)
	camp_button.pressed.connect(func() -> void: camp_pressed.emit())

func _scroll(content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(content)
	return sc

## 竖屏纵列：标题行（退路）→ 队伍卡 → 角色表 → 快取袋 → 资源库（滚动，占余高）→ 加点 / 预设 → 开战（拇指区）。
func _build_portrait() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var top := HBoxContainer.new()
	var title := Label.new()
	title.text = Texts.s(&"LOADOUT_TITLE")
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(camp_button)
	top.add_child(back_button)
	v.add_child(top)
	v.add_child(party_bar)
	v.add_child(sheet_title)
	v.add_child(equip_grid)
	v.add_child(skill_box)
	v.add_child(item_box)
	v.add_child(lib_tabs)
	v.add_child(_scroll(lib_list))
	v.add_child(lib_hint)
	v.add_child(attr_label)
	v.add_child(attr_box)
	preset_box = HBoxContainer.new() # 系统预设一键套用（09 §9.3；无配置 = 空行不占地）
	(preset_box as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	preset_box.add_theme_constant_override("separation", 6)
	v.add_child(preset_box)
	v.add_child(hint_label)
	v.add_child(confirm_button)

## 横屏专版（04 §④.8）：队伍卡置顶 + 三段横列（左角色表 / 中资源库+快取袋+属性点 / 右预设与开战）。
func _build_landscape() -> void:
	var root_v := VBoxContainer.new()
	root_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_v.add_theme_constant_override("separation", 10)
	add_child(root_v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root_v.add_child(top)
	var title := Label.new()
	title.text = Texts.s(&"LOADOUT_TITLE")
	title.add_theme_font_size_override("font_size", 24)
	top.add_child(title)
	party_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(party_bar)
	cols = HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 20)
	root_v.add_child(cols)
	col_skills = VBoxContainer.new()
	col_skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_skills.size_flags_stretch_ratio = 3.0
	col_skills.add_theme_constant_override("separation", 6)
	cols.add_child(col_skills)
	col_skills.add_child(sheet_title)
	col_skills.add_child(equip_grid)
	col_skills.add_child(skill_box)
	col_items = VBoxContainer.new()
	col_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_items.size_flags_stretch_ratio = 4.0
	col_items.add_theme_constant_override("separation", 6)
	cols.add_child(col_items)
	col_items.add_child(lib_tabs)
	col_items.add_child(_scroll(lib_list))
	col_items.add_child(lib_hint)
	col_items.add_child(item_box)
	col_items.add_child(attr_label)
	col_items.add_child(attr_box)
	col_right = VBoxContainer.new()
	col_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_right.size_flags_stretch_ratio = 2.0
	col_right.add_theme_constant_override("separation", 8)
	cols.add_child(col_right)
	var preset_title := Label.new()
	preset_title.text = Texts.s(&"LOADOUT_PRESET_TITLE")
	preset_title.add_theme_font_size_override("font_size", 18)
	col_right.add_child(preset_title)
	preset_box = VBoxContainer.new() # 系统预设一键套用（09 §9.3：预设卡可点击套用）
	preset_box.add_theme_constant_override("separation", 4)
	col_right.add_child(preset_box)
	preset_label = Label.new()
	preset_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preset_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	col_right.add_child(preset_label)
	var right_spacer := Control.new()
	right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_right.add_child(right_spacer)
	col_right.add_child(hint_label)
	confirm_button.custom_minimum_size = Vector2(240, 72) # 大号开战按钮（拇指右手区）
	col_right.add_child(confirm_button)
	camp_button.custom_minimum_size = Vector2(240, 48)
	col_right.add_child(camp_button)
	col_right.add_child(back_button)

# ---------------------------------------------------------------- 数据绑定

## candidates = {skills[], items[], attr_points, attr_alloc, attrs, party[], gear[], basic_attacks[], last?}。
## party 条目可带 kind / ac / learned[] / skill_slots / equipment{}（逐角色整备）；缺省 = 只整备玩家（兼容旧结构）。
func bind(config: Dictionary, candidates: Dictionary) -> void:
	_config = config
	_skills = candidates.get("skills", [])
	_items = candidates.get("items", [])
	_party = candidates.get("party", [])
	_gear = candidates.get("gear", [])
	_basic_attacks = candidates.get("basic_attacks", [])
	_attr_points = int(candidates.get("attr_points", 0))
	_attr_alloc = (candidates.get("attr_alloc", {"might": 0, "finesse": 0, "wits": 0}) as Dictionary).duplicate()
	_attrs_base = (candidates.get("attrs", {"might": 0, "finesse": 0, "wits": 0}) as Dictionary).duplicate()
	_picked_skills.clear()
	_picked_items.clear()
	_picked_by_char.clear()
	_equip.clear()
	_player_id = ""
	for p: Variant in _party:
		var d: Dictionary = p
		if str(d.get("kind", "")) == "player_template" and _player_id.is_empty():
			_player_id = str(d["id"])
		_equip[str(d["id"])] = (d.get("equipment", {}) as Dictionary).duplicate()
	if _player_id.is_empty() and not _party.is_empty():
		_player_id = str((_party[0] as Dictionary)["id"]) # 无 kind 标注：首位视为玩家（旧结构）
	_sel = _player_id
	_prefill(candidates.get("last", {}))
	_refresh()

## 营地动作后刷新备选（HP / 道具数 / 装备库变了），保留当前已做的选择（仍合法的部分）。
func update_candidates(candidates: Dictionary) -> void:
	_party = candidates.get("party", _party)
	_items = candidates.get("items", _items)
	_gear = candidates.get("gear", _gear)
	_skills = candidates.get("skills", _skills)
	for iid: String in _picked_items.duplicate():
		if _item_entry(iid).is_empty():
			_picked_items.erase(iid) # 用掉的最后一瓶药：从快取袋摘下
	_refresh()

## 打开营地弹层（data = {gold, stock, party, rest_free, usable}，引导层 CampaignFlow._camp_data 组装）。
func open_camp(data: Dictionary) -> void:
	camp_popup.usable = data.get("usable", [])
	camp_popup.open(int(data.get("gold", 0)), data.get("stock", []), data.get("party", []),
		HubPopup.MODE_CAMP, bool(data.get("rest_free", false)))

## 营地动作后刷新弹层（开着才刷，不关弹层）。
func sync_camp(data: Dictionary) -> void:
	if camp_popup.visible:
		camp_popup.usable = data.get("usable", [])
		camp_popup.rest_free = bool(data.get("rest_free", false))
		camp_popup.bind(int(data.get("gold", 0)), data.get("stock", []), data.get("party", []))

## 沿用上次整备（只填仍合法的：已习得 / 仍持有 / 槽位内）。
func _prefill(last: Dictionary) -> void:
	if last.is_empty():
		return
	var by_char: Dictionary = last.get("skills_by_char", {})
	for cid: Variant in by_char.keys():
		for sid: Variant in by_char[cid]:
			if _knows(str(cid), str(sid)) and _prepared(str(cid)).size() < _slots_for(str(cid)):
				_prepared(str(cid)).append(str(sid))
	for iid: Variant in last.get("items", []):
		if _item_entry(str(iid)).size() > 0 and _picked_items.size() < int(_config.get("item_slots", 0)):
			_picked_items.append(str(iid))

# ---------------------------------------------------------------- 数据查询

func _entry(cid: String) -> Dictionary:
	for p: Variant in _party:
		if str((p as Dictionary)["id"]) == cid:
			return p
	return {}

func _name(cid: String) -> String:
	var e := _entry(cid)
	return str(e.get("name", cid)) if not e.is_empty() else Texts.s(&"LOADOUT_TITLE")

func _is_player(cid: String) -> bool:
	return cid == _player_id

## 该队员可备战的技能列表。
func _learned(cid: String) -> Array:
	if _is_player(cid):
		return _skills
	return _entry(cid).get("learned", [])

func _knows(cid: String, sid: String) -> bool:
	for sk: Variant in _learned(cid):
		if str((sk as Dictionary)["id"]) == sid:
			return true
	return false

## 备战槽位数：玩家 = 配置 skill_slots；同伴 = 条目 skill_slots（缺省 / -1 = 招牌技能恒带，不可选）。
func _slots_for(cid: String) -> int:
	if _is_player(cid):
		return int(_config.get("skill_slots", 0))
	return int(_entry(cid).get("skill_slots", -1))

func _prepared(cid: String) -> Array:
	if _is_player(cid):
		return _picked_skills
	if not _picked_by_char.has(cid):
		_picked_by_char[cid] = []
	return _picked_by_char[cid]

func _item_entry(iid: String) -> Dictionary:
	for it: Variant in _items:
		if str((it as Dictionary)["id"]) == iid:
			return it
	return {}

func _gear_entry(iid: String) -> Dictionary:
	for g: Variant in _gear:
		if str((g as Dictionary)["id"]) == iid:
			return g
	return {}

## 当前工作副本中装备了 iid 的队员。
func _holders(iid: String) -> Array[String]:
	var out: Array[String] = []
	for cid: Variant in _equip.keys():
		for slot: Variant in (_equip[cid] as Dictionary).keys():
			if str(_equip[cid][slot]) == iid:
				out.append(str(cid))
	return out

# ---------------------------------------------------------------- 操作（点按 / 拖放同一入口）

func select_character(cid: String) -> void:
	_sel = cid
	hint_label.text = ""
	_refresh()

func set_library_tab(tab: StringName) -> void:
	_lib_tab = tab
	_refresh()

## 技能交给 cid：已备 → 取下；未备 → 备上（槽满 / 不会 → 提示）。
func assign_skill(cid: String, sid: String) -> void:
	if _slots_for(cid) < 0 or not _knows(cid, sid):
		hint_label.text = Texts.s(&"LOADOUT_CANT_LEARN") % [_name(cid), _skill_name(sid)]
		return
	var prep := _prepared(cid)
	if prep.has(sid):
		prep.erase(sid)
	elif prep.size() < _slots_for(cid):
		prep.append(sid)
	else:
		hint_label.text = Texts.s(&"LOADOUT_FULL")
		return
	hint_label.text = ""
	_refresh()

## 装备交给 cid：同槽替换；只有一件且在别人身上 = 转手。返回原因码（"" = 成功）。
func assign_gear(cid: String, iid: String) -> String:
	var g := _gear_entry(iid)
	if g.is_empty() or not _equip.has(cid):
		return "not_equipment"
	var eb: Dictionary = g.get("equip", {})
	var users: Array = eb.get("users", [])
	if not users.is_empty() and not users.has(cid):
		hint_label.text = Texts.s(&"LOADOUT_CANT_USE") % [_name(cid), str(g.get("name", iid))]
		return "not_user"
	var slot := str(eb.get("slot", ""))
	if str((_equip[cid] as Dictionary).get(slot, "")) == iid:
		(_equip[cid] as Dictionary).erase(slot) # 再点一次 = 卸下
		hint_label.text = ""
		_refresh()
		return ""
	var others := _holders(iid)
	others.erase(cid)
	hint_label.text = ""
	if others.size() >= int(g.get("count", 1)):
		var from := others[0] # 没有多余的：从第一位持有者手里转手
		for s: Variant in (_equip[from] as Dictionary).keys():
			if str(_equip[from][s]) == iid:
				(_equip[from] as Dictionary).erase(s)
				break
		hint_label.text = Texts.s(&"LOADOUT_HANDED") % [str(g.get("name", iid)), _name(from), _name(cid)]
	(_equip[cid] as Dictionary)[slot] = iid
	_refresh()
	return ""

func clear_slot(cid: String, slot: String) -> void:
	if _equip.has(cid):
		(_equip[cid] as Dictionary).erase(slot)
	_refresh()

## 资源库点按 = 交给当前角色（道具 = 放进 / 取出快取袋）。
func tap_library(kind: StringName, id: String) -> void:
	match kind:
		LIB_SKILLS:
			assign_skill(_sel, id)
		LIB_ITEMS:
			_toggle_item(id)
		LIB_GEAR:
			assign_gear(_sel, id)

## 拖放落到队伍卡。
func drop_on_character(cid: String, data: Dictionary) -> void:
	match StringName(str(data.get("kind", ""))):
		LIB_SKILLS:
			_sel = cid
			assign_skill(cid, str(data.get("id", "")))
		LIB_GEAR:
			_sel = cid
			assign_gear(cid, str(data.get("id", "")))
		LIB_ITEMS:
			drop_on_pouch(data)

## 拖放落到装备槽（槽位不符 = 忽略）。
func drop_on_slot(cid: String, slot: String, data: Dictionary) -> void:
	if StringName(str(data.get("kind", ""))) != LIB_GEAR:
		return
	var g := _gear_entry(str(data.get("id", "")))
	if str((g.get("equip", {}) as Dictionary).get("slot", "")) != slot:
		return
	assign_gear(cid, str(data["id"]))

## 拖放落到快取袋（道具 → 放进；已在袋中不重复）。
func drop_on_pouch(data: Dictionary) -> void:
	if StringName(str(data.get("kind", ""))) != LIB_ITEMS:
		return
	if not _picked_items.has(str(data.get("id", ""))):
		_toggle_item(str(data["id"]))

func _can_drop_any(_pos: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("kind")

func _skill_name(sid: String) -> String:
	var pools: Array = [_skills]
	for p: Variant in _party:
		pools.append((p as Dictionary).get("learned", []))
	for pool: Variant in pools:
		for sk: Variant in (pool as Array):
			if str((sk as Dictionary)["id"]) == sid:
				return str((sk as Dictionary).get("name", sid))
	return sid

# ---------------------------------------------------------------- 渲染

func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _refresh() -> void:
	_refresh_party()
	_refresh_sheet()
	_refresh_pouch()
	_refresh_library()
	_refresh_attrs()
	_refresh_preset_box()
	_refresh_preset()

## 队伍卡：名字 + HP（+ AC）；当前角色高亮；拖放目标。
func _refresh_party() -> void:
	_clear(party_bar)
	party_bar.visible = not _party.is_empty()
	for p: Variant in _party:
		var d: Dictionary = p
		var cid := str(d["id"])
		var b := Button.new()
		b.name = "Card_%s" % cid
		b.toggle_mode = true
		b.button_pressed = cid == _sel
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 56)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # 长名字换行，不截断（卡片随之增高）
		b.text = Texts.s(&"LOADOUT_PARTY_CARD") % [str(d.get("name", cid)), int(d.get("hp", 0)), int(d.get("max_hp", 0))]
		b.pressed.connect(func() -> void: select_character(cid))
		b.set_drag_forwarding(Callable(), _can_drop_any, func(_p: Vector2, data: Variant) -> void:
			drop_on_character(cid, data as Dictionary))
		party_bar.add_child(b)

## 角色表：标题（HP/AC）+ 四装备槽 + 备战技能。
func _refresh_sheet() -> void:
	_clear(equip_grid)
	_clear(skill_box)
	var e := _entry(_sel)
	sheet_title.visible = not e.is_empty()
	equip_grid.visible = not e.is_empty() and (not _gear.is_empty() or _has_equipment(_sel))
	if not e.is_empty():
		sheet_title.text = Texts.s(&"LOADOUT_SHEET") % [str(e.get("name", _sel)), int(e.get("hp", 0)),
			int(e.get("max_hp", 0)), int(e.get("ac", 10)) + _equip_ac_delta(_sel)]
		var slot_names: Dictionary = Texts.t(&"SLOT_NAME")
		for slot: String in Equipment.SLOTS:
			var iid := str((_equip.get(_sel, {}) as Dictionary).get(slot, ""))
			var b := Button.new()
			b.name = "Slot_%s" % slot
			b.custom_minimum_size = Vector2(0, 40)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # 长装备名换行，不截断
			b.text = Texts.s(&"LOADOUT_SLOT_FMT") % [str(slot_names.get(slot, slot)),
				str(_gear_entry(iid).get("name", iid)) if iid != "" else Texts.s(&"LOADOUT_SLOT_EMPTY")]
			if iid != "":
				ArtLoader.decorate_item_button(b, iid, _gear_entry(iid))
			var cid := _sel
			b.pressed.connect(func() -> void:
				if iid != "":
					clear_slot(cid, slot)
				else:
					set_library_tab(LIB_GEAR))
			b.set_drag_forwarding(Callable(), _can_drop_any, func(_p: Vector2, data: Variant) -> void:
				drop_on_slot(cid, slot, data as Dictionary))
			equip_grid.add_child(b)
	# 备战技能
	var head := Label.new()
	var slots := _slots_for(_sel)
	if slots < 0:
		var names: Array[String] = []
		for sk: Variant in _learned(_sel):
			names.append(str((sk as Dictionary).get("name", (sk as Dictionary)["id"])))
		head.text = Texts.s(&"LOADOUT_SIGNATURE") % Texts.s(&"LIST_SEP").join(names) if not names.is_empty() \
			else Texts.s(&"LOADOUT_NO_SKILLS")
		skill_box.add_child(head)
		return
	head.text = Texts.s(&"LOADOUT_PREPARED") % [_prepared(_sel).size(), slots]
	skill_box.add_child(head)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	for sid: Variant in _prepared(_sel):
		var b := Button.new()
		b.text = "● %s ✕" % _skill_name(str(sid))
		b.custom_minimum_size = Vector2(0, 40)
		var s := str(sid)
		var cid2 := _sel
		b.pressed.connect(func() -> void: assign_skill(cid2, s))
		row.add_child(b)
	skill_box.add_child(row)

func _has_equipment(cid: String) -> bool:
	return not (_equip.get(cid, {}) as Dictionary).is_empty()

## 工作副本相对板上装备的 AC 变化（角色表实时显示换装后的 AC）。
func _equip_ac_delta(cid: String) -> int:
	var now := 0
	for slot: Variant in (_equip.get(cid, {}) as Dictionary).keys():
		now += int((_gear_entry(str(_equip[cid][slot])).get("equip", {}) as Dictionary).get("ac", 0))
	var before := 0
	var orig: Dictionary = _entry(cid).get("equipment", {})
	for slot: Variant in orig.keys():
		before += int((_gear_entry(str(orig[slot])).get("equip", {}) as Dictionary).get("ac", 0))
	return now - before

## 快取袋（全队共享）：已放入的道具芯片，点按取出；拖放目标。
func _refresh_pouch() -> void:
	_clear(item_box)
	var slots := int(_config.get("item_slots", 0))
	var head := Label.new()
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.text = Texts.s(&"LOADOUT_POUCH") % [_picked_items.size(), slots]
	item_box.add_child(head)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	for iid: String in _picked_items:
		var d := _item_entry(iid)
		var b := Button.new()
		b.text = "● %s ×%d ✕" % [str(d.get("name", iid)), int(d.get("count", 1))]
		b.custom_minimum_size = Vector2(0, 40)
		ArtLoader.decorate_item_button(b, iid, d)
		b.pressed.connect(func() -> void: _toggle_item(iid))
		row.add_child(b)
	item_box.add_child(row)

## 资源库：当前页签条目（每条：名称 + 一句话说明 + 归属），点按 = 交给当前角色，拖动 = 指定交付。
func _refresh_library() -> void:
	_clear(lib_list)
	for b: Node in lib_tabs.get_children():
		(b as Button).button_pressed = b.name == "Tab_%s" % _lib_tab
	var entries: Array = []
	match _lib_tab:
		LIB_SKILLS:
			for sk: Variant in _learned(_sel):
				var d: Dictionary = sk
				var sid := str(d["id"])
				entries.append({"id": sid, "title": str(d.get("name", sid)), "desc": Texts.skill_desc(d),
					"on": _prepared(_sel).has(sid) if _slots_for(_sel) >= 0 else true})
		LIB_ITEMS:
			for it: Variant in _items:
				var d2: Dictionary = it
				var iid := str(d2["id"])
				entries.append({"id": iid, "title": "%s ×%d" % [str(d2.get("name", iid)), int(d2.get("count", 1))],
					"desc": Texts.item_desc(d2.get("use", {})) if d2.has("use") else "",
					"on": _picked_items.has(iid)})
		LIB_GEAR:
			for g: Variant in _gear:
				var d3: Dictionary = g
				var gid := str(d3["id"])
				var hs := _holders(gid)
				var who: Array[String] = []
				for h: String in hs:
					who.append(_name(h))
				var title := "%s ×%d" % [str(d3.get("name", gid)), int(d3.get("count", 1))]
				if not who.is_empty():
					title += Texts.s(&"LOADOUT_ON") % Texts.s(&"LIST_SEP").join(who)
				entries.append({"id": gid, "title": title, "desc": Texts.gear_desc(d3.get("equip", {})),
					"on": hs.has(_sel)})
	if entries.is_empty():
		var l := Label.new()
		l.text = Texts.s(&"LOADOUT_EMPTY_LIB")
		lib_list.add_child(l)
	for en: Variant in entries:
		lib_list.add_child(_lib_card(en as Dictionary))
	lib_hint.text = Texts.s(&"LOADOUT_LIB_HINT") % _name(_sel) if not _party.is_empty() else ""

func _lib_card(en: Dictionary) -> Button:
	var b := Button.new()
	var id := str(en["id"])
	b.name = "Lib_%s" % id
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(0, 48)
	b.text = ("● " if bool(en.get("on", false)) else "○ ") + str(en["title"])
	if str(en.get("desc", "")) != "":
		b.text += "\n   " + str(en["desc"])
	var kind := _lib_tab
	if kind == LIB_ITEMS:
		ArtLoader.decorate_item_button(b, id, _item_entry(id), 32)
	elif kind == LIB_GEAR:
		ArtLoader.decorate_item_button(b, id, _gear_entry(id), 32)
	b.pressed.connect(func() -> void: tap_library(kind, id))
	b.set_drag_forwarding(func(_p: Vector2) -> Variant:
		var pv := Label.new()
		pv.text = str(en["title"])
		pv.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		b.set_drag_preview(pv)
		return {"kind": String(kind), "id": id}, Callable(), Callable())
	return b

func _refresh_attrs() -> void:
	_clear(attr_box)
	attr_label.text = Texts.s(&"LOADOUT_ATTRS") % _attr_points
	attr_label.visible = _attr_points > 0 or _alloc_total() > 0
	attr_box.visible = attr_label.visible
	var names: Dictionary = Texts.t(&"ATTR_SHORT")
	for attr: String in ["might", "finesse", "wits"]:
		var b := Button.new()
		b.text = "%s %+d +" % [str(names[attr]), int(_attr_alloc.get(attr, 0))]
		b.custom_minimum_size = Vector2(0, 40)
		var total_now := int(_attrs_base.get(attr, 0)) + int(_attr_alloc.get(attr, 0))
		b.disabled = _attr_points <= 0 or total_now >= LightV1.ATTR_POINT_CAP # 单项 ≤+3 封顶（11 §6）
		b.pressed.connect(func() -> void:
			_attr_alloc[attr] = int(_attr_alloc[attr]) + 1
			_attr_points -= 1
			_refresh())
		attr_box.add_child(b)

func _alloc_total() -> int:
	return int(_attr_alloc.get("might", 0)) + int(_attr_alloc.get("finesse", 0)) + int(_attr_alloc.get("wits", 0))

## 系统预设按钮（09 §9.3；配置驱动——manifest loadout.presets，tech/02 §2.4；无配置 = 不呈现）。
func _refresh_preset_box() -> void:
	if preset_box == null:
		return
	_clear(preset_box)
	for p: Variant in _config.get("presets", []):
		var preset: Dictionary = p
		var b := Button.new()
		b.text = str(preset.get("name", preset.get("id", "")))
		b.custom_minimum_size = Vector2(0, 40)
		b.tooltip_text = "%s / %s" % [str(preset.get("skills", [])), str(preset.get("items", []))]
		b.pressed.connect(func() -> void: _apply_preset(preset))
		preset_box.add_child(b)

## 一键套用预设（09 §9.3：玩家技能 + 快取袋；套用后可逐槽微调；预设不含数值加成）。
## 普攻（basic_attack）恒定携带不占槽位（tech/04 §2）；未习得技能 / 未持有道具跳过并提示。
func _apply_preset(preset: Dictionary) -> void:
	var skill_slots := int(_config.get("skill_slots", 0))
	var item_slots := int(_config.get("item_slots", 0))
	var missing: Array[String] = []
	_picked_skills.clear()
	_picked_items.clear()
	for sid: Variant in preset.get("skills", []):
		var s := str(sid)
		if _picked_skills.size() >= skill_slots:
			break
		if _basic_attacks.has(s):
			continue
		var known := false
		for sk: Variant in _skills:
			if str((sk as Dictionary)["id"]) == s:
				known = true
				break
		if known:
			_picked_skills.append(s)
		else:
			missing.append(s)
	for iid: Variant in preset.get("items", []):
		var it := str(iid)
		if _picked_items.size() >= item_slots:
			break
		if not _item_entry(it).is_empty():
			_picked_items.append(it)
		else:
			missing.append(it)
	_refresh()
	hint_label.text = Texts.s(&"LOADOUT_PRESET_MISSING") % Texts.s(&"LIST_SEP").join(missing) \
		if not missing.is_empty() else ""

## 预设卡 = 当前选择摘要（横屏右列）。
func _refresh_preset() -> void:
	if preset_label == null:
		return
	var names: Array[String] = []
	for sid: String in _picked_skills:
		names.append(_skill_name(sid))
	for iid: String in _picked_items:
		names.append(str(_item_entry(iid).get("name", iid)))
	preset_label.text = Texts.s(&"LIST_SEP").join(names) if not names.is_empty() else Texts.s(&"LOADOUT_PRESET_EMPTY")

## 兼容入口：为玩家切换技能（旧测试 / 预设微调）。
func _toggle_skill(sid: String) -> void:
	var cid := _player_id
	if _picked_skills.has(sid):
		_picked_skills.erase(sid)
	elif _picked_skills.size() < _slots_for(cid):
		var known := _skills.is_empty()
		for sk: Variant in _skills:
			if str((sk as Dictionary)["id"]) == sid:
				known = true
		if known:
			_picked_skills.append(sid)
	_refresh()

func _toggle_item(iid: String) -> void:
	if _picked_items.has(iid):
		_picked_items.erase(iid)
	elif _picked_items.size() < int(_config.get("item_slots", 0)):
		_picked_items.append(iid)
	else:
		hint_label.text = Texts.s(&"LOADOUT_FULL")
		return
	_refresh()

func _on_confirm() -> void:
	var reason := Loadout.validate(_config, _picked_skills, _picked_items)
	if reason != "":
		hint_label.text = Texts.s(&"COLON_PAIR_FMT") % [Texts.s(&"LOADOUT_FULL"), reason]
		return
	var by_char := {}
	if not _player_id.is_empty():
		by_char[_player_id] = _picked_skills.duplicate()
	for cid: Variant in _picked_by_char.keys():
		if _slots_for(str(cid)) >= 0:
			by_char[str(cid)] = (_picked_by_char[cid] as Array).duplicate()
	confirmed.emit({"skills": _picked_skills.duplicate(), "items": _picked_items.duplicate(),
		"attr_alloc": _attr_alloc.duplicate(), "attr_points_left": _attr_points,
		"skills_by_char": by_char, "equipment": _equip.duplicate(true)})

# ---------------------------------------------------------------- 测试探针

func picked_skills() -> Array[String]:
	return _picked_skills.duplicate()

func picked_items() -> Array[String]:
	return _picked_items.duplicate()

func picked_for(cid: String) -> Array:
	return _prepared(cid).duplicate()

func equipment_of(cid: String) -> Dictionary:
	return (_equip.get(cid, {}) as Dictionary).duplicate()

func selected_character() -> String:
	return _sel

## 布局形态探针（04 §④.8：横屏三段横列）。
func is_landscape_layout() -> bool:
	return cols != null
