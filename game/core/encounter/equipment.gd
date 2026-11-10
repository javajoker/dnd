# 装备（docs/framework/10-道具与图鉴规范.md §装备；docs/tech/04-资源与效果系统.md §4.1；11 文档 §8.1）
# d20 核心规则口径的四个装备槽：武器 / 护甲 / 盾牌 / 饰物。
# - 装备 = items.json 条目的可选 `equip` 块：{slot, ac?, attack?, damage_die?, max_hp?, users?}；
# - 持有走背包（global.inv）；"谁装备了哪件"是世界状态，写包命名空间簿记键 <ns>.equip.<char_id>.<slot>；
# - 同一道具可被装备的人数 ≤ 背包持有数（两人不能共用同一把斧）；
# - 修正在战斗组装时叠加（BattleDef）：AC 加值、攻击加值、武器伤害骰替换（保留原修正）、HP 上限加值；
# - 战斗中只允许换武器（物品互动，每回合一次免费）；护甲/盾牌/饰物只在战斗外更换（穿脱护甲需要时间）。
# 纯数据 + 板读写，零引擎依赖。
class_name Equipment
extends RefCounted

const SLOTS: Array[String] = ["weapon", "armor", "shield", "trinket"]
const MOD_KEYS: Array[String] = ["ac", "attack", "damage_die", "max_hp"]
## 战斗中可更换的槽位（11 §8.1：只有武器能在战斗中拔出/收起）。
const COMBAT_SWAPPABLE: Array[String] = ["weapon"]

static func key(pack_id: String, cid: String, slot: String) -> String:
	return "%s.equip.%s.%s" % [pack_id, cid, slot]

## 道具的 equip 块（非装备返回 {}）。
static func equip_block(items: Dictionary, iid: String) -> Dictionary:
	return ((items.get(iid, {}) as Dictionary).get("equip", {}) as Dictionary)

## 角色当前装备 {slot: item_id}（只含仍持有的；背包已无该道具的槽位视为空）。
static func equipped(board: Board, pack_id: String, items: Dictionary, cid: String) -> Dictionary:
	var out := {}
	for slot: String in SLOTS:
		var k := key(pack_id, cid, slot)
		if not board.has(k):
			continue
		var iid := str(board.read(k))
		if iid.is_empty() or iid == "false" or equip_block(items, iid).is_empty() or not board.has_item(iid):
			continue
		out[slot] = iid
	return out

## 装备了该道具的角色列表（队伍范围：characters.json 的 player_template / companion）。
static func holders(board: Board, pack: Dictionary, iid: String) -> Array[String]:
	var out: Array[String] = []
	var slot := str(equip_block(pack.get("items", {}), iid).get("slot", ""))
	if slot.is_empty():
		return out
	var pid := str(pack.get("pack_id", ""))
	for cid: String in (pack.get("characters", {}) as Dictionary).keys():
		var k := key(pid, cid, slot)
		if board.has(k) and str(board.read(k)) == iid:
			out.append(cid)
	return out

## 可分配的余量 = 持有数 − 已被他人装备数（cid 自己已装备的不计）。
static func free_count(board: Board, pack: Dictionary, iid: String, for_cid: String = "") -> int:
	var hs := holders(board, pack, iid)
	hs.erase(for_cid)
	return board.item_count(iid) - hs.size()

## 能否装备：返回 "" = 可以，否则原因码（not_equipment / not_owned / none_free / not_user）。
static func can_equip(board: Board, pack: Dictionary, cid: String, iid: String) -> String:
	var eb := equip_block(pack.get("items", {}), iid)
	if eb.is_empty():
		return "not_equipment"
	if not board.has_item(iid):
		return "not_owned"
	var users: Array = eb.get("users", [])
	if not users.is_empty() and not users.has(cid):
		return "not_user"
	if free_count(board, pack, iid, cid) <= 0:
		return "none_free"
	return ""

## 装备（写板）。返回原因码，"" = 成功。
static func equip(board: Board, pack: Dictionary, cid: String, iid: String, prov: Dictionary) -> String:
	var reason := can_equip(board, pack, cid, iid)
	if reason != "":
		return reason
	var slot := str(equip_block(pack.get("items", {}), iid)["slot"])
	board.write(key(str(pack.get("pack_id", "")), cid, slot), iid, prov)
	return ""

## 卸下某槽（写空串）。
static func unequip(board: Board, pack_id: String, cid: String, slot: String, prov: Dictionary) -> void:
	var k := key(pack_id, cid, slot)
	if board.has(k) and str(board.read(k)) != "":
		board.write(k, "", prov)

## 修正合计 {ac, attack, damage_die, max_hp, weapon}（damage_die 取武器槽；无则空串）。
static func modifiers(board: Board, pack_id: String, items: Dictionary, cid: String) -> Dictionary:
	var out := {"ac": 0, "attack": 0, "damage_die": "", "max_hp": 0, "weapon": ""}
	var eq := equipped(board, pack_id, items, cid)
	for slot: String in eq.keys():
		var eb := equip_block(items, str(eq[slot]))
		out["ac"] = int(out["ac"]) + int(eb.get("ac", 0))
		out["max_hp"] = int(out["max_hp"]) + int(eb.get("max_hp", 0))
		if slot == "weapon":
			out["attack"] = int(out["attack"]) + int(eb.get("attack", 0))
			out["damage_die"] = str(eb.get("damage_die", ""))
			out["weapon"] = str(eq[slot])
		else:
			out["attack"] = int(out["attack"]) + int(eb.get("attack", 0))
	return out

## 武器伤害骰替换：保留原表达式的固定修正，只换骰子（"1d6+2" + "1d8" → "1d8+2"）。
static func weapon_damage(base_expr: String, die: String) -> String:
	if die.is_empty():
		return base_expr
	var mod := int(LightV1.parse_dice(base_expr).get("mod", 0))
	if mod > 0:
		return "%s+%d" % [die, mod]
	if mod < 0:
		return "%s%d" % [die, mod]
	return die

## 装备一句话说明（呈现层文案拼装的数据侧：[{key, value}]，壳按语言格式化）。
static func describe(items: Dictionary, iid: String) -> Dictionary:
	var eb := equip_block(items, iid)
	return {"slot": str(eb.get("slot", "")), "ac": int(eb.get("ac", 0)), "attack": int(eb.get("attack", 0)),
		"damage_die": str(eb.get("damage_die", "")), "max_hp": int(eb.get("max_hp", 0))}
