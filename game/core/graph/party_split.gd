# 队伍分合（docs/en/framework/15-party-split-and-perspective-spec.md）
# 状态全部在状态板（簿记键，带溯源），故事图只持有"焦点小组"的当前节点：
#   <ns>.party.groups = {gid: {members[], node, status: active|waiting, entered, steps}}
#   <ns>.party.focus / .rejoin / .stash = {gid: {iid: n}} / .links = {gid: n} / .help = [gid…]
# - 分队边（split）建组、各组进各自支线；汇合节点是屏障：先到的组"等待"，最后一组到达才真正进入；
# - 背包分装：stash 只记"非焦点小组"手里的数量；焦点小组可用 = 背包总数 − 其他组持有（新得/消耗自然记在焦点组）；
# - 联络（links）：每组若干次数（长休恢复）；求援 / 送物 / 换人 / 远程触发都扣次数并进事件流；
# - 周目渐进（manifest.progression）：按周目决定能否分队、能否联络（15 §7）。
class_name PartySplit
extends RefCounted

const DEFAULT_CHARGES := 2
const DEFAULT_MAX_ITEMS := 2
const DEFAULT_MAX_DRIFT := 3 # 组间推进步数差上限（防一组跑太远；15 §2.4 落地为"节点步数"）

var board: Board
var pack: Dictionary
var pack_id := ""

func _init(p_board: Board, p_pack: Dictionary) -> void:
	board = p_board
	pack = p_pack
	pack_id = str(p_pack.get("pack_id", ""))

func _k(suffix: String) -> String:
	return "%s.party.%s" % [pack_id, suffix]

func _prov(node_id: String) -> Dictionary:
	return {"event_id": board.stream.tail(), "node_id": node_id, "pack_id": pack_id}

func _settings() -> Dictionary:
	return (pack.get("manifest", {}) as Dictionary).get("party", {})

# ---------------------------------------------------------------- 周目渐进（15 §7）

## 当前周目（1 起）：manifest.ngplus.carries.playthrough 指向的簿记键 + 1。
func playthrough() -> int:
	var carries: Dictionary = (((pack.get("manifest", {}) as Dictionary).get("ngplus", {}) as Dictionary).get("carries", {}) as Dictionary)
	var key := str(carries.get("playthrough", ""))
	return (int(board.read(key, 0)) if key != "" else 0) + 1

## 本周目生效的能力档：progression 中 ≤ 当前周目的最高档；未声明 = 全开。
func tier() -> Dictionary:
	var prog: Dictionary = (pack.get("manifest", {}) as Dictionary).get("progression", {})
	if prog.is_empty():
		return {"split": true, "links": true}
	var best := -1
	var out := {"split": true, "links": true}
	for k: Variant in prog.keys():
		var n := int(str(k))
		if n <= playthrough() and n > best:
			best = n
			out = prog[k]
	return out

func split_enabled() -> bool:
	return bool(tier().get("split", true))

func links_enabled() -> bool:
	return bool(tier().get("links", true))

# ---------------------------------------------------------------- 状态读取

func groups() -> Dictionary:
	var g: Variant = board.read(_k("groups"), {})
	return (g as Dictionary).duplicate(true) if g is Dictionary else {}

func is_split() -> bool:
	return groups().size() > 1

func focus() -> String:
	var f := str(board.read(_k("focus"), ""))
	return "" if f == "false" else f

func rejoin_node() -> String:
	var r := str(board.read(_k("rejoin"), ""))
	return "" if r == "false" else r

func group(gid: String) -> Dictionary:
	return groups().get(gid, {})

func members(gid: String) -> Array:
	return (group(gid).get("members", []) as Array).duplicate()

## 焦点小组领队（检定掷骰者，15 §2.2）；未分队返回 ""（= 玩家模板）。
func lead() -> String:
	if not is_split():
		return ""
	var ms := members(focus())
	return str(ms[0]) if not ms.is_empty() else ""

func charges(gid: String) -> int:
	var l: Variant = board.read(_k("links"), {})
	return int((l as Dictionary).get(gid, 0)) if l is Dictionary else 0

## 其他小组（按 split 声明顺序）。
func others() -> Array:
	var out: Array = []
	for gid: String in groups().keys():
		if gid != focus():
			out.append(gid)
	return out

## 下一个仍在行动的小组（焦点之外；无则 ""）。
func next_active() -> String:
	for gid: String in groups().keys():
		if gid != focus() and str((groups()[gid] as Dictionary).get("status", "")) == "active":
			return gid
	return ""

## 推进过远：焦点组步数比最慢的行动组多出 max_drift（15 §2.4）。
func blocked() -> bool:
	if not is_split():
		return false
	var gs := groups()
	var mine := int((gs.get(focus(), {}) as Dictionary).get("steps", 0))
	var slowest := mine
	for gid: String in gs.keys():
		var g: Dictionary = gs[gid]
		if gid != focus() and str(g.get("status", "")) == "active":
			slowest = mini(slowest, int(g.get("steps", 0)))
	return mine - slowest >= int(_settings().get("max_drift", DEFAULT_MAX_DRIFT))

# ---------------------------------------------------------------- 写入

func _write_groups(gs: Dictionary, node_id: String) -> void:
	board.write(_k("groups"), gs, _prov(node_id))

## 建组（分队边，15 §2.1）。返回首个小组 id。
func begin(edge: Dictionary, node_id: String) -> String:
	var gs := {}
	var links := {}
	var first := ""
	for g: Variant in edge.get("groups", []):
		var gd: Dictionary = g
		var gid := str(gd.get("id", ""))
		gs[gid] = {"members": (gd.get("members", []) as Array).duplicate(), "node": str(gd.get("entry", "")),
			"status": "active", "entered": false, "steps": 0}
		links[gid] = int(_settings().get("link_charges", DEFAULT_CHARGES))
		if first == "":
			first = gid
	_write_groups(gs, node_id)
	board.write(_k("rejoin"), str(edge.get("rejoin", "")), _prov(node_id))
	board.write(_k("links"), links, _prov(node_id))
	board.write(_k("stash"), {}, _prov(node_id))
	board.write(_k("focus"), first, _prov(node_id))
	board.stream.emit(EventTypes.PARTY_SPLIT, {"groups": gs.duplicate(true), "rejoin": str(edge.get("rejoin", "")),
		"label": str(edge.get("label", ""))}, &"graph", node_id)
	return first

func set_node(gid: String, nid: String, step: bool = false) -> void:
	var gs := groups()
	if not gs.has(gid):
		return
	(gs[gid] as Dictionary)["node"] = nid
	(gs[gid] as Dictionary)["entered"] = true
	if step:
		(gs[gid] as Dictionary)["steps"] = int((gs[gid] as Dictionary).get("steps", 0)) + 1
	_write_groups(gs, nid)

func set_status(gid: String, status: String, node_id: String) -> void:
	var gs := groups()
	if gs.has(gid):
		(gs[gid] as Dictionary)["status"] = status
		_write_groups(gs, node_id)

func set_focus(gid: String, node_id: String) -> void:
	capture_stash(focus(), node_id)
	board.write(_k("focus"), gid, _prov(node_id))

## 汇合（15 §2.3）：小组并回、背包合一、联络次数清空。
func merge(node_id: String) -> void:
	var gs := groups()
	board.stream.emit(EventTypes.PARTY_REJOIN, {"groups": gs.keys(), "node": node_id}, &"graph", node_id)
	for k: String in ["groups", "stash", "links", "help"]:
		board.write(_k(k), {} if k != "help" else [], _prov(node_id))
	board.write(_k("focus"), "", _prov(node_id))
	board.write(_k("rejoin"), "", _prov(node_id))

func all_waiting_except_focus() -> bool:
	for gid: String in groups().keys():
		if gid != focus() and str((groups()[gid] as Dictionary).get("status", "")) != "waiting":
			return false
	return true

# ---------------------------------------------------------------- 背包分装（15 §3.3）

func stash() -> Dictionary:
	var s: Variant = board.read(_k("stash"), {})
	return (s as Dictionary).duplicate(true) if s is Dictionary else {}

## 焦点组可用数 = 背包总数 − 其他组持有（未分队 = 背包总数）。
func available(iid: String) -> int:
	var total := board.item_count(iid)
	if not is_split():
		return total
	var st := stash()
	var held := 0
	for gid: Variant in st.keys():
		if str(gid) != focus():
			held += int((st[gid] as Dictionary).get(iid, 0))
	return maxi(0, total - held)

## 离开焦点时把该组此刻的实际持有写进 stash（新得/消耗都已体现在总数里）。
func capture_stash(gid: String, node_id: String) -> void:
	if gid == "" or not is_split():
		return
	var st := stash()
	var mine := {}
	for iid: String in (board.read("global.inv", {}) as Dictionary).keys():
		var n := available(iid)
		if n > 0:
			mine[iid] = n
	st[gid] = mine
	board.write(_k("stash"), st, _prov(node_id))

## 分装：assign = {gid: {iid: n}}（各物品合计 ≤ 背包总数；焦点组拿余下的）。返回原因码。
func divide(assign: Dictionary, node_id: String) -> String:
	var totals := {}
	for gid: Variant in assign.keys():
		for iid: Variant in (assign[gid] as Dictionary).keys():
			totals[str(iid)] = int(totals.get(str(iid), 0)) + int(assign[gid][iid])
	for iid: Variant in totals.keys():
		if int(totals[iid]) > board.item_count(str(iid)):
			return "over"
	var st := {}
	for gid: Variant in assign.keys():
		if str(gid) != focus():
			st[str(gid)] = (assign[gid] as Dictionary).duplicate()
	board.write(_k("stash"), st, _prov(node_id))
	return ""

## 缺省分装：每件物品轮流发给持有最少的小组（治疗品优先，15 §3.3）。
func default_division() -> Dictionary:
	var out := {}
	var counts := {}
	for gid: String in groups().keys():
		out[gid] = {}
		counts[gid] = 0
	var inv: Dictionary = board.read("global.inv", {})
	var ids: Array = inv.keys()
	var items: Dictionary = pack.get("items", {})
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ha := ((items.get(str(a), {}) as Dictionary).get("use", {}) as Dictionary).has("heal")
		var hb := ((items.get(str(b), {}) as Dictionary).get("use", {}) as Dictionary).has("heal")
		return ha and not hb)
	for iid: Variant in ids:
		if not (items.get(str(iid), {}) as Dictionary).has("use"):
			continue # 只分可用道具；剧情钥匙 / 图鉴留在背包总账（焦点组）
		for i: int in int(inv[iid]):
			var best := ""
			for gid: String in counts.keys():
				if best == "" or int(counts[gid]) < int(counts[best]):
					best = gid
			(out[best] as Dictionary)[str(iid)] = int((out[best] as Dictionary).get(str(iid), 0)) + 1
			counts[best] = int(counts[best]) + 1
	return out

# ---------------------------------------------------------------- 联络（15 §5）

func spend(gid: String, cost: int, node_id: String) -> bool:
	if not links_enabled() or charges(gid) < cost:
		return false
	var l: Dictionary = board.read(_k("links"), {})
	l = l.duplicate()
	l[gid] = int(l.get(gid, 0)) - cost
	board.write(_k("links"), l, _prov(node_id))
	return true

func restore_charges(node_id: String) -> void:
	if not is_split():
		return
	var l := {}
	for gid: String in groups().keys():
		l[gid] = int(_settings().get("link_charges", DEFAULT_CHARGES))
	board.write(_k("links"), l, _prov(node_id))

func add_help(gid: String, node_id: String) -> void:
	var h: Array = (board.read(_k("help"), []) as Array).duplicate() if board.read(_k("help"), []) is Array else []
	if not h.has(gid):
		h.append(gid)
		board.write(_k("help"), h, _prov(node_id))

## 远方求援：本组下一次检定优势（消耗一次）。
func consume_help(gid: String, node_id: String) -> bool:
	var h: Array = (board.read(_k("help"), []) as Array).duplicate() if board.read(_k("help"), []) is Array else []
	if not h.has(gid):
		return false
	h.erase(gid)
	board.write(_k("help"), h, _prov(node_id))
	return true

func max_items() -> int:
	return int(_settings().get("max_items", DEFAULT_MAX_ITEMS))

## 送物（15 §5.2）：焦点组 → 目标组 stash，单次不超过 max_items。
func send_item(iid: String, n: int, target: String, node_id: String) -> String:
	if not groups().has(target) or target == focus():
		return "bad_target"
	if n < 1 or n > max_items() or available(iid) < n:
		return "not_enough"
	if not spend(focus(), 1, node_id):
		return "no_charge"
	var st := stash()
	var t: Dictionary = (st.get(target, {}) as Dictionary).duplicate()
	t[iid] = int(t.get(iid, 0)) + n
	st[target] = t
	board.write(_k("stash"), st, _prov(node_id))
	board.stream.emit(EventTypes.PARTY_LINK, {"kind": "send_item", "from": focus(), "to": target, "item": iid, "n": n,
		"name": str(((pack.get("items", {}) as Dictionary).get(iid, {}) as Dictionary).get("name", iid))}, &"graph", node_id)
	return ""

## 换人（15 §5.2）：只在锚点之间（两组当前节点都 anchor:true），2 次 + 时间钟 +1；不得清空一组。
func move_member(cid: String, target: String, node_id: String) -> String:
	var gs := groups()
	var from := focus()
	if not gs.has(target) or target == from:
		return "bad_target"
	var nodes: Dictionary = pack.get("nodes", {})
	if not bool((nodes.get(str((gs[from] as Dictionary)["node"]), {}) as Dictionary).get("anchor", false)) \
			or not bool((nodes.get(str((gs[target] as Dictionary)["node"]), {}) as Dictionary).get("anchor", false)):
		return "no_anchor"
	var ms: Array = (gs[from] as Dictionary)["members"]
	if not ms.has(cid) or ms.size() <= 1:
		return "cannot_leave"
	if not spend(from, 2, node_id):
		return "no_charge"
	ms.erase(cid)
	((gs[target] as Dictionary)["members"] as Array).append(cid)
	_write_groups(gs, node_id)
	board.stream.emit(EventTypes.PARTY_LINK, {"kind": "move_member", "from": from, "to": target, "member": cid}, &"graph", node_id)
	return ""
