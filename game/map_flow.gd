# 地图与场所流程（docs/en/framework/16-map-and-exploration-spec.md）：自战役流程分出的独立模块。
# 职责：在 map / site 节点上驱动 RegionMap / SiteMap（core），把结果分派给对应出口——
#   遭遇 → 战役流程的整备与战斗（胜负都回地图）；事件卡 → 卡片弹层；节点 → 故事图 travel_to；
#   抵达地点 → 进入地点节点或场所；时辰推进时间钟 → 复查时间边（可能直接改写剧情）。
# 壳只呈现 ScreenMap（形态感知：竖屏纵列 / 横屏左图右栏），掷骰与写板全部在 core。
class_name MapFlow
extends RefCounted

var m: Node
var flow: CampaignFlow
var region: RegionMap = null
var site: SiteMap = null
var screen: ScreenMap = null
var _selected := ""
var _pace := "normal"
var _card := ""          # 打开中的事件卡
var _note := ""          # 最近一步的结果摘要（信息卡第一行）
var _busy := false
var _pending_arrival := "" # 到达那一段被事件卡打断：卡片结算后再进入地点

func _init(main: Node, campaign: CampaignFlow) -> void:
	m = main
	flow = campaign

func _mod_fn() -> Callable:
	return Callable(m.graph, "check_mod")

func _in_site_key() -> String:
	return "%s.map.%s.in_site" % [m._campaign_id, region.map_id] if region != null else ""

## 呈现当前 map / site 节点（战役流程 _present_node 分派而来）。
func present() -> void:
	var node: Dictionary = m.graph.current()
	var ntype := str(node.get("type", ""))
	site = null
	_selected = "" # 重新呈现（回到地图 / 战后 / 读档）一律从"未选目的地"开始，防陈旧目标
	_note = ""
	if ntype == "map":
		region = RegionMap.new(m.board, m.stream, m.rng, m.pack, str(node.get("map", "")))
		var in_site := str(m.board.read(_in_site_key(), ""))
		if in_site != "" and in_site != "false":
			site = SiteMap.new(m.board, m.stream, m.rng, m.pack, in_site)
	elif ntype == "site":
		region = null
		site = SiteMap.new(m.board, m.stream, m.rng, m.pack, str(node.get("site", "")))
	_ensure_screen()
	if site != null and site.entered().is_empty():
		var en := site.enter(str(site.site.get("start", "")), _mod_fn(), m.graph.current_id)
		if _dispatch(en.get("outcome", {})):
			return
	refresh()

func _ensure_screen() -> void:
	m._set_window_orientation(flow._story_mode()) # 地图随战役形态呈现（09 §8）
	if m.current_screen is ScreenMap and is_instance_valid(m.current_screen):
		screen = m.current_screen
		return
	screen = ScreenMap.new()
	screen.set_form(flow._story_mode())
	m._swap(screen)
	screen.audio_settings_path = UiSettings.PATH
	screen.location_tapped.connect(_on_location)
	screen.pace_changed.connect(func(p: String) -> void:
		_pace = p
		refresh())
	screen.travel_pressed.connect(_on_travel)
	screen.camp_pressed.connect(func() -> void: screen.open_camp(flow._camp_data()))
	screen.camp_action.connect(flow._on_hub_action)
	screen.menu_pressed.connect(flow._on_save_quit)
	screen.card_option.connect(_on_card_option)
	screen.feature_pressed.connect(_on_feature)
	screen.exit_pressed.connect(_on_exit)
	m.stream.subscribe(screen.on_event)
	screen.tree_exiting.connect(func() -> void: m.stream.unsubscribe(screen.on_event))

## 重绘（数据全部来自 core 视图 + 本流程的选择状态）。
func refresh() -> void:
	if screen == null or not is_instance_valid(screen):
		return
	var common := {"clock": m.board.get_doom_clock(), "gold": m.graph.get_gold(), "party": m.graph.party_status(),
		"note": _note}
	if site != null:
		var sv := site.view()
		sv.merge(common)
		screen.show_site(sv)
	elif region != null:
		var rv := region.view()
		rv.merge(common)
		rv["selected"] = _selected
		rv["pace"] = _pace
		var sel_route := region.route_between(region.pos(), _selected) if _selected != "" else {}
		rv["selected_route"] = sel_route
		screen.show_region(rv)
	if _card != "":
		screen.show_card((m.pack.get("cards", {}) as Dictionary).get(_card, {}))

func _on_location(id: String) -> void:
	if _busy or region == null:
		return
	_selected = "" if id == region.pos() else id
	_note = ""
	refresh()

## 出发 / 继续：一次推进一段（16 §2.2：一步一骰）。
func _on_travel() -> void:
	if _busy or region == null:
		return
	if region.journey().is_empty():
		if _selected == "":
			# 原地"进入"：当前地点有场所 / 节点则进入（返回地点的入口）
			_arrive_at(region.pos())
			return
		var reason := region.start_journey(_selected, _pace, m.graph.current_id)
		if reason != "":
			_selected = ""
			_note = Texts.s(&"MAP_NO_ROUTE")
			refresh()
			return
	_busy = true
	var res := region.step(_mod_fn(), m.graph.current_id)
	_note = _step_note(res)
	refresh()
	await m.get_tree().create_timer(0.9).timeout # 让骰子条 / 托盘落定再推进
	_busy = false
	if m.graph.rescan(): # 时辰满额推进时间钟 → 时间边可能改写剧情
		flow._present_node()
		return
	if bool(res.get("arrived", false)):
		_selected = ""
		_pending_arrival = str(res["to"])
	if _dispatch(res.get("outcome", {})):
		return
	if _pending_arrival != "":
		var to := _pending_arrival
		_pending_arrival = ""
		_arrive_at(to)
		return
	refresh()

func _step_note(res: Dictionary) -> String:
	var parts: Array[String] = [] # 掷骰明细已在骰子条；这里只说结果（迷途 / 抵达 / 路上发生了什么）
	var tr: Dictionary = res.get("table", {})
	if str(tr.get("label", "")) != "":
		parts.append(str(tr["label"]))
	if bool(res.get("lost", false)):
		parts.append(Texts.s(&"MAP_LOST"))
	if bool(res.get("arrived", false)):
		parts.append(Texts.s(&"MAP_ARRIVED") % str(region.location(str(res["to"])).get("name", res["to"])))
	return "\n".join(parts)

## 结果分派：遭遇 / 事件卡 / 节点会离开当前呈现 → 返回 true；其余（效果 / 检定 / 无）留在地图。
func _dispatch(outcome: Dictionary) -> bool:
	match str(outcome.get("kind", "none")):
		"encounter":
			_pending_arrival = "" # 战后回到地图：玩家在目的地按"进入"即可
			flow._enter_encounter(str(outcome["encounter"]))
			return true
		"card":
			_card = str(outcome["card"])
			refresh()
			return true
		"node":
			_leave_site()
			m.graph.travel_to(str(outcome["node"]))
			flow._present_node()
			return true
	if m.graph.rescan():
		flow._present_node()
		return true
	return false

## 抵达地点：节点 → 进入故事节点；场所 → 进入场所（首次从 start 区域开始）。
func _arrive_at(loc: String) -> void:
	var l := region.location(loc)
	if str(l.get("site", "")) != "":
		m.board.write(_in_site_key(), str(l["site"]),
			{"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id})
		site = SiteMap.new(m.board, m.stream, m.rng, m.pack, str(l["site"]))
		_note = ""
		if site.entered().is_empty():
			var en := site.enter(str(site.site.get("start", "")), _mod_fn(), m.graph.current_id)
			if _dispatch(en.get("outcome", {})):
				return
		refresh()
		return
	if str(l.get("node", "")) != "":
		m.graph.travel_to(str(l["node"]))
		flow._present_node()

func _leave_site() -> void:
	if region != null and site != null:
		m.board.write(_in_site_key(), "",
			{"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id})
	site = null

func _on_card_option(idx: int) -> void:
	if _card == "" or _busy:
		return
	var tables := EventTables.new(m.board, m.stream, m.rng, m.pack)
	var res := tables.choose_card_option(_card, idx, _mod_fn(), m.graph.current_id)
	_card = ""
	screen.hide_card()
	_note = ""
	if str(res.get("kind", "")) == "check":
		_note = Texts.s(&"RESULT_SUCCESS") if bool(res.get("success", false)) else Texts.s(&"RESULT_FAIL")
		_busy = true
		await m.get_tree().create_timer(0.8).timeout
		_busy = false
	if _dispatch(res):
		return
	if _pending_arrival != "" and region != null:
		var to := _pending_arrival
		_pending_arrival = ""
		_arrive_at(to)
		return
	refresh()

func _on_feature(fid: String) -> void:
	if site == null or _busy:
		return
	var res := site.use_feature(fid, _mod_fn(), m.graph.current_id)
	_note = ""
	if str(res.get("kind", "")) == "check":
		_note = Texts.s(&"RESULT_SUCCESS") if bool(res.get("success", false)) else Texts.s(&"RESULT_FAIL")
		_busy = true
		await m.get_tree().create_timer(0.8).timeout
		_busy = false
	if _dispatch(res):
		return
	refresh()

func _on_exit(to: String) -> void:
	if site == null or _busy:
		return
	var res := site.go(to, _mod_fn(), m.graph.current_id)
	if bool(res.get("to_map", false)):
		if region != null:
			_leave_site()
			_note = ""
			refresh()
		else:
			flow._present_story_node() # site 节点：回到节点出边
		return
	_note = ""
	if not bool(res.get("moved", false)):
		_note = Texts.s(&"SITE_NEED_KEY") if str(res.get("reason", "")) == "need_key" else Texts.s(&"SITE_DOOR_FAIL")
		_busy = true
		await m.get_tree().create_timer(0.8).timeout
		_busy = false
	if _dispatch(res.get("outcome", {})):
		return
	refresh()
