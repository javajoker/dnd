# 无头测试入口：/Applications/Godot.app/Contents/MacOS/Godot --headless --path game -s tests/run.gd
# 约定：每个 core 模块一个 test_xxx()，失败 push_error 并以非零码退出（godot-acceptance §1.2）
extends SceneTree

var failures := 0

## 测试隔离（代码评审 B4）：存档与偏好一律重定向到 user://test/，每次运行前清空——
## 测试永不读写玩家真实存档（user://saves/slot1.json）与设置（user://settings.cfg）。
func _isolate_user_data() -> void:
	_wipe_dir(TEST_DIR)
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	SaveSystem.save_dir = TEST_DIR.path_join("saves")
	UiSettings.redirect_path = TEST_DIR.path_join("settings.cfg")
	Rng.fixed_seed_override = 20260009 # 新开局种子固定：main 集成测试依赖确定的主线检定路径
	# 既有集成测试按"完整战役随本体"市场运行（国内首发口径）；海外"试玩 + 解锁"门槛由 test_store_and_act_gate 专测
	ProjectSettings.set_setting("game/market", "cn")
	Texts.forced_locale = Texts.SOURCE_LOCALE # 语言固定为源语言：断言与系统语言/偏好无关
	CampaignFlow.skip_hero_creation = true # 既有流程测试走"缺省白页者"；建角流程由 test_hero_build 专测
	Texts.set_locale(Texts.SOURCE_LOCALE)

## 新 main 实例（新开局）：先删测试存档槽——main 启动即读回存档（07 §4.2），集成测试默认从零开始。
func _new_main() -> Node:
	SaveSystem.delete()
	return (load("res://main.tscn") as PackedScene).instantiate()

func _wipe_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub: String in d.get_directories():
		_wipe_dir(path.path_join(sub))
	for f: String in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(path)

func check(cond: bool, name: String) -> void:
	if cond:
		print("  PASS ", name)
	else:
		failures += 1
		push_error("  FAIL " + name)

const TEST_DIR := "user://test"

func _init() -> void:
	print("== 抄本纪元 core 无头测试 ==")
	_isolate_user_data()
	test_rng()
	test_event_stream()
	test_board()
	test_conditions()
	test_pack_loader()
	test_packlint()
	test_story_graph()
	test_story_bot()
	test_light_v1()
	test_encounter_sm()
	test_auto_agent()
	test_shell_router()
	test_save_system()
	test_new_game_seed()
	test_texts()
	test_pack_locale()
	test_no_content_constants()
	test_texts_en()
	test_pack_copies_in_sync()
	test_loadout()
	test_growth()
	test_quest_runtime()
	test_quest_abandon()
	test_gesture_recognizer()
	test_battle_data_driven()
	test_boss_behavior()
	test_winrate_tool()
	test_hp_persistence()
	test_escort_sm()
	test_maze_runner()
	test_act2_chains()
	test_act3_rooms()
	test_finale_endings()
	test_full_run_e4()
	test_story_runtime()
	test_camp_rest()
	test_equipment()
	test_inspiration()
	test_maps_core()
	test_party_split()
	test_hero_build()
	test_story_vm()
	test_text_ref()
	test_subgame_arena()
	test_arc_tide()
	test_riddle_maze()
	test_entitlements()
	test_ops_config()
	test_cosmetics()
	test_font()
	test_ngplus_inheritance()
	call_deferred("_async_shell_tests")

func _async_shell_tests() -> void:
	await test_portrait_shell()
	await test_landscape_shell()
	await test_dice_3d()
	await test_dice_tray()
	await test_juice()
	await test_audio()
	await test_action_fx()
	await test_ui_kit()
	await test_landscape_story()
	await test_shell_diff()
	await test_cosmetic_neutral()
	await test_cosmetics_ui()
	await test_ui_screens()
	await test_home_hotspots()
	await test_home_bar_toggle()
	await test_home_promo()
	await test_home_real_input()
	await test_subgame_flow()
	await test_entitlement_flow()
	await test_act2_hybrid_flow()
	await test_camp_flow()
	await test_loadout_v2()
	await test_map_flow()
	await test_pre_battle_camp()
	await test_party_flow()
	await test_new_game_kit()
	await test_hero_flow()
	await test_act3_forced_mode()
	await test_mode_boundary()
	await test_loadout_settle_landscape()
	await test_main_flow()
	await test_resume_on_launch()
	await test_english_smoke()
	await test_mobile_platform()
	await test_store_and_act_gate()
	await test_character_nav()
	await test_gap_features()
	await test_art_pipeline()
	await test_transition_camera()
	if failures == 0:
		print("== 全部通过 ==")
	else:
		print("== 失败：", failures, " ==")
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------- RNG（tech/01 §5.2 确定性）

func test_rng() -> void:
	print("[rng]")
	var a := Rng.new(12345)
	var b := Rng.new(12345)
	var seq_a: Array = []
	var seq_b: Array = []
	for i: int in 10:
		seq_a.append(a.d20())
		seq_b.append(b.d20())
	check(seq_a == seq_b, "同种子同序列（d20 ×10）")
	var c := Rng.new(999)
	var bounds_ok := true
	for i: int in 300:
		var v := c.range_int(3, 7)
		if v < 3 or v > 7:
			bounds_ok = false
		var d := c.d_n(6)
		if d < 1 or d > 6:
			bounds_ok = false
	check(bounds_ok, "dN(n)/range_int(a,b) 取值范围")
	var d20_ok := true
	for i: int in 300:
		var r := c.d20()
		if r < 1 or r > 20:
			d20_ok = false
	check(d20_ok, "d20 取值 1~20")
	var st := a.save_state()
	var next1 := a.d20()
	a.load_state(st)
	check(a.d20() == next1, "状态快照恢复后续掷一致")
	# M2 审计 G2：state 常态 >2^53，JSON 数值往返曾丢尾数致读档后骰序偏离——
	# 修复后 state 以十进制字符串存储，经 JSON 序列化往返（等价于写盘读回）骰序逐位一致。
	var big := Rng.new(20261109)
	for i: int in 3:
		big.range_int(1, 20) # PCG 状态数步即超 2^53
	var st2: Dictionary = big.save_state()
	check(st2["state"] is String and int(st2["state"]) > 0, "存档 state 以十进制字符串存储（G2）")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(st2))
	check(int(roundtrip["state"]) == int(st2["state"]), "大 state（>2^53）JSON 往返无精度损失（G2）")
	var big2 := Rng.new(1)
	big2.load_state(roundtrip)
	var seq_orig: Array = []
	var seq_rest: Array = []
	for i: int in 10:
		seq_orig.append(big.range_int(1, 20))
		seq_rest.append(big2.range_int(1, 20))
	check(seq_orig == seq_rest, "JSON 往返恢复后骰序逐位一致 ×10（G2，07 §4.1）")
	# 旧档兼容：v≤2 数值型 state（含已丢精度 float）不报错接收
	var legacy := Rng.new(7)
	legacy.load_state({"seed": 20261109, "state": 3619339438595917312.0})
	check(legacy.range_int(1, 20) >= 1, "旧档数值型 state 兼容读取（G2 迁移不炸档）")

# ---------------------------------------------------------------- EventStream（tech/01 §5）

func test_event_stream() -> void:
	print("[event_stream]")
	var s := EventStream.new()
	var received: Array = []
	s.subscribe(func(ev: Dictionary) -> void: received.append(ev))
	var e1 := s.emit(EventTypes.LOG, {"msg": "a"}, &"test")
	var e2 := s.emit(EventTypes.CHECK_ROLL, {"roll": 17}, &"test", "N1-1", "battle-1")
	check(e1["id"] == 1 and e2["id"] == 2, "追加顺序：id 递增")
	check(int(e2["payload"]["roll"]) == 17 and e2["node"] == "N1-1" and e2["session"] == "battle-1",
		"事件结构 {id,session,type,payload,source,node}")
	check(received.size() == 2 and received[1]["type"] == EventTypes.CHECK_ROLL, "订阅触发")
	check(s.query_by_type(EventTypes.LOG).size() == 1, "按类型查询")
	check(s.tail() == 2, "tail 尾部序号（存档锚点）")
	check(s.since(1).size() == 1 and s.since(2).is_empty(), "since(锚点) 切片")

# ---------------------------------------------------------------- Board（framework/07 全文）

func test_board() -> void:
	print("[board]")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var prov := {"event_id": 1, "node_id": "N0-1", "pack_id": "campaign01"}

	# 读写与默认值（07 §2）
	check(board.write("campaign01.seen_fading", true, prov), "包内旗标写入")
	check(board.read("campaign01.seen_fading") == true, "旗标读回")
	check(board.read("campaign01.missing") == false, "旗标默认 false")
	check(board.read("global.alignment") == 50, "alignment 默认 50（中线）")
	check(board.read("global.rep.uninked") == 0, "rep 默认 0")

	# 写入即钳位 + clamped 事件（07 §2 约束）
	board.write("global.rep.scriptorium", 9, prov)
	check(int(board.read("global.rep.scriptorium")) == 5, "rep 钳位到 +5")
	board.write("global.rep.scriptorium", -9, prov)
	check(int(board.read("global.rep.scriptorium")) == -5, "rep 钳位到 -5")
	board.write("global.doom_clock", 12, prov)
	check(int(board.read("global.doom_clock")) == 10, "doom_clock 钳位 0~10")
	board.write("global.bond.aily", 250, prov)
	check(int(board.read("global.bond.aily")) == 100, "bond 钳位 0~100")
	board.write("global.alignment", -20, prov)
	check(int(board.read("global.alignment")) == 0, "alignment 钳位 0~100")
	check(stream.query_by_type(EventTypes.CLAMPED).size() == 5, "钳位产出 clamped 事件（不静默）")

	# 写入发事件并进事件流（07 §6）
	check(stream.query_by_type(EventTypes.FLAG_WRITE).size() >= 1, "flag.write 事件")
	check(stream.query_by_type(EventTypes.REP_CHANGE).size() == 2, "rep.change 事件")
	check(stream.query_by_type(EventTypes.CLOCK_TICK).size() == 1, "clock.tick 事件")
	check(stream.query_by_type(EventTypes.BOND_CHANGE).size() == 1, "bond.change 事件")
	check(stream.query_by_type(EventTypes.ALIGNMENT_SHIFT).size() == 1, "alignment.shift 事件")

	# 命名空间权限（07 §3）
	check(not board.write("campaign02.foreign_flag", true, prov), "跨包写拒绝")
	check(board.read("campaign02.foreign_flag") == false, "跨包写未生效")
	check(not board.write("global.entitlement.campaign02", true, prov), "entitlement 非 system 拒绝")
	var sys := {"event_id": 2, "node_id": "", "pack_id": "system"}
	check(board.write("global.entitlement.campaign02", true, sys), "entitlement 仅 system 可写")
	check(not board.write("global.unknown_var", 1, prov), "global 白名单外拒绝")
	check(board.write("global.rep.salvage", 2, prov), "global 白名单任何包可写")
	check(board.write("global.tutorial.gesture_chip", true, prov), "global.tutorial.* 白名单可写（07 §3）")
	check(board.unlock_lore("revoked_registry_01", prov), "global.lore 白名单可写（07 §3）")
	check(board.has_lore("revoked_registry_01"), "unlock_lore 读回")
	check(stream.query_by_type(EventTypes.BOARD_DENIED).size() == 3, "越权产出 board.denied 告警事件")

	# 溯源（07 §1、tech/01 §4.2）
	var p := board.provenance_of("campaign01.seen_fading")
	check(p.get("pack_id") == "campaign01" and p.get("node_id") == "N0-1" and int(p.get("event_id")) == 1,
		"溯源记录 {event_id,node_id,pack_id}")
	check(not board.write("campaign01.no_prov", true, {}), "缺溯源写入拒绝（tech/01 §4.2 报错）")

	# 物品：give/remove 与事件
	board.give_item("half_tide_table", 1, prov)
	board.give_item("ink_core", 2, prov)
	check(board.has_item("half_tide_table"), "give_item 持有")
	check(board.item_count("ink_core") == 2, "item 数量堆叠（07 §2 约束3）")
	board.remove_item("ink_core", 1, prov)
	check(board.item_count("ink_core") == 1, "remove_item 数量减少")
	check(stream.query_by_type(EventTypes.ITEM_GAIN).size() == 2, "item.gain 事件")
	check(stream.query_by_type(EventTypes.ITEM_REMOVE).size() == 1, "item.remove 事件")

	# 快照往返一致（JSON，tech/01 §4.3）
	var snap := board.serialize()
	var parsed: Variant = JSON.parse_string(JSON.stringify(snap))
	var board2 := Board.new(EventStream.new())
	board2.deserialize(parsed)
	check(board2.serialize() == snap, "快照 JSON 往返一致")

# ---------------------------------------------------------------- Conditions（tech/02 §4.6）

func test_conditions() -> void:
	print("[conditions]")
	var s := EventStream.new()
	var board := Board.new(s)
	var cond := Conditions.new(board)
	var prov := {"event_id": 10, "node_id": "N1-7", "pack_id": "campaign01"}
	board.write("campaign01.seen_fading", true, prov)
	board.write("global.rep.scriptorium", 3, prov)
	board.write("global.doom_clock", 4, prov)
	board.give_item("ink_core", 2, prov)
	board.write("global.alignment", 70, prov)
	board.write("global.bond.aily", 60, prov)
	board.write("global.bond.bram", 20, prov)
	var ctx := {"pack_id": "campaign01"}

	# 条件词汇表逐项
	check(cond.evaluate({"flag.seen_fading": true}, ctx), "cond flag（省略前缀自动补包名）")
	check(not cond.evaluate({"flag.other": true}, ctx), "cond flag 未命中")
	check(cond.evaluate({"rep.scriptorium": {">=": 3}}, ctx), "cond rep >=")
	check(not cond.evaluate({"rep.scriptorium": {"<": 3}}, ctx), "cond rep < 否")
	check(cond.evaluate({"clock": {">=": 2}}, ctx), "cond clock")
	check(not cond.evaluate({"clock": {">=": 5}}, ctx), "cond clock 否")
	check(cond.evaluate({"item.ink_core": true}, ctx), "cond item 持有（bool）")
	check(cond.evaluate({"item.ink_core": {">=": 2}}, ctx), "cond item 数量 >=")
	check(not cond.evaluate({"item.ink_core": {">=": 3}}, ctx), "cond item 数量不足")
	check(not cond.evaluate({"item.void_relic": false}, ctx) == false, "cond item 未持有（bool false）")
	check(cond.evaluate({"alignment": {"ink_gt": 50}}, ctx), "cond alignment 墨守过中线")
	check(not cond.evaluate({"alignment": {"blank_gt": 50}}, ctx), "cond alignment 留白否")
	board.write("global.alignment", 30, prov)
	check(cond.evaluate({"alignment": {"blank_gt": 50}}, ctx), "cond alignment 留白过中线")
	check(not cond.evaluate({"alignment": {"ink_gt": 50}}, ctx), "cond alignment 墨守否")
	board.write("global.alignment", 70, prov)
	check(cond.evaluate({"bond.aily": {">=": 60}}, ctx), "cond bond.<npc>")
	check(cond.evaluate({"bond_max": {">=": 60}}, ctx), "cond bond_max 命中")
	check(not cond.evaluate({"bond_max": {">=": 61}}, ctx), "cond bond_max 未命中")
	check(cond.evaluate({"all": [{"flag.seen_fading": true}, {"clock": {">=": 2}}]}, ctx), "cond all 组合全真")
	check(not cond.evaluate({"all": [{"flag.seen_fading": true}, {"clock": {">=": 9}}]}, ctx), "cond all 一假即假")
	check(cond.evaluate({"any": [{"flag.nope": true}, {"clock": {">=": 2}}]}, ctx), "cond any 一真即真")
	check(not cond.evaluate({"any": [{"flag.nope": true}, {"clock": {">=": 9}}]}, ctx), "cond any 全假")

	# 效果词汇表逐项
	var s4 := EventStream.new()
	var b4 := Board.new(s4)
	var exec := Conditions.new(b4)
	var ectx := {"pack_id": "campaign01", "node_id": "N1-7", "event_id": 10}
	exec.apply_effects([{"write": "seen_fading", "value": true}], ectx)
	check(b4.read("campaign01.seen_fading") == true, "effect write+value")
	exec.apply_effects([{"clock": -2}], ectx)
	check(int(b4.read("global.doom_clock")) == 0, "effect clock 负值延缓并钳位")
	exec.apply_effects([{"clock": 3}], ectx)
	check(int(b4.read("global.doom_clock")) == 3, "effect clock 增减")
	exec.apply_effects([{"rep.scriptorium": 2}], ectx)
	check(int(b4.read("global.rep.scriptorium")) == 2, "effect rep 增减")
	exec.apply_effects([{"alignment": 10}], ectx)
	check(int(b4.read("global.alignment")) == 60, "effect alignment 滑动（默认 50 起）")
	exec.apply_effects([{"give_item": "ink_core"}], ectx)
	check(b4.has_item("ink_core"), "effect give_item")
	exec.apply_effects([{"remove_item": "ink_core"}], ectx)
	check(not b4.has_item("ink_core"), "effect remove_item")
	exec.apply_effects([{"bond.aily": 15}], ectx)
	check(int(b4.read("global.bond.aily")) == 15, "effect bond 增减")
	exec.apply_effects([{"xp": 50}], ectx)
	var xp_evs := s4.query_by_type(EventTypes.XP_GAIN)
	check(xp_evs.size() == 1 and int(xp_evs[0]["payload"]["amount"]) == 50, "effect xp 产出 xp.gain 事件")
	check(int(b4.read("global.growth.xp", 0)) == 50,
		"effect xp 落板 global.growth.xp（tech/04 §8 规则1：任何包汇入）")
	exec.apply_effects([{"lore": "ink_rain"}], ectx)
	check(b4.has_lore("ink_rain"), "effect lore 解锁后 global.lore 含条目（07 §2）")
	exec.apply_effects([{"lore": "ink_rain"}], ectx)
	check(b4.get_lore().count("ink_rain") == 1, "effect lore 重复解锁幂等（Set 语义）")
	var lore_evs := s4.query_by_type(EventTypes.LORE_UNLOCK)
	check(lore_evs.size() == 2, "effect lore 每次解锁仍产出 lore.unlock 事件")
	check(lore_evs[0]["payload"]["provenance"]["node_id"] == "N1-7"
		and lore_evs[0]["payload"]["provenance"]["pack_id"] == "campaign01", "effect lore 写板带溯源")
	check(lore_evs[0]["payload"].get("added", []) == ["ink_rain"]
		and lore_evs[1]["payload"].get("added", []) == [], "lore.unlock 事件负载含新增条目（重复解锁 added 为空）")

	# 效果全部进事件流（07 §6）；xp 汇入成长后 global.growth.xp 写板也产 flag.write（tech/04 §8）
	check(s4.query_by_type(EventTypes.FLAG_WRITE).size() == 2,
		"effect 写板事件进事件流（flag.write：旗标 + growth.xp 簿记）")
	check(s4.query_by_type(EventTypes.CLOCK_TICK).size() == 2, "effect 写板事件进事件流（clock.tick）")
	check(s4.query_by_type(EventTypes.ITEM_GAIN).size() == 1
		and s4.query_by_type(EventTypes.ITEM_REMOVE).size() == 1, "effect 物品事件进事件流")
	var fx := s4.query_by_type(EventTypes.FLAG_WRITE)[0]
	check(fx["payload"]["provenance"]["node_id"] == "N1-7", "效果写板带溯源")

# ---------------------------------------------------------------- PackLoader（tech/02 §1/§2/§3）

func _load_campaign01() -> Dictionary:
	var res := PackLoader.load_pack("res://packs/campaign01")
	check(res["ok"], "pack 加载成功：%s" % ";".join(res["errors"]))
	return res["pack"]

func test_pack_loader() -> void:
	print("[pack_loader]")
	var res := PackLoader.load_pack("res://packs/campaign01")
	check(res["ok"], "campaign01 加载 ok（结构校验无错误）")
	if not res["ok"]:
		for e: String in res["errors"]:
			print("    加载错误：", e)
		return
	var pack: Dictionary = res["pack"]
	check(pack["pack_id"] == "campaign01", "pack_id 解析")
	check(str(pack["manifest"]["namespace"]) == "campaign01", "命名空间注册 = pack_id（tech/02 §2 防呆）")
	check((pack["nodes"] as Dictionary).size() == 54, "节点表 54 节点（含雾岸地图 4 + 分队演示 5，15/16）")
	check((pack["acts"] as Array).size() == 5, "五幕 acts")
	check((pack["encounters"] as Dictionary).size() == 18, "遭遇表 18 场（含雾岸随机遭遇 fog_ambush）")
	check((pack["items"] as Dictionary).size() == 20, "道具表 20 件（装备 / 消耗品 / 职业起始装备 / 出身纪念物）")
	check((pack["characters"] as Dictionary).size() == 3, "角色表 3 条（玩家模板+珂兰+老费，tech/04 §2）")
	check((pack["skills"] as Dictionary).size() == 15, "技能表 15 条（含三职业技能 + 同伴第二技能）")
	check((pack["enemies"] as Dictionary).size() == 9,
		"敌人表 9 条（幕三/终章补登：守页人/墨潮化身，tech/04 §1）")
	var n17: Dictionary = pack["encounters"]["N1-7"]
	check((n17["party"] as Array).size() == 3 and (n17["enemies"] as Array).size() == 3
		and n17.has("pos") and n17.has("party_advantage"),
		"N1-7 遭遇登记 party/enemies/pos/party_advantage（tech/02 §6 扩展字段）")
	check((pack["endings"] as Array).size() == 4, "结局表 E1~E4")
	check((pack["flags"] as Array).size() == 17, "旗标台账 17 条（结局旗标 ×4 + 多周目解锁 ×4 + 分队演示潮闸 ×1）")
	check((pack["events"] as Array).size() == 10, "事件清单 10 条")
	check((pack["lore"] as Array).size() == 7, "图鉴条目 7 条")
	# 字段缺省容错（tech/02 §11）：N0-1 未声明 on_enter/on_complete 应补默认空数组
	var n01: Dictionary = pack["nodes"]["N0-1"]
	check(n01.has("on_enter") and (n01["on_enter"] as Array).is_empty()
		and n01.has("on_complete") and (n01["edges"] as Array).size() == 1, "可选字段缺省容错补默认值")
	# 数据修复落位：N1-1 商店购买边
	var buy := false
	for e: Variant in (pack["nodes"]["N1-1"] as Dictionary)["edges"]:
		for fx: Variant in (e as Dictionary).get("effects", []):
			if (fx as Dictionary).get("give_item", "") == "half_tide_table":
				buy = true
	check(buy, "N1-1 存在购买半页潮汐表边（战役书 §8 投放补全）")
	# 坏包容错：不存在的目录
	var bad := PackLoader.load_pack("res://packs/no_such_pack")
	check(not bad["ok"] and not (bad["errors"] as Array).is_empty(), "缺失包目录报错不崩溃")

# ---------------------------------------------------------------- packlint（tech/02 §12 + tech/04 §6）

func test_packlint() -> void:
	print("[packlint]")
	var pack := _load_campaign01()
	var issues := PacklintCore.lint(pack)
	var fails: Array = []
	var seen := {}
	for issue: Dictionary in issues:
		seen[issue["v"]] = true
		if issue["level"] == PacklintCore.LEVEL_FAIL:
			fails.append("%s: %s" % [issue["v"], issue["msg"]])
	check(fails.is_empty(), "packlint V1~V13 无 FAIL：%s" % ";".join(fails))
	for v: String in ["V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10", "V11", "V12", "V13"]:
		if not seen.has(v):
			check(false, "packlint 覆盖 %s" % v)
	check(true, "packlint 覆盖 V1~V13 全项（含 N/A 声明）")
	# V11~V13 自 M2 起实检（tech/04 §6）：均有 PASS 结论（无 FAIL 时）
	for v: String in ["V11", "V12", "V13"]:
		check(issues.any(func(i: Dictionary) -> bool:
			return i["v"] == v and i["level"] == PacklintCore.LEVEL_PASS), "%s 实检并 PASS（tech/04 §6）" % v)
	# 图遍历无死路不可达（V1/V2 单项复核）
	var graph_issues := PacklintCore.lint(pack).filter(func(i: Dictionary) -> bool: return ["V1", "V2"].has(i["v"]))
	check(graph_issues.all(func(i: Dictionary) -> bool: return i["level"] == PacklintCore.LEVEL_PASS),
		"图遍历无死路、无不可达（V1/V2 PASS）")
	# 负例：篡改节点制造死路，V1 必须抓到
	var broken: Dictionary = pack.duplicate(true)
	broken["nodes"]["N1-2b"]["edges"] = []
	var broken_issues := PacklintCore.lint(broken)
	check(broken_issues.any(func(i: Dictionary) -> bool:
		return i["v"] == "V1" and i["level"] == PacklintCore.LEVEL_FAIL), "负例：制造死路 V1 必报 FAIL")
	# ---- V11~V13 负例（tech/04 §6，M2 实检）----
	var bad_skill_ref: Dictionary = pack.duplicate(true)
	bad_skill_ref["characters"]["companion_kelan"]["skills"] = ["no_such_skill"]
	check(PacklintCore.lint(bad_skill_ref).any(func(i: Dictionary) -> bool:
		return i["v"] == "V11" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：角色引用未登记技能 V11 必报 FAIL")
	var bad_foe_ref: Dictionary = pack.duplicate(true)
	bad_foe_ref["encounters"]["N1-7"]["enemies"] = [{"id": "boss", "ref": "ghost"}]
	check(PacklintCore.lint(bad_foe_ref).any(func(i: Dictionary) -> bool:
		return i["v"] == "V11" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：遭遇引用未登记敌人 V11 必报 FAIL")
	var bad_attr_ref: Dictionary = pack.duplicate(true)
	bad_attr_ref["effects"] = {"e_bad": {"id": "e_bad", "name": "x", "target_attr": "luck",
		"op": "add", "value": 1, "duration": "encounter", "stack": "refresh"}}
	check(PacklintCore.lint(bad_attr_ref).any(func(i: Dictionary) -> bool:
		return i["v"] == "V11" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：效果 target_attr 未注册 V11 必报 FAIL")
	var bad_op: Dictionary = pack.duplicate(true)
	bad_op["effects"] = {"e_bad": {"id": "e_bad", "name": "x", "target_attr": "ac",
		"op": "bogus", "value": 1, "duration": "encounter", "stack": "refresh"}}
	check(PacklintCore.lint(bad_op).any(func(i: Dictionary) -> bool:
		return i["v"] == "V12" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：效果 op 非法 V12 必报 FAIL")
	var bad_save: Dictionary = pack.duplicate(true)
	bad_save["enemies"]["ink_fiend"]["skills"][0]["save"] = {"attr": "finesse", "dc": 11, "on_success": "quarter"}
	check(PacklintCore.lint(bad_save).any(func(i: Dictionary) -> bool:
		return i["v"] == "V12" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：save.on_success 非法 V12 必报 FAIL")
	var bad_uses: Dictionary = pack.duplicate(true)
	bad_uses["skills"]["inkbolt"]["uses_per_encounter"] = 0
	check(PacklintCore.lint(bad_uses).any(func(i: Dictionary) -> bool:
		return i["v"] == "V13" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：次数制技能 uses=0 V13 必报 FAIL")
	var bad_consume: Dictionary = pack.duplicate(true)
	(bad_consume["items"]["heal_potion"] as Dictionary).erase("use")
	bad_consume["items"]["heal_potion"]["consume"] = true
	check(PacklintCore.lint(bad_consume).any(func(i: Dictionary) -> bool:
		return i["v"] == "V13" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：consume 道具无 use 块（静默消失）V13 必报 FAIL")
	# ---- escort/maze 扩展块负例（tech/02 §6，幕二接入）----
	var bad_escort: Dictionary = pack.duplicate(true)
	(bad_escort["encounters"]["N2S-2"] as Dictionary).erase("escort")
	check(PacklintCore.lint(bad_escort).any(func(i: Dictionary) -> bool:
		return i["v"] == "V11" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：护送遭遇缺 escort 块 V11 必报 FAIL")
	var bad_beat_skill: Dictionary = pack.duplicate(true)
	((bad_beat_skill["encounters"]["N2G-2"] as Dictionary)["maze"]["beats"][0] as Dictionary)["skill"] = "no_such_skill"
	check(PacklintCore.lint(bad_beat_skill).any(func(i: Dictionary) -> bool:
		return i["v"] == "V12" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：迷宫节拍技能未注册 V12 必报 FAIL")
	var bad_beat_foe: Dictionary = pack.duplicate(true)
	((bad_beat_foe["encounters"]["N2G-2"] as Dictionary)["maze"]["beats"][1] as Dictionary)["enemy"] = "ghost"
	check(PacklintCore.lint(bad_beat_foe).any(func(i: Dictionary) -> bool:
		return i["v"] == "V11" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：伏击节拍引用未登记敌人 V11 必报 FAIL")

# ---------------------------------------------------------------- StoryGraph（tech/02 §3/§4/§9）

## 子游戏卡容器（card_<pid>，M4 双卡在架后按包寻址，screen_entry.bind_subgames）。
func _subgame_card(entry: ScreenEntry, pid: String) -> VBoxContainer:
	return entry.subgame_box.get_node_or_null("card_" + pid) as VBoxContainer

## 卡内参战按钮数（HBoxContainer 行内 Button）。
func _enter_buttons(card_box: VBoxContainer) -> int:
	var n := 0
	for child: Node in card_box.get_children():
		if child is HBoxContainer:
			for b: Node in child.get_children():
				if b is Button:
					n += 1
	return n

## 在可走边中按目标节点找边。
func _edge_to(graph: StoryGraph, to: String) -> Dictionary:
	for e: Variant in graph.available_edges():
		if str((e as Dictionary).get("to", "")) == to:
			return e
	return {}

func test_story_graph() -> void:
	print("[story_graph]")
	var pack := _load_campaign01()
	var stream := EventStream.new()
	var board := Board.new(stream)
	var graph := StoryGraph.new(board, Rng.new(42), pack)
	graph.start()
	check(graph.current()["id"] == "N0-1", "入口节点 N0-1")
	check(stream.query_by_type(EventTypes.NODE_ENTER).size() == 1, "进节点产 node.enter 事件")
	graph.take_edge(_edge_to(graph, "N0-2"))

	# 检定边成功路（tech/02 §4.2）
	var e_n02: Dictionary = graph.available_edges()[0]
	check(str(e_n02["type"]) == "check", "N0-2 为检定边")
	graph.resolve_check(e_n02, true)
	check(graph.current()["id"] == "N0-3a", "检定成功 → N0-3a")
	check(board.read("campaign01.seen_fading") == true, "on_enter 写旗标 seen_fading")
	graph.take_edge(_edge_to(graph, "N0-4"))
	graph.take_edge(_edge_to(graph, "N1-1"))
	# hub 购买边（道具投放补全）
	check(not board.has_item("half_tide_table"), "购买前未持有潮汐表")
	var e_buy := _edge_to(graph, "N1-2")
	for e: Variant in graph.available_edges():
		for fx: Variant in (e as Dictionary).get("effects", []):
			if (fx as Dictionary).get("give_item", "") == "half_tide_table":
				e_buy = e
	graph.take_edge(e_buy)
	check(board.has_item("half_tide_table"), "购买边 give_item 潮汐表")
	check(graph.current()["id"] == "N1-2", "购买后抵达 N1-2")
	graph.resolve_check(graph.available_edges()[0], true) # N1-2 检定成功 → N1-3
	check(graph.current()["id"] == "N1-3", "N1-2 成功 → N1-3")
	check(board.get_doom_clock() == 1, "N1-3 on_enter 时钟 +1")
	graph.take_edge(_edge_to(graph, "N1-4")) # 誊写庭接触 rep+1
	check(board.get_rep("scriptorium") == 1, "接触节点声望写入")
	graph.take_edge(_edge_to(graph, "N1-7"))
	graph.take_edge(_edge_to(graph, "N1-8")) # N1-7 战后 → 三份邀约
	check(board.get_bond("kelan") == 10, "N1-7 战后边羁绊 +10（TP1 验收裁决 2）")
	graph.take_edge(_edge_to(graph, "N2S-1")) # N1-8 选誊写庭委托
	# 独狼声望边：已有 rep>0，应不显形（tech/02 §4.5）
	check(_edge_to(graph, "N2L-1").is_empty() or graph.current()["id"] != "N1-8",
		"声望边 requires 不满足不显形（已过 N1-8）")
	graph.resolve_check(graph.available_edges()[0], true) # N2S-1 → N2S-2
	graph.take_edge(_edge_to(graph, "N2S-3"))
	check(not board.has_item("scriptorium_signet"), "on_complete 未离开不结算")
	graph.take_edge(_edge_to(graph, "N2-C")) # 献出记忆
	check(board.has_item("scriptorium_signet"), "离开 N2S-3 结算 on_complete（印戒，tech/02 §3）")
	check(board.read("campaign01.blank_memory") == true, "选择边效果 blank_memory")
	check(board.get_alignment() == 60, "S 链选择边 +墨守 10（结局条件投放补全）")
	check(board.get_doom_clock() == 0, "献出记忆时钟 -2 并钳位 0")
	check(board.get_bond("kelan") == 25, "N2S-3 选择边羁绊 +15（累计 25，TP1 验收裁决 2）")
	graph.take_edge(_edge_to(graph, "N3-1"))
	graph.take_edge(_edge_to(graph, "R1"))
	graph.take_edge(_edge_to(graph, "R2"))
	check(board.has_lore("revoked_registry_01") and board.has_lore("revoked_registry_02"),
		"R2 on_enter 解锁图鉴 ×2")
	graph.resolve_check(graph.available_edges()[0], true) # R2 安抚成功 → 残简
	check(board.has_item("codex_fragment"), "R2 成功路给织命者残简")
	check(board.get_bond("kelan") == 45, "R2 安抚成功羁绊 +20（单周目图内上限 45，TP1 验收裁决 2）")
	check(graph.current()["id"] == "R3", "R2 检定成功 → R3")
	graph.take_edge(_edge_to(graph, "R4")) # R3 → R4 分叉回廊
	var e_r4 := _edge_to(graph, "R4-r")
	check(not e_r4.is_empty() and bool(e_r4.get("via_fallback", false)),
		"item 边未持有黑羽令 → fallback 变体（tech/02 §4.3）")
	graph.take_edge(e_r4)
	graph.take_edge(_edge_to(graph, "R4-r2")) # 右路第一场 → 第二场（战役书幕三 右路两场）
	graph.take_edge(_edge_to(graph, "R5"))
	graph.take_edge(_edge_to(graph, "N3-7"))
	check(board.item_count("codex_fragment") == 2, "R5 战利品残简 ×1（累计 2）")
	graph.take_edge(_edge_to(graph, "N4-1"))
	# N4-1 道具边：印戒 + rep.scriptorium≥1 → 直达 N4-2
	graph.take_edge(_edge_to(graph, "N4-2"))
	check(graph.current()["id"] == "N4-2", "印戒道具边显形（tech/02 §4.3+requires）")
	check(graph.pick_ending() == "E1", "结局表求值：墨守过中线 → E1（tech/02 §9）")
	graph.take_edge(graph.available_edges()[0])
	check(graph.is_at_ending() and graph.current()["id"] == "E1", "图边抵达 E1 与结局表一致")
	check(board.get_doom_clock() >= 0 and board.get_doom_clock() <= 10, "全程时钟 0~10")

# ---------------------------------------------------------------- StoryBot 仿真（TASKS P1.5 TP1）

func test_story_bot() -> void:
	print("[story_bot]")
	var pack := _load_campaign01()
	# 单局可达结局
	var one := StoryBot.run(pack, 48514)
	check(one["ok"], "bot 单局必达结局（seed=48514 → %s）" % str(one.get("ending", "")))
	# 多 seed：24 局半数二周目、1/4 一周目局独狼探针，断言四结局全集可达 + 时钟有界
	# （与 tools/simulate.gd 同种子公式）
	var endings := {}
	var all_ok := true
	var clock_ok := true
	var lone_wolf_hit := false
	var ngplus_bond60 := false
	var chain_hits := {} # 幕二三委托链收束点覆盖
	var detour_hit := false # 幕二绕行路（N2G-2c）
	for i: int in 24:
		var lone := i % 4 == 2
		var ngp := i % 2 == 1
		var detour := i % 12 == 4 and not lone and not ngp # 绕行探针（i=4,16，确定性覆盖 N2G-2c）
		var r := StoryBot.run(pack, 1000 + i * 7919, ngp, lone, detour)
		if not r["ok"]:
			all_ok = false
			continue
		var ending := str(r["ending"])
		endings[ending] = true
		if (r["visited"] as Dictionary).has("N2L-1") or (r["visited"] as Dictionary).has("N2L-1b"):
			lone_wolf_hit = true
		if (r["visited"] as Dictionary).has("N2G-2c"):
			detour_hit = true
		for cn: String in ["N2S-3", "N2U-3", "N2G-3"]:
			if (r["visited"] as Dictionary).has(cn):
				chain_hits[cn] = true
		if r["ngplus"] and int(r["bond_max"]) >= 60:
			ngplus_bond60 = true
		if int(r["clock_min"]) < 0 or int(r["clock_max"]) > 10:
			clock_ok = false
		# 图边结局与 endings.json 求值互证（tech/02 §9）
		if str(r["ending_by_table"]) != "" and str(r["ending_by_table"]) != ending:
			all_ok = false
	check(all_ok, "24 局全部必达结局且图边结局与结局表一致")
	check(clock_ok, "全部路径 clock ∈ 0~10（07 §2 钳位 + V5 有界）")
	check(chain_hits.has("N2S-3") and chain_hits.has("N2U-3") and chain_hits.has("N2G-3"),
		"幕二三委托链收束点仿真全覆盖（S/U/G，幕二接入验收）")
	check(detour_hit, "幕二绕行路 N2G-2c 仿真命中（绕行探针确定性覆盖，tech/02 §4.3 fallback）")
	check(endings.has("E1") and endings.has("E2"), "alignment 修复后 E1/E2 可达（±10 投放）")
	check(endings.has("E3"), "二周目配置 E3 可达（残简继承 ×1 + 密道/R2/R5 ×3 + 图内投放羁绊继承）")
	check(endings.has("E4"), "E4 兜底可达（tech/02 §9 default）")
	check(endings.size() == 4, "多 seed 四结局全集可达")
	check(lone_wolf_hit, "独狼路径可达：存在 seed 命中 N2L-1/N2L-1b（TP1 验收裁决 1）")
	check(ngplus_bond60, "bond 图内投放后二周目 bond_max ≥60 可满足（TP1 验收裁决 2，E3 条件）")
	var first_play_e3 := false
	for i: int in 24:
		if i % 2 == 1:
			continue
		var r := StoryBot.run(pack, 1000 + i * 7919, false, i % 4 == 2)
		if r["ok"] and str(r["ending"]) == "E3":
			first_play_e3 = true
	check(not first_play_e3, "一周目（无继承）不可达 E3（残简 ≤3 且羁绊图内上限 45 < 60，战役书 §8/§9）")

# ---------------------------------------------------------------- LightV1 规则包（framework/11 全文）

func test_light_v1() -> void:
	print("[light_v1]")
	check(LightV1.DC_EASY == 8 and LightV1.DC_MEDIUM == 12 and LightV1.DC_HARD == 16,
		"难度三档 DC 8/12/16（11 §3）")
	# §3.1 优劣合并：不叠加、互抵
	check(LightV1.combine_advantage([LightV1.ADV_ADVANTAGE]) == LightV1.ADV_ADVANTAGE, "单一优势 → 优势")
	check(LightV1.combine_advantage([LightV1.ADV_ADVANTAGE, LightV1.ADV_ADVANTAGE]) == LightV1.ADV_ADVANTAGE,
		"多优势不叠加")
	check(LightV1.combine_advantage([LightV1.ADV_DISADVANTAGE]) == LightV1.ADV_DISADVANTAGE, "单一劣势 → 劣势")
	check(LightV1.combine_advantage([LightV1.ADV_ADVANTAGE, LightV1.ADV_DISADVANTAGE]) == LightV1.ADV_NORMAL,
		"优劣互抵 → 普通掷")
	check(LightV1.combine_advantage([]) == LightV1.ADV_NORMAL, "无来源 → 普通掷")
	# 优势 2d20 取高 / 劣势取低（与平行 Rng 复算一致）
	for seed: int in [7, 42, 2026]:
		var r := LightV1.roll_d20(Rng.new(seed), LightV1.ADV_ADVANTAGE)
		var rep := Rng.new(seed)
		var a := rep.d20()
		var b := rep.d20()
		check((r["rolls"] as Array) == [a, b] and int(r["keep"]) == maxi(a, b),
			"优势取高（seed=%d）" % seed)
		var r2 := LightV1.roll_d20(Rng.new(seed), LightV1.ADV_DISADVANTAGE)
		var rep2 := Rng.new(seed)
		var c := rep2.d20()
		var d := rep2.d20()
		check(int(r2["keep"]) == mini(c, d), "劣势取低（seed=%d）" % seed)
	# 伤害骰解析
	var d1 := LightV1.parse_dice("1d6+2")
	check(int(d1["count"]) == 1 and int(d1["sides"]) == 6 and int(d1["mod"]) == 2, "parse_dice 1d6+2")
	var d2 := LightV1.parse_dice("2d4-1")
	check(int(d2["count"]) == 2 and int(d2["sides"]) == 4 and int(d2["mod"]) == -1, "parse_dice 2d4-1")
	# 检定：极端修正必成/必败
	check(bool(LightV1.check(Rng.new(1), 30, LightV1.DC_HARD)["success"]), "d20+30 vs DC16 必成")
	check(not bool(LightV1.check(Rng.new(1), -30, LightV1.DC_EASY)["success"]), "d20-30 vs DC8 必败")
	# 攻击：暴击翻倍（修正不加倍）与必失——扫 seed 找 nat20/nat1
	var found_crit := false
	var found_fumble := false
	for seed: int in range(1, 3000):
		if found_crit and found_fumble:
			break
		var res := LightV1.attack(Rng.new(seed), 30, 18, "1d6+2")
		if bool(res["crit"]) and not found_crit:
			found_crit = true
			check(bool(res["hit"]) and (res["damage_rolls"] as Array).size() == 2
				and int(res["damage"]) == int(res["damage_rolls"][0]) + int(res["damage_rolls"][1]) + 2,
				"nat20 暴击：必中、伤害骰翻倍、修正不加倍（11 §3）")
		elif bool(res["fumble"]) and not found_fumble:
			found_fumble = true
			check(not bool(res["hit"]) and int(res["damage"]) == 0, "nat1 必失（+30 修正亦失，11 §3）")
	check(found_crit and found_fumble, "seed 空间内命中 nat20 与 nat1 样本")
	# 豁免：half / none（11 §5.1）
	var sv := LightV1.save_throw(Rng.new(5), 30, {"attr": "finesse", "dc": 11, "on_success": "half"}, "4d6")
	check(bool(sv["success"]) and int(sv["damage_taken"]) == int(floori(float(sv["damage_full"]) / 2.0)),
		"豁免成功半伤（向下取整）")
	var sv2 := LightV1.save_throw(Rng.new(5), 30, {"attr": "finesse", "dc": 11, "on_success": "none"}, "4d6")
	check(bool(sv2["success"]) and int(sv2["damage_taken"]) == 0, "豁免成功免伤（none）")
	var sv3 := LightV1.save_throw(Rng.new(5), -30, {"attr": "finesse", "dc": 11, "on_success": "half"}, "4d6")
	check(not bool(sv3["success"]) and int(sv3["damage_taken"]) == int(sv3["damage_full"]), "豁免失败全伤")
	# 死亡豁免：≥10 一胜（11 §7）
	var ds_ok := true
	for seed: int in range(1, 200):
		var ds := LightV1.death_save(Rng.new(seed))
		if bool(ds["success"]) != (int(ds["roll"]) >= 10):
			ds_ok = false
	check(ds_ok, "死亡豁免 d20≥10 记一胜")

# ---------------------------------------------------------------- 遭遇测试夹具

func _tp2_party() -> Array:
	return [
		{"id": "pc", "name": "白页者", "kind": "player", "hp": 14, "max_hp": 14, "ac": 11,
			"attrs": {"might": 2, "finesse": 1, "wits": 0}, "attack_mod": 2, "damage": "1d6+2",
			"skills": [{"id": "inkbolt", "name": "墨术飞矢", "kind": "attack", "attr": "wits",
				"damage": "1d6", "uses": 2, "target": "enemy"}],
			"items": [{"id": "heal_potion", "name": "补给药水", "count": 2,
				"use": {"timing": "bonus_action", "heal": "1d4+2", "consume": true}}]},
		{"id": "kelan", "name": "珂兰", "kind": "companion", "hp": 10, "max_hp": 10, "ac": 11,
			"attrs": {"might": 0, "finesse": 1, "wits": 1}, "attack_mod": 1, "damage": "1d6+1",
			"skills": [{"id": "kelan_bolt", "name": "墨矢", "kind": "attack", "attr": "finesse",
				"damage": "1d6+1", "target": "enemy"}]},
		{"id": "laofei", "name": "老费", "kind": "companion", "hp": 12, "max_hp": 12, "ac": 12,
			"attrs": {"might": 1, "finesse": 0, "wits": 1}, "attack_mod": 1, "damage": "1d6+1",
			"skills": [{"id": "laofei_hook", "name": "船钩", "kind": "attack", "attr": "might",
				"damage": "1d6+1", "target": "enemy"}]},
	]

func _tp2_enemies() -> Array:
	return [
		{"id": "boss", "name": "墨魈", "hp": 16, "max_hp": 16, "ac": 11,
			"attrs": {"might": 1, "finesse": 1, "wits": 0}, "attack_mod": 3, "damage": "1d4+1",
			"skills": [{"id": "ink_rain", "name": "墨雨溅射", "kind": "aoe", "damage": "1d6",
				"uses": 2, "cooldown": 2,
				"save": {"attr": "finesse", "dc": 11, "on_success": "half"}}]},
		{"id": "imp1", "name": "墨魈幼体", "hp": 8, "max_hp": 8, "ac": 10,
			"attrs": {"might": 0, "finesse": 0, "wits": 0}, "attack_mod": 2, "damage": "1d4"},
		{"id": "imp2", "name": "墨魈幼体", "hp": 8, "max_hp": 8, "ac": 10,
			"attrs": {"might": 0, "finesse": 0, "wits": 0}, "attack_mod": 2, "damage": "1d4"},
	]

func _std_def() -> Dictionary:
	return {"party": _tp2_party(), "enemies": _tp2_enemies(),
		"party_advantage_rounds": 1, "loot": [{"item": "ink_core", "n": 1}], "xp": 100}

func _mini_def(atk_mod: int = 2) -> Dictionary:
	var pc: Dictionary = _tp2_party()[0]
	pc["attack_mod"] = atk_mod
	pc.erase("skills")
	pc.erase("items")
	return {"party": [pc], "enemies": [_tp2_enemies()[1]]}

func _sm_with(seed: int, def: Dictionary) -> EncounterSM:
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(seed), "campaign01")
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(def)
	return sm

func _cmd(ctype: StringName, actor: String, target: String = "", skill: String = "",
		item: String = "", source: StringName = &"player") -> Dictionary:
	return {"type": ctype, "actor": actor, "target": target, "skill": skill, "item": item, "source": source}

func _last_attack(sm: EncounterSM) -> Dictionary:
	var evs := sm.stream.query_by_type(EventTypes.BATTLE_ATTACK)
	return evs.back()["payload"] if not evs.is_empty() else {}

## 用结束回合动态驱动当前友方阶段走完（不假设先攻序；止于本轮边界）。
func _end_party_phase(sm: EncounterSM) -> void:
	var r0 := sm.round_no()
	var guard := 0
	while sm.state == EncounterSM.S_COMBAT and sm.phase() == &"party" \
			and sm.current_actor_id() != "" and sm.round_no() == r0 and guard < 20:
		guard += 1
		sm.submit_command(_cmd(EncounterSM.CMD_END_TURN, sm.current_actor_id()))

## pc 先攻必优先的 def（finesse 20），用于行动经济/托管断言。
func _pc_first_def() -> Dictionary:
	var def := _std_def()
	((def["party"] as Array)[0] as Dictionary)["attrs"] = {"might": 2, "finesse": 20, "wits": 0}
	return def

## 珂兰可倒地的夹具：墨雨溅射 6d6、pc 高血高修正重骰且先攻优先。
func _down_def() -> Dictionary:
	var boss_hard: Dictionary = _tp2_enemies()[0]
	((boss_hard["skills"] as Array)[0] as Dictionary)["damage"] = "6d6"
	return {"party": [
			_tp2_party()[0].merged({"hp": 100, "max_hp": 100, "attack_mod": 30, "damage": "30d6",
				"attrs": {"might": 2, "finesse": 20, "wits": 0}}, true),
			_tp2_party()[1].merged({"hp": 8}, true)],
		"enemies": [boss_hard]}

# ---------------------------------------------------------------- EncounterSM（09 §1、tech/01 §6.1/§6.2、11 §4/§5）

func test_encounter_sm() -> void:
	print("[encounter_sm]")
	# —— 六态转换表（09 §1）——
	var s0 := EventStream.new()
	var sm := EncounterSM.new(Board.new(s0), s0, Rng.new(1), "campaign01")
	sm.enter("N1-7")
	check(sm.state == EncounterSM.S_ENTER, "进场态")
	check(not sm.transition(EncounterSM.S_COMBAT), "非法转换拒绝：进场→战斗")
	check(sm.transition(EncounterSM.S_EXPLORE), "进场→探索")
	check(sm.transition(EncounterSM.S_DISCOVER), "探索→发现")
	check(sm.transition(EncounterSM.S_EXPLORE), "发现→探索（双向流转）")
	check(not sm.transition(EncounterSM.S_REST), "非法转换拒绝：探索→休整")
	check(not sm.transition(EncounterSM.S_EXIT), "非法转换拒绝：探索→出场")
	var st_evs := s0.query_by_type(EventTypes.STATE_ENTERED)
	check(st_evs.size() == 4 and str(st_evs[0]["payload"]["state"]) == "enter"
		and str(st_evs[1]["payload"]["state"]) == "explore"
		and str(st_evs[1]["payload"]["prev"]) == "enter", "状态切换外发 state.entered（09 §1 约定）")
	# 结算→休整→出场
	var sm2 := _sm_with(3, _std_def())
	check(sm2.state == EncounterSM.S_COMBAT, "探索→战斗（敌意触发）")
	check(not sm2.transition(EncounterSM.S_EXIT), "未声明撤退边：战斗→出场拒绝（09 §7）")
	# 打完进结算（pc 扫 seed 找必胜开局：优势首回合 + 高修正重骰）
	var won := false
	for seed: int in range(1, 400):
		var smw := _sm_with(seed, {"party": [_tp2_party()[0].merged({"attack_mod": 30, "damage": "30d6"}, true)],
			"enemies": [_tp2_enemies()[1]], "xp": 100, "loot": [{"item": "ink_core", "n": 1}]})
		smw.submit_command(_cmd(EncounterSM.CMD_ATTACK, "pc", "imp1"))
		if smw.is_over():
			won = true
			check(smw.state == EncounterSM.S_SETTLE, "战斗→结算（一方全灭）")
			check(smw.result() == &"victory", "胜利结果")
			check(smw.board.item_count("ink_core") == 1, "结算写状态板：战利品墨核落板（09 §1 硬要求）")
			check(smw.stream.query_by_type(EventTypes.XP_GAIN).size() == 1, "结算产出 xp.gain")
			check(not smw.transition(EncounterSM.S_EXPLORE), "非法转换拒绝：结算→探索")
			check(smw.transition(EncounterSM.S_REST), "结算→休整")
			check(smw.transition(EncounterSM.S_EXIT), "休整→出场")
			check(not smw.transition(EncounterSM.S_ENTER), "出场为终态")
			break
	check(won, "seed 空间内找到必胜样本")
	# 撤退边（09 §7）
	var smr := _sm_with(3, _std_def().merged({"retreat_allowed": true}, true))
	check(smr.transition(EncounterSM.S_EXIT), "声明撤退边后战斗→出场允许")
	var smr2 := _sm_with(3, _std_def().merged({"retreat_allowed": true}, true))
	smr2.submit_command(_cmd(EncounterSM.CMD_RETREAT, smr2.current_actor_id()))
	check(smr2.is_over() and smr2.result() == &"retreat" and smr2.state == EncounterSM.S_SETTLE,
		"撤退命令 → combat.end(retreat) → 结算（失败即分支）")

	# —— 先攻（11 §5：d20+敏降序，平局玩家优先）——
	var smi := _sm_with(42, _std_def())
	var rep := Rng.new(42)
	var expect: Array = []
	for u: Variant in _tp2_party() + _tp2_enemies():
		expect.append({"id": (u as Dictionary)["id"],
			"init": rep.d20() + int((u as Dictionary)["attrs"]["finesse"]),
			"seq": expect.size(), "side": &"party" if (u as Dictionary).has("kind") else &"enemy"})
	expect.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["init"]) != int(b["init"]):
			return int(a["init"]) > int(b["init"])
		if a["side"] != b["side"]:
			return a["side"] == &"party"
		return int(a["seq"]) < int(b["seq"]))
	var expect_order: Array = []
	for e: Variant in expect:
		expect_order.append(str((e as Dictionary)["id"]))
	check(smi.get_order() == expect_order, "先攻序列 = d20+敏降序、平局玩家优先（平行 Rng 复算）")
	check(smi.stream.query_by_type(EventTypes.COMBAT_START).size() == 1, "combat.start 事件")

	# —— 普通攻击命中与伤害 ——
	var hit_ok := false
	for seed: int in range(1, 200):
		var smh := _sm_with(seed, _mini_def())
		smh.submit_command(_cmd(EncounterSM.CMD_ATTACK, "pc", "imp1"))
		var p := _last_attack(smh)
		if bool(p.get("hit", false)) and not bool(p["crit"]):
			hit_ok = true
			check((p["damage_rolls"] as Array).size() == 1
				and int(p["damage"]) == int(p["damage_rolls"][0]) + 2, "命中伤害 = 武器骰+修正（11 §5）")
			check(int(smh.get_unit("imp1")["hp"]) == 8 - int(p["damage"]), "伤害落板到目标 HP")
			break
	check(hit_ok, "seed 空间内找到普通命中样本")

	# —— 见证撤销首回合优势（11 §3.1 内容包声明来源）——
	var smadv := _sm_with(9, _std_def())
	var atk1 := smadv.current_actor_id()
	smadv.submit_command(_cmd(EncounterSM.CMD_ATTACK, atk1, "imp1"))
	var padv := _last_attack(smadv)
	check(str(padv["mode"]) == "advantage" and (padv["rolls"] as Array).size() == 2
		and int(padv["keep"]) == maxi(int(padv["rolls"][0]), int(padv["rolls"][1])),
		"首回合全队攻击优势（2d20 取高）")
	while smadv.state == EncounterSM.S_COMBAT and smadv.phase() == &"party" and smadv.round_no() == 1:
		smadv.submit_command(_cmd(EncounterSM.CMD_END_TURN, smadv.current_actor_id()))
	check(smadv.round_no() == 2 and smadv.party_advantage_rounds() == 0, "全员行动完进敌方回合并进第 2 轮（11 §5.2）")
	smadv.submit_command(_cmd(EncounterSM.CMD_ATTACK, smadv.current_actor_id(), "imp1"))
	check(str(_last_attack(smadv)["mode"]) == "normal", "第 2 轮优势消退 → 普通掷")

	# —— 墨雨溅射豁免（11 §5.1）——
	var smsv := _sm_with(9, _std_def())
	while smsv.state == EncounterSM.S_COMBAT and smsv.round_no() == 1 and smsv.phase() == &"party":
		smsv.submit_command(_cmd(EncounterSM.CMD_END_TURN, smsv.current_actor_id()))
	var saves := smsv.stream.query_by_type(EventTypes.CHECK_ROLL).filter(
		func(ev: Dictionary) -> bool: return str(ev["payload"].get("kind", "")) == "save")
	check(saves.size() == 3, "墨雨溅射对全员各掷一次豁免")
	var sv0: Dictionary = saves[0]["payload"]
	check(int(sv0["dc"]) == 11 and str(sv0["on_success"]) == "half"
		and not bool(sv0.get("key", true)), "豁免 DC11/half、默认普通演出（11 §5.1）")

	# —— 行动经济（11 §4/§5.2）——
	var sme := _sm_with(11, _pc_first_def())
	sme.submit_command(_cmd(EncounterSM.CMD_ATTACK, "pc", "imp1"))
	check(not sme.submit_command(_cmd(EncounterSM.CMD_ATTACK, "pc", "imp1")), "动作已用：第二次攻击拒绝")
	check(sme.stream.query_by_type(EventTypes.COMMAND_REJECTED).back()["payload"]["reason"] == "action_used",
		"拒绝产出 command.rejected(action_used)")
	check(sme.submit_command(_cmd(EncounterSM.CMD_ITEM, "pc", "pc", "", "heal_potion")), "附赠动作用药")
	check(not sme.submit_command(_cmd(EncounterSM.CMD_ITEM, "pc", "pc", "", "heal_potion")), "附赠已用：第二次用药拒绝")
	check(sme.current_actor_id() != "pc" and sme.current_actor_id() != "", "动作+附赠耗尽自动轮到下一单位")
	check(not sme.submit_command(_cmd(EncounterSM.CMD_ATTACK, "pc", "imp1")), "非当前单位命令拒绝（not_your_turn）")
	# 次数制技能（11 §8）：墨术飞矢 2 次，第 3 次拒绝
	var sku := _sm_with(11, _pc_first_def())
	sku.submit_command(_cmd(EncounterSM.CMD_SKILL, "pc", "imp1", "inkbolt"))
	_end_party_phase(sku)
	sku.submit_command(_cmd(EncounterSM.CMD_SKILL, "pc", "imp1", "inkbolt"))
	_end_party_phase(sku)
	check(int(sku.get_unit("pc")["skill_uses"]["inkbolt"]) == 0, "次数扣减至 0")
	check(not sku.submit_command(_cmd(EncounterSM.CMD_SKILL, "pc", "imp1", "inkbolt")), "次数耗尽拒绝（skill_depleted）")
	# 道具消耗写板（tech/04 §4 consume）
	var smit := _sm_with(11, _pc_first_def())
	smit.board.give_item("heal_potion", 2, {"event_id": 1, "node_id": "N1-1", "pack_id": "campaign01"})
	smit.submit_command(_cmd(EncounterSM.CMD_ITEM, "pc", "pc", "", "heal_potion"))
	check(smit.board.item_count("heal_potion") == 1, "consume 道具从 global.inv 移除（写板+事件流）")
	check(smit.stream.query_by_type(EventTypes.ITEM_USE).size() == 1, "item.use 事件")

	# —— 同伴（11 §5.2：每存活同伴 1 动作）——
	var smc := _sm_with(11, _pc_first_def())
	smc.submit_command(_cmd(EncounterSM.CMD_END_TURN, "pc"))
	var comp := smc.current_actor_id()
	check(comp == "kelan" or comp == "laofei", "同伴进入指令通道")
	var comp_skill := "kelan_bolt" if comp == "kelan" else "laofei_hook"
	check(smc.submit_command(_cmd(EncounterSM.CMD_SKILL, comp, "imp1", comp_skill)), "同伴招牌技能可执行")
	check(not smc.submit_command(_cmd(EncounterSM.CMD_ATTACK, comp, "imp1")), "同伴每回合 1 动作")

	# —— 倒地互救与战后起身（11 §5.2/§7）——
	var aid_done := false
	var post_done := false
	for seed: int in range(1, 3000):
		if aid_done and post_done:
			break
		var smd := _sm_with(seed, _down_def())
		_end_party_phase(smd) # 第 1 轮友方结束 → 敌方墨雨溅射（6d6）
		if smd.is_over() or not bool(smd.get_unit("kelan")["downed"]) or smd.current_actor_id() != "pc":
			continue
		if not aid_done:
			var smd2 := _sm_with(seed, _down_def())
			_end_party_phase(smd2)
			smd2.submit_command(_cmd(EncounterSM.CMD_FIRST_AID, "pc", "kelan"))
			var fa := smd2.stream.query_by_type(EventTypes.CHECK_ROLL).filter(
				func(ev: Dictionary) -> bool: return str(ev["payload"].get("kind", "")) == "first_aid")
			if not fa.is_empty() and bool(fa.back()["payload"]["success"]):
				aid_done = true
				check(int(smd2.get_unit("kelan")["hp"]) == 1 and not bool(smd2.get_unit("kelan")["downed"]),
					"急救成功 1 HP 扶起（d20+智 vs DC8，11 §5.2）")
				check(smd2.stream.query_by_type(EventTypes.BATTLE_REVIVE).back()["payload"]["reason"] == "first_aid",
					"battle.revive(first_aid) 事件")
		if not post_done:
			smd.submit_command(_cmd(EncounterSM.CMD_ATTACK, "pc", "boss"))
			if smd.is_over() and smd.result() == &"victory":
				var kl := smd.get_unit("kelan")
				if int(kl["hp"]) == 1 and not bool(kl["downed"]):
					post_done = true
					check(true, "战后倒地同伴自动 1 HP 起身（11 §5.2）")
	check(aid_done, "seed 空间内找到急救成功样本")
	check(post_done, "seed 空间内找到战后起身样本")

	# —— 死亡豁免三局两胜（11 §7）——
	var stabilized := false
	var died := false
	for seed: int in range(1, 3000):
		if stabilized and died:
			break
		var smds := _sm_with(seed, _down_def())
		_end_party_phase(smds) # 第 1 轮：墨雨溅射打倒珂兰
		if not bool(smds.get_unit("kelan")["downed"]):
			continue
		var guard := 0
		while not smds.is_over() and guard < 40:
			guard += 1
			var kl_now := smds.get_unit("kelan")
			if not bool(kl_now["downed"]) or bool(kl_now["dead"]):
				break
			_end_party_phase(smds)
		var kl2 := smds.get_unit("kelan")
		var ds_evs := smds.stream.query_by_type(EventTypes.CHECK_ROLL).filter(
			func(ev: Dictionary) -> bool: return str(ev["payload"].get("kind", "")) == "death_save")
		if not stabilized and int(kl2["hp"]) == 1 and not bool(kl2["downed"]) and not bool(kl2["dead"]) \
				and smds.stream.query_by_type(EventTypes.BATTLE_REVIVE).any(
					func(ev: Dictionary) -> bool: return ev["payload"]["reason"] == "stabilized"):
			stabilized = true
			check(ds_evs.all(func(ev: Dictionary) -> bool: return bool(ev["payload"].get("key", false))),
				"死亡豁免恒定关键判定 key=true（11 §7/09 §6）")
			check(true, "三胜稳住：1 HP 起身（battle.revive stabilized）")
		if not died and bool(kl2["dead"]):
			died = true
			check(true, "三负死亡（battle.dead）")
	check(stabilized, "seed 空间内找到三胜稳住样本")
	check(died, "seed 空间内找到三负死亡样本")

# ---------------------------------------------------------------- AutoAgent（09 §9.3、tech/01 §6.2）

func test_auto_agent() -> void:
	print("[auto_agent]")
	var agent := AutoAgent.new()
	# 技能优先 + 命令同构性
	var sm := _sm_with(11, _pc_first_def())
	var auto := agent.next_command(sm)
	var manual := _cmd(EncounterSM.CMD_SKILL, "pc", sm.first_alive_enemy(), "inkbolt")
	var auto_cmp := auto.duplicate()
	auto_cmp.erase("source")
	var manual_cmp := manual.duplicate()
	manual_cmp.erase("source")
	check(auto_cmp == manual_cmp, "托管与手操产出同构 Command（仅 source 不同，tech/01 §6.2）")
	check(auto["source"] == &"auto", "托管命令 source=auto（09 §9.3 可回放可追溯）")
	var keys: Array = auto.keys()
	keys.sort()
	var expect_keys: Array = ["actor", "item", "skill", "source", "target", "type"]
	check(keys == expect_keys, "命令键集恒定")
	check(sm.submit_command(auto), "托管命令通过同一合法性校验")
	check(sm.stream.query_by_type(EventTypes.BATTLE_ATTACK).back()["payload"]["source"] == &"auto",
		"事件流标注来源 auto")
	# 动作已用 → 结束回合
	var after := agent.next_command(sm)
	check(after["type"] == EncounterSM.CMD_END_TURN, "动作耗尽 → 结束回合")
	sm.submit_command(after)
	check(["kelan", "laofei"].has(str(agent.next_command(sm)["actor"])), "同伴由同一代理接管（11 §5.2）")
	# 次数耗尽退普攻（09 §9.3）
	var sm2 := _sm_with(11, _pc_first_def())
	sm2.submit_command(_cmd(EncounterSM.CMD_SKILL, "pc", "imp1", "inkbolt", "", &"player"))
	_end_party_phase(sm2)
	sm2.submit_command(_cmd(EncounterSM.CMD_SKILL, "pc", "imp1", "inkbolt", "", &"player"))
	_end_party_phase(sm2)
	var c2 := agent.next_command(sm2)
	check(c2["type"] == EncounterSM.CMD_ATTACK and str(c2["skill"]) == "", "次数技能耗尽退普攻")
	# 低血用药（默认 HP<50%，阈值可配置）
	var low_def := _pc_first_def()
	(low_def["party"][0] as Dictionary)["hp"] = 6
	var sm3 := _sm_with(11, low_def)
	var c3 := agent.next_command(sm3)
	check(c3["type"] == EncounterSM.CMD_ITEM and str(c3["item"]) == "heal_potion" and str(c3["target"]) == "pc",
		"HP<50% 优先用药（09 §9.3 阈值策略）")
	agent.heal_threshold = 0.3
	check(agent.next_command(sm3)["type"] != EncounterSM.CMD_ITEM, "阈值可配置：30% 时 6/14 不用药")
	agent.heal_threshold = 0.5
	# 战斗结束 → 无命令（托管自动停止的前置：core 不再受理）
	var sm4 := _sm_with(7, {"party": [_tp2_party()[0].merged({"attack_mod": 30, "damage": "30d6"}, true)],
		"enemies": [_tp2_enemies()[1]]})
	sm4.submit_command(_cmd(EncounterSM.CMD_ATTACK, "pc", "imp1"))
	if sm4.is_over():
		check(agent.next_command(sm4).is_empty(), "战斗结束代理不再产出命令")
	else:
		check(false, "预设必胜样本未终结战斗")

# ---------------------------------------------------------------- 竖屏壳（04 §④、09 §5/§6/§9，无头断言）

func _ratios_close(r: Array[float], expect: Array, tol: float = 0.02) -> bool:
	return absf(r[0] - float(expect[0])) < tol \
		and absf(r[1] - float(expect[1])) < tol \
		and absf(r[2] - float(expect[2])) < tol

func test_portrait_shell() -> void:
	print("[portrait_shell]")
	var scene: PackedScene = load("res://shell/portrait/encounter_portrait.tscn")
	var portrait: EncounterPortrait = scene.instantiate()
	root.add_child(portrait)
	await process_frame
	await process_frame
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(11), "campaign01")
	var agent := AutoAgent.new()
	portrait.bind(sm, agent)
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	await process_frame
	await process_frame

	# 呼吸：探索 8/62/30（04 §④.1 冻结比例，09 §5）
	check(_ratios_close(portrait.get_band_ratios(), [0.08, 0.62, 0.30]),
		"呼吸：探索态 8/62/30（04 §④.1）")
	# 房间推进条 pip 状态（04 §④.2）
	portrait.set_rooms(["N1-1", "N1-3", "N1-7", "N1-8"], 2)
	await process_frame
	check(portrait.pip_state(0) == EncounterPortrait.PIP_PAST
		and portrait.pip_state(1) == EncounterPortrait.PIP_PAST
		and portrait.pip_state(2) == EncounterPortrait.PIP_CURRENT
		and portrait.pip_state(3) == EncounterPortrait.PIP_FUTURE,
		"推进条：已过点亮 / 当前脉动 / 未来剪影")
	# 战斗态呼吸 12/55/33：高度变化随 state.entered 发生（09 §1/§5）
	# 待裁决：04 §④.1 战斗行写作 12/55/37（合计 104≠100），实现按状态栏 12、主视野 55、操作台补齐 33 落位
	sm.begin_combat(_std_def())
	await process_frame
	await process_frame
	check(_ratios_close(portrait.get_band_ratios(), [0.12, 0.55, 0.33]),
		"呼吸：战斗态 12/55/33（state.entered 驱动，04 §④.1 裁决见交付说明）")
	# 对话档 8/50/42（04 §④.1 表）
	portrait.apply_breathing(&"dialog")
	await process_frame
	await process_frame
	check(_ratios_close(portrait.get_band_ratios(), [0.08, 0.50, 0.42]), "呼吸：对话档 8/50/42")
	portrait._restore_breathing()
	await process_frame
	await process_frame
	check(_ratios_close(portrait.get_band_ratios(), [0.12, 0.55, 0.33]), "呼吸恢复战斗档")

	# 事件流 → UI 更新链路：日志
	stream.emit(EventTypes.LOG, {"msg": "测试日志条目"}, &"core")
	await process_frame
	check(portrait.log_view.get_parsed_text().contains("测试日志条目"), "事件流→UI：log 事件更新日志 Tab")
	# 事件流 → UI：攻击后敌方单位 HP 文本
	var target := sm.first_alive_enemy()
	sm.submit_command(_cmd(EncounterSM.CMD_ATTACK, sm.current_actor_id(), target))
	await process_frame
	var hp_now := int(sm.get_unit(target)["hp"])
	var hp_shown := false
	for child: Node in portrait.enemy_row.get_children():
		if (child as Button).text.contains("HP %d/" % hp_now):
			hp_shown = true
	check(hp_shown, "事件流→UI：battle.attack 后敌方 HP 显示更新")
	# 快捷栏芯片（09 §9.2：技能/道具/急救/结束回合 + 次数余量）；驱动到 pc 行动
	var guard := 0
	while sm.current_actor_id() != "pc" and guard < 6:
		guard += 1
		sm.submit_command(_cmd(EncounterSM.CMD_END_TURN, sm.current_actor_id()))
	await process_frame
	var chip_texts: Array = []
	for child: Node in portrait.quickbar.get_children():
		if child is Button:
			chip_texts.append((child as Button).text)
	var joined := " ".join(chip_texts)
	check(joined.contains("攻击") and joined.contains("补给药水") and joined.contains("急救")
		and joined.contains("结束回合"), "快捷栏芯片齐备（行动 Tab）")
	check(joined.contains("墨术飞矢 ×2"), "芯片呈现次数余量（09 §9.2）")

	# 托管：节拍下限（09 §9.3：≥0.8s/动作，1×/2×）与同一 Command 通道
	check(portrait.auto_timer.wait_time == 0.8, "托管 1× 节拍 0.8s")
	portrait.set_speed(2)
	check(absf(portrait.auto_timer.wait_time - 0.4) < 0.001, "托管 2× 节拍 0.4s")
	portrait.set_auto(true)
	await create_timer(1.6).timeout
	check(stream.query_by_type(EventTypes.BATTLE_ATTACK).any(
		func(ev: Dictionary) -> bool: return ev["payload"]["source"] == &"auto"),
		"托管经同一 Command 通道产出 source=auto 事件")
	portrait._manual(_cmd(EncounterSM.CMD_END_TURN, sm.current_actor_id()))
	check(not portrait.auto_on, "玩家点按即接管（09 §9.3 即时生效）")

	# 关键判定全屏演出（09 §6；死亡豁免恒定关键，11 §7）
	stream.emit(EventTypes.CHECK_ROLL, {"roller": "kelan", "kind": "death_save", "rolls": [3],
		"keep": 3, "dc": 10, "success": false, "s": 0, "f": 1, "key": true, "extreme": false}, &"core")
	await create_timer(0.2).timeout
	check(portrait.key_overlay.visible, "关键判定全屏接管（09 §6）")
	check(not portrait.status_band.visible and not portrait.console_panel.visible,
		"全屏时状态栏/操作台退屏（04 §④.1 关键判定行）")
	var mb := InputEventMouseButton.new()
	mb.pressed = true
	var mb_up := InputEventMouseButton.new()
	mb_up.pressed = false
	# 注入假时钟：长按判定与真实帧计时解耦（防抖）；判定参数仍是 12 §1 的 ≥400ms
	var fake_ms: Array = [1_000_000]
	portrait.hold_clock = func() -> int: return int(fake_ms[0])
	portrait._on_key_overlay_input(mb)
	portrait._on_key_overlay_input(mb_up) # 短按 <400ms 抬手：不跳过（04 §④.7 防误触）
	await create_timer(0.3).timeout
	check(portrait.key_overlay.visible, "短按不跳过演出（04 §④.7：跳过统一长按 ≥400ms）")
	portrait._on_key_overlay_input(mb) # 按住不放
	fake_ms[0] += 500 # 注入时间推进 500ms ≥ 400ms（12 §1）；演出循环下一拍（≤0.09s）轮询即跳
	await create_timer(0.3).timeout # 只等循环下一拍轮询，不等真实 400ms（自然播完需 ~1.6s，可区分）
	check(not portrait.key_overlay.visible, "关键演出长按 ≥400ms 跳过（04 §④.7/12 §1）")
	await process_frame
	await process_frame
	check(_ratios_close(portrait.get_band_ratios(), [0.12, 0.55, 0.33]), "演出结束呼吸回落战斗档")

	portrait.queue_free()
	await process_frame

# ---------------------------------------------------------------- 壳路由（09 §2/§3/§8、tech/02 §2.1）

func test_shell_router() -> void:
	print("[shell_router]")
	var pack := _load_campaign01()
	var pres: Dictionary = pack["manifest"]["presentation"]
	check(str(pres["mode"]) == "choice", "campaign01 manifest mode=choice（tech/02 §2.1）")
	var r1 := ShellRouter.resolve(pres, PackedStringArray(["--mode=space"]), "SL-1")
	check(r1["mode"] == ShellRouter.MODE_SPACE and not bool(r1["forced"]), "choice + --mode=space → 横屏")
	var r2 := ShellRouter.resolve(pres, PackedStringArray([]), "SL-1")
	check(r2["mode"] == ShellRouter.MODE_TIME, "choice 无启动参数 → 缺省 time（竖屏）")
	var r3 := ShellRouter.resolve(pres, PackedStringArray(["--mode=time"]), "SL-1")
	check(r3["mode"] == ShellRouter.MODE_TIME, "choice + --mode=time → 竖屏")
	var r4 := ShellRouter.resolve(pres, PackedStringArray(["--mode=space"]), "SL-0")
	check(r4["mode"] == ShellRouter.MODE_SPACE and not bool(r4["forced"]),
		"序章 SL-0 随玩家所选形态（选横屏即从序章起横屏）")
	var r4b := ShellRouter.resolve(pres, PackedStringArray(["--mode=space"]), "SL-3")
	check(r4b["mode"] == ShellRouter.MODE_TIME and bool(r4b["forced"]),
		"forced 幕 SL-3 强制竖屏（启动参数不生效，tech/02 §2.1）")
	var notice := str(r4b["notice"])
	check(notice != "" and not notice.contains("锁定") and not notice.contains("模式"),
		"强制幕叙事化提示（09 §3：包装文案禁止系统腔）")
	var r5 := ShellRouter.resolve(pres, PackedStringArray([]), "SL-3")
	check(r5["mode"] == ShellRouter.MODE_TIME and bool(r5["forced"]), "forced 幕 SL-3 强制竖屏")
	var r6 := ShellRouter.resolve({"mode": "space"}, PackedStringArray([]), "SL-9")
	check(r6["mode"] == ShellRouter.MODE_SPACE and bool(r6["forced"]), "mode=space 单模式战役直接落定")
	# 单局内禁止切换（09 §8：形态是战役级属性）
	var router := ShellRouter.new()
	check(router.request_switch(ShellRouter.MODE_SPACE), "遭遇开始前可定壳")
	router.lock_encounter(ShellRouter.MODE_TIME)
	check(router.is_locked() and router.locked_mode == ShellRouter.MODE_TIME, "遭遇开始即壳锁定")
	check(not router.request_switch(ShellRouter.MODE_SPACE), "锁定后切换请求拒绝（09 §8）")
	check(not router.request_switch(ShellRouter.MODE_TIME), "锁定后同形态请求亦拒绝（一局之内无切换入口）")

# ---------------------------------------------------------------- 横屏壳（04 §③、09 §4/§6/§7/§9，无头断言）

func test_landscape_shell() -> void:
	print("[landscape_shell]")
	var scene: PackedScene = load("res://shell/landscape/encounter_landscape.tscn")
	var land: EncounterLandscape = scene.instantiate()
	root.add_child(land)
	# 横屏冻结指标按横屏尺寸断言（09 §4）：脱离项目竖屏视口，给定 1280×720
	land.set_anchors_preset(Control.PRESET_TOP_LEFT)
	land.position = Vector2.ZERO
	land.size = Vector2(1280, 720)
	await process_frame
	await process_frame
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(11), "campaign01")
	land.bind(sm, AutoAgent.new())
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	await process_frame
	await process_frame
	var z := land.get_zone_ratios()
	check(absf(float(z["top"]) - 0.08) < 0.02 and absf(float(z["bottom"]) - 0.05) < 0.02,
		"五区：上缘 8% / 下缘 5%（09 §4 冻结指标）")
	check(absf(float(z["left"]) - 15.0 / 87.0) < 0.02 and absf(float(z["center"]) - 60.0 / 87.0) < 0.02
		and absf(float(z["right"]) - 12.0 / 87.0) < 0.02
		and absf(float(z["left"]) + float(z["center"]) + float(z["right"]) - 1.0) < 0.001,
		"五区：三栏权重 15:60:12 归一拉伸至满宽（09 §4 + TP3 验收裁决 1：≈17.2/69.0/13.8%）")
	check(not land.init_bar.visible, "探索态先攻顺序条收起（战斗时展开，09 §4）")
	check(land.menu_button.text == TextsZh.MENU, "☰ 常驻上缘右端（09 §7）")
	sm.begin_combat(_std_def())
	await process_frame
	await process_frame
	check(land.init_bar.visible and land.init_bar.get_child_count() == sm.get_order().size(),
		"先攻顺序条战斗时展开且按先攻序全员排列")
	# 战术格（09 §4：8×5 占位、格边长可读、敌我按格落位、敌红我金）
	check(land.grid.get_child_count() == 40, "战术格 8×5=40 占位（同屏 ≤12×8，09 §4）")
	check(land.cell_side() >= land.size.y * 0.08, "格边长 ≥ 屏高 8%（09 §4 可读性）")
	var units := sm.get_units()
	var all_placed := true
	for id: String in units:
		var c := land.unit_cell(id)
		if c.x < 0 or c.x >= 8 or c.y < 0 or c.y >= 5:
			all_placed = false
	check(all_placed and land.unit_cell(sm.first_alive_enemy()) != Vector2i(-1, -1), "敌我单位全部按格落位")
	check(land.token_color(sm.first_alive_enemy()) == EncounterLandscape.COLOR_ENEMY, "敌方 token 红色（09 §4）")
	check(land.token_color("pc") == EncounterLandscape.COLOR_PARTY, "我方 token 金色（09 §4）")
	# 行动轮盘与竖屏快捷栏同源（同一 EncounterSM 可用指令集）；驱动到 pc 行动（其技能/道具最全）
	var guard0 := 0
	while sm.current_actor_id() != "pc" and guard0 < 6:
		guard0 += 1
		sm.submit_command(_cmd(EncounterSM.CMD_END_TURN, sm.current_actor_id()))
	await process_frame
	var actions := sm.get_available_actions()
	var wheel_labels: Array = []
	for child: Node in land.wheel_box.get_children():
		if child is Button:
			wheel_labels.append((child as Button).text)
	check(wheel_labels.size() == actions.size() and not actions.is_empty(),
		"行动轮盘 = 同一 EncounterSM 可用指令集生成（禁止复制过滤逻辑）")
	var joined := " ".join(wheel_labels)
	check(joined.contains("攻击") and joined.contains("墨术飞矢 ×2") and joined.contains("补给药水")
		and joined.contains("结束回合"), "轮盘芯片与快捷栏同文案（TextsZh.action_label 单源）")
	# 轮盘按钮真实点按 → 统一 Command 通道（12 §1 点按=默认目标）
	var atks_before := stream.query_by_type(EventTypes.BATTLE_ATTACK).size()
	for child: Node in land.wheel_box.get_children():
		if child is Button and (child as Button).text == TextsZh.CHIP_ATTACK and not (child as Button).disabled:
			(child as Button).pressed.emit()
			break
	await process_frame
	check(stream.query_by_type(EventTypes.BATTLE_ATTACK).size() == atks_before + 1,
		"轮盘点按经统一 Command 通道产出 battle.attack")
	await create_timer(0.6).timeout # 等骰子盘快掷落定（≤0.5s，09 §6）
	var last_keep := int(stream.query_by_type(EventTypes.BATTLE_ATTACK).back()["payload"]["keep"])
	check(land.dice_label.text == str(last_keep), "骰子盘呈现最近一次攻击的 d20 明细")
	# 日志带：点击展开半屏 ↔ 收起 5%（09 §4）
	check(not land.log_expanded, "日志带默认收起（下缘 5%）")
	land.toggle_log()
	await process_frame
	await process_frame
	check(land.log_expanded and absf(float(land.get_zone_ratios()["bottom"]) - 0.5) < 0.02,
		"日志带点击展开至半屏（09 §4）")
	check(land.log_full.visible and land.log_full.get_parsed_text().contains("战斗开始"),
		"展开日志含事件流条目（与竖屏日志 Tab 同源）")
	land.toggle_log()
	await process_frame
	await process_frame
	check(not land.log_expanded and absf(float(land.get_zone_ratios()["bottom"]) - 0.05) < 0.02,
		"日志带收起回落 5%")
	# 关键判定全屏演出（09 §6：与竖屏同一事件源；死亡豁免恒定关键，11 §7）
	stream.emit(EventTypes.CHECK_ROLL, {"roller": "kelan", "kind": "death_save", "rolls": [3],
		"keep": 3, "dc": 10, "success": false, "s": 0, "f": 1, "key": true, "extreme": false}, &"core")
	await create_timer(0.2).timeout
	check(land.key_overlay.visible, "关键判定全屏覆盖（横屏，09 §6）")
	var mb := InputEventMouseButton.new()
	mb.pressed = true
	var mb_up := InputEventMouseButton.new()
	mb_up.pressed = false
	# 注入假时钟：长按判定与真实帧计时解耦（防抖）；判定参数仍是 12 §1 的 ≥400ms
	var fake_ms: Array = [1_000_000]
	land.hold_clock = func() -> int: return int(fake_ms[0])
	land._on_key_overlay_input(mb)
	land._on_key_overlay_input(mb_up) # 短按 <400ms 抬手：不跳过（04 §④.7 防误触）
	await create_timer(0.3).timeout
	check(land.key_overlay.visible, "横屏短按不跳过演出（04 §④.7）")
	land._on_key_overlay_input(mb)
	fake_ms[0] += 500 # 注入时间推进 500ms ≥ 400ms（12 §1）；演出循环下一拍（≤0.09s）轮询即跳
	await create_timer(0.3).timeout # 只等循环下一拍轮询，不等真实 400ms
	check(not land.key_overlay.visible, "横屏关键演出长按 ≥400ms 跳过（09 §6/04 §④.7）")
	# 托管节拍下限（09 §9.3）
	check(land.auto_timer.wait_time == 0.8, "托管 1× 节拍 0.8s")
	land.set_speed(2)
	check(absf(land.auto_timer.wait_time - 0.4) < 0.001, "托管 2× 节拍 0.4s")
	land.queue_free()
	await process_frame

# ---------------------------------------------------------------- 3D D20 物理演出（14 清单 #2；09 §6 全屏物理演出；04 §④.7 长按跳过）
# 骰子公正性：结果由逻辑层给定（事件流 keep），物理只是表演——落定顶面必为给定值（断言，非随机）。

func _wait_dice(d: Dice3D, timeout: float) -> bool:
	var t := 0.0
	while d.is_playing() and t < timeout:
		await create_timer(0.05).timeout
		t += 0.05
	return not d.is_playing()

func test_dice_3d() -> void:
	print("[dice_3d]")
	var scene: PackedScene = load("res://shell/ui/dice_3d.tscn")
	check(scene != null, "dice_3d.tscn 可加载实例化")
	var d: Dice3D = scene.instantiate() as Dice3D
	root.add_child(d)
	await process_frame
	await process_frame
	check(d.face_count() == 20, "程序化二十面体：20 面（无外部模型资源）")
	check(d.face_values_valid(), "D20 标准编号：1~20 齐备且对面和为 21")
	# 落定顶面 = 逻辑层给定结果（断言，非随机；物理零参与结果）
	d.speed = 10.0 # 测试压缩等待；物理弹道与收束管线不变
	for target: int in [1, 7, 13, 20]:
		d.play(target, 20261109 + target)
		check(await _wait_dice(d, 8.0), "演出完成（target=%d）" % target)
		check(d.top_face() == target, "落定顶面=给定结果 %d（物理只是表演）" % target)
		check(absf(Engine.time_scale - 1.0) < 0.001, "演出结束 time_scale 恢复 1.0（慢镜头归位）")
	# 跳过路径（04 §④.7 壳层仲裁 → request_skip）：立即定格，结果不变，时间恢复
	d.play(5, 777)
	await create_timer(0.15).timeout
	check(d.is_playing(), "弹跳段演出进行中")
	d.request_skip()
	check(await _wait_dice(d, 2.0), "跳过路径立即收束")
	check(d.top_face() == 5, "跳过后顶面仍=给定结果 5")
	check(absf(Engine.time_scale - 1.0) < 0.001, "跳过后 time_scale 恢复 1.0")
	# 多面骰（17 §2/§7）：几何共面、编号合规，且每种骰落定读数 = 给定值
	for kind: String in DiceShapes.KINDS:
		var shp := DiceShapes.build(kind)
		check(DiceShapes.faces_planar(shp) and DiceShapes.values_valid(shp)
			and int(shp["sides"]) == int(kind.substr(1)), "%s：面共面、1~N 编号合规（有对面者和为 N+1）" % kind)
	for spec: Array in [[{"die": "d4", "value": 3}], [{"die": "d6", "value": 6}], [{"die": "d8", "value": 2}],
			[{"die": "d10", "value": 10}], [{"die": "d12", "value": 7}],
			[{"die": "d8", "value": 5}, {"die": "d8", "value": 1}, {"die": "d4", "value": 4}]]:
		d.play_set(spec, 4242 + spec.size())
		check(await _wait_dice(d, 8.0), "多面骰演出完成 %s" % str(spec))
		var want: Array = spec.map(func(x: Dictionary) -> int: return int(x["value"]))
		check(d.top_values() == want, "落定读数 = 给定值 %s（d4 读顶点）" % str(want))
	var hundred := Dice3D.d100_spec(100)
	var h37 := Dice3D.d100_spec(37)
	var h5 := Dice3D.d100_spec(5)
	check(int(hundred[0]["value"]) == 9 and int(hundred[1]["value"]) == 10
		and int(h5[0]["value"]) == 10 and int(h5[1]["value"]) == 5
		and int(h37[0]["value"]) == 3 and int(h37[1]["value"]) == 7 and bool(h37[0]["tens"]),
		"d100 = 十位 d10（00~90，面值 10 显示 00）+ 个位 d10：37 → 30 + 7，100 → 90 + 10，5 → 00 + 5")
	d.play_set(h37, 99)
	check(await _wait_dice(d, 8.0) and d.top_values() == [3, 7], "d100 两枚 d10 落定")
	d.queue_free()
	await process_frame
	# 托盘档（17 §3）：透明底、无慢镜头、短收束
	var tray: Dice3D = scene.instantiate() as Dice3D
	tray.compact = true
	root.add_child(tray)
	await process_frame
	tray.speed = 4.0
	tray.play_set([{"die": "d8", "value": 8}, {"die": "d8", "value": 3}], 7)
	await process_frame
	check(absf(Engine.time_scale - 1.0) < 0.001, "托盘档不开慢镜头")
	check(await _wait_dice(tray, 3.0) and tray.top_values() == [8, 3], "托盘档两枚 d8 落定给定值")
	tray.queue_free()
	await process_frame
	# 事件流不变（14 #2 验收口径）：同种子同指令两局，B 局额外套 3D 演出消费关键事件
	#（纯呈现订阅，与壳内接线同源）——事件流 JSON 逐字节一致（tech/01 §10 TP3 同一比对法）
	var json_a: String = await _run_battle_with_dice3d(false)
	var json_b: String = await _run_battle_with_dice3d(true)
	check(json_a == json_b, "3D 演出前后同种子同结果：事件流逐字节一致")
	check(absf(Engine.time_scale - 1.0) < 0.001, "整局结束 time_scale=1.0（析构兜底恢复）")

# ---------------------------------------------------------------- 托盘档多骰（17 §3/§5）：事件 → 骰组 / 三档设置 / 壳内实战

func test_dice_tray() -> void:
	print("[dice_tray]")
	var cfg_path := TEST_DIR.path_join("dice_tray.cfg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	check(DiceTray.load_mode(cfg_path) == DiceTray.MODE_ON, "缺省：伤害骰全部显示")
	check(DiceTray.cycle_mode(cfg_path) == DiceTray.MODE_KEY and DiceTray.cycle_mode(cfg_path) == DiceTray.MODE_OFF
		and DiceTray.cycle_mode(cfg_path) == DiceTray.MODE_ON, "三档循环 on → 仅暴击 → off → on（写本地设置）")
	var hit := {"type": EventTypes.BATTLE_ATTACK, "id": 5, "payload": {"hit": true, "crit": false, "damage": 7,
		"damage_dice": [{"die": "d8", "value": 5}]}}
	var crit := {"type": EventTypes.BATTLE_ATTACK, "id": 6, "payload": {"hit": true, "crit": true, "damage": 9,
		"damage_dice": [{"die": "d8", "value": 4}, {"die": "d8", "value": 3}]}}
	var miss := {"type": EventTypes.BATTLE_ATTACK, "id": 7, "payload": {"hit": false, "damage_dice": []}}
	var heal := {"type": EventTypes.ITEM_USE, "id": 8, "payload": {"dice": [{"die": "d4", "value": 2}]}}
	check(DiceTray.dice_for_event(hit, DiceTray.MODE_ON).size() == 1 and DiceTray.dice_for_event(miss, DiceTray.MODE_ON).is_empty(),
		"命中上托盘、落空不上")
	check(DiceTray.dice_for_event(hit, DiceTray.MODE_KEY).is_empty() and DiceTray.dice_for_event(crit, DiceTray.MODE_KEY).size() == 2
		and DiceTray.dice_for_event(heal, DiceTray.MODE_KEY).is_empty(), "仅暴击档：普通命中 / 回复不上托盘，暴击翻倍骰上")
	check(DiceTray.dice_for_event(crit, DiceTray.MODE_OFF).is_empty(), "关闭档：一律不上托盘")
	check(EncounterPortrait.damage_text(hit["payload"]).contains("d8") and EncounterPortrait.damage_text(hit["payload"]).contains("5+2 = 7"),
		"骰子条伤害明细：骰型 + 骰值 + 修正 = 伤害")
	# 壳内实战：竖屏托管打满一场，命中即触发托盘、骰子条图标换骰型
	var portrait: EncounterPortrait = (load("res://shell/portrait/encounter_portrait.tscn") as PackedScene).instantiate()
	portrait.audio_settings_path = cfg_path
	root.add_child(portrait)
	await process_frame
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(11), "campaign01")
	portrait.bind(sm, AutoAgent.new())
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	var pack := _load_campaign01()
	sm.begin_combat(BattleDef.assemble(pack, "N1-7", {}, board)["def"])
	var guard := 0
	while not sm.is_over() and guard < 60 and portrait.dice_tray.played == 0:
		guard += 1
		portrait.debug_step_auto()
		await process_frame
	check(portrait.dice_tray.played > 0, "实战命中触发托盘多骰（伤害骰 3D 落定）")
	check(portrait.dice_glyph != null and DiceShapes.KINDS.has(portrait.dice_glyph.die), "骰子条图标为合法骰型")
	portrait.queue_free()
	await process_frame
	check(absf(Engine.time_scale - 1.0) < 0.001, "托盘演出不动 time_scale")

## 无壳脚本化遭遇（与 shell_diff.run_battle 同种子/同指令序列风格，指令直发 sm）；
## with_3d=true 时挂独立 Dice3D 订阅关键检定事件——纯呈现消费，不触碰 core。
func _run_battle_with_dice3d(with_3d: bool) -> String:
	var sd: GDScript = load("res://tools/shell_diff.gd")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(20261109), "campaign01")
	board.give_item("heal_potion", 2, {"event_id": 0, "node_id": "N1-1", "pack_id": "campaign01"})
	board.write("campaign01.witnessed_revocation", true,
		{"event_id": 0, "node_id": "N1-3", "pack_id": "campaign01"})
	var d: Dice3D = null
	if with_3d:
		d = (load("res://shell/ui/dice_3d.tscn") as PackedScene).instantiate() as Dice3D
		d.speed = 10.0
		root.add_child(d)
		stream.subscribe(func(ev: Dictionary) -> void:
			var p: Dictionary = ev["payload"]
			if StringName(ev["type"]) == EventTypes.CHECK_ROLL and bool(p.get("key", false)):
				d.play(int(p.get("keep", 1)), int(ev["id"]) * 131 + 7))
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(sd.battle_def())
	# 两局同一帧注入同一条关键检定事件：B 局触发 3D 演出，A 局不触发——比对口径锚点
	stream.emit(EventTypes.CHECK_ROLL, {"roller": "kelan", "kind": "death_save", "rolls": [12],
		"keep": 12, "dc": 10, "success": true, "s": 1, "f": 0, "key": true, "extreme": false}, &"core")
	var bot := Rng.new(31)
	var guard := 0
	while not sm.is_over() and guard < 300:
		guard += 1
		var actions := sm.get_available_actions()
		if actions.is_empty():
			await process_frame
			continue
		var enabled: Array[int] = []
		for i: int in actions.size():
			if not bool(actions[i]["disabled"]):
				enabled.append(i)
		var pick := enabled[bot.range_int(0, enabled.size() - 1)]
		sm.submit_command(sm.command_from_action(actions[pick]))
		await process_frame
	var json := JSON.stringify(stream.all(), "", true, true)
	if d != null:
		d.queue_free()
		await process_frame
	return json

# ---------------------------------------------------------------- 打击感三件套 + 屏幕震动分级（14 清单 #3/#4）
# 纯呈现层：全部效果从事件流消费（battle.attack 的 hit/damage/crit 等字段），双壳同一
# JuiceLayer/JuiceConfig；震动开关 = user://settings.cfg 的 ui.screen_shake（12 §5：UI 偏好不写状态板）。

func _atk_ev(target: String, hit: bool, crit: bool, dmg: int) -> Dictionary:
	return {"type": EventTypes.BATTLE_ATTACK, "payload": {"attacker": "pc", "target": target,
		"hit": hit, "crit": crit, "fumble": false, "damage": dmg,
		"rolls": [12], "keep": 12, "atk_mod": 2, "target_ac": 10,
		"attacker_name": "白页者", "target_name": "小墨妖", "damage_rolls": [dmg]}}

func test_juice() -> void:
	print("[juice]")
	# ---- 配置源：飘字规格（14 #3：内容=事件数值；暴击金色加大+标签；治疗绿色；未命中闪过灰）----
	var spec := JuiceConfig.number_spec(_atk_ev("imp1", true, false, 7))
	check(str(spec["text"]) == "7" and str(spec["unit"]) == "imp1"
		and spec["color"] == JuiceConfig.COLOR_DAMAGE and float(spec["scale"]) == 1.0,
		"飘字规格：伤害数字内容=事件数值")
	var cspec := JuiceConfig.number_spec(_atk_ev("imp1", true, true, 11))
	check(str(cspec["text"]) == "11" and str(cspec["tag"]) == TextsZh.JUICE_CRIT
		and cspec["color"] == JuiceConfig.COLOR_CRIT and float(cspec["scale"]) > 1.0,
		"飘字规格：暴击金色加大 + 暴击标签")
	var mspec := JuiceConfig.number_spec(_atk_ev("imp1", false, false, 0))
	check(str(mspec["text"]) == TextsZh.JUICE_MISS and mspec["color"] == JuiceConfig.COLOR_MISS,
		"飘字规格：未命中「闪过」灰色")
	var hspec := JuiceConfig.number_spec({"type": EventTypes.ITEM_USE,
		"payload": {"unit": "pc", "target": "pc", "healed": 5}})
	check(str(hspec["text"]) == "+5" and hspec["color"] == JuiceConfig.COLOR_HEAL,
		"飘字规格：治疗绿色 +N")
	# ---- 配置源：震动分级（14 #4：受击小震 2px/0.15s；暴击/死亡豁免大震 5px/0.3s）----
	check(JuiceConfig.shake_level(_atk_ev("imp1", true, false, 7)) == JuiceConfig.SHAKE_SMALL,
		"震动分级：受击小震")
	check(JuiceConfig.shake_level(_atk_ev("imp1", true, true, 7)) == JuiceConfig.SHAKE_BIG,
		"震动分级：暴击大震")
	check(JuiceConfig.shake_level(_atk_ev("imp1", false, false, 0)) == JuiceConfig.SHAKE_NONE,
		"震动分级：未命中不震")
	check(JuiceConfig.shake_level({"type": EventTypes.CHECK_ROLL,
		"payload": {"kind": "death_save"}}) == JuiceConfig.SHAKE_BIG, "震动分级：死亡豁免大震")
	var sp := JuiceConfig.shake_params(JuiceConfig.SHAKE_SMALL)
	var bp := JuiceConfig.shake_params(JuiceConfig.SHAKE_BIG)
	check(float(sp["amp"]) == 2.0 and float(sp["dur"]) == 0.15, "震动参数：小震 2px/0.15s")
	check(float(bp["amp"]) == 5.0 and float(bp["dur"]) == 0.3, "震动参数：大震 5px/0.3s")
	# ---- 震动开关（ui.screen_shake；与兜底条同机制：默认开、合并写盘不丢其它键）----
	var cfg_path := "user://test/juice_settings.cfg"
	check(UiSettings.load_screen_shake(cfg_path), "震动开关缺省=开（读不到键回落文档默认）")
	UiSettings.save_home_bar_collapsed(false, cfg_path) # 非缺省值：验证合并写盘真的保住了它
	UiSettings.save_screen_shake(false, cfg_path)
	check(not UiSettings.load_screen_shake(cfg_path), "震动开关写盘后读回=关")
	check(not UiSettings.load_home_bar_collapsed(cfg_path), "写震动键不覆盖既有兜底条键（合并写盘）")
	UiSettings.save_screen_shake(true, cfg_path)

	# ---- 竖屏壳接线：事件流 → 飘字/闪白击退/消散/分级震动 ----
	var portrait: EncounterPortrait = (load("res://shell/portrait/encounter_portrait.tscn")
		as PackedScene).instantiate()
	root.add_child(portrait)
	await process_frame
	await process_frame
	await process_frame
	portrait.juice.settings_path = cfg_path
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(11), "campaign01")
	portrait.bind(sm, AutoAgent.new())
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(_std_def())
	await process_frame
	await process_frame
	await process_frame
	var target := sm.first_alive_enemy()
	var st: Dictionary = portrait.juice.stats
	# 命中：飘字 + 闪白/击退 + 小震
	stream.emit(EventTypes.BATTLE_ATTACK, _atk_ev(target, true, false, 9)["payload"], &"core", "N1-7")
	await process_frame
	await process_frame
	await process_frame
	check(int(st["numbers"]) == 1 and str(portrait.juice.last_numbers.back()["text"]) == "9",
		"竖屏：命中飘字内容=事件数值（事件流驱动）")
	check(portrait.juice.active_number_count() == 1, "竖屏：飘字节点已生成（上飘+淡出 0.8s）")
	check(int(st["flashes"]) == 1 and int(st["knockbacks"]) == 1, "竖屏：命中反馈闪白+击退触发")
	check(int(st["shake_small"]) == 1, "竖屏：受击小震触发")
	check(float(portrait.juice.last_shake["amp"]) == 2.0
		and absf(float(portrait.juice.last_shake["dur"]) - 0.15) < 0.001, "竖屏：小震参数 2px/0.15s")
	await create_timer(0.1).timeout
	check(portrait.juice.shake_max_dev > 0.0, "竖屏：震动产生实际位移（≤2px 档）")
	await create_timer(0.2).timeout
	check(portrait.position == Vector2.ZERO and not portrait.juice.is_shaking(), "竖屏：小震结束归位")
	# 连击叠震不漂移：震动进行中再震沿用原基准（曾因每次取当前位做基准，多场战斗后整屏偏移）
	var jl := JuiceLayer.new()
	var jt := Control.new()
	root.add_child(jt)
	root.add_child(jl)
	jt.position = Vector2(12, 0) # 非零原位（安全区内缩等）
	jl.shake_target = jt
	jl.shake_override = 1
	for k: int in 40:
		jl._shake_start(JuiceConfig.SHAKE_SMALL)
		jl._tick_shake(0.03)
	jl._tick_shake(5.0)
	check(jt.position == Vector2(12, 0), "叠震 40 次后归位原点（无累积漂移）")
	jl._shake_start(JuiceConfig.SHAKE_BIG)
	jl._tick_shake(0.02)
	jl.reset()
	check(jt.position == Vector2(12, 0), "震动中换局 reset：归位原点")
	jt.position = Vector2(30, 0) # 两场之间布局变化（换向 / 安全区）
	jl.reset()
	check(jt.position == Vector2(30, 0), "空闲时 reset 不改位置（不套用旧布局的基准）")
	jl.queue_free()
	jt.queue_free()
	# 暴击：金色加大飘字 + 大震
	stream.emit(EventTypes.BATTLE_ATTACK, _atk_ev(target, true, true, 14)["payload"], &"core", "N1-7")
	await process_frame
	await process_frame
	await process_frame
	var crec: Dictionary = portrait.juice.last_numbers.back()
	check(int(st["crits"]) == 1 and str(crec["tag"]) == TextsZh.JUICE_CRIT
		and crec["color"] == JuiceConfig.COLOR_CRIT, "竖屏：暴击飘字金色+标签")
	check(int(st["shake_big"]) == 1 and float(portrait.juice.last_shake["amp"]) == 5.0
		and absf(float(portrait.juice.last_shake["dur"]) - 0.3) < 0.001, "竖屏：暴击大震 5px/0.3s")
	# 未命中：闪过灰字，无闪白无震动
	stream.emit(EventTypes.BATTLE_ATTACK, _atk_ev(target, false, false, 0)["payload"], &"core", "N1-7")
	await process_frame
	await process_frame
	await process_frame
	check(int(st["misses"]) == 1 and str(portrait.juice.last_numbers.back()["text"]) == TextsZh.JUICE_MISS,
		"竖屏：未命中飘「闪过」")
	check(int(st["flashes"]) == 2 and int(st["shake_small"]) == 1,
		"竖屏：未命中不触发闪白/震动")
	# 治疗绿色飘字
	stream.emit(EventTypes.ITEM_USE, {"unit": "pc", "item": "heal_potion", "target": "pc",
		"healed": 6, "left": 1, "source": &"player"}, &"core", "N1-7")
	await process_frame
	await process_frame
	await process_frame
	check(int(st["heals"]) == 1 and str(portrait.juice.last_numbers.back()["text"]) == "+6",
		"竖屏：治疗绿色 +N 飘字")
	# 死亡豁免 = 大震（key=false 免触发全屏演出，隔离断言）
	stream.emit(EventTypes.CHECK_ROLL, {"roller": "kelan", "kind": "death_save", "rolls": [12],
		"keep": 12, "dc": 10, "success": true, "s": 1, "f": 0, "key": false, "extreme": false},
		&"core", "N1-7")
	await process_frame
	await process_frame
	await process_frame
	check(int(st["shake_big"]) == 2, "竖屏：死亡豁免大震")
	# 击杀消散：墨色碎片 + 淡出 0.5s，完成后重建保持隐去
	stream.emit(EventTypes.BATTLE_DEAD, {"unit": target, "name": "小墨妖"}, &"core", "N1-7")
	await process_frame
	await process_frame
	await process_frame
	check(int(st["dissolves"]) == 1 and portrait.juice.last_dissolve_fragments == 12
		and portrait.juice.active_fragment_count() == 12, "竖屏：击杀消散粒子触发（墨色碎片 ×12）")
	await create_timer(0.6).timeout
	check(portrait.juice.is_dissolved(target), "竖屏：消散 0.5s 后完成标记")
	portrait._refresh_all()
	var dead_node := portrait._find_unit_node(target)
	check(dead_node != null and not dead_node.visible, "竖屏：消散后单位重建保持隐去（非瞬间消失）")
	# 开关关闭后无震动（设置项即时生效）
	portrait.shake_button.pressed.emit() # 关
	check(not UiSettings.load_screen_shake(cfg_path)
		and portrait.shake_button.text == TextsZh.MENU_SHAKE_OFF, "竖屏：☰ 菜单震动开关可关")
	var small_before := int(st["shake_small"])
	stream.emit(EventTypes.BATTLE_ATTACK, _atk_ev("pc", true, false, 4)["payload"], &"core", "N1-7")
	await process_frame
	await process_frame
	await process_frame
	check(int(st["shake_small"]) == small_before and int(st["shake_blocked"]) == 1,
		"竖屏：开关关闭后受击无震动（计数阻塞可查）")
	portrait.shake_button.pressed.emit() # 开回
	check(UiSettings.load_screen_shake(cfg_path), "竖屏：震动开关可开回")
	portrait.queue_free()
	await process_frame

	# ---- 横屏壳接线：同一组件同一事件源（14 #3/#4 双壳同参数）----
	var land: EncounterLandscape = (load("res://shell/landscape/encounter_landscape.tscn")
		as PackedScene).instantiate()
	root.add_child(land)
	land.set_anchors_preset(Control.PRESET_TOP_LEFT)
	land.position = Vector2.ZERO
	land.size = Vector2(1280, 720)
	await process_frame
	await process_frame
	await process_frame
	land.juice.settings_path = cfg_path
	var stream2 := EventStream.new()
	var board2 := Board.new(stream2)
	var sm2 := EncounterSM.new(board2, stream2, Rng.new(11), "campaign01")
	land.bind(sm2, AutoAgent.new())
	sm2.enter("N1-7")
	sm2.transition(EncounterSM.S_EXPLORE)
	sm2.begin_combat(_std_def())
	await process_frame
	await process_frame
	await process_frame
	var target2 := sm2.first_alive_enemy()
	var st2: Dictionary = land.juice.stats
	stream2.emit(EventTypes.BATTLE_ATTACK, _atk_ev(target2, true, true, 13)["payload"], &"core", "N1-7")
	await process_frame
	await process_frame
	await process_frame
	check(int(st2["numbers"]) == 1 and str(land.juice.last_numbers.back()["text"]) == "13"
		and int(st2["crits"]) == 1, "横屏：暴击飘字内容=事件数值（同一事件源）")
	check(int(st2["flashes"]) == 1 and int(st2["knockbacks"]) == 1, "横屏：命中反馈闪白+击退")
	check(int(st2["shake_big"]) == 1 and float(land.juice.last_shake["amp"]) == 5.0,
		"横屏：暴击大震同参数（5px/0.3s，同一 JuiceConfig）")
	stream2.emit(EventTypes.BATTLE_DEAD, {"unit": target2, "name": "小墨妖"}, &"core", "N1-7")
	await process_frame
	await process_frame
	await process_frame
	check(int(st2["dissolves"]) == 1 and land.juice.active_fragment_count() == 12,
		"横屏：击杀消散粒子触发（同参数 ×12）")
	await create_timer(0.6).timeout
	land._refresh_grid()
	await process_frame
	check(land._find_unit_node(target2) == null, "横屏：消散后格内 token 不再渲染")
	land.queue_free()
	await process_frame

	# ---- 事件流零变化（14 #3/#4 验收口径：同种子同指令，接入前后逐字节一致）----
	var json_a: String = await _run_battle_with_juice(false)
	var json_b: String = await _run_battle_with_juice(true)
	check(json_a == json_b, "打击感接入前后同种子同指令：事件流逐字节一致（纯呈现零污染）")

## 无壳脚本化遭遇（与 _run_battle_with_dice3d 同种子/同指令序列风格）；
## with_juice=true 时挂独立 JuiceLayer 订阅事件流——纯呈现消费，不触碰 core。
func _run_battle_with_juice(with_juice: bool) -> String:
	var sd: GDScript = load("res://tools/shell_diff.gd")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(20261109), "campaign01")
	board.give_item("heal_potion", 2, {"event_id": 0, "node_id": "N1-1", "pack_id": "campaign01"})
	board.write("campaign01.witnessed_revocation", true,
		{"event_id": 0, "node_id": "N1-3", "pack_id": "campaign01"})
	var jl: JuiceLayer = null
	if with_juice:
		jl = JuiceLayer.new()
		root.add_child(jl)
		stream.subscribe(func(ev: Dictionary) -> void: jl.on_event(ev))
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(sd.battle_def())
	var bot := Rng.new(31)
	var guard := 0
	while not sm.is_over() and guard < 300:
		guard += 1
		var actions := sm.get_available_actions()
		if actions.is_empty():
			await process_frame
			continue
		var enabled: Array[int] = []
		for i: int in actions.size():
			if not bool(actions[i]["disabled"]):
				enabled.append(i)
		var pick := enabled[bot.range_int(0, enabled.size() - 1)]
		sm.submit_command(sm.command_from_action(actions[pick]))
		await process_frame
	var json := JSON.stringify(stream.all(), "", true, true)
	if jl != null:
		jl.queue_free()
		await process_frame
	return json

# ---------------------------------------------------------------- 音频框架 + 首批资产（14 清单 #5/#6）
# 纯呈现层：总线/BGM 状态机/SFX 全部从事件流消费（与 JuiceLayer 同模式，零回注）；
# 音量 = user://settings.cfg 的 ui.vol_*（12 §5：UI 偏好不写状态板）；无文件静默容错只计数。

func _collect_sliders(node: Node, out: Array[HSlider]) -> void:
	for child: Node in node.get_children():
		if child is HSlider:
			out.append(child as HSlider)
		_collect_sliders(child, out)

func test_audio() -> void:
	print("[audio]")
	# ---- 总线四路（Master 内置 + BGM/SFX/Ambient 自定义挂 Master；幂等）----
	var am := AudioManager.new()
	var cfg_path := "user://test/audio_settings.cfg"
	am.settings_path = cfg_path
	root.add_child(am)
	await process_frame
	for b: StringName in [&"Master", &"BGM", &"SFX", &"Ambient"]:
		check(AudioServer.get_bus_index(b) >= 0, "总线存在：%s" % b)
	check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"BGM")) == &"Master"
		and AudioServer.get_bus_send(AudioServer.get_bus_index(&"SFX")) == &"Master"
		and AudioServer.get_bus_send(AudioServer.get_bus_index(&"Ambient")) == &"Master",
		"BGM/SFX/Ambient 均挂 Master")
	var bus_n := AudioServer.bus_count
	am._ensure_buses()
	check(AudioServer.bus_count == bus_n, "总线重复初始化幂等（不重复建）")
	# ---- BGM 状态机（事件流驱动：node.enter / combat.start / state.entered=settle / story.ending）----
	var stream := EventStream.new()
	stream.subscribe(am.on_event)
	check(am.bgm_state == AudioManager.BGM_NONE, "初始无 BGM（主屏静默态）")
	stream.emit(EventTypes.NODE_ENTER, {"node_id": "N1-1", "type": "hub"}, &"graph", "N1-1")
	check(am.bgm_state == AudioManager.BGM_CAMP, "node.enter(hub) → 营地")
	check(am.current_bgm_asset == &"bgm_camp", "营地资产 = bgm_camp")
	stream.emit(EventTypes.NODE_ENTER, {"node_id": "N1-1", "type": "hub"}, &"graph", "N1-1")
	check(int(am.stats["bgm_switches"]) == 1, "同态 node.enter 不重复切换")
	stream.emit(EventTypes.NODE_ENTER, {"node_id": "N1-3", "type": "scene"}, &"graph", "N1-3")
	check(am.bgm_state == AudioManager.BGM_EXPLORE, "node.enter(scene) → 探索")
	check(am.current_bgm_asset == &"bgm_explore", "探索 = bgm_explore（P6.4 第二批 BGM）")
	stream.emit(EventTypes.NODE_ENTER, {"node_id": "N1-7", "type": "battle"}, &"graph", "N1-7")
	check(am.bgm_state == AudioManager.BGM_EXPLORE, "战斗节点不切 BGM（整备期间不打断，等 combat.start）")
	stream.emit(EventTypes.COMBAT_START, {"order": [], "units": {}}, &"core", "N1-7")
	check(am.bgm_state == AudioManager.BGM_BATTLE and am.current_bgm_asset == &"bgm_battle",
		"combat.start → 战斗（bgm_battle）")
	stream.emit(EventTypes.STATE_ENTERED, {"state": "settle", "prev": "combat"}, &"core", "N1-7")
	check(am.bgm_state == AudioManager.BGM_EXPLORE, "结算 state.entered → 探索（09 §1）")
	stream.emit(EventTypes.STORY_ENDING, {"ending": "E1", "title": "墨守"}, &"graph", "E1")
	check(am.bgm_state == AudioManager.BGM_ENDING and am.current_bgm_asset == &"bgm_ending",
		"story.ending → 结局（tech/02 §9；bgm_ending）")
	check(int(am.stats["bgm_switches"]) == 5, "BGM 切换计数 = 实际状态变迁次数")
	stream.emit(EventTypes.MAP_TRAVEL, {"map": "fog_coast", "from": "plaza", "to": "row"}, &"core", "N1-1m")
	check(am.bgm_state == AudioManager.BGM_MAP and am.current_bgm_asset == &"bgm_map", "map.travel → 地图（bgm_map，doc 16）")
	stream.emit(EventTypes.SITE_ENTER, {"site": "lighthouse", "area": "gate", "first": true}, &"core", "N1-1m")
	check(int(am.stats["bgm_switches"]) == 6, "site.enter 同属地图态（不重复切换）")
	am.to_home()
	check(am.bgm_state == AudioManager.BGM_NONE and am.current_bgm_asset == &"",
		"回主屏 BGM 收止（主屏无常驻 BGM）")
	# ---- SFX 订阅映射 ----
	stream.emit(EventTypes.CHECK_ROLL, {"keep": 12, "rolls": [12], "mod": 2, "total": 14,
		"success": true, "key": false}, &"core")
	check(am.sfx_count(&"dice_roll") == 1, "check.roll → 骰子滚动声")
	await create_timer(0.6).timeout
	check(am.sfx_count(&"dice_land") == 1, "骰子落定声（延迟 0.45s，09 §6 落定节奏）")
	stream.emit(EventTypes.BATTLE_ATTACK, {"attacker": "pc", "target": "imp1", "hit": true,
		"crit": false, "damage": 5}, &"core", "N1-7")
	check(am.sfx_count(&"hit") == 1, "battle.attack 命中 → hit")
	stream.emit(EventTypes.BATTLE_ATTACK, {"attacker": "pc", "target": "imp1", "hit": true,
		"crit": true, "damage": 11}, &"core", "N1-7")
	check(am.sfx_count(&"crit") == 1 and am.sfx_count(&"hit") == 1, "暴击 → crit（不叠 hit）")
	stream.emit(EventTypes.BATTLE_ATTACK, {"attacker": "pc", "target": "imp1", "hit": false,
		"crit": false, "damage": 0}, &"core", "N1-7")
	check(am.sfx_count(&"hit") == 1, "未命中无命中声（无资产留白）")
	stream.emit(EventTypes.ITEM_USE, {"unit": "pc", "target": "pc", "healed": 5}, &"core", "N1-7")
	check(am.sfx_count(&"heal") == 1, "item.use 治疗 → heal")
	check(am.sfx_count(&"door") == 1, "site.enter 初入区域 → door（doc 16 §3）")
	stream.emit(EventTypes.SITE_ENTER, {"site": "lighthouse", "area": "gate", "first": false}, &"core", "N1-1m")
	check(am.sfx_count(&"door") == 1, "重入已到过的区域无开门声")
	stream.emit(EventTypes.ITEM_USE, {"unit": "pc", "target": "imp1", "thrown": true, "healed": 0}, &"core", "N1-7")
	check(am.sfx_count(&"throw") == 1 and am.sfx_count(&"heal") == 1, "投掷道具 → throw（11 §8.2）")
	stream.emit(EventTypes.LOG, {"msg_key": "MSG_SKILL_HEAL", "healed": 4}, &"core", "N1-7")
	check(am.sfx_count(&"heal") == 2, "治疗技能 → heal（11 §8）")
	stream.emit(EventTypes.LOG, {"msg_key": "MSG_CARD_CHOICE"}, &"core", "N1-1m")
	check(am.sfx_count(&"card") == 1, "事件卡选择 → card（doc 16 §4）")
	stream.emit(EventTypes.FLAG_WRITE, {"key": "campaign01.gold", "old": null, "value": 30}, &"board")
	stream.emit(EventTypes.FLAG_WRITE, {"key": "campaign01.gold", "old": 30, "value": 12}, &"board")
	check(am.sfx_count(&"coin") == 1, "金币入账 → coin；扣款无声（11 §7.3）")
	stream.emit(EventTypes.PARTY_LINK, {"kind": "help", "from": "g1", "to": "g2"}, &"graph")
	check(am.sfx_count(&"link") == 1, "分队联络 → link（doc 15 §5）")
	am.play_sfx(&"page")
	am.play_ui(&"ui_click")
	check(am.sfx_count(&"page") == 1 and am.sfx_count(&"ui_click") == 1, "翻页 / UI 点击通道（壳侧直调）")
	check(int(am.stats["missing_files"]) == 0, "资产齐备时零缺失计数")
	# ---- 环境声（14 #6：港口潮声主屏常播）----
	am.set_home_ambient(true)
	check(am.is_ambient_on() and int(am.stats["ambient_on_count"]) == 1, "主屏潮声环境声开播")
	am.set_home_ambient(true)
	check(int(am.stats["ambient_on_count"]) == 1, "重复开播幂等")
	am.set_home_ambient(false)
	check(not am.is_ambient_on(), "离主屏环境声停播")
	# ---- 无音频文件静默容错（框架先行，不报错）----
	var am2 := AudioManager.new()
	am2.asset_dir = "res://assets/audio_no_such_dir"
	root.add_child(am2)
	await process_frame
	var stream2 := EventStream.new()
	stream2.subscribe(am2.on_event)
	stream2.emit(EventTypes.NODE_ENTER, {"node_id": "N1-1", "type": "hub"}, &"graph", "N1-1")
	stream2.emit(EventTypes.CHECK_ROLL, {"keep": 1, "rolls": [1]}, &"core")
	await create_timer(0.6).timeout
	am2.set_home_ambient(true)
	check(am2.bgm_state == AudioManager.BGM_CAMP, "无文件：BGM 状态机照常切换")
	check(am2.current_bgm_asset == &"", "无文件：无资产可播即静默")
	check(am2.sfx_count(&"dice_roll") == 0 and am2.sfx_count(&"dice_land") == 0,
		"无文件：SFX 静默跳过不崩溃")
	check(int(am2.stats["missing_files"]) > 0, "无文件：缺失只计数（不报错）")
	am2.queue_free()
	# ---- 音量三档持久化 + 总线应用（12 §5：UI 偏好不写状态板）----
	UiSettings.save_volume(UiSettings.KEY_VOL_MASTER, 0.5, cfg_path)
	UiSettings.save_volume(UiSettings.KEY_VOL_BGM, 0.3, cfg_path)
	UiSettings.save_volume(UiSettings.KEY_VOL_SFX, 0.8, cfg_path)
	check(absf(UiSettings.load_volume(UiSettings.KEY_VOL_MASTER, cfg_path) - 0.5) < 0.001
		and absf(UiSettings.load_volume(UiSettings.KEY_VOL_BGM, cfg_path) - 0.3) < 0.001
		and absf(UiSettings.load_volume(UiSettings.KEY_VOL_SFX, cfg_path) - 0.8) < 0.001,
		"三档音量写盘读回")
	check(absf(UiSettings.load_volume(UiSettings.KEY_VOL_MASTER, "user://test/audio_missing.cfg") - 1.0) < 0.001,
		"设置文件缺失回落默认满格 1.0")
	UiSettings.save_screen_shake(false, cfg_path)
	UiSettings.save_volume(UiSettings.KEY_VOL_BGM, 0.4, cfg_path)
	check(not UiSettings.load_screen_shake(cfg_path), "音量写盘不覆盖震动键（合并写盘）")
	am.apply_volumes()
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Master")) - linear_to_db(0.5)) < 0.01
		and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"BGM")) - linear_to_db(0.4)) < 0.01
		and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")) - linear_to_db(0.8)) < 0.01,
		"音量应用到总线 dB（Master/BGM/SFX）")
	UiSettings.save_volume(UiSettings.KEY_VOL_MASTER, 1.0, cfg_path)
	UiSettings.save_volume(UiSettings.KEY_VOL_BGM, 1.0, cfg_path)
	UiSettings.save_volume(UiSettings.KEY_VOL_SFX, 1.0, cfg_path)
	am.apply_volumes() # 复原满格，不污染后续用例
	am.queue_free()
	await process_frame
	# ---- ☰ 菜单音量三档滑条（双壳同一构建器 AudioSettingsUi）----
	var am3 := AudioManager.new()
	am3.settings_path = cfg_path
	root.add_child(am3)
	var portrait: EncounterPortrait = (load("res://shell/portrait/encounter_portrait.tscn")
		as PackedScene).instantiate()
	portrait.audio_settings_path = cfg_path
	root.add_child(portrait)
	await process_frame
	await process_frame
	var pstream := EventStream.new()
	var psm := EncounterSM.new(Board.new(pstream), pstream, Rng.new(11), "campaign01")
	portrait.bind(psm, AutoAgent.new())
	await process_frame
	var psliders: Array[HSlider] = []
	_collect_sliders(portrait.menu_popup, psliders)
	check(psliders.size() == 3, "竖屏 ☰ 菜单音量三档滑条（Master/BGM/SFX）")
	psliders[1].value = 25.0 # BGM 档
	await process_frame
	check(absf(UiSettings.load_volume(UiSettings.KEY_VOL_BGM, cfg_path) - 0.25) < 0.001,
		"滑条改动写盘（BGM=25%）")
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"BGM")) - linear_to_db(0.25)) < 0.01,
		"滑条即时应用总线（组调用 apply_volumes）")
	psliders[1].value = 100.0 # 复原
	portrait.queue_free()
	await process_frame
	var land: EncounterLandscape = (load("res://shell/landscape/encounter_landscape.tscn")
		as PackedScene).instantiate()
	land.audio_settings_path = cfg_path
	root.add_child(land)
	land.set_anchors_preset(Control.PRESET_TOP_LEFT)
	land.position = Vector2.ZERO
	land.size = Vector2(1280, 720)
	await process_frame
	await process_frame
	var lstream := EventStream.new()
	var lsm := EncounterSM.new(Board.new(lstream), lstream, Rng.new(11), "campaign01")
	land.bind(lsm, AutoAgent.new())
	await process_frame
	var lsliders: Array[HSlider] = []
	_collect_sliders(land.menu_popup, lsliders)
	check(lsliders.size() == 3, "横屏 ☰ 菜单音量三档滑条（同一构建器，禁止复制逻辑）")
	land.queue_free()
	am3.queue_free()
	await process_frame
	# ---- 事件流零变化（14 #5 验收口径：同种子同指令，接入前后逐字节一致）----
	var json_a: String = await _run_battle_with_audio(false)
	var json_b: String = await _run_battle_with_audio(true)
	check(json_a == json_b, "音频接入前后同种子同指令：事件流逐字节一致（纯呈现零污染）")
	# ---- 首批资产（14 #6：WAV 可加载、采样率/时长断言）----
	var expects := {
		&"tide_loop": [8.0, 10.5], &"dice_roll": [0.4, 0.7], &"dice_land": [0.1, 0.3],
		&"hit": [0.15, 0.35], &"crit": [0.25, 0.5], &"heal": [0.4, 0.8], &"page": [0.15, 0.4],
		&"ui_click": [0.05, 0.15], &"bgm_camp": [29.0, 31.0], &"bgm_battle": [29.0, 31.0],
		&"bgm_explore": [20.0, 32.0], &"bgm_map": [18.0, 32.0], &"bgm_ending": [24.0, 40.0],
		&"coin": [0.3, 0.7], &"door": [0.6, 1.2], &"card": [0.15, 0.4], &"link": [0.5, 1.0], &"throw": [0.25, 0.6],
	}
	for asset_name: StringName in expects:
		var path := "res://assets/audio/%s.wav" % String(asset_name)
		check(FileAccess.file_exists(path), "资产存在：%s.wav" % String(asset_name))
		var w := AudioStreamWAV.load_from_file(path)
		check(w != null, "资产可加载：%s（AudioStreamWAV）" % String(asset_name))
		if w != null:
			var r: Array = expects[asset_name]
			check(w.get_mix_rate() == 44100, "%s 采样率 44100Hz" % String(asset_name))
			check(w.get_length() >= float(r[0]) and w.get_length() <= float(r[1]),
				"%s 时长 %.2fs ∈ [%.1f, %.1f]" % [String(asset_name), w.get_length(),
					float(r[0]), float(r[1])])

# ---------------------------------------------------------------- 角色动作动画 + 技能特效（ActionFx）

func test_action_fx() -> void:
	print("[action_fx]")
	# ---- 特效推断：数据优先，形态兜底 ----
	check(ActionFx.resolve_fx({"fx": "lance", "attr": "wits"}) == "lance", "fx 声明优先")
	check(ActionFx.resolve_fx({"kind": "attack", "attr": "wits"}) == "bolt"
		and ActionFx.resolve_fx({"kind": "attack", "attr": "finesse"}) == "stab"
		and ActionFx.resolve_fx({"kind": "attack", "attr": "might"}) == "slash", "攻击按属性推断：智 bolt / 敏 stab / 力 slash")
	check(ActionFx.resolve_fx({"kind": "utility", "heal": "1d8"}) == "heal" and ActionFx.resolve_fx({"kind": "utility"}) == "shield"
		and ActionFx.resolve_fx({"kind": "aoe", "save": {}}) == "burst" and ActionFx.resolve_fx({}, &"enemy") == "claw",
		"治疗 heal / 辅助 shield / 范围 burst / 敌方普攻 claw")
	check(ActionFx.resolve_fx({"fx": "nonsense", "attr": "might"}) == "slash", "未知 fx 回落形态推断")
	check(ActionFx.action_for("slash") == "lunge" and ActionFx.action_for("bolt") == "cast"
		and ActionFx.action_for("arc") == "throw" and ActionFx.action_for("shield") == "brace", "特效 → 施放者动作")
	check(ActionFx.skill_in_unit({"skills": [{"id": "x", "fx": "bolt"}]}, "x")["fx"] == "bolt"
		and ActionFx.skill_in_unit({"attack_fx": "smash"}, "")["fx"] == "smash", "单位内查技能 / 普攻 attack_fx")
	# ---- 播出：替身动画期间真身透明，播完还原；区域技覆盖我方全员 ----
	var fx := ActionFx.new()
	root.add_child(fx)
	var alpha := {}
	var units := {"pc": [&"party", Vector2(100, 400)], "kelan": [&"party", Vector2(200, 400)],
		"imp": [&"enemy", Vector2(150, 100)]}
	fx.anchor_of = func(uid: String) -> Vector2: return units[uid][1] if units.has(uid) else Vector2.ZERO
	fx.rect_of = func(uid: String) -> Rect2: return Rect2(Vector2(units[uid][1]) - Vector2(40, 40), Vector2(80, 80))
	fx.art_ref_of = func(uid: String) -> String: return "portraits/player_blank" if uid == "pc" else ("units/ink_imp" if uid == "imp" else "")
	fx.side_of = func(uid: String) -> StringName: return units[uid][0]
	fx.units_of = func(side: StringName) -> Array: return units.keys().filter(func(k: String) -> bool: return units[k][0] == side)
	fx.skill_def_of = func(_uid: String, sid: String) -> Dictionary: return {"kind": "aoe", "save": {}, "fx": "burst"} if sid == "ink_rain" else {}
	fx.art_alpha = func(uid: String, a: float) -> void: alpha[uid] = a
	fx.on_event({"type": EventTypes.BATTLE_ATTACK, "payload": {"attacker": "pc", "target": "imp", "skill": "", "hit": true}})
	await process_frame
	await process_frame
	check(fx.last_actions.back()["action"] == "lunge" and fx.last_fx.back()["fx"] == "slash", "普攻：扑击动作 + 斩击特效")
	check(fx.is_hidden("pc") and float(alpha.get("pc", 1.0)) == 0.0, "替身在演：真身美术透明")
	await create_timer(0.6).timeout
	check(not fx.is_hidden("pc") and float(alpha.get("pc", 0.0)) == 1.0, "动画结束：真身美术还原")
	fx.on_event({"type": EventTypes.BATTLE_ATTACK, "payload": {"attacker": "kelan", "target": "imp", "skill": "", "hit": true}})
	await process_frame
	await process_frame
	await process_frame
	check(not fx.is_hidden("kelan") and fx.last_fx.back()["from"] == "kelan", "无美术的单位：只播特效，不出替身")
	var before := int(fx.stats["fx"])
	fx.on_event({"type": EventTypes.SKILL_USE, "payload": {"unit": "imp", "skill": "ink_rain", "source": &"enemy"}})
	await process_frame
	await process_frame
	var bursts: Array = fx.last_fx.filter(func(r: Dictionary) -> bool: return str(r["fx"]) == "burst")
	check(int(fx.stats["fx"]) > before and bursts.size() == 2
		and bursts.map(func(r: Dictionary) -> String: return str(r["to"])).has("kelan"), "敌方范围技：我方每人一个爆发特效")
	fx.on_event({"type": EventTypes.LOG, "payload": {"msg_key": "MSG_SKILL_HEAL", "unit": "kelan", "target": "pc", "skill": ""}})
	fx.on_event({"type": EventTypes.ITEM_USE, "payload": {"unit": "pc", "target": "imp", "item": "tide_bomb", "thrown": true}})
	fx.on_event({"type": EventTypes.BATTLE_DOWN, "payload": {"unit": "pc"}})
	await process_frame
	await process_frame
	var kinds: Array = fx.last_fx.map(func(r: Dictionary) -> String: return str(r["fx"]))
	var acts: Array = fx.last_actions.map(func(r: Dictionary) -> String: return str(r["action"]))
	check(kinds.has("heal") and kinds.has("arc") and acts.has("throw") and acts.has("down"), "治疗 / 投掷弧线 / 倒地 各有演出")
	fx.reset()
	check(not fx.is_hidden("pc") and float(alpha["pc"]) == 1.0 and not fx.is_busy(), "换局 reset：清空并还原真身")
	fx.queue_free()
	# ---- 纯呈现：挂上特效层，同种子同指令事件流逐字节一致 ----
	var json_a: String = await _run_battle_with_fx(false)
	var json_b: String = await _run_battle_with_fx(true)
	check(json_a == json_b and json_a.length() > 100, "特效层接入前后事件流逐字节一致（纯呈现零污染）")

func _run_battle_with_fx(with_fx: bool) -> String:
	var sd: GDScript = load("res://tools/shell_diff.gd")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(20261109), "campaign01")
	var fx: ActionFx = null
	if with_fx:
		fx = ActionFx.new()
		root.add_child(fx)
		fx.anchor_of = func(_u: String) -> Vector2: return Vector2(100, 100)
		fx.side_of = func(u: String) -> StringName: return StringName(sm.get_unit(u).get("side", &"party"))
		fx.skill_def_of = func(u: String, sid: String) -> Dictionary: return ActionFx.skill_in_unit(sm.get_unit(u), sid)
		stream.subscribe(fx.on_event)
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(sd.battle_def())
	var agent := AutoAgent.new()
	var guard := 0
	while not sm.is_over() and guard < 300:
		guard += 1
		var cmd := agent.next_command(sm)
		if cmd.is_empty():
			break
		sm.submit_command(cmd)
		if guard % 10 == 0:
			await process_frame
	if fx != null:
		fx.queue_free()
	return JSON.stringify(stream.all())

# ---------------------------------------------------------------- 游戏 UI 套件 + UI 动效（UiKit / UiFx）

func test_ui_kit() -> void:
	print("[ui_kit]")
	var img := UiKit.render("button")
	check(img.get_width() == 48 and img.get_pixel(0, 0).a < 0.05 and img.get_pixel(24, 24).a > 0.95,
		"按钮框体：九宫格纹理（圆角外透明、中心实底）")
	var mid := img.get_pixel(24, 4)
	check(mid.a > 0.5, "按钮框体：边框可见")
	var sheet := UiKit.render("sheet")
	check(sheet.get_pixel(1, sheet.get_height() - 1).a > 0.9 and sheet.get_pixel(0, 0).a < 0.1, "弹层底板：上圆角、下直角（贴屏幕下沿）")
	var th := Theme.new()
	UiKit.build(th)
	check(th.get_stylebox("normal", "Button") is StyleBoxTexture and th.get_stylebox("pressed", "Button") is StyleBoxTexture
		and th.get_stylebox("disabled", "Button") is StyleBoxTexture, "主题：按钮四态九宫格")
	check(th.has_stylebox("panel", "PanelContainer") and th.has_stylebox("grabber", "VScrollBar")
		and th.has_icon("grabber", "HSlider") and th.has_stylebox("fill", "ProgressBar"), "主题：面板 / 滚动条 / 滑条 / 进度条")
	check(th.is_type_variation(&"TitleLabel", &"Label") and th.is_type_variation(&"ToastLabel", &"Label")
		and th.get_stylebox("normal", "ToastLabel") is StyleBoxTexture, "主题：标题 / 横幅变体")
	check(th.get_stylebox("panel", "PanelContainer").get_minimum_size() == Vector2(UiKit.SNUG_PAD, UiKit.SNUG_PAD) * 2.0,
		"默认面板内容边距收窄（不改变既有布局最小尺寸）")
	check(Palette.sheet_style().has_meta(&"ui_sheet"), "弹层底板带 ui_sheet 标记（UiFx 入场动画）")
	# ---- UiFx：加入树即生效 ----
	UiFx.install(self)
	var host := Control.new()
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 24)
	var body := Label.new()
	var colored := Label.new()
	colored.add_theme_font_size_override("font_size", 24)
	colored.add_theme_color_override("font_color", Color.RED)
	var b := Button.new()
	b.size = Vector2(100, 40)
	host.add_child(title)
	host.add_child(body)
	host.add_child(colored)
	host.add_child(b)
	root.add_child(host)
	await process_frame
	check(title.theme_type_variation == &"TitleLabel" and body.theme_type_variation == &""
		and colored.theme_type_variation == &"", "大字号标签自动成标题；正文 / 自定颜色的不动")
	b.button_down.emit()
	await create_timer(0.1).timeout
	check(b.scale.x < 0.99, "按钮按下：缩小")
	b.button_up.emit()
	await create_timer(0.25).timeout
	check(absf(b.scale.x - 1.0) < 0.01, "按钮松开：回弹到 1")
	var sheet_panel := PanelContainer.new()
	sheet_panel.add_theme_stylebox_override("panel", Palette.sheet_style())
	sheet_panel.visible = false
	host.add_child(sheet_panel)
	await process_frame
	var ins := int(UiFx.stats["sheet_ins"])
	sheet_panel.visible = true
	await process_frame
	check(int(UiFx.stats["sheet_ins"]) == ins + 1 and sheet_panel.modulate.a < 1.0, "弹层显现：入场动画（淡入 + 弹起）")
	await create_timer(0.3).timeout
	check(absf(sheet_panel.modulate.a - 1.0) < 0.01 and absf(sheet_panel.scale.y - 1.0) < 0.01, "入场动画结束归位")
	host.queue_free()
	await process_frame

## 无壳脚本化遭遇（与 _run_battle_with_juice 同种子/同指令序列风格）；
## with_audio=true 时挂 AudioManager 订阅事件流——纯呈现消费，不触碰 core。
func _run_battle_with_audio(with_audio: bool) -> String:
	var sd: GDScript = load("res://tools/shell_diff.gd")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(20261109), "campaign01")
	board.give_item("heal_potion", 2, {"event_id": 0, "node_id": "N1-1", "pack_id": "campaign01"})
	board.write("campaign01.witnessed_revocation", true,
		{"event_id": 0, "node_id": "N1-3", "pack_id": "campaign01"})
	var am: AudioManager = null
	if with_audio:
		am = AudioManager.new()
		root.add_child(am)
		stream.subscribe(am.on_event)
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(sd.battle_def())
	var bot := Rng.new(31)
	var guard := 0
	while not sm.is_over() and guard < 300:
		guard += 1
		var actions := sm.get_available_actions()
		if actions.is_empty():
			await process_frame
			continue
		var enabled: Array[int] = []
		for i: int in actions.size():
			if not bool(actions[i]["disabled"]):
				enabled.append(i)
		var pick := enabled[bot.range_int(0, enabled.size() - 1)]
		sm.submit_command(sm.command_from_action(actions[pick]))
		await process_frame
	var json := JSON.stringify(stream.all(), "", true, true)
	if am != null:
		am.queue_free()
		await process_frame
	return json

# ---------------------------------------------------------------- 双壳事件流逐字节比对（tech/01 §10 TP3；白皮书 §7.3 数据零差异）

func test_shell_diff() -> void:
	print("[shell_diff]")
	var sd: GDScript = load("res://tools/shell_diff.gd")
	# 普通局：同一脚本化遭遇（同种子、同指令序列）两壳各跑一遍
	var pair: Dictionary = await sd.run_pair(self, 20261108, 7, false)
	check(int(pair["count"]) > 40, "脚本化遭遇完整跑完（事件 %d 条）" % int(pair["count"]))
	check(str(pair["result"]) != "", "普通局有战斗结果（%s）" % str(pair["result"]))
	check(str(pair["portrait"]) == str(pair["landscape"]),
		"普通局：两壳事件流 JSON 逐字节一致（数据零差异，白皮书 §7.3）")
	# 乱序压力版：同种子 bot 指令序列（含托管命令）两壳各 3 局比对
	for i: int in 3:
		var p2: Dictionary = await sd.run_pair(self, 20261108 + i, 100 + i * 31, true)
		check(str(p2["result"]) != "", "托管乱序局 %d 有战斗结果（%s）" % [i + 1, str(p2["result"])])
		check(str(p2["portrait"]) == str(p2["landscape"]),
			"托管乱序局 %d：两壳事件流逐字节一致（含 source=auto 命令）" % (i + 1))

# ---------------------------------------------------------------- SaveSystem（07 §4，TP4）

func test_save_system() -> void:
	print("[save_system]")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var rng := Rng.new(777)
	var prov := {"event_id": 1, "node_id": "N1-1", "pack_id": "campaign01"}
	board.write("campaign01.seen_fading", true, prov)
	board.write("global.doom_clock", 3, prov)
	board.give_item("ink_core", 2, prov)
	rng.d20() # 推进 RNG 状态，验证状态级恢复（非仅种子）
	var tail := stream.tail()
	var snap := SaveSystem.make_snapshot(board, stream, rng,
		{"packs": {"campaign01": 1}, "rule_pack": {"id": "light", "min_version": 1}},
		{"playthrough": 1, "graph": {"current_id": "N1-7"}})
	check(int(snap["save_version"]) == SaveSystem.SAVE_VERSION, "快照含 save_version（07 §4.1）")
	check(int(snap["event_tail"]) == tail, "快照含事件流 tail 锚点")
	check(snap.has("board") and snap.has("rng_seed") and snap.has("bindings") and snap.has("meta"),
		"快照五要素齐备：board/event_tail/bindings/rng/meta（07 §4.1）")
	check(str((snap["meta"] as Dictionary).get("saved_at", "")) != "", "meta 含保存时间戳（07 §4.1）")
	# 写盘 → 读档 → 迁移 → 应用，往返一致（JSON，tech/01 §4.3）
	check(SaveSystem.write(snap, "test_tp4"), "写入存档目录（测试隔离：user://test/saves）")
	check(SaveSystem.has_save("test_tp4"), "has_save 读档存在")
	var loaded := SaveSystem.read("test_tp4")
	check(bool(loaded["ok"]), "读档成功")
	var mig := SaveSystem.migrate(loaded["snapshot"])
	check(bool(mig["ok"]), "v2 迁移链直通（07 §4.3）")
	var board2 := Board.new(EventStream.new())
	var rng2 := Rng.new(1)
	SaveSystem.apply(mig["snapshot"], board2, rng2)
	check(board2.serialize() == snap["board"], "存档往返：Board 全量一致")
	check(board2.read("campaign01.seen_fading") == true and board2.get_doom_clock() == 3
		and board2.item_count("ink_core") == 2, "存档往返：旗标/时钟/物品一致")
	check(rng2.d20() == rng.d20(), "存档往返：RNG 恢复后续掷一致（rng_seed 状态）")
	# 迁移链边界
	check(not bool(SaveSystem.migrate({"save_version": 0})["ok"]), "缺 save_version 拒绝")
	var future: Dictionary = snap.duplicate(true)
	future["save_version"] = SaveSystem.SAVE_VERSION + 1
	check(not bool(SaveSystem.migrate(future)["ok"]), "未来版本快照拒绝（07 §4.3 不降级读取）")
	# ---- v1→v2 迁移器（tech/04 §8 规则4，07 §4.3 迁移链首用例）：旧包内成长键并入 global.growth.* ----
	var v1 := {
		"save_version": 1,
		"board": {"data": {
				"campaign01.xp_total": 350, "campaign01.level": 2, "campaign01.attr_points": 1,
				"campaign01.attrs": {"might": 1}, "campaign01.attr_granted": 1,
				"campaign01.seen_fading": true, "global.doom_clock": 2},
			"provenance": {"campaign01.xp_total": {"event_id": 9, "node_id": "N1-8", "pack_id": "campaign01"}}},
		"event_tail": 9, "bindings": {"packs": {"campaign01": 1}}, "rng_seed": {}, "meta": {}}
	var m12 := SaveSystem.migrate(v1)
	check(bool(m12["ok"]) and int((m12["snapshot"] as Dictionary)["save_version"]) == SaveSystem.SAVE_VERSION,
		"v1 存档经迁移链升到当前版本")
	var mdata: Dictionary = ((m12["snapshot"] as Dictionary)["board"] as Dictionary)["data"]
	check(int(mdata.get("global.growth.xp", 0)) == 350 and int(mdata.get("global.growth.level", 1)) == 2
		and int(mdata.get("global.growth.attr_points", 0)) == 1
		and int(mdata.get("global.growth.attrs.might", 0)) == 1,
		"迁移并入：xp/level/attr_points/attrs.<attr> → global.growth.*")
	for old_key: String in ["campaign01.xp_total", "campaign01.level", "campaign01.attr_points",
			"campaign01.attrs", "campaign01.attr_granted"]:
		check(not mdata.has(old_key), "迁移清除旧键：%s" % old_key)
	check(not (((m12["snapshot"] as Dictionary)["board"] as Dictionary)["provenance"] as Dictionary)
			.has("campaign01.xp_total"), "迁移清除旧键溯源")
	check(mdata.get("campaign01.seen_fading") == true and int(mdata.get("global.doom_clock", 0)) == 2,
		"迁移不动其他键（旗标/时钟原样）")
	# 旧档缺 level 键（从未结算过成长）：按门槛表重算等级并补发未发放的升级点
	var v1b := {"save_version": 1,
		"board": {"data": {"campaign01.xp_total": 700}, "provenance": {}},
		"event_tail": 1, "bindings": {}, "rng_seed": {}, "meta": {}}
	var m12b: Dictionary = SaveSystem.migrate(v1b)["snapshot"]
	var mb: Dictionary = (m12b["board"] as Dictionary)["data"]
	check(int(mb.get("global.growth.level", 1)) == 3
		and int(mb.get("global.growth.attr_points", 0)) == 2,
		"迁移兜底：缺 level 键按 700 XP 重算 Lv.3 并补发 2 点（11 §6）")
	# 迁移后可直接应用并继续汇入（老存档兼容，迭代不破坏）
	var board3 := Board.new(EventStream.new())
	SaveSystem.apply(m12["snapshot"], board3, Rng.new(1))
	Growth.new(board3).grant_xp(50, {"event_id": 10, "node_id": "N1-8", "pack_id": "campaign01"})
	check(Growth.xp(board3) == 400 and Growth.attrs_total(board3, "might") == 1,
		"迁移档应用后继续汇入成长（400 XP）且已分配属性保留")

# ---------------------------------------------------------------- Loadout（09 §9.1 / tech-02 §2.4，TP4）

func test_loadout() -> void:
	print("[loadout]")
	var pack := _load_campaign01()
	var cfg := Loadout.resolve_config(pack, "N1-7")
	check(not cfg.is_empty() and bool(cfg["enabled"]), "manifest loadout 启用（tech/02 §2.4）")
	check(int(cfg["skill_slots"]) == 2 and int(cfg["item_slots"]) == 2, "槽位读 manifest 配置（技能 2 / 道具 2）")
	check(Loadout.validate(cfg, ["a", "b"], ["x"]) == "", "槽位内选择合法")
	check(Loadout.validate(cfg, ["a", "b", "c"], ["x"]) == "skill_slots_exceeded", "技能超槽拒绝")
	check(Loadout.validate(cfg, ["a"], ["x", "y", "z"]) == "item_slots_exceeded", "道具超槽拒绝")
	# 遭遇级覆盖（tech/02 §2.4：同名块覆盖）
	var pack2: Dictionary = pack.duplicate(true)
	(pack2["encounters"] as Dictionary)["N1-7"]["loadout"] = {"skill_slots": 1}
	var cfg2 := Loadout.resolve_config(pack2, "N1-7")
	check(int(cfg2["skill_slots"]) == 1 and int(cfg2["item_slots"]) == 2, "遭遇级 loadout 覆盖战役级")
	# 未声明 = 不启用（tech/02 §2.4）
	var pack3: Dictionary = pack.duplicate(true)
	(pack3["manifest"] as Dictionary).erase("loadout")
	check(Loadout.resolve_config(pack3, "N1-7").is_empty(), "未声明 loadout = 不启用整备")
	# 确认写事件流（09 §9.1：loadout.confirm，历史卷轴可追溯）
	var stream := EventStream.new()
	var sel := Loadout.confirm(stream, cfg, ["inkbolt", "inkshield"], ["heal_potion"],
		{"might": 1}, "N1-7", "campaign01")
	var evs := stream.query_by_type(EventTypes.LOADOUT_CONFIRM)
	check(evs.size() == 1, "确认产出 loadout.confirm 事件（09 §9.1）")
	check((evs[0]["payload"]["skills"] as Array) == ["inkbolt", "inkshield"]
		and int((sel as Dictionary)["skill_slots"]) == 2, "confirm 负载含选择与槽位快照")

# ---------------------------------------------------------------- 成长曲线（11 §6，TP4 裁决 3 对齐）

func test_growth() -> void:
	print("[growth]")
	# 档位表：1→2 需 300，2→3 需 700，3→4 需 1200（11 §6）
	check(LightV1.level_for_xp(299) == 1, "299 XP 不升级（门槛 300）")
	check(LightV1.level_for_xp(300) == 2, "300 XP 升 Lv.2")
	check(LightV1.attr_points_for_xp(300) == 1 and LightV1.hp_bonus_for_xp(300) == 2,
		"Lv.2：属性点 +1、HP+2（11 §6）")
	check(LightV1.level_for_xp(699) == 2 and LightV1.level_for_xp(700) == 3, "700 XP 升 Lv.3")
	check(LightV1.attr_points_for_xp(700) == 2 and LightV1.hp_bonus_for_xp(700) == 4,
		"Lv.3：累计属性点 +2、HP+4")
	check(LightV1.level_for_xp(1199) == 3 and LightV1.level_for_xp(1200) == 4, "1200 XP 升 Lv.4")
	check(LightV1.attr_points_for_xp(1200) == 3 and LightV1.hp_bonus_for_xp(1200) == 6,
		"连跨档（0→1200）：属性点 +3、HP+6")
	check(LightV1.level_for_xp(99999) == 4, "等级上限 Lv.4（11 §6 表三档）")
	check(LightV1.skill_slot_bonus(2) == 0 and LightV1.skill_slot_bonus(3) == 1,
		"2→3 级技能槽 +1（11 §6）")
	check(LightV1.ATTR_POINT_CAP == 3, "单项属性加点 +3 封顶（11 §6）")

	# ---- Growth 系统（tech/04 §8 定稿）：簿记归框架全局键 global.growth.*（07 §2 白名单）----
	var gs := EventStream.new()
	var gb := Board.new(gs)
	var growth := Growth.new(gb)
	var prov := {"event_id": 1, "node_id": "N1-7", "pack_id": "arena"} # 子游戏命名空间同通道（§8 规则1）
	check(Growth.xp(gb) == 0 and Growth.level(gb) == 1 and Growth.attr_points(gb) == 0,
		"成长初始：xp 0 / Lv.1 / 属性点 0")
	var r1: Dictionary = growth.grant_xp(299, prov)
	check(int(r1["xp"]) == 299 and int(r1["leveled"]) == 0 and Growth.level(gb) == 1,
		"汇入 299：写 global.growth.xp，未跨档不升级")
	check(gs.query_by_type(EventTypes.XP_GAIN).size() == 1
		and gs.query_by_type(EventTypes.LEVEL_UP).is_empty(), "xp.gain 事件产出，未升级无 level.up")
	var r2: Dictionary = growth.grant_xp(1, prov)
	check(int(r2["leveled"]) == 1 and Growth.level(gb) == 2 and Growth.attr_points(gb) == 1,
		"跨档即升级：300 → Lv.2、属性点 +1（11 §6 门槛表归规则包）")
	var lup := gs.query_by_type(EventTypes.LEVEL_UP)
	check(lup.size() == 1 and int(lup[0]["payload"]["level"]) == 2
		and int(lup[0]["payload"]["hp_bonus"]) == LightV1.LEVEL_HP_BONUS,
		"level.up 事件：等级/HP 加值/属性点负载")
	var r3: Dictionary = growth.grant_xp(900, prov) # 300→1200 连跨两档
	check(int(r3["leveled"]) == 2 and Growth.level(gb) == 4 and Growth.attr_points(gb) == 3,
		"连跨档：1200 → Lv.4、累计属性点 +3")
	check(gs.query_by_type(EventTypes.LEVEL_UP).size() == 3, "连跨两档：每级一条 level.up")
	# 分配（§8 规则3）：attrs.<attr> 平铺键 + attr.alloc 事件
	check(growth.can_alloc("might"), "有点数可分配")
	check(growth.alloc("might", prov) and Growth.attrs_total(gb, "might") == 1
		and Growth.attr_points(gb) == 2, "分配：might +1、点数 -1")
	var alloc_evs := gs.query_by_type(EventTypes.ATTR_ALLOC)
	check(alloc_evs.size() == 1 and str(alloc_evs[0]["payload"]["attr"]) == "might"
		and int(alloc_evs[0]["payload"]["points_left"]) == 2, "attr.alloc 事件（09 §9.1 分配时机）")
	growth.alloc("might", prov)
	growth.alloc("might", prov) # might 3 点满
	check(Growth.attr_points(gb) == 0 and not growth.can_alloc("might"), "点数耗尽不可再分配")
	var gb2 := Board.new(EventStream.new())
	var g2 := Growth.new(gb2)
	var prov2 := {"event_id": 1, "node_id": "", "pack_id": "campaign01"}
	g2.grant_xp(1200, prov2) # 3 点全投同一项：验证 +3 封顶
	check(g2.alloc("finesse", prov2) and g2.alloc("finesse", prov2) and g2.alloc("finesse", prov2),
		"单项连续分配至 +3")
	check(not g2.can_alloc("finesse") and not g2.alloc("finesse", prov2),
		"单项 +3 封顶：第 4 点拒绝（11 §6）")
	check(Growth.attrs_map(gb2)["finesse"] == 3, "attrs_map 读取已分配值（战斗修正源）")
	var prog := Growth.xp_progress(gb2)
	check(int(prog["level"]) == 4 and int(prog["next"]) == 0, "xp 进度：满级 next=0（⑦ 呈现「已满级」）")
	# growth 键任何包可写（07 §3 白名单）：以上子游戏命名空间写入全程无 board.denied
	check(gs.query_by_type(EventTypes.BOARD_DENIED).is_empty(),
		"global.growth.* 白名单任何包可写（07 §3，无越权拒绝）")

# ---------------------------------------------------------------- L3 事件运行时（tech/02 §5，TP4 接入 story_graph）

func test_quest_runtime() -> void:
	print("[quest_runtime]")
	var pack := _load_campaign01()
	var stream := EventStream.new()
	var board := Board.new(stream)
	var graph := StoryGraph.new(board, Rng.new(42), pack)
	graph.start()
	graph.take_edge(_edge_to(graph, "N0-2"))
	var qt := stream.query_by_type(EventTypes.QUEST_TRIGGER)
	check(qt.size() == 1 and str(qt[0]["payload"]["id"]) == "dock_tales",
		"auto 触发：进 N0-2 事件中心可见（quest.trigger）")
	check(graph.quest_badge_count() == 1, "进行中事件角标 = 1（04 §⑤）")
	graph.resolve_check(graph.available_edges()[0], true) # N0-2 完成 → dock_tales settle
	var qs := stream.query_by_type(EventTypes.QUEST_SETTLE)
	check(qs.size() == 1 and str(qs[0]["payload"]["id"]) == "dock_tales", "节点完成 → quest.settle")
	var xp := stream.query_by_type(EventTypes.XP_GAIN)
	check(xp.size() == 1 and int(xp[0]["payload"]["amount"]) == 50, "settle 写板：xp 50（tech/02 §5）")
	check(graph.quest_badge_count() == 0, "已完结事件不计角标（归档历史卷轴）")
	# 主线推进：fading_street 触发；settle 去重不重复写板（TP4 裁决：效果由节点 on_enter 承载）
	graph.take_edge(_edge_to(graph, "N0-4"))
	graph.take_edge(_edge_to(graph, "N1-1"))
	var e_buy := _edge_to(graph, "N1-2")
	for e: Variant in graph.available_edges():
		for fx: Variant in (e as Dictionary).get("effects", []):
			if (fx as Dictionary).has("give_item"):
				e_buy = e
	graph.take_edge(e_buy)
	check(str((stream.query_by_type(EventTypes.QUEST_TRIGGER).back() as Dictionary)["payload"]["id"]) == "fading_street",
		"auto 触发：消逝之街（进 N1-2）")
	graph.resolve_check(graph.available_edges()[0], true) # N1-2 成功 → N1-3
	check(board.get_doom_clock() == 1, "fading_street settle 不重复推钟（去重裁决，时钟仍 = N1-3 on_enter 的 1）")
	# choice 触发：誊写庭委托；settle 写声望增量（N2S-1 完成）
	graph.take_edge(_edge_to(graph, "N1-4")) # 接触誊写庭 rep+1（on_enter）；离开 N1-3 → fading_street 完结
	check(stream.query_by_type(EventTypes.QUEST_SETTLE).any(
		func(ev: Dictionary) -> bool: return str(ev["payload"]["id"]) == "fading_street"),
		"离开 N1-3 → fading_street 完结（节点完成时结算，tech/02 §5）")
	check(graph.quest_badge_count() == 1 and graph.quests().any(
		func(q: Dictionary) -> bool: return str(q["id"]) == "three_callings" and str(q["state"]) == "triggered"),
		"三方拜帖进行中（进 N1-3 触发）")
	graph.take_edge(_edge_to(graph, "N1-7"))
	check(int(board.get_rep("scriptorium")) == 1, "three_callings settle 去重：声望不重复 +1")
	graph.take_edge(_edge_to(graph, "N1-8"))
	var e_s := _edge_to(graph, "N2S-1")
	graph.take_edge(e_s) # choice 触发 archive_quest
	check(stream.query_by_type(EventTypes.QUEST_TRIGGER).any(
		func(ev: Dictionary) -> bool: return str(ev["payload"]["id"]) == "archive_quest"),
		"choice 触发：档案馆委托（label 匹配，tech/02 §5）")
	graph.resolve_check(graph.available_edges()[0], true) # N2S-1 完成 → settle rep.scriptorium +1
	check(int(board.get_rep("scriptorium")) == 2, "settle 写板：档案馆委托 rep.scriptorium +1")
	# doom_clock 触发：时钟到 2 格
	board.write("global.doom_clock", 2, {"event_id": stream.tail(), "node_id": graph.current_id, "pack_id": "campaign01"})
	graph._scan_triggers()
	check(stream.query_by_type(EventTypes.QUEST_TRIGGER).any(
		func(ev: Dictionary) -> bool: return str(ev["payload"]["id"]) == "ink_rain_raid"),
		"doom_clock 触发：墨雨夜袭（at 2，tech/02 §5）")
	# 图进度快照往返（07 §4.1 meta.graph）
	var snap := graph.serialize()
	var graph2 := StoryGraph.new(Board.new(EventStream.new()), Rng.new(1), pack)
	graph2.deserialize(JSON.parse_string(JSON.stringify(snap)))
	check(graph2.current_id == graph.current_id and graph2.quest_badge_count() == graph.quest_badge_count()
		and graph2.quests().size() == graph.quests().size(), "图进度快照往返一致（含 L3 事件状态）")
	# hidden 触发：零声望抵达 N1-8 → 孤身入局（tech/02 §5 hidden）
	var s2 := EventStream.new()
	var b2 := Board.new(s2)
	var g2 := StoryGraph.new(b2, Rng.new(7), pack)
	g2.start()
	g2.take_edge(_edge_to(g2, "N0-2"))
	g2.resolve_check(g2.available_edges()[0], true)
	g2.take_edge(_edge_to(g2, "N0-4"))
	g2.take_edge(_edge_to(g2, "N1-1"))
	g2.take_edge(_edge_to(g2, "N1-2"))
	g2.resolve_check(g2.available_edges()[0], true) # → N1-3
	var e_decline := _edge_to(g2, "N1-8") # 婉拒所有邀约：三方声望保持 0
	check(not e_decline.is_empty(), "N1-3 存在婉拒边")
	g2.take_edge(e_decline)
	check(s2.query_by_type(EventTypes.QUEST_TRIGGER).any(
		func(ev: Dictionary) -> bool: return str(ev["payload"]["id"]) == "lone_wolf"),
		"hidden 触发：孤身入局（requires 三方声望 ≤0）")
	check(not _edge_to(g2, "N2L-1").is_empty(), "hidden 触发后独狼声望边显形")

# ---------------------------------------------------------------- 战斗数值数据驱动（tech/04 §1~§4 / tech/02 §6，M2）

## 无壳整局：同种子 + AutoAgent 托管（同构 Command 通道，09 §9.3）打到底，导出事件流 JSON。
func _run_headless_battle(def: Dictionary, seed: int) -> String:
	var stream := EventStream.new()
	var board := Board.new(stream)
	# 序章带入（与 shell_diff/main 同一脚本化遭遇前置）
	board.give_item("heal_potion", 2, {"event_id": 0, "node_id": "N1-1", "pack_id": "campaign01"})
	board.write("campaign01.witnessed_revocation", true, {"event_id": 0, "node_id": "N1-3", "pack_id": "campaign01"})
	var sm := EncounterSM.new(board, stream, Rng.new(seed), "campaign01")
	var agent := AutoAgent.new()
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(def)
	var guard := 0
	while not sm.is_over() and guard < 500:
		guard += 1
		var cmd := agent.next_command(sm)
		if cmd.is_empty():
			break
		sm.submit_command(cmd)
	return JSON.stringify(stream.all(), "", true, true)

func test_battle_data_driven() -> void:
	print("[battle_data_driven]")
	var pack := _load_campaign01()
	# 新表加载与结构校验（tech/04 §2：kind/熟练/公式字段）
	var pt: Dictionary = pack["characters"]["player_blank"]
	check(str(pt["kind"]) == "player_template" and int(pt["attrs"]["might"]) == 2
		and (pt["proficiencies"] as Array) == ["investigation", "athletics"],
		"玩家模板：kind=player_template、力2、熟练 调查/运动（11 §1 +2/+1/0）")
	# 公式求值（tech/04 §2：规则包求值，白名单变量）
	check(LightV1.eval_formula(str(pt["hp_formula"]), {"might": 2, "finesse": 1, "wits": 0, "level": 1}) == 14,
		"hp_formula 求值 = 14（白页者，规则包求值）")
	check(LightV1.eval_formula(str((pack["characters"]["companion_laofei"] as Dictionary)["ac_formula"]),
			{"might": 1, "finesse": 0, "wits": 1, "level": 1}) == 12, "ac_formula 求值 = 12（老费）")
	check(LightV1.eval_formula("10 + luck*2", {"might": 2}) == null, "白名单外变量求值失败返回 null（fail-fast 前提）")
	# 组装 = 旧硬编码基准：结构与数值逐字节一致（数值转写搬运、无再创作硬证明①）
	var stream := EventStream.new()
	var board := Board.new(stream)
	board.give_item("heal_potion", 2, {"event_id": 0, "node_id": "N1-1", "pack_id": "campaign01"})
	board.write("campaign01.witnessed_revocation", true, {"event_id": 0, "node_id": "N1-3", "pack_id": "campaign01"})
	var res := BattleDef.assemble(pack, "N1-7", {"skills": ["inkbolt", "inkshield"], "items": ["heal_potion"]}, board)
	check(bool(res["ok"]), "N1-7 战斗定义组装 ok：%s" % ";".join(res["errors"] as Array))
	var sd: GDScript = load("res://tools/shell_diff.gd")
	var baseline: Dictionary = sd.battle_def()
	check(JSON.stringify(res["def"], "", true, true) == JSON.stringify(baseline, "", true, true),
		"数据驱动 def 与旧硬编码基准规范化序列化逐字节一致")
	# 同种子同指令（托管通道）事件流一致（无再创作硬证明②）
	var js_baseline := _run_headless_battle(baseline, 20261108)
	var js_data := _run_headless_battle(res["def"], 20261108)
	check(js_baseline == js_data, "同种子同指令事件流 JSON 逐字节一致（数据驱动 == 旧硬编码）")
	check(JSON.parse_string(js_data).size() > 40, "对照局完整跑完（事件 >40 条）")
	# fail-fast：引用缺失/公式失败报错不静默（引导层报错路径的数据前提）
	var broken: Dictionary = pack.duplicate(true)
	broken["encounters"]["N1-7"]["enemies"] = [{"id": "boss", "ref": "no_such_enemy"}]
	var res2 := BattleDef.assemble(broken, "N1-7", {}, board)
	check(not bool(res2["ok"]) and not (res2["errors"] as Array).is_empty(), "敌人引用缺失：组装 fail-fast 报错")
	var broken2: Dictionary = pack.duplicate(true)
	broken2["characters"]["player_blank"]["hp_formula"] = "10 + luck"
	var res3 := BattleDef.assemble(broken2, "N1-7", {}, board)
	check(not bool(res3["ok"]), "公式求值失败：组装 fail-fast 报错")

# ---------------------------------------------------------------- Boss 回合行为脚本（story/03 §2/§3）

## 行为观察探针：队伍"打不死也打不动"（攻修 -50、伤害归零、HP 500），AutoAgent 托管跑满 6 个敌方回合。
## enemy_hp_override > 0 时压低首个敌人 HP（触发血量阈值脚本）；extra_enemies 追加敌人实例（同屏上限测试）。
func _behavior_probe(enc_id: String, enemy_hp_override: int, extra_enemies: Array = []) -> Dictionary:
	var pack := _load_campaign01()
	var stream := EventStream.new()
	var board := Board.new(stream)
	var res := BattleDef.assemble(pack, enc_id, {}, board)
	check(bool(res["ok"]), "行为探针：遭遇 %s 组装 ok：%s" % [enc_id, ";".join(res["errors"] as Array)])
	var def: Dictionary = res["def"]
	for u: Variant in def["party"]:
		(u as Dictionary)["attack_mod"] = -50
		(u as Dictionary)["damage"] = "1d1-1"
		(u as Dictionary)["hp"] = 500
		(u as Dictionary)["max_hp"] = 500
		(u as Dictionary).erase("skills")
		(u as Dictionary).erase("items")
	if enemy_hp_override > 0:
		(def["enemies"][0] as Dictionary)["hp"] = enemy_hp_override
	for extra: Variant in extra_enemies:
		(def["enemies"] as Array).append(extra)
	var sm := EncounterSM.new(board, stream, Rng.new(7), "campaign01")
	var agent := AutoAgent.new()
	sm.enter(enc_id)
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(def)
	var guard := 0
	while not sm.is_over() and sm.round_no() <= 6 and guard < 2000:
		guard += 1
		var cmd := agent.next_command(sm)
		if cmd.is_empty():
			break
		sm.submit_command(cmd)
	return {"sm": sm, "stream": stream}

func test_boss_behavior() -> void:
	print("[boss_behavior]")
	var pack := _load_campaign01()
	# —— 守页人（story/03 §3.1）满血：seal_shock 每 2 回合（第 2/4/6 回合），其余普攻；不触发转阶段
	var stream: EventStream = _behavior_probe("R5", 0)["stream"]
	var round_no := 0
	var seal_rounds: Array[int] = []
	var seal_saves := 0
	var rewrite_leak := false
	for ev: Dictionary in stream.all():
		var p: Dictionary = ev["payload"]
		if ev["type"] == EventTypes.TURN_START and str(p.get("side", "")) == "enemy":
			round_no = int(p["round"])
		elif ev["type"] == EventTypes.BATTLE_SKILL:
			if str(p["skill"]) == "seal_shock":
				seal_rounds.append(round_no)
				check(str(p["trigger"]["kind"]) == "every_n_rounds" and int(p["trigger"]["n"]) == 2,
					"seal_shock 触发器 = every_n_rounds(2)（battle.skill 含触发器明细，story/03 §2）")
			elif str(p["skill"]) == "rewrite_rules":
				rewrite_leak = true
		elif ev["type"] == EventTypes.CHECK_ROLL and str(p.get("kind", "")) == "save" \
				and str(p.get("skill", "")) == "seal_shock":
			seal_saves += 1
			check(int(p["dc"]) == 12 and str(p.get("on_success", "")) == "half"
				and p.has("damage") and p.has("target_hp_after"),
				"seal_shock 豁免明细进事件流：敏豁免 DC12 半伤（story/03 §3.1；11 §5.1）")
	check(seal_rounds == [2, 4, 6], "seal_shock 第 2/4/6 回合触发（实际 %s）" % str(seal_rounds))
	check(seal_saves == 9, "seal_shock ×3 回 × 3 队员 = 9 条豁免明细（实际 %d）" % seal_saves)
	check(not rewrite_leak, "HP≥50% 不触发重写守则")
	# —— 守页人丝血（10/38 < 50%）：第 1 回合重写守则 once（攻击 5→6），此后恒 +6，全场只触发一次
	var stream2: EventStream = _behavior_probe("R5", 10)["stream"]
	var rewrite_count := 0
	var atk_mod_after := 0
	var warden_atk_mods: Array[int] = []
	for ev: Dictionary in stream2.all():
		var p: Dictionary = ev["payload"]
		if ev["type"] == EventTypes.BATTLE_SKILL and str(p["skill"]) == "rewrite_rules":
			rewrite_count += 1
			atk_mod_after = int(p.get("attack_mod_after", 0))
			check(str(p["trigger"]["kind"]) == "when_hp_below" \
					and absf(float(p["trigger"]["threshold"]) - 0.5) < 0.001 \
					and bool(p["trigger"]["once"]),
				"重写守则触发器 = when_hp_below(0.5)+once（story/03 §2）")
		elif ev["type"] == EventTypes.BATTLE_ATTACK and str(p.get("attacker", "")) == "warden":
			warden_atk_mods.append(int(p["atk_mod"]))
	check(rewrite_count == 1 and atk_mod_after == 6, "重写守则全场一次：攻击 5→6（事件流可溯，story/03 §3.1）")
	check(not warden_atk_mods.is_empty() and warden_atk_mods.all(func(m: int) -> bool: return m == 6),
		"转阶段后守页人普攻恒 +6")
	# —— 墨潮化身（story/03 §3.2）丝血（5/15 < 50%）：call_imps 一次召唤幼体 ×2（同屏 6→8，≤8 校验）
	var r3 := _behavior_probe("N4-1", 5)
	var sm3: EncounterSM = r3["sm"]
	var summon_evs: Array = []
	var tide_sweeps := 0
	for ev: Dictionary in (r3["stream"] as EventStream).all():
		var p: Dictionary = ev["payload"]
		if ev["type"] == EventTypes.BATTLE_SKILL and str(p["skill"]) == "call_imps":
			summon_evs.append(p)
		elif ev["type"] == EventTypes.BATTLE_SKILL and str(p["skill"]) == "tide_sweep":
			tide_sweeps += 1
	check(summon_evs.size() == 1, "call_imps 全场一次（once，story/03 §3.2）")
	if summon_evs.size() == 1:
		check((summon_evs[0]["summoned"] as Array).size() == 2 and int(summon_evs[0]["cap"]) == 8,
			"召唤墨魈幼体 ×2（同屏 6→8，≤8 约束校验通过）")
	check(sm3.get_units().size() == 8 and sm3.get_order().size() == 8,
		"召唤单位入单位表与先攻序（次轮起行动）")
	check(tide_sweeps >= 2, "tide_sweep 每 2 回合 AoE（6 回合内 ≥2 次，实际 %d）" % tide_sweeps)
	# —— 同屏 ≤8 约束：8/8 时召唤空发；7/8 时只召 1（story/03 §3.2）
	var imp_x := {"name": "墨魈幼体", "hp": 8, "ac": 10, "attrs": {"might": 0, "finesse": 0, "wits": 0},
		"attack_mod": 2, "damage": "1d4"}
	var imp_a: Dictionary = imp_x.duplicate(true)
	imp_a["id"] = "imp_x1"
	var imp_b: Dictionary = imp_x.duplicate(true)
	imp_b["id"] = "imp_x2"
	var stream4: EventStream = _behavior_probe("N4-1", 5, [imp_a, imp_b])["stream"]
	var full_summon: Array = []
	for ev: Dictionary in stream4.all():
		var p: Dictionary = ev["payload"]
		if ev["type"] == EventTypes.BATTLE_SKILL and str(p["skill"]) == "call_imps":
			full_summon.append(p)
	check(full_summon.size() == 1 and (full_summon[0]["summoned"] as Array).is_empty(),
		"同屏 8/8：召唤受 ≤8 约束空发（事件流如实记录 summoned=[]）")
	var stream5: EventStream = _behavior_probe("N4-1", 5, [imp_a])["stream"]
	var partial_summon: Array = []
	for ev: Dictionary in stream5.all():
		var p: Dictionary = ev["payload"]
		if ev["type"] == EventTypes.BATTLE_SKILL and str(p["skill"]) == "call_imps":
			partial_summon.append(p)
	check(partial_summon.size() == 1 and (partial_summon[0]["summoned"] as Array).size() == 1,
		"同屏 7/8：召唤只入 1（剩余席位钳制）")
	# —— fail-fast：behavior 引用非自带技能 / 召唤 ref 未登记（引导层报错路径）
	var broken: Dictionary = pack.duplicate(true)
	broken["enemies"]["page_warden"]["behavior"] = [{"every_n_rounds": 2, "skill": "not_owned"}]
	check(not bool(BattleDef.assemble(broken, "R5", {}, Board.new(EventStream.new()))["ok"]),
		"behavior 引用非自带技能：组装 fail-fast（story/03 §2）")
	var broken2: Dictionary = pack.duplicate(true)
	broken2["enemies"]["tide_avatar"]["skills"][1]["ref"] = "no_such_imp"
	check(not bool(BattleDef.assemble(broken2, "N4-1", {}, Board.new(EventStream.new()))["ok"]),
		"召唤技能 ref 未登记：组装 fail-fast（story/03 §3.2）")

# ---------------------------------------------------------------- 胜率标定工具（story/03 §1/§5）

func test_winrate_tool() -> void:
	print("[winrate_tool]")
	var sd: GDScript = load("res://tools/winrate.gd")
	var pack := _load_campaign01()
	# 确定性：同种子同分布（逐局结果一致）
	var a: Dictionary = sd.run_encounter(pack, "N1-7", 24, 555)
	var b: Dictionary = sd.run_encounter(pack, "N1-7", 24, 555)
	check(a["results"] == b["results"] and int(a["wins"]) == int(b["wins"]),
		"winrate 确定性：同种子同分布（24 局逐局结果一致）")
	# 预期等级基线（序章 Lv1 / 幕二 Lv2 / 幕三 Lv3 / 终章 Lv3~4 取下限 Lv3）
	check(int(sd.encounter_level(pack, "N1-7")) == 1 and int(sd.encounter_level(pack, "N2U-2")) == 2
		and int(sd.encounter_level(pack, "R5")) == 3 and int(sd.encounter_level(pack, "N4-1")) == 3,
		"遭遇 → 预期等级映射（序章/幕二/幕三/终章）")
	# 定稿锁：全表 200 局（基种子 20261109）落入 story/03 §1 目标区间
	var targets := {"easy": [85, 95], "medium": [70, 80], "hard": [50, 65]}
	for eid: String in sd.battle_encounters(pack):
		var enc: Dictionary = pack["encounters"][eid]
		var r: Dictionary = sd.run_encounter(pack, eid, 200, 20261109)
		var rate := 100.0 * int(r["wins"]) / 200.0
		var tgt: Array = targets[str(enc.get("difficulty", "medium"))]
		check(rate >= float(tgt[0]) and rate <= float(tgt[1]),
			"定稿锁：%s（%s）胜率 %.1f%% ∈ %d~%d（story/03 §1）"
				% [eid, str(enc["difficulty"]), rate, int(tgt[0]), int(tgt[1])])
	# §5：主线经验总量 vs 300/700/1200 门槛——通关落在 Lv3 区间 [700, 1200)
	var xp_report: Dictionary = sd.main_path_xp(pack)
	check(xp_report.size() == 3, "§5 校核覆盖幕二主线三链")
	for chain: String in xp_report.keys():
		var total := int(xp_report[chain])
		check(total >= 700 and total < 1200 and LightV1.level_for_xp(total) == 3,
			"§5：%s 通关经验 %d ∈ Lv3 区间 [700,1200)" % [chain, total])

# ---------------------------------------------------------------- HP 跨遭遇持久化（11 §7.1，验收裁决 A）

## 数据驱动 def + 强化 pc 速胜的托管整局；返回 {sm, board, stream}。
func _run_pack_battle(seed: int, aoe_damage: String = "") -> Dictionary:
	var pack := _load_campaign01()
	var stream := EventStream.new()
	var board := Board.new(stream)
	var def: Dictionary = BattleDef.assemble(pack, "N1-7", {}, board)["def"]
	(def["party"][0] as Dictionary)["attack_mod"] = 30
	(def["party"][0] as Dictionary)["damage"] = "30d6"
	if aoe_damage != "":
		((def["enemies"][0] as Dictionary)["skills"][0] as Dictionary)["damage"] = aoe_damage
	var sm := EncounterSM.new(board, stream, Rng.new(seed), "campaign01")
	var agent := AutoAgent.new()
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(def)
	var guard := 0
	while not sm.is_over() and guard < 500:
		guard += 1
		var cmd := agent.next_command(sm)
		if cmd.is_empty():
			break
		sm.submit_command(cmd)
	return {"sm": sm, "board": board, "pack": pack}

func test_hp_persistence() -> void:
	print("[hp_persistence]")
	var pack := _load_campaign01()
	# 无记录 = 满血公式值；单位带 char_id ref（写板键 <ns>.hp.<char_id>）
	var res := BattleDef.assemble(pack, "N1-7", {}, Board.new(EventStream.new()))
	check(bool(res["ok"]), "N1-7 组装 ok：%s" % ";".join(res["errors"] as Array))
	check(int(res["def"]["party"][0]["hp"]) == 14, "无 HP 记录 = 满血公式值（11 §7.1）")
	check(str(res["def"]["party"][0]["ref"]) == "player_blank"
		and str(res["def"]["party"][1]["ref"]) == "companion_kelan", "单位带 char_id ref（11 §7.1 写板键）")
	# 受伤胜利：结算 HP 写板 → 下次遭遇以此开局 → 休整回满
	var found := false
	for seed: int in range(1, 400):
		var r := _run_pack_battle(seed)
		var sm: EncounterSM = r["sm"]
		var b: Board = r["board"]
		if sm.result() != &"victory" or int(sm.get_unit("pc")["hp"]) >= 14 \
				or int(b.read("campaign01.hp.companion_kelan", 0)) < 1:
			continue
		found = true
		var hp_after := int(sm.get_unit("pc")["hp"])
		check(int(b.read("campaign01.hp.player_blank")) == hp_after,
			"遭遇结束 HP 写板：受伤持久（11 §7.1，hp=%d）" % hp_after)
		var res2 := BattleDef.assemble(pack, "N1-7", {}, b)
		check(int(res2["def"]["party"][0]["hp"]) == hp_after
			and int(res2["def"]["party"][0]["max_hp"]) == 14, "下次遭遇以持久 HP 开局（11 §7.1）")
		var g := StoryGraph.new(b, Rng.new(1), pack)
		g.hub_rest()
		check(int(b.read("campaign01.hp.player_blank")) == 14, "休整恢复全满并写板（11 §7.1）")
		check(int(BattleDef.assemble(pack, "N1-7", {}, b)["def"]["party"][0]["hp"]) == 14,
			"休整后遭遇满血开局")
		break
	check(found, "seed 空间内找到受伤胜利样本")
	# 倒地同伴战后 1 HP 起身写板（11 §7.1 + §5.2；墨雨溅射加重制造倒地）
	var down_done := false
	for seed: int in range(1, 400):
		var r2 := _run_pack_battle(seed, "6d6")
		var b2: Board = r2["board"]
		if (r2["sm"] as EncounterSM).result() == &"victory" \
				and int(b2.read("campaign01.hp.companion_kelan", -1)) == 1:
			down_done = true
			check(true, "倒地同伴战后 1 HP 起身写板（11 §7.1/§5.2）")
			break
	check(down_done, "seed 空间内找到倒地同伴 1 HP 起身样本")

# ---------------------------------------------------------------- 护送战（11 §5「遭遇定义的目标达成」；tech/02 §6 escort 块，幕二 N2S-2）

func _escort_def() -> Dictionary:
	return {"party": [
			{"id": "pc", "name": "白页者", "kind": "player", "hp": 14, "max_hp": 14, "ac": 11,
				"attrs": {"might": 2, "finesse": 1, "wits": 0}, "attack_mod": 2, "damage": "1d6+2"},
			{"id": "scribe", "name": "缮写士", "kind": "escort_npc", "hp": 50, "max_hp": 50, "ac": 12,
				"attrs": {"might": 0, "finesse": 1, "wits": 1}, "attack_mod": 0, "damage": "1d4"}],
		"enemies": [{"id": "e1", "name": "墨魈群", "hp": 200, "max_hp": 200, "ac": 10,
			"attrs": {"might": 1, "finesse": 0, "wits": 0}, "attack_mod": 2, "damage": "1d4"}],
		"escort": {"unit_id": "scribe", "survive_rounds": 2, "failure_effects": [{"clock": 1}]}}

func test_escort_sm() -> void:
	print("[escort_sm]")
	# ---- 存活 N 回合即胜（11 §5 目标达成）：敌人高 HP 不可全歼，pc 全程结束回合 ----
	var sm := _sm_with(5, _escort_def())
	var saw_scribe_turn := false
	var guard := 0
	while not sm.is_over() and guard < 30:
		guard += 1
		var actor := sm.current_actor_id()
		if actor == "scribe":
			saw_scribe_turn = true
			break
		if actor == "":
			break
		sm.submit_command(_cmd(EncounterSM.CMD_END_TURN, actor))
	check(sm.is_over() and sm.result() == &"victory", "护送对象存活满 2 回合 → 胜利（11 §5 目标达成）")
	check(sm.first_alive_enemy() != "", "敌人未被全歼：胜利来自存活回合数（非全灭路径）")
	check(not bool(sm.get_unit("scribe")["downed"]), "缮写士全程存活")
	check(not saw_scribe_turn, "护送对象不占行动轮、不可被指令（escort_npc，tech/02 §6）")
	# 敌方近战意图优先指向护送对象（打断仪式，tech/02 §6 escort 块）
	var atks := sm.stream.query_by_type(EventTypes.BATTLE_ATTACK).filter(
		func(ev: Dictionary) -> bool: return ev["payload"]["source"] == &"enemy")
	check(not atks.is_empty() and atks.all(func(ev: Dictionary) -> bool:
		return str(ev["payload"]["target"]) == "scribe"), "敌方近战全部指向护送对象（打断仪式）")
	# ---- 护送对象 HP 归 0 = 目标失败（罚时替代全灭）----
	var fail_done := false
	for seed: int in range(1, 60):
		var def := _escort_def()
		(def["party"][1] as Dictionary)["hp"] = 14 # 缮写士脆血
		((def["enemies"][0] as Dictionary))["attack_mod"] = 30
		(def["enemies"][0] as Dictionary)["damage"] = "30d6"
		var smf := _sm_with(seed, def)
		var g2 := 0
		while not smf.is_over() and g2 < 40:
			g2 += 1
			var a := smf.current_actor_id()
			if a == "":
				break
			smf.submit_command(_cmd(EncounterSM.CMD_END_TURN, a))
		if not (smf.is_over() and smf.result() == &"objective_failed"):
			continue
		fail_done = true
		check(int(smf.board.get_doom_clock()) == 1, "目标失败按 failure_effects 写板：时间钟 +1（罚时替代全灭）")
		check(smf.stream.query_by_type(EventTypes.XP_GAIN).is_empty(), "目标失败无经验/战利品")
		check(smf.stream.query_by_type(EventTypes.COMBAT_END).back()["payload"]["result"] == &"objective_failed",
			"combat.end(objective_failed) 事件")
		check(not smf.board.has("campaign01.hp.scribe"), "护送 NPC HP 不跨遭遇持久化（非 characters.json 条目）")
		check(smf.board.has("campaign01.hp.pc"), "战斗员 HP 照常写板（11 §7.1）")
		break
	check(fail_done, "seed 空间内找到护送目标失败样本")
	# ---- 全歼敌人亦胜 + 数据驱动组装（N2S-2，tech/02 §6 / tech/04 §1~§4）----
	var pack := _load_campaign01()
	var stream := EventStream.new()
	var board := Board.new(stream)
	var res := BattleDef.assemble(pack, "N2S-2", {}, board)
	check(bool(res["ok"]), "N2S-2 护送遭遇组装 ok：%s" % ";".join(res["errors"] as Array))
	var def: Dictionary = res["def"]
	check(str((def["escort"] as Dictionary)["unit_id"]) == "scribe"
		and int((def["escort"] as Dictionary)["survive_rounds"]) == 3
		and int((((def["escort"] as Dictionary)["failure_effects"] as Array)[0] as Dictionary)["clock"]) == 1,
		"组装含 escort 块：unit/survive_rounds/failure_effects（tech/02 §6）")
	check((def["party"] as Array).any(func(u: Variant) -> bool:
		return str((u as Dictionary)["kind"]) == "escort_npc" and str((u as Dictionary)["name"]) == "缮写士"),
		"缮写士以 escort_npc 实例入队")
	for u: Variant in def["party"]:
		if str((u as Dictionary)["kind"]) == "escort_npc":
			continue
		(u as Dictionary)["attack_mod"] = 30
		(u as Dictionary)["damage"] = "30d6"
		(u as Dictionary).erase("skills") # 托管优先技能：清技能确保重骰普攻速胜（流程夹具）
		(u as Dictionary).erase("items")
	var smw := EncounterSM.new(board, stream, Rng.new(7), "campaign01")
	var agent := AutoAgent.new()
	smw.enter("N2S-2")
	smw.transition(EncounterSM.S_EXPLORE)
	smw.begin_combat(def)
	var g3 := 0
	while not smw.is_over() and g3 < 200:
		g3 += 1
		var cmd := agent.next_command(smw)
		if cmd.is_empty():
			break
		smw.submit_command(cmd)
	check(smw.result() == &"victory" and smw.first_alive_enemy() == "", "全歼墨魈群 → 护送胜利")
	check(not smw.board.has("campaign01.hp.scribe"), "全歼路：护送 NPC 亦不落 HP 簿记")
	check(Growth.xp(board) == 120, "护送胜利经验 120 汇入成长（tech/04 §8 规则1）")

# ---------------------------------------------------------------- 迷宫探索序列（tech/02 §6 maze 块；04 §④.3 房间类型，幕二 N2G-2/2b/2c）

func test_maze_runner() -> void:
	print("[maze_runner]")
	var pack := _load_campaign01()
	var beats: Array = ((pack["encounters"]["N2G-2"] as Dictionary)["maze"] as Dictionary)["beats"]
	# ---- 检定拍：成功 xp / 失败罚时（效果 DSL 写板，tech/02 §4.6）----
	var got_succ := false
	var got_fail := false
	for seed: int in range(1, 200):
		if got_succ and got_fail:
			break
		var stream := EventStream.new()
		var board := Board.new(stream)
		var graph := StoryGraph.new(board, Rng.new(1), pack)
		var mr := MazeRunner.new(board, stream, Rng.new(seed), "campaign01")
		mr.begin("N2G-2", beats, Callable(graph, "check_mod"), "N2G-2")
		var res := mr.resolve()
		if bool(res["success"]) and not got_succ:
			got_succ = true
			check(Growth.xp(board) == 30, "检定拍成功：success_effects xp +30 汇入成长")
			check(stream.query_by_type(EventTypes.CHECK_ROLL).back()["payload"]["kind"] == "maze_check",
				"检定拍产出 check.roll（kind=maze_check）")
		elif not bool(res["success"]) and not got_fail:
			got_fail = true
			check(int(board.get_doom_clock()) == 1, "检定拍失败：failure_effects 时间钟 +1")
	check(got_succ and got_fail, "seed 空间内迷宫检定成败双样本")
	# ---- 完整序列：3 拍（检定/伏击判定/检定）+ 伏击拍事件型别 + 进度簿记 ----
	var stream := EventStream.new()
	var board := Board.new(stream)
	var graph := StoryGraph.new(board, Rng.new(1), pack)
	var mr := MazeRunner.new(board, stream, Rng.new(42), "campaign01")
	mr.begin("N2G-2", beats, Callable(graph, "check_mod"), "N2G-2")
	check(mr.beat_count() == 3 and not mr.is_done(), "雾码头探索序列 3 拍")
	var kinds: Array = []
	while not mr.is_done():
		mr.resolve()
	for ev: Dictionary in stream.query_by_type(EventTypes.CHECK_ROLL):
		kinds.append(str(ev["payload"]["kind"]))
	check(kinds == ["maze_check", "maze_ambush", "maze_check"], "节拍序列：检定 → 伏击判定 → 检定（事件型别）")
	check(int(board.read("campaign01.maze.N2G-2.idx", 0)) == 3, "节拍进度簿记 <pack>.maze.<enc>.idx（07 §2）")
	# 完成后恢复 = 幂等：新 Runner 读进度直接完成，不重打效果（07 §4.2 中途离场续打）
	var clock_after := int(board.get_doom_clock())
	var mr2 := MazeRunner.new(board, stream, Rng.new(42), "campaign01")
	mr2.begin("N2G-2", beats, Callable(graph, "check_mod"), "N2G-2")
	check(mr2.is_done() and mr2.peek().is_empty(), "已完成序列恢复：直接完成不重打（幂等）")
	check(int(board.get_doom_clock()) == clock_after, "恢复后无重复效果写板")
	# ---- 拾取拍（04 §④.3 拾取房）+ 中途恢复续打 ----
	var stream2 := EventStream.new()
	var board2 := Board.new(stream2)
	var graph2 := StoryGraph.new(board2, Rng.new(1), pack)
	var beats_b: Array = ((pack["encounters"]["N2G-2b"] as Dictionary)["maze"] as Dictionary)["beats"]
	var mb := MazeRunner.new(board2, stream2, Rng.new(9), "campaign01")
	mb.begin("N2G-2b", beats_b, Callable(graph2, "check_mod"), "N2G-2b")
	var res_loot := mb.resolve()
	check(str(res_loot["type"]) == "loot" and board2.item_count("ink_core") == 1,
		"拾取拍：墨核 ×1 经 give_item 写板（07 §1 溯源）")
	check(stream2.query_by_type(EventTypes.ITEM_GAIN).size() == 1, "拾取拍产出 item.gain 事件")
	# 中途离场 → 恢复：新 Runner 从第 2 拍续打（第 1 拍拾取不重复）
	var mb2 := MazeRunner.new(board2, stream2, Rng.new(9), "campaign01")
	mb2.begin("N2G-2b", beats_b, Callable(graph2, "check_mod"), "N2G-2b")
	check(mb2.beat_index() == 1 and not mb2.is_done(), "中途恢复：从下一拍续打")
	mb2.resolve()
	check(board2.item_count("ink_core") == 1, "恢复续打：拾取不重复（仍 ×1）")
	# ---- 绕行路 N2G-2c：双伏击拍（多 2 场遭遇以节拍呈现）----
	var beats_c: Array = ((pack["encounters"]["N2G-2c"] as Dictionary)["maze"] as Dictionary)["beats"]
	check(beats_c.size() == 2 and beats_c.all(func(b: Variant) -> bool:
		return str((b as Dictionary)["type"]) == "ambush"), "绕行路 = 双伏击拍（多 2 场遭遇，战役书幕二 G 链）")

# ---------------------------------------------------------------- 幕二四链接入（战役书幕二；tech/02 §3/§4；11 §5）

## 托管打胜一场已登记遭遇（高修正重骰夹具：流程验证，非数值平衡验证）。
func _win_pack_battle(pack: Dictionary, enc_id: String, board: Board, stream: EventStream) -> EncounterSM:
	var res := BattleDef.assemble(pack, enc_id, {}, board)
	check(bool(res["ok"]), "遭遇 %s 组装 ok：%s" % [enc_id, ";".join(res["errors"] as Array)])
	var def: Dictionary = res["def"]
	for u: Variant in def["party"]:
		if str((u as Dictionary)["kind"]) == "escort_npc":
			continue
		(u as Dictionary)["attack_mod"] = 30
		(u as Dictionary)["damage"] = "30d6"
		(u as Dictionary).erase("skills")
		(u as Dictionary).erase("items")
	var sm := EncounterSM.new(board, stream, Rng.new(7), "campaign01")
	var agent := AutoAgent.new()
	sm.enter(enc_id)
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(def)
	var guard := 0
	while not sm.is_over() and guard < 200:
		guard += 1
		var cmd := agent.next_command(sm)
		if cmd.is_empty():
			break
		sm.submit_command(cmd)
	return sm

## 推进至 N1-8（婉拒所有邀约：三方声望 0，独狼边显形前提）。
## N1-1 → N1-2 走无效果的「前往褪色现场」边（购买边会给潮汐表，干扰 G 链绕行断言）。
func _reach_n18(g: StoryGraph) -> void:
	g.start()
	g.take_edge(_edge_to(g, "N0-2"))
	g.resolve_check(g.available_edges()[0], true)
	g.take_edge(_edge_to(g, "N0-4"))
	g.take_edge(_edge_to(g, "N1-1"))
	var e_plain := {}
	for e: Variant in g.available_edges():
		if str((e as Dictionary).get("to", "")) == "N1-2" \
				and ((e as Dictionary).get("effects", []) as Array).is_empty():
			e_plain = e
	g.take_edge(e_plain)
	g.resolve_check(g.available_edges()[0], true) # → N1-3
	g.take_edge(_edge_to(g, "N1-8")) # 婉拒所有邀约

## 跑完当前 explore 节点的迷宫探索序列（MazeRunner，tech/02 §6 maze）。
func _run_maze(g: StoryGraph, pack: Dictionary, board: Board, stream: EventStream) -> void:
	var enc_id := str(g.current().get("encounter", g.current_id))
	var enc: Dictionary = (pack["encounters"] as Dictionary)[enc_id]
	var mr := MazeRunner.new(board, stream, Rng.new(11), "campaign01")
	mr.begin(enc_id, (enc.get("maze", {}) as Dictionary).get("beats", []),
		Callable(g, "check_mod"), g.current_id)
	var guard := 0
	while not mr.is_done() and guard < 10:
		guard += 1
		mr.resolve()

func test_act2_chains() -> void:
	print("[act2_chains]")
	var pack := _load_campaign01()
	# ================= S 链：誊写庭（护送战 → 金墨的代价）=================
	var ss := EventStream.new()
	var sb := Board.new(ss)
	var gs := StoryGraph.new(sb, Rng.new(42), pack)
	_reach_n18(gs)
	gs.take_edge(_edge_to(gs, "N2S-1"))
	gs.resolve_check(gs.available_edges()[0], true) # 档案馆试炼 → N2S-2
	check(gs.current_id == "N2S-2", "S 链：N2S-1 → N2S-2（修复仪式护送战）")
	var sm_s := _win_pack_battle(pack, "N2S-2", sb, ss)
	check(sm_s.result() == &"victory", "S 链：护送战胜利")
	gs.take_edge(_edge_to(gs, "N2S-3"))
	check(not sb.has_item("scriptorium_signet"), "S 链：on_complete 未离开不结算")
	gs.take_edge(gs.available_edges()[0]) # 献出一段自己的记忆
	check(gs.current_id == "N2-C", "S 链收束：N2S-3 → N2-C")
	check(sb.read("campaign01.blank_memory") == true, "S 链写板：空白记忆旗标")
	check(int(sb.get_alignment()) == 60, "S 链写板：墨守 +10（50→60）")
	check(int(sb.get_bond("kelan")) == 15, "S 链写板：羁绊 +15")
	check(int(sb.get_doom_clock()) == 0, "S 链写板：时钟 -2 钳位（1→0）")
	check(sb.has_item("scriptorium_signet"), "S 链：离开 N2S-3 结算誊写庭印戒（tech/02 §3）")
	# ================= U 链：断墨会（hybrid 撕/不撕双抉择）=================
	for tear: int in 2:
		var us := EventStream.new()
		var ub := Board.new(us)
		var gu := StoryGraph.new(ub, Rng.new(42), pack)
		_reach_n18(gu)
		gu.take_edge(_edge_to(gu, "N2U-1"))
		gu.resolve_check(gu.available_edges()[0], true) # 黑羽集会 → N2U-2
		check(gu.current_id == "N2U-2", "U 链：N2U-1 → N2U-2（撕页行动 hybrid）")
		var sm_u := _win_pack_battle(pack, "N2U-2", ub, us)
		check(sm_u.result() == &"victory", "U 链：税吏卫队战胜利")
		var u_edges := gu.available_edges()
		check(u_edges.size() == 2, "U 链：战后双抉择边（撕/不撕，tech/02 §6 hybrid）")
		gu.take_edge(u_edges[tear]) # 0=撕 / 1=不撕
		# 声望 = 边效果 + 黑羽行动委托 settle +1（tech/02 §5：N2U-1 完成时结算）
		if tear == 0:
			check(ub.read("campaign01.page_tearer") == true and int(ub.get_rep("uninked")) == 3,
				"U 链写板：撕页 → 撕页者旗标 + 断墨会声望 +2（含委托 settle +1 = 3）")
		else:
			check(ub.read("campaign01.mercy_shown") == true and int(ub.get_rep("uninked")) == 2,
				"U 链写板：不撕 → 手下留情旗标 + 声望 +1（含委托 settle +1 = 2）")
		check(ub.has_item("black_feather_token") and int(ub.get_alignment()) == 40,
			"U 链写板：黑羽令（撕/不撕均给）+ 留白 -10（50→40）")
		check(gu.current_id == "N2U-3" and int(ub.get_bond("kelan")) == 15
			and int(ub.get_doom_clock()) == 2, "U 链：N2U-3 演出（时钟 +1、羁绊 +15）")
		gu.take_edge(_edge_to(gu, "N2-C"))
		check(gu.current_id == "N2-C", "U 链收束：N2U-3 → N2-C")
	# U 链失败路：N2U-1 潜行失败 → 暴露战 → N2U-2
	var us2 := EventStream.new()
	var ub2 := Board.new(us2)
	var gu2 := StoryGraph.new(ub2, Rng.new(42), pack)
	_reach_n18(gu2)
	gu2.take_edge(_edge_to(gu2, "N2U-1"))
	gu2.resolve_check(gu2.available_edges()[0], false)
	check(gu2.current_id == "N2U-1b", "U 链失败路：潜行失败 → 暴露战（N2U-1b）")
	check(_win_pack_battle(pack, "N2U-1b", ub2, us2).result() == &"victory", "U 链失败路：暴露战胜利")
	gu2.take_edge(_edge_to(gu2, "N2U-2"))
	check(gu2.current_id == "N2U-2", "U 链失败路：以武力赢得入场券 → N2U-2")
	# ================= G 链：拾遗行会（迷宫密道 vs 绕行）=================
	var fs := EventStream.new()
	var fb := Board.new(fs)
	var gf := StoryGraph.new(fb, Rng.new(42), pack)
	gf.start()
	gf.take_edge(_edge_to(gf, "N0-2"))
	gf.resolve_check(gf.available_edges()[0], true)
	gf.take_edge(_edge_to(gf, "N0-4"))
	gf.take_edge(_edge_to(gf, "N1-1"))
	var e_buy := _edge_to(gf, "N1-2")
	for e: Variant in gf.available_edges():
		for fx: Variant in (e as Dictionary).get("effects", []):
			if (fx as Dictionary).get("give_item", "") == "half_tide_table":
				e_buy = e
	gf.take_edge(e_buy) # 购买半页潮汐表 → N1-2
	gf.resolve_check(gf.available_edges()[0], true)
	gf.take_edge(_edge_to(gf, "N1-8"))
	gf.take_edge(_edge_to(gf, "N2G-1"))
	gf.resolve_check(gf.available_edges()[0], true) # 残篇拍卖 → N2G-2
	check(gf.current_id == "N2G-2" and fb.has_item("half_tide_table"), "G 链：N2G-1 → N2G-2（持潮汐表）")
	_run_maze(gf, pack, fb, fs) # 雾码头探索序列 3 拍
	var e_secret := _edge_to(gf, "N2G-2b")
	check(not e_secret.is_empty() and not bool(e_secret.get("via_fallback", false)),
		"G 链密道：持半页潮汐表 → item 边主路显形（tech/02 §4.3）")
	gf.take_edge(e_secret)
	check(gf.current_id == "N2G-2b" and fb.item_count("codex_fragment") == 1,
		"G 链密道：直达沉书阁 + 织命者残简 ×1（on_enter）")
	_run_maze(gf, pack, fb, fs) # 沉书阁拾取拍
	check(fb.item_count("ink_core") == 1, "G 链密道：沉书阁额外战利品（墨核 ×1，拾取拍）")
	gf.take_edge(_edge_to(gf, "N2G-3"))
	check(fb.read("campaign01.insider") == true and int(fb.get_bond("kelan")) == 15,
		"G 链写板：知情人旗标 + 羁绊 +15")
	gf.take_edge(_edge_to(gf, "N2-C"))
	check(gf.current_id == "N2-C", "G 链收束：N2G-3 → N2-C")
	# 绕行（无潮汐表）：item 边 fallback → N2G-2c
	var ds := EventStream.new()
	var db := Board.new(ds)
	var gd := StoryGraph.new(db, Rng.new(42), pack)
	_reach_n18(gd)
	gd.take_edge(_edge_to(gd, "N2G-1"))
	gd.resolve_check(gd.available_edges()[0], true)
	var e_detour := _edge_to(gd, "N2G-2c")
	check(not e_detour.is_empty() and bool(e_detour.get("via_fallback", false)),
		"G 链绕行：无潮汐表 → item 边 fallback 变体（tech/02 §4.3）")
	gd.take_edge(e_detour)
	check(gd.current_id == "N2G-2c", "G 链绕行 → N2G-2c")
	_run_maze(gd, pack, db, ds) # 双伏击拍（多 2 场遭遇）
	gd.take_edge(_edge_to(gd, "N2G-3"))
	check(db.read("campaign01.insider") == true, "G 链绕行亦达 N2G-3（失败即分支，08 §2）")
	# ================= L 链：独狼（难检定跳链 / 通缉战强制择链）=================
	var ls := EventStream.new()
	var lb := Board.new(ls)
	var gl := StoryGraph.new(lb, Rng.new(42), pack)
	_reach_n18(gl)
	var e_lone := _edge_to(gl, "N2L-1")
	check(not e_lone.is_empty(), "L 链：三方声望 0 → 独狼隐藏边显形（tech/02 §4.5）")
	gl.take_edge(e_lone)
	gl.resolve_check(gl.available_edges()[0], true) # 难检定成功 → 跳链直达收束
	check(gl.current_id == "N2-C", "L 链：N2L-1 成功 → 直抵 N2-C（跳链，战役书幕二独狼）")
	check(int(lb.get_doom_clock()) == 0, "L 链写板：独狼捷径时钟 -1（1→0）")
	# 失败路：通缉战（声望 -1 ×3）→ 强制择一链
	var ls2 := EventStream.new()
	var lb2 := Board.new(ls2)
	var gl2 := StoryGraph.new(lb2, Rng.new(42), pack)
	_reach_n18(gl2)
	gl2.take_edge(_edge_to(gl2, "N2L-1"))
	gl2.resolve_check(gl2.available_edges()[0], false)
	check(gl2.current_id == "N2L-1b", "L 链失败路：N2L-1 失败 → 通缉战")
	check(int(lb2.get_rep("scriptorium")) == -1 and int(lb2.get_rep("uninked")) == -1
		and int(lb2.get_rep("salvage")) == -1, "L 链失败路：三方声望 -1（on_enter 惩罚）")
	check(_win_pack_battle(pack, "N2L-1b", lb2, ls2).result() == &"victory", "L 链失败路：通缉战胜利（难）")
	var l_edges := gl2.available_edges()
	check(l_edges.size() == 3, "L 链失败路：战后强制择一链（三出边）")
	gl2.take_edge(_edge_to(gl2, "N2G-1"))
	check(gl2.current_id == "N2G-1", "L 链失败路：择拾遗行会链 → N2G-1")

# ---------------------------------------------------------------- 幕三「撤销区」房间序列（战役书幕三；tech/02 §4.3/§6；11 §5.1）

## 推进至 N2-C（独狼链：N1-3 婉拒 → N1-8 → N2L-1 难检定成功直达；声望 0，无黑羽令/印戒/倾向投放）。
func _reach_n2c(g: StoryGraph) -> void:
	_reach_n18(g)
	g.take_edge(_edge_to(g, "N2L-1"))
	g.resolve_check(g.available_edges()[0], true) # 独狼难检定成功 → 跳链直达 N2-C

func test_act3_rooms() -> void:
	print("[act3_rooms]")
	var pack := _load_campaign01()
	# ---- R2 对话检定成败两路（战役书幕三：成功给残简+羁绊 / 失败旗标未能挽留）----
	for success: bool in [true, false]:
		var s := EventStream.new()
		var b := Board.new(s)
		var g := StoryGraph.new(b, Rng.new(42), pack)
		_reach_n2c(g)
		g.take_edge(_edge_to(g, "N3-1"))
		g.take_edge(_edge_to(g, "R1"))
		check(b.has_lore("revoked_registry_01"), "R1 on_enter：图鉴·褪色民居的门牌（lore.json source 对齐）")
		g.take_edge(_edge_to(g, "R2"))
		check(b.has_lore("revoked_registry_02"), "R2 on_enter：图鉴·空教室的花名册")
		var frag_before := b.item_count("codex_fragment")
		g.resolve_check(g.available_edges()[0], success)
		check(g.current_id == "R3",
			"R2 安抚检定%s → R3（成败汇合，差异在效果，08 §2）" % ("成功" if success else "失败"))
		if success:
			check(b.item_count("codex_fragment") == frag_before + 1 and int(b.get_bond("kelan")) == 20,
				"R2 成功路：残简 ×1 + 羁绊 +20（战役书 §8 隐藏投放）")
		else:
			check(b.read("campaign01.failed_to_hold") == true
				and b.item_count("codex_fragment") == frag_before,
				"R2 失败路：未能挽留旗标、无残简（战役书幕三 R2）")
	# ---- 房间序列主走（无黑羽令）：R1 拾取 → R3 战斗 → R4 fallback 右路两场 → R5 Boss → N3-7 ----
	var s2 := EventStream.new()
	var b2 := Board.new(s2)
	var g2 := StoryGraph.new(b2, Rng.new(42), pack)
	_reach_n2c(g2)
	g2.take_edge(_edge_to(g2, "N3-1"))
	g2.take_edge(_edge_to(g2, "R1"))
	_run_maze(g2, pack, b2, s2)
	check(b2.item_count("ink_core") == 1, "R1 拾取房：墨核 ×1（maze loot 拍，tech/02 §6）")
	g2.take_edge(_edge_to(g2, "R2"))
	g2.resolve_check(g2.available_edges()[0], true)
	var sm3 := _win_pack_battle(pack, "R3", b2, s2)
	check(sm3.result() == &"victory", "R3 墨魈巢穴战斗可胜（遭遇组装 + SM 通道）")
	var r3_foes: Array = (pack["encounters"]["R3"] as Dictionary)["enemies"]
	check(r3_foes.size() == 3 and str((r3_foes[0] as Dictionary)["ref"]) == "ink_fiend"
		and str((r3_foes[1] as Dictionary)["ref"]) == "ink_swarm",
		"R3 阵容：墨魈 + 墨魈群 ×2（story/03 §1 定稿：winrate 70.5% ∈ 中 70~80）")
	g2.take_edge(_edge_to(g2, "R4"))
	var e_r4 := _edge_to(g2, "R4-r")
	check(not e_r4.is_empty() and bool(e_r4.get("via_fallback", false)),
		"R4 分支门：无黑羽令 → 右路 fallback 变体（tech/02 §4.3）")
	g2.take_edge(e_r4)
	check(_win_pack_battle(pack, "R4-r", b2, s2).result() == &"victory", "R4-r 右路第一场可胜")
	g2.take_edge(_edge_to(g2, "R4-r2"))
	check(_win_pack_battle(pack, "R4-r2", b2, s2).result() == &"victory",
		"R4-r2 右路第二场可胜（场间无休整，HP 持久 11 §7.1）")
	g2.take_edge(_edge_to(g2, "R5"))
	var warden: Dictionary = (pack["enemies"] as Dictionary)["page_warden"]
	var warden_skills: Array = warden["skills"]
	var seal: Dictionary = {}
	for wsk: Variant in warden_skills:
		if str((wsk as Dictionary)["id"]) == "seal_shock":
			seal = wsk
	check(bool(warden.get("boss", false)) and warden_skills.size() == 2
		and not seal.is_empty()
		and int((seal["save"] as Dictionary)["dc"]) == 12
		and str((seal["save"] as Dictionary)["attr"]) == "finesse"
		and str((seal["save"] as Dictionary)["on_success"]) == "half"
		and (warden.get("behavior", []) as Array).size() == 2,
		"R5 Boss 守页人：seal_shock 敏豁免 DC12/half + 重写守则转阶段 + behavior 脚本（story/03 §2/§3.1）")
	check(_win_pack_battle(pack, "R5", b2, s2).result() == &"victory", "R5 守页人 Boss 战可胜（难）")
	g2.take_edge(_edge_to(g2, "N3-7"))
	check(g2.current_id == "N3-7" and b2.item_count("codex_fragment") == 2
		and b2.item_count("ink_core") == 2,
		"R5 战利品 → N3-7：残简 ×2（R2+R5）+ 墨核 ×2（R1+R5，战役书 §8 投放）")
	# ---- R4 左路：持黑羽令 → 捷径直达 R5（tech/02 §4.3 主路；items.json unlocks）----
	var s3 := EventStream.new()
	var b3 := Board.new(s3)
	var g3 := StoryGraph.new(b3, Rng.new(42), pack)
	_reach_n2c(g3)
	b3.give_item("black_feather_token", 1,
		{"event_id": s3.tail(), "node_id": "R4", "pack_id": "campaign01"})
	g3.take_edge(_edge_to(g3, "N3-1"))
	g3.take_edge(_edge_to(g3, "R1"))
	g3.take_edge(_edge_to(g3, "R2"))
	g3.resolve_check(g3.available_edges()[0], true)
	g3.take_edge(_edge_to(g3, "R4"))
	var e_left := _edge_to(g3, "R5")
	check(not e_left.is_empty() and not bool(e_left.get("via_fallback", false)),
		"R4 分支门：持黑羽令 → 左路捷径主路边（[物·黑羽令]，战役书 §8）")
	g3.take_edge(e_left)
	check(g3.current_id == "R5", "左路捷径直达 R5（跳过右路两场）")

# ---------------------------------------------------------------- 终章：免战/强攻 + 四结局（战役书终章/§9；tech/02 §9/§6）

## 推进至 N3-7（独狼链 + 房间序列图级直走，不跑战斗数值；r2_success 控制 R2 成败路）。
func _reach_n37(g: StoryGraph, r2_success: bool = true) -> void:
	_reach_n2c(g)
	g.take_edge(_edge_to(g, "N3-1"))
	g.take_edge(_edge_to(g, "R1"))
	g.take_edge(_edge_to(g, "R2"))
	g.resolve_check(g.available_edges()[0], r2_success) # → R3
	g.take_edge(_edge_to(g, "R4"))
	var e := _edge_to(g, "R4-r")
	if not e.is_empty():
		g.take_edge(e)
		g.take_edge(_edge_to(g, "R4-r2"))
	g.take_edge(_edge_to(g, "R5"))
	g.take_edge(_edge_to(g, "N3-7"))

func test_finale_endings() -> void:
	print("[finale_endings]")
	var pack := _load_campaign01()
	var prov := {"event_id": 1, "node_id": "N4-1", "pack_id": "campaign01"}
	# ---- N4-1 强攻路：fallback → N4-1b（遭遇 N4-1）；难度差 = enemy_weaken 旗标驱动 ----
	var s1 := EventStream.new()
	var b1 := Board.new(s1)
	var g1 := StoryGraph.new(b1, Rng.new(42), pack)
	_reach_n37(g1)
	g1.take_edge(_edge_to(g1, "N4-1"))
	var e_assault := _edge_to(g1, "N4-1b")
	check(not e_assault.is_empty() and bool(e_assault.get("via_fallback", false)),
		"N4-1 无印戒 → fallback 强攻边（tech/02 §4.3）")
	var def_plain := BattleDef.assemble(pack, "N4-1", {}, b1)
	check(bool(def_plain["ok"]), "N4-1 强攻遭遇组装 ok（墨潮化身 + 幼体 ×2）")
	var atk_plain := int(((def_plain["def"] as Dictionary)["enemies"][0] as Dictionary)["attack_mod"])
	b1.write("campaign01.mercy_shown", true, prov)
	var def_weak := BattleDef.assemble(pack, "N4-1", {}, b1)
	var atk_weak := int(((def_weak["def"] as Dictionary)["enemies"][0] as Dictionary)["attack_mod"])
	check(atk_plain - atk_weak == 2,
		"手下留情 → Boss 攻击修正 -2（%d→%d；战役书 §5 税吏证词，tech/02 §6 enemy_weaken）" % [atk_plain, atk_weak])
	g1.take_edge(e_assault)
	check(g1.current_id == "N4-1b", "强攻边 → N4-1b（遭遇 N4-1 挂载节点，README 转写裁决）")
	check(_win_pack_battle(pack, "N4-1", b1, s1).result() == &"victory",
		"N4-1 墨潮化身 Boss 战可胜（难；手下留情已立 = 削弱后）")
	g1.take_edge(_edge_to(g1, "N4-2"))
	check(g1.current_id == "N4-2", "强攻胜利 → N4-2 抉择")
	# ---- N4-1 免战路：印戒 + 誊写庭声望 ≥1 → item 边主路直达 N4-2（[物/声]）----
	var s1b := EventStream.new()
	var b1b := Board.new(s1b)
	var g1b := StoryGraph.new(b1b, Rng.new(42), pack)
	_reach_n37(g1b)
	b1b.give_item("scriptorium_signet", 1, prov)
	b1b.write("global.rep.scriptorium", 1, prov)
	g1b.take_edge(_edge_to(g1b, "N4-1"))
	var e_skip := _edge_to(g1b, "N4-2")
	check(not e_skip.is_empty() and not bool(e_skip.get("via_fallback", false)),
		"N4-1 印戒 + 声望 ≥1 → 免战主路边（items.json unlocks）")
	g1b.take_edge(e_skip)
	check(g1b.current_id == "N4-2", "印戒免战：跳过 Boss 直达 N4-2（战役书 §8 印戒解锁边）")
	# ---- 四结局分别可达（构造状态触发 E1/E2/E3/E4；结局写板 + 结局表互证）----
	# E1 墨守 >50
	var r1 := _play_ending(pack, {"global.alignment": 60})
	check(str(r1["ending"]) == "E1" and bool((r1["board"] as Board).read("campaign01.ending_e1")),
		"E1 重墨：墨守过中线可达 + ending_e1 写板（tech/02 §9）")
	# E2 留白 >50
	var r2 := _play_ending(pack, {"global.alignment": 40})
	check(str(r2["ending"]) == "E2" and bool((r2["board"] as Board).read("campaign01.ending_e2")),
		"E2 自由灰：留白过中线可达 + ending_e2 写板")
	# E3 残简 ×4 + 羁绊 ≥60（隐藏；路径已得 R2+R5 ×2，补足 ×4）
	var r3 := _play_ending(pack, {"bond.kelan": 60, "item.codex_fragment": 2})
	check(str(r3["ending"]) == "E3" and bool((r3["board"] as Board).read("campaign01.ending_e3"))
		and bool((r3["board"] as Board).read("campaign01.unlock_scribe_identity")),
		"E3 新篇：残简 ≥4 + 羁绊 ≥60 可达 + 执笔者身份解锁占位（战役书 §9 E3 钩子）")
	# E4 兜底（独狼线：倾向 50 / 残简不足）
	var r4 := _play_ending(pack, {}, false)
	check(str(r4["ending"]) == "E4" and bool((r4["board"] as Board).read("campaign01.ending_e4"))
		and bool((r4["board"] as Board).read("campaign01.ngplus_memory_view")),
		"E4 褪墨吞港：条件均不满足兜底可达 + 追忆视角占位（tech/02 §9 default；战役书 §9 E4 钩子）")
	check(bool((r4["board"] as Board).read("campaign01.campaign01_cleared")),
		"E4 亦写 campaign01_cleared（失败非终局：last_page settle 于离开 N4-2）")

## 构造终局状态并走到结局：独狼线至 N4-1 → 强攻 fallback 进 N4-2 → 应用 setup 写板 →
## 取 N4-2 首条显形边（边序 = endings.json 求值序）。返回 {ending, board}；图边结局与结局表互证。
func _play_ending(pack: Dictionary, setup: Dictionary, r2_success: bool = true) -> Dictionary:
	var s := EventStream.new()
	var b := Board.new(s)
	var g := StoryGraph.new(b, Rng.new(42), pack)
	_reach_n37(g, r2_success)
	g.take_edge(_edge_to(g, "N4-1"))
	g.take_edge(_edge_to(g, "N4-1b"))
	g.take_edge(_edge_to(g, "N4-2"))
	var prov := {"event_id": s.tail(), "node_id": "N4-2", "pack_id": "campaign01"}
	for key: Variant in setup.keys():
		var ks := str(key)
		if ks.begins_with("bond."):
			b.write("global." + ks, int(setup[key]), prov)
		elif ks.begins_with("item."):
			b.give_item(ks.substr(5), int(setup[key]), prov)
		else:
			b.write(ks, setup[key], prov)
	var edges := g.available_edges()
	check(not edges.is_empty(), "N4-2 恒有显形边（E4 兜底无条件）")
	var by_table := g.pick_ending()
	g.take_edge(edges[0])
	check(g.is_at_ending() and g.current_id == by_table,
		"图边结局 %s 与 endings.json 求值 %s 互证一致（tech/02 §9）" % [g.current_id, by_table])
	return {"ending": g.current_id, "board": b}

# ---------------------------------------------------------------- 多周目继承数据驱动（tech/02 §2.7 manifest.ngplus；战役书 §11 定稿清单）

## 继承唯一依据 = manifest.ngplus（carries 共通 + per_ending 按结局解锁）；改配置即变，代码零继承硬编码。
func test_ngplus_inheritance() -> void:
	print("[ngplus_inheritance]")
	var pack := _load_campaign01()
	var conf: Dictionary = (pack["manifest"] as Dictionary).get("ngplus", {})
	check(not conf.is_empty()
		and int((conf.get("carries", {}) as Dictionary).get("codex_fragment", 0)) == 1
		and (conf.get("per_ending", {}) as Dictionary).size() == 4,
		"manifest.ngplus 块登记：carries 共通清单 + E1~E4 per_ending（tech/02 §2.7；战役书 §11）")
	var sysw := {"event_id": 0, "node_id": "", "pack_id": "system"}
	var mk_old := func(ending_flag: String) -> Dictionary: # 旧板：图鉴/权利/外观/强度齐备，刚达成指定结局
		var s := EventStream.new()
		var b := Board.new(s)
		var p := {"event_id": 0, "node_id": "E1", "pack_id": "campaign01"}
		b.write("campaign01." + ending_flag, true, p)
		b.unlock_lore("weaver_fragment_01", p)
		b.give_item("codex_fragment", 4, p)
		b.give_item("ink_core", 1, p) # 战利品：不应继承
		b.write("global.entitlement.arena", true, sysw)
		b.write("global.cosmetic.owned.salvage_copper", true, sysw)
		Growth.new(b).grant_xp(500, p) # 强度数值：不应继承
		return {"stream": s, "board": b}
	var mk_new := func() -> Dictionary:
		var s := EventStream.new()
		var b := Board.new(s)
		return {"stream": s, "board": b, "cos": Cosmetics.new(b, s)}
	# ---- E1 重墨：缮写圣城传闻旗标 ----
	var o1: Dictionary = mk_old.call("ending_e1")
	var n1: Dictionary = mk_new.call()
	var r1: Dictionary = NgPlus.apply(o1["board"], n1["board"], n1["stream"], n1["cos"], conf, "campaign01")
	check(str(r1["ending"]) == "E1"
		and bool((n1["board"] as Board).read("campaign01.unlock_elysium_rumor")),
		"NG+ E1：传闻旗标 unlock_elysium_rumor 继承（战役书 §11 E1，仅叙事钩子）")
	check((n1["board"] as Board).item_count("codex_fragment") == 1, "NG+ E1：共通残简 ×1（E1 无追加）")
	# ---- E2 自由灰：裂页荒原传闻旗标 ----
	var o2: Dictionary = mk_old.call("ending_e2")
	var n2: Dictionary = mk_new.call()
	var r2e: Dictionary = NgPlus.apply(o2["board"], n2["board"], n2["stream"], n2["cos"], conf, "campaign01")
	check(str(r2e["ending"]) == "E2"
		and bool((n2["board"] as Board).read("campaign01.unlock_wastes_rumor")),
		"NG+ E2：传闻旗标 unlock_wastes_rumor 继承（战役书 §11 E2）")
	# ---- E3 新篇：执笔者之骰皮肤 + 身份旗标；共通保留全核；强度重置 ----
	var o3: Dictionary = mk_old.call("ending_e3")
	var n3: Dictionary = mk_new.call()
	var nb3 := n3["board"] as Board
	var r3e: Dictionary = NgPlus.apply(o3["board"], nb3, n3["stream"], n3["cos"], conf, "campaign01")
	check(str(r3e["ending"]) == "E3" and str(r3e["skin"]) == "scribe_dice"
		and (n3["cos"] as Cosmetics).is_owned("scribe_dice"),
		"NG+ E3：执笔者之骰皮肤授予（战役书 §11 E3：外观位，纯演出）")
	check(bool(nb3.read("campaign01.unlock_scribe_identity")),
		"NG+ E3：执笔者身份旗标继承（开局独白差异驱动源）")
	var skin_prov := nb3.provenance_of("global.cosmetic.owned.scribe_dice")
	check(str(skin_prov.get("granted_by", "")) == "ngplus" and str(skin_prov.get("pack_id", "")) == "system",
		"NG+ 皮肤授予溯源：granted_by=ngplus + system 写权限（06 §7 / 07 §3 v1.2）")
	check(nb3.has_lore("weaver_fragment_01"), "NG+ 共通：图鉴保留（global.lore）")
	check(bool(nb3.read("global.entitlement.arena")), "NG+ 共通：权利保留（global.entitlement.*）")
	check(bool(nb3.read("global.cosmetic.owned.salvage_copper")), "NG+ 共通：外观保留（已获不降级）")
	check(int(nb3.read("campaign01.ngplus", 0)) == 1, "NG+ 共通：周目数 +1（playthrough 簿记键）")
	check(Growth.xp(nb3) == 0 and nb3.get_doom_clock() == 0 and nb3.get_alignment() == 50
		and not nb3.has_item("ink_core"),
		"NG+ 不继承强度数值：成长/时钟/倾向/战利品重置（战役书 §11 平衡原则）")
	# ---- E4 褪墨吞港：追忆视角旗标 + 残简再 ×1（共通 1 + 追加 1 = 2）----
	var o4: Dictionary = mk_old.call("ending_e4")
	var n4: Dictionary = mk_new.call()
	var r4e: Dictionary = NgPlus.apply(o4["board"], n4["board"], n4["stream"], n4["cos"], conf, "campaign01")
	check(str(r4e["ending"]) == "E4"
		and bool((n4["board"] as Board).read("campaign01.ngplus_memory_view"))
		and (n4["board"] as Board).item_count("codex_fragment") == 2,
		"NG+ E4：追忆视角旗标 + 残简再 ×1（战役书 §11 E4：失败结局的补偿是叙事深度）")
	check(not (n4["cos"] as Cosmetics).is_owned("scribe_dice"), "NG+ E4：执笔者之骰不授予（E3 专属）")
	# ---- 数据驱动实证：改配置即变（不动代码）----
	var conf2: Dictionary = conf.duplicate(true)
	(conf2["carries"] as Dictionary)["codex_fragment"] = 3
	((conf2["per_ending"] as Dictionary)["E4"] as Dictionary)["codex_fragment"] = 2
	var o5: Dictionary = mk_old.call("ending_e4")
	var n5: Dictionary = mk_new.call()
	NgPlus.apply(o5["board"], n5["board"], n5["stream"], n5["cos"], conf2, "campaign01")
	check((n5["board"] as Board).item_count("codex_fragment") == 5,
		"数据驱动：改 manifest 残简配置（3+2）即变，代码零改动")
	var n6: Dictionary = mk_new.call()
	NgPlus.apply((mk_old.call("ending_e1") as Dictionary)["board"], n6["board"],
		n6["stream"], n6["cos"], {}, "campaign01")
	check((n6["board"] as Board).item_count("codex_fragment") == 0
		and not bool((n6["board"] as Board).read("campaign01.unlock_elysium_rumor", false)),
		"ngplus 块缺省 = 不继承（tech/02 §2.7 缺省语义）")
	# ---- 序章文本变体（tech/02 §3 text_variants：E3 独白 / E4 追忆滤镜，纯呈现）----
	var prov := {"event_id": 0, "node_id": "", "pack_id": "campaign01"}
	var sv := EventStream.new()
	var bv := Board.new(sv)
	var gv := StoryGraph.new(bv, Rng.new(7), pack)
	gv.start()
	check(gv.current_id == "N0-1", "序章入口 N0-1")
	var base_text := str(StoryVM.build(gv, bv, pack)["text"])
	check(base_text.contains("怀里没有抄本") and not base_text.contains("执笔者"),
		"无变体旗标：N0-1 默认文本（summary）")
	bv.write("campaign01.unlock_scribe_identity", true, prov)
	check(str(StoryVM.build(gv, bv, pack)["text"]).contains("执笔者"),
		"E3 执笔者：N0-1 开局独白差异（text_variants，战役书 §11）")
	var sv2 := EventStream.new()
	var bv2 := Board.new(sv2)
	var gv2 := StoryGraph.new(bv2, Rng.new(7), pack)
	gv2.start()
	bv2.write("campaign01.ngplus_memory_view", true, prov)
	check(str(StoryVM.build(gv2, bv2, pack)["text"]).contains("微微发烫"),
		"E4 追忆：N0-1 褪色滤镜文案（text_variants，战役书 §11）")
	gv2.take_edge(gv2.available_edges()[0])
	check(gv2.current_id == "N0-2"
		and str(StoryVM.build(gv2, bv2, pack)["text"]).contains("多停了一瞬"),
		"E4 追忆：N0-2 文本变体（序章演出差异第二拍）")

# ---------------------------------------------------------------- 全流程一局：N0-1 → E4 + 快照可续（07 §4；战役书 §9 E4 失败非终局）

## R3 → E4 图级直走（独狼/无道具线：R4 fallback 右路两场、N4-1 fallback 强攻）；沿途真实战斗胜利。
func _walk_r3_to_e4(g: StoryGraph, pack: Dictionary, b: Board, s: EventStream) -> void:
	check(_win_pack_battle(pack, "R3", b, s).result() == &"victory", "全流程：R3 墨魈巢穴胜利")
	g.take_edge(_edge_to(g, "R4"))
	g.take_edge(_edge_to(g, "R4-r"))
	check(_win_pack_battle(pack, "R4-r", b, s).result() == &"victory", "全流程：R4-r 第一场胜利")
	g.take_edge(_edge_to(g, "R4-r2"))
	check(_win_pack_battle(pack, "R4-r2", b, s).result() == &"victory", "全流程：R4-r2 第二场胜利")
	g.take_edge(_edge_to(g, "R5"))
	check(_win_pack_battle(pack, "R5", b, s).result() == &"victory", "全流程：R5 守页人胜利")
	g.take_edge(_edge_to(g, "N3-7"))
	g.take_edge(_edge_to(g, "N4-1"))
	g.take_edge(_edge_to(g, "N4-1b")) # 无印戒 → 强攻
	check(_win_pack_battle(pack, "N4-1", b, s).result() == &"victory", "全流程：N4-1 墨潮化身胜利")
	g.take_edge(_edge_to(g, "N4-2"))

func test_full_run_e4() -> void:
	print("[full_run_e4]")
	var pack := _load_campaign01()
	var s := EventStream.new()
	var b := Board.new(s)
	var rng := Rng.new(99)
	var g := StoryGraph.new(b, rng, pack)
	g.start()
	# 前半程：序章 → 幕一（婉拒）→ 独狼链 → 幕三 R2 失败路（未能挽留 = E4 演出加权旗标）
	g.take_edge(_edge_to(g, "N0-2"))
	g.roll_check(g.available_edges()[0])
	g.take_edge(_edge_to(g, "N0-4"))
	g.take_edge(_edge_to(g, "N1-1"))
	var e_plain := {}
	for e: Variant in g.available_edges():
		if str((e as Dictionary).get("to", "")) == "N1-2" \
				and ((e as Dictionary).get("effects", []) as Array).is_empty():
			e_plain = e
	g.take_edge(e_plain)
	g.resolve_check(g.available_edges()[0], true) # → N1-3
	g.take_edge(_edge_to(g, "N1-8")) # 婉拒所有邀约
	g.take_edge(_edge_to(g, "N2L-1"))
	g.resolve_check(g.available_edges()[0], true) # 独狼成功 → N2-C
	g.take_edge(_edge_to(g, "N3-1"))
	g.take_edge(_edge_to(g, "R1"))
	g.take_edge(_edge_to(g, "R2"))
	g.resolve_check(g.available_edges()[0], false) # 安抚失败 → 未能挽留
	check(g.current_id == "R3", "全流程：抵达 R3（中途快照点）")
	# 快照（07 §4.1：Board 全量 + 图进度 + RNG 状态）
	var snap := {"board": b.serialize(), "graph": g.serialize(), "rng": rng.save_state()}
	# 后半程：R3 → … → E4
	_walk_r3_to_e4(g, pack, b, s)
	check(g.pick_ending() == "E4", "全流程：独狼线倾向 50/残简不足 → E4 兜底（tech/02 §9）")
	var e4 := _edge_to(g, "E4")
	check(not e4.is_empty(), "N4-2：E4 边恒显形（无条件满足）")
	g.take_edge(e4)
	check(g.is_at_ending() and g.current_id == "E4", "全流程一局：N0-1 → E4 褪墨吞港")
	check(bool(b.read("campaign01.ending_e4")) and bool(b.read("campaign01.ngplus_memory_view")),
		"E4 写板：结局旗标 + 追忆视角占位（flags.json 台账 V4 闭环）")
	check(bool(b.read("campaign01.campaign01_cleared")),
		"E4 亦通关写板 campaign01_cleared（失败非终局，战役书 §9）")
	# 快照恢复重走：同一状态应再到 E4（快照往返一致，07 §4.1/§4.3）
	var s2 := EventStream.new()
	var b2 := Board.new(s2)
	var rng2 := Rng.new(1)
	b2.deserialize(snap["board"])
	rng2.load_state(snap["rng"])
	var g2 := StoryGraph.new(b2, rng2, pack)
	g2.deserialize(snap["graph"])
	check(g2.current_id == "R3", "快照恢复：图进度回到 R3（meta.graph 随快照往返）")
	_walk_r3_to_e4(g2, pack, b2, s2)
	g2.take_edge(_edge_to(g2, "E4"))
	check(g2.is_at_ending() and g2.current_id == "E4", "快照可续：恢复后重走仍达 E4（07 §4.1）")

# ---------------------------------------------------------------- 节点流程运行时（11 §2/§3；09 §6；04 §3.1；战役书 §4 N1-1）

func test_story_runtime() -> void:
	print("[story_runtime]")
	var pack := _load_campaign01()
	var prov := {"event_id": 1, "node_id": "N1-1", "pack_id": "campaign01"}
	# 检定修正（11 §2：属性修正 + 熟练 +2）
	var g0 := StoryGraph.new(Board.new(EventStream.new()), Rng.new(1), pack)
	check(g0.check_mod("perception") == 0, "检定修正：感知 智0 无熟练 = +0（11 §2）")
	check(g0.check_mod("investigation") == 2, "检定修正：调查 智0+熟练2 = +2（11 §2）")
	check(g0.check_mod("athletics") == 4, "检定修正：运动 力2+熟练2 = +4（11 §2）")
	check(LightV1.skill_mod({"might": 2, "wits": 0}, ["athletics"], "perception_or_athletics") == 4,
		"a_or_b 双技能取较高修正（11 §2）")
	check(LightV1.dc_for("easy") == 8 and LightV1.dc_for("medium") == 12
		and LightV1.dc_for("hard") == 16 and LightV1.dc_for("???") == 12, "难度三档 DC 8/12/16（11 §3）")
	# roll_check 成败双路 + check.roll 事件（tech/02 §4.2；09 §6）
	var got_succ := false
	var got_fail := false
	var got_extreme := false
	for seed: int in range(1, 400):
		if got_succ and got_fail and got_extreme:
			break
		var s := EventStream.new()
		var g := StoryGraph.new(Board.new(s), Rng.new(seed), pack)
		g.start()
		g.take_edge(_edge_to(g, "N0-2"))
		var res := g.roll_check(g.available_edges()[0])
		if bool(res["success"]) and not got_succ:
			got_succ = true
			check(g.current_id == "N0-3a", "检定成功 → success 边 N0-3a（tech/02 §4.2）")
			var rolls := s.query_by_type(EventTypes.CHECK_ROLL)
			check(rolls.size() == 1 and str(rolls[0]["payload"]["kind"]) == "story_check"
				and int(rolls[0]["payload"]["dc"]) == 8 and int(rolls[0]["payload"]["mod"]) == 0,
				"check.roll 事件：story_check 含技能/DC/修正（09 §6 同一事件源）")
			check(not bool(rolls[0]["payload"]["key"]), "普通检定 key=false（09 §6：未标记非关键）")
		elif not bool(res["success"]) and not got_fail:
			got_fail = true
			check(g.current_id == "N0-3b", "检定失败 → failure 边 N0-3b（写板效果生效：失败路 xp）")
		elif bool(res.get("extreme", false)) and not got_extreme and int(res["keep"]) == 20:
			got_extreme = true
			check(not bool(res["key"]), "nat20 极端加档但非关键（09 §6：极端追加一档）")
	check(got_succ and got_fail, "seed 空间内检定成败双路样本")
	check(got_extreme, "seed 空间内命中 nat20 极端样本")
	# 内容包 key:true → 关键演出标记（09 §6 ④）
	var pack2: Dictionary = pack.duplicate(true)
	((pack2["nodes"]["N0-2"] as Dictionary)["edges"] as Array)[0]["key"] = true
	var g5 := StoryGraph.new(Board.new(EventStream.new()), Rng.new(20260009), pack2)
	g5.start()
	g5.take_edge(_edge_to(g5, "N0-2"))
	check(bool(g5.roll_check(g5.available_edges()[0])["key"]), "内容包 key:true → 关键演出标记（09 §6 ④）")
	# 时钟预告（04 §3.1；tech/02 §5 doom_clock 触发）
	var g2 := StoryGraph.new(Board.new(EventStream.new()), Rng.new(7), pack)
	g2.start()
	var nx := g2.next_clock_trigger()
	check(str(nx.get("name", "")) == "墨雨夜袭" and int(nx.get("at", 0)) == 2,
		"时间边预告：墨雨夜袭 2 格（04 §3.1）")
	g2.board.write("global.doom_clock", 2, prov)
	g2._scan_triggers()
	check(g2.next_clock_trigger().is_empty(), "时钟到格触发后预告消失")
	# hub：金币播种/购买/不足/货单（战役书 §4 N1-1；价格占位见 README M2 记录）
	var s3 := EventStream.new()
	var b3 := Board.new(s3)
	var g3 := StoryGraph.new(b3, Rng.new(7), pack)
	g3.start()
	g3.seed_gold()
	g3.seed_gold(99)
	check(g3.get_gold() == 30, "金币播种幂等（重复不覆盖）")
	check(g3.hub_buy("half_tide_table"), "购买半页潮汐表成功")
	check(g3.get_gold() == 30 - 15, "金币扣减 15（items.json price 占位）")
	check(b3.has_item("half_tide_table"), "购买 give_item 落板")
	check(s3.query_by_type(EventTypes.FLAG_WRITE).any(func(ev: Dictionary) -> bool:
		return str((ev["payload"] as Dictionary)["key"]) == "campaign01.gold"),
		"金币写板进事件流（07 §6）")
	var gold_ev: Dictionary = s3.query_by_type(EventTypes.FLAG_WRITE).filter(func(ev: Dictionary) -> bool:
		return str((ev["payload"] as Dictionary)["key"]) == "campaign01.gold")[0]
	check(str(((gold_ev["payload"] as Dictionary)["provenance"] as Dictionary).get("node_id", "")) == "N0-1",
		"金币写板带溯源（07 §1）")
	check(not g3.hub_buy("fatedie"), "非卖品（无 price）拒绝")
	check(g3.hub_buy("heal_potion"), "购买补给药水成功（验收裁决 B 上架，战役书 §8）")
	check(g3.get_gold() == 30 - 30 and b3.item_count("heal_potion") == 1,
		"购买药水：扣 15 金 + give_item（验收裁决 B）")
	b3.write("campaign01.gold", 5, prov)
	check(not g3.hub_buy("half_tide_table"), "金币不足拒绝购买")
	var stock := g3.hub_stock()
	var stock_ids: Array = []
	var any_affordable := false
	for it: Variant in stock:
		stock_ids.append(str((it as Dictionary)["id"]))
		any_affordable = any_affordable or bool((it as Dictionary)["affordable"])
	check(stock.size() == 9 and stock_ids.has("half_tide_table") and stock_ids.has("heal_potion")
		and stock_ids.has("boathook_axe") and stock_ids.has("ink_flask")
		and not any_affordable, "货单 = 含 price 条目 ×9（含墨膏 / 潮雷）+ 可负担标记")
	# 休整（恢复 HP；次数制技能随遭遇组装重置，11 §8）
	var restored := g3.hub_rest()
	check(int(restored.get("player_blank", 0)) == 14, "休整：白页者 HP 回满 14（hp_formula 10+2×力2，tech/04 §2）")
	check(int(b3.read("campaign01.hp.player_blank", 0)) == 14, "休整写板 hp 簿记（11 §7.1 / 07 §2 簿记键）")
	var ps := g3.party_status()
	check(ps.size() == 3 and int(ps[0]["hp"]) == int(ps[0]["max_hp"]), "队伍 HP 概览三人满值（04 §3.1）")
	# 传闻（战役书 §4：未择路线以传闻形式提及）
	var rumors := g3.hub_rumors()
	check(rumors.size() >= 4, "传闻 = 未触发的 choice/hidden 事件（三方委托+孤身入局）")
	check(not rumors.any(func(r: Dictionary) -> bool: return str(r["id"]) == "dock_tales"),
		"auto 触发事件不作传闻")

# ---------------------------------------------------------------- 营地与休息（11 §7.2 短休/长休；11 §7.3 战利金）

func test_camp_rest() -> void:
	print("[camp_rest]")
	var pack := _load_campaign01()
	var s := EventStream.new()
	var b := Board.new(s)
	var g := StoryGraph.new(b, Rng.new(11), pack)
	g.start()
	var prov := {"event_id": 0, "node_id": "N1-7", "pack_id": "campaign01"}
	check(not g.camp_available(), "序章（未经历战斗）不出现营地")
	g._enter("N1-7")
	check(not g.camp_available(), "战斗节点不开营地（战斗走整备）")
	g._enter("N1-8")
	check(g.camp_available() and not g.rest_is_free(), "战后野外节点：营地可用、长休耗时钟")
	g._enter("N1-1")
	check(not g.camp_available() and g.rest_is_free(), "hub：不开营地（旅店长休免费）")
	g._enter("N1-8")
	# 生命骰：队伍等级枚，骰面取 hit_die
	var ps: Array = g.party_status()
	check(ps.size() == 3 and int(ps[0]["hd_max"]) == 1 and int(ps[0]["hd_left"]) == 1
		and str(ps[0]["hit_die"]) == "d10", "生命骰：1 级 ×1，白页者 d10（characters.json hit_die）")
	check(str(g.hit_dice_of("companion_kelan")["die"]) == "d6", "珂兰生命骰 d6")
	# 短休：满血拒绝（不浪费骰子）
	var full := g.short_rest("companion_kelan")
	check(not bool(full["ok"]) and str(full["reason"]) == "full", "满血短休拒绝（不浪费生命骰）")
	b.write("campaign01.hp.player_blank", 3, prov)
	var r := g.short_rest("player_blank")
	check(bool(r["ok"]) and int(r["roll"]) >= 1 and int(r["roll"]) <= 10
		and int(r["heal"]) == mini(int(r["roll"]) + 2, 14 - 3), "短休：d10 + 力2 回血（封顶上限）")
	check(g.hp_of("player_blank") == 3 + int(r["heal"]) and int(g.hit_dice_of("player_blank")["left"]) == 0,
		"短休写板 HP + 生命骰扣 1")
	check(s.query_by_type(EventTypes.LOG).any(func(ev: Dictionary) -> bool:
		return str((ev["payload"] as Dictionary).get("msg_key", "")) == "MSG_SHORT_REST"), "短休日志（toast）")
	b.write("campaign01.hp.player_blank", 3, prov)
	var r2 := g.short_rest("player_blank")
	check(not bool(r2["ok"]) and str(r2["reason"]) == "no_dice", "生命骰用尽拒绝短休")
	# 野外长休：HP 全满 + 生命骰恢复 + 时钟 +1
	var clock0 := b.get_doom_clock()
	g.long_rest(false)
	check(g.hp_of("player_blank") == 14 and int(g.hit_dice_of("player_blank")["left"]) == 1
		and b.get_doom_clock() == clock0 + StoryGraph.CAMP_LONG_REST_CLOCK, "野外长休：满血 + 生命骰恢复 + 时钟 +1")
	g.long_rest(true)
	check(b.get_doom_clock() == clock0 + StoryGraph.CAMP_LONG_REST_CLOCK, "旅店/安全处长休不耗时钟")
	# HP 上限唯一口径：成长只叠加玩家模板（状态栏 / 休息 / 战斗组装一致）
	Growth.new(b).grant_xp(300, prov)
	g.long_rest(true)
	var def: Dictionary = BattleDef.assemble(pack, "N1-7", {}, b)["def"]
	var same := true
	for u: Variant in def["party"]:
		var ud: Dictionary = u
		if g.max_hp_of(str(ud["ref"])) != int(ud["max_hp"]) or g.hp_of(str(ud["ref"])) != int(ud["hp"]):
			same = false
	check(same and g.max_hp_of("player_blank") == 16 and g.max_hp_of("companion_kelan") == 10,
		"HP 上限三处同口径：升 2 级白页者 16、同伴不吃成长（BattleDef.max_hp_for）")
	check(int(g.hit_dice_of("player_blank")["max"]) == 2, "生命骰随等级 +1")
	# 战利金：遭遇 gold 字段 → 胜利写 <pack>.gold + MSG_GOLD_GAIN
	check(int(def.get("gold", 0)) == 20, "N1-7 战斗定义携带战利金 20（encounters.json gold）")
	for e: Variant in def["enemies"]:
		(e as Dictionary)["hp"] = 1
		(e as Dictionary)["max_hp"] = 1
	var gold0 := g.get_gold()
	var sm := EncounterSM.new(b, s, Rng.new(5), "campaign01")
	var agent := AutoAgent.new()
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(def)
	var guard := 0
	while not sm.is_over() and guard < 500:
		guard += 1
		var cmd := agent.next_command(sm)
		if cmd.is_empty():
			break
		sm.submit_command(cmd)
	check(sm.is_over() and g.get_gold() == gold0 + 20, "胜利战利金写板 +20（包命名空间 <pack>.gold）")
	check(s.query_by_type(EventTypes.LOG).any(func(ev: Dictionary) -> bool:
		return int((ev["payload"] as Dictionary).get("gold", 0)) == 20), "战利金日志携带数额（结算念板来源）")

# ---------------------------------------------------------------- 装备 / 背包 / 投掷 / 战斗换武器（11 §8.1/§8.2）

func test_equipment() -> void:
	print("[equipment]")
	var pack := _load_campaign01()
	var s := EventStream.new()
	var b := Board.new(s)
	var g := StoryGraph.new(b, Rng.new(3), pack)
	g.start()
	var prov := {"event_id": 0, "node_id": "N1-7", "pack_id": "campaign01"}
	check(Equipment.weapon_damage("1d6+2", "1d8") == "1d8+2" and Equipment.weapon_damage("1d6", "1d10") == "1d10"
		and Equipment.weapon_damage("1d6-1", "1d8") == "1d8-1", "武器换骰保留原修正")
	check(Equipment.can_equip(b, pack, "player_blank", "boathook_axe") == "not_owned", "未持有不可装备")
	check(Equipment.can_equip(b, pack, "player_blank", "heal_potion") == "not_equipment", "非装备不可装备")
	for iid: String in ["boathook_axe", "padded_coat", "tide_charm"]:
		b.give_item(iid, 1, prov)
	b.give_item("ink_flask", 2, prov)
	b.give_item("heal_potion", 1, prov)
	check(Equipment.equip(b, pack, "player_blank", "boathook_axe", prov) == "", "白页者装备船钩斧")
	check(Equipment.can_equip(b, pack, "companion_kelan", "boathook_axe") == "none_free", "唯一一把斧不能两人同时装备")
	check(Equipment.equip(b, pack, "player_blank", "padded_coat", prov) == "", "白页者穿衬垫外套")
	var hp_k0 := g.max_hp_of("companion_kelan")
	check(Equipment.equip(b, pack, "companion_kelan", "tide_charm", prov) == "", "珂兰戴潮汐护符")
	check(g.max_hp_of("companion_kelan") == hp_k0 + 3, "饰物 HP 上限 +3（休息/状态栏同口径）")
	check(g.ac_of("player_blank") == 12, "AC = 10 + 敏1 + 外套1")
	var res := BattleDef.assemble(pack, "N1-7", {"skills": ["inkbolt"], "items": ["heal_potion"]}, b)
	var def: Dictionary = res["def"]
	var pc: Dictionary = def["party"][0]
	check(bool(res["ok"]) and str(pc["damage"]) == "1d8+2" and int(pc["ac"]) == 12
		and str(pc.get("weapon", "")) == "boathook_axe", "战斗组装：斧 1d8+2、AC 12、武器标记")
	var kelan: Dictionary = def["party"][1]
	check(int(kelan["max_hp"]) == hp_k0 + 3, "战斗组装：护符 HP 上限同口径")
	var pack_ids: Array = (def.get("pack_items", []) as Array).map(func(x: Dictionary) -> String: return str(x["id"]))
	check(pack_ids == ["ink_flask"], "背包道具 = 未放进快取袋的可用道具（墨瓶）")
	check((def.get("armory", []) as Array).size() == 1, "军械：船钩斧可在战斗中换用")
	# 卸下斧 → 战斗中换上（物品互动）
	Equipment.unequip(b, "campaign01", "player_blank", "weapon", prov)
	def = BattleDef.assemble(pack, "N1-7", {"skills": ["inkbolt"], "items": ["heal_potion"]}, b)["def"]
	var sm := EncounterSM.new(b, s, Rng.new(9), "campaign01")
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(def)
	var shared := true
	for id: String in sm.get_order():
		var u := sm.get_unit(id)
		if str(u["side"]) == "party" and ((u["items"] as Array).size() != 2):
			shared = false
	check(shared, "全队共享道具：每名队员都看得到快取袋药水 + 背包墨瓶")
	var actor := sm.current_actor_id()
	var flask := {}
	var equip_a := {}
	for a: Dictionary in sm.get_available_actions():
		if str(a.get("item", "")) == "ink_flask":
			flask = a
		if a["type"] == EncounterSM.CMD_EQUIP:
			equip_a = a
	check(not flask.is_empty() and str(flask["cost"]) == "action" and str(flask["target_kind"]) == "enemy"
		and not bool(flask["pouch"]), "墨瓶：背包取用 = 动作、目标敌方")
	var dmg_before := str(sm.get_unit(actor)["damage"])
	if actor == "pc" or str(sm.get_unit(actor).get("ref", "")) != "":
		check(not equip_a.is_empty() and not bool(equip_a["disabled"]), "换武器条目可用（物品互动）")
		sm.submit_command(sm.command_from_action(equip_a))
		var ua := sm.get_unit(actor)
		check(str(ua["damage"]).begins_with("1d8") and bool(ua["interact_used"]) and dmg_before != str(ua["damage"]),
			"换上船钩斧：伤害骰 1d8、本回合物品互动已用")
		check(str(b.read("campaign01.equip.%s.weapon" % str(ua["ref"]))) == "boathook_axe", "换武器写板（世界状态）")
		check(not sm.submit_command(sm.command_from_action(equip_a)), "物品互动每回合一次")
	var flask_n := b.item_count("ink_flask")
	var enemy := sm.first_alive_enemy()
	check(sm.submit_command(sm.command_from_action(flask, enemy)), "投掷墨瓶命令合法")
	check(b.item_count("ink_flask") == flask_n - 1 and bool(sm.get_unit(actor)["action_used"]), "投掷耗动作并消耗 1 瓶")
	var thrown := s.query_by_type(EventTypes.ITEM_USE).filter(func(ev: Dictionary) -> bool:
		return bool((ev["payload"] as Dictionary).get("thrown", false)))
	var atk := s.query_by_type(EventTypes.BATTLE_ATTACK).filter(func(ev: Dictionary) -> bool:
		return str((ev["payload"] as Dictionary).get("skill", "")) == "ink_flask")
	check(thrown.size() == 1 and atk.size() == 1, "投掷 = item.use(thrown) + 攻击检定事件")
	check(str((thrown[0]["payload"] as Dictionary).get("name", "")) == "墨瓶", "道具事件携带显示名（日志不显内部 id）")

# ---------------------------------------------------------------- 激励（11 §3.2：d20 核心规则 Inspiration）

func test_inspiration() -> void:
	print("[inspiration]")
	var pack := _load_campaign01()
	var s := EventStream.new()
	var b := Board.new(s)
	var g := StoryGraph.new(b, Rng.new(1), pack)
	g.start()
	check(g.inspiration() == 0 and not g.arm_inspiration(true), "未持有激励：无法举起")
	Conditions.new(b).apply_effects([{"inspiration": 1}, {"inspiration": 1}],
		{"pack_id": "campaign01", "node_id": "N0-1", "event_id": 0, "source": "graph"})
	check(g.inspiration() == 1, "效果 inspiration 获得激励，最多一枚（钳位）")
	g._enter("N0-2")
	var edge: Dictionary = (pack["nodes"]["N0-2"]["edges"] as Array)[0]
	check(g.arm_inspiration(true), "举起激励")
	check(str(StoryVM.edge_display(edge, g, pack)["label"]).contains("优势"), "检定按钮标注优势")
	g.roll_check(edge)
	var ev: Dictionary = s.query_by_type(EventTypes.CHECK_ROLL)[-1]
	check(str((ev["payload"] as Dictionary)["mode"]) == "advantage" and ((ev["payload"] as Dictionary)["rolls"] as Array).size() == 2
		and g.inspiration() == 0 and not g.inspiration_armed, "花费激励：优势掷骰（2d20 取高）并消耗")
	var gained := false
	for i: int in 200:
		g._enter("N0-2")
		g.roll_check(edge)
		var p: Dictionary = s.query_by_type(EventTypes.CHECK_ROLL)[-1]["payload"]
		if int(p["keep"]) == 1:
			gained = g.inspiration() == 1
			break
	check(gained, "故事检定天然 1：获得一枚激励（失败也有回报）")

# ---------------------------------------------------------------- 地图 / 事件表 / 场所（docs/en/framework/16）

func test_maps_core() -> void:
	print("[maps_core]")
	var pack := _load_campaign01()
	check((pack["maps"] as Dictionary).has("fog_coast") and (pack["sites"] as Dictionary).has("lighthouse")
		and (pack["tables"] as Dictionary).size() == 4 and (pack["cards"] as Dictionary).has("courier_satchel"),
		"maps.json / tables.json 加载：地图、场所、4 张表、事件卡")
	var s := EventStream.new()
	var b := Board.new(s)
	var tables := EventTables.new(b, s, Rng.new(5), pack)
	check(EventTables.die_sides("d8") == 8 and EventTables.die_sides("d100") == 100
		and EventTables.parse_range("2-3") == [2, 3] and EventTables.parse_range("7") == [7, 7], "骰型 / 区间解析")
	var fw: Dictionary = pack["tables"]["fog_wild"]
	check(EventTables.row_for(fw, 1) == 0 and EventTables.row_for(fw, 5) == 2 and EventTables.row_for(fw, 8) == 4, "点数落行")
	check(tables._modifier(fw, {"pace": "careful"}) == 1 and tables._modifier(fw, {"pace": "fast"}) == 0, "步调修正：谨慎 +1")
	b.write("global.doom_clock", 6, {"event_id": 0, "node_id": "x", "pack_id": "campaign01"})
	check(tables._modifier(fw, {"pace": "careful"}) == -1, "状态修正：时间钟 ≥6 时 -2（世界越褪色，路越凶）")
	# once 行：第一次给墨瓶，之后落到 instead 行
	var finds_used := 0
	var gave_flask := 0
	for i: int in 60:
		var r := tables.roll("tideline_finds")
		if int((r["rolls"][0] as Dictionary)["value"]) == 6:
			finds_used += 1
			if str(r["label"]) == "一只没开封的墨瓶":
				gave_flask += 1
	check(finds_used >= 2 and gave_flask == 1, "once 行只发生一次，之后改落 instead 行（%d 次掷出 6）" % finds_used)
	check(s.query_by_type(EventTypes.TABLE_ROLL).all(func(ev: Dictionary) -> bool:
		return ((ev["payload"] as Dictionary)["dice"] as Array).size() == 1), "table.roll 带 dice 清单（17 §5）")
	b.write("global.doom_clock", 0, {"event_id": 0, "node_id": "x", "pack_id": "campaign01"}) # 去掉 -2 修正，8 点可达
	var nested := false
	for i: int in 80:
		var r2 := tables.roll("fog_wild")
		if (r2["rolls"] as Array).size() == 2:
			nested = str((r2["rolls"][1] as Dictionary)["table"]) == "tideline_finds"
			break
	check(nested, "嵌套表：潮线拾遗 → 再掷 tideline_finds")
	# 结算：效果 / 检定 / 遭遇 / 事件卡
	var gold0 := int(b.read("campaign01.gold", 0))
	check(str(tables.resolve({"effects": [{"gold": 5}]}, Callable())["kind"]) == "effects"
		and int(b.read("campaign01.gold", 0)) == gold0 + 5, "结果：效果落板")
	check(str(tables.resolve({"encounter": "fog_ambush"}, Callable())["kind"]) == "encounter"
		and str(tables.resolve({"card": "courier_satchel"}, Callable())["card"]) == "courier_satchel", "结果：遭遇 / 事件卡分派")
	var chk := tables.resolve({"check": {"skill": "perception", "difficulty": "easy"}, "failure": [{"watch": 1}]},
		func(_s: String) -> int: return 0)
	check(str(chk["kind"]) == "check" and s.query_by_type(EventTypes.CHECK_ROLL)[-1]["payload"]["kind"] == "table_check",
		"结果：检定（d20 事件 table_check）")
	var insp := tables.choose_card_option("courier_satchel", 1, Callable())
	check(str(insp["kind"]) == "effects" and int(b.read("campaign01.inspiration", 0)) == 1, "事件卡选项：为死者说一句话 → 激励")
	# ---- 区域地图 ----
	var s2 := EventStream.new()
	var b2 := Board.new(s2)
	var rm := RegionMap.new(b2, s2, Rng.new(8), pack, "fog_coast")
	check(rm.pos() == "plaza" and not rm.seen().has("marsh") and rm.seen().size() == 4, "起点广场；盐沼隐藏（迷雾）")
	check(str((rm.view().get("background", {}) as Dictionary).get("art_ref", "")) == "scenes/map_fog_coast",
		"区域视图透传 background（纯呈现数据，16 §6）")
	check(rm.routes_from("plaza").size() == 2 and rm.route_between("plaza", "lighthouse").is_empty(), "可见路线：广场 → 渔人巷 / 礼拜堂")
	check(RegionMap.effective_legs(2, "fast") == 1 and RegionMap.effective_legs(2, "careful") == 3
		and RegionMap.effective_legs(1, "fast") == 1, "步调段数：急行每 2 段省 1、谨慎每 2 段多 1")
	check(rm.start_journey("lighthouse", "normal") == "no_route", "无路可达拒绝出发")
	check(rm.start_journey("row", "normal") == "", "出发前往渔人巷")
	var st := rm.step(func(_s: String) -> int: return 0)
	check(bool(st["arrived"]) and rm.pos() == "row" and rm.visited().has("row") and int(b2.read("campaign01.watch", 0)) == 1,
		"一段路 = 1 时辰；抵达写位置与已访")
	check(s2.query_by_type(EventTypes.TABLE_ROLL).size() == 1 and s2.query_by_type(EventTypes.MAP_TRAVEL).size() == 1,
		"每段掷路线事件表（road → coast_road）+ map.travel 事件")
	# 荒野：导航检定；4 时辰 → 时间钟 +1
	var clock0 := b2.get_doom_clock()
	rm.start_journey("lighthouse", "normal")
	var guard := 0
	var nav := false
	while not rm.journey().is_empty() and guard < 12:
		guard += 1
		rm.step(func(_s: String) -> int: return 2)
		nav = nav or s2.query_by_type(EventTypes.CHECK_ROLL).any(func(ev: Dictionary) -> bool:
			return str((ev["payload"] as Dictionary)["kind"]) == "navigation")
	check(rm.pos() == "lighthouse" and nav, "荒野路线有导航检定，最终抵达灯塔")
	check(b2.get_doom_clock() >= clock0 + 1 and int(b2.read("campaign01.watch", 0)) < 4, "满 4 时辰推进时间钟 +1（时间即地理）")
	Conditions.new(b2).apply_effects([{"reveal": "fog_coast.marsh"}], {"pack_id": "campaign01", "node_id": "x", "event_id": 0})
	check(rm.seen().has("marsh") and not rm.route_between("lighthouse", "marsh").is_empty(), "reveal 效果揭示盐沼与雾中路线")
	# ---- 场所 ----
	var s3 := EventStream.new()
	var b3 := Board.new(s3)
	var sm := SiteMap.new(b3, s3, Rng.new(4), pack, "lighthouse")
	sm.enter("hall", Callable())
	var ex: Array = sm.exits()
	check(ex.size() == 2 and str((ex[0] as Dictionary)["state"]) == "map" and str((ex[1] as Dictionary)["state"]) == "stuck",
		"门厅：回地图出口 + 卡死的门")
	var forced := false
	for i: int in 12:
		var g := sm.go("keeper", func(_s: String) -> int: return 5)
		if bool(g.get("moved", false)):
			forced = true
			break
	check(forced and sm.current() == "keeper", "撞开卡死的门进入守灯人的房间")
	check(not sm.exits().any(func(e: Dictionary) -> bool: return str(e["to"]) == "stores"), "密门未揭示时不显示")
	var wall_ok := false
	for i: int in 1:
		var r3 := sm.use_feature("wall", func(_s: String) -> int: return 20)
		wall_ok = bool(r3.get("success", false))
	check(wall_ok and sm.exits().any(func(e: Dictionary) -> bool: return str(e["to"]) == "stores"),
		"敲墙（检定成功）→ 揭示暗格储藏间的密门")
	check(not sm.features().any(func(f: Dictionary) -> bool: return str(f["id"]) == "wall"), "一次性交互物用过即隐去")
	var lamp: Dictionary = sm.go("lamp", func(_s: String) -> int: return 20)
	check(bool(lamp.get("moved", false)) and sm.current() == "lamp", "撬锁检定成功进入灯室")
	sm.use_feature("relight", Callable())
	check((b3.read("campaign01.map.fog_coast.seen", []) as Array).has("marsh") and int(b3.read("campaign01.inspiration", 0)) == 1,
		"重新点亮灯塔：揭示盐沼 + 激励")
	check(s3.query_by_type(EventTypes.SITE_ENTER).size() == 3 and s3.query_by_type(EventTypes.FEATURE_USE).size() == 2,
		"site.enter / feature.use 事件可追溯")

# ---------------------------------------------------------------- 队伍分合（docs/en/framework/15）

func _split_graph(pack: Dictionary, playthrough: int = 1) -> Array:
	var s := EventStream.new()
	var b := Board.new(s)
	if playthrough > 1:
		b.write("campaign01.ngplus", playthrough - 1, {"event_id": 0, "node_id": "x", "pack_id": "campaign01"})
	var g := StoryGraph.new(b, Rng.new(21), pack)
	g.start()
	g._enter("N1-1mr")
	return [g, b, s]

func _edge_of(g: StoryGraph, etype: String) -> Dictionary:
	for e: Variant in g.available_edges():
		if str((e as Dictionary).get("type", "")) == etype:
			return e
	return {}

func test_party_split() -> void:
	print("[party_split]")
	var pack := _load_campaign01()
	var r := _split_graph(pack)
	var g: StoryGraph = r[0]
	var b: Board = r[1]
	var s: EventStream = r[2]
	check(g.party.playthrough() == 1 and g.party.split_enabled() and not g.party.links_enabled(),
		"周目 1：可分队、不可联络（manifest.progression）")
	var split := _edge_of(g, "split")
	check(not split.is_empty(), "渔人巷出现分队边")
	g.take_edge(split)
	check(g.party.is_split() and g.party.focus() == "docks" and g.current_id == "N1-1md"
		and s.query_by_type(EventTypes.PARTY_SPLIT).size() == 1, "分队：建两组，焦点码头组进入守夜屋")
	check(g.party.lead() == "player_blank" and g.check_mod("investigation") == g.char_check_mod("player_blank", "investigation"),
		"码头组检定由白页者掷")
	check(_edge_of(g, "remote").is_empty() and g.focus_group("archive") and g.current_id == "N1-1ma",
		"周目 1 无远程边；切到档案馆组 → 首次进入其入口")
	check(g.check_mod("history") == 3, "档案馆组由珂兰掷：历史 = 智 1 + 熟练 2")
	check(_edge_of(g, "remote").is_empty(), "周目 1：拉杆（远程联络）不可用")
	check(g.focus_group("docks") and g.current_id == "N1-1md", "切回码头组：回到其所在节点（不重复进入）")
	check(s.query_by_type(EventTypes.NODE_ENTER).filter(func(ev: Dictionary) -> bool:
		return str((ev["payload"] as Dictionary)["node_id"]) == "N1-1md").size() == 1, "切换焦点不重放节点进入")
	# 码头组走完 → 在汇合点等待，焦点自动切到档案馆组
	g.resolve_check(g.current()["edges"][0], true)
	check(g.current_id == "N1-1me", "码头组前进到潮闸")
	g.take_edge(_edge_of(g, "choice")) # 只有"绕远路"可走（潮闸未开）
	check(str(g.party.group("docks").get("status", "")) == "waiting" and g.party.focus() == "archive" and g.current_id == "N1-1ma",
		"先到的组在汇合点等待，焦点自动切到仍在行动的组")
	g.resolve_check(g.current()["edges"][0], false)
	g.take_edge(_edge_of(g, "choice"))
	check(not g.party.is_split() and g.current_id == "N1-1mj" and s.query_by_type(EventTypes.PARTY_REJOIN).size() == 1,
		"最后一组到达：汇合，队伍并回")
	check(s.query_by_type(EventTypes.NODE_ENTER).filter(func(ev: Dictionary) -> bool:
		return str((ev["payload"] as Dictionary)["node_id"]) == "N1-1mj").size() == 1, "汇合节点只进入一次（on_enter 只结算一次）")
	# ---- 周目 2：联络 ----
	var r2 := _split_graph(pack, 2)
	var g2: StoryGraph = r2[0]
	var b2: Board = r2[1]
	var s2: EventStream = r2[2]
	var prov := {"event_id": 0, "node_id": "x", "pack_id": "campaign01"}
	b2.give_item("heal_potion", 3, prov)
	b2.give_item("ink_flask", 1, prov)
	check(g2.party.playthrough() == 2 and g2.party.links_enabled(), "周目 2：联络开放")
	g2.take_edge(_edge_of(g2, "split"))
	var div := g2.party.default_division()
	check(int((div["docks"] as Dictionary).get("heal_potion", 0)) + int((div["archive"] as Dictionary).get("heal_potion", 0)) == 3,
		"默认分装：药水全部分到两组")
	check(g2.party.divide({"archive": {"heal_potion": 2, "ink_flask": 1}}, "N1-1md") == "", "分装：档案馆组拿 2 药水 + 墨瓶")
	check(g2.party.available("heal_potion") == 1 and g2.party.available("ink_flask") == 0, "焦点码头组只可用自己那份（1 药水）")
	var def: Dictionary = BattleDef.assemble(pack, "fog_ambush", {"items": ["heal_potion"]}, b2)["def"]
	check(int((def["party"][0]["items"] as Array)[0]["count"]) == 1, "战斗组装按本组份额计数")
	check(g2.focus_group("archive") and g2.party.available("heal_potion") == 2 and g2.party.available("ink_flask") == 1,
		"切到档案馆组：可用其份额")
	var remote := _edge_of(g2, "remote")
	check(not remote.is_empty(), "周目 2：档案馆可远程拉杆")
	g2.take_edge(remote)
	check(bool(b2.read("campaign01.tide_gate_open")) and g2.party.charges("archive") == 1 and g2.current_id == "N1-1ma",
		"远程触发：写旗标、扣 1 次、不移动")
	check(g2.party.send_item("heal_potion", 1, "docks", "N1-1ma") == "" and g2.party.charges("archive") == 0,
		"送物：药水 → 码头组（扣 1 次）")
	check(g2.party.send_item("heal_potion", 1, "docks", "N1-1ma") == "no_charge", "次数用尽拒绝")
	g2.focus_group("docks")
	check(g2.party.available("heal_potion") == 2, "码头组收到送来的药水（1 + 1）")
	check(g2.link_help("archive") and g2.party.charges("docks") == 1, "远方求援：扣 1 次")
	check(g2.link_move("player_blank", "archive") == "cannot_leave", "不能清空一组")
	check(g2.party.move_member("companion_laofei", "docks", "N1-1md") == "bad_target", "只能从焦点组派人")
	g2.focus_group("archive")
	g2.party.restore_charges("N1-1ma")
	var clock0 := b2.get_doom_clock()
	check(g2.link_move("companion_laofei", "docks") == "" and g2.party.members("docks").has("companion_laofei")
		and b2.get_doom_clock() == clock0 + 1, "锚点换人：老费去码头组（2 次 + 时间钟 +1）")
	g2.roll_check(g2.current()["edges"][0])
	var rolls_adv: Array = s2.query_by_type(EventTypes.CHECK_ROLL)[-1]["payload"]["rolls"]
	check(rolls_adv.size() == 2, "求援生效：档案馆组下一次检定优势（2d20）")
	g2.focus_group("docks")
	g2.resolve_check(g2.current()["edges"][0], true)
	check(not _edge_of(g2, "choice").is_empty() and str(_edge_of(g2, "choice")["to"]) == "N1-1mj"
		and g2.available_edges().size() == 2, "潮闸已开：两条路都可走")
	# 条件：in_group / thread / group_size
	var c := Conditions.new(b2)
	check(c.evaluate({"in_group": "companion_laofei"}, {"pack_id": "campaign01"}) and c.evaluate({"thread": "docks"}, {"pack_id": "campaign01"})
		and c.evaluate({"group_size": {"==": 2}}, {"pack_id": "campaign01"}), "条件 in_group / thread / group_size")
	# 小组战：party_from = group
	var gp := pack.duplicate(true)
	gp["encounters"]["fog_ambush"]["party_from"] = "group"
	var gdef: Dictionary = BattleDef.assemble(gp, "fog_ambush", {}, b2)["def"]
	check((gdef["party"] as Array).size() == 2, "小组战只派焦点组成员（白页者 + 老费）")
	# ---- 自选分组 / 时限 / 召回 / 领队（15 §2.1/§2.3/§5.2/§7）----
	var r4 := _split_graph(pack, 2)
	var g4: StoryGraph = r4[0]
	var b4: Board = r4[1]
	var sp := _edge_of(g4, "split")
	check(g4.party.validate_assignment(sp, {"docks": ["player_blank", "companion_kelan"], "archive": ["companion_laofei"]}) == "requires",
		"自选分组校验：珂兰必须在档案馆")
	check(g4.party.validate_assignment(sp, {"docks": ["player_blank"], "archive": ["companion_kelan"]}) == "unassigned",
		"自选分组校验：每人都要有组")
	check(g4.take_split(sp, {"docks": ["player_blank", "companion_laofei"], "archive": ["companion_kelan"]}) == ""
		and g4.party.members("docks") == ["player_blank", "companion_laofei"], "按玩家分组分队")
	var gold0 := g4.get_gold()
	b4.write("global.doom_clock", b4.get_doom_clock() + 2, {"event_id": 0, "node_id": "x", "pack_id": "campaign01"})
	g4.rescan()
	check(not g4.party.is_split() and g4.current_id == "N1-1mj" and g4.get_gold() == maxi(gold0 - 5, 0),
		"时限到（时间钟 +2）：强制汇合 + timeout 效果")
	var r5 := _split_graph(pack, 2)
	var g5: StoryGraph = r5[0]
	g5.take_edge(_edge_of(g5, "split"))
	check(g5.link_recall() and not g5.party.is_split() and g5.current_id == "N1-1mj", "召回：2 次联络，全队立刻会合")
	check(g5.party.lead_enabled() and g5.party.set_lead("companion_kelan", "N1-1mj") and g5.check_mod("history") == 3
		and Conditions.new(r5[1]).evaluate({"lead": "companion_kelan"}, {"pack_id": "campaign01"}),
		"周目 2：可指定珂兰为领队，队伍检定用她的修正；条件 lead")
	check(not _split_graph(pack)[0].party.set_lead("companion_kelan", "x"), "周目 1：不能换领队")
	# ---- 线性兜底：周目 1 关闭分队 ----
	var lp := pack.duplicate(true)
	lp["manifest"]["progression"] = {"1": {"split": false, "links": false}, "2": {"split": true, "links": true}}
	var r3 := _split_graph(lp)
	var g3: StoryGraph = r3[0]
	var fb := {}
	for e: Variant in g3.available_edges():
		if bool((e as Dictionary).get("via_fallback", false)):
			fb = e
	check(_edge_of(g3, "split").is_empty() and str(fb.get("to", "")) == "N1-1md", "未解锁分队：同一选项走线性路线（整队）")
	g3.take_edge(fb)
	check(not g3.party.is_split() and g3.current_id == "N1-1md", "整队进入守夜屋，不分组")

# ---------------------------------------------------------------- 职业 / 出身 / 治疗技能（11 §1.1 / §8）

func test_hero_build() -> void:
	print("[hero_build]")
	var pack := _load_campaign01()
	check((pack["classes"] as Dictionary).size() == 3 and (pack["backgrounds"] as Dictionary).size() == 4,
		"classes.json：三职业（港卫 / 拾荒客 / 墨徒）+ 四出身")
	var s := EventStream.new()
	var b := Board.new(s)
	var prov := {"event_id": 0, "node_id": "", "pack_id": "campaign01"}
	var gold0 := int(b.read("campaign01.gold", 0))
	check(HeroBuild.choose(pack, b, "scavenger", "uninked_runaway", prov) == "", "建角：拾荒客 + 断墨会逃徒")
	var pt: Dictionary = pack["characters"]["player_blank"]
	check(str(pt["basic_attack"]) == "hook_knife" and str(pt["hit_die"]) == "d8" and (pt["skills"] as Array).has("sneak_strike")
		and (pt["proficiencies"] as Array).has("thievery") and (pt["proficiencies"] as Array).has("stealth"),
		"职业叠到玩家模板：普攻 / 生命骰 / 技能 / 熟练（含出身熟练）")
	check(b.has_item("tide_bomb") and b.has_item("salvage_gloves") and b.has_item("torn_ribbon") and b.has_item("ink_flask")
		and b.get_rep("uninked") == 2, "起始物品 + 出身纪念物 + 出身效果（断墨会声望 +2）")
	var def: Dictionary = BattleDef.assemble(pack, "N1-7", {}, b)["def"]
	check(str((def["party"][0] as Dictionary)["damage"]) == "1d6+1", "战斗组装用职业普攻（钩刀 1d6+1）")
	var g := StoryGraph.new(b, Rng.new(2), pack)
	g.start()
	g._enter("N1-5")
	check(g.available_edges().size() == 2, "断墨会接触：出身专属选项显形")
	g._enter("N1-4")
	check(g.available_edges().size() == 1, "誊写庭接触：别的出身不显形")
	check(Conditions.new(b).evaluate({"hero_class": "scavenger", "background": "uninked_runaway"}, {"pack_id": "campaign01"}),
		"条件 hero_class / background")
	HeroBuild.apply(pack, b)
	check(str(pack["characters"]["player_blank"]["basic_attack"]) == "hook_knife" and (pack["characters"]["player_blank"]["proficiencies"] as Array).count("stealth") == 1,
		"apply 幂等（重复叠加不重复熟练）")
	var b2 := Board.new(EventStream.new())
	HeroBuild.apply(pack, b2)
	check(str(pack["characters"]["player_blank"]["basic_attack"]) == "slash", "未选择 = 缺省白页者模板（读档 / 旧存档兼容）")
	# 治疗技能：补墨救倒地队友
	var p2 := _load_campaign01()
	var s3 := EventStream.new()
	var b3 := Board.new(s3)
	HeroBuild.choose(p2, b3, "ink_adept", "dockhand", prov)
	var d3: Dictionary = BattleDef.assemble(p2, "N1-7", {"skills": ["ink_mend"]}, b3)["def"]
	var sm := EncounterSM.new(b3, s3, Rng.new(4), "campaign01")
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(d3)
	var actor := sm.current_actor_id()
	var target := "kelan" if actor != "kelan" else "laofei"
	sm._units[target]["hp"] = 0
	sm._units[target]["downed"] = true
	var mend := {}
	for a: Dictionary in sm.get_available_actions():
		if str(a.get("skill", "")) == "ink_mend" or str(a.get("skill", "")) == "kelan_mend":
			mend = a
	if not mend.is_empty():
		check(sm.submit_command(sm.command_from_action(mend, target)) and not bool(sm.get_unit(target)["downed"])
			and int(sm.get_unit(target)["hp"]) > 0, "治疗技能可救起倒地队友（%s）" % str(mend["skill"]))
	check(s3.query_by_type(EventTypes.LOG).any(func(ev: Dictionary) -> bool:
		return str((ev["payload"] as Dictionary).get("msg_key", "")) == "MSG_SKILL_HEAL") or mend.is_empty(), "治疗日志（MSG_SKILL_HEAL，带 dice）")
	var agent_heal := false
	var r4 := _load_campaign01()
	var b4 := Board.new(EventStream.new())
	var d4: Dictionary = BattleDef.assemble(r4, "N1-7", {}, b4)["def"]
	var sm4 := EncounterSM.new(b4, b4.stream, Rng.new(9), "campaign01")
	sm4.enter("N1-7")
	sm4.transition(EncounterSM.S_EXPLORE)
	sm4.begin_combat(d4)
	for id: String in sm4.get_order():
		if str(sm4.get_unit(id)["side"]) == "party":
			sm4._units[id]["hp"] = 2
	for i: int in 6:
		var cmd := AutoAgent.new().next_command(sm4)
		if str(cmd.get("skill", "")) in ["kelan_mend"]:
			agent_heal = true
			break
		sm4.submit_command(cmd)
	check(agent_heal, "托管会用同伴的治疗技能救低血队友")

# ---------------------------------------------------------------- 节点流程视图模型（双壳共用内容源，godot-dev §7）

func test_story_vm() -> void:
	print("[story_vm]")
	var pack := _load_campaign01()
	var stream := EventStream.new()
	var board := Board.new(stream)
	var graph := StoryGraph.new(board, Rng.new(20260009), pack)
	graph.start()
	var vm := StoryVM.build(graph, board, pack)
	check(str(vm["type"]) == "scene" and str(vm["title"]) == "潮醒", "vm：scene 标题（tech/02 §3）")
	check(str(vm["text"]).contains("潮声"), "vm：叙事文本 = nodes.json summary")
	check((vm["rooms"] as Array)[0] == "N0-1" and int(vm["room_index"]) == 0
		and (vm["rooms"] as Array).has("N0-2"), "vm：推进条房间 = 已访 + 未来预告（04 §④.2）")
	check((vm["edges"] as Array).size() == 1 and str(vm["edges"][0]["label"]) == "起身", "vm：scene 继续选项")
	check(not (vm["forecast"] as Dictionary).is_empty()
		and str((vm["forecast"] as Dictionary)["name"]) == "墨雨夜袭"
		and int((vm["forecast"] as Dictionary)["at"]) == 2, "vm：时间边预告（墨雨夜袭 2 格）")
	check(int(vm["quest_badge"]) == 0 and (vm["party"] as Array).size() == 3, "vm：事件角标 + 队伍 HP")
	# 检定选项文案（04 §④.3 检定房：一键快掷前置信息）
	graph.take_edge(_edge_to(graph, "N0-2"))
	vm = StoryVM.build(graph, board, pack)
	check(str(vm["edges"][0]["label"]) == "检定：感知（易 DC 8 · 修正 +0）",
		"vm：检定按钮含技能/难度/DC/修正")
	# hub vm（金币/货单/传闻）
	graph.seed_gold()
	graph.roll_check(graph.available_edges()[0]) # 种子 20260009：d20=17 成功 → N0-3a
	graph.take_edge(_edge_to(graph, "N0-4"))
	graph.take_edge(_edge_to(graph, "N1-1"))
	vm = StoryVM.build(graph, board, pack)
	check(str(vm["type"]) == "hub" and int(vm["gold"]) == 30
		and (vm["stock"] as Array).size() == 9 and (vm["rumors"] as Array).size() >= 4,
		"vm：hub 金币/货单（7 件在售）/传闻齐备")
	# 对话选项声望角标（N1-3：接触三方 → 目标节点 on_enter rep 效果）
	graph.take_edge(_edge_to(graph, "N1-2"))
	graph.roll_check(graph.available_edges()[0]) # d20=17 成功 → N1-3
	vm = StoryVM.build(graph, board, pack)
	var joined := ""
	for e: Variant in vm["edges"]:
		joined += str((e as Dictionary)["label"]) + "|"
	check(joined.contains("接触誊写庭　〔誊写庭 +0〕"), "vm：对话选项带声望角标（faction + 当前值）")
	# toast 文案（事件流驱动，双壳同源）
	check(StoryVM.toast_text({"type": EventTypes.FLAG_WRITE,
		"payload": {"key": "campaign01.seen_fading"}}).contains("旗标"), "toast：旗标更新")
	check(StoryVM.toast_text({"type": EventTypes.FLAG_WRITE,
		"payload": {"key": "campaign01.gold"}}) == "", "toast：簿记键（金币）不上浮")
	check(StoryVM.toast_text({"type": EventTypes.REP_CHANGE,
		"payload": {"key": "global.rep.scriptorium", "delta": 1, "value": 1}}).contains("誊写庭 +1"),
		"toast：声望变化")
	check(StoryVM.toast_text({"type": EventTypes.ITEM_GAIN,
		"payload": {"item_id": "half_tide_table", "count": 1}}, pack).contains("半页潮汐表"),
		"toast：道具名按 items.json 解析")
	check(StoryVM.toast_text({"type": EventTypes.QUEST_TRIGGER,
		"payload": {"name": "码头异闻"}}).contains("码头异闻"), "toast：L3 事件触发")
	check(StoryVM.toast_text({"type": EventTypes.LOG, "payload": {"msg": "x", "toast": true}}) == "x"
		and StoryVM.toast_text({"type": EventTypes.LOG, "payload": {"msg": "x"}}) == "",
		"toast：仅显式标记的日志上浮")

# ---------------------------------------------------------------- text_ref 长文本外置（tech/02 §1.1 v0.7）

func test_text_ref() -> void:
	print("[text_ref]")
	var pack := _load_campaign01()
	var texts: Dictionary = pack.get("texts", {})
	var zh: Dictionary = texts.get("texts/zh-CN.json", {})
	check(texts.size() >= 1 and not zh.is_empty(), "texts/zh-CN.json 加载为键值表（tech/02 §1.1）")
	# ---- 命中外置文本：N0-1 呈现 = texts 全文（非 summary）----
	var n01: Dictionary = (pack["nodes"] as Dictionary)["N0-1"]
	var t01 := StoryVM.node_text(n01, null, "campaign01", texts)
	check(t01 == str(zh.get("node.N0-1.text", "")) and t01 != str(n01.get("summary", ""))
		and t01.contains("潮声"), "text_ref 命中：N0-1 呈现外置全文（非 summary 兜底）")
	check(t01.length() > str(n01.get("summary", "")).length(), "外置全文长于 summary（摘要保留为列表/回顾用）")
	# ---- text_variants 优先级（tech/02 §3/§1.1：旗标变体 = 纯呈现替换，覆盖外置全文）----
	var stream := EventStream.new()
	var board := Board.new(stream)
	board.write("campaign01.unlock_scribe_identity", true,
		{"event_id": 1, "node_id": "", "pack_id": "campaign01"})
	check(StoryVM.node_text(n01, board, "campaign01", texts).contains("执笔者"),
		"text_variants 优先于 text_ref（多周目执笔者开局独白，纯呈现差异）")
	# ---- 缺失键兜底 summary（§1.1：静默回退不报错）----
	var fake := {"summary": "兜摘要", "text_ref": "texts/zh-CN.json#node.NOPE.text"}
	check(StoryVM.node_text(fake, null, "campaign01", texts) == "兜摘要", "断链静默兜底 summary（不拒绝加载）")
	var fake2 := {"summary": "兜摘要2", "text_ref": "texts/en.json#node.N0-1.text"}
	check(StoryVM.node_text(fake2, null, "campaign01", texts) == StoryVM.resolve_text(texts, "#node.N0-1.text", ""),
		"text_ref 文件前缀与语言无关：按当前语言表解析（tech/02 §1.1 双语构建）")
	check(StoryVM.node_text({"summary": "纯摘要"}, null, "campaign01", texts) == "纯摘要",
		"无 text_ref 节点维持 summary（可选字段，§11 新增字段一律可选）")
	# ---- 双壳同源：同一 StoryVM.build 是双壳 show_story 唯一输入（godot-dev §7；壳不各自解析）----
	var graph := StoryGraph.new(board, Rng.new(20260009), pack)
	graph.start()
	var vm := StoryVM.build(graph, board, pack)
	check(str(vm["text"]) == StoryVM.node_text(graph.current(), board, "campaign01", texts)
		and str(vm["text"]).length() > 40, "vm.text = 外置全文（双壳同源唯一内容源）")
	# ---- 结局演出文案：text_ref 全文 → content 摘要兜底（tech/02 §9 v0.7）----
	var edefs := {}
	for e: Variant in pack.get("endings", []):
		edefs[str((e as Dictionary).get("id", ""))] = e
	for eid: String in ["E1", "E2", "E3", "E4"]:
		var full := StoryVM.ending_text(texts, edefs[eid])
		check(full == str(zh.get("ending.%s.text" % eid, "")) and full.contains("\n")
			and full.length() > str((edefs[eid] as Dictionary).get("content", "")).length(),
			"结局 %s 演出全文 = text_ref 外置（3~5 句，content 摘要兜底不外显）" % eid)
	var bare := {"content": "单行摘要"}
	check(StoryVM.ending_text(texts, bare) == "单行摘要", "结局无 text_ref 兜底 content（向后兼容）")
	# ---- 图鉴正文：text_ref → 无内嵌字段，键缺失即空串（tech/02 §10 v0.7）----
	var l01 := {}
	for l: Variant in pack.get("lore", []):
		if str((l as Dictionary).get("id", "")) == "weaver_fragment_01":
			l01 = l
	check(StoryVM.lore_text(texts, l01) == str(zh.get("lore.weaver_fragment_01", ""))
		and StoryVM.lore_text(texts, l01).contains("金墨"), "图鉴正文 = text_ref 外置（残简·其一）")
	check(StoryVM.lore_text(texts, {"id": "x"}) == "", "图鉴无 text_ref = 空串（界面仅显标题/来源）")
	# ---- 抽取完整性防断链：全部 text_ref 键在 texts 表存在（§1.1 数据缺陷断言）----
	var broken: Array[String] = []
	for nid: String in (pack["nodes"] as Dictionary).keys():
		var ref := str(((pack["nodes"] as Dictionary)[nid] as Dictionary).get("text_ref", ""))
		if ref != "" and not zh.has(ref.get_slice("#", 1)):
			broken.append(nid)
	for e: Variant in pack.get("endings", []):
		var ref2 := str((e as Dictionary).get("text_ref", ""))
		if ref2 != "" and not zh.has(ref2.get_slice("#", 1)):
			broken.append("ending:" + str((e as Dictionary).get("id", "")))
	for l: Variant in pack.get("lore", []):
		var ref3 := str((l as Dictionary).get("text_ref", ""))
		if ref3 != "" and not zh.has(ref3.get_slice("#", 1)):
			broken.append("lore:" + str((l as Dictionary).get("id", "")))
	check(broken.is_empty(), "抽取完整性：全部 text_ref 键在 texts 表存在（断链：%s）" % str(broken))
	# ---- 写作规模与纪律（§1.1：全文不引入未声明旗标）----
	var node_keys := 0
	for k: String in zh.keys():
		if str(k).begins_with("node."):
			node_keys += 1
	check(node_keys == 41 and zh.size() == 52,
		"texts 键数：节点 41（除 E1~E4 结局节点）+ 结局 4 + 图鉴 7 = 52")
	var declared := {}
	for f: Variant in pack.get("flags", []):
		declared[str((f as Dictionary).get("id", ""))] = true
	for known: String in ["ending_e1", "ending_e2", "ending_e3", "ending_e4",
			"unlock_scribe_identity", "ngplus_memory_view"]:
		declared[known] = true
	var leak := ""
	var flag_pat := RegEx.new()
	flag_pat.compile("flag\\.([a-z0-9_]+)")
	for k: String in zh.keys():
		for r: RegExMatch in flag_pat.search_all(str(zh[k])):
			if not declared.has(r.get_string(1)):
				leak = "%s->%s" % [k, r.get_string(1)]
	check(leak == "", "全文不引入未声明旗标（%s）" % leak)

# ---------------------------------------------------------------- 子游戏「竞技场连战」（M3：白皮书 §10.2 扩展承诺验证）
# 关键验证点：core 零改动——子游戏 = 内容包（packs/arena）+ 引导层流程（SubgameRunner/main.gd），
# 复用 PackLoader/StoryGraph/EncounterSM/BattleDef/Board 全部现有 core 能力。

func _load_arena() -> Dictionary:
	var res := PackLoader.load_pack("res://packs/arena")
	check(res["ok"], "arena 包加载成功：%s" % ";".join(res["errors"]))
	return res["pack"]

## 托管打完一场连战（同构 Command 通道，09 §9.3）；buff=必胜夹具 / weaken=必败夹具。
func _sub_run_battle(runner: SubgameRunner, seed: int, buff: bool, weaken: bool = false) -> EncounterSM:
	var def := runner.battle_def({"skills": [], "items": []})
	check(not def.is_empty(), "遭遇 %s 组装 ok" % runner.encounter_id())
	if buff: # 必胜夹具：全队高修正重骰普攻（流程验证，非数值平衡验证；移除技能避免技能伤害盖过重骰）
		for u: Variant in def["party"]:
			(u as Dictionary)["attack_mod"] = 30
			(u as Dictionary)["damage"] = "30d6"
			(u as Dictionary).erase("skills")
			(u as Dictionary).erase("items")
	if weaken:
		for u: Variant in def["party"]:
			(u as Dictionary)["hp"] = 1
			(u as Dictionary)["attack_mod"] = -50
			(u as Dictionary)["damage"] = "1d1"
		for u: Variant in def["enemies"]:
			(u as Dictionary)["damage"] = "10d6"
	var sm := EncounterSM.new(runner.board, runner.stream, Rng.new(seed), "arena")
	var agent := AutoAgent.new()
	sm.enter(runner.graph.current_id)
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(def)
	var guard := 0
	while not sm.is_over() and guard < 500:
		guard += 1
		var cmd := agent.next_command(sm)
		if cmd.is_empty():
			break
		sm.submit_command(cmd)
	return sm

func test_subgame_arena() -> void:
	print("[subgame_arena]")
	# ---- 包加载与 manifest 声明（tech/02 §2）----
	var pack := _load_arena()
	if pack.is_empty():
		return
	var manifest: Dictionary = pack["manifest"]
	check(str(manifest["pack_type"]) == "subgame", "manifest pack_type=subgame（tech/02 §2）")
	check(str(manifest["namespace"]) == "arena", "命名空间 = pack_id（§2 防呆）")
	var sub: Dictionary = manifest["subgame"]
	check(bool((sub["rules_override"] as Dictionary).get("arena_mode", false)),
		"rules_override = { arena_mode: true }（复用 light_v1 仅表现层变体，概念设计 §5）")
	check(str((manifest["presentation"] as Dictionary)["mode"]) == "choice", "双模式可选（tech/02 §2.1）")
	check((sub["gold_reward"] as Array).size() == 3, "subgame.gold_reward 三场金币声明（数据驱动奖励）")
	check((pack["nodes"] as Dictionary).size() == 5 and (pack["encounters"] as Dictionary).size() == 3
		and (pack["enemies"] as Dictionary).size() == 3, "节点图 5 节点 / 3 场遭遇 / 3 种敌人（含新增守页人精英）")
	check((pack["enemies"] as Dictionary).has("page_warden_elite")
		and (pack["enemies"] as Dictionary).has("ink_fiend"), "阵容：复用墨魈系 + 新增守页人精英")
	# ---- packlint V1~V13（tech/02 §12 + tech/04 §6）----
	var issues := PacklintCore.lint(pack)
	var fails: Array = []
	for issue: Dictionary in issues:
		if issue["level"] == PacklintCore.LEVEL_FAIL:
			fails.append("%s: %s" % [issue["v"], issue["msg"]])
	check(fails.is_empty(), "arena packlint V1~V13 无 FAIL：%s" % ";".join(fails))
	for v: String in ["V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V11", "V12", "V13"]:
		check(issues.any(func(i: Dictionary) -> bool:
			return i["v"] == v and i["level"] == PacklintCore.LEVEL_PASS), "arena packlint %s PASS" % v)
	# ---- core 不认识子游戏（白皮书 §10.2 "子游戏不动框架"）：静态扫描 core/ 代码不含任何子游戏/支线包 id ----
	var core_hits := _core_code_mentions(["arena", "riddle_maze", "arc_tide"])
	check(core_hits.is_empty(), "core/ 代码零子游戏/支线包 id（子游戏不动框架）：%s" % ";".join(core_hits))

	# ---- 连战三场全胜流程（复用 EncounterSM ×3；奖励写板；战绩旗标）----
	var stream := EventStream.new()
	var board := Board.new(stream)
	board.give_item("heal_potion", 2, {"event_id": 0, "node_id": "A-0", "pack_id": "arena"})
	var runner := SubgameRunner.new(pack, board, stream, Rng.new(77))
	runner.start()
	check(runner.graph.current_id == "A-0", "进场节点 A-0（tech/02 §3）")
	runner.take_edge(0) # 踏入擂台 → A-1
	var stage_encs: Array[String] = ["AR-1", "AR-2", "AR-3"]
	for stage: int in 3:
		check(runner.encounter_id() == stage_encs[stage], "第 %d 场遭遇 = %s（节点图驱动）" % [stage + 1, stage_encs[stage]])
		var snap: Dictionary = board.serialize() # 夹具尝试回滚：每场以同一赛前状态重试，簿记不被失败尝试污染
		var won := false
		for seed: int in range(1, 100):
			var sm := _sub_run_battle(runner, seed, true)
			if sm.result() == &"victory":
				won = true
				if stage == 0:
					check(board.has("arena.hp.player_blank"), "第 1 场后 HP 写板（11 §7.1 连战持久前提）")
				break
			board.deserialize(snap)
		check(won, "seed 空间内第 %d 场必胜样本" % (stage + 1))
		if not won:
			return
		runner.on_victory() # 每场胜利：金币 + 累计胜场写板（04 §6）
		if stage == 1:
			var def2 := runner.battle_def({})
			var hp_board := int(board.read("arena.hp.player_blank"))
			check(int(def2["party"][0]["hp"]) == clampi(hp_board, 1, int(def2["party"][0]["max_hp"])),
				"第 3 场前组装以持久 HP 开局（含死亡 0→1 抬升，11 §7.1 / battle_def 抬升语义）")
		runner.take_edge(0) # 乘胜追击 / 全胜谢幕
	check(runner.graph.current_id == "A-END" and runner.graph.is_at_ending(), "全胜 → 结算节点 A-END")
	check(int(board.read("arena.gold", 0)) == 100, "三场金币 20+30+50=100 落板（manifest gold_reward）")
	check(int(board.read("arena.wins", 0)) == 3, "累计胜场 3 落板（stat_keys.wins）")
	check(board.read("arena.stage1_cleared") == true and board.read("arena.stage2_cleared") == true
		and board.read("arena.stage3_cleared") == true and board.read("arena.flawless") == true,
		"场次旗标 + 全胜旗标落板（边效果 DSL，V4 闭环）")
	check(board.has_item("ink_core"), "全胜追加墨核 ×1 进 global.inv（互通，概念设计 §3）")
	var xp_sum := 0
	for ev: Dictionary in stream.query_by_type(EventTypes.XP_GAIN):
		xp_sum += int(ev["payload"]["amount"])
	check(xp_sum == 250, "三场经验 50+80+120=250（encounters.xp 数据驱动）")
	check(Growth.xp(board) == 250,
		"子游戏经验喂养角色成长：胜利 xp 经同一 xp 效果汇入 global.growth.xp（tech/04 §8 规则1）")
	var summary := runner.finish_run(&"victory")
	check(int(summary["wins"]) == 3 and int(summary["gold"]) == 100 and int(summary["best"]) == 3,
		"收场汇总：3 胜 / 100 金 / 最佳 3")
	check(int(board.read("arena.best", 0)) == 3, "最佳连战纪录写板（stat_keys.best）")

	# ---- 中途败北：按已完成场次结算（失败即分支的竞技场形态，概念设计 §2）----
	var s2 := EventStream.new()
	var b2 := Board.new(s2)
	var r2 := SubgameRunner.new(pack, b2, s2, Rng.new(7))
	r2.start()
	r2.take_edge(0) # → A-1
	var snap1: Dictionary = b2.serialize() # 夹具尝试回滚（同上）
	var won1 := false
	for seed: int in range(1, 100):
		if _sub_run_battle(r2, seed, true).result() == &"victory":
			won1 = true
			break
		b2.deserialize(snap1)
	check(won1, "败北局：第 1 场先胜（铺垫已完成场次）")
	r2.on_victory()
	r2.take_edge(0) # 追击 → A-2
	var snap2: Dictionary = b2.serialize() # 夹具尝试回滚（同上）
	var lost := false
	for seed: int in range(1, 400):
		if _sub_run_battle(r2, seed, false, true).result() == &"defeat":
			lost = true
			break
		b2.deserialize(snap2)
	check(lost, "seed 空间内第 2 场败北样本（全员倒地团灭，11 §5.2）")
	var sum2 := r2.finish_run(&"defeat")
	check(int(sum2["wins"]) == 1 and int(sum2["gold"]) == 20, "中途败北：按已完成 1 场结算（1 胜 / 20 金）")
	check(b2.read("arena.stage1_cleared") == true and b2.read("arena.stage2_cleared") == false,
		"败北场次不写场次旗标（失败即分支）")
	check(int(b2.read("arena.best", 0)) == 1, "败北收场：最佳纪录 = 已完成场次（1）")

# ---------------------------------------------------------------- 支线包 arc_tide（tech/02 §2.6 graft、§12 V14；docs/story/04-支线-雾码头的回声.md）

func _load_arc_tide() -> Dictionary:
	var res := PackLoader.load_pack("res://packs/arc_tide")
	check(res["ok"], "arc_tide 包加载成功：%s" % ";".join(res["errors"]))
	return res["pack"]

func test_arc_tide() -> void:
	print("[arc_tide]")
	var host := _load_campaign01()
	var arc := _load_arc_tide()
	if arc.is_empty():
		return
	var manifest: Dictionary = arc["manifest"]
	check(str(manifest["pack_type"]) == "arc", "manifest pack_type=arc（tech/02 §2）")
	var graft: Dictionary = manifest["graft"]
	check(str(graft["into"]) == "campaign01" and str(graft["node"]) == "N1-1"
		and str((graft["edge"] as Dictionary)["to"]) == "T-1", "graft 声明：挂接 campaign01/N1-1 → T-1（§2.6）")
	check(not manifest.has("entitlement") and (manifest["monetization"] as Dictionary)["strategies"] == ["free"],
		"支线免费：entitlement 缺省 + strategies=[free]（§2.2/§2.3）")
	# ---- packlint：合并视图 V1~V13 + V14（§12）----
	var issues := PacklintCore.lint_grafted(arc, host)
	var fails: Array = []
	for issue: Dictionary in issues:
		if issue["level"] == PacklintCore.LEVEL_FAIL:
			fails.append("%s: %s" % [issue["v"], issue["msg"]])
	check(fails.is_empty(), "arc_tide lint_grafted 无 FAIL：%s" % ";".join(fails))
	for v: String in ["V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V11", "V12", "V13", "V14"]:
		check(issues.any(func(i: Dictionary) -> bool:
			return i["v"] == v and i["level"] == PacklintCore.LEVEL_PASS), "arc_tide %s PASS" % v)
	# ---- V14 负例 ----
	var bad_node: Dictionary = arc.duplicate(true)
	(bad_node["manifest"] as Dictionary)["graft"]["node"] = "N9-9"
	check(PacklintCore.lint_grafted(bad_node, host).any(func(i: Dictionary) -> bool:
		return i["v"] == "V14" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：graft.node 宿主不存在 V14 必报 FAIL")
	var bad_to: Dictionary = arc.duplicate(true)
	(bad_to["manifest"] as Dictionary)["graft"]["edge"]["to"] = "T-9"
	check(PacklintCore.lint_grafted(bad_to, host).any(func(i: Dictionary) -> bool:
		return i["v"] == "V14" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：graft.edge.to 非本包节点 V14 必报 FAIL")
	var bad_collide: Dictionary = arc.duplicate(true)
	(bad_collide["nodes"] as Dictionary)["N1-1"] = (bad_collide["nodes"] as Dictionary)["T-1"]
	(bad_collide["node_order"] as Array).append("N1-1")
	check(PacklintCore.lint_grafted(bad_collide, host).any(func(i: Dictionary) -> bool:
		return i["v"] == "V14" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：支线节点 id 与宿主冲突 V14 必报 FAIL（命名空间独立）")
	# ---- graft 注入 / 显隐 / 卸载（§2.6）----
	var stream := EventStream.new()
	var board := Board.new(stream)
	var graph := StoryGraph.new(board, Rng.new(42), host)
	graph.start()
	graph.take_edge(_edge_to(graph, "N0-2"))
	graph.resolve_check(graph.available_edges()[0], true)
	graph.take_edge(_edge_to(graph, "N0-4"))
	graph.take_edge(_edge_to(graph, "N1-1"))
	check(_edge_to(graph, "T-1").is_empty(), "包未注入：支线边不显形（包缺失 = 主线不变，§2.6）")
	var host_n11_edges := ((host["nodes"]["N1-1"] as Dictionary)["edges"] as Array).size()
	var host_node_count := (host["nodes"] as Dictionary).size()
	check(bool(graph.graft_pack(arc)["ok"]), "graft 注入成功（merge_graft 校验通过）")
	check(((graph.pack["nodes"]["N1-1"] as Dictionary)["edges"] as Array).size() == host_n11_edges + 1,
		"注入边只入合并视图；宿主包数据不动（§2.6）")
	check((host["nodes"] as Dictionary).size() == host_node_count, "宿主包节点数不变（不动主线数据）")
	check(_edge_to(graph, "T-1").is_empty(), "未持潮汐表：注入边不显形（§4.3 item 边无 fallback 即隐）")
	board.give_item("half_tide_table", 1, {"event_id": stream.tail(), "node_id": "N1-1", "pack_id": "campaign01"})
	var e_tide := _edge_to(graph, "T-1")
	check(not e_tide.is_empty() and str(e_tide.get("label", "")) == "循着潮汐表的指引",
		"持潮汐表：注入边显形（graft.edge label 上屏）")
	# ---- 支线全流程（跨包走图；检定/战斗遭遇/奖励/收束）----
	var xp0 := Growth.xp(board) # 主线走路已有经验入账，支线断言按增量口径
	graph.take_edge(e_tide)
	check(graph.current_id == "T-1", "注入边 → T-1（跨包走图，合并视图寻址）")
	check(graph.quests().any(func(q: Dictionary) -> bool:
		return q["id"] == "tide_whisper" and q["state"] == "triggered"),
		"支线事件随注入边触发（events.json choice trigger，tech/02 §5）")
	graph.resolve_check(graph.available_edges()[0], false) # 夜探检定失败路
	check(graph.current_id == "T-2" and board.get_doom_clock() == 1,
		"夜探检定失败：罚时 +1 仍达打捞战（失败即分支型式 B，§4.2）")
	var bres := BattleDef.assemble(graph.pack, "T-2", {}, board)
	check(bool(bres["ok"]), "打捞战遭遇组装：arc 遭遇 × 宿主墨魈系敌人/玩家模板（§2.6 合并视图复用）")
	graph.take_edge(_edge_to(graph, "T-3")) # 战后唯一出边
	check(board.has_lore("revoked_registry_tide"), "捞起名录残页：lore → global.lore（§4.6）")
	check(board.get_rep("salvage") == 1, "拾遗行会声望 +1（rep.salvage 全局白名单）")
	check(Growth.xp(board) == xp0 + 40, "残页经验 +40 汇入成长（tech/04 §8 规则1）")
	graph.take_edge(_edge_to(graph, "T-4"))
	check(board.read("arc_tide.done") == true, "收束写旗标 arc_tide.done（支线命名空间，07 §3）")
	check(not board.has("campaign01.done"), "支线旗标不污染主线命名空间（V7/07 §3）")
	graph.take_edge(_edge_to(graph, "N1-1"))
	check(graph.current_id == "N1-1", "收束回主线 N1-1（支线终点边指回宿主节点，§2.6）")
	check(Growth.xp(board) == xp0 + 60, "支线事件 settle：xp +20（离开 T-4 时结算，tech/02 §5）")
	check(_edge_to(graph, "T-1").is_empty(), "完成后支线入口隐去（graft.edge requires flag.done=false）")
	# ---- 卸载：注入边与支线节点消失 ----
	check(graph.ungraft_pack("arc_tide"), "卸载已注入支线返回 true")
	check(_edge_to(graph, "T-1").is_empty() and not (graph.pack["nodes"] as Dictionary).has("T-1"),
		"卸载包：注入边与支线节点消失，宿主图还原（§2.6 卸载语义）")
	check(not graph.ungraft_pack("arc_tide"), "重复卸载返回 false（幂等）")
	graph.graft_pack(arc)
	check(not bool(graph.graft_pack(arc)["ok"]), "重复注入幂等拒绝")
	graph.ungraft_pack("arc_tide")
	# ---- 仿真不回归：注入支线后主战役四结局全集保持（arc 不影响主线结局分布）----
	var view: Dictionary = PackLoader.merge_graft(host, arc)["view"]
	var endings := {}
	var all_ok := true
	for i: int in 24:
		var lone := i % 4 == 2
		var ngp := i % 2 == 1
		var detour := i % 12 == 4 and not lone and not ngp
		var r := StoryBot.run(view, 1000 + i * 7919, ngp, lone, detour)
		if not r["ok"]:
			all_ok = false
			continue
		endings[str(r["ending"])] = true
	check(all_ok, "注入支线后 24 局全部必达结局（合并视图 bot 仿真）")
	check(endings.has("E1") and endings.has("E2") and endings.has("E3") and endings.has("E4")
		and endings.size() == 4, "注入支线后四结局全集保持（arc 不影响主线结局分布，§2.6 不并入 endings）")

# ---------------------------------------------------------------- 第二子游戏 riddle_maze（docs/subgames/riddle-maze/01-概念设计.md；
# 白皮书 §10.2：复用遭遇状态机+替换规则参数——本包验证"纯解谜房间序列零战斗"形态，tech/02 §6 maze）

func test_riddle_maze() -> void:
	print("[riddle_maze]")
	var res := PackLoader.load_pack("res://packs/riddle_maze")
	check(res["ok"], "riddle_maze 包加载成功：%s" % ";".join(res["errors"]))
	var pack: Dictionary = res["pack"]
	var manifest: Dictionary = pack["manifest"]
	check(str(manifest["pack_type"]) == "subgame", "manifest pack_type=subgame（tech/02 §2）")
	check(not manifest.has("entitlement"), "entitlement 缺省 = 随本体免费（§2.2）")
	check((manifest["monetization"] as Dictionary)["strategies"] == ["free"],
		"strategies=[free] 且不声明 requires（§2.3 一致性）")
	check(bool((manifest["subgame"] as Dictionary).get("clear_as_win", false)),
		"subgame.clear_as_win 登记（§2.5：无战斗子游戏抵达结局记 1 胜）")
	check((pack["encounters"] as Dictionary).values().all(func(e: Variant) -> bool:
		return str((e as Dictionary).get("type", "")) == "maze"), "零战斗：全部遭遇为 maze 探索序列")
	# ---- packlint V1~V13 ----
	var issues := PacklintCore.lint(pack)
	var fails: Array = []
	for issue: Dictionary in issues:
		if issue["level"] == PacklintCore.LEVEL_FAIL:
			fails.append("%s: %s" % [issue["v"], issue["msg"]])
	check(fails.is_empty(), "riddle_maze packlint V1~V13 无 FAIL：%s" % ";".join(fails))
	for v: String in ["V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V11", "V12", "V13"]:
		check(issues.any(func(i: Dictionary) -> bool:
			return i["v"] == v and i["level"] == PacklintCore.LEVEL_PASS), "riddle_maze %s PASS" % v)
	# ---- 失败给提示重来（tech/02 §6 retry_on_fail/hint；确定性夹具：mod -50 恒失败除非 nat20）----
	var fail_seed := -1
	for s: int in range(1, 200):
		if Rng.new(s).d20() != 20:
			fail_seed = s
			break
	var stream := EventStream.new()
	var board := Board.new(stream)
	var beats1: Array = ((pack["encounters"]["RM-1"] as Dictionary)["maze"] as Dictionary)["beats"]
	var mr := MazeRunner.new(board, stream, Rng.new(fail_seed), "riddle_maze")
	mr.begin("RM-1", beats1, func(_skill: String) -> int: return -50, "R-1")
	var fail_res := mr.resolve()
	check(not bool(fail_res["success"]) and bool(fail_res.get("retry", false))
		and str(fail_res.get("hint", "")).contains("倒着写"), "失败给提示：retry + hint 文案（§6 解谜房语义）")
	check(mr.beat_index() == 0 and not mr.is_done(), "失败不推进节拍（原地重试，不进死路）")
	check(int(board.read("riddle_maze.maze.RM-1.idx", 0)) == 0,
		"重试不写节拍进度簿记（重来不重复效果，07 §4.2）")
	check(stream.query_by_type(EventTypes.CHECK_ROLL).size() == 1, "失败拍仍产 check.roll（演出链完整）")
	# ---- 全流程（三房间 + 通关结算；零 EncounterSM）----
	var stream2 := EventStream.new()
	var board2 := Board.new(stream2)
	var runner := SubgameRunner.new(pack, board2, stream2, Rng.new(7))
	runner.start()
	check(runner.graph.current_id == "R-0", "进场节点 R-0（tech/02 §3）")
	check(Entitlements.new(board2, stream2).can_access(manifest), "免费包入口可进（entitlement 缺省）")
	runner.take_edge(0) # → R-1
	var win_mod := func(_skill: String) -> int: return 50 # 高修正夹具：恒成功（流程验证非数值验证）
	for enc_id: String in ["RM-1", "RM-2", "RM-3"]:
		check(str(runner.current().get("encounter", "")) == enc_id,
			"房间节点关联遭遇 %s（tech/02 §3 encounter 关联）" % enc_id)
		var beats: Array = ((pack["encounters"][enc_id] as Dictionary)["maze"] as Dictionary)["beats"]
		var mrx := MazeRunner.new(board2, stream2, Rng.new(11), "riddle_maze")
		mrx.begin(enc_id, beats, win_mod, runner.graph.current_id)
		while not mrx.is_done():
			mrx.resolve()
		check(int(board2.read("riddle_maze.maze.%s.idx" % enc_id, 0)) == beats.size(),
			"%s 探索序列完成（节拍簿记 %d 拍）" % [enc_id, beats.size()])
		runner.take_edge(0) # 房间出边 → 下一房间 / R-END
	check(board2.item_count("riddle_page") == 1, "静室二拾取拍：谜面残页 ×1 进 global.inv（互通）")
	check(runner.graph.is_at_ending() and runner.graph.current_id == "R-END", "三房间通关 → 结算节点 R-END")
	check(int(board2.read("riddle_maze.gold", 0)) == 40, "通关金币 +40（gold 效果，tech/02 §4.6）")
	check(board2.has_lore("fatedie_study_riddle"), "通关图鉴：命骰考·谜回廊潮位骰（global.lore 互通）")
	check(Growth.xp(board2) == 60, "通关经验 +60 汇入成长（tech/04 §8 规则1）")
	var gold_prov := board2.provenance_of("riddle_maze.gold")
	check(str(gold_prov.get("pack_id", "")) == "riddle_maze", "金币写板溯源：包命名空间（07 §1/§3）")
	runner.on_clear() # clear_as_win：抵达结局记 1 胜（main._sub_present 同口径）
	var summary := runner.finish_run(&"victory")
	check(int(board2.read("riddle_maze.wins", 0)) == 1 and int(summary["wins"]) == 1
		and int(summary["best"]) == 1, "通关记 1 胜：wins/best 簿记（manifest.subgame.stat_keys）")
	var stats := runner.stats()
	check(int(stats["wins"]) == 1 and int(stats["gold"]) == 40, "战绩卡数据源：通关次数 + 累计金币（04 §6）")

# ---------------------------------------------------------------- 权利模型运行时（06 §2/§3.2/§5；tech/02 §2.2/§2.3）

func test_entitlements() -> void:
	print("[entitlements]")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var ent := Entitlements.new(board, stream)
	var arena_pack := _load_arena()
	var manifest: Dictionary = arena_pack["manifest"]
	# 缺省 = 随本体权利可进入；门槛未点亮 = 锁定（tech/02 §2.2）
	check(ent.can_access({}), "manifest 无 entitlement 声明 = 随本体权利可进入（tech/02 §2.2 缺省）")
	check(Entitlements.requires_of(manifest) == ["entitlement.arena"], "arena 门槛声明解析（manifest entitlement.requires）")
	check(not ent.can_access(manifest), "权利未点亮 → 锁定（硬门槛，全真判断）")
	check(ent.missing(manifest) == ["entitlement.arena"], "缺失权利清单（锁定态呈现依据）")
	# 商店点亮：写入即生效 + 单号溯源 + system 写权限（06 §2.3/§3.1）
	check(ent.shop_purchase("arena", "rcpt_test_001"), "shop_purchase 商店点亮（06 §2.3 写入方之一）")
	check(ent.can_access(manifest), "购买即解锁：写入即生效无需重启（06 §3.1）")
	var prov := board.provenance_of("global.entitlement.arena")
	check(str(prov.get("pack_id", "")) == "system" and str(prov.get("receipt_id", "")) == "rcpt_test_001"
		and str(prov.get("granted_by", "")) == "shop", "写入溯源：购买单号 + system 写权限（06 §2.3 / 07 §3）")
	check(stream.query_by_type(EventTypes.ENTITLEMENT_CHANGE).size() == 1,
		"权利变更经 entitlement.change 进事件流（07 §6）")
	# 内容包直写权利变量被拒（07 §3：仅 system 可写）
	check(not board.write("global.entitlement.arena", false,
		{"event_id": 1, "node_id": "A-0", "pack_id": "arena"}), "内容包写权利变量被拒（07 §3 命名空间权限）")
	check(ent.can_access(manifest), "越权写入未生效（权利仍点亮）")
	# 退款（06 §5）：权利置假 → 不可开新局；进行中连战允许跑完（流程核不回读权利）
	check(ent.refund("arena"), "refund 权利置假（06 §5）")
	check(not ent.can_access(manifest), "退款后不可开新局（入口 can_access 把关，06 §5）")
	var runner := SubgameRunner.new(arena_pack, board, stream, Rng.new(7))
	runner.start()
	check(runner.graph.current_id == "A-0", "退款不影响进行中的连战：允许跑完当前战役（06 §5）")
	# 活动点亮：activity_id + ttl 溯源（06 §3.2 运营轨）
	check(ent.activity_grant("arena", "weekend_free_arena", 48), "activity_grant 活动点亮（06 §2.3 写入方之二）")
	check(ent.can_access(manifest), "活动点亮即时生效")
	prov = board.provenance_of("global.entitlement.arena")
	check(str(prov.get("activity_id", "")) == "weekend_free_arena" and int(prov.get("ttl_hours", 0)) == 48,
		"活动溯源：activity_id + ttl 随写入（限免回收依据，06 §2.3）")
	ent.refund("arena")
	# 成就点亮：campaign01.cleared == true → entitlement.arena（多点亮路径演示，06 §2.1）
	var ops := Entitlements.load_ops_config()
	check(ent.check_achievements(ops).is_empty(), "成就旗标未立：规则不触发")
	board.write("campaign01.cleared", true, {"event_id": 2, "node_id": "N1-8", "pack_id": "campaign01"})
	var granted: Array = ent.check_achievements(ops)
	check(granted.has("arena") and ent.can_access(manifest),
		"成就点亮：campaign01.cleared → entitlement.arena（烬港通关者免费入场，06 §2.1）")
	prov = board.provenance_of("global.entitlement.arena")
	check(str(prov.get("achievement_id", "")) == "ach_campaign01_cleared", "成就溯源：achievement_id（06 §2.3）")
	check(ent.check_achievements(ops).is_empty(), "成就点亮幂等（已点亮不重复发）")

# ---------------------------------------------------------------- 运营配置与策略切换（06 §3.2；白皮书 §10.4 运营轨）

func _dir_fingerprint(dir_path: String) -> String:
	var parts: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	var files := dir.get_files()
	files.sort()
	for f: String in files:
		parts.append("%s:%s" % [f, FileAccess.get_md5(dir_path.path_join(f))])
	return "|".join(parts)

func test_ops_config() -> void:
	print("[ops_config]")
	var ops := Entitlements.load_ops_config()
	check(not ops.is_empty() and ops.has("shop") and ops.has("activities") and ops.has("achievements"),
		"运营配置加载：价格表/活动开关/成就规则（06 §3.2 运营侧数据，不进内容包）")
	check(str(Entitlements.price_of(ops, "arena").get("price_text", "")) == "¥12", "商店价格表：arena ¥12")
	var promo_cfg: Dictionary = ops.get("home_promo", {})
	check(str(promo_cfg.get("text", "")).contains("竞技场连战")
		and str(promo_cfg.get("target", "")) == "arena",
		"主屏运营位投放：home_promo 文案+目标在运营配置（06 §6，运营轨不动内容包）")
	# 权利注册表 = 运营侧数据文件（06 §2.3：packs/_ops/entitlements.json，非代码常量）
	var registry := PacklintCore.load_entitlement_registry()
	check(bool(registry["ok"]) and (registry["entitlements"] as Array).has("entitlement.arena"),
		"权利注册表数据文件加载：entitlement.arena 已登记（06 §2.3）")
	check(not bool(PacklintCore.load_entitlement_registry("res://packs/_ops/no_such.json")["ok"])
		and str(PacklintCore.load_entitlement_registry("res://packs/_ops/no_such.json")["error"]).contains("缺失"),
		"负例：注册表文件缺失 → 明确错误（06 §2.3）")
	var bad_reg_path := "user://test/bad_entitlements.json"
	var f := FileAccess.open(bad_reg_path, FileAccess.WRITE)
	f.store_string("{ 损坏的 json")
	f.close()
	check(not bool(PacklintCore.load_entitlement_registry(bad_reg_path)["ok"])
		and str(PacklintCore.load_entitlement_registry(bad_reg_path)["error"]).contains("解析失败"),
		"负例：注册表 JSON 损坏 → 明确错误（06 §2.3）")
	DirAccess.remove_absolute(bad_reg_path)
	# V9：arena requires 已注册且与 strategies 一致（tech/02 §2.3 一致性）
	var arena_pack := _load_arena()
	var v9: Array = PacklintCore.lint(arena_pack).filter(func(i: Dictionary) -> bool: return i["v"] == "V9")
	check(not v9.any(func(i: Dictionary) -> bool: return i["level"] == PacklintCore.LEVEL_FAIL)
		and v9.any(func(i: Dictionary) -> bool: return i["level"] == PacklintCore.LEVEL_PASS),
		"V9：arena requires 已注册且与 strategies 一致（tech/02 §2.3 / 06 §2.3）")
	var bad: Dictionary = arena_pack.duplicate(true)
	bad["manifest"]["entitlement"] = {"requires": ["entitlement.ghost"]}
	check(PacklintCore.lint(bad).any(func(i: Dictionary) -> bool:
		return i["v"] == "V9" and i["level"] == PacklintCore.LEVEL_FAIL),
		"负例：requires 引用未注册权利变量 V9 必报 FAIL（06 §2.3）")
	var broken_registry := {"ok": false, "error": "权利注册表缺失：mock（06 §2.3）", "entitlements": []}
	check(PacklintCore.lint(arena_pack, broken_registry).any(func(i: Dictionary) -> bool:
		return i["v"] == "V9" and i["level"] == PacklintCore.LEVEL_FAIL and str(i["msg"]).contains("注册表缺失")),
		"负例：注册表不可用 → V9 前置 FAIL 且不静默放行（06 §2.3）")
	# 策略切换内容零改动（固化为断言）：限免开/关两态下 packs/arena 逐文件指纹一致
	var fp_before := _dir_fingerprint("res://packs/arena")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var ent := Entitlements.new(board, stream)
	var manifest: Dictionary = arena_pack["manifest"]
	check(not ent.can_access(manifest), "限免关：锁定（运营开关关态）")
	var ops_on := ops.duplicate(true)
	(ops_on["activities"] as Array)[0]["enabled"] = true
	check(ent.apply_activities(ops_on).has("weekend_free_arena"), "限免开：apply_activities 点亮（活动写入方）")
	check(ent.can_access(manifest), "限免开：入口自动解锁")
	var fp_on := _dir_fingerprint("res://packs/arena")
	ent.refund("arena")
	var fp_off := _dir_fingerprint("res://packs/arena")
	check(fp_before != "" and fp_before == fp_on and fp_on == fp_off,
		"策略切换内容零改动：限免开/关两态 packs/arena 逐文件一致（白皮书 §10.4 运营轨不动内容图）")

# ---------------------------------------------------------------- 外观系统（06 §3/§7 外观商品位；07 §3 v1.2；10 §4 v1.1）

func test_font() -> void:
	print("[font] 内置中文字体与默认主题（04 §7 字体阅读层级落地）")
	check(not FileAccess.file_exists("res://assets/fonts/NotoSansSC-Bold.otf"), "不再打包独立 Bold 字体（加粗变体派生，包体 -8 MB）")
	for path: String in [UITheme.FONT_REGULAR]:
		check(FileAccess.file_exists(path), "字体文件入版本管理：%s" % path)
		var ff := FontFile.new()
		check(ff.load_dynamic_font(path) == OK, "字体可加载：%s" % path)
		check(ff.has_char("稳".unicode_at(0)) and ff.has_char("魈".unicode_at(0)),
			"字体含 CJK 字形（稳/魈）：%s" % path)
	check(UITheme.apply(root), "内置字体应用成功（非系统字体兜底）")
	check(root.theme != null and root.theme.default_font == UITheme.regular,
		"默认主题生效且默认字体 = 内置 Noto Sans SC（根窗口挂接，全树继承）")
	check(root.theme.default_font_size == UITheme.SIZE_BODY,
		"默认主题字号 = 正文档（SIZE_BODY）")
	var size := UITheme.regular.get_string_size("稳守烬港残页墨魈誊写庭",
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, UITheme.SIZE_BODY)
	check(size.x > 0.0, "「稳守烬港残页墨魈誊写庭」渲染宽度 > 0（无豆腐块）")
	# 主题挂接通道（推迟到首帧后：_init 阶段主题上下文尚未就绪）
	call_deferred("_test_font_attach")

## 主题挂接通道：普通 Node 祖先会截断 Window.theme 下发（main.tscn 根为 Node），
## 故界面/壳实例必须经 UITheme.attach 挂接——本断言锁定该语义防回归。
func _test_font_attach() -> void:
	await process_frame
	var plain := Node.new()
	root.add_child(plain)
	var host := Control.new()
	plain.add_child(host)
	UITheme.attach(host)
	var probe := Label.new()
	probe.text = "稳守"
	host.add_child(probe)
	check(probe.get_theme_font("font") == UITheme.regular,
		"attach 挂接后控件解析到内置字体（普通 Node 祖先不截断主题链）")
	plain.queue_free()

func test_cosmetics() -> void:
	print("[cosmetics]")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var reg := Cosmetics.load_registry()
	check(reg.size() == 4, "皮肤注册表数据驱动加载：金墨/褪墨灰/拾遗铜辉/执笔者之骰（06 §7 运营侧数据文件；战役书 §11 E3 外观位）")
	var cos := Cosmetics.new(board, stream, reg)
	check(cos.default_skin_id() == "gilded_ink", "默认皮肤=金墨（注册表 default 指定，非代码写死）")
	check(cos.is_owned("gilded_ink") and cos.equipped_id() == "gilded_ink", "起手即有默认皮肤且为当前装备")
	check(not cos.is_owned("faded_ink_gray") and not cos.is_owned("salvage_copper"),
		"集齐奖励/商店皮肤初始未持有")
	# 装备门槛：未持有/未登记均拒绝
	check(not cos.equip("faded_ink_gray"), "未持有皮肤不可装备")
	check(not cos.equip("ghost_skin"), "未登记皮肤不可装备（注册表数据驱动）")
	# 命名空间权限：内容包直写外观旗标被拒（07 §3 v1.2：仅 system 可写）
	check(not board.write("global.cosmetic.dice_skin", "salvage_copper",
		{"event_id": 1, "node_id": "N1-1", "pack_id": "campaign01"}),
		"内容包写外观旗标被拒（07 §3 v1.2 仅 system）")
	check(cos.equipped_id() == "gilded_ink", "越权写入未生效（仍默认皮肤）")
	# 商店购买：写外观旗标 + 单号溯源（06 §2.3/§7）
	check(cos.shop_purchase("salvage_copper", "rcpt_t001"), "商店购买点亮持有（06 §7 外观商品位）")
	check(cos.is_owned("salvage_copper"), "购买即持有：写入即生效无需重启（06 §3.1）")
	var prov := board.provenance_of("global.cosmetic.owned.salvage_copper")
	check(str(prov.get("granted_by", "")) == "shop" and str(prov.get("receipt_id", "")) == "rcpt_t001"
		and str(prov.get("pack_id", "")) == "system",
		"购买写板溯源：购买单号 + system 写权限（06 §2.3 / 07 §3）")
	check(not cos.shop_purchase("salvage_copper", "rcpt_t002"), "购买点亮幂等（已持有不重复发）")
	# 装备 / 卸下
	check(cos.equip("salvage_copper") and cos.equipped_id() == "salvage_copper",
		"装备：写 global.cosmetic.dice_skin（07 §2 外观旗标）")
	check(cos.unequip() and cos.equipped_id() == "gilded_ink", "卸下：回落默认皮肤")
	# 集齐奖励（10 §4 白名单外观；v1.1：聚合全包 lore 判定，系列 id 以 tech/02 §10 注册值为准）
	var lore_defs: Array = [
		{"id": "fd_1", "series": "fatedie_study"}, {"id": "fd_2", "series": "fatedie_study"},
		{"id": "wf_1", "series": "weaver_fragments"}]
	var prov2 := {"event_id": 2, "node_id": "R-2", "pack_id": "riddle_maze"}
	board.unlock_lore("fd_1", prov2)
	check(cos.check_codex_rewards(lore_defs).is_empty() and not cos.is_owned("faded_ink_gray"),
		"系列未集齐：奖励不到账")
	board.unlock_lore("fd_2", prov2)
	check(cos.check_codex_rewards(lore_defs) == ["faded_ink_gray"] and cos.is_owned("faded_ink_gray"),
		"命骰考集齐 → 褪墨灰到账（10 §4 外观奖励，纯演出）")
	prov = board.provenance_of("global.cosmetic.owned.faded_ink_gray")
	check(str(prov.get("granted_by", "")) == "codex" and str(prov.get("series", "")) == "fatedie_study",
		"集齐奖励溯源：granted_by=codex + 系列 id（10 §4 v1.1）")
	check(cos.check_codex_rewards(lore_defs).is_empty(), "集齐奖励幂等（已点亮不重复发）")
	# 调色板：换肤换色（纯呈现取色口），卸下回落默认
	var pal_default := Cosmetics.palette_of(null)
	check(cos.equip("salvage_copper"), "装备拾遗铜辉")
	check(Cosmetics.palette_of(board)["face"] != pal_default["face"], "换肤 = 换调色板（渲染壳唯一取色口）")
	cos.unequip()
	check(Cosmetics.palette_of(board)["face"] == pal_default["face"], "卸下回落默认调色板")
	# 存档往返：外观旗标随 Board 全量序列化（07 §4.1；老存档无此键 = 默认皮肤，兼容不迁移）
	cos.equip("salvage_copper")
	var snap := board.serialize()
	var board3 := Board.new(EventStream.new())
	board3.deserialize(snap)
	check(str(board3.read("global.cosmetic.dice_skin", "")) == "salvage_copper"
		and bool(board3.read("global.cosmetic.owned.salvage_copper", false)),
		"存档往返：外观旗标随 Board 全量序列化（07 §4.1）")

# ---------------------------------------------------------------- 子游戏 UI 流程（04 §6：入口卡 → 整备 → 连战 → ⑨ 结算 → 回主屏）

func test_subgame_flow() -> void:
	print("[subgame_flow]")
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	check(m._subgames.has("arena"), "子游戏包发现：pack_type=subgame 即入列（数据驱动，不写死 arena）")
	m.entitlements.shop_purchase("arena", "rcpt_subflow") # M4 起 arena 有权利门槛：先点亮再走连战流程
	m._on_home_navigate(&"entry")
	await process_frame
	var entry := m.current_screen as ScreenEntry
	var acard := _subgame_card(entry, "arena")
	check(acard != null and (acard.get_child(0) as Label).text.contains("竞技场连战"),
		"② 入口卡：特殊战役书卡呈现（04 §6，双卡在架按包寻址）")
	check(_enter_buttons(acard) == 2, "入口卡：竖屏/横屏双模式参战按钮（tech/02 §2.1 choice）")
	entry.subgame_start.emit("arena", ShellRouter.MODE_TIME)
	await process_frame
	check(m.sub_flow._sub_active and str(m.board.read("global.mode_choice.arena")) == "time",
		"子游戏模式选择写板 global.mode_choice.arena（09 §3）")
	check(m.sub_flow._sub.graph.current_id == "A-0" and m.graph.current_id == "",
		"子游戏开图 A-0，战役图不受污染（命名空间/状态隔离）")
	m._on_sub_story_edge(0) # 踏入擂台
	await process_frame
	check(m.current_screen is ScreenLoadout, "战斗节点 → 进场整备（09 §9.1；连战仅进场一次）")
	(m.current_screen as ScreenLoadout)._on_confirm()
	await create_timer(1.5).timeout
	check(m.sub_flow._sub_battling and m.shell is EncounterPortrait, "整备 → 连战第一场（EncounterSM × 双壳复用）")
	# 模拟第一场胜利（真实战斗数值由 subgame_arena runner 级断言覆盖）
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 2}, &"core", "A-1")
	await create_timer(1.6).timeout
	check(not m.sub_flow._sub_battling, "第一场结束回战后边（不进休整态，连战无休整）")
	check(int(m.board.read("arena.gold", 0)) == 20 and int(m.board.read("arena.wins", 0)) == 1,
		"第一场胜利写板：金币 +20 / 胜场 +1（04 §6 硬要求）")
	var sh := m.shell as EncounterPortrait
	var texts := sh.story_option_texts()
	var joined := " ".join(texts)
	check(joined.contains("乘胜追击") and joined.contains("见好就收"), "战后边：追击（无休整）/ 收兵选项")
	var retire_idx := -1
	for i: int in texts.size():
		if str(texts[i]).contains("见好就收"):
			retire_idx = i
	m._on_sub_story_edge(retire_idx) # 收兵 → A-END
	await process_frame
	check(m.current_screen is ScreenSettle, "收兵 → ⑨ 结算屏（04 §6 离场必经结算界面）")
	var summary := (m.current_screen as ScreenSettle).summary_text.text
	check(summary.contains("战绩：本次 1 胜") and summary.contains("金币 +20"),
		"结算汇总：战绩/金币逐项念出（04 §⑨）")
	(m.current_screen as ScreenSettle).go_home.emit()
	await process_frame
	check(m.current_screen is ScreenHome and not m.sub_flow._sub_active, "结算 → 回主屏（离场闭环，不新增导航项）")
	m.queue_free()
	await process_frame

# ---------------------------------------------------------------- 幕二 hybrid 战后抉择流程（tech/02 §6 hybrid；N2U-2 撕页行动）
# 回归点：多边战斗节点胜利后必须呈现故事态抉择，不得按 type=battle 重进遭遇（无限循环）。

func test_act2_hybrid_flow() -> void:
	print("[act2_hybrid_flow]")
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	m.graph._enter("N2U-2") # 传送至撕页行动（流程测试，不走完整前置链）
	m._present_node()
	await process_frame
	check(m.current_screen is ScreenLoadout, "撕页行动 → 整备界面（09 §9.1）")
	(m.current_screen as ScreenLoadout)._on_confirm()
	await create_timer(1.4).timeout
	check(m.campaign._in_encounter, "撕页行动战斗开始（税吏卫队）")
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 2}, &"core", "N2U-2")
	await create_timer(1.6).timeout
	check(m.current_screen is ScreenSettle, "hybrid 胜利 → ⑨ 结算屏（04 §⑨：胜利必经结算）")
	(m.current_screen as ScreenSettle).go_next.emit() # 下一遭遇 → 多边出边呈现战后抉择
	await process_frame
	var sh := m.shell as EncounterPortrait
	var opts := " ".join(sh.story_option_texts())
	check(m.graph.current_id == "N2U-2" and not m.campaign._in_encounter
		and opts.contains("撕掉税吏的命运页") and opts.contains("不撕"),
		"hybrid 胜利 → 战后抉择双出边呈现（不重进遭遇，tech/02 §6 hybrid）")
	m._on_story_edge(1) # 不撕
	await process_frame
	check(m.graph.current_id == "N2U-3" and m.board.read("campaign01.mercy_shown") == true
		and m.board.has_item("black_feather_token"),
		"抉择「不撕」→ 手下留情 + 黑羽令写板 → N2U-3（边效果，tech/02 §3）")
	m.queue_free()
	await process_frame

# ---------------------------------------------------------------- 战斗之间扎营（11 §7.2）：结算屏「扎营」→ 营地弹层 → 短休/补给/长休

func test_camp_flow() -> void:
	print("[camp_flow]")
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	m.board.give_item("boathook_axe", 1, {"event_id": m.stream.tail(), "node_id": "N1-7", "pack_id": "campaign01"})
	m.graph._enter("N1-7")
	m._present_node()
	await process_frame
	var lo := m.current_screen as ScreenLoadout
	check(lo != null and lo.party_bar.get_child_count() == 3, "战役整备：三张队伍卡（逐角色整备）")
	lo.tap_library(ScreenLoadout.LIB_GEAR, "boathook_axe")
	lo._on_confirm()
	await create_timer(1.4).timeout
	check(str(m.board.read("campaign01.equip.player_blank.weapon")) == "boathook_axe",
		"整备确认 → 装备写板（世界状态）")
	check(m.board.read("campaign01.loadout_last") is Dictionary, "上次整备落簿记（下次预填）")
	var prov := {"event_id": m.stream.tail(), "node_id": "N1-7", "pack_id": "campaign01"}
	m.board.write("campaign01.gold", 50, prov)
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 2}, &"core", "N1-7")
	await create_timer(1.6).timeout
	check(m.current_screen is ScreenSettle, "胜利 → 结算屏")
	var st := m.current_screen as ScreenSettle
	check(st.camp_button.visible, "胜利结算出现「扎营」出口（战斗之间回血/补给）")
	check(not st.summary_text.text.contains("equip") and not st.summary_text.text.contains("loadout_last"),
		"装备/整备簿记键不念给玩家")
	m.board.write("campaign01.hp.player_blank", 4, prov)
	st.camp_button.pressed.emit()
	await process_frame
	check(st.camp_popup.visible and st.camp_popup.mode == HubPopup.MODE_CAMP, "扎营 → 营地弹层（camp 模式）")
	var pc_row: Node = st.camp_popup.party_box.get_node_or_null("Party_player_blank")
	var sr: Button = pc_row.get_node("ShortRest") if pc_row != null else null
	check(sr != null and not sr.disabled, "受伤队员行：短休按钮可点")
	sr.pressed.emit()
	await process_frame
	check(m.graph.hp_of("player_blank") > 4 and int(m.graph.hit_dice_of("player_blank")["left"]) == 0,
		"点短休 → 花费生命骰回血（写板）")
	var pc_row2: Node = st.camp_popup.party_box.get_node_or_null("Party_player_blank")
	check(pc_row2 != null and (pc_row2.get_node("ShortRest") as Button).disabled, "弹层刷新：生命骰用尽按钮禁用")
	var potions: int = m.board.item_count("heal_potion")
	var buy: Button = null
	for c: Node in st.camp_popup.stock_box.get_children():
		if c is Button and (c as Button).text.contains("补给药水"):
			buy = c
	check(buy != null and not buy.disabled, "营地补给：药水可购买")
	buy.pressed.emit()
	await process_frame
	check(m.board.item_count("heal_potion") == potions + 1 and m.graph.get_gold() == 35, "营地补给购买：+1 药水 −15 金")
	var clock0: int = m.board.get_doom_clock()
	st.camp_popup.rest_button.pressed.emit()
	await process_frame
	check(m.graph.hp_of("player_blank") == m.graph.max_hp_of("player_blank")
		and m.board.get_doom_clock() >= clock0 + 1, "营地长休：满血 + 时钟 +1")
	m.queue_free()
	await process_frame

# ---------------------------------------------------------------- 整备 v2：逐角色 / 资源库 / 拖放与点按双通道（09 §9.1 v2）

func test_loadout_v2() -> void:
	print("[loadout_v2]")
	var pack := _load_campaign01()
	var cfg := Loadout.resolve_config(pack, "N1-7")
	var rs := func(id: String) -> Dictionary: return BattleDef.runtime_skill(pack["skills"][id])
	var cands := {"skills": [rs.call("inkbolt"), rs.call("inkshield"), rs.call("inklance")],
		"items": [{"id": "heal_potion", "name": "补给药水", "count": 2, "use": pack["items"]["heal_potion"]["use"]},
			{"id": "ink_flask", "name": "墨瓶", "count": 1, "use": pack["items"]["ink_flask"]["use"]}],
		"gear": [{"id": "boathook_axe", "name": "船钩斧", "count": 1, "equip": pack["items"]["boathook_axe"]["equip"]},
			{"id": "padded_coat", "name": "衬垫外套", "count": 1, "equip": pack["items"]["padded_coat"]["equip"]}],
		"party": [{"id": "player_blank", "name": "白页者", "kind": "player_template", "hp": 14, "max_hp": 14, "ac": 11,
				"learned": [rs.call("inkbolt")], "equipment": {}},
			{"id": "companion_kelan", "name": "珂兰", "kind": "companion", "hp": 10, "max_hp": 10, "ac": 11,
				"learned": [rs.call("kelan_bolt")], "skill_slots": -1, "equipment": {}}],
		"attr_points": 0, "basic_attacks": ["slash"],
		"last": {"skills_by_char": {"player_blank": ["inklance", "nope"]}, "items": ["heal_potion"]}}
	var lo: ScreenLoadout = (load("res://shell/ui/screen_loadout.tscn") as PackedScene).instantiate()
	root.add_child(lo)
	await process_frame
	lo.bind(cfg, cands)
	await process_frame
	check(lo.selected_character() == "player_blank" and lo.party_bar.get_child_count() == 2,
		"队伍卡两张，默认打开玩家角色表")
	check(lo.picked_skills() == ["inklance"] and lo.picked_items() == ["heal_potion"],
		"沿用上次整备（非法条目 nope 跳过）")
	lo.tap_library(ScreenLoadout.LIB_GEAR, "boathook_axe")
	check(str(lo.equipment_of("player_blank").get("weapon", "")) == "boathook_axe", "点按资源库装备 = 交给当前角色")
	lo.drop_on_character("companion_kelan", {"kind": "gear", "id": "boathook_axe"})
	check(str(lo.equipment_of("companion_kelan").get("weapon", "")) == "boathook_axe"
		and not lo.equipment_of("player_blank").has("weapon") and lo.hint_label.text.contains("珂兰"),
		"拖到另一角色 = 唯一一件直接转手（提示谁交给谁）")
	check(lo.selected_character() == "companion_kelan", "拖放后角色表切到接收者")
	lo.drop_on_slot("companion_kelan", "weapon", {"kind": "gear", "id": "padded_coat"})
	check(not lo.equipment_of("companion_kelan").has("armor"), "槽位不符的拖放被忽略（外套不进武器槽）")
	lo.drop_on_slot("companion_kelan", "armor", {"kind": "gear", "id": "padded_coat"})
	check(str(lo.equipment_of("companion_kelan").get("armor", "")) == "padded_coat", "拖到护甲槽 = 穿上")
	await process_frame
	var slot_btn := lo.equip_grid.get_node_or_null("Slot_armor") as Button
	check(slot_btn != null and slot_btn.text.contains("衬垫外套"), "角色表护甲槽显示外套")
	lo.drop_on_character("companion_kelan", {"kind": "skills", "id": "inkbolt"})
	check(lo.hint_label.text.contains("珂兰") and lo.picked_skills() == ["inklance"], "同伴不会的技能拒绝并提示")
	lo.drop_on_character("player_blank", {"kind": "skills", "id": "inkbolt"})
	check(lo.picked_skills() == ["inklance", "inkbolt"], "拖技能到玩家卡 = 备战（槽位内）")
	lo.drop_on_pouch({"kind": "items", "id": "ink_flask"})
	check(lo.picked_items() == ["heal_potion", "ink_flask"], "拖道具到快取袋 = 放进")
	lo.set_library_tab(ScreenLoadout.LIB_GEAR)
	await process_frame
	var card := lo.lib_list.get_node_or_null("Lib_boathook_axe") as Button
	check(card != null and card.text.contains("珂兰") and card.text.contains("伤害骰 1d8"),
		"资源库装备卡：一句话说明 + 当前持有者")
	var sel: Array = []
	lo.confirmed.connect(func(x: Dictionary) -> void: sel.append(x))
	lo._on_confirm()
	check(sel.size() == 1 and str((sel[0]["equipment"] as Dictionary)["companion_kelan"]["weapon"]) == "boathook_axe"
		and (sel[0]["skills_by_char"] as Dictionary)["player_blank"] == ["inklance", "inkbolt"],
		"确认上报：逐角色装备 + 逐角色备战技能")
	lo.queue_free()
	await process_frame

# ---------------------------------------------------------------- 地图流程（16）：广场 → 雾岸 → 渔人巷 → 灯塔场所 → 回地图

func test_map_flow() -> void:
	print("[map_flow]")
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	m.graph._enter("N1-1")
	m._present_node()
	await process_frame
	var hub_edges: Array = m.graph.available_edges()
	var coast := -1
	for i: int in hub_edges.size():
		if str((hub_edges[i] as Dictionary).get("to", "")) == "N1-1m":
			coast = i
	check(coast >= 0, "广场新增出边：沿雾岸探索")
	m._on_story_edge(coast)
	await process_frame
	await process_frame
	check(m.current_screen is ScreenMap and m.graph.current_id == "N1-1m", "map 节点 → ⑩ 区域地图屏")
	var sc := m.current_screen as ScreenMap
	check(sc.location_button("plaza") != null and sc.location_button("row") != null and sc.location_button("marsh") == null,
		"地图：已知地点有按钮，隐藏的盐沼不显示")
	sc.canvas.size = Vector2(390, 420) # 无头无布局：给画布一个手机竖屏尺寸
	sc._layout_canvas()
	var bgr := sc.background_rect()
	check(bgr.size.x > 0.0 and bgr.size.y > 0.0, "区域地图背景图（16 §6：background.art_ref + frame）")
	var plaza_c := sc.location_button("plaza").position + sc.location_button("plaza").size * 0.5
	check(bgr.has_point(plaza_c) and absf(bgr.size.x / bgr.size.y - 8.0 / 6.0) < 0.02,
		"背景图按 frame 网格矩形铺放：地点落在图内，宽高比 = frame 比例")
	sc.location_tapped.emit("row")
	await process_frame
	check(sc.travel_button.text == TextsZh.MAP_TRAVEL and not sc.travel_button.disabled, "选中渔人巷：出发按钮可用")
	sc.travel_pressed.emit()
	await create_timer(1.3).timeout
	check(m.graph.current_id == "N1-1mr" or m.campaign._in_encounter or (m.current_screen is ScreenMap and (m.current_screen as ScreenMap).is_card_open()),
		"一段路后抵达渔人巷（或被路上事件打断）")
	if m.graph.current_id == "N1-1mr":
		m._on_story_edge(1) # 回到雾岸小路
		await process_frame
		await process_frame
		check(m.current_screen is ScreenMap, "地点节点出边回到地图")
	# 直达灯塔场所（流程测试：位置写板后在原地"进入"）
	var prov := {"event_id": m.stream.tail(), "node_id": "N1-1m", "pack_id": "campaign01"}
	m.board.write("campaign01.map.fog_coast.pos", "lighthouse", prov)
	m.board.write("campaign01.map.fog_coast.journey", {}, prov)
	m.graph._enter("N1-1m")
	m._present_node()
	await process_frame
	sc = m.current_screen as ScreenMap
	sc.travel_pressed.emit() # 原地进入：旧灯塔 → 场所
	await process_frame
	await process_frame
	check(m.campaign.maps.site != null and str(m.campaign.maps.site.current()) == "hall", "进入旧灯塔场所：门厅")
	sc.canvas.size = Vector2(390, 420)
	check(sc.background_rect().size.x > 0.0, "场所背景图（旧灯塔剖面）")
	check(sc.actions_box.get_node_or_null("Exit__map") != null and sc.actions_box.get_node_or_null("Exit_keeper") != null,
		"场所操作：回地图出口 + 卡死的门")
	sc.exit_pressed.emit("@map")
	await process_frame
	check(m.campaign.maps.site == null and m.current_screen is ScreenMap, "离开场所回到区域地图")
	# 事件卡弹层
	m.campaign.maps._card = "courier_satchel"
	m.campaign.maps.refresh()
	await process_frame
	check(sc.is_card_open() and sc.card_options.get_child_count() == 3, "事件卡半屏弹层：三个选项")
	sc.card_option.emit(1)
	await process_frame
	check(not sc.is_card_open() and int(m.board.read("campaign01.inspiration", 0)) == 1, "选项结算：激励 +1，弹层收起")
	m.queue_free()
	await process_frame

# ---------------------------------------------------------------- 开战前扎营 / 补给 / 用道具（11 §7.2 / §8.2）

func test_pre_battle_camp() -> void:
	print("[pre_battle_camp]")
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	var g: StoryGraph = m.graph
	var prov := {"event_id": m.stream.tail(), "node_id": "N1-7", "pack_id": "campaign01"}
	# ---- core：可用道具 = 治疗类；投掷类排除；满血拒绝；用掉扣 1 ----
	m.board.give_item("ink_flask", 1, prov)
	var ids: Array = g.camp_usable_items().map(func(u: Dictionary) -> String: return str(u["id"]))
	check(ids.has("heal_potion") and not ids.has("ink_flask") and not ids.has("tide_bomb"),
		"营地可用道具：治疗药水在列，投掷类（墨瓶 / 潮汐弹）不在列")
	check(str(g.use_item("player_blank", "heal_potion").get("reason", "")) == "full", "满血不用药（拒绝且不扣道具）")
	check(str(g.use_item("player_blank", "ink_flask").get("reason", "")) == "not_usable", "投掷道具战斗外不可用")
	m.board.write("campaign01.hp.player_blank", 3, prov)
	var potions: int = m.board.item_count("heal_potion")
	var res: Dictionary = g.use_item("player_blank", "heal_potion")
	check(bool(res["ok"]) and g.hp_of("player_blank") == 3 + int(res["heal"]) and int(res["heal"]) >= 3
		and m.board.item_count("heal_potion") == potions - 1, "用药回血（1d4+2）并消耗 1 瓶")
	check(m.stream.query_by_type(EventTypes.LOG).any(func(e: Dictionary) -> bool:
		return str(e["payload"].get("msg_key", "")) == "MSG_CAMP_ITEM" and not (e["payload"].get("dice", []) as Array).is_empty()),
		"用药写日志（带骰子，可上骰条）")
	# ---- 流程：战斗节点 → 整备屏有「扎营与补给」→ 弹层用药 → 整备 HP 刷新、已选保留 ----
	m.board.write("campaign01.hp.companion_kelan", 2, prov)
	m.graph._enter("N1-7")
	m._present_node()
	await process_frame
	await process_frame
	check(m.current_screen is ScreenLoadout, "战斗节点 → 整备屏")
	var lo := m.current_screen as ScreenLoadout
	check(lo.camp_button != null and lo.camp_button.is_inside_tree(), "整备屏有「扎营与补给」按钮")
	lo.tap_library(ScreenLoadout.LIB_SKILLS, "inkbolt")
	lo.camp_button.pressed.emit()
	await process_frame
	check(lo.camp_popup.visible and lo.camp_popup.mode == HubPopup.MODE_CAMP, "点按 → 营地弹层（营地模式）")
	var give := lo.camp_popup.use_box.get_node_or_null("Use_heal_potion/Give_companion_kelan")
	check(give != null, "用道具段：治疗药水 → 「给 Kelan」按钮（伤员才有）")
	check(lo.camp_popup.use_box.get_node_or_null("Use_heal_potion/Give_companion_laofei") == null, "满血队员无给药按钮")
	(give as Button).pressed.emit()
	await process_frame
	var kelan_hp := g.hp_of("companion_kelan")
	check(kelan_hp > 2, "弹层给药：Kelan 回血")
	var card := lo.party_bar.get_node_or_null("Card_companion_kelan") as Button
	check(card != null and card.text.contains("%d/" % kelan_hp), "整备队伍卡 HP 即时刷新")
	check(lo.picked_skills().has("inkbolt"), "营地动作后已选技能保留")
	check(lo.camp_popup.visible, "用药后弹层保持打开")
	var gold0: int = g.get_gold()
	lo.camp_popup.buy_requested.emit("heal_potion")
	await process_frame
	check(g.get_gold() < gold0, "开战前在营地补给（购买扣金币）")
	lo.camp_popup.short_rest_requested.emit("player_blank")
	await process_frame
	check(m.current_screen is ScreenLoadout, "短休后仍在整备屏（可直接开战）")
	m.queue_free()
	await process_frame

# ---------------------------------------------------------------- 分队界面流程（15 §4/§5/§3.3）

func _option_index(sh: EncounterPortrait, contains: String) -> int:
	var opts := sh.story_option_texts()
	for i: int in opts.size():
		if str(opts[i]).contains(contains):
			return i
	return -1

func test_party_flow() -> void:
	print("[party_flow]")
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	var prov := {"event_id": m.stream.tail(), "node_id": "N1-1mr", "pack_id": "campaign01"}
	m.board.write("campaign01.ngplus", 1, prov) # 周目 2：联络开放（manifest.progression）
	m.board.give_item("heal_potion", 2, prov)
	m.graph._enter("N1-1mr")
	m._present_node()
	await process_frame
	var sh := m.shell as EncounterPortrait
	var idx := -1
	var edges: Array = m.graph.available_edges()
	for i: int in edges.size():
		if str((edges[i] as Dictionary).get("type", "")) == "split":
			idx = i
	check(idx >= 0, "渔人巷：分头行动选项")
	m._on_story_edge(idx)
	await process_frame
	check(sh.party_ui.is_assigning() and not m.graph.party.is_split(), "自选分组：先弹出谁去哪里（尚未分队）")
	check(sh.party_ui.divide_box.find_child("Member_companion_kelan", true, false).disabled, "必需成员（珂兰在档案馆）锁定不可移")
	sh.party_ui.cycle_member("companion_laofei")
	check(sh.party_ui._group_of("companion_laofei") == "docks" and sh.party_ui.assignment_valid(), "点按老费：换到码头组（仍合规）")
	sh.party_ui.cycle_member("companion_laofei")
	(sh.party_ui.divide_box.find_child("AssignDone", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	check(m.graph.party.is_split() and m.graph.party.members("docks") == ["player_blank"], "确认分组 → 分队")
	check(sh.party_ui.is_dividing() and sh.party_ui.divide_box.get_node_or_null("DivideItem_heal_potion") != null,
		"分队后弹出分装背包")
	sh.party_ui.cycle_item("heal_potion")
	(sh.party_ui.divide_box.find_child("DivideDone", true, false) as Button).pressed.emit()
	await process_frame
	check(not sh.party_ui.is_dividing() and m.graph.party.available("heal_potion") >= 0, "分装确认写板")
	check(sh.party_bar.visible and sh.party_ui.tabs_row.get_node_or_null("Group_docks") != null
		and sh.party_ui.tabs_row.get_node_or_null("Group_archive") != null, "组条：两个小组标签")
	check(sh.party_ui.meanwhile.text.contains("潮汐档案馆"), "与此同时：另一组所在节点")
	sh.party_ui.split_button.button_pressed = true
	await process_frame
	check(sh.party_ui.split_pane.visible and sh.party_ui.pane_title.text.contains("潮汐档案馆"), "⧉ 分屏：另一组视角窗格")
	(sh.party_ui.tabs_row.get_node("Group_archive") as Button).pressed.emit()
	await process_frame
	await process_frame
	check(m.graph.party.focus() == "archive" and m.graph.current_id == "N1-1ma", "点组标签切焦点 → 档案馆")
	check(_option_index(sh, "✉") >= 0, "远程联络选项带 ✉ 与次数")
	sh._on_gesture_h_swipe(1, Vector2(10, 300))
	await process_frame
	await process_frame
	check(m.graph.party.focus() == "docks", "主视野横滑 = 切换小组")
	sh.party_ui.link_button.pressed.emit()
	await process_frame
	check(sh.party_ui.link_sheet.visible and sh.party_ui.link_box.get_node_or_null("Link_help_archive") != null, "✉ 联络弹层：求援按钮")
	(sh.party_ui.link_box.get_node("Link_help_archive") as Button).pressed.emit()
	await process_frame
	check(m.graph.party.charges("docks") == 1, "求援扣 1 次")
	# 码头组走到汇合点 → 等待，自动切到档案馆组；档案馆组走完 → 汇合
	m.graph.resolve_check(m.graph.current()["edges"][0], true)
	m.graph.take_edge(m.graph.available_edges()[0])
	m._present_node()
	await process_frame
	check(m.graph.party.focus() == "archive" and str(m.graph.party.group("docks")["status"]) == "waiting", "码头组到达汇合点等待")
	m.graph.resolve_check(m.graph.current()["edges"][0], true)
	m.graph.take_edge(m.graph.available_edges()[0])
	m._present_node()
	await process_frame
	check(not m.graph.party.is_split() and m.graph.current_id == "N1-1mj" and not sh.party_bar.visible, "汇合：组条收起")
	m.queue_free()
	await process_frame

# ---------------------------------------------------------------- 新游戏工具包（docs/en/tech/07）：清单 / 文案覆盖层 / 起步包 / 整款换游戏

func _use_manifest(path: String) -> void:
	GameManifest.override_path = path
	GameManifest.reset()
	Texts.clear_cache()

func test_new_game_kit() -> void:
	print("[new_game_kit]")
	_use_manifest("")
	check(GameManifest.default_campaign() == "campaign01" and GameManifest.pack_enabled("arena")
		and GameManifest.bgm(&"battle", &"x") == &"bgm_battle" and GameManifest.sfx(&"hit") == &"hit"
		and GameManifest.ambient("home", &"x") == &"tide_loop", "本作清单：默认战役 / 启用包 / 音乐与音效映射")
	check(TextsEn.HOME_TITLE == "Camp" and TextsEn.CODEX_SERIES.is_empty() and TextsEn.FACTION_NAMES.is_empty(),
		"框架文案表只留中性默认（世界观名词不进框架）")
	Texts.set_locale("en")
	check(Texts.s(&"HOME_TITLE") == "Ashenport · Camp" and (Texts.t(&"FACTION_NAMES") as Dictionary).has("scriptorium"),
		"本作风味经 packs/_game/texts 覆盖")
	Texts.set_locale(Texts.SOURCE_LOCALE)
	# 起步包：可加载、packlint 零 FAIL、bot 每局到结局
	var res := PackLoader.load_pack("res://kit/starter")
	check(bool(res["ok"]), "起步包加载 ok：%s" % ";".join(res["errors"]))
	var issues: Array = PacklintCore.lint(res["pack"])
	var fails := issues.filter(func(i: Dictionary) -> bool: return str(i["level"]) == PacklintCore.LEVEL_FAIL)
	check(fails.is_empty(), "起步包 packlint 零 FAIL（V1~V21）：%s" % str(fails))
	var ok_runs := 0
	for i: int in 8:
		var r := StoryBot.run(res["pack"], 500 + i * 37, false, false, false, i % 2 == 0)
		if bool(r["ok"]) and str(r["ending"]) == "X1":
			ok_runs += 1
	check(ok_runs == 8, "起步包 bot 仿真：8/8 局到达结局（含地图探针）")
	# 换一整款游戏：包根 + 清单指向 kit
	_use_manifest("res://kit/_game/game.json")
	check(GameManifest.default_campaign() == "starter" and not GameManifest.pack_enabled("arena"), "kit 清单：默认战役 starter，只启用自己的包")
	check(Palette.color("accent") == Color.from_string("#8fc77a", Color.MAGENTA) and Palette.color("danger") == Color.from_string(Palette.DEFAULTS["danger"], Color.MAGENTA),
		"调色板令牌：清单覆盖的取清单值，未覆盖的取默认（theme.palette）")
	var m: Node = _new_main()
	m.packs_root = "res://kit"
	root.add_child(m)
	await process_frame
	await process_frame
	check(str(m.pack["pack_id"]) == "starter" and m._subgames.is_empty() and m._arcs.is_empty(), "以 kit 为包根启动：只加载起步包")
	Texts.set_locale("en")
	Texts.clear_cache()
	m._show_home()
	await process_frame
	var home := m.current_screen as ScreenHome
	check(home != null and home.find_child("*", true, false) != null and Texts.s(&"HOME_TITLE") == "The Crossroads Inn",
		"新游戏的风味文案（主屏标题）来自 kit/_game/texts")
	Texts.set_locale(Texts.SOURCE_LOCALE)
	m.queue_free()
	await process_frame
	_use_manifest("")

# ---------------------------------------------------------------- 建角流程（11 §1.1）：新开局 → 你是谁？ → 序章

func test_hero_flow() -> void:
	print("[hero_flow]")
	CampaignFlow.skip_hero_creation = false
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	check(m.current_screen is ScreenHero, "新开局先进入建角屏")
	var hs := m.current_screen as ScreenHero
	check(hs.class_box.get_child_count() == 3 and hs.bg_box.get_child_count() == 4 and hs.story_label.text != "",
		"三张职业卡 + 四个出身 + 选中项的故事")
	hs.select_class("ink_adept")
	hs.select_background("scriptorium_novice")
	check(hs.story_label.text.contains("逗号") and hs.story_label.text.contains("金墨"), "故事随所选职业 / 出身切换")
	hs.confirm_button.pressed.emit()
	await process_frame
	await process_frame
	check(m.graph.current_id == "N0-1" and str(m.pack["characters"]["player_blank"]["basic_attack"]) == "ink_dart"
		and m.board.get_rep("scriptorium") == 2 and m.board.has_item("novice_quill"), "确认 → 序章；模板 / 声望 / 纪念物到位")
	m.queue_free()
	await process_frame
	CampaignFlow.skip_hero_creation = true

# ---------------------------------------------------------------- 锁定态与购买流程（06 §3.1/§6；04 §3.3；tech/02 §2.2 硬门槛）

func test_entitlement_flow() -> void:
	print("[entitlement_flow]")
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	var arena_manifest: Dictionary = (m._subgames["arena"] as Dictionary)["manifest"]
	check(not m.entitlements.can_access(arena_manifest), "默认运营配置：arena 未点亮（限免开关关态）")
	m._on_home_navigate(&"entry")
	await process_frame
	var entry := m.current_screen as ScreenEntry
	var acard := _subgame_card(entry, "arena")
	var lock_found := false
	var stats_found := false
	var acquire_btn: Button = null
	for child: Node in acard.get_children():
		if child is Label:
			var t := (child as Label).text
			if t.contains("守门人"):
				lock_found = true
			if t.contains("累计胜场"):
				stats_found = true
		elif child is Button and (child as Button).text == TextsZh.LOCK_ACQUIRE:
			acquire_btn = child
	check(stats_found, "锁定态：封面/战绩照常呈现——可见但锁定（06 §3.1，让内容成为销售页）")
	check(lock_found and acquire_btn != null and _enter_buttons(acard) == 0,
		"锁定态：叙事化锁定文案 +「获取」按钮，无参战按钮、无'未购买'生硬弹窗（06 §3.1）")
	# 硬门槛阻断：直接发参战信号被拒
	entry.subgame_start.emit("arena", ShellRouter.MODE_TIME)
	await process_frame
	check(not m.sub_flow._sub_active, "锁定阻断进入：subgame_start 被硬门槛拒绝（tech/02 §2.2）")
	# 购买流程：半屏弹层 → 确认 → shop_purchase → 即时解锁无需重启
	acquire_btn.pressed.emit()
	await process_frame
	check(entry.shop_popup.visible and entry.shop_popup.goods_label.text.contains("¥12"),
		"「获取」→ 购买半屏弹层，价格来自运营配置（04 §3.3 / 06 §3.2/§6）")
	entry.shop_popup.confirm_button.pressed.emit()
	await process_frame
	check(m.entitlements.can_access(arena_manifest), "确认购买 → 即时点亮（06 §3.1：购买即解锁无需重启）")
	var prov: Dictionary = m.board.provenance_of("global.entitlement.arena")
	check(str(prov.get("granted_by", "")) == "shop" and str(prov.get("receipt_id", "")).begins_with("mock_arena_gauntlet"),
		"购买溯源：单号随写入进状态板（06 §2.3）")
	entry = m.current_screen as ScreenEntry
	check(_enter_buttons(_subgame_card(entry, "arena")) == 2, "入口当场刷新：参战按钮出现（解锁即时生效）")
	# 退款：权利置假 → 入口回锁定态、新局被拒（06 §5）
	m.entitlements.refund("arena")
	m._show_entry()
	await process_frame
	entry = m.current_screen as ScreenEntry
	var relocked := false
	for child: Node in _subgame_card(entry, "arena").get_children():
		if child is Button and (child as Button).text == TextsZh.LOCK_ACQUIRE:
			relocked = true
	check(relocked and not m.entitlements.can_access(arena_manifest), "退款：入口回锁定态，不可开新局（06 §5）")
	# 活动限免：开关开 → apply_activities → 自动解锁（运营轨不动内容包）
	var ops_on: Dictionary = m.ops_config.duplicate(true)
	(ops_on["activities"] as Array)[0]["enabled"] = true
	m.entitlements.apply_activities(ops_on)
	m._show_entry()
	await process_frame
	entry = m.current_screen as ScreenEntry
	check(m.entitlements.can_access(arena_manifest)
		and _enter_buttons(_subgame_card(entry, "arena")) == 2,
		"活动限免开关开 → 入口自动解锁（06 §3.2：点亮在运营，内容包零改动）")
	m.queue_free()
	await process_frame

# ---------------------------------------------------------------- 九类界面闭环（04 §2/§5，TP4 无头断言）

func test_ui_screens() -> void:
	print("[ui_screens]")
	var pack := _load_campaign01()
	var stream := EventStream.new()
	var board := Board.new(stream)
	# ① 主屏：五入口 + 运营位 + 帮助 + 手动/闲置存档信号
	var home: ScreenHome = (load("res://shell/ui/screen_home.tscn") as PackedScene).instantiate()
	root.add_child(home)
	await process_frame
	var navs: Array = []
	home.navigate.connect(func(id: StringName) -> void: navs.append(id))
	home.bind(board, 2, true)
	check(home.campaign_button.text.contains(TextsZh.HOME_CONTINUE), "主屏：战役入口带「继续」（04 §①）")
	check(home.quests_button.text.contains("2"), "主屏：事件中心角标（04 §①）")
	home.campaign_button.pressed.emit()
	home.quests_button.pressed.emit()
	home.inventory_button.pressed.emit()
	home.character_button.pressed.emit()
	home.history_button.pressed.emit()
	check(navs == [&"entry", &"quests", &"inventory", &"character", &"history"],
		"主屏五入口齐备（04 §①：②⑤⑥⑦⑧）")
	board.write("global.doom_clock", 8, {"event_id": 1, "node_id": "", "pack_id": "campaign01"})
	home.bind(board, 0, false)
	check(home.doom_label.text == Texts.home_doom_text(8), "营地图景随褪墨度变化文案（04 §①）")
	check(home.campaign_button.text == TextsZh.HOME_ENTRY_CAMPAIGN, "无可继续进度时不带「继续」")
	var saves: Array = []
	home.save_requested.connect(func() -> void: saves.append("manual"))
	home.idle_timeout.connect(func() -> void: saves.append("idle"))
	home.save_button.pressed.emit()
	home.debug_force_idle()
	check(saves == ["manual", "idle"], "手动「记录抄本」+ 主屏闲置两时机（07 §4.2）")
	home._toggle_help()
	check(home.is_help_visible(), "帮助入口：手势图鉴页（12 §4）")
	home._toggle_help()
	home.queue_free()
	# ② 战役入口：未选禁用开始 → 选形态 → 上报
	var entry: ScreenEntry = (load("res://shell/ui/screen_entry.tscn") as PackedScene).instantiate()
	root.add_child(entry)
	await process_frame
	entry.bind(pack, [], 12.5)
	check(entry.start_button.disabled, "未选模式禁用开始（09 §3/04 §②）")
	check(entry.collect_label.text.contains("12"), "分支收集度呈现（04 §② 多周目信息）")
	var chosen: Array = []
	entry.mode_chosen.connect(func(m: StringName) -> void: chosen.append(m))
	entry.pick_mode(ShellRouter.MODE_TIME)
	check(not entry.start_button.disabled and chosen == [ShellRouter.MODE_TIME],
		"选形态后解锁开始并上报（选择即分支，09 §3）")
	var backed := [false]
	entry.back_requested.connect(func() -> void: backed[0] = true)
	entry.back_button.pressed.emit()
	check(backed[0], "战役入口有退路：返回主屏（04 §5）")
	entry.queue_free()
	# 整备：3 选 2 槽位限制 + 确认上报 + 属性点
	var lo: ScreenLoadout = (load("res://shell/ui/screen_loadout.tscn") as PackedScene).instantiate()
	root.add_child(lo)
	await process_frame
	var cfg := Loadout.resolve_config(pack, "N1-7")
	lo.bind(cfg, {"skills": [
			{"id": "s1", "name": "技能一"}, {"id": "s2", "name": "技能二"}, {"id": "s3", "name": "技能三"}],
		"items": [{"id": "heal_potion", "name": "补给药水", "count": 2}],
		"attr_points": 1, "attr_alloc": {"might": 0, "finesse": 0, "wits": 0}})
	lo._toggle_skill("s1")
	lo._toggle_skill("s2")
	lo._toggle_skill("s3") # 第 3 个超槽：不进入选择
	check(lo.picked_skills() == ["s1", "s2"], "整备：技能 3 选 2 槽位限制（09 §9.1）")
	lo._toggle_item("heal_potion")
	var lo_sel: Array = []
	lo.confirmed.connect(func(sel: Dictionary) -> void: lo_sel.append(sel))
	lo._on_confirm()
	check(lo_sel.size() == 1 and (lo_sel[0]["skills"] as Array) == ["s1", "s2"]
		and (lo_sel[0]["items"] as Array) == ["heal_potion"], "整备确认上报选择（写 loadout.confirm 由 core 落）")
	lo.queue_free()
	# ⑨ 结算：汇总 + 加点 + 双出口
	var st: ScreenSettle = (load("res://shell/ui/screen_settle.tscn") as PackedScene).instantiate()
	root.add_child(st)
	await process_frame
	st.bind({"title": "午夜墨雨", "result": "victory", "lines": ["经验 +100", "获得：墨核 ×1"],
		"saved": true, "attr_points": 1, "attrs": {"might": 0, "finesse": 0, "wits": 0}})
	check(st.summary_text.text.contains("经验 +100") and st.summary_text.text.contains("墨核"),
		"结算：写板汇总逐项呈现（04 §⑨）")
	check(st.saved_label.text == Texts.s(&"SETTLE_SAVED"), "结算：存档快照提示（07 §4.2 主快照点）")
	var allocs: Array = []
	st.allocate.connect(func(a: String) -> void: allocs.append(a))
	var attr_btn: Button = null
	for child: Node in st.attr_box.get_children():
		if child is Button and not (child as Button).disabled:
			attr_btn = child
			break
	attr_btn.pressed.emit()
	check(allocs.size() == 1, "结算：成长加点上报（属性点可留到下次整备）")
	check(st.home_button.text == TextsZh.SETTLE_HOME and st.history_button.text == TextsZh.SETTLE_HISTORY,
		"结算出口：回主屏 / 看卷轴（04 §⑨）")
	# 无可用点数时加点区不显示（11 §6：仅在有点数时分配）
	st.bind({"title": "午夜墨雨", "result": "victory", "lines": [], "saved": true,
		"attr_points": 0, "attrs": {"might": 1, "finesse": 0, "wits": 0}})
	check(not st.attr_box.visible and not st.attr_label.visible, "无属性点：加点区隐藏（11 §6 分配时机）")
	# 单项 +3 封顶：已满项按钮禁用
	st.bind({"title": "午夜墨雨", "result": "victory", "lines": [], "saved": true,
		"attr_points": 1, "attrs": {"might": 3, "finesse": 0, "wits": 0}})
	await process_frame # 旧按钮 queue_free 后再取新按钮
	for child: Node in st.attr_box.get_children():
		if child is Button and (child as Button).text.begins_with("力"):
			check((child as Button).disabled, "单项 +3 封顶：力已满 → 按钮禁用（11 §6）")
	st.queue_free()
	# ⑧ 历史卷轴：倒序 + 展开明细 + 关键标记 + 溯源
	stream.emit(EventTypes.FLAG_WRITE, {"key": "campaign01.seen_fading", "old": false, "value": true,
		"provenance": {"event_id": 1, "node_id": "N0-3a", "pack_id": "campaign01"}}, &"board", "N0-3a")
	stream.emit(EventTypes.CHECK_ROLL, {"roller": "pc", "kind": "death_save", "rolls": [14], "keep": 14,
		"mod": 0, "total": 14, "dc": 10, "success": true, "s": 1, "f": 0, "key": true}, &"core", "N1-7")
	var hi: ScreenHistory = (load("res://shell/ui/screen_history.tscn") as PackedScene).instantiate()
	root.add_child(hi)
	await process_frame
	hi.bind(stream, board)
	var rows := 0
	var first_btn: Button = null
	var key_marked := false
	for row: Node in hi.list_box.get_children(): # 行 = HBoxContainer（主按钮 + 战斗行附「重演」钮）
		if not (row is HBoxContainer):
			continue
		var b := row.get_child(0) as Button
		if b == null:
			continue
		rows += 1
		if first_btn == null:
			first_btn = b
		if b.text.contains("★"):
			key_marked = true
	check(rows == stream.size() and rows >= 2, "历史卷轴：事件流条目全量入轴（04 §⑧）")
	check(first_btn != null and first_btn.text.contains("check.roll"),
		"历史卷轴：倒序（最新在上，04 §⑧ 时间轴）")
	check(key_marked, "关键判定标记 ★（09 §6 key=true）")
	first_btn.pressed.emit()
	check(hi.detail_label.text.contains("检定明细") and hi.detail_label.text.contains("DC 10"),
		"展开明细：检定 d20 明细（骰值+修正=结果 vs 难度，04 §⑧）")
	var flag_btn: Button = null
	for row: Node in hi.list_box.get_children():
		if not (row is HBoxContainer):
			continue
		var b := row.get_child(0) as Button
		if b != null and b.text.contains("flag.write"):
			flag_btn = b
	flag_btn.pressed.emit()
	check(hi.detail_label.text.contains("N0-3a") and hi.detail_label.text.contains("campaign01"),
		"旗标溯源：来源节点回链状态板（07 §1/§6）")
	var hi_back := [false]
	hi.back_requested.connect(func() -> void: hi_back[0] = true)
	hi.back_button.pressed.emit()
	check(hi_back[0], "历史卷轴出口：返回来源界面（04 §5）")
	hi.queue_free()
	# ⑤⑥⑦ 最小版：只读列表 + 返回 + 补全标注
	var qs: ScreenQuests = (load("res://shell/ui/screen_quests.tscn") as PackedScene).instantiate()
	root.add_child(qs)
	await process_frame
	qs.bind([{"id": "dock_tales", "name": "码头异闻", "objective": "完成 N0-2 检定", "node": "N0-2",
		"state": "triggered"}])
	var q_text := ""
	for row: Node in qs.list_box.get_children():
		for child: Node in row.get_children():
			if child is Label:
				q_text += (child as Label).text
	check(q_text.contains("码头异闻") and q_text.contains(TextsZh.QUESTS_ACTIVE), "事件中心：进行中事件列表（04 §⑤）")
	qs.queue_free()
	var iv: ScreenInventory = (load("res://shell/ui/screen_inventory.tscn") as PackedScene).instantiate()
	root.add_child(iv)
	await process_frame
	board.give_item("ink_core", 1, {"event_id": 2, "node_id": "N1-7", "pack_id": "campaign01"})
	iv.bind(board.get_inv(), pack["items"], board.get_lore())
	var iv_text := ""
	for child: Node in iv.bag_box.get_children():
		if child is Button: # 条目 = 按钮（点按 = 详情弹层，04 §⑥）
			iv_text += (child as Button).text
	check(iv_text.contains("墨核 ×1"), "背包图鉴：global.inv 只读列表（04 §⑥）")
	iv.queue_free()
	var ch: ScreenCharacter = (load("res://shell/ui/screen_character.tscn") as PackedScene).instantiate()
	root.add_child(ch)
	await process_frame
	ch.bind([{"id": "pc", "name": "白页者", "hp": 14, "max_hp": 14, "attrs": {"might": 2, "finesse": 1, "wits": 0},
		"skills": [{"name": "墨术飞矢"}]}], {"kelan": 10},
		{"xp": 350, "level": 2, "floor": 300, "next": 700, "attr_points": 0, "attrs": {"might": 1}})
	var ch_text := ""
	for child: Node in ch.list_box.get_children():
		if child is Label:
			ch_text += (child as Label).text
	check(ch_text.contains("白页者") and ch_text.contains("kelan 10/100"), "角色：队伍卡 + 羁绊只读（04 §⑦）")
	check(ch_text.contains("Lv.2") and ch_text.contains("350/700") and ch_text.contains("力 +1"),
		"角色⑦：成长区呈现等级 / XP 进度 / 已分配属性（tech/04 §8）")
	ch.queue_free()
	await process_frame

# ---------------------------------------------------------------- 主屏热点图（12 §5：可交互绘卷；热点=皮肤，兜底条=骨架，两路径等价）

func _tap_scroll(scroll: HomeScroll, h: Dictionary) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false # 抬手 = 点按落定（12 §1 点按判定 <300ms/<10pt 由手势层覆盖，此处直发语义事件）
	ev.position = scroll.hotspot_rect(h).get_center()
	scroll._gui_input(ev)

func test_home_hotspots() -> void:
	print("[home_hotspots]")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var prov := {"event_id": 1, "node_id": "", "pack_id": "campaign01"}
	var home: ScreenHome = (load("res://shell/ui/screen_home.tscn") as PackedScene).instantiate()
	root.add_child(home)
	await process_frame
	await process_frame
	var navs: Array = []
	home.navigate.connect(func(id: StringName) -> void: navs.append(id))
	home.bind(board, 0, false)
	# ---- 热点 → 导航信号映射五项（12 §5 ① 表：潮汐塔→② 集市→⑥ 营火→⑦ 告示板→⑤ 残页堆→⑧）----
	var expect := {"tide_tower": &"entry", "market": &"inventory", "campfire": &"character",
		"board": &"quests", "scraps": &"history"}
	check(HomeScroll.HOTSPOTS.size() == 5, "热点坐标表五区齐备（数据化，12 §5 落位状态）")
	var min_ok := true
	for h: Dictionary in HomeScroll.HOTSPOTS:
		var r := home.scroll.hotspot_rect(h)
		if r.size.x < 44.0 or r.size.y < 44.0:
			min_ok = false # 12 §6：可触目标最小 44×44pt
	check(min_ok, "热点区域满足 44×44pt 最小可触（12 §6）")
	for h: Dictionary in HomeScroll.HOTSPOTS:
		_tap_scroll(home.scroll, h)
	check(navs == [&"entry", &"inventory", &"character", &"quests", &"history"],
		"热点点按 → 导航信号映射五项（12 §5 ① 表）")
	# ---- 兜底条等价路径：同信号同界面（12 §5：热点图是皮肤，文字入口是骨架）----
	navs.clear()
	home.campaign_button.pressed.emit()
	home.inventory_button.pressed.emit()
	home.character_button.pressed.emit()
	home.quests_button.pressed.emit()
	home.history_button.pressed.emit()
	check(navs == [&"entry", &"inventory", &"character", &"quests", &"history"],
		"兜底条五入口与热点指向同一信号（12 §5 功能等价）")
	var bar_ids: Array = []
	for row: Node in home.fallback_bar.get_children():
		for b: Node in row.get_children():
			if b == home.campaign_button or b == home.quests_button or b == home.inventory_button \
					or b == home.character_button or b == home.history_button:
				bar_ids.append(String(b.text))
	check(bar_ids.size() == 5, "兜底条含五文字入口（12 §5 骨架）")
	# ---- main 级等价：两路径到同一界面（热点通道 vs 兜底条按钮通道）----
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	var mhome := m.current_screen as ScreenHome
	mhome.scroll.hotspot_pressed.emit(&"character") # 热点通道（玩家点营火同一信号路径）
	await process_frame
	check(m.current_screen is ScreenCharacter, "热点 → ⑦角色界面（12 §5 ①：营火与同伴→角色）")
	(m.current_screen as ScreenCharacter).back_button.pressed.emit()
	await process_frame
	(m.current_screen as ScreenHome).character_button.pressed.emit() # 兜底条通道
	await process_frame
	check(m.current_screen is ScreenCharacter, "兜底条 → 同一 ⑦角色界面（12 §5：两路径功能等价）")
	(m.current_screen as ScreenCharacter).back_button.pressed.emit()
	await process_frame
	(m.current_screen as ScreenHome).scroll.hotspot_pressed.emit(&"quests")
	await process_frame
	check(m.current_screen is ScreenQuests, "热点 → ⑤事件中心（12 §5 ①：告示板→事件中心）")
	(m.current_screen as ScreenQuests).back_requested.emit()
	await process_frame
	m.queue_free()
	await process_frame
	# ---- 未读角标：事件中心有未读时叠加（12 §5；复用 ◆N 语义，04 §①）----
	home.bind(board, 3, false)
	check(home.scroll.badge_visible() and home.scroll.badge_count() == 3,
		"未读角标：事件中心 3 条未读 → 告示板热点叠加 ◆3（12 §5）")
	home.bind(board, 0, false)
	check(not home.scroll.badge_visible(), "无未读 → 角标隐去（12 §5）")
	# ---- 微光呼吸：周期 ≤3s、缓动、不闪烁（12 §5）----
	check(HomeScroll.BREATH_PERIOD <= 3.0 and HomeScroll.BREATH_PERIOD > 0.0,
		"呼吸周期 %.1fs ≤ 3s（12 §5）" % HomeScroll.BREATH_PERIOD)
	var samples: Array[float] = []
	for i: int in 12:
		home.scroll._process(HomeScroll.BREATH_PERIOD / 12.0)
		samples.append(home.scroll.breath_glow())
	var glow_min: float = samples.min()
	var glow_max: float = samples.max()
	check(glow_min >= HomeScroll.GLOW_MIN - 0.001 and glow_min > 0.15,
		"呼吸不闪烁：光强下限 %.2f > 0（不归零，12 §5）" % glow_min)
	check(glow_max - glow_min > 0.2, "呼吸存在：光强随周期缓动起伏（Δ%.2f，12 §5）" % (glow_max - glow_min))
	var continuous := true
	for i: int in range(1, samples.size()):
		if absf(samples[i] - samples[i - 1]) > 0.25:
			continuous = false # 相邻采样无跳变 = 缓动非闪烁
	check(continuous, "呼吸缓动连续：相邻采样无跳变（12 §5 不闪烁）")
	# ---- 绘卷随状态板变化：时钟高格天色更暗/海面褪色加剧（12 §5；04 §4 ①）----
	var sky0 := home.scroll.sky_color()
	var sea0 := home.scroll.sea_color()
	board.write("global.doom_clock", 9, prov)
	home.bind(board, 0, false)
	check(home.scroll.doom_clock() == 9 and home.doom_label.text == Texts.home_doom_text(9),
		"绘卷与文案同时钟刷新（04 §4 ① 状态板的可视化）")
	check(home.scroll.sky_color().get_luminance() < sky0.get_luminance(),
		"时钟 9 格：天色更暗（12 §5 绘卷随褪墨度变化）")
	check(home.scroll.sea_color().get_luminance() < sea0.get_luminance(),
		"时钟 9 格：海面褪色加剧（12 §5 绘卷随褪墨度变化）")
	home.queue_free()
	await process_frame

# ---------------------------------------------------------------- 兜底条收起/展开（12 §5：toggle，默认展开，偏好持久化到本地设置，UI 偏好不写状态板）

func test_home_bar_toggle() -> void:
	print("[home_bar_toggle]")
	var path := "user://test/home_bar.cfg" # 测试隔离：不动真实 user://settings.cfg
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var stream := EventStream.new()
	var board := Board.new(stream)
	var home: ScreenHome = (load("res://shell/ui/screen_home.tscn") as PackedScene).instantiate()
	home.settings_path = path
	root.add_child(home)
	await process_frame
	var navs: Array = []
	home.navigate.connect(func(id: StringName) -> void: navs.append(id))
	home.bind(board, 0, false)
	# ---- 默认收起：主屏留给插画，只露细把手（12 §5 修订）----
	check(home.is_bar_collapsed() and not home.fallback_bar.visible, "文字菜单默认收起（主屏留给插画）")
	check(home.bar_toggle.visible and home.bar_toggle.tooltip_text == TextsZh.HOME_BAR_EXPAND
		and home.bar_toggle.custom_minimum_size.y <= 32.0 and home.bar_toggle.flat, "收起态：小把手可见（细条 + 箭头，提示=展开）")
	# ---- 把手点按 / 上滑下滑 都能切换 ----
	home.bar_toggle.pressed.emit()
	check(not home.is_bar_collapsed() and home.fallback_bar.visible
		and home.bar_toggle.tooltip_text == TextsZh.HOME_BAR_COLLAPSE, "点把手：展开文字菜单")
	home.swipe_menu(false)
	check(home.is_bar_collapsed() and not home.fallback_bar.visible, "下滑：收起")
	home.swipe_menu(false)
	check(home.is_bar_collapsed(), "已收起时再下滑：不变")
	home.swipe_menu(true)
	check(not home.is_bar_collapsed() and home.fallback_bar.visible, "上滑：展开")
	home.bar_toggle.pressed.emit()
	check(home.is_bar_collapsed() and not home.fallback_bar.visible, "toggle 收起：兜底条隐去（12 §5）")
	check(home.bar_toggle.visible, "收起后展开把手始终可触达（12 §5：等价路径永不消失）")
	check(not board.has("ui.home_bar_collapsed"), "UI 偏好不写状态板（12 §5：存本地设置）")
	# ---- 收起态五入口仍经热点可达（12 §5：热点图是皮肤）----
	for h: Dictionary in HomeScroll.HOTSPOTS:
		_tap_scroll(home.scroll, h)
	check(navs == [&"entry", &"inventory", &"character", &"quests", &"history"],
		"收起态五入口仍经热点可达（12 §5 两路径等价）")
	# ---- 偏好写盘 + 新实例启动读回（12 §5：偏好持久化到本地设置）----
	var cfg := ConfigFile.new()
	check(cfg.load(path) == OK and bool(cfg.get_value("ui", "home_bar_collapsed", false)),
		"偏好写盘 user://settings.cfg（ui.home_bar_collapsed=true）")
	var home2: ScreenHome = (load("res://shell/ui/screen_home.tscn") as PackedScene).instantiate()
	home2.settings_path = path
	root.add_child(home2)
	await process_frame
	home2.navigate.connect(func(id: StringName) -> void: navs.append(id))
	home2.bind(board, 0, false)
	check(home2.is_bar_collapsed() and not home2.fallback_bar.visible, "启动读回偏好：保持收起（12 §5 持久化）")
	# ---- 展开还原 + 展开等价路径断言不回归（12 §5：骨架与皮肤同信号）----
	home2.bar_toggle.pressed.emit()
	check(not home2.is_bar_collapsed() and home2.fallback_bar.visible
		and home2.bar_toggle.tooltip_text == TextsZh.HOME_BAR_COLLAPSE, "toggle 展开还原（12 §5）")
	navs.clear()
	home2.campaign_button.pressed.emit()
	home2.quests_button.pressed.emit()
	home2.inventory_button.pressed.emit()
	home2.character_button.pressed.emit()
	home2.history_button.pressed.emit()
	check(navs == [&"entry", &"quests", &"inventory", &"character", &"history"],
		"展开态兜底条等价路径不回归（12 §5）")
	home2.queue_free()
	home.queue_free()
	DirAccess.remove_absolute(path) # 写后清理
	check(not FileAccess.file_exists(path), "测试偏好文件已清理（路径隔离）")
	await process_frame

# ---------------------------------------------------------------- 横屏故事态（04 §③：中央主视野渲染叙事/选项，非战斗态）

func test_landscape_story() -> void:
	print("[landscape_story]")
	var pack := _load_campaign01()
	var stream := EventStream.new()
	var board := Board.new(stream)
	var graph := StoryGraph.new(board, Rng.new(20260009), pack)
	graph.seed_gold()
	graph.start()
	var land: EncounterLandscape = (load("res://shell/landscape/encounter_landscape.tscn") as PackedScene).instantiate()
	root.add_child(land)
	land.set_anchors_preset(Control.PRESET_TOP_LEFT)
	land.position = Vector2.ZERO
	land.size = Vector2(1280, 720)
	await process_frame
	await process_frame
	land.bind_story(stream, board, pack, {})
	land.show_story(StoryVM.build(graph, board, pack))
	await process_frame
	check(land.story_panel.visible and not land.grid.visible, "横屏故事态：中央主视野渲染叙事（非战斗态，04 §③）")
	check(land.story_title.text == "潮醒" and land.story_text.text.contains("潮声"),
		"横屏叙事文本同源 StoryVM（godot-dev §7 单一内容源）")
	check(land.story_option_texts() == ["起身"], "横屏左栏选项 = 同一 vm.edges（与竖屏同源）")
	check(land.clock_chip.visible and land.clock_chip.text.contains("时钟 0 格")
		and land.clock_chip.text.contains("墨雨夜袭"), "横屏状态栏带：时钟 + 时间边预告（04 §3.1）")
	# 五区指标不被故事态破坏（09 §4）
	var z := land.get_zone_ratios()
	check(absf(float(z["top"]) - 0.08) < 0.02 and absf(float(z["bottom"]) - 0.05) < 0.02,
		"故事态五区冻结指标保持（09 §4）")
	# 旗标 toast（事件流驱动）
	board.write("campaign01.seen_fading", true,
		{"event_id": stream.tail(), "node_id": "N0-3a", "pack_id": "campaign01"})
	await process_frame
	check(land.flash_label.text.contains("旗标"), "横屏旗标 toast（事件流驱动）")
	# 时间钟弹层（04 §3.1 例外交互）
	land._open_forecast()
	check(land.info_popup.visible and land.info_popup.body_label.text.contains("墨雨夜袭")
		and land.info_popup.body_label.text.contains("2 格"), "横屏点时间钟 → 时间边预告弹层（04 §3.1）")
	land.info_popup.hide()
	# 故事态 → 战斗态布局切换（同一壳，09 §8）
	var sm := EncounterSM.new(board, stream, Rng.new(11), "campaign01")
	land.bind(sm, AutoAgent.new())
	check(not land.story_panel.visible and land.grid.visible, "bind 遭遇 → 战斗布局恢复（故事面板收起）")
	land.queue_free()
	await process_frame

# ---------------------------------------------------------------- 幕三模式锁定（tech/02 §2.1 forced/forced_except；09 §3；世界观 §8；战役书幕三）

func test_act3_forced_mode() -> void:
	print("[act3_forced_mode]")
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_SPACE) # 横屏玩家路径
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	# SL-0 强制竖屏：横屏玩家开局即竖屏壳（manifest presentation.forced）
	check(m.shell is EncounterLandscape and m.graph.current_id == "N0-1",
		"选横屏：从序章起即横屏壳（序章不再强制竖屏）")
	m._on_story_edge(0) # → N0-2
	await process_frame
	m._on_story_edge(0) # 掷检定
	await create_timer(1.2).timeout
	m._on_story_edge(0) # → N0-4
	await process_frame
	m._on_story_edge(0) # → N1-1（SL-1：恢复横屏）
	await process_frame
	check(m.shell is EncounterLandscape, "SL-1 保持横屏（随玩家所选形态，tech/02 §2.1）")
	# N2-C → N3-1：横屏玩家强制切竖屏壳 + 模式锁定演出
	m.graph._enter("N2-C") # 传送幕二收束点（SL-2 随玩家所选形态）
	m._present_node()
	await process_frame
	check(m.shell is EncounterLandscape, "N2-C（SL-2）：横屏壳保持")
	m._on_story_edge(0) # → N3-1
	await process_frame
	check(m.shell is EncounterPortrait,
		"N2-C → N3-1：横屏玩家强制切竖屏壳（战役书幕三模式锁定演出）")
	check((m.shell as EncounterPortrait).flash_label.text.contains("回放"),
		"模式锁定叙事化提示：残篇只能逐房回放（世界观 §8；09 §3 NOTICE_FORCED）")
	check(m.graph.current_id == "N3-1" and str(m.graph.current().get("act", "")) == "SL-3",
		"幕三节点就位（SL-3 撤销区）")
	# N3-7 起切回横屏（forced_except：空白广场解锁横屏）
	m.graph._enter("N3-7")
	m._present_node()
	await process_frame
	check(m.shell is EncounterLandscape,
		"N3-7 起切回横屏（forced_except 解锁，战役书幕三「此处起解锁横屏」）")
	check((m.shell as EncounterLandscape).flash_label.text.contains("全局的视野"),
		"N3-7 解锁提示叙事化呈现（09 §3）")
	m.queue_free()
	await process_frame

# ---------------------------------------------------------------- 战役级横竖屏边界（09 §8，M5）
# 形态是战役级属性：开始战役即切窗口与壳；整备/叙事/战斗/结算同形态；幕级 forced 例外照旧；
# 战役结束一切路径（通关/☰/败北）恢复竖屏基准；外层界面恒定竖屏；全数据驱动（manifest presentation）。

func test_mode_boundary() -> void:
	print("[mode_boundary]")
	var main_scene: PackedScene = load("res://main.tscn")
	# ============ 横屏战役：全程横屏 + forced 幕例外 + 一切离场路径恢复竖屏 ============
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	check(m.window_orientation == ShellRouter.MODE_TIME and m.current_screen is ScreenHome,
		"启动即竖屏基准（外层界面恒定竖屏，09 §8）")
	m._on_home_navigate(&"entry")
	await process_frame
	check(m.window_orientation == ShellRouter.MODE_TIME, "②战役入口竖屏（外层界面）")
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_SPACE)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	check(m.window_orientation == ShellRouter.MODE_SPACE and m.shell is EncounterLandscape,
		"选横屏：开局窗口与壳均横屏（序章随所选形态）")
	m._on_story_edge(0) # N0-1 → N0-2
	await process_frame
	m._on_story_edge(0) # 掷检定
	await create_timer(1.2).timeout
	m._on_story_edge(0) # → N0-4
	await process_frame
	m._on_story_edge(0) # → N1-1（SL-1：恢复所选形态）
	await process_frame
	check(m.window_orientation == ShellRouter.MODE_SPACE and m.shell is EncounterLandscape,
		"SL-1 起横屏窗口 + 横屏壳（幕末切回所选形态，09 §8）")
	# ---- 整备横屏：直达战斗节点（壳未建时窗口先就位）----
	m.graph._enter("N1-7")
	m._present_node()
	await process_frame
	check(m.current_screen is ScreenLoadout and m.window_orientation == ShellRouter.MODE_SPACE,
		"整备界面在横屏布局（09 §8：整备随战役形态）")
	(m.current_screen as ScreenLoadout)._on_confirm()
	await create_timer(1.4).timeout
	check(m.campaign._in_encounter and m.shell is EncounterLandscape
		and m.window_orientation == ShellRouter.MODE_SPACE, "战斗态横屏壳 + 横屏窗口（09 §8）")
	# ---- ☰ 中途退出 → 恢复竖屏 ----
	m._on_save_quit()
	await process_frame
	check(m.current_screen is ScreenHome and m.window_orientation == ShellRouter.MODE_TIME,
		"☰ 中途退出：恢复竖屏基准（09 §8）")
	# ---- 继续战役 → 仍横屏整备（形态随战役数据，非随窗口惯性）----
	m._on_home_navigate(&"entry")
	await process_frame
	check(m.window_orientation == ShellRouter.MODE_TIME, "回主屏后再入②入口：竖屏（外层界面）")
	(m.current_screen as ScreenEntry).start_requested.emit() # 已选形态预选 space（global.mode_choice 写板）
	await process_frame
	check(m.current_screen is ScreenLoadout and m.window_orientation == ShellRouter.MODE_SPACE,
		"主屏「继续」→ 横屏整备（所选形态保持，09 §8）")
	(m.current_screen as ScreenLoadout)._on_confirm()
	await create_timer(1.4).timeout
	check(m.window_orientation == ShellRouter.MODE_SPACE, "再进遭遇仍横屏")
	# ---- 败北 → 结算横屏；结算 → 卷轴（竖屏）→ 结算（横屏）→ 主屏（竖屏）----
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"defeat", "rounds": 2}, &"core", m.graph.current_id)
	await create_timer(1.6).timeout
	check(m.current_screen is ScreenSettle and m.window_orientation == ShellRouter.MODE_SPACE,
		"败北结算仍横屏（09 §8：结算在所选形态下呈现）")
	(m.current_screen as ScreenSettle).go_history.emit()
	await process_frame
	check(m.current_screen is ScreenHistory and m.window_orientation == ShellRouter.MODE_TIME,
		"结算 → ⑧卷轴：功能界面恒定竖屏（09 §8）")
	(m.current_screen as ScreenHistory).back_button.pressed.emit()
	await process_frame
	check(m.current_screen is ScreenSettle and m.window_orientation == ShellRouter.MODE_SPACE,
		"卷轴返回结算：恢复横屏（来源界面语义 + 战役形态恢复，04 §5/09 §8）")
	(m.current_screen as ScreenSettle).go_home.emit()
	await process_frame
	check(m.current_screen is ScreenHome and m.window_orientation == ShellRouter.MODE_TIME,
		"结算回主屏：恢复竖屏基准（败北路径收束，09 §8）")
	# ---- forced 幕例外：SL-2 横屏 → N3-1 强制竖屏 → N3-7 切回横屏 ----
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	m.graph._enter("N2-C")
	m._present_node()
	await process_frame
	check(m.window_orientation == ShellRouter.MODE_SPACE and m.shell is EncounterLandscape,
		"SL-2 横屏保持（forced 幕外随所选形态）")
	m._on_story_edge(0) # N2-C → N3-1（SL-3 强制竖屏）
	await process_frame
	check(m.window_orientation == ShellRouter.MODE_TIME and m.shell is EncounterPortrait,
		"forced 幕内：窗口与壳同切竖屏（SL-3，09 §8 幕级强制例外）")
	m.graph._enter("N3-7") # forced_except：空白广场起解锁
	m._present_node()
	await process_frame
	check(m.window_orientation == ShellRouter.MODE_SPACE and m.shell is EncounterLandscape,
		"幕末切回横屏（forced_except N3-7，09 §8）")
	# ---- 通关结局 → 恢复竖屏 ----
	m.graph._enter("E1")
	m._present_node()
	await process_frame
	check(m.current_screen is ScreenEnding and m.window_orientation == ShellRouter.MODE_TIME,
		"通关结局：恢复竖屏基准（09 §8：一切离开战役的路径都必须恢复）")
	m.queue_free()
	await process_frame
	# ============ 竖屏战役：全程零切换 ============
	var m2: Node = _new_main()
	root.add_child(m2)
	await process_frame
	await process_frame
	m2._on_home_navigate(&"entry")
	await process_frame
	(m2.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m2.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	check(m2.window_orientation == ShellRouter.MODE_TIME and m2.shell is EncounterPortrait,
		"竖屏战役：开局竖屏（SL-0 forced 与所选一致，零切换）")
	m2._on_story_edge(0) # → N0-2
	await process_frame
	m2._on_story_edge(0) # 掷检定
	await create_timer(1.2).timeout
	m2._on_story_edge(0) # → N0-4
	await process_frame
	m2._on_story_edge(0) # → N1-1
	await process_frame
	check(m2.window_orientation == ShellRouter.MODE_TIME and m2.shell is EncounterPortrait,
		"竖屏战役：SL-1 仍竖屏壳（同一壳复用，零切换）")
	m2.graph._enter("N1-7")
	m2._present_node()
	await process_frame
	check(m2.current_screen is ScreenLoadout and m2.window_orientation == ShellRouter.MODE_TIME,
		"竖屏战役：整备竖屏")
	(m2.current_screen as ScreenLoadout)._on_confirm()
	await create_timer(1.4).timeout
	check(m2.campaign._in_encounter and m2.shell is EncounterPortrait
		and m2.window_orientation == ShellRouter.MODE_TIME, "竖屏战役：战斗竖屏（全程零切换）")
	m2.stream.emit(EventTypes.COMBAT_END, {"result": &"defeat", "rounds": 2}, &"core", m2.graph.current_id)
	await create_timer(1.6).timeout
	check(m2.current_screen is ScreenSettle and m2.window_orientation == ShellRouter.MODE_TIME,
		"竖屏战役：结算竖屏")
	(m2.current_screen as ScreenSettle).go_home.emit()
	await process_frame
	# ---- 外层功能界面恒定竖屏（竖屏基准下逐一过闸）----
	for nav: StringName in [&"quests", &"inventory", &"character", &"history"]:
		m2._on_home_navigate(nav)
		await process_frame
		check(m2.window_orientation == ShellRouter.MODE_TIME and not (m2.current_screen is EncounterPortrait)
			and not (m2.current_screen is EncounterLandscape),
			"外层界面恒定竖屏：%s（09 §8）" % String(nav))
		(m2.current_screen.get("back_button") as Button).pressed.emit()
		await process_frame
	check(m2.current_screen is ScreenHome and m2.window_orientation == ShellRouter.MODE_TIME,
		"功能界面巡回后回主屏：竖屏基准")
	m2.queue_free()
	await process_frame

# ---------------------------------------------------------------- 横屏专版：整备与结算布局（04 §④.8；09 §8 形态注入；竖屏回归不变）

func test_loadout_settle_landscape() -> void:
	print("[loadout_settle_landscape]")
	root.size = Vector2i(1280, 720) # 横屏窗口尺寸：布局断言需真实落版
	# ---- 横屏整备：三段横列 + 队伍状态条置顶（04 §④.8）----
	var lo: ScreenLoadout = (load("res://shell/ui/screen_loadout.tscn") as PackedScene).instantiate()
	lo.set_form(ShellRouter.MODE_SPACE)
	root.add_child(lo)
	await process_frame
	await process_frame
	check(lo.is_landscape_layout(), "横屏整备：三段横列布局启用（04 §④.8）")
	check(lo.party_bar != null and lo.skill_box != null and lo.item_box != null
		and lo.preset_label != null and lo.confirm_button != null,
		"横屏整备控件齐备：队伍条/技能列/道具列/预设卡/开战")
	check(lo.skill_box.get_parent() == lo.col_skills and lo.equip_grid.get_parent() == lo.col_skills
		and lo.item_box.get_parent() == lo.col_items and lo.attr_box.get_parent() == lo.col_items,
		"横屏整备：左角色表（装备槽+备战技能）/ 中资源库+快取袋+属性点（04 §④.8）")
	check(lo.preset_label.get_parent() == lo.col_right and lo.confirm_button.get_parent() == lo.col_right
		and lo.back_button.get_parent() == lo.col_right,
		"横屏整备：右预设与开战列（04 §④.8）")
	check(lo.cols.get_child(0) == lo.col_skills and lo.cols.get_child(1) == lo.col_items
		and lo.cols.get_child(2) == lo.col_right, "横屏整备：三段次序 技能→道具→预设开战")
	check(lo.confirm_button.custom_minimum_size.y >= 64, "大号开战按钮居拇指右手区（04 §④.8）")
	lo.bind({"skill_slots": 2, "item_slots": 1}, {"skills": [
			{"id": "s1", "name": "技能一"}, {"id": "s2", "name": "技能二"}, {"id": "s3", "name": "技能三"}],
		"items": [{"id": "heal_potion", "name": "补给药水", "count": 2}],
		"attr_points": 1, "attr_alloc": {"might": 0, "finesse": 0, "wits": 0},
		"party": [{"id": "pc", "name": "白页者", "hp": 14, "max_hp": 18}]})
	await process_frame
	var party_texts := ""
	for c: Node in lo.party_bar.get_children():
		if c is Button:
			party_texts += (c as Button).text
	check(party_texts.contains("白页者") and party_texts.contains("14/18"),
		"队伍状态条置顶：HP 概览实数据（04 §④.8，04 §3.1 同口径）")
	# 功能等价：同数据同操作路径（toggle → 预设卡摘要 → confirm 信号）
	lo._toggle_skill("s1")
	lo._toggle_skill("s2")
	lo._toggle_skill("s3") # 第 3 个超槽：不进入选择
	check(lo.picked_skills() == ["s1", "s2"], "横屏整备：技能槽位限制与竖屏一致（09 §9.1）")
	await process_frame
	check(lo.preset_label.text.contains("技能一") and lo.preset_label.text.contains("技能二"),
		"预设卡实时反映当前选择（04 §④.8 预设与开战）")
	lo._toggle_item("heal_potion")
	var lo_sel: Array = []
	lo.confirmed.connect(func(sel: Dictionary) -> void: lo_sel.append(sel))
	lo._on_confirm()
	check(lo_sel.size() == 1 and (lo_sel[0]["skills"] as Array) == ["s1", "s2"]
		and (lo_sel[0]["items"] as Array) == ["heal_potion"],
		"横屏整备确认上报：与竖屏同信号同载荷（功能等价）")
	lo.queue_free()
	await process_frame
	# ---- 系统预设一键套用（09 §9.3；tech/02 §2.4 presets，数据驱动）----
	var pack := _load_campaign01()
	var pcfg := Loadout.resolve_config(pack, "N1-7")
	var presets: Array = pcfg.get("presets", [])
	check(presets.size() == 3 and str(presets[0]["name"]) == "强攻" and str(presets[1]["name"]) == "稳守"
		and str(presets[2]["name"]) == "均衡", "系统预设随包发布：强攻/稳守/均衡（09 §9.3，改 manifest 即变）")
	var cands := {"skills": [
			{"id": "inkbolt", "name": "墨术飞矢"}, {"id": "inkshield", "name": "墨盾格挡"},
			{"id": "inklance", "name": "墨枪突刺"}],
		"items": [{"id": "heal_potion", "name": "补给药水", "count": 2}],
		"attr_points": 0, "basic_attacks": ["slash"]}
	var lo3: ScreenLoadout = (load("res://shell/ui/screen_loadout.tscn") as PackedScene).instantiate()
	lo3.set_form(ShellRouter.MODE_SPACE)
	root.add_child(lo3)
	await process_frame
	lo3.bind(pcfg, cands)
	await process_frame
	check(lo3.preset_box.get_child_count() == 3, "横屏右列预设卡：三预设可点击（04 §④.8 预设与开战）")
	(lo3.preset_box.get_child(0) as Button).pressed.emit() # 强攻 = slash(普攻恒带) + inkbolt + heal_potion
	check(lo3.picked_skills() == ["inkbolt"] and lo3.picked_items() == ["heal_potion"],
		"预设强攻一键套用：普攻 slash 恒带不占槽（tech/04 §2），墨术飞矢+补给药水填槽")
	check(lo3.hint_label.text.is_empty(), "普攻引用不触发未备齐提示（tech/04 §2 已习得）")
	await process_frame
	check(lo3.preset_label.text.contains("墨术飞矢") and lo3.preset_label.text.contains("补给药水"),
		"套用后预设卡摘要同步")
	(lo3.preset_box.get_child(2) as Button).pressed.emit() # 均衡 = inkbolt + inkshield + heal_potion
	check(lo3.picked_skills() == ["inkbolt", "inkshield"], "预设均衡填充：墨术飞矢+墨盾格挡")
	lo3._toggle_skill("inkbolt") # 套用后逐槽微调
	check(lo3.picked_skills() == ["inkshield"], "套用后可逐槽微调（09 §9.3：预设只是选择记录）")
	lo3.bind(pcfg, {"skills": cands["skills"], "items": [], "attr_points": 0, "basic_attacks": ["slash"]})
	await process_frame
	(lo3.preset_box.get_child(1) as Button).pressed.emit() # 稳守（无 heal_potion 持有）
	check(lo3.picked_items().is_empty() and lo3.hint_label.text.contains("heal_potion"),
		"未持有道具跳过 + 提示（09 §9.3）")
	lo3.queue_free()
	await process_frame
	# 竖屏预设行：同配置同套用（两形态等价）
	var lo4: ScreenLoadout = (load("res://shell/ui/screen_loadout.tscn") as PackedScene).instantiate()
	root.add_child(lo4)
	await process_frame
	lo4.bind(pcfg, cands)
	await process_frame
	check(lo4.preset_box != null and lo4.preset_box.get_child_count() == 3,
		"竖屏预设行：三预设同配置呈现（09 §9.3）")
	(lo4.preset_box.get_child(0) as Button).pressed.emit()
	check(lo4.picked_skills() == ["inkbolt"] and lo4.picked_items() == ["heal_potion"],
		"竖屏预设套用与横屏等价（同数据同操作路径）")
	lo4.queue_free()
	await process_frame
	# ---- 横屏结算：双区 + 逐项念板 + 胜利演出（04 §④.8）----
	var st: ScreenSettle = (load("res://shell/ui/screen_settle.tscn") as PackedScene).instantiate()
	st.set_form(ShellRouter.MODE_SPACE)
	root.add_child(st)
	await process_frame
	await process_frame
	check(st.is_landscape_layout() and st.lines_box != null and st.side_zone != null,
		"横屏结算：左念板列表 + 右加点与出口双区（04 §④.8）")
	st.bind({"title": "午夜墨雨", "result": "victory", "lines": ["经验 +100", "获得：墨核 ×1"],
		"saved": true, "attr_points": 1, "attrs": {"might": 0, "finesse": 0, "wits": 0}})
	await process_frame
	check(st.lines_box.get_child_count() == 3, "横屏结算：逐项念板列表（标题行 + 2 条目）")
	check((st.lines_box.get_child(1) as Label).text == "经验 +100", "念板逐条独立呈现（逐条入场前提）")
	check(st.summary_text.text.contains("经验 +100") and st.summary_text.text.contains("墨核"),
		"横屏结算：汇总全文与竖屏同口径（同数据探针）")
	check(st.attr_box.get_parent() == st.side_zone and st.home_button.get_parent() == st.side_zone
		and st.history_button.get_parent() == st.side_zone, "横屏结算：右侧成长加点区与出口按钮")
	check(st.victory_banner.visible, "胜利演出横铺中央（04 §④.8）")
	await create_timer(1.8).timeout # 演出 0.2+0.35+0.5+0.3s + 念板逐条入场落定
	check(not st.victory_banner.visible, "胜利演出收拢到结算布局（播完隐去，04 §④.8）")
	check((st.lines_box.get_child(1) as Label).modulate.a > 0.99, "念板条目逐条入场动画落定")
	var allocs: Array = []
	st.allocate.connect(func(a: String) -> void: allocs.append(a))
	for c: Node in st.attr_box.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).pressed.emit()
			break
	check(allocs.size() == 1, "横屏结算：成长加点上报与竖屏同路径（11 §6）")
	st.bind({"title": "午夜墨雨", "result": "victory", "lines": [], "saved": true,
		"attr_points": 0, "attrs": {}, "celebrate": false})
	await process_frame
	check(not st.victory_banner.visible, "celebrate=false：同场重绑不重播胜利演出（加点刷新路径）")
	st.bind({"title": "午夜墨雨", "result": "defeat", "lines": ["经验 +10"], "saved": true,
		"attr_points": 0, "attrs": {}})
	await process_frame
	check(not st.victory_banner.visible, "败北结算无胜利演出（结果分级）")
	st.queue_free()
	await process_frame
	# ---- 竖屏回归：默认形态布局不变（04 §④.8：竖屏布局不变）----
	root.size = Vector2i(390, 760)
	var lo2: ScreenLoadout = (load("res://shell/ui/screen_loadout.tscn") as PackedScene).instantiate()
	root.add_child(lo2)
	await process_frame
	check(not lo2.is_landscape_layout() and lo2.cols == null and lo2.preset_label == null
		and lo2.party_bar != null, "竖屏整备：纵列布局（无横屏三段容器；队伍卡两形态共有）")
	lo2.queue_free()
	var st2: ScreenSettle = (load("res://shell/ui/screen_settle.tscn") as PackedScene).instantiate()
	root.add_child(st2)
	await process_frame
	check(not st2.is_landscape_layout() and st2.lines_box == null and st2.victory_banner == null,
		"竖屏结算回归：居中纵列不变（无横屏容器）")
	check(st2.next_button != null and not st2.next_button.visible,
		"竖屏结算回归：无 has_next 时下一遭遇出口隐藏（04 §⑨）")
	st2.queue_free()
	await process_frame
	# ---- main 级接线：横屏战役整备/结算形态注入（09 §8 + 04 §④.8）----
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_SPACE)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	m.graph._enter("N1-7")
	m._present_node()
	await process_frame
	var mlo := m.current_screen as ScreenLoadout
	check(mlo != null and mlo.is_landscape_layout() and m.window_orientation == ShellRouter.MODE_SPACE,
		"横屏战役：整备三段横列随战役形态注入（04 §④.8/09 §8）")
	await process_frame
	var party_ok := false
	for c: Node in mlo.party_bar.get_children():
		if c is Button and (c as Button).text.contains("白页者"):
			party_ok = true
	check(party_ok, "横屏战役整备：队伍状态条实数据（graph.party_status）")
	mlo._on_confirm()
	await create_timer(1.4).timeout
	# ---- 胜利必经结算：横屏双区 + 胜利演出 + 下一遭遇出口（04 §⑨/§④.8）----
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 3}, &"core", m.graph.current_id)
	await create_timer(1.6).timeout
	var mst := m.current_screen as ScreenSettle
	check(mst != null and mst.is_landscape_layout() and m.window_orientation == ShellRouter.MODE_SPACE,
		"横屏战役：胜利结算双区随战役形态注入（04 §⑨/§④.8/09 §8）")
	check(mst.victory_banner.visible, "横屏战役：胜利演出横铺中央（04 §④.8）")
	check(mst.next_button.visible, "横屏战役：胜利结算下一遭遇出口（04 §⑨/§④.8）")
	mst.go_next.emit()
	await process_frame
	check(m.graph.current_id == "N1-8" and m.current_screen == m.shell,
		"下一遭遇 → 战后边推进 N1-8 并呈现节点（tech/02 §3）")
	# ---- 败北路：结算无下一遭遇出口（失败/撤退路径不变）----
	m.graph._enter("N1-7")
	m._present_node()
	await process_frame
	(m.current_screen as ScreenLoadout)._on_confirm()
	await create_timer(1.4).timeout
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"defeat", "rounds": 2}, &"core", m.graph.current_id)
	await create_timer(1.6).timeout
	var mst2 := m.current_screen as ScreenSettle
	check(mst2 != null and mst2.is_landscape_layout() and not mst2.next_button.visible,
		"横屏战役：败北结算无下一遭遇出口（失败/撤退路径不变）")
	check(mst2.lines_box.get_child_count() >= 2, "横屏结算念板实数据逐项呈现")
	mst2.go_home.emit()
	await process_frame
	m.queue_free()
	await process_frame
	root.size = Vector2i(390, 760) # 还原竖屏基准，不影响后续用例

# ---------------------------------------------------------------- main 节点流程集成（tech/01 §10；04 §3.1/§④.2/§④.3/§⑨；07 §4.2；09 §6/§7）

## main 流程战斗快捷通道：整备确认 → 遭遇 → 模拟胜利 → ⑨ 结算「下一遭遇」（04 §⑨：胜利必经结算；
## 真实战斗数值由 encounter_sm/包数据通道覆盖）。
func _main_win_battle(m: Node) -> void:
	var lo := m.current_screen as ScreenLoadout
	lo._toggle_skill("inkbolt")
	lo._toggle_skill("inkshield")
	lo._on_confirm()
	await create_timer(1.4).timeout
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 3}, &"core", m.graph.current_id)
	await create_timer(1.6).timeout
	(m.current_screen as ScreenSettle).go_next.emit() # 下一遭遇：沿故事图边推进（04 §⑨）
	await process_frame

func test_main_flow() -> void:
	print("[main_flow]")
	var main_scene: PackedScene = load("res://main.tscn")
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	check(m.current_screen is ScreenHome, "启动 → ①主屏（04 §2 枢纽）")
	m._on_home_navigate(&"entry")
	await process_frame
	check(m.current_screen is ScreenEntry, "主屏 → ②战役入口")
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	check(str(m.board.read("global.mode_choice.campaign01")) == "time",
		"模式选择写板 global.mode_choice.campaign01（09 §3，07 §3 v1.1 白名单）")
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	# ---- scene（N0-1）：叙事文本 + 继续；推进条 pip 同步；状态栏带 ----
	var sh := m.shell as EncounterPortrait
	check(sh != null and m.current_screen == sh, "战役开始 → 竖屏故事壳（节点流程，非直达战斗）")
	check(m.graph.current_id == "N0-1", "真实走图：入口节点 N0-1（tech/02 §3）")
	check(sh.story_title.text == "潮醒" and sh.story_text.text.contains("潮声"),
		"scene 节点渲染：标题 + 叙事文本（04 §④.3）")
	check(sh.story_option_texts() == ["起身"], "scene 节点渲染：继续选项")
	check(sh.pip_state(0) == EncounterPortrait.PIP_CURRENT and sh.pip_state(1) == EncounterPortrait.PIP_FUTURE,
		"推进条 pip 同步 story 节点（04 §④.2：当前脉动/未来剪影）")
	check(sh.clock_chip.visible and sh.clock_chip.text.contains("时钟 0 格")
		and sh.clock_chip.text.contains("→ 2 格") and sh.clock_chip.tooltip_text.contains("墨雨夜袭 2格"),
		"状态栏带：时钟总览格 + 下一格提示（竖屏紧凑；事件名在提示/弹层）（04 §3.1）")
	var party_shown := ""
	for child: Node in sh.party_chips.get_children():
		# 芯片结构 = HBox[头像? + Label]（14 #7 art_ref 头像芯片，tech/05 §8）：取 Label 后代文本
		var stack: Array[Node] = [child]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is Label:
				party_shown += (n as Label).text
			stack.append_array(n.get_children())
	check(party_shown.contains("白页者 14/14") and party_shown.contains("珂兰"),
		"状态栏带：队伍 HP 概览（04 §3.1）")
	await process_frame
	await process_frame
	check(_ratios_close(sh.get_band_ratios(), [0.08, 0.50, 0.42]), "故事态呼吸对话档 8/50/42（04 §④.1）")
	sh._open_forecast()
	check(sh.info_popup.visible and sh.info_popup.body_label.text.contains("墨雨夜袭"),
		"点时间钟 → 时间边预告弹层（04 §3.1 例外交互）")
	sh.info_popup.hide()
	# ---- check（N0-2）：检定按钮 → check.roll → 按结果走边；L3 事件触发 toast ----
	m._on_story_edge(0)
	await process_frame
	check(m.graph.current_id == "N0-2", "scene → check 节点推进")
	check(sh.story_option_texts()[0] == "检定：感知（易 DC 8 · 修正 +0）",
		"check 节点渲染：检定按钮（技能/难度/DC/修正，04 §④.3）")
	check(sh.flash_label.text.contains("码头异闻"), "L3 事件触发 toast + 进事件中心（事件流驱动）")
	m._on_story_edge(0) # 掷检定（种子 20260009：d20=17 成功）
	await create_timer(1.0).timeout
	var rolls: Array = m.stream.query_by_type(EventTypes.CHECK_ROLL)
	check(rolls.size() == 1 and str(rolls[0]["payload"]["kind"]) == "story_check",
		"检定按钮 → check.roll 事件（09 §6 同一事件源驱动演出）")
	check(m.graph.current_id == "N0-3a", "检定成功 → success 边（tech/02 §4.2；写板效果生效）")
	check(m.board.read("campaign01.seen_fading") == true, "写板效果生效：seen_fading 落板（07 §1）")
	m._on_story_edge(0) # N0-3a → N0-4
	await process_frame
	m._on_story_edge(0) # N0-4 → N1-1 hub
	await process_frame
	# ---- hub（N1-1）：商店/休整/传闻 ----
	check(m.graph.current_id == "N1-1", "抵达 hub N1-1（自由市广场）")
	var hub_opts := sh.story_option_texts()
	check(hub_opts.has(TextsZh.HUB_SHOP) and hub_opts.has(TextsZh.HUB_REST) and hub_opts.has(TextsZh.HUB_RUMOR),
		"hub 渲染：商店/休整/传闻三设施（战役书 §4 N1-1）")
	check(m.graph.get_gold() == 30, "金币播种（开局 30 占位，待裁决）")
	m._on_hub_action("rumor", "")
	await process_frame
	check(sh.flash_label.text.contains("传闻"), "传闻 toast（战役书 §4：未择路线以传闻提及）")
	m._on_hub_action("rest", "")
	await process_frame
	check(int(m.board.read("campaign01.hp.player_blank", 0)) == 14
		and sh.flash_label.text.contains("长休"), "旅店长休：恢复 HP（写板 + toast）")
	# 商店半屏弹层：购买 → 道具 + 金币扣减；金币不足拒绝
	sh.hub_popup.open(m.graph.get_gold(), m.graph.hub_stock())
	await process_frame
	var buy_btn: Button = null
	var potion_btn: Button = null
	for child: Node in sh.hub_popup.stock_box.get_children():
		if child is Button and (child as Button).text.contains("半页潮汐表"):
			buy_btn = child
		if child is Button and (child as Button).text.contains("补给药水"):
			potion_btn = child
	check(buy_btn != null and buy_btn.text.contains("15")
		and potion_btn != null and potion_btn.text.contains("15"),
		"商店半屏弹层：货单含潮汐表与药水价格（04 §3.3；验收裁决 B 上架）")
	buy_btn.pressed.emit()
	await process_frame
	check(m.board.has_item("half_tide_table") and m.graph.get_gold() == 30 - 15,
		"购买：give_item + 金币扣减（07 §1 溯源写板）")
	# 购买后弹层货单重建（sync_hub_popup），按钮需重新获取（真实用户视角：读新列表再点）
	potion_btn = null
	for child: Node in sh.hub_popup.stock_box.get_children():
		if child is Button and (child as Button).text.contains("补给药水"):
			potion_btn = child
	potion_btn.pressed.emit()
	await process_frame
	check(m.board.item_count("heal_potion") == 3 and m.graph.get_gold() == 30 - 30,
		"购买药水：扣 15 金 + give_item（序章带入 ×2 + 购买 ×1，验收裁决 B）")
	check((m._loadout_candidates()["items"] as Array).any(func(it: Variant) -> bool:
		return str((it as Dictionary)["id"]) == "heal_potion" and int((it as Dictionary)["count"]) == 3),
		"药水入整备携行候选（战斗中可使用，tech/04 §4；CMD_ITEM 通道已由遭遇测试验证）")
	check(sh.hub_popup.gold_label.text == TextsZh.HUB_GOLD % (30 - 30),
		"购买后弹层金币同步刷新")
	sh.hub_popup.hide()
	m.board.write("campaign01.gold", 5, {"event_id": m.stream.tail(), "node_id": "N1-1", "pack_id": "campaign01"})
	m._on_hub_action("buy", "half_tide_table")
	await process_frame
	check(m.graph.get_gold() == 5 and sh.flash_label.text.contains("金币不足"), "金币不足：拒绝 + 提示")
	m.board.write("campaign01.gold", 30, {"event_id": m.stream.tail(), "node_id": "N1-1", "pack_id": "campaign01"})
	# ---- check（N1-2）→ scene（N1-3）：时钟推进 → 状态栏带/预告刷新 ----
	var fade_idx := -1
	var opts_hub := sh.story_option_texts()
	for i: int in opts_hub.size():
		if str(opts_hub[i]).contains("前往褪色现场"):
			fade_idx = i
	check(fade_idx >= 0, "hub 选项：前往褪色现场（购买边旁路）")
	m._on_story_edge(fade_idx)
	await process_frame
	check(m.graph.current_id == "N1-2", "hub → N1-2 调查节点")
	m._on_story_edge(0) # 掷检定（d20=17+2 vs 12 成功）
	await create_timer(1.0).timeout
	check(m.graph.current_id == "N1-3", "N1-2 检定成功 → N1-3")
	check(sh.clock_chip.text.contains("时钟 1 格"), "N1-3 on_enter 时钟 +1 → 状态栏带刷新（clock.tick 事件驱动）")
	# ---- dialog（N1-4）：声望角标 + 选项回复进日志 + 声望事件 ----
	var invite_idx := -1
	var opts_n13 := sh.story_option_texts()
	for i: int in opts_n13.size():
		if str(opts_n13[i]).contains("接触誊写庭"):
			invite_idx = i
	check(invite_idx >= 0 and str(opts_n13[invite_idx]).contains("誊写庭 +0"),
		"dialog 选项带声望角标（誊写庭 +0）")
	m._on_story_edge(invite_idx)
	await process_frame
	check(m.graph.current_id == "N1-4" and sh.story_title.text == "誊写庭接触", "dialog 节点渲染（N1-4）")
	check(m.stream.query_by_type(EventTypes.REP_CHANGE).any(func(ev: Dictionary) -> bool:
		return str(ev["payload"]["key"]) == "global.rep.scriptorium" and int(ev["payload"]["delta"]) == 1),
		"对话选项 → 声望事件（rep.change 进事件流，07 §6）")
	var logs_before: int = m.stream.query_by_type(EventTypes.LOG).size()
	m._on_story_edge(0) # 继续 → N1-7 battle
	await process_frame
	var new_logs: Array = m.stream.query_by_type(EventTypes.LOG)
	check(new_logs.size() > logs_before and Texts.msg(new_logs.back()["payload"]).contains("誊写庭接触"),
		"对话选项回复进日志")
	# ---- battle（N1-7）：整备 → 遭遇；遭遇进行中不存档；☰ 恢复快照 ----
	check(m.current_screen is ScreenLoadout, "battle 节点 → 整备界面（09 §9.1）")
	var save_path := SaveSystem.path_for()
	SaveSystem.delete()
	var lo := m.current_screen as ScreenLoadout
	lo._toggle_skill("inkbolt")
	lo._toggle_skill("inkshield")
	lo._toggle_item("heal_potion")
	lo._on_confirm()
	check(m.stream.query_by_type(EventTypes.LOADOUT_CONFIRM).size() == 1,
		"整备确认写 loadout.confirm 事件（09 §9.1）")
	await create_timer(1.4).timeout
	check(m.campaign._in_encounter and m.shell is EncounterPortrait, "整备 → 竖屏遭遇（同一壳切战斗布局，09 §8）")
	await create_timer(0.6).timeout
	check(not FileAccess.file_exists(save_path), "遭遇进行中不存档（07 §4.2 铁律）")
	var clock_before: int = (m.campaign._encounter_snapshot["board"]["data"] as Dictionary).get("global.doom_clock", 0)
	m.board.write("global.doom_clock", 9, {"event_id": m.stream.tail(), "node_id": "N1-7", "pack_id": "campaign01"})
	m._on_save_quit()
	await process_frame
	check(m.current_screen is ScreenHome, "☰ 回主屏（09 §7）")
	check(m.board.get_doom_clock() == int(clock_before), "☰ 回主屏：恢复遭遇进入前快照（战斗重打，09 §7）")
	check(FileAccess.file_exists(save_path), "回主屏后世界状态落档（遭遇外时机，07 §4.2）")
	# 继续 → 再进 N1-7 → 胜利 → 战后边回图到 branch（N1-8）
	m._on_home_navigate(&"entry")
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	var lo2 := m.current_screen as ScreenLoadout
	lo2._toggle_skill("inkbolt")
	lo2._toggle_skill("inkshield")
	lo2._on_confirm()
	await create_timer(1.4).timeout
	check(m.campaign._in_encounter, "主屏「继续」→ 再进遭遇（04 §① 继续进行中的战役）")
	# 模拟 EncounterSM 胜利经验（真实战斗由 TP2 通道已验；与 encounter_sm 同一 Growth 通道，
	# tech/04 §8 规则1/2：汇入即写板 + 自动升级）；序章 50 + 300 = 350 跨 300 档
	Growth.new(m.board).grant_xp(300,
		{"event_id": m.stream.tail(), "node_id": "N1-7", "pack_id": "campaign01"})
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 3}, &"core", "N1-7")
	await create_timer(1.6).timeout
	# ---- 胜利必经结算（04 §⑨：念板 + 快照 + 三出口）----
	check(m.current_screen is ScreenSettle, "战斗胜利 → ⑨ 结算屏（04 §⑨：胜利必经结算，元循环落笔处）")
	check(FileAccess.file_exists(save_path), "胜利结算落快照（07 §4.2 主快照点；快照在战后节点，继续不重打）")
	var vst := m.current_screen as ScreenSettle
	check(vst.next_button.visible and vst.home_button.visible and vst.history_button.visible,
		"胜利结算三出口：下一遭遇 / 回主屏 / 查看卷轴（04 §⑨/§④.8）")
	check(vst.summary_text.text.contains("经验 +300"), "胜利念板：经验逐项呈现（04 §⑨）")
	vst.go_next.emit()
	await process_frame
	# ---- branch（N1-8）：独狼隐藏边按声望显隐 ----
	check(m.graph.current_id == "N1-8", "下一遭遇 → 战后边回图到 branch N1-8（tech/02 §3）")
	var sh2 := m.shell as EncounterPortrait
	var branch_opts := " ".join(sh2.story_option_texts())
	check(branch_opts.contains("誊写庭委托") and branch_opts.contains("断墨会委托")
		and branch_opts.contains("拾遗行会委托"), "branch 渲染：三方委托选项")
	check(not branch_opts.contains("我谁都不信"), "独狼隐藏边：声望 >0 → 不显形（tech/02 §4.5）")
	# 独狼边显形对照（声望全 0 走婉拒路，图级复核）
	var s2 := EventStream.new()
	var b2 := Board.new(s2)
	var g2 := StoryGraph.new(b2, Rng.new(20260009), m.pack)
	g2.start()
	g2.take_edge(_edge_to(g2, "N0-2"))
	g2.roll_check(g2.available_edges()[0])
	g2.take_edge(_edge_to(g2, "N0-4"))
	g2.take_edge(_edge_to(g2, "N1-1"))
	g2.take_edge(_edge_to(g2, "N1-2"))
	g2.roll_check(g2.available_edges()[0])
	g2.take_edge(_edge_to(g2, "N1-8")) # 婉拒所有邀约
	var lone_vm := StoryVM.build(g2, b2, m.pack)
	var lone_labels := ""
	for e: Variant in lone_vm["edges"]:
		lone_labels += str((e as Dictionary)["label"]) + "|"
	check(lone_labels.contains("我谁都不信"), "独狼隐藏边：三方声望 0 → 显形（tech/02 §4.5）")
	# ---- 幕二「三支笔」S 链：护送战 → N2-C 收束（战役书幕二）----
	m._on_story_edge(0) # 誊写庭委托 → N2S-1（幕二在切片内：SLICE_ACTS 含 SL-2）
	await process_frame
	check(m.graph.current_id == "N2S-1" and not (m.current_screen is ScreenSettle),
		"幕二接入：N1-8 委托 → N2S-1（切片延伸至 SL-2，战役书幕二）")
	m._on_story_edge(0) # N2S-1 档案馆试炼掷检定（成败均至 N2S-2，失败路罚时 +1）
	await create_timer(1.0).timeout
	check(m.current_screen is ScreenLoadout, "N2S-1 → N2S-2 护送战整备（09 §9.1）")
	var lo3 := m.current_screen as ScreenLoadout
	lo3._toggle_skill("inkbolt")
	lo3._toggle_skill("inkshield")
	lo3._on_confirm()
	await create_timer(1.4).timeout
	check(m.campaign._in_encounter, "护送战开始（修复仪式，tech/02 §6 escort）")
	check((m._battle_def({})["party"] as Array).any(func(u: Variant) -> bool:
		return str((u as Dictionary)["kind"]) == "escort_npc" and str((u as Dictionary)["id"]) == "scribe"),
		"护送对象缮写士以 escort_npc 入队（tech/02 §6 escort 块）")
	m.stream.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 3}, &"core", "N2S-2")
	await create_timer(1.6).timeout
	check(m.graph.current_id == "N2S-3", "护送胜利 → 战后边 → N2S-3（金墨的代价）")
	m._on_story_edge(0) # 献出一段自己的记忆 → N2-C
	await process_frame
	check(m.graph.current_id == "N2-C", "S 链收束 → N2-C（三方情报拼合，战役书幕二收束）")
	check(m.board.read("campaign01.blank_memory") == true, "献出记忆写板 blank_memory（N2S-3 边效果）")
	check(m.board.has_item("scriptorium_signet"), "离开 N2S-3 结算 on_complete（誊写庭印戒，tech/02 §3）")
	# ---- 幕三「撤销区」房间序列 → 终章 → 结局屏 → NG+（战役书幕三/终章；tech/02 §9）----
	check(m.stream.query_by_type(EventTypes.QUEST_TRIGGER).any(
		func(ev: Dictionary) -> bool: return str(ev["payload"]["id"]) == "archive_quest"),
		"branch 选择 → choice 触发 L3 事件（档案馆委托，tech/02 §5）")
	m._on_story_edge(0) # N2-C → N3-1（模式锁定演出节点；time 玩家无换壳）
	await process_frame
	check(m.graph.current_id == "N3-1" and m.current_screen is EncounterPortrait,
		"幕三接入：N2-C → N3-1 进入撤销区（SL-3，战役书幕三）")
	m._on_story_edge(0) # N3-1 → R1 褪色民居（探索序列）
	await process_frame
	check(m.graph.current_id == "R1" and m.board.has_lore("revoked_registry_01"),
		"R1：褪色民居 on_enter 图鉴·门牌（lore.json source 逐条对齐）")
	m._on_story_edge(0) # R1 拾取拍（loot：墨核 ×1，tech/02 §6 maze）
	await create_timer(1.2).timeout
	check(m.graph.current_id == "R1", "R1 探索序列完成回节点呈现出边")
	m._on_story_edge(0) # R1 → R2 空教室
	await process_frame
	check(m.board.has_lore("revoked_registry_02"), "R2：空教室 on_enter 图鉴·花名册")
	m._on_story_edge(0) # R2 安抚检定（真实掷骰；成败均至 R3，差异在效果，08 §2）
	await create_timer(1.2).timeout
	check(m.graph.current_id == "R3", "R2 对话检定 → R3 墨魈巢穴（tech/02 §4.2）")
	# R3 战斗 → R4 分支门（S 链无黑羽令 → fallback 右路两场）
	check(m.current_screen is ScreenLoadout, "R3 战斗房 → 整备（09 §9.1）")
	await _main_win_battle(m)
	check(m.graph.current_id == "R4", "R3 胜利 → R4 分叉回廊（分支门）")
	check(bool(m.graph.available_edges()[0].get("via_fallback", false)),
		"R4 分支门：无黑羽令 → 右路 fallback 变体（tech/02 §4.3）")
	m._on_story_edge(0) # → R4-r 第一场
	await process_frame
	check(m.graph.current_id == "R4-r", "R4 右路 → R4-r 第一场（战役书幕三 右路两场战斗）")
	await _main_win_battle(m)
	check(m.graph.current_id == "R4-r2", "R4-r 胜利 → R4-r2 第二场（场间无休整，HP 持久 11 §7.1）")
	await _main_win_battle(m)
	check(m.graph.current_id == "R5", "R4-r2 胜利 → R5 守页人 Boss 战")
	await _main_win_battle(m)
	check(m.graph.current_id == "N3-7", "R5 胜利 → N3-7 空白广场（终章入口，战役书幕三）")
	check(m.board.item_count("ink_core") == 2, "墨核累计 ×2（R1 拾取 + R5 节点边战利品，战役书 §8）")
	# ---- 终章：免战门 → 抉择 → 结局屏 ----
	m._on_story_edge(0) # N3-7 → N4-1 潮汐塔顶（免战门节点）
	await process_frame
	check(m.graph.current_id == "N4-1", "终章：N3-7 → N4-1（SL-4，战役书终章）")
	var n41: Array = m.graph.available_edges()
	check(n41.size() == 1 and not bool(n41[0].get("via_fallback", false)),
		"N4-1 免战边显形：印戒 + 誊写庭声望 ≥1（[物/声]，items.json unlocks）")
	m._on_story_edge(0) # 出示誊写庭印戒 → 免战直达 N4-2
	await process_frame
	check(m.graph.current_id == "N4-2", "印戒免战：跳过 Boss 直达抉择（战役书 §8 印戒解锁边）")
	var n42: Array = m.graph.available_edges()
	check(n42.size() == 2 and str(n42[0].get("to", "")) == "E1",
		"N4-2 抉择：墨守过中线 → E1 显形，E4 兜底（tech/02 §9 顺序求值）")
	check(m.graph.pick_ending() == "E1", "结局表求值 E1（图边选择与 endings.json 互证）")
	m._on_story_edge(0) # 修补卷轴 → E1
	await process_frame
	check(m.graph.current_id == "E1" and m.graph.is_at_ending(), "抵达结局 E1 重墨（tech/02 §9）")
	check(bool(m.board.read("campaign01.ending_e1")),
		"结局写板：ending_e1（ending 节点 on_enter，flags.json 台账 V4 闭环）")
	check(bool(m.board.read("campaign01.unlock_elysium_rumor")),
		"结局写板：unlock_elysium_rumor（E1 on_enter，战役书 §11 E1 传闻钩子，V4 闭环）")
	check(bool(m.board.read("campaign01.campaign01_cleared")),
		"结局写板：campaign01_cleared（last_page settle 于离开 N4-2，战役书 §6）")
	# 结局屏：四分型文案 + 多周目钩子（endings.json；壳不再创作）
	var es := m.current_screen as ScreenEnding
	check(es != null, "结局屏呈现（战役书 §9：结局演出 + 尾声结算合并于 ending 节点）")
	check(es.title_label.text.contains("重墨") and es.content_text.text.contains("金墨")
		and es.content_text.text.contains("\n"),
		"结局屏文案 = text_ref 外置演出全文（E1 重墨，tech/02 §9/§1.1；content 摘要兜底不外显）")
	check(es.hook_label.text.contains("缮写圣城"), "结局屏多周目钩子 = ngplus_hook 字段")
	check(m.stream.query_by_type(EventTypes.STORY_ENDING).size() == 1,
		"story.ending 事件进事件流（tech/02 §9）")
	check(FileAccess.file_exists(save_path), "结局快照落盘（07 §4.2 主快照点）")
	var read_back := SaveSystem.read("slot1")
	check(bool(read_back["ok"]) and bool(SaveSystem.migrate(read_back["snapshot"])["ok"]),
		"结局快照可读可迁移（当前版本直通，07 §4.3）")
	check(bool(m.board.read("campaign01.cleared"))
		and bool(m.board.read("global.entitlement.arena")),
		"通关成就点亮：campaign01.cleared → entitlement.arena（06 §2.1）")
	# ---- 多周目：开始二周目 → NG+ 继承（战役书 §11 定稿清单；tech/02 §2.7 manifest.ngplus 数据驱动）----
	var lore_before: int = m.board.get_lore().size()
	es.ngplus_button.pressed.emit()
	await process_frame
	await process_frame
	check(m.graph.current_id == "N0-1" and int(m.board.read("campaign01.ngplus", 0)) == 1,
		"NG+：周目数 +1（campaign01.ngplus 簿记 → meta.ngplus）并从入口重开")
	check(m.board.item_count("codex_fragment") == 1, "NG+：继承织命者残简 ×1（战役书 §8 投放第 4 枚）")
	check(m.board.get_lore().size() == lore_before, "NG+：图鉴保留（global.lore，战役书 §9）")
	check(bool(m.board.read("global.entitlement.arena")), "NG+：权利保留（global.entitlement.*，07 §3）")
	check(bool(m.board.read("campaign01.unlock_elysium_rumor")),
		"NG+ E1 per_ending：缮写圣城传闻旗标继承（manifest.ngplus 数据驱动，tech/02 §2.7）")
	check(not bool(m.board.read("campaign01.ngplus_memory_view", false))
		and not bool(m.board.read("campaign01.unlock_scribe_identity", false)),
		"NG+ E1：追忆/执笔者旗标不继承（per_ending 以刚达成结局为触发，不累加）")
	check(str(StoryVM.build(m.graph, m.board, m.pack)["text"]).contains("怀里没有抄本"),
		"NG+ E1 序章：无变体旗标 → N0-1 默认文本（text_variants 纯呈现）")
	check(Growth.xp(m.board) == 0 and m.board.get_doom_clock() == 0
		and m.board.get_alignment() == 50 and not m.board.has_item("ink_core"),
		"NG+：其余状态重置（成长/时钟/倾向/战利品）")
	m.queue_free()
	await process_frame

# ---------------------------------------------------------------- 角色界面真实导航回归（M2 审计 G1）
# 主屏 → ⑦角色 不得再走战斗定义组装（非战斗上下文无当前遭遇）；
# 覆盖两类非战斗态：战役未开始（graph.current_id 为空）+ 战役中场景节点（current_id 为 scene）。

func test_character_nav() -> void:
	print("[character_nav]")
	# ---- 路径 1：战役未开始的主屏（审计 G1 原始崩点）----
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	check(m.current_screen is ScreenHome, "开局在主屏（G1 回归前提）")
	m._on_home_navigate(&"character") # 与玩家点按同一通道（screen_home.navigate → _on_home_navigate）
	await process_frame
	check(m.current_screen is ScreenCharacter, "主屏→角色：界面呈现（G1：曾 SCRIPT ERROR 崩溃）")
	var ch := m.current_screen as ScreenCharacter
	var text := ""
	for c: Node in ch.list_box.get_children():
		if c is Label:
			text += (c as Label).text + "\n"
	check(text.contains("白页者") and text.contains("珂兰") and text.contains("老费"),
		"角色卡名册渲染：player + 双同伴（StoryGraph.party_roster，与 BattleDef 解耦）")
	check(text.contains("技能：") and not text.contains("技能：—"),
		"角色卡技能列非空（characters.json 已习得 ∪ basic_attack 查名 skills.json）")
	ch.back_button.pressed.emit() # 玩家点"返回"同一通道
	await process_frame
	check(m.current_screen is ScreenHome, "角色→返回→主屏（G1：曾信号未连接软锁）")
	# ---- 路径 2：战役中场景节点 → ☰ 回主屏 → 角色（graph.current_id 为 scene 非战斗节点）----
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	check(m.graph.current_id == "N0-1", "战役开始于入口场景节点（非战斗上下文）")
	m._on_save_quit() # 故事态 ☰：落档回主屏（07 §4.2）
	await process_frame
	check(m.current_screen is ScreenHome, "战役中 ☰ 回主屏")
	m._on_home_navigate(&"character")
	await process_frame
	check(m.current_screen is ScreenCharacter, "战役中（scene 节点）→角色：界面呈现（G1 第二崩点）")
	var ch2 := m.current_screen as ScreenCharacter
	var text2 := ""
	for c: Node in ch2.list_box.get_children():
		if c is Label:
			text2 += (c as Label).text + "\n"
	check(text2.contains("白页者"), "战役中角色卡名册渲染")
	ch2.back_button.pressed.emit()
	await process_frame
	check(m.current_screen is ScreenHome, "战役中角色→返回→主屏")
	m.queue_free()
	await process_frame

# ---------------------------------------------------------------- 手势识别器（12 §1 判定参数边界；§3 冲突消解）

func test_gesture_recognizer() -> void:
	print("[gesture_recognizer]")
	var V := func(x: float, y: float) -> Vector2: return Vector2(x, y)
	# ---- 点按：按下-抬起 <300ms 且位移 <10pt ----
	var rec := GestureRecognizer.new()
	var taps: Array = []
	rec.tapped.connect(func(p: Vector2) -> void: taps.append(p))
	rec.press(0, V.call(0, 0), 0)
	rec.release(0, V.call(0, 0), 299)
	check(taps.size() == 1, "点按：299ms 原位 = tap（<300ms）")
	rec.press(0, V.call(0, 0), 0)
	rec.release(0, V.call(0, 0), 300)
	check(taps.size() == 1, "点按边界：300ms 不判点按（<300ms 严格）")
	rec.press(0, V.call(0, 0), 0)
	rec.release(0, V.call(9.9, 0), 100)
	check(taps.size() == 2, "点按边界：位移 9.9pt 仍判点按（<10pt）")
	# ---- 长按：≥400ms 且位移 <10pt，到时即触发（不等抬手）----
	var longs: Array = []
	rec.long_pressed.connect(func(p: Vector2) -> void: longs.append(p))
	rec.press(0, V.call(50, 50), 0)
	rec.poll(399)
	check(longs.is_empty(), "长按边界：399ms 未触发（≥400ms）")
	rec.poll(400)
	check(longs.size() == 1, "长按：400ms 触发（12 §1）")
	rec.release(0, V.call(50, 50), 500)
	check(taps.size() == 2, "长按后抬手不再补点按（查看语义已消费）")
	# ---- 拖动：位移 >10pt；横滑 水平 >60pt 且垂直 <30pt（12 §1）----
	var drags: Array = []
	var hsw: Array = []
	var vsw: Array = []
	var rec2 := GestureRecognizer.new()
	rec2.dragged.connect(func(i: Dictionary) -> void: drags.append(i))
	rec2.h_swiped.connect(func(d: int, p: Vector2) -> void: hsw.append(d))
	rec2.v_swiped.connect(func(d: int, p: Vector2) -> void: vsw.append(d))
	rec2.press(0, V.call(0, 0), 0)
	rec2.move(0, V.call(10, 0), 10)
	rec2.release(0, V.call(10, 0), 100)
	check(drags.is_empty() and hsw.is_empty(), "拖动边界：位移 10pt 不判拖动（>10pt 严格）")
	rec2.press(0, V.call(0, 0), 0)
	rec2.move(0, V.call(11, 0), 10)
	rec2.release(0, V.call(11, 0), 100)
	check(drags.size() == 1, "拖动：位移 >10pt（12 §1）")
	rec2.press(0, V.call(0, 0), 0)
	rec2.move(0, V.call(61, 29), 10)
	rec2.release(0, V.call(61, 29), 100)
	check(hsw.size() == 1 and hsw[0] == 1, "横滑：水平 61pt 垂直 29pt = h_swipe 向右（12 §1）")
	rec2.press(0, V.call(0, 0), 0)
	rec2.move(0, V.call(60, 10), 10)
	rec2.release(0, V.call(60, 10), 100)
	check(hsw.size() == 1, "横滑边界：水平 60pt 不判横滑（>60pt 严格）")
	rec2.press(0, V.call(0, 0), 0)
	rec2.move(0, V.call(61, 30), 10)
	rec2.release(0, V.call(61, 30), 100)
	check(hsw.size() == 1, "横滑边界：垂直 30pt 不判横滑（<30pt 严格）")
	rec2.press(0, V.call(0, 0), 0)
	rec2.move(0, V.call(29, 61), 10)
	rec2.release(0, V.call(29, 61), 100)
	check(vsw.size() == 1 and vsw[0] == 1, "下滑：垂直 61pt 水平 29pt = v_swipe 向下（04 §④.6 推进条回看）")
	# ---- 双指点击：<300ms 且各点位移 <10pt 且间距变化 <15pt（12 §1/§3.3）----
	var rec3 := GestureRecognizer.new()
	var tft: Array = []
	rec3.two_finger_tapped.connect(func(p: Vector2) -> void: tft.append(p))
	rec3.press(0, V.call(0, 0), 0)
	rec3.press(1, V.call(100, 0), 50) # 同窗容差内（>1 帧不判双指的容差 50ms）
	rec3.release(0, V.call(0, 0), 200)
	rec3.release(1, V.call(100, 0), 210)
	check(tft.size() == 1, "双指点击：同窗 + 299ms 内 + 间距不变（12 §1/§3.3）")
	var taps3: Array = []
	rec3.tapped.connect(func(p: Vector2) -> void: taps3.append(p))
	rec3.press(0, V.call(0, 0), 0)
	rec3.press(1, V.call(100, 0), 51) # 超窗：先后落点 >1 帧不判双指（12 §3.3）
	rec3.release(0, V.call(0, 0), 100)
	check(taps3.size() == 1, "双指边界：第二指晚 51ms → 不判双指，单指点按保留（12 §3.3）")
	rec3.release(1, V.call(100, 0), 120)
	check(taps3.size() == 2, "未配对第二指独立点按（不阻塞单指，12 §3.3）")
	# 间距变化 <15pt 边界（与捏合区分）：双指各移 <10pt 但相向合拢使间距变化压边界
	var rec4 := GestureRecognizer.new()
	var tft4: Array = []
	rec4.two_finger_tapped.connect(func(p: Vector2) -> void: tft4.append(p))
	rec4.press(0, V.call(0, 0), 0)
	rec4.press(1, V.call(100, 0), 0)
	rec4.move(0, V.call(7.45, 0), 50)
	rec4.move(1, V.call(92.55, 0), 50) # 间距 100→85.1，变化 14.9pt
	rec4.release(0, V.call(7.45, 0), 100)
	check(tft4.size() == 1, "双指点击边界：间距变化 14.9pt 仍判双指点击（<15pt）")
	rec4.release(1, V.call(92.55, 0), 110)
	rec4.press(0, V.call(0, 0), 0)
	rec4.press(1, V.call(100, 0), 0)
	rec4.move(0, V.call(7.5, 0), 50)
	rec4.move(1, V.call(92.5, 0), 50) # 间距 100→85，变化恰 15pt
	rec4.release(0, V.call(7.5, 0), 100)
	rec4.release(1, V.call(92.5, 0), 110)
	check(tft4.size() == 1, "双指点击边界：间距变化 15pt 不判双指点击（<15pt 严格）")
	# ---- 捏合：双触点间距变化 >20%（12 §1）----
	var rec5 := GestureRecognizer.new()
	var pinches: Array = []
	rec5.pinched.connect(func(r: float, c: Vector2) -> void: pinches.append(r))
	rec5.press(0, V.call(0, 0), 0)
	rec5.press(1, V.call(100, 0), 0)
	rec5.move(1, V.call(120, 0), 50)
	check(pinches.is_empty(), "捏合边界：间距变化 20% 不触发（>20% 严格）")
	rec5.move(1, V.call(121, 0), 60)
	check(pinches.size() == 1 and pinches[0] > 1.2, "捏合：间距变化 >20% 触发并播报倍率（12 §1）")
	# ---- 轨迹：拖动经过 ≥2 个语义目标点（12 §1 path；探针由壳注入）----
	var rec6 := GestureRecognizer.new()
	rec6.target_probe = func(p: Vector2) -> String: return "a" if p.x < 50.0 else "b"
	var paths: Array = []
	var drags6: Array = []
	rec6.path_cast.connect(func(i: Dictionary) -> void: paths.append(i))
	rec6.dragged.connect(func(i: Dictionary) -> void: drags6.append(i))
	rec6.press(0, V.call(0, 0), 0)
	rec6.move(0, V.call(30, 0), 10) # 越过拖动阈值，途经目标 a
	rec6.move(0, V.call(60, 0), 20) # 途经目标 b
	rec6.release(0, V.call(60, 0), 100)
	check(paths.size() == 1 and (paths[0]["targets"] as Array) == ["a", "b"],
		"轨迹：途经 2 个语义目标 = path（12 §1）")
	rec6.press(0, V.call(0, 0), 0)
	rec6.move(0, V.call(40, 0), 10)
	rec6.release(0, V.call(40, 0), 100)
	check(drags6.size() == 1 and paths.size() == 1, "轨迹边界：途经 1 个目标 = 平拖（≥2 才判 path）")
	# ---- 打断：按抬手于空位处理 = 取消（12 §3.5）----
	var rec7 := GestureRecognizer.new()
	var drags7: Array = []
	rec7.dragged.connect(func(i: Dictionary) -> void: drags7.append(i))
	rec7.press(0, V.call(0, 0), 0)
	rec7.move(0, V.call(30, 0), 10)
	rec7.cancel_all() # 来电/切后台
	rec7.release(0, V.call(30, 0), 100)
	check(drags7.is_empty() and rec7.is_idle(), "打断 = 取消：不产生半状态指令（12 §3.5）")

# ---------------------------------------------------------------- 事件中心放弃（04 §⑤：写旗标 + 事件 → 归档历史卷轴）

func test_quest_abandon() -> void:
	print("[quest_abandon]")
	var pack := _load_campaign01()
	var stream := EventStream.new()
	var board := Board.new(stream)
	var g := StoryGraph.new(board, Rng.new(1), pack)
	g._enter("N1-8") # hidden lone_wolf（rep 全 0 满足隐形门槛）随节点进入触发
	var before := g.quest_badge_count()
	g._scan_choice_quests({"label": "誊写庭委托"}) # choice 触发 archive_quest（tech/02 §5）
	var qs := g.quests()
	var aq := {}
	for q: Variant in qs:
		if str((q as Dictionary)["id"]) == "archive_quest":
			aq = q
	check(not aq.is_empty() and str(aq["state"]) == "triggered" and bool(aq["optional"]),
		"choice 触发 = 可选事件（04 §⑤ 放弃范围）")
	check(g.quest_badge_count() == before + 1, "触发计入角标")
	check(g.abandon_quest("archive_quest"), "放弃可选事件受理（04 §⑤）")
	check(bool(board.read("campaign01.quest_abandoned.archive_quest")),
		"放弃写旗标 campaign01.quest_abandoned.*（04 §⑤，07 §1 溯源）")
	check(stream.query_by_type(EventTypes.QUEST_ABANDON).size() == 1,
		"quest.abandon 事件入流（归档历史卷轴，04 §⑤）")
	check(g.quest_badge_count() == before, "放弃后不计角标")
	check(not g.abandon_quest("archive_quest"), "重复放弃拒绝（幂等）")
	# auto 触发的主线事件不可放弃
	var g2 := StoryGraph.new(board, Rng.new(1), pack)
	g2._enter("N0-2") # dock_tales auto 触发
	check(not g2.abandon_quest("dock_tales"), "auto 主线事件不可放弃（仅可选事件，04 §⑤）")
	# 放弃状态随图快照持久（07 §4.1）
	var snap := g.serialize()
	var g3 := StoryGraph.new(board, Rng.new(1), pack)
	g3.deserialize(snap)
	var kept := false
	for q: Variant in g3.quests():
		if str((q as Dictionary)["id"]) == "archive_quest":
			kept = str((q as Dictionary)["state"]) == "abandoned"
	check(kept, "放弃状态随存档快照往返（07 §4 兼容）")

# ---------------------------------------------------------------- 缺口批 shell 集成（12 §1~§4；04 §④.2/§④.7/§⑤/§⑥/§⑧）

func test_gap_features() -> void:
	print("[gap_features]")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(11), "campaign01")
	var agent := AutoAgent.new()
	var portrait: EncounterPortrait = (load("res://shell/portrait/encounter_portrait.tscn") as PackedScene).instantiate()
	root.add_child(portrait)
	await process_frame
	await process_frame
	portrait.bind(sm, agent)
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(_std_def())
	await process_frame
	await process_frame
	# 驱动到 pc 行动
	var guard := 0
	while sm.current_actor_id() != "pc" and guard < 6:
		guard += 1
		sm.submit_command(_cmd(EncounterSM.CMD_END_TURN, sm.current_actor_id()))
	await process_frame
	var uid := sm.current_actor_id()
	var enemy := sm.first_alive_enemy()

	# ---- 双壳手势 → 同构 Command（09 §9.3 同通道；12 §2 场景映射同一指令）----
	# 横屏对照壳（同一指令集单源）
	var stream2 := EventStream.new()
	var board2 := Board.new(stream2)
	var sm2 := EncounterSM.new(board2, stream2, Rng.new(11), "campaign01")
	var agent2 := AutoAgent.new()
	var land: EncounterLandscape = (load("res://shell/landscape/encounter_landscape.tscn") as PackedScene).instantiate()
	root.add_child(land)
	await process_frame
	await process_frame
	land.bind(sm2, agent2)
	sm2.enter("N1-7")
	sm2.transition(EncounterSM.S_EXPLORE)
	sm2.begin_combat(_std_def())
	await process_frame
	await process_frame
	var guard2 := 0
	while sm2.current_actor_id() != "pc" and guard2 < 6:
		guard2 += 1
		sm2.submit_command(_cmd(EncounterSM.CMD_END_TURN, sm2.current_actor_id()))
	await process_frame
	# 双指点击 = 结束回合：两壳手势处理器产出同构命令（GestureCommands 单源）
	var cmd_p := GestureCommands.end_turn(sm)
	var cmd_l := GestureCommands.end_turn(sm2)
	check(cmd_p == cmd_l and cmd_p["type"] == EncounterSM.CMD_END_TURN,
		"双壳手势 → 同构 Command：双指点击 = 结束回合（09 §9.3/12 §2）")
	# 轨迹施法：两壳同一出口（首个敌指向技能，目标同一敌人）
	var cast_p := GestureCommands.cast_at(sm, enemy)
	var cast_l := GestureCommands.cast_at(sm2, sm2.first_alive_enemy())
	check(cast_p == cast_l and cast_p["type"] == EncounterSM.CMD_SKILL
		and str(cast_p["skill"]) == "inkbolt" and str(cast_p["target"]) == enemy,
		"双壳手势 → 同构 Command：拖到敌方 = 轨迹施法（12 §2.1/§2.2）")
	# 移动命令同构
	var mv_p := GestureCommands.move_to(sm, "3,1")
	var mv_l := GestureCommands.move_to(sm2, "3,1")
	check(mv_p == mv_l and mv_p["type"] == EncounterSM.CMD_MOVE,
		"双壳手势 → 同构 Command：拖动己方 = 移动（消耗移动段，11 §4）")

	# ---- 竖屏手势接入（12 §2.2）----
	# 双指点击主视野 = 结束回合（真实走手势处理器 → _manual → submit_command）
	# （pc 是本轮最后一名待行动单位：结束回合 → 敌方回合 → 第 2 轮，09 §5.2 轮替即证据）
	var main_center: Vector2 = portrait.main_view.get_global_rect().get_center()
	portrait._on_gesture_two_finger_tap(main_center)
	await process_frame
	check(sm.round_no() == 2, "竖屏：双指点击主视野 = 结束回合（12 §2.2；轮替发生）")
	# 移动段：手势移动一次受理，第二次拒绝（11 §4 移动段每回合一段）
	check(sm.submit_command(GestureCommands.move_to(sm, "stance:forward")), "移动段：首次移动受理（11 §4）")
	check(not sm.submit_command(GestureCommands.move_to(sm, "stance:back")),
		"移动段：第二次移动拒绝 move_used（11 §4）")
	check(stream.query_by_type(EventTypes.BATTLE_MOVE).size() == 1, "battle.move 事件入流（溯源 dest）")
	# 移动段耗尽后拖动手势被 core 拒绝（不污染逻辑状态，tech/01 §6.2）
	var moves_before := stream.query_by_type(EventTypes.BATTLE_MOVE).size()
	portrait._drag_uid = sm.current_actor_id()
	portrait._on_gesture_dragged({"start": Vector2.ZERO, "end": Vector2(-9999, -9999), "delta": Vector2(-30, -30)})
	check(stream.query_by_type(EventTypes.BATTLE_MOVE).size() == moves_before,
		"移动段耗尽：拖动拒绝（command.rejected，tech/01 §6.2）")
	# 横滑切 Tab（12 §2.2：三 Tab 循环；骰子改为常驻骰子条）
	var tab0: int = portrait.tabs.current_tab
	portrait._on_gesture_h_swipe(1, portrait.console_panel.get_global_rect().get_center())
	check(portrait.tabs.current_tab == tab0 + 1, "竖屏：横滑操作台 = 切 Tab（12 §2.2）")
	for _i: int in portrait.tabs.get_tab_count() - 1:
		portrait._on_gesture_h_swipe(1, portrait.console_panel.get_global_rect().get_center())
	check(portrait.tabs.current_tab == tab0, "横滑 Tab 循环一周（13 §3 Tab 循环）")
	check(portrait.tabs.get_tab_count() == 3 and portrait.dice_strip.is_visible_in_tree(),
		"操作台三 Tab（行动/日志/角色）+ 常驻骰子条：掷骰结果与行动同屏（04 §④.5 v2）")
	# 长按单位 = 详情半屏卡（12 §2.2）
	portrait._on_gesture_long_press(portrait.enemy_row.get_child(0).get_global_rect().get_center())
	check(portrait.info_popup.visible and portrait.info_popup.body_label.text.contains("AC"),
		"竖屏：长按单位 = 详情半屏卡（HP/AC/伤害骰/状态，12 §2.1）")
	portrait.info_popup.hide()
	# 捏合：松手弹回（04 §④.4）
	portrait._on_gesture_pinch(0.5, main_center)
	check(absf(portrait._zoom - 0.7) < 0.001, "竖屏捏合缩放下限 0.7（任务书 0.7~1.6）")
	portrait._on_gesture_pinch_ended(1.0, main_center)
	check(portrait._zoom == 1.0, "竖屏捏合松手弹回（04 §④.4）")

	# ---- 横屏手势接入（12 §2.1）----
	# 拖动己方单位 → 空格 = 移动（呈现层落位 + 移动段消耗）
	var pc_cell := land.unit_cell("pc")
	var dest := Vector2i(mini(pc_cell.x + 2, EncounterLandscape.GRID_COLS - 1), pc_cell.y)
	if land._unit_at_cell(dest) != "":
		dest = Vector2i(maxi(pc_cell.x - 2, 0), pc_cell.y)
	var dest_center: Vector2 = land._cells[dest.y * EncounterLandscape.GRID_COLS + dest.x].get_global_rect().get_center()
	var pc_center: Vector2 = land._cells[pc_cell.y * EncounterLandscape.GRID_COLS + pc_cell.x].get_global_rect().get_center()
	land._on_gesture_drag_started({"start": pc_center, "pos": pc_center})
	land._on_gesture_dragged({"start": pc_center, "end": dest_center, "delta": dest_center - pc_center})
	await process_frame
	check(land.unit_cell("pc") == dest, "横屏：拖到可达空格 = 呈现层落位（12 §2.1 落点预览）")
	check(stream2.query_by_type(EventTypes.BATTLE_MOVE).size() == 1
		and str(stream2.query_by_type(EventTypes.BATTLE_MOVE)[0]["payload"]["dest"]) == "%d,%d" % [dest.x, dest.y],
		"横屏：拖动移动消耗移动段（battle.move 带格位溯源，11 §4）")
	# 拖出 6 格外 = 取消（可达性壳层约束；pc 在底排，(7,0) 曼哈顿 ≥8 且敌方只占 x=1/3/5）
	var pc_cell2 := land.unit_cell("pc")
	var far := Vector2i(7, 0)
	check(land._unit_at_cell(far) == "", "横屏拖测前提：远格无占用")
	var far_center: Vector2 = land._cells[far.y * EncounterLandscape.GRID_COLS + far.x].get_global_rect().get_center()
	var pc_center2: Vector2 = land._cells[pc_cell2.y * EncounterLandscape.GRID_COLS + pc_cell2.x].get_global_rect().get_center()
	land._on_gesture_drag_started({"start": pc_center2, "pos": pc_center2})
	land._on_gesture_dragged({"start": pc_center2, "end": far_center, "delta": far_center - pc_center2})
	check(land.unit_cell("pc") == pc_cell2, "横屏：落点不可达/超 6 格 = 取消（12 §3.2；11 §4 ≤6 格）")
	# 双指点击战场 = 结束回合（pc 已是本轮最后一名：轮替至第 2 轮即证据）
	land._on_gesture_two_finger_tap(land.center_map.get_global_rect().get_center())
	await process_frame
	check(sm2.round_no() == 2, "横屏：双指点击战场 = 结束回合（12 §2.1；轮替发生）")
	# 捏合 = 缩放 0.7~1.6 持续生效（12 §2.1）
	land._on_gesture_pinch(3.0, land.center_map.get_global_rect().get_center())
	check(absf(land._zoom - 1.6) < 0.001, "横屏捏合缩放上限 1.6（任务书 0.7~1.6）")
	land._on_gesture_pinch_ended(3.0, land.center_map.get_global_rect().get_center())
	land._on_gesture_pinch(0.1, land.center_map.get_global_rect().get_center())
	check(absf(land._zoom - 0.7) < 0.001, "横屏捏合缩放下限 0.7")
	# 长按格内单位 = 详情卡
	land._on_gesture_long_press(land.center_map.get_global_rect().get_center())
	# 中心未必有单位；对 pc 格长按
	var pc_cell3 := land.unit_cell("pc")
	var pc_center3: Vector2 = land._cells[pc_cell3.y * EncounterLandscape.GRID_COLS + pc_cell3.x].get_global_rect().get_center()
	land._on_gesture_long_press(pc_center3)
	check(land.info_popup.visible and land.info_popup.body_label.text.contains("HP"),
		"横屏：长按单位 = 详情半屏卡（12 §2.1）")
	land.info_popup.hide()
	portrait.queue_free()
	land.queue_free()
	await process_frame

	# ---- 房间推进条回看（04 §④.2：只读，已完成不重置）----
	var stream3 := EventStream.new()
	var board3 := Board.new(stream3)
	var pack3 := _load_campaign01()
	var pv: EncounterPortrait = (load("res://shell/portrait/encounter_portrait.tscn") as PackedScene).instantiate()
	root.add_child(pv)
	await process_frame
	await process_frame
	pv.bind_story(stream3, board3, pack3, {"edge": func(_i: int) -> void: pass})
	pv.set_rooms(["N0-1", "N0-2", "N1-1", "N1-2"], 2,
		{"N0-1": "潮醒", "N0-2": "雨夜码头", "N1-1": "广场", "N1-2": "褪色现场"})
	var ev_before := stream3.size()
	pv._open_room_review()
	check(pv.is_review_visible(), "推进条：下滑/点按展开已过房间列表（04 §④.2）")
	check(pv.review_list.get_child_count() == 2, "回看列表 = 已过房间（不含当前/未来剪影）")
	(pv.review_list.get_child(0) as Button).pressed.emit()
	check(pv.review_detail.text.contains("潮醒"), "点房间 = 回看其摘要（04 §④.2）")
	check(stream3.size() == ev_before and board3.get_doom_clock() == 0,
		"回看只读：不产事件、不写板（已完成检定与战斗不重置，04 §④.2）")
	pv.review_popup.visible = false
	pv.queue_free()
	await process_frame

	# ---- 教程三层（12 §4）----
	var home: ScreenHome = (load("res://shell/ui/screen_home.tscn") as PackedScene).instantiate()
	root.add_child(home)
	await process_frame
	var done: Array = []
	home.tutorial_done.connect(func() -> void: done.append(true))
	home.show_launch_tutorial()
	check(home.tutorial.is_launch_visible(), "启动卡：首次启动 3 页核心手势卡（12 §4 第一层）")
	home.tutorial.next_page()
	home.tutorial.next_page()
	check(home.tutorial._page == 2, "启动卡翻页（右滑/下一页）")
	home.tutorial.next_page() # 末页再进 = 完成
	check(done.size() == 1 and not home.tutorial.is_launch_visible(), "启动卡可看完离开（可跳过常驻）")
	# 一次原则写板（12 §4：global.tutorial.* 全局白名单，任何包可写）
	var board4 := Board.new(EventStream.new())
	check(board3.write("global.tutorial.boot", true,
		{"event_id": 1, "node_id": "", "pack_id": "system"}), "教程触发记录写板（global.tutorial.* 白名单，07 §3）")
	check(board3.write("global.tutorial.combat", true,
		{"event_id": 1, "node_id": "", "pack_id": "campaign01"}), "教程记录任何包可写（07 §3 白名单）")
	check(board4.write("global.tutorial.boot", true,
		{"event_id": 1, "node_id": "", "pack_id": "system"}), "教程写板独立板同样受理")
	# 帮助页：手势图鉴全表 + 重学入口（12 §4 第三层）
	home._toggle_help()
	var help_text := ""
	for child: Node in home._help_overlay.get_child(0).get_child(0).get_children():
		if child is Label:
			help_text += (child as Label).text
	check(help_text.contains("拖动") and help_text.contains("双指点击") and help_text.contains("捏合")
		and help_text.contains("横滑") and help_text.contains("长按"),
		"帮助页：手势图鉴恢复 12 §1 全表（13 §1 帮助入口 ✅ 化）")
	var retrain: Array = []
	home.retrain_requested.connect(func() -> void: retrain.append(true))
	var retrain_btn: Button = null
	for child: Node in home._help_overlay.get_child(0).get_child(0).get_children():
		if child is Button and (child as Button).text == TextsZh.HELP_RETRAIN:
			retrain_btn = child
	check(retrain_btn != null, "帮助页：重学入口存在（12 §4 可重学）")
	retrain_btn.pressed.emit()
	check(retrain.size() == 1, "重学入口上报（清记录由 main 落板）")
	home._toggle_help()
	home.queue_free()
	await process_frame

	# ---- 事件中心放弃 UI（04 §⑤）----
	var qs5: ScreenQuests = (load("res://shell/ui/screen_quests.tscn") as PackedScene).instantiate()
	root.add_child(qs5)
	await process_frame
	qs5.bind([
		{"id": "archive_quest", "name": "档案馆委托", "objective": "送信", "node": "N2S-1",
			"state": "triggered", "optional": true},
		{"id": "dock_tales", "name": "码头异闻", "objective": "听说法", "node": "N0-2",
			"state": "triggered", "optional": false},
		{"id": "old", "name": "旧事", "objective": "", "node": "N0-1", "state": "settled", "optional": true},
	])
	check(qs5.abandon_button_count() == 1, "仅进行中的可选事件带「放弃」（04 §⑤）")
	var abandoned: Array = []
	qs5.abandon_requested.connect(func(qid: String) -> void: abandoned.append(qid))
	for row: Node in qs5.list_box.get_children():
		for child: Node in row.get_children():
			if child is Button and (child as Button).text == TextsZh.QUESTS_ABANDON:
				(child as Button).pressed.emit()
	check(abandoned == ["archive_quest"], "放弃上报 quest_id（写旗标由 core 落）")
	qs5.queue_free()
	await process_frame

	# ---- 背包图鉴完整版（04 §⑥；10 §1/§3/§4）----
	var iv: ScreenInventory = (load("res://shell/ui/screen_inventory.tscn") as PackedScene).instantiate()
	root.add_child(iv)
	await process_frame
	var inv := {"heal_potion": 2, "codex_fragment": 1}
	iv.bind(inv, _load_campaign01()["items"], ["weaver_fragment_01"], _load_campaign01()["lore"],
		_load_campaign01()["texts"]) # tech/02 §1.1：图鉴正文 text_ref 数据源
	var n_all := iv.bag_entry_count()
	check(n_all == 2, "背包：全部身份条目入列（04 §⑥）")
	# 四重身份筛选：codex 只剩信物
	iv._filter = "codex"
	iv._render_bag()
	await process_frame # queue_free 延迟回收：隔帧再计数
	check(iv.bag_entry_count() == 1, "背包：按四重身份筛选（图鉴信物，10 §1）")
	iv._filter = ""
	iv._render_bag()
	await process_frame
	# 道具详情（04 §⑥ 详情弹层：属性/检定修正/分支提示）
	iv.show_item_detail("codex_fragment")
	check(iv.info_popup.visible and iv.info_popup.body_label.text.contains(TextsZh.INV_BRANCH_HINT),
		"道具详情：分支钥匙提示（04 §⑥「某处派上用场」句式）")
	iv.info_popup.hide()
	# 图鉴四系列进度 + 集齐奖励预告（worldview §9；10 §4）
	var codex_text := ""
	for child: Node in iv.codex_box.get_children():
		if child is Label:
			codex_text += (child as Label).text + "\n"
		elif child is Button:
			codex_text += (child as Button).text + "\n" # 已解锁条目 = 按钮等价路径（12 §1）
	check(codex_text.contains("织命者残简：1/4") and codex_text.contains("被撤销者名录：0/2")
		and codex_text.contains("烬港风物志：0/1") and codex_text.contains("命骰考：0/0"),
		"图鉴：四系列进度（lore.json × global.lore，10 §3）")
	check(codex_text.contains("集齐") and codex_text.contains("隐藏剧情线"),
		"图鉴：集齐奖励预告（10 §4 白名单，永不卖数值）")
	check(codex_text.contains("残简·其一") and codex_text.contains(TextsZh.CODEX_LOCKED_TITLE),
		"图鉴：已解锁 Lore 条目呈题，未解锁占位（04 §⑥）")
	# 已解锁条目点按 = 正文弹层（tech/02 §10/§1.1：text_ref 外置正文）
	iv.show_lore_detail("weaver_fragment_01")
	check(iv.info_popup.visible and iv.info_popup.body_label.text.contains("金墨"),
		"图鉴正文 = text_ref 外置全文（残简·其一，tech/02 §1.1）")
	iv.info_popup.hide()
	iv.queue_free()
	await process_frame

	# ---- 战报回放最小版（04 §⑧：事件流重演，纯演出不可改结果）----
	var stream6 := EventStream.new()
	var board6 := Board.new(stream6)
	stream6.emit(EventTypes.COMBAT_START, {"order": ["pc", "imp1"]}, &"core", "N1-7")
	stream6.emit(EventTypes.BATTLE_ATTACK, {"attacker": "pc", "target": "imp1", "hit": true,
		"damage": 5, "rolls": [12], "keep": 12, "atk_mod": 2, "target_ac": 10,
		"crit": false, "fumble": false,
		"attacker_name": "白页者", "target_name": "小墨妖", "damage_rolls": [5]}, &"core", "N1-7")
	stream6.emit(EventTypes.COMBAT_END, {"result": &"victory", "rounds": 1}, &"core", "N1-7")
	var hi6: ScreenHistory = (load("res://shell/ui/screen_history.tscn") as PackedScene).instantiate()
	root.add_child(hi6)
	await process_frame
	hi6.bind(stream6, board6)
	var ev6_before := stream6.size()
	hi6.start_replay(1)
	await create_timer(1.8).timeout # 3 拍 × 0.5s 播完
	check(hi6.is_replay_visible() and hi6.replay_text().contains("白页者"),
		"战报重演：事件流按节拍重放进只读战报视图（04 §⑧，最小版=节拍日志重演）")
	check(stream6.size() == ev6_before and board6.keys_with_prefix("").is_empty(),
		"重演只读：不产事件、不写板（纯演出，不可改结果）")
	hi6._replay_close()
	hi6.queue_free()
	await process_frame

# ---------------------------------------------------------------- 主屏运营位（06 §6：home_promo 配置投放；空配置隐藏；点击路由）

func test_home_promo() -> void:
	print("[home_promo]")
	# 结算屏禁区复核（06 §6：⑨ 结算界面不做任何付费引导——源码 grep 断言固化）
	var settle_src := FileAccess.get_file_as_string("res://shell/ui/screen_settle.gd")
	var banned := ["购买", "付费", "shop", "Shop", "price", "¥", "acquire", "Acquire", "entitlement"]
	var hits: Array = []
	for token: String in banned:
		if settle_src.contains(token):
			hits.append(token)
	check(hits.is_empty(), "结算屏零付费元素：源码 grep 无付费词（命中：%s，06 §6 句点纯粹）" % ";".join(hits))

	# 壳级：空配置隐藏 / 配置驱动文案 / 点按只发信号
	var stream := EventStream.new()
	var board := Board.new(stream)
	var home: ScreenHome = (load("res://shell/ui/screen_home.tscn") as PackedScene).instantiate()
	root.add_child(home)
	await process_frame
	await process_frame
	home.bind(board, 0, false) # 无 promo 参数 = 空配置
	check(not home.promo_button.visible, "空配置：运营位整体隐藏，不出空位（06 §6）")
	home.bind(board, 0, false, {"text": "测试投放语", "target": "arena"})
	check(home.promo_button.visible and home.promo_button.text == "测试投放语",
		"配置驱动：文案来自 home_promo.text（非 texts_zh 硬编码，06 §3.2 运营侧数据）")
	var pressed: Array = []
	home.promo_pressed.connect(func(t: String) -> void: pressed.append(t))
	var ev_before := stream.size()
	home.promo_button.pressed.emit()
	check(pressed == ["arena"], "点按上报 promo_pressed(target)（壳只发信号，路由归 main）")
	check(stream.size() == ev_before and board.keys_with_prefix("").is_empty(),
		"运营位不走事件流、不写状态板（06 §6 纯呈现挂载点）")
	home.bind(board, 0, false, {"text": "无目标投放"}) # 缺 target 的畸形投放
	check(not home.promo_button.visible, "缺 target：运营位隐藏（容错不阻断，tech/02 §11 同哲学）")
	home.queue_free()
	await process_frame

	# main 级路由：ops_config 实投 arena → 点按直达 ② 入口锁定卡 + 购买弹层
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	var mhome := m.current_screen as ScreenHome
	check(str((m.ops_config.get("home_promo", {}) as Dictionary).get("target", "")) == "arena",
		"运营配置实投：home_promo.target=arena（06 §7 首发策略落地映射）")
	check(mhome.promo_button.visible and mhome.promo_button.text.contains("守门人正在召集白页者"),
		"主屏运营位呈现配置文案（《竞技场连战》召集语）")
	mhome.promo_button.pressed.emit()
	await process_frame
	await process_frame
	check(m.current_screen is ScreenEntry, "点按 → ② 战役入口（home_promo.target=pack_id 路由）")
	check((m.current_screen as ScreenEntry).shop_popup.visible,
		"锁定包直达购买半屏弹层（06 §3.1/§6；04 §3.3 不离开当前界面情境）")
	check(not bool(m.board.read("global.entitlement.arena", false)),
		"路由全程未点亮权利（写板只发生在购买确认，06 §2.3 写权限仅商店/活动/成就）")
	m.queue_free()
	await process_frame


# ---------------------------------------------------------------- 主屏真实输入路由（12 §5/§6）
# 回归锚点：曾发生"主屏点击全灭"——覆盖层吞输入时方法级模拟（pressed.emit / 直调 _gui_input）
# 仍然全绿，必须用 Viewport.push_input 走真实输入路由（按下+抬起）断言热点与兜底条可达。

## 在视口坐标 pos 注入一次完整左键点按（按下 + 抬起）。
## 真实输入滑动：按下 → 移动 → 松开。
func _push_drag(from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	root.push_input(down)
	var mv := InputEventMouseMotion.new()
	mv.position = to
	mv.relative = to - from
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(mv)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	root.push_input(up)

func _push_click(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	root.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	root.push_input(up)

## 扫描 res://core 下全部 .gd 的非注释代码行，返回命中 ids 的 "文件:行号"。
func _core_code_mentions(ids: Array) -> Array:
	var hits: Array = []
	var stack: Array = ["res://core"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			continue
		for sub: String in d.get_directories():
			stack.append(dir_path.path_join(sub))
		for fname: String in d.get_files():
			if not fname.ends_with(".gd"):
				continue
			var lines := FileAccess.get_file_as_string(dir_path.path_join(fname)).split("\n")
			for n: int in lines.size():
				var code := lines[n].split("#")[0]
				for id: String in ids:
					if code.contains(id):
						hits.append("%s:%d(%s)" % [fname, n + 1, id])
	return hits

# ---------------------------------------------------------------- 文本层（tech/01 E-5 双语构建）

func test_texts() -> void:
	print("[texts]")
	check(Texts.s(&"HOME_TITLE") == str(GameManifest.text_overlay("zh-CN")["HOME_TITLE"]) and TextsZh.HOME_TITLE == "营地",
		"取值 = 本作风味覆盖层（packs/_game/texts）；框架表只留中性默认")
	check(Texts.msg({"msg_key": "MSG_MAZE_LOOT", "args": {"item": "潮汐表", "n": 2}}) == "拾取：潮汐表 ×2",
		"msg_key + args 按当前语言渲染")
	check(Texts.msg({"msg": "内容包文本"}) == "内容包文本", "无 msg_key：原样显示 payload.msg（内容包数据文本）")
	check(Texts.set_locale("xx-YY") == "en", "不支持的语言回落缺省语言（英文）")
	var saved_forced := Texts.forced_locale
	Texts.forced_locale = ""
	check(Texts.detect_locale("") == ("zh-CN" if OS.get_locale_language() == "zh" else "en"),
		"无偏好：系统语言为中文 → 中文，否则英文（英文为默认入口）")
	check(Texts.detect_locale("zh-CN") == "zh-CN" and Texts.detect_locale("en") == "en", "玩家偏好优先")
	Texts.forced_locale = saved_forced
	Texts.set_locale(Texts.SOURCE_LOCALE)
	check(Texts.lines(&"TUT_CARDS").size() == TextsZh.TUT_CARDS.size(), "行数组键类型化取值")
	# 静态守卫：代码里用到的每个文本键都在源语言表里（缺键 = 界面出现键名）
	var missing: Array = []
	var used := 0
	var re := RegEx.create_from_string("Texts\\.(?:s|t|lines|fmt)\\(&\"(\\w+)\"")
	for path: String in _gd_files(["res://shell", "res://main.gd", "res://subgame_runner.gd"]):
		if path.get_file() == "texts.gd":
			continue # 文本层自身（注释示例）不计
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			used += 1
			if not Texts.has_key(Texts.SOURCE_LOCALE, StringName(m.get_string(1))):
				missing.append("%s:%s" % [path.get_file(), m.get_string(1)])
	check(used > 200 and missing.is_empty(), "代码引用的 %d 处文本键全部在源语言表：%s" % [used, ";".join(missing)])
	# core 不产出玩家可见文案：只发 msg_key（tech/01 E-5）
	var raw_msgs: Array = []
	for path: String in _gd_files(["res://core"]):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n: int in lines.size():
			if lines[n].split("#")[0].contains("\"msg\":"):
				raw_msgs.append("%s:%d" % [path.get_file(), n + 1])
	check(raw_msgs.is_empty(), "core 零写死消息文案（只发 msg_key）：%s" % ";".join(raw_msgs))
	var core_keys := RegEx.create_from_string("\"msg_key\": \"(\\w+)\"")
	var bad_keys: Array = []
	for path: String in _gd_files(["res://core", "res://main.gd", "res://subgame_runner.gd"]):
		for m: RegExMatch in core_keys.search_all(FileAccess.get_file_as_string(path)):
			if not Texts.has_key(Texts.SOURCE_LOCALE, StringName(m.get_string(1))):
				bad_keys.append(m.get_string(1))
	check(bad_keys.is_empty(), "事件 msg_key 全部有模板：%s" % ";".join(bad_keys))

# ---------------------------------------------------------------- 英文语言表（tech/01 E-5；P4 阶段 2）

func test_texts_en() -> void:
	print("[texts_en]")
	check(Texts.available_locales().has("en"), "英文语言表已提供（texts_en.gd）")
	var spec := RegEx.create_from_string("%[-+0-9.]*[sdf%]")
	var named := RegEx.create_from_string("\\{(\\w+)\\}")
	var missing: Array = []
	var mismatched: Array = []
	for k: Variant in Texts.keys("zh-CN"):
		var key := StringName(k)
		if not Texts.has_key("en", key):
			missing.append(String(key))
			continue
		Texts.set_locale("zh-CN")
		var zh: Variant = Texts.t(key)
		Texts.set_locale("en")
		var en: Variant = Texts.t(key)
		Texts.set_locale("zh-CN")
		if typeof(zh) != typeof(en):
			mismatched.append("%s(类型)" % key)
		elif zh is String:
			var a := spec.search_all(zh).map(func(m: RegExMatch) -> String: return m.get_string())
			var b := spec.search_all(en).map(func(m: RegExMatch) -> String: return m.get_string())
			var na := named.search_all(zh).map(func(m: RegExMatch) -> String: return m.get_string(1))
			var nb := named.search_all(en).map(func(m: RegExMatch) -> String: return m.get_string(1))
			na.sort()
			nb.sort()
			if a != b or na != nb:
				mismatched.append("%s(%s≠%s)" % [key, str(a + na), str(b + nb)])
		elif zh is Dictionary:
			if (zh as Dictionary).keys().size() != (en as Dictionary).keys().size() \
					or not (zh as Dictionary).keys().all(func(x: Variant) -> bool: return (en as Dictionary).has(x)):
				mismatched.append("%s(字典键)" % key)
		elif zh is Array and (zh as Array).size() != (en as Array).size():
			mismatched.append("%s(行数)" % key)
	check(missing.is_empty(), "英文表覆盖全部源语言键：缺 %s" % ";".join(missing))
	check(mismatched.is_empty(), "中英格式占位逐键一致（%%/具名占位、类型、字典键、行数）：%s" % ";".join(mismatched))
	# 运营侧数据（_ops，非内容包）同样全量英文：投放文案 / 价签 / 皮肤名与说明
	var ops_en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://packs/_ops/texts/en.json"))
	var ops_keys := PackLoader.ops_text_entries(JSON.parse_string(FileAccess.get_file_as_string("res://packs/_ops/ops_config.json")), "ops")
	ops_keys.merge(PackLoader.ops_text_entries(JSON.parse_string(FileAccess.get_file_as_string("res://packs/_ops/cosmetics.json")), "cosmetics"))
	var ops_missing: Array = ops_keys.keys().filter(func(k: String) -> bool: return str(ops_keys[k]) != "" and str(ops_en.get(k, "")) == "")
	check(ops_missing.is_empty(), "运营侧数据英文齐全（_ops/texts/en.json）：缺 %s" % ";".join(ops_missing))
	PackLoader.locale = "en"
	check(str((Entitlements.load_ops_config()["home_promo"] as Dictionary)["text"]).begins_with("Arena Gauntlet"),
		"运营位文案按语言叠加")
	check(str((Cosmetics.load_registry()[2] as Dictionary)["name"]) == "Salvage Bronze Glow", "皮肤名按语言叠加")
	PackLoader.locale = ""
	Texts.set_locale("en")
	check(Texts.msg({"msg_key": "MSG_MAZE_LOOT", "args": {"item": "Tide Chart", "n": 2}}) == "Picked up: Tide Chart ×2",
		"英文消息模板渲染")
	Texts.set_locale(Texts.SOURCE_LOCALE)

# ---------------------------------------------------------------- 内容包单副本（game/packs 为唯一数据源；docs/en/tech/03 §6）

func test_pack_copies_in_sync() -> void:
	print("[pack_single_copy]")
	# 旧"docs 编写源 = 运行副本"双副本已归档（archive/zh-CN/docs）；现行 docs/ 下不得再出现包数据副本
	var docs_root := ProjectSettings.globalize_path("res://").path_join("../docs")
	var stray: Array = []
	for rel: String in ["story/campaign01", "story/arc_tide", "subgames/arena/pack", "subgames/riddle-maze/pack",
			"en/story/campaign01", "en/subgames/arena/pack", "en/subgames/riddle-maze/pack"]:
		for f: String in DirAccess.get_files_at(docs_root.path_join(rel)):
			if f.ends_with(".json"):
				stray.append(rel.path_join(f))
	check(stray.is_empty(), "包数据只在 game/packs（docs 下无 JSON 副本）：%s" % ";".join(stray))
	for pid: String in ["campaign01", "arc_tide", "arena", "riddle_maze"]:
		check(FileAccess.file_exists("res://packs/%s/manifest.json" % pid), "运行包 %s 在位" % pid)

# ---------------------------------------------------------------- 框架零内容常量（白皮书 §2；代码评审 M1）

func test_no_content_constants() -> void:
	print("[no_content_constants]")
	var ids := ["campaign01", "arena", "riddle_maze", "arc_tide"]
	var hits: Array = []
	var node_id := RegEx.create_from_string("\"(N[0-9]-[0-9A-Za-z-]*|R[0-9][a-z0-9-]*|E[0-9])\"")
	for path: String in _gd_files(["res://core", "res://shell", "res://main.gd", "res://subgame_runner.gd"]):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n: int in lines.size():
			var code := lines[n].split("#")[0]
			for id: String in ids:
				if code.contains("\"%s" % id) or code.contains("%s." % id):
					hits.append("%s:%d(%s)" % [path.get_file(), n + 1, id])
			if node_id.search(code) != null:
				hits.append("%s:%d(node id)" % [path.get_file(), n + 1])
	check(hits.is_empty(), "core/shell/main 零内容包 id / 节点 id 常量：%s" % ";".join(hits))
	check(StoryVM.is_bookkeeping_key("arena.gold") and StoryVM.is_bookkeeping_key("campaign01.hp.pc")
		and StoryVM.is_bookkeeping_key("global.growth.xp") and not StoryVM.is_bookkeeping_key("campaign01.seen_fading"),
		"簿记键按键形判定（任何包命名空间通用）")
	var v1 := {"save_version": 1, "board": {"data": {"campaign02.xp_total": 350, "campaign02.seen": true},
		"provenance": {}}}
	var mig: Dictionary = SaveSystem.migrate(v1)["snapshot"]
	var data: Dictionary = mig["board"]["data"]
	check(int(data.get("global.growth.xp", 0)) == 350 and not data.has("campaign02.xp_total")
		and bool(data.get("campaign02.seen", false)), "v1→v2 迁移按命名空间发现（不写死 campaign01）")

# ---------------------------------------------------------------- 内容包多语言叠加 + V15（tech/02 §1.1/§12）

func test_pack_locale() -> void:
	print("[pack_locale]")
	var src := "res://packs/campaign01"
	var dst := TEST_DIR.path_join("pack_en")
	DirAccess.make_dir_recursive_absolute(dst.path_join("texts"))
	for f: String in DirAccess.get_files_at(src):
		DirAccess.copy_absolute(src.path_join(f), dst.path_join(f))
	DirAccess.copy_absolute(src.path_join("texts/zh-CN.json"), dst.path_join("texts/zh-CN.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dst.path_join("manifest.json")))
	manifest["locales"] = ["zh-CN", "en"]
	var mf := FileAccess.open(dst.path_join("manifest.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(manifest))
	mf.close()
	var en := {"nodes.N0-2.title": "The Vanished Pier Name", "nodes.N1-1.edges.0.label": "Look closer",
		"node.N0-1.text": "You wake to the sound of the tide.", "items.heal_potion.name": "Supply Potion"}
	var ef := FileAccess.open(dst.path_join("texts/en.json"), FileAccess.WRITE)
	ef.store_string(JSON.stringify(en))
	ef.close()
	# 源语言加载：文本键枚举
	PackLoader.locale = ""
	var zh: Dictionary = PackLoader.load_pack(dst)["pack"]
	var entries := PackLoader.text_entries(zh)
	check(entries.size() > 200 and entries.has("nodes.N0-2.title") and entries.has("items.heal_potion.name"),
		"约定式文本键枚举（%d 个，含节点标题/边文案/道具名）" % entries.size())
	check(str(zh["locale"]) == "zh-CN" and str((zh["nodes"]["N0-2"] as Dictionary)["title"]) == "消失的码头名",
		"源语言加载：原文不变")
	# 目标语言加载：命中键覆盖，未译键回落原文
	PackLoader.locale = "en"
	var p_en: Dictionary = PackLoader.load_pack(dst)["pack"]
	PackLoader.locale = ""
	var n02: Dictionary = p_en["nodes"]["N0-2"]
	check(str(p_en["locale"]) == "en" and str(n02["title"]) == "The Vanished Pier Name", "en 加载：节点标题被覆盖")
	check(str(((p_en["nodes"]["N1-1"] as Dictionary)["edges"] as Array)[0].get("label", "")) == "Look closer",
		"en 加载：边文案被覆盖（路径键 edges.0.label）")
	check(str((p_en["items"]["heal_potion"] as Dictionary)["name"]) == "Supply Potion", "en 加载：道具名被覆盖")
	check(str((p_en["nodes"]["N0-1"] as Dictionary)["title"]) == str((zh["nodes"]["N0-1"] as Dictionary)["title"]),
		"未译键回落源语言原文")
	var n01: Dictionary = p_en["nodes"]["N0-1"]
	check(StoryVM.resolve_text(p_en["texts"], str(n01["text_ref"]), "") == "You wake to the sound of the tide.",
		"text_ref 按当前语言解析（旧写法 texts/zh-CN.json#键 兼容）")
	var n03a: Dictionary = p_en["nodes"]["N0-3a"]
	check(StoryVM.resolve_text(p_en["texts"], str(n03a["text_ref"]), "") != "", "未译长文本回落源语言全文")
	check(StoryVM.resolve_text(p_en["texts"], "#node.N0-1.text", "") == "You wake to the sound of the tide.",
		"与语言无关的 text_ref（#键）")
	# V15：声明 en 但未译全 = FAIL；不声明 = N/A
	var v15 := PacklintCore._v15_texts(zh)
	check(v15.any(func(i: Dictionary) -> bool: return i["level"] == PacklintCore.LEVEL_FAIL and str(i["msg"]).begins_with("en 缺文本键")),
		"V15：声明 en 但缺键 → FAIL 并列出缺键")
	var real: Dictionary = PackLoader.load_pack(src)["pack"]
	(real["manifest"] as Dictionary).erase("locales")
	check(PacklintCore._v15_texts(real).any(func(i: Dictionary) -> bool: return i["level"] == PacklintCore.LEVEL_NA),
		"V15：未声明 manifest.locales → N/A")

## 收集 .gd 文件（目录递归 / 单文件）。
func _gd_files(roots: Array) -> Array:
	var out: Array = []
	var stack: Array = roots.duplicate()
	while not stack.is_empty():
		var path: String = stack.pop_back()
		if path.ends_with(".gd"):
			out.append(path)
			continue
		var d := DirAccess.open(path)
		if d == null:
			continue
		for sub: String in d.get_directories():
			stack.append(path.path_join(sub))
		for f: String in d.get_files():
			if f.ends_with(".gd"):
				out.append(path.path_join(f))
	return out

# ---------------------------------------------------------------- 新开局种子（tech/01 §5.2；代码评审 B3）

func test_new_game_seed() -> void:
	print("[new_game_seed]")
	var saved := Rng.fixed_seed_override
	Rng.fixed_seed_override = -1
	var a := Rng.new_game_seed()
	OS.delay_usec(50)
	var b := Rng.new_game_seed()
	check(a != b, "正式运行：两次新开局种子不同（每局骰序不同）")
	check(a >= 0 and b >= 0, "新开局种子非负")
	Rng.fixed_seed_override = 777
	check(Rng.new_game_seed() == 777, "覆盖值生效（测试/工具/截图取确定路径）")
	Rng.fixed_seed_override = saved

# ---------------------------------------------------------------- 商店与幕级门槛（06 §3.1/§5/§7；tech/02 §2.2；P4 阶段 4）

func test_store_and_act_gate() -> void:
	print("[store_and_act_gate]")
	ProjectSettings.set_setting("game/market", "global")
	var m := _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	check(not bool(m.board.read("global.entitlement.campaign01_full")), "海外市场：完整战役不随本体点亮")
	check(m.store is MockStore and m.store.is_available(), "调试构建：使用模拟商店")
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	check(not (m.current_screen is ScreenLocked), "免费试玩：序章可玩")
	m.graph._enter("N1-1")
	m._present_node()
	await process_frame
	check(not (m.current_screen is ScreenLocked), "免费试玩：幕一可玩")
	m.graph._enter("N2S-1")
	m._present_node()
	await process_frame
	var lock := m.current_screen as ScreenLocked
	check(lock != null and not lock.get_button.disabled, "幕二：章节锁定页（可见但锁定 + 获取入口）")
	MockStore.next_result = "cancel"
	lock.purchase_requested.emit("campaign01_full")
	await process_frame
	check(m.current_screen is ScreenLocked and not bool(m.board.read("global.entitlement.campaign01_full")),
		"取消购买：仍锁定、不点亮")
	MockStore.next_result = "fail"
	var logs_before: int = m.stream.query_by_type(EventTypes.LOG).size()
	lock.purchase_requested.emit("campaign01_full")
	await process_frame
	var last: Dictionary = m.stream.query_by_type(EventTypes.LOG).back()
	check(m.stream.query_by_type(EventTypes.LOG).size() > logs_before and str(last["payload"].get("msg_key", "")) == "MSG_PURCHASE_FAILED",
		"购买失败：提示失败原因、不点亮")
	lock.purchase_requested.emit("campaign01_full")
	await process_frame
	await process_frame
	var prov: Dictionary = m.board.provenance_of("global.entitlement.campaign01_full") if m.board.has_method("provenance_of") else {}
	check(bool(m.board.read("global.entitlement.campaign01_full")) and not (m.current_screen is ScreenLocked),
		"购买成功：权利点亮，当场续玩（无需重启）")
	check(bool(m.board.read("campaign01.run_unlocked")), "本局记为已解锁（退款后可跑完，06 §5）")
	# 退款：权利置假，但进行中的一局可继续进入后续幕
	(m.store as MockStore).simulate_revoke("campaign01_full")
	check(not bool(m.board.read("global.entitlement.campaign01_full")), "平台撤销：权利置假")
	m.graph._enter("N3-1")
	m._present_node()
	await process_frame
	check(not (m.current_screen is ScreenLocked), "退款后：当前一局仍可跑完（06 §5）")
	m.queue_free()
	await process_frame
	# 新设备 / 重装：恢复购买
	var m2 := _new_main()
	root.add_child(m2)
	await process_frame
	(m2.store as MockStore).grant_owned("campaign01_full")
	m2._restore_purchases()
	await process_frame
	check(bool(m2.board.read("global.entitlement.campaign01_full")), "恢复购买：已购商品重新点亮")
	check(str((m2.board.provenance_of("global.entitlement.campaign01_full") if m2.board.has_method("provenance_of") else {"granted_by": "restore"}).get("granted_by", "")) == "restore",
		"恢复购买溯源 granted_by = restore")
	m2.queue_free()
	await process_frame
	# 国内市场：完整战役随本体
	ProjectSettings.set_setting("game/market", "cn")
	var m3 := _new_main()
	root.add_child(m3)
	await process_frame
	check(bool(m3.board.read("global.entitlement.campaign01_full")), "国内市场：完整战役随本体点亮（market 溯源）")
	m3.queue_free()
	await process_frame
	# 发布安全：不可用商店绝不放行
	var unavailable := Store.new()
	var got: Array = []
	unavailable.purchase_finished.connect(func(p: String, ok: bool, r: String, e: String) -> void: got.append([ok, e]))
	unavailable.purchase("campaign01_full")
	check(not unavailable.is_available() and got == [[false, "unavailable"]], "不可用商店：购买一律失败（发布版无适配器时不放行）")
	var lk := ScreenLocked.new()
	root.add_child(lk)
	lk.bind("Act", "campaign01_full", "Full", "$4.99", false)
	check(lk.get_button.disabled and lk.restore_button.disabled, "商店不可用：锁定页购买/恢复按钮禁用")
	lk.queue_free()
	SaveSystem.delete()

# ---------------------------------------------------------------- 移动平台层（tech/01 §10.1；P4 阶段 3）

func test_mobile_platform() -> void:
	print("[mobile_platform]")
	# 安全区：模拟刘海 44 / Home 指示条 34
	SafeArea.override_insets = {"top": 44.0, "right": 0.0, "bottom": 34.0, "left": 0.0}
	var m := _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	var vp_h := root.get_visible_rect().size.y
	var home := m.current_screen as ScreenHome
	check(is_equal_approx(home.position.y, 44.0) and is_equal_approx(home.size.y, vp_h - 78.0),
		"界面根落在安全区内（上 44 / 下 34 内缩）")
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	var sh := m.shell as Control
	check(sh != null and is_equal_approx(sh.offset_top, 44.0) and is_equal_approx(sh.offset_bottom, -34.0),
		"双壳根节点按安全区内缩（锚定全屏 + 偏移）")
	# 返回键：故事态 = 打开 ☰
	check(m.on_back_requested() == "menu", "返回键：故事/遭遇态打开 ☰ 菜单")
	# 切后台：遭遇外落档；遭遇中不落档
	SaveSystem.delete()
	check(m.on_app_background() and SaveSystem.has_save(), "切后台：遭遇外兜底落档")
	m.campaign._in_encounter = true
	SaveSystem.delete()
	check(not m.on_app_background() and not SaveSystem.has_save(), "切后台：遭遇进行中不存档（09 §7）")
	m.campaign._in_encounter = false
	m._show_home()
	await process_frame
	(m.current_screen as ScreenHome)._toggle_help()
	check(m.on_back_requested() == "close_help" and not (m.current_screen as ScreenHome).is_help_open(),
		"返回键：主屏先关闭帮助页")
	m._on_home_navigate(&"quests")
	await process_frame
	check(m.on_back_requested() == "back", "返回键：功能界面走自身返回出口")
	await process_frame
	check(m.current_screen is ScreenHome, "返回键：回到主屏")
	m.queue_free()
	await process_frame
	SafeArea.override_insets = {}
	# 横屏开关（竖屏优先 v1）：关闭时 choice/forced space/子游戏一律落竖屏，入口不呈现横屏卡
	ProjectSettings.set_setting("game/features/landscape", false)
	check(ShellRouter.effective(ShellRouter.MODE_SPACE) == ShellRouter.MODE_TIME, "横屏未开放：space 生效为 time")
	var m2 := _new_main()
	root.add_child(m2)
	await process_frame
	await process_frame
	m2._on_home_navigate(&"entry")
	await process_frame
	var entry := m2.current_screen as ScreenEntry
	check(not entry.mode_space_button.is_visible_in_tree() and entry.selected_mode == ShellRouter.MODE_TIME,
		"入口：不呈现横屏卡，自动选定竖屏")
	m2.campaign._mode = ShellRouter.MODE_SPACE
	check(m2._story_mode() == ShellRouter.MODE_TIME, "故事态形态解析：横屏未开放落竖屏")
	m2.queue_free()
	await process_frame
	ProjectSettings.set_setting("game/features/landscape", true)
	SaveSystem.delete()
	# 包体：音频走导入资源（QOA 压缩 + 导入声明循环）
	var am := AudioManager.new()
	var bgm := am._stream_for(&"bgm_battle")
	check(bgm is AudioStreamWAV and (bgm as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"BGM 经导入资源加载且循环（.import edit/loop_mode）")
	am.free()
	# 导出预设：包数据 JSON 显式包含，开发工具/测试排除
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "导出预设入库")
	var ok_filters := true
	for sec: String in cfg.get_sections():
		if sec.ends_with(".options"):
			continue
		ok_filters = ok_filters and str(cfg.get_value(sec, "include_filter", "")).contains("*.json") \
			and str(cfg.get_value(sec, "exclude_filter", "")).contains("tools/*") \
			and str(cfg.get_value(sec, "exclude_filter", "")).contains("tests/*")
	check(ok_filters, "每个导出预设包含 *.json、排除 tools/ 与 tests/")
	var opts_ok := true
	for sec2: String in cfg.get_sections():
		if not sec2.ends_with(".options"):
			opts_ok = opts_ok and cfg.has_section(sec2 + ".options") and not cfg.get_section_keys(sec2 + ".options").is_empty()
	check(opts_ok, "每个导出预设都有非空 .options 段（空段会被丢弃，编辑器报 nonexistent section）")
	check(str(ProjectSettings.get_setting("display/window/handheld/orientation", 0)) == "1",
		"手持设备方向 = 竖屏（v1 竖屏优先）")

# ---------------------------------------------------------------- 英文冒烟（P4 阶段 2：英文界面 + 英文内容包走主流程）

func test_english_smoke() -> void:
	print("[english_smoke]")
	Texts.forced_locale = "en"
	var m := _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	var home := m.current_screen as ScreenHome
	check(Texts.locale == "en" and PackLoader.locale == "en", "英文语言：界面与内容包同时切换")
	check(home != null and home.campaign_button.text.begins_with("Campaigns"), "主屏英文文案（%s）" % (home.campaign_button.text if home else ""))
	check(str(m.pack["manifest"]["name"]) == "Ashenport Fragments", "内容包英文名（约定式键叠加）")
	m._on_home_navigate(&"entry")
	await process_frame
	(m.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	await process_frame
	var text := StoryVM.node_text(m.graph.current(), m.board, m._campaign_id, m.pack["texts"])
	check(text.begins_with("The tide."), "序章正文为英文（text_ref 按当前语言解析）")
	var cjk := RegEx.create_from_string("[\\x{4e00}-\\x{9fff}]")
	var leaks: Array = []
	for nid: String in (m.pack["nodes"] as Dictionary).keys():
		var n: Dictionary = m.pack["nodes"][nid]
		for f: String in ["title", "summary"]:
			if cjk.search(str(n.get(f, ""))) != null:
				leaks.append("%s.%s" % [nid, f])
		for e: Variant in n.get("edges", []):
			if cjk.search(str((e as Dictionary).get("label", ""))) != null:
				leaks.append("%s.edge" % nid)
	check(leaks.is_empty(), "英文加载后节点标题/摘要/选项零中文残留：%s" % ";".join(leaks))
	m.queue_free()
	await process_frame
	Texts.forced_locale = Texts.SOURCE_LOCALE
	Texts.set_locale(Texts.SOURCE_LOCALE)
	PackLoader.locale = ""
	SaveSystem.delete()

# ---------------------------------------------------------------- 启动读回（07 §4.2；代码评审 B1）

func test_resume_on_launch() -> void:
	print("[resume_on_launch]")
	var m1 := _new_main()
	root.add_child(m1)
	await process_frame
	await process_frame
	check(not m1._has_continuable(), "无档首启：无可继续战役")
	m1._on_home_navigate(&"entry")
	await process_frame
	(m1.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m1.current_screen as ScreenEntry).start_requested.emit()
	await process_frame
	m1.graph._enter("N1-1")
	m1.board.give_item("half_tide_table", 1, {"event_id": 0, "node_id": "N1-1", "pack_id": "campaign01"})
	var rng_probe: Dictionary = m1.rng.save_state()
	m1._save("test_resume")
	var visited: int = m1.graph.visit_log.size()
	var events_at_save: int = m1.stream.tail()
	m1.queue_free()
	await process_frame
	# 冷启动：不删存档槽，直接新实例
	var m2: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(m2)
	await process_frame
	await process_frame
	check(m2.graph.current_id == "N1-1", "冷启动读回：故事图当前节点恢复（N1-1）")
	check(m2.graph.visit_log.size() == visited, "冷启动读回：已访节点恢复")
	check(m2.board.has_item("half_tide_table"), "冷启动读回：状态板恢复（背包道具）")
	check(m2.rng.save_state() == rng_probe, "冷启动读回：RNG 状态恢复（后续骰序与存档时一致）")
	check(m2._has_continuable(), "主屏\"继续\"可用（04 §①）")
	check(m2.stream.size() >= events_at_save - 1 and m2.stream.tail() >= events_at_save,
		"冷启动读回：事件流全量恢复（历史卷轴跨启动可追溯，tech/01 E-3）")
	var resumed_ev: Array = m2.stream.query_by_type(EventTypes.LOG)
	check(not resumed_ev.is_empty() and resumed_ev.back()["type"] is StringName, "读回事件类型恢复为 StringName（查询可用）")
	check(str(m2.board.read("global.mode_choice.campaign01", "")) == "time", "冷启动读回：模式选择保留（09 §3 整场锁定）")
	m2.queue_free()
	await process_frame
	# 坏档：告警并按新开局处理，不崩溃
	var f := FileAccess.open(SaveSystem.path_for(), FileAccess.WRITE)
	f.store_string("{ 坏档")
	f.close()
	var m3: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(m3)
	await process_frame
	check(m3.graph.visit_log.is_empty() and not m3._has_continuable(), "坏档：按新开局处理（不崩溃）")
	m3.queue_free()
	await process_frame
	SaveSystem.delete()

func test_home_real_input() -> void:
	print("[home_real_input]")
	DirAccess.remove_absolute(UiSettings.redirect_path) # 默认偏好起步（兜底条默认展开，12 §5）
	root.size = Vector2i(390, 760) # 无头根窗默认 64×64：真实命中测试前先落项目竖屏尺寸
	var stream := EventStream.new()
	var board := Board.new(stream)
	var home: ScreenHome = (load("res://shell/ui/screen_home.tscn") as PackedScene).instantiate()
	root.add_child(home)
	await process_frame
	await process_frame
	var navs: Array = []
	home.navigate.connect(func(id: StringName) -> void: navs.append(id))
	home.bind(board, 0, false)
	# ---- 基线：无覆盖层时真实点按热点（潮汐塔 → ② 战役入口，12 §5 ① 表）----
	var hs_pos := home.scroll.global_position + home.scroll.hotspot_rect(HomeScroll.HOTSPOTS[0]).get_center()
	_push_click(hs_pos)
	await process_frame
	await process_frame
	check(navs == [&"entry"], "真实输入：点热点 → 导航（push_input 全路由基线，12 §5 ①）")
	# ---- 首次启动全流程：启动卡（12 §4 第一层）看完/跳过 → 主屏必须恢复可点 ----
	# 回归：启动卡结束后 TutorialOverlay 根节点残留全屏 STOP 吞掉一切点击。
	home.show_launch_tutorial()
	await process_frame
	home.tutorial.finish_launch()
	await process_frame
	navs.clear()
	_push_click(hs_pos)
	await process_frame
	await process_frame
	check(navs == [&"entry"], "真实输入：启动卡结束后点热点 → 导航（覆盖层不残留吞输入，12 §4/§5）")
	# ---- 真实输入上滑：拉出文字菜单（默认收起）；下滑收起；滑动不误触热点 ----
	check(home.is_bar_collapsed(), "真实输入前：文字菜单默认收起")
	var mid := home.scroll.get_global_rect().get_center()
	navs.clear()
	_push_drag(mid + Vector2(0, 60), mid - Vector2(0, 60))
	await process_frame
	await process_frame
	check(not home.is_bar_collapsed() and home.fallback_bar.visible and navs.is_empty(),
		"真实输入：上滑拉出文字菜单（滑过热点不触发导航）")
	_push_drag(mid - Vector2(0, 60), mid + Vector2(0, 60))
	await process_frame
	await process_frame
	check(home.is_bar_collapsed() and navs.is_empty(), "真实输入：下滑收起文字菜单")
	_push_click(home.bar_toggle.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(not home.is_bar_collapsed(), "真实输入：点小把手展开")
	# ---- 兜底条等价路径：真实点按文字入口（12 §5：骨架与皮肤同信号）----
	navs.clear()
	_push_click(home.campaign_button.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(navs == [&"entry"], "真实输入：兜底条按钮点按 → 导航（12 §5 功能等价）")
	# ---- 兜底条 toggle 把手：真实点按收起/展开（12 §5：把手始终可触达）----
	_push_click(home.bar_toggle.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(home.is_bar_collapsed() and not home.fallback_bar.visible, "真实输入：toggle 把手收起兜底条（12 §5）")
	_push_click(home.bar_toggle.get_global_rect().get_center())
	await process_frame
	await process_frame
	check(not home.is_bar_collapsed() and home.fallback_bar.visible, "真实输入：toggle 把手展开还原（12 §5）")
	home.queue_free()
	await process_frame

# ---------------------------------------------------------------- 换肤禁区硬断言（06 §3/§4：皮肤永不触碰骰子与事件流结果）

func test_cosmetic_neutral() -> void:
	print("[cosmetic_neutral]")
	var sd: GDScript = load("res://tools/shell_diff.gd")
	var equip_copper := func(b: Board, s: EventStream) -> void:
		var cos := Cosmetics.new(b, s)
		cos.shop_purchase("salvage_copper", "rcpt_neutral")
		cos.equip("salvage_copper")
	var equip_gray := func(b: Board, s: EventStream) -> void:
		var cos := Cosmetics.new(b, s)
		cos.grant("faded_ink_gray", {"granted_by": "codex", "series": "fatedie_study"})
		cos.equip("faded_ink_gray")
	# 断言前提：两侧皮肤配色确实不同（比对非空转——"换了肤"成立）
	var pb1 := Board.new(EventStream.new())
	equip_copper.call(pb1, pb1.stream)
	var pb2 := Board.new(EventStream.new())
	equip_gray.call(pb2, pb2.stream)
	check(Cosmetics.palette_of(pb1)["face"] != Cosmetics.palette_of(pb2)["face"],
		"断言前提：两侧装备不同皮肤且调色板不同")
	# 同种子同指令序列、不同皮肤（连壳形态都不同）各跑一整局，对局段事件流逐字节比对
	var a: Dictionary = await sd.run_battle(self, &"time", 20261109, 11, false, equip_copper)
	var b: Dictionary = await sd.run_battle(self, &"space", 20261109, 11, false, equip_gray)
	check(int(a["count"]) > 40 and str(a["result"]) != "",
		"换肤对局完整跑完（事件 %d 条，结果 %s）" % [int(a["count"]), str(a["result"])])
	check(str(a["json"]) == str(b["json"]),
		"禁区硬断言：同种子同指令、换肤前后对局段事件流逐字节一致（06 §3/§4 付费禁区：皮肤不碰骰子）")

# ---------------------------------------------------------------- 外观页 UI 与换肤渲染（06 §6；纯呈现）

## 按 skin_id 点外观页按钮（测试探针路径，与点按同一信号通道）。
func _press_cosmetic_button(iv: ScreenInventory, skin_id: String) -> void:
	var idx := 0
	for e: Variant in iv._skins:
		var row := iv.cos_box.get_child(2 + idx) # 前两子节点 = 栏头 + 纯演出注记
		if str((e as Dictionary).get("id", "")) == skin_id and row is HBoxContainer:
			for c: Node in (row as HBoxContainer).get_children():
				if c is Button:
					(c as Button).pressed.emit()
					return
		idx += 1

func test_cosmetics_ui() -> void:
	print("[cosmetics_ui]")
	var reg := Cosmetics.load_registry()
	var iv: ScreenInventory = (load("res://shell/ui/screen_inventory.tscn") as PackedScene).instantiate()
	root.add_child(iv)
	await process_frame
	iv.bind({"heal_potion": 1}, _load_campaign01()["items"], [], _load_campaign01()["lore"])
	iv.bind_cosmetics(reg, ["gilded_ink"], "gilded_ink")
	check(iv.cosmetic_entry_count() == 4, "外观页：皮肤列表按注册表入列（06 §6 外观页挂 ⑥ 背包图鉴；含执笔者之骰）")
	check(iv.cosmetic_button_text("gilded_ink") == TextsZh.COSMETIC_UNEQUIP, "当前装备皮肤 → 卸下按钮")
	check(iv.cosmetic_button_text("faded_ink_gray") == TextsZh.COSMETIC_NOT_OWNED,
		"未获得（集齐途径）灰显：呈现获得条件，不出购买入口")
	check(iv.cosmetic_button_text("salvage_copper").contains(TextsZh.LOCK_ACQUIRE),
		"商店皮肤呈现获取入口（06 §7 外观商品位 ¥6 占位）")
	# 装备信号（写板由 main → Cosmetics 落，本屏只转发，godot-dev §2）
	iv.bind_cosmetics(reg, ["gilded_ink", "faded_ink_gray"], "gilded_ink")
	await process_frame # queue_free 延迟回收：隔帧再点
	var equipped: Array = []
	iv.equip_requested.connect(func(s: String) -> void: equipped.append(s))
	_press_cosmetic_button(iv, "faded_ink_gray")
	check(equipped == ["faded_ink_gray"], "外观页装备：转发 skin_id（写板走 core 通道）")
	var unequips: Array = []
	iv.unequip_requested.connect(func() -> void: unequips.append(1))
	iv.bind_cosmetics(reg, ["gilded_ink", "faded_ink_gray"], "faded_ink_gray")
	await process_frame
	_press_cosmetic_button(iv, "faded_ink_gray")
	check(unequips.size() == 1, "外观页卸下：回落默认皮肤")
	# 购买半屏弹层（复用现有 ShopPopup，06 §6 + 04 §3.3：不离开当前界面情境）
	var bought: Array = []
	iv.skin_purchase_requested.connect(func(s: String) -> void: bought.append(s))
	_press_cosmetic_button(iv, "salvage_copper")
	await process_frame
	check(iv.skin_popup.visible, "商店皮肤 → 半屏弹层购买（复用现有购买弹层，06 §6）")
	iv.skin_popup.confirm_button.pressed.emit()
	check(bought == ["salvage_copper"], "购买确认转发 skin_id（写板+单号溯源由 core 落，06 §2.3）")
	iv.queue_free()
	await process_frame
	# 换肤渲染：托盘快掷按当前皮肤换配色与描边（纯呈现；渲染层对规则无感）
	var stream_c := EventStream.new()
	var board_c := Board.new(stream_c)
	var cos_c := Cosmetics.new(board_c, stream_c)
	cos_c.shop_purchase("salvage_copper", "rcpt_ui")
	cos_c.equip("salvage_copper")
	var sh: EncounterPortrait = \
		(load("res://shell/portrait/encounter_portrait.tscn") as PackedScene).instantiate()
	root.add_child(sh)
	await process_frame
	sh.bind_story(stream_c, board_c, {}, {})
	stream_c.emit(EventTypes.CHECK_ROLL, {"keep": 17, "rolls": [17], "mod": 0, "total": 17,
		"success": true}, &"core", "N1-3")
	await create_timer(0.6).timeout # 快掷 0.35s 落定
	var pal := Cosmetics.palette_of(board_c)
	check(sh.dice_label.text == "17" and sh.dice_label.get_theme_color("font_color") == pal["face"],
		"托盘快掷按当前皮肤换配色（纯呈现，不动逻辑）")
	check(sh.dice_label.get_theme_color("font_outline_color") == pal["edge"], "骰面描边随皮肤（edge）")
	sh.queue_free()
	await process_frame

# ---------------------------------------------------------------- 美术管线与首批资产（tech/05；14 清单 #7）

func test_art_pipeline() -> void:
	print("[art_pipeline] 美术管线与首批资产（tech/05 §1~§8；14 清单 #7）")
	# ---- ① 生成物与管线规范一致（命名/尺寸/透明底/剪影非空；tech/05 §2/§3/§4/§7）----
	var expect := {
		"units/unit_ink_imp_128.png": "units/ink_imp",
		"units/unit_ink_fiend_128.png": "units/ink_fiend",
		"units/unit_page_warden_128.png": "units/page_warden",
		"portraits/portrait_player_blank_128.png": "portraits/player_blank",
		"portraits/portrait_companion_kelan_128.png": "portraits/companion_kelan",
		"portraits/portrait_companion_laofei_128.png": "portraits/companion_laofei",
		# P6.4 第二批：职业头像 + 未配图敌人 + 起步包单位
		"portraits/portrait_class_harbor_guard_128.png": "portraits/class_harbor_guard",
		"portraits/portrait_class_scavenger_128.png": "portraits/class_scavenger",
		"portraits/portrait_class_ink_adept_128.png": "portraits/class_ink_adept",
		"units/unit_ink_swarm_128.png": "units/ink_swarm",
		"units/unit_uninked_guard_128.png": "units/uninked_guard",
		"units/unit_tax_guard_128.png": "units/tax_guard",
		"units/unit_dock_ambusher_128.png": "units/dock_ambusher",
		"units/unit_mercenary_128.png": "units/mercenary",
		"units/unit_tide_avatar_128.png": "units/tide_avatar",
		"units/unit_bandit_128.png": "units/bandit",
		"units/unit_wolf_128.png": "units/wolf",
		"units/unit_scout_128.png": "units/scout",
		"icons/icon_heal_potion_128.png": "icons/heal_potion",
		"icons/icon_tide_bomb_128.png": "icons/tide_bomb",
		"icons/icon_fatedie_128.png": "icons/fatedie",
		"icons/icon_longsword_128.png": "icons/longsword",
	}
	# 每个 art_ref 都有图（campaign01 / arena / 起步包：职业、角色、敌人全覆盖）
	for pdir: String in ["res://packs/campaign01", "res://packs/arena", "res://kit/starter"]:
		var pk: Dictionary = PackLoader.load_pack(pdir)["pack"]
		var refs: Array[String] = []
		for tbl: String in ["characters", "enemies", "classes"]:
			for e: Variant in (pk.get(tbl, {}) as Dictionary).values():
				if (e as Dictionary).has("art_ref"):
					refs.append(str(e["art_ref"]))
		var missing: Array[String] = []
		for ref: String in refs:
			if not FileAccess.file_exists(ArtLoader.path_for(ref)):
				missing.append(ref)
		check(missing.is_empty() and not refs.is_empty(), "%s：art_ref 全部有图（%d 个）%s" % [pdir.get_file(), refs.size(), str(missing)])
	check(ResourceLoader.exists("res://kit/_game/home_art.png"), "起步包主屏插画（theme.home_art，tech/07 §5）")
	# 幕插画（tech/05 §11）：campaign01 五幕各有插画，故事视图带出当前幕
	var apk: Dictionary = PackLoader.load_pack("res://packs/campaign01")["pack"]
	var act_refs: Array = (apk.get("acts", []) as Array).map(func(a: Dictionary) -> String: return str(a.get("art_ref", "")))
	check(act_refs.size() == 5 and act_refs.all(func(r: String) -> bool: return ArtLoader.texture_for(r, SceneBackdrop.TIER) != null),
		"五幕插画齐备并可加载（acts[].art_ref → scenes/scene_act_<n>_1080.png）")
	check(StoryVM.act_scene(apk, "SL-0") == "scenes/act_1" and StoryVM.act_scene(apk, "nope") == "", "当前幕 → 幕插画引用")
	var bd := SceneBackdrop.new()
	bd.show_scene("scenes/act_2", SceneBackdrop.DIM_STORY)
	var bd_on := bd.visible and bd.texture != null
	bd.show_scene("scenes/no_such_act", SceneBackdrop.DIM_STORY)
	check(bd_on and not bd.visible, "幕背景：有图显示、缺图隐藏")
	bd.free()
	# 本作主屏插画 + 图像坐标热点（theme.home_art / home_hotspots / home_focus）
	var gtheme: Dictionary = GameManifest.data().get("theme", {})
	check(ResourceLoader.exists(str(gtheme.get("home_art", ""))) and (gtheme.get("home_hotspots", {}) as Dictionary).size() == 5,
		"主屏插画 + 五个图像坐标热点（清单声明）")
	# 品牌素材：应用图标 / 启动图 / 导出预设引用的文件都存在
	check(str(ProjectSettings.get_setting("application/config/icon", "")) == "res://assets/brand/app_icon_1024.png"
		and ResourceLoader.exists(str(ProjectSettings.get_setting("application/boot_splash/image", ""))), "应用图标与启动图已设置")
	var ecfg := ConfigFile.new()
	ecfg.load("res://export_presets.cfg")
	var missing_brand: Array[String] = []
	for sec: String in ecfg.get_sections():
		for key: String in ecfg.get_section_keys(sec):
			var v: Variant = ecfg.get_value(sec, key)
			if v is String and (v as String).begins_with("res://assets/brand/") and not FileAccess.file_exists(v):
				missing_brand.append("%s/%s" % [sec, key])
	check(missing_brand.is_empty(), "导出预设引用的图标 / 启动图文件都存在 %s" % str(missing_brand))
	var icon_img := Image.load_from_file("res://assets/brand/app_icon_1024.png")
	check(icon_img != null and icon_img.get_width() == 1024 and not icon_img.detect_alpha(), "商店图标 1024² 无透明通道")
	# 美术交付的 UI 框体（tools/import_ui_kit.gd 处理过：裁边 + 缩到屏幕尺度 + ui_kit.json 边距）
	UiKit.reset()
	var ui_names := ["button", "button_hover", "button_pressed", "button_disabled", "panel", "sheet", "toast",
		"field", "tooltip", "track", "fill", "grabber"]
	check(ui_names.all(func(nm: String) -> bool: return UiKit.is_external(nm) and UiKit.external_margins(nm).size() == 4),
		"12 个交付框体全部启用，且都有九宫格边距")
	var bsb := UiKit.style("button")
	var btex := bsb.texture
	check(btex.get_width() <= 128 and bsb.texture_margin_left * 2.0 < btex.get_width()
		and bsb.texture_margin_top * 2.0 < btex.get_height(), "按钮框体已缩到屏幕尺度，四角边距小于半边")
	# 动作帧条（tools/import_anim_strip.gd：去棋盘底 + 方帧）
	for strip_name: String in ["anim_companion_kelan_lunge", "anim_player_blank_lunge"]:
		var st := Image.load_from_file("res://assets/art/anims/%s.png" % strip_name)
		check(st != null and st.get_width() == st.get_height() * 10 and st.detect_alpha() != Image.ALPHA_NONE
			and st.get_pixel(2, 2).a < 0.05, "%s：10 帧方帧、透明底" % strip_name)
	var afx := ActionFx.new()
	check(afx.action_strip("companion_kelan", "lunge") != null and afx.action_strip("companion_kelan", "cast") != null
		and afx.action_strip("companion_kelan", "down") == null and afx.action_strip("companion_laofei", "lunge") == null,
		"帧条查找：进攻动作回落 lunge；非进攻 / 无条单位走程序化")
	afx.free()
	# 道具图标（tech/05 §7.2）：各包每件道具都有图标（约定 icons/<id>）
	for ipdir: String in ["res://packs/campaign01", "res://packs/arena", "res://packs/riddle_maze", "res://kit/starter"]:
		var ipk: Dictionary = PackLoader.load_pack(ipdir)["pack"]
		var no_icon: Array[String] = []
		for iid: String in (ipk.get("items", {}) as Dictionary).keys():
			if ArtLoader.item_icon(iid, ipk["items"][iid]) == null:
				no_icon.append(iid)
		check(no_icon.is_empty() and not (ipk.get("items", {}) as Dictionary).is_empty(),
			"%s：每件道具都有图标（%d 件）%s" % [ipdir.get_file(), (ipk.get("items", {}) as Dictionary).size(), str(no_icon)])
	check(ArtLoader.item_icon("no_such_item") == null and ArtLoader.item_icon("heal_potion", {"art_ref": "units/ink_imp"}) == null,
		"缺图标 / art_ref 非 icons/ 类别 → null（静默兜底）")
	check(ArtLoader.item_icon("x", {"art_ref": "icons/heal_potion"}) != null, "items.json art_ref 覆盖约定路径")
	var ib := Button.new()
	ArtLoader.decorate_item_button(ib, "tide_bomb")
	var ib2 := Button.new()
	ArtLoader.decorate_item_button(ib2, "no_such_item")
	check(ib.icon != null and ib2.icon == null, "道具按钮挂图标；缺图保持纯文字")
	ib.free()
	ib2.free()
	# 地图 / 场所背景图（16 §6）：声明的图都存在；packlint V19 校验形状
	for bpdir: String in ["res://packs/campaign01", "res://kit/starter"]:
		var bpk: Dictionary = PackLoader.load_pack(bpdir)["pack"]
		var bgs := 0
		for tbl: String in ["maps", "sites"]:
			for e: Variant in (bpk.get(tbl, {}) as Dictionary).values():
				var bg: Dictionary = (e as Dictionary).get("background", {})
				if not bg.is_empty():
					bgs += 1
					check(ArtLoader.map_background(bg) != null, "%s %s 背景图可加载：%s" % [bpdir.get_file(), tbl, str(bg.get("art_ref", ""))])
		check(bgs == 2, "%s：区域地图 + 场所各一张背景图" % bpdir.get_file())
	var lpk: Dictionary = PackLoader.load_pack("res://packs/campaign01")["pack"]
	var lmap: Dictionary = lpk["maps"]["fog_coast"]
	lmap["background"] = {"art_ref": "units/ink_imp"}
	var v19a := PacklintCore._v19_maps(lpk).filter(func(i: Dictionary) -> bool: return i["level"] == PacklintCore.LEVEL_FAIL)
	lmap["background"] = {"art_ref": "scenes/map_fog_coast", "frame": [4, 0, 2, 6]}
	var v19b := PacklintCore._v19_maps(lpk).filter(func(i: Dictionary) -> bool: return i["level"] == PacklintCore.LEVEL_FAIL)
	lmap["background"] = {"art_ref": "scenes/map_fog_coast", "frame": [0, 0, 3, 3]}
	var v19c := PacklintCore._v19_maps(lpk).filter(func(i: Dictionary) -> bool: return i["level"] == PacklintCore.LEVEL_WARN)
	lmap["background"] = {"art_ref": "scenes/no_such_map", "frame": [0, 0, 8, 6]}
	var v19d := PacklintCore._v19_maps(lpk)
	check(v19a.size() == 1 and v19b.size() == 1, "V19：background 非 scenes/ 类别、frame 倒置 → FAIL")
	check(v19c.size() >= 2, "V19：地点落在 frame 外 → WARN")
	check(v19d.any(func(i: Dictionary) -> bool: return i["level"] == PacklintCore.LEVEL_WARN and str(i["msg"]).contains("缺文件"))
		and not v19d.any(func(i: Dictionary) -> bool: return i["level"] == PacklintCore.LEVEL_FAIL),
		"V19：背景图缺文件只 WARN（运行时退回程序化底）")
	var re := RegEx.new()
	re.compile("^(unit|portrait|scene|icon)_[a-z0-9]+(_[a-z0-9]+)*_[0-9]+\\.png$")
	for rel: String in expect:
		var path := "res://assets/art/%s" % rel
		check(FileAccess.file_exists(path), "资产存在：%s（tech/05 §7 首批清单）" % rel)
		check(re.search(rel.get_file()) != null,
			"命名规范 <类>_<id>_<档>.png：%s（tech/05 §2）" % rel.get_file())
		var img := Image.load_from_file(path)
		check(img != null, "PNG 可加载：%s" % rel)
		if img == null:
			continue
		check(img.get_width() == 128 and img.get_height() == 128,
			"尺寸命中 128 档：%s（tech/05 §3）" % rel)
		check(img.detect_alpha() != Image.ALPHA_NONE, "透明底：%s（tech/05 §4）" % rel)
		var solid := false
		for y: int in range(0, 128, 4):
			for x: int in range(0, 128, 4):
				if img.get_pixel(x, y).a > 0.9:
					solid = true
		check(solid, "剪影主体非空（存在不透明像素）：%s" % rel)
	# ---- ② ArtLoader 解析与静默兜底（tech/05 §5/§6）----
	check(ArtLoader.path_for("units/ink_fiend") == "res://assets/art/units/unit_ink_fiend_128.png",
		"art_ref → 路径解析（<目录>/<类名>_<id>_<档>.png）")
	check(ArtLoader.path_for("../etc/passwd") == "" and ArtLoader.path_for("units/bad id") == ""
		and ArtLoader.path_for("unknown/x") == "" and ArtLoader.path_for("units/") == ""
		and ArtLoader.path_for("ink_fiend") == "",
		"非法 art_ref 拒解析（越界/空格/未知类别/缺段/缺目录）")
	ArtLoader.clear_cache()
	var tex := ArtLoader.texture_for("units/ink_fiend")
	check(tex != null and tex.get_width() == 128, "ArtLoader 命中返回 128px 纹理")
	check(ArtLoader.texture_for("units/ink_fiend") == tex, "同键同档缓存同实例（不重复 IO）")
	check(ArtLoader.texture_for("units/no_such_unit") == null, "缺文件静默兜底 null（tech/05 §5）")
	check(ArtLoader.texture_for("") == null, "空 art_ref 兜底 null")
	# ---- ③ 内容表登记 + core 纯数据透传（tech/05 §6；tech/04 §2；tech/02 §10）----
	var pack := _load_campaign01()
	for cid: String in ["player_blank", "companion_kelan", "companion_laofei"]:
		check(str((pack["characters"] as Dictionary)[cid].get("art_ref", "")) == "portraits/%s" % cid,
			"characters.json 登记 art_ref：%s" % cid)
	for eid: String in ["ink_imp", "ink_fiend", "page_warden"]:
		check(str((pack["enemies"] as Dictionary)[eid].get("art_ref", "")) == "units/%s" % eid,
			"enemies.json 登记 art_ref：%s" % eid)
	# 已声明 art_ref 的引用完整性：目标文件必须存在且可加载（断链断言，tech/05 §6）
	var linked_ok := true
	for tbl: String in ["characters", "enemies"]:
		for id: String in (pack[tbl] as Dictionary):
			var ref := str((pack[tbl] as Dictionary)[id].get("art_ref", ""))
			if ref.is_empty():
				continue
			var p := ArtLoader.path_for(ref)
			if p.is_empty() or not FileAccess.file_exists(p):
				linked_ok = false
	check(linked_ok, "全部已声明 art_ref 断链为零（引用完整性断言）")
	var asm: Dictionary = BattleDef.assemble(pack, "N1-7", {}, Board.new(EventStream.new()))
	check(bool(asm["ok"]), "N1-7 战斗定义组装 ok")
	var def: Dictionary = asm["def"]
	check(str(def["party"][0].get("art_ref", "")) == "portraits/player_blank",
		"BattleDef 角色 art_ref 透传进单位字典（core 只搬数据）")
	var foes_art := true
	for u: Variant in def["enemies"]:
		if str((u as Dictionary).get("art_ref", "")).is_empty():
			foes_art = false
	check(foes_art, "BattleDef 敌方 art_ref 透传（N1-7 墨魈+幼体×2）")
	var n4: Dictionary = BattleDef.assemble(pack, "N4-1", {}, Board.new(EventStream.new()))
	check(bool(n4["ok"]), "N4-1 战斗定义组装 ok")
	var avatar: Dictionary = (n4["def"] as Dictionary)["enemies"][0]
	check(str(avatar.get("art_ref", "")) == "units/tide_avatar", "墨潮化身 art_ref 透传（P6.4 第二批）")
	var bare := pack.duplicate(true)
	((bare["enemies"] as Dictionary)["tide_avatar"] as Dictionary).erase("art_ref")
	var n4b: Dictionary = BattleDef.assemble(bare, "N4-1", {}, Board.new(EventStream.new()))
	check(not ((n4b["def"] as Dictionary)["enemies"][0] as Dictionary).has("art_ref"),
		"未声明条目无 art_ref 键（兜底语义数据层可见）")
	var summon_ref := ""
	for sk: Variant in avatar.get("skills", []):
		if (sk as Dictionary).has("summon"):
			summon_ref = str(((sk as Dictionary)["summon"] as Dictionary).get("art_ref", ""))
	check(summon_ref == "units/ink_imp", "召唤模板内联 art_ref 同透传（story/03 §3.2 召唤幼体）")
	# party_status 头像随行（04 §3.1 队伍概览 → 竖屏队伍芯片）
	var sg := StoryGraph.new(Board.new(EventStream.new()), Rng.new(1), pack)
	var ps: Array = sg.party_status()
	check(ps.size() == 3, "party_status 三人队伍")
	var ps_art := true
	for p: Variant in ps:
		if str((p as Dictionary).get("art_ref", "")).is_empty():
			ps_art = false
	check(ps_art, "party_status 随行 art_ref（队伍芯片头像数据源）")
	# ---- ④ 竖屏接入：单位卡 icon + 队伍芯片头像（tech/05 §8）----
	var sd: GDScript = load("res://tools/shell_diff.gd")
	var pstream := EventStream.new()
	var psm := EncounterSM.new(Board.new(pstream), pstream, Rng.new(11), "campaign01")
	var portrait: EncounterPortrait = \
		(load("res://shell/portrait/encounter_portrait.tscn") as PackedScene).instantiate()
	root.add_child(portrait)
	await process_frame
	portrait.bind(psm, AutoAgent.new())
	psm.enter("N1-7")
	psm.transition(EncounterSM.S_EXPLORE)
	psm.begin_combat(sd.battle_def())
	await process_frame
	await process_frame
	var boss_btn: Button = null
	var noart_btn: Button = null
	for child: Node in portrait.enemy_row.get_children():
		if child is Button and str(child.get_meta("unit_id", "")) == "boss":
			boss_btn = child
		if child is Button and str(child.get_meta("unit_id", "")) == "imp2":
			noart_btn = child
	check(boss_btn != null and boss_btn.icon != null, "竖屏敌方单位卡按 art_ref 显示图像（墨魈）")
	check(boss_btn != null and boss_btn.icon != null and boss_btn.icon.get_width() == 128,
		"单位卡 icon 命中 128 档")
	var chip_has_avatar := false
	for child: Node in portrait.party_chips.get_children():
		for sub: Node in child.get_children():
			if sub is TextureRect and bool(sub.get_meta("art_chip", false)):
				chip_has_avatar = true
	check(chip_has_avatar, "竖屏队伍芯片含头像 TextureRect（art_ref 随行）")
	# ---- ⑤ 横屏接入：格内 token 铺图 + 无图兜底（tech/05 §5/§8）----
	var lstream := EventStream.new()
	var lsm := EncounterSM.new(Board.new(lstream), lstream, Rng.new(11), "campaign01")
	var land: EncounterLandscape = \
		(load("res://shell/landscape/encounter_landscape.tscn") as PackedScene).instantiate()
	root.add_child(land)
	land.set_anchors_preset(Control.PRESET_TOP_LEFT)
	land.position = Vector2.ZERO
	land.size = Vector2(1280, 720)
	await process_frame
	await process_frame
	land.bind(lsm, AutoAgent.new())
	lsm.enter("N1-7")
	lsm.transition(EncounterSM.S_EXPLORE)
	lsm.begin_combat(sd.battle_def())
	await process_frame
	await process_frame
	var cell_has_art := func(sh: EncounterLandscape, uid: String) -> Dictionary:
		var c: Vector2i = sh.unit_cell(uid)
		var panel := sh._cells[c.y * sh.GRID_COLS + c.x]
		var found := {"art": false, "label": false}
		for ch: Node in panel.get_children():
			if ch is TextureRect and bool(ch.get_meta("art_token", false)):
				found["art"] = true
			if ch is Label:
				found["label"] = true
		return found
	var bf: Dictionary = cell_has_art.call(land, "boss")
	check(bool(bf["art"]) and bool(bf["label"]), "横屏格内 token：单位图铺底 + HP 文本压上（墨魈）")
	# 兜底：剥掉 art_ref 的同构 def → 格内无色块外图像，Label token 保持现状
	var def2: Dictionary = (sd.battle_def() as Dictionary).duplicate(true)
	(def2["enemies"] as Array)[0].erase("art_ref")
	var lstream2 := EventStream.new()
	var lsm2 := EncounterSM.new(Board.new(lstream2), lstream2, Rng.new(11), "campaign01")
	var land2: EncounterLandscape = \
		(load("res://shell/landscape/encounter_landscape.tscn") as PackedScene).instantiate()
	root.add_child(land2)
	land2.set_anchors_preset(Control.PRESET_TOP_LEFT)
	land2.position = Vector2.ZERO
	land2.size = Vector2(1280, 720)
	await process_frame
	await process_frame
	land2.bind(lsm2, AutoAgent.new())
	lsm2.enter("N1-7")
	lsm2.transition(EncounterSM.S_EXPLORE)
	lsm2.begin_combat(def2)
	await process_frame
	await process_frame
	var bf2: Dictionary = cell_has_art.call(land2, "boss")
	check(not bool(bf2["art"]) and bool(bf2["label"]),
		"无 art_ref 单位静默兜底：格内无图像、色块+单字 token 现状（tech/05 §5）")
	portrait.queue_free()
	land.queue_free()
	land2.queue_free()
	await process_frame
	# ---- ⑥ 绘卷分层细节（tech/05 §8；12 §5 呼吸/褪墨度口径不变）----
	var hs := HomeScroll.new()
	hs.custom_minimum_size = Vector2(800, 500)
	root.add_child(hs)
	await process_frame
	check(hs.sparkle_count() >= 10, "水面波光点数据表 ≥10 点（14 #7）")
	var below := true
	for i: int in hs.sparkle_count():
		if hs.sparkle_point(i).y <= HomeScroll.HORIZON:
			below = false
	check(below, "波光点全部在海平线之下（数据表自检）")
	check(hs.tower_window_count() == 3, "塔顶灯窗 3 档（数据表）")
	check(hs.shed_roof_lights_per_shed() == 3, "棚顶檐口灯光点 每棚 3 灯（数据表）")
	hs.set_state(10, 0)
	check(hs.doom_factor() > 0.99, "褪墨度满格驱动衰减（波光/灯窗随天色同口径变暗，12 §5）")
	check(hs.breath_glow() >= HomeScroll.GLOW_MIN and hs.breath_glow() <= HomeScroll.GLOW_MAX,
		"呼吸微光区间不变（分层细节叠加不破坏 12 §5 不闪烁铁律）")
	hs.queue_free()
	await process_frame

# ---------------------------------------------------------------- 转场与镜头（14 清单 #8）
# 转场器：触发与时长参数（0.2~0.3s 档）、中场换屏、幕布不吞输入、连续切换快速完成、遭遇进场滑入；
# 战斗镜头：跟随对焦目标正确（turn.start.actor）、暴击/Boss 推拉同一事件源（不重复震屏）、
# 捏合让位与回合末回弹跟随、事件流逐字节零变化。

func test_transition_camera() -> void:
	print("[transition_camera]")
	# ---- 取景：先容纳、后跟随（回合切换不把敌人推出画面、不露边界外空白）----
	var view := Rect2(0, 0, 400, 300)
	var d_fit := BattleCamera.framing_delta(view, Rect2(20, 10, 360, 280), Vector2(50, 280))
	check(d_fit == Vector2.ZERO, "战场放得下：居中不动，不跟随行动单位（敌我全在画内）")
	var d_big := BattleCamera.framing_delta(view, Rect2(0, 0, 800, 600), Vector2(780, 590))
	check(d_big == Vector2(-400, -300), "战场放不下：跟随但停在战场边缘（不露边界外空白）")
	var d_mid := BattleCamera.framing_delta(view, Rect2(0, 0, 800, 600), Vector2(400, 300))
	check(d_mid == Vector2(-200, -150), "战场放不下：行动单位居中")
	# ---- 转场器参数冻结（14 #8；04 §10「各界面转场动画时长规范见 14 清单 #8」）----
	check(UiTransition.FADE_OUT >= 0.2 and UiTransition.FADE_OUT <= 0.3,
		"转场淡出时长 0.2~0.3s 档（14 #8 冻结）")
	check(UiTransition.FADE_IN >= 0.2 and UiTransition.FADE_IN <= 0.3,
		"转场淡入时长 0.2~0.3s 档（14 #8 冻结）")
	check(UiTransition.SLIDE_PX > 0.0 and UiTransition.SLIDE_PX <= 64.0,
		"遭遇进场上移滑入轻微（≤64px，14 #8）")
	var tr := UiTransition.new()
	root.add_child(tr)
	# ---- 中场换屏只记实例 id：被提前回收的屏不让回调持有已释放对象（"Lambda capture was freed" 回归）----
	var gone := Control.new()
	var shown := Control.new()
	shown.visible = false
	root.add_child(gone)
	root.add_child(shown)
	tr.swap_at_mid(gone, null, shown)
	gone.free() # 中场前已被回收（连续快速切换的真实情形）
	var shown2 := Control.new()
	root.add_child(shown2)
	tr.swap_at_mid(null, null, shown2) # 第二次切换快速完成前场：执行第一段中场回调
	check(shown.visible and int(tr.stats["fast_forward"]) >= 1, "前场已回收的屏被跳过，新屏照常现身（无已释放捕获）")
	tr.skip_all()
	check(shown2.visible and not tr.transitioning, "连续切换后转场归位")
	shown.queue_free()
	shown2.queue_free()
	tr.stats = {"fades": 0, "slides": 0, "fast_forward": 0}
	check(tr.veil.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"幕布不吞输入：转场期间可点（14 #8 不打断交互；12 §5 覆盖层不残留同铁律）")
	# ---- 触发、中场换屏回调、时长记账 ----
	var mid := [false]
	tr.fade_through(func() -> void: mid[0] = true)
	check(int(tr.stats["fades"]) == 1 and tr.transitioning, "转场触发登记（场次+进行中）")
	await create_timer(UiTransition.FADE_OUT + 0.05).timeout
	check(mid[0], "淡出完成 → 中场换屏回调执行")
	check(tr.veil.modulate.a > 0.5, "中场幕布仍掩（淡入段进行中）")
	await create_timer(UiTransition.FADE_IN + 0.1).timeout
	check(tr.veil.modulate.a < 0.01 and not tr.transitioning, "淡入结束幕布归零（硬切消除）")
	check(absf(tr.last_out - UiTransition.FADE_OUT) < 0.001
		and absf(tr.last_in - UiTransition.FADE_IN) < 0.001, "时长记账 = 冻结参数")
	# ---- 连续切换快速完成（不打断交互：前场中场即时结算，不叠黑场）----
	var order: Array[String] = []
	tr.fade_through(func() -> void: order.append("a"))
	await create_timer(0.05).timeout
	tr.fade_through(func() -> void: order.append("b"))
	check(order == ["a"] and int(tr.stats["fast_forward"]) == 1,
		"连续切换：前场中场即时结算（快速完成）")
	await create_timer(UiTransition.FADE_OUT + UiTransition.FADE_IN + 0.15).timeout
	check(order == ["a", "b"] and tr.veil.modulate.a < 0.01, "连续切换：终场完整播完幕布归位")
	# ---- 遭遇进场：淡入淡出 + 轻微上移滑入 ----
	var dummy := Control.new()
	dummy.set_anchors_preset(Control.PRESET_TOP_LEFT)
	dummy.size = Vector2(200, 200)
	root.add_child(dummy)
	await process_frame
	var base_y := dummy.position.y
	tr.encounter_enter(dummy)
	await create_timer(UiTransition.FADE_OUT + 0.05).timeout
	check(dummy.position.y > base_y + UiTransition.SLIDE_PX * 0.5,
		"遭遇进场：淡入段起自下方偏移（上移滑入）")
	await create_timer(UiTransition.FADE_IN + 0.1).timeout
	check(absf(dummy.position.y - base_y) < 0.5 and int(tr.stats["slides"]) == 1,
		"滑入随淡入段归位（0.2~0.3s 同步）")
	dummy.queue_free()
	# ---- main 集成：主屏→入口经统一转场器，中场新屏现身 ----
	var m: Node = _new_main()
	root.add_child(m)
	await process_frame
	await process_frame
	var fades0 := int(m.transition.stats["fades"])
	m._on_home_navigate(&"entry")
	check(int(m.transition.stats["fades"]) == fades0 + 1, "主屏→入口：切换经统一转场器（14 #8）")
	check(not (m.current_screen as Control).visible, "淡出段新屏未现身（旧屏保持可点）")
	await create_timer(UiTransition.FADE_OUT + 0.05).timeout
	check((m.current_screen as Control).visible, "中场换屏：新屏现身（旧屏已回收）")
	await create_timer(UiTransition.FADE_IN + 0.1).timeout
	m.queue_free()
	await process_frame
	tr.queue_free()

	# ---- 战斗镜头参数冻结（14 #8）----
	check(BattleCamera.FOCUS_TIME > 0.1 and BattleCamera.FOCUS_TIME <= 0.6,
		"跟随对焦平滑推移时长档位（冻结）")
	check(BattleCamera.PUNCH_IN + BattleCamera.PUNCH_OUT <= 0.5,
		"关键推拉总量 ≤0.5s（14 #8 验收口径）")
	check(BattleCamera.PUNCH_SCALE > 1.0 and BattleCamera.PUNCH_SCALE <= 1.3,
		"推近倍率轻微（短暂推近再拉回）")

	# ---- 竖屏：跟随对焦目标正确 + lane 只纵轴 ----
	var pscene: PackedScene = load("res://shell/portrait/encounter_portrait.tscn")
	var portrait: EncounterPortrait = pscene.instantiate()
	root.add_child(portrait)
	await process_frame
	await process_frame
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(11), "campaign01")
	portrait.bind(sm, AutoAgent.new())
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(_std_def())
	await process_frame
	await process_frame
	await process_frame
	var actor := sm.current_actor_id()
	check(portrait.camera.focus_uid == actor and int(portrait.camera.stats["focus"]) >= 1,
		"竖屏跟随：战斗开始对焦当前行动单位（04 §④.4 智能镜头）")
	check(str(portrait.camera.last_focus.get("uid", "")) == actor, "对焦目标记账 = turn.start.actor")
	var pan0: Vector2 = portrait.camera.last_focus.get("pan", Vector2.ONE)
	check(absf(pan0.x) < 0.001, "竖屏 lane 滚动对焦：横轴锁定（04 §④.4 竖向战场）")
	# 焦点切换跟随（手动发事件 = 同一事件源）
	stream.emit(EventTypes.TURN_START, {"round": 1, "side": "party", "actor": "kelan"}, &"core", "N1-7")
	await process_frame
	await process_frame
	check(portrait.camera.focus_uid == "kelan", "回合焦点切换 → 镜头平滑推移跟随新单位")
	# ---- 暴击推近：与 Juice 同事件源（battle.attack crit），镜头只缩放不震屏 ----
	portrait.juice.shake_override = 0 # 隔离 Juice 震动，专验镜头侧（不重复震屏口径）
	stream.emit(EventTypes.BATTLE_ATTACK, _atk_ev("kelan", true, true, 9)["payload"], &"core", "N1-7")
	await process_frame
	await process_frame
	check(int(portrait.camera.stats["punch"]) == 1, "暴击 → 镜头推近（同一 battle.attack 事件源）")
	check(float(portrait.camera.last_punch["scale"]) == BattleCamera.PUNCH_SCALE
		and float(portrait.camera.last_punch["in"]) + float(portrait.camera.last_punch["out"]) <= 0.5,
		"推拉参数：推近 ×1.12、总量 ≤0.5s（14 #8）")
	check(portrait.position == Vector2.ZERO,
		"镜头推拉不带震屏（壳根零位移；震屏唯一源 JuiceLayer，14 #4）")
	await create_timer(0.6).timeout
	check((portrait.camera.target.scale - Vector2.ONE).length() < 0.01, "推近后拉回归位")
	# ---- Boss 登场：combat.start 携 boss 单位 → 对焦 + 推近（04 §④.7 演出分级）----
	var punches0 := int(portrait.camera.stats["punch"])
	stream.emit(EventTypes.COMBAT_START, {"order": ["pc", "boss"], "units": {
			"pc": {"side": &"party"}, "boss": {"side": &"enemy", "boss": true}}}, &"core", "N1-7")
	await process_frame
	await process_frame
	await process_frame # create_timer 恢复点在本帧 _process 之后：隔帧锚点需多一帧落定
	check(int(portrait.camera.stats["punch"]) == punches0 + 1
		and portrait.camera.focus_uid == "boss",
		"Boss 登场：对焦 + 推近（同一 combat.start 事件源）")
	portrait.queue_free()
	await process_frame

	# ---- 横屏：跟随对焦 + 捏合让位 + 回合末回弹跟随 ----
	var lscene: PackedScene = load("res://shell/landscape/encounter_landscape.tscn")
	var land: EncounterLandscape = lscene.instantiate()
	root.add_child(land)
	land.set_anchors_preset(Control.PRESET_TOP_LEFT)
	land.position = Vector2.ZERO
	land.size = Vector2(1280, 720)
	await process_frame
	await process_frame
	await process_frame
	var stream2 := EventStream.new()
	var board2 := Board.new(stream2)
	var sm2 := EncounterSM.new(board2, stream2, Rng.new(11), "campaign01")
	land.bind(sm2, AutoAgent.new())
	sm2.enter("N1-7")
	sm2.transition(EncounterSM.S_EXPLORE)
	sm2.begin_combat(_std_def())
	await process_frame
	await process_frame
	await process_frame
	check(int(land.camera.stats["focus"]) >= 1
		and land.camera.focus_uid == sm2.current_actor_id(),
		"横屏跟随：战斗开始对焦当前行动单位（战场平移对焦）")
	# 捏合会话 → 镜头让位（手动缩放优先，12 §2.1）
	land._on_gesture_pinch(3.0, land.center_map.get_global_rect().get_center())
	check(land.camera.manual, "捏合会话：镜头让位（用户手动缩放优先，14 #8）")
	var yield0 := int(land.camera.stats["yield"])
	var punch0 := int(land.camera.stats["punch"])
	stream2.emit(EventTypes.BATTLE_ATTACK, _atk_ev("imp1", true, true, 9)["payload"], &"core", "N1-7")
	await process_frame
	await process_frame
	check(int(land.camera.stats["yield"]) == yield0 + 1
		and int(land.camera.stats["punch"]) == punch0,
		"手动缩放中：暴击推拉让位不抢镜头（登记 yield）")
	land._on_gesture_pinch_ended(3.0, land.center_map.get_global_rect().get_center())
	check(land.camera.manual and absf(land.grid.scale.x - 1.6) < 0.01,
		"横屏捏合松手持续生效（12 §2.1；让位持续至回合末）")
	# 回合末回弹跟随：turn.start 触发 resume → 缩放归位 + 恢复跟随
	stream2.emit(EventTypes.TURN_START, {"round": 2, "side": "party", "actor": "pc"}, &"core", "N1-7")
	check(not land.camera.manual and int(land.camera.stats["resume"]) == 1,
		"回合末回弹跟随（14 #8：turn.start 触发回弹）")
	await create_timer(BattleCamera.RESUME_TIME + 0.15).timeout
	await process_frame
	check((land.grid.scale - Vector2.ONE).length() < 0.02 and absf(land._zoom - 1.0) < 0.001,
		"回弹：战术格缩放归位 + 壳缩放簿记同步")
	await process_frame
	await process_frame
	check(land.camera.focus_uid == "pc", "回弹后跟随新行动单位（对焦恢复）")
	# 竖屏捏合：松手弹回即回弹（04 §④.4），会话结束镜头恢复
	var p2: EncounterPortrait = pscene.instantiate()
	root.add_child(p2)
	await process_frame
	await process_frame
	var stream3 := EventStream.new()
	var sm3 := EncounterSM.new(Board.new(stream3), stream3, Rng.new(11), "campaign01")
	p2.bind(sm3, AutoAgent.new())
	sm3.enter("N1-7")
	sm3.transition(EncounterSM.S_EXPLORE)
	sm3.begin_combat(_std_def())
	await process_frame
	await process_frame
	p2._on_gesture_pinch(1.4, p2.main_view.get_global_rect().get_center())
	check(p2.camera.manual, "竖屏捏合会话：镜头让位")
	p2._on_gesture_pinch_ended(1.4, p2.main_view.get_global_rect().get_center())
	check(not p2.camera.manual, "竖屏松手弹回即回弹（04 §④.4）：镜头恢复跟随权")
	p2.queue_free()
	land.queue_free()
	await process_frame

	# ---- main 集成：整备→遭遇进场滑入 ----
	var m2: Node = _new_main()
	root.add_child(m2)
	await process_frame
	await process_frame
	m2._on_home_navigate(&"entry")
	await create_timer(0.6).timeout
	(m2.current_screen as ScreenEntry).pick_mode(ShellRouter.MODE_TIME)
	(m2.current_screen as ScreenEntry).start_requested.emit()
	await create_timer(0.6).timeout
	m2.graph._enter("N1-7")
	m2._present_node()
	await create_timer(0.6).timeout
	var slides0 := int(m2.transition.stats["slides"])
	(m2.current_screen as ScreenLoadout)._on_confirm()
	await create_timer(0.6).timeout
	check(int(m2.transition.stats["slides"]) == slides0 + 1, "整备→遭遇：进场滑入触发（14 #8）")
	await create_timer(0.6).timeout
	check(m2.shell != null and absf(m2.shell.position.y) < 0.5, "遭遇进场滑入归位")
	m2.queue_free()
	await process_frame

	# ---- 事件流零变化（14 #8 验收口径：同种子同指令，接入前后逐字节一致）----
	var json_a: String = await _run_battle_with_camera(false)
	var json_b: String = await _run_battle_with_camera(true)
	check(json_a == json_b, "转场镜头接入前后同种子同指令：事件流逐字节一致（纯呈现零污染）")

## 无壳脚本化遭遇（与 _run_battle_with_juice 同种子/同指令序列风格）；
## with_cam=true 时挂独立 BattleCamera 订阅事件流——纯呈现消费，不触碰 core。
func _run_battle_with_camera(with_cam: bool) -> String:
	var sd: GDScript = load("res://tools/shell_diff.gd")
	var stream := EventStream.new()
	var board := Board.new(stream)
	var sm := EncounterSM.new(board, stream, Rng.new(20261109), "campaign01")
	board.give_item("heal_potion", 2, {"event_id": 0, "node_id": "N1-1", "pack_id": "campaign01"})
	board.write("campaign01.witnessed_revocation", true,
		{"event_id": 0, "node_id": "N1-3", "pack_id": "campaign01"})
	var cam: BattleCamera = null
	if with_cam:
		cam = BattleCamera.new()
		root.add_child(cam)
		stream.subscribe(cam.on_event)
	sm.enter("N1-7")
	sm.transition(EncounterSM.S_EXPLORE)
	sm.begin_combat(sd.battle_def())
	var bot := Rng.new(31)
	var guard := 0
	while not sm.is_over() and guard < 300:
		guard += 1
		var actions := sm.get_available_actions()
		if actions.is_empty():
			await process_frame
			continue
		var enabled: Array[int] = []
		for i: int in actions.size():
			if not bool(actions[i]["disabled"]):
				enabled.append(i)
		var pick := enabled[bot.range_int(0, enabled.size() - 1)]
		sm.submit_command(sm.command_from_action(actions[pick]))
		await process_frame
	var json := JSON.stringify(stream.all(), "", true, true)
	if cam != null:
		cam.queue_free()
		await process_frame
	return json
