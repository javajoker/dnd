# 区域地图（docs/en/framework/16-map-and-exploration-spec.md §2：点线式行旅 point-crawl）
# - 地点（location）由路线（route）相连；隐藏地点/路线经 reveal 效果或抵达相邻地点揭示（迷雾）；
# - 行程按"段"推进，每段 = 1 个时辰（watch）：步调（fast/normal/careful）→ 导航检定（荒野/雾区）
#   → 路线事件表掷骰 → 时辰累计满额推进时间钟（时间即地理）；
# - 一次只推进一段（step）：遭遇 / 事件卡打断后行程保留，下次继续——桌游的"一步一骰"节奏；
# - 状态全部写板（簿记键，带溯源）：<ns>.map.<map>.pos / .seen / .visited / .journey，<ns>.watch。
class_name RegionMap
extends RefCounted

const PACES: Array[String] = ["fast", "normal", "careful"]
## 地形 → 导航难度（road 不检定）。
const NAV_DIFFICULTY := {"wild": "easy", "fog": "medium", "sea": "medium"}

var board: Board
var stream: EventStream
var rng: Rng
var pack: Dictionary
var pack_id := ""
var map_id := ""
var map: Dictionary = {}
var tables: EventTables

func _init(p_board: Board, p_stream: EventStream, p_rng: Rng, p_pack: Dictionary, p_map_id: String) -> void:
	board = p_board
	stream = p_stream
	rng = p_rng
	pack = p_pack
	pack_id = str(p_pack.get("pack_id", ""))
	map_id = p_map_id
	map = (p_pack.get("maps", {}) as Dictionary).get(p_map_id, {})
	tables = EventTables.new(p_board, p_stream, p_rng, p_pack)

func _k(suffix: String) -> String:
	return "%s.map.%s.%s" % [pack_id, map_id, suffix]

func _prov(node_id: String = "") -> Dictionary:
	return {"event_id": stream.tail(), "node_id": node_id, "pack_id": pack_id}

func _arr(key: String) -> Array:
	var v: Variant = board.read(key, [])
	return (v as Array).duplicate() if v is Array else []

# ---------------------------------------------------------------- 查询

func location(id: String) -> Dictionary:
	for l: Variant in map.get("locations", []):
		if str((l as Dictionary).get("id", "")) == id:
			return l
	return {}

func pos() -> String:
	var p := str(board.read(_k("pos"), ""))
	return p if p != "" and p != "false" else str(map.get("start", ""))

func seen() -> Array:
	var out := _arr(_k("seen"))
	for l: Variant in map.get("locations", []):
		var d: Dictionary = l
		if not bool(d.get("hidden", false)) and not out.has(str(d["id"])):
			out.append(str(d["id"]))
	if not out.has(pos()):
		out.append(pos())
	return out

func visited() -> Array:
	var out := _arr(_k("visited"))
	if not out.has(pos()):
		out.append(pos())
	return out

func journey() -> Dictionary:
	var j: Variant = board.read(_k("journey"), {})
	return j if j is Dictionary else {}

## 路线可见：两端都已揭示，且 requires 成立。
func route_visible(r: Dictionary) -> bool:
	var s := seen()
	if not (s.has(str(r.get("from", ""))) and s.has(str(r.get("to", "")))):
		return false
	if r.has("requires"):
		return Conditions.new(board).evaluate(r["requires"], {"pack_id": pack_id})
	return true

## 从 loc 出发的可见路线：[{route, other}]。
func routes_from(loc: String) -> Array:
	var out: Array = []
	for r: Variant in map.get("routes", []):
		var d: Dictionary = r
		if not route_visible(d):
			continue
		if str(d["from"]) == loc:
			out.append({"route": d, "other": str(d["to"])})
		elif str(d["to"]) == loc:
			out.append({"route": d, "other": str(d["from"])})
	return out

func route_between(a: String, b: String) -> Dictionary:
	for e: Variant in routes_from(a):
		if str((e as Dictionary)["other"]) == b:
			return (e as Dictionary)["route"]
	return {}

## 步调修正后的段数（16 §2.2：fast 每 2 段省 1 段，careful 每 2 段多 1 段，至少 1）。
static func effective_legs(legs: int, pace: String) -> int:
	match pace:
		"fast":
			return maxi(1, legs - legs / 2)
		"careful":
			return legs + legs / 2
	return maxi(1, legs)

# ---------------------------------------------------------------- 行程

## 出发：须有可见路线；已有行程时拒绝（先走完）。返回原因码（"" = 成功）。
func start_journey(to: String, pace: String, node_id: String = "") -> String:
	if not journey().is_empty():
		return "in_journey"
	if not PACES.has(pace):
		pace = "normal"
	var r := route_between(pos(), to)
	if r.is_empty():
		return "no_route"
	var legs := effective_legs(int(r.get("legs", 1)), pace)
	board.write(_k("journey"), {"from": pos(), "to": to, "pace": pace, "legs_left": legs, "legs_total": legs},
		_prov(node_id))
	return ""

## 推进一段。mod_fn(skill) = 检定修正。返回 {from, to, legs_left, arrived, lost, outcome{kind…}, table{…}}。
func step(mod_fn: Callable, node_id: String = "") -> Dictionary:
	var j := journey()
	if j.is_empty():
		return {}
	var r := route_between(str(j["from"]), str(j["to"]))
	var terrain := str(r.get("terrain", "road"))
	var pace := str(j.get("pace", "normal"))
	var ctx := {"pack_id": pack_id, "node_id": node_id, "event_id": stream.tail(), "source": "core",
		"watches_per_segment": tables.watches_per_segment}
	Conditions.new(board).apply_effects([{"watch": 1}], ctx) # 每段一个时辰
	var lost := false
	if NAV_DIFFICULTY.has(terrain):
		var skill := "perception"
		var dc := LightV1.dc_for(str(r.get("difficulty", NAV_DIFFICULTY[terrain])))
		var mode := LightV1.ADV_ADVANTAGE if pace == "careful" else (LightV1.ADV_DISADVANTAGE if pace == "fast" else LightV1.ADV_NORMAL)
		var mod := int(mod_fn.call(skill)) if mod_fn.is_valid() else 0
		var res := LightV1.check(rng, mod, dc, mode)
		lost = not bool(res["success"])
		stream.emit(EventTypes.CHECK_ROLL, {"roller": "pc", "kind": "navigation", "skill": skill,
			"rolls": res["rolls"], "keep": res["keep"], "mod": mod, "total": res["total"], "dc": dc,
			"success": not lost, "key": false, "extreme": bool(res["nat20"]) or bool(res["nat1"]),
			"mode": String(mode), "dice": LightV1.d20_dice(res["rolls"], int(res["keep"])), "source": &"core"},
			&"core", node_id)
	var legs_left := int(j["legs_left"]) - (0 if lost else 1) # 迷途：这一段白走（失败即分支：多耗时辰）
	var table_id := str(r.get("table", (map.get("tables", {}) as Dictionary).get(terrain, "")))
	var table_res := {}
	var outcome := {"kind": "none"}
	if table_id != "":
		table_res = tables.roll(table_id, {"pace": pace}, node_id)
		outcome = tables.resolve(table_res.get("outcome", {}), mod_fn, node_id)
	var arrived := legs_left <= 0
	var out := {"from": str(j["from"]), "to": str(j["to"]), "legs_left": maxi(legs_left, 0), "arrived": arrived,
		"lost": lost, "outcome": outcome, "table": table_res}
	if arrived:
		board.write(_k("journey"), {}, _prov(node_id))
		_arrive(str(j["to"]), node_id)
	else:
		var j2 := j.duplicate()
		j2["legs_left"] = legs_left
		board.write(_k("journey"), j2, _prov(node_id))
	stream.emit(EventTypes.MAP_TRAVEL, {"map": map_id, "from": out["from"], "to": out["to"],
		"legs_left": out["legs_left"], "arrived": arrived, "lost": lost,
		"to_name": str(location(str(j["to"])).get("name", j["to"]))}, &"core", node_id)
	return out

## 抵达：位置写板、记已访、揭示相邻地点（16 §2.1：抵达相邻即揭示）。
func _arrive(loc: String, node_id: String) -> void:
	board.write(_k("pos"), loc, _prov(node_id))
	var v := _arr(_k("visited"))
	if not v.has(loc):
		v.append(loc)
		board.write(_k("visited"), v, _prov(node_id))
	var s := _arr(_k("seen"))
	var changed := false
	for r: Variant in map.get("routes", []):
		var d: Dictionary = r
		if bool(d.get("hidden", false)):
			continue # 隐藏路线不随抵达揭示（只经 reveal 效果）
		var other := ""
		if str(d["from"]) == loc:
			other = str(d["to"])
		elif str(d["to"]) == loc:
			other = str(d["from"])
		if other != "" and not s.has(other) and not bool(location(other).get("secret", false)):
			s.append(other)
			changed = true
	if changed:
		board.write(_k("seen"), s, _prov(node_id))

## 视图模型数据（壳只读）：地点 / 路线 / 当前位置 / 行程。
func view() -> Dictionary:
	var s := seen()
	var v := visited()
	var here := pos()
	var locs: Array = []
	for l: Variant in map.get("locations", []):
		var d: Dictionary = l
		var id := str(d["id"])
		if not s.has(id):
			continue
		locs.append({"id": id, "name": str(d.get("name", id)), "pos": d.get("pos", [0, 0]),
			"visited": v.has(id), "here": id == here, "icon": str(d.get("icon", "")),
			"site": str(d.get("site", "")), "node": str(d.get("node", ""))})
	var routes: Array = []
	for r: Variant in map.get("routes", []):
		var d2: Dictionary = r
		if route_visible(d2):
			routes.append({"from": str(d2["from"]), "to": str(d2["to"]), "legs": int(d2.get("legs", 1)),
				"danger": int(d2.get("danger", 0)), "terrain": str(d2.get("terrain", "road"))})
	return {"id": map_id, "name": str(map.get("name", map_id)), "locations": locs, "routes": routes,
		"here": here, "journey": journey(), "watch": int(board.read("%s.watch" % pack_id, 0)),
		"watches_per_segment": tables.watches_per_segment,
		"background": (map.get("background", {}) as Dictionary).duplicate()} # 背景图纯呈现透传（16 §6）
