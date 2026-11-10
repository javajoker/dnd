# 主角构筑：职业 + 出身（docs/en/framework/11 §1.1；story/01 §4.3 白页者；classes.json）
# - 职业 = 世界观里的"技能组合包"（港卫 / 拾荒客 / 墨徒）：属性、生命骰、熟练、普攻、职业技能、起始装备；
# - 出身 = 烬港与三方势力的来历：额外熟练、纪念物（图鉴道具）、声望 / 金币 / 物品等效果、一段背景故事；
# - 选择写板（<ns>.hero.class / .background，簿记键）；apply() 把选择叠到包内玩家模板上——
#   读档、换语言重载包后再 apply 一次即可，所有读取玩家模板的地方（战斗组装 / 检定 / 名册）自动生效；
# - 未选择 = 模板原样（旧存档与测试的"缺省白页者"）。
class_name HeroBuild
extends RefCounted

const PATCH_FIELDS: Array[String] = ["attrs", "hp_formula", "ac_formula", "hit_die", "proficiencies",
	"basic_attack", "skills"]

static func player_id(pack: Dictionary) -> String:
	for cid: String in (pack.get("characters", {}) as Dictionary).keys():
		if str((pack["characters"][cid] as Dictionary).get("kind", "")) == "player_template":
			return cid
	return ""

static func _k(pack: Dictionary, suffix: String) -> String:
	return "%s.hero.%s" % [str(pack.get("pack_id", "")), suffix]

static func chosen_class(pack: Dictionary, board: Board) -> String:
	var v := str(board.read(_k(pack, "class"), ""))
	return "" if v == "false" else v

static func chosen_background(pack: Dictionary, board: Board) -> String:
	var v := str(board.read(_k(pack, "background"), ""))
	return "" if v == "false" else v

static func has_choices(pack: Dictionary) -> bool:
	return not (pack.get("classes", {}) as Dictionary).is_empty()

## 把选择叠到玩家模板上（幂等：原模板存于 pack["_hero_base"]）。
static func apply(pack: Dictionary, board: Board) -> void:
	var pid := player_id(pack)
	if pid == "":
		return
	var chars: Dictionary = pack["characters"]
	if not pack.has("_hero_base"):
		pack["_hero_base"] = (chars[pid] as Dictionary).duplicate(true)
	var t: Dictionary = (pack["_hero_base"] as Dictionary).duplicate(true)
	var cls: Dictionary = (pack.get("classes", {}) as Dictionary).get(chosen_class(pack, board), {})
	for f: String in PATCH_FIELDS:
		if cls.has(f):
			t[f] = (cls[f] as Variant) if not (cls[f] is Dictionary or cls[f] is Array) else (cls[f] as Variant).duplicate(true)
	if not cls.is_empty():
		t["class"] = str(cls["id"])
		if cls.has("art_ref"):
			t["art_ref"] = str(cls["art_ref"])
	var bg: Dictionary = (pack.get("backgrounds", {}) as Dictionary).get(chosen_background(pack, board), {})
	if not bg.is_empty():
		t["background"] = str(bg["id"])
		var profs: Array = (t.get("proficiencies", []) as Array).duplicate()
		if str(bg.get("proficiency", "")) != "" and not profs.has(str(bg["proficiency"])):
			profs.append(str(bg["proficiency"]))
		t["proficiencies"] = profs
	# 原地替换条目内容（其他持有同一字典引用的视图同步生效）
	var entry: Dictionary = chars[pid]
	entry.clear()
	entry.merge(t)

## 建角：写选择、叠模板、发起始物品与装备、结算出身效果。返回原因码（"" = 成功）。
static func choose(pack: Dictionary, board: Board, class_id: String, background_id: String, prov: Dictionary) -> String:
	var classes: Dictionary = pack.get("classes", {})
	var bgs: Dictionary = pack.get("backgrounds", {})
	if class_id != "" and not classes.has(class_id):
		return "bad_class"
	if background_id != "" and not bgs.has(background_id):
		return "bad_background"
	board.write(_k(pack, "class"), class_id, prov)
	board.write(_k(pack, "background"), background_id, prov)
	apply(pack, board)
	var pid := player_id(pack)
	var cls: Dictionary = classes.get(class_id, {})
	for it: Variant in cls.get("start_items", []):
		board.give_item(str((it as Dictionary)["item"]), int((it as Dictionary).get("n", 1)), prov)
	for iid: Variant in cls.get("start_equip", []):
		Equipment.equip(board, pack, pid, str(iid), prov)
	var bg: Dictionary = bgs.get(background_id, {})
	if str(bg.get("keepsake", "")) != "":
		board.give_item(str(bg["keepsake"]), 1, prov)
	if not (bg.get("effects", []) as Array).is_empty():
		Conditions.new(board).apply_effects(bg["effects"], {"pack_id": str(pack.get("pack_id", "")),
			"node_id": str(prov.get("node_id", "")), "event_id": int(prov.get("event_id", 0)), "source": "core"})
	board.stream.emit(EventTypes.LOG, {"msg_key": "MSG_HERO_CREATED", "toast": true, "args": {
		"class": str(cls.get("name", class_id)), "background": str(bg.get("name", background_id))}}, &"core",
		str(prov.get("node_id", "")))
	return ""
