# 子游戏流程（白皮书 §10.2；04 §6；docs/subgames/）：自 main.gd 拆出（代码评审 M2）。
# 职责：子游戏开局 → 节点/迷宫/战斗推进 → 结算 → 回主屏；状态（进行中包、战斗中、快照锚点）归本对象。
# 通过 `m`（main 应用层）使用共享服务：状态板、事件流、RNG、权利、换屏与转场。
class_name SubgameFlow
extends RefCounted

var m: Node

var _sub: SubgameRunner = null        # 进行中的子游戏流程核
var _sub_active := false
var _sub_battling := false
var _sub_mode: StringName = &""
var _sub_tail := 0                    # 子游戏开始锚点（结算汇总区间，04 §⑨）
var _sub_snapshot: Dictionary = {}    # 子游戏遭遇进入前快照（09 §7 ☰ 恢复点）
var _sub_gold0 := 0                   # 子游戏开始时 <ns>.gold 读数（效果投放金币的结算增量口径）
var _sub_maze: MazeRunner = null      # 子游戏探索序列核（tech/02 §6 maze；谜回廊纯解谜复用）
var _sub_maze_outcome := ""
var _sub_settle_celebrated := false # 子游戏结算同理

func _init(main: Node) -> void:
	m = main

func _on_subgame_start(pack_id: String, mode: StringName) -> void:
	if not m._subgames.has(pack_id) or _sub_active:
		return
	if not m.entitlements.can_access((m._subgames[pack_id] as Dictionary)["manifest"]):
		# 硬门槛（tech/02 §2.2）：叙事化提示，无"未购买"生硬弹窗（06 §3.1）
		var lock := str(((m._subgames[pack_id] as Dictionary)["manifest"] as Dictionary).get("lock_text", ""))
		m.stream.emit(EventTypes.LOG, {"msg": lock, "toast": true} if lock != "" else
			{"msg_key": "LOCK_DEFAULT", "toast": true}, &"core")
		return
	_sub = SubgameRunner.new(m._subgames[pack_id], m.board, m.stream, m.rng)
	_sub_mode = mode
	_sub_active = true
	_sub_battling = false
	_sub_maze = null
	_sub_tail = m.stream.tail()
	_sub_gold0 = int(m.board.read("%s.gold" % pack_id, 0)) # 效果投放金币的结算增量口径（tech/02 §4.6 gold）
	# 模式选择 = 一次分支，写入状态板（09 §3；global.mode_choice.* 白名单，07 §3 v1.1）
	m.board.write("global.mode_choice.%s" % pack_id, String(mode),
		{"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": pack_id})
	_sub.start()
	_sub_present()

## 子游戏节点呈现：ending → ⑨ 结算；battle → 整备/遭遇；explore（maze 探索序列）→ 逐拍呈现；
## 其余 → 双壳故事态（StoryVM 单源）。
func _sub_present() -> void:
	var node := _sub.current()
	var t := str(node.get("type", ""))
	if t == "ending":
		_sub.on_clear() # tech/02 §2.5 clear_as_win：无战斗子游戏抵达结局节点记 1 胜
		_sub_finish(&"victory")
		return
	if t == "battle":
		_sub_enter_battle()
		return
	if t == "explore" and _sub_maze_pending():
		_sub_enter_maze()
		return
	_ensure_sub_shell()
	m._story_show(StoryVM.build(_sub.graph, m.board, _sub.pack))

# ---- 子游戏探索序列（tech/02 §6 maze；谜回廊纯解谜房间序列——零战斗，复用 MazeRunner）----

func _sub_maze_pending() -> bool:
	var enc: Dictionary = (_sub.pack.get("encounters", {}) as Dictionary).get(
		str(_sub.current().get("encounter", _sub.graph.current_id)), {})
	var beats: Array = (enc.get("maze", {}) as Dictionary).get("beats", [])
	if beats.is_empty():
		return false
	var enc_id := str(enc.get("id", _sub.graph.current_id))
	return int(m.board.read("%s.maze.%s.idx" % [_sub.pack_id, enc_id], 0)) < beats.size()

func _sub_enter_maze() -> void:
	var enc_id := str(_sub.current().get("encounter", _sub.graph.current_id))
	var enc: Dictionary = (_sub.pack.get("encounters", {}) as Dictionary).get(enc_id, {})
	_sub_maze = MazeRunner.new(m.board, m.stream, m.rng, _sub.pack_id)
	_sub_maze.begin(enc_id, (enc.get("maze", {}) as Dictionary).get("beats", []),
		Callable(_sub.graph, "check_mod"), _sub.graph.current_id)
	_sub_maze_outcome = ""
	_sub_show_maze_beat()

## 呈现当前节拍（与战役 _show_maze_beat 同一呈现口径，数据源自子游戏包）。
func _sub_show_maze_beat() -> void:
	if _sub_maze == null:
		_sub_present()
		return
	var beat := _sub_maze.peek()
	if beat.is_empty(): # 序列完成 → 回节点呈现出边（tech/02 §6）
		_sub_maze = null
		_sub_maze_outcome = ""
		_sub_present()
		return
	var vm := StoryVM.build(_sub.graph, m.board, _sub.pack)
	vm["type"] = "explore"
	vm["title"] = Texts.s(&"MAZE_TITLE") % [str(_sub.current().get("title", _sub.graph.current_id)),
		_sub_maze.beat_index() + 1, _sub_maze.beat_count()]
	vm["text"] = _sub_maze_outcome + str(beat.get("text", ""))
	var label := Texts.s(&"STORY_CONTINUE")
	var btype := str(beat.get("type", ""))
	if btype == "check" or btype == "ambush":
		var skill := str(beat.get("skill", "perception"))
		var diff := str(beat.get("difficulty", "medium"))
		label = Texts.s(&"FMT_CHECK_LABEL") % [Texts.s(&"STORY_CHECK"),
			str(Texts.t(&"SKILL_NAMES").get(skill, skill)), str(Texts.t(&"DIFF_NAMES").get(diff, diff)),
			LightV1.dc_for(diff), _sub.graph.check_mod(skill)]
		if btype == "ambush":
			label = Texts.s(&"MAZE_AMBUSH_PREFIX") + label
	elif btype == "loot":
		label = Texts.s(&"MAZE_LOOT") % [_sub_item_name(str(beat.get("item", ""))), int(beat.get("n", 1))]
	vm["edges"] = [{"type": "choice", "label": label}]
	_ensure_sub_shell()
	m._story_show(vm)

func _sub_item_name(item_id: String) -> String:
	return str((_sub.pack.get("items", {}) as Dictionary).get(item_id, {}).get("name", item_id))

## 推进当前节拍（掷骰/写板在 core）；解谜房失败给提示原地重试（tech/02 §6 retry_on_fail/hint）。
func _on_sub_maze_advance() -> void:
	var res := _sub_maze.resolve()
	if bool(res.get("retry", false)):
		_sub_maze_outcome = "%s %s\n\n" % [Texts.s(&"MAZE_BEAT_FAIL"), str(res.get("hint", ""))]
	elif str(res.get("type", "")) == "loot":
		_sub_maze_outcome = "%s\n\n" % Texts.s(&"MAZE_LOOT") % [_sub_item_name(str(res.get("item", ""))),
			int(res.get("n", 1))]
	else:
		_sub_maze_outcome = (Texts.s(&"MAZE_BEAT_OK") if bool(res.get("success", false)) \
			else Texts.s(&"MAZE_BEAT_FAIL")) + "\n\n"
	await m.get_tree().create_timer(0.8).timeout
	_sub_show_maze_beat()

## 子游戏故事壳：复用双壳场景（09 §8 一局一壳），绑定子游戏包与子游戏回调（与战役通道隔离）。
func _ensure_sub_shell() -> void:
	m._set_window_orientation(_sub_mode) # 子游戏同遵战役级边界（09 §8：整备/叙事/战斗/结算同形态）
	var created := false
	if m.shell == null:
		m.shell = (load(m.SHELL_SCENES[_sub_mode]) as PackedScene).instantiate()
		UITheme.attach(m.shell as Control)
		m.add_child(m.shell)
		m.router.lock_encounter(_sub_mode) # 形态整场锁定（09 §3/§8）
		created = true
	var old: Control = m.current_screen
	m.current_screen = m.shell
	if created and m.transition != null:
		# 入口→子游戏遭遇（壳新建）：转场中场壳现身、旧屏回收（14 #8，与战役同一通道）
		m.shell.visible = false
		var new_shell: Control = m.shell
		m.transition.fade_through(func() -> void:
			if old != null and is_instance_valid(old):
				old.queue_free()
			if is_instance_valid(new_shell):
				new_shell.visible = true)
	else:
		if old != null and old != m.shell:
			old.queue_free()
		m.shell.visible = true
	m.shell.set("on_save_quit", Callable(self, "_on_sub_save_quit"))
	m.shell.bind_story(m.stream, m.board, _sub.pack,
		{"edge": _on_sub_story_edge, "hub": func(_a: String, _b: String) -> void: pass})

func _on_sub_story_edge(idx: int) -> void:
	if _sub_maze != null:
		_on_sub_maze_advance() # 探索序列进行中：选项按钮 = 推进当前节拍（tech/02 §6 maze）
		return
	_sub.take_edge(idx)
	_sub_present()

## 战斗节点：进场一次整备（09 §9.1；连战中途不再整备、HP 不恢复——概念设计 §2 无休整）。
func _sub_enter_battle() -> void:
	m._set_window_orientation(_sub_mode) # 子游戏整备同形态（09 §8）
	var cfg := _sub.loadout_config()
	if not cfg.is_empty() and _sub.run_wins == 0:
		var screen: ScreenLoadout = (load(m.SCREEN_SCENES[&"loadout"]) as PackedScene).instantiate()
		screen.set_form(_sub_mode) # 子游戏整备同形态（09 §8；04 §④.8 横屏专版）
		m._swap(screen)
		screen.bind(cfg, _sub.loadout_candidates())
		screen.confirmed.connect(_on_sub_loadout_confirmed.bind(cfg))
		screen.back_requested.connect(_sub_leave_home) # 整备可退（04 §5 有退路）
		return
	_sub_begin_combat({"skills": [], "items": [], "attr_alloc": {}})

func _on_sub_loadout_confirmed(selection: Dictionary, cfg: Dictionary) -> void:
	Loadout.confirm(m.stream, cfg, selection["skills"], selection["items"],
		selection.get("attr_alloc", {}), _sub.graph.current_id, _sub.pack_id) # loadout.confirm（09 §9.1）
	# 整备分配写板 global.growth.*（tech/04 §8 规则3；与战役整备同一通道）
	var growth := Growth.new(m.board)
	var prov := {"event_id": m.stream.tail(), "node_id": _sub.graph.current_id, "pack_id": _sub.pack_id}
	for attr: String in (selection.get("attr_alloc", {}) as Dictionary).keys():
		for i: int in int((selection["attr_alloc"] as Dictionary)[attr]):
			if not growth.alloc(attr, prov):
				push_warning("[main] 子游戏整备加点被拒（%s，封顶或点数不足，11 §6）" % attr)
	_sub_begin_combat(selection)

func _sub_begin_combat(selection: Dictionary) -> void:
	_sub_battling = true
	_sub_snapshot = SaveSystem.make_snapshot(m.board, m.stream, m.rng, m._bindings(), m._meta()) # ☰ 恢复点（09 §7）
	var sm := EncounterSM.new(m.board, m.stream, m.rng, _sub.pack_id)
	var agent := AutoAgent.new()
	_ensure_sub_shell()
	if m.current_screen != null and m.current_screen != m.shell:
		m.current_screen.queue_free()
	m.current_screen = m.shell
	m.shell.visible = true
	if m.shell is EncounterPortrait:
		(m.shell as EncounterPortrait).bind(sm, agent)
	else:
		(m.shell as EncounterLandscape).bind(sm, agent)
	if m.transition != null:
		m.transition.encounter_enter(m.shell) # 子游戏遭遇进场同一场（14 #8：子游戏复用框架界面，04 §6）
	var nid := _sub.graph.current_id
	sm.enter(nid)
	sm.transition(EncounterSM.S_EXPLORE)
	m.stream.emit(EventTypes.LOG, {"msg": str(_sub.current().get("summary", ""))}, &"core", nid)
	await m.get_tree().create_timer(1.0).timeout
	if sm.state == EncounterSM.S_EXPLORE:
		var def := _sub.battle_def(selection)
		if def.is_empty():
			return # fail-fast：包数据缺陷不进战斗（报错已由 battle_def 输出）
		sm.begin_combat(def)

## 连战收场路由（COMBAT_END 由 _on_event 分发）：胜利 → 写奖励 + 战后边回图（追击/收兵）；
## 败北 → 按已完成场次直接进 ⑨ 结算（失败即分支，概念设计 §2）。
func _sub_on_combat_end(result: StringName) -> void:
	await m.get_tree().create_timer(1.2).timeout
	_sub_battling = false
	if result == &"victory":
		_sub.on_victory() # 每场胜利：金币 + 累计胜场写板（04 §6 写状态板硬要求）
		_ensure_sub_shell()
		m._story_show(StoryVM.build(_sub.graph, m.board, _sub.pack)) # 战后边：追击（无休整）/ 收兵
	else:
		_sub_finish(result)

## ⑨ 结算（04 §6/§9：进出场必经；逐项念给玩家听）→ 结算快照（07 §4.2）→ 回主屏 / ⑧ 卷轴。
func _sub_finish(result: StringName) -> void:
	_sub_battling = false
	var summary := _sub.finish_run(result) # 最佳连战纪录取大写板
	m._save("settle")
	_sub_settle_cache = _sub_settle_lines(summary, result)
	_sub_settle_celebrated = false # 新一场结算：胜利演出恢复首播（04 §④.8）
	_sub_bind_settle()

var _sub_settle_cache: Dictionary = {}

func _sub_settle_lines(summary: Dictionary, result: StringName) -> Dictionary:
	var lines: Array[String] = []
	var xp := 0
	for ev: Dictionary in m.stream.since(_sub_tail):
		var p: Dictionary = ev["payload"]
		match StringName(ev["type"]):
			EventTypes.XP_GAIN:
				xp += int(p.get("amount", 0))
			EventTypes.ITEM_GAIN:
				var iid := str(p.get("item_id", ""))
				lines.append(Texts.s(&"SETTLE_LINE_ITEM_SHARED") % [
					str((_sub.pack.get("items", {}) as Dictionary).get(iid, {}).get("name", iid)),
					int(p.get("count", 1))])
			EventTypes.LORE_UNLOCK:
				var added: Array = p.get("added", [])
				if not added.is_empty():
					lines.append(Texts.s(&"SETTLE_LINE_LORE") % Texts.s(&"LIST_SEP").join(added))
	if xp > 0:
		lines.append(Texts.s(&"SETTLE_LINE_XP") % xp)
	# 效果投放金币（tech/02 §4.6 gold：解谜通关等非战斗奖励）：总量增量 - 连战胜利已报部分
	var gold_now := int(m.board.read("%s.gold" % _sub.pack_id, 0))
	var gold_fx := gold_now - _sub_gold0 - int(summary["gold"])
	if gold_fx != 0:
		lines.append(Texts.s(&"SETTLE_LINE_GOLD_DELTA") % [gold_fx, gold_now])
	if int(summary["gold"]) > 0:
		lines.append(Texts.s(&"SETTLE_LINE_GOLD") % [int(summary["gold"]),
			int(m.board.read("%s.gold" % _sub.pack_id, 0))])
	lines.append(Texts.s(&"SETTLE_LINE_RECORD") % [int(summary["wins"]),
		int((_sub.stats() as Dictionary)["wins"]), int(summary["best"])])
	if bool(summary["flawless"]):
		lines.append(Texts.s(&"SETTLE_LINE_FLAWLESS"))
	return {"title": "%s · %s" % [str((_sub.pack["manifest"] as Dictionary).get("name", _sub.pack_id)),
			str(_sub.current().get("title", Texts.s(&"SETTLE_SUB_TITLE")))],
		"result": String(result), "lines": lines, "saved": true,
		# 成长簿记归框架全局键（tech/04 §8）：子游戏结算屏同口径呈现与分配
		"attr_points": Growth.attr_points(m.board), "attrs": Growth.attrs_map(m.board)}

func _sub_bind_settle() -> void:
	m._set_window_orientation(_sub_mode) # 子游戏结算同形态（09 §8）
	var screen: ScreenSettle = (load(m.SCREEN_SCENES[&"settle"]) as PackedScene).instantiate()
	screen.set_form(_sub_mode) # 子游戏结算横屏专版（04 §④.8/§6：子游戏复用框架界面）
	m._swap(screen)
	var sub_summary := _sub_settle_cache.duplicate()
	sub_summary["celebrate"] = not _sub_settle_celebrated # 胜利演出首播；加点刷新重绑不重播
	_sub_settle_celebrated = true
	screen.bind(sub_summary)
	# 子游戏结算屏同接成长分配（tech/04 §8 规则3：结算屏分配；概念设计 §8 待裁决 3 随全局簿记结构消解）
	screen.allocate.connect(func(attr: String) -> void:
		if Growth.new(m.board).alloc(attr, {"event_id": m.stream.tail(),
				"node_id": _sub.graph.current_id, "pack_id": _sub.pack_id}):
			_sub_settle_cache["attr_points"] = Growth.attr_points(m.board)
			_sub_settle_cache["attrs"] = Growth.attrs_map(m.board)
			_sub_bind_settle()) # 刷新可用点数与已分配值
	screen.go_home.connect(_sub_leave_home)
	screen.go_history.connect(func() -> void:
		m._history_origin = &"sub_settle"
		m._show_history())

## ☰「保存并回主屏」（09 §7）：战斗中 = 恢复本场进入前快照（本场重打，不存档）；故事态 = 落档回主屏。
func _on_sub_save_quit() -> void:
	if _sub_battling:
		SaveSystem.apply(_sub_snapshot, m.board, m.rng)
		m.stream.emit(EventTypes.LOG, {"msg_key": "MSG_REWIND_SUB"}, &"core")
	m._save("quit_home")
	_sub_leave_home()

func _sub_leave_home() -> void:
	_sub_active = false
	_sub_battling = false
	_sub_maze = null
	_sub = null
	m._show_home()

# ---------------------------------------------------------------- 存档（07 §4）
