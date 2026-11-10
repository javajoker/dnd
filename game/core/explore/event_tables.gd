# 事件表与事件卡（docs/en/framework/16-map-and-exploration-spec.md §4）
# 选择 → 掷骰 → 结果：tables.json 的表按骰型掷出、按状态加修正、落到某行；行结果可以是
# 效果（效果 DSL）/ 检定（成败各有效果，失败即分支）/ 遭遇 / 事件卡 / 节点 / 嵌套另一张表。
# - once 行用过即作废，改落 instead 指向的行（独有发现只发生一次；簿记 <ns>.table.<id>.used）；
# - 一切随机走注入的种子化 Rng；掷骰与写板都在 core，事件流带 dice 清单供壳层画骰（17 §5）。
class_name EventTables
extends RefCounted

const MAX_DEPTH := 4 # 嵌套表上限（防内容循环；V20 静态再查一遍）

var board: Board
var stream: EventStream
var rng: Rng
var pack: Dictionary
var pack_id := ""
var watches_per_segment := 4

func _init(p_board: Board, p_stream: EventStream, p_rng: Rng, p_pack: Dictionary) -> void:
	board = p_board
	stream = p_stream
	rng = p_rng
	pack = p_pack
	pack_id = str(p_pack.get("pack_id", ""))
	watches_per_segment = int(((p_pack.get("manifest", {}) as Dictionary).get("travel", {}) as Dictionary).get(
		"watches_per_segment", 4))

## "d8" → 8；"d100" → 100；非法 → 0。
static func die_sides(die: String) -> int:
	return int(die.substr(1)) if die.begins_with("d") and die.substr(1).is_valid_int() else 0

## "2-3" → [2, 3]；"7" → [7, 7]。
static func parse_range(r: String) -> Array:
	var parts := r.split("-", false)
	if parts.size() == 2:
		return [int(parts[0]), int(parts[1])]
	return [int(r), int(r)]

## 行落点：total 所在 range 的行；找不到返回 -1。
static func row_for(table: Dictionary, total: int) -> int:
	var rows: Array = table.get("rows", [])
	for i: int in rows.size():
		var rr := parse_range(str((rows[i] as Dictionary).get("range", "")))
		if total >= int(rr[0]) and total <= int(rr[1]):
			return i
	return -1

func _used_key(table_id: String) -> String:
	return "%s.table.%s.used" % [pack_id, table_id]

## 修正合计：when 里 pace 由调用方上下文判定，其余条件走 Conditions（clock / flag / item / rep …）。
func _modifier(table: Dictionary, ctx: Dictionary) -> int:
	var total := 0
	var cond := Conditions.new(board)
	for m: Variant in table.get("modifiers", []):
		var md: Dictionary = m
		var when: Dictionary = (md.get("when", {}) as Dictionary).duplicate()
		var ok := true
		if when.has("pace"):
			ok = str(ctx.get("pace", "normal")) == str(when["pace"])
			when.erase("pace")
		if ok and not when.is_empty():
			ok = cond.evaluate(when, {"pack_id": pack_id})
		if ok:
			total += int(md.get("add", 0))
	return total

## 掷一张表（含嵌套）。返回 {rolls: [{table, die, value, mod, total, row, label}], outcome, label}。
func roll(table_id: String, ctx: Dictionary = {}, node_id: String = "") -> Dictionary:
	var rolls: Array = []
	var outcome := {}
	var label := ""
	var tid := table_id
	for depth: int in MAX_DEPTH:
		var t: Dictionary = (pack.get("tables", {}) as Dictionary).get(tid, {})
		if t.is_empty():
			push_error("EventTables: 未登记的表 '%s'" % tid)
			break
		var die := str(t.get("die", "d6"))
		var sides := maxi(die_sides(die), 1)
		var value := rng.d_n(sides)
		var mod := _modifier(t, ctx)
		var total := clampi(value + mod, 1, sides)
		var ri := row_for(t, total)
		if ri < 0:
			push_error("EventTables: 表 %s 未覆盖点数 %d（V20）" % [tid, total])
			break
		var rows: Array = t["rows"]
		var row: Dictionary = rows[ri]
		var used: Array = board.read(_used_key(tid), []) if board.read(_used_key(tid), []) is Array else []
		if bool(row.get("once", false)):
			if used.has(ri) and row.has("instead"):
				var alt := row_for(t, int(parse_range(str(row["instead"]))[0]))
				if alt >= 0:
					ri = alt
					row = rows[ri]
			elif not used.has(ri):
				var u2 := used.duplicate()
				u2.append(ri)
				board.write(_used_key(tid), u2, {"event_id": stream.tail(), "node_id": node_id, "pack_id": pack_id})
		label = str(row.get("label", ""))
		var dice: Array = LightV1.d100_dice(value) if sides == 100 else [{"die": die, "value": value}]
		stream.emit(EventTypes.TABLE_ROLL, {"table": tid, "die": die, "value": value, "mod": mod, "total": total,
			"row": ri, "label": label, "dice": dice, "key": bool(t.get("key", false)) or bool(row.get("key", false))},
			&"core", node_id)
		rolls.append({"table": tid, "die": die, "value": value, "mod": mod, "total": total, "row": ri, "label": label})
		outcome = (row.get("outcome", {}) as Dictionary).duplicate(true)
		if outcome.has("table"):
			tid = str(outcome["table"])
			outcome.erase("table")
			continue
		break
	return {"rolls": rolls, "outcome": outcome, "label": label}

## 结算一个结果（表行 outcome 或事件卡选项）：先落 effects，再按种类返回给引导层。
## mod_fn(skill) -> int = 检定修正（与 StoryGraph.check_mod 同源）。
## 返回 {kind: none|effects|check|encounter|card|node, success?, encounter?, card?, node?}
func resolve(outcome: Dictionary, mod_fn: Callable, node_id: String = "") -> Dictionary:
	var ctx := {"pack_id": pack_id, "node_id": node_id, "event_id": stream.tail(), "source": "core",
		"watches_per_segment": watches_per_segment}
	var cond := Conditions.new(board)
	var effects: Array = outcome.get("effects", [])
	if not effects.is_empty():
		cond.apply_effects(effects, ctx)
	var out := {"kind": "effects" if not effects.is_empty() else "none"}
	if outcome.has("check"):
		var chk: Dictionary = outcome["check"]
		var skill := str(chk.get("skill", "perception"))
		var dc := LightV1.dc_for(str(chk.get("difficulty", "medium")))
		var mod := int(mod_fn.call(skill)) if mod_fn.is_valid() else 0
		var res := LightV1.check(rng, mod, dc)
		var success := bool(res["success"])
		stream.emit(EventTypes.CHECK_ROLL, {"roller": "pc", "kind": "table_check", "skill": skill,
			"rolls": res["rolls"], "keep": res["keep"], "mod": mod, "total": res["total"], "dc": dc,
			"success": success, "key": bool(chk.get("key", false)),
			"extreme": bool(res["nat20"]) or bool(res["nat1"]),
			"dice": LightV1.d20_dice(res["rolls"], int(res["keep"])), "source": &"core"}, &"core", node_id)
		ctx["event_id"] = stream.tail()
		cond.apply_effects(outcome.get("success" if success else "failure", []), ctx)
		out = {"kind": "check", "success": success}
	if outcome.has("encounter"):
		out = {"kind": "encounter", "encounter": str(outcome["encounter"])}
	elif outcome.has("card"):
		out = {"kind": "card", "card": str(outcome["card"])}
	elif outcome.has("node"):
		out = {"kind": "node", "node": str(outcome["node"])}
	return out

## 事件卡选项（16 §4.2）：选项结构与表行 outcome 同构（label + check/effects/success/failure/encounter/node）。
func choose_card_option(card_id: String, idx: int, mod_fn: Callable, node_id: String = "") -> Dictionary:
	var card: Dictionary = (pack.get("cards", {}) as Dictionary).get(card_id, {})
	var opts: Array = card.get("options", [])
	if idx < 0 or idx >= opts.size():
		return {"kind": "none"}
	stream.emit(EventTypes.LOG, {"msg_key": "MSG_CARD_CHOICE", "args": {"title": str(card.get("title", card_id)),
		"choice": str((opts[idx] as Dictionary).get("label", ""))}}, &"core", node_id)
	return resolve(opts[idx], mod_fn, node_id)
