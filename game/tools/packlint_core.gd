# packlint 校验核（docs/tech/02-内容包格式规范.md §12 V1~V10 + docs/tech/04-资源与效果系统.md §6 V11~V13）
# 纯数据校验，零引擎依赖（RefCounted），供 tools/packlint.gd（CLI）与 tests/run.gd 复用。
# 每条结论：{v, level, msg}；level ∈ PASS / WARN / FAIL / NA。
# V11~V13 自 M2 起实检资源四表（tech/04 §6）；仅 V10 界面闭环保留 N/A 及原因。
class_name PacklintCore
extends RefCounted

const LEVEL_PASS := "PASS"
const LEVEL_WARN := "WARN"
const LEVEL_FAIL := "FAIL"
const LEVEL_NA := "N/A"

## 轻规则包 v1 §2 技能表（V12 检定技能合法值；_or_ 双技能取两者较高，11 文档 §2）。
const LIGHT_SKILLS := ["athletics", "intimidate", "stealth", "thievery",
	"perception", "investigation", "history", "persuasion", "soothe"]
const DIFFICULTIES := ["easy", "medium", "hard"]
const ITEM_ROLES := ["stat", "check_mod", "branch_key", "codex"] # tech/02 §7 四重身份
const STRATEGIES := ["buyout_component", "dlc", "subscription", "cosmetic", "free"] # tech/02 §2.3
## 框架层权利变量注册表路径（06 文档 §2.3：全部合法权利变量登记在运营侧注册表
## packs/_ops/entitlements.json——数据文件，非代码常量；新增权利 = 运营侧登记一行）。
const ENTITLEMENT_REGISTRY_PATH := "res://packs/_ops/entitlements.json"

## 加载权利注册表。返回 {ok, error, entitlements: Array[id]}；文件缺失 / JSON 损坏 /
## 结构非法均给明确错误——V9 据此前置 FAIL，不静默按空表放行（06 §2.3）。
static func load_entitlement_registry(path: String = ENTITLEMENT_REGISTRY_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "entitlements": [],
			"error": "权利注册表缺失：%s（06 §2.3：注册表落 packs/_ops/entitlements.json）" % path}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if raw == null or not raw is Dictionary or not (raw as Dictionary).get("entitlements") is Array:
		return {"ok": false, "entitlements": [],
			"error": "权利注册表 JSON 解析失败或缺 entitlements 数组：%s（06 §2.3）" % path}
	var out: Array = []
	for e: Variant in (raw as Dictionary)["entitlements"]:
		if e is Dictionary and not str((e as Dictionary).get("id", "")).is_empty():
			out.append(str((e as Dictionary)["id"]))
	return {"ok": true, "error": "", "entitlements": out}
const EFFECT_KEYS := ["write", "value", "clock", "alignment", "give_item", "remove_item", "xp", "gold", "lore", "inspiration", "reveal", "watch"]
const COND_KEYS := ["clock", "alignment", "bond_max", "all", "any"]
const EFFECT_PREFIXES := ["rep.", "bond.", "clock."]
const COND_PREFIXES := ["flag.", "rep.", "item.", "bond.", "clock."]
# ---- tech/04 合法值集合（V11~V13；规则包 light v1 注册的属性/枚举）----
const ATTRS := ["might", "finesse", "wits"]                       # 11 文档 §1 三属性
const MODIFIABLE_ATTRS := ["attack_damage", "ac", "hp_max"]       # tech/04 §5.1 规则包注册可修饰属性
const EFFECT_OPS := ["add", "mul", "override", "clamp_max", "clamp_min"] # tech/04 §5.1
const EFFECT_DURATIONS := ["encounter", "rest", "campaign", "permanent"] # tech/04 §5.1
const EFFECT_STACKS := ["refresh", "stack", "unique"]             # tech/04 §5.1
const SKILL_KINDS := ["attack", "check", "heal", "utility"]       # tech/04 §3
const SKILL_TARGETS := ["enemy_single", "ally_single", "self"]    # tech/04 §3
const GESTURES := ["tap", "path"]                                 # tech/04 §3（12 文档手势）
const STATUS_KEYS := ["attackers_disadvantage", "ac_bonus", "duration_rounds"] # EncounterSM statuses 键
const SAVE_KEYS := ["attr", "dc", "on_success"]                   # 11 文档 §5.1
const SAVE_ON_SUCCESS := ["half", "none"]                         # 11 文档 §5.1
const ITEM_USE_TIMINGS := ["action", "bonus_action", "out_of_combat"] # tech/04 §4
const ITEM_USE_EFFECT_KEYS := ["heal", "damage"]                  # tech/04 §4 v1 落位（扁平键；damage = 投掷攻击）
const ITEM_USE_TARGETS := ["ally", "enemy"]                        # tech/04 §4 use.target（缺省 ally）

## registry = load_entitlement_registry() 的返回形态；缺省空字典 = 从默认路径现读
## （06 §2.3：注册表是运营侧数据文件）。测试可注入损坏/缺失形态做 V9 负例。
static func lint(pack: Dictionary, registry: Dictionary = {}) -> Array:
	if registry.is_empty():
		registry = load_entitlement_registry()
	var issues: Array = []
	issues.append_array(_v1_no_dead_end(pack))
	issues.append_array(_v2_no_unreachable(pack))
	issues.append_array(_v3_failure_path(pack))
	issues.append_array(_v4_flag_closure(pack))
	issues.append_array(_v5_clock_bounded(pack))
	issues.append_array(_v6_node_budget(pack))
	issues.append_array(_v7_namespace(pack))
	issues.append_array(_v8_portrait_constraint(pack))
	issues.append_array(_v9_entitlement(pack, registry))
	issues.append({"v": "V10", "level": LEVEL_NA,
		"msg": "界面闭环：九类界面入口/出口检查依赖 shell 界面实现（04 文档 §5），TP2/TP4 落地后方可数据化"})
	issues.append_array(_v11_resource_refs(pack))
	issues.append_array(_v12_legal_keys(pack))
	issues.append_array(_v13_uses_consume(pack))
	issues.append_array(_v15_texts(pack))
	issues.append_array(_v16_split(pack))
	issues.append_array(_v17_group_battles(pack))
	issues.append_array(_v18_progression(pack))
	issues.append_array(_v19_maps(pack))
	issues.append_array(_v20_tables(pack))
	issues.append_array(_v21_outcome_refs(pack))
	return issues

static func has_failures(issues: Array) -> bool:
	for issue: Dictionary in issues:
		if issue["level"] == LEVEL_FAIL:
			return true
	return false

# ---------------------------------------------------------------- 支线包（arc）lint：graft 挂接（tech/02 §2.6、§12 V14，M4）
# 口径：V14  graft 结构与命名空间独立（复用 PackLoader.merge_graft 判定，单一真相）；
#       V1~V3 图遍历在**合并视图**（宿主 + 注入）上跑——支线节点经注入边可达宿主结局；
#       V4/V6~V9/V11~V13 按本包口径（本包节点/事件/遭遇/旗标 vs 合并视图资源表解析）；
#       V5 时钟代数和按合并视图合计（宿主 + 支线须共同有界），支线无结局表不做 default 检查。

static func lint_grafted(arc_pack: Dictionary, host_pack: Dictionary, registry: Dictionary = {}) -> Array:
	if registry.is_empty():
		registry = load_entitlement_registry()
	var issues: Array = []
	var arc_id := str(arc_pack.get("pack_id", ""))
	var m := PackLoader.merge_graft(host_pack, arc_pack)
	for e: String in (m["errors"] as Array):
		issues.append({"v": "V14", "level": LEVEL_FAIL, "msg": e})
	if not bool(m["ok"]):
		return issues
	issues.append({"v": "V14", "level": LEVEL_PASS,
		"msg": "graft 挂接：目标包 '%s' / 节点 '%s' 存在、注入边合法、命名空间独立"
			% [str((arc_pack["manifest"] as Dictionary)["graft"]["into"]),
				str((arc_pack["manifest"] as Dictionary)["graft"]["node"])]})
	var view: Dictionary = m["view"]
	issues.append_array(_v1_no_dead_end(view))
	issues.append_array(_v2_no_unreachable(view))
	issues.append_array(_v3_failure_path(view))
	var scoped := _arc_scope(arc_pack, view)
	issues.append_array(_v4_flag_closure(scoped))
	issues.append(_v5_clock_arc(view, arc_id))
	issues.append_array(_v6_node_budget(scoped))
	issues.append_array(_v7_namespace(scoped))
	issues.append_array(_v8_portrait_constraint(scoped))
	issues.append_array(_v9_entitlement(arc_pack, registry))
	issues.append({"v": "V10", "level": LEVEL_NA,
		"msg": "界面闭环：九类界面入口/出口检查依赖 shell 界面实现（04 文档 §5），TP2/TP4 落地后方可数据化"})
	issues.append_array(_v11_resource_refs(scoped))
	issues.append_array(_v12_legal_keys(scoped))
	issues.append_array(_v13_uses_consume(scoped))
	issues.append_array(_v15_texts(arc_pack))
	return issues

## 本包口径视图：本包节点（+ graft 注入边合成节点承载其效果校验）/事件/遭遇/旗标，
## 资源表（items/characters/skills/enemies/effects/lore）取合并视图——支线可直接引用宿主表（§2.6 复用）。
static func _arc_scope(arc_pack: Dictionary, view: Dictionary) -> Dictionary:
	var arc_id := str(arc_pack.get("pack_id", ""))
	var scoped := {"pack_id": arc_id, "manifest": arc_pack["manifest"], "acts": arc_pack.get("acts", []),
		"nodes": (view.get("nodes", {}) as Dictionary).duplicate(), "node_order": [], "events": [], "encounters": {},
		"flags": arc_pack.get("flags", []), "endings": [], "lore": view.get("lore", []),
		"items": view.get("items", {}), "characters": view.get("characters", {}),
		"skills": view.get("skills", {}), "effects": view.get("effects", {}),
		"enemies": view.get("enemies", {})}
	# nodes 取合并视图（支线事件/收束边可指回宿主节点，§2.6）；
	# node_order 只列本包节点——V4/V6/V7 等按 node_order 圈定本包校验范围
	for nid: String in arc_pack.get("node_order", []):
		(scoped["node_order"] as Array).append(nid)
	# graft 注入边 = 本包内容（其效果/条件归支线命名空间），合成节点纳入本包口径校验
	var graft: Dictionary = (arc_pack["manifest"] as Dictionary).get("graft", {})
	var gedge: Dictionary = graft.get("edge", {})
	if not gedge.is_empty():
		(scoped["nodes"] as Dictionary)["graft_edge"] = {"id": "graft_edge", "act": "", "type": "scene",
			"title": "graft 注入边", "summary": "", "edges": [gedge]}
		(scoped["node_order"] as Array).append("graft_edge")
	for ev: Variant in view.get("events", []):
		if str((ev as Dictionary).get("_ns", "")) == arc_id:
			(scoped["events"] as Array).append(ev)
	for eid: String in (view.get("encounters", {}) as Dictionary).keys():
		var enc: Dictionary = view["encounters"][eid]
		if str(enc.get("_ns", "")) == arc_id:
			(scoped["encounters"] as Dictionary)[eid] = enc
	return scoped

## V5 支线口径：合并视图时钟代数和须有界；支线包无结局表（§9 仅战役包），default 兜底检查不适用。
static func _v5_clock_arc(view: Dictionary, arc_id: String) -> Dictionary:
	var pos := 0
	for rec: Dictionary in _collect_effects(view):
		var effect: Dictionary = rec["effect"]
		if effect.has("clock"):
			pos += maxi(int(effect["clock"]), 0)
	if pos > Board.CLOCK_MAX:
		return {"v": "V5", "level": LEVEL_FAIL,
			"msg": "合并视图正向时钟效果代数和 +%d 超过上限 %d（宿主+支线合计越界）" % [pos, Board.CLOCK_MAX]}
	return {"v": "V5", "level": LEVEL_PASS,
		"msg": "合并视图时钟代数和 +%d（界 0~%d）；支线 %s 无结局表，default 兜底检查不适用（§9 仅战役包）"
			% [pos, Board.CLOCK_MAX, arc_id]}

# ---------------------------------------------------------------- 图遍历工具

## 全图邻接（V1/V2 共用）：边条件按"可满足即通"处理（任务裁决）——choice/reputation/check/item/
## doom_clock 五类边一律计为可通，check 取 success+failure 双路，item 取主路+fallback。
static func _adjacency(pack: Dictionary) -> Dictionary:
	var adj := {}
	var nodes: Dictionary = pack["nodes"]
	for nid: String in nodes.keys():
		var outs: Array = []
		for edge: Variant in (nodes[nid] as Dictionary).get("edges", []):
			var e: Dictionary = edge
			for key: String in ["to", "success", "failure", "fallback", "linear_fallback"]:
				if e.has(key) and not str(e[key]).is_empty():
					outs.append(str(e[key]))
			for g: Variant in e.get("groups", []): # 分队边：各支线入口可达（15 §2.1）
				if str((g as Dictionary).get("entry", "")) != "":
					outs.append(str((g as Dictionary)["entry"]))
		# 地图节点（16 §1）：经地图到达地点节点——计入邻接，V1/V2 才不误报
		var nd: Dictionary = nodes[nid]
		if str(nd.get("type", "")) == "map":
			for l: Variant in ((pack.get("maps", {}) as Dictionary).get(str(nd.get("map", "")), {}) as Dictionary).get("locations", []):
				var ln := str((l as Dictionary).get("node", ""))
				if ln != "":
					outs.append(ln)
		adj[nid] = outs
	return adj

static func _bfs(adj: Dictionary, start_ids: Array, reverse: bool) -> Dictionary:
	var graph := adj
	if reverse:
		graph = {}
		for nid: String in adj.keys():
			graph[nid] = []
		for nid: String in adj.keys():
			for to: Variant in adj[nid]:
				if graph.has(to):
					graph[to].append(nid)
	var seen := {}
	var queue: Array = start_ids.duplicate()
	for s: Variant in start_ids:
		seen[s] = true
	while not queue.is_empty():
		var nid: String = queue.pop_front()
		for to: Variant in graph.get(nid, []):
			if not seen.has(to):
				seen[to] = true
				queue.append(to)
	return seen

# ---------------------------------------------------------------- 效果/条件收集

## 全包效果出处：[{effect, where}]（节点 on_enter/on_complete/边效果/成败效果 + events.json settle）。
static func _collect_effects(pack: Dictionary) -> Array:
	var out: Array = []
	for nid: String in pack.get("node_order", []):
		var node: Dictionary = pack["nodes"][nid]
		for effect: Variant in node.get("on_enter", []):
			out.append({"effect": effect, "where": "%s.on_enter" % nid})
		for effect: Variant in node.get("on_complete", []):
			out.append({"effect": effect, "where": "%s.on_complete" % nid})
		var edges: Array = node.get("edges", [])
		for i: int in edges.size():
			var e: Dictionary = edges[i]
			for field: String in ["effects", "success_effects", "failure_effects"]:
				for effect: Variant in e.get(field, []):
					out.append({"effect": effect, "where": "%s.edge[%d].%s" % [nid, i, field]})
	for ev: Variant in pack.get("events", []):
		var evd: Dictionary = ev
		for effect: Variant in evd.get("settle", []):
			out.append({"effect": effect, "where": "events.%s.settle" % str(evd.get("id", "?"))})
	# 遭遇扩展块效果（tech/02 §6）：maze 节拍成败效果 + escort 目标失败效果，纳入同一校验闭环
	for eid: String in (pack.get("encounters", {}) as Dictionary).keys():
		var enc: Dictionary = pack["encounters"][eid]
		for effect: Variant in (enc.get("escort", {}) as Dictionary).get("failure_effects", []):
			out.append({"effect": effect, "where": "encounters.%s.escort.failure_effects" % eid})
		var beats: Array = (enc.get("maze", {}) as Dictionary).get("beats", [])
		for i: int in beats.size():
			var beat: Dictionary = beats[i]
			for field: String in ["success_effects", "failure_effects"]:
				for effect: Variant in beat.get(field, []):
					out.append({"effect": effect, "where": "encounters.%s.maze.beats[%d].%s" % [eid, i, field]})
	return out

## 全包条件出处：[{cond, where}]（边 requires + endings.conditions + events trigger.requires）。
static func _collect_conditions(pack: Dictionary) -> Array:
	var out: Array = []
	for nid: String in pack.get("node_order", []):
		var edges: Array = (pack["nodes"][nid] as Dictionary).get("edges", [])
		for i: int in edges.size():
			var e: Dictionary = edges[i]
			if e.has("requires"):
				out.append({"cond": e["requires"], "where": "%s.edge[%d].requires" % [nid, i]})
	for ending: Variant in pack.get("endings", []):
		var ed: Dictionary = ending
		if not (ed.get("conditions", {}) as Dictionary).is_empty():
			out.append({"cond": ed["conditions"], "where": "endings.%s" % str(ed.get("id", "?"))})
	for ev: Variant in pack.get("events", []):
		var evd: Dictionary = ev
		var trig: Dictionary = evd.get("trigger", {})
		if trig.has("requires"):
			out.append({"cond": trig["requires"], "where": "events.%s.trigger" % str(evd.get("id", "?"))})
	return out

# ---------------------------------------------------------------- V1 无死路（tech/02 §12）

static func _v1_no_dead_end(pack: Dictionary) -> Array:
	var issues: Array = []
	var nodes: Dictionary = pack["nodes"]
	var bad_target := false
	for nid: String in pack.get("node_order", []):
		var node: Dictionary = nodes[nid]
		if str(node.get("type", "")) == "ending":
			continue
		if (node.get("edges", []) as Array).is_empty():
			issues.append({"v": "V1", "level": LEVEL_FAIL, "msg": "非结局节点 %s 无出边（死路）" % nid})
		for edge: Variant in node.get("edges", []):
			for key: String in ["to", "success", "failure", "fallback"]:
				if edge.has(key):
					var to := str(edge[key])
					if not to.is_empty() and not nodes.has(to):
						issues.append({"v": "V1", "level": LEVEL_FAIL,
							"msg": "节点 %s 的边指向不存在的节点 '%s'" % [nid, to]})
						bad_target = true
	if bad_target:
		return issues
	# 每条路径可达某结局：自结局反向遍历全覆盖
	var endings: Array = []
	for nid: String in pack.get("node_order", []):
		if str((nodes[nid] as Dictionary).get("type", "")) == "ending":
			endings.append(nid)
	if endings.is_empty():
		issues.append({"v": "V1", "level": LEVEL_FAIL, "msg": "包内无结局节点"})
		return issues
	var can_reach := _bfs(_adjacency(pack), endings, true)
	for nid: String in pack.get("node_order", []):
		if not can_reach.has(nid):
			issues.append({"v": "V1", "level": LEVEL_FAIL, "msg": "节点 %s 无法到达任何结局" % nid})
	if issues.is_empty():
		issues.append({"v": "V1", "level": LEVEL_PASS, "msg": "无死路；全部节点可达某结局"})
	return issues

# ---------------------------------------------------------------- V2 无不可达节点

static func _v2_no_unreachable(pack: Dictionary) -> Array:
	var issues: Array = []
	var order: Array = pack.get("node_order", [])
	if order.is_empty():
		return [{"v": "V2", "level": LEVEL_FAIL, "msg": "包内无节点"}]
	var entry := str(order[0])
	var seen := _bfs(_adjacency(pack), [entry], false)
	for nid: String in order:
		if not seen.has(nid):
			issues.append({"v": "V2", "level": LEVEL_FAIL, "msg": "节点 %s 自入口 %s 不可达" % [nid, entry]})
	if issues.is_empty():
		issues.append({"v": "V2", "level": LEVEL_PASS,
			"msg": "自入口 %s 全图遍历覆盖 %d 节点（边条件按可满足即通）" % [entry, order.size()]})
	return issues

# ---------------------------------------------------------------- V3 失败路完备（tech/02 §4.2 硬规则、08 文档 §2）

static func _v3_failure_path(pack: Dictionary) -> Array:
	var issues: Array = []
	var nodes: Dictionary = pack["nodes"]
	var checks := 0
	for nid: String in pack.get("node_order", []):
		var edges: Array = (nodes[nid] as Dictionary).get("edges", [])
		for i: int in edges.size():
			var e: Dictionary = edges[i]
			if str(e.get("type", "")) != "check":
				continue
			checks += 1
			var where := "%s.edge[%d]" % [nid, i]
			if not e.has("failure") or str(e.get("failure", "")).is_empty():
				issues.append({"v": "V3", "level": LEVEL_FAIL,
					"msg": "%s 检定边缺 failure（tech/02 §4.2：校验器拒绝无失败路的检定边）" % where})
				continue
			var failure := str(e["failure"])
			if failure == str(e.get("success", "")):
				# 型式 B 代价汇合：差异必须体现在成败效果（tech/02 §4.2）；
				# alt_pass 是规范声明的替代通过方式（资源代价落位，如 N2G-1 支付金币），视同差异化代价。
				if (e.get("failure_effects", []) as Array).is_empty()  and (e.get("success_effects", []) as Array).is_empty() and not e.has("alt_pass"):
					issues.append({"v": "V3", "level": LEVEL_FAIL,
						"msg": "%s 成败同点汇合但无差异化效果（空转汇合，08 文档 §2 禁止）" % where})
			elif nodes.has(failure) and str((nodes[failure] as Dictionary).get("type", "")) != "ending"  and ((nodes[failure] as Dictionary).get("edges", []) as Array).is_empty():
				issues.append({"v": "V3", "level": LEVEL_FAIL,
					"msg": "%s 失败路 %s 无出边（失败锁死，08 文档 §2 禁止）" % [where, failure]})
	if issues.is_empty():
		issues.append({"v": "V3", "level": LEVEL_PASS, "msg": "%d 条检定边失败路完备" % checks})
	return issues

# ---------------------------------------------------------------- V4 旗标闭环（tech/02 §8、§12）

static func _v4_flag_closure(pack: Dictionary) -> Array:
	var issues: Array = []
	var pack_id := str(pack.get("pack_id", ""))
	# 图内实际写入（nodes + events settle；write 键省略前缀自动解析为本包命名空间，tech/02 §4.6）
	var written := {} # flag_id -> [where]
	for rec: Dictionary in _collect_effects(pack):
		var effect: Dictionary = rec["effect"]
		if effect.has("write"):
			var fid := str(effect["write"])
			if "." in fid:
				continue # 全键（跨包/global）不计包内台账
			if not written.has(fid):
				written[fid] = []
			written[fid].append(str(rec["where"]))
	# 图内实际读取（条件 flag.<id>）
	var read := {}
	for rec: Dictionary in _collect_conditions(pack):
		_collect_flag_reads(rec["cond"], str(rec["where"]), read)
	# 遭遇层读取亦算图内消费（tech/02 §6：party_advantage/enemy_weaken 旗标声明，M2 审计 G5 误报修复）
	for enc_id: String in (pack.get("encounters", {}) as Dictionary).keys():
		var enc: Dictionary = pack["encounters"][enc_id]
		for field: String in ["party_advantage", "enemy_weaken"]:
			var fid := str((enc.get(field, {}) as Dictionary).get("flag", ""))
			if fid.is_empty() or "." in fid:
				continue
			if not read.has(fid):
				read[fid] = []
			read[fid].append("encounters.%s.%s" % [enc_id, field])
	# 节点文本变体读取亦算图内消费（tech/02 §3 text_variants：战役书 §11 多周目演出差异落点）
	for nid: String in (pack.get("nodes", {}) as Dictionary).keys():
		var node: Dictionary = pack["nodes"][nid]
		for v: Variant in node.get("text_variants", []):
			var vfid := str((v as Dictionary).get("flag", ""))
			if vfid.is_empty() or "." in vfid:
				continue
			if not read.has(vfid):
				read[vfid] = []
			read[vfid].append("nodes.%s.text_variants" % nid)
	for e: Variant in pack.get("endings", []):
		for v: Variant in (e as Dictionary).get("text_variants", []):
			var efid := str((v as Dictionary).get("flag", ""))
			if efid.is_empty() or "." in efid:
				continue
			if not read.has(efid):
				read[efid] = []
			read[efid].append("endings.%s.text_variants" % str((e as Dictionary).get("id", "")))
	# 台账比对
	var declared := {}
	for f: Variant in pack.get("flags", []):
		declared[str((f as Dictionary).get("id", ""))] = f
	for fid: String in written.keys():
		if not declared.has(fid):
			issues.append({"v": "V4", "level": LEVEL_FAIL,
				"msg": "旗标 %s.%s 图内写入但未在 flags.json 登记（写入处：%s）" % [pack_id, fid, ",".join(written[fid])]})
	for fid: String in declared.keys():
		if fid.is_empty():
			issues.append({"v": "V4", "level": LEVEL_FAIL, "msg": "flags.json 存在缺 id 条目"})
			continue
		if not written.has(fid):
			issues.append({"v": "V4", "level": LEVEL_FAIL,
				"msg": "旗标 %s 已登记但图内无写入点（孤立旗标）" % fid})
			continue
		if not read.has(fid) and _declares_graph_reader(pack, declared[fid]):
			# 台账承诺了图内读取点（节点/结局），实际无任何读取 = 选择没有后果（代码评审 M3）
			issues.append({"v": "V4", "level": LEVEL_FAIL,
				"msg": "旗标 %s 声明读取点（%s）但图内/结局无任何读取" % [fid, ";".join(_reader_strings(declared[fid]))]})
		elif not read.has(fid):
			issues.append({"v": "V4", "level": LEVEL_WARN,
				"msg": "旗标 %s 无图层条件读取；声明读取点为 UI/演出面（%s），需人工核对"  % [fid, ";".join(_reader_strings(declared[fid]))]})
		# 声明写入点的节点号须存在（容忍"N4-4 尾声结算"式描述，取首 token）
		for w: Variant in (declared[fid] as Dictionary).get("writers", []):
			var token := str(w).get_slice(" ", 0).get_slice("（", 0)
			if _looks_like_node_id(token) and not (pack["nodes"] as Dictionary).has(token):
				issues.append({"v": "V4", "level": LEVEL_WARN,
					"msg": "旗标 %s 声明写入点 '%s' 非图节点（按转写决策并入结局/L3 事件结算），实际写入存在：%s"  % [fid, token, ",".join(written[fid])]})
	if not issues.any(func(i: Dictionary) -> bool: return i["level"] == LEVEL_FAIL):
		issues.append({"v": "V4", "level": LEVEL_PASS,
			"msg": "旗标台账闭环：%d 登记 / %d 图内写入" % [declared.size(), written.size()]})
	return issues

static func _collect_flag_reads(cond: Dictionary, where: String, read: Dictionary) -> void:
	for key: Variant in cond.keys():
		var k := str(key)
		if k == "all" or k == "any":
			for sub: Variant in cond[key]:
				_collect_flag_reads(sub, where, read)
		elif k.begins_with("flag."):
			var fid := k.substr(5)
			if "." in fid:
				continue
			if not read.has(fid):
				read[fid] = []
			read[fid].append(where)

## 声明的读取点中是否有图内节点或结局（取首 token，如 "R2（对话加成）" → R2）。
static func _declares_graph_reader(pack: Dictionary, flag_decl: Dictionary) -> bool:
	var ending_ids := {}
	for e: Variant in pack.get("endings", []):
		ending_ids[str((e as Dictionary).get("id", ""))] = true
	for r: Variant in flag_decl.get("readers", []):
		var token := str(r).get_slice(" ", 0).get_slice("（", 0).get_slice("/", 0)
		if (pack.get("nodes", {}) as Dictionary).has(token) or ending_ids.has(token):
			return true
	return false

static func _reader_strings(flag_decl: Dictionary) -> Array:
	var out: Array = []
	for r: Variant in flag_decl.get("readers", []):
		out.append(str(r))
	return out

static func _looks_like_node_id(s: String) -> bool:
	if s.is_empty() or s.length() > 8:
		return false
	var c := s.substr(0, 1)
	return c == "N" or c == "R" or c == "E"

# ---------------------------------------------------------------- V5 时间钟有界 + E4 兜底

static func _v5_clock_bounded(pack: Dictionary) -> Array:
	var issues: Array = []
	var pos := 0
	var neg := 0
	for rec: Dictionary in _collect_effects(pack):
		var effect: Dictionary = rec["effect"]
		if effect.has("clock"):
			var d := int(effect["clock"])
			if d > 0:
				pos += d
			else:
				neg += d
	var default_ending := ""
	for ending: Variant in pack.get("endings", []):
		if bool((ending as Dictionary).get("default", false)):
			default_ending = str((ending as Dictionary).get("id", ""))
	if default_ending.is_empty():
		issues.append({"v": "V5", "level": LEVEL_FAIL,
			"msg": "endings.json 缺 default: true 兜底结局（tech/02 §9，战役书 §9 E4 失败非终局）"})
	if pos > Board.CLOCK_MAX:
		issues.append({"v": "V5", "level": LEVEL_FAIL,
			"msg": "全包正向时钟效果代数和 +%d 超过上限 %d（单周目可证越界）" % [pos, Board.CLOCK_MAX]})
	if issues.is_empty():
		issues.append({"v": "V5", "level": LEVEL_PASS,
			"msg": "时钟效果代数和 +%d/%d（界 0~%d，写入钳位兜底）；E4 兜底 = %s"  % [pos, neg, Board.CLOCK_MAX, default_ending]})
	return issues

# ---------------------------------------------------------------- V6 节点预算（tech/02 §12：派生后缀与结局节点不计）

static func _v6_node_budget(pack: Dictionary) -> Array:
	var issues: Array = []
	var mains := {}
	for nid: String in pack.get("node_order", []):
		var node: Dictionary = pack["nodes"][nid]
		if str(node.get("type", "")) == "ending":
			continue
		mains[_main_node_id(nid)] = true
	var budget := int((pack["manifest"] as Dictionary).get("node_budget", 0))
	if mains.size() > budget:
		issues.append({"v": "V6", "level": LEVEL_FAIL,
			"msg": "逻辑节点 %d 超预算 %d（08 文档 §4：超预算须拆包，不允许例外放行）" % [mains.size(), budget]})
	else:
		issues.append({"v": "V6", "level": LEVEL_PASS,
			"msg": "逻辑节点 %d/%d（实际节点 %d，派生与结局不计）"  % [mains.size(), budget, (pack["nodes"] as Dictionary).size()]})
	return issues

## 派生后缀剥离（campaign01 README 转写决策：主编号 + 小写后缀）：N1-2b→N1-2、N2G-2c→N2G-2、R4-r→R4。
static func _main_node_id(nid: String) -> String:
	var re := RegEx.new()
	re.compile("^(.*?\\d+)[a-z]+$|^(.*\\D)-[a-z]+$")
	var m := re.search(nid)
	if m == null:
		return nid
	return m.get_string(1) if not m.get_string(1).is_empty() else m.get_string(2)

# ---------------------------------------------------------------- V7 命名空间（tech/02 §12、07 文档 §3）

static func _v7_namespace(pack: Dictionary) -> Array:
	var issues: Array = []
	var pack_id := str(pack.get("pack_id", ""))
	# 写旗标：带前缀的全键不得越出本包命名空间（global 变量走效果键，不经 write）
	for rec: Dictionary in _collect_effects(pack):
		var effect: Dictionary = rec["effect"]
		if effect.has("write"):
			var fid := str(effect["write"])
			if "." in fid and not fid.begins_with(pack_id + "."):
				issues.append({"v": "V7", "level": LEVEL_FAIL,
					"msg": "%s 写旗标 '%s' 越出本包命名空间 %s（07 §3：跨包写禁止）" % [str(rec["where"]), fid, pack_id]})
	# 条件旗标：保守约束包外引用（跨包读虽运行时可行，上线包不允许隐式耦合）
	for rec: Dictionary in _collect_conditions(pack):
		_v7_check_cond(rec["cond"], str(rec["where"]), pack_id, issues)
	if issues.is_empty():
		issues.append({"v": "V7", "level": LEVEL_PASS,
			"msg": "包内旗标引用均落在 %s.* 或省略前缀自动解析" % pack_id})
	return issues

static func _v7_check_cond(cond: Dictionary, where: String, pack_id: String, issues: Array) -> void:
	for key: Variant in cond.keys():
		var k := str(key)
		if k == "all" or k == "any":
			for sub: Variant in cond[key]:
				_v7_check_cond(sub, where, pack_id, issues)
		elif k.begins_with("flag."):
			var fid := k.substr(5)
			if "." in fid and not fid.begins_with(pack_id + "."):
				issues.append({"v": "V7", "level": LEVEL_FAIL,
					"msg": "%s 读旗标 '%s' 越出本包命名空间 %s" % [where, fid, pack_id]})

# ---------------------------------------------------------------- V8 竖屏约束（tech/02 §6、04 文档 §④.4）

static func _v8_portrait_constraint(pack: Dictionary) -> Array:
	var issues: Array = []
	var n := 0
	for eid: String in (pack["encounters"] as Dictionary).keys():
		var enc: Dictionary = pack["encounters"][eid]
		if str(enc.get("mode", "")) == "forced_time":
			n += 1
			if int(enc.get("max_units", 0)) > 8:
				issues.append({"v": "V8", "level": LEVEL_FAIL,
					"msg": "遭遇 %s forced_time 但 max_units=%d > 8（tech/02 §6 校验器强制）"  % [eid, int(enc.get("max_units", 0))]})
	if issues.is_empty():
		issues.append({"v": "V8", "level": LEVEL_PASS, "msg": "%d 场 forced_time 遭遇 max_units 均 ≤8" % n})
	return issues

# ---------------------------------------------------------------- V9 权利与策略一致（tech/02 §2.2/§2.3、06 文档 §3.2）

static func _v9_entitlement(pack: Dictionary, registry: Dictionary) -> Array:
	var issues: Array = []
	# 注册表本身不可读 = 前置 FAIL 并给出明确错误（06 §2.3：文件缺失/损坏不静默放行）
	if not bool(registry.get("ok", false)):
		issues.append({"v": "V9", "level": LEVEL_FAIL, "msg": str(registry.get("error", "权利注册表不可用"))})
		return issues
	var registered: Array = registry["entitlements"]
	var manifest: Dictionary = pack["manifest"]
	var entitlement: Dictionary = manifest.get("entitlement", {})
	var monetization: Dictionary = manifest.get("monetization", {})
	var requires: Array = entitlement.get("requires", [])
	var strategies: Array = monetization.get("strategies", [])
	for s: Variant in strategies:
		if not STRATEGIES.has(str(s)):
			issues.append({"v": "V9", "level": LEVEL_FAIL,
				"msg": "monetization.strategies 含非法值 '%s'（tech/02 §2.3 合法值集合）" % str(s)})
	for r: Variant in requires:
		var rv := str(r)
		if not rv.begins_with("entitlement.") or rv.length() <= "entitlement.".length():
			issues.append({"v": "V9", "level": LEVEL_FAIL,
				"msg": "entitlement.requires 条目 '%s' 非 global.entitlement.* 权利变量形态（06 文档 §2.3）" % rv})
		elif not registered.has(rv):
			issues.append({"v": "V9", "level": LEVEL_FAIL,
				"msg": "entitlement.requires 条目 '%s' 未在权利注册表登记（%s，06 文档 §2.3）" % [rv, ENTITLEMENT_REGISTRY_PATH]})
	# 幕级门槛（tech/02 §2.2）：acts[].entitlement.requires 同样必须是已登记的权利变量
	for act: Variant in pack.get("acts", []):
		for r: Variant in ((act as Dictionary).get("entitlement", {}) as Dictionary).get("requires", []):
			if not registered.has(str(r)):
				issues.append({"v": "V9", "level": LEVEL_FAIL,
					"msg": "幕 %s 的 entitlement.requires 条目 '%s' 未在权利注册表登记" % [str((act as Dictionary).get("id", "")), str(r)]})
	if strategies.has("dlc") and requires.is_empty():
		issues.append({"v": "V9", "level": LEVEL_FAIL,
			"msg": "strategies 含 dlc 但 entitlement.requires 缺省（tech/02 §2.3 一致性硬规则）"})
	if strategies == ["free"] and not requires.is_empty():
		issues.append({"v": "V9", "level": LEVEL_FAIL,
			"msg": "strategies 为 [free] 不得声明 requires（tech/02 §2.3）"})
	if issues.is_empty():
		if requires.is_empty() and strategies.is_empty():
			issues.append({"v": "V9", "level": LEVEL_PASS,
				"msg": "entitlement/monetization 双缺省 = 随本体权利与策略（tech/02 §2.2/§2.3）"})
		else:
			issues.append({"v": "V9", "level": LEVEL_PASS, "msg": "权利与策略声明一致"})
	return issues

# ---------------------------------------------------------------- V11 资源引用闭环（tech/04 §6）

static func _v11_resource_refs(pack: Dictionary) -> Array:
	var issues: Array = []
	var items: Dictionary = pack["items"]
	var lore_ids := {}
	for l: Variant in pack.get("lore", []):
		lore_ids[str((l as Dictionary).get("id", ""))] = true
	var encounters: Dictionary = pack["encounters"]
	var nodes: Dictionary = pack["nodes"]

	# item 边 / 效果 / 条件引用的道具存在
	for nid: String in pack.get("node_order", []):
		var edges: Array = (nodes[nid] as Dictionary).get("edges", [])
		for i: int in edges.size():
			var e: Dictionary = edges[i]
			if str(e.get("type", "")) == "item" and not items.has(str(e.get("item", ""))):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "%s.edge[%d] 引用未登记道具 '%s'（items.json）" % [nid, i, str(e.get("item", ""))]})
	for rec: Dictionary in _collect_effects(pack):
		var effect: Dictionary = rec["effect"]
		for key: String in ["give_item", "remove_item"]:
			if effect.has(key) and not items.has(str(effect[key])):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "%s 效果 %s 引用未登记道具 '%s'" % [str(rec["where"]), key, str(effect[key])]})
		if effect.has("lore") and not lore_ids.has(str(effect["lore"])):
			issues.append({"v": "V11", "level": LEVEL_FAIL,
				"msg": "%s 效果 lore 引用未登记图鉴条目 '%s'（lore.json）" % [str(rec["where"]), str(effect["lore"])]})
	for rec: Dictionary in _collect_conditions(pack):
		_v11_check_cond(rec["cond"], str(rec["where"]), items, issues)

	# 节点 encounter 引用存在；遭遇回指节点存在
	for nid: String in pack.get("node_order", []):
		var node: Dictionary = nodes[nid]
		if node.has("encounter"):
			var enc_id := str(node["encounter"])
			if not encounters.has(enc_id):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "节点 %s 引用未登记遭遇 '%s'（encounters.json）" % [nid, enc_id]})
		else:
			var t := str(node.get("type", ""))
			if ["battle", "explore", "rest", "hub"].has(t):
				issues.append({"v": "V11", "level": LEVEL_WARN,
					"msg": "节点 %s 类型 %s 缺 encounter 关联（tech/02 §3：战斗/迷宫/休整节点必填）" % [nid, t]})
	for eid: String in encounters.keys():
		var ref := str((encounters[eid] as Dictionary).get("node", ""))
		if not ref.is_empty() and not nodes.has(ref):
			issues.append({"v": "V11", "level": LEVEL_FAIL,
				"msg": "遭遇 %s 回指不存在的节点 '%s'" % [eid, ref]})
	# 事件触发/落点节点存在
	for ev: Variant in pack.get("events", []):
		var evd: Dictionary = ev
		var trig: Dictionary = evd.get("trigger", {})
		for key: String in ["node"]:
			if trig.has(key) and not nodes.has(str(trig[key])):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "事件 %s 触发引用不存在的节点 '%s'" % [str(evd.get("id", "?")), str(trig[key])]})
		if evd.has("node") and not nodes.has(str(evd["node"])):
			issues.append({"v": "V11", "level": LEVEL_FAIL,
				"msg": "事件 %s 落点引用不存在的节点 '%s'" % [str(evd.get("id", "?")), str(evd["node"])]})
	# 道具身份合法值（tech/02 §7）
	for iid: String in items.keys():
		for role: Variant in (items[iid] as Dictionary).get("roles", []):
			if not ITEM_ROLES.has(str(role)):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "道具 %s 身份 '%s' 非法（tech/02 §7 四重身份）" % [iid, str(role)]})

	# ---- tech/04 §6 资源引用闭环（M2 实检）----
	var characters: Dictionary = pack.get("characters", {})
	var skills: Dictionary = pack.get("skills", {})
	var enemies: Dictionary = pack.get("enemies", {})
	var effects: Dictionary = pack.get("effects", {})
	# 角色 → 技能（skills[] 与 basic_attack 均须登记）；熟练 ∈ 规则包技能表（11 §2）
	for cid: String in characters.keys():
		var c: Dictionary = characters[cid]
		for sid: Variant in c.get("skills", []):
			if not skills.has(str(sid)):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "角色 %s 引用未登记技能 '%s'（skills.json）" % [cid, str(sid)]})
		var ba := str(c.get("basic_attack", ""))
		if not ba.is_empty() and not skills.has(ba):
			issues.append({"v": "V11", "level": LEVEL_FAIL,
				"msg": "角色 %s basic_attack 引用未登记技能 '%s'（skills.json）" % [cid, ba]})
		for prof: Variant in c.get("proficiencies", []):
			if not LIGHT_SKILLS.has(str(prof)):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "角色 %s 熟练 '%s' 未在绑定规则包 light v1 注册（11 §2）" % [cid, str(prof)]})
	# 遭遇 → 敌人/角色/战利品道具（tech/02 §6）
	for eid: String in encounters.keys():
		var enc: Dictionary = encounters[eid]
		for entry: Variant in enc.get("enemies", []):
			if not enemies.has(str((entry as Dictionary).get("ref", ""))):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "遭遇 %s enemies 引用未登记敌人 '%s'（enemies.json）"
						% [eid, str((entry as Dictionary).get("ref", ""))]})
		for entry: Variant in enc.get("party", []):
			if not characters.has(str((entry as Dictionary).get("ref", ""))):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "遭遇 %s party 引用未登记角色 '%s'（characters.json）"
						% [eid, str((entry as Dictionary).get("ref", ""))]})
		for l: Variant in enc.get("loot", []):
			if not items.has(str((l as Dictionary).get("item", ""))):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "遭遇 %s 战利品引用未登记道具 '%s'（items.json）"
						% [eid, str((l as Dictionary).get("item", ""))]})
		if str(enc.get("type", "")) == "battle" and (enc.get("enemies", []) as Array).is_empty():
			issues.append({"v": "V11", "level": LEVEL_WARN,
				"msg": "战斗遭遇 %s 未声明 enemies（tech/02 §6）：敌人阵容待内容定稿" % eid})
		# 护送/迷宫扩展块（tech/02 §6 escort/maze 字段）
		if str(enc.get("type", "")) == "escort":
			var esc: Dictionary = enc.get("escort", {})
			if esc.is_empty():
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "护送遭遇 %s 缺 escort 块（tech/02 §6：escort 类型必填）" % eid})
			elif (esc.get("unit", {}) as Dictionary).is_empty() or int(esc.get("survive_rounds", 0)) < 1:
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "护送遭遇 %s escort 块缺 unit 或 survive_rounds < 1（tech/02 §6）" % eid})
		if str(enc.get("type", "")) == "maze":
			var beats: Array = (enc.get("maze", {}) as Dictionary).get("beats", [])
			if beats.is_empty():
				issues.append({"v": "V11", "level": LEVEL_WARN,
					"msg": "迷宫遭遇 %s 未声明 maze.beats（tech/02 §6）：探索序列待内容定稿" % eid})
			for beat: Variant in beats:
				var b: Dictionary = beat
				var btype := str(b.get("type", ""))
				if not ["check", "loot", "ambush"].has(btype):
					issues.append({"v": "V11", "level": LEVEL_FAIL,
						"msg": "遭遇 %s maze 节拍类型 '%s' 非法（tech/02 §6：check/loot/ambush）" % [eid, btype]})
				if btype == "loot" and not items.has(str(b.get("item", ""))):
					issues.append({"v": "V11", "level": LEVEL_FAIL,
						"msg": "遭遇 %s maze 拾取节拍引用未登记道具 '%s'（items.json）" % [eid, str(b.get("item", ""))]})
				if btype == "ambush" and str(b.get("enemy", "")) != "" \
						and not enemies.has(str(b["enemy"])):
					issues.append({"v": "V11", "level": LEVEL_FAIL,
						"msg": "遭遇 %s maze 伏击节拍引用未登记敌人 '%s'（enemies.json）" % [eid, str(b["enemy"])]})
	# 效果 → 规则包注册属性（tech/04 §5.1：target_attr 须在绑定规则包注册）
	for eid: String in effects.keys():
		var ta := str((effects[eid] as Dictionary).get("target_attr", ""))
		if not _registered_attr(ta):
			issues.append({"v": "V11", "level": LEVEL_FAIL,
				"msg": "效果 %s target_attr '%s' 未在绑定规则包注册（tech/04 §5.1）" % [eid, ta]})
	if not issues.any(func(i: Dictionary) -> bool: return i["level"] == LEVEL_FAIL):
		issues.append({"v": "V11", "level": LEVEL_PASS,
			"msg": "资源引用闭环：%d 道具 / %d 图鉴 / %d 遭遇 / %d 事件 / %d 角色 / %d 技能 / %d 敌人引用均可解析"
				% [items.size(), lore_ids.size(), encounters.size(), (pack.get("events", []) as Array).size(),
					characters.size(), skills.size(), enemies.size()]})
	return issues

## target_attr 注册判定：基础可修饰属性（tech/04 §5.1）∪ check_mod.<规则包技能>。
static func _registered_attr(ta: String) -> bool:
	if MODIFIABLE_ATTRS.has(ta):
		return true
	if ta.begins_with("check_mod."):
		return LIGHT_SKILLS.has(ta.trim_prefix("check_mod."))
	return false

static func _v11_check_cond(cond: Dictionary, where: String, items: Dictionary, issues: Array) -> void:
	for key: Variant in cond.keys():
		var k := str(key)
		if k == "all" or k == "any":
			for sub: Variant in cond[key]:
				_v11_check_cond(sub, where, items, issues)
		elif k.begins_with("item.") and not items.has(k.substr(5)):
			issues.append({"v": "V11", "level": LEVEL_FAIL,
				"msg": "%s 条件引用未登记道具 '%s'" % [where, k.substr(5)]})

# ---------------------------------------------------------------- V12 效果与条件键合法值（tech/04 §6、tech/02 §4.6）

static func _v12_legal_keys(pack: Dictionary) -> Array:
	var issues: Array = []
	for rec: Dictionary in _collect_effects(pack):
		for key: Variant in (rec["effect"] as Dictionary).keys():
			if not _effect_key_legal(str(key)):
				issues.append({"v": "V12", "level": LEVEL_FAIL,
					"msg": "%s 含未登记效果键 '%s'（tech/02 §4.6 词汇表）" % [str(rec["where"]), str(key)]})
	for rec: Dictionary in _collect_conditions(pack):
		_v12_check_cond(rec["cond"], str(rec["where"]), issues)
	# 检定边：技能名在绑定规则包注册 + 难度三档（08 文档 §1 校验硬规则）
	for nid: String in pack.get("node_order", []):
		var edges: Array = (pack["nodes"][nid] as Dictionary).get("edges", [])
		for i: int in edges.size():
			var e: Dictionary = edges[i]
			if str(e.get("type", "")) != "check":
				continue
			var where := "%s.edge[%d]" % [nid, i]
			if not DIFFICULTIES.has(str(e.get("difficulty", ""))):
				issues.append({"v": "V12", "level": LEVEL_FAIL,
					"msg": "%s 难度 '%s' 非法（轻规则三档 easy/medium/hard，11 文档 §3）" % [where, str(e.get("difficulty", ""))]})
			for skill: String in str(e.get("skill", "")).split("_or_", false):
				if not LIGHT_SKILLS.has(skill):
					issues.append({"v": "V12", "level": LEVEL_FAIL,
						"msg": "%s 技能 '%s' 未在绑定规则包 light v1 注册（11 文档 §2）" % [where, skill]})
	# ---- tech/04 §6 资源合法值（M2 实检）----
	# 效果修饰器：op / duration / stack 合法值；stack=stack 需 max_stack（tech/04 §5.1）
	for eid: String in (pack.get("effects", {}) as Dictionary).keys():
		var fx: Dictionary = pack["effects"][eid]
		if not EFFECT_OPS.has(str(fx.get("op", ""))):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "效果 %s op '%s' 非法（tech/04 §5.1：add/mul/override/clamp_max/clamp_min）"
					% [eid, str(fx.get("op", ""))]})
		if not EFFECT_DURATIONS.has(str(fx.get("duration", ""))):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "效果 %s duration '%s' 非法（tech/04 §5.1）" % [eid, str(fx.get("duration", ""))]})
		if not EFFECT_STACKS.has(str(fx.get("stack", ""))):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "效果 %s stack '%s' 非法（tech/04 §5.1）" % [eid, str(fx.get("stack", ""))]})
		elif str(fx.get("stack", "")) == "stack" and not fx.has("max_stack"):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "效果 %s stack=stack 缺 max_stack（tech/04 §5.1 叠层需上限）" % eid})
	# 技能：kind/target/attr/gesture 合法值；effect 键与 save 块合法（tech/04 §3、11 §5.1）
	for sid: String in (pack.get("skills", {}) as Dictionary).keys():
		var sk: Dictionary = pack["skills"][sid]
		var where := "skills.%s" % sid
		if not SKILL_KINDS.has(str(sk.get("kind", ""))):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "%s kind '%s' 非法（tech/04 §3：attack/check/heal/utility）" % [where, str(sk.get("kind", ""))]})
		if not SKILL_TARGETS.has(str(sk.get("target", ""))):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "%s target '%s' 非法（tech/04 §3）" % [where, str(sk.get("target", ""))]})
		if sk.has("attr") and not ATTRS.has(str(sk["attr"])):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "%s attr '%s' 非法（11 §1 三属性）" % [where, str(sk["attr"])]})
		if sk.has("gesture") and not GESTURES.has(str(sk["gesture"])):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "%s gesture '%s' 非法（tech/04 §3：tap/path）" % [where, str(sk["gesture"])]})
		if str(sk.get("kind", "")) == "attack" and (not sk.has("attr") or not sk.has("damage")):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "%s attack 技能缺 attr/damage（tech/04 §3：走检定公式必填）" % where})
		for key: Variant in (sk.get("effect", {}) as Dictionary).keys():
			if not STATUS_KEYS.has(str(key)):
				issues.append({"v": "V12", "level": LEVEL_FAIL,
					"msg": "%s effect 含未登记状态键 '%s'（EncounterSM statuses）" % [where, str(key)]})
		if sk.has("save"):
			_check_save(sk["save"], where, issues)
	# 敌人内联技能：save 块合法（11 §5.1）；uses/cooldown 为非负整数
	for eid: String in (pack.get("enemies", {}) as Dictionary).keys():
		var edef: Dictionary = pack["enemies"][eid]
		var own_skills: Array = []
		for sk: Variant in edef.get("skills", []):
			var s: Dictionary = sk
			own_skills.append(str(s.get("id", "")))
			var where := "enemies.%s.%s" % [eid, str(s.get("id", "?"))]
			if s.has("attr") and not ATTRS.has(str(s["attr"])):
				issues.append({"v": "V12", "level": LEVEL_FAIL,
					"msg": "%s attr '%s' 非法（11 §1 三属性）" % [where, str(s["attr"])]})
			if s.has("save"):
				_check_save(s["save"], where, issues)
			if str(s.get("kind", "")) == "summon":
				if not (pack.get("enemies", {}) as Dictionary).has(str(s.get("ref", ""))):
					issues.append({"v": "V12", "level": LEVEL_FAIL,
						"msg": "%s 召唤技能引用未登记敌人 '%s'（story/03 §3.2）"
							% [where, str(s.get("ref", ""))]})
				if int(s.get("count", 0)) < 1:
					issues.append({"v": "V12", "level": LEVEL_FAIL,
						"msg": "%s 召唤技能 count<1（story/03 §3.2）" % where})
		# 回合行为脚本（story/03 §2）：触发器二选一、技能须为本条目自带、阈值/周期合法
		for b: Variant in edef.get("behavior", []):
			var bd: Dictionary = b
			var where := "enemies.%s.behavior" % eid
			if not bd.has("every_n_rounds") and not bd.has("when_hp_below"):
				issues.append({"v": "V12", "level": LEVEL_FAIL,
					"msg": "%s 条目缺触发器（story/03 §2：every_n_rounds / when_hp_below）" % where})
			if bd.has("every_n_rounds") and int(bd["every_n_rounds"]) < 1:
				issues.append({"v": "V12", "level": LEVEL_FAIL,
					"msg": "%s every_n_rounds=%d < 1（story/03 §2）" % [where, int(bd["every_n_rounds"])]})
			if bd.has("when_hp_below"):
				var th := float(bd["when_hp_below"])
				if th <= 0.0 or th >= 1.0:
					issues.append({"v": "V12", "level": LEVEL_FAIL,
						"msg": "%s when_hp_below=%.2f 越出 (0,1)（story/03 §2）" % [where, th]})
			if not own_skills.has(str(bd.get("skill", ""))):
				issues.append({"v": "V12", "level": LEVEL_FAIL,
					"msg": "%s 引用非自带技能 '%s'（story/03 §2：skill 引用敌人自带技能）"
						% [where, str(bd.get("skill", ""))]})
	# 迷宫节拍检定：技能名在绑定规则包注册 + 难度三档（与检定边同一硬规则，tech/02 §6 maze 块）
	for eid: String in (pack.get("encounters", {}) as Dictionary).keys():
		var beats: Array = ((pack["encounters"][eid] as Dictionary).get("maze", {}) as Dictionary).get("beats", [])
		for i: int in beats.size():
			var beat: Dictionary = beats[i]
			if not ["check", "ambush"].has(str(beat.get("type", ""))):
				continue
			var where := "encounters.%s.maze.beats[%d]" % [eid, i]
			if not DIFFICULTIES.has(str(beat.get("difficulty", ""))):
				issues.append({"v": "V12", "level": LEVEL_FAIL,
					"msg": "%s 难度 '%s' 非法（轻规则三档 easy/medium/hard，11 文档 §3）"
						% [where, str(beat.get("difficulty", ""))]})
			for skill: String in str(beat.get("skill", "")).split("_or_", false):
				if not LIGHT_SKILLS.has(skill):
					issues.append({"v": "V12", "level": LEVEL_FAIL,
						"msg": "%s 技能 '%s' 未在绑定规则包 light v1 注册（11 文档 §2）" % [where, skill]})
	# 道具 use 块：timing 合法值（tech/04 §4）
	for iid: String in (pack.get("items", {}) as Dictionary).keys():
		var it: Dictionary = pack["items"][iid]
		if it.has("use") and not ITEM_USE_TIMINGS.has(str((it["use"] as Dictionary).get("timing", ""))):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "items.%s use.timing '%s' 非法（tech/04 §4：action/bonus_action/out_of_combat）"
					% [iid, str((it["use"] as Dictionary).get("timing", ""))]})
	# 道具 use.target / 伤害骰、equip 块（tech/04 §4/§4.1；11 §8.1 四槽）
	for iid: String in (pack.get("items", {}) as Dictionary).keys():
		var it: Dictionary = pack["items"][iid]
		var use: Dictionary = it.get("use", {})
		if use.has("target") and not ITEM_USE_TARGETS.has(str(use["target"])):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "items.%s use.target '%s' 非法（tech/04 §4：ally/enemy）" % [iid, str(use["target"])]})
		for dk: String in ["heal", "damage"]:
			if use.has(dk) and int(LightV1.parse_dice(str(use[dk])).get("sides", 0)) <= 0:
				issues.append({"v": "V12", "level": LEVEL_FAIL,
					"msg": "items.%s use.%s '%s' 非骰式（如 2d4）" % [iid, dk, str(use[dk])]})
		if not it.has("equip"):
			continue
		var eb: Variant = it["equip"]
		if not eb is Dictionary:
			issues.append({"v": "V12", "level": LEVEL_FAIL, "msg": "items.%s equip 块非对象（tech/04 §4.1）" % iid})
			continue
		var ed: Dictionary = eb
		if not Equipment.SLOTS.has(str(ed.get("slot", ""))):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "items.%s equip.slot '%s' 非法（11 §8.1：weapon/armor/shield/trinket）" % [iid, str(ed.get("slot", ""))]})
		for k: Variant in ed.keys():
			if not (Equipment.MOD_KEYS.has(str(k)) or ["slot", "users"].has(str(k))):
				issues.append({"v": "V12", "level": LEVEL_FAIL,
					"msg": "items.%s equip 含未登记键 '%s'（tech/04 §4.1：slot/ac/attack/damage_die/max_hp/users）" % [iid, str(k)]})
		if ed.has("damage_die") and int(LightV1.parse_dice(str(ed["damage_die"])).get("sides", 0)) <= 0:
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "items.%s equip.damage_die '%s' 非骰式（如 1d8）" % [iid, str(ed["damage_die"])]})
		if ed.has("damage_die") and str(ed.get("slot", "")) != "weapon":
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "items.%s equip.damage_die 只能挂在 weapon 槽" % iid})
		for uid: Variant in ed.get("users", []):
			if not (pack.get("characters", {}) as Dictionary).has(str(uid)):
				issues.append({"v": "V11", "level": LEVEL_FAIL,
					"msg": "items.%s equip.users 引用未登记角色 '%s'" % [iid, str(uid)]})
	if issues.is_empty():
		issues.append({"v": "V12", "level": LEVEL_PASS,
			"msg": "效果键 / 条件键 / 检定技能与难度 / 资源枚举（op·duration·stack·save·timing）/ 装备块均为合法值"})
	return issues

## save 块校验（11 §5.1）：键集 ⊆ {attr,dc,on_success}，attr ∈ 三属性，on_success ∈ {half,none}，dc 为数值。
static func _check_save(save: Variant, where: String, issues: Array) -> void:
	if not save is Dictionary:
		issues.append({"v": "V12", "level": LEVEL_FAIL, "msg": "%s save 块非对象（11 §5.1）" % where})
		return
	var sv: Dictionary = save
	for key: Variant in sv.keys():
		if not SAVE_KEYS.has(str(key)):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "%s save 含未登记键 '%s'（11 §5.1：attr/dc/on_success）" % [where, str(key)]})
	if sv.has("attr") and not ATTRS.has(str(sv["attr"])):
		issues.append({"v": "V12", "level": LEVEL_FAIL,
			"msg": "%s save.attr '%s' 非法（11 §1 三属性）" % [where, str(sv["attr"])]})
	if sv.has("on_success") and not SAVE_ON_SUCCESS.has(str(sv["on_success"])):
		issues.append({"v": "V12", "level": LEVEL_FAIL,
			"msg": "%s save.on_success '%s' 非法（11 §5.1：half/none）" % [where, str(sv["on_success"])]})
	if sv.has("dc") and not (sv["dc"] is float or sv["dc"] is int):
		issues.append({"v": "V12", "level": LEVEL_FAIL,
			"msg": "%s save.dc 非数值（11 §5.1）" % where})

# ---------------------------------------------------------------- V13 次数制与 consume 语义（tech/04 §6，M2 实检）

static func _v13_uses_consume(pack: Dictionary) -> Array:
	var issues: Array = []
	var checked := 0
	# 次数制技能 uses ≥ 1（tech/04 §3 uses_per_encounter；null = 不限次不检）
	for sid: String in (pack.get("skills", {}) as Dictionary).keys():
		var sk: Dictionary = pack["skills"][sid]
		if sk.get("uses_per_encounter") != null:
			checked += 1
			if int(sk["uses_per_encounter"]) < 1:
				issues.append({"v": "V13", "level": LEVEL_FAIL,
					"msg": "技能 %s uses_per_encounter=%d < 1（tech/04 §6 V13：次数制技能 uses≥1）"
						% [sid, int(sk["uses_per_encounter"])]})
	# 敌人内联次数制技能 uses ≥ 1
	for eid: String in (pack.get("enemies", {}) as Dictionary).keys():
		for sk: Variant in (pack["enemies"][eid] as Dictionary).get("skills", []):
			var s: Dictionary = sk
			if s.has("uses"):
				checked += 1
				if int(s["uses"]) < 1:
					issues.append({"v": "V13", "level": LEVEL_FAIL,
						"msg": "敌人 %s 技能 %s uses=%d < 1（tech/04 §6 V13）"
							% [eid, str(s.get("id", "?")), int(s["uses"])]})
	# consume 道具语义（tech/04 §4/§6：不得在遭遇外静默消失——数据侧可证部分）
	for iid: String in (pack.get("items", {}) as Dictionary).keys():
		var it: Dictionary = pack["items"][iid]
		var use: Dictionary = it.get("use", {})
		var declared_consume := bool(use.get("consume", false)) or bool(it.get("consume", false))
		if declared_consume:
			checked += 1
			if use.is_empty():
				issues.append({"v": "V13", "level": LEVEL_FAIL,
					"msg": "道具 %s consume:true 但无 use 块（tech/04 §4：无使用效果即静默消失）" % iid})
			elif use.get("timing") == null:
				issues.append({"v": "V13", "level": LEVEL_FAIL,
					"msg": "道具 %s consume:true 但 use 缺 timing（tech/04 §4：无行动经济落点）" % iid})
			elif not ITEM_USE_EFFECT_KEYS.any(func(k: String) -> bool: return use.has(k)):
				issues.append({"v": "V13", "level": LEVEL_FAIL,
					"msg": "道具 %s consume:true 但 use 无效果键（%s，tech/04 §4 v1 扁平键）"
						% [iid, "/".join(ITEM_USE_EFFECT_KEYS)]})
		elif not use.is_empty():
			checked += 1
	if issues.is_empty():
		issues.append({"v": "V13", "level": LEVEL_PASS,
			"msg": "次数制技能 uses≥1、consume 道具均有 use 效果落点（%d 项实检）" % checked})
	return issues

static func _effect_key_legal(k: String) -> bool:
	if EFFECT_KEYS.has(k):
		return true
	for p: String in EFFECT_PREFIXES:
		if k.begins_with(p) and k.length() > p.length():
			return true
	return false

static func _cond_key_legal(k: String) -> bool:
	if COND_KEYS.has(k):
		return true
	for p: String in COND_PREFIXES:
		if k.begins_with(p) and k.length() > p.length():
			return true
	return false

static func _v12_check_cond(cond: Dictionary, where: String, issues: Array) -> void:
	for key: Variant in cond.keys():
		var k := str(key)
		if not _cond_key_legal(k):
			issues.append({"v": "V12", "level": LEVEL_FAIL,
				"msg": "%s 含未登记条件键 '%s'（tech/02 §4.6 词汇表）" % [where, k]})
		elif k == "all" or k == "any":
			for sub: Variant in cond[key]:
				_v12_check_cond(sub, where, issues)

# ---------------------------------------------------------------- V15 文本完整性（tech/02 §1.1/§12；tech/01 E-5 双语构建）
# manifest.locales 声明的每种非源语言：全部显示文本键（PackLoader.text_entries 约定式键）+ 全部 text_ref
# 键在 texts/<locale>.json 中存在且非空；源语言只核 text_ref 键（短文本原文即在包内）。未声明 locales = N/A。
static func _v15_texts(pack: Dictionary) -> Array:
	var manifest: Dictionary = pack.get("manifest", {})
	var locales: Array = manifest.get("locales", [])
	var source := str(pack.get("source_locale", manifest.get("source_locale", PackLoader.DEFAULT_SOURCE_LOCALE)))
	var texts: Dictionary = pack.get("texts", {})
	var issues: Array = []
	var ref_keys := PackLoader.text_ref_keys(pack)
	var src_table: Dictionary = texts.get("texts/%s.json" % source, {})
	var src_missing: Array = ref_keys.filter(func(k: String) -> bool: return str(src_table.get(k, "")) == "")
	if not src_missing.is_empty():
		issues.append({"v": "V15", "level": LEVEL_FAIL, "msg": "源语言 %s 缺 text_ref 键 %d 个：%s" % [
			source, src_missing.size(), ", ".join(src_missing.slice(0, 5))]})
	if locales.is_empty():
		issues.append({"v": "V15", "level": LEVEL_NA, "msg": "未声明 manifest.locales（仅源语言 %s）" % source})
		return issues
	var entries := PackLoader.text_entries(pack)
	var required: Array = entries.keys().filter(func(k: String) -> bool: return str(entries[k]) != "")
	required.append_array(ref_keys)
	for l: Variant in locales:
		var loc := str(l)
		if loc == source:
			continue
		if not texts.has("texts/%s.json" % loc):
			issues.append({"v": "V15", "level": LEVEL_FAIL, "msg": "声明语言 %s 但缺 texts/%s.json" % [loc, loc]})
			continue
		var table: Dictionary = texts["texts/%s.json" % loc]
		var missing: Array = required.filter(func(k: String) -> bool: return str(table.get(k, "")) == "")
		if missing.is_empty():
			issues.append({"v": "V15", "level": LEVEL_PASS, "msg": "%s：%d 个文本键齐全" % [loc, required.size()]})
		else:
			issues.append({"v": "V15", "level": LEVEL_FAIL, "msg": "%s 缺文本键 %d/%d 个：%s" % [
				loc, missing.size(), required.size(), ", ".join(missing.slice(0, 5))]})
	return issues

# ---------------------------------------------------------------- V19 地图连通（docs/en/framework/16 §7）

static func _v19_maps(pack: Dictionary) -> Array:
	var issues: Array = []
	var nodes: Dictionary = pack.get("nodes", {})
	var maps: Dictionary = pack.get("maps", {})
	var sites: Dictionary = pack.get("sites", {})
	var tables: Dictionary = pack.get("tables", {})
	if maps.is_empty() and sites.is_empty():
		return []
	for nid: String in nodes.keys():
		var n: Dictionary = nodes[nid]
		if str(n.get("type", "")) == "map" and not maps.has(str(n.get("map", ""))):
			issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "map 节点 %s 引用未登记地图 '%s'" % [nid, str(n.get("map", ""))]})
		if str(n.get("type", "")) == "site" and not sites.has(str(n.get("site", ""))):
			issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "site 节点 %s 引用未登记场所 '%s'" % [nid, str(n.get("site", ""))]})
	for mid: String in maps.keys():
		var m: Dictionary = maps[mid]
		var locs := {}
		for l: Variant in m.get("locations", []):
			var d: Dictionary = l
			locs[str(d.get("id", ""))] = d
			if d.has("node") and not nodes.has(str(d["node"])):
				issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "地图 %s 地点 %s 的 node '%s' 不存在" % [mid, str(d["id"]), str(d["node"])]})
			if d.has("site") and not sites.has(str(d["site"])):
				issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "地图 %s 地点 %s 的 site '%s' 未登记" % [mid, str(d["id"]), str(d["site"])]})
			if not d.has("node") and not d.has("site"):
				issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "地图 %s 地点 %s 既无 node 也无 site（抵达无落点）" % [mid, str(d["id"])]})
		if not locs.has(str(m.get("start", ""))):
			issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "地图 %s 的 start '%s' 不是地点" % [mid, str(m.get("start", ""))]})
			continue
		var adj := {}
		for r: Variant in m.get("routes", []):
			var rd: Dictionary = r
			var a := str(rd.get("from", ""))
			var b := str(rd.get("to", ""))
			if not locs.has(a) or not locs.has(b):
				issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "地图 %s 路线 %s→%s 端点不存在" % [mid, a, b]})
				continue
			if rd.has("table") and not tables.has(str(rd["table"])):
				issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "地图 %s 路线 %s→%s 引用未登记表 '%s'" % [mid, a, b, str(rd["table"])]})
			adj[a] = (adj.get(a, []) as Array) + [b]
			adj[b] = (adj.get(b, []) as Array) + [a]
		for terrain: Variant in (m.get("tables", {}) as Dictionary).keys():
			if not tables.has(str(m["tables"][terrain])):
				issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "地图 %s 地形 %s 引用未登记表 '%s'" % [mid, str(terrain), str(m["tables"][terrain])]})
		var reach := {str(m["start"]): true}
		var queue: Array = [str(m["start"])]
		while not queue.is_empty():
			var cur: String = queue.pop_front()
			for nb: Variant in adj.get(cur, []):
				if not reach.has(nb):
					reach[nb] = true
					queue.append(nb)
		for lid: String in locs.keys():
			if not reach.has(lid):
				issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "地图 %s 地点 %s 从 start 不可达" % [mid, lid]})
	for sid: String in sites.keys():
		var st: Dictionary = sites[sid]
		var areas := {}
		for a: Variant in st.get("areas", []):
			areas[str((a as Dictionary).get("id", ""))] = a
		if not areas.has(str(st.get("start", ""))):
			issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "场所 %s 的 start 不是区域" % sid})
			continue
		var has_out := false
		var sreach := {str(st["start"]): true}
		var q2: Array = [str(st["start"])]
		while not q2.is_empty():
			var cur2: String = q2.pop_front()
			for e: Variant in (areas[cur2] as Dictionary).get("exits", []):
				var to := str((e as Dictionary).get("to", ""))
				if to == SiteMap.EXIT_TO_MAP:
					has_out = true
					continue
				if not areas.has(to):
					issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "场所 %s 区域 %s 出口指向不存在的区域 '%s'" % [sid, cur2, to]})
					continue
				var key := str((e as Dictionary).get("key", ""))
				if key != "" and not (pack.get("items", {}) as Dictionary).has(key):
					issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "场所 %s 门钥匙 '%s' 未在 items.json 登记" % [sid, key]})
				if not sreach.has(to):
					sreach[to] = true
					q2.append(to)
		for aid: String in areas.keys():
			if not sreach.has(aid):
				issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "场所 %s 区域 %s 不可达（孤立区域）" % [sid, aid]})
		if not has_out:
			issues.append({"v": "V19", "level": LEVEL_FAIL, "msg": "场所 %s 没有回到地图的出口（@map）" % sid})
	if issues.is_empty():
		issues.append({"v": "V19", "level": LEVEL_PASS, "msg": "地图 %d 张 / 场所 %d 处：连通、落点与引用齐备" % [maps.size(), sites.size()]})
	return issues

# ---------------------------------------------------------------- V20 事件表覆盖（16 §4.1）

static func _v20_tables(pack: Dictionary) -> Array:
	var issues: Array = []
	var tables: Dictionary = pack.get("tables", {})
	if tables.is_empty():
		return []
	for tid: String in tables.keys():
		var t: Dictionary = tables[tid]
		var sides := EventTables.die_sides(str(t.get("die", "")))
		if not [4, 6, 8, 10, 12, 20, 100].has(sides):
			issues.append({"v": "V20", "level": LEVEL_FAIL, "msg": "表 %s 骰型 '%s' 非法（d4/d6/d8/d10/d12/d20/d100）" % [tid, str(t.get("die", ""))]})
			continue
		var hits := {}
		for row: Variant in t.get("rows", []):
			var rr := EventTables.parse_range(str((row as Dictionary).get("range", "")))
			for v: int in range(int(rr[0]), int(rr[1]) + 1):
				hits[v] = int(hits.get(v, 0)) + 1
			if (row as Dictionary).has("instead") and EventTables.row_for(t, int(EventTables.parse_range(str(row["instead"]))[0])) < 0:
				issues.append({"v": "V20", "level": LEVEL_FAIL, "msg": "表 %s 的 instead '%s' 不落在任何行" % [tid, str(row["instead"])]})
		for v2: int in range(1, sides + 1):
			if int(hits.get(v2, 0)) != 1:
				issues.append({"v": "V20", "level": LEVEL_FAIL, "msg": "表 %s 点数 %d 覆盖 %d 次（须恰好一次）" % [tid, v2, int(hits.get(v2, 0))]})
				break
	# 嵌套循环检测
	for tid2: String in tables.keys():
		var seen := {tid2: true}
		var frontier: Array = [tid2]
		var cyc := false
		while not frontier.is_empty() and not cyc:
			var cur: String = frontier.pop_front()
			for row2: Variant in (tables.get(cur, {}) as Dictionary).get("rows", []):
				var nt := str(((row2 as Dictionary).get("outcome", {}) as Dictionary).get("table", ""))
				if nt == "":
					continue
				if nt == tid2:
					cyc = true
				elif not seen.has(nt):
					seen[nt] = true
					frontier.append(nt)
		if cyc:
			issues.append({"v": "V20", "level": LEVEL_FAIL, "msg": "表 %s 嵌套成环（结果再掷回自身）" % tid2})
	if issues.is_empty():
		issues.append({"v": "V20", "level": LEVEL_PASS, "msg": "事件表 %d 张：骰面恰好全覆盖、无嵌套环" % tables.size()})
	return issues

# ---------------------------------------------------------------- V21 结果引用（16 §7）

static func _v21_outcome_refs(pack: Dictionary) -> Array:
	var issues: Array = []
	var outcomes: Array = [] # [where, outcome]
	for tid: String in (pack.get("tables", {}) as Dictionary).keys():
		for row: Variant in (pack["tables"][tid] as Dictionary).get("rows", []):
			outcomes.append(["表 %s 行 %s" % [tid, str((row as Dictionary).get("range", ""))], (row as Dictionary).get("outcome", {})])
	for cid: String in (pack.get("cards", {}) as Dictionary).keys():
		for opt: Variant in (pack["cards"][cid] as Dictionary).get("options", []):
			outcomes.append(["事件卡 %s 选项 %s" % [cid, str((opt as Dictionary).get("label", ""))], opt])
	for sid: String in (pack.get("sites", {}) as Dictionary).keys():
		for a: Variant in (pack["sites"][sid] as Dictionary).get("areas", []):
			var ad: Dictionary = a
			for f: Variant in ad.get("features", []):
				outcomes.append(["场所 %s 区域 %s 交互 %s" % [sid, str(ad.get("id", "")), str((f as Dictionary).get("id", ""))], f])
			if ad.has("encounter"):
				outcomes.append(["场所 %s 区域 %s" % [sid, str(ad.get("id", ""))], {"encounter": ad["encounter"]}])
			var oe: Dictionary = ad.get("on_enter", {})
			if oe.has("table"):
				outcomes.append(["场所 %s 区域 %s on_enter" % [sid, str(ad.get("id", ""))], {"table": oe["table"]}])
		if (pack["sites"][sid] as Dictionary).has("wandering_table"):
			outcomes.append(["场所 %s wandering" % sid, {"table": pack["sites"][sid]["wandering_table"]}])
	for pair: Array in outcomes:
		var o: Dictionary = pair[1]
		if o.has("encounter") and not (pack.get("encounters", {}) as Dictionary).has(str(o["encounter"])):
			issues.append({"v": "V21", "level": LEVEL_FAIL, "msg": "%s 引用未登记遭遇 '%s'" % [pair[0], str(o["encounter"])]})
		if o.has("card") and not (pack.get("cards", {}) as Dictionary).has(str(o["card"])):
			issues.append({"v": "V21", "level": LEVEL_FAIL, "msg": "%s 引用未登记事件卡 '%s'" % [pair[0], str(o["card"])]})
		if o.has("node") and not (pack.get("nodes", {}) as Dictionary).has(str(o["node"])):
			issues.append({"v": "V21", "level": LEVEL_FAIL, "msg": "%s 引用不存在的节点 '%s'" % [pair[0], str(o["node"])]})
		if o.has("table") and not (pack.get("tables", {}) as Dictionary).has(str(o["table"])):
			issues.append({"v": "V21", "level": LEVEL_FAIL, "msg": "%s 引用未登记表 '%s'" % [pair[0], str(o["table"])]})
		for key: String in ["effects", "success", "failure"]:
			for fx: Variant in o.get(key, []):
				for k: Variant in (fx as Dictionary).keys():
					if not _effect_key_legal(str(k)):
						issues.append({"v": "V21", "level": LEVEL_FAIL, "msg": "%s 效果键 '%s' 未登记" % [pair[0], str(k)]})
					if str(k) == "give_item" and not (pack.get("items", {}) as Dictionary).has(str(fx[k])):
						issues.append({"v": "V21", "level": LEVEL_FAIL, "msg": "%s 给予未登记道具 '%s'" % [pair[0], str(fx[k])]})
	if outcomes.is_empty():
		return []
	if issues.is_empty():
		issues.append({"v": "V21", "level": LEVEL_PASS, "msg": "地图/事件表结果引用 %d 处齐备" % outcomes.size()})
	return issues

# ---------------------------------------------------------------- V16 分队支线完整性（docs/en/framework/15 §9）

static func _v16_split(pack: Dictionary) -> Array:
	var issues: Array = []
	var nodes: Dictionary = pack.get("nodes", {})
	var chars: Dictionary = pack.get("characters", {})
	var adj := _adjacency(pack)
	var found := 0
	for nid: String in nodes.keys():
		for edge: Variant in (nodes[nid] as Dictionary).get("edges", []):
			var e: Dictionary = edge
			if str(e.get("type", "")) != "split":
				continue
			found += 1
			var gs: Array = e.get("groups", [])
			var rejoin := str(e.get("rejoin", ""))
			if gs.size() < 2:
				issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 分队边少于两组" % nid})
			if not nodes.has(rejoin):
				issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 分队边 rejoin '%s' 不存在" % [nid, rejoin]})
				continue
			var seen_members := {}
			if e.has("assign") and str(e["assign"]) not in ["player", "fixed"]:
				issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 分队边 assign '%s' 非法（player / fixed）" % [nid, str(e["assign"])]})
			if e.has("timeout") and int((e["timeout"] as Dictionary).get("clock", 0)) < 1:
				issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 分队边 timeout.clock 须 ≥1" % nid})
			for g: Variant in gs:
				var gd: Dictionary = g
				if int(gd.get("min", 1)) > int(gd.get("max", 99)) or int(gd.get("min", 1)) < 1:
					issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 小组 %s 人数区间非法" % [nid, str(gd.get("id", ""))]})
				for rq: Variant in gd.get("requires", []):
					if not chars.has(str(rq)):
						issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 小组 %s requires 未登记角色 '%s'" % [nid, str(gd.get("id", "")), str(rq)]})
				var entry := str(gd.get("entry", ""))
				if not nodes.has(entry):
					issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 小组 %s 入口 '%s' 不存在" % [nid, str(gd.get("id", "")), entry]})
					continue
				if (gd.get("members", []) as Array).is_empty():
					issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 小组 %s 没有成员" % [nid, str(gd.get("id", ""))]})
				for m: Variant in gd.get("members", []):
					if not chars.has(str(m)):
						issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 小组成员 '%s' 未在 characters.json 登记" % [nid, str(m)]})
					if seen_members.has(str(m)):
						issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 角色 '%s' 同时在两个小组" % [nid, str(m)]})
					seen_members[str(m)] = true
				if not _bfs(adj, [entry], false).has(rejoin):
					issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 小组 %s 的支线到不了汇合节点 %s" % [nid, str(gd.get("id", "")), rejoin]})
	for nid2: String in nodes.keys():
		var only_remote := true
		var has_edges := false
		for edge2: Variant in (nodes[nid2] as Dictionary).get("edges", []):
			has_edges = true
			if str((edge2 as Dictionary).get("type", "")) != "remote":
				only_remote = false
			elif str((edge2 as Dictionary).get("target_thread", "")) == "":
				issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 远程边缺 target_thread" % nid2})
		if has_edges and only_remote:
			issues.append({"v": "V16", "level": LEVEL_FAIL, "msg": "节点 %s 只有远程边（联络不可用时成死路）" % nid2})
	if found == 0:
		return issues
	if issues.is_empty():
		issues.append({"v": "V16", "level": LEVEL_PASS, "msg": "分队边 %d 条：小组 / 成员 / 支线到汇合均完整" % found})
	return issues

# ---------------------------------------------------------------- V17 小组战（15 §2.2）

static func _v17_group_battles(pack: Dictionary) -> Array:
	var issues: Array = []
	var n := 0
	for eid: String in (pack.get("encounters", {}) as Dictionary).keys():
		var enc: Dictionary = pack["encounters"][eid]
		if not enc.has("party_from"):
			continue
		n += 1
		if str(enc["party_from"]) != "group":
			issues.append({"v": "V17", "level": LEVEL_FAIL, "msg": "遭遇 %s party_from '%s' 非法（只允许 group）" % [eid, str(enc["party_from"])]})
	if n == 0:
		return []
	if issues.is_empty():
		issues.append({"v": "V17", "level": LEVEL_PASS, "msg": "小组战 %d 场声明合法" % n})
	return issues

# ---------------------------------------------------------------- V18 周目渐进兜底（15 §7）

static func _v18_progression(pack: Dictionary) -> Array:
	var issues: Array = []
	var prog: Dictionary = (pack.get("manifest", {}) as Dictionary).get("progression", {})
	if prog.is_empty():
		return []
	var gated := false
	for tier: Variant in prog.values():
		if not bool((tier as Dictionary).get("split", true)):
			gated = true
	var nodes: Dictionary = pack.get("nodes", {})
	for nid: String in nodes.keys():
		for edge: Variant in (nodes[nid] as Dictionary).get("edges", []):
			var e: Dictionary = edge
			if str(e.get("type", "")) == "split" and gated and not e.has("linear_fallback"):
				issues.append({"v": "V18", "level": LEVEL_FAIL, "msg": "节点 %s 分队边在某周目被关闭但缺 linear_fallback" % nid})
			if str(e.get("type", "")) == "split" and e.has("linear_fallback") and not nodes.has(str(e["linear_fallback"])):
				issues.append({"v": "V18", "level": LEVEL_FAIL, "msg": "节点 %s linear_fallback '%s' 不存在" % [nid, str(e["linear_fallback"])]})
	if issues.is_empty():
		issues.append({"v": "V18", "level": LEVEL_PASS, "msg": "周目渐进：被关闭的分队边都有线性兜底"})
	return issues
