# bot 仿真核（TASKS P1.5 TP1；检定公式依据 framework/11-轻规则包-v1.md §3）
# - 从入口节点随机走图：choice 随机（含策略优先项）/ check 用种子化 RNG 掷 d20 判成败 /
#   item·reputation 边由 StoryGraph 条件求值显隐 / 战斗节点按难度直接判胜（不跑战斗数值，TP1 范围）；
# - hub（N1-1）执行"购买半页潮汐表"策略（战役书 §8 投放点）；
# - 二周目配置（ngplus=true）：初始 inv 含 codex_fragment×1（战役书 §8 多周目继承 ×1）；
#   羁绊不再注入——按 TP1 验收裁决 2 改为图内投放，二周目以"上一周目（同包异种子）图内所得
#   bond.kelan 继承"作为初始状态（战役书 §9 E4 钩子：收集与进度保留），不含任何非图内数值；
# - 独狼探针（lone_wolf=true）：N1-3 优先"婉拒所有邀约"、N1-8 优先独狼边（TP1 验收裁决 1 可达性验证）；
# - 纯逻辑零引擎依赖，供 tools/simulate.gd（CLI）与 tests/run.gd 复用。
class_name StoryBot
extends RefCounted

## 轻规则包三档 DC（11 文档 §3：易 8 / 中 12 / 难 16）。
const DIFF_DC := {"easy": 8, "medium": 12, "hard": 16}
## bot 角色修正占位（+2 属性档，11 文档 §1；熟练另计，仿真取中位 +2）。
const BOT_CHECK_MOD := 2
const MAX_STEPS := 200

## 跑一局。返回 {ok, reason, ending, ending_by_table, steps, visited{node_id:count},
## clock_min, clock_max, bond_max, checks{total,success}, ngplus, lone_wolf}。
## detour_probe=true（幕二绕行探针）：N1-1 不买半页潮汐表且 N1-8 优先拾遗行会链——
## 确定性覆盖 N2G-2c 无道具绕行路（tech/02 §4.3 item 边 fallback，幕二接入验收）。
## explore_probe=true（地图探针，docs/en/framework/15/16）：遇到通往 map 节点的边优先走；在地图上
## 逐段行旅、进场所用尽可交互物与出口、事件卡随机选项、遭遇按胜计；分队后被推进上限卡住时切组。
static func run(pack: Dictionary, seed: int, ngplus: bool = false, lone_wolf: bool = false,
		detour_probe: bool = false, explore_probe: bool = false, arcs: Array = []) -> Dictionary:
	var stream := EventStream.new()
	var board := Board.new(stream)
	var rng := Rng.new(seed)
	var graph := StoryGraph.new(board, rng, pack)
	for arc: Variant in arcs: # 支线仿真（tech/11 §5）：注入后从宿主起点跑，嫁接探针优先走注入边
		graph.graft_pack(arc)
		# 道具门支线：探针开局即持有门道具（模拟买过 / 拿到它的玩家），否则入口可能永不显形
		var gedge: Dictionary = (((arc as Dictionary).get("manifest", {}) as Dictionary).get("graft", {}) as Dictionary).get("edge", {})
		if str(gedge.get("type", "")) == "item":
			board.give_item(str(gedge.get("item", "")), 1, {"event_id": 0, "node_id": "graft_probe", "pack_id": "system"})
	if ngplus:
		var prov := {"event_id": 0, "node_id": "ngplus_boot", "pack_id": "system"}
		# 多周目残简继承：数据驱动读 manifest.ngplus.carries（tech/02 §2.7；战役书 §11），缺省 1
		var carries: Dictionary = ((pack.get("manifest", {}) as Dictionary)
			.get("ngplus", {}) as Dictionary).get("carries", {})
		board.give_item("codex_fragment", int(carries.get("codex_fragment", 1)), prov)
		# 多周目羁绊继承：上一周目图内投放所得（TP1 验收裁决 2；不含注入数值）
		var prev := run(pack, seed + 1, false, false, false, false, arcs)
		var prev_bond := int(prev.get("bond_max", 0))
		if prev_bond > 0:
			board.write("global.bond.kelan", prev_bond, prov)
	graph.start()

	var visited := {}
	var clock_min := 0
	var clock_max := 0
	var checks := {"total": 0, "success": 0}
	var ending_by_table := ""
	var steps := 0
	var map_rounds := 0
	while steps < MAX_STEPS:
		steps += 1
		var node := graph.current()
		var nid := str(node.get("id", ""))
		visited[nid] = int(visited.get(nid, 0)) + 1
		var clock := board.get_doom_clock()
		clock_min = mini(clock_min, clock)
		clock_max = maxi(clock_max, clock)
		if graph.is_at_ending():
			return _result(true, "", nid, ending_by_table, steps, visited,
				clock_min, clock_max, board, checks, ngplus, lone_wolf)
		if str(node.get("type", "")) == "map" and map_rounds < 12:
			map_rounds += 1
			if _explore_map(graph, board, rng, pack):
				continue # 抵达地点节点：主循环在新节点继续
		var edges := graph.available_edges()
		if edges.is_empty() and graph.party.is_split():
			for gid: String in graph.party.others(): # 推进上限：切到其他小组（15 §2.4）
				if graph.focus_group(gid):
					break
			edges = graph.available_edges()
		if edges.is_empty():
			return _result(false, "卡在节点 %s（无可走边）" % nid, "", "", steps, visited,
				clock_min, clock_max, board, checks, ngplus, lone_wolf)
		if nid == "N4-2":
			ending_by_table = graph.pick_ending() # 结局表求值与图边选择互证（tech/02 §9）
		var edge: Dictionary = {}
		for ge: Variant in edges: # 嫁接探针：注入边（_graft）显形即走
			if not arcs.is_empty() and (ge as Dictionary).has("_graft"):
				edge = ge
				break
		if edge.is_empty():
			edge = _choose(node, edges, board, rng, ngplus, lone_wolf, detour_probe, explore_probe, pack, visited)
		if str(edge.get("type", "")) == "check":
			checks["total"] = int(checks["total"]) + 1
			var roll := rng.d20()
			# 11 文档 §3：自然 20 大成功 / 自然 1 大失败
			var success := roll == 20 or (roll != 1 and roll + BOT_CHECK_MOD >= int(DIFF_DC[str(edge.get("difficulty", "medium"))]))
			if success:
				checks["success"] = int(checks["success"]) + 1
			graph.resolve_check(edge, success)
		else:
			graph.take_edge(edge)
	return _result(false, "超步数上限 %d（疑似环）" % MAX_STEPS, "", "", steps, visited,
		clock_min, clock_max, board, checks, ngplus, lone_wolf)

static func _result(ok: bool, reason: String, ending: String, ending_by_table: String,
		steps: int, visited: Dictionary, clock_min: int, clock_max: int,
		board: Board, checks: Dictionary, ngplus: bool, lone_wolf: bool) -> Dictionary:
	var bond_max := 0
	for key: String in board.keys_with_prefix("global.bond."):
		bond_max = maxi(bond_max, int(board.read(key)))
	return {"ok": ok, "reason": reason, "ending": ending, "ending_by_table": ending_by_table,
		"steps": steps, "visited": visited, "clock_min": clock_min, "clock_max": clock_max,
		"bond_max": bond_max, "checks": checks, "ngplus": ngplus, "lone_wolf": lone_wolf}

## 选边策略：hub 优先购买潮汐表（绕行探针除外）；二周目优先拾遗行会链（密道残简，战役书 §8）；
## 独狼探针优先"婉拒所有邀约"与独狼边（TP1 验收裁决 1）；绕行探针优先拾遗行会链（N2G-2c 覆盖）；
## 终章按结局边列出顺序取首个显形边（E1→E2→E3 优先、E4 兜底，nodes.json N4-2 边序即优先级）；其余随机。
static func _choose(node: Dictionary, edges: Array, board: Board, rng: Rng,
		ngplus: bool, lone_wolf: bool, detour_probe: bool = false, explore_probe: bool = false,
		pack: Dictionary = {}, visited: Dictionary = {}) -> Dictionary:
	var nid := str(node.get("id", ""))
	if explore_probe:
		for edge: Variant in edges: # 地图探针：分队边优先（覆盖各小组支线，15）
			if str((edge as Dictionary).get("type", "")) == "split":
				return edge
		for edge: Variant in edges: # 地图探针：首次遇到通往地图节点的边就走（只走一次，免得来回绕）
			var to := str((edge as Dictionary).get("to", ""))
			if to != "" and not visited.has(to) and str(((pack.get("nodes", {}) as Dictionary).get(to, {}) as Dictionary).get("type", "")) == "map":
				return edge
	if nid == "N1-1" and detour_probe:
		for edge: Variant in edges: # 绕行探针：不买任何东西（无效果的「前往褪色现场」边）
			if ((edge as Dictionary).get("effects", []) as Array).is_empty():
				return edge
	if nid == "N1-1" and not board.has_item("half_tide_table") and not detour_probe:
		for edge: Variant in edges:
			for effect: Variant in (edge as Dictionary).get("effects", []):
				if (effect as Dictionary).get("give_item", "") == "half_tide_table":
					return edge
	if lone_wolf:
		if nid == "N1-3":
			for edge: Variant in edges:
				if str((edge as Dictionary).get("to", "")) == "N1-8":
					return edge # 婉拒所有邀约（TP1 验收裁决 1）
		if nid == "N1-8":
			for edge: Variant in edges:
				if str((edge as Dictionary).get("to", "")) == "N2L-1":
					return edge
	elif nid == "N1-8" and (ngplus or detour_probe):
		for edge: Variant in edges:
			if str((edge as Dictionary).get("to", "")) == "N2G-1":
				return edge
	if str(node.get("type", "")) == "branch" and nid == "N4-2":
		return edges[0]
	return edges[rng.range_int(0, edges.size() - 1)]

## 地图一轮（16）：随机挑一处未访问地点逐段走过去（事件卡随机选项、遭遇按胜计）；抵达地点节点返回 true，
## 抵达场所则把可交互物和出口都试一遍再离开。全部访问过 = false（主循环随后走地图节点的普通出边）。
static func _explore_map(graph: StoryGraph, board: Board, rng: Rng, pack: Dictionary) -> bool:
	var map := RegionMap.new(board, board.stream, rng, pack, str(graph.current().get("map", "")))
	var mod := Callable(graph, "check_mod")
	var targets: Array = []
	for e: Variant in map.routes_from(map.pos()):
		var other := str((e as Dictionary)["other"])
		if not map.visited().has(other) or rng.range_int(0, 3) == 0:
			targets.append(other)
	if targets.is_empty():
		return false
	if map.journey().is_empty() and map.start_journey(str(targets[rng.range_int(0, targets.size() - 1)]),
			RegionMap.PACES[rng.range_int(0, 2)], graph.current_id) != "":
		return false
	var guard := 0
	while not map.journey().is_empty() and guard < 12:
		guard += 1
		var res := map.step(mod, graph.current_id)
		graph.rescan()
		var outcome: Dictionary = res.get("outcome", {})
		if str(outcome.get("kind", "")) == "card":
			var card: Dictionary = (pack.get("cards", {}) as Dictionary).get(str(outcome["card"]), {})
			var n := (card.get("options", []) as Array).size()
			if n > 0:
				map.tables.choose_card_option(str(outcome["card"]), rng.range_int(0, n - 1), mod, graph.current_id)
	var loc := map.location(map.pos())
	if str(loc.get("site", "")) != "":
		_explore_site(SiteMap.new(board, board.stream, rng, pack, str(loc["site"])), mod, rng, graph.current_id)
		return false
	if str(loc.get("node", "")) != "" and str(loc["node"]) != graph.current_id:
		graph.travel_to(str(loc["node"]))
		return true
	return false

## 场所：从入口开始，最多 16 个动作——用掉所有可交互物、随机试出口（门会失败，再试），最后回地图。
static func _explore_site(site: SiteMap, mod: Callable, rng: Rng, node_id: String) -> void:
	if site.entered().is_empty():
		site.enter(str(site.site.get("start", "")), mod, node_id)
	for i: int in 40:
		var feats := site.features()
		if not feats.is_empty():
			site.use_feature(str((feats[0] as Dictionary).get("id", "")), mod, node_id)
			continue
		var exits: Array = site.exits().filter(func(e: Dictionary) -> bool: return str(e["to"]) != SiteMap.EXIT_TO_MAP)
		if exits.is_empty():
			break
		var fresh: Array = exits.filter(func(e: Dictionary) -> bool: return not site.entered().has(str(e["to"])))
		var pool: Array = fresh if not fresh.is_empty() else exits # 先探未进过的区域（门失败就再试）
		site.go(str((pool[rng.range_int(0, pool.size() - 1)] as Dictionary)["to"]), mod, node_id)
