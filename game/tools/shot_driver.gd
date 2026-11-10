# 截图/演示驱动（开发工具，不进正式构建）：原 main.gd 内 `_run_shots_*`，按代码评审 M2 迁出。
# 用法：godot --path game -- --<flag>（如 --home-shot / --m4-shots / --trans-shots …）；
# main.gd 仅在命令行带截图旗标时动态加载本脚本——导出时排除 tools/ 即不随包发布。
# 驱动通过 `m`（main 实例）调用其流程方法，截图写 /tmp（不提交）。
extends RefCounted

const FLAGS := {
	"--m2n-shots": "_run_shots_m2n", "--m3-shots": "_run_shots_m3", "--m4-shots": "_run_shots_m4",
	"--skin-shots": "_run_shots_skin", "--m4c-shots": "_run_shots_m4c", "--growth-shots": "_run_shots_growth",
	"--act2-shots": "_run_shots_act2", "--act3-shots": "_run_shots_act3", "--gap-shots": "_run_shots_gap",
	"--home-shot": "_run_shot_home", "--home-bar-shot": "_run_shot_home_bar", "--promo-shot": "_run_shot_promo",
	"--mode-shots": "_run_shots_mode", "--ls-shots": "_run_shots_ls", "--text-shots": "_run_shots_text",
	"--font-shot": "_run_shot_font", "--trans-shots": "_run_shots_trans", "--lock-shot": "_run_shot_lock",
	"--loadout-shots": "_run_shots_loadout", "--dice-shots": "_run_shots_dice",
}
const SHOT_SEED := 20260009 # 固定种子：截图路径确定（主线两次检定均为成功路）

var m: Node

func _init(main: Node) -> void:
	m = main

static func wanted(args: PackedStringArray) -> bool:
	for a: String in args:
		if FLAGS.has(a):
			return true
	return false

func run(args: PackedStringArray) -> void:
	for a: String in args:
		if FLAGS.has(a):
			call(FLAGS[a])

# ---------------------------------------------------------------- 转场与镜头截图（14 清单 #8 证据 /tmp/trans_*.png，不提交）

## `-- --trans-shots`：主屏→入口淡出中间帧（幕布半掩）+ 竖屏遭遇战斗跟随对焦帧。
func _run_shots_trans() -> void:
	await m.get_tree().create_timer(0.8).timeout
	if m.current_screen is ScreenHome:
		(m.current_screen as ScreenHome).tutorial.finish_launch() # 跳过启动卡取干净画面
		m._tutorial_mark("combat") # 首次战斗情境提示不遮对焦帧（12 §4 一次原则）
		await m.get_tree().create_timer(0.2).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.12).timeout # 淡出进行中（0.25s 半程）
	await _shot_raw("/tmp/trans_mid.png") # 转场中间帧：幕布半掩、旧屏仍可点（14 #8）
	await m.get_tree().create_timer(0.6).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_TIME)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.6).timeout
	m.graph._enter("N1-7") # 战斗节点 → 竖屏整备（截图证据，不走完整前置链）
	m._present_node()
	await m.get_tree().create_timer(0.6).timeout
	(m.current_screen as ScreenLoadout)._on_confirm()
	await m.get_tree().create_timer(1.8).timeout # 进场滑入 0.5s + 探索演出 1.0s + 对焦 0.35s
	# 对焦帧：发焦点事件指向上排敌方（截图证据专用，与战斗内对焦同一事件源/管线）
	m.stream.emit(EventTypes.TURN_START, {"round": 1, "side": "party",
		"actor": "boss"}, &"core", "N1-7")
	await m.get_tree().create_timer(BattleCamera.FOCUS_TIME + 0.1).timeout # 推移落定
	await _shot("/tmp/trans_focus.png") # 对焦帧：lane 滚动对焦当前行动单位（04 §④.4 智能镜头）
	print("[shots] 转场与镜头两张完成：/tmp/trans_mid.png /tmp/trans_focus.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 截图模式（节点流程证据 /tmp，不提交）

## 竖屏：scene/check/hub/dialog 四张；横屏（--mode=space）：叙事态一张。
func _run_shots_m2n() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_SPACE if m._cli_mode == ShellRouter.MODE_SPACE else ShellRouter.MODE_TIME)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	if m.campaign._mode == ShellRouter.MODE_SPACE:
		await _shot("/tmp/m2n_landscape_story.png") # 横屏叙事态（N0-1，04 §③ 中央主视野）
		print("[shots] 横屏叙事态完成")
		m.get_tree().quit()
		return
	await _shot("/tmp/m2n_scene.png") # N0-1 scene
	m._on_story_edge(0) # → N0-2 检定房
	m.board.write("%s.inspiration" % m._campaign_id, 1,
		{"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id}) # 激励入口演示（11 §3.2）
	m.campaign._present_node()
	await m.get_tree().create_timer(0.3).timeout
	if (m.shell as EncounterPortrait).tutorial.is_hint_visible():
		(m.shell as EncounterPortrait).tutorial._dismiss_hint() # 截图看操作台本体
	await m.get_tree().create_timer(0.2).timeout
	await _shot("/tmp/m2n_check.png")
	m._on_story_edge(0) # 掷检定（截图种子成功路）
	await m.get_tree().create_timer(1.2).timeout # 快掷落定 + 节点呈现
	m._on_story_edge(0) # N0-3a → N0-4
	await m.get_tree().create_timer(0.3).timeout
	m._on_story_edge(0) # N0-4 → N1-1 hub
	await m.get_tree().create_timer(0.3).timeout
	(m.shell as EncounterPortrait).hub_popup.open(m.graph.get_gold(), m.graph.hub_stock(),
		m.graph.party_status()) # 商店半屏弹层（04 §3.3）
	await m.get_tree().create_timer(0.3).timeout
	await _shot("/tmp/m2n_hub.png")
	(m.shell as EncounterPortrait).hub_popup.hide()
	# 营地弹层（11 §7.2：短休/长休/补给）——伤员一名演示短休入口
	m.board.write("%s.hp.player_blank" % m._campaign_id, 6,
		{"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id})
	(m.shell as EncounterPortrait).hub_popup.open(m.graph.get_gold(), m.graph.hub_stock(),
		m.graph.party_status(), HubPopup.MODE_CAMP)
	await m.get_tree().create_timer(0.3).timeout
	await _shot("/tmp/m2n_camp.png")
	(m.shell as EncounterPortrait).hub_popup.hide()
	m.graph.hub_rest()
	# N1-1 → 前往褪色现场 N1-2（按文案找边：购买边数量随货单变化）
	var edges: Array = m.graph.available_edges()
	for i: int in edges.size():
		if str((edges[i] as Dictionary).get("label", "")).contains("褪色现场"):
			m._on_story_edge(i)
			break
	await m.get_tree().create_timer(0.3).timeout
	m._on_story_edge(0) # N1-2 掷检定（成功 → N1-3）
	await m.get_tree().create_timer(1.2).timeout
	m._on_story_edge(0) # N1-3 → 接触誊写庭 N1-4
	await m.get_tree().create_timer(0.3).timeout
	await _shot("/tmp/m2n_dialog.png")
	print("[shots] 竖屏四张完成：scene/check/hub/dialog")
	m.get_tree().quit()

func _shot(path: String) -> void:
	if m.transition != null:
		m.transition.skip_all() # 证据帧取转场完成态（14 #8；转场中间帧另由 _shot_raw 取）
	await RenderingServer.frame_post_draw
	var err: int = m.get_viewport().get_texture().get_image().save_png(path)
	print("[shots] ", path, " err=", err)

## 原始帧（不结算转场）：转场中间帧证据专用。
func _shot_raw(path: String) -> void:
	await RenderingServer.frame_post_draw
	var err: int = m.get_viewport().get_texture().get_image().save_png(path)
	print("[shots] ", path, " err=", err)

# ---------------------------------------------------------------- 长文本截图（tech/02 §1.1 text_ref 外置全文呈现证据 /tmp，不提交）

## 竖屏故事态节点全文（N0-1，text_ref → texts/zh-CN.json）+ 结局屏 E1 演出全文：`-- --text-shots`。
func _run_shots_text() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_TIME)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	await _shot("/tmp/text_story.png") # 故事态：节点呈现文本 = text_ref 外置全文（§3 解析顺序）
	# 结局屏：真实 ScreenEnding + 真实 text_ref 解析链（§9/§1.1；夹具直绑，不走通关路径）
	var edef := {}
	for e: Variant in m.pack.get("endings", []):
		if str((e as Dictionary).get("id", "")) == "E1":
			edef = e
	var screen: ScreenEnding = (load(m.SCREEN_SCENES[&"ending"]) as PackedScene).instantiate()
	m._swap(screen)
	screen.bind({"ending_id": "E1", "title": str(edef.get("title", "E1")),
		"content": StoryVM.ending_text(m.pack.get("texts", {}), edef),
		"hook": str(edef.get("ngplus_hook", "")), "playthrough": 1, "saved": true})
	await m.get_tree().create_timer(0.4).timeout
	await _shot("/tmp/text_ending.png") # 结局屏：E1 演出全文 3~5 句（content 摘要兜底不外显）
	print("[shots] 长文本两屏完成：/tmp/text_story.png /tmp/text_ending.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 字体修复证据截图（/tmp，不提交）

## `-- --font-shot`：竖屏整备 → 套用「稳守」预设卡 → /tmp/font_fixed.png（曾现 CJK 豆腐块的界面）。
func _run_shot_font() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_TIME)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	m.graph._enter("N1-7") # 战斗节点 → 竖屏整备（预设卡 = 右列，09 §9.3）
	m._present_node()
	await m.get_tree().create_timer(0.5).timeout
	var lo := m.current_screen as ScreenLoadout
	for b: Node in lo.preset_box.get_children(): # 按文案找预设，不假设顺序
		if (b as Button).text.contains("稳守"):
			(b as Button).pressed.emit()
			break
	await m.get_tree().create_timer(0.3).timeout
	await _shot("/tmp/font_fixed.png")
	print("[shots] 字体修复证据：/tmp/font_fixed.png（整备·稳守预设卡）")
	m.get_tree().quit()

# ---------------------------------------------------------------- 成长截图（角色界面⑦成长区证据 /tmp，不提交）

## ⑦ 角色：汇入 350 XP（跨 300 档升 Lv.2）+ 力 +1 后的成长区呈现：`-- --growth-shots`。
func _run_shots_growth() -> void:
	await m.get_tree().create_timer(0.8).timeout
	var prov := {"event_id": m.stream.tail(), "node_id": "", "pack_id": "campaign01"}
	var growth := Growth.new(m.board)
	growth.grant_xp(350, prov) # tech/04 §8 规则1/2：汇入即写 global.growth.xp，跨档自动升级
	growth.alloc("might", prov) # 规则3：属性点分配
	m.campaign._encounter_id = "N1-7" # ⑦ 队伍卡数据源需要一场已登记遭遇（tech/02 §6）
	m._show_character()
	await m.get_tree().create_timer(0.4).timeout
	await _shot("/tmp/growth_char.png")
	print("[shots] 角色界面成长区完成：/tmp/growth_char.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- M3 截图（子游戏证据 /tmp，不提交）

## ② 入口卡 + 连战第一场（竖屏）：`-- --m3-shots`。
func _run_shots_m3() -> void:
	await m.get_tree().create_timer(1.2).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	await _shot("/tmp/m3_entry.png") # ② 战役入口：子游戏特殊战役书卡（04 §6）
	if m._subgames.is_empty():
		print("[shots] 无子游戏包，跳过连战截图")
		m.get_tree().quit()
		return
	var pid := str((m._subgames.keys() as Array)[0])
	m.entitlements.shop_purchase(pid, "rcpt_m3_shots") # M3 截图前提：权利已点亮（M4 起 arena 有门槛）
	m._on_subgame_start(pid, ShellRouter.MODE_TIME)
	await m.get_tree().create_timer(0.4).timeout
	m._on_sub_story_edge(0) # A-0 → 踏入擂台
	await m.get_tree().create_timer(0.4).timeout
	var lo := m.current_screen as ScreenLoadout
	if lo != null:
		lo._on_confirm() # 空选择 = BattleDef 缺省出战（与战役引导同一兜底）
		await m.get_tree().create_timer(2.0).timeout # 探索演出 1s + 战斗铺开
	await _shot("/tmp/m3_battle.png") # 连战第一场（无休整，HP 持久 11 §7.1）
	print("[shots] M3 两张完成：/tmp/m3_entry.png /tmp/m3_battle.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 幕二截图（护送战/迷宫序列/撕页抉择证据 /tmp，不提交）

## `-- --act2-shots`：传送至幕二节点（仅截图证据，不走完整流程）——
## 护送战 N2S-2（缮写士入队）、雾码头探索序列 N2G-2（伏击拍）、撕页行动战后抉择 N2U-2。
func _run_shots_act2() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_TIME)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	# 1) 护送战：整备 → 遭遇（缮写士以 escort_npc 入队，tech/02 §6 escort 块）
	m.graph._enter("N2S-2")
	m._present_node()
	await m.get_tree().create_timer(0.3).timeout
	(m.current_screen as ScreenLoadout)._on_confirm()
	await m.get_tree().create_timer(1.8).timeout
	await _shot("/tmp/act2_escort.png")
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 3}, &"core", "N2S-2")
	await m.get_tree().create_timer(1.6).timeout
	# 2) 迷宫探索序列：N2G-2 第 1 拍检定 → 推进 → 第 2 拍伏击判定
	m.graph._enter("N2G-2")
	m.campaign._maze = null
	m._present_node()
	await m.get_tree().create_timer(0.4).timeout
	m._on_story_edge(0) # 第 1 拍（检定）
	await m.get_tree().create_timer(1.2).timeout
	await _shot("/tmp/act2_maze.png") # 第 2 拍：伏击判定呈现
	# 3) 撕页行动：战斗 → 模拟胜利 → 战后抉择（撕/不撕双出边，tech/02 §6 hybrid）
	m.graph._enter("N2U-2")
	m.campaign._maze = null
	m._present_node()
	await m.get_tree().create_timer(0.3).timeout
	(m.current_screen as ScreenLoadout)._on_confirm()
	await m.get_tree().create_timer(1.8).timeout
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 2}, &"core", "N2U-2")
	await m.get_tree().create_timer(1.8).timeout
	await _shot("/tmp/act2_hybrid.png")
	print("[shots] 幕二三张完成：/tmp/act2_escort.png /tmp/act2_maze.png /tmp/act2_hybrid.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 幕三/终章截图（模式锁定演出 / 分支门 / 结局屏证据 /tmp，不提交）

## `-- --act3-shots`：横屏玩家路径——N2-C → N3-1 强制切竖屏壳（叙事化提示 toast，09 §3）→
## R4 分支门（[物·黑羽令] 左路捷径 / fallback 右路，tech/02 §4.3）→ E3 结局屏（tech/02 §9）。
func _run_shots_act3() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_SPACE) # 横屏玩家路径（强制幕换壳证据）
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	m.graph._enter("N2-C") # 横屏故事态就位（SL-2 随玩家所选形态）
	m._present_node()
	await m.get_tree().create_timer(0.4).timeout
	m._on_story_edge(0) # N2-C → N3-1：强制切竖屏 + 模式锁定叙事化提示
	await m.get_tree().create_timer(0.5).timeout
	await _shot("/tmp/act3_mode_lock.png")
	m.graph._enter("R4") # 分叉回廊分支门
	m._present_node()
	await m.get_tree().create_timer(0.4).timeout
	await _shot("/tmp/act3_branch_gate.png")
	m.graph._enter("E3") # 结局屏：四分型文案 + 多周目钩子（endings.json）
	m._present_node()
	await m.get_tree().create_timer(0.5).timeout
	await _shot("/tmp/act3_ending.png")
	print("[shots] 幕三/终章三张完成：/tmp/act3_mode_lock.png /tmp/act3_branch_gate.png /tmp/act3_ending.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 缺口批截图（手势/教程/图鉴证据 /tmp/gap_*.png，不提交）

## `-- --gap-shots`：启动卡（12 §4 第一层）→ 帮助页手势图鉴全表（12 §4 第三层）→ ⑥ 图鉴页（四系列进度）。
func _run_shots_gap() -> void:
	await m.get_tree().create_timer(1.0).timeout
	await _shot("/tmp/gap_tutorial.png") # 首次启动：3 页核心手势卡（可跳过）
	if m.current_screen is ScreenHome:
		var home := m.current_screen as ScreenHome
		home.tutorial.finish_launch()
		await m.get_tree().create_timer(0.2).timeout
		home._toggle_help()
		await m.get_tree().create_timer(0.3).timeout
		await _shot("/tmp/gap_help.png") # 帮助页：手势图鉴全表 + 重学入口
		home._toggle_help()
	# 图鉴页：注入两枚残简演示系列进度（仅截图证据，不写板正规流程——截图后即退出进程）
	m.board.unlock_lore("weaver_fragment_01",
		{"event_id": m.stream.tail(), "node_id": "", "pack_id": "campaign01"})
	m.board.give_item("codex_fragment", 1,
		{"event_id": m.stream.tail(), "node_id": "", "pack_id": "campaign01"})
	m._on_home_navigate(&"inventory")
	await m.get_tree().create_timer(0.4).timeout
	await _shot("/tmp/gap_codex.png") # ⑥ 图鉴页：四系列进度 + 集齐奖励预告
	print("[shots] 缺口批三张完成：/tmp/gap_tutorial.png /tmp/gap_help.png /tmp/gap_codex.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 主屏热点图截图（12 §5 证据 /tmp，不提交）

## `-- --home-shot`：主屏可交互绘卷（烬港夜景程序化占位 + 五热点微光 + 底部兜底条）。
func _run_shot_home() -> void:
	await m.get_tree().create_timer(1.0).timeout
	if m.current_screen is ScreenHome:
		var home := m.current_screen as ScreenHome
		if home.tutorial != null:
			home.tutorial.finish_launch() # 跳过启动卡，取干净绘卷
		await m.get_tree().create_timer(0.6).timeout # 呼吸微光推进到非零相位
	await _shot("/tmp/home_hotspot.png")
	print("[shots] 主屏热点图完成：/tmp/home_hotspot.png")
	m.get_tree().quit()

## 章节锁定页（06 §3.1/§7）：`-- --market=global --lock-shot`——幕二入口锁定页 + 购买弹层。
func _run_shot_lock() -> void:
	await m.get_tree().create_timer(1.0).timeout
	ProjectSettings.set_setting("game/market", "global")
	m.board.write("global.entitlement.campaign01_full", false, {"event_id": m.stream.tail(), "node_id": "", "pack_id": "system"})
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.4).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_TIME)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	m.graph._enter("N2S-1")
	m._present_node()
	await m.get_tree().create_timer(0.6).timeout
	await _shot("/tmp/lock_chapter.png")
	(m.current_screen as ScreenLocked).get_button.pressed.emit()
	await m.get_tree().create_timer(0.4).timeout
	await _shot("/tmp/lock_shop.png")
	print("[shots] 章节锁定两张完成：/tmp/lock_chapter.png /tmp/lock_shop.png")
	m.get_tree().quit()

## 主屏兜底条收起态（12 §5：toggle 可收起，收起为细条把手，绘卷占满）：`-- --home-bar-shot`（/tmp 不提交）。
func _run_shot_home_bar() -> void:
	await m.get_tree().create_timer(1.0).timeout
	if m.current_screen is ScreenHome:
		var home := m.current_screen as ScreenHome
		if home.tutorial != null:
			home.tutorial.finish_launch() # 跳过启动卡，取干净绘卷
		home.set_bar_collapsed(true, false) # 截图态不落盘（不写 user://settings.cfg）
		await m.get_tree().create_timer(0.6).timeout # 呼吸微光推进到非零相位
	await _shot("/tmp/home_bar_collapsed.png")
	print("[shots] 主屏兜底条收起态完成：/tmp/home_bar_collapsed.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- M4 截图（锁定态 + 购买弹层证据 /tmp，不提交）

## ② 入口锁定态卡（06 §3.1：可见但锁定 + 叙事化包装）+ 购买半屏弹层（04 §3.3）：`-- --m4-shots`。
func _run_shots_m4() -> void:
	await m.get_tree().create_timer(1.2).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.4).timeout
	await _shot("/tmp/m4_lock.png") # 锁定态战役书卡（战绩照常呈现 + 守门人文案 +「获取」）
	m._on_acquire_requested("arena")
	await m.get_tree().create_timer(0.4).timeout
	await _shot("/tmp/m4_shop.png") # 购买半屏弹层（06 §6：不离开当前界面情境）
	print("[shots] M4 两张完成：/tmp/m4_lock.png /tmp/m4_shop.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 外观商品截图（06 §7 皮肤证据 /tmp，不提交）

## ⑥ 外观页 + 换肤骰子：`-- --skin-shots`。演示前提两款皮肤到账（集齐/商店同一写板通道）。
func _run_shots_skin() -> void:
	await m.get_tree().create_timer(1.2).timeout
	m.cosmetics.grant("faded_ink_gray", {"granted_by": "codex", "series": "fatedie_study"}) # 命骰考集齐奖励（10 §4）
	m.cosmetics.shop_purchase("salvage_copper", "rcpt_skin_shots") # 商店外观商品（06 §7）
	m._on_home_navigate(&"inventory")
	await m.get_tree().create_timer(0.4).timeout
	await _shot("/tmp/skin_cosmetics.png") # 外观页：三皮肤 + 预览色块 + 装备/卸下/获取
	# 换肤骰子：装备拾遗铜辉 → 战役故事态 → 快掷演出取当前皮肤配色与描边（纯呈现）
	m.cosmetics.equip("salvage_copper")
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_TIME)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	m.graph._enter("N1-3")
	m._present_node()
	await m.get_tree().create_timer(0.5).timeout
	m.stream.emit(EventTypes.CHECK_ROLL, {"keep": 17, "rolls": [17], "mod": 0, "total": 17,
		"success": true, "key": false}, &"core", "N1-3") # 常驻骰子条即呈现位（04 §④.5 v2）
	await m.get_tree().create_timer(0.8).timeout # 快掷 0.35s 落定后取图
	await _shot("/tmp/skin_dice.png")
	print("[shots] 皮肤两张完成：/tmp/skin_cosmetics.png /tmp/skin_dice.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- M4 截图（支线注入边 + 解谜房证据 /tmp，不提交）

## 支线入口边（N1-1 持潮汐表 → graft 注入边显形，tech/02 §2.6）+ 谜回廊解谜房（tech/02 §6 maze）。
func _run_shots_m4c() -> void:
	await m.get_tree().create_timer(1.2).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_TIME)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	# 支线入口边：注入在合并视图，宿主包数据不动（§2.6）
	m.graph._enter("N1-1")
	m.board.give_item("half_tide_table", 1,
		{"event_id": m.stream.tail(), "node_id": "N1-1", "pack_id": "campaign01"})
	m._present_node()
	await m.get_tree().create_timer(0.5).timeout
	if DisplayServer.get_name() != "headless":
		m.get_window().size = Vector2i(960, 760) # 加宽窗口：N1-1 四条出边（含支线注入边）同屏可见
		m.get_window().move_to_center()
		await m.get_tree().create_timer(0.3).timeout
	await _shot("/tmp/m4_graft_edge.png")
	# 谜回廊解谜房：R-0 → R-1 探索序列第 1 拍（失败给提示重来，tech/02 §6 retry_on_fail）
	m._on_subgame_start("riddle_maze", ShellRouter.MODE_TIME)
	await m.get_tree().create_timer(0.4).timeout
	m._on_sub_story_edge(0)
	await m.get_tree().create_timer(0.6).timeout
	await _shot("/tmp/m4_riddle.png")
	print("[shots] M4c 两张完成：/tmp/m4_graft_edge.png /tmp/m4_riddle.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 战役级横竖屏边界截图（09 §8 证据 /tmp，不提交）

## `-- --mode-shots`：横屏战役——跳过 SL-0 强制竖屏段，落 SL-1 横屏叙事态 → N1-7 整备（横屏）→ 横屏战斗态。
func _run_shots_mode() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_SPACE)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	m.graph._enter("N1-4") # SL-1：横屏叙事态（09 §8：开始战役即切横屏窗口+横屏壳）
	m._present_node()
	await m.get_tree().create_timer(0.6).timeout
	await _shot("/tmp/mode_story.png")
	m.graph._enter("N1-7") # 战斗节点 → 整备（横屏布局）→ 遭遇
	m._present_node()
	await m.get_tree().create_timer(0.4).timeout
	(m.current_screen as ScreenLoadout)._on_confirm()
	await m.get_tree().create_timer(2.2).timeout # 探索演出 1s + 战斗铺开
	await _shot("/tmp/mode_battle.png")
	print("[shots] 战役级横竖屏边界两张完成：/tmp/mode_story.png /tmp/mode_battle.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 横屏专版截图（04 §④.8 整备/结算布局证据 /tmp，不提交）

## `-- --ls-shots`：横屏战役 → 整备三段横列（预设卡套用）→ 战斗 → 胜利结算（横幅横铺 → 收拢双区）。
func _run_shots_ls() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_SPACE)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	_give_gear()
	m.graph._enter("N1-7") # 战斗节点 → 横屏整备（04 §④.8：三段横列 + 队伍状态条置顶）
	m._present_node()
	await m.get_tree().create_timer(0.5).timeout
	var lo := m.current_screen as ScreenLoadout
	(lo.preset_box.get_child(0) as Button).pressed.emit() # 一键套用「强攻」（09 §9.3）
	await m.get_tree().create_timer(0.3).timeout
	await _shot("/tmp/ls_loadout.png")
	lo._on_confirm()
	await m.get_tree().create_timer(2.2).timeout # 探索演出 1s + 战斗铺开
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 3}, &"core", m.graph.current_id)
	await m.get_tree().create_timer(1.5).timeout # 结算 1.2s 后出现，胜利横幅横铺中央（04 §④.8）
	await _shot("/tmp/ls_settle.png")
	await m.get_tree().create_timer(1.3).timeout # 横幅收拢 → 双区 + 下一遭遇出口（04 §⑨）
	await _shot("/tmp/ls_settle_next.png")
	print("[shots] 横屏专版三张完成：/tmp/ls_loadout.png /tmp/ls_settle.png /tmp/ls_settle_next.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 主屏运营位截图（06 §6 home_promo 投放证据 /tmp，不提交）

## `-- --promo-shot`：主屏运营位（配置驱动文案）→ 点按直达 arena 锁定卡 + 购买弹层。
func _run_shot_promo() -> void:
	await m.get_tree().create_timer(1.2).timeout
	if m.current_screen is ScreenHome:
		var home := m.current_screen as ScreenHome
		if home.tutorial != null:
			home.tutorial.finish_launch() # 跳过启动卡，取干净绘卷
		await m.get_tree().create_timer(0.4).timeout
		await _shot("/tmp/m2_promo.png") # 主屏运营位：home_promo 文案呈现（06 §6）
		home.promo_button.pressed.emit() # 点按 → arena 锁定卡 + 直达购买弹层
		await m.get_tree().create_timer(0.5).timeout
		await _shot("/tmp/m2_promo_entry.png") # 路由落点证据（锁定卡 + 购买弹层）
	print("[shots] 运营位两张完成：/tmp/m2_promo.png /tmp/m2_promo_entry.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 整备 v2 截图（09 §9.1 v2 逐角色整备证据 /tmp，不提交）

func _give_gear() -> void:
	var prov := {"event_id": m.stream.tail(), "node_id": m.graph.current_id, "pack_id": m._campaign_id}
	for iid: String in ["boathook_axe", "padded_coat", "tide_charm", "dock_buckler"]:
		m.board.give_item(iid, 1, prov)
	m.board.give_item("ink_flask", 2, prov)

## `-- --loadout-shots`：竖屏整备——装备页签（斧交给珂兰）+ 技能页签。
func _run_shots_loadout() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_TIME)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	_give_gear()
	m.graph._enter("N1-7")
	m._present_node()
	await m.get_tree().create_timer(0.5).timeout
	var lo := m.current_screen as ScreenLoadout
	lo.tap_library(ScreenLoadout.LIB_GEAR, "padded_coat")
	lo.drop_on_character("companion_kelan", {"kind": "gear", "id": "boathook_axe"})
	lo.set_library_tab(ScreenLoadout.LIB_GEAR)
	await m.get_tree().create_timer(0.3).timeout
	await _shot("/tmp/lo_gear.png")
	lo.select_character("player_blank")
	lo.set_library_tab(ScreenLoadout.LIB_SKILLS)
	lo.tap_library(ScreenLoadout.LIB_SKILLS, "inkbolt")
	await m.get_tree().create_timer(0.3).timeout
	await _shot("/tmp/lo_skills.png")
	lo.set_library_tab(ScreenLoadout.LIB_ITEMS)
	lo.tap_library(ScreenLoadout.LIB_ITEMS, "heal_potion")
	lo._on_confirm()
	await m.get_tree().create_timer(2.4).timeout
	var sh := m.shell as EncounterPortrait
	if sh != null:
		sh.pack_open = true
		sh._refresh_quickbar()
	await m.get_tree().create_timer(0.3).timeout
	await _shot("/tmp/lo_battle_pack.png")
	print("[shots] 整备 v2 三张：/tmp/lo_gear.png /tmp/lo_skills.png /tmp/lo_battle_pack.png")
	m.get_tree().quit()

# ---------------------------------------------------------------- 多面骰托盘截图（17 §3 证据 /tmp，不提交）

## `-- --dice-shots`：竖屏实战——托管打到第一次命中，伤害骰托盘落定时截图（骰子条同时换骰型图标）。
func _run_shots_dice() -> void:
	await m.get_tree().create_timer(0.8).timeout
	m._on_home_navigate(&"entry")
	await m.get_tree().create_timer(0.3).timeout
	var entry := m.current_screen as ScreenEntry
	entry.pick_mode(ShellRouter.MODE_TIME)
	entry.start_requested.emit()
	await m.get_tree().create_timer(0.5).timeout
	m.graph._enter("N1-7")
	m._present_node()
	await m.get_tree().create_timer(0.5).timeout
	(m.current_screen as ScreenLoadout)._on_confirm()
	await m.get_tree().create_timer(2.4).timeout
	var sh := m.shell as EncounterPortrait
	if sh.tutorial.is_hint_visible():
		sh.tutorial._dismiss_hint()
	var guard := 0
	while sh.dice_tray.played == 0 and guard < 80 and not sh.sm.is_over():
		guard += 1
		sh.debug_step_auto()
		await m.get_tree().create_timer(0.05).timeout
	while sh.dice_tray.dice3d.is_playing():
		await m.get_tree().process_frame
	await m.get_tree().create_timer(0.15).timeout
	await _shot("/tmp/dice_tray_battle.png")
	print("[shots] 托盘：/tmp/dice_tray_battle.png played=", sh.dice_tray.played, " glyph=", sh.dice_glyph.die)
	m.get_tree().quit()
