# 场所地图（docs/en/framework/16-map-and-exploration-spec.md §3：城镇 / 地城 / 灯塔……）
# - 区域（area）经通道相连；门：open（缺省）/ locked（钥匙道具，或可选撬锁检定）/ stuck（力量·运动检定，
#   失败弄出声响 → 掷场所 wandering 表）/ secret（须先被揭示：搜索类 feature 的 reveal_exit 或旗标）；
# - 可交互物（feature）：检定或直接效果，缺省一次性；首次进入区域可掷 on_enter 表、触发区域遭遇；
# - 出口 to = "@map" 回到所在区域地图；
# - 同一份数据两种呈现：竖屏 = 房间序列，横屏 = 迷雾区域图（壳层决定，本类只给数据）。
# 状态写板（簿记键）：<ns>.site.<id>.area / .entered / .opened / .used / .revealed。
class_name SiteMap
extends RefCounted

const EXIT_TO_MAP := "@map"

var board: Board
var stream: EventStream
var rng: Rng
var pack: Dictionary
var pack_id := ""
var site_id := ""
var site: Dictionary = {}
var tables: EventTables

func _init(p_board: Board, p_stream: EventStream, p_rng: Rng, p_pack: Dictionary, p_site_id: String) -> void:
	board = p_board
	stream = p_stream
	rng = p_rng
	pack = p_pack
	pack_id = str(p_pack.get("pack_id", ""))
	site_id = p_site_id
	site = (p_pack.get("sites", {}) as Dictionary).get(p_site_id, {})
	tables = EventTables.new(p_board, p_stream, p_rng, p_pack)

func _k(suffix: String) -> String:
	return "%s.site.%s.%s" % [pack_id, site_id, suffix]

func _prov(node_id: String) -> Dictionary:
	return {"event_id": stream.tail(), "node_id": node_id, "pack_id": pack_id}

func _arr(key: String) -> Array:
	var v: Variant = board.read(key, [])
	return (v as Array).duplicate() if v is Array else []

func _add(key: String, value: String, node_id: String) -> void:
	var a := _arr(key)
	if not a.has(value):
		a.append(value)
		board.write(key, a, _prov(node_id))

func area_def(id: String) -> Dictionary:
	for a: Variant in site.get("areas", []):
		if str((a as Dictionary).get("id", "")) == id:
			return a
	return {}

func current() -> String:
	var a := str(board.read(_k("area"), ""))
	return a if a != "" and a != "false" else str(site.get("start", ""))

func entered() -> Array:
	return _arr(_k("entered"))

static func _door_id(a: String, b: String) -> String:
	return "%s>%s" % [a, b] if a < b else "%s>%s" % [b, a]

## 进入区域（首次：on_enter 表 / 区域遭遇）。返回 {area, first, outcome{kind…}}。
func enter(area_id: String, mod_fn: Callable, node_id: String = "") -> Dictionary:
	var first := not entered().has(area_id)
	board.write(_k("area"), area_id, _prov(node_id))
	_add(_k("entered"), area_id, node_id)
	stream.emit(EventTypes.SITE_ENTER, {"site": site_id, "area": area_id, "first": first,
		"name": str(area_def(area_id).get("name", area_id))}, &"core", node_id)
	var outcome := {"kind": "none"}
	if first:
		var a := area_def(area_id)
		var oe: Dictionary = a.get("on_enter", {})
		if oe.has("table"):
			outcome = tables.resolve(tables.roll(str(oe["table"]), {}, node_id).get("outcome", {}), mod_fn, node_id)
		if a.has("encounter") and outcome.get("kind", "none") in ["none", "effects", "check"]:
			outcome = {"kind": "encounter", "encounter": str(a["encounter"])}
	return {"area": area_id, "first": first, "outcome": outcome}

## 当前区域的出口：[{to, name, door, state: open|locked|stuck|map, key?}]（未揭示的密门不列出）。
func exits() -> Array:
	var here := current()
	var opened := _arr(_k("opened"))
	var revealed := _arr(_k("revealed"))
	var out: Array = []
	for e: Variant in area_def(here).get("exits", []):
		var d: Dictionary = e
		var to := str(d.get("to", ""))
		var door := str(d.get("door", "open"))
		if door == "secret" and not revealed.has(_door_id(here, to)) \
				and not (d.has("flag") and bool(board.read("%s.%s" % [pack_id, str(d["flag"])]))):
			continue
		var state := "open"
		if to == EXIT_TO_MAP:
			state = "map"
		elif door in ["locked", "stuck"] and not opened.has(_door_id(here, to)):
			state = door
		out.append({"to": to, "name": str(area_def(to).get("name", to)) if to != EXIT_TO_MAP else "",
			"door": door, "state": state, "key": str(d.get("key", "")),
			"pick": (d.get("pick", {}) as Dictionary).duplicate(), "force": (d.get("force", {}) as Dictionary).duplicate()})
	return out

## 当前区域可用的可交互物（一次性的用过即隐去）。
func features() -> Array:
	var used := _arr(_k("used"))
	var out: Array = []
	for f: Variant in area_def(current()).get("features", []):
		var d: Dictionary = f
		var fid := "%s.%s" % [current(), str(d.get("id", ""))]
		if bool(d.get("once", true)) and used.has(fid):
			continue
		out.append(d)
	return out

## 使用可交互物：检定 / 效果（同事件表结果结算口径）；reveal_exit 揭示本区密门。
func use_feature(fid: String, mod_fn: Callable, node_id: String = "") -> Dictionary:
	var f := {}
	for d: Variant in features():
		if str((d as Dictionary).get("id", "")) == fid:
			f = d
	if f.is_empty():
		return {"kind": "none", "reason": "no_feature"}
	_add(_k("used"), "%s.%s" % [current(), fid], node_id)
	var res := tables.resolve(f, mod_fn, node_id)
	var ok := str(res.get("kind", "")) != "check" or bool(res.get("success", false))
	if ok and f.has("reveal_exit"):
		_add(_k("revealed"), _door_id(current(), str(f["reveal_exit"])), node_id)
	stream.emit(EventTypes.FEATURE_USE, {"site": site_id, "area": current(), "feature": fid,
		"label": str(f.get("label", fid)), "success": ok}, &"core", node_id)
	return res

## 通过出口：开着就走；锁门需钥匙或撬锁检定；卡住需力量检定（失败掷 wandering 表）。
## 返回 {moved, to, state, outcome{kind…}, to_map}。
func go(to: String, mod_fn: Callable, node_id: String = "") -> Dictionary:
	var ex := {}
	for e: Variant in exits():
		if str((e as Dictionary)["to"]) == to:
			ex = e
	if ex.is_empty():
		return {"moved": false, "reason": "no_exit"}
	if str(ex["state"]) == "map":
		return {"moved": true, "to_map": true, "to": to, "outcome": {"kind": "none"}}
	var here := current()
	if str(ex["state"]) == "locked":
		var key := str(ex.get("key", ""))
		if key != "" and board.has_item(key):
			_add(_k("opened"), _door_id(here, to), node_id)
		elif not (ex["pick"] as Dictionary).is_empty():
			var r := tables.resolve({"check": ex["pick"]}, mod_fn, node_id)
			if not bool(r.get("success", false)):
				return {"moved": false, "to": to, "state": "locked", "outcome": r}
			_add(_k("opened"), _door_id(here, to), node_id)
		else:
			return {"moved": false, "to": to, "state": "locked", "reason": "need_key"}
	elif str(ex["state"]) == "stuck":
		var force: Dictionary = ex["force"] if not (ex["force"] as Dictionary).is_empty() \
			else {"skill": "athletics", "difficulty": "medium"}
		var r2 := tables.resolve({"check": force}, mod_fn, node_id)
		if not bool(r2.get("success", false)):
			var noise := {"kind": "none"}
			if str(site.get("wandering_table", "")) != "":
				noise = tables.resolve(tables.roll(str(site["wandering_table"]), {}, node_id).get("outcome", {}),
					mod_fn, node_id)
			return {"moved": false, "to": to, "state": "stuck", "outcome": noise}
		_add(_k("opened"), _door_id(here, to), node_id)
	var en := enter(to, mod_fn, node_id)
	return {"moved": true, "to": to, "state": "open", "outcome": en["outcome"]}

## 视图数据：区域（已进入 / 当前 / 未知迷雾）、连线、当前区域、出口、可交互物。
func view() -> Dictionary:
	var ent := entered()
	var here := current()
	var areas: Array = []
	var known := ent.duplicate()
	if not known.has(here):
		known.append(here)
	for e: Variant in exits():
		if str((e as Dictionary)["to"]) != EXIT_TO_MAP and not known.has(str((e as Dictionary)["to"])):
			known.append(str((e as Dictionary)["to"]))
	for a: Variant in site.get("areas", []):
		var d: Dictionary = a
		var id := str(d["id"])
		areas.append({"id": id, "name": str(d.get("name", id)) if ent.has(id) or id == here else "?",
			"pos": d.get("pos", [0, 0]), "entered": ent.has(id), "current": id == here, "known": known.has(id)})
	var links: Array = []
	for a: Variant in site.get("areas", []):
		for e: Variant in (a as Dictionary).get("exits", []):
			var to := str((e as Dictionary).get("to", ""))
			if to == EXIT_TO_MAP:
				continue
			var from := str((a as Dictionary)["id"])
			if known.has(from) and known.has(to) and (ent.has(from) or ent.has(to)):
				links.append({"from": from, "to": to})
	var ad := area_def(here)
	return {"id": site_id, "name": str(site.get("name", site_id)), "areas": areas, "links": links,
		"current": here, "area_name": str(ad.get("name", here)), "area_text": str(ad.get("text", "")),
		"exits": exits(), "features": features()}
