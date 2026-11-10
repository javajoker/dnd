# 故事图运行时（docs/tech/02-内容包格式规范.md §3 节点、§4 五类边 DSL、§9 结局分型）
# - 五类边统一按"条件 + 目标 + 效果"求值（§4 导言：运行时只有条件求值），条件/效果复用 Conditions；
#   choice 显式可选 / check 成功失败双路（§4.2）/ item 持有显形否则 fallback（§4.3）/
#   doom_clock 到格自动触发 + once（§4.4）/ reputation requires 隐形门槛（§4.5）；
# - 触发器扫描：任何写板（节点 on_enter/on_complete、边效果）后全量复查 doom_clock 边（35 节点量级）；
# - 结局选择：按 endings.json 顺序求值条件，首个命中者胜，default: true 兜底（§9、战役书 §9 E4）；
# - 一切写板经 Board（07 §1 溯源），节点进入/触发/结局产事件进事件流（07 §6）；
# - graft 支线挂接（tech/02 §2.6，M4）：graft_pack/ungraft_pack 注入/卸载支线——合并视图承载支线
#   节点与注入边（_ns 元数据键标记来源包，支线效果/settle 写板归支线命名空间），宿主包数据不动。
class_name StoryGraph
extends RefCounted

var board: Board
var rng: Rng
var pack: Dictionary
var pack_id: String
var cond: Conditions

var current_id: String = ""
var visit_log: Array[String] = []
var _completed: Dictionary = {} # node_id -> true（on_complete 只结算一次，§3 "离开前结算"）
var _fired_triggers: Dictionary = {} # "node_id/edge_idx" -> true（doom_clock once，§4.4）
var _clock_edges: Array = [] # 预索引全图 doom_clock 边：{node_id, idx, edge}
# L3 任务/事件运行时（tech/02 §5，TP4 接入）：quest_id -> {"def": 事件定义, "state": triggered/settled}
# 触发后事件中心可见（quest.trigger）；触发事件的 node 完成（离开）时按 settle 写板（quest.settle）。
var _quests: Dictionary = {}
var _quest_ns: Dictionary = {} # quest_id -> 来源包命名空间（settle 写板归属，tech/02 §2.6）
# ---- graft 支线挂接（tech/02 §2.6，M4）：pack = 合并视图；_host_pack = 宿主原包（卸载还原用）----
var _host_pack: Dictionary = {}
var _grafts: Dictionary = {} # arc pack_id -> arc pack

func _init(p_board: Board, p_rng: Rng, p_pack: Dictionary) -> void:
	board = p_board
	rng = p_rng
	pack = p_pack
	pack_id = str(pack.get("pack_id", ""))
	cond = Conditions.new(board)
	_index_clock_edges()

# ---------------------------------------------------------------- graft 支线挂接（tech/02 §2.6）

## 注入支线包：按 manifest.graft 把注入边与支线节点并入合并视图（宿主数据不动，PackLoader.merge_graft）。
## 返回 { ok, errors[] }；挂接失败视图不变。权利门槛由引导层在调用前把关（06 §3.1）。
func graft_pack(arc_pack: Dictionary) -> Dictionary:
	var arc_id := str(arc_pack.get("pack_id", ""))
	if _grafts.has(arc_id):
		return {"ok": false, "errors": ["graft：包 %s 已注入（幂等拒绝）" % arc_id]}
	if _host_pack.is_empty():
		_host_pack = pack
	var res := PackLoader.merge_graft(pack, arc_pack) # 以当前视图为宿主：多支线链式合并
	if not bool(res["ok"]):
		return res
	_grafts[arc_id] = arc_pack
	pack = res["view"]
	_index_clock_edges()
	return res

## 卸载支线包：注入边与支线节点随视图重建消失（§2.6 卸载语义）。返回是否原本已注入。
func ungraft_pack(arc_id: String) -> bool:
	if not _grafts.has(arc_id):
		return false
	_grafts.erase(arc_id)
	_rebuild_view()
	return true

func grafted_packs() -> Array:
	return _grafts.keys()

## 视图重建 = 宿主原包 + 全部支线逐一注入（卸载即还原宿主图，宿主数据全程未动）。
func _rebuild_view() -> void:
	if _host_pack.is_empty():
		return
	pack = _host_pack
	for arc_id: String in _grafts:
		var res := PackLoader.merge_graft(pack, _grafts[arc_id])
		if not bool(res["ok"]):
			push_error("StoryGraph: 重建视图注入 %s 失败：%s" % [arc_id, ";".join(res["errors"] as Array)])
			continue
		pack = res["view"]
	_index_clock_edges()

## 节点来源命名空间（§2.6：支线节点效果解析到支线包命名空间；宿主节点 = pack_id）。
func _ns_of(node_id: String) -> String:
	return str((pack.get("nodes", {}) as Dictionary).get(node_id, {}).get("_ns", pack_id))

# ---------------------------------------------------------------- 进入与遍历

## 从入口节点开图（缺省取节点表首个节点，campaign01 = N0-1）。
func start(entry_id: String = "") -> void:
	var eid := entry_id
	if eid.is_empty():
		eid = (pack["node_order"] as Array)[0]
	_enter(eid)

func current() -> Dictionary:
	return (pack["nodes"] as Dictionary).get(current_id, {})

func is_at_ending() -> bool:
	return str(current().get("type", "")) == "ending"

## 当前节点玩家可走的边（check 边整体返回，成败由 resolve_check 结算）。
## item 边：持有 → 主路；未持有且有 fallback → 以 {to: fallback} 变体出现；无 fallback 则不显形（§4.3）。
func available_edges() -> Array:
	var out: Array = []
	for edge: Variant in current().get("edges", []):
		var e: Dictionary = edge
		var ctx := {"pack_id": _edge_ns(e)} # 注入边 requires 归支线命名空间（§2.6）；普通边归当前节点来源包
		match str(e.get("type", "")):
			"choice", "reputation":
				if _requires_ok(e, ctx):
					out.append(e)
			"item":
				if board.has_item(str(e.get("item", ""))) and _requires_ok(e, ctx):
					out.append(e)
				elif e.has("fallback"):
					var fb := e.duplicate(true)
					fb["to"] = e["fallback"]
					fb["via_fallback"] = true
					out.append(fb)
			"check":
				out.append(e)
			"doom_clock":
				pass # 自动触发，非玩家选项（§4.4）
	return out

## 走一条非检定边：先结算离开节点的 on_complete，再边效果，再触发器扫描，最后进入目标。
## 边效果命名空间：graft 注入边携带 _ns（效果归支线包，§2.6）；普通边归所属节点来源包。
func take_edge(edge: Dictionary) -> void:
	_scan_choice_quests(edge) # choice 触发的事件在离点前按所选边登记（tech/02 §5 trigger.choice）
	_leave_current()
	_apply(edge.get("effects", []), current_id, _edge_ns(edge))
	_scan_triggers()
	_enter(str(edge.get("to", "")))

## 检定边成败双路结算（§4.2：差异体现在 success/failure 目标与效果）。
func resolve_check(edge: Dictionary, success: bool) -> void:
	_leave_current()
	var ns := _edge_ns(edge)
	if success:
		_apply(edge.get("success_effects", []), current_id, ns)
		_scan_triggers()
		_enter(str(edge.get("success", "")))
	else:
		_apply(edge.get("failure_effects", []), current_id, ns)
		_scan_triggers()
		_enter(str(edge.get("failure", "")))

# ---------------------------------------------------------------- 检定掷骰（11 §2/§3；09 §6 两级演出标记）
# UI 只按下"检定"按钮；掷骰、check.roll 事件、成败双路推进全部在 core 完成（godot-dev §2）。

## 玩家有效属性 = 模板属性 + 已分配加点（11 §6；簿记 global.growth.attrs.*，tech/04 §8）。
func player_attrs() -> Dictionary:
	var out: Dictionary = (_player_template().get("attrs", {}) as Dictionary).duplicate(true)
	var alloc := Growth.attrs_map(board)
	for k: Variant in alloc.keys():
		out[str(k)] = int(out.get(str(k), 0)) + int(alloc[k])
	return out

func player_proficiencies() -> Array:
	return (_player_template().get("proficiencies", []) as Array).duplicate()

## 检定修正 = 属性修正 + 熟练 +2（11 §2；a_or_b 双技能取高，LightV1.skill_mod）。
func check_mod(skill: String) -> int:
	return LightV1.skill_mod(player_attrs(), player_proficiencies(), skill)

## 检定边真实掷骰：d20+修正 vs DC（11 §3），产出 check.roll（kind=story_check）后按成败走边（§4.2）。
## key/extreme 分级按 09 §6：内容包 key:true / hard 且 pivot 标记 → 关键；nat20/nat1 恒追加极端档。
func roll_check(edge: Dictionary) -> Dictionary:
	var skill := str(edge.get("skill", ""))
	var dc := LightV1.dc_for(str(edge.get("difficulty", "medium")))
	var mod := check_mod(skill)
	var mode := LightV1.ADV_NORMAL
	if inspiration_armed and inspiration() > 0:
		mode = LightV1.ADV_ADVANTAGE # 花费激励：本次检定优势（11 §3.2）
		board.write(_insp_key(), 0, _hub_prov())
		board.stream.emit(EventTypes.LOG, {"msg_key": "MSG_INSPIRATION_SPENT", "toast": true}, &"graph", current_id)
	inspiration_armed = false
	var res := LightV1.check(rng, mod, dc, mode)
	var success := bool(res["success"])
	var key := bool(edge.get("key", false)) \
		or (str(edge.get("difficulty", "")) == "hard" and bool(edge.get("pivot", false)))
	var extreme := bool(res["nat20"]) or bool(res["nat1"])
	board.stream.emit(EventTypes.CHECK_ROLL, {"roller": "pc", "kind": "story_check",
		"skill": skill, "rolls": res["rolls"], "keep": res["keep"], "mod": mod,
		"total": res["total"], "dc": dc, "success": success, "key": key, "extreme": extreme,
		"mode": String(mode)}, &"graph", current_id)
	if bool(res["nat1"]) and inspiration() < 1:
		# 失败也是故事：天然 1 换来一枚激励（11 §3.2 失败即分支的正反馈）
		board.write(_insp_key(), 1, _hub_prov())
		board.stream.emit(EventTypes.LOG, {"msg_key": "MSG_INSPIRATION_GAIN", "toast": true}, &"graph", current_id)
	resolve_check(edge, success)
	res["success"] = success
	res["key"] = key
	res["extreme"] = extreme
	return res

# ---------------------------------------------------------------- 激励（11 §3.2：d20 核心规则的 Inspiration）
# 最多持有一枚（<ns>.inspiration 簿记）；故事检定掷出天然 1 或内容效果 inspiration 获得；
# 玩家在检定前"举起"激励（arm），下一次故事检定以优势掷骰并消耗。

var inspiration_armed := false

func _insp_key() -> String:
	return "%s.inspiration" % pack_id

func inspiration() -> int:
	return clampi(int(board.read(_insp_key(), 0)), 0, 1)

## 举起 / 放下激励；未持有时无法举起。返回当前是否举起。
func arm_inspiration(on: bool) -> bool:
	inspiration_armed = on and inspiration() > 0
	return inspiration_armed

func _player_template() -> Dictionary:
	for cid: String in (pack.get("characters", {}) as Dictionary).keys():
		var c: Dictionary = pack["characters"][cid]
		if str(c.get("kind", "")) == "player_template":
			return c
	return {}

# ---------------------------------------------------------------- 时间边预告（04 §3.1：点时间钟 → 逼近事件预告）

## 全部未触发且尚未到格的时钟逼近项（L3 事件 doom_clock 触发 §5 + 图内 doom_clock 边 §4.4），按格数升序。
func clock_forecasts() -> Array:
	var out: Array = []
	var now := board.get_doom_clock()
	for ev: Variant in pack.get("events", []):
		var def: Dictionary = ev
		var trig: Dictionary = def.get("trigger", {})
		if str(trig.get("type", "")) != "doom_clock":
			continue
		var at := int(trig.get("at", 0))
		if at > now and not _quests.has(str(def.get("id", ""))):
			out.append({"id": str(def.get("id", "")), "name": str(def.get("name", "")),
				"at": at, "objective": str(def.get("objective", ""))})
	for rec: Dictionary in _clock_edges:
		var edge: Dictionary = rec["edge"]
		var at := int(edge.get("at", 0))
		var key := "%s/%d" % [str(rec["node_id"]), int(rec["idx"])]
		if at > now and not _fired_triggers.has(key):
			# objective 上屏文本取节点标题（节点 id 是内部寻址，不上屏——M2 审计 G7）
			var node_title := str((pack["nodes"] as Dictionary).get(
				str(rec["node_id"]), {}).get("title", ""))
			out.append({"id": "", "name": str(edge.get("label", "")), # 无文案时由壳按语言兜底（TIME_EDGE_DEFAULT）
				"at": at, "objective": node_title})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))
	return out

## 最近一条逼近项（状态栏带时钟角标用；无则空字典）。
func next_clock_trigger() -> Dictionary:
	var f := clock_forecasts()
	return f[0] if not f.is_empty() else {}

# ---------------------------------------------------------------- Hub 动作（战役书 §4 N1-1：休整 / 商店 / 传闻）
# 金币：包命名空间计数型旗标 <pack>.gold（07 §2 货币条款，v1.7 补记；M2 审计 X1 裁决：合规）。

# 开局配置来自 manifest.start（tech/02 §2.8）：{gold, items:[{item, n}]}——框架不写死任何包的经济数值。

## 本包金币键（<pack_id>.gold）。
func gold_key() -> String:
	return "%s.gold" % pack_id

## manifest.start.gold（缺省 0）。
func start_gold() -> int:
	return int(((pack.get("manifest", {}) as Dictionary).get("start", {}) as Dictionary).get("gold", 0))

## manifest.start.items（开局带入道具，叙事既定）：[{item, n}]。
func start_items() -> Array:
	return ((pack.get("manifest", {}) as Dictionary).get("start", {}) as Dictionary).get("items", [])

func _hub_prov() -> Dictionary:
	return {"event_id": board.stream.tail(), "node_id": current_id, "pack_id": pack_id}

## 开局播种金币（幂等：已存在不覆盖）。
func seed_gold(amount: int = -1) -> void:
	if not board.has(gold_key()):
		board.write(gold_key(), amount if amount >= 0 else start_gold(), _hub_prov())

func get_gold() -> int:
	return int(board.read(gold_key(), 0))

## 商店货单 = items.json 含 price 字段条目（tech/02 §7 投放声明；价格占位见 campaign01 README M2 记录）。
func hub_stock() -> Array:
	var out: Array = []
	for iid: String in (pack.get("items", {}) as Dictionary).keys():
		var it: Dictionary = pack["items"][iid]
		if it.has("price"):
			out.append({"id": iid, "name": str(it.get("name", iid)), "price": int(it["price"]),
				"owned": board.item_count(iid), "affordable": get_gold() >= int(it["price"])})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["price"]) < int(b["price"]))
	return out

## 购买：金币扣减 + give_item（同一次动作两笔写板，均带溯源）；金币不足拒绝返回 false。
func hub_buy(item_id: String) -> bool:
	var it: Dictionary = (pack.get("items", {}) as Dictionary).get(item_id, {})
	if it.is_empty() or not it.has("price"):
		push_error("StoryGraph.hub_buy: 非卖品 '%s'" % item_id)
		return false
	var price := int(it["price"])
	if get_gold() < price:
		return false
	board.write(gold_key(), get_gold() - price, _hub_prov())
	board.give_item(item_id, 1, _hub_prov())
	return true

## 休整（旅店长休）：等同 long_rest(true)——hub 内长休不耗时钟（战役书 §4 N1-1）。
func hub_rest() -> Dictionary:
	return long_rest(true)

## 队伍成员（玩家模板 + 同伴）characters.json 条目 id 列表（按包内顺序）。
func party_ids() -> Array[String]:
	var out: Array[String] = []
	for cid: String in (pack.get("characters", {}) as Dictionary).keys():
		if ["player_template", "companion"].has(str((pack["characters"][cid] as Dictionary).get("kind", ""))):
			out.append(cid)
	return out

## HP 上限（唯一口径 BattleDef.max_hp_for）。
func max_hp_of(cid: String) -> int:
	return BattleDef.max_hp_for((pack.get("characters", {}) as Dictionary).get(cid, {}), board, pack)

## AC（ac_formula 以模板基础属性求值 + 装备 AC 加值，与 BattleDef 同口径）。
func ac_of(cid: String) -> int:
	var c: Dictionary = (pack.get("characters", {}) as Dictionary).get(cid, {})
	var base: Dictionary = c.get("attrs", {})
	var lv := Growth.level(board) if str(c.get("kind", "")) == "player_template" else 1
	var ac: Variant = LightV1.eval_formula(str(c.get("ac_formula", "10")), {"might": int(base.get("might", 0)),
		"finesse": int(base.get("finesse", 0)), "wits": int(base.get("wits", 0)), "level": lv})
	return (int(ac) if ac != null else 10) + int(Equipment.modifiers(board, pack_id, pack.get("items", {}), cid)["ac"])

## 当前 HP：<pack>.hp.<cid> 簿记，未写入按满值；死亡记录 0 按 1 抬升（同 BattleDef，11 §7.1）。
func hp_of(cid: String) -> int:
	var mx := max_hp_of(cid)
	var key := "%s.hp.%s" % [pack_id, cid]
	return clampi(int(board.read(key)), 1, mx) if board.has(key) else mx

# ---------------------------------------------------------------- 营地与休息（11 §7.2：d20 核心规则的短休 / 长休）
# 生命骰：每名队员持有「队伍等级」枚生命骰（骰面取 characters.json hit_die，缺省 d8）。
# 短休：逐枚花费生命骰回血 = 骰值 + 力量修正（最少 1）；不耗时钟。
# 长休：HP 全满 + 生命骰全数恢复；旅店（hub）免费，野外营地推进末日时钟 +1（时间即墨迹）。
# 次数制技能按遭遇计次（11 §8），每场遭遇开局即视为已短休充能，无需另行恢复。
const DEFAULT_HIT_DIE := "d8"
const CAMP_LONG_REST_CLOCK := 1

func _hd_key(cid: String) -> String:
	return "%s.hd_spent.%s" % [pack_id, cid]

## 生命骰状态：{die, max, left}。
func hit_dice_of(cid: String) -> Dictionary:
	var c: Dictionary = (pack.get("characters", {}) as Dictionary).get(cid, {})
	var mx := Growth.level(board)
	var spent := clampi(int(board.read(_hd_key(cid))), 0, mx)
	return {"die": str(c.get("hit_die", DEFAULT_HIT_DIE)), "max": mx, "left": mx - spent}

## 营地可用：已经历过至少一场战斗（序章教学不出现营地）、不在 hub（hub 有旅店长休与正式商店）、
## 不在战斗节点（战斗走整备）且未到结局。
func camp_available() -> bool:
	if ["hub", "battle"].has(str(current().get("type", ""))) or is_at_ending():
		return false
	var nodes: Dictionary = pack.get("nodes", {})
	for nid: Variant in visit_log:
		if str((nodes.get(str(nid), {}) as Dictionary).get("type", "")) == "battle":
			return true
	return false

## 长休免费：hub（旅店）与 rest 节点（安全落脚点）不耗时钟；其余野外营地耗时钟。
func rest_is_free() -> bool:
	return ["hub", "rest"].has(str(current().get("type", "")))

## 短休：为 cid 花费一枚生命骰。返回 {ok, reason?, roll, heal, hp, max_hp}。
## 拒绝：无剩余生命骰（no_dice）/ 已满血（full）——满血不浪费骰子。
func short_rest(cid: String) -> Dictionary:
	if not party_ids().has(cid):
		return {"ok": false, "reason": "unknown"}
	var hd := hit_dice_of(cid)
	var mx := max_hp_of(cid)
	var hp := hp_of(cid)
	if hp >= mx:
		return {"ok": false, "reason": "full", "hp": hp, "max_hp": mx}
	if int(hd["left"]) <= 0:
		return {"ok": false, "reason": "no_dice", "hp": hp, "max_hp": mx}
	var c: Dictionary = pack["characters"][cid]
	var roll: int = int(LightV1.roll_damage(rng, "1" + str(hd["die"]))["total"])
	var might := int((c.get("attrs", {}) as Dictionary).get("might", 0))
	var heal := maxi(1, roll + might)
	var new_hp := mini(mx, hp + heal)
	board.write("%s.hp.%s" % [pack_id, cid], new_hp, _hub_prov())
	board.write(_hd_key(cid), int(hd["max"]) - int(hd["left"]) + 1, _hub_prov())
	board.stream.emit(EventTypes.LOG, {"msg_key": "MSG_SHORT_REST", "toast": true,
		"args": {"name": str(c.get("name", cid)), "die": str(hd["die"]), "roll": roll,
			"heal": new_hp - hp, "hp": new_hp, "max_hp": mx}}, &"graph", current_id)
	return {"ok": true, "roll": roll, "heal": new_hp - hp, "hp": new_hp, "max_hp": mx}

## 长休：全队 HP 全满 + 生命骰清零花费；at_inn=false（野外营地）推进末日时钟 +1，
## 时钟写板后复查 doom_clock 触发（可能直接把剧情推到触发节点，调用方需重新呈现）。
func long_rest(at_inn: bool) -> Dictionary:
	var restored := {}
	for cid: String in party_ids():
		var mx := max_hp_of(cid)
		board.write("%s.hp.%s" % [pack_id, cid], mx, _hub_prov())
		if int(board.read(_hd_key(cid))) != 0:
			board.write(_hd_key(cid), 0, _hub_prov())
		restored[cid] = mx
	if at_inn:
		board.stream.emit(EventTypes.LOG, {"msg_key": "MSG_REST", "toast": true}, &"graph", current_id)
	else:
		board.stream.emit(EventTypes.LOG, {"msg_key": "MSG_LONG_REST_CAMP", "toast": true,
			"args": {"clock": CAMP_LONG_REST_CLOCK}}, &"graph", current_id)
		_apply([{"clock": CAMP_LONG_REST_CLOCK}], current_id)
		_scan_triggers()
	return restored

## 队伍状态（状态栏带 04 §3.1「队伍 HP 概览」与营地面板数据源）：
## [{id, name, hp, max_hp, hd_left, hd_max, hit_die, art_ref?}]。
func party_status() -> Array:
	var out: Array = []
	for cid: String in party_ids():
		var c: Dictionary = pack["characters"][cid]
		var hd := hit_dice_of(cid)
		var entry := {"id": cid, "name": str(c.get("name", cid)), "kind": str(c.get("kind", "")),
			"hp": hp_of(cid), "max_hp": max_hp_of(cid), "ac": ac_of(cid),
			"hd_left": int(hd["left"]), "hd_max": int(hd["max"]), "hit_die": str(hd["die"])}
		if c.has("art_ref"): # 头像引用随行（tech/05 §6 纯呈现；队伍芯片按 art_ref 显示头像）
			entry["art_ref"] = str(c["art_ref"])
		out.append(entry)
	return out

## ⑦ 角色界面名册（04 §⑦ 只读队伍卡数据源）：characters.json + 成长簿记 + HP 持久化直接组装，
## 与战斗定义（BattleDef）解耦——主屏/非战斗上下文同样可用（M2 审计 G1 修复）；
## 数值口径与 BattleDef._build_character_unit 一致（11 §6：成长只叠加玩家模板，hp 公式吃基础属性）。
func party_roster() -> Array:
	var alloc := Growth.attrs_map(board)
	var skills: Dictionary = pack.get("skills", {})
	var out: Array = []
	for cid: String in (pack.get("characters", {}) as Dictionary).keys():
		var c: Dictionary = pack["characters"][cid]
		var kind := str(c.get("kind", ""))
		if not ["player_template", "companion"].has(kind):
			continue
		var base_attrs: Dictionary = c.get("attrs", {})
		var final_attrs := {}
		for a: String in ["might", "finesse", "wits"]:
			final_attrs[a] = int(base_attrs.get(a, 0)) + (int(alloc.get(a, 0)) if kind == "player_template" else 0)
		var max_hp := max_hp_of(cid)
		var hp_now := hp_of(cid) # 11 §7.1 持久化；0 抬 1 同 BattleDef
		var skill_entries: Array = []
		var learned: Array = (c.get("skills", []) as Array).duplicate()
		var ba := str(c.get("basic_attack", ""))
		if not ba.is_empty() and not learned.has(ba):
			learned.push_front(ba) # 普攻列首（tech/04 §2 basic_attack 亦属已习得）
		for sid: Variant in learned:
			var sd: Dictionary = skills.get(str(sid), {})
			skill_entries.append({"id": str(sid), "name": str(sd.get("name", sid))})
		out.append({"id": cid, "name": str(c.get("name", cid)),
			"hp": hp_now, "max_hp": max_hp, "attrs": final_attrs, "skills": skill_entries})
	return out

## 传闻（战役书 §4：未择路线以传闻形式提及）：已注册但尚未触发的 choice/hidden 触发事件。
func hub_rumors() -> Array:
	var out: Array = []
	for ev: Variant in pack.get("events", []):
		var def: Dictionary = ev
		if not ["choice", "hidden"].has(str((def.get("trigger", {}) as Dictionary).get("type", ""))):
			continue
		if not _quests.has(str(def.get("id", ""))):
			out.append({"id": str(def.get("id", "")), "name": str(def.get("name", "")),
				"objective": str(def.get("objective", ""))})
	return out

# ---------------------------------------------------------------- 结局（§9）

## 按 endings.json 顺序求值，首个条件命中者胜；无命中取 default: true 兜底（E4，战役书 §9）。
func pick_ending() -> String:
	var ctx := {"pack_id": pack_id}
	var fallback := ""
	for ending: Variant in pack.get("endings", []):
		var e: Dictionary = ending
		if bool(e.get("default", false)):
			fallback = str(e.get("id", ""))
			continue
		if cond.evaluate(e.get("conditions", {}), ctx):
			return str(e.get("id", ""))
	return fallback

# ---------------------------------------------------------------- 内部

func _enter(node_id: String) -> void:
	if not (pack["nodes"] as Dictionary).has(node_id):
		push_error("StoryGraph: 进入不存在的节点 '%s'" % node_id)
		return
	current_id = node_id
	visit_log.append(node_id)
	board.stream.emit(EventTypes.NODE_ENTER,
		{"node_id": node_id, "type": str(current().get("type", ""))}, &"graph", node_id)
	_apply(current().get("on_enter", []), node_id)
	_scan_triggers()
	_scan_node_quests(node_id) # auto/hidden 触发随节点进入登记（tech/02 §5）

## §3：on_complete 在"节点全部边结算完成、离开前"结算，每节点只一次。
## 节点完成同时结算已触发 L3 事件的 settle 写板（tech/02 §5：节点完成时按 settle 写板）。
func _leave_current() -> void:
	if current_id.is_empty() or _completed.has(current_id):
		return
	_completed[current_id] = true
	_apply(current().get("on_complete", []), current_id)
	_settle_quests_at(current_id)

func _apply(effects: Array, node_id: String, ns: String = "") -> void:
	if effects.is_empty():
		return
	cond.apply_effects(effects, {
		"pack_id": ns if not ns.is_empty() else _ns_of(node_id), # 支线节点/注入边效果归来源包（§2.6）
		"node_id": node_id,
		"event_id": board.stream.tail(),
		"source": "graph",
	})

## 边来源命名空间：graft 注入边携带 _ns；普通边归当前节点来源包（§2.6）。
func _edge_ns(edge: Dictionary) -> String:
	return str(edge.get("_ns", _ns_of(current_id)))

func _requires_ok(edge: Dictionary, ctx: Dictionary) -> bool:
	if not edge.has("requires"):
		return true
	return cond.evaluate(edge["requires"], ctx)

func _index_clock_edges() -> void:
	_clock_edges.clear()
	for nid: String in pack.get("node_order", []):
		var edges: Array = (pack["nodes"][nid] as Dictionary).get("edges", [])
		for i: int in edges.size():
			if str((edges[i] as Dictionary).get("type", "")) == "doom_clock":
				_clock_edges.append({"node_id": nid, "idx": i, "edge": edges[i]})

## §4.4：写板后全量复查 doom_clock 边；once 防重复触发（35 节点量级，全量扫描即可）。
func _scan_triggers() -> void:
	for rec: Dictionary in _clock_edges:
		var key := "%s/%d" % [str(rec["node_id"]), int(rec["idx"])]
		var edge: Dictionary = rec["edge"]
		if bool(edge.get("once", true)) and _fired_triggers.has(key):
			continue
		if board.get_doom_clock() < int(edge.get("at", 0)):
			continue
		_fired_triggers[key] = true
		board.stream.emit(EventTypes.STORY_TRIGGER,
			{"edge": edge.duplicate(true), "at": int(edge.get("at", 0))}, &"graph", str(rec["node_id"]))
		_apply(edge.get("effects", []), str(rec["node_id"]))
		var to := str(edge.get("to", ""))
		if not to.is_empty() and to != current_id:
			_enter(to)
	_scan_clock_quests() # doom_clock 触发的事件随时钟写板复查（tech/02 §5）

# ---------------------------------------------------------------- L3 任务/事件运行时（tech/02 §5，TP4 接入）
# 触发 → quest.trigger 事件 + 事件中心可见；节点完成（离开）→ 按 settle 写板 + quest.settle 事件。
# 已完结事件由事件中心归档至历史卷轴（04 §⑤：事件流即档案）。

## 事件中心数据源：[{id, name, objective, node, state, optional}]（state: triggered/settled/abandoned）。
func quests() -> Array:
	var out: Array = []
	for qid: String in _quests:
		var q: Dictionary = _quests[qid]
		var def: Dictionary = q["def"]
		out.append({"id": qid, "name": str(def.get("name", qid)),
			"objective": str(def.get("objective", "")), "node": str(def.get("node", "")),
			"state": str(q["state"]), "optional": is_optional_quest(def)})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	return out

## 可选事件判定（04 §⑤「放弃可选事件」）：choice/hidden 触发 = 玩家自择介入；
## auto/doom_clock 触发 = 主线推移事件，不可放弃。
static func is_optional_quest(def: Dictionary) -> bool:
	return ["choice", "hidden"].has(str((def.get("trigger", {}) as Dictionary).get("type", "")))

## 放弃可选事件（04 §⑤：写旗标 + 事件 → 归档历史卷轴）。仅进行中（triggered）可选事件可放弃；
## 放弃后 state=abandoned（不再结算 settle、不计角标），旗标 <pack>.quest_abandoned.<id> 落板可溯源。
func abandon_quest(qid: String) -> bool:
	if not _quests.has(qid):
		return false
	var q: Dictionary = _quests[qid]
	if str(q["state"]) != "triggered" or not is_optional_quest(q["def"]):
		return false
	q["state"] = "abandoned"
	var ev := board.stream.emit(EventTypes.QUEST_ABANDON, {"id": qid,
		"name": str((q["def"] as Dictionary).get("name", qid))}, &"graph", current_id)
	board.write("%s.quest_abandoned.%s" % [pack_id, qid], true,
		{"event_id": ev["id"], "node_id": current_id, "pack_id": pack_id})
	return true

## 事件中心角标数：已触发未完结（04 §⑤ 主屏角标）。
func quest_badge_count() -> int:
	var n := 0
	for qid: String in _quests:
		if str((_quests[qid] as Dictionary)["state"]) == "triggered":
			n += 1
	return n

## 进入节点时登记 auto / hidden 触发（hidden 需满足 requires 隐形门槛，§5）。
func _scan_node_quests(node_id: String) -> void:
	for ev: Variant in pack.get("events", []):
		var def: Dictionary = ev
		var trig: Dictionary = def.get("trigger", {})
		if str(trig.get("node", "")) != node_id:
			continue
		match str(trig.get("type", "")):
			"auto":
				_trigger_quest(def)
			"hidden":
				if cond.evaluate(trig.get("requires", {}), {"pack_id": str(def.get("_ns", pack_id))}):
					_trigger_quest(def)

## 选择边离点前登记 choice 触发：trigger.node = 当前节点 且 label 匹配所选边（§5）。
func _scan_choice_quests(edge: Dictionary) -> void:
	var label := str(edge.get("label", ""))
	for ev: Variant in pack.get("events", []):
		var def: Dictionary = ev
		var trig: Dictionary = def.get("trigger", {})
		if str(trig.get("type", "")) == "choice" and str(trig.get("node", "")) == current_id \
				and str(trig.get("label", "")) == label:
			_trigger_quest(def)

## 时钟写板后复查 doom_clock 触发（§5 trigger.doom_clock.at）。
func _scan_clock_quests() -> void:
	for ev: Variant in pack.get("events", []):
		var def: Dictionary = ev
		var trig: Dictionary = def.get("trigger", {})
		if str(trig.get("type", "")) == "doom_clock" \
				and board.get_doom_clock() >= int(trig.get("at", 0)):
			_trigger_quest(def)

func _trigger_quest(def: Dictionary) -> void:
	var qid := str(def.get("id", ""))
	if qid.is_empty() or _quests.has(qid):
		return # 每事件只触发一次（once 语义，与 §4.4 一致）
	_quests[qid] = {"def": def.duplicate(true), "state": "triggered"}
	_quest_ns[qid] = str(def.get("_ns", pack_id)) # settle 写板归来源包命名空间（§2.6）
	board.stream.emit(EventTypes.QUEST_TRIGGER, {"id": qid, "name": str(def.get("name", qid)),
		"objective": str(def.get("objective", "")), "node": str(def.get("node", ""))},
		&"graph", current_id)

## 节点完成（离开）时结算以该节点为落点的已触发事件：按 settle 写板（§5）。
## settle 效果归事件来源包命名空间（graft 支线事件写本包旗标，§2.6）。
func _settle_quests_at(node_id: String) -> void:
	for qid: String in _quests:
		var q: Dictionary = _quests[qid]
		if str(q["state"]) != "triggered" or str((q["def"] as Dictionary).get("node", "")) != node_id:
			continue
		q["state"] = "settled"
		board.stream.emit(EventTypes.QUEST_SETTLE, {"id": qid,
			"name": str((q["def"] as Dictionary).get("name", qid))}, &"graph", node_id)
		_apply((q["def"] as Dictionary).get("settle", []), node_id, str(_quest_ns.get(qid, "")))

# ---------------------------------------------------------------- 快照（07 §4.1：进度随 meta 入存档）

## 图进度快照（存 SaveSystem meta.graph；Board/Rng/事件锚点由 SaveSystem 汇总）。
func serialize() -> Dictionary:
	var quest_states := {}
	for qid: String in _quests:
		quest_states[qid] = str((_quests[qid] as Dictionary)["state"])
	return {"current_id": current_id, "visit_log": visit_log.duplicate(),
		"completed": _completed.keys(), "fired_triggers": _fired_triggers.keys(),
		"quests": quest_states}

func deserialize(snap: Dictionary) -> void:
	current_id = str(snap.get("current_id", ""))
	visit_log.clear()
	for nid: Variant in snap.get("visit_log", []):
		visit_log.append(str(nid))
	_completed.clear()
	for nid: Variant in snap.get("completed", []):
		_completed[str(nid)] = true
	_fired_triggers.clear()
	for key: Variant in snap.get("fired_triggers", []):
		_fired_triggers[str(key)] = true
	_quests.clear()
	_quest_ns.clear()
	var defs := {}
	for ev: Variant in pack.get("events", []):
		defs[str((ev as Dictionary).get("id", ""))] = ev
	for qid: Variant in (snap.get("quests", {}) as Dictionary).keys():
		if defs.has(str(qid)):
			_quests[str(qid)] = {"def": (defs[str(qid)] as Dictionary).duplicate(true),
				"state": str(snap["quests"][qid])}
			_quest_ns[str(qid)] = str((defs[str(qid)] as Dictionary).get("_ns", pack_id))
