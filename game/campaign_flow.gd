# 战役流程（白皮书 §9 元循环；04 §2 主动脉：入口 → 节点 → 遭遇 → 结算）：自 main.gd 拆出（代码评审 M2）。
# 职责：开局 / 节点呈现 / 故事边推进 / 迷宫节拍 / 整备与遭遇 / 结算与加点 / 结局与多周目 / 章节锁定页；
# 战役进行态（遭遇中、快照锚点、结算缓存、所选形态）归本对象。
# 通过 `m`（main 应用层）使用共享服务：状态板、事件流、RNG、权利、故事图、换屏与转场、存档。
class_name CampaignFlow
extends RefCounted

var m: Node

var _in_encounter := false
var _encounter_snapshot: Dictionary = {} # 遭遇进入前快照（09 §7 ☰ 回主屏恢复点）
var _encounter_tail := 0                 # 遭遇开始时的事件锚点（结算汇总区间）
var _campaign_tail := 0                  # 战役开始锚点（切片结算汇总区间）
var _encounter_result: StringName = &""
var _encounter_id := ""                  # 当前战斗节点的遭遇 id（tech/02 §6）
var _battle_title := ""
var _battles_won := 0
var _mode: StringName = &""
var _maze: MazeRunner = null      # 进行中的探索序列核（core 渐进执行，壳只呈现）
var _maze_outcome := ""           # 上一拍结果摘要（拼进下一拍文本）
var _settle_lines: Array[String] = [] # 结算汇总缓存（卷轴往返 / 加点刷新复用）
var _settle_celebrated := false # 本场胜利演出已播（04 §④.8：加点/卷轴往返重绑不重播）

func _init(main: Node) -> void:
	m = main

func _on_mode_chosen(mode: StringName) -> void:
	# 模式选择 = 一次分支，写入状态板（09 §3）；全局白名单键（07 §3 v1.1）
	m.board.write("global.mode_choice.%s" % m._campaign_id, String(mode),
		{"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id})

func _on_campaign_start(entry: ScreenEntry) -> void:
	_mode = entry.selected_mode
	if _mode == &"":
		return
	if m.graph.is_at_ending():
		_on_ngplus_start() # 已通关战役再开 = 多周目（战役书 §9：结局屏外同一继承语义）
		return
	if not m.graph.visit_log.is_empty():
		_present_node() # 战役进行中：继续当前节点（主屏"继续"语义，04 §①）
		return
	_start_campaign()

## 战役开局：播种金币（hub 商店）→ 序章带入补给 → 从入口节点真实走图（tech/02 §3）。
func _start_campaign() -> void:
	_campaign_tail = m.stream.tail()
	m.graph.seed_gold()
	m.graph.start()
	# 开局带入（manifest.start.items，叙事既定；campaign01 = 补给药水 ×2，战役书 §4）
	for it: Variant in m.graph.start_items():
		m.board.give_item(str((it as Dictionary).get("item", "")), int((it as Dictionary).get("n", 1)),
			{"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id})
	_present_node()

## 呈现当前节点：ending → 结局屏（tech/02 §9）；battle → 整备/遭遇；
## explore（迷宫探索序列，tech/02 §6 maze）→ 逐拍呈现；出切片范围 → 切片结算；其余 → 双壳故事态。
func _present_node() -> void:
	var act := str(m.graph.current().get("act", ""))
	if act != "" and not m.entitlements.enter_act(m.pack, act):
		_show_act_lock(act) # 幕级门槛未点亮：章节锁定页（06 §3.1；tech/02 §2.2）
		return
	if m.graph.is_at_ending():
		_present_ending()
		return
	if not m.SLICE_ACTS.has(str(m.graph.current().get("act", ""))):
		_end_slice()
		return
	var ntype := str(m.graph.current().get("type", ""))
	if ntype == "battle":
		_enter_encounter()
		return
	if ntype == "explore" and _maze_pending():
		_enter_maze()
		return
	_present_story_node()

func _present_story_node() -> void:
	var vm := StoryVM.build(m.graph, m.board, m.pack)
	_ensure_story_shell()
	_story_show(vm)
	# 情境教程：首次检定（12 §4：双指点击快掷；可跳过不丢信息）
	for e: Variant in vm["edges"]:
		if bool((e as Dictionary).get("check", false)):
			m._context_hint("first_check", Texts.s(&"TUT_HINT_CHECK"))
			break

func _story_show(vm: Dictionary) -> void:
	if m.shell is EncounterPortrait:
		(m.shell as EncounterPortrait).show_story(vm)
	elif m.shell is EncounterLandscape:
		(m.shell as EncounterLandscape).show_story(vm)

## 当前节点要求的壳形态（tech/02 §2.1：forced 按幕强制、forced_except 幕内节点级例外——
## 战役书幕三：SL-3 强制竖屏，N3-7 空白广场起恢复玩家所选形态"此处起解锁横屏"；09 §3 强制是叙事手段）。
func _story_mode() -> StringName:
	var pres: Dictionary = (m.pack.get("manifest", {}) as Dictionary).get("presentation", {})
	var act := str(m.graph.current().get("act", ""))
	var forced: Dictionary = pres.get("forced", {})
	if forced.has(act):
		var exempt: Array = (pres.get("forced_except", {}) as Dictionary).get(act, [])
		if not exempt.has(m.graph.current_id):
			return ShellRouter.effective(StringName(str(forced[act])))
	return ShellRouter.effective(_mode)

func _shell_mode() -> StringName:
	if m.shell is EncounterPortrait:
		return ShellRouter.MODE_TIME
	if m.shell is EncounterLandscape:
		return ShellRouter.MODE_SPACE
	return &""

## 故事壳就位：实例化/复用同一壳（09 §8 一局一壳），绑定故事回调（唯一指令通道）。
## 强制幕换壳（09 §3 内容驱动，非玩家切换——router 的玩家切换锁不变）：形态不一致即重建壳，
## 并以叙事化提示呈现（09 §3：禁止系统腔；锁定用 NOTICE_FORCED，解锁用 Texts.s(&"STORY_MODE_UNLOCK")）。
func _ensure_story_shell() -> void:
	var want := _story_mode()
	var notice := ""
	m._set_window_orientation(want) # 窗口随壳形态（09 §8：开始战役即切换；forced 幕内外双向经同一通道）
	if m.shell != null and _shell_mode() != want:
		m.shell.queue_free()
		m.shell = null
		m.router = ShellRouter.new() # 换壳重开一局壳锁定（09 §8：锁管玩家切换，不管内容驱动换壳）
		notice = ShellRouter.forced_notice(want) if want != _mode \
			else Texts.s(&"STORY_MODE_UNLOCK")
	var created := false
	if m.shell == null:
		m.shell = (load(m.SHELL_SCENES[want]) as PackedScene).instantiate()
		UITheme.attach(m.shell as Control)
		m.add_child(m.shell)
		m.shell.set("on_save_quit", Callable(self, "_on_save_quit"))
		m.router.lock_encounter(want) # 形态整场锁定（09 §3/§8：战役开始即定壳）
		created = true
	var old: Control = m.current_screen
	m.current_screen = m.shell
	if created and m.transition != null:
		# 入口→遭遇（故事壳新建）：转场中场壳现身、旧屏回收（14 #8 淡入淡出）
		m.shell.visible = false
		m.transition.swap_at_mid(old, null, m.shell)
	else:
		if old != null and old != m.shell:
			old.queue_free()
		m.shell.visible = true
	m.shell.bind_story(m.stream, m.board, m.pack, {"edge": _on_story_edge, "hub": _on_hub_action})
	if notice != "": # 换壳提示在新壳订阅事件流之后发出（事件流驱动 toast，壳只订阅）
		m.stream.emit(EventTypes.LOG, {"msg": notice, "toast": true}, &"core", m.graph.current_id)

## 玩家执行节点选项：check 边真实掷骰（11 §3，check.roll 事件驱动两级演出 09 §6）；
## dialog 选项回复进日志；边效果/on_enter 写板由 StoryGraph 落（07 §1 溯源）。
## 探索序列进行中时，选项按钮 = 推进当前节拍（MazeRunner，tech/02 §6 maze）。
func _on_story_edge(idx: int) -> void:
	if _maze != null:
		_on_maze_advance()
		return
	var edges: Array = m.graph.available_edges()
	if idx < 0 or idx >= edges.size():
		return
	var edge: Dictionary = edges[idx]
	if str(m.graph.current().get("type", "")) == "dialog":
		m.stream.emit(EventTypes.LOG, {"msg_key": "MSG_STORY_ECHO", "args": {
			"title": str(m.graph.current().get("title", "")),
			"text": str(edge.get("label", Texts.s(&"STORY_CONTINUE")))}}, &"core", m.graph.current_id)
	if str(edge.get("type", "")) == "check":
		var res: Dictionary = m.graph.roll_check(edge)
		await m.get_tree().create_timer(2.3 if bool(res.get("key", false)) else 0.8).timeout # 等演出落定
	else:
		m.graph.take_edge(edge)
	_present_node()

## Hub / 营地动作（战役书 §4 N1-1；11 §7.2 短休/长休）：商店购买 / 旅店长休 / 短休 / 野外长休 / 传闻；
## 写板全部在 core，本层只转发与刷新。野外长休推进时钟可能触发 doom_clock 边直接改写当前节点 → 重新呈现。
func _on_hub_action(action: String, arg: String) -> void:
	var before: String = m.graph.current_id
	match action:
		"buy":
			if not m.graph.hub_buy(arg):
				m.stream.emit(EventTypes.LOG, {"msg_key": "HUB_NO_GOLD", "toast": true}, &"core", m.graph.current_id)
		"rest":
			m.graph.hub_rest()
		"short_rest":
			m.graph.short_rest(arg)
		"long_rest":
			m.graph.long_rest(m.graph.rest_is_free())
		"rumor":
			var rumors: Array = m.graph.hub_rumors()
			var msg := StoryVM.rumor_text(rumors[0]) if not rumors.is_empty() else Texts.s(&"HUB_RUMOR_NONE")
			m.stream.emit(EventTypes.LOG, {"msg": msg, "toast": true}, &"core", m.graph.current_id)
			return
	if m.graph.current_id != before: # 时钟触发改道：弹层随旧节点作废
		_present_node()
		return
	if m.current_screen is ScreenSettle: # 结算屏营地（战斗之间）：只刷新弹层
		(m.current_screen as ScreenSettle).sync_camp(_camp_data())
		return
	var vm := StoryVM.build(m.graph, m.board, m.pack)
	_story_show(vm)
	m.shell.sync_hub_popup(vm)

## 营地弹层数据（结算屏用；故事态由 StoryVM 提供同口径字段）。
func _camp_data() -> Dictionary:
	return {"gold": m.graph.get_gold(), "stock": m.graph.hub_stock(), "party": m.graph.party_status(),
		"rest_free": m.graph.rest_is_free()}

## 切片终点（出 SL-0/SL-1 范围或结局节点）：结算快照落盘（07 §4.2 主快照点）+ ⑨结算屏。
func _end_slice() -> void:
	_in_encounter = false
	# 通关旗标 → 成就点亮路径（06 §2.1：点亮手段多样；规则表在运营配置，06 §3.2）
	if not bool(m.board.read("%s.cleared" % m._campaign_id)):
		m.board.write("%s.cleared" % m._campaign_id, true,
			{"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id})
	m.entitlements.check_achievements(m.ops_config)
	# 成长在 xp 效果产出时已即时汇入 global.growth.*（tech/04 §8 规则1/2）；
	# 结算界面 = 成长加点时机（11 §6；04 §⑨），此处只呈现与分配。
	m._save("settle")
	_encounter_tail = _campaign_tail # 汇总区间 = 整个切片（逐项念给玩家听，04 §⑨）
	_encounter_result = &"slice"
	_show_settle()

## 结局节点：写通关旗标（成就点亮路径 06 §2.1）→ story.ending 事件（tech/02 §9）→ 结局快照
## （07 §4.2 主快照点）→ 结局屏（四分型文案 + 多周目钩子均取 endings.json，壳不再创作）。
## 结局分型旗标（ending_e1~e4 / 解锁占位）由 ending 节点 on_enter 写板（nodes.json，V4 台账闭环）。
func _present_ending() -> void:
	_in_encounter = false
	m._set_window_orientation(ShellRouter.MODE_TIME) # 战役结束恢复原屏幕布局（09 §8：通关路径收束于竖屏基准）
	var eid: String = m.graph.current_id
	if not bool(m.board.read("%s.cleared" % m._campaign_id)):
		m.board.write("%s.cleared" % m._campaign_id, true,
			{"event_id": m.stream.tail(), "node_id": eid, "pack_id": m._campaign_id})
	m.entitlements.check_achievements(m.ops_config)
	var edef := {}
	for e: Variant in m.pack.get("endings", []):
		if str((e as Dictionary).get("id", "")) == eid:
			edef = e
	m.stream.emit(EventTypes.STORY_ENDING, {"ending": eid,
		"title": str(edef.get("title", m.graph.current().get("title", eid)))}, &"graph", eid)
	m._save("ending")
	var screen: ScreenEnding = (load(m.SCREEN_SCENES[&"ending"]) as PackedScene).instantiate()
	m._swap(screen)
	screen.bind({"ending_id": eid, "title": str(edef.get("title", eid)),
		# 结局演出全文 = text_ref 外置 → content 摘要兜底（tech/02 §9/§1.1；壳不创作）
		"content": StoryVM.ending_text(m.pack.get("texts", {}), edef, m.board, m._campaign_id),
		"hook": str(edef.get("ngplus_hook", "")),
		"playthrough": int(m.board.read(m._playthrough_key(), 0)) + 1, "saved": true})
	screen.ngplus_requested.connect(_on_ngplus_start)
	screen.go_home.connect(m._show_home)

## 开始二周目（战役书 §11 多周目继承清单·定稿；tech/02 §2.7 manifest.ngplus 数据驱动）：
## 继承内容唯一依据 = 战役包 manifest.ngplus（carries 共通 + per_ending 按结局解锁），
## 本函数不写死任何继承内容——改 manifest 即变；执行落 core（NgPlus.apply，bot NG+ 语义同口径）。
func _on_ngplus_start() -> void:
	var old_board: Board = m.board
	m.board = Board.new(m.stream)
	m.entitlements = Entitlements.new(m.board, m.stream)
	m.entitlements.apply_activities(m.ops_config)
	m.entitlements.apply_market_grants(m.ops_config, m._market())
	m.cosmetics = Cosmetics.new(m.board, m.stream)
	var ngplus_conf: Dictionary = ((m._pack_host.get("manifest", {}) as Dictionary)
		.get("ngplus", {})) # tech/02 §2.6：宿主原包 manifest 为唯一继承依据
	NgPlus.apply(old_board, m.board, m.stream, m.cosmetics, ngplus_conf, str(m._pack_host.get("pack_id", "")))
	m.graph = StoryGraph.new(m.board, m.rng, m._pack_host) # 从宿主原包重建（tech/02 §2.6：宿主数据不动）
	m._graft_discovered_arcs() # 支线随新周目重新注入（权利随新板再判定，06 §3.1）
	if m.shell != null:
		m.shell.queue_free()
		m.shell = null
	m.router = ShellRouter.new()
	_battles_won = 0
	m.stream.emit(EventTypes.LOG, {"msg_key": "NGPLUS_TOAST", "toast": true}, &"core")
	_start_campaign()

## 当前 explore 节点有待完成的探索序列（节拍进度簿记在状态板，中途离场续打不重效果）。
func _maze_pending() -> bool:
	var enc: Dictionary = (m.pack.get("encounters", {}) as Dictionary).get(
		str(m.graph.current().get("encounter", m.graph.current_id)), {})
	var beats: Array = (enc.get("maze", {}) as Dictionary).get("beats", [])
	if beats.is_empty():
		return false
	var enc_id := str(enc.get("id", m.graph.current_id))
	return int(m.board.read("%s.maze.%s.idx" % [m.pack["pack_id"], enc_id], 0)) < beats.size()

func _enter_maze() -> void:
	var enc_id := str(m.graph.current().get("encounter", m.graph.current_id))
	var enc: Dictionary = (m.pack.get("encounters", {}) as Dictionary).get(enc_id, {})
	_maze = MazeRunner.new(m.board, m.stream, m.rng, str(m.pack["pack_id"]))
	_maze.begin(enc_id, (enc.get("maze", {}) as Dictionary).get("beats", []),
		Callable(m.graph, "check_mod"), m.graph.current_id)
	_maze_outcome = ""
	_show_maze_beat()

## 呈现当前节拍：复用双壳故事态（StoryVM 单源），选项按钮 = 推进本拍。
func _show_maze_beat() -> void:
	if _maze == null:
		_present_node()
		return
	var beat := _maze.peek()
	if beat.is_empty(): # 序列完成 → 回节点呈现出边（密道道具边按条件显形，tech/02 §4.3）
		_maze = null
		_maze_outcome = ""
		_present_node()
		return
	var vm := StoryVM.build(m.graph, m.board, m.pack)
	vm["type"] = "explore"
	vm["title"] = Texts.s(&"MAZE_TITLE") % [str(m.graph.current().get("title", m.graph.current_id)),
		_maze.beat_index() + 1, _maze.beat_count()]
	vm["text"] = _maze_outcome + str(beat.get("text", ""))
	var label := Texts.s(&"STORY_CONTINUE")
	var btype := str(beat.get("type", ""))
	if btype == "check" or btype == "ambush":
		var skill := str(beat.get("skill", "perception"))
		var diff := str(beat.get("difficulty", "medium"))
		label = Texts.s(&"FMT_CHECK_LABEL") % [Texts.s(&"STORY_CHECK"),
			str(Texts.t(&"SKILL_NAMES").get(skill, skill)), str(Texts.t(&"DIFF_NAMES").get(diff, diff)),
			LightV1.dc_for(diff), m.graph.check_mod(skill)]
		if btype == "ambush":
			label = Texts.s(&"MAZE_AMBUSH_PREFIX") + label
	elif btype == "loot":
		label = Texts.s(&"MAZE_LOOT") % [m._item_name(str(beat.get("item", ""))), int(beat.get("n", 1))]
	vm["edges"] = [{"type": "choice", "label": label}]
	_ensure_story_shell()
	_story_show(vm)

## 推进当前节拍：掷骰/写板在 core（check.roll、item.gain、效果 DSL 事件进事件流）；
## 结果摘要拼入下一拍文本；等快掷落定再刷新（09 §6 普通检定 ≤0.5s 出结果）。
func _on_maze_advance() -> void:
	var res := _maze.resolve()
	if bool(res.get("retry", false)):
		# 解谜房：失败给提示原地重试（tech/02 §6 retry_on_fail/hint；campaign01 迷宫未声明，通用能力）
		_maze_outcome = "%s %s\n\n" % [Texts.s(&"MAZE_BEAT_FAIL"), str(res.get("hint", ""))]
	elif str(res.get("type", "")) == "loot":
		_maze_outcome = "%s\n\n" % Texts.s(&"MAZE_LOOT") % [m._item_name(str(res.get("item", ""))),
			int(res.get("n", 1))]
	else:
		_maze_outcome = (Texts.s(&"MAZE_BEAT_OK") if bool(res.get("success", false)) \
			else Texts.s(&"MAZE_BEAT_FAIL")) + "\n\n"
	await m.get_tree().create_timer(0.8).timeout
	_show_maze_beat()

func _enter_encounter() -> void:
	var node: Dictionary = m.graph.current()
	_encounter_id = str(node.get("encounter", m.graph.current_id))
	_battle_title = str(node.get("title", _encounter_id))
	m._set_window_orientation(_story_mode()) # 整备同战役形态（09 §8）：壳未建时窗口先就位（如「继续」直达战斗节点）
	var cfg := Loadout.resolve_config(m.pack, _encounter_id)
	if not cfg.is_empty():
		cfg = cfg.duplicate() # 2→3 级技能槽 +1（11 §6；槽位基值仍读配置，tech/02 §2.4）
		cfg["skill_slots"] = int(cfg["skill_slots"]) \
			+ LightV1.skill_slot_bonus(Growth.level(m.board))
	if cfg.is_empty():
		_begin_encounter({"skills": [], "items": ["heal_potion"], "attr_alloc": {}}) # 空选择 = BattleDef 缺省
		return
	var screen: ScreenLoadout = (load(m.SCREEN_SCENES[&"loadout"]) as PackedScene).instantiate()
	screen.set_form(_story_mode()) # 整备横屏专版（04 §④.8：横屏三段横列 + 队伍状态条置顶）
	m._swap(screen)
	screen.bind(cfg, _loadout_candidates(cfg))
	screen.confirmed.connect(_on_loadout_confirmed.bind(cfg))
	screen.back_requested.connect(_present_node) # 整备可退回节点（04 §5 有退路）

## 整备备选（09 §9.1 v2 逐角色整备）：
## - skills = 玩家模板已习得 ∩ skills.json（tech/04 §7）；items = 背包含 use 块条目（快取袋候选，tech/04 §4）；
## - party = 队伍状态 + 每人已习得技能 / 当前装备（同伴备战槽 = loadout.companion_skill_slots，缺省 -1 恒带）；
## - gear = 背包里的装备（11 §8.1）；last = 上次整备（沿用，仍合法的才回填）。
func _loadout_candidates(cfg: Dictionary = {}) -> Dictionary:
	var skill_pool: Array = []
	var skills: Dictionary = m.pack.get("skills", {})
	for sid: Variant in _player_template().get("skills", []):
		if skills.has(str(sid)):
			skill_pool.append(BattleDef.runtime_skill(skills[str(sid)]))
	var items: Array = []
	var gear: Array = []
	var pack_items: Dictionary = m.pack.get("items", {})
	for iid: String in pack_items.keys():
		var it: Dictionary = pack_items[iid]
		if not m.board.has_item(iid):
			continue
		if it.has("use") and str((it["use"] as Dictionary).get("timing", "")) != "out_of_combat":
			items.append({"id": iid, "name": str(it.get("name", iid)), "count": m.board.item_count(iid),
				"use": (it["use"] as Dictionary).duplicate()})
		if it.has("equip"):
			gear.append({"id": iid, "name": str(it.get("name", iid)), "count": m.board.item_count(iid),
				"equip": (it["equip"] as Dictionary).duplicate()})
	var party: Array = []
	for p: Variant in m.graph.party_status():
		var e: Dictionary = (p as Dictionary).duplicate()
		var c: Dictionary = (m.pack.get("characters", {}) as Dictionary).get(str(e["id"]), {})
		var learned: Array = []
		for sid: Variant in c.get("skills", []):
			if skills.has(str(sid)):
				learned.append(BattleDef.runtime_skill(skills[str(sid)]))
		e["learned"] = learned
		if str(e.get("kind", "")) != "player_template":
			e["skill_slots"] = int(cfg.get("companion_skill_slots", -1))
		e["equipment"] = Equipment.equipped(m.board, m._campaign_id, pack_items, str(e["id"]))
		party.append(e)
	var last: Variant = m.board.read("%s.loadout_last" % m._campaign_id, {})
	return {"skills": skill_pool, "items": items, "gear": gear,
		"attr_points": Growth.attr_points(m.board), # 成长簿记归全局键（tech/04 §8）
		"attrs": Growth.attrs_map(m.board), # 已分配值（单项 +3 封顶判定用，11 §6）
		"attr_alloc": {"might": 0, "finesse": 0, "wits": 0},
		"party": party, # 队伍卡（04 §④.8 置顶；04 §3.1 同口径）+ 逐角色整备数据
		"last": last if last is Dictionary else {},
		"basic_attacks": _basic_attacks()} # 普攻恒定携带（tech/04 §2；预设套用不占槽，09 §9.3）

## 队伍普攻清单（tech/04 §2 basic_attack 亦属已习得）：预设含普攻 = 视为已携带，不占整备槽位。
func _basic_attacks() -> Array:
	var out: Array = []
	for cid: String in (m.pack.get("characters", {}) as Dictionary).keys():
		var c: Dictionary = m.pack["characters"][cid]
		if not ["player_template", "companion"].has(str(c.get("kind", ""))):
			continue
		var ba := str(c.get("basic_attack", ""))
		if not ba.is_empty() and not out.has(ba):
			out.append(ba)
	return out

## 玩家模板条目（tech/04 §2 kind=player_template；找不到 = 包数据缺陷，返回空字典由组装层报错）。
func _player_template() -> Dictionary:
	for cid: String in (m.pack.get("characters", {}) as Dictionary).keys():
		var c: Dictionary = m.pack["characters"][cid]
		if str(c.get("kind", "")) == "player_template":
			return c
	return {}

func _on_loadout_confirmed(selection: Dictionary, cfg: Dictionary) -> void:
	Loadout.confirm(m.stream, cfg, selection["skills"], selection["items"],
		selection["attr_alloc"], m.graph.current_id, m.pack["pack_id"]) # loadout.confirm 事件（09 §9.1）
	_apply_attr_alloc(selection.get("attr_alloc", {}), int(selection.get("attr_points_left", 0)))
	_apply_equipment(selection.get("equipment", {}))
	# 沿用上次整备（下次整备预填；簿记键不念给玩家）
	m.board.write("%s.loadout_last" % m._campaign_id, {"skills_by_char": selection.get("skills_by_char", {}),
		"items": selection.get("items", [])},
		{"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id})
	_begin_encounter(selection)

## 装备变更写板（11 §8.1；世界状态带溯源）：先卸后装，避免转手时的余量误判。
func _apply_equipment(equipment: Dictionary) -> void:
	if equipment.is_empty():
		return
	var prov := {"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id}
	var items: Dictionary = m.pack.get("items", {})
	for cid: Variant in equipment.keys():
		var want: Dictionary = equipment[cid]
		var have := Equipment.equipped(m.board, m._campaign_id, items, str(cid))
		for slot: String in Equipment.SLOTS:
			if have.has(slot) and str(want.get(slot, "")) != str(have[slot]):
				Equipment.unequip(m.board, m._campaign_id, str(cid), slot, prov)
	for cid: Variant in equipment.keys():
		var want2: Dictionary = equipment[cid]
		var have2 := Equipment.equipped(m.board, m._campaign_id, items, str(cid))
		for slot: Variant in want2.keys():
			if str(have2.get(str(slot), "")) != str(want2[slot]):
				var r := Equipment.equip(m.board, m.pack, str(cid), str(want2[slot]), prov)
				if r != "":
					push_warning("[campaign] 装备 %s → %s 未生效：%s" % [str(want2[slot]), str(cid), r])

## 属性点分配经成长系统写板 global.growth.*（07 §1 溯源；tech/04 §8 规则3）；
## 单项 ≤+3 封顶（11 §6）或点数不足 → 拒绝整体分配并返回 false。
func _apply_attr_alloc(alloc: Dictionary, _points_left: int = 0) -> bool:
	var growth := Growth.new(m.board)
	for attr: String in alloc.keys():
		var n := int(alloc[attr])
		if n <= 0:
			continue
		if Growth.attrs_total(m.board, attr) + n > LightV1.ATTR_POINT_CAP:
			return false # 单项 ≤+3 封顶（11 §6）
		if n > Growth.attr_points(m.board):
			return false # 未分配点数不足
	var prov := {"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id}
	for attr: String in alloc.keys():
		for i: int in int(alloc[attr]):
			if not growth.alloc(attr, prov):
				return false
	return true

func _begin_encounter(selection: Dictionary) -> void:
	_in_encounter = true
	_encounter_snapshot = SaveSystem.make_snapshot(m.board, m.stream, m.rng, m._bindings(), m._meta()) # ☰ 恢复点
	_encounter_tail = m.stream.tail()
	_encounter_result = &""
	var inames := {}
	for iid: String in (m.pack.get("items", {}) as Dictionary).keys():
		inames[iid] = str((m.pack["items"][iid] as Dictionary).get("name", iid))
	BattleText.item_names = inames # 日志道具显示名（不显内部 id）
	var sm := EncounterSM.new(m.board, m.stream, m.rng, m.pack["pack_id"])
	var agent := AutoAgent.new()
	_ensure_story_shell() # 复用故事壳（09 §8：一局一壳；bind 内切战斗布局）
	if m.current_screen != null and m.current_screen != m.shell:
		m.current_screen.queue_free()
	m.current_screen = m.shell
	m.shell.visible = true
	if m.shell is EncounterPortrait:
		(m.shell as EncounterPortrait).bind(sm, agent)
	else:
		(m.shell as EncounterLandscape).bind(sm, agent)
	m.shell.set("on_save_quit", Callable(self, "_on_save_quit"))
	m.router.lock_encounter(_mode) # 遭遇开始即壳锁定（09 §8）
	if m.transition != null:
		m.transition.encounter_enter(m.shell) # 遭遇进场：淡入淡出 + 轻微上移滑入（14 #8）
	var nid: String = m.graph.current_id
	sm.enter(nid)
	sm.transition(EncounterSM.S_EXPLORE)
	m.stream.emit(EventTypes.LOG, {"msg": str(m.graph.current().get("summary", ""))}, &"core", nid)
	await m.get_tree().create_timer(1.0).timeout
	if sm.state == EncounterSM.S_EXPLORE:
		var def := _battle_def(selection)
		if def.is_empty():
			return # fail-fast：包数据缺陷不进战斗（报错已由 _battle_def 输出）
		sm.begin_combat(def)

## 战斗定义 = pack 资源表组装（tech/04 §1~§4 / tech/02 §6；M2：TP2 硬编码留白落位）。
## 引用缺失/公式失败 = 包数据缺陷：fail-fast 报错并返回空字典（不静默降级、不进战斗）。
func _battle_def(selection: Dictionary) -> Dictionary:
	var enc: String = _encounter_id if not _encounter_id.is_empty() else m.graph.current_id
	var res := BattleDef.assemble(m.pack, enc, selection, m.board)
	if not bool(res["ok"]):
		push_error("[main] 战斗定义组装失败（%s/%s）：%s"
			% [m._campaign_id, enc, ";".join(res["errors"] as Array)])
		return {}
	return res["def"]

## ☰「保存并回主屏」（09 §7）：遭遇进行中 = 恢复遭遇进入前快照（本局重打，不存档）；
## 故事态（遭遇外）= 进度随图快照落档后回主屏（07 §4.2 遭遇外时机）。
func _on_save_quit() -> void:
	if _in_encounter:
		if m.shell != null:
			m.shell.queue_free()
			m.shell = null
		SaveSystem.apply(_encounter_snapshot, m.board, m.rng) # 恢复遭遇进入前的世界状态（战斗不写板，RNG 归位）
		m.graph.deserialize(_encounter_snapshot["meta"].get("graph", {}))
		m.stream.emit(EventTypes.LOG, {"msg_key": "MSG_REWIND_BATTLE"}, &"core")
		_in_encounter = false
		m._save("quit_home") # 恢复后的世界状态落档（遭遇外时机，07 §4.2）
		m._show_home()
		return
	m._save("quit_home") # 故事态：节点进度在 meta.graph 内随快照落档
	m.stream.emit(EventTypes.LOG, {"msg_key": "MSG_REWIND_STORY"}, &"core")
	m._show_home()

func _show_settle_deferred() -> void:
	await m.get_tree().create_timer(1.2).timeout
	_in_encounter = false
	if _encounter_result == &"victory":
		_battles_won += 1
		var edges: Array = m.graph.available_edges()
		if edges.is_empty():
			_end_slice()
			return
		# 胜利必经结算（04 §⑨：单局的句点，元循环的落笔处）——先念板+快照，再由玩家择出口。
		# 唯一出边先推进再落快照（07 §4.2：快照落在战后节点，「继续」不重打已胜之仗）；
		# 多条出边（hybrid 战后抉择 N2U-2 撕/不撕、通缉战 N2L-1b 强制择链）留在战斗节点，
		# 由结算「下一遭遇」呈现故事态抉择（tech/02 §6 hybrid）。
		if edges.size() == 1:
			m.graph.take_edge(edges[0])
		m._save("settle")
		_show_settle()
	elif _encounter_result == &"objective_failed":
		# 护送目标失败：罚时等代价已按 escort.failure_effects 写板（core，tech/02 §6），
		# 仍走节点唯一出边——罚时替代全灭（N2S-1 注记就近处理，08 §2 失败即分支）
		var edges: Array = m.graph.available_edges()
		if edges.is_empty():
			_end_slice()
			return
		m.graph.take_edge(edges[0])
		_present_node()
	else:
		m._save("settle") # 失败即分支：结算仍是元循环落笔（09 §7 失败不读档）
		_show_settle()

## 汇总区间 = 锚点之后的事件（04 §⑨：逐项念给玩家听）。
func _show_settle() -> void:
	var lines: Array[String] = []
	var xp := 0
	var gold := 0
	var attr_gained := 0
	for ev: Dictionary in m.stream.since(_encounter_tail):
		var p: Dictionary = ev["payload"]
		match StringName(ev["type"]):
			EventTypes.XP_GAIN:
				xp += int(p.get("amount", 0))
			EventTypes.LOG:
				gold += int(p.get("gold", 0)) # 战利金（11 §7.3；MSG_GOLD_GAIN 携带 gold 数额）
			EventTypes.LEVEL_UP:
				attr_gained += int(p.get("attr_points", 0)) # 升级即发放（tech/04 §8 规则2）
			EventTypes.ITEM_GAIN:
				lines.append(Texts.s(&"SETTLE_LINE_ITEM") % [m._item_name(str(p.get("item_id", ""))),
					int(p.get("count", 1))])
			EventTypes.FLAG_WRITE:
				var fkey := str(p.get("key", ""))
				# 内部簿记键（成长/模式选择/金币/HP）不念给玩家（04 §⑨ 呈现语义：旗标变化摘要）
				if StoryVM.is_bookkeeping_key(fkey):
					continue
				lines.append(Texts.s(&"SETTLE_LINE_FLAG") % StoryVM.flag_display(fkey, m.pack))
			EventTypes.REP_CHANGE:
				lines.append(Texts.s(&"SETTLE_LINE_REP") % [str(p.get("key", "")).trim_prefix("global.rep."),
					int(p.get("delta", 0))])
			EventTypes.LOADOUT_CONFIRM:
				lines.append(Texts.s(&"SETTLE_LINE_LOADOUT") % [str(p.get("skills", [])), str(p.get("items", []))])
	if gold > 0:
		lines.insert(0, Texts.s(&"SETTLE_LINE_GOLD") % [gold, m.graph.get_gold()])
	if xp > 0:
		lines.insert(0, Texts.s(&"SETTLE_LINE_XP") % xp)
	var level := Growth.level(m.board)
	if level > 1:
		lines.append(Texts.s(&"SETTLE_LINE_LEVEL") % level)
	if attr_gained > 0:
		lines.append(Texts.s(&"SETTLE_LINE_ATTR") % attr_gained)
	lines.append(Texts.s(&"SETTLE_LINE_CLOCK") % m.board.get_doom_clock())
	_settle_lines = lines
	_settle_celebrated = false # 新一场结算：胜利演出恢复首播（04 §④.8）
	_bind_settle()

func _bind_settle() -> void:
	m._set_window_orientation(_story_mode()) # 结算在所选形态下呈现（09 §8）；从⑧卷轴返回时恢复战役形态
	var screen: ScreenSettle = (load(m.SCREEN_SCENES[&"settle"]) as PackedScene).instantiate()
	screen.set_form(_story_mode()) # 结算横屏专版（04 §④.8：左念板列表 + 右加点与出口）
	m._swap(screen)
	screen.bind({"title": Texts.s(&"STORY_SLICE_END") if _encounter_result == &"slice" else _battle_title,
		"result": String(_encounter_result), "lines": _settle_lines,
		"saved": true, "attr_points": Growth.attr_points(m.board),
		"attrs": Growth.attrs_map(m.board),
		"has_next": _encounter_result == &"victory", # 下一遭遇出口（04 §⑨：胜利结算三出口）
		"can_camp": _encounter_result == &"victory", # 战斗之间扎营：短休/长休/补给（11 §7.2）
		"celebrate": not _settle_celebrated}) # 胜利演出每场首播（04 §④.8；加点刷新重绑不重播）
	_settle_celebrated = true
	screen.allocate.connect(_on_settle_allocate)
	screen.go_home.connect(m._show_home)
	screen.go_next.connect(_on_settle_next)
	screen.go_camp.connect(func() -> void: screen.open_camp(_camp_data())) # 战斗之间扎营（11 §7.2）
	screen.camp_action.connect(_on_hub_action)
	screen.go_history.connect(func() -> void:
		m._history_origin = &"settle"
		m._show_history())

## 胜利结算「下一遭遇」（04 §⑨）：唯一出边已在进结算前推进，此处呈现战后节点；
## 多条出边（hybrid 战后抉择）呈现战斗节点的故事态选项——不得 _present_node（type=battle 会重进遭遇，tech/02 §6）。
func _on_settle_next() -> void:
	var edges: Array = m.graph.available_edges()
	if edges.size() > 1 and str(m.graph.current().get("type", "")) == "battle":
		_present_story_node()
		return
	_present_node()

func _on_settle_allocate(attr: String) -> void:
	var prov := {"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id}
	if not Growth.new(m.board).alloc(attr, prov):
		return # 点数不足或单项 +3 封顶（11 §6）：拒绝并保持界面
	_bind_settle() # 刷新可用点数与已分配值

## 章节锁定页（06 §3.1：可见但锁定 + 叙事化 + 购买弹层；回营地不丢进度——节点已落档可继续）。
func _show_act_lock(act_id: String) -> void:
	m._set_window_orientation(ShellRouter.MODE_TIME)
	var key := str(Entitlements.act_requires(m.pack, act_id)[0]).trim_prefix("entitlement.")
	var item := Entitlements.price_of(m.ops_config, key)
	var act_title := ""
	for a: Variant in m.pack.get("acts", []):
		if str((a as Dictionary).get("id", "")) == act_id:
			act_title = str((a as Dictionary).get("title", act_id))
	var screen := ScreenLocked.new()
	m._swap(screen)
	screen.bind(act_title, key, str(item.get("name", key)), str(item.get("price_text", "")), m.store.is_available())
	screen.purchase_requested.connect(m._buy)
	screen.restore_requested.connect(m._restore_purchases)
	screen.back_requested.connect(func() -> void:
		m._save("locked_chapter")
		m._show_home())
